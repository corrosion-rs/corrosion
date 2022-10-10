if(CMAKE_VERSION VERSION_LESS 3.19.0)
    return()
endif()

if(CMAKE_C_COMPILER)
    set(TEST_C_COMPILER "C_COMPILER" "${CMAKE_C_COMPILER}")
endif()
if(CMAKE_CXX_COMPILER)
    set(TEST_CXX_COMPILER "CXX_COMPILER" "${CMAKE_CXX_COMPILER}")
endif()
if(CMAKE_GENERATOR_PLATFORM)
    set(TEST_GENERATOR_PLATFORM "GENERATOR_PLATFORM" "${CMAKE_GENERATOR_PLATFORM}")
endif()

add_test(NAME "output_directory_build"
    COMMAND
        ${CMAKE_COMMAND}
        -P "${CMAKE_SOURCE_DIR}/test/ConfigureAndBuild.cmake"
        SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/output directory"
        BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/build"
        GENERATOR "${CMAKE_GENERATOR}"
        RUST_TOOLCHAIN "${Rust_TOOLCHAIN}"
        CARGO_TARGET "${Rust_CARGO_TARGET}"
        SYSTEM_NAME "${CMAKE_SYSTEM_NAME}"
        "${TEST_C_COMPILER}"
        "${TEST_CXX_COMPILER}"
        "${TEST_GENERATOR_PLATFORM}"

        COMMAND_EXPAND_LISTS
)
set_tests_properties("output_directory_build" PROPERTIES FIXTURES_SETUP "build_fixture_output_directory")
if(CORROSION_TESTS_INSTALL_CORROSION)
    set_tests_properties("output_directory_build" PROPERTIES FIXTURES_REQUIRED "fixture_corrosion_install")
endif()

if(WIN32)
    set(bin_name "rust_bin.exe")
else()
    set(bin_name "rust_bin")
endif()

add_test(NAME output_directory_bin
        COMMAND
        "${CMAKE_COMMAND}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/TestFileExists.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/build/custom_bin/${bin_name}"
)
set_tests_properties("output_directory_bin" PROPERTIES FIXTURES_REQUIRED "output_directory_build")

set(lib_name "rust_lib")

if(MSVC)
    set(static_lib_name "${lib_name}.lib")
else()
    set(static_lib_name "lib${lib_name}.a")
endif()

add_test(NAME output_directory_staticlib
        COMMAND
        "${CMAKE_COMMAND}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/TestFileExists.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/build/custom_archive/${static_lib_name}"
)
set_tests_properties("output_directory_staticlib" PROPERTIES FIXTURES_REQUIRED "output_directory_build")

if(WIN32)
    set(dynamic_lib_name "${lib_name}.dll")
elseif(APPLE)
    set(dynamic_lib_name "lib${lib_name}.dylib")
else()
    set(dynamic_lib_name "lib${lib_name}.so")
endif()

add_test(NAME output_directory_cdylib
        COMMAND
        "${CMAKE_COMMAND}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/TestFileExists.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/build/custom_lib/${dynamic_lib_name}"
)
set_tests_properties("output_directory_cdylib" PROPERTIES FIXTURES_REQUIRED "output_directory_build")

if(WIN32)
    if(MSVC)
        set(implib_name "${lib_name}.dll.lib")
    else()
        # windows-gnu
        set(implib_name "lib${lib_name}.dll.a")
    endif()

    add_test(NAME output_directory_implib
        COMMAND
        "${CMAKE_COMMAND}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/TestFileExists.cmake"
        # Implib is an ARCHIVE artifact, see:
        # https://cmake.org/cmake/help/v3.25/manual/cmake-buildsystem.7.html#archive-output-artifacts
        "${CMAKE_CURRENT_BINARY_DIR}/build/custom_archive/${implib_name}"
        )
    set_tests_properties("output_directory_implib" PROPERTIES FIXTURES_REQUIRED "output_directory_build")

    if(MSVC)
        set(lib_pdb_name "${lib_name}.pdb")
        add_test(NAME output_directory_cdylib_pdb
            COMMAND
            "${CMAKE_COMMAND}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/TestFileExists.cmake"
            "${CMAKE_CURRENT_BINARY_DIR}/build/custom_lib_pdb/${lib_pdb_name}"
            )
        set_tests_properties("output_directory_cdylib_pdb" PROPERTIES FIXTURES_REQUIRED "output_directory_build")

        set(bin_pdb_name "rust_bin.pdb")
        add_test(NAME output_directory_bin_pdb
            COMMAND
            "${CMAKE_COMMAND}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/TestFileExists.cmake"
            "${CMAKE_CURRENT_BINARY_DIR}/build/custom_bin_pdb/${bin_pdb_name}"
            )
        set_tests_properties("output_directory_bin_pdb" PROPERTIES FIXTURES_REQUIRED "output_directory_build")
    endif()
endif()
