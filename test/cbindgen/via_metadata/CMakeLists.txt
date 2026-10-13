cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0)

set(CORROSION_TOOLS_RUST_TOOLCHAIN "stable")
include(../../test_header.cmake)
corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)

add_library(cbindgen_rust_lib INTERFACE)
# Don't call corrosion_experimental_cbindgen() as the invocation should be picked up from Cargo.toml metadata.

# The interface library for the generated headers should link to the actual rust library
target_link_libraries(cbindgen_rust_lib INTERFACE the_actual_library_crate_name)

add_executable(cpp-exe main.cpp)
set_property(TARGET cpp-exe PROPERTY CXX_STANDARD 11)
# The C/C++ bin needs to link to the cbindgen library with the generated sources.
target_link_libraries(cpp-exe PUBLIC cbindgen_rust_lib)
#add_dependencies(cpp-exe cbindgen_rust_lib)
