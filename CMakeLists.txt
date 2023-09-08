cmake_minimum_required(VERSION 3.22)
project(Corrosion
    # Official releases will be major.minor.patch. When the `tweak` field is
    # set it indicates that we are on a commit, that is not a officially
    # tagged release. Users don't need to care about this, it is mainly to
    # clearly see in configure logs which version was used, without needing to
    # rely on `git`, since Corrosion may be installed or otherwise packaged.
    VERSION 0.4.99.99 # a 0.5-pre-release
    LANGUAGES NONE
    HOMEPAGE_URL "https://corrosion-rs.github.io/corrosion/"
)

# Default behavior:
# - If the project is being used as a subdirectory, then don't build tests and
#   don't enable any languages.
# - If this is a top level project, then build tests and enable the C++ compiler
if (NOT CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
    set(_CORROSION_TOP_LEVEL OFF)
else()
    set(_CORROSION_TOP_LEVEL ON)
endif()

# ==== Corrosion Configuration ====

option(
    CORROSION_BUILD_TESTS
    "Build Corrosion test project"
    ${_CORROSION_TOP_LEVEL}
)

set(
  CORROSION_GENERATOR_EXECUTABLE CACHE STRING
  "Use prebuilt, non-bootstrapped corrosion-generator")
mark_as_advanced(CORROSION_GENERATOR_EXECUTABLE)

option(
    CORROSION_INSTALL_EXECUTABLE
    "Controls whether corrosion-generator is installed with the package"
    ${CORROSION_INSTALL_EXECUTABLE_DEFAULT}
)
mark_as_advanced(CORROSION_INSTALL_EXECUTABLE)

if (CORROSION_GENERATOR_EXECUTABLE OR CORROSION_INSTALL_EXECUTABLE)
    message(FATAL_ERROR "The Cache variables CORROSION_GENERATOR_EXECUTABLE CORROSION_INSTALL_EXECUTABLE"
            " were removed.")
endif()

if (_CORROSION_TOP_LEVEL)
    # We need to enable a language for corrosions test to work.
    # For projects using corrosion this is not needed
    enable_language(C)
endif()

# This little bit self-hosts the Corrosion toolchain to build the generator
# tool.
#
# It is strongly encouraged to install Corrosion separately and use
# `find_package(Corrosion REQUIRED)` instead if that works with your workflow.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include(Corrosion)

# Testing
if (CORROSION_BUILD_TESTS)
    include(CTest)
    add_subdirectory(test)
endif()

# If Corrosion is a subdirectory, do not enable its install code
if (NOT _CORROSION_TOP_LEVEL)
    return()
endif()

# Installation

include(GNUInstallDirs)

# Generate the Config file
include(CMakePackageConfigHelpers)

configure_package_config_file(
    cmake/CorrosionConfig.cmake.in CorrosionConfig.cmake
    INSTALL_DESTINATION
        "${CMAKE_INSTALL_FULL_LIBDIR}/cmake/Corrosion"
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY
        SameMinorVersion # TODO: Should be SameMajorVersion when 1.0 is released
    ARCH_INDEPENDENT
)

install(
    FILES
        "${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfig.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/CorrosionConfigVersion.cmake"
    DESTINATION
        "${CMAKE_INSTALL_FULL_LIBDIR}/cmake/Corrosion"
)

# These CMake scripts are needed both for the install and as a subdirectory
install(
    FILES
        cmake/Corrosion.cmake
        cmake/CorrosionGenerator.cmake
        cmake/FindRust.cmake
    DESTINATION
        "${CMAKE_INSTALL_FULL_DATADIR}/cmake"
)
