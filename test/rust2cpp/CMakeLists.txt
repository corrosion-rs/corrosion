corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)

add_executable(cpp-exe main.cpp)
target_link_libraries(cpp-exe PUBLIC rust-lib)

add_executable(cpp-exe-shared main.cpp)
target_link_libraries(cpp-exe-shared
        PUBLIC rust-lib-shared)
