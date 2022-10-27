#[cxx::bridge(namespace = "foo")]
mod bridge {
    extern "Rust" {
        fn print();
    }
}

fn print() {
    println!("Hello cxxbridge from foo/mod.rs!");
}
