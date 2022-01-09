fn main() {
    assert!(!env!("CORROSION_LINKER_LANGUAGES").is_empty());
    assert_eq!(env!("REQUIRED_VARIABLE"), "EXPECTED_VALUE");
    assert_eq!(std::env::var("ANOTHER_VARIABLE").unwrap(), "ANOTHER_VALUE");
}
