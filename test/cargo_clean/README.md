# Cargo Clean Test

Verifies that `cargo-clean_${target_name}` targets delete build artifacts from Corrosion's custom target directory.

## What's Being Tested

Corrosion builds Rust crates in a custom target directory (`${CMAKE_BINARY_DIR}/cargo/build/`) instead of Cargo's default location (`${CMAKE_CURRENT_SOURCE_DIR}/target/`). The `cargo-clean_${target_name}` target must pass `--target-dir` to clean artifacts from the correct location.

## How It Works

1. Builds a Rust static library
2. Verifies the artifact exists under `${BUILD_DIR}/cargo/build/`
3. Allows `build_fixture_cargo_clean` to run the `cargo-clean` target
4. Confirms the artifacts were removed

Without `--target-dir`, the clean operation would fail to remove artifacts from Corrosion's custom target directory.
