extern crate cargo_metadata;
extern crate clap;

use clap::{App, Arg};

use std::fs::File;
use std::io::{stdout, Write};
use std::path::Path;
use std::process::exit;

const MANIFEST_PATH: &str = "manifest-path";
const OUT_FILE: &str = "out-file";

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

    let mut out_file: Box<Write> = if let Some(path) = matches.value_of(OUT_FILE) {
        let file = File::create(Path::new(path)).expect("Unable to open out-file!");
        Box::new(file)
    } else {
        Box::new(stdout())
    };

    writeln!(out_file,
"\
cmake_minimum_required (VERSION 3.0)
find_package(Cargo REQUIRED)


").unwrap();

    // writeln!(out_file)

    // for package in metadata.packages {
    //     write!(out_file, "{:?}", package).expect("File I/O error!");
    // }
}
