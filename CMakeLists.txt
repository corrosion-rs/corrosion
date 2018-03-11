cmake_minimum_required (VERSION 3.0)
project(CargoTest NONE)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake" CACHE FILEPATH "")

include(Cargo)

add_crate(Cargo.toml)