if(NOT (CMAKE_CROSSCOMPILING AND MSVC))
    # When using MSVC the cmake build via ExternalProject seems to inherit the target architecture,
    # which breaks the test. Since we practically don't care about this, and we just want to ensure
    # that installing an executable works, skipping this test when cross-compiling is fine.
    corrosion_tests_add_test(install_rust_bin "generated_from_installed_bin")

    set_tests_properties("install_rust_bin_run_generated_from_installed_bin"
                         PROPERTIES PASS_REGULAR_EXPRESSION
                         "Hello World! I'm generated code"
    )
endif()
