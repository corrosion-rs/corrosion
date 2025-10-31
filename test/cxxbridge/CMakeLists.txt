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
    if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.24.0" AND CMAKE_LINK_GROUP_USING_RESCAN_SUPPORTED)
        corrosion_tests_add_test(cxxbridge_circular_link_group "cpp_bin"
            TEST_SRC_DIR cxxbridge_circular
            PASS_THROUGH_ARGS -DTEST_CXXBRIDGE_VARIANT1=ON
        )
    endif()
    corrosion_tests_add_test(cxxbridge_circular_mutual_link "cpp_bin"
        TEST_SRC_DIR cxxbridge_circular
        PASS_THROUGH_ARGS -DTEST_CXXBRIDGE_VARIANT2=ON
    )

    set_tests_properties("cxxbridge_cpp2rust_1_run_rust_bin"
        PROPERTIES PASS_REGULAR_EXPRESSION
            "main function"
    )
    set_tests_properties("cxxbridge_rust2cpp_run_cxxbridge-exe"
        PROPERTIES PASS_REGULAR_EXPRESSION
            "Hello cxxbridge from lib.rs! \\[4, 5, 6\\]\r?\nHello cxxbridge from foo/mod.rs! \\[4, 5, 6\\]"
    )

    if(NOT WIN32)
        corrosion_tests_add_test(cxxbridge_exported_impls "test_main")
        set_tests_properties("cxxbridge_exported_impls_run_test_main"
            PROPERTIES PASS_REGULAR_EXPRESSION
                "main function"
        )
    endif()
endif()
