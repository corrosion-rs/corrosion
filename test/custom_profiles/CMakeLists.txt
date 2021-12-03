set(_release_profile $<IF:$<CONFIG:Release>,release-without-dbg,custom-without-dbg>)
set(custom_profile $<IF:$<CONFIG:Debug>,dev-without-dbg,${_release_profile}>)

corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml PROFILE ${custom_profile})

add_executable(custom-profile-exe main.cpp)
target_link_libraries(custom-profile-exe PUBLIC custom-profiles-lib)
