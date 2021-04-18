corrosion_import_crate(MANIFEST_PATH ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml CRATES member1 member2)

#NOTE: member3 also constains a binary called my_program, but that shouldn't be a problem since it is not imported
add_executable(my_program main.cpp)
target_link_libraries(my_program PUBLIC member1 member2)
