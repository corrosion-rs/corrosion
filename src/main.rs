extern crate cargo_metadata;
extern crate clap;

use clap::{App, Arg, SubCommand};

use std::fs::{create_dir_all, File};
use std::io::{stdout, Write};
use std::path::Path;
use std::process::exit;

const MANIFEST_PATH: &str = "manifest-path";
const OUT_FILE: &str = "out-file";
const PRINT_ROOT: &str = "print-root";

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
        .arg(
            Arg::with_name(OUT_FILE)
                .short("o")
                .long("out-file")
                .help("Output CMake file name. Defaults to stdout.")
                .takes_value(true),
        )
        .subcommand(
            SubCommand::with_name(PRINT_ROOT)
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

    writeln!(out_file,
"\
cmake_minimum_required (VERSION 3.0)
find_package(Cargo REQUIRED)
").unwrap();

    for package in &metadata.packages {
        writeln!(out_file,
"\
add_cargo_build({} \"{}\")
",
        package.name, package.manifest_path.replace("\\", "\\\\")).unwrap();
    }
}
