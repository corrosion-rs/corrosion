cmake_minimum_required(VERSION 3.22)
project(crubit_incremental LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 20)
set(CORROSION_BUILD_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory("${CORROSION_SOURCE_DIR}" corrosion)

corrosion_experimental_crubit(incremental)
corrosion_import_crate(MANIFEST_PATH Cargo.toml)

add_executable(main main.cpp)
target_link_libraries(main PRIVATE incremental)
add_executable(dependency_only dependency.cpp)
target_link_libraries(dependency_only PRIVATE incremental)
