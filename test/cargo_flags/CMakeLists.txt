corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml FLAGS --features one)

add_executable(flags-exe main.cpp)
target_link_libraries(flags-exe PUBLIC flags-lib)
corrosion_set_cargo_flags(flags-lib FLAGS --features two)
