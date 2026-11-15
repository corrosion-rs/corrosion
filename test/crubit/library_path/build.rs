use std::{env, path::PathBuf};

fn main() {
    let variable = if cfg!(windows) {
        "PATH"
    } else if cfg!(target_os = "macos") {
        "DYLD_LIBRARY_PATH"
    } else {
        "LD_LIBRARY_PATH"
    };
    let expected = PathBuf::from(env::var_os("CORROSION_TEST_LIBRARY_DIR").unwrap());
    let paths = env::var_os(&variable).unwrap_or_default();
    assert!(
        env::split_paths(&paths).any(|path| path == expected),
        "Crubit dropped the caller's library directory from {variable}: {paths:?}"
    );
    println!("cargo:rerun-if-env-changed={variable}");
    println!("cargo:rerun-if-env-changed=CORROSION_TEST_LIBRARY_DIR");
}
