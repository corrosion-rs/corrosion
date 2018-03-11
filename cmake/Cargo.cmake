set(CARGO_DEV_MODE OFF CACHE INTERNAL
    "Only for use when making changes to cmake-cargo.")
    
if (CARGO_DEV_MODE)
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

    exec_program(
        ${_CMAKE_CARGO_GEN}
        ARGS ${_CMAKE_CARGO_GEN_ARGS} --manifest-path ${path_to_toml}
            -o ${generated_cmake})

    include(${generated_cmake})
endfunction(add_crate)
