corrosion_tests_add_test(cbindgen_rust2cpp_auto "cpp-exe" TEST_SRC_DIR auto)
corrosion_tests_add_test(cbindgen_manual "cpp-exe" TEST_SRC_DIR manual)


set_tests_properties(cbindgen_rust2cpp_auto_run_cpp-exe cbindgen_manual_run_cpp-exe
         PROPERTIES PASS_REGULAR_EXPRESSION
        "^add_point Result: Point { x: 100, y: 100 }\r?\n$"
)
# Todo: We also should add a cpp2rust test with the following setup:
# - A rust lib that is used by a rust executable
# - cbindgen creates bindings for the rust-lib
# - c++ code uses the rust lib and is used in turn by the rust bin.

# todo: add a test for the DEPFILE and correct regenerating if the sources are touched.
