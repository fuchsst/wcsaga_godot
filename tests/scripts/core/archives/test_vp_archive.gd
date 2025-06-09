class_name TestVPArchive
extends GdUnitTestSuite

## Unit tests for VPArchive VP file reading infrastructure.
## Tests VP file parsing, file extraction, and error handling.

const VPArchive = preload("res://scripts/core/archives/vp_archive.gd")
const VPFileAccess = preload("res://scripts/core/archives/vp_file_access.gd")
const VPArchiveManager = preload("res://scripts/core/archives/vp_archive_manager.gd")
const DebugManager = preload("res://scripts/core/platform/debug_manager.gd")

var test_vp_path: String = "user://test_archive.vp"
var test_data_dir: String = "user://test_vp_data"

func before_test() -> void:
	# Initialize debug system for testing
	DebugManager.initialize(false)
	
	# Clean up any existing test files
	_cleanup_test_files()
	
	# Create test directory
	if not DirAccess.dir_exists_absolute(test_data_dir):
		DirAccess.make_dir_recursive_absolute(test_data_dir)

func after_test() -> void:
	# Clean up test files after each test
	_cleanup_test_files()

func _cleanup_test_files() -> void:
	if FileAccess.file_exists(test_vp_path):
		DirAccess.remove_absolute(test_vp_path)
	
	if DirAccess.dir_exists_absolute(test_data_dir):
		var dir: DirAccess = DirAccess.open(test_data_dir)
		if dir != null:
			var files: PackedStringArray = dir.get_files()
			for file: String in files:
				dir.remove(file)
			DirAccess.remove_absolute(test_data_dir)

func test_vp_header_structure() -> void:
	# Test VP header structure
	var header: VPArchive.VPHeader = VPArchive.VPHeader.new()
	
	# Test default values
	assert_that(header.signature).is_equal("")
	assert_that(header.version).is_equal(0)
	assert_that(header.index_offset).is_equal(0)
	assert_that(header.num_files).is_equal(0)
	
	# Test assignment
	header.signature = "VPVP"
	header.version = 1
	header.index_offset = 100
	header.num_files = 5
	
	assert_that(header.signature).is_equal("VPVP")
	assert_that(header.version).is_equal(1)
	assert_that(header.index_offset).is_equal(100)
	assert_that(header.num_files).is_equal(5)

func test_vp_file_entry_structure() -> void:
	# Test VP file entry structure
	var entry: VPArchive.VPFileEntry = VPArchive.VPFileEntry.new()
	
	# Test default values
	assert_that(entry.offset).is_equal(0)
	assert_that(entry.size).is_equal(0)
	assert_that(entry.filename).is_equal("")
	assert_that(entry.write_time).is_equal(0)
	assert_that(entry.is_directory()).is_true()  # size=0 means directory
	
	# Test file entry
	entry.offset = 1024
	entry.size = 2048
	entry.filename = "test.txt"
	entry.write_time = 1234567890
	
	assert_that(entry.offset).is_equal(1024)
	assert_that(entry.size).is_equal(2048)
	assert_that(entry.filename).is_equal("test.txt")
	assert_that(entry.write_time).is_equal(1234567890)
	assert_that(entry.is_directory()).is_false()  # size>0 means file

func test_create_mock_vp_archive() -> void:
	# Create a mock VP archive for testing
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	
	# Write test archive to file
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	file.store_buffer(archive_data)
	file.close()
	
	# Verify file was created
	assert_that(FileAccess.file_exists(test_vp_path)).is_true()
	
	# Verify file size
	var file_size: int = FileAccess.get_file_as_bytes(test_vp_path).size()
	assert_that(file_size).is_equal(archive_data.size())

func test_load_valid_vp_archive() -> void:
	# Create and save mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	# Load archive
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_not_null()
	assert_that(archive.is_loaded).is_true()
	
	# Verify header
	assert_that(archive.header.signature).is_equal("VPVP")
	assert_that(archive.header.version).is_equal(1)
	assert_that(archive.header.num_files).is_equal(3)  # 1 dir + 2 files
	
	# Verify files can be found
	assert_that(archive.has_file("data/test1.txt")).is_true()
	assert_that(archive.has_file("data/test2.dat")).is_true()
	assert_that(archive.has_file("nonexistent.txt")).is_false()
	
	# Clean up
	archive.close_archive()

func test_load_nonexistent_archive() -> void:
	# Try to load non-existent archive
	var archive: VPArchive = VPArchive.load_archive("user://nonexistent.vp")
	assert_that(archive).is_null()

func test_load_invalid_archive() -> void:
	# Create invalid archive (wrong signature)
	var invalid_data: PackedByteArray = PackedByteArray()
	invalid_data.append_array("INVALID_SIG".to_ascii_buffer())
	invalid_data.resize(100)  # Pad to minimum size
	
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(invalid_data)
	file.close()
	
	# Try to load invalid archive
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_null()

func test_get_file_data() -> void:
	# Create and load mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_not_null()
	
	# Get file data
	var file_data: PackedByteArray = archive.get_file_data("data/test1.txt")
	assert_that(file_data).is_not_empty()
	
	var file_text: String = file_data.get_string_from_utf8()
	assert_that(file_text).is_equal("Test file 1 content")
	
	# Test case insensitive access
	var file_data2: PackedByteArray = archive.get_file_data("DATA/TEST1.TXT")
	assert_that(file_data2).is_equal(file_data)
	
	# Test non-existent file
	var missing_data: PackedByteArray = archive.get_file_data("missing.txt")
	assert_that(missing_data.is_empty()).is_true()
	
	archive.close_archive()

func test_get_file_text() -> void:
	# Create and load mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_not_null()
	
	# Get file as text
	var file_text: String = archive.get_file_text("data/test1.txt")
	assert_that(file_text).is_equal("Test file 1 content")
	
	# Test non-existent file
	var missing_text: String = archive.get_file_text("missing.txt")
	assert_that(missing_text).is_empty()
	
	archive.close_archive()

func test_get_file_list() -> void:
	# Create and load mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_not_null()
	
	# Get file list
	var file_list: PackedStringArray = archive.get_file_list()
	assert_that(file_list.size()).is_equal(2)  # Only files, not directories
	assert_that(file_list).contains("data/test1.txt")
	assert_that(file_list).contains("data/test2.dat")
	
	archive.close_archive()

func test_find_files_with_pattern() -> void:
	# Create and load mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_not_null()
	
	# Find files by pattern
	var txt_files: PackedStringArray = archive.find_files("*.txt")
	assert_that(txt_files.size()).is_equal(1)
	assert_that(txt_files).contains("data/test1.txt")
	
	var data_files: PackedStringArray = archive.find_files("data/*")
	assert_that(data_files.size()).is_equal(2)
	
	var no_files: PackedStringArray = archive.find_files("*.xyz")
	assert_that(no_files.size()).is_equal(0)
	
	archive.close_archive()

func test_archive_validation() -> void:
	# Create and load mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_not_null()
	
	# Validate archive
	var is_valid: bool = archive.validate_archive()
	assert_that(is_valid).is_true()
	
	archive.close_archive()

func test_archive_info() -> void:
	# Create and load mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_not_null()
	
	# Get archive info
	var info: Dictionary = archive.get_archive_info()
	assert_that(info).has_key("archive_path")
	assert_that(info).has_key("version")
	assert_that(info).has_key("file_count")
	assert_that(info).has_key("directory_count")
	assert_that(info).has_key("total_uncompressed_size")
	
	assert_that(info["version"]).is_equal(1)
	assert_that(info["file_count"]).is_equal(2)
	assert_that(info["directory_count"]).is_equal(1)
	
	archive.close_archive()

func test_vp_file_access() -> void:
	# Create and load mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_not_null()
	
	# Open file for reading
	var vp_file: VPFileAccess = VPFileAccess.open(archive, "data/test1.txt")
	assert_that(vp_file).is_not_null()
	assert_that(vp_file.is_file_open()).is_true()
	
	# Test file operations
	assert_that(vp_file.get_length()).is_equal(19)  # "Test file 1 content".length()
	assert_that(vp_file.get_position()).is_equal(0)
	assert_that(vp_file.eof_reached()).is_false()
	
	# Read data
	var file_text: String = vp_file.get_as_text()
	assert_that(file_text).is_equal("Test file 1 content")
	
	# Close file
	vp_file.close()
	assert_that(vp_file.is_file_open()).is_false()
	
	archive.close_archive()

func test_vp_file_access_positioning() -> void:
	# Create and load mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	var archive: VPArchive = VPArchive.load_archive(test_vp_path)
	assert_that(archive).is_not_null()
	
	var vp_file: VPFileAccess = VPFileAccess.open(archive, "data/test1.txt")
	assert_that(vp_file).is_not_null()
	
	# Test seeking
	vp_file.seek(5)
	assert_that(vp_file.get_position()).is_equal(5)
	
	vp_file.seek_end(-3)
	assert_that(vp_file.get_position()).is_equal(16)  # 19 - 3
	
	# Test reading after seek
	vp_file.seek(0)
	var first_char: int = vp_file.get_8()
	assert_that(first_char).is_equal(84)  # 'T' in ASCII
	
	vp_file.close()
	archive.close_archive()

func test_vp_archive_manager() -> void:
	# Create mock archive
	var archive_data: PackedByteArray = _create_mock_vp_archive()
	var file: FileAccess = FileAccess.open(test_vp_path, FileAccess.WRITE)
	file.store_buffer(archive_data)
	file.close()
	
	# Initialize manager
	var manager: VPArchiveManager = VPArchiveManager.get_instance()
	manager.initialize(PackedStringArray(["user://"]))
	
	# Load archive through manager
	var archive: VPArchive = manager.load_archive("test_archive.vp")
	assert_that(archive).is_not_null()
	
	# Test file access through manager
	var file_data: PackedByteArray = manager.get_file_data("data/test1.txt")
	assert_that(file_data).is_not_empty()
	
	var file_text: String = file_data.get_string_from_utf8()
	assert_that(file_text).is_equal("Test file 1 content")
	
	# Test file existence check
	assert_that(manager.file_exists("data/test1.txt")).is_true()
	assert_that(manager.file_exists("nonexistent.txt")).is_false()
	
	# Get cache stats
	var stats: Dictionary = manager.get_cache_stats()
	assert_that(stats).has_key("cached_archives")
	assert_that(stats["cached_archives"]).is_equal(1)
	
	manager.clear_caches()

func test_error_handling() -> void:
	# Test various error conditions
	
	# Empty archive path
	var archive1: VPArchive = VPArchive.load_archive("")
	assert_that(archive1).is_null()
	
	# Invalid file path
	var archive2: VPArchive = VPArchive.load_archive("invalid:/path")
	assert_that(archive2).is_null()
	
	# Try to open non-existent file
	var vp_file: VPFileAccess = VPFileAccess.open(null, "test.txt")
	assert_that(vp_file).is_null()

func _create_mock_vp_archive() -> PackedByteArray:
	# Create a mock VP archive for testing
	var archive_data: PackedByteArray = PackedByteArray()
	
	# VP Header (16 bytes)
	archive_data.append_array("VPVP".to_ascii_buffer())  # Signature (4 bytes)
	archive_data.append_array(_int_to_bytes(1))          # Version (4 bytes)
	archive_data.append_array(_int_to_bytes(72))         # Index offset (4 bytes) - after header + file data
	archive_data.append_array(_int_to_bytes(3))          # Num files (4 bytes) - 1 dir + 2 files
	
	# File data section
	var file1_content: PackedByteArray = "Test file 1 content".to_utf8_buffer()
	var file2_content: PackedByteArray = "Test file 2 data".to_utf8_buffer()
	
	var file1_offset: int = 16  # After header
	var file2_offset: int = file1_offset + file1_content.size()
	
	# Store file data
	archive_data.append_array(file1_content)
	archive_data.append_array(file2_content)
	
	# File index section (starts at offset 72)
	# Directory entry: "data"
	archive_data.append_array(_int_to_bytes(0))          # Offset (0 for directory)
	archive_data.append_array(_int_to_bytes(0))          # Size (0 for directory)
	var dir_name: PackedByteArray = "data".to_ascii_buffer()
	dir_name.resize(32)  # Pad to 32 bytes
	archive_data.append_array(dir_name)                  # Filename (32 bytes)
	archive_data.append_array(_int_to_bytes(1234567890)) # Write time (4 bytes)
	
	# File entry 1: "test1.txt"
	archive_data.append_array(_int_to_bytes(file1_offset))  # Offset
	archive_data.append_array(_int_to_bytes(file1_content.size()))  # Size
	var file1_name: PackedByteArray = "test1.txt".to_ascii_buffer()
	file1_name.resize(32)  # Pad to 32 bytes
	archive_data.append_array(file1_name)                # Filename (32 bytes)
	archive_data.append_array(_int_to_bytes(1234567891)) # Write time (4 bytes)
	
	# File entry 2: "test2.dat"
	archive_data.append_array(_int_to_bytes(file2_offset))  # Offset
	archive_data.append_array(_int_to_bytes(file2_content.size()))  # Size
	var file2_name: PackedByteArray = "test2.dat".to_ascii_buffer()
	file2_name.resize(32)  # Pad to 32 bytes
	archive_data.append_array(file2_name)                # Filename (32 bytes)
	archive_data.append_array(_int_to_bytes(1234567892)) # Write time (4 bytes)
	
	return archive_data

func _int_to_bytes(value: int) -> PackedByteArray:
	# Convert 32-bit integer to little-endian byte array
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)
	bytes.append((value >> 16) & 0xFF)
	bytes.append((value >> 24) & 0xFF)
	return bytes