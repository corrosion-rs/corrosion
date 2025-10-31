pub mod bridge_a;
pub mod bridge_b;
// pub use bridge_a::combine_result;

#[cxx::bridge]
pub mod ffi {

    extern "C++" {
        include!("cxxbridge/bridge_a.h");
        include!("cxxbridge/bridge_b.h");

        type TestResult = crate::bridge_a::ffi::TestResult;
        type NewVal = crate::bridge_b::ffi::NewVal;
    }

    extern "Rust" {
        fn combine_result(other: SharedPtr<NewVal>) -> Result<TestResult>;
    }

}

pub fn combine_result(other: cxx::SharedPtr<crate::bridge_b::ffi::NewVal>) -> Result<ffi::TestResult, String> {
    if let Some(crate::bridge_b::ffi::NewVal { value, message }) = other.as_ref().cloned() {
        let result = crate::bridge_a::ffi::TestResult { ok: cxx::SharedPtr::new(crate::bridge_a::ffi::OkResult { value, message }) };
        Ok(result)
    }
    else {
        crate::bridge_a::make_result()
    }
}