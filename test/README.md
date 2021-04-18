# Corrosion Config Tests

These tests are "config" tests. Essentially, they invoke CMake to create new build configurations,
which then perform some number of interactions with Corrosion (`find_package`, `add_subdirectory`,
etc.), and then validate the results in some way. Think of these as "integration" tests. These tests
are all, for better or worse, written in CMake in scripting mode.

Tests are discovered by looking for directories with `Test.cmake` scripts. These `Test.cmake`
scripts are invoked - they are considered successful if they exit with a 0 exit code. Typical tests
will also bundle a "top-level" `CMakeLists.txt`, but this isn't necessarily required.
