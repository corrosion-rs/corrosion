# This option is currently used to prevent recursion
option(CORROSION_TESTS "Enable Corrosion tests" ON)
mark_as_advanced(CORROSION_TESTS)
if(NOT CORROSION_TESTS)
    return()
endif()

option(CORROSION_TESTS_CXXBRIDGE
        "Build cxxbridge tests which requires cxxbridge executable being available"
        OFF)
find_program(_corrosion_crubit_installed cargo-cpp_api_from_rust)
if(_corrosion_crubit_installed)
    set(_corrosion_tests_crubit_default ON)
else()
    set(_corrosion_tests_crubit_default OFF)
endif()
option(CORROSION_TESTS_CRUBIT
        "Build Crubit tests which requires Crubit and a compatible toolchain being available"
        ${_corrosion_tests_crubit_default})
option(CORROSION_TESTS_KEEP_BUILDDIRS
    "By default corrosion tests will cleanup after themselves. This option limits the cleaning up to the
     target directories and will keep the build directories, which may be useful for caching."
    OFF)
mark_as_advanced(CORROSION_TESTS_KEEP_BUILDDIRS)

set(test_install_path "${CMAKE_CURRENT_BINARY_DIR}/test-install-corrosion")

option(CORROSION_TESTS_INSTALL_CORROSION
        "Install Corrosion to a test directory and let tests use the installed Corrosion"
        OFF)
if(CORROSION_TESTS_INSTALL_CORROSION)
    add_test(NAME "install_corrosion_configure"
        COMMAND
            ${CMAKE_COMMAND}
            -S "${CMAKE_CURRENT_SOURCE_DIR}/.."
            -B "${CMAKE_CURRENT_BINARY_DIR}/build-corrosion"
            -DCORROSION_VERBOSE_OUTPUT=ON
            -DCORROSION_TESTS=OFF
            -DCMAKE_BUILD_TYPE=Release
            -G${CMAKE_GENERATOR}
            "-DCMAKE_INSTALL_PREFIX=${test_install_path}"
    )
    add_test(NAME "install_corrosion_build"
            COMMAND
            ${CMAKE_COMMAND} --build "${CMAKE_CURRENT_BINARY_DIR}/build-corrosion" --config Release
            )
    add_test(NAME "install_corrosion_install"
            COMMAND
            ${CMAKE_COMMAND} --install "${CMAKE_CURRENT_BINARY_DIR}/build-corrosion" --config Release
        )
    set_tests_properties("install_corrosion_configure" PROPERTIES FIXTURES_SETUP "fixture_corrosion_configure")
    set_tests_properties("install_corrosion_build"     PROPERTIES FIXTURES_SETUP "fixture_corrosion_build")
    set_tests_properties("install_corrosion_build"     PROPERTIES FIXTURES_REQUIRED "fixture_corrosion_configure")
    set_tests_properties("install_corrosion_install"   PROPERTIES FIXTURES_REQUIRED "fixture_corrosion_build")
    set_tests_properties("install_corrosion_install"   PROPERTIES FIXTURES_SETUP "fixture_corrosion_install")

    add_test(NAME "install_corrosion_build_cleanup" COMMAND "${CMAKE_COMMAND}" -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/build-corrosion")
    set_tests_properties("install_corrosion_build_cleanup" PROPERTIES
        FIXTURES_CLEANUP
        "fixture_corrosion_configure;fixture_corrosion_build"
    )

    add_test(NAME "install_corrosion_cleanup" COMMAND "${CMAKE_COMMAND}" -E remove_directory "${test_install_path}")
    set_tests_properties("install_corrosion_cleanup" PROPERTIES
        FIXTURES_CLEANUP
        "fixture_corrosion_configure;fixture_corrosion_build;fixture_corrosion_install"
    )
endif()

# Settings of this build that every test project inherits. A variable is forwarded if it
# is non-empty when `corrosion_tests_add_test()` is called, so a test can override one by setting
# a normal variable before the call (see `custom_target`) or via `CACHE_VARS`.
set(_corrosion_tests_forwarded_variables
    CMAKE_C_COMPILER
    CMAKE_CXX_COMPILER
    CMAKE_C_COMPILER_TARGET
    CMAKE_CXX_COMPILER_TARGET
    CMAKE_OSX_ARCHITECTURES
    CMAKE_OSX_SYSROOT
    CMAKE_TOOLCHAIN_FILE
    CORROSION_VERBOSE_OUTPUT
    Rust_TOOLCHAIN
    Rust_CARGO_TARGET
    Rust_RUSTUP_INSTALL_MISSING_TARGET
)
if(CMAKE_CROSSCOMPILING)
    list(APPEND _corrosion_tests_forwarded_variables CMAKE_SYSTEM_NAME)
    # Only forward a user-specified version, not one CMake computed itself (e.g. for Android).
    if(DEFINED CACHE{CMAKE_SYSTEM_VERSION})
        list(APPEND _corrosion_tests_forwarded_variables CMAKE_SYSTEM_VERSION)
    endif()
endif()
get_property(_corrosion_tests_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT _corrosion_tests_is_multi_config)
    list(APPEND _corrosion_tests_forwarded_variables CMAKE_BUILD_TYPE)
endif()

# Appends a `set(<name> [=[<value>]=] CACHE <type> "" FORCE)` line for an initial-cache script
# (`cmake -C`) to the variable <out_var>. CMake reads bracket arguments verbatim, so we don't need to escape.
function(_corrosion_tests_append_cache_entry out_var name type value)
    string(FIND "${value}]" "]=]" closing_bracket_pos)
    if(NOT closing_bracket_pos EQUAL -1 OR "${value}" MATCHES "^\n|\r\n")
        message(FATAL_ERROR "The value of `${name}` can't be passed to a test project: `${value}`")
    endif()
    set(${out_var} "${${out_var}}set(${name} [=[${value}]=] CACHE ${type} \"\" FORCE)\n" PARENT_SCOPE)
endfunction()

# corrosion_tests_add_test(<test_name> <bin_names>
#                          [TEST_SRC_DIR <dir>]
#                          [IS_HOSTBUILD]
#                          [CACHE_VARS <name>[:<type>]=<value>...])
#
# Adds the test `<test_name>_build`, which configures and builds the CMake project in the directory
# `<dir>` (default: `<test_name>`) in `build-<test_name>`, and a test `<test_name>_run_<bin>` for each
# executable in the list <bin_names> (may be ""). The run tests are disabled when cross-compiling,
# unless IS_HOSTBUILD is given.
#
# The test project is configured with an initial cache file (`cmake -C`), which contains the settings
# in `_corrosion_tests_forwarded_variables` and then the CACHE_VARS, so CACHE_VARS take precedence.
# Values are written verbatim, so lists and spaces need no special care, as long as each entry is a
# single (quoted) argument:
#     CACHE_VARS "CMAKE_OSX_ARCHITECTURES=arm64;x86_64" MY_OPTION:BOOL=ON
function(corrosion_tests_add_test test_name bin_names)
    set(options "IS_HOSTBUILD")
    set(one_value_keywords "TEST_SRC_DIR")
    set(multi_value_keywords "CACHE_VARS")
    cmake_parse_arguments(PARSE_ARGV 2 TST "${options}" "${one_value_keywords}" "${multi_value_keywords}")
    if(TST_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "corrosion_tests_add_test(${test_name}): Unexpected arguments: `${TST_UNPARSED_ARGUMENTS}`.\n"
            "Valid keywords are: ${options} ${one_value_keywords} ${multi_value_keywords}. "
            "Variables for the test project are passed as `CACHE_VARS <name>=<value>`.")
    endif()
    foreach(keyword IN LISTS TST_KEYWORDS_MISSING_VALUES)
        if(keyword IN_LIST one_value_keywords)
            message(FATAL_ERROR "corrosion_tests_add_test(${test_name}): `${keyword}` requires a value.")
        endif()
    endforeach()

# In the future we could add multiple tests here for different configurations (generator, build mode, rust version ...)
# which would allow us to simplify the github job matrix
    if(TST_TEST_SRC_DIR)
        set(test_dir "${TST_TEST_SRC_DIR}")
    else()
        set(test_dir "${test_name}")
    endif()

    set(initial_cache "# Generated by corrosion_tests_add_test(${test_name}). Do not edit.\n")
    foreach(var IN LISTS _corrosion_tests_forwarded_variables)
        if(NOT "${${var}}" STREQUAL "")
            _corrosion_tests_append_cache_entry(initial_cache "${var}" STRING "${${var}}")
        endif()
    endforeach()
    if(CORROSION_TESTS_INSTALL_CORROSION)
        _corrosion_tests_append_cache_entry(initial_cache CORROSION_TESTS_FIND_CORROSION BOOL ON)
        _corrosion_tests_append_cache_entry(initial_cache CORROSION_TESTS_INSTALL_PREFIX PATH "${test_install_path}")
    endif()
    foreach(entry IN LISTS TST_CACHE_VARS)
        if(NOT "${entry}" MATCHES "^([A-Za-z_][A-Za-z0-9_.+-]*)(:([A-Za-z]+))?=(.*)$")
            message(FATAL_ERROR "corrosion_tests_add_test(${test_name}): CACHE_VARS entry `${entry}` "
                "is not of the form `<name>[:<type>]=<value>` (note: without a leading `-D`).")
        endif()
        set(name "${CMAKE_MATCH_1}")
        set(value "${CMAKE_MATCH_4}")
        string(TOUPPER "${CMAKE_MATCH_3}" type)
        if(type STREQUAL "")
            set(type STRING)
        elseif(NOT type MATCHES "^(BOOL|FILEPATH|PATH|STRING|INTERNAL)$")
            message(FATAL_ERROR "corrosion_tests_add_test(${test_name}): Invalid cache type `${type}` in `${entry}`.")
        endif()
        _corrosion_tests_append_cache_entry(initial_cache "${name}" "${type}" "${value}")
    endforeach()
    # Note: This file must be outside of the test's binary directory, which is deleted before configuring.
    set(initial_cache_file "${CMAKE_CURRENT_BINARY_DIR}/${test_name}-initial-cache.cmake")
    file(WRITE "${initial_cache_file}" "${initial_cache}")

    add_test(NAME "${test_name}_build"
            COMMAND
            ${CMAKE_COMMAND}
            "-DTEST_SOURCE_DIR=${CMAKE_CURRENT_LIST_DIR}/${test_dir}"
            "-DTEST_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/build-${test_name}"
            "-DTEST_GENERATOR=${CMAKE_GENERATOR}"
            "-DTEST_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}"
            "-DTEST_INITIAL_CACHE=${initial_cache_file}"
            -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ConfigureAndBuild.cmake"
            )
    set_tests_properties("${test_name}_build" PROPERTIES FIXTURES_SETUP "build_fixture_${test_name}")
    if(CORROSION_TESTS_INSTALL_CORROSION)
        set_tests_properties("${test_name}_build" PROPERTIES FIXTURES_REQUIRED "fixture_corrosion_install")
    endif()
    foreach(bin ${bin_names})
        if(WIN32)
            set(bin_filename "${bin}.exe")
        else()
            set(bin_filename "${bin}")
        endif()
        add_test(NAME "${test_name}_run_${bin}" COMMAND "${CMAKE_CURRENT_BINARY_DIR}/build-${test_name}/${bin_filename}")
        set_tests_properties("${test_name}_run_${bin}" PROPERTIES FIXTURES_REQUIRED "build_fixture_${test_name}")
        # CMAKE_CROSSCOMPILING is not set when cross-compiling with VS (via -A flag).
        # Todo: We could run x86 binaries on x64 hosts.
        if((CMAKE_CROSSCOMPILING OR CMAKE_VS_PLATFORM_NAME) AND NOT "${TST_IS_HOSTBUILD}")
            # Todo: In the future we could potentially run some tests with qemu.
            set_tests_properties("${test_name}_run_${bin}" PROPERTIES DISABLED TRUE)
        endif()
    endforeach()

    if(CORROSION_TESTS_KEEP_BUILDDIRS)
        add_test(NAME "${test_name}_cleanup_artifacts"
            COMMAND "${CMAKE_COMMAND}" --build "${CMAKE_CURRENT_BINARY_DIR}/build-${test_name}" --target clean
        )
        add_test(NAME "${test_name}_cleanup_cargo"
            COMMAND "${CMAKE_COMMAND}" -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/build-${test_name}/cargo"
            )
        set_tests_properties("${test_name}_cleanup_artifacts" PROPERTIES FIXTURES_CLEANUP "build_fixture_${test_name}")
        set_tests_properties("${test_name}_cleanup_cargo" PROPERTIES FIXTURES_CLEANUP "build_fixture_${test_name}")
    else()
        add_test(NAME "${test_name}_cleanup" COMMAND "${CMAKE_COMMAND}" -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/build-${test_name}")
        set_tests_properties("${test_name}_cleanup" PROPERTIES FIXTURES_CLEANUP "build_fixture_${test_name}")
    endif()
endfunction()

# Please keep this in alphabetical order.
add_subdirectory(config_discovery)
add_subdirectory(cargo_flags)
add_subdirectory(cpp2rust)
if(Rust_VERSION VERSION_GREATER_EQUAL "1.64.0")
    # Flag `--crate-type` is only supported since Rust 1.64.0
    add_subdirectory(crate_type)
    if(CORROSION_TESTS_CRUBIT)
        add_subdirectory(crubit)
    endif()
    add_subdirectory(override_crate_type)
endif()
add_subdirectory(custom_profiles)
if(NOT Rust_CROSSCOMPILING AND Rust_VERSION VERSION_GREATER_EQUAL "1.60.0")
    add_subdirectory(custom_target)
endif()
add_subdirectory(cbindgen)
add_subdirectory(corrosion_install)
add_subdirectory(cxxbridge)
add_subdirectory(envvar)
add_subdirectory(features)
add_subdirectory(find_rust)
add_subdirectory(gensource)
add_subdirectory(hostbuild)
add_subdirectory(multitarget)
add_subdirectory(nostd)
add_subdirectory("output directory")
add_subdirectory(parse_target_triple)
add_subdirectory(rust2cpp)
add_subdirectory(rustflags)
add_subdirectory(workspace)
