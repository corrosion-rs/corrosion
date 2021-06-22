corrosion_import_crate(MANIFEST_PATH ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml)

set_property(
    TARGET rust-host-program
    PROPERTY CORROSION_USE_HOST_BUILD 1
)
