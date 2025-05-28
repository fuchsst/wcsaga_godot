class_name TestPlatformUtils
extends GdUnitTestSuite

## Unit tests for PlatformUtils cross-platform functionality.
## Tests file operations, path handling, system information, and error handling.

const PlatformUtils = preload("res://scripts/core/platform/platform_utils.gd")

var test_directory: String = "user://test_platform_utils"
var test_file: String = "user://test_platform_utils/test_file.txt"
var test_content: String = "Test file content for platform utils testing"

func before_test() -> void:
	# Initialize platform utils
	PlatformUtils.initialize()
	
	# Clean up any existing test files
	if DirAccess.dir_exists_absolute(test_directory):
		PlatformUtils.remove_directory_recursive(test_directory)
	
	# Create test directory
	PlatformUtils.create_directory_recursive(test_directory)

func after_test() -> void:
	# Clean up test files after each test
	if DirAccess.dir_exists_absolute(test_directory):
		PlatformUtils.remove_directory_recursive(test_directory)

func test_platform_initialization() -> void:
	# Test that initialization works correctly
	PlatformUtils.initialize()
	
	var platform_info: Dictionary = PlatformUtils.get_platform_info()
	assert_that(platform_info).is_not_empty()
	assert_that(platform_info.has("os_name")).is_true()
	assert_that(platform_info.has("processor_count")).is_true()
	assert_that(platform_info.has("memory_mb")).is_true()

func test_directory_operations() -> void:
	var nested_dir: String = test_directory + "/nested/deep/path"
	
	# Test directory creation
	var create_result: PlatformUtils.ErrorCode = PlatformUtils.create_directory_recursive(nested_dir)
	assert_that(create_result).is_equal(PlatformUtils.ErrorCode.SUCCESS)
	assert_that(PlatformUtils.directory_exists(nested_dir)).is_true()
	
	# Test directory existence check
	assert_that(PlatformUtils.directory_exists(test_directory)).is_true()
	assert_that(PlatformUtils.directory_exists("user://nonexistent_directory")).is_false()
	
	# Test directory removal
	var remove_result: PlatformUtils.ErrorCode = PlatformUtils.remove_directory_recursive(nested_dir)
	assert_that(remove_result).is_equal(PlatformUtils.ErrorCode.SUCCESS)
	assert_that(PlatformUtils.directory_exists(nested_dir)).is_false()

func test_file_operations() -> void:
	# Test file existence check (should not exist initially)
	assert_that(PlatformUtils.file_exists(test_file)).is_false()
	
	# Create test file manually
	var file: FileAccess = FileAccess.open(test_file, FileAccess.WRITE)
	assert_that(file).is_not_null()
	file.store_string(test_content)
	file.close()
	
	# Test file existence check (should exist now)
	assert_that(PlatformUtils.file_exists(test_file)).is_true()
	
	# Test file size
	var file_size: int = PlatformUtils.get_file_size(test_file)
	assert_that(file_size).is_equal(test_content.length())
	
	# Test file modification time
	var mod_time: int = PlatformUtils.get_file_modification_time(test_file)
	assert_that(mod_time).is_greater(0)

func test_file_copy_operations() -> void:
	var source_file: String = test_directory + "/source.txt"
	var dest_file: String = test_directory + "/destination.txt"
	
	# Create source file
	var file: FileAccess = FileAccess.open(source_file, FileAccess.WRITE)
	assert_that(file).is_not_null()
	file.store_string(test_content)
	file.close()
	
	# Test file copy
	var copy_result: PlatformUtils.ErrorCode = PlatformUtils.copy_file(source_file, dest_file)
	assert_that(copy_result).is_equal(PlatformUtils.ErrorCode.SUCCESS)
	assert_that(PlatformUtils.file_exists(dest_file)).is_true()
	
	# Verify copied content
	var dest_file_access: FileAccess = FileAccess.open(dest_file, FileAccess.READ)
	assert_that(dest_file_access).is_not_null()
	var copied_content: String = dest_file_access.get_as_text()
	dest_file_access.close()
	assert_that(copied_content).is_equal(test_content)

func test_file_move_operations() -> void:
	var source_file: String = test_directory + "/move_source.txt"
	var dest_file: String = test_directory + "/move_destination.txt"
	
	# Create source file
	var file: FileAccess = FileAccess.open(source_file, FileAccess.WRITE)
	assert_that(file).is_not_null()
	file.store_string(test_content)
	file.close()
	
	# Test file move
	var move_result: PlatformUtils.ErrorCode = PlatformUtils.move_file(source_file, dest_file)
	assert_that(move_result).is_equal(PlatformUtils.ErrorCode.SUCCESS)
	assert_that(PlatformUtils.file_exists(source_file)).is_false()
	assert_that(PlatformUtils.file_exists(dest_file)).is_true()

func test_file_delete_operations() -> void:
	var delete_file: String = test_directory + "/delete_me.txt"
	
	# Create file to delete
	var file: FileAccess = FileAccess.open(delete_file, FileAccess.WRITE)
	assert_that(file).is_not_null()
	file.store_string(test_content)
	file.close()
	
	# Verify file exists
	assert_that(PlatformUtils.file_exists(delete_file)).is_true()
	
	# Test file deletion
	var delete_result: PlatformUtils.ErrorCode = PlatformUtils.delete_file(delete_file)
	assert_that(delete_result).is_equal(PlatformUtils.ErrorCode.SUCCESS)
	assert_that(PlatformUtils.file_exists(delete_file)).is_false()

func test_path_normalization() -> void:
	# Test Windows-style path normalization
	var windows_path: String = "C:\\Users\\Player\\Documents\\file.txt"
	var normalized: String = PlatformUtils.normalize_path(windows_path)
	assert_that(normalized).is_equal("C:/Users/Player/Documents/file.txt")
	
	# Test double slash removal
	var double_slash_path: String = "res://scripts//core//platform//utils.gd"
	var normalized_double: String = PlatformUtils.normalize_path(double_slash_path)
	assert_that(normalized_double).is_equal("res://scripts/core/platform/utils.gd")
	
	# Test relative path handling
	var relative_path: String = "./scripts/core/platform.gd"
	var normalized_relative: String = PlatformUtils.normalize_path(relative_path)
	assert_that(normalized_relative).is_equal("scripts/core/platform.gd")
	
	# Test empty path
	var empty_normalized: String = PlatformUtils.normalize_path("")
	assert_that(empty_normalized).is_equal("")

func test_directory_listing() -> void:
	# Create test files with different extensions
	var test_files: PackedStringArray = ["test1.txt", "test2.gd", "test3.txt", "readme.md"]
	
	for file_name: String in test_files:
		var file_path: String = test_directory + "/" + file_name
		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		assert_that(file).is_not_null()
		file.store_string("Test content")
		file.close()
	
	# Create subdirectories
	PlatformUtils.create_directory_recursive(test_directory + "/subdir1")
	PlatformUtils.create_directory_recursive(test_directory + "/subdir2")
	
	# Test getting all files
	var all_files: PackedStringArray = PlatformUtils.get_directory_files(test_directory)
	assert_that(all_files.size()).is_equal(4)
	
	# Test getting files with specific extension
	var txt_files: PackedStringArray = PlatformUtils.get_directory_files(test_directory, "txt")
	assert_that(txt_files.size()).is_equal(2)
	
	# Test getting subdirectories
	var subdirs: PackedStringArray = PlatformUtils.get_directory_subdirs(test_directory)
	assert_that(subdirs.size()).is_equal(2)
	assert_that(subdirs).contains("subdir1")
	assert_that(subdirs).contains("subdir2")

func test_system_information() -> void:
	# Test OS name
	var os_name: String = PlatformUtils.get_os_name()
	assert_that(os_name).is_not_empty()
	
	# Test processor information
	var processor_info: Dictionary = PlatformUtils.get_processor_info()
	assert_that(processor_info.has("name")).is_true()
	assert_that(processor_info.has("count")).is_true()
	assert_that(processor_info["count"]).is_greater(0)
	
	# Test system memory
	var memory_mb: int = PlatformUtils.get_system_memory_mb()
	assert_that(memory_mb).is_greater(0)
	
	# Test platform detection
	var is_pc: bool = PlatformUtils.is_pc_platform()
	var is_mobile: bool = PlatformUtils.is_mobile_platform()
	var is_web: bool = PlatformUtils.is_web_platform()
	
	# At least one platform type should be true
	assert_that(is_pc or is_mobile or is_web).is_true()

func test_executable_information() -> void:
	var exe_info: Dictionary = PlatformUtils.get_executable_info()
	assert_that(exe_info.has("path")).is_true()
	assert_that(exe_info.has("directory")).is_true()
	assert_that(exe_info.has("filename")).is_true()
	
	# Path should not be empty (unless running in editor)
	if not OS.has_feature("editor"):
		assert_that(exe_info["path"]).is_not_empty()

func test_user_data_directory() -> void:
	var user_dir: String = PlatformUtils.get_user_data_directory()
	assert_that(user_dir).is_not_empty()
	
	# Directory should exist or be creatable
	assert_that(DirAccess.dir_exists_absolute(user_dir) or user_dir.begins_with("user://")).is_true()

func test_command_line_args() -> void:
	var args: PackedStringArray = PlatformUtils.get_command_line_args()
	# Command line args array should exist (may be empty)
	assert_that(args).is_not_null()

func test_path_validation() -> void:
	# Test valid paths
	assert_that(PlatformUtils.validate_file_path("res://scripts/test.gd")).is_true()
	assert_that(PlatformUtils.validate_file_path("user://save_data.dat")).is_true()
	assert_that(PlatformUtils.validate_file_path("C:/Users/Player/Documents/file.txt")).is_true()
	
	# Test invalid paths with illegal characters
	assert_that(PlatformUtils.validate_file_path("file<name>.txt")).is_false()
	assert_that(PlatformUtils.validate_file_path("file>name.txt")).is_false()
	assert_that(PlatformUtils.validate_file_path("file:name.txt")).is_false()
	assert_that(PlatformUtils.validate_file_path("file\"name.txt")).is_false()
	assert_that(PlatformUtils.validate_file_path("file|name.txt")).is_false()
	assert_that(PlatformUtils.validate_file_path("file?name.txt")).is_false()
	assert_that(PlatformUtils.validate_file_path("file*name.txt")).is_false()
	
	# Test reserved Windows names
	assert_that(PlatformUtils.validate_file_path("CON.txt")).is_false()
	assert_that(PlatformUtils.validate_file_path("PRN.dat")).is_false()
	assert_that(PlatformUtils.validate_file_path("AUX.log")).is_false()
	assert_that(PlatformUtils.validate_file_path("NUL.cfg")).is_false()
	
	# Test empty path
	assert_that(PlatformUtils.validate_file_path("")).is_false()

func test_error_code_conversion() -> void:
	# Test error code conversion (internal function testing)
	# These would typically be tested through operations that trigger specific Godot errors
	
	# Test successful operations return SUCCESS
	var create_result: PlatformUtils.ErrorCode = PlatformUtils.create_directory_recursive(test_directory + "/error_test")
	assert_that(create_result).is_equal(PlatformUtils.ErrorCode.SUCCESS)
	
	# Test invalid path operations
	var invalid_result: PlatformUtils.ErrorCode = PlatformUtils.create_directory_recursive("")
	assert_that(invalid_result).is_equal(PlatformUtils.ErrorCode.INVALID_PATH)
	
	# Test file not found
	var not_found_size: int = PlatformUtils.get_file_size("user://nonexistent_file.txt")
	assert_that(not_found_size).is_equal(-1)

func test_current_directory_operations() -> void:
	# Test getting current directory
	var current_dir: String = PlatformUtils.get_current_directory()
	assert_that(current_dir).is_not_empty()
	
	# Test setting current directory (should succeed but not actually change in Godot)
	var set_result: PlatformUtils.ErrorCode = PlatformUtils.set_current_directory("user://")
	assert_that(set_result).is_equal(PlatformUtils.ErrorCode.SUCCESS)

func test_sleep_function() -> void:
	# Test sleep function (non-blocking)
	var start_time: float = Time.get_ticks_msec() / 1000.0
	await PlatformUtils.sleep_ms(100)  # Sleep for 100ms
	var end_time: float = Time.get_ticks_msec() / 1000.0
	
	var elapsed: float = end_time - start_time
	# Should have elapsed at least 100ms (allowing some tolerance for timing)
	assert_that(elapsed).is_greater_equal(0.09)  # 90ms tolerance

func test_edge_cases_and_error_conditions() -> void:
	# Test operations on non-existent files/directories
	assert_that(PlatformUtils.file_exists("user://completely_nonexistent_file.xyz")).is_false()
	assert_that(PlatformUtils.directory_exists("user://completely_nonexistent_directory")).is_false()
	
	# Test operations with empty strings
	assert_that(PlatformUtils.copy_file("", "")).is_equal(PlatformUtils.ErrorCode.INVALID_PATH)
	assert_that(PlatformUtils.move_file("", "")).is_equal(PlatformUtils.ErrorCode.INVALID_PATH)
	assert_that(PlatformUtils.delete_file("")).is_equal(PlatformUtils.ErrorCode.INVALID_PATH)
	
	# Test file operations on directories
	var file_on_dir_size: int = PlatformUtils.get_file_size(test_directory)
	assert_that(file_on_dir_size).is_equal(-1)
	
	# Test directory operations on files
	if PlatformUtils.file_exists(test_file):
		PlatformUtils.delete_file(test_file)
	
	# Create a file
	var file: FileAccess = FileAccess.open(test_file, FileAccess.WRITE)
	file.store_string("test")
	file.close()
	
	var files_in_file: PackedStringArray = PlatformUtils.get_directory_files(test_file)
	assert_that(files_in_file.is_empty()).is_true()

func test_large_file_operations() -> void:
	# Test with larger file content
	var large_content: String = ""
	for i: int in range(10000):
		large_content += "This is line %d of a large test file.\n" % i
	
	var large_file: String = test_directory + "/large_file.txt"
	
	# Create large file
	var file: FileAccess = FileAccess.open(large_file, FileAccess.WRITE)
	assert_that(file).is_not_null()
	file.store_string(large_content)
	file.close()
	
	# Test file size
	var size: int = PlatformUtils.get_file_size(large_file)
	assert_that(size).is_equal(large_content.length())
	
	# Test copy large file
	var large_copy: String = test_directory + "/large_file_copy.txt"
	var copy_result: PlatformUtils.ErrorCode = PlatformUtils.copy_file(large_file, large_copy)
	assert_that(copy_result).is_equal(PlatformUtils.ErrorCode.SUCCESS)
	
	# Verify copy size
	var copy_size: int = PlatformUtils.get_file_size(large_copy)
	assert_that(copy_size).is_equal(size)

func test_unicode_and_special_characters() -> void:
	# Test files with Unicode characters in names (if supported by filesystem)
	var unicode_file: String = test_directory + "/测试文件.txt"
	var unicode_content: String = "Unicode content: 你好世界! Здравствуй мир! こんにちは世界!"
	
	# Create file with Unicode name and content
	var file: FileAccess = FileAccess.open(unicode_file, FileAccess.WRITE)
	if file != null:  # May not be supported on all filesystems
		file.store_string(unicode_content)
		file.close()
		
		# Test file operations
		assert_that(PlatformUtils.file_exists(unicode_file)).is_true()
		var size: int = PlatformUtils.get_file_size(unicode_file)
		assert_that(size).is_greater(0)
		
		# Test copy with Unicode
		var unicode_copy: String = test_directory + "/拷贝文件.txt"
		var copy_result: PlatformUtils.ErrorCode = PlatformUtils.copy_file(unicode_file, unicode_copy)
		if copy_result == PlatformUtils.ErrorCode.SUCCESS:
			assert_that(PlatformUtils.file_exists(unicode_copy)).is_true()

func test_concurrent_operations() -> void:
	# Test multiple file operations in sequence to ensure state consistency
	var files: Array[String] = []
	
	# Create multiple files
	for i: int in range(10):
		var file_path: String = test_directory + "/concurrent_%d.txt" % i
		files.append(file_path)
		
		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		assert_that(file).is_not_null()
		file.store_string("Concurrent test file %d" % i)
		file.close()
	
	# Verify all files exist
	for file_path: String in files:
		assert_that(PlatformUtils.file_exists(file_path)).is_true()
	
	# Perform operations on all files
	for i: int in range(files.size()):
		var source: String = files[i]
		var dest: String = test_directory + "/moved_%d.txt" % i
		
		var move_result: PlatformUtils.ErrorCode = PlatformUtils.move_file(source, dest)
		assert_that(move_result).is_equal(PlatformUtils.ErrorCode.SUCCESS)
		assert_that(PlatformUtils.file_exists(dest)).is_true()
		assert_that(PlatformUtils.file_exists(source)).is_false()

func test_platform_specific_behavior() -> void:
	# Test behavior that might differ across platforms
	var platform_info: Dictionary = PlatformUtils.get_platform_info()
	var os_name: String = platform_info.get("os_name", "Unknown")
	
	match os_name:
		"Windows":
			# Test Windows-specific behavior
			assert_that(PlatformUtils.is_pc_platform()).is_true()
			# Windows typically has drive letters
			var user_dir: String = PlatformUtils.get_user_data_directory()
			# Note: user:// paths in Godot are abstracted, so this might not apply
		
		"Linux", "FreeBSD", "NetBSD", "OpenBSD":
			# Test Unix-like behavior
			assert_that(PlatformUtils.is_pc_platform()).is_true()
			# Unix-like systems typically use forward slashes
			var normalized: String = PlatformUtils.normalize_path("/home/user/file.txt")
			assert_that(normalized).is_equal("/home/user/file.txt")
		
		"macOS":
			# Test macOS-specific behavior
			assert_that(PlatformUtils.is_pc_platform()).is_true()
		
		"Android", "iOS":
			# Test mobile platform behavior
			assert_that(PlatformUtils.is_mobile_platform()).is_true()
		
		"Web":
			# Test web platform behavior
			assert_that(PlatformUtils.is_web_platform()).is_true()
		
		_:
			# Unknown platform - basic tests should still work
			assert_that(os_name).is_not_empty()

func test_performance_characteristics() -> void:
	# Test that operations complete within reasonable time limits
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Perform a series of file operations
	for i: int in range(100):
		var file_path: String = test_directory + "/perf_test_%d.txt" % i
		var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
		if file != null:
			file.store_string("Performance test content")
			file.close()
	
	var creation_time: float = Time.get_ticks_msec() / 1000.0
	var creation_duration: float = creation_time - start_time
	
	# File creation should complete in reasonable time (less than 5 seconds for 100 files)
	assert_that(creation_duration).is_less(5.0)
	
	# Test directory listing performance
	var list_start: float = Time.get_ticks_msec() / 1000.0
	var files: PackedStringArray = PlatformUtils.get_directory_files(test_directory)
	var list_end: float = Time.get_ticks_msec() / 1000.0
	
	var list_duration: float = list_end - list_start
	assert_that(list_duration).is_less(1.0)  # Directory listing should be fast
	assert_that(files.size()).is_greater_equal(100)  # Should find all created files