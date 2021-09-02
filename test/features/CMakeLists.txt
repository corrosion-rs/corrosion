corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)

add_executable(features-cpp-exe main.cpp)
target_link_libraries(features-cpp-exe PUBLIC rust-feature-lib)
set_property(
    TARGET rust-feature-lib
    APPEND
    PROPERTY CORROSION_FEATURES myfeature
)
