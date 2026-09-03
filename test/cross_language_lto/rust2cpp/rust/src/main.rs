extern "C" {
    fn cpp_add(a: u32, b: u32) -> u32;
}

fn main() {
    let sum = unsafe { cpp_add(40, 2) };
    if sum != 42 {
        println!("FAIL");
        std::process::exit(1);
    }
    println!("Ok");
}
