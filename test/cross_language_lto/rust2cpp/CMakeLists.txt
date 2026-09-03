cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0 LANGUAGES CXX)
include(../../test_header.cmake)

set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)

add_library(lto_cpp_lib STATIC cpp_lib.cpp)

corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)
corrosion_link_libraries(lto-rust-exe lto_cpp_lib)
