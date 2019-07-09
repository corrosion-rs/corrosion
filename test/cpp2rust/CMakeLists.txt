cmake_minimum_required(VERSION 3.10)
project(cpp-lib-rust-exe LANGUAGES CXX)

add_crate(rust/Cargo.toml)

add_library(cpp-lib lib.cpp)
target_compile_features(cpp-lib PRIVATE cxx_std_17)
add_dependencies(cargo-build_rust-exe cpp-lib)
# target_link_libraries(cpp-exe PUBLIC rust-lib)