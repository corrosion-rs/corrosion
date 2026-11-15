# This test asserts that incremental builds after edits to Rust code cause rebuilds of C++ code
# depending on generate headers, when necessary.
# This is mostly relevant for the Ninja Generator.
cmake_minimum_required(VERSION 3.22)
file(REMOVE_RECURSE "${TEST_BINARY_DIR}")
file(MAKE_DIRECTORY "${TEST_BINARY_DIR}/src")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/incremental/" DESTINATION "${TEST_BINARY_DIR}/src")
set(build_dir "${TEST_BINARY_DIR}/build")
set(configure_args)
foreach(language C CXX)
    if(TEST_${language}_COMPILER)
        list(APPEND configure_args "-DCMAKE_${language}_COMPILER=${TEST_${language}_COMPILER}")
    endif()
endforeach()
if(TEST_CRUBIT_SOURCE_DIR)
    list(APPEND configure_args "-DFETCHCONTENT_SOURCE_DIR_CRUBIT=${TEST_CRUBIT_SOURCE_DIR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${TEST_BINARY_DIR}/src" -B "${build_dir}"
    -G "${TEST_GENERATOR}" "-DCORROSION_SOURCE_DIR=${CORROSION_SOURCE_DIR}"
    "-DRust_TOOLCHAIN=${TEST_RUST_TOOLCHAIN}"
    ${configure_args}
    COMMAND_ERROR_IS_FATAL ANY)

set(bin_dir "${build_dir}")
if(TEST_MULTI_CONFIG)
    string(APPEND bin_dir "/Debug")
endif()
if(CMAKE_HOST_WIN32)
    set(suffix .exe)
endif()

function(build_and_check expected expected_dep)
    execute_process(COMMAND "${CMAKE_COMMAND}" --build "${build_dir}" --config Debug
        COMMAND_ERROR_IS_FATAL ANY)
    execute_process(COMMAND "${bin_dir}/main${suffix}" OUTPUT_VARIABLE actual
        COMMAND_ERROR_IS_FATAL ANY)
    execute_process(COMMAND "${bin_dir}/dependency_only${suffix}" OUTPUT_VARIABLE actual_dep
        COMMAND_ERROR_IS_FATAL ANY)
    if(NOT actual STREQUAL expected OR NOT actual_dep STREQUAL expected_dep)
        message(FATAL_ERROR "Stale bindings: expected '${expected}' / '${expected_dep}', got '${actual}' / '${actual_dep}'")
    endif()
endfunction()

build_and_check("11 11" "10")

set(rust_source "${TEST_BINARY_DIR}/src/src/lib.rs")
file(READ "${rust_source}" source)
string(REPLACE "API_VERSION: u32 = 1" "API_VERSION: u32 = 2" source "${source}")
file(WRITE "${rust_source}" "${source}")
build_and_check("12 12" "10")

# Change the API of a real dependency and check a consumer that includes only its header.
set(dependency_source "${TEST_BINARY_DIR}/src/dependency/src/lib.rs")
file(READ "${dependency_source}" source)
string(REPLACE "DEP_VERSION: u32 = 10" "DEP_VERSION: u32 = 20" source "${source}")
file(WRITE "${dependency_source}" "${source}")
build_and_check("22 22" "20")
build_and_check("22 22" "20")

# Missing generated headers must be regenerated in the same build too.
file(REMOVE_RECURSE "${build_dir}/corrosion_generated")
build_and_check("22 22" "20")
