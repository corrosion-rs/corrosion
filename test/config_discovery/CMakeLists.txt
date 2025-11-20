# The `.cargo/config.toml` file registers the `my-registry` index. If Cargo fails to
# discover the config file, the build will fail with:
# "registry index was not found in any configuration: `my-registry`"
corrosion_tests_add_test(config_discovery "config_discovery")

# Run the `cargo-clean` target to verify `.cargo/config.toml` discovery.
add_test(NAME "config_discovery_run_cargo_clean"
    COMMAND "${CMAKE_COMMAND}" --build "${CMAKE_CURRENT_BINARY_DIR}/build-config_discovery" --target cargo-clean
)
set_tests_properties("config_discovery_run_cargo_clean" PROPERTIES 
    FIXTURES_REQUIRED "build_fixture_config_discovery"
    DEPENDS "config_discovery_run_config_discovery"
)
