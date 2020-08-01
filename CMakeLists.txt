cmake_minimum_required (VERSION 3.12)
project(Corrosion VERSION 0.0.1 LANGUAGES NONE)

if (NOT CMAKE_PROJECT_NAME STREQUAL "Corrosion")
    set(IS_SUBDIRECTORY ON)
else()
    set(IS_SUBDIRECTORY OFF)
endif()

if (NOT IS_SUBDIRECTORY)
    # TODO: If we don't have a language enabled, add_crate will attempt to enable a C compiler.
    # Ideally, we could delay this somehow until after we've linked libraries
    enable_language(CXX)
endif()

# This little bit self-hosts the Corrosion toolchain to build the generator tool.
#
# It is strongly encouraged to install Corrosion separately and use
# `find_package(Corrosion REQUIRED)` instead if that works with your workflow.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include(Corrosion)

# If Corrosion is being used as a submodule, then return early - we don't want to pollute the
# install rules, add unnecessary builds, or enable tests.
if (IS_SUBDIRECTORY)
    return()
endif()

# Builds the generator executables
add_crate(generator/Cargo.toml)

# Testing
add_subdirectory(test)

# Installation

# It's not possible to install imported targets, so we need to install the files off of
# corrosion-generator manually. `Corrosion::Generator` is defined in CorrosionConfig.cmake.in.
install(
    PROGRAMS $<TARGET_FILE:corrosion-generator>
    DESTINATION Corrosion/libexec
)

# Generate the Config file
include(CMakePackageConfigHelpers)

configure_package_config_file(
    cmake/CorrosionConfig.cmake.in CorrosionConfig.cmake
    INSTALL_DESTINATION Corrosion/lib/cmake/Corrosion
)

write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMinorVersion # Should be SameMajorVersion when 1.0 is released
)

install(
    FILES
        ${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfigVersion.cmake
    DESTINATION Corrosion/lib/cmake/Corrosion
)

# These CMake scripts are needed both for the install and as a subdirectory
install(
    FILES
        cmake/Corrosion.cmake
        cmake/FindRust.cmake
    DESTINATION
        Corrosion/share/cmake
)
