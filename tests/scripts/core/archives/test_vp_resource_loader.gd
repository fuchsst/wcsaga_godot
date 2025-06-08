extends GdUnitTestSuite

## Integration tests for VP ResourceLoader functionality

const VPArchive = preload("res://scripts/core/archives/vp_archive.gd")

func before_test() -> void:
	# Ensure VPResourceManager is available
	assert_that(VPResourceManager).is_not_null()
	assert_that(VPResourceManager.is_vp_loading_available()).is_true()

func test_vp_resource_loader_registration() -> void:
	# Test that VP ResourceLoader is properly registered
	assert_that(VPResourceManager.is_vp_loading_available()).is_true()
	
	# Test cache functionality
	var cache_info = VPResourceManager.get_cache_info()
	assert_that(cache_info).is_not_null()
	assert_that(cache_info.has("cached_archives")).is_true()
	assert_that(cache_info.has("max_cache_size")).is_true()

func test_vp_file_extension_recognition() -> void:
	# Test that VP files would be recognized by ResourceLoader
	# Note: This tests the loader registration, not actual file loading
	var vp_loader = VPResourceManager.vp_loader
	assert_that(vp_loader).is_not_null()
	
	var extensions = vp_loader._get_recognized_extensions()
	assert_that(extensions).contains("vp")
	assert_that(extensions).contains("VP")

func test_vp_resource_type_handling() -> void:
	var vp_loader = VPResourceManager.vp_loader
	assert_that(vp_loader).is_not_null()
	
	# Test type handling
	assert_that(vp_loader._handles_type(&"VPArchive")).is_true()
	assert_that(vp_loader._handles_type(&"Resource")).is_true()
	assert_that(vp_loader._handles_type(&"Node")).is_false()
	
	# Test resource type detection
	assert_that(vp_loader._get_resource_type("test.vp")).is_equal("VPArchive")
	assert_that(vp_loader._get_resource_type("test.VP")).is_equal("VPArchive")
	assert_that(vp_loader._get_resource_type("test.txt")).is_equal("")

func test_cache_management() -> void:
	# Test cache clearing
	VPResourceManager.clear_cache()
	var cache_info = VPResourceManager.get_cache_info()
	assert_that(cache_info["cached_archives"]).is_equal(0)
	
	# Test debug logging toggle
	VPResourceManager.enable_debug_logging(true)
	VPResourceManager.enable_debug_logging(false)

func test_load_nonexistent_vp_file() -> void:
	# Test loading a VP file that doesn't exist
	var result = VPResourceManager.load_vp_archive("res://nonexistent.vp")
	assert_that(result).is_null()

func after_test() -> void:
	# Clean up cache after tests
	VPResourceManager.clear_cache()
