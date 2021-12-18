use platforms::target::{Env, OS};
use semver::Version;

pub struct Platform {
    pub libs: Vec<String>,
    pub libs_debug: Vec<String>,
    pub libs_release: Vec<String>,
    pub cargo_target: Option<platforms::Platform>,
}

impl Platform {
    pub fn from_rust_version_target(
        version: &Version,
        cargo_target: Option<platforms::Platform>,
    ) -> Self {
        let (libs, libs_debug, libs_release) = if let Some(ref cargo_target) = cargo_target {
            match cargo_target.target_os {
                OS::Windows => {
                    let mut libs = vec![
                        "advapi32".to_string(),
                        "userenv".to_string(),
                        "ws2_32".to_string(),
                    ];

                    let mut libs_debug = vec![];
                    let mut libs_release = vec![];

                    match cargo_target.target_env {
                        Some(Env::Msvc) => {
                            libs_debug.extend_from_slice(&["msvcrtd".to_string()]);
                            libs_release.extend_from_slice(&["msvcrt".to_string()]);
                        }
                        Some(Env::Gnu) => {
                            libs.extend_from_slice(&["gcc_eh".to_string(), "pthread".to_string()]);
                        }
                        // not sure why we need an exhaustive match here
                        _ => {}
                    }

                    if version < &Version::parse("1.33.0").unwrap() {
                        libs.extend_from_slice(&["shell32".to_string(), "kernel32".to_string()]);
                    }

                    if version >= &Version::parse("1.57.0").unwrap() {
                        libs.extend_from_slice(&["bcrypt".to_string()]);
                    }

                    (libs, libs_debug, libs_release)
                }
                OS::MacOS => (
                    vec![
                        "System".to_string(),
                        "resolv".to_string(),
                        "c".to_string(),
                        "m".to_string(),
                    ],
                    vec![],
                    vec![],
                ),
                OS::Linux => (
                    vec![
                        "dl".to_string(),
                        "rt".to_string(),
                        "pthread".to_string(),
                        "gcc_s".to_string(),
                        "c".to_string(),
                        "m".to_string(),
                        "util".to_string(),
                    ],
                    vec![],
                    vec![],
                ),
                _ => (vec![], vec![], vec![]),
            }
        } else {
            (vec![], vec![], vec![])
        };

        Platform {
            libs,
            libs_debug,
            libs_release,
            cargo_target: cargo_target.clone(),
        }
    }

    pub fn is_windows(&self) -> bool {
        self.cargo_target
            .as_ref()
            .map_or(false, |t| t.target_os == OS::Windows)
    }

    pub fn is_msvc(&self) -> bool {
        self.is_windows()
            && self
                .cargo_target
                .as_ref()
                .map_or(false, |t| t.target_env == Some(Env::Msvc))
    }

    pub fn is_windows_gnu(&self) -> bool {
        self.is_windows()
            && self
                .cargo_target
                .as_ref()
                .map_or(false, |t| t.target_env == Some(Env::Gnu))
    }

    pub fn is_macos(&self) -> bool {
        self.cargo_target
            .as_ref()
            .map_or(false, |t| t.target_os == OS::MacOS)
    }
}
