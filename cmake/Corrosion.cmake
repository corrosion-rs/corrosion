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
    if (CORROSION_DEV_MODE)
        # If you're developing Corrosion, you want to make sure to re-configure whenever the
        # generator changes.
        file(GLOB_RECURSE _RUST_FILES CONFIGURE_DEPENDS generator/src/*.rs)
        file(GLOB _CARGO_FILES CONFIGURE_DEPENDS generator/Cargo.*)
        set_property(
            DIRECTORY APPEND
            PROPERTY CMAKE_CONFIGURE_DEPENDS
                ${_RUST_FILES} ${_CARGO_FILES})
    endif()
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
    if (NOT MSVC)
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
                CMAKECARGO_LINKER_LANGUAGES="$<TARGET_PROPERTY:cargo-build_${target_name},LINKER_LANGUAGE>$<GENEX_EVAL:$<TARGET_PROPERTY:cargo-build_${target_name},CARGO_DEPS_LINKER_LANGUAGES>>"
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

function(corrosion_set_linker_language target_name language)
    set_property(
        TARGET cargo-build_${target_name}
        PROPERTY LINKER_LANGUAGE ${language}
    )
endfunction()

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

function(corrosion_install)
    # Default install dirs
    include(GNUInstallDirs)

    # Parse arguments to corrosion_install
    list(GET ARGN 0 INSTALL_TYPE)
    list(REMOVE_AT ARGN 0)

    # The different install types that are supported. Some targets may have more than one of these
    # types. For example, on Windows, a shared library will have both an ARCHIVE component and a
    # RUNTIME component.
    set(INSTALL_TARGET_TYPES ARCHIVE LIBRARY RUNTIME PRIVATE_HEADER PUBLIC_HEADER)
    
    # Arguments to each install target type
    set(OPTIONS)
    set(ONE_VALUE_ARGS DESTINATION)
    set(MULTI_VALUE_ARGS PERMISSIONS CONFIGURATIONS)
    set(TARGET_ARGS ${OPTIONS} ${ONE_VALUE_ARGS} ${MULTI_VALUE_ARGS})

    if (INSTALL_TYPE STREQUAL "TARGETS")
        # corrosion_install(TARGETS ... [EXPORT <export-name>]
        #                   [[ARCHIVE|LIBRARY|RUNTIME|PRIVATE_HEADER|PUBLIC_HEADER]
        #                    [DESTINATION <dir>]
        #                    [PERMISSIONS permissions...]
        #                    [CONFIGURATIONS [Debug|Release|...]]
        #                   ] [...])

        # Extract targets
        set(INSTALL_TARGETS)
        list(LENGTH ARGN ARGN_LENGTH)
        set(DELIMITERS EXPORT ${INSTALL_TARGET_TYPES} ${TARGET_ARGS})
        while(ARGN_LENGTH)
            # If we hit another keyword, stop - we've found all the targets
            list(GET ARGN 0 FRONT)
            if (FRONT IN_LIST DELIMITERS)
                break()
            endif()

            list(APPEND INSTALL_TARGETS ${FRONT})
            list(REMOVE_AT ARGN 0)
            
            # Update ARGN_LENGTH
            list(LENGTH ARGN ARGN_LENGTH)
        endwhile()

        # Check if there are any args left before proceeding
        list(LENGTH ARGN ARGN_LENGTH)
        if (ARGN_LENGTH)
            list(GET ARGN 0 FRONT)
            if (FRONT STREQUAL "EXPORT")
                list(REMOVE_AT ARGN 0) # Pop "EXPORT"

                list(GET ARGN 0 EXPORT_NAME)
                list(REMOVE_AT ARGN 0) # Pop <export-name>
                message(FATAL_ERROR "EXPORT keyword not yet implemented!")
            endif()
        endif()

        # Loop over all arguments and get options for each install target type
        list(LENGTH ARGN ARGN_LENGTH)
        while(ARGN_LENGTH)
            # Check if we're dealing with arguments for a specific install target type, or with
            # default options for all target types.
            list(GET ARGN 0 FRONT)
            if (FRONT IN_LIST INSTALL_TARGET_TYPES)
                set(INSTALL_TARGET_TYPE ${FRONT})
                list(REMOVE_AT ARGN 0)
            else()
                set(INSTALL_TARGET_TYPE DEFAULT)
            endif()

            # Gather the arguments to this install type
            set(ARGS)
            while(ARGN_LENGTH)
                # If the next keyword is an install target type, then break - arguments have been
                # gathered.
                list(GET ARGN 0 FRONT)
                if (FRONT IN_LIST INSTALL_TARGET_TYPES)
                    break()
                endif()

                list(APPEND ARGS ${FRONT})
                list(REMOVE_AT ARGN 0)

                list(LENGTH ARGN ARGN_LENGTH)
            endwhile()

            # Parse the arguments and register the file install
            cmake_parse_arguments(
                COR "${OPTIONS}" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGS})

            if (COR_DESTINATION)
                set(COR_INSTALL_${INSTALL_TARGET_TYPE}_DESTINATION ${COR_DESTINATION})
            endif()

            if (COR_PERMISSIONS)
                set(COR_INSTALL_${INSTALL_TARGET_TYPE}_PERMISSIONS ${COR_PERMISSIONS})
            endif()

            if (COR_CONFIGURATIONS)
                set(COR_INSTALL_${INSTALL_TARGET_TYPE}_CONFIGURATIONS ${COR_CONFIGURATIONS})
            endif()
            
            # Update ARG_LENGTH
            list(LENGTH ARGN ARGN_LENGTH)
        endwhile()

        # Default permissions for all files
        set(DEFAULT_PERMISSIONS OWNER_WRITE OWNER_READ GROUP_READ WORLD_READ)

        # Loop through each install target and register file installations
        foreach(INSTALL_TARGET ${INSTALL_TARGETS})
            # Don't both implementing target type differentiation using generator expressions since
            # TYPE cannot change after target creation
            get_property(
                TARGET_TYPE
                TARGET ${INSTALL_TARGET} PROPERTY TYPE
            )

            # Install executable files first
            if (TARGET_TYPE STREQUAL "EXECUTABLE")
                if (DEFINED COR_INSTALL_RUNTIME_DESTINATION)
                    set(DESTINATION ${COR_INSTALL_RUNTIME_DESTINATION})
                elseif (DEFINED COR_INSTALL_DEFAULT_DESTINATION)
                    set(DESTINATION ${COR_INSTALL_DEFAULT_DESTINATION})
                else()
                    set(DESTINATION ${CMAKE_INSTALL_BINDIR})
                endif()

                if (DEFINED COR_INSTALL_RUNTIME_PERMISSIONS)
                    set(PERMISSIONS ${COR_INSTALL_RUNTIME_PERMISSIONS})
                elseif (DEFINED COR_INSTALL_DEFAULT_PERMISSIONS)
                    set(PERMISSIONS ${COR_INSTALL_DEFAULT_PERMISSIONS})
                else()
                    set(
                        PERMISSIONS
                        ${DEFAULT_PERMISSIONS} OWNER_EXECUTE GROUP_EXECUTE WORLD_EXECUTE)
                endif()

                if (DEFINED COR_INSTALL_RUNTIME_CONFIGURATIONS)
                    set(CONFIGURATIONS CONFIGURATIONS ${COR_INSTALL_RUNTIME_CONFIGURATIONS})
                elseif (DEFINED COR_INSTALL_DEFAULT_CONFIGURATIONS)
                    set(CONFIGURATIONS CONFIGURATIONS ${COR_INSTALL_DEFAULT_CONFIGURATIONS})
                else()
                    set(CONFIGURATIONS)
                endif()

                install(
                    FILES $<TARGET_FILE:${INSTALL_TARGET}>
                    DESTINATION ${DESTINATION}
                    PERMISSIONS ${PERMISSIONS}
                    ${CONFIGURATIONS}
                )
            endif()
        endforeach()

    elseif(INSTALL_TYPE STREQUAL "EXPORT")
        message(FATAL_ERROR "install(EXPORT ...) not yet implemented")
    endif()
endfunction()