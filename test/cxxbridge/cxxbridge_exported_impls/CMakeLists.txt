cmake_minimum_required(VERSION 3.24)
project(test_project VERSION 0.1.0 LANGUAGES CXX)
include(../../test_header.cmake)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED 1)

corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)
corrosion_add_cxxbridge(cxxbridge
    CRATE rust_lib
    FILES
        bridge_a.rs
        bridge_b.rs
        lib.rs
)

if(MSVC)
    set_target_properties(cxxbridge PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
endif()

add_executable(test_main
    main.cpp
)

target_link_libraries(test_main
    cxxbridge
)