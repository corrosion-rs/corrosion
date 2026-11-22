# Corrosion Tests

Corrosions tests are run via ctest. The tests themselves utilize CMake script mode
to configure and build a test project, which allows for great flexibility.
Using ctest properties such as `PASS_REGULAR_EXPRESSION` or `FAIL_REGULAR_EXPRESSION`
can be used to confirm that built executable targets run as expected, but can also
be used to fail tests if Corrosion warnings appear in the configure output.

## Adding a test

1. Create a test project in `test/<group>/<test_name>/`. Its `CMakeLists.txt` should
   `include(../../test_header.cmake)` after `project()`, which makes Corrosion available.
2. Register it in `test/<group>/CMakeLists.txt`, and add the group to `test/CMakeLists.txt`:

   ```cmake
   corrosion_tests_add_test(<test_name> "<bin1>;<bin2>"   # executables to run, or ""
       [TEST_SRC_DIR <dir>]                                 # if the directory isn't <test_name>
       [IS_HOSTBUILD]                                       # run binaries when cross-compiling
       [CACHE_VARS <name>[:<type>]=<value>...]              # variables for the test project
   )
   set_tests_properties(<test_name>_run_<bin1> PROPERTIES PASS_REGULAR_EXPRESSION "...")
   ```

The test project is configured with an initial cache file (`cmake -C`), written to
`<build>/test/<group>/<test_name>-initial-cache.cmake`. It contains the relevant settings of
the main build (compilers, toolchain file, Rust toolchain and target, ...), see
`_corrosion_tests_forwarded_variables` in `test/CMakeLists.txt`, followed by the `CACHE_VARS`.
Values are passed through verbatim, so list values work as long as each entry is quoted:
`CACHE_VARS "CMAKE_OSX_ARCHITECTURES=arm64;x86_64"`. The file is also printed in the output
of the `<test_name>_build` test, and it can be used to configure the test project manually:

```sh
cmake -C <build>/test/<group>/<test_name>-initial-cache.cmake -S test/<group>/<test_name> -B /tmp/<test_name>
```
