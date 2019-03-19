cmake_minimum_required (VERSION 3.10)
project(CargoTest LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
set(CARGO_DEV_MODE ON CACHE INTERNAL "")

include(Cargo)

add_crate(Cargo.toml)

add_subdirectory(test)
