cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0)
include(../../test_header.cmake)

corrosion_import_crate(MANIFEST_PATH Cargo.toml)

# Note: The output directories defined here must be manually kept in sync with the expected test location.
set_target_properties(rust_bin
    PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/custom_bin"
        PDB_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/custom_bin_pdb"

)
set_target_properties(rust_lib PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/custom_archive")
set_target_properties(rust_lib
    PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/custom_lib"
        PDB_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/custom_lib_pdb"
)

add_custom_command(TARGET cargo-build_rust_bin POST_BUILD
    COMMAND
    ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/another_dir"
    COMMAND
    ${CMAKE_COMMAND} -E copy_if_different "$<TARGET_PROPERTY:rust_bin,LOCATION>" "${CMAKE_CURRENT_BINARY_DIR}/another_dir/moved_bin"
    )

add_executable(consumer consumer.cpp)
add_dependencies(consumer cargo-build_rust_lib)

target_link_libraries(consumer rust_lib)
