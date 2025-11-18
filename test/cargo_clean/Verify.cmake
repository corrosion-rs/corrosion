# Verifies the cargo_clean_test library artifact exists or doesn't exist as expected.
# Usage: cmake -P Verify.cmake <build_directory> <SHOULD_EXIST|SHOULD_NOT_EXIST>

if(NOT CMAKE_ARGV3 OR NOT CMAKE_ARGV4)
    message(FATAL_ERROR "Usage: cmake -P Verify.cmake <build_directory> <SHOULD_EXIST|SHOULD_NOT_EXIST>")
endif()

set(BUILD_DIR "${CMAKE_ARGV3}")
set(EXPECT_MODE "${CMAKE_ARGV4}")

if(NOT EXPECT_MODE MATCHES "^(SHOULD_EXIST|SHOULD_NOT_EXIST)$")
    message(FATAL_ERROR "Second argument must be either SHOULD_EXIST or SHOULD_NOT_EXIST")
endif()

# Find source directory
get_filename_component(TEST_DIR "${BUILD_DIR}" DIRECTORY)
get_filename_component(TEST_DIR "${TEST_DIR}" DIRECTORY)
set(SOURCE_DIR "${TEST_DIR}/cargo_clean/cargo_clean")

# Find Corrosion cargo build directories.
# Multi-config generators create one per configuration (Debug, Release, etc.)
file(GLOB_RECURSE CUSTOM_ARTIFACTS "${BUILD_DIR}/**/*cargo_clean_test*")

# Verify based on expected mode
if(EXPECT_MODE STREQUAL "SHOULD_EXIST")
    # Before clean: artifact should exist in custom directory
    if(NOT CUSTOM_ARTIFACTS)
        message(FATAL_ERROR 
            "Build verification failed: cargo_clean_test library not found in any cargo build directories\n"
        )
    endif()
    message(STATUS "SUCCESS: Build artifact found: ${CUSTOM_ARTIFACTS}")
    
elseif(EXPECT_MODE STREQUAL "SHOULD_NOT_EXIST")
    # Verify the artifact was actually cleaned from custom directory
    if(CUSTOM_ARTIFACTS)
        message(FATAL_ERROR "Artifact remains in cargo build directories:\n${CUSTOM_ARTIFACTS}")
    endif()
    
    message(STATUS "SUCCESS: cargo-clean properly cleaned cargo_clean_test library from all cargo build directories")
endif()
