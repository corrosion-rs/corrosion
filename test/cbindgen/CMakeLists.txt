# cmake_minimum_required(VERSION 3.15)
# project(Corrosion VERSION 0.2.0 LANGUAGES NONE)
# include(FetchContent)

# FetchContent_Declare(
#     Corrosion
#     GIT_REPOSITORY https://github.com/corrosion-rs/corrosion.git
#     GIT_TAG v0.2.1 # Optionally specify a commit hash, version tag or branch here
# )

# FetchContent_MakeAvailable(Corrosion)

corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)

add_executable(cbindgen-cpp-exe main.cpp)
target_link_libraries(cbindgen-cpp-exe PUBLIC cbindgen-rust-lib)
target_include_directories(cbindgen-cpp-exe PRIVATE rust/include)
