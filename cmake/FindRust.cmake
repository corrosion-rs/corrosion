cmake_minimum_required(VERSION 3.12)

# search for Cargo here and set up a bunch of cool flags and stuff
include(FindPackageHandleStandardArgs)

if (NOT "${Rust_TOOLCHAIN}" STREQUAL "$CACHE{Rust_TOOLCHAIN}")
    # Promote Rust_TOOLCHAIN to a cache variable if it is not already a cache variable
    set(Rust_TOOLCHAIN ${Rust_TOOLCHAIN} CACHE STRING "Requested rustup toolchain" FORCE)
endif()

# This block checks to see if we're prioritizing a rustup-managed toolchain.
if (DEFINED Rust_TOOLCHAIN)
    # If the user changes the Rust_TOOLCHAIN, then we should re-evaluate all cache variables
    if (NOT Rust_TOOLCHAIN STREQUAL _Rust_TOOLCHAIN_CACHED)
        unset(Rust_CARGO CACHE)
        unset(Rust_COMPILER CACHE)
        unset(Rust_CARGO_TARGET CACHE)
        unset(_Rust_TOOLCHAIN_CACHED CACHE)
    endif()

    # If the user specifies `Rust_TOOLCHAIN`, then look for `rustup` first, rather than `rustc`.
    find_program(Rust_RUSTUP rustup PATHS $ENV{HOME}/.cargo/bin)
    if (NOT Rust_RUSTUP)
        message(
            WARNING "CMake variable `Rust_TOOLCHAIN` specified, but `rustup` was not found. "
            "Ignoring toolchain and looking for a Rust toolchain not managed by rustup.")
    else()
        set(_RESOLVE_RUSTUP_TOOLCHAINS ON)
    endif()
else()
    # Even if we failed to find rustup in the previous branch - it's safe to skip this step

    # If we aren't definitely using a rustup toolchain, look for rustc first - the user may have
    # a toolchain installed via a method other than rustup higher in the PATH, which should be
    # preferred. However, if the first-found rustc is a rustup proxy, then we'll revert to
    # finding the preferred toolchain via rustup.

    # Falls back to the rustup proxies in $HOME/.cargo/bin if a toolchain cannot be found in the
    # user's PATH.
    find_program(Rust_COMPILER rustc PATHS $ENV{HOME}/.cargo/bin)

    # Check if the discovered cargo is actually a "rustup" proxy.
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -E env
                RUSTUP_FORCE_ARG0=rustup
            ${Rust_COMPILER} --version
        OUTPUT_VARIABLE _RUSTC_VERSION_RAW
    )

    if (_RUSTC_VERSION_RAW MATCHES "rustup [0-9\\.]+")
        set(_RESOLVE_RUSTUP_TOOLCHAINS ON)
        
        # Get `rustup` next to the `rustc` proxy
        get_filename_component(_RUST_PROXIES_PATH ${Rust_COMPILER} DIRECTORY)
        find_program(Rust_RUSTUP rustup HINTS ${_RUST_PROXIES_PATH}/bin)

        # Throw out Rust_COMPILER if it was a proxy
        unset(Rust_COMPILER CACHE)
    endif()
endif()


# Discover what toolchains are installed by rustup, if the discovered `rustc` is a proxy from
# `rustup`, and select either the default toolchain, or the requested toolchain Rust_TOOLCHAIN
if (_RESOLVE_RUSTUP_TOOLCHAINS)
    execute_process(
        COMMAND
            ${Rust_RUSTUP} toolchain list --verbose
        OUTPUT_VARIABLE _TOOLCHAINS_RAW
    )

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

    if (NOT DEFINED Rust_TOOLCHAIN)
        message(STATUS "Rust Toolchain: ${_TOOLCHAIN_DEFAULT}")
    endif()
    set(Rust_TOOLCHAIN ${_TOOLCHAIN_DEFAULT} CACHE STRING "The rustup toolchain to use")

    if (NOT Rust_TOOLCHAIN IN_LIST _DISCOVERED_TOOLCHAINS)
        # If the precise toolchain wasn't found, try appending the default host 
        execute_process(
            COMMAND
                ${Rust_RUSTUP} show
            OUTPUT_VARIABLE _SHOW_RAW
        )

        if (_SHOW_RAW MATCHES "Default host: ([a-zA-Z0-9_\\-]*)\n")
            set(_DEFAULT_HOST "${CMAKE_MATCH_1}")
        else()
            message(FATAL_ERROR "Failed to parse \"Default host\" from `${Rust_RUSTUP} show`. Got: ${_SHOW_RAW}")
        endif()

        if (NOT "${Rust_TOOLCHAIN}-${_DEFAULT_HOST}" IN_LIST _DISCOVERED_TOOLCHAINS)
            message(NOTICE "Could not find toolchain '${Rust_TOOLCHAIN}'")
            message(NOTICE "Available toolchains:")

            list(APPEND CMAKE_MESSAGE_INDENT "  ")
            foreach(_TOOLCHAIN ${_DISCOVERED_TOOLCHAINS})
                message(NOTICE "${_TOOLCHAIN}")
            endforeach()
            list(POP_BACK CMAKE_MESSAGE_INDENT)

            message(FATAL_ERROR "")
        endif()
        
        set(_RUSTUP_TOOLCHAIN_FULL "${Rust_TOOLCHAIN}-${_DEFAULT_HOST}")
    else()
        set(_RUSTUP_TOOLCHAIN_FULL "${Rust_TOOLCHAIN}")
    endif()

    unset(Rust_COMPILER CACHE)

    set(_Rust_TOOLCHAIN_CACHED ${Rust_TOOLCHAIN} CACHE INTERNAL "The active Rust toolchain")

    set(_RUST_TOOLCHAIN_PATH "${${_RUSTUP_TOOLCHAIN_FULL}_PATH}")

    find_program(
        Rust_COMPILER
        rustc
            HINTS "${_RUST_TOOLCHAIN_PATH}/bin"
            NO_DEFAULT_PATH)
else()
    get_filename_component(_RUST_TOOLCHAIN_PATH ${Rust_COMPILER}        DIRECTORY)
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
                set(_CARGO_ARCH i686)
            elseif("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "x64")
                set(_CARGO_ARCH x86_64)
            elseif("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "ARM64")
                set(_CARGO_ARCH aarch64)
            else()
                message(WARNING "VS Platform '${CMAKE_VS_PLATFORM_NAME}' not recognized")
            endif()
        else ()
            if (NOT DEFINED CMAKE_SIZEOF_VOID_P)
                message(
                    FATAL_ERROR "Compiler hasn't been enabled yet - can't determine the target architecture")
            endif()

            if (CMAKE_SIZEOF_VOID_P EQUAL 8)
                set(_CARGO_ARCH x86_64)
            else()
                set(_CARGO_ARCH i686)
            endif()
        endif()

        set(_CARGO_VENDOR "pc-windows")

        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            set(_CARGO_ABI gnu)
        else()
            set(_CARGO_ABI msvc)
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
