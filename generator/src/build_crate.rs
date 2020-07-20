use clap::{App, Arg, SubCommand};
use std::{env, process};

// build-crate Subcommand
pub const BUILD_CRATE: &str = "build-crate";

// build-crate options
const RELEASE: &str = "release";
const PACKAGE: &str = "package";
const TARGET: &str = "target";
const CARGO_EXECUTABLE: &str = "cargo-executable";

pub fn subcommand() -> App<'static, 'static> {
    SubCommand::with_name(BUILD_CRATE)
        .arg(Arg::with_name(RELEASE).long("release"))
        .arg(
            Arg::with_name(TARGET)
                .long("target")
                .value_name("TRIPLE")
                .required(true)
                .help("The target triple to build for"),
        )
        .arg(
            Arg::with_name(PACKAGE)
                .long("package")
                .value_name("PACKAGE")
                .required(true)
                .help("The name of the package being built with cargo"),
        )
        .arg(
            Arg::with_name(CARGO_EXECUTABLE)
                .long("cargo")
                .value_name("EXECUTABLE")
                .required(true)
                .help("Path to the cargo executable to use"),
        )
}

pub fn invoke(matches: &clap::ArgMatches) -> Result<(), Box<dyn std::error::Error>> {
    let manifest_path = matches.value_of(super::MANIFEST_PATH).unwrap();

    let matches = matches.subcommand().1.unwrap();

    let cargo_executable = matches.value_of(CARGO_EXECUTABLE).unwrap();
    let target = matches.value_of(TARGET).unwrap();

    let mut cargo = process::Command::new(cargo_executable);

    cargo.args(&[
        "build",
        "--target",
        target,
        "--package",
        matches.value_of(PACKAGE).unwrap(),
        "--manifest-path",
        manifest_path,
    ]);

    if matches.is_present(RELEASE) {
        cargo.arg("--release");
    }

    let languages: Vec<String> = env::var("CMAKECARGO_LINKER_LANGUAGES")
        .unwrap_or("".to_string())
        .split(";")
        .map(Into::into)
        .collect();

    if !languages.is_empty() {
        cargo.env("RUSTFLAGS", "-C default-linker-libraries=yes");

        // This loop gets the highest preference link language to use for the linker
        let mut highest_preference: Option<(Option<i32>, &str)> = None;
        for language in &languages {
            highest_preference = Some(
                if let Ok(preference) =
                    env::var(&format!("CMAKECARGO_{}_LINKER_PREFERENCE", language))
                {
                    let preference = preference
                        .parse()
                        .expect("cmake-cargo internal error: PREFERENCE wrong format");
                    match highest_preference {
                        Some((Some(current), language)) if current > preference => {
                            (Some(current), language)
                        }
                        _ => (Some(preference), &language),
                    }
                } else if let Some(p) = highest_preference {
                    p
                } else {
                    (None, &language)
                },
            );
        }

        // If a preferred compiler is selected, use it as the linker so that the correct standard, implicit libraries
        // are linked in.
        if let Some((_, language)) = highest_preference {
            if let Ok(compiler) = env::var(&format!("CMAKECARGO_{}_COMPILER", language)) {
                let linker_arg = format!(
                    "CARGO_TARGET_{}_LINKER",
                    target.replace("-", "_").to_uppercase()
                );

                cargo.env(linker_arg, compiler);
            }
        }
    }

    process::exit(if cargo.status()?.success() { 0 } else { 1 });
}
