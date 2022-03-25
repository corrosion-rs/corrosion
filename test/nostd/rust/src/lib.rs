#![no_std]
use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn rust_function() {}

// Some symbols which would collide when linking against
// libraries included by default


#[panic_handler]
fn panic(_panic: &PanicInfo<'_>) -> ! {
    loop {}
}