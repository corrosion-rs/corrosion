#[no_mangle]
pub extern "C" fn rust_add(a: u32, b: u32) -> u32 {
    a + b
}
