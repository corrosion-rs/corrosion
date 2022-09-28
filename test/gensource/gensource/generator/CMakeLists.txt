corrosion_import_crate(MANIFEST_PATH Cargo.toml TARGET srcgen)
set_property(
	TARGET srcgen 
	PROPERTY CORROSION_USE_HOST_BUILD 1
)
