# Both gates on -> the flag must reach cargo. Nothing links the Rust staticlib, so this is safe
# to run everywhere, including MSVC-ABI targets: cargo produces a bitcode archive and no linker
# ever reads it. If rustc turns out to reject `-Clinker-plugin-lto` on MSVC, CI will say so.
corrosion_tests_add_test(cross_language_lto_enabled "" TEST_SRC_DIR gating
    PASS_THROUGH_ARGS
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
        -DCORROSION_CROSS_LANGUAGE_LTO=ON
        -DEXPECT_LTO=1
)

# Intent gate off -> no flag, even though permission is granted.
corrosion_tests_add_test(cross_language_lto_no_ipo "" TEST_SRC_DIR gating
    PASS_THROUGH_ARGS
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF
        -DCORROSION_CROSS_LANGUAGE_LTO=ON
        -DEXPECT_LTO=0
)

# Permission gate off -> no flag, even though IPO is requested.
corrosion_tests_add_test(cross_language_lto_disabled "" TEST_SRC_DIR gating
    PASS_THROUGH_ARGS
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
        -DCORROSION_CROSS_LANGUAGE_LTO=OFF
        -DEXPECT_LTO=0
)

# Host builds are excluded: their linker is the host `cc`, not the version-matched Clang.
corrosion_tests_add_test(cross_language_lto_hostbuild "" TEST_SRC_DIR gating IS_HOSTBUILD
    PASS_THROUGH_ARGS
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
        -DCORROSION_CROSS_LANGUAGE_LTO=ON
        -DUSE_HOSTBUILD=ON
        -DEXPECT_LTO=0
)

# An explicit `CROSS_LANGUAGE_LTO OFF` must beat a global ON.
corrosion_tests_add_test(cross_language_lto_import_off "" TEST_SRC_DIR gating
    PASS_THROUGH_ARGS
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
        -DCORROSION_CROSS_LANGUAGE_LTO=ON
        -DIMPORT_CROSS_LANGUAGE_LTO=OFF
        -DEXPECT_LTO=0
)

# An explicit `CROSS_LANGUAGE_LTO ON` must beat a global OFF.
corrosion_tests_add_test(cross_language_lto_import_on "" TEST_SRC_DIR gating
    PASS_THROUGH_ARGS
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
        -DCORROSION_CROSS_LANGUAGE_LTO=OFF
        -DIMPORT_CROSS_LANGUAGE_LTO=ON
        -DEXPECT_LTO=1
)

# Per-config IPO must be honoured: `_RELEASE=ON` alone must enable LTO in Release.
# These two rely on `-DCMAKE_BUILD_TYPE=Release`, which multi-config generators (Ninja
# Multi-Config, Visual Studio, Xcode) ignore in favor of building several configs from one
# configure - so the expectation below is only well-defined on single-config generators, where
# CMAKE_BUILD_TYPE is fixed at configure time. Making EXPECT_LTO config-aware is more machinery
# than this is worth; per-config resolution itself is already exercised by the production genex.
if(NOT CMAKE_CONFIGURATION_TYPES)
    corrosion_tests_add_test(cross_language_lto_per_config_on "" TEST_SRC_DIR gating
        PASS_THROUGH_ARGS
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE=ON
            -DCORROSION_CROSS_LANGUAGE_LTO=ON
            -DEXPECT_LTO=1
    )

    # A per-config OFF must beat a plain ON, or Rust would emit bitcode against non-LTO C++.
    corrosion_tests_add_test(cross_language_lto_per_config_off "" TEST_SRC_DIR gating
        PASS_THROUGH_ARGS
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE=OFF
            -DCORROSION_CROSS_LANGUAGE_LTO=ON
            -DEXPECT_LTO=0
    )
endif()

if(CORROSION_TESTS_CROSS_LANGUAGE_LTO)
    # C++ executable linking a Rust staticlib whose members are LLVM bitcode. CMake drives
    # this link, so it exercises the direction where Corrosion adds no link flags at all.
    corrosion_tests_add_test(cross_language_lto_cpp2rust "lto-cpp-exe" TEST_SRC_DIR cpp2rust)
    set_tests_properties("cross_language_lto_cpp2rust_run_lto-cpp-exe" PROPERTIES
        PASS_REGULAR_EXPRESSION "Ok")

    # Rust executable linking a C++ static library of bitcode objects. rustc drives this link,
    # so it exercises the `-Clink-args` path.
    corrosion_tests_add_test(cross_language_lto_rust2cpp "lto-rust-exe" TEST_SRC_DIR rust2cpp)
    set_tests_properties("cross_language_lto_rust2cpp_run_lto-rust-exe" PROPERTIES
        PASS_REGULAR_EXPRESSION "Ok")
endif()
