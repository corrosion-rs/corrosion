// Simple test library for cargo-clean test

#[no_mangle]
pub extern "C" fn test_function() -> i32 {
    42
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        assert_eq!(test_function(), 42);
    }
}
