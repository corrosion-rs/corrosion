cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0 LANGUAGES C CXX)
# The outer test driver gives the file a useless name
# Supress the warning, since we don't rely on this information anyway.
set(CORROSION_NO_WARN_PARSE_TARGET_TRIPLE_FAILED ON)
include(../../test_header.cmake)

if(NOT "${Rust_CARGO_TARGET}" MATCHES ".json")
    message(FATAL_ERROR "This test project expects to be configured with a custom rust target!"
            "Actual target: ${Rust_CARGO_TARGET}"
    )
endif()

corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)
corrosion_set_cargo_flags(rust_lib "-Zbuild-std")
# custom target triples require nightly features
corrosion_set_env_vars(rust_lib RUSTC_BOOTSTRAP=1)
 

add_executable(test-exe main.cpp)
target_link_libraries(test-exe PUBLIC rust_lib)
