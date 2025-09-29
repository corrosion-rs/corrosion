#[cxx::bridge]
pub mod ffi {
    pub struct OkResult {
        pub value: bool,
        pub message: String,
    }

    pub struct TestResult {
        pub ok: SharedPtr<OkResult>,
    }

    impl SharedPtr<OkResult> {}

    extern "Rust" {
        fn make_result() -> Result<TestResult>;
    }
}

pub fn make_result() -> Result<ffi::TestResult, String> {
    let now = std::time::Instant::now();
    let ok = ffi::OkResult { value: true, message: format!("{:#?}", now)};
    Ok(ffi::TestResult { ok: cxx::SharedPtr::new(ok)} )
}

