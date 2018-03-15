option(CARGO_DEV_MODE OFF "Only for use when making changes to cmake-cargo.")

if (CMAKE_VS_PLATFORM_NAME)
    if ("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "Win32")
        set(CARGO_TARGET i686-pc-windows-msvc CACHE STRING
            "The target triple to build for")
    elseif("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "x64")
        set(CARGO_TARGET x86_64-pc-windows-msvc CACHE STRING
            "The target triple to build for")
    else()
        message(WARNING "VS Platform '${CMAKE_VS_PLATFORM_NAME}' not recognized")
    endif()
endif()
    
if (CARGO_DEV_MODE)
    message(STATUS "Running in cmake-cargo dev mode")

    find_package(Cargo REQUIRED)
    get_filename_component(_moddir ${CMAKE_CURRENT_LIST_FILE} DIRECTORY)

    set(_CMAKE_CARGO_GEN ${CARGO})
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

    exec_program(
        ${_CMAKE_CARGO_GEN}
        ARGS ${_CMAKE_CARGO_GEN_ARGS} --manifest-path ${path_to_toml}
            gen-cmake ${_CMAKE_CARGO_CONFIGURATION_ROOT} ${_CMAKE_CARGO_TARGET}
            ${_CMAKE_CARGO_CONFIGURATION_TYPES} -o ${generated_cmake})

    include(${generated_cmake})
endfunction(add_crate)
