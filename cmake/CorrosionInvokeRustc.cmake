#[[ rustc compiler wrapper which captures the required libraries for Rust static libraries into an rsp file.

## Parameters

In CMake script mode everything after `--` is not parsed by the original CMake, so we use that
to pass in the build command we are supposed to execute in this script.
Any other settings should be passed via `-D` arguments.

- `COR_LIBS_OUTFILE`: The output rsp filepath the linker arguments should be written to.
- `COR_TARGET_NAME`: The name of the target currently being built
- `COR_TARGET_IS_NO_STD`: True, if the target is a nostd target
#]]

if(NOT DEFINED COR_LIBS_OUTFILE)
    message(FATAL_ERROR "CorrosionInvokeRustc.cmake internal error:"
            " Required parameter COR_LIBS_OUTFILE not set")
endif()
set(command "")
set(passthrough_args FALSE)
foreach(idx RANGE ${CMAKE_ARGC})
    if(passthrough_args)
        list(APPEND command "${CMAKE_ARGV${idx}}")
    elseif("${CMAKE_ARGV${idx}}" STREQUAL "--")
        set(passthrough_args TRUE)
    endif()
endforeach()

execute_process(
        COMMAND ${command}
        OUTPUT_VARIABLE rustc_stdout
        ERROR_VARIABLE rustc_stderr
        RESULT_VARIABLE rustc_result
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE
)

if(rustc_result)
    message(FATAL_ERROR "COMMAND `${command}` failed with error code ${rustc_result}.")
endif()

if(rustc_stderr MATCHES "native-static-libs: ([^\r\n]+)\r?\n")
    string(REPLACE " " ";" "libs_list" "${CMAKE_MATCH_1}")
    # Special case `msvcrt` to link with the debug version in Debug mode.
    # TODO: Debug mode or not, needs to be passed into the script!
    # list(TRANSFORM libs_list REPLACE "^msvcrt$" "\$<\$<CONFIG:Debug>:msvcrtd>")
    message(DEBUG "libs list: ${libs_list}")
elseif(COR_TARGET_IS_NO_STD)
    message(STATUS "`native-static-libs` not found in rustc stderr for NO_STD target ${COR_TARGET_NAME}."
        "NO_STD targets may not require linking against anything, so ignoring this."
    )
else()
    message(STATUS "Determining required native libraries - failed: Regex match failure.")
    message(FATAL_ERROR "`native-static-libs` line not found for target ${COR_TARGET_NAME}."
        "This target is not marked as a `NO_STD` target, so treating it as an error."
    )
endif()

# Transform back
list(JOIN libs_list " " libs_list_joined)
file(WRITE "${COR_LIBS_OUTFILE}" "${libs_list_joined}")
message(STATUS "Wrote required libs for target ${COR_TARGET_NAME} to ${COR_LIBS_OUTFILE}")
message(STATUS "Required libs: " ${libs_list_joined})
