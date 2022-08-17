corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml FLAGS --features one)

add_executable(flags-exe main.cpp)
target_link_libraries(flags-exe PUBLIC flags-lib)
corrosion_set_cargo_flags(flags-lib --features two)
corrosion_set_cargo_flags(flags-lib $<TARGET_PROPERTY:flags-lib,more_flags>)

set_property(
    TARGET flags-lib
    APPEND
    PROPERTY more_flags --features three
)
