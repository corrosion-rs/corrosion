corrosion_import_crate(MANIFEST_PATH ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml)

add_library(cpp-lib4 lib.cpp)
target_compile_features(cpp-lib4 PRIVATE cxx_std_14)
corrosion_link_libraries(bin1 cpp-lib4)
corrosion_link_libraries(bin2 cpp-lib4)
corrosion_link_libraries(bin3 cpp-lib4)
