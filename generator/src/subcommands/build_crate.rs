use clap::{App, Arg, ArgMatches, SubCommand};
use std::{env, process};

// build-crate Subcommand
pub const BUILD_CRATE: &str = "build-crate";

// build-crate options
const RELEASE: &str = "release";
const PROFILE: &str = "profile";
const PACKAGE: &str = "package";
const TARGET: &str = "target";
const RUSTFLAGS: &str = "rustflags";

// build-crate features list
const FEATURES: &str = "features";
const ALL_FEATURES: &str = "all-features";
const NO_DEFAULT_FEATURES: &str = "no-default-features";

pub fn subcommand() -> App<'static, 'static> {
    SubCommand::with_name(BUILD_CRATE)
        .arg(Arg::with_name(RELEASE).long("release"))
        .arg(
            Arg::with_name(PROFILE)
                .long("profile")
                .takes_value(true)
                .help("The cargo profile to build with, e.g. 'dev' or 'release'")
                .conflicts_with(RELEASE)
        )
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
        .arg(Arg::with_name(RUSTFLAGS)
            .long(RUSTFLAGS)
            .value_name("RUSTFLAGS")
            .takes_value(true)
            .multiple(false)
            .help("The RUSTFLAGS to pass to rustc.")
        )
        .arg(
            Arg::with_name(FEATURES)
                .long("features")
                .value_name("features")
                .takes_value(true)
                .multiple(true)
                .require_delimiter(true)
                .help("Specifies which features of the crate to use"),
        )
        .arg(
            Arg::with_name(ALL_FEATURES)
            .long(ALL_FEATURES)
                .help("Specifies that all features of the crate are to be activated"),
        )
        .arg(
            Arg::with_name(NO_DEFAULT_FEATURES)
            .long(NO_DEFAULT_FEATURES)
                .help("Specifies that the default features of the crate are to be disabled"),
        )
}

pub fn invoke(
    args: &crate::GeneratorSharedArgs,
    matches: &ArgMatches,
) -> Result<(), Box<dyn std::error::Error>> {
    let target = matches.value_of(TARGET).unwrap();
    let features = matches
        .values_of(FEATURES)
        .map_or(Vec::new(), |c| c.collect())
        .join(" ");
    let package_name = matches.value_of(PACKAGE).unwrap();

    let mut cargo = process::Command::new(&args.cargo_executable);

    cargo.args(&[
        "build",
        "--target",
        target,
        "--features",
        &features,
        "--package",
        package_name,
        "--manifest-path",
        args.manifest_path.to_str().unwrap(),
    ]);

    if args.verbose {
        cargo.arg("--verbose");
    }

    if matches.is_present(ALL_FEATURES) {
        cargo.arg("--all-features");
    }

    if matches.is_present(NO_DEFAULT_FEATURES) {
        cargo.arg("--no-default-features");
    }

    if matches.is_present(RELEASE) {
        cargo.arg("--release");
    }

    if matches.is_present(PROFILE) {
        cargo.arg("--profile");
        cargo.arg(matches.value_of(PROFILE).unwrap());
    }

    let mut rustflags = matches.value_of(RUSTFLAGS).unwrap_or_default().to_owned();

    let languages: Vec<String> = env::var("CORROSION_LINKER_LANGUAGES")
        .unwrap_or("".to_string())
        .trim()
        .split(" ")
        .map(Into::into)
        .collect();

    if !languages.is_empty() {
        rustflags += " -Cdefault-linker-libraries=yes";

        // This loop gets the highest preference link language to use for the linker
        let mut highest_preference: Option<(Option<i32>, &str)> = None;
        for language in &languages {
            highest_preference = Some(
                if let Ok(preference) =
                    env::var(&format!("CORROSION_{}_LINKER_PREFERENCE", language))
                {
                    let preference = preference
                        .parse()
                        .expect("Corrosion internal error: PREFERENCE wrong format");
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
            if let Ok(compiler) = env::var(&format!("CORROSION_{}_COMPILER", language)) {
                let linker_arg = format!(
                    "CARGO_TARGET_{}_LINKER",
                    target.replace("-", "_").to_uppercase()
                );

                cargo.env(linker_arg, compiler);
            }

            if let Ok(target) = env::var(format!("CORROSION_{}_COMPILER_TARGET", language)) {
                rustflags += format!(" -Clink-args=--target={}", target).as_str();
            }
        }

        let extra_link_args = env::var("CORROSION_LINK_ARGS").unwrap_or("".to_string());
        if !extra_link_args.is_empty() {
            rustflags += format!(" -Clink-args={}", extra_link_args).as_str();
        }

        let rustflags_trimmed = rustflags.trim();
        if args.verbose {
            println!("Rustflags for package {} are: `{}`", matches.value_of(PACKAGE).unwrap(), rustflags_trimmed);
        }
        cargo.env("RUSTFLAGS", rustflags_trimmed);
    }

    if args.verbose {
        println!("Corrosion: {:?}", cargo);
    }

    process::exit(if cargo.status()?.success() { 0 } else { 1 });
}
