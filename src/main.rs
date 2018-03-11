extern crate cargo_metadata;
extern crate clap;

use clap::{App, Arg, SubCommand};

use std::fs::{create_dir_all, File};
use std::io::{stdout, Write};
use std::path::Path;
use std::process::exit;

const MANIFEST_PATH: &str = "manifest-path";
const TARGET_DIRECTORY: &str = "target-directory";
const OUT_FILE: &str = "out-file";

const PRINT_ROOT: &str = "print-root";
const GEN_CMAKE: &str = "gen-cmake";

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
                    Arg::with_name(TARGET_DIRECTORY)
                        .long("target-directory")
                        .value_name("DIRECTORY")
                        .help("Specifies the directory where build artifacts are located")
                        .takes_value(true)
                        .required(true),
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

    let target_directory = matches.value_of(TARGET_DIRECTORY).unwrap();

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
            "\
             add_cargo_build(cargo_{} \"{}\")",
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
                "\
                 add_dependencies(cargo_{} cargo_{})",
                package.name, dependency.name
            ).unwrap();
        }
    }

    writeln!(out_file).unwrap();

    // Output staticlib information
    for package in &metadata.packages {
        for staticlib in package
            .targets
            .iter()
            .filter(|t| t.kind.iter().any(|k| k == "staticlib"))
        {
            writeln!(out_file, "add_library({} STATIC IMPORTED)", staticlib.name).unwrap();

            writeln!(
                out_file,
                "\
if (WIN32)
    set_property(TARGET {} PROPERTY IMPORTED_LOCATION {}/debug/{}.lib)
    set_property(TARGET {} PROPERTY IMPORTED_LOCATION_DEBUG {}/debug/{}.lib)
else()
    set_property(TARGET {} PROPERTY IMPORTED_LOCATION {}/debug/lib{}.a)
    set_property(TARGET {} PROPERTY IMPORTED_LOCATION_DEBUG {}/debug/lib{}.a)
endif()",
                // WIN32 set_property
                staticlib.name,
                target_directory.replace("\\", "\\\\"),
                staticlib.name.replace("-", "_"),
                // WIN32 set_property
                staticlib.name,
                target_directory.replace("\\", "\\\\"),
                staticlib.name.replace("-", "_"),
                // set_property
                staticlib.name,
                target_directory.replace("\\", "\\\\"),
                staticlib.name.replace("-", "_"),
                // set_property
                staticlib.name,
                target_directory.replace("\\", "\\\\"),
                staticlib.name.replace("-", "_"),
            ).unwrap();

            for config in &["Release", "MinSizeRel", "RelWithDebInfo"] {
                writeln!(
                    out_file,
                    "\
if (WIN32)
    set_property(TARGET {} PROPERTY IMPORTED_LOCATION_{} {}/release/{}.lib)
else()
    set_property(TARGET {} PROPERTY IMPORTED_LOCATION_{} {}/release/lib{}.a)
endif()",
                    // WIN32 set_property
                    staticlib.name,
                    config.to_uppercase(),
                    target_directory.replace("\\", "\\\\"),
                    staticlib.name.replace("-", "_"),
                    // set_property
                    staticlib.name,
                    config.to_uppercase(),
                    target_directory.replace("\\", "\\\\"),
                    staticlib.name.replace("-", "_"),
                ).unwrap();
            }

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
    set_property(TARGET {} PROPERTY INTERFACE_LINK_LIBRARIES advapi32 kernel32 shell32 userenv ws2_32)
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
}
