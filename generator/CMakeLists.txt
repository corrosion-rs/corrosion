message(STATUS "Building CMake Generator for Corrosion - This may take a while")

set(generator_destination "${CMAKE_CURRENT_BINARY_DIR}/legacy_generator_src")
set(generator_destination "${CMAKE_CURRENT_BINARY_DIR}/legacy_generator")
set(generator_build_quiet "")

# Using cargo install has the advantage of caching the build in the user .cargo directory,
# so likely the rebuild will be very cheap even after deleting the build directory.
execute_process(
        COMMAND ${CMAKE_COMMAND}
        -E env
        # If the Generator is built at configure of a project (instead of being pre-installed)
        # We don't want environment variables like `RUSTFLAGS` affecting the Generator build.
        --unset=RUSTFLAGS
        "CARGO_BUILD_RUSTC=${RUSTC_EXECUTABLE}"
        "${CARGO_EXECUTABLE}" install
        --path "."
        --root "${generator_destination}"
        --locked
        ${_CORROSION_QUIET_OUTPUT_FLAG}
        WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
        RESULT_VARIABLE generator_build_failed
)
if(generator_build_failed)
    message(FATAL_ERROR "Building CMake Generator for Corrosion - failed")
else()
    message(STATUS "Building CMake Generator for Corrosion - done")
endif()
set(host_executable_suffix "")
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(host_executable_suffix ".exe")
endif()
set(_CORROSION_GENERATOR_EXE
        "${generator_destination}/bin/corrosion-generator${host_executable_suffix}"
        PARENT_SCOPE)
if (CORROSION_DEV_MODE)
    # If you're developing Corrosion, you want to make sure to re-configure whenever the
    # generator changes.
    file(GLOB_RECURSE _RUST_FILES CONFIGURE_DEPENDS generator/src/*.rs)
    file(GLOB _CARGO_FILES CONFIGURE_DEPENDS generator/Cargo.*)
    set_property(
            DIRECTORY APPEND
            PROPERTY CMAKE_CONFIGURE_DEPENDS
            ${_RUST_FILES} ${_CARGO_FILES})
endif()

