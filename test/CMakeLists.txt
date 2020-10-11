cmake_minimum_required(VERSION 3.12)
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
endif()

add_subdirectory(cpp2rust)
add_subdirectory(rust2cpp)
add_subdirectory(workspace)