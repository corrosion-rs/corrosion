cmake_minimum_required(VERSION 3.12)

# search for Cargo here and set up a bunch of cool flags and stuff
include(FindPackageHandleStandardArgs)

if (NOT "${Rust_TOOLCHAIN}" STREQUAL "$CACHE{Rust_TOOLCHAIN}")
    # Promote Rust_TOOLCHAIN to a cache variable if it is not already a cache variable
    set(Rust_TOOLCHAIN ${Rust_TOOLCHAIN} CACHE STRING "Requested rustup toolchain" FORCE)
endif()

# This block checks to see if we're prioritizing a rustup-managed toolchain.
if (DEFINED Rust_TOOLCHAIN)
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
    # If we aren't definitely using a rustup toolchain, look for rustc first - the user may have
    # a toolchain installed via a method other than rustup higher in the PATH, which should be
    # preferred. However, if the first-found rustc is a rustup proxy, then we'll revert to
    # finding the preferred toolchain via rustup.

    # Uses `Rust_COMPILER` to let user-specified `rustc` win. But we will still "override" the
    # user's setting if it is pointing to `rustup`. Default rustup install path is provided as a
    # backup if a toolchain cannot be found in the user's PATH.

    if (DEFINED Rust_COMPILER)
        set(_Rust_COMPILER_TEST ${Rust_COMPILER})
        set(_USER_SPECIFIED_RUSTC ON)
    else()
        find_program(_Rust_COMPILER_TEST rustc PATHS $ENV{HOME}/.cargo/bin)
    endif()

    # Check if the discovered rustc is actually a "rustup" proxy.
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -E env
                RUSTUP_FORCE_ARG0=rustup
            ${_Rust_COMPILER_TEST} --version
        OUTPUT_VARIABLE _RUSTC_VERSION_RAW
    )

    if (_RUSTC_VERSION_RAW MATCHES "rustup [0-9\\.]+")
        if (_USER_SPECIFIED_RUSTC)
            message(
                WARNING "User-specified Rust_COMPILER pointed to rustup's rustc proxy. Corrosion's "
                "FindRust will always try to evaluate to an actual Rust toolchain, and so the "
                "user-specified Rust_COMPILER will be discarded in favor of the default "
                "rustup-managed toolchain."
            )

            unset(Rust_COMPILER)
            unset(Rust_COMPILER CACHE)
        endif()

        set(_RESOLVE_RUSTUP_TOOLCHAINS ON)

        # Get `rustup` next to the `rustc` proxy
        get_filename_component(_RUST_PROXIES_PATH ${_Rust_COMPILER_TEST} DIRECTORY)
        find_program(Rust_RUSTUP rustup HINTS ${_RUST_PROXIES_PATH} NO_DEFAULT_PATH)
    endif()

    unset(_Rust_COMPILER_TEST CACHE)
endif()

# At this point, the only thing we should have evaluated is a path to `rustup` _if that's what the
# best source for a Rust toolchain was determined to be_.

# List of user variables that will override any toolchain-provided setting
set(_Rust_USER_VARS Rust_COMPILER Rust_CARGO Rust_CARGO_TARGET Rust_CARGO_HOST_TARGET)
foreach(_VAR ${_Rust_USER_VARS})
    if (DEFINED ${_VAR})
        set(${_VAR}_CACHED ${${_VAR}} CACHE INTERNAL "Internal cache of ${_VAR}")
    else()
        unset(${_VAR}_CACHED CACHE)
    endif()
endforeach()

# Discover what toolchains are installed by rustup, if the discovered `rustc` is a proxy from
# `rustup`, then select either the default toolchain, or the requested toolchain Rust_TOOLCHAIN
if (_RESOLVE_RUSTUP_TOOLCHAINS)
    execute_process(
        COMMAND
            ${Rust_RUSTUP} toolchain list --verbose
        OUTPUT_VARIABLE _TOOLCHAINS_RAW
    )

    string(REPLACE "\n" ";" _TOOLCHAINS_RAW "${_TOOLCHAINS_RAW}")

    foreach(_TOOLCHAIN_RAW ${_TOOLCHAINS_RAW})
        if (_TOOLCHAIN_RAW MATCHES "([a-zA-Z0-9\\._\\-]+)[ \t\r\n]?(\\(default\\) \\(override\\)|\\(default\\)|\\(override\\))?[ \t\r\n]+(.+)")
            set(_TOOLCHAIN "${CMAKE_MATCH_1}")
            set(_TOOLCHAIN_TYPE ${CMAKE_MATCH_2})
            list(APPEND _DISCOVERED_TOOLCHAINS ${_TOOLCHAIN})

            set(${_TOOLCHAIN}_PATH "${CMAKE_MATCH_3}")

            if (_TOOLCHAIN_TYPE MATCHES ".*\\(default\\).*")
                set(_TOOLCHAIN_DEFAULT ${_TOOLCHAIN})
            endif()

            if (_TOOLCHAIN_TYPE MATCHES ".*\\(override\\).*")
                set(_TOOLCHAIN_OVERRIDE ${_TOOLCHAIN})
            endif()
        else()
            message(WARNING "Didn't recognize toolchain: ${_TOOLCHAIN_RAW}")
        endif()
    endforeach()

    if (NOT DEFINED Rust_TOOLCHAIN)
        if (NOT DEFINED _TOOLCHAIN_OVERRIDE)
            set(_TOOLCHAIN_SELECTED ${_TOOLCHAIN_DEFAULT})
        else()
            set(_TOOLCHAIN_SELECTED ${_TOOLCHAIN_OVERRIDE})
        endif()
    endif()
    set(Rust_TOOLCHAIN ${_TOOLCHAIN_SELECTED} CACHE STRING "The rustup toolchain to use")
    message(STATUS "Rust Toolchain: ${Rust_TOOLCHAIN}")

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

    set(_RUST_TOOLCHAIN_PATH "${${_RUSTUP_TOOLCHAIN_FULL}_PATH}")
    message(VERBOSE "Rust toolchain ${_RUSTUP_TOOLCHAIN_FULL}")
    message(VERBOSE "Rust toolchain path ${_RUST_TOOLCHAIN_PATH}")

    # Is overridden if the user specifies `Rust_COMPILER` explicitly.
    find_program(
        Rust_COMPILER_CACHED
        rustc
            HINTS "${_RUST_TOOLCHAIN_PATH}/bin"
            NO_DEFAULT_PATH)
else()
    find_program(Rust_COMPILER_CACHED rustc)
    if (Rust_COMPILER_CACHED)
        get_filename_component(_RUST_TOOLCHAIN_PATH ${Rust_COMPILER_CACHED} DIRECTORY)
        get_filename_component(_RUST_TOOLCHAIN_PATH ${_RUST_TOOLCHAIN_PATH} DIRECTORY)
    endif()
endif()

if (NOT Rust_COMPILER_CACHED)
    message(
        WARNING "The rustc executable was not found. "
        "Rust not installed or ~/.cargo/bin not added to path? "
        "Aborting further actions of find_package(Rust). ")
    set(Rust_FOUND false)
    return()
endif()

if (_RESOLVE_RUSTUP_TOOLCHAINS)
    # If not already explicitly set by the `Rust_CARGO` variable, search for cargo next to rustc,
    # since the toolchain is managed by rustup.
    # Note: Not all toolchains managed by rustup have `cargo` installed. Specifically, a custom
    # toolchain may not have had cargo built. In this case the user should manually specify
    # `Rust_CARGO`.
    find_program(
        Rust_CARGO_CACHED
        cargo
            HINTS "${_RUST_TOOLCHAIN_PATH}/bin"
            REQUIRED NO_DEFAULT_PATH)
else()
    # On some systems (e.g. NixOS) cargo is not managed by rustup and also not next to rustc.
    find_program(
            Rust_CARGO_CACHED
            cargo
                HINTS "${_RUST_TOOLCHAIN_PATH}/bin"
                REQUIRED)
endif()

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
    COMMAND ${Rust_CARGO_CACHED} --version --verbose
    OUTPUT_VARIABLE _CARGO_VERSION_RAW)

if (_CARGO_VERSION_RAW MATCHES "cargo ([0-9]+)\\.([0-9]+)\\.([0-9]+)")
    set(Rust_CARGO_VERSION_MAJOR "${CMAKE_MATCH_1}" CACHE INTERNAL "" FORCE)
    set(Rust_CARGO_VERSION_MINOR "${CMAKE_MATCH_2}" CACHE INTERNAL "" FORCE)
    set(Rust_CARGO_VERSION_PATCH "${CMAKE_MATCH_3}" CACHE INTERNAL "" FORCE)
    set(Rust_CARGO_VERSION "${Rust_CARGO_VERSION_MAJOR}.${Rust_CARGO_VERSION_MINOR}.${Rust_CARGO_VERSION_PATCH}" CACHE INTERNAL "" FORCE)
# Workaround for the version strings where the `cargo ` prefix is missing.
elseif(_CARGO_VERSION_RAW MATCHES "([0-9]+)\\.([0-9]+)\\.([0-9]+)")
    set(Rust_CARGO_VERSION_MAJOR "${CMAKE_MATCH_1}" CACHE INTERNAL "" FORCE)
    set(Rust_CARGO_VERSION_MINOR "${CMAKE_MATCH_2}" CACHE INTERNAL "" FORCE)
    set(Rust_CARGO_VERSION_PATCH "${CMAKE_MATCH_3}" CACHE INTERNAL "" FORCE)
    set(Rust_CARGO_VERSION "${Rust_CARGO_VERSION_MAJOR}.${Rust_CARGO_VERSION_MINOR}.${Rust_CARGO_VERSION_PATCH}" CACHE INTERNAL "" FORCE)
else()
    message(
        FATAL_ERROR
        "Failed to parse cargo version. `cargo --version` evaluated to (${_CARGO_VERSION_RAW})")
endif()

execute_process(
    COMMAND ${Rust_COMPILER_CACHED} --version --verbose
    OUTPUT_VARIABLE _RUSTC_VERSION_RAW)

if (_RUSTC_VERSION_RAW MATCHES "rustc ([0-9]+)\\.([0-9]+)\\.([0-9]+)(-nightly)?")
    set(Rust_VERSION_MAJOR "${CMAKE_MATCH_1}" CACHE INTERNAL "" FORCE)
    set(Rust_VERSION_MINOR "${CMAKE_MATCH_2}" CACHE INTERNAL "" FORCE)
    set(Rust_VERSION_PATCH "${CMAKE_MATCH_3}" CACHE INTERNAL "" FORCE)
    set(Rust_VERSION "${Rust_VERSION_MAJOR}.${Rust_VERSION_MINOR}.${Rust_VERSION_PATCH}" CACHE INTERNAL "" FORCE)
    if(CMAKE_MATCH_4)
        set(Rust_IS_NIGHTLY 1 CACHE INTERNAL "" FORCE)
    else()
        set(Rust_IS_NIGHTLY 0 CACHE INTERNAL "" FORCE)
    endif()
else()
    message(
        FATAL_ERROR
        "Failed to parse rustc version. `rustc --version --verbose` evaluated to:\n${_RUSTC_VERSION_RAW}")
endif()

if (_RUSTC_VERSION_RAW MATCHES "host: ([a-zA-Z0-9_\\-]*)\n")
    set(Rust_DEFAULT_HOST_TARGET "${CMAKE_MATCH_1}")
    set(Rust_CARGO_HOST_TARGET_CACHED "${Rust_DEFAULT_HOST_TARGET}" CACHE STRING "Host triple")
else()
    message(
        FATAL_ERROR
        "Failed to parse rustc host target. `rustc --version --verbose` evaluated to:\n${_RUSTC_VERSION_RAW}"
    )
endif()

if (_RUSTC_VERSION_RAW MATCHES "LLVM version: ([0-9]+)\\.([0-9]+)(\\.([0-9]+))?")
    set(Rust_LLVM_VERSION_MAJOR "${CMAKE_MATCH_1}" CACHE INTERNAL "" FORCE)
    set(Rust_LLVM_VERSION_MINOR "${CMAKE_MATCH_2}" CACHE INTERNAL "" FORCE)
    # With the Rust toolchain 1.44.1 the reported LLVM version is 9.0, i.e. without a patch version.
    # Since cmake regex does not support non-capturing groups, just ignore Match 3.
    set(Rust_LLVM_VERSION_PATCH "${CMAKE_MATCH_4}" CACHE INTERNAL "" FORCE)
    set(Rust_LLVM_VERSION "${Rust_LLVM_VERSION_MAJOR}.${Rust_LLVM_VERSION_MINOR}.${Rust_LLVM_VERSION_PATCH}" CACHE INTERNAL "" FORCE)
else()
    message(
            WARNING
            "Failed to parse rustc LLVM version. `rustc --version --verbose` evaluated to:\n${_RUSTC_VERSION_RAW}"
    )
endif()

if (NOT Rust_CARGO_TARGET_CACHED)
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

        set(Rust_CARGO_TARGET_CACHED "${_CARGO_ARCH}-${_CARGO_VENDOR}-${_CARGO_ABI}"
            CACHE STRING "Target triple")
    elseif (ANDROID)
        if (CMAKE_ANDROID_ARCH_ABI STREQUAL armeabi-v7a)
            if (CMAKE_ANDROID_ARM_MODE)
                set(_Rust_ANDROID_TARGET armv7-linux-androideabi)
            else ()
                set(_Rust_ANDROID_TARGET thumbv7neon-linux-androideabi)
            endif()
        elseif (CMAKE_ANDROID_ARCH_ABI STREQUAL arm64-v8a)
            set(_Rust_ANDROID_TARGET aarch64-linux-android)
        elseif (CMAKE_ANDROID_ARCH_ABI STREQUAL x86)
            set(_Rust_ANDROID_TARGET i686-linux-android)
        elseif (CMAKE_ANDROID_ARCH_ABI STREQUAL x86_64)
            set(_Rust_ANDROID_TARGET x86_64-linux-android)
        endif()

        if (_Rust_ANDROID_TARGET)
            set(Rust_CARGO_TARGET_CACHED ${_Rust_ANDROID_TARGET} CACHE STRING "Target triple")
        endif()
    else()
        set(Rust_CARGO_TARGET_CACHED "${Rust_DEFAULT_HOST_TARGET}" CACHE STRING "Target triple")
    endif()

    message(STATUS "Rust Target: ${Rust_CARGO_TARGET_CACHED}")
endif()

# Set the input variables as non-cache variables so that the variables are available after
# `find_package`, even if the values were evaluated to defaults.
foreach(_VAR ${_Rust_USER_VARS})
    set(${_VAR} ${${_VAR}_CACHED})
    # Ensure cached variables have type INTERNAL
    set(${_VAR}_CACHED ${${_VAR}_CACHED} CACHE INTERNAL "Internal cache of ${_VAR}")
endforeach()

find_package_handle_standard_args(
    Rust
    REQUIRED_VARS Rust_COMPILER Rust_VERSION Rust_CARGO Rust_CARGO_VERSION Rust_CARGO_TARGET Rust_CARGO_HOST_TARGET
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

if(NOT TARGET Rust::Rustc)
    add_executable(Rust::Rustc IMPORTED GLOBAL)
    set_property(
        TARGET Rust::Rustc
        PROPERTY IMPORTED_LOCATION ${Rust_COMPILER_CACHED}
    )

    add_executable(Rust::Cargo IMPORTED GLOBAL)
    set_property(
        TARGET Rust::Cargo
        PROPERTY IMPORTED_LOCATION ${Rust_CARGO_CACHED}
    )
    set(Rust_FOUND true)
endif()
