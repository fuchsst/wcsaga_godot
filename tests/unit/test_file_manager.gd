extends GdUnitTestSuite
class_name TestFileManager

## Comprehensive unit tests for FileManager class.
## Tests file operations, path resolution, caching, and cross-platform compatibility.

var _file_manager: FileManager
var _test_root_dir: String
var _test_user_dir: String
var _mock_files: Dictionary = {}

func before_test() -> void:
	_file_manager = FileManager.new()
	
	# Create temporary test directories
	_test_root_dir = OS.get_user_data_dir().path_join("wcs_test_root")
	_test_user_dir = OS.get_user_data_dir().path_join("wcs_test_user")
	
	_create_test_directory_structure()
	
	# Initialize FileManager with test directories
	var success: bool = _file_manager.initialize(_test_root_dir, _test_user_dir)
	assert_bool(success).is_true()

func after_test() -> void:
	if _file_manager != null:
		_file_manager.clear_cache()
	
	# Clean up test directories
	_cleanup_test_directories()

func test_initialization() -> void:
	# Test successful initialization
	var fm: FileManager = FileManager.new()
	var success: bool = fm.initialize(_test_root_dir, _test_user_dir)
	assert_bool(success).is_true()
	
	# Test initialization with empty root directory
	var fm2: FileManager = FileManager.new()
	var failure: bool = fm2.initialize("", _test_user_dir)
	assert_bool(failure).is_false()
	
	# Test initialization with non-existent directory
	var fm3: FileManager = FileManager.new()
	var failure2: bool = fm3.initialize("/this/path/does/not/exist", _test_user_dir)
	assert_bool(failure2).is_false()

func test_singleton_pattern() -> void:
	# Test singleton instance creation
	var instance1: FileManager = FileManager.get_instance()
	var instance2: FileManager = FileManager.get_instance()
	
	assert_object(instance1).is_not_null()
	assert_object(instance2).is_not_null()
	assert_that(instance1).is_same(instance2)

func test_path_type_resolution() -> void:
	# Test path type determination from file extensions
	var _resolve_method = _file_manager.get("_determine_path_type_from_extension")
	
	# Test common extensions
	assert_int(_resolve_method.call("test.pcx")).is_equal(FileManager.PathType.MAPS)
	assert_int(_resolve_method.call("test.wav")).is_equal(FileManager.PathType.SOUNDS)
	assert_int(_resolve_method.call("test.pof")).is_equal(FileManager.PathType.MODELS)
	assert_int(_resolve_method.call("test.tbl")).is_equal(FileManager.PathType.TABLES)
	assert_int(_resolve_method.call("test.txt")).is_equal(FileManager.PathType.TEXT)
	assert_int(_resolve_method.call("test.cfg")).is_equal(FileManager.PathType.DATA)
	
	# Test unknown extension defaults to ROOT
	assert_int(_resolve_method.call("test.unknown")).is_equal(FileManager.PathType.ROOT)

func test_file_operations() -> void:
	# Test writing and reading text files
	var test_content: String = "Hello, WCS-Godot World!\nThis is a test file."
	var test_filename: String = "test_file.txt"
	
	# Write file
	var write_success: bool = _file_manager.write_file_text(test_filename, test_content, FileManager.PathType.TEXT)
	assert_bool(write_success).is_true()
	
	# Read file back
	var read_content: String = _file_manager.read_file_text(test_filename, FileManager.PathType.TEXT)
	assert_str(read_content).is_equal(test_content)
	
	# Test file exists
	var exists: bool = _file_manager.file_exists(test_filename, FileManager.PathType.TEXT)
	assert_bool(exists).is_true()
	
	# Test file size
	var file_size: int = _file_manager.get_file_size(test_filename, FileManager.PathType.TEXT)
	assert_int(file_size).is_greater(0)

func test_binary_file_operations() -> void:
	# Test writing and reading binary files
	var test_data: PackedByteArray = PackedByteArray([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD, 0xFC])
	var test_filename: String = "test_binary.dat"
	
	# Write binary file
	var write_success: bool = _file_manager.write_file_bytes(test_filename, test_data, FileManager.PathType.DATA)
	assert_bool(write_success).is_true()
	
	# Read binary file back
	var read_data: PackedByteArray = _file_manager.read_file_bytes(test_filename, FileManager.PathType.DATA)
	assert_int(read_data.size()).is_equal(test_data.size())
	
	for i in range(test_data.size()):
		assert_int(read_data[i]).is_equal(test_data[i])

func test_file_access_modes() -> void:
	var test_filename: String = "access_test.txt"
	var test_content: String = "Access mode test content"
	
	# Test READ mode
	_file_manager.write_file_text(test_filename, test_content, FileManager.PathType.TEXT)
	var read_file: FileAccess = _file_manager.open_file(test_filename, FileManager.AccessMode.READ, FileManager.PathType.TEXT)
	assert_object(read_file).is_not_null()
	
	if read_file != null:
		var content: String = read_file.get_as_text()
		assert_str(content).is_equal(test_content)
		read_file.close()
	
	# Test WRITE mode
	var write_file: FileAccess = _file_manager.open_file("write_test.txt", FileManager.AccessMode.WRITE, FileManager.PathType.TEXT)
	assert_object(write_file).is_not_null()
	
	if write_file != null:
		write_file.store_string("Write mode test")
		write_file.close()

func test_file_caching() -> void:
	# Enable caching
	_file_manager.configure_cache(true, 1)  # 1MB cache
	
	var test_filename: String = "cache_test.txt"
	var test_content: String = "This content should be cached"
	
	# Write test file
	_file_manager.write_file_text(test_filename, test_content, FileManager.PathType.TEXT)
	
	# Read file twice - second read should be from cache
	var content1: String = _file_manager.read_file_text(test_filename, FileManager.PathType.TEXT)
	var content2: String = _file_manager.read_file_text(test_filename, FileManager.PathType.TEXT)
	
	assert_str(content1).is_equal(test_content)
	assert_str(content2).is_equal(test_content)
	
	# Check cache statistics
	var cache_stats: Dictionary = _file_manager.get_cache_stats()
	assert_bool(cache_stats["enabled"]).is_true()
	assert_int(cache_stats["entry_count"]).is_greater(0)
	
	# Test cache clearing
	_file_manager.clear_cache()
	var cache_stats_after_clear: Dictionary = _file_manager.get_cache_stats()
	assert_int(cache_stats_after_clear["entry_count"]).is_equal(0)
	assert_int(cache_stats_after_clear["current_size"]).is_equal(0)

func test_cache_eviction() -> void:
	# Configure small cache to test eviction
	_file_manager.configure_cache(true, 1)  # 1MB cache
	var small_cache_size: int = 1024  # 1KB for testing
	_file_manager.get("_cache_max_size") = small_cache_size
	
	# Create multiple files that exceed cache size
	var large_content: String = "x".repeat(500)  # 500 bytes each
	
	for i in range(5):
		var filename: String = "cache_evict_test_%d.txt" % i
		_file_manager.write_file_text(filename, large_content, FileManager.PathType.TEXT)
		_file_manager.read_file_text(filename, FileManager.PathType.TEXT)  # Cache the file
	
	# Cache should have evicted some entries
	var cache_stats: Dictionary = _file_manager.get_cache_stats()
	assert_int(cache_stats["current_size"]).is_less_or_equal(small_cache_size)

func test_access_statistics() -> void:
	# Clear existing stats
	_file_manager.clear_access_stats()
	
	var test_filename: String = "stats_test.txt"
	var test_content: String = "Statistics test content"
	
	# Perform various operations
	_file_manager.write_file_text(test_filename, test_content, FileManager.PathType.TEXT)
	_file_manager.read_file_text(test_filename, FileManager.PathType.TEXT)
	_file_manager.read_file_text(test_filename, FileManager.PathType.TEXT)  # Read again
	
	# Check statistics
	var stats: Dictionary = _file_manager.get_access_stats()
	assert_int(stats.size()).is_greater(0)
	
	# Should have write and read entries
	var has_write: bool = false
	var has_read: bool = false
	
	for key in stats.keys():
		if key.ends_with(":write"):
			has_write = true
		if key.ends_with(":read"):
			has_read = true
	
	assert_bool(has_write).is_true()
	assert_bool(has_read).is_true()

func test_file_deletion() -> void:
	var test_filename: String = "delete_test.txt"
	var test_content: String = "This file will be deleted"
	
	# Create file
	var write_success: bool = _file_manager.write_file_text(test_filename, test_content, FileManager.PathType.TEXT)
	assert_bool(write_success).is_true()
	
	# Verify it exists
	var exists_before: bool = _file_manager.file_exists(test_filename, FileManager.PathType.TEXT)
	assert_bool(exists_before).is_true()
	
	# Delete file
	var delete_success: bool = _file_manager.delete_file(test_filename, FileManager.PathType.TEXT)
	assert_bool(delete_success).is_true()
	
	# Verify it's gone
	var exists_after: bool = _file_manager.file_exists(test_filename, FileManager.PathType.TEXT)
	assert_bool(exists_after).is_false()

func test_path_resolution_cross_platform() -> void:
	# Test path separators work correctly on different platforms
	var _resolve_method = _file_manager.get("_resolve_file_path")
	
	# Test different path types
	var data_path: String = _resolve_method.call("test.cfg", FileManager.PathType.DATA)
	assert_str(data_path).contains("data")
	
	var models_path: String = _resolve_method.call("ship.pof", FileManager.PathType.MODELS)
	assert_str(models_path).contains("models")
	
	var sounds_path: String = _resolve_method.call("explosion.wav", FileManager.PathType.SOUNDS)
	assert_str(sounds_path).contains("sounds")
	
	# Paths should use correct separators for platform
	if OS.get_name() == "Windows":
		assert_str(data_path).contains("\\")
	else:
		assert_str(data_path).contains("/")

func test_error_handling() -> void:
	# Test opening non-existent file
	var non_existent_file: FileAccess = _file_manager.open_file("does_not_exist.txt", FileManager.AccessMode.READ, FileManager.PathType.TEXT)
	assert_object(non_existent_file).is_null()
	
	# Test reading non-existent file
	var empty_content: String = _file_manager.read_file_text("does_not_exist.txt", FileManager.PathType.TEXT)
	assert_str(empty_content).is_empty()
	
	# Test writing to invalid path (empty filename)
	var write_failure: bool = _file_manager.write_file_text("", "content", FileManager.PathType.TEXT)
	assert_bool(write_failure).is_false()
	
	# Test file size of non-existent file
	var invalid_size: int = _file_manager.get_file_size("does_not_exist.txt", FileManager.PathType.TEXT)
	assert_int(invalid_size).is_equal(-1)

func test_vp_archive_integration() -> void:
	# Test that VP archive integration is properly set up
	var vp_manager = _file_manager.get("_vp_archive_manager")
	assert_object(vp_manager).is_not_null()
	assert_object(vp_manager).is_instance_of(VPArchiveManager)
	
	# Test that VP file check works (even if no VP files are present)
	var vp_exists: bool = _file_manager.file_exists("nonexistent.txt", FileManager.PathType.ANY)
	# This should return false but not crash
	assert_bool(vp_exists).is_false()

## PRIVATE HELPER METHODS

func _create_test_directory_structure() -> void:
	# Create test root directory structure
	var dir_access: DirAccess = DirAccess.open("/")
	if dir_access == null:
		push_error("TestFileManager: Failed to create directory access")
		return
	
	# Create root directory
	dir_access.make_dir_recursive_absolute(_test_root_dir)
	
	# Create WCS-style subdirectories
	var subdirs: PackedStringArray = [
		"data",
		"data/maps",
		"data/text",
		"data/models",
		"data/tables",
		"data/sounds",
		"data/sounds/8b22k",
		"data/sounds/16b11k",
		"data/voice",
		"data/voice/briefing",
		"data/music",
		"data/movies",
		"data/interface",
		"data/fonts",
		"data/effects",
		"data/hud",
		"data/players",
		"data/players/images",
		"data/cache",
		"data/missions",
		"data/config"
	]
	
	for subdir in subdirs:
		var full_path: String = _test_root_dir.path_join(subdir)
		dir_access.make_dir_recursive_absolute(full_path)
	
	# Create user directory
	dir_access.make_dir_recursive_absolute(_test_user_dir)
	
	# Create some test files
	_create_test_file(_test_root_dir.path_join("data/config/test.cfg"), "[Test]\nvalue=123\n")
	_create_test_file(_test_root_dir.path_join("data/text/readme.txt"), "This is a test readme file.\n")
	_create_test_file(_test_root_dir.path_join("data/tables/ships.tbl"), "#Ships Table\n$Name: TestShip\n")

func _create_test_file(file_path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()
		_mock_files[file_path] = content

func _cleanup_test_directories() -> void:
	# Remove test directories
	var dir_access: DirAccess = DirAccess.open("/")
	if dir_access != null:
		_remove_directory_recursive(dir_access, _test_root_dir)
		_remove_directory_recursive(dir_access, _test_user_dir)

func _remove_directory_recursive(dir_access: DirAccess, path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = path.path_join(file_name)
		
		if dir.current_is_dir():
			_remove_directory_recursive(dir_access, full_path)
		else:
			DirAccess.remove_absolute(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	DirAccess.remove_absolute(path)