# Cargo Configuration Discovery Test

This test verifies that `cargo` correctly discovers configuration files such as `.cargo/config.toml` and `toolchain.toml` in the source tree.

## What's Being Tested

Cargo discovers configuration files by searching the current working directory and its parent directories. Therefore, Corrosion must set the correct `WORKING_DIRECTORY` for all `cargo` invocations.

## How the Test Works

The test uses a `.cargo/config.toml` that defines a custom registry alias `my-registry`. A dependency in `Cargo.toml` references this alias via `registry = "my-registry"`.

If `cargo` does not find `.cargo/config.toml`, the `registry = "my-registry"` entry will cause an error during manifest parsing.
