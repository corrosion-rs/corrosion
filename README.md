# Corrosion
[![Build Status](https://github.com/AndrewGaspar/cmake-cargo/workflows/.github/workflows/test.yaml/badge.svg)](https://github.com/AndrewGaspar/cmake-cargo/actions?query=branch%3Amaster)

Corrosion, formerly known as cmake-cargo, is a tool for integrating Rust into an existing CMake
project. Corrosion is capable of importing executables, static libraries, and dynamic libraries
from a crate.

## Installation
There are two fundamental installation methods that are supported by Corrosion - installation as a
CMake package or using it as a subdirectory in an existing CMake project. Corrosion strongly
recommends installing the package, either via a package manager or manually using cmake's
installation facilities.

Installation will pre-build all of Corrosion's native tooling, meaning that configuring any project
which uses Corrosion is much faster. Using Corrosion as a subdirectory will result in the native
tooling for Corrosion to be re-built every time you configure a new build directory, which could
be a non-trivial cost for some projects. It also may result in issues with large, complex projects
with many git submodules that each individually may use Corrosion. This can unnecessarily exacerbate
diamond dependency problems that wouldn't otherwise occur using an externally installed Corrosion.

### Package Manager

Coming soon...

### CMake Install
After using a package manager, the next recommended way to use Corrosion is to install it as a
package using CMake. This means you won't need to rebuild Corrosion's tooling every time you
generate a new build directory. Installation also solves the diamond dependency problem that often
comes with git submodules or other primitive dependency solutions.

First, download and install Corrosion:
```bash
git clone https://github.com/AndrewGaspar/corrosion.git
# Optionally, specify -DCMAKE_INSTALL_PREFIX=<target-install-path>. You can install Corrosion anyway
cmake -Scorrosion -Bbuild -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
# This next step may require sudo or admin privileges if you're installing to a system location,
# which is the default.
cmake --install build --config Release
```

You'll want to ensure that the install directory is available in your `PATH` or `CMAKE_PREFIX_PATH`
environment variable. This is likely to already be the case by default on a Unix system, but on
Windows it will install to `C:\Program Files (x86)\Corrosion` by default, which will not be in your
`PATH` or `CMAKE_PREFIX_PATH` by default.

Once Corrosion is installed and you've ensured the package is avilable in your `PATH`, you
can use it from your own project like any other package from your CMakeLists.txt:
```cmake
find_package(Corrosion REQUIRED)
```

### FetchContent
If installation is difficult or not feasible in your environment, you can use the
[FetchContent](https://cmake.org/cmake/help/latest/module/FetchContent.html) module to include
Corrosion. This will download Corrosion and use it as if it were a subdirectory at configure time.

In your CMakeLists.txt:
```cmake
include(FetchContent)

FetchContent_Declare(
    Corrosion
    GIT_REPOSITORY https://github.com/AndrewGaspar/corrosion.git
    GIT_TAG origin/master # Optionally specify a version tag or branch here
)

FetchContent_MakeAvailable(Corrosion)
```

### Subdirectory
Corrosion can also be used directly as a subdirectory. This solution may work well for small
projects, but it's discouraged for large projects with many dependencies, especially those which may
themselves use Corrosion. Either copy the Corrosion library into your source tree, being sure to
preserve the `LICENSE` file, or add this repository as a git submodule:
```bash
git submodule add https://github.com/AndrewGaspar/corrosion.git
```

From there, using Corrosion is easy. In your CMakeLists.txt:
```cmake
add_subdirectory(path/to/corrosion)
```

## Usage
### Importing C-Style Libraries Written in Rust
Corrosion makes it completely trivial to import a crate into an existing CMake project. Consider
a project called [rust2cpp](test/rust2cpp) with the following file structure:
```
rust2cpp/
    rust/
        src/
            lib.rs
        Cargo.lock
        Cargo.toml
    CMakeLists.txt
    main.cpp
```

This project defines a simple Rust lib crate, like so, in [`rust2cpp/rust/Cargo.toml`](test/rust2cpp/rust/Cargo.toml):
```toml
[package]
name = "rust-lib"
version = "0.1.0"
authors = ["Andrew Gaspar <andrew.gaspar@outlook.com>"]
license = "MIT"
edition = "2018"

[dependencies]

[lib]
crate-type=["staticlib"]
```

In addition to `"staticlib"`, you can also use `"cdylib"`. In fact, you can define both with a
single crate and switch between which is used using the standard
[`BUILD_SHARED_LIBS`](https://cmake.org/cmake/help/latest/variable/BUILD_SHARED_LIBS.html) variable.

This crate defines a simple crate called `rust-lib`. Importing this crate into your
[CMakeLists.txt](test/rust2cpp/CMakeLists.txt) is trivial:
```cmake
# Note: you must have already included Corrosion for `add_crate` to be available. See the
# `Installation` section above.

add_crate(rust2cpp)
```

Now that you've imported the crate into CMake, all of the executables, static libraries, and dynamic
libraries defined in the Rust can be directly referenced. So, merely define your C++ executable as
normal in CMake and add your crate's library using target_link_libraries:
```cmake
add_executable(cpp-exe main.cpp)
target_link_libraries(cpp-exe PUBLIC rust-lib)
```

That's it! You're now linking your Rust library to your C++ library.

#### Generate Bindings to Rust Library Automatically

Currently, you must manually declare bindings in your C or C++ program to the exported routines and
types in your Rust project. You can see boths sides of this in
[the Rust code](test/rust2cpp/rust/src/lib.rs) and in [the C++ code](test/rust2cpp/main.cpp).

Integration with [cbindgen](https://github.com/eqrion/cbindgen) is
planned for the future.

### Importing Libraries Written in C and C++ Into Rust
TODO