# Included by the test projects to make Corrosion available.
#
# By default, Corrosion is added from this source tree, so test projects can also be configured
# manually. When the tests run with `CORROSION_TESTS_INSTALL_CORROSION=ON`, the test harness sets
# `CORROSION_TESTS_FIND_CORROSION` and `CORROSION_TESTS_INSTALL_PREFIX`, and the installed
# Corrosion is used instead.
option(CORROSION_TESTS_FIND_CORROSION "Use an installed Corrosion instead of the source tree" OFF)
if(CORROSION_TESTS_FIND_CORROSION)
    if(NOT CORROSION_TESTS_INSTALL_PREFIX)
        message(FATAL_ERROR "CORROSION_TESTS_FIND_CORROSION requires CORROSION_TESTS_INSTALL_PREFIX to be set.")
    endif()
    set(CMAKE_PREFIX_PATH "${CORROSION_TESTS_INSTALL_PREFIX}" CACHE INTERNAL "" FORCE)
    find_package(Corrosion REQUIRED PATHS "${CORROSION_TESTS_INSTALL_PREFIX}" NO_CMAKE_SYSTEM_PATH)
else()
    get_filename_component(_corrosion_tests_source_dir "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
    add_subdirectory("${_corrosion_tests_source_dir}" corrosion)
endif()
