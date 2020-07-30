cmake_minimum_required(VERSION 3.12)

# search for Cargo here and set up a bunch of cool flags and stuff
include(FindPackageHandleStandardArgs)

# Falls back to the rustup proxies if a toolchain cannot be found in the user's path
find_program(Rust_COMPILER rustc PATHS $ENV{HOME}/.cargo/bin)

# Check if the discovered cargo is actually a "rustup" proxy.
execute_process(
    COMMAND
        ${CMAKE_COMMAND} -E env
            RUSTUP_FORCE_ARG0=rustup
        ${Rust_COMPILER} --version
    OUTPUT_VARIABLE _RUSTC_VERSION_RAW
)

# Discover what toolchains are installed by rustup
if (_RUSTC_VERSION_RAW MATCHES "rustup [0-9\\.]+")
    set(_FOUND_PROXIES ON)

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -E env
                RUSTUP_FORCE_ARG0=rustup
            ${Rust_COMPILER} toolchain list --verbose
        OUTPUT_VARIABLE _TOOLCHAINS_RAW
    )

    # We don't need Rust_COMPILER anymore
    unset(Rust_COMPILER CACHE)

    string(REPLACE "\n" ";" _TOOLCHAINS_RAW "${_TOOLCHAINS_RAW}")

    foreach(_TOOLCHAIN_RAW ${_TOOLCHAINS_RAW})
        if (_TOOLCHAIN_RAW MATCHES "([a-zA-Z0-9\\._\\-]+)([ \t\r\n]+\\(default\\))?[ \t\r\n]+(.+)")
            set(_TOOLCHAIN "${CMAKE_MATCH_1}")
            list(APPEND _DISCOVERED_TOOLCHAINS ${_TOOLCHAIN})

            set(${_TOOLCHAIN}_PATH "${CMAKE_MATCH_3}")

            if (CMAKE_MATCH_2)
                set(_TOOLCHAIN_DEFAULT ${_TOOLCHAIN})
            endif()
        else()
            message(WARNING "Didn't reconize toolchain: ${_TOOLCHAIN_RAW}")
        endif()
    endforeach()

    set(RUSTUP_TOOLCHAIN ${_TOOLCHAIN_DEFAULT} CACHE STRING "The rustup toolchain to use")
else()
    set(_FOUND_PROXIES OFF)
endif()

# Resolve to the concrete toolchain if a proxy is found, otherwise use the provided executable
if (_FOUND_PROXIES)
    if (RUSTUP_TOOLCHAIN)
        if (NOT RUSTUP_TOOLCHAIN IN_LIST _DISCOVERED_TOOLCHAINS)
            message(NOTICE "Could not find toolchain '${RUSTUP_TOOLCHAIN}'")
            message(NOTICE "Available toolchains:")

            list(APPEND CMAKE_MESSAGE_INDENT "  ")
            foreach(_TOOLCHAIN ${_DISCOVERED_TOOLCHAINS})
                message(NOTICE "${_TOOLCHAIN}")
            endforeach()
            list(POP_BACK CMAKE_MESSAGE_INDENT)

            message(FATAL_ERROR "")
        endif()
    endif()

    unset(Rust_COMPILER CACHE)

    set(_RUST_TOOLCHAIN_PATH "${${RUSTUP_TOOLCHAIN}_PATH}")

    find_program(
        Rust_COMPILER
        rustc
            HINTS "${_RUST_TOOLCHAIN_PATH}/bin"
            NO_DEFAULT_PATH)
else()
    get_filename_component(_RUST_TOOLCHAIN_PATH ${Rust_COMPILER}    DIRECTORY)
    get_filename_component(_RUST_TOOLCHAIN_PATH ${_RUST_TOOLCHAIN_PATH} DIRECTORY)
endif()

# Look for Cargo next to rustc.
# If you want to use a different cargo, explicitly set the Rust_CARGO cache variable
find_program(
    Rust_CARGO
    cargo
        HINTS "${_RUST_TOOLCHAIN_PATH}/bin"
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
    COMMAND ${Rust_CARGO} --version --verbose
    OUTPUT_VARIABLE _CARGO_VERSION_RAW)

if (_CARGO_VERSION_RAW MATCHES "cargo ([0-9]+)\\.([0-9]+)\\.([0-9]+)")
    set(Rust_CARGO_VERSION_MAJOR "${CMAKE_MATCH_1}")
    set(Rust_CARGO_VERSION_MINOR "${CMAKE_MATCH_2}")
    set(Rust_CARGO_VERSION_PATCH "${CMAKE_MATCH_3}")
    set(Rust_CARGO_VERSION "${Rust_CARGO_VERSION_MAJOR}.${Rust_CARGO_VERSION_MINOR}.${Rust_CARGO_VERSION_PATCH}")
else()
    message(
        FATAL_ERROR
        "Failed to parse cargo version. `cargo --version` evaluated to (${_CARGO_VERSION_RAW})")
endif()

execute_process(
    COMMAND ${Rust_COMPILER} --version --verbose
    OUTPUT_VARIABLE _RUSTC_VERSION_RAW)

if (_RUSTC_VERSION_RAW MATCHES "rustc ([0-9]+)\\.([0-9]+)\\.([0-9]+)")
    set(Rust_VERSION_MAJOR "${CMAKE_MATCH_1}")
    set(Rust_VERSION_MINOR "${CMAKE_MATCH_2}")
    set(Rust_VERSION_PATCH "${CMAKE_MATCH_3}")
    set(Rust_VERSION "${Rust_VERSION_MAJOR}.${Rust_VERSION_MINOR}.${Rust_VERSION_PATCH}")
else()
    message(
        FATAL_ERROR
        "Failed to parse rustc version. `rustc --version --verbose` evaluated to:\n${_RUSTC_VERSION_RAW}")
endif()

if (_RUSTC_VERSION_RAW MATCHES "host: ([a-zA-Z0-9_\\-]*)\n")
    set(Rust_DEFAULT_HOST_TARGET "${CMAKE_MATCH_1}")
else()
    message(
        FATAL_ERROR
        "Failed to parse rustc host target. `rustc --version --verbose` evaluated to:\n${_RUSTC_VERSION_RAW}"
    )
endif()

if (NOT Rust_CARGO_TARGET)
    if (WIN32)
        if (CMAKE_VS_PLATFORM_NAME)
            if ("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "Win32")
                set(_CARGO_ARCH i686 CACHE STRING "Build for 32-bit x86")
            elseif("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "x64")
                set(_CARGO_ARCH x86_64 CACHE STRING "Build for 64-bit x86")
            elseif("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "ARM64")
                set(_CARGO_ARCH aarch64 CACHE STRING "Build for 64-bit ARM")
            else()
                message(WARNING "VS Platform '${CMAKE_VS_PLATFORM_NAME}' not recognized")
            endif()
        else ()
            if (CMAKE_SIZEOF_VOID_P EQUAL 8)
                set(_CARGO_ARCH x86_64 CACHE STRING "Build for 64-bit x86")
            else()
                set(_CARGO_ARCH i686 CACHE STRING "Build for 32-bit x86")
            endif()
        endif()

        set(_CARGO_VENDOR "pc-windows" CACHE STRING "Build for Microsoft Windows")

        if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
            set(_CARGO_ABI gnu CACHE STRING "Build for linking with GNU")
        else()
            set(_CARGO_ABI msvc CACHE STRING "Build for linking with MSVC")
        endif()

        set(Rust_CARGO_TARGET "${_CARGO_ARCH}-${_CARGO_VENDOR}-${_CARGO_ABI}"
            CACHE STRING "Target triple")
    else()
        set(Rust_CARGO_TARGET "${Rust_DEFAULT_HOST_TARGET}" CACHE STRING "Target triple")
    endif()

    message(STATUS "Rust Target: ${Rust_CARGO_TARGET}")
endif()

find_package_handle_standard_args(
    Rust
    REQUIRED_VARS Rust_COMPILER Rust_VERSION Rust_CARGO Rust_CARGO_VERSION Rust_CARGO_TARGET
    VERSION_VAR Rust_VERSION)

function(_gen_config config_type use_config_dir)
    string(TOUPPER "${config_type}" _UPPER_CONFIG_TYPE)

    if(use_config_dir)
        set(_DESTINATION_DIR ${CMAKE_BINARY_DIR}/${CMAKE_VS_PLATFORM_NAME}/${config_type})
    else()
        set(_DESTINATION_DIR ${CMAKE_BINARY_DIR})
    endif()

    set(_CARGO_CONFIG ${_DESTINATION_DIR}/.cargo/config)

    file(WRITE ${_CARGO_CONFIG}
"\
[build]
target-dir=\"cargo/build\"
")

    string(REPLACE ";" "\", \"" _RUSTFLAGS "${CARGO_RUST_FLAGS}" "${CARGO_RUST_FLAGS_${_UPPER_CONFIG_TYPE}}")

    if (_RUSTFLAGS)
        file(APPEND ${_CARGO_CONFIG}
            "rustflags = [\"${_RUSTFLAGS}\"]\n")
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

add_executable(Rust::Rustc IMPORTED GLOBAL)
set_property(
    TARGET Rust::Rustc
    PROPERTY IMPORTED_LOCATION ${Rust_COMPILER}
)

add_executable(Rust::Cargo IMPORTED GLOBAL)
set_property(
    TARGET Rust::Cargo
    PROPERTY IMPORTED_LOCATION ${Rust_CARGO}
)
