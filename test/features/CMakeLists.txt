corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml FEATURES thirdfeature ALL_FEATURES)

add_executable(features-cpp-exe main.cpp)
target_link_libraries(features-cpp-exe PUBLIC rust-feature-lib)
set_property(
    TARGET rust-feature-lib
    PROPERTY CORROSION_ALL_FEATURES OFF
)
set_property(
    TARGET rust-feature-lib
    PROPERTY CORROSION_NO_DEFAULT_FEATURES ON
)
set_property(
    TARGET features-cpp-exe
    APPEND
    PROPERTY app_features myfeature
)
set_property(
    TARGET features-cpp-exe
    APPEND
    PROPERTY app_features secondfeature
)
set_property(
    TARGET rust-feature-lib
    APPEND
    PROPERTY CORROSION_FEATURES $<TARGET_PROPERTY:features-cpp-exe,app_features>
)
