# 0.2.1 (2022-05-07)

## Fixes

- Fix missing variables provided by corrosion, when corrosion is used as a subdirectory ([181](https://github.com/corrosion-rs/corrosion/pull/181)):
  Public [Variables](https://github.com/corrosion-rs/corrosion#information-provided-by-corrosion) set
  by Corrosion were not visible when using Corrosion as a subdirectory, due to the wrong scope of 
  the variables. This was fixed by promoting the respective variables to Cache variables.

# 0.2.0 (2022-05-05)

## Breaking changes

- Removed the integrator build script ([#156](https://github.com/corrosion-rs/corrosion/pull/156)).
  The build script provided by corrosion (for rust code that links in foreign code) is no longer necessary,
  so users can just remove the dependency.

## Deprecations

- Direct usage of the following target properties has been deprecated. The names of the custom properties are
  no longer considered part of the public API and may change in the future. Instead, please use the functions
  provided by corrosion. Internally different property names are used depending on the CMake version.
  - `CORROSION_FEATURES`, `CORROSION_ALL_FEATURES`, `CORROSION_NO_DEFAULT_FEATURES`. Instead please use
    `corrosion_set_features()`. See the updated Readme for details.
  - `CORROSION_ENVIRONMENT_VARIABLES`. Please use `corrosion_set_env_vars()` instead.
  - `CORROSION_USE_HOST_BUILD`. Please use `corrosion_set_hostbuild()` instead.
- The Minimum CMake version will likely be increased for the next major release. At the very least we want to drop 
  support for CMake 3.12, but requiring CMake 3.16 or even 3.18 is also on the table. If you are using a CMake version
  that would be no longer supported by corrosion, please comment on issue
  [#168](https://github.com/corrosion-rs/corrosion/issues/168), so that we can gauge the number of affected users.

## New features

- Add `NO_STD` option to `corrosion_import_crate` ([#154](https://github.com/corrosion-rs/corrosion/pull/154)).
- Remove the requirement of building the Rust based generator crate for CMake >= 3.19. This makes using corrosion as
  a subdirectory as fast as the installed version (since everything is done in CMake). 
  ([#131](https://github.com/corrosion-rs/corrosion/pull/131), [#161](https://github.com/corrosion-rs/corrosion/pull/161))
  If you do choose to install Corrosion, then by default the old Generator is still compiled and installed, so you can
  fall back to using it in case you use multiple cmake versions on the same machine for different projects.

## Fixes

- Fix Corrosion on MacOS 11 and 12 ([#167](https://github.com/corrosion-rs/corrosion/pull/167) and
  [#164](https://github.com/corrosion-rs/corrosion/pull/164)).
- Improve robustness of parsing the LLVM version (exported in `Rust_LLVM_VERSION`). It now also works for
  Rust versions, where the LLVM version is reported as `MAJOR.MINOR`. ([#148](https://github.com/corrosion-rs/corrosion/pull/148))
- Fix a bug which occurred when Corrosion was added multiple times via `add_subdirectory()` 
  ([#143](https://github.com/corrosion-rs/corrosion/pull/143)).
- Set `CC_<target_triple_undercore>` and `CXX_<target_triple_undercore>` environment variables for the invocation of 
  `cargo build` to the compilers selected by CMake  (if any) 
  ([#138](https://github.com/corrosion-rs/corrosion/pull/138) and [#161](https://github.com/corrosion-rs/corrosion/pull/161)).
  This should ensure that C dependencies built in cargo buildscripts via [cc-rs](https://github.com/alexcrichton/cc-rs)
  use the same compiler as CMake built dependencies. Users can override the compiler by specifying the higher 
  priority environment variable variants with dashes instead of underscores (See cc-rs documentation for details).
- Fix Ninja-Multiconfig Generator support for CMake versions >= 3.20. Previous CMake versions are missing a feature,
  which prevents us from supporting the Ninja-Multiconfig generator. ([#137](https://github.com/corrosion-rs/corrosion/pull/137))


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
