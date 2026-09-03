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
}
