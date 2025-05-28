extends GdUnitTestSuite
class_name TestFileUtils

## Comprehensive unit tests for FileUtils class.
## Tests utility functions, file operations, and cross-platform compatibility.

var _test_directory: String
var _test_files: PackedStringArray = []

func before_test() -> void:
	# Create temporary test directory
	_test_directory = OS.get_user_data_dir().path_join("wcs_fileutils_test")
	_create_test_directory_structure()

func after_test() -> void:
	# Clean up test directory
	_cleanup_test_directory()

func test_add_extension() -> void:
	# Test adding extension to filename without extension
	assert_str(FileUtils.add_extension("test", "txt")).is_equal("test.txt")
	assert_str(FileUtils.add_extension("test", ".txt")).is_equal("test.txt")
	
	# Test file that already has the extension
	assert_str(FileUtils.add_extension("test.txt", "txt")).is_equal("test.txt")
	assert_str(FileUtils.add_extension("test.txt", ".txt")).is_equal("test.txt")
	
	# Test file with different extension
	assert_str(FileUtils.add_extension("test.cfg", "txt")).is_equal("test.cfg.txt")
	
	# Test case sensitivity
	assert_str(FileUtils.add_extension("test.TXT", "txt")).is_equal("test.TXT")
	
	# Test empty inputs
	assert_str(FileUtils.add_extension("", "txt")).is_equal("")
	assert_str(FileUtils.add_extension("test", "")).is_equal("test")

func test_remove_extension() -> void:
	# Test removing extension
	assert_str(FileUtils.remove_extension("test.txt")).is_equal("test")
	assert_str(FileUtils.remove_extension("file.name.ext")).is_equal("file.name")
	
	# Test file without extension
	assert_str(FileUtils.remove_extension("test")).is_equal("test")
	
	# Test file ending with dot
	assert_str(FileUtils.remove_extension("test.")).is_equal("test.")
	
	# Test empty input
	assert_str(FileUtils.remove_extension("")).is_equal("")

func test_get_extension() -> void:
	# Test getting extension
	assert_str(FileUtils.get_extension("test.txt")).is_equal("txt")
	assert_str(FileUtils.get_extension("file.name.ext")).is_equal("ext")
	assert_str(FileUtils.get_extension("TEST.PCX")).is_equal("pcx")
	
	# Test file without extension
	assert_str(FileUtils.get_extension("test")).is_equal("")
	
	# Test file ending with dot
	assert_str(FileUtils.get_extension("test.")).is_equal("")
	
	# Test empty input
	assert_str(FileUtils.get_extension("")).is_equal("")

func test_has_extension() -> void:
	var image_extensions: PackedStringArray = [".pcx", ".png", ".jpg", ".tga"]
	
	# Test positive cases
	assert_bool(FileUtils.has_extension("test.pcx", image_extensions)).is_true()
	assert_bool(FileUtils.has_extension("test.PNG", image_extensions)).is_true()
	assert_bool(FileUtils.has_extension("file.jpg", image_extensions)).is_true()
	
	# Test negative cases
	assert_bool(FileUtils.has_extension("test.txt", image_extensions)).is_false()
	assert_bool(FileUtils.has_extension("test", image_extensions)).is_false()
	
	# Test with extensions without dots
	var clean_extensions: PackedStringArray = ["pcx", "png", "jpg"]
	assert_bool(FileUtils.has_extension("test.pcx", clean_extensions)).is_true()
	assert_bool(FileUtils.has_extension("test.txt", clean_extensions)).is_false()
	
	# Test empty inputs
	assert_bool(FileUtils.has_extension("", image_extensions)).is_false()
	assert_bool(FileUtils.has_extension("test.pcx", PackedStringArray())).is_false()

func test_file_list_operations() -> void:
	# Test getting all files
	var all_files: PackedStringArray = FileUtils.get_file_list(_test_directory)
	assert_int(all_files.size()).is_greater(0)
	
	# Test filtering by extension
	var text_files: PackedStringArray = FileUtils.get_file_list(_test_directory, PackedStringArray([".txt"]))
	assert_int(text_files.size()).is_greater(0)
	
	for file in text_files:
		assert_str(file).ends_with(".txt")
	
	# Test recursive search
	var recursive_files: PackedStringArray = FileUtils.get_file_list(_test_directory, PackedStringArray(), true)
	assert_int(recursive_files.size()).is_greater_or_equal(all_files.size())
	
	# Test non-existent directory
	var empty_files: PackedStringArray = FileUtils.get_file_list("/path/that/does/not/exist")
	assert_int(empty_files.size()).is_equal(0)

func test_file_time_operations() -> void:
	var test_file1: String = _test_directory.path_join("time_test1.txt")
	var test_file2: String = _test_directory.path_join("time_test2.txt")
	
	# Create first file
	_create_test_file(test_file1, "First file")
	
	# Wait a bit
	await get_tree().create_timer(0.1).timeout
	
	# Create second file
	_create_test_file(test_file2, "Second file")
	
	# Test modification time
	var time1: int = FileUtils.get_file_modification_time(test_file1)
	var time2: int = FileUtils.get_file_modification_time(test_file2)
	
	assert_int(time1).is_greater(0)
	assert_int(time2).is_greater(0)
	assert_int(time2).is_greater_or_equal(time1)
	
	# Test is_file_newer
	assert_bool(FileUtils.is_file_newer(test_file2, test_file1)).is_true()
	assert_bool(FileUtils.is_file_newer(test_file1, test_file2)).is_false()
	
	# Test non-existent file
	var invalid_time: int = FileUtils.get_file_modification_time("/does/not/exist.txt")
	assert_int(invalid_time).is_equal(-1)

func test_file_copy_operations() -> void:
	var source_file: String = _test_directory.path_join("copy_source.txt")
	var dest_file: String = _test_directory.path_join("copy_dest.txt")
	var dest_subdir_file: String = _test_directory.path_join("subdir/copy_dest.txt")
	
	var test_content: String = "This content will be copied"
	_create_test_file(source_file, test_content)
	
	# Test successful copy
	var copy_success: bool = FileUtils.copy_file(source_file, dest_file)
	assert_bool(copy_success).is_true()
	assert_bool(FileAccess.file_exists(dest_file)).is_true()
	
	# Verify content is identical
	var copied_content: String = FileAccess.get_file_as_string(dest_file)
	assert_str(copied_content).is_equal(test_content)
	
	# Test copy to subdirectory (should create directory)
	var copy_subdir_success: bool = FileUtils.copy_file(source_file, dest_subdir_file)
	assert_bool(copy_subdir_success).is_true()
	assert_bool(FileAccess.file_exists(dest_subdir_file)).is_true()
	
	# Test copy non-existent source
	var copy_fail: bool = FileUtils.copy_file("/does/not/exist.txt", dest_file)
	assert_bool(copy_fail).is_false()
	
	# Test copy with empty paths
	var copy_empty: bool = FileUtils.copy_file("", dest_file)
	assert_bool(copy_empty).is_false()

func test_file_move_operations() -> void:
	var source_file: String = _test_directory.path_join("move_source.txt")
	var dest_file: String = _test_directory.path_join("move_dest.txt")
	
	var test_content: String = "This content will be moved"
	_create_test_file(source_file, test_content)
	
	# Test successful move
	var move_success: bool = FileUtils.move_file(source_file, dest_file)
	assert_bool(move_success).is_true()
	assert_bool(FileAccess.file_exists(dest_file)).is_true()
	assert_bool(FileAccess.file_exists(source_file)).is_false()
	
	# Verify content is preserved
	var moved_content: String = FileAccess.get_file_as_string(dest_file)
	assert_str(moved_content).is_equal(test_content)
	
	# Test move non-existent source
	var move_fail: bool = FileUtils.move_file("/does/not/exist.txt", dest_file)
	assert_bool(move_fail).is_false()

func test_directory_operations() -> void:
	var new_dir: String = _test_directory.path_join("new_test_directory")
	var nested_dir: String = _test_directory.path_join("level1/level2/level3")
	
	# Test directory creation
	var create_success: bool = FileUtils.create_directory(new_dir)
	assert_bool(create_success).is_true()
	assert_bool(DirAccess.dir_exists_absolute(new_dir)).is_true()
	
	# Test nested directory creation
	var create_nested_success: bool = FileUtils.create_directory(nested_dir)
	assert_bool(create_nested_success).is_true()
	assert_bool(DirAccess.dir_exists_absolute(nested_dir)).is_true()
	
	# Test creating existing directory (should succeed)
	var create_existing_success: bool = FileUtils.create_directory(new_dir)
	assert_bool(create_existing_success).is_true()
	
	# Create some files in directory for removal test
	_create_test_file(new_dir.path_join("test1.txt"), "Test file 1")
	_create_test_file(new_dir.path_join("test2.txt"), "Test file 2")
	
	# Test directory removal
	var remove_success: bool = FileUtils.remove_directory_recursive(new_dir)
	assert_bool(remove_success).is_true()
	assert_bool(DirAccess.dir_exists_absolute(new_dir)).is_false()
	
	# Test removing non-existent directory (should succeed)
	var remove_nonexistent: bool = FileUtils.remove_directory_recursive("/does/not/exist")
	assert_bool(remove_nonexistent).is_true()
	
	# Test with empty path
	var create_empty: bool = FileUtils.create_directory("")
	assert_bool(create_empty).is_false()

func test_checksum_calculation() -> void:
	var test_file: String = _test_directory.path_join("checksum_test.txt")
	var test_content: String = "This is test content for checksum calculation"
	_create_test_file(test_file, test_content)
	
	# Test checksum calculation
	var checksum: int = FileUtils.calculate_file_checksum(test_file)
	assert_int(checksum).is_not_equal(-1)
	assert_int(checksum).is_not_equal(0)
	
	# Test that same content produces same checksum
	var test_file2: String = _test_directory.path_join("checksum_test2.txt")
	_create_test_file(test_file2, test_content)
	
	var checksum2: int = FileUtils.calculate_file_checksum(test_file2)
	assert_int(checksum2).is_equal(checksum)
	
	# Test different content produces different checksum
	var test_file3: String = _test_directory.path_join("checksum_test3.txt")
	_create_test_file(test_file3, test_content + " modified")
	
	var checksum3: int = FileUtils.calculate_file_checksum(test_file3)
	assert_int(checksum3).is_not_equal(checksum)
	
	# Test empty file
	var empty_file: String = _test_directory.path_join("empty.txt")
	_create_test_file(empty_file, "")
	
	var empty_checksum: int = FileUtils.calculate_file_checksum(empty_file)
	assert_int(empty_checksum).is_equal(0)
	
	# Test non-existent file
	var invalid_checksum: int = FileUtils.calculate_file_checksum("/does/not/exist.txt")
	assert_int(invalid_checksum).is_equal(-1)

func test_find_files_matching() -> void:
	# Create test files with various patterns
	_create_test_file(_test_directory.path_join("test1.txt"), "Content 1")
	_create_test_file(_test_directory.path_join("test2.txt"), "Content 2")
	_create_test_file(_test_directory.path_join("data.cfg"), "Config data")
	_create_test_file(_test_directory.path_join("readme.md"), "Readme content")
	
	# Test wildcard matching
	var txt_files: PackedStringArray = FileUtils.find_files_matching(_test_directory, "*.txt")
	assert_int(txt_files.size()).is_greater_or_equal(2)
	
	for file in txt_files:
		assert_str(file.get_file()).ends_with(".txt")
	
	# Test single character wildcard
	var test_files: PackedStringArray = FileUtils.find_files_matching(_test_directory, "test?.txt")
	assert_int(test_files.size()).is_greater_or_equal(2)
	
	# Test exact match
	var exact_files: PackedStringArray = FileUtils.find_files_matching(_test_directory, "data.cfg")
	assert_int(exact_files.size()).is_equal(1)
	assert_str(exact_files[0].get_file()).is_equal("data.cfg")
	
	# Test no matches
	var no_matches: PackedStringArray = FileUtils.find_files_matching(_test_directory, "*.nonexistent")
	assert_int(no_matches.size()).is_equal(0)
	
	# Test invalid pattern
	var invalid_pattern: PackedStringArray = FileUtils.find_files_matching(_test_directory, "")
	assert_int(invalid_pattern.size()).is_equal(0)

func test_config_file_operations() -> void:
	var config_file: String = _test_directory.path_join("test_config.cfg")
	
	# Create test config data
	var test_config: Dictionary = {
		"global_setting": "value1",
		"debug_mode": "true",
		"Graphics": {
			"resolution": "1920x1080",
			"fullscreen": "false",
			"vsync": "true"
		},
		"Audio": {
			"master_volume": "100",
			"music_volume": "80",
			"sfx_volume": "90"
		}
	}
	
	# Test writing config file
	var write_success: bool = FileUtils.write_config_file(config_file, test_config)
	assert_bool(write_success).is_true()
	assert_bool(FileAccess.file_exists(config_file)).is_true()
	
	# Test reading config file
	var read_config: Dictionary = FileUtils.read_config_file(config_file)
	assert_int(read_config.size()).is_greater(0)
	
	# Verify global settings
	assert_str(read_config["global_setting"]).is_equal("value1")
	assert_str(read_config["debug_mode"]).is_equal("true")
	
	# Verify sections
	assert_that(read_config.has("Graphics")).is_true()
	assert_that(read_config.has("Audio")).is_true()
	
	var graphics_section: Dictionary = read_config["Graphics"]
	assert_str(graphics_section["resolution"]).is_equal("1920x1080")
	assert_str(graphics_section["fullscreen"]).is_equal("false")
	
	var audio_section: Dictionary = read_config["Audio"]
	assert_str(audio_section["master_volume"]).is_equal("100")
	assert_str(audio_section["music_volume"]).is_equal("80")
	
	# Test reading non-existent config file
	var empty_config: Dictionary = FileUtils.read_config_file("/does/not/exist.cfg")
	assert_int(empty_config.size()).is_equal(0)

func test_cross_platform_paths() -> void:
	# Test that file operations work with different path separators
	var forward_slash_path: String = _test_directory + "/forward/slash/test.txt"
	var backward_slash_path: String = _test_directory + "\\backward\\slash\\test.txt"
	
	# Create directories and files using forward slashes
	var create_success: bool = FileUtils.create_directory(_test_directory.path_join("forward/slash"))
	assert_bool(create_success).is_true()
	
	# Create file with forward slash path
	_create_test_file(forward_slash_path, "Forward slash test")
	assert_bool(FileAccess.file_exists(forward_slash_path)).is_true()
	
	# Test that checksum works with various path formats
	var checksum: int = FileUtils.calculate_file_checksum(forward_slash_path)
	assert_int(checksum).is_not_equal(-1)

func test_error_handling() -> void:
	# Test various error conditions
	
	# File operations with invalid paths
	var copy_invalid: bool = FileUtils.copy_file("", "dest.txt")
	assert_bool(copy_invalid).is_false()
	
	var move_invalid: bool = FileUtils.move_file("source.txt", "")
	assert_bool(move_invalid).is_false()
	
	# Directory operations with invalid paths
	var create_invalid: bool = FileUtils.create_directory("")
	assert_bool(create_invalid).is_false()
	
	# File matching with invalid inputs
	var find_invalid: PackedStringArray = FileUtils.find_files_matching("", "*.txt")
	assert_int(find_invalid.size()).is_equal(0)
	
	var find_invalid_pattern: PackedStringArray = FileUtils.find_files_matching(_test_directory, "")
	assert_int(find_invalid_pattern.size()).is_equal(0)

## PRIVATE HELPER METHODS

func _create_test_directory_structure() -> void:
	var dir_access: DirAccess = DirAccess.open("/")
	if dir_access == null:
		push_error("TestFileUtils: Failed to create directory access")
		return
	
	# Create main test directory
	dir_access.make_dir_recursive_absolute(_test_directory)
	
	# Create some subdirectories
	dir_access.make_dir_recursive_absolute(_test_directory.path_join("subdir1"))
	dir_access.make_dir_recursive_absolute(_test_directory.path_join("subdir2"))
	dir_access.make_dir_recursive_absolute(_test_directory.path_join("nested/deep/structure"))
	
	# Create initial test files
	_create_test_file(_test_directory.path_join("test.txt"), "Test file content")
	_create_test_file(_test_directory.path_join("config.cfg"), "[Settings]\nvalue=123\n")
	_create_test_file(_test_directory.path_join("data.json"), '{"key": "value"}')
	_create_test_file(_test_directory.path_join("subdir1/nested.txt"), "Nested file content")
	_create_test_file(_test_directory.path_join("nested/deep/structure/deep_file.txt"), "Deep file content")

func _create_test_file(file_path: String, content: String) -> void:
	# Ensure directory exists
	var dir_path: String = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var dir_access: DirAccess = DirAccess.open("/")
		if dir_access != null:
			dir_access.make_dir_recursive_absolute(dir_path)
	
	# Create file
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()
		_test_files.append(file_path)

func _cleanup_test_directory() -> void:
	if DirAccess.dir_exists_absolute(_test_directory):
		FileUtils.remove_directory_recursive(_test_directory)