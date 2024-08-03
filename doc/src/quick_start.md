# Quick Start

You can add corrosion to your project via the `FetchContent` CMake module or one of the other methods
described in the [Setup chapter](setup_corrosion.md).
Afterwards you can import Rust targets defined in a `Cargo.toml` manifest file by using
`corrosion_import_crate`. This will add CMake targets with names matching the crate names defined
in the Cargo.toml manifest. These targets can then subsequently be used, e.g. to link the imported
target into a regular C/C++ target.

The example below shows how to add Corrosion to your project via `FetchContent`
and how to import a rust library and link it into a regular C/C++ CMake target.

```cmake
include(FetchContent)

FetchContent_Declare(
    Corrosion
    GIT_REPOSITORY https://github.com/corrosion-rs/corrosion.git
    GIT_TAG v0.5 # Optionally specify a commit hash, version tag or branch here
)
# Set any global configuration variables such as `Rust_TOOLCHAIN` before this line!
FetchContent_MakeAvailable(Corrosion)

# Import targets defined in a package or workspace manifest `Cargo.toml` file
corrosion_import_crate(MANIFEST_PATH rust-lib/Cargo.toml)

add_executable(your_cool_cpp_bin main.cpp)

# In this example the the `Cargo.toml` file passed to `corrosion_import_crate` is assumed to have
# defined a static (`staticlib`) or shared (`cdylib`) rust library with the name "rust-lib".
# A target with the same name is now available in CMake and you can use it to link the rust library into
# your C/C++ CMake target(s).
target_link_libraries(your_cool_cpp_bin PUBLIC rust-lib)
```

The example below shows how to import a rust library and make it available for install through CMake.


```cmake
include(FetchContent)

FetchContent_Declare(
        Corrosion
        GIT_REPOSITORY https://github.com/corrosion-rs/corrosion.git
        GIT_TAG v0.5 # Optionally specify a commit hash, version tag or branch here
)
# Set any global configuration variables such as `Rust_TOOLCHAIN` before this line!
FetchContent_MakeAvailable(Corrosion)

# Import targets defined in a package or workspace manifest `Cargo.toml` file
corrosion_import_crate(MANIFEST_PATH rust-lib/Cargo.toml)

# Add a manually written header file which will be exported
# Requires CMake >=3.23
target_sources(rust-lib INTERFACE
        FILE_SET HEADERS
        BASE_DIRS include
        FILES
        include/rust-lib/rust-lib.h
)

# OR for CMake <= 3.23
target_include_directories(is_odd INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)
target_sources(is_odd
        INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/rust-lib/rust-lib.h>
        $<INSTALL_INTERFACE:include/rust-lib/rust-lib.h>
)

# Rust libraries must be installed using `corrosion_install`.
corrosion_install(TARGETS rust-lib EXPORT RustLibTargets)

# Installs the main target
install(
        EXPORT RustLibTargets
        NAMESPACE RustLib::
        DESTINATION lib/cmake/RustLib
)

# Necessary for packaging helper commands
include(CMakePackageConfigHelpers)
# Create a file for checking version compatibility
# Optional
write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/RustLibConfigVersion.cmake"
        VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}"
        COMPATIBILITY AnyNewerVersion
)

# Configures the main config file that cmake loads
configure_package_config_file(${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in
        "${CMAKE_CURRENT_BINARY_DIR}/RustLibConfig.cmake"
        INSTALL_DESTINATION lib/cmake/RustLib
        NO_SET_AND_CHECK_MACRO
        NO_CHECK_REQUIRED_COMPONENTS_MACRO
)
# Config.cmake.in contains
# @PACKAGE_INIT@
# 
# include(${CMAKE_CURRENT_LIST_DIR}/RustLibTargetsCorrosion.cmake)
# include(${CMAKE_CURRENT_LIST_DIR}/RustLibTargets.cmake)

# Install all generated files
install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/RustLibConfigVersion.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/RustLibConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/corrosion/RustLibTargetsCorrosion.cmake
        DESTINATION lib/cmake/RustLib
)
```

Please see the [Usage chapter](usage.md) for a complete discussion of possible configuration options.
