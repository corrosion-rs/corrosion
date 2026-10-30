corrosion_tests_add_test(rust2cpp "cpp-exe;cpp-exe-shared")

set_tests_properties("rust2cpp_run_cpp-exe" PROPERTIES PASS_REGULAR_EXPRESSION
        "^Hello, Cpp! I'm Rust!\r?\n$"
        )

set_tests_properties("rust2cpp_run_cpp-exe-shared" PROPERTIES PASS_REGULAR_EXPRESSION
        "^Hello, Cpp! I'm Rust!\r?\n$"
        )

corrosion_tests_add_test(rust2cpp_target_dir "cpp-exe"
        TEST_SRC_DIR rust2cpp
        PASS_THROUGH_ARGS "-DCORROSION_CARGO_TARGET_DIR=${CMAKE_CURRENT_BINARY_DIR}/build-rust2cpp_target_dir/cargo"
        )
set_tests_properties("rust2cpp_target_dir_run_cpp-exe" PROPERTIES PASS_REGULAR_EXPRESSION
        "^Hello, Cpp! I'm Rust!\r?\n$"
        )
# By default, the target directory is a subdirectory of `cargo`.
# Cargo writes `.rustc_info.json` to the root of its target directory.
add_test(NAME rust2cpp_target_dir_location
        COMMAND
        "${CMAKE_COMMAND}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/../TestFileExists.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/build-rust2cpp_target_dir/cargo/.rustc_info.json"
        )
set_tests_properties("rust2cpp_target_dir_location" PROPERTIES FIXTURES_REQUIRED "build_fixture_rust2cpp_target_dir")
