class_name VPArchive
extends RefCounted

## WCS VP (Volition Pack) archive reader for loading game assets.
## Handles the FreeSpace 2 / WCS VP file format with proper endianness conversion
## and directory structure management.

signal file_extracted(filename: String, size: int)
signal extraction_error(filename: String, error: String)

# VP file format constants
const VP_MAGIC: String = "VPVP"
const VP_HEADER_SIZE: int = 16
const VP_FILE_ENTRY_SIZE: int = 44
const VP_FILENAME_SIZE: int = 32

# Header structure
class VPHeader:
	var magic: String = ""
	var version: int = 0
	var index_offset: int = 0
	var num_files: int = 0
	
	func is_valid() -> bool:
		return magic == VP_MAGIC and version > 0 and num_files > 0

# File entry structure  
class VPFileEntry:
	var offset: int = 0
	var size: int = 0
	var filename: String = ""
	var write_time: int = 0
	var is_directory: bool = false
	
	func get_normalized_path() -> String:
		return filename.replace("\\", "/").to_lower()

# Archive state
var archive_path: String = ""
var header: VPHeader
var file_entries: Array[VPFileEntry] = []
var file_lookup: Dictionary = {}  # filename -> VPFileEntry
var directory_tree: Dictionary = {}  # path -> Array[String]
var is_loaded: bool = false
var file_handle: FileAccess

func _init(vp_file_path: String = "") -> void:
	if not vp_file_path.is_empty():
		load_archive(vp_file_path)

## Public API

func load_archive(vp_file_path: String) -> bool:
	"""Load and parse a VP archive file."""
	
	if not FileAccess.file_exists(vp_file_path):
		push_error("VPArchive: File does not exist: %s" % vp_file_path)
		return false
	
	archive_path = vp_file_path
	file_handle = FileAccess.open(vp_file_path, FileAccess.READ)
	
	if file_handle == null:
		push_error("VPArchive: Failed to open file: %s" % vp_file_path)
		return false
	
	# Read and validate header
	if not _read_header():
		file_handle.close()
		return false
	
	# Read file entries
	if not _read_file_entries():
		file_handle.close()
		return false
	
	# Build lookup tables
	_build_lookup_tables()
	
	is_loaded = true
	print("VPArchive: Successfully loaded %s with %d files" % [vp_file_path, header.num_files])
	return true

func close_archive() -> void:
	"""Close the archive and clean up resources."""
	
	if file_handle != null:
		file_handle.close()
		file_handle = null
	
	file_entries.clear()
	file_lookup.clear()
	directory_tree.clear()
	is_loaded = false

func has_file(filename: String) -> bool:
	"""Check if the archive contains a specific file."""
	
	var normalized: String = filename.replace("\\", "/").to_lower()
	return file_lookup.has(normalized)

func get_file_size(filename: String) -> int:
	"""Get the size of a file in the archive."""
	
	var normalized: String = filename.replace("\\", "/").to_lower()
	var entry: VPFileEntry = file_lookup.get(normalized)
	
	if entry != null:
		return entry.size
	
	return -1

func extract_file(filename: String) -> PackedByteArray:
	"""Extract a file from the archive and return its data."""
	
	if not is_loaded:
		push_error("VPArchive: Archive not loaded")
		return PackedByteArray()
	
	var normalized: String = filename.replace("\\", "/").to_lower()
	var entry: VPFileEntry = file_lookup.get(normalized)
	
	if entry == null:
		push_error("VPArchive: File not found: %s" % filename)
		extraction_error.emit(filename, "File not found")
		return PackedByteArray()
	
	if entry.is_directory:
		push_error("VPArchive: Cannot extract directory: %s" % filename)
		extraction_error.emit(filename, "Is a directory")
		return PackedByteArray()
	
	if entry.size == 0:
		# Empty file
		file_extracted.emit(filename, 0)
		return PackedByteArray()
	
	# Seek to file data and read
	file_handle.seek(entry.offset)
	var data: PackedByteArray = file_handle.get_buffer(entry.size)
	
	if data.size() != entry.size:
		push_error("VPArchive: Failed to read complete file: %s (expected %d, got %d)" % 
			[filename, entry.size, data.size()])
		extraction_error.emit(filename, "Incomplete read")
		return PackedByteArray()
	
	file_extracted.emit(filename, entry.size)
	return data

func extract_file_to_path(filename: String, output_path: String) -> bool:
	"""Extract a file from the archive to a specific path."""
	
	var data: PackedByteArray = extract_file(filename)
	
	if data.is_empty() and get_file_size(filename) > 0:
		return false
	
	# Ensure output directory exists
	var output_dir: String = output_path.get_base_dir()
	if not output_dir.is_empty():
		DirAccess.open("res://").make_dir_recursive(output_dir)
	
	var output_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if output_file == null:
		push_error("VPArchive: Failed to create output file: %s" % output_path)
		return false
	
	output_file.store_buffer(data)
	output_file.close()
	
	return true

func get_file_list() -> Array[String]:
	"""Get a list of all files in the archive."""
	
	var files: Array[String] = []
	
	for entry in file_entries:
		if not entry.is_directory:
			files.append(entry.filename)
	
	return files

func get_directory_listing(directory: String = "") -> Array[String]:
	"""Get files and subdirectories in a specific directory."""
	
	var normalized_dir: String = directory.replace("\\", "/").to_lower()
	if not normalized_dir.is_empty() and not normalized_dir.ends_with("/"):
		normalized_dir += "/"
	
	return directory_tree.get(normalized_dir, [])

func get_archive_info() -> Dictionary:
	"""Get information about the loaded archive."""
	
	return {
		"path": archive_path,
		"version": header.version if header != null else 0,
		"num_files": header.num_files if header != null else 0,
		"total_files": file_entries.size(),
		"directories": directory_tree.size(),
		"is_loaded": is_loaded
	}

## Private implementation

func _read_header() -> bool:
	"""Read and parse the VP file header."""
	
	if file_handle.get_length() < VP_HEADER_SIZE:
		push_error("VPArchive: File too small to be a valid VP archive")
		return false
	
	header = VPHeader.new()
	
	# Read magic number
	header.magic = file_handle.get_buffer(4).get_string_from_ascii()
	
	if header.magic != VP_MAGIC:
		push_error("VPArchive: Invalid VP magic number: %s" % header.magic)
		return false
	
	# Read header fields (little-endian)
	header.version = _read_int32_le()
	header.index_offset = _read_int32_le()
	header.num_files = _read_int32_le()
	
	if not header.is_valid():
		push_error("VPArchive: Invalid VP header - version: %d, offset: %d, files: %d" % 
			[header.version, header.index_offset, header.num_files])
		return false
	
	if header.index_offset >= file_handle.get_length():
		push_error("VPArchive: Invalid index offset: %d (file size: %d)" % 
			[header.index_offset, file_handle.get_length()])
		return false
	
	return true

func _read_file_entries() -> bool:
	"""Read the file entry table from the archive."""
	
	# Seek to index table
	file_handle.seek(header.index_offset)
	
	var expected_size: int = header.num_files * VP_FILE_ENTRY_SIZE
	var remaining_size: int = file_handle.get_length() - header.index_offset
	
	if remaining_size < expected_size:
		push_error("VPArchive: Insufficient data for file entries (need %d, have %d)" % 
			[expected_size, remaining_size])
		return false
	
	file_entries.clear()
	
	for i in range(header.num_files):
		var entry: VPFileEntry = VPFileEntry.new()
		
		# Read entry fields (little-endian)
		entry.offset = _read_int32_le()
		entry.size = _read_int32_le()
		
		# Read filename (32 bytes, null-terminated)
		var filename_buffer: PackedByteArray = file_handle.get_buffer(VP_FILENAME_SIZE)
		var null_pos: int = filename_buffer.find(0)
		if null_pos >= 0:
			entry.filename = filename_buffer.slice(0, null_pos).get_string_from_ascii()
		else:
			entry.filename = filename_buffer.get_string_from_ascii()
		
		entry.write_time = _read_int32_le()
		
		# Determine if this is a directory entry
		entry.is_directory = (entry.size == 0 and not entry.filename.is_empty() and 
							 entry.filename != "..")
		
		file_entries.append(entry)
	
	return true

func _build_lookup_tables() -> void:
	"""Build filename lookup table and directory tree."""
	
	file_lookup.clear()
	directory_tree.clear()
	
	var current_path: String = ""
	var path_stack: Array[String] = []
	
	for entry in file_entries:
		var normalized_filename: String = entry.get_normalized_path()
		
		if entry.filename == "..":
			# Go up one directory
			if not path_stack.is_empty():
				path_stack.pop_back()
				current_path = "/".join(path_stack)
				if not current_path.is_empty():
					current_path += "/"
		elif entry.is_directory:
			# Enter subdirectory
			path_stack.append(entry.filename.to_lower())
			current_path = "/".join(path_stack) + "/"
			
			# Add directory to tree
			if not directory_tree.has(current_path):
				directory_tree[current_path] = []
		else:
			# Regular file
			var full_path: String = current_path + normalized_filename
			file_lookup[full_path] = entry
			
			# Add to directory listing
			if not directory_tree.has(current_path):
				directory_tree[current_path] = []
			
			directory_tree[current_path].append(entry.filename)

func _read_int32_le() -> int:
	"""Read a 32-bit little-endian integer."""
	
	var bytes: PackedByteArray = file_handle.get_buffer(4)
	
	if bytes.size() != 4:
		push_error("VPArchive: Failed to read 4 bytes for int32")
		return 0
	
	# Convert little-endian to int32
	return (bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24))

## Cleanup

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		close_archive()