fn main() {
    println!("cargo:rerun-if-env-changed=CARGO_ENCODED_RUSTFLAGS");
    println!("cargo:rerun-if-env-changed=EXPECT_LINKER_PLUGIN_LTO");

    // `expect` is reused by the cc-rs assertions added in Task 4. Keep it in scope.
    let expect = std::env::var("EXPECT_LINKER_PLUGIN_LTO")
        .expect("the test harness must set EXPECT_LINKER_PLUGIN_LTO to 0 or 1");
    let encoded = std::env::var("CARGO_ENCODED_RUSTFLAGS").unwrap_or_default();
    let present = encoded.split('\u{1f}').any(|flag| flag == "-Clinker-plugin-lto");

    match (expect.as_str(), present) {
        ("1", false) => panic!(
            "expected `-Clinker-plugin-lto` in CARGO_ENCODED_RUSTFLAGS, got `{}`",
            encoded
        ),
        ("0", true) => panic!(
            "did not expect `-Clinker-plugin-lto` in CARGO_ENCODED_RUSTFLAGS, got `{}`",
            encoded
        ),
        ("0", false) | ("1", true) => {}
        (other, _) => panic!("EXPECT_LINKER_PLUGIN_LTO must be 0 or 1, got `{}`", other),
    }

    // C/C++ compiled by cc-rs inside build scripts must join the LTO unit, which means
    // Corrosion has to forward the IPO compile flags as CFLAGS_<triple>/CXXFLAGS_<triple>.
    // The expected value is space-joined and may contain multiple flags (e.g. GCC's
    // `-flto=auto -fno-fat-lto-objects`); every expected token must be present, not just one,
    // or a regression that drops flags after the first would go undetected.
    println!("cargo:rerun-if-env-changed=EXPECT_IPO_C_FLAGS");
    println!("cargo:rerun-if-env-changed=EXPECT_IPO_CXX_FLAGS");
    let target = std::env::var("TARGET").expect("cargo always sets TARGET for build scripts");

    for (var_base, expect_var) in [("CFLAGS", "EXPECT_IPO_C_FLAGS"), ("CXXFLAGS", "EXPECT_IPO_CXX_FLAGS")] {
        let expected_value = std::env::var(expect_var)
            .unwrap_or_else(|_| panic!("the test harness must set {}", expect_var));
        let expected_flags: Vec<&str> = expected_value.split_whitespace().collect();
        if expected_flags.is_empty() {
            panic!(
                "{} was set but parsed to zero tokens; the `all()`/`any()` checks below would \
                 be vacuously true/false and would not actually verify anything. This means the \
                 test harness could not determine the compiler's IPO flags (CMAKE_{}_COMPILE_OPTIONS_IPO \
                 was empty) - fix the test setup rather than let this pass silently.",
                expect_var, var_base
            );
        }

        let key = format!("{}_{}", var_base, target);
        let actual = std::env::var(&key).unwrap_or_default();
        let actual_flags: Vec<&str> = actual.split_whitespace().collect();

        // Positive direction: every expected flag must be present.
        let all_present = expected_flags.iter().all(|f| actual_flags.contains(f));
        // Negative direction: none of the expected flags may be present.
        let any_present = expected_flags.iter().any(|f| actual_flags.contains(f));

        match (expect.as_str(), all_present, any_present) {
            ("1", false, _) => panic!(
                "expected all of `{:?}` in `{}`, got `{}`",
                expected_flags, key, actual
            ),
            ("0", _, true) => panic!(
                "did not expect any of `{:?}` in `{}`, got `{}`",
                expected_flags, key, actual
            ),
            _ => {}
        }
    }
}
