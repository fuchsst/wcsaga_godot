class_name FileUtils
extends RefCounted

## Utility functions for WCS-specific file operations and convenience methods.
## Provides high-level functionality built on top of FileManager for common file tasks.

# File list filter function type for directory scanning
signal file_filter_requested(filename: String, should_include: bool)

## Add extension to filename if it doesn't already have one
static func add_extension(filename: String, extension: String) -> String:
	if filename.is_empty() or extension.is_empty():
		return filename
	
	# Ensure extension starts with a dot
	var ext: String = extension
	if not ext.starts_with("."):
		ext = "." + ext
	
	# Check if filename already has this extension
	if filename.to_lower().ends_with(ext.to_lower()):
		return filename
	
	return filename + ext

## Remove extension from filename
static func remove_extension(filename: String) -> String:
	if filename.is_empty():
		return filename
	
	var last_dot: int = filename.rfind(".")
	if last_dot == -1:
		return filename
	
	return filename.substr(0, last_dot)

## Get file extension (without the dot)
static func get_extension(filename: String) -> String:
	if filename.is_empty():
		return ""
	
	var last_dot: int = filename.rfind(".")
	if last_dot == -1 or last_dot == filename.length() - 1:
		return ""
	
	return filename.substr(last_dot + 1).to_lower()

## Check if filename has any of the given extensions
static func has_extension(filename: String, extensions: PackedStringArray) -> bool:
	var file_ext: String = get_extension(filename)
	if file_ext.is_empty():
		return false
	
	for ext in extensions:
		var clean_ext: String = ext
		if clean_ext.starts_with("."):
			clean_ext = clean_ext.substr(1)
		
		if file_ext.to_lower() == clean_ext.to_lower():
			return true
	
	return false

## Get files in directory with optional filtering
static func get_file_list(directory_path: String, filter_extensions: PackedStringArray = PackedStringArray(), recursive: bool = false) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	
	if directory_path.is_empty():
		push_error("FileUtils: Directory path cannot be empty")
		return files
	
	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null:
		push_warning("FileUtils: Cannot open directory: " + directory_path)
		return files
	
	_scan_directory_recursive(dir, "", filter_extensions, recursive, files)
	return files

## Check if file is newer than another file (by modification time)
static func is_file_newer(file1_path: String, file2_path: String) -> bool:
	var file1_time: int = get_file_modification_time(file1_path)
	var file2_time: int = get_file_modification_time(file2_path)
	
	if file1_time == -1 or file2_time == -1:
		return false
	
	return file1_time > file2_time

## Get file modification time as unix timestamp
static func get_file_modification_time(file_path: String) -> int:
	if not FileAccess.file_exists(file_path):
		return -1
	
	return FileAccess.get_modified_time(file_path)

## Copy file from source to destination
static func copy_file(source_path: String, dest_path: String) -> bool:
	if source_path.is_empty() or dest_path.is_empty():
		push_error("FileUtils: Source and destination paths cannot be empty")
		return false
	
	if not FileAccess.file_exists(source_path):
		push_error("FileUtils: Source file does not exist: " + source_path)
		return false
	
	# Ensure destination directory exists
	var dest_dir: String = dest_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dest_dir):
		var dir_access: DirAccess = DirAccess.open("/")
		if dir_access == null:
			push_error("FileUtils: Failed to create directory access")
			return false
		
		var error: Error = dir_access.make_dir_recursive_absolute(dest_dir)
		if error != OK:
			push_error("FileUtils: Failed to create destination directory: " + error_string(error))
			return false
	
	# Copy the file
	var error: Error = DirAccess.copy_absolute(source_path, dest_path)
	if error != OK:
		push_error("FileUtils: Failed to copy file '%s' to '%s': %s" % [source_path, dest_path, error_string(error)])
		return false
	
	return true

## Move/rename file from source to destination
static func move_file(source_path: String, dest_path: String) -> bool:
	if source_path.is_empty() or dest_path.is_empty():
		push_error("FileUtils: Source and destination paths cannot be empty")
		return false
	
	if not FileAccess.file_exists(source_path):
		push_error("FileUtils: Source file does not exist: " + source_path)
		return false
	
	# Ensure destination directory exists
	var dest_dir: String = dest_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dest_dir):
		var dir_access: DirAccess = DirAccess.open("/")
		if dir_access == null:
			push_error("FileUtils: Failed to create directory access")
			return false
		
		var error: Error = dir_access.make_dir_recursive_absolute(dest_dir)
		if error != OK:
			push_error("FileUtils: Failed to create destination directory: " + error_string(error))
			return false
	
	# Move the file
	var error: Error = DirAccess.rename_absolute(source_path, dest_path)
	if error != OK:
		push_error("FileUtils: Failed to move file '%s' to '%s': %s" % [source_path, dest_path, error_string(error)])
		return false
	
	return true

## Create directory (and parent directories if needed)
static func create_directory(directory_path: String) -> bool:
	if directory_path.is_empty():
		push_error("FileUtils: Directory path cannot be empty")
		return false
	
	if DirAccess.dir_exists_absolute(directory_path):
		return true
	
	var dir_access: DirAccess = DirAccess.open("/")
	if dir_access == null:
		push_error("FileUtils: Failed to create directory access")
		return false
	
	var error: Error = dir_access.make_dir_recursive_absolute(directory_path)
	if error != OK:
		push_error("FileUtils: Failed to create directory '%s': %s" % [directory_path, error_string(error)])
		return false
	
	return true

## Remove directory and all its contents
static func remove_directory_recursive(directory_path: String) -> bool:
	if directory_path.is_empty():
		push_error("FileUtils: Directory path cannot be empty")
		return false
	
	if not DirAccess.dir_exists_absolute(directory_path):
		return true  # Already doesn't exist
	
	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null:
		push_error("FileUtils: Cannot open directory for removal: " + directory_path)
		return false
	
	# Remove all files and subdirectories
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory_path.path_join(file_name)
		
		if dir.current_is_dir():
			if not remove_directory_recursive(full_path):
				return false
		else:
			var error: Error = DirAccess.remove_absolute(full_path)
			if error != OK:
				push_error("FileUtils: Failed to remove file '%s': %s" % [full_path, error_string(error)])
				return false
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Remove the directory itself
	var error: Error = DirAccess.remove_absolute(directory_path)
	if error != OK:
		push_error("FileUtils: Failed to remove directory '%s': %s" % [directory_path, error_string(error)])
		return false
	
	return true

## Calculate checksum of file (CRC32)
static func calculate_file_checksum(file_path: String) -> int:
	if not FileAccess.file_exists(file_path):
		push_error("FileUtils: File does not exist for checksum: " + file_path)
		return -1
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("FileUtils: Failed to open file for checksum: " + file_path)
		return -1
	
	var buffer: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	if buffer.is_empty():
		return 0
	
	# Simple CRC32 calculation
	var crc: int = 0xFFFFFFFF
	for byte in buffer:
		crc = crc ^ byte
		for i in range(8):
			if (crc & 1) != 0:
				crc = (crc >> 1) ^ 0xEDB88320
			else:
				crc = crc >> 1
	
	return crc ^ 0xFFFFFFFF

## Find files matching a pattern (with wildcard support)
static func find_files_matching(directory_path: String, pattern: String, recursive: bool = false) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	
	if directory_path.is_empty() or pattern.is_empty():
		return files
	
	var regex: RegEx = RegEx.new()
	# Convert wildcard pattern to regex
	var regex_pattern: String = pattern.replace("*", ".*").replace("?", ".")
	regex_pattern = "^" + regex_pattern + "$"
	
	var error: Error = regex.compile(regex_pattern)
	if error != OK:
		push_error("FileUtils: Invalid pattern for file search: " + pattern)
		return files
	
	var all_files: PackedStringArray = get_file_list(directory_path, PackedStringArray(), recursive)
	
	for file in all_files:
		var filename: String = file.get_file()
		if regex.search(filename):
			files.append(file)
	
	return files

## Read structured data from WCS-style configuration files
static func read_config_file(file_path: String) -> Dictionary:
	var config: Dictionary = {}
	
	var file_manager: FileManager = FileManager.get_instance()
	var content: String = file_manager.read_file_text(file_path.get_file(), FileManager.PathType.CONFIG)
	
	if content.is_empty():
		push_warning("FileUtils: Config file is empty or not found: " + file_path)
		return config
	
	var lines: PackedStringArray = content.split("\n")
	var current_section: String = ""
	
	for line in lines:
		line = line.strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.starts_with(";") or line.starts_with("#"):
			continue
		
		# Section header
		if line.starts_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2)
			if not config.has(current_section):
				config[current_section] = {}
			continue
		
		# Key-value pair
		var equals_pos: int = line.find("=")
		if equals_pos > 0:
			var key: String = line.substr(0, equals_pos).strip_edges()
			var value: String = line.substr(equals_pos + 1).strip_edges()
			
			# Remove quotes if present
			if value.starts_with("\"") and value.ends_with("\""):
				value = value.substr(1, value.length() - 2)
			
			if current_section.is_empty():
				config[key] = value
			else:
				if not config.has(current_section):
					config[current_section] = {}
				config[current_section][key] = value
	
	return config

## Write structured data to WCS-style configuration files
static func write_config_file(file_path: String, config: Dictionary) -> bool:
	var content: String = ""
	
	# Write top-level keys first (no section)
	for key in config.keys():
		var value = config[key]
		if typeof(value) != TYPE_DICTIONARY:
			content += "%s=%s\n" % [key, str(value)]
	
	# Write sections
	for section_name in config.keys():
		var section_data = config[section_name]
		if typeof(section_data) == TYPE_DICTIONARY:
			content += "\n[%s]\n" % section_name
			for key in section_data.keys():
				var value = section_data[key]
				# Quote string values
				if typeof(value) == TYPE_STRING and (value.find(" ") != -1 or value.find("=") != -1):
					value = "\"%s\"" % value
				content += "%s=%s\n" % [key, str(value)]
	
	var file_manager: FileManager = FileManager.get_instance()
	return file_manager.write_file_text(file_path.get_file(), content, FileManager.PathType.CONFIG)

## Extract files from VP archive to filesystem (utility for debugging/conversion)
static func extract_vp_archive(vp_file_path: String, output_directory: String) -> bool:
	var vp_manager: VPArchiveManager = VPArchiveManager.get_instance()
	var archive: VPArchive = vp_manager.get_archive(vp_file_path)
	
	if archive == null:
		push_error("FileUtils: Failed to open VP archive: " + vp_file_path)
		return false
	
	if not create_directory(output_directory):
		return false
	
	var file_list: PackedStringArray = archive.get_file_list()
	var extracted_count: int = 0
	
	for file_path in file_list:
		var output_file_path: String = output_directory.path_join(file_path)
		
		# Create directory structure
		var file_dir: String = output_file_path.get_base_dir()
		if not create_directory(file_dir):
			continue
		
		# Extract file data
		var file_data: PackedByteArray = archive.read_file(file_path)
		if file_data.is_empty():
			push_warning("FileUtils: Failed to extract file from VP: " + file_path)
			continue
		
		# Write to filesystem
		var output_file: FileAccess = FileAccess.open(output_file_path, FileAccess.WRITE)
		if output_file == null:
			push_warning("FileUtils: Failed to create output file: " + output_file_path)
			continue
		
		output_file.store_buffer(file_data)
		output_file.close()
		extracted_count += 1
	
	print("FileUtils: Extracted %d files from VP archive '%s' to '%s'" % [extracted_count, vp_file_path, output_directory])
	return extracted_count > 0

## PRIVATE METHODS

static func _scan_directory_recursive(dir: DirAccess, relative_path: String, filter_extensions: PackedStringArray, recursive: bool, files: PackedStringArray) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_relative_path: String = relative_path
			if not full_relative_path.is_empty():
				full_relative_path = full_relative_path.path_join(file_name)
			else:
				full_relative_path = file_name
			
			if dir.current_is_dir():
				if recursive:
					var subdir: DirAccess = DirAccess.open(dir.get_current_dir().path_join(file_name))
					if subdir != null:
						_scan_directory_recursive(subdir, full_relative_path, filter_extensions, recursive, files)
			else:
				# Check if file matches filter
				if filter_extensions.is_empty() or has_extension(file_name, filter_extensions):
					files.append(full_relative_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()