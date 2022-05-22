cmake_minimum_required(VERSION 3.15)
find_package(Corrosion REQUIRED CMAKE_FIND_ROOT_PATH_BOTH)

add_custom_command(
	OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/src/foo.rs
	DEPENDS $<TARGET_FILE:srcgen>
	COMMAND $<TARGET_FILE:srcgen> ${CMAKE_CURRENT_SOURCE_DIR}/src/foo.rs
)

add_custom_target(after_generation DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/foo.rs)
add_custom_target(genexdebug COMMAND ${CMAKE_COMMAND} -E echo "Config DEBUG: $<TARGET_PROPERTY:srcgen,IMPORTED_LOCATION_DEBUG> Config Release: $<TARGET_PROPERTY:srcgen,IMPORTED_LOCATION_RELEASE> IMPORTED_LOCATION: $<TARGET_PROPERTY:srcgen,IMPORTED_LOCATION>")

corrosion_import_crate(MANIFEST_PATH ${CMAKE_CURRENT_SOURCE_DIR}/Cargo.toml)
add_dependencies(cargo-build_generated after_generation)
