corrosion_tests_add_test(cargo_clean "")

# Verify that build artifacts exist before cargo-clean
add_test(NAME cargo_clean_verify_build
    COMMAND
        ${CMAKE_COMMAND}
        -P "${CMAKE_CURRENT_SOURCE_DIR}/Verify.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/build-cargo_clean"
        SHOULD_EXIST
)
set_tests_properties(cargo_clean_verify_build PROPERTIES 
    FIXTURES_REQUIRED "build_fixture_cargo_clean"
)

# Verify that artifacts are actually removed after cargo-clean
add_test(NAME cargo_clean_verify_cleaned
   COMMAND
       ${CMAKE_COMMAND}
       -P "${CMAKE_CURRENT_SOURCE_DIR}/Verify.cmake"
       "${CMAKE_CURRENT_BINARY_DIR}/build-cargo_clean"
       SHOULD_NOT_EXIST
)
set_tests_properties(cargo_clean_verify_cleaned PROPERTIES 
   FIXTURES_REQUIRED "build_fixture_cargo_clean"
   DEPENDS cargo_clean_run_clean
)
