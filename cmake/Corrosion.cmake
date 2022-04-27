cmake_minimum_required(VERSION 3.15)

if (CMAKE_GENERATOR STREQUAL "Ninja Multi-Config" AND CMAKE_VERSION VERSION_LESS 3.20.0)
    message(FATAL_ERROR "Corrosion requires at least CMake 3.20 with the \"Ninja Multi-Config\" "
       "generator. Please use a different generator or update to cmake >= 3.20.")
endif()

option(CORROSION_VERBOSE_OUTPUT "Enables verbose output from Corrosion and Cargo" OFF)

set(CORROSION_NATIVE_TOOLING_DESCRIPTION 
    "Use native tooling - Required on CMake < 3.19 and available as a fallback option for recent versions"
    )

set(CORROSION_NATIVE_TOOLING_DEFAULT OFF)
# `CORROSION_EXPERIMENTAL_PARSER` was not part of a tagged release, but we still provide a 
# deprecation notice for users that directly use corrosion on the master branch and may have set
# this option.
if(DEFINED CORROSION_EXPERIMENTAL_PARSER)
    message(DEPRECATION "The experimental option `CORROSION_EXPERIMENTAL_PARSER` is now deprecated."
                " Please use `CORROSION_NATIVE_TOOLING` instead (with inverted semantics)."
                " This warning will be removed in version 0.3 and the variable silently ignored."
    )
    if(CORROSION_EXPERIMENTAL_PARSER)
        set(CORROSION_NATIVE_TOOLING_DEFAULT OFF)
    else()
        set(CORROSION_NATIVE_TOOLING_DEFAULT ON)
    endif()
endif()

option(
    CORROSION_NATIVE_TOOLING
    "${CORROSION_NATIVE_TOOLING_DESCRIPTION}"
    ${CORROSION_NATIVE_TOOLING_DEFAULT}
)

# The native tooling is required on CMAke < 3.19 so we override whatever the user may have set.
if (CMAKE_VERSION VERSION_LESS 3.19.0)
    set(CORROSION_NATIVE_TOOLING ON CACHE INTERNAL "${CORROSION_NATIVE_TOOLING_DESCRIPTION}" FORCE)
endif()

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

if (NOT CORROSION_NATIVE_TOOLING)
    include(CorrosionGenerator)
endif()

if (CORROSION_VERBOSE_OUTPUT)
    set(_CORROSION_VERBOSE_OUTPUT_FLAG --verbose)
endif()

if(CORROSION_NATIVE_TOOLING)
    if (NOT TARGET Corrosion::Generator )
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

    set(
        _CORROSION_GENERATOR
        ${CMAKE_COMMAND} -E env
            CARGO_BUILD_RUSTC=${RUSTC_EXECUTABLE}
            ${_CORROSION_GENERATOR_EXE}
                --cargo ${CARGO_EXECUTABLE}
                ${_CORROSION_VERBOSE_OUTPUT_FLAG}
        CACHE INTERNAL "corrosion-generator runner"
    )
endif()

set(_CORROSION_CARGO_VERSION ${Rust_CARGO_VERSION} CACHE INTERNAL "cargo version used by corrosion")
set(_CORROSION_RUST_CARGO_TARGET ${Rust_CARGO_TARGET} CACHE INTERNAL "target triple used by corrosion")
set(_CORROSION_RUST_CARGO_HOST_TARGET ${Rust_CARGO_HOST_TARGET} CACHE INTERNAL "host triple used by corrosion")
set(_CORROSION_RUSTC "${RUSTC_EXECUTABLE}" CACHE INTERNAL  "Path to rustc used by corrosion")
set(_CORROSION_CARGO "${CARGO_EXECUTABLE}" CACHE INTERNAL "Path to cargo used by corrosion")

string(REPLACE "-" "_" _CORROSION_RUST_CARGO_TARGET_UNDERSCORE "${Rust_CARGO_TARGET}")
string(TOUPPER "${_CORROSION_RUST_CARGO_TARGET_UNDERSCORE}" _CORROSION_TARGET_TRIPLE_UPPER)
set(_CORROSION_RUST_CARGO_TARGET_UNDERSCORE ${Rust_CARGO_TARGET} CACHE INTERNAL "lowercase target triple with underscores")
set(_CORROSION_RUST_CARGO_TARGET_UPPER
        "${_CORROSION_TARGET_TRIPLE_UPPER}"
        CACHE INTERNAL
        "target triple in uppercase with underscore"
)

# We previously specified some Custom properties as part of our public API, however the chosen names prevented us from
# supporting CMake versions before 3.19. In order to both support older CMake versions and not break existing code
# immediately, we are using a different property name depending on the CMake version. However users avoid using
# any of the properties directly, as they are no longer part of the public API and are to be considered deprecated.
# Instead use the corrosion_set_... functions as documented in the Readme.
if (CMAKE_VERSION VERSION_GREATER_EQUAL 3.19.0)
    set(_CORR_PROP_FEATURES CORROSION_FEATURES CACHE INTERNAL "")
    set(_CORR_PROP_ALL_FEATURES CORROSION_ALL_FEATURES CACHE INTERNAL "")
    set(_CORR_PROP_NO_DEFAULT_FEATURES CORROSION_NO_DEFAULT_FEATURES CACHE INTERNAL "")
    set(_CORR_PROP_ENV_VARS CORROSION_ENVIRONMENT_VARIABLES CACHE INTERNAL "")
    set(_CORR_PROP_HOST_BUILD CORROSION_USE_HOST_BUILD CACHE INTERNAL "")
else()
    set(_CORR_PROP_FEATURES INTERFACE_CORROSION_FEATURES CACHE INTERNAL "")
    set(_CORR_PROP_ALL_FEATURES INTERFACE_CORROSION_ALL_FEATURES CACHE INTERNAL "")
    set(_CORR_PROP_NO_DEFAULT_FEATURES INTERFACE_NO_DEFAULT_FEATURES CACHE INTERNAL "")
    set(_CORR_PROP_ENV_VARS INTERFACE_CORROSION_ENVIRONMENT_VARIABLES CACHE INTERNAL "")
    set(_CORR_PROP_HOST_BUILD INTERFACE_CORROSION_USE_HOST_BUILD CACHE INTERNAL "")
endif()

function(_add_cargo_build)
    set(options "")
    set(one_value_args PACKAGE TARGET MANIFEST_PATH PROFILE)
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
    set(cargo_profile_name "${ACB_PROFILE}")

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

    # For MSVC targets, don't mess with linker preferences.
    # TODO: We still should probably make sure that rustc is using the correct cl.exe to link programs.
    if (NOT MSVC)
        set(languages C CXX Fortran)

        set(has_compiler OFF)
        foreach(language ${languages})
            if (CMAKE_${language}_COMPILER)
                set(has_compiler ON)
            endif()
        endforeach()

        # When cross-compiling a Rust crate, at the very least we need a C linker
        if (NOT has_compiler AND CMAKE_CROSSCOMPILING)
            message(STATUS "Enabling the C compiler for linking Rust programs")
            enable_language(C)
        endif()

        # Determine the linker CMake prefers based on the enabled languages.
        set(_CORROSION_LINKER_PREFERENCE_SCORE "0")
        foreach(language ${languages})
            if( ${CMAKE_${language}_LINKER_PREFERENCE} )
                if(NOT CORROSION_LINKER_PREFERENCE
                    OR (${CMAKE_${language}_LINKER_PREFERENCE} GREATER ${_CORROSION_LINKER_PREFERENCE_SCORE}))
                    set(CORROSION_LINKER_PREFERENCE "${CMAKE_${language}_COMPILER}")
                    set(CORROSION_LINKER_PREFERENCE_TARGET "${CMAKE_${language}_COMPILER_TARGET}")
                    set(CORROSION_LINKER_PREFERENCE_LANGUAGE "${language}")
                    set(_CORROSION_LINKER_PREFERENCE_SCORE "${CMAKE_${language}_LINKER_PREFERENCE}")
                endif()
            endif()
        endforeach()
        message(VERBOSE "CORROSION_LINKER_PREFERENCE for target ${target_name}: ${CORROSION_LINKER_PREFERENCE}")
    endif()

    if (NOT CMAKE_CONFIGURATION_TYPES)
        set(target_dir ${CMAKE_CURRENT_BINARY_DIR})
        if (CMAKE_BUILD_TYPE STREQUAL "" OR CMAKE_BUILD_TYPE STREQUAL Debug)
            set(build_type_dir debug)
        else()
            set(build_type_dir release)
        endif()
    else()
        set(target_dir ${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>)
        set(build_type_dir $<IF:$<OR:$<CONFIG:Debug>,$<CONFIG:>>,debug,release>)
    endif()

    # If a CMake sysroot is specified, forward it to the linker rustc invokes, too. CMAKE_SYSROOT is documented
    # to be passed via --sysroot, so we assume that when it's set, the linker supports this option in that style.
    if(CMAKE_CROSSCOMPILING AND CMAKE_SYSROOT)
        set(corrosion_link_args "--sysroot=${CMAKE_SYSROOT}")
    endif()

    if(COR_ALL_FEATURES)
        set(all_features_arg --all-features)
    endif()
    if(COR_NO_DEFAULT_FEATURES)
        set(no_default_features_arg --no-default-features)
    endif()
    if(COR_NO_STD)
        set(no_default_libraries_arg --no-default-libraries)
    endif()

    set(rustflags_target_property "$<TARGET_GENEX_EVAL:${target_name},$<TARGET_PROPERTY:${target_name},INTERFACE_CORROSION_RUSTFLAGS>>")
    # `rustflags_target_property` may contain multiple arguments and double quotes, so we _should_ single quote it to
    # preserve any double quotes and keep it as one argument value. However single quotes don't work on windows, so we
    # can only add double quotes here. Any double quotes _in_ the rustflags must be escaped like `\\\"`.
    set(rustflags_genex "$<$<BOOL:${rustflags_target_property}>:--rustflags=\"${rustflags_target_property}\">")

    set(features_target_property "$<GENEX_EVAL:$<TARGET_PROPERTY:${target_name},${_CORR_PROP_FEATURES}>>")
    set(features_genex "$<$<BOOL:${features_target_property}>:--features=$<JOIN:${features_target_property},$<COMMA>>>")

    # target property overrides corrosion_import_crate argument
    set(all_features_target_property "$<GENEX_EVAL:$<TARGET_PROPERTY:${target_name},${_CORR_PROP_ALL_FEATURES}>>")
    set(all_features_property_exists_condition "$<NOT:$<STREQUAL:${all_features_target_property},>>")
    set(all_features_property_arg "$<IF:$<BOOL:${all_features_target_property}>,--all-features,>")
    set(all_features_arg "$<IF:${all_features_property_exists_condition},${all_features_property_arg},${all_features_arg}>")

    set(no_default_features_target_property "$<GENEX_EVAL:$<TARGET_PROPERTY:${target_name},${_CORR_PROP_NO_DEFAULT_FEATURES}>>")
    set(no_default_features_property_exists_condition "$<NOT:$<STREQUAL:${no_default_features_target_property},>>")
    set(no_default_features_property_arg "$<IF:$<BOOL:${no_default_features_target_property}>,--no-default-features,>")
    set(no_default_features_arg "$<IF:${no_default_features_property_exists_condition},${no_default_features_property_arg},${no_default_features_arg}>")

    set(build_env_variable_genex "$<GENEX_EVAL:$<TARGET_PROPERTY:${target_name},${_CORR_PROP_ENV_VARS}>>")
    set(if_not_host_build_condition "$<NOT:$<BOOL:$<TARGET_PROPERTY:${target_name},${_CORR_PROP_HOST_BUILD}>>>")

    set(corrosion_link_args "$<${if_not_host_build_condition}:${corrosion_link_args}>")
    set(cargo_target_option "$<IF:${if_not_host_build_condition},--target=${_CORROSION_RUST_CARGO_TARGET},--target=${_CORROSION_RUST_CARGO_HOST_TARGET}>")
    set(target_artifact_dir "$<IF:${if_not_host_build_condition},${_CORROSION_RUST_CARGO_TARGET},${_CORROSION_RUST_CARGO_HOST_TARGET}>")

    # Rust will add `-lSystem` as a flag for the linker on macOS. Adding the -L flag via RUSTFLAGS only fixes the
    # problem partially - buildscripts still break, since they won't receive the RUSTFLAGS. This seems to only be a
    # problem if we specify the linker ourselves (which we do, since this is necessary for e.g. linking C++ code).
    # We can however set `LIBRARY_PATH`, which is propagated to the build-script-build properly.
    if(NOT CMAKE_CROSSCOMPILING AND CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        set(cargo_library_path "LIBRARY_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib")
    elseif(CMAKE_CROSSCOMPILING AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        set(cargo_library_path "$<IF:${if_not_host_build_condition},,LIBRARY_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib>")
    endif()

    if(cargo_profile_name)
        set(cargo_profile "--profile=${cargo_profile_name}")
        set(build_type_dir "${cargo_profile_name}")
    else()
        set(cargo_profile $<$<NOT:$<OR:$<CONFIG:Debug>,$<CONFIG:>>>:--release>)
    endif()

    set(cargo_build_dir "${CMAKE_BINARY_DIR}/${build_dir}/cargo/build/${target_artifact_dir}/${build_type_dir}")
    set(build_byproducts)
    set(byproducts)
    foreach(byproduct_file ${ACB_BYPRODUCTS})
        list(APPEND build_byproducts "${cargo_build_dir}/${byproduct_file}")
        if (CMAKE_CONFIGURATION_TYPES AND CMAKE_VERSION VERSION_GREATER_EQUAL 3.20.0)
            list(APPEND byproducts "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/${byproduct_file}")
        else()
            list(APPEND byproducts "${CMAKE_CURRENT_BINARY_DIR}/${byproduct_file}")
        endif()
    endforeach()

    set(features_args)
    foreach(feature ${COR_FEATURES})
        list(APPEND features_args --features ${feature})
    endforeach()

    set(corrosion_cc_rs_flags)

    if(CMAKE_C_COMPILER AND _CORROSION_RUST_CARGO_TARGET_UNDERSCORE)
        # This variable is read by cc-rs (often used in build scripts) to determine the c-compiler.
        # It can still be overridden if the user sets the non underscore variant via the environment variables
        # on the target.
        list(APPEND corrosion_cc_rs_flags "CC_${_CORROSION_RUST_CARGO_TARGET_UNDERSCORE}=${CMAKE_C_COMPILER}")
    endif()
    if(DEFINED ENV{CC})
        # HOST_CC has a lower priority then CC_<target_triple> for cc-rs.
        list(APPEND corrosion_cc_rs_flags "HOST_CC=$ENV{CC}")
    endif()
    if(CMAKE_CXX_COMPILER AND _CORROSION_RUST_CARGO_TARGET_UNDERSCORE)
        list(APPEND corrosion_cc_rs_flags "CXX_${_CORROSION_RUST_CARGO_TARGET_UNDERSCORE}=${CMAKE_CXX_COMPILER}")
    endif()
    if(DEFINED ENV{CXX})
        list(APPEND corrosion_cc_rs_flags "HOST_CXX=$ENV{CXX}")
    endif()
    # Since we instruct cc-rs to use the compiler found by CMake, it is likely one that requires also
    # specifying the target sysroot to use. CMake's generator makes sure to pass --sysroot with
    # CMAKE_OSX_SYSROOT. Fortunately the compilers Apple ships also respect the SDKROOT environment
    # variable, which we can set for use when cc-rs invokes the compiler.
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin" AND CMAKE_OSX_SYSROOT)
        list(APPEND corrosion_cc_rs_flags "SDKROOT=${CMAKE_OSX_SYSROOT}")
    endif()

    corrosion_add_target_rustflags("${target_name}" "$<$<BOOL:${corrosion_link_args}>:-Clink-args=${corrosion_link_args}>")

    # todo: this should probably also be guarded by if_not_host_build_condition.
    if(COR_NO_STD)
        corrosion_add_target_rustflags("${target_name}" "-Cdefault-linker-libraries=no")
    else()
        corrosion_add_target_rustflags("${target_name}" "-Cdefault-linker-libraries=yes")
    endif()

    set(rustflags_genex_test "$<$<BOOL:${rustflags_target_property}>:RUSTFLAGS=\"${rustflags_target_property}\">")

    if(CORROSION_LINKER_PREFERENCE)
        if(CMAKE_CROSSCOMPILING)
            # CMake does not offer a host compiler we could select when configured for cross-compiling. This
            # effectively means that by default cc will be selected for builds targeting host. The user can still
            # override this by manually adding the appropriate rustflags to select the compiler for the target!
            set(cargo_target_linker "$<${if_not_host_build_condition}:CARGO_TARGET_${_CORROSION_RUST_CARGO_TARGET_UPPER}_LINKER=${CORROSION_LINKER_PREFERENCE}>")
        else()
            set(cargo_target_linker "CARGO_TARGET_${_CORROSION_RUST_CARGO_TARGET_UPPER}_LINKER=${CORROSION_LINKER_PREFERENCE}")
        endif()
        # Will be only set for cross-compilers like clang, c.f. `CMAKE_<LANG>_COMPILER_TARGET`.
        if(CORROSION_LINKER_PREFERENCE_TARGET)
            corrosion_add_target_rustflags("${target_name}" "-Clink-args=--target=${CORROSION_LINKER_PREFERENCE_TARGET}")
        endif()
    else()
        message(STATUS "No linker preference for target ${target_name} could be detected.")
    endif()

    add_custom_target(
    cargo-build_${target_name}
    ALL
    # Ensure the target directory exists
    COMMAND
        ${CMAKE_COMMAND} -E make_directory ${target_dir}
    # Build crate
    COMMAND
        ${CMAKE_COMMAND} -E env
            ${build_env_variable_genex}
            ${rustflags_genex_test}
            ${cargo_target_linker}
            ${corrosion_cc_rs_flags}
            ${cargo_library_path}
            CORROSION_BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
            CARGO_BUILD_RUSTC="${_CORROSION_RUSTC}"
        "${_CORROSION_CARGO}"
            build
            ${cargo_target_option}
            ${_CORROSION_VERBOSE_OUTPUT_FLAG}
            # Global --features arguments added via corrosion_import_crate()
            ${features_args}
            ${all_features_arg}
            ${no_default_features_arg}
            # Target specific features added via corrosion_set_features().
            ${features_genex}
            --package ${package_name}
            --manifest-path "${path_to_toml}"
            ${cargo_profile}

    # Copy crate artifacts to the binary dir
    COMMAND
        ${CMAKE_COMMAND} -E copy_if_different ${build_byproducts} ${target_dir}
    BYPRODUCTS ${byproducts}
    # The build is conducted in root build directory so that cargo
    # dependencies are shared
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/${build_dir}
    USES_TERMINAL
    COMMAND_EXPAND_LISTS
    )

    add_custom_target(
        cargo-clean_${target_name}
        COMMAND
            $<TARGET_FILE:Rust::Cargo> clean --target ${_CORROSION_RUST_CARGO_TARGET}
            -p ${package_name} --manifest-path ${path_to_toml}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/${build_dir}
        USES_TERMINAL
    )

    if (NOT TARGET cargo-clean)
        add_custom_target(cargo-clean)
    endif()
    add_dependencies(cargo-clean cargo-clean_${target_name})
endfunction(_add_cargo_build)

function(corrosion_import_crate)
    set(OPTIONS ALL_FEATURES NO_DEFAULT_FEATURES NO_STD)
    set(ONE_VALUE_KEYWORDS MANIFEST_PATH PROFILE)
    set(MULTI_VALUE_KEYWORDS CRATES FEATURES)
    cmake_parse_arguments(COR "${OPTIONS}" "${ONE_VALUE_KEYWORDS}" "${MULTI_VALUE_KEYWORDS}" ${ARGN})

    if (NOT DEFINED COR_MANIFEST_PATH)
        message(FATAL_ERROR "MANIFEST_PATH is a required keyword to corrosion_add_crate")
    endif()

    if(COR_PROFILE)
        if(Rust_VERSION VERSION_LESS 1.57.0)
            message(FATAL_ERROR "Selecting custom profiles via `PROFILE` requires at least rust 1.57.0, but you "
                        "have ${Rust_VERSION}."
        )
        else()
            set(cargo_profile --profile=${COR_PROFILE})
        endif()
    endif()

    if (NOT IS_ABSOLUTE "${COR_MANIFEST_PATH}")
        set(COR_MANIFEST_PATH ${CMAKE_CURRENT_SOURCE_DIR}/${COR_MANIFEST_PATH})
    endif()

    if (CORROSION_NATIVE_TOOLING)
        execute_process(
            COMMAND
                ${_CORROSION_GENERATOR}
                    --manifest-path ${COR_MANIFEST_PATH}
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
            "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_FILES_DIRECTORY}/corrosion/${toml_dir_name}.dir/cargo-build.cmake"
        )

        if (CMAKE_VS_PLATFORM_NAME)
            set (_CORROSION_CONFIGURATION_ROOT --configuration-root ${CMAKE_VS_PLATFORM_NAME})
        endif()

        if (_CORROSION_RUST_CARGO_TARGET)
            set(_CORROSION_TARGET --target ${_CORROSION_RUST_CARGO_TARGET})
        endif()

        if(CMAKE_CONFIGURATION_TYPES)
            string (REPLACE ";" "," _CONFIGURATION_TYPES
                "${CMAKE_CONFIGURATION_TYPES}")
            set (_CORROSION_CONFIGURATION_TYPES --configuration-types
                ${_CONFIGURATION_TYPES})
        elseif(CMAKE_BUILD_TYPE)
            set (_CORROSION_CONFIGURATION_TYPES --configuration-type
                ${CMAKE_BUILD_TYPE})
        else()
            # uses default build type
        endif()

        set(no_default_libs_arg)
        if(COR_NO_STD)
            set(no_default_libs_arg "--no-default-libraries")
        endif()

        set(crates_args)
        foreach(crate ${COR_CRATES})
            list(APPEND crates_args --crates ${crate})
        endforeach()

        execute_process(
            COMMAND
                ${_CORROSION_GENERATOR}
                    --manifest-path ${COR_MANIFEST_PATH}
                    gen-cmake
                        ${_CORROSION_CONFIGURATION_ROOT}
                        ${_CORROSION_TARGET}
                        ${_CORROSION_CONFIGURATION_TYPES}
                        ${crates_args}
                        ${cargo_profile}
                        ${no_default_libs_arg}
                        --cargo-version ${_CORROSION_CARGO_VERSION}
                        -o ${generated_cmake}
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            RESULT_VARIABLE ret)

        if (NOT ret EQUAL "0")
            message(FATAL_ERROR "corrosion-generator failed")
        endif()

        include(${generated_cmake})
    else()
        _generator_add_cargo_targets(
            MANIFEST_PATH
                "${COR_MANIFEST_PATH}"
            CONFIGURATION_ROOT
                "${CMAKE_VS_PLATFORM_NAME}"
            TARGET
                "${_CORROSION_RUST_CARGO_TARGET}"
            CARGO_VERSION
                "${_CORROSION_CARGO_VERSION}"
            CONFIGURATION_TYPE
                "${CMAKE_BUILD_TYPE}"
            CONFIGURATION_TYPES
                "${CMAKE_CONFIGURATION_TYPES}"
            CRATES
                "${COR_CRATES}"
            PROFILE
                "${COR_PROFILE}"
        )
    endif()
endfunction(corrosion_import_crate)

function(add_crate path_to_toml)
    message(DEPRECATION "add_crate is deprecated. Switch to corrosion_import_crate.")

    corrosion_import_crate(MANIFEST_PATH ${path_to_toml})
endfunction(add_crate)

function(corrosion_set_linker_language target_name language)
    set_property(
        TARGET cargo-build_${target_name}
        PROPERTY LINKER_LANGUAGE ${language}
    )
endfunction()

function(corrosion_set_hostbuild target_name)
    # Configure the target to be compiled for the Host target and ignore any cross-compile configuration.
    set_property(
            TARGET ${target_name}
            PROPERTY ${_CORR_PROP_HOST_BUILD} 1
    )
endfunction()

function(corrosion_add_target_rustflags target_name rustflag)
    # Additional rustflags may be passed as optional parameters after rustflag.
    set_property(
            TARGET ${target_name}
            APPEND
            PROPERTY INTERFACE_CORROSION_RUSTFLAGS ${rustflag} ${ARGN}
    )
endfunction()

function(corrosion_set_env_vars target_name env_var)
    # Additional environment variables may be passed as optional parameters after env_var.
    set_property(
        TARGET ${target_name}
        APPEND
        PROPERTY ${_CORR_PROP_ENV_VARS} ${env_var} ${ARGN}
    )
endfunction()

function(corrosion_set_features target_name)
    # corrosion_set_features(<target_name> [ALL_FEATURES=Bool] [NO_DEFAULT_FEATURES] [FEATURES <feature1> ... ])
    set(options NO_DEFAULT_FEATURES)
    set(one_value_args ALL_FEATURES)
    set(multi_value_args FEATURES)
    cmake_parse_arguments(
            PARSE_ARGV 1
            SET
            "${options}"
            "${one_value_args}"
            "${multi_value_args}"
    )

    if(DEFINED SET_ALL_FEATURES)
        set_property(
                TARGET ${target_name}
                PROPERTY ${_CORR_PROP_ALL_FEATURES} ${SET_ALL_FEATURES}
        )
    endif()
    if(SET_NO_DEFAULT_FEATURES)
        set_property(
                TARGET ${target_name}
                PROPERTY ${_CORR_PROP_NO_DEFAULT_FEATURES} 1
        )
    endif()
    if(SET_FEATURES)
        set_property(
                TARGET ${target_name}
                APPEND
                PROPERTY ${_CORR_PROP_FEATURES} ${SET_FEATURES}
        )
    endif()
endfunction()

function(cargo_link_libraries)
    message(DEPRECATION "cargo_link_libraries is deprecated. Switch to corrosion_link_libraries.")

    corrosion_link_libraries(${ARGN})
endfunction(cargo_link_libraries)

function(corrosion_link_libraries target_name)
    add_dependencies(cargo-build_${target_name} ${ARGN})
    foreach(library ${ARGN})
        set_property(
            TARGET cargo-build_${target_name}
            APPEND
            PROPERTY CARGO_DEPS_LINKER_LANGUAGES
            $<TARGET_PROPERTY:${library},LINKER_LANGUAGE>
        )

        corrosion_add_target_rustflags(${target_name} "-L$<TARGET_LINKER_FILE_DIR:${library}>")
        corrosion_add_target_rustflags(${target_name} "-l$<TARGET_LINKER_FILE_BASE_NAME:${library}>")
    endforeach()
endfunction(corrosion_link_libraries)

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
