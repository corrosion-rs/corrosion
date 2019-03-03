cmake_minimum_required(VERSION 3.10)

# search for Cargo here and set up a bunch of cool flags and stuff
include(ExternalProject)

find_program(CARGO
    cargo
    HINTS $ENV{HOME}/.cargo/bin)

message(STATUS "Found Cargo: ${CARGO}")

set(CARGO_BUILD_FLAGS "" CACHE STRING "Flags to pass to cargo build")
set(CARGO_BUILD_FLAGS_DEBUG "" CACHE STRING
    "Flags to pass to cargo build in Debug configuration")
set(CARGO_BUILD_FLAGS_RELEASE --release CACHE STRING
    "Flags to pass to cargo build in Release configuration")
set(CARGO_BUILD_FLAGS_MINSIZEREL --release CACHE STRING
    "Flags to pass to cargo build in MinSizeRel configuration")
set(CARGO_BUILD_FLAGS_RELWITHDEBINFO --release CACHE STRING
    "Flags to pass to cargo build in RelWithDebInfo configuration")

set(CARGO_RUST_FLAGS "" CACHE STRING "Flags to pass to rustc")
set(CARGO_RUST_FLAGS_DEBUG "" CACHE STRING
    "Flags to pass to rustc in Debug Configuration")
set(CARGO_RUST_FLAGS_RELEASE "" CACHE STRING
    "Flags to pass to rustc in Release Configuration")
set(CARGO_RUST_FLAGS_MINSIZEREL -C opt-level=z CACHE STRING
    "Flags to pass to rustc in MinSizeRel Configuration")
set(CARGO_RUST_FLAGS_RELWITHDEBINFO -g CACHE STRING
    "Flags to pass to rustc in RelWithDebInfo Configuration")
    
if (WIN32)
    set(CARGO_BUILD_SCRIPT cargo_build.cmd)
    set(CARGO_BUILD ${CARGO_BUILD_SCRIPT})
else()
    set(CARGO_BUILD_SCRIPT cargo_build.sh)
    set(CARGO_BUILD ./${CARGO_BUILD_SCRIPT})
endif()

set(CARGO_TARGET "" CACHE STRING "The target triple to build for")

function(_gen_config config_type use_config_dir)
    string(TOUPPER "${config_type}" UPPER_CONFIG_TYPE)

    if(use_config_dir)
        set(_DESTINATION_DIR ${CMAKE_BINARY_DIR}/${CMAKE_VS_PLATFORM_NAME}/${config_type})
    else()
        set(_DESTINATION_DIR ${CMAKE_BINARY_DIR})
    endif()

    set(CARGO_CONFIG ${_DESTINATION_DIR}/.cargo/config)

    file(WRITE ${CARGO_CONFIG}
"\
[build]
target-dir=\"cargo/build\"
")

    string(REPLACE ";" "\", \"" RUSTFLAGS "${CARGO_RUST_FLAGS}" "${CARGO_RUST_FLAGS_${UPPER_CONFIG_TYPE}}")

    if (RUSTFLAGS)
        file(APPEND ${CARGO_CONFIG}
            "rustflags = [\"${RUSTFLAGS}\"]\n")
    endif()

    if (CARGO_TARGET)
        set(CARGO_BUILD_FLAGS ${CARGO_BUILD_FLAGS} --target ${CARGO_TARGET})
    endif()

    string(REPLACE ";" " " _CARGO_BUILD_FLAGS
        "${CARGO_BUILD_FLAGS} ${CARGO_BUILD_FLAGS_${UPPER_CONFIG_TYPE}}")

    get_filename_component(_moddir ${CMAKE_CURRENT_LIST_FILE} DIRECTORY)

    configure_file(
        ${_moddir}/cmds/${CARGO_BUILD_SCRIPT}.in
        ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${CARGO_BUILD_SCRIPT})

    file(COPY ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${CARGO_BUILD_SCRIPT}
        DESTINATION ${_DESTINATION_DIR}
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ
        GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endfunction(_gen_config)

if (CMAKE_CONFIGURATION_TYPES)
    foreach(config_type ${CMAKE_CONFIGURATION_TYPES})
        _gen_config(${config_type} ON)
    endforeach()
elseif(CMAKE_BUILD_TYPE)
    _gen_config(${CMAKE_BUILD_TYPE} OFF)
else()
    message(STATUS "Defaulting Cargo to build debug")
    _gen_config(Debug OFF)
endif()

function(add_cargo_build target_name path_to_toml)
    if (NOT IS_ABSOLUTE "${path_to_toml}")
        set(path_to_toml "${CMAKE_SOURCE_DIR}/${path_to_toml}")
    endif()

    if (CMAKE_VS_PLATFORM_NAME)
        set (build_dir "${CMAKE_VS_PLATFORM_NAME}/$<CONFIG>")
    elseif(CMAKE_CONFIGURATION_TYPES)
        set (build_dir "$<CONFIG>")
    else()
        set (build_dir .)
    endif()

    ExternalProject_Add(
        ${target_name}
        DOWNLOAD_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ${CMAKE_COMMAND} -E chdir ${build_dir} ${CARGO_BUILD} --manifest-path ${path_to_toml}
        BINARY_DIR "${CMAKE_BINARY_DIR}"
        INSTALL_COMMAND ""
        PREFIX cargo
        BUILD_ALWAYS ON
    )
endfunction()