cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0)
include(../../test_header.cmake)

corrosion_import_crate(MANIFEST_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../rust2cpp/rust/Cargo.toml")
# cbindgen with non-existent target
corrosion_experimental_cbindgen(TARGET rust_lib_h HEADER_NAME "rust-lib.h" MANIFEST_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../rust2cpp/rust")

add_executable(cpp-exe "${CMAKE_CURRENT_SOURCE_DIR}/../rust2cpp/main.cpp")
set_property(TARGET cpp-exe PROPERTY CXX_STANDARD 11)
target_link_libraries(cpp-exe PUBLIC rust_lib rust_lib_h)
