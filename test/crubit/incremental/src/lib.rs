pub const API_VERSION: u32 = 1;

pub fn rust_value() -> u32 {
    API_VERSION + incremental_dependency::DEP_VERSION
}
