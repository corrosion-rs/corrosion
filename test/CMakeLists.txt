cmake_minimum_required(VERSION 3.15)
project(CorrosionTests LANGUAGES CXX)

# If building the tests as a top-level project
if (CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
    # Add option to disable the external Corrosion if necessary
    option(CORROSION_TESTS_FIND_CORROSION "Use Corrosion as a subdirectory" OFF)
    if (CORROSION_TESTS_FIND_CORROSION)
        find_package(Corrosion REQUIRED)
    else()
        add_subdirectory(.. corrosion)
    endif()

    set(_TOP_LEVEL ON)
endif()

add_subdirectory(cpp2rust)
add_subdirectory(rust2cpp)
add_subdirectory(workspace)
add_subdirectory(rustflags)
add_subdirectory(nostd)
add_subdirectory(hostbuild)
add_subdirectory(envvar)
add_subdirectory(features)


if(Rust_VERSION VERSION_GREATER_EQUAL 1.57.0)
    add_subdirectory(custom_profiles)
endif()

# Config tests don't work if this is the top level directory.
if (NOT _TOP_LEVEL)
    add_subdirectory(config)
endif()

# gensource only works with external Corrosion
if (CORROSION_TESTS_FIND_CORROSION)
    add_subdirectory(gensource)
endif()
