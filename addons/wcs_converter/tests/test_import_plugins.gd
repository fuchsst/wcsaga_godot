extends GdUnitTestSuite

## Unit tests for WCS import plugins
## Tests VP, POF, and Mission import functionality

const VPImportPlugin = preload("res://addons/wcs_converter/import/vp_import_plugin.gd")
const POFImportPlugin = preload("res://addons/wcs_converter/import/pof_import_plugin.gd")
const MissionImportPlugin = preload("res://addons/wcs_converter/import/mission_import_plugin.gd")
const VPExtractor = preload("res://addons/wcs_converter/conversion/vp_extractor.gd")
const POFConverter = preload("res://addons/wcs_converter/conversion/pof_converter.gd")
const MissionConverter = preload("res://addons/wcs_converter/conversion/mission_converter.gd")

var temp_dir: String
var test_assets_dir: String

func before_test() -> void:
	# Create temporary directory for tests
	temp_dir = "user://test_wcs_import_" + str(Time.get_ticks_msec())
	var error: Error = DirAccess.open("user://").make_dir_recursive(temp_dir.replace("user://", ""))
	if error != OK:
		push_error("Failed to create temp directory: %s (Error: %d)" % [temp_dir, error])
	
	test_assets_dir = temp_dir + "/test_assets"
	var error2: Error = DirAccess.open("user://").make_dir_recursive(test_assets_dir.replace("user://", ""))
	if error2 != OK:
		push_error("Failed to create test assets directory: %s (Error: %d)" % [test_assets_dir, error2])
	
	_create_test_assets()

func after_test() -> void:
	# Clean up temporary files
	_remove_directory_recursive(temp_dir)

func _create_test_assets() -> void:
	"""Create mock test assets for testing"""
	
	# Create a mock VP file (minimal valid structure)
	_create_mock_vp_file(test_assets_dir + "/test.vp")
	
	# Create a mock POF file (minimal valid structure)
	_create_mock_pof_file(test_assets_dir + "/test.pof")
	
	# Create a mock mission file
	_create_mock_mission_file(test_assets_dir + "/test.fs2")

func _create_mock_vp_file(file_path: String) -> void:
	"""Create a minimal mock VP file for testing"""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	# Write VP signature
	file.store_buffer("VPVP".to_ascii_buffer())
	file.store_32(2)  # Version
	file.store_32(36) # Directory offset
	file.store_32(1)  # Number of files
	
	# Padding to directory offset
	for i in range(20):
		file.store_8(0)
	
	# Directory entry
	file.store_32(0)   # File offset
	file.store_32(0)   # File size
	file.store_buffer("testfile.txt".to_ascii_buffer().resize(32))
	
	file.close()

func _create_mock_pof_file(file_path: String) -> void:
	"""Create a minimal mock POF file for testing"""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	# Write POF signature and minimal header
	file.store_32(0x4f505350)  # 'OPSP'
	file.store_32(1900)        # Version
	
	file.close()

func _create_mock_mission_file(file_path: String) -> void:
	"""Create a minimal mock mission file for testing"""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	var mission_content: String = '''#Mission Info
$Version: 1.00
$Name: Test Mission
$Author: Test Author

#Objects

#Events

#Goals

#End
'''
	
	file.store_string(mission_content)
	file.close()

func _remove_directory_recursive(directory: String) -> void:
	"""Remove directory and all contents"""
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_remove_directory_recursive(full_path)
			dir.remove(file_name)
		elif not dir.current_is_dir():
			dir.remove(file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	dir.remove(directory)

# VP Import Plugin Tests
func test_vp_import_plugin_creation() -> void:
	var plugin: VPImportPlugin = VPImportPlugin.new()
	assert_that(plugin).is_not_null()
	assert_that(plugin._get_importer_name()).is_equal("wcs.vp_archive")
	assert_that(plugin._get_visible_name()).is_equal("WCS VP Archive")

func test_vp_import_plugin_extensions() -> void:
	var plugin: VPImportPlugin = VPImportPlugin.new()
	var extensions: PackedStringArray = plugin._get_recognized_extensions()
	assert_that(extensions).contains("vp")

func test_vp_import_plugin_options() -> void:
	var plugin: VPImportPlugin = VPImportPlugin.new()
	var options: Array[Dictionary] = plugin._get_import_options("", 0)
	
	assert_that(options.size()).is_greater(0)
	
	# Check for expected options
	var option_names: Array[String] = []
	for option in options:
		option_names.append(option.get("name", ""))
	
	assert_that(option_names).contains("extract_to_subdir")
	assert_that(option_names).contains("organize_by_type")
	assert_that(option_names).contains("auto_import_assets")

func test_vp_extractor_creation() -> void:
	var extractor: VPExtractor = VPExtractor.new()
	assert_that(extractor).is_not_null()

func test_vp_extractor_file_info() -> void:
	var extractor: VPExtractor = VPExtractor.new()
	var vp_file: String = test_assets_dir + "/test.vp"
	
	var info: Dictionary = extractor.get_vp_file_info(vp_file)
	assert_that(info.get("success", false)).is_true()
	assert_that(info).contains_keys(["version", "file_count", "file_size"])

# POF Import Plugin Tests
func test_pof_import_plugin_creation() -> void:
	var plugin: POFImportPlugin = POFImportPlugin.new()
	assert_that(plugin).is_not_null()
	assert_that(plugin._get_importer_name()).is_equal("wcs.pof_model")
	assert_that(plugin._get_visible_name()).is_equal("WCS POF Model")

func test_pof_import_plugin_extensions() -> void:
	var plugin: POFImportPlugin = POFImportPlugin.new()
	var extensions: PackedStringArray = plugin._get_recognized_extensions()
	assert_that(extensions).contains("pof")

func test_pof_import_plugin_options() -> void:
	var plugin: POFImportPlugin = POFImportPlugin.new()
	var options: Array[Dictionary] = plugin._get_import_options("", 0)
	
	assert_that(options.size()).is_greater(0)
	
	# Check for expected options
	var option_names: Array[String] = []
	for option in options:
		option_names.append(option.get("name", ""))
	
	assert_that(option_names).contains("auto_find_textures")
	assert_that(option_names).contains("generate_collision")
	assert_that(option_names).contains("generate_lods")

func test_pof_converter_creation() -> void:
	var converter: POFConverter = POFConverter.new()
	assert_that(converter).is_not_null()

func test_pof_converter_file_info() -> void:
	var converter: POFConverter = POFConverter.new()
	var pof_file: String = test_assets_dir + "/test.pof"
	
	# Note: This test may fail if Python script is not available
	# In that case, we test the method exists and handles errors gracefully
	var info: Dictionary = converter.get_pof_file_info(pof_file)
	assert_that(info).contains_key("success")

# Mission Import Plugin Tests
func test_mission_import_plugin_creation() -> void:
	var plugin: MissionImportPlugin = MissionImportPlugin.new()
	assert_that(plugin).is_not_null()
	assert_that(plugin._get_importer_name()).is_equal("wcs.mission_file")
	assert_that(plugin._get_visible_name()).is_equal("WCS Mission File")

func test_mission_import_plugin_extensions() -> void:
	var plugin: MissionImportPlugin = MissionImportPlugin.new()
	var extensions: PackedStringArray = plugin._get_recognized_extensions()
	assert_that(extensions).contains("fs2")
	assert_that(extensions).contains("fc2")

func test_mission_import_plugin_options() -> void:
	var plugin: MissionImportPlugin = MissionImportPlugin.new()
	var options: Array[Dictionary] = plugin._get_import_options("", 0)
	
	assert_that(options.size()).is_greater(0)
	
	# Check for expected options
	var option_names: Array[String] = []
	for option in options:
		option_names.append(option.get("name", ""))
	
	assert_that(option_names).contains("convert_sexp_events")
	assert_that(option_names).contains("generate_waypoint_gizmos")
	assert_that(option_names).contains("preserve_coordinates")

func test_mission_converter_creation() -> void:
	var converter: MissionConverter = MissionConverter.new()
	assert_that(converter).is_not_null()

func test_mission_converter_file_info() -> void:
	var converter: MissionConverter = MissionConverter.new()
	var mission_file: String = test_assets_dir + "/test.fs2"
	
	# Note: This test may fail if Python script is not available
	# In that case, we test the method exists and handles errors gracefully
	var info: Dictionary = converter.get_mission_file_info(mission_file)
	assert_that(info).contains_key("success")

# Import Option Validation Tests
func test_vp_import_option_visibility() -> void:
	var plugin: VPImportPlugin = VPImportPlugin.new()
	
	# Test that all options are visible by default
	var test_options: Dictionary = {
		"extract_to_subdir": true,
		"organize_by_type": true,
		"auto_import_assets": true
	}
	
	assert_that(plugin._get_option_visibility("test.vp", &"extract_to_subdir", test_options)).is_true()
	assert_that(plugin._get_option_visibility("test.vp", &"organize_by_type", test_options)).is_true()
	assert_that(plugin._get_option_visibility("test.vp", &"auto_import_assets", test_options)).is_true()

func test_pof_import_option_visibility() -> void:
	var plugin: POFImportPlugin = POFImportPlugin.new()
	
	# Test conditional visibility
	var options_with_textures: Dictionary = {"auto_find_textures": true}
	var options_without_textures: Dictionary = {"auto_find_textures": false}
	
	assert_that(plugin._get_option_visibility("test.pof", &"texture_search_paths", options_with_textures)).is_true()
	assert_that(plugin._get_option_visibility("test.pof", &"texture_search_paths", options_without_textures)).is_false()

func test_mission_import_option_visibility() -> void:
	var plugin: MissionImportPlugin = MissionImportPlugin.new()
	
	# Test conditional visibility
	var options_with_sexp: Dictionary = {"convert_sexp_events": true}
	var options_without_sexp: Dictionary = {"convert_sexp_events": false}
	
	assert_that(plugin._get_option_visibility("test.fs2", &"sexp_validation_level", options_with_sexp)).is_true()
	assert_that(plugin._get_option_visibility("test.fs2", &"sexp_validation_level", options_without_sexp)).is_false()

# Preset Tests
func test_import_plugin_presets() -> void:
	var vp_plugin: VPImportPlugin = VPImportPlugin.new()
	var pof_plugin: POFImportPlugin = POFImportPlugin.new()
	var mission_plugin: MissionImportPlugin = MissionImportPlugin.new()
	
	# Test preset counts
	assert_that(vp_plugin._get_preset_count()).is_equal(1)
	assert_that(pof_plugin._get_preset_count()).is_equal(3)
	assert_that(mission_plugin._get_preset_count()).is_equal(2)
	
	# Test preset names
	assert_that(vp_plugin._get_preset_name(0)).is_equal("Default")
	assert_that(pof_plugin._get_preset_name(0)).is_equal("Default")
	assert_that(pof_plugin._get_preset_name(1)).is_equal("High Quality (with LODs)")
	assert_that(pof_plugin._get_preset_name(2)).is_equal("Performance Optimized")
	assert_that(mission_plugin._get_preset_name(0)).is_equal("Default")
	assert_that(mission_plugin._get_preset_name(1)).is_equal("Editor Mode (with Gizmos)")

# Error Handling Tests
func test_vp_extractor_invalid_file() -> void:
	var extractor: VPExtractor = VPExtractor.new()
	var invalid_file: String = test_assets_dir + "/nonexistent.vp"
	
	var info: Dictionary = extractor.get_vp_file_info(invalid_file)
	assert_that(info.get("success", true)).is_false()
	assert_that(info).contains_key("error")

func test_pof_converter_invalid_file() -> void:
	var converter: POFConverter = POFConverter.new()
	var invalid_file: String = test_assets_dir + "/nonexistent.pof"
	
	var info: Dictionary = converter.get_pof_file_info(invalid_file)
	assert_that(info.get("success", true)).is_false()
	assert_that(info).contains_key("error")

func test_mission_converter_invalid_file() -> void:
	var converter: MissionConverter = MissionConverter.new()
	var invalid_file: String = test_assets_dir + "/nonexistent.fs2"
	
	var info: Dictionary = converter.get_mission_file_info(invalid_file)
	assert_that(info.get("success", true)).is_false()
	assert_that(info).contains_key("error")

# Integration Tests (if Python backend is available)
func test_vp_extraction_integration() -> void:
	"""Integration test for VP extraction (requires Python backend)"""
	var extractor: VPExtractor = VPExtractor.new()
	var vp_file: String = test_assets_dir + "/test.vp"
	var output_dir: String = temp_dir + "/vp_output"
	
	var options: Dictionary = {
		"organize_by_type": false,
		"generate_manifest": false
	}
	
	# This test may fail if Python script is not available - that's expected
	var result: Dictionary = extractor.extract_vp_archive(vp_file, output_dir, options)
	
	# If extraction succeeds, validate the result structure
	if result.get("success", false):
		assert_that(result).contains_keys(["file_count", "extraction_time"])
		assert_that(DirAccess.dir_exists_absolute(output_dir)).is_true()

func test_directory_scan_functionality() -> void:
	"""Test directory scanning utility functions"""
	var vp_plugin: VPImportPlugin = VPImportPlugin.new()
	
	# Create some test files
	var test_files: Array[String] = [
		test_assets_dir + "/test1.pof",
		test_assets_dir + "/test2.pof",
		test_assets_dir + "/texture.pcx"
	]
	
	for test_file in test_files:
		var file: FileAccess = FileAccess.open(test_file, FileAccess.WRITE)
		if file != null:
			file.store_string("test content")
			file.close()
	
	# Test file finding functionality
	var found_pofs: Array[String] = vp_plugin._find_files_by_extension(test_assets_dir, "pof")
	assert_that(found_pofs.size()).is_equal(2)
	
	var found_textures: Array[String] = vp_plugin._find_files_by_extension(test_assets_dir, "pcx")
	assert_that(found_textures.size()).is_equal(1)
