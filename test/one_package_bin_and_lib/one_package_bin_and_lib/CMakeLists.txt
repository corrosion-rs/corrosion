cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0)
include(../../test_header.cmake)

corrosion_import_crate(
    MANIFEST_PATH ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml
    BIN_NAMESPACE bin LIB_NAMESPACE lib
)

if(NOT TARGET bin::mycrate)
    message(FATAL_ERROR "Unable to import bin::mycrate.")
endif()

add_executable(my_program main.cpp)
target_link_libraries(my_program PUBLIC lib::mycrate)

