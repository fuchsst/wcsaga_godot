class_name VPArchive
extends RefCounted

## VP Archive reading infrastructure for WCS-Godot conversion.
## Provides low-level access to VP archive files for raw data extraction.
## FOUNDATION SCOPE: Raw binary data access only - conversion handled by EPIC-003.

const WCSConstants = preload("res://scripts/core/foundation/wcs_constants.gd")
const DebugManager = preload("res://scripts/core/platform/debug_manager.gd")
const ErrorHandler = preload("res://scripts/core/platform/error_handler.gd")
const PlatformUtils = preload("res://scripts/core/platform/platform_utils.gd")

## VP file format constants based on WCS source analysis
const VP_SIGNATURE: String = "VPVP"
const VP_HEADER_SIZE: int = 16
const VP_FILE_ENTRY_SIZE: int = 44  # 4+4+32+4 bytes
const MAX_FILENAME_LENGTH: int = 32

## VP file header structure (16 bytes total)
class VPHeader:
	var signature: String = ""           # 4 bytes: "VPVP"
	var version: int = 0                 # 4 bytes: archive version
	var index_offset: int = 0            # 4 bytes: offset to file index
	var num_files: int = 0               # 4 bytes: number of files in archive

## VP file entry structure (44 bytes total)
class VPFileEntry:
	var offset: int = 0                  # 4 bytes: file data offset in archive
	var size: int = 0                    # 4 bytes: uncompressed file size
	var filename: String = ""            # 32 bytes: null-terminated filename
	var write_time: int = 0              # 4 bytes: file modification timestamp
	
	## Directory flag: size=0 indicates directory entry
	func is_directory() -> bool:
		return size == 0

## Archive file information
var archive_path: String = ""
var header: VPHeader
var file_entries: Array[VPFileEntry] = []
var file_lookup: Dictionary = {}         # filename -> VPFileEntry
var is_loaded: bool = false
var archive_file: FileAccess = null

## Load VP archive from file path
static func load_archive(vp_path: String) -> VPArchive:
	var archive: VPArchive = VPArchive.new()
	var success: bool = archive._load_from_path(vp_path)
	
	if not success:
		ErrorHandler.file_io_error("Failed to load VP archive", vp_path)
		return null
	
	return archive

## Initialize archive from file path
func _load_from_path(vp_path: String) -> bool:
	if not PlatformUtils.file_exists(vp_path):
		DebugManager.log_error(DebugManager.Category.FILE_IO, "VP archive not found: %s" % vp_path)
		return false
	
	archive_path = vp_path
	archive_file = FileAccess.open(vp_path, FileAccess.READ)
	
	if archive_file == null:
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Failed to open VP archive: %s" % vp_path)
		return false
	
	# Parse header
	if not _parse_header():
		archive_file.close()
		archive_file = null
		return false
	
	# Parse file index
	if not _parse_file_index():
		archive_file.close()
		archive_file = null
		return false
	
	is_loaded = true
	DebugManager.log_info(DebugManager.Category.FILE_IO, "Loaded VP archive: %s (%d files)" % [vp_path, header.num_files])
	return true

## Parse VP archive header
func _parse_header() -> bool:
	if archive_file.get_length() < VP_HEADER_SIZE:
		DebugManager.log_error(DebugManager.Category.FILE_IO, "VP archive too small for header: %s" % archive_path)
		return false
	
	archive_file.seek(0)
	
	# Read header data
	var signature_bytes: PackedByteArray = archive_file.get_buffer(4)
	header.signature = signature_bytes.get_string_from_ascii()
	header.version = archive_file.get_32()
	header.index_offset = archive_file.get_32()
	header.num_files = archive_file.get_32()
	
	# Validate header
	if header.signature != VP_SIGNATURE:
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Invalid VP signature: %s (expected %s)" % [header.signature, VP_SIGNATURE])
		return false
	
	if header.index_offset >= archive_file.get_length():
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Invalid index offset: %d" % header.index_offset)
		return false
	
	if header.num_files < 0 or header.num_files > 100000:  # Sanity check
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Invalid file count: %d" % header.num_files)
		return false
	
	DebugManager.log_debug(DebugManager.Category.FILE_IO, "VP Header: version=%d, index_offset=%d, num_files=%d" % [header.version, header.index_offset, header.num_files])
	return true

## Parse file index from VP archive
func _parse_file_index() -> bool:
	archive_file.seek(header.index_offset)
	
	file_entries.clear()
	file_lookup.clear()
	
	var current_path: String = ""  # Track directory structure
	
	for i: int in range(header.num_files):
		var entry: VPFileEntry = VPFileEntry.new()
		
		# Read file entry data
		entry.offset = archive_file.get_32()
		entry.size = archive_file.get_32()
		
		# Read filename (32 bytes, null-terminated)
		var filename_bytes: PackedByteArray = archive_file.get_buffer(MAX_FILENAME_LENGTH)
		entry.filename = _extract_null_terminated_string(filename_bytes)
		
		entry.write_time = archive_file.get_32()
		
		# Handle directory structure
		if entry.is_directory():
			if entry.filename == "..":
				# Go up one directory level
				var last_separator: int = current_path.rfind("/")
				if last_separator > 0:
					current_path = current_path.substr(0, last_separator)
				else:
					current_path = ""
			else:
				# Enter directory
				if current_path.is_empty():
					current_path = entry.filename
				else:
					current_path = current_path + "/" + entry.filename
			
			DebugManager.log_trace(DebugManager.Category.FILE_IO, "VP Directory: %s" % current_path)
		else:
			# Regular file - add to lookup with full path
			var full_path: String
			if current_path.is_empty():
				full_path = entry.filename
			else:
				full_path = current_path + "/" + entry.filename
			
			file_lookup[full_path.to_lower()] = entry
			DebugManager.log_trace(DebugManager.Category.FILE_IO, "VP File: %s (size=%d, offset=%d)" % [full_path, entry.size, entry.offset])
		
		file_entries.append(entry)
	
	DebugManager.log_info(DebugManager.Category.FILE_IO, "VP index parsed: %d entries, %d files" % [file_entries.size(), file_lookup.size()])
	return true

## Extract null-terminated string from byte array
func _extract_null_terminated_string(bytes: PackedByteArray) -> String:
	var end_index: int = 0
	for i: int in range(bytes.size()):
		if bytes[i] == 0:
			end_index = i
			break
		end_index = i + 1
	
	if end_index == 0:
		return ""
	
	var string_bytes: PackedByteArray = bytes.slice(0, end_index)
	return string_bytes.get_string_from_ascii()

## Check if file exists in archive
func has_file(file_path: String) -> bool:
	if not is_loaded:
		return false
	
	var normalized_path: String = file_path.replace("\\", "/").to_lower()
	return file_lookup.has(normalized_path)

## Get file entry by path
func get_file_entry(file_path: String) -> VPFileEntry:
	if not is_loaded:
		return null
	
	var normalized_path: String = file_path.replace("\\", "/").to_lower()
	return file_lookup.get(normalized_path, null)

## Get file data as bytes
func get_file_data(file_path: String) -> PackedByteArray:
	var entry: VPFileEntry = get_file_entry(file_path)
	if entry == null:
		DebugManager.log_warning(DebugManager.Category.FILE_IO, "File not found in VP archive: %s" % file_path)
		return PackedByteArray()
	
	if entry.is_directory():
		DebugManager.log_warning(DebugManager.Category.FILE_IO, "Attempted to read directory as file: %s" % file_path)
		return PackedByteArray()
	
	if archive_file == null:
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Archive file not open: %s" % archive_path)
		return PackedByteArray()
	
	# Seek to file data and read
	archive_file.seek(entry.offset)
	var file_data: PackedByteArray = archive_file.get_buffer(entry.size)
	
	if file_data.size() != entry.size:
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Failed to read complete file data: %s (expected %d, got %d)" % [file_path, entry.size, file_data.size()])
		return PackedByteArray()
	
	DebugManager.log_trace(DebugManager.Category.FILE_IO, "Read file from VP: %s (%d bytes)" % [file_path, file_data.size()])
	return file_data

## Get file data as string (for text files)
func get_file_text(file_path: String) -> String:
	var file_data: PackedByteArray = get_file_data(file_path)
	if file_data.is_empty():
		return ""
	
	return file_data.get_string_from_utf8()

## Get list of all files in archive
func get_file_list() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	
	for file_path: String in file_lookup.keys():
		files.append(file_path)
	
	return files

## Get files matching pattern (simple wildcard support)
func find_files(pattern: String) -> PackedStringArray:
	var matching_files: PackedStringArray = PackedStringArray()
	var regex_pattern: String = pattern.replace("*", ".*").replace("?", ".")
	var regex: RegEx = RegEx.new()
	
	if regex.compile(regex_pattern) != OK:
		DebugManager.log_warning(DebugManager.Category.FILE_IO, "Invalid pattern for file search: %s" % pattern)
		return matching_files
	
	for file_path: String in file_lookup.keys():
		if regex.search(file_path) != null:
			matching_files.append(file_path)
	
	return matching_files

## Get archive statistics
func get_archive_info() -> Dictionary:
	if not is_loaded:
		return {}
	
	var total_size: int = 0
	var file_count: int = 0
	var dir_count: int = 0
	
	for entry: VPFileEntry in file_entries:
		if entry.is_directory():
			dir_count += 1
		else:
			file_count += 1
			total_size += entry.size
	
	return {
		"archive_path": archive_path,
		"version": header.version,
		"total_entries": file_entries.size(),
		"file_count": file_count,
		"directory_count": dir_count,
		"total_uncompressed_size": total_size,
		"archive_file_size": archive_file.get_length() if archive_file else 0
	}

## Validate archive integrity
func validate_archive() -> bool:
	if not is_loaded:
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Cannot validate unloaded archive")
		return false
	
	var errors: int = 0
	
	# Check header consistency
	if header.num_files != file_entries.size():
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Header file count mismatch: %d vs %d" % [header.num_files, file_entries.size()])
		errors += 1
	
	# Validate file entries
	for entry: VPFileEntry in file_entries:
		if not entry.is_directory():
			# Check file bounds
			if entry.offset < VP_HEADER_SIZE:
				DebugManager.log_error(DebugManager.Category.FILE_IO, "Invalid file offset: %s at %d" % [entry.filename, entry.offset])
				errors += 1
			
			if entry.offset + entry.size > archive_file.get_length():
				DebugManager.log_error(DebugManager.Category.FILE_IO, "File extends beyond archive: %s" % entry.filename)
				errors += 1
	
	if errors == 0:
		DebugManager.log_info(DebugManager.Category.FILE_IO, "VP archive validation passed: %s" % archive_path)
	else:
		DebugManager.log_error(DebugManager.Category.FILE_IO, "VP archive validation failed: %d errors" % errors)
	
	return errors == 0

## Close archive and free resources
func close_archive() -> void:
	if archive_file != null:
		archive_file.close()
		archive_file = null
	
	file_entries.clear()
	file_lookup.clear()
	is_loaded = false
	
	DebugManager.log_debug(DebugManager.Category.FILE_IO, "Closed VP archive: %s" % archive_path)

## Destructor
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		close_archive()
