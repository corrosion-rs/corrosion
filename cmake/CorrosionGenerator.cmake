function(_cargo_metadata out manifest)
    get_property(
        RUSTC_EXECUTABLE
        TARGET Rust::Rustc PROPERTY IMPORTED_LOCATION
    )
    get_property(
        CARGO_EXECUTABLE
        TARGET Rust::Cargo PROPERTY IMPORTED_LOCATION
    )
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -E env
                CARGO_BUILD_RUSTC=${RUSTC_EXECUTABLE}
                ${CARGO_EXECUTABLE}
                    metadata
                        --manifest-path ${manifest}
                        --format-version 1
        OUTPUT_VARIABLE json
        COMMAND_ERROR_IS_FATAL ANY
    )

    set(${out} ${json} PARENT_SCOPE)
endfunction()

function(_generator_parse_platform manifest version target)
    string(REGEX MATCH ".+-([^-]+)-([^-]+)$" os_env ${target})
    set(os ${CMAKE_MATCH_1})
    set(env ${CMAKE_MATCH_2})

    set(libs "")
    set(libs_debug "")
    set(libs_release "")

    set(is_windows FALSE)
    set(is_windows_msvc FALSE)
    set(is_windows_gnu FALSE)
    set(is_macos FALSE)

    if(os STREQUAL "windows")
        set(is_windows TRUE)

        if(NOT COR_NO_STD)
          list(APPEND libs "advapi32" "userenv" "ws2_32")
        endif()

        if(env STREQUAL "msvc")
            set(is_windows_msvc TRUE)

            if(NOT COR_NO_STD)
              list(APPEND libs_debug "msvcrtd")
              list(APPEND libs_release "msvcrt")
            endif()
        elseif(env STREQUAL "gnu")
            set(is_windows_gnu TRUE)

            if(NOT COR_NO_STD)
              list(APPEND libs "gcc_eh" "pthread")
            endif()
        endif()

        if(NOT COR_NO_STD)
          if(version VERSION_LESS "1.33.0")
              list(APPEND libs "shell32" "kernel32")
          endif()

          if(version VERSION_GREATER_EQUAL "1.57.0")
              list(APPEND libs "bcrypt")
          endif()
        endif()
    elseif(os STREQUAL "apple" AND env STREQUAL "darwin")
        set(is_macos TRUE)

        if(NOT COR_NO_STD)
           list(APPEND libs "System" "resolv" "c" "m")
        endif()
    elseif(os STREQUAL "linux")
        if(NOT COR_NO_STD)
           list(APPEND libs "dl" "rt" "pthread" "gcc_s" "c" "m" "util")
        endif()
    endif()

    set_source_files_properties(
        ${manifest}
        PROPERTIES
            CORROSION_PLATFORM_LIBS "${libs}"
            CORROSION_PLATFORM_LIBS_DEBUG "${libs_debug}"
            CORROSION_PLATFORM_LIBS_RELEASE "${libs_release}"

            CORROSION_PLATFORM_IS_WINDOWS "${is_windows}"
            CORROSION_PLATFORM_IS_WINDOWS_MSVC "${is_windows_msvc}"
            CORROSION_PLATFORM_IS_WINDOWS_GNU "${is_windows_gnu}"
            CORROSION_PLATFORM_IS_MACOS "${is_macos}"
    )
endfunction()

function(_generator_parse_target manifest package target)
    string(JSON package_name GET "${package}" "name")
    string(JSON manifest_path GET "${package}" "manifest_path")
    string(JSON target_name GET "${target}" "name")
    string(JSON target_kind GET "${target}" "kind")

    string(JSON target_kind_len LENGTH "${target_kind}")
    math(EXPR target_kind_len-1 "${target_kind_len} - 1")

    set(kinds)
    foreach(ix RANGE ${target_kind_len-1})
        string(JSON kind GET "${target_kind}" ${ix})
        list(APPEND kinds ${kind})
    endforeach()

    # target types
    set(is_library FALSE)
    set(has_staticlib FALSE)
    set(has_cdylib FALSE)
    set(is_executable FALSE)

    if("staticlib" IN_LIST kinds OR "cdylib" IN_LIST kinds)
        set(is_library TRUE)

        if("staticlib" IN_LIST kinds)
            set(has_staticlib TRUE)
        endif()

        if("cdylib" IN_LIST kinds)
            set(has_cdylib TRUE)
        endif()
    elseif("bin" IN_LIST kinds)
        set(is_executable TRUE)
    else()
        return()
    endif()

    # target file names
    string(REPLACE "-" "_" lib_name "${target_name}")

    get_source_file_property(is_windows ${manifest} CORROSION_PLATFORM_IS_WINDOWS)
    get_source_file_property(is_windows_msvc ${manifest} CORROSION_PLATFORM_IS_WINDOWS_MSVC)
    get_source_file_property(is_windows_gnu ${manifest} CORROSION_PLATFORM_IS_WINDOWS_GNU)
    get_source_file_property(is_macos ${manifest} CORROSION_PLATFORM_IS_MACOS)

    if(is_windows_msvc)
        set(static_lib_name "${lib_name}.lib")
    else()
        set(static_lib_name "lib${lib_name}.a")
    endif()

    if(is_windows)
        set(dynamic_lib_name "${lib_name}.dll")
    elseif(is_macos)
        set(dynamic_lib_name "lib${lib_name}.dylib")
    else()
        set(dynamic_lib_name "lib${lib_name}.so")
    endif()

    if(is_windows_msvc)
        set(implib_name "${lib_name}.dll.lib")
    elseif(is_windows_gnu)
        set(implib_name "lib${lib_name}.dll.a")
    elseif(is_windows)
        message(FATAL_ERROR "Unknown windows environment - Can't determine implib name")
    endif()

    set(pdb_name "${lib_name}.pdb")

    if(is_windows)
        set(exe_name "${target_name}.exe")
    else()
        set(exe_name "${target_name}")
    endif()

    # set properties
    get_source_file_property(ix ${manifest} CORROSION_NUM_TARGETS)

    set_source_files_properties(
        ${manifest}
        PROPERTIES
            CORROSION_TARGET${ix}_PACKAGE_NAME "${package_name}"
            CORROSION_TARGET${ix}_MANIFEST_PATH "${manifest_path}"
            CORROSION_TARGET${ix}_TARGET_NAME "${target_name}"

            CORROSION_TARGET${ix}_IS_LIBRARY "${is_library}"
            CORROSION_TARGET${ix}_HAS_STATICLIB "${has_staticlib}"
            CORROSION_TARGET${ix}_HAS_CDYLIB "${has_cdylib}"
            CORROSION_TARGET${ix}_IS_EXECUTABLE "${is_executable}"

            CORROSION_TARGET${ix}_STATIC_LIB_NAME "${static_lib_name}"
            CORROSION_TARGET${ix}_DYNAMIC_LIB_NAME "${dynamic_lib_name}"
            CORROSION_TARGET${ix}_IMPLIB_NAME "${implib_name}"
            CORROSION_TARGET${ix}_PDB_NAME "${pdb_name}"
            CORROSION_TARGET${ix}_EXE_NAME "${exe_name}"
    )

    math(EXPR ix "${ix} + 1")
    set_source_files_properties(
        ${manifest}
        PROPERTIES
            CORROSION_NUM_TARGETS ${ix}
    )
endfunction()

function(_generator_add_target manifest ix cargo_version profile)
    get_source_file_property(package_name ${manifest} CORROSION_TARGET${ix}_PACKAGE_NAME)
    get_source_file_property(manifest_path ${manifest} CORROSION_TARGET${ix}_MANIFEST_PATH)
    get_source_file_property(target_name ${manifest} CORROSION_TARGET${ix}_TARGET_NAME)

    get_source_file_property(is_library ${manifest} CORROSION_TARGET${ix}_IS_LIBRARY)
    get_source_file_property(has_staticlib ${manifest} CORROSION_TARGET${ix}_HAS_STATICLIB)
    get_source_file_property(has_cdylib ${manifest} CORROSION_TARGET${ix}_HAS_CDYLIB)
    get_source_file_property(is_executable ${manifest} CORROSION_TARGET${ix}_IS_EXECUTABLE)

    get_source_file_property(static_lib_name ${manifest} CORROSION_TARGET${ix}_STATIC_LIB_NAME)
    get_source_file_property(dynamic_lib_name ${manifest} CORROSION_TARGET${ix}_DYNAMIC_LIB_NAME)
    get_source_file_property(implib_name ${manifest} CORROSION_TARGET${ix}_IMPLIB_NAME)
    get_source_file_property(pdb_name ${manifest} CORROSION_TARGET${ix}_PDB_NAME)
    get_source_file_property(exe_name ${manifest} CORROSION_TARGET${ix}_EXE_NAME)

    get_source_file_property(libs ${manifest} CORROSION_PLATFORM_LIBS)
    get_source_file_property(libs_debug ${manifest} CORROSION_PLATFORM_LIBS_DEBUG)
    get_source_file_property(libs_release ${manifest} CORROSION_PLATFORM_LIBS_RELEASE)

    get_source_file_property(is_windows ${manifest} CORROSION_PLATFORM_IS_WINDOWS)
    get_source_file_property(is_windows_msvc ${manifest} CORROSION_PLATFORM_IS_WINDOWS_MSVC)
    get_source_file_property(is_windows_gnu ${manifest} CORROSION_PLATFORM_IS_WINDOWS_GNU)
    get_source_file_property(is_macos ${manifest} CORROSION_PLATFORM_IS_MACOS)

    string(REPLACE "\\" "/" manifest_path "${manifest_path}")

    set(byproducts)
    if(is_library)
        if(has_staticlib)
            list(APPEND byproducts ${static_lib_name})
        endif()

        if(has_cdylib)
            list(APPEND byproducts ${dynamic_lib_name})

            if(is_windows)
                list(APPEND byproducts ${implib_name})
            endif()
        endif()
    elseif(is_executable)
        list(APPEND byproducts ${exe_name})
    else()
        message(FATAL_ERROR "unknown target type")
    endif()

    # Only shared libraries and executables have PDBs on Windows
    # We don't know why PDBs aren't generated for staticlibs...
    if(is_windows_msvc AND (has_cdylib OR is_executable))
        if(cargo_version VERSION_LESS "1.45.0")
            set(prefix "deps/")
        endif()
        list(APPEND byproducts "${prefix}${pdb_name}")
    endif()

    if(is_library)
        if(NOT (has_staticlib OR has_cdylib))
            message(FATAL_ERROR "Unknown library type")
        endif()

        if(has_staticlib)
            add_library(${target_name}-static STATIC IMPORTED GLOBAL)
            add_dependencies(${target_name}-static cargo-build_${target_name})

            if(libs)
                set_property(
                    TARGET ${target_name}-static
                    PROPERTY INTERFACE_LINK_LIBRARIES ${libs}
                )
                if(is_macos)
                    set_property(TARGET ${target_name}-static
                            PROPERTY INTERFACE_LINK_DIRECTORIES "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
                    )
                endif()
            endif()

            if(libs_debug)
                set_property(
                    TARGET ${target_name}-static
                    PROPERTY INTERFACE_LINK_LIBRARIES_DEBUG ${libs_debug}
                )
            endif()

            if(libs_release)
                foreach(config "RELEASE" "MINSIZEREL" "RELWITHDEBINFO")
                    set_property(
                        TARGET ${target_name}-static
                        PROPERTY INTERFACE_LINK_LIBRARIES_${config} ${libs_release}
                    )
                endforeach()
            endif()
        endif()

        if(has_cdylib)
            add_library(${target_name}-shared SHARED IMPORTED GLOBAL)
            add_dependencies(${target_name}-shared cargo-build_${target_name})
            if(is_macos)
                set_property(TARGET ${target_name}-shared
                        PROPERTY INTERFACE_LINK_DIRECTORIES "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
                        )
            endif()
        endif()

        add_library(${target_name} INTERFACE)

        if(has_cdylib AND has_staticlib)
            if(BUILD_SHARED_LIBS)
                target_link_libraries(${target_name} INTERFACE ${target_name}-shared)
            else()
                target_link_libraries(${target_name} INTERFACE ${target_name}-static)
            endif()
        elseif(has_cdylib)
            target_link_libraries(${target_name} INTERFACE ${target_name}-shared)
        else()
            target_link_libraries(${target_name} INTERFACE ${target_name}-static)
        endif()
    elseif(is_executable)
        add_executable(${target_name} IMPORTED GLOBAL)
        add_dependencies(${target_name} cargo-build_${target_name})
        if(is_macos)
            set_property(TARGET ${target_name}
                    PROPERTY INTERFACE_LINK_DIRECTORIES "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
            )
        endif()
    else()
        message(FATAL_ERROR "unknown target type")
    endif()

    _add_cargo_build(
            PACKAGE ${package_name}
            TARGET ${target_name}
            MANIFEST_PATH "${manifest_path}"
            BYPRODUCTS ${byproducts}
            PROFILE "${profile}"
    )
endfunction()

function(_generator_add_config_info manifest ix is_multi_config config_type)
    get_source_file_property(target_name ${manifest} CORROSION_TARGET${ix}_TARGET_NAME)

    get_source_file_property(is_library ${manifest} CORROSION_TARGET${ix}_IS_LIBRARY)
    get_source_file_property(has_staticlib ${manifest} CORROSION_TARGET${ix}_HAS_STATICLIB)
    get_source_file_property(has_cdylib ${manifest} CORROSION_TARGET${ix}_HAS_CDYLIB)
    get_source_file_property(is_executable ${manifest} CORROSION_TARGET${ix}_IS_EXECUTABLE)

    get_source_file_property(static_lib_name ${manifest} CORROSION_TARGET${ix}_STATIC_LIB_NAME)
    get_source_file_property(dynamic_lib_name ${manifest} CORROSION_TARGET${ix}_DYNAMIC_LIB_NAME)
    get_source_file_property(implib_name ${manifest} CORROSION_TARGET${ix}_IMPLIB_NAME)
    get_source_file_property(exe_name ${manifest} CORROSION_TARGET${ix}_EXE_NAME)

    get_source_file_property(is_windows ${manifest} CORROSION_PLATFORM_IS_WINDOWS)

    if(config_type)
        string(TOUPPER "${config_type}" config_type_upper)
        set(imported_location "IMPORTED_LOCATION_${config_type_upper}")
        set(imported_implib "IMPORTED_IMPLIB_${config_type_upper}")
    else()
        set(imported_location "IMPORTED_LOCATION")
        set(imported_implib "IMPORTED_IMPLIB")
    endif()

    if(is_multi_config)
        set(binary_root "${CMAKE_CURRENT_BINARY_DIR}/${config_type}")
    else()
        set(binary_root "${CMAKE_CURRENT_BINARY_DIR}")
    endif()

    if(is_library)
        if(has_staticlib)
            set_property(
                TARGET ${target_name}-static
                PROPERTY ${imported_location} "${binary_root}/${static_lib_name}"
            )
        endif()

        if(has_cdylib)
            set_property(
                TARGET ${target_name}-shared
                PROPERTY ${imported_location} "${binary_root}/${dynamic_lib_name}"
            )

            if(is_windows)
                set_property(
                    TARGET ${target_name}-shared
                    PROPERTY ${imported_implib} "${binary_root}/${implib_name}"
                )
            endif()
        endif()
    elseif(is_executable)
        set_property(
            TARGET ${target_name}
            PROPERTY ${imported_location} "${binary_root}/${exe_name}"
        )
    else()
        message(FATAL_ERROR "unknown target type")
    endif()
endfunction()

function(_generator_add_cargo_targets)
    set(options "")
    set(one_value_args MANIFEST_PATH CONFIGURATION_ROOT CONFIGURATION_TYPE TARGET CARGO_VERSION PROFILE)
    set(multi_value_args CONFIGURATION_TYPES CRATES)
    cmake_parse_arguments(
        GGC
        "${options}"
        "${one_value_args}"
        "${multi_value_args}"
        ${ARGN}
    )

    set(config_root "${CMAKE_BINARY_DIR}/${GGC_CONFIGURATION_ROOT}")

    set(config_types)
    set(config_folders)
    if(GGC_CONFIGURATION_TYPES)
        set(is_multi_config TRUE)
        foreach(config_type ${GGC_CONFIGURATION_TYPES})
            list(APPEND config_types ${config_type})
            list(APPEND config_folders "${config_root}/${config_type}")
        endforeach()
    else()
        set(is_multi_config FALSE)
        list(APPEND config_types "${GGC_CONFIGURATION_TYPE}")
        list(APPEND config_folders ${config_root})
    endif()

    foreach(folder ${config_folders})
        if(NOT EXISTS "${folder}/.cargo/config")
            message(FATAL_ERROR "Target config_folder '${folder}' must contain a '.cargo/config'.")
        endif()
    endforeach()

    _cargo_metadata(json ${GGC_MANIFEST_PATH})
    string(JSON packages GET "${json}" "packages")
    string(JSON workspace_members GET "${json}" "workspace_members")

    string(JSON pkgs_len LENGTH "${packages}")
    math(EXPR pkgs_len-1 "${pkgs_len} - 1")

    string(JSON ws_mems_len LENGTH ${workspace_members})
    math(EXPR ws_mems_len-1 "${ws_mems_len} - 1")

    set_source_files_properties(
        ${GGC_MANIFEST_PATH}
        PROPERTIES
            CORROSION_NUM_TARGETS 0
    )

    _generator_parse_platform(${GGC_MANIFEST_PATH} ${GGC_CARGO_VERSION} ${GGC_TARGET})

    foreach(ix RANGE ${pkgs_len-1})
        string(JSON pkg GET "${packages}" ${ix})
        string(JSON pkg_id GET "${pkg}" "id")
        string(JSON pkg_name GET "${pkg}" "name")
        string(JSON targets GET "${pkg}" "targets")

        string(JSON targets_len LENGTH "${targets}")
        math(EXPR targets_len-1 "${targets_len} - 1")

        foreach(ix RANGE ${ws_mems_len-1})
            string(JSON ws_mem GET "${workspace_members}" ${ix})

            if(ws_mem STREQUAL pkg_id AND ((NOT GGC_CRATES) OR (pkg_name IN_LIST GGC_CRATES)))
                foreach(ix RANGE ${targets_len-1})
                    string(JSON target GET "${targets}" ${ix})
                    _generator_parse_target(${GGC_MANIFEST_PATH} "${pkg}" "${target}")
                endforeach()
            endif()
        endforeach()
    endforeach()

    get_source_file_property(num_targets ${GGC_MANIFEST_PATH} CORROSION_NUM_TARGETS)
    if(NOT num_targets)
        message(FATAL_ERROR "found no target")
    endif()
    math(EXPR num_targets-1 "${num_targets} - 1")

    foreach(ix RANGE ${num_targets-1})
        _generator_add_target(
            ${GGC_MANIFEST_PATH}
            ${ix}
            ${GGC_CARGO_VERSION}
            "${GGC_PROFILE}"
        )
    endforeach()

    foreach(config_type config_folder IN ZIP_LISTS config_types config_folders)
        foreach(ix RANGE ${num_targets-1})
            _generator_add_config_info(
                ${GGC_MANIFEST_PATH}
                ${ix}
                ${is_multi_config}
                "${config_type}"
            )
        endforeach()
    endforeach()
endfunction()
