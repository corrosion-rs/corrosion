# Both gates on. Nothing links the Rust staticlib, so this is safe to run
# everywhere: cargo produces a bitcode archive and no linker ever reads it.
corrosion_tests_add_test(cross_language_lto_enabled "" TEST_SRC_DIR gating
    PASS_THROUGH_ARGS
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
        -DCORROSION_CROSS_LANGUAGE_LTO=ON
)
