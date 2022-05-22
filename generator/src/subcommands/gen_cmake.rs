use std::{
    fs::{create_dir_all, File},
    io::{stdout, Write},
    path::Path,
    rc::Rc,
};

use clap::{App, Arg, ArgMatches, SubCommand};
use platforms::Platform;
use semver::Version;

mod platform;
mod target;

// Command name
pub const GEN_CMAKE: &str = "gen-cmake";

// Options
const OUT_FILE: &str = "out-file";
const CONFIGURATION_TYPE: &str = "configuration-type";
const CONFIGURATION_TYPES: &str = "configuration-types";
const CONFIGURATION_ROOT: &str = "configuration-root";
const TARGET: &str = "target";
const CARGO_VERSION: &str = "cargo-version";
const PROFILE: &str = "profile";
const CRATES: &str = "crates";
const NO_DEFAULT_LIBRARIES: &str = "no-default-libraries";

pub fn subcommand() -> App<'static, 'static> {
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
            Arg::with_name(CRATES)
                .long("crates")
                .value_name("crates")
                .takes_value(true)
                .multiple(true)
                .require_delimiter(true)
                .help("Specifies which crates of the workspace to import"),
        )
        .arg(
            Arg::with_name(TARGET)
                .long("target")
                .value_name("TRIPLE")
                .required(true)
                .help("The build target being used."),
        )
        .arg(
            Arg::with_name(CARGO_VERSION)
                .long(CARGO_VERSION)
                .value_name("VERSION")
                .required(true)
                .help("Version of target cargo"),
        )
        .arg(
            Arg::with_name(PROFILE)
                .long(PROFILE)
                .value_name("PROFILE")
                .required(false)
                .help("Custom cargo profile to select."),
        )
        .arg(
            Arg::with_name(OUT_FILE)
                .short("o")
                .long("out-file")
                .value_name("FILE")
                .help("Output CMake file name. Defaults to stdout."),
        )
        .arg(
            Arg::with_name(NO_DEFAULT_LIBRARIES)
                .long(NO_DEFAULT_LIBRARIES)
                .help(
                    "Do not include libraries usually included by default. Use for no-std crates",
                ),
        )
}

pub fn invoke(
    args: &crate::GeneratorSharedArgs,
    matches: &ArgMatches,
) -> Result<(), Box<dyn std::error::Error>> {
    let cargo_version = Version::parse(matches.value_of(CARGO_VERSION).unwrap())
        .expect("cargo-version must be a semver-compatible version!");

    let cargo_target = matches.value_of(TARGET).and_then(Platform::find).cloned();

    if cargo_target.is_none() {
        println!("WARNING: The target was not recognized.");
    }
    if matches.value_of(PROFILE).is_some() && cargo_version < Version::new(1, 57, 0) {
        panic!("Selecting a custom cargo profile requires rust/cargo >= 1.57.0");
    }

    let cargo_platform = platform::Platform::from_rust_version_target(&cargo_version, cargo_target);

    let mut out_file: Box<dyn Write> = if let Some(path) = matches.value_of(OUT_FILE) {
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
cmake_minimum_required(VERSION 3.15)
"
    )?;

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

    let crates = matches
        .values_of(CRATES)
        .map_or(Vec::new(), |c| c.collect());
    let targets: Vec<_> = args
        .metadata
        .packages
        .iter()
        .filter(|p| {
            args.metadata.workspace_members.contains(&p.id)
                && (crates.is_empty() || crates.contains(&p.name.as_str()))
        })
        .cloned()
        .map(Rc::new)
        .flat_map(|package| {
            let package2 = package.clone();
            package
                .targets
                .clone()
                .into_iter()
                .filter_map(move |t| target::CargoTarget::from_metadata(package2.clone(), t))
        })
        .collect();

    let cargo_profile = matches.value_of(PROFILE);

    for target in &targets {
        target
            .emit_cmake_target(
                &mut out_file,
                &cargo_platform,
                &cargo_version,
                cargo_profile,
                !matches.is_present(NO_DEFAULT_LIBRARIES),
            )
            .unwrap();
    }

    writeln!(out_file)?;

    let metadata_manifest_path = Path::new(&args.metadata.workspace_root).join("Cargo.toml");

    for (config_type, config_folder) in config_folders {
        let current_dir = std::env::current_dir().expect("Could not get current directory!");
        std::env::set_current_dir(config_folder)
            .expect("Could not change directory to the Config directory!");

        let mut local_metadata_cmd = cargo_metadata::MetadataCommand::new();
        local_metadata_cmd.manifest_path(Path::new(&metadata_manifest_path));

        for target in &targets {
            target.emit_cmake_config_info(
                &mut out_file,
                &cargo_platform,
                matches.is_present(CONFIGURATION_TYPES),
                &config_type,
            )?;
        }

        std::env::set_current_dir(current_dir)
            .expect("Could not return to the build root directory!")
    }

    std::process::exit(0);
}
