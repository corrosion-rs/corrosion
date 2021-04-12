corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml FEATURES myfeature)

add_executable(cpp-exe main.cpp)
target_link_libraries(cpp-exe PUBLIC rust-lib)
