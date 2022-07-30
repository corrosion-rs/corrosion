use clap::{SubCommand, Command};

// Subcommand Name
pub const PRINT_ROOT: &str = "print-root";

pub fn subcommand() -> Command<'static> {
    SubCommand::with_name(PRINT_ROOT)
}

pub fn invoke(args: &crate::GeneratorSharedArgs) -> Result<(), Box<dyn std::error::Error>> {
    println!("{}", args.metadata.workspace_root);

    std::process::exit(0);
}
