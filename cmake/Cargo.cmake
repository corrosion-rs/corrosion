cmake_minimum_required(VERSION 3.12)

option(CARGO_DEV_MODE OFF "Only for use when making changes to cmake-cargo.")

find_package(Cargo REQUIRED)
    
if (CARGO_DEV_MODE)
    message(STATUS "Running in cmake-cargo dev mode")

    get_filename_component(_moddir ${CMAKE_CURRENT_LIST_FILE} DIRECTORY)

    set(_CMAKE_CARGO_GEN ${CARGO_EXECUTABLE})
    set(_CMAKE_CARGO_GEN_ARGS run --quiet --manifest-path "${_moddir}/../generator/Cargo.toml" --)
else()
    find_program(
        _CMAKE_CARGO_GEN cmake-cargo-gen
        HINTS $ENV{HOME}/.cargo/bin)
endif()

function(_add_cargo_build package_name target_name path_to_toml)
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

    set(link_libs "$<GENEX_EVAL:$<TARGET_PROPERTY:cargo-build_${target_name},CARGO_LINK_LIBRARIES>>")
    set(search_dirs "$<GENEX_EVAL:$<TARGET_PROPERTY:cargo-build_${target_name},CARGO_LINK_DIRECTORIES>>")

    foreach(language C CXX Fortran)
        if(CMAKE_${language}_COMPILER AND CMAKE_${language}_LINKER_PREFERENCE_PROPAGATES)
            list(
                APPEND
                link_prefs
                CMAKECARGO_${language}_LINKER_PREFERENCE="${CMAKE_${language}_LINKER_PREFERENCE}")

            list(
                APPEND
                compilers
                CMAKECARGO_${language}_COMPILER="${CMAKE_${language}_COMPILER}"
            )
        endif()
    endforeach()

    # The C compiler must be at least enabled in order to choose a linker
    if (NOT compilers)
        if (NOT CMAKE_C_COMPILER)
            message(STATUS "Enabling the C compiler for linking Rust programs")
            enable_language(C REQUIRED)
        endif()

        list(APPEND link_prefs CMAKECARGO_C_LINKER_PREFERENCE="${CMAKE_C_LINKER_PREFERENCE}")
        list(APPEND compilers CMAKECARGO_C_COMPILER="${CMAKE_C_COMPILER}")
    endif()

    add_custom_target(
        cargo-build_${target_name}
        ALL
        COMMAND
            ${CMAKE_COMMAND} -E env
                CMAKECARGO_BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
                CMAKECARGO_LINK_LIBRARIES=${link_libs}
                CMAKECARGO_LINK_DIRECTORIES=${search_dirs}
                ${link_prefs}
                ${compilers}
                CMAKECARGO_LINKER_LANGUAGES=$<GENEX_EVAL:$<TARGET_PROPERTY:cargo-build_${target_name},CARGO_DEPS_LINKER_LANGUAGES>>
            ${_CMAKE_CARGO_GEN} ${_CMAKE_CARGO_GEN_ARGS}
                --manifest-path "${path_to_toml}"
                build-crate
                    $<$<NOT:$<OR:$<CONFIG:Debug>,$<CONFIG:>>>:--release>
                    --target ${CARGO_TARGET}
                    --package ${package_name}
                    --cargo ${CARGO_EXECUTABLE}
        # The build is conducted in root build directory so that cargo
        # dependencies are shared
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/${build_dir}
    )

    add_custom_target(
        cargo-clean_${target_name}
        COMMAND
            ${CARGO_EXECUTABLE} clean --target ${CARGO_TARGET}
            -p ${package_name} --manifest-path ${path_to_toml}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/${build_dir}
    )
    
    if (NOT TARGET cargo-clean)
        add_custom_target(cargo-clean)
        add_dependencies(cargo-clean cargo-clean_${target_name})
    endif()
endfunction(_add_cargo_build)

function(add_crate path_to_toml)
    if (NOT IS_ABSOLUTE "${path_to_toml}")
        set(path_to_toml "${CMAKE_CURRENT_SOURCE_DIR}/${path_to_toml}")
    endif()

    execute_process(
        COMMAND
            ${_CMAKE_CARGO_GEN} ${_CMAKE_CARGO_GEN_ARGS}
            --manifest-path "${path_to_toml}" print-root
        OUTPUT_VARIABLE toml_dir
        RESULT_VARIABLE ret)

    if (NOT ret EQUAL "0")
        message(FATAL_ERROR "cmake-cargo-gen failed")
    endif()

    string(STRIP "${toml_dir}" toml_dir)

    get_filename_component(toml_dir_name ${toml_dir} NAME)

    set(
        generated_cmake
        ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_FILES_DIRECTORY}/cmake-cargo/${toml_dir_name}.dir/cargo-build.cmake)

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
            "${path_to_toml}" gen-cmake ${_CMAKE_CARGO_CONFIGURATION_ROOT}
            ${_CMAKE_CARGO_TARGET} ${_CMAKE_CARGO_CONFIGURATION_TYPES}
            --cargo-version ${CARGO_VERSION} -o
            ${generated_cmake}
        RESULT_VARIABLE ret)

    if (NOT ret EQUAL "0")
        message(FATAL_ERROR "cmake-cargo-gen failed")
    endif()

    include(${generated_cmake})
endfunction(add_crate)

function(cargo_link_libraries target_name)
    add_dependencies(cargo-build_${target_name} ${ARGN})
    foreach(library ${ARGN})
        set_property(
            TARGET cargo-build_${target_name}
            APPEND
            PROPERTY CARGO_LINK_DIRECTORIES
            $<TARGET_LINKER_FILE_DIR:${library}>
        )

        set_property(
            TARGET cargo-build_${target_name}
            APPEND
            PROPERTY CARGO_DEPS_LINKER_LANGUAGES
            $<TARGET_PROPERTY:${library},LINKER_LANGUAGE>
        )

        # TODO: The output name of the library can be overridden - find a way to support that.
        set_property(
            TARGET cargo-build_${target_name}
            APPEND
            PROPERTY CARGO_LINK_LIBRARIES
            ${library}
        )
    endforeach()
endfunction(cargo_link_libraries)