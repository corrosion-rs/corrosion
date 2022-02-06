# This test uses C++, so we can modify the C compiler to test if it is passed through as CC to 
# cargo. Must be set before corrosion_import_crate.
set(CMAKE_C_COMPILER "some-custom-c-compiler")

corrosion_import_crate(MANIFEST_PATH ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml)

set_property(
    TARGET rust-lib-requiring-envvar
    APPEND
    PROPERTY CORROSION_ENVIRONMENT_VARIABLES
    "ANOTHER_VARIABLE=ANOTHER_VALUE"
)

set_property(
    TARGET rust-lib-requiring-envvar
    APPEND
    PROPERTY CORROSION_ENVIRONMENT_VARIABLES
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
