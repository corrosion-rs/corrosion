cmake_minimum_required(VERSION 3.12)

option(CORROSION_VERBOSE_OUTPUT "Enables verbose output from Corrosion and Cargo" OFF)

find_package(Rust REQUIRED)

if (NOT TARGET Corrosion::Generator)
    message(STATUS "Using Corrosion as a subdirectory")
endif()

get_property(
    RUSTC_EXECUTABLE
    TARGET Rust::Rustc PROPERTY IMPORTED_LOCATION
)

get_property(
    CARGO_EXECUTABLE
    TARGET Rust::Cargo PROPERTY IMPORTED_LOCATION
)

if (NOT TARGET Corrosion::Generator)
    set(_CORROSION_GENERATOR_EXE
        ${CARGO_EXECUTABLE} run --quiet --manifest-path "${CMAKE_CURRENT_LIST_DIR}/../generator/Cargo.toml" --)
else()
    get_property(
        _CORROSION_GENERATOR_EXE
        TARGET Corrosion::Generator PROPERTY IMPORTED_LOCATION
    )
endif()

if (CORROSION_VERBOSE_OUTPUT)
    set(_CORROSION_VERBOSE_OUTPUT_FLAG --verbose)
endif()

set(
    _CORROSION_GENERATOR
    ${CMAKE_COMMAND} -E env
        CARGO_BUILD_RUSTC=${RUSTC_EXECUTABLE}
        ${_CORROSION_GENERATOR_EXE}
            --cargo ${CARGO_EXECUTABLE}
            ${_CORROSION_VERBOSE_OUTPUT_FLAG}
    CACHE INTERNAL "corrosion-generator runner"
)

set(_CORROSION_CARGO_VERSION ${Rust_CARGO_VERSION} CACHE INTERNAL "cargo version used by corrosion")

function(_add_cargo_build)
    set(options "")
    set(one_value_args PACKAGE TARGET MANIFEST_PATH)
    set(multi_value_args BYPRODUCTS)
    cmake_parse_arguments(
        ACB
        "${options}"
        "${one_value_args}"
        "${multi_value_args}"
        ${ARGN}
    )

    set(package_name "${ACB_PACKAGE}")
    set(target_name "${ACB_TARGET}")
    set(path_to_toml "${ACB_MANIFEST_PATH}")

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

    # For MSVC targets, don't mess with linker preferences.
    # TODO: We still should probably make sure that rustc is using the correct cl.exe to link programs.
    if (NOT CARGO_ABI STREQUAL "msvc")
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
                enable_language(C)
            endif()

            list(APPEND link_prefs CMAKECARGO_C_LINKER_PREFERENCE="${CMAKE_C_LINKER_PREFERENCE}")
            list(APPEND compilers CMAKECARGO_C_COMPILER="${CMAKE_C_COMPILER}")
        endif()
    endif()

    # BYPRODUCTS doesn't support generator expressions, so only add BYPRODUCTS for single-config generators
    if (NOT CMAKE_CONFIGURATION_TYPES)
        if (CMAKE_BUILD_TYPE STREQUAL "" OR CMAKE_BUILD_TYPE STREQUAL Debug)
            set(build_type_dir debug)
        else()
            set(build_type_dir release)
        endif()

        set(cargo_build_dir "${CMAKE_BINARY_DIR}/${build_dir}/cargo/build/${Rust_CARGO_TARGET}/${build_type_dir}")
        foreach(byproduct_file ${ACB_BYPRODUCTS})
            list(APPEND byproducts "${cargo_build_dir}/${byproduct_file}")
        endforeach()
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
            ${_CORROSION_GENERATOR}
                --manifest-path "${path_to_toml}"
                build-crate
                    $<$<NOT:$<OR:$<CONFIG:Debug>,$<CONFIG:>>>:--release>
                    --target ${Rust_CARGO_TARGET}
                    --package ${package_name}
            BYPRODUCTS ${byproducts}
        # The build is conducted in root build directory so that cargo
        # dependencies are shared
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/${build_dir}
    )

    add_custom_target(
        cargo-clean_${target_name}
        COMMAND
            $<TARGET_FILE:Rust::Cargo> clean --target ${Rust_CARGO_TARGET}
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
            ${_CORROSION_GENERATOR}
                --manifest-path "${path_to_toml}"
                print-root
        OUTPUT_VARIABLE toml_dir
        RESULT_VARIABLE ret)

    if (NOT ret EQUAL "0")
        message(FATAL_ERROR "corrosion-generator failed: ${ret}")
    endif()

    string(STRIP "${toml_dir}" toml_dir)

    get_filename_component(toml_dir_name ${toml_dir} NAME)

    set(
        generated_cmake
        "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_FILES_DIRECTORY}/cmake-cargo/${toml_dir_name}.dir/cargo-build.cmake"
    )

    if (CMAKE_VS_PLATFORM_NAME)
        set (_CMAKE_CARGO_CONFIGURATION_ROOT --configuration-root ${CMAKE_VS_PLATFORM_NAME})
    endif()

    if (Rust_CARGO_TARGET)
        set(_CMAKE_CARGO_TARGET --target ${Rust_CARGO_TARGET})
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
        COMMAND
            ${_CORROSION_GENERATOR}
                --manifest-path "${path_to_toml}"
                gen-cmake
                    ${_CMAKE_CARGO_CONFIGURATION_ROOT}
                    ${_CMAKE_CARGO_TARGET}
                    ${_CMAKE_CARGO_CONFIGURATION_TYPES}
                    --cargo-version ${_CORROSION_CARGO_VERSION}
                    -o ${generated_cmake}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        RESULT_VARIABLE ret)

    if (NOT ret EQUAL "0")
        message(FATAL_ERROR "corrosion-generator failed")
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