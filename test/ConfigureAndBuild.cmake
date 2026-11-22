# CMake script to configure and build a test project. Added by `corrosion_tests_add_test()`.
#
# Usage:
#   cmake -DTEST_SOURCE_DIR=<dir> -DTEST_BINARY_DIR=<dir> -DTEST_GENERATOR=<generator>
#         [-DTEST_GENERATOR_PLATFORM=<platform>] -DTEST_INITIAL_CACHE=<file>
#         -P ConfigureAndBuild.cmake
#
# All settings for the test project itself (compilers, Rust toolchain, test specific variables...)
# are in TEST_INITIAL_CACHE, which is passed to the test project via `cmake -C`.

foreach(required_var TEST_SOURCE_DIR TEST_BINARY_DIR TEST_GENERATOR TEST_INITIAL_CACHE)
    if("${${required_var}}" STREQUAL "")
        message(FATAL_ERROR "Test internal error: `${required_var}` must be set.")
    endif()
endforeach()

set(configure_args "")
if(TEST_GENERATOR_PLATFORM)
    list(APPEND configure_args "-A${TEST_GENERATOR_PLATFORM}")
endif()

# Remove old binary directory
file(REMOVE_RECURSE "${TEST_BINARY_DIR}")

file(MAKE_DIRECTORY "${TEST_BINARY_DIR}")

message(STATUS "TEST_BINARY_DIRECTORY: ${TEST_BINARY_DIR}")

# The settings aren't visible in the echoed configure command, so print them for debugging.
file(READ "${TEST_INITIAL_CACHE}" initial_cache_contents)
message(STATUS "Initial cache `${TEST_INITIAL_CACHE}`:\n${initial_cache_contents}")

execute_process(
    COMMAND
        "${CMAKE_COMMAND}"
            "-G${TEST_GENERATOR}"
            --log-level Debug
            ${configure_args}
            -C "${TEST_INITIAL_CACHE}"
            -S "${TEST_SOURCE_DIR}"
            -B "${TEST_BINARY_DIR}"
        COMMAND_ECHO STDOUT
        RESULT_VARIABLE EXIT_CODE
)

if (NOT "${EXIT_CODE}" EQUAL 0)
    message(FATAL_ERROR "Configure step failed. Exit code: `${EXIT_CODE}`")
endif()

if ("${TEST_GENERATOR}" STREQUAL "Ninja Multi-Config"
        OR "${TEST_GENERATOR}" MATCHES "Visual Studio"
    )
    foreach(config Debug Release RelWithDebInfo)
        execute_process(
                COMMAND "${CMAKE_COMMAND}"
                    --build "${TEST_BINARY_DIR}"
                    --config "${config}"
                COMMAND_ECHO STDOUT
                RESULT_VARIABLE EXIT_CODE
        )
        if (NOT "${EXIT_CODE}" EQUAL 0)
            message(FATAL_ERROR "Build step failed for config `${config}`. "
                    "Exit code: `${EXIT_CODE}`")
        endif()
    endforeach()
else()
    execute_process(
            COMMAND "${CMAKE_COMMAND}" --build "${TEST_BINARY_DIR}"
            COMMAND_ECHO STDOUT
            RESULT_VARIABLE EXIT_CODE
    )
    if (NOT "${EXIT_CODE}" EQUAL 0)
        message(FATAL_ERROR "Build step failed. Exit code: `${EXIT_CODE}`")
    endif()
endif()


