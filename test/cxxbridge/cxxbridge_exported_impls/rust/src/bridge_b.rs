#[cxx::bridge]
pub mod ffi {

    #[derive(Clone)]
    pub struct NewVal {
        pub value: bool,
        pub message: String,
    }

    impl SharedPtr<NewVal> {}

    extern "Rust" {
        fn make_new_val() -> SharedPtr<NewVal>;
    }
}

pub fn make_new_val() -> cxx::SharedPtr<ffi::NewVal> {
    let now = std::time::Instant::now();
    let ok = ffi::NewVal { value: true, message: format!("{:#?}", now)};
    cxx::SharedPtr::new(ok)
}