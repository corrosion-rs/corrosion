# Create test install for Corrosion
if(CORROSION_NATIVE_TOOLING)
    set(generator_executable_define -DCORROSION_GENERATOR_EXECUTABLE=$<TARGET_FILE:corrosion-generator>)
endif()
add_custom_target(
    test-install ALL
    COMMAND
        ${CMAKE_COMMAND} -S${Corrosion_SOURCE_DIR} -Btest-build
            -DCORROSION_BUILD_TESTS=OFF
            -DCMAKE_INSTALL_PREFIX=${CMAKE_CURRENT_BINARY_DIR}/test-install
            ${generator_executable_define}
    COMMAND ${CMAKE_COMMAND} --build test-build --config Debug # Ignored for single-config builds
    COMMAND ${CMAKE_COMMAND} --install test-build --config Debug # Ignored for single-config builds
)

file(
    GLOB CONFIG_TESTS
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    CONFIGURE_DEPENDS */Test.cmake)

message(DEBUG "CONFIG_TESTS: ${CONFIG_TESTS}")

foreach(CONFIG_TEST ${CONFIG_TESTS})
    get_filename_component(CONFIG_TEST_NAME ${CONFIG_TEST} DIRECTORY)
    message(DEBUG "CONFIG_TEST_NAME: ${CONFIG_TEST_NAME}")

    add_test(
        NAME ${CONFIG_TEST_NAME}
        COMMAND
            ${CMAKE_COMMAND} -P
                ${CMAKE_CURRENT_SOURCE_DIR}/RunTest.cmake
                    "${Corrosion_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}"
                    "${CONFIG_TEST_NAME}" "${CMAKE_CURRENT_BINARY_DIR}/test-install")
endforeach()
