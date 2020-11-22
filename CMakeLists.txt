cmake_minimum_required (VERSION 3.12)
project(Corrosion VERSION 0.0.1 LANGUAGES NONE)

# Default behavior:
# - If the project is being used as a subdirectory, then don't build tests and don't enable any
#   languages.
# - If this is a top level project, then build tests and eanble teh C++ compiler
if (NOT CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
    set(CORROSION_IS_SUBDIRECTORY ON)
    set(_CORROSION_TOP_LEVEL OFF)
else()
    set(CORROSION_IS_SUBDIRECTORY OFF)
    set(_CORROSION_TOP_LEVEL ON)
endif()

option(
    CORROSION_DEV_MODE
    "Enables some additional features if you're developing Corrosion"
    ${_CORROSION_TOP_LEVEL}
)

option(
    CORROSION_BUILD_TESTS
    "Build Corrosion test project"
    ${_CORROSION_TOP_LEVEL}
)

if (NOT CORROSION_IS_SUBDIRECTORY)
    # TODO: If we don't have a language enabled, corrosion_import_crate will attempt to enable a C
    # compiler. Ideally, we could delay this somehow until after we've set link libraries.
    enable_language(CXX)
endif()

# This little bit self-hosts the Corrosion toolchain to build the generator tool.
#
# It is strongly encouraged to install Corrosion separately and use
# `find_package(Corrosion REQUIRED)` instead if that works with your workflow.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include(Corrosion)

# Testing
if (CORROSION_BUILD_TESTS)
    add_subdirectory(test)
endif()

# Installation
# If Corrosion is a subdirectory, do not enable its install code
if (NOT CORROSION_IS_SUBDIRECTORY)
    # Builds the generator executable
    corrosion_import_crate(MANIFEST_PATH generator/Cargo.toml)

    # Set the link language to CXX since it's already enabled
    corrosion_set_linker_language(corrosion-generator CXX)

    corrosion_install(
        TARGETS corrosion-generator
        DESTINATION libexec
    )

    # Generate the Config file
    include(CMakePackageConfigHelpers)

    configure_package_config_file(
        cmake/CorrosionConfig.cmake.in CorrosionConfig.cmake
        INSTALL_DESTINATION lib/cmake/Corrosion
    )

    if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.13")
        set(arch_independent ARCH_INDEPENDENT)
    endif()

    write_basic_package_version_file(
        ${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfigVersion.cmake
        VERSION ${PROJECT_VERSION}
        COMPATIBILITY SameMinorVersion # Should be SameMajorVersion when 1.0 is released
        ${arch_independent}
    )

    install(
        FILES
            ${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfig.cmake
            ${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfigVersion.cmake
        DESTINATION lib/cmake/Corrosion
    )

    # These CMake scripts are needed both for the install and as a subdirectory
    install(
        FILES
            cmake/Corrosion.cmake
            cmake/FindRust.cmake
        DESTINATION
            share/cmake
    )
endif()