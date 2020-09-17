corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)
corrosion_link_libraries(rust-exe cpp-lib)

add_library(cpp-lib lib.cpp)
target_compile_features(cpp-lib PRIVATE cxx_std_17)
set_target_properties(
    cpp-lib
    PROPERTIES
        POSITION_INDEPENDENT_CODE ON
)