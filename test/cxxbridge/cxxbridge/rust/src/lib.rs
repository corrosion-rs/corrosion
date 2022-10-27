mod foo;

#[cxx::bridge(namespace = "lib")]
mod bridge {
    extern "Rust" {
        fn print();
    }
}

fn print() {
    println!("Hello cxxbridge from lib.rs!");
}
