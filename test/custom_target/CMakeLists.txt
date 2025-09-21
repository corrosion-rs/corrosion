# Create a custom target triple, by taking the default host triple target spec.
# This way we don't actually need to cross-compile and just check if we can handle
# custom json target triples.
# Note: dashes and not underscore is important, at least if cc-rs is used by dependencies,
# since cc-rs will attempt to parse the target triple.
# A real-world toolchain .json file should be named the same as the corresponding c/c++ compiler target,
# in order for cc-rs to choose the correct target by default.
set(target_spec_file "${CMAKE_CURRENT_BINARY_DIR}/custom-target-triple.json")
execute_process(COMMAND
                ${CMAKE_COMMAND} -E env RUSTC_BOOTSTRAP=1
                ${_CORROSION_RUSTC} -Z unstable-options --print target-spec-json
                OUTPUT_FILE "${target_spec_file}"
                COMMAND_ERROR_IS_FATAL ANY
)

set(Rust_CARGO_TARGET "${target_spec_file}")
corrosion_tests_add_test(custom_target "test-exe;rust-bin")

set_tests_properties("custom_target_run_test-exe" PROPERTIES PASS_REGULAR_EXPRESSION [[Hello, Cxx! I am Rust!]])
set_tests_properties("custom_target_run_rust-bin" PROPERTIES PASS_REGULAR_EXPRESSION [[The answer is 42]])

