use clap::{App, Arg};

mod subcommands {
    pub mod build_crate;
    pub mod gen_cmake;
    pub mod print_root;
}

use subcommands::*;

// common options
const MANIFEST_PATH: &str = "manifest-path";
const CARGO_EXECUTABLE: &str = "cargo-executable";

fn main() -> Result<(), Box<dyn std::error::Error>> {
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
            Arg::with_name(CARGO_EXECUTABLE)
                .long("cargo")
                .value_name("EXECUTABLE")
                .required(true)
                .help("Path to the cargo executable to use"),
        )
        .subcommand(print_root::subcommand())
        .subcommand(gen_cmake::subcommand())
        .subcommand(build_crate::subcommand())
        .get_matches();

    let mut cmd = cargo_metadata::MetadataCommand::new();

    let manifest_path = matches.value_of(MANIFEST_PATH).unwrap();
    cmd.manifest_path(manifest_path);

    let cargo_executable = matches.value_of(CARGO_EXECUTABLE).unwrap();
    cmd.cargo_path(cargo_executable);

    let metadata = cmd.exec().unwrap();

    match matches.subcommand() {
        (print_root::PRINT_ROOT, _) => print_root::invoke(&metadata)?,
        (build_crate::BUILD_CRATE, Some(matches)) => {
            build_crate::invoke(manifest_path, cargo_executable, matches)?
        }
        (gen_cmake::GEN_CMAKE, Some(matches)) => gen_cmake::invoke(&metadata, matches)?,
        _ => unreachable!(),
    };

    // We should never reach this statement
    std::process::exit(1);
}
