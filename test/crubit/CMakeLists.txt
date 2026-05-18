cmake_minimum_required(VERSION 3.22)
project(test_project VERSION 0.1.0)
include(../test_header.cmake)

corrosion_experimental_crubit(rust_lib)
corrosion_import_crate(MANIFEST_PATH rust_lib/Cargo.toml)

add_executable(main main.cpp)
target_link_libraries(main PRIVATE rust_lib)
add_dependencies(main crubit_support)

