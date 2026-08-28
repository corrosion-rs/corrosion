
pub fn make_engine() -> base64::engine::GeneralPurpose {
    let alphabet = base64::alphabet::Alphabet::new("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/").unwrap();
    base64::engine::GeneralPurpose::new(
        &alphabet,
        base64::engine::general_purpose::PAD)
}

pub fn add(left: u64, right: u64) -> u64 {
    left + right
}
