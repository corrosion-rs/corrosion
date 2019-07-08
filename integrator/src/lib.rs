pub fn integrate() {
    let current_dir = std::env::current_dir().unwrap();

    println!("Current dir: {}", current_dir.to_str().unwrap());
}