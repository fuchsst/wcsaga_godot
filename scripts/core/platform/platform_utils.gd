class_name PlatformUtils
extends RefCounted

## Cross-platform utility functions providing WCS-compatible OS abstraction.
## Replaces WCS osapi.cpp functionality using Godot's built-in cross-platform capabilities.
## Provides unified interface for file operations, directory management, and system info.

const WCSConstants = preload("res://scripts/core/foundation/wcs_constants.gd")
const WCSPaths = preload("res://scripts/core/foundation/wcs_paths.gd")

## Platform-specific error codes matching WCS expectations
enum ErrorCode {
	SUCCESS = 0,
	FILE_NOT_FOUND = -1,
	ACCESS_DENIED = -2,
	INVALID_PATH = -3,
	DISK_FULL = -4,
	GENERIC_ERROR = -5
}

## File attribute flags for cross-platform file operations
enum FileAttributes {
	NONE = 0,
	READ_ONLY = 1,
	HIDDEN = 2,
	SYSTEM = 4,
	DIRECTORY = 8,
	ARCHIVE = 16
}

## Detection result for platform capabilities
static var _platform_info: Dictionary = {}
static var _is_initialized: bool = false

## Initialize platform detection and capabilities
static func initialize() -> void:
	if _is_initialized:
		return
	
	_platform_info = {
		"os_name": OS.get_name(),
		"processor_name": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"memory_mb": _get_system_memory_mb(),
		"user_data_dir": OS.get_user_data_dir(),
		"executable_path": OS.get_executable_path(),
		"cmdline_args": OS.get_cmdline_args(),
		"has_feature_pc": OS.has_feature("pc"),
		"has_feature_mobile": OS.has_feature("mobile"),
		"has_feature_web": OS.has_feature("web")
	}
	
	_is_initialized = true

## Get system memory in megabytes (estimated)
static func _get_system_memory_mb() -> int:
	# Godot doesn't provide direct system memory access
	# Use reasonable estimates based on platform
	if OS.has_feature("mobile"):
		return 4096  # 4GB typical for mobile
	elif OS.has_feature("web"):
		return 2048  # 2GB typical for web
	else:
		return 8192  # 8GB typical for PC

## Create directory structure recursively with proper error handling
static func create_directory_recursive(dir_path: String) -> ErrorCode:
	if dir_path.is_empty():
		push_error("PlatformUtils: Empty directory path provided")
		return ErrorCode.INVALID_PATH
	
	var normalized_path: String = normalize_path(dir_path)
	
	# Check if directory already exists
	if DirAccess.dir_exists_absolute(normalized_path):
		return ErrorCode.SUCCESS
	
	# Create directory recursively using static method
	var result: Error = DirAccess.make_dir_recursive_absolute(normalized_path)
	if result != OK:
		push_error("PlatformUtils: Failed to create directory '%s' - Error: %d" % [normalized_path, result])
		return _convert_godot_error_to_platform_error(result)
	
	return ErrorCode.SUCCESS

## Remove directory and all contents recursively
static func remove_directory_recursive(dir_path: String) -> ErrorCode:
	if dir_path.is_empty():
		push_error("PlatformUtils: Empty directory path provided")
		return ErrorCode.INVALID_PATH
	
	var normalized_path: String = normalize_path(dir_path)
	
	if not DirAccess.dir_exists_absolute(normalized_path):
		return ErrorCode.FILE_NOT_FOUND
	
	var dir_access: DirAccess = DirAccess.open(normalized_path)
	if dir_access == null:
		push_error("PlatformUtils: Failed to open directory '%s'" % normalized_path)
		return ErrorCode.ACCESS_DENIED
	
	# Remove all files and subdirectories
	var files: PackedStringArray = dir_access.get_files()
	for file_name: String in files:
		var file_path: String = dir_access.get_current_dir() + "/" + file_name
		var result: Error = dir_access.remove(file_name)
		if result != OK:
			push_error("PlatformUtils: Failed to remove file '%s' - Error: %d" % [file_path, result])
			return _convert_godot_error_to_platform_error(result)
	
	var subdirs: PackedStringArray = dir_access.get_directories()
	for subdir_name: String in subdirs:
		var subdir_path: String = dir_access.get_current_dir() + "/" + subdir_name
		var remove_result: ErrorCode = remove_directory_recursive(subdir_path)
		if remove_result != ErrorCode.SUCCESS:
			return remove_result
	
	# Remove the now-empty directory
	dir_access.change_dir("..")
	var result: Error = dir_access.remove(normalized_path.get_file())
	if result != OK:
		push_error("PlatformUtils: Failed to remove directory '%s' - Error: %d" % [normalized_path, result])
		return _convert_godot_error_to_platform_error(result)
	
	return ErrorCode.SUCCESS

## Check if file exists with cross-platform path handling
static func file_exists(file_path: String) -> bool:
	if file_path.is_empty():
		return false
	
	var normalized_path: String = normalize_path(file_path)
	return FileAccess.file_exists(normalized_path)

## Check if directory exists with cross-platform path handling
static func directory_exists(dir_path: String) -> bool:
	if dir_path.is_empty():
		return false
	
	var normalized_path: String = normalize_path(dir_path)
	return DirAccess.dir_exists_absolute(normalized_path)

## Get file size in bytes
static func get_file_size(file_path: String) -> int:
	if not file_exists(file_path):
		return -1
	
	var file: FileAccess = FileAccess.open(normalize_path(file_path), FileAccess.READ)
	if file == null:
		return -1
	
	var size: int = file.get_length()
	file.close()
	return size

## Get file modification time as Unix timestamp
static func get_file_modification_time(file_path: String) -> int:
	if not file_exists(file_path):
		return -1
	
	var normalized_path: String = normalize_path(file_path)
	return FileAccess.get_modified_time(normalized_path)

## Copy file from source to destination with proper error handling
static func copy_file(source_path: String, dest_path: String) -> ErrorCode:
	if source_path.is_empty() or dest_path.is_empty():
		push_error("PlatformUtils: Empty file paths provided")
		return ErrorCode.INVALID_PATH
	
	var normalized_source: String = normalize_path(source_path)
	var normalized_dest: String = normalize_path(dest_path)
	
	if not file_exists(normalized_source):
		push_error("PlatformUtils: Source file does not exist: '%s'" % normalized_source)
		return ErrorCode.FILE_NOT_FOUND
	
	# Ensure destination directory exists
	var dest_dir: String = normalized_dest.get_base_dir()
	if not dest_dir.is_empty():
		var create_result: ErrorCode = create_directory_recursive(dest_dir)
		if create_result != ErrorCode.SUCCESS:
			return create_result
	
	# Open source file for reading
	var source_file: FileAccess = FileAccess.open(normalized_source, FileAccess.READ)
	if source_file == null:
		push_error("PlatformUtils: Failed to open source file: '%s'" % normalized_source)
		return ErrorCode.ACCESS_DENIED
	
	# Open destination file for writing
	var dest_file: FileAccess = FileAccess.open(normalized_dest, FileAccess.WRITE)
	if dest_file == null:
		source_file.close()
		push_error("PlatformUtils: Failed to create destination file: '%s'" % normalized_dest)
		return ErrorCode.ACCESS_DENIED
	
	# Copy file contents
	var buffer: PackedByteArray = source_file.get_buffer(source_file.get_length())
	dest_file.store_buffer(buffer)
	
	source_file.close()
	dest_file.close()
	
	return ErrorCode.SUCCESS

## Move/rename file with proper error handling
static func move_file(source_path: String, dest_path: String) -> ErrorCode:
	if source_path.is_empty() or dest_path.is_empty():
		push_error("PlatformUtils: Empty file paths provided")
		return ErrorCode.INVALID_PATH
	
	var normalized_source: String = normalize_path(source_path)
	var normalized_dest: String = normalize_path(dest_path)
	
	if not file_exists(normalized_source):
		push_error("PlatformUtils: Source file does not exist: '%s'" % normalized_source)
		return ErrorCode.FILE_NOT_FOUND
	
	# Ensure destination directory exists
	var dest_dir: String = normalized_dest.get_base_dir()
	if not dest_dir.is_empty():
		var create_result: ErrorCode = create_directory_recursive(dest_dir)
		if create_result != ErrorCode.SUCCESS:
			return create_result
	
	# Use DirAccess for file operations
	var dir_access: DirAccess = DirAccess.open("res://")
	if dir_access == null:
		push_error("PlatformUtils: Failed to open directory access")
		return ErrorCode.GENERIC_ERROR
	
	var result: Error = dir_access.rename(normalized_source, normalized_dest)
	if result != OK:
		push_error("PlatformUtils: Failed to move file from '%s' to '%s' - Error: %d" % [normalized_source, normalized_dest, result])
		return _convert_godot_error_to_platform_error(result)
	
	return ErrorCode.SUCCESS

## Delete file with proper error handling
static func delete_file(file_path: String) -> ErrorCode:
	if file_path.is_empty():
		push_error("PlatformUtils: Empty file path provided")
		return ErrorCode.INVALID_PATH
	
	var normalized_path: String = normalize_path(file_path)
	
	if not file_exists(normalized_path):
		return ErrorCode.FILE_NOT_FOUND
	
	var dir_access: DirAccess = DirAccess.open("res://")
	if dir_access == null:
		push_error("PlatformUtils: Failed to open directory access")
		return ErrorCode.GENERIC_ERROR
	
	var result: Error = dir_access.remove(normalized_path)
	if result != OK:
		push_error("PlatformUtils: Failed to delete file '%s' - Error: %d" % [normalized_path, result])
		return _convert_godot_error_to_platform_error(result)
	
	return ErrorCode.SUCCESS

## Normalize file path for cross-platform compatibility
static func normalize_path(path: String) -> String:
	if path.is_empty():
		return ""
	
	# Replace Windows backslashes with forward slashes
	var normalized: String = path.replace("\\", "/")
	
	# Remove duplicate slashes
	while normalized.contains("//"):
		normalized = normalized.replace("//", "/")
	
	# Handle relative paths
	if normalized.begins_with("./"):
		normalized = normalized.substr(2)
	
	return normalized

## Get list of files in directory with optional filtering
static func get_directory_files(dir_path: String, file_extension: String = "") -> PackedStringArray:
	var normalized_path: String = normalize_path(dir_path)
	
	if not directory_exists(normalized_path):
		push_error("PlatformUtils: Directory does not exist: '%s'" % normalized_path)
		return PackedStringArray()
	
	var dir_access: DirAccess = DirAccess.open(normalized_path)
	if dir_access == null:
		push_error("PlatformUtils: Failed to open directory: '%s'" % normalized_path)
		return PackedStringArray()
	
	var files: PackedStringArray = dir_access.get_files()
	
	# Filter by extension if specified
	if not file_extension.is_empty():
		var filtered_files: PackedStringArray = PackedStringArray()
		var extension_with_dot: String = file_extension if file_extension.begins_with(".") else "." + file_extension
		
		for file_name: String in files:
			if file_name.get_extension() == extension_with_dot.substr(1):
				filtered_files.append(file_name)
		
		return filtered_files
	
	return files

## Get list of subdirectories in directory
static func get_directory_subdirs(dir_path: String) -> PackedStringArray:
	var normalized_path: String = normalize_path(dir_path)
	
	if not directory_exists(normalized_path):
		push_error("PlatformUtils: Directory does not exist: '%s'" % normalized_path)
		return PackedStringArray()
	
	var dir_access: DirAccess = DirAccess.open(normalized_path)
	if dir_access == null:
		push_error("PlatformUtils: Failed to open directory: '%s'" % normalized_path)
		return PackedStringArray()
	
	return dir_access.get_directories()

## Get platform information
static func get_platform_info() -> Dictionary:
	if not _is_initialized:
		initialize()
	return _platform_info.duplicate()

## Get OS name (Windows, Linux, macOS, etc.)
static func get_os_name() -> String:
	if not _is_initialized:
		initialize()
	return _platform_info.get("os_name", "Unknown")

## Get processor information
static func get_processor_info() -> Dictionary:
	if not _is_initialized:
		initialize()
	return {
		"name": _platform_info.get("processor_name", "Unknown"),
		"count": _platform_info.get("processor_count", 1)
	}

## Get estimated system memory in MB
static func get_system_memory_mb() -> int:
	if not _is_initialized:
		initialize()
	return _platform_info.get("memory_mb", 2048)

## Get user data directory for the application
static func get_user_data_directory() -> String:
	if not _is_initialized:
		initialize()
	return _platform_info.get("user_data_dir", "")

## Get executable path and directory
static func get_executable_info() -> Dictionary:
	if not _is_initialized:
		initialize()
	var exe_path: String = _platform_info.get("executable_path", "")
	return {
		"path": exe_path,
		"directory": exe_path.get_base_dir(),
		"filename": exe_path.get_file()
	}

## Get command line arguments
static func get_command_line_args() -> PackedStringArray:
	if not _is_initialized:
		initialize()
	return _platform_info.get("cmdline_args", PackedStringArray())

## Check if running on PC platform
static func is_pc_platform() -> bool:
	if not _is_initialized:
		initialize()
	return _platform_info.get("has_feature_pc", false)

## Check if running on mobile platform
static func is_mobile_platform() -> bool:
	if not _is_initialized:
		initialize()
	return _platform_info.get("has_feature_mobile", false)

## Check if running on web platform
static func is_web_platform() -> bool:
	if not _is_initialized:
		initialize()
	return _platform_info.get("has_feature_web", false)

## Sleep for specified milliseconds (non-blocking)
static func sleep_ms(milliseconds: int) -> void:
	if milliseconds <= 0:
		return
	
	await Engine.get_main_loop().create_timer(milliseconds / 1000.0).timeout

## Get current working directory
static func get_current_directory() -> String:
	return OS.get_user_data_dir()

## Set current working directory (limited in Godot)
static func set_current_directory(dir_path: String) -> ErrorCode:
	# Godot doesn't support changing working directory
	# This is a compatibility function for WCS code
	push_warning("PlatformUtils: set_current_directory() not supported in Godot - ignored")
	return ErrorCode.SUCCESS

## Validate that a path is safe for file operations
static func validate_file_path(file_path: String) -> bool:
	if file_path.is_empty():
		return false
	
	# Check for invalid characters
	var invalid_chars: PackedStringArray = ["<", ">", ":", "\"", "|", "?", "*"]
	for invalid_char: String in invalid_chars:
		if file_path.contains(invalid_char):
			return false
	
	# Check for reserved names on Windows
	var reserved_names: PackedStringArray = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
	var filename: String = file_path.get_file().get_basename().to_upper()
	if reserved_names.has(filename):
		return false
	
	return true

## Convert Godot error codes to platform error codes
static func _convert_godot_error_to_platform_error(godot_error: Error) -> ErrorCode:
	match godot_error:
		OK:
			return ErrorCode.SUCCESS
		ERR_FILE_NOT_FOUND:
			return ErrorCode.FILE_NOT_FOUND
		ERR_FILE_NO_PERMISSION:
			return ErrorCode.ACCESS_DENIED
		ERR_FILE_CANT_OPEN, ERR_FILE_CANT_WRITE, ERR_FILE_CANT_READ:
			return ErrorCode.ACCESS_DENIED
		ERR_INVALID_PARAMETER:
			return ErrorCode.INVALID_PATH
		ERR_OUT_OF_MEMORY:
			return ErrorCode.DISK_FULL
		_:
			return ErrorCode.GENERIC_ERROR
