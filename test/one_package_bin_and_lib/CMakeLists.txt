corrosion_tests_add_test(one_package_bin_and_lib "my_program")

set_tests_properties("one_package_bin_and_lib_run_my_program" PROPERTIES PASS_REGULAR_EXPRESSION
        "^Ok\r?\n$"
        )

