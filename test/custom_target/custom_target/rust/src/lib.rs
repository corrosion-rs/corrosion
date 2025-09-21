use std::os::raw::c_char;

extern "C" {
    fn calculate_42() -> u32;
}

#[no_mangle]
pub extern "C" fn rust_function(name: *const c_char) {
    let name = unsafe { std::ffi::CStr::from_ptr(name).to_str().unwrap() };
    let res = unsafe { calculate_42() };
    assert_eq!(res, 42);
    println!("Hello, {}! I am Rust!", name);
}
