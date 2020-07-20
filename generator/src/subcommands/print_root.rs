use clap::{App, SubCommand};

// Subcommand Name
pub const PRINT_ROOT: &str = "print-root";

pub fn subcommand() -> App<'static, 'static> {
    SubCommand::with_name(PRINT_ROOT)
}

pub fn invoke(metadata: &cargo_metadata::Metadata) -> Result<(), Box<dyn std::error::Error>> {
    println!("{}", metadata.workspace_root.to_str().unwrap());

    std::process::exit(0);
}
