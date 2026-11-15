if(CORROSION_TESTS_CRUBIT)
    corrosion_tests_add_test(crubit "main")
    add_test(NAME crubit_incremental
        COMMAND "${CMAKE_COMMAND}"
            "-DTEST_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/build-crubit-incremental"
            "-DCORROSION_SOURCE_DIR=${PROJECT_SOURCE_DIR}"
            "-DTEST_GENERATOR=${CMAKE_GENERATOR}"
            "-DTEST_MULTI_CONFIG=${COR_IS_MULTI_CONFIG}"
            "-DTEST_RUST_TOOLCHAIN=${Rust_TOOLCHAIN}"
            "-DTEST_C_COMPILER=${CMAKE_C_COMPILER}"
            "-DTEST_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
            "-DTEST_CRUBIT_SOURCE_DIR=${FETCHCONTENT_SOURCE_DIR_CRUBIT}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/Incremental.cmake")
endif()
