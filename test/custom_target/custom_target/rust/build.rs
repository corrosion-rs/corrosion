fn main() {
    let mut builder = cc::Build::new();
    // We override the target here, purely to make the testcase simpler.
    // In a real-world project, the custom rust .json target triple file
    // should have a filename matching the target-triple the c-compiler understands
    // (if the c/c++ toolchain is llvm based)
    builder.target(&std::env::var("HOST").unwrap());

    builder.file("c_lib.c").compile("custom_target");
}