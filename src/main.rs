extern crate cargo_metadata;
extern crate clap;

use clap::{App, Arg, SubCommand};

use std::fs::{create_dir_all, File};
use std::io::{stdout, Write};
use std::path::Path;
use std::process::exit;

const MANIFEST_PATH: &str = "manifest-path";
const OUT_FILE: &str = "out-file";
const CONFIGURATION_TYPE: &str = "configuration-type";
const CONFIGURATION_TYPES: &str = "configuration-types";
const CONFIGURATION_ROOT: &str = "configuration-root";
const TARGET: &str = "target";

const PRINT_ROOT: &str = "print-root";
const GEN_CMAKE: &str = "gen-cmake";

fn config_type_target_folder(config_type: Option<&str>) -> &'static str {
    match config_type {
        Some("Debug") | None => "debug",
        Some("Release") | Some("RelWithDebInfo") | Some("MinSizeRel") => "release",
        Some(config_type) => panic!("Unknown config_type {}!", config_type),
    }
}

fn main() {
    let matches = App::new("CMake Generator for Cargo")
        .version("0.1")
        .author("Andrew Gaspar <andrew.gaspar@outlook.com>")
        .about("Generates CMake files for Cargo projects")
        .arg(
            Arg::with_name(MANIFEST_PATH)
                .long("manifest-path")
                .value_name("Cargo.toml")
                .help("Specifies the target Cargo project")
                .takes_value(true),
        )
        .subcommand(SubCommand::with_name(PRINT_ROOT))
        .subcommand(
            SubCommand::with_name(GEN_CMAKE)
                .arg(
                    Arg::with_name(CONFIGURATION_ROOT)
                        .long("configuration-root")
                        .value_name("DIRECTORY")
                        .takes_value(true)
                        .help(
                            "Specifies a root directory for configuration folders. E.g. Win32 \
                             in VS Generator.",
                        ),
                )
                .arg(
                    Arg::with_name(CONFIGURATION_TYPE)
                        .long("configuration-type")
                        .value_name("type")
                        .takes_value(true)
                        .conflicts_with(CONFIGURATION_TYPES)
                        .help(
                            "Specifies the configuration type to use in a single configuration \
                             environment.",
                        ),
                )
                .arg(
                    Arg::with_name(CONFIGURATION_TYPES)
                        .long("configuration-types")
                        .value_name("types")
                        .takes_value(true)
                        .multiple(true)
                        .require_delimiter(true)
                        .conflicts_with(CONFIGURATION_TYPE)
                        .help(
                            "Specifies the configuration types to use in a multi-configuration \
                             environment.",
                        ),
                )
                .arg(
                    Arg::with_name(TARGET)
                        .long("target")
                        .value_name("triple")
                        .takes_value(true)
                        .help("The build target being used."),
                )
                .arg(
                    Arg::with_name(OUT_FILE)
                        .short("o")
                        .long("out-file")
                        .value_name("FILE")
                        .help("Output CMake file name. Defaults to stdout.")
                        .takes_value(true),
                ),
        )
        .get_matches();

    let metadata = if let Some(manifest_path) = matches.value_of(MANIFEST_PATH) {
        match cargo_metadata::metadata(Some(Path::new(manifest_path))) {
            Ok(metadata) => metadata,
            Err(_) => {
                eprintln!("{} is not a valid crate!", manifest_path);
                exit(1);
            }
        }
    } else {
        match cargo_metadata::metadata(None) {
            Ok(metadata) => metadata,
            Err(_) => {
                eprintln!("No crate found in the pwd.");
                exit(1)
            }
        }
    };

    if let Some(_) = matches.subcommand_matches(PRINT_ROOT) {
        println!("{}", metadata.workspace_root);
        std::process::exit(0);
    }

    let matches = matches.subcommand_matches(GEN_CMAKE).unwrap();

    let mut out_file: Box<Write> = if let Some(path) = matches.value_of(OUT_FILE) {
        let path = Path::new(path);
        if let Some(parent) = path.parent() {
            create_dir_all(parent).expect("Failed to create directory!");
        }
        let file = File::create(path).expect("Unable to open out-file!");
        Box::new(file)
    } else {
        Box::new(stdout())
    };

    writeln!(
        out_file,
        "\
cmake_minimum_required (VERSION 3.0)
find_package(Cargo REQUIRED)
"
    ).unwrap();

    // Print out all packages
    for package in &metadata.packages {
        writeln!(
            out_file,
            "add_cargo_build(cargo_{} \"{}\")",
            package.name,
            package.manifest_path.replace("\\", "\\\\")
        ).unwrap();
    }

    writeln!(out_file).unwrap();

    // Add dependencies to CMake DAG
    for package in metadata
        .packages
        .iter()
        .filter(|p| !p.dependencies.is_empty())
    {
        for dependency in &package.dependencies {
            writeln!(
                out_file,
                "add_dependencies(cargo_{} cargo_{})",
                package.name, dependency.name
            ).unwrap();
        }
    }

    writeln!(out_file).unwrap();

    let config_root = Path::new(matches.value_of(CONFIGURATION_ROOT).unwrap_or("."));

    let mut config_folders = Vec::new();
    if let Some(config_types) = matches.values_of(CONFIGURATION_TYPES) {
        for config_type in config_types {
            let config_folder = config_root.join(config_type);
            assert!(
                config_folder.join(".cargo/config").exists(),
                "Target config_folder '{}' must contain a '.cargo/config'.",
                config_folder.display()
            );
            config_folders.push((Some(config_type), config_folder));
        }
    } else {
        let config_type = matches.value_of(CONFIGURATION_TYPE);
        let config_folder = config_root;
        assert!(
            config_folder.join(".cargo/config").exists(),
            "Target config_folder '{}' must contain a '.cargo/config'.",
            config_folder.display()
        );
        config_folders.push((config_type, config_folder.to_path_buf()));
    }

    for package in &metadata.packages {
        for staticlib in package
            .targets
            .iter()
            .filter(|t| t.kind.iter().any(|k| k == "staticlib"))
        {
            writeln!(out_file, "add_library({} STATIC IMPORTED)", staticlib.name).unwrap();

            writeln!(
                out_file,
                "add_dependencies({} cargo_{})",
                // add_dependencies
                staticlib.name,
                package.name
            ).unwrap();

            writeln!(
                out_file,
                "\
if (WIN32)
    set_property(TARGET {} PROPERTY INTERFACE_LINK_LIBRARIES advapi32 kernel32 shell32 userenv \
        ws2_32)
    set_property(TARGET {} PROPERTY INTERFACE_LINK_LIBRARIES_DEBUG msvcrtd)
    set_property(TARGET {} PROPERTY INTERFACE_LINK_LIBRARIES_RELEASE msvcrt)
    set_property(TARGET {} PROPERTY INTERFACE_LINK_LIBRARIES_MINSIZEREL msvcrt)
    set_property(TARGET {} PROPERTY INTERFACE_LINK_LIBRARIES_RELWITHDEBINFO msvcrt)
else()
    set_property(TARGET {} PROPERTY INTERFACE_LINK_LIBRARIES dl rt pthread gcc_s c m util)
endif()",
                staticlib.name,
                staticlib.name,
                staticlib.name,
                staticlib.name,
                staticlib.name,
                staticlib.name,
            ).unwrap();
        }
    }

    let metadata_manifest_path = Path::new(&metadata.workspace_root).join("Cargo.toml");

    for (config_type, config_folder) in config_folders {
        let current_dir = std::env::current_dir().expect("Could not get current directory!");
        std::env::set_current_dir(config_folder)
            .expect("Could not change directory to the Config directory!");

        // Re-gathering the cargo metadata from here gets us a target_directory scoped to the
        // configuration type.
        let local_metadata = cargo_metadata::metadata(Some(&metadata_manifest_path))
            .expect("Could not open Crate specific metadata!");

        let imported_location = config_type.map_or("IMPORTED_LOCATION".to_owned(), |config_type| {
            format!("IMPORTED_LOCATION_{}", config_type.to_uppercase())
        });

        let build_path = Path::new(&local_metadata.target_directory)
            .join(matches.value_of(TARGET).unwrap_or(""))
            .join(config_type_target_folder(config_type));

        // Output staticlib information
        for package in &local_metadata.packages {
            for staticlib in package
                .targets
                .iter()
                .filter(|t| t.kind.iter().any(|k| k == "staticlib"))
            {
                let static_lib_name = staticlib.name.replace("-", "_");

                writeln!(
                    out_file,
                    "\
if (WIN32)
    set_property(TARGET {} PROPERTY {} {})
else()
    set_property(TARGET {} PROPERTY {} {})
endif()",
                    // WIN32 set_property
                    staticlib.name,
                    imported_location,
                    build_path
                        .join(format!("{}.lib", static_lib_name))
                        .to_str()
                        .unwrap()
                        .replace("\\", "\\\\"),
                    // set_property
                    staticlib.name,
                    imported_location,
                    build_path
                        .join(format!("lib{}.a", static_lib_name))
                        .to_str()
                        .unwrap()
                        .replace("\\", "\\\\"),
                ).unwrap();
            }
        }

        std::env::set_current_dir(current_dir)
            .expect("Could not return to the build root directory!")
    }
}
