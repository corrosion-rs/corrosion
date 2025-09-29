if(CORROSION_TESTS_CXXBRIDGE)
    corrosion_tests_add_test(cxxbridge_cpp2rust_1 "rust_bin"
        TEST_SRC_DIR cxxbridge_cpp2rust
        PASS_THROUGH_ARGS -DTEST_CXXBRIDGE_VARIANT1=ON
    )
    corrosion_tests_add_test(cxxbridge_cpp2rust_2 "rust_bin"
            TEST_SRC_DIR cxxbridge_cpp2rust
            PASS_THROUGH_ARGS -DTEST_CXXBRIDGE_VARIANT2=ON
    )
    corrosion_tests_add_test(cxxbridge_rust2cpp "cxxbridge-exe")
    corrosion_tests_add_test(cxxbridge_exported_impls "test_main")

    set_tests_properties("cxxbridge_cpp2rust_1_run_rust_bin"
        PROPERTIES PASS_REGULAR_EXPRESSION
            "main function"
    )
    set_tests_properties("cxxbridge_rust2cpp_run_cxxbridge-exe"
        PROPERTIES PASS_REGULAR_EXPRESSION
            "Hello cxxbridge from lib.rs! \\[4, 5, 6\\]\r?\nHello cxxbridge from foo/mod.rs! \\[4, 5, 6\\]"
    )
    set_tests_properties("cxxbridge_exported_impls_run_test_main"
        PROPERTIES PASS_REGULAR_EXPRESSION
            "main function"
    )
endif()
