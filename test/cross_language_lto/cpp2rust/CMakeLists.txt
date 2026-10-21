cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0 LANGUAGES CXX)
include(../../test_header.cmake)

set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)

corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)

add_executable(lto-cpp-exe main.cpp)
target_link_libraries(lto-cpp-exe PUBLIC lto_cpp2rust_lib)
