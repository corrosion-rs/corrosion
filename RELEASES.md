# 0.1.0 (2022-02-01)

This is the first release of corrosion after it was moved to the new corrosion-rs organization.
Since there are no previous releases, this is not a complete changelog but only lists changes since
September 2021.

## New features
- [Add --profile support for rust >= 1.57](https://github.com/corrosion-rs/corrosion/pull/130):
  Allows users to specify a custom cargo profile with 
  `corrosion_import_crate(... PROFILE <profilename>)`.
- [Add support for specifying per-target Rustflags](https://github.com/corrosion-rs/corrosion/pull/127):
  Rustflags can be added via `corrosion_add_target_rustflags(<target_name> [rustflags1...])`
- [Add `Rust_IS_NIGHTLY` and `Rust_LLVM_VERSION` variables](https://github.com/corrosion-rs/corrosion/pull/123):
  This may be useful if you want to conditionally enabled features when using a nightly toolchain
  or a specific LLVM Version.
- [Let `FindRust` fail gracefully if rustc is not found](https://github.com/corrosion-rs/corrosion/pull/111):
  This allows using `FindRust` in a more general setting (without corrosion).
- [Add support for cargo feature selection](https://github.com/corrosion-rs/corrosion/pull/108):
  See the [README](https://github.com/corrosion-rs/corrosion#cargo-feature-selection) for details on
  how to select features.


## Fixes
- [Fix the cargo-clean target](https://github.com/corrosion-rs/corrosion/pull/129)
- [Fix #84: CorrosionConfig.cmake looks in wrong place for Corrosion::Generator when CMAKE_INSTALL_LIBEXEC is an absolute path](https://github.com/corrosion-rs/corrosion/pull/122/commits/6f29af3ac53917ca2e0638378371e715a18a532d)
- [Fix #116: (Option CORROSION_INSTALL_EXECUTABLE not working)](https://github.com/corrosion-rs/corrosion/commit/97d44018fac1b1a2a7c095288c628f5bbd9b3184)
- [Fix building on Windows with rust >= 1.57](https://github.com/corrosion-rs/corrosion/pull/120)

## Known issues:
- Corrosion is currently not working on macos-11 and newer. See issue [#104](https://github.com/corrosion-rs/corrosion/issues/104).
  Contributions are welcome.
