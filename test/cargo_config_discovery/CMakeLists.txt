# The `.cargo/config.toml` file registers the `my-registry` index. If Cargo fails to
# discover the config file, the build will fail with:
# "registry index was not found in any configuration: `my-registry`"
corrosion_tests_add_test(cargo_config_discovery "cargo_config_discovery")

# Run the `cargo-clean` target to verify `.cargo/config.toml` discovery.
add_test(NAME "cargo_config_discovery_run_cargo_clean"
    COMMAND "${CMAKE_COMMAND}" --build "${CMAKE_CURRENT_BINARY_DIR}/build-cargo_config_discovery" --target cargo-clean
)
set_tests_properties("cargo_config_discovery_run_cargo_clean" PROPERTIES FIXTURES_REQUIRED "build_fixture_cargo_config_discovery")
