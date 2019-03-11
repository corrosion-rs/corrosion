cmake_minimum_required(VERSION 3.10)
project(cmake-cargo-test LANGUAGES CXX)

add_crate(rust/Cargo.toml)

add_executable(cmake-cargo-test main.cpp)
target_link_libraries(cmake-cargo-test PUBLIC cmake-cargo-test-lib)