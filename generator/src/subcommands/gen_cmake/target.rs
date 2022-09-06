use std::error::Error;
use std::rc::Rc;

#[derive(Clone)]
pub enum CargoTargetType {
    Executable,
    Library {
        has_staticlib: bool,
        has_cdylib: bool,
    },
}

#[derive(Clone)]
pub struct CargoTarget {
    cargo_package: Rc<cargo_metadata::Package>,
    cargo_target: cargo_metadata::Target,
    target_type: CargoTargetType,
}

pub(crate) enum ConfigType {
    SingleConfig(Option<String>),
    MultiConfig(Vec<String>),
}

impl CargoTarget {
    pub fn from_metadata(
        cargo_package: Rc<cargo_metadata::Package>,
        cargo_target: cargo_metadata::Target,
    ) -> Option<Self> {
        let target_type = if cargo_target
            .kind
            .iter()
            .any(|k| k == "staticlib" || k == "cdylib")
        {
            CargoTargetType::Library {
                has_staticlib: cargo_target.kind.iter().any(|k| k == "staticlib"),
                has_cdylib: cargo_target.kind.iter().any(|k| k == "cdylib"),
            }
        } else if cargo_target.kind.iter().any(|k| k == "bin") {
            CargoTargetType::Executable
        } else {
            return None;
        };

        Some(Self {
            cargo_package: cargo_package.clone(),
            cargo_target,
            target_type,
        })
    }

    fn lib_name(&self) -> String {
        self.cargo_target.name.replace("-", "_")
    }

    fn static_lib_name(&self, platform: &super::platform::Platform) -> String {
        if platform.is_msvc() {
            format!("{}.lib", self.lib_name())
        } else {
            format!("lib{}.a", self.lib_name())
        }
    }

    fn dynamic_lib_name(&self, platform: &super::platform::Platform) -> String {
        if platform.is_windows() {
            format!("{}.dll", self.lib_name())
        } else if platform.is_macos() {
            format!("lib{}.dylib", self.lib_name())
        } else {
            format!("lib{}.so", self.lib_name())
        }
    }

    fn implib_name(&self, platform: &super::platform::Platform) -> String {
        let prefix = if platform.is_msvc() {
            ""
        } else if platform.is_windows_gnu() {
            "lib"
        } else {
            ""
        };

        let suffix = if platform.is_msvc() {
            "lib"
        } else if platform.is_windows_gnu() {
            "a"
        } else {
            ""
        };

        format!("{}{}.dll.{}", prefix, self.lib_name(), suffix)
    }

    fn pdb_name(&self) -> String {
        format!("{}.pdb", self.lib_name())
    }

    fn exe_name(&self, platform: &super::platform::Platform) -> String {
        if platform.is_windows() {
            format!("{}.exe", self.cargo_target.name)
        } else {
            self.cargo_target.name.clone()
        }
    }

    pub fn emit_cmake_target(
        &self,
        out_file: &mut dyn std::io::Write,
        platform: &super::platform::Platform,
        _cargo_version: &semver::Version,
        cargo_profile: Option<&str>,
        include_platform_libs: bool,
    ) -> Result<(), Box<dyn Error>> {
        // This bit aggregates the byproducts of "cargo build", which is needed for generators like Ninja.
        let mut byproducts = vec![];
        match self.target_type {
            CargoTargetType::Library {
                has_staticlib,
                has_cdylib,
            } => {
                if has_staticlib {
                    byproducts.push(self.static_lib_name(platform));
                }

                if has_cdylib {
                    byproducts.push(self.dynamic_lib_name(platform));

                    if platform.is_windows() {
                        byproducts.push(self.implib_name(platform));
                    }
                }
            }
            CargoTargetType::Executable => {
                byproducts.push(self.exe_name(platform));
            }
        }

        // Only shared libraries and executables have PDBs on Windows
        // I don't know why PDBs aren't generated for staticlibs...
        let has_pdb = platform.is_windows()
            && platform.is_msvc()
            && match self.target_type {
                CargoTargetType::Library {
                    has_cdylib: true, ..
                }
                | CargoTargetType::Executable => true,
                _ => false,
            };

        if has_pdb {
            byproducts.push(self.pdb_name());
        }

        let cargo_build_profile_option = if let Some(profile) = cargo_profile {
            format!("PROFILE {}", profile)
        } else {
            String::default()
        };

        match self.target_type {
            CargoTargetType::Library {
                has_staticlib,
                has_cdylib,
            } => {
                assert!(has_staticlib || has_cdylib);

                if has_staticlib {
                    writeln!(
                        out_file,
                        "add_library({0}-static STATIC IMPORTED GLOBAL)\n\
                         add_dependencies({0}-static cargo-build_{0})",
                        self.cargo_target.name
                    )?;

                    if include_platform_libs {
                        if !platform.libs.is_empty() {
                            writeln!(
                                out_file,
                                "set_property(TARGET {0}-static PROPERTY INTERFACE_LINK_LIBRARIES \
                                 {1})",
                                self.cargo_target.name,
                                platform.libs.join(" ")
                            )?;
                        }

                        if !platform.libs_debug.is_empty() {
                            writeln!(
                                out_file,
                                "set_property(TARGET {0}-static PROPERTY \
                                 INTERFACE_LINK_LIBRARIES_DEBUG {1})",
                                self.cargo_target.name,
                                platform.libs_debug.join(" ")
                            )?;
                        }

                        if !platform.libs_release.is_empty() {
                            for config in &["RELEASE", "MINSIZEREL", "RELWITHDEBINFO"] {
                                writeln!(
                                    out_file,
                                    "set_property(TARGET {0}-static PROPERTY \
                                     INTERFACE_LINK_LIBRARIES_{2} {1})",
                                    self.cargo_target.name,
                                    platform.libs_release.join(" "),
                                    config
                                )?;
                            }
                        }
                    }
                }

                if has_cdylib {
                    writeln!(
                        out_file,
                        "add_library({0}-shared SHARED IMPORTED GLOBAL)\n\
                         add_dependencies({0}-shared cargo-build_{0})",
                        self.cargo_target.name
                    )?;
                }

                writeln!(
                    out_file,
                    "add_library({0} INTERFACE)",
                    self.cargo_target.name
                )?;

                if has_cdylib && has_staticlib {
                    writeln!(
                        out_file,
                        "\
if (BUILD_SHARED_LIBS)
    target_link_libraries({0} INTERFACE {0}-shared)
else()
    target_link_libraries({0} INTERFACE {0}-static)
endif()",
                        self.cargo_target.name
                    )?;
                } else if has_cdylib {
                    writeln!(
                        out_file,
                        "target_link_libraries({0} INTERFACE {0}-shared)",
                        self.cargo_target.name
                    )?;
                } else {
                    writeln!(
                        out_file,
                        "target_link_libraries({0} INTERFACE {0}-static)",
                        self.cargo_target.name
                    )?;
                }
            }
            CargoTargetType::Executable => {
                writeln!(
                    out_file,
                    "add_executable({0} IMPORTED GLOBAL)\n\
                     add_dependencies({0} cargo-build_{0})",
                    self.cargo_target.name
                )?;
            }
        }

        let target_kind = match self.target_type {
            CargoTargetType::Executable => "bin",
            CargoTargetType::Library{ has_staticlib: _, has_cdylib: _ }  => "lib",
        };

        writeln!(
            out_file,
            "\
_add_cargo_build(
    PACKAGE {0}
    TARGET {1}
    MANIFEST_PATH \"{2}\"
    BYPRODUCTS {3}
    {4}
    TARGET_KIND {5}
)
",
            self.cargo_package.name,
            self.cargo_target.name,
            self.cargo_package.manifest_path.as_str().replace("\\", "/"),
            byproducts.join(" "),
            cargo_build_profile_option,
            target_kind
        )?;

        writeln!(out_file)?;

        Ok(())
    }

    pub(crate) fn emit_cmake_config_info(
        &self,
        out_file: &mut dyn std::io::Write,
        platform: &super::platform::Platform,
        config_type: &ConfigType,
    ) -> Result<(), Box<dyn Error>> {
        let multi_config_args = match config_type {
            ConfigType::SingleConfig(_) => "".into(),
            ConfigType::MultiConfig(configs) => configs.join(" "),
        };

        match self.target_type {
            CargoTargetType::Library {
                has_staticlib,
                has_cdylib,
            } => {
                if has_staticlib {
                    writeln!(
                        out_file,
                        "corrosion_internal_set_imported_location({0}-static {1} {2} {3})",
                        self.cargo_target.name,
                        "IMPORTED_LOCATION",
                        self.static_lib_name(platform),
                        multi_config_args
                    )?;
                }

                if has_cdylib {
                    writeln!(
                        out_file,
                        "corrosion_internal_set_imported_location({0}-shared {1} {2} {3})",
                        self.cargo_target.name,
                        "IMPORTED_LOCATION",
                        self.dynamic_lib_name(platform),
                        multi_config_args
                    )?;

                    if platform.is_windows() {
                        writeln!(
                            out_file,
                            "corrosion_internal_set_imported_location({0}-shared {1} {2} {3})",
                            self.cargo_target.name,
                            "IMPORTED_IMPLIB",
                            self.implib_name(platform),
                            multi_config_args
                        )?;
                    }
                }
            }
            CargoTargetType::Executable => {
                let exe_file = if platform.is_windows() {
                    format!("{}.exe", self.cargo_target.name)
                } else {
                    self.cargo_target.name.clone()
                };

                writeln!(
                    out_file,
                    "corrosion_internal_set_imported_location({0} {1} {2} {3})",
                    self.cargo_target.name, "IMPORTED_LOCATION", exe_file, multi_config_args
                )?;
            }
        }

        Ok(())
    }
}
