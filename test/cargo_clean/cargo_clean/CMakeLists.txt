cmake_minimum_required(VERSION 3.15)
project(test_cargo_clean VERSION 0.1.0)

include(../../test_header.cmake)

corrosion_import_crate(
    MANIFEST_PATH ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml
)
