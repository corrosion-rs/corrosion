pub fn is_corrosion_build() -> bool {
    std::env::var("CORROSION_BUILD_DIR").is_ok()
}

pub fn build_script() {
    if !is_corrosion_build() {
        panic!("CORROSION_BUILD_DIR environment variable not set - build must be initiated from CMake.")
    }

    let search_dirs: Vec<_> = std::env::var("CORROSION_LINK_DIRECTORIES")
        .iter()
        .flat_map(|v| v.split(':').map(std::string::ToString::to_string))
        .collect();

    let libraries: Vec<_> = std::env::var("CORROSION_LINK_LIBRARIES")
        .iter()
        .flat_map(|v| v.split(':').map(std::string::ToString::to_string))
        .collect();

    for dir in &search_dirs {
        // can be eliminated if we directly add the rustflag "-L<dir>".
        println!("cargo:rustc-link-search={}", dir);
    }

    for library in &libraries {
        // can be eliminated if we directly add the rustflag "-l<library>".
        println!("cargo:rustc-link-lib={}", library);
    }
}
