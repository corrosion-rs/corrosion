## What does corrosion do?

The specifics of what corrosion does should be regarded as an implementation detail and not relied on
when writing user code. However, a basic understanding of what corrosion does may be helpful when investigating
issues.

### FindRust

Corrosion maintains a CMake module `FindRust` which is executed when Corrosion is loaded, i.e. at the time
of `find_package(corrosion)`, `FetchContent_MakeAvailable(corrosion)` or `add_subdirectory(corrosion)` depending
on the method used to include Corrosion.

`FindRust` will search for installed rust toolchains, respecting the options prefixed with `Rust_` documented in
the [Usage](usage.md#corrosion-options) chapter.
It will select _one_ Rust toolchain to be used for the compilation of Rust code. Toolchains managed by `rustup`
will be resolved and corrosion will always select a specific toolchain, not a `rustup` proxy.


### Importing Rust crates

Corrosion's main function is `corrosion_import_crate`, which internally will call `cargo metadata` to provide
structured information based on the `Cargo.toml` manifest.
Corrosion will then iterate over all workspace and/or package members and find all rust crates that are either
a static (`staticlib`) or shared (`cdylib`) library or a `bin` target and create CMake targets matching the
crate name. Additionally, a build target is created for each imported target, containing the required build
command to create the imported artifact. This build command can be influenced by various arguments to 
`corrosion_import_crate` as well as corrosion specific target properties which are documented int the  
[Usage](usage.md) chapter.
Corrosion adds the necessary dependencies and also copies the target artifacts out of the cargo build tree
to standard CMake locations, even respecting `OUTPUT_DIRECTORY` target properties if set.
