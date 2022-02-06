fn main() {
    assert_eq!(env!("REQUIRED_VARIABLE"), "EXPECTED_VALUE");
    assert_eq!(std::env::var("ANOTHER_VARIABLE").unwrap(), "ANOTHER_VALUE");
    assert_eq!(env!("CC"), "some-custom-c-compiler");
}
