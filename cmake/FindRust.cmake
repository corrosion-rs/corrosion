cmake_minimum_required(VERSION 3.12)

# search for Cargo here and set up a bunch of cool flags and stuff
include(FindPackageHandleStandardArgs)

# Falls back to the rustup proxies if a toolchain cannot be found in the user's path
find_program(RUSTC_EXECUTABLE rustc PATHS $ENV{HOME}/.cargo/bin)

# Check if the discovered cargo is actually a "rustup" proxy.
execute_process(
    COMMAND
        ${CMAKE_COMMAND} -E env
            RUSTUP_FORCE_ARG0=rustup
        ${RUSTC_EXECUTABLE} --version
    OUTPUT_VARIABLE RUSTC_VERSION_RAW
)

# Discover what toolchains are installed by rustup
if (RUSTC_VERSION_RAW MATCHES "rustup [0-9\\.]+")
    set(FOUND_PROXIES ON)

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -E env
                RUSTUP_FORCE_ARG0=rustup
            ${RUSTC_EXECUTABLE} toolchain list --verbose
        OUTPUT_VARIABLE TOOLCHAINS_RAW
    )

    # We don't need RUSTC_EXECUTABLE anymore
    unset(RUSTC_EXECUTABLE CACHE)

    string(REPLACE "\n" ";" TOOLCHAINS_RAW "${TOOLCHAINS_RAW}")

    foreach(TOOLCHAIN_RAW ${TOOLCHAINS_RAW})
        if (TOOLCHAIN_RAW MATCHES "([a-zA-Z0-9\\._\\-]+)([ \t\r\n]+\\(default\\))?[ \t\r\n]+(.+)")
            set(TOOLCHAIN "${CMAKE_MATCH_1}")
            list(APPEND DISCOVERED_TOOLCHAINS ${TOOLCHAIN})

            set(${TOOLCHAIN}_PATH "${CMAKE_MATCH_3}")

            if (CMAKE_MATCH_2)
                set(TOOLCHAIN_DEFAULT ${TOOLCHAIN})
            endif()
        else()
            message(WARNING "Didn't reconize toolchain: ${TOOLCHAIN_RAW}")
        endif()
    endforeach()

    set(RUSTUP_TOOLCHAIN ${TOOLCHAIN_DEFAULT} CACHE STRING "The rustup toolchain to use")
else()
    set(FOUND_PROXIES OFF)
endif()

# Resolve to the concrete toolchain if a proxy is found, otherwise use the provided executable
if (FOUND_PROXIES)
    if (RUSTUP_TOOLCHAIN)
        if (NOT RUSTUP_TOOLCHAIN IN_LIST DISCOVERED_TOOLCHAINS)
            message(NOTICE "Could not find toolchain '${RUSTUP_TOOLCHAIN}'")
            message(NOTICE "Available toolchains:")

            list(APPEND CMAKE_MESSAGE_INDENT "  ")
            foreach(TOOLCHAIN ${DISCOVERED_TOOLCHAINS})
                message(NOTICE "${TOOLCHAIN}")
            endforeach()
            list(POP_BACK CMAKE_MESSAGE_INDENT)

            message(FATAL_ERROR "")
        endif()
    endif()

    unset(RUSTC_EXECUTABLE CACHE)

    set(RUST_TOOLCHAIN_PATH "${${RUSTUP_TOOLCHAIN}_PATH}")

    find_program(
        RUSTC_EXECUTABLE
        rustc
            HINTS "${RUST_TOOLCHAIN_PATH}/bin"
            NO_DEFAULT_PATH)
else()
    get_filename_component(RUST_TOOLCHAIN_PATH ${RUSTC_EXECUTABLE}    DIRECTORY)
    get_filename_component(RUST_TOOLCHAIN_PATH ${RUST_TOOLCHAIN_PATH} DIRECTORY)
endif()

# Look for Cargo next to rustc.
# If you want to use a different cargo, explicitly set the CARGO_EXECUTABLE cache variable
find_program(
    CARGO_EXECUTABLE
    cargo
        HINTS "${RUST_TOOLCHAIN_PATH}/bin"
        REQUIRED NO_DEFAULT_PATH)

set(CARGO_RUST_FLAGS "" CACHE STRING "Flags to pass to rustc")
set(CARGO_RUST_FLAGS_DEBUG "" CACHE STRING
    "Flags to pass to rustc in Debug Configuration")
set(CARGO_RUST_FLAGS_RELEASE "" CACHE STRING
    "Flags to pass to rustc in Release Configuration")
set(CARGO_RUST_FLAGS_MINSIZEREL -C opt-level=z CACHE STRING
    "Flags to pass to rustc in MinSizeRel Configuration")
set(CARGO_RUST_FLAGS_RELWITHDEBINFO -g CACHE STRING
    "Flags to pass to rustc in RelWithDebInfo Configuration")

execute_process(
    COMMAND ${CARGO_EXECUTABLE} --version --verbose
    OUTPUT_VARIABLE CARGO_VERSION_RAW)

if (CARGO_VERSION_RAW MATCHES "cargo ([0-9]+)\\.([0-9]+)\\.([0-9]+)")
    set(CARGO_VERSION_MAJOR "${CMAKE_MATCH_1}")
    set(CARGO_VERSION_MINOR "${CMAKE_MATCH_2}")
    set(CARGO_VERSION_PATCH "${CMAKE_MATCH_3}")
    set(CARGO_VERSION "${CARGO_VERSION_MAJOR}.${CARGO_VERSION_MINOR}.${CARGO_VERSION_PATCH}")
else()
    message(
        FATAL_ERROR
        "Failed to parse cargo version. `cargo --version` evaluated to (${CARGO_VERSION_RAW})")
endif()

execute_process(
    COMMAND ${RUSTC_EXECUTABLE} --version --verbose
    OUTPUT_VARIABLE RUSTC_VERSION_RAW)

if (RUSTC_VERSION_RAW MATCHES "rustc ([0-9]+)\\.([0-9]+)\\.([0-9]+)")
    set(RUSTC_VERSION_MAJOR "${CMAKE_MATCH_1}")
    set(RUSTC_VERSION_MINOR "${CMAKE_MATCH_2}")
    set(RUSTC_VERSION_PATCH "${CMAKE_MATCH_3}")
    set(RUSTC_VERSION "${RUSTC_VERSION_MAJOR}.${RUSTC_VERSION_MINOR}.${RUSTC_VERSION_PATCH}")
else()
    message(
        FATAL_ERROR
        "Failed to parse rustc version. `rustc --version --verbose` evaluated to:\n${RUSTC_VERSION_RAW}")
endif()

set(RUST_VERSION ${RUSTC_VERSION})

if (NOT CARGO_TARGET)
    if (WIN32)
        if (CMAKE_VS_PLATFORM_NAME)
            if ("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "Win32")
                set(CARGO_ARCH i686 CACHE STRING "Build for 32-bit x86")
            elseif("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "x64")
                set(CARGO_ARCH x86_64 CACHE STRING "Build for 64-bit x86")
            elseif("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "ARM64")
                set(CARGO_ARCH aarch64 CACHE STRING "Build for 64-bit ARM")
            else()
                message(WARNING "VS Platform '${CMAKE_VS_PLATFORM_NAME}' not recognized")
            endif()
        else ()
            if (CMAKE_SIZEOF_VOID_P EQUAL 8)
                set(CARGO_ARCH x86_64 CACHE STRING "Build for 64-bit x86")
            else()
                set(CARGO_ARCH i686 CACHE STRING "Build for 32-bit x86")
            endif()
        endif()

        set(CARGO_VENDOR "pc-windows" CACHE STRING "Build for Microsoft Windows")

        if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
            set(CARGO_ABI gnu CACHE STRING "Build for linking with GNU")
        else()
            set(CARGO_ABI msvc CACHE STRING "Build for linking with MSVC")
        endif()

        set(CARGO_TARGET "${CARGO_ARCH}-${CARGO_VENDOR}-${CARGO_ABI}"
            CACHE STRING "Windows Target")
    elseif (RUSTC_VERSION_RAW MATCHES "host: ([a-zA-Z0-9_\\-]*)\n")
        set(CARGO_TARGET "${CMAKE_MATCH_1}" CACHE STRING "Default Host Target")
    else()
        message(
            FATAL_ERROR
            "Failed to parse rustc host target. `rustc --version --verbose` evaluated to:\n${RUSTC_VERSION_RAW}"
        )
    endif()

    message(STATUS "Rust Target: ${CARGO_TARGET}")
endif()

find_package_handle_standard_args(
    Rust
    REQUIRED_VARS RUSTC_EXECUTABLE CARGO_EXECUTABLE CARGO_TARGET
    VERSION_VAR RUST_VERSION)

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

    get_filename_component(_moddir ${CMAKE_CURRENT_LIST_FILE} DIRECTORY)
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
