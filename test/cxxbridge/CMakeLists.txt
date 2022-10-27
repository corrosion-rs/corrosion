if(CORROSION_TESTS_CXXBRIDGE)
    corrosion_tests_add_test(cxxbridge "cxxbridge-exe")

    set_tests_properties("cxxbridge_run_cxxbridge-exe"
        PROPERTIES PASS_REGULAR_EXPRESSION
            "Hello cxxbridge from lib.rs!\r?\nHello cxxbridge from foo/mod.rs!"
    )
endif()
