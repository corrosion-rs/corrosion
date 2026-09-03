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
