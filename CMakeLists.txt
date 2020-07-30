cmake_minimum_required (VERSION 3.12)
project(Corrosion VERSION 0.0.1 LANGUAGES NONE)

# This little bit self-hosts the Corrosion toolchain to build the generator tool.
# Projects that want to use Corrosion as a submodule can do something similar.
# It is NOT recommended to add this directory directly - you should instead add the cmake
# directory to CMAKE_MODULE_PATH and include the Corrosion module.
#
# It is strongly encouraged to install Corrosion separately and use
# `find_package(Corrosion REQUIRED)` instead.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include(Corrosion)

# If Corrosion is being used as a submodule, then return early - we don't want to pollute the
# install rules, add unnecessary builds, or enable tests.
if (NOT CMAKE_PROJECT_NAME STREQUAL "Corrosion")
    return()
endif()

# Builds the generator executables
add_crate(generator/Cargo.toml)

# Testing
enable_testing()
if (BUILD_TESTING)
    add_subdirectory(test)
endif()

# Installation
install(
    PROGRAMS $<TARGET_FILE:corrosion-generator>
    DESTINATION Corrosion/libexec
)

include(CMakePackageConfigHelpers)

configure_package_config_file(
    cmake/CorrosionConfig.cmake.in CorrosionConfig.cmake
    INSTALL_DESTINATION Corrosion/lib/cmake/Corrosion
)

write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMinorVersion
)

install(
    FILES
        ${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfigVersion.cmake
    DESTINATION Corrosion/lib/cmake/Corrosion
)

install(
    FILES
        cmake/Corrosion.cmake
        cmake/FindRust.cmake
    DESTINATION
        Corrosion/share/cmake
)
