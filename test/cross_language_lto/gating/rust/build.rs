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
    println!("cargo:rerun-if-env-changed=EXPECT_IPO_C_FLAG");
    let target = std::env::var("TARGET").expect("cargo always sets TARGET for build scripts");
    let expected_flag = std::env::var("EXPECT_IPO_C_FLAG")
        .expect("the test harness must set EXPECT_IPO_C_FLAG");

    for var_base in ["CFLAGS", "CXXFLAGS"].iter() {
        let key = format!("{}_{}", var_base, target);
        let actual = std::env::var(&key).unwrap_or_default();
        let has_flag = actual.split_whitespace().any(|f| f == expected_flag);
        match (expect.as_str(), has_flag) {
            ("1", false) => panic!("expected `{}` in `{}`, got `{}`", expected_flag, key, actual),
            ("0", true) => panic!("did not expect `{}` in `{}`, got `{}`", expected_flag, key, actual),
            _ => {}
        }
    }
}
