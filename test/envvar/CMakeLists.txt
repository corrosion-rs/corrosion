corrosion_import_crate(MANIFEST_PATH ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml)

corrosion_set_env_vars(rust-lib-requiring-envvar
        "ANOTHER_VARIABLE=ANOTHER_VALUE"
        "$<TARGET_PROPERTY:program_requiring_rust_lib_with_envvar,INDIRECT_VAR_TEST>"
)

add_executable(program_requiring_rust_lib_with_envvar main.cpp)

set_property(
    TARGET program_requiring_rust_lib_with_envvar
    APPEND
    PROPERTY INDIRECT_VAR_TEST
    "REQUIRED_VARIABLE=EXPECTED_VALUE"
)

target_link_libraries(program_requiring_rust_lib_with_envvar PUBLIC rust-lib-requiring-envvar)
