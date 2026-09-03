cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0 LANGUAGES C CXX)
include(../../test_header.cmake)

# The test harness always passes -DCMAKE_INTERPROCEDURAL_OPTIMIZATION explicitly,
# so the variable is always DEFINED here.
if(NOT DEFINED CMAKE_INTERPROCEDURAL_OPTIMIZATION)
    message(FATAL_ERROR "This test must be configured with -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=<ON|OFF>")
endif()

corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)

# Corrosion must seed the permission property from the global option.
get_target_property(actual_permission cross_lang_lto_lib CORROSION_CROSS_LANGUAGE_LTO)
if(NOT "${actual_permission}" STREQUAL "${CORROSION_CROSS_LANGUAGE_LTO}")
    message(FATAL_ERROR "Expected target property CORROSION_CROSS_LANGUAGE_LTO to be seeded to "
        "`${CORROSION_CROSS_LANGUAGE_LTO}`, but it is `${actual_permission}`")
endif()

# `INTERPROCEDURAL_OPTIMIZATION` is not inherited by IMPORTED or INTERFACE targets,
# so Corrosion must seed it from `CMAKE_INTERPROCEDURAL_OPTIMIZATION` itself.
get_target_property(actual_ipo cross_lang_lto_lib INTERPROCEDURAL_OPTIMIZATION)
if(NOT "${actual_ipo}" STREQUAL "${CMAKE_INTERPROCEDURAL_OPTIMIZATION}")
    message(FATAL_ERROR "Expected target property INTERPROCEDURAL_OPTIMIZATION to be seeded to "
        "`${CMAKE_INTERPROCEDURAL_OPTIMIZATION}`, but it is `${actual_ipo}`")
endif()
