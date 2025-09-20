cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0)
include(../../test_header.cmake)

corrosion_import_crate(MANIFEST_PATH proj1/Cargo.toml)

# Note: The output directories defined here must be manually kept in sync with the expected test location.
set_target_properties(rust_bin1
    PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/bin"
        PDB_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/bin"
)

set_target_properties(rust_lib1 PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/lib")
set_target_properties(rust_lib1
                      PROPERTIES
                      LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/lib"
                      PDB_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/lib"
)

add_executable(consumer consumer.cpp)
add_dependencies(consumer cargo-build_rust_lib1)
target_link_libraries(consumer rust_lib1)
