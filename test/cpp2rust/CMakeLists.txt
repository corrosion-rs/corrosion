add_crate(rust/Cargo.toml)

add_library(cpp-lib lib.cpp)
target_compile_features(cpp-lib PRIVATE cxx_std_17)
cargo_link_libraries(rust-exe cpp-lib)