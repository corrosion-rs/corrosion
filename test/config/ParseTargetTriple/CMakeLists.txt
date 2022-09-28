# This test is supposed to ensure that the regex in _corrosion_parse_platform works as expected.
cmake_minimum_required(VERSION 3.15)

project(ParseTargetTriple LANGUAGES C)

add_subdirectory(../../.. corrosion)


# Important built-in target triples.
_corrosion_parse_platform("Cargo.toml" "1.55" "x86_64-unknown-linux-gnu")
_corrosion_parse_platform("Cargo.toml" "1.55" "aarch64-unknown-linux-gnu")
_corrosion_parse_platform("Cargo.toml" "1.55" "aarch64-fuchsia")

# Unconventional target triples
_corrosion_parse_platform("Cargo.toml" "1.55" "thumbv8m.base-none-eabi")
_corrosion_parse_platform("Cargo.toml" "1.55" "thumbv8m.main-none-eabi")
_corrosion_parse_platform("Cargo.toml" "1.55" "thumbv8m.main-none-eabihf")

# Custom json file. The file doesn't need to exist for the test.
_corrosion_parse_platform("Cargo.toml" "1.55" "../../blah/x86_64-unknown-custom-gnu.json")
_corrosion_parse_platform("Cargo.toml" "1.55" "x86_64-unknown-custom-gnu.json")
_corrosion_parse_platform("Cargo.toml" "1.55" "/path/to/x86_64-unknown-custom-gnu.json")
_corrosion_parse_platform("Cargo.toml" "1.55" "../../blah/x86_64-custom_os.json")


