cmake_minimum_required(VERSION 3.12)

add_subdirectory(rust)

add_executable(cpp-exe main.cpp)
target_link_libraries(cpp-exe PUBLIC rust-lib)
target_include_directories(cpp-exe PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/rust/src)
