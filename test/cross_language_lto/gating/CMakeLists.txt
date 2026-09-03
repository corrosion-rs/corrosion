cmake_minimum_required(VERSION 3.15)
project(test_project VERSION 0.1.0 LANGUAGES C CXX)
include(../../test_header.cmake)

# The test harness always passes -DCMAKE_INTERPROCEDURAL_OPTIMIZATION explicitly,
# so the variable is always DEFINED here.
if(NOT DEFINED CMAKE_INTERPROCEDURAL_OPTIMIZATION)
    message(FATAL_ERROR "This test must be configured with -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=<ON|OFF>")
endif()

if(DEFINED IMPORT_CROSS_LANGUAGE_LTO)
    corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml
        CROSS_LANGUAGE_LTO "${IMPORT_CROSS_LANGUAGE_LTO}")
else()
    corrosion_import_crate(MANIFEST_PATH rust/Cargo.toml)
endif()

# Corrosion must seed the permission property from the global option, unless
# `corrosion_import_crate` was given an explicit override.
get_target_property(actual_permission cross_lang_lto_lib CORROSION_CROSS_LANGUAGE_LTO)
if(DEFINED IMPORT_CROSS_LANGUAGE_LTO)
    set(expected_permission "${IMPORT_CROSS_LANGUAGE_LTO}")
else()
    set(expected_permission "${CORROSION_CROSS_LANGUAGE_LTO}")
endif()
if(NOT "${actual_permission}" STREQUAL "${expected_permission}")
    message(FATAL_ERROR "Expected target property CORROSION_CROSS_LANGUAGE_LTO to be "
        "`${expected_permission}`, but it is `${actual_permission}`")
endif()

# `INTERPROCEDURAL_OPTIMIZATION` is not inherited by IMPORTED or INTERFACE targets,
# so Corrosion must seed it from `CMAKE_INTERPROCEDURAL_OPTIMIZATION` itself.
get_target_property(actual_ipo cross_lang_lto_lib INTERPROCEDURAL_OPTIMIZATION)
if(NOT "${actual_ipo}" STREQUAL "${CMAKE_INTERPROCEDURAL_OPTIMIZATION}")
    message(FATAL_ERROR "Expected target property INTERPROCEDURAL_OPTIMIZATION to be seeded to "
        "`${CMAKE_INTERPROCEDURAL_OPTIMIZATION}`, but it is `${actual_ipo}`")
endif()

# `EXPECT_LTO` is passed by the test harness and tells the build script whether
# `-Clinker-plugin-lto` must be present.
if(NOT DEFINED EXPECT_LTO)
    message(FATAL_ERROR "This test must be configured with -DEXPECT_LTO=<0|1>")
endif()
corrosion_set_env_vars(cross_lang_lto_lib "EXPECT_LINKER_PLUGIN_LTO=${EXPECT_LTO}")

# Both languages are enabled by this test project, so both variables are defined.
# CMAKE_<LANG>_COMPILE_OPTIONS_IPO may itself be a list (e.g. GCC emits two elements,
# `-flto=auto;-fno-fat-lto-objects`); interpolating it directly would embed a literal `;` in
# the env var value, which CMake would later re-split as a list separator. Join it with spaces
# instead - same as the production code at cmake/Corrosion.cmake does - and pass every element
# through, so the test proves all IPO flags survive the forwarding, not just the first.
list(JOIN CMAKE_C_COMPILE_OPTIONS_IPO " " expect_ipo_c_flags)
list(JOIN CMAKE_CXX_COMPILE_OPTIONS_IPO " " expect_ipo_cxx_flags)
corrosion_set_env_vars(cross_lang_lto_lib
    "EXPECT_IPO_C_FLAGS=${expect_ipo_c_flags}"
    "EXPECT_IPO_CXX_FLAGS=${expect_ipo_cxx_flags}")

if(USE_HOSTBUILD)
    corrosion_set_hostbuild(cross_lang_lto_lib)
endif()
