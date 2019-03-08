cmake_minimum_required(VERSION 3.10)

option(CARGO_DEV_MODE OFF "Only for use when making changes to cmake-cargo.")

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

        set(CARGO_TARGET "${CARGO_ARCH}-${CARGO_VENDOR}-${CARGO_ABI}" CACHE STRING
            "Cargo target triple")
    endif()
endif()

find_package(Cargo REQUIRED)
    
if (CARGO_DEV_MODE)
    message(STATUS "Running in cmake-cargo dev mode")

    get_filename_component(_moddir ${CMAKE_CURRENT_LIST_FILE} DIRECTORY)

    set(_CMAKE_CARGO_GEN ${CARGO_EXECUTABLE})
    set(_CMAKE_CARGO_GEN_ARGS run --quiet --manifest-path ${_moddir}/../Cargo.toml --)
else()
    find_program(
        _CMAKE_CARGO_GEN cmake-cargo-gen
        HINTS $ENV{HOME}/.cargo/bin)
endif()

function(add_crate path_to_toml)
    if (NOT IS_ABSOLUTE "${path_to_toml}")
        set(path_to_toml "${CMAKE_SOURCE_DIR}/${path_to_toml}")
    endif()

    exec_program(
        ${_CMAKE_CARGO_GEN}
        ARGS ${_CMAKE_CARGO_GEN_ARGS} --manifest-path ${path_to_toml} print-root
        OUTPUT_VARIABLE toml_dir)

    get_filename_component(toml_dir_name ${toml_dir} NAME)

    set(
        generated_cmake
        ${CMAKE_BINARY_DIR}/${CMAKE_FILES_DIRECTORY}/cmake-cargo/${toml_dir_name}.dir/cargo-build.cmake)

    if (CMAKE_VS_PLATFORM_NAME)
        set (_CMAKE_CARGO_CONFIGURATION_ROOT --configuration-root
            ${CMAKE_VS_PLATFORM_NAME})
    endif()

    if (CARGO_TARGET)
        set(_CMAKE_CARGO_TARGET --target ${CARGO_TARGET})
    endif()
    
    if(CMAKE_CONFIGURATION_TYPES)
        string (REPLACE ";" "," _CONFIGURATION_TYPES
            "${CMAKE_CONFIGURATION_TYPES}")
        set (_CMAKE_CARGO_CONFIGURATION_TYPES --configuration-types
            ${_CONFIGURATION_TYPES})
    elseif(CMAKE_BUILD_TYPE)
        set (_CMAKE_CARGO_CONFIGURATION_TYPES --configuration-type
            ${CMAKE_BUILD_TYPE})
    else()
        # uses default build type
    endif()

    execute_process(
        COMMAND ${_CMAKE_CARGO_GEN} ${_CMAKE_CARGO_GEN_ARGS} --manifest-path
        ${path_to_toml} gen-cmake ${_CMAKE_CARGO_CONFIGURATION_ROOT}
        ${_CMAKE_CARGO_TARGET} ${_CMAKE_CARGO_CONFIGURATION_TYPES}
        --cargo-version ${CARGO_VERSION} -o
        ${generated_cmake})

    include(${generated_cmake})
endfunction(add_crate)
