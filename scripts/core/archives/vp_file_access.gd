class_name VPFileAccess
extends RefCounted

## FileAccess-compatible wrapper for files embedded in VP archives.
## Provides transparent access to VP archive files using Godot's FileAccess interface.
## FOUNDATION SCOPE: Raw file access only - conversion handled by EPIC-003.

const DebugManager = preload("res://scripts/core/platform/debug_manager.gd")
const ErrorHandler = preload("res://scripts/core/platform/error_handler.gd")

## Error constants matching Godot FileAccess behavior
enum VPError {
	OK = 0,
	ERR_FILE_NOT_FOUND = 7,
	ERR_FILE_BAD_DRIVE = 8,
	ERR_FILE_BAD_PATH = 9,
	ERR_FILE_NO_PERMISSION = 10,
	ERR_FILE_ALREADY_IN_USE = 11,
	ERR_FILE_CANT_OPEN = 12,
	ERR_FILE_CANT_WRITE = 13,
	ERR_FILE_CANT_READ = 14,
	ERR_FILE_UNRECOGNIZED = 15,
	ERR_FILE_CORRUPT = 16,
	ERR_FILE_MISSING_DEPENDENCIES = 17,
	ERR_FILE_EOF = 18
}

## VP archive reference
var vp_archive: VPArchive
var file_entry: VPArchive.VPFileEntry
var file_data: PackedByteArray = PackedByteArray()
var current_position: int = 0
var is_open: bool = false
var file_path: String = ""

## Open file from VP archive
static func open(vp_archive: VPArchive, file_path: String) -> VPFileAccess:
	var vp_file: VPFileAccess = VPFileAccess.new()
	var success: bool = vp_file._open_internal(vp_archive, file_path)
	
	if not success:
		return null
	
	return vp_file

## Internal open implementation
func _open_internal(archive: VPArchive, path: String) -> bool:
	if archive == null or not archive.is_loaded:
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Invalid VP archive for file access")
		return false
	
	var entry: VPArchive.VPFileEntry = archive.get_file_entry(path)
	if entry == null:
		DebugManager.log_warning(DebugManager.Category.FILE_IO, "File not found in VP archive: %s" % path)
		return false
	
	if entry.is_directory():
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Cannot open directory as file: %s" % path)
		return false
	
	# Load file data into memory for FileAccess-like behavior
	file_data = archive.get_file_data(path)
	if file_data.is_empty():
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Failed to read file data from VP: %s" % path)
		return false
	
	vp_archive = archive
	file_entry = entry
	file_path = path
	current_position = 0
	is_open = true
	
	DebugManager.log_trace(DebugManager.Category.FILE_IO, "Opened VP file: %s (%d bytes)" % [path, file_data.size()])
	return true

## Close the file
func close() -> void:
	if is_open:
		file_data.clear()
		vp_archive = null
		file_entry = null
		current_position = 0
		is_open = false
		DebugManager.log_trace(DebugManager.Category.FILE_IO, "Closed VP file: %s" % file_path)

## Check if file is open
func is_file_open() -> bool:
	return is_open

## Get file length
func get_length() -> int:
	if not is_open:
		return 0
	return file_data.size()

## Get current position
func get_position() -> int:
	if not is_open:
		return 0
	return current_position

## Seek to position
func seek(position: int) -> void:
	if not is_open:
		return
	
	current_position = clamp(position, 0, file_data.size())

## Seek to end of file
func seek_end(position: int = 0) -> void:
	if not is_open:
		return
	
	current_position = clamp(file_data.size() + position, 0, file_data.size())

## Check if at end of file
func eof_reached() -> bool:
	if not is_open:
		return true
	
	return current_position >= file_data.size()

## Get remaining bytes until EOF
func get_var(allow_objects: bool = false) -> Variant:
	# This would need specific implementation for VP file formats
	# For now, return null as this is primarily for structured data
	DebugManager.log_warning(DebugManager.Category.FILE_IO, "get_var() not implemented for VP files")
	return null

## Read single byte
func get_8() -> int:
	if not is_open or eof_reached():
		return 0
	
	var byte_value: int = file_data[current_position]
	current_position += 1
	return byte_value

## Read 16-bit integer (little-endian)
func get_16() -> int:
	if not is_open or current_position + 2 > file_data.size():
		return 0
	
	var value: int = file_data[current_position] | (file_data[current_position + 1] << 8)
	current_position += 2
	return value

## Read 32-bit integer (little-endian)
func get_32() -> int:
	if not is_open or current_position + 4 > file_data.size():
		return 0
	
	var value: int = (file_data[current_position] | 
					 (file_data[current_position + 1] << 8) |
					 (file_data[current_position + 2] << 16) |
					 (file_data[current_position + 3] << 24))
	current_position += 4
	return value

## Read 64-bit integer (little-endian)
func get_64() -> int:
	if not is_open or current_position + 8 > file_data.size():
		return 0
	
	var low: int = get_32()
	var high: int = get_32()
	return low | (high << 32)

## Read float (IEEE 754 single precision)
func get_float() -> float:
	if not is_open or current_position + 4 > file_data.size():
		return 0.0
	
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append_array(file_data.slice(current_position, current_position + 4))
	current_position += 4
	
	return bytes.decode_float(0)

## Read double (IEEE 754 double precision)
func get_double() -> float:
	if not is_open or current_position + 8 > file_data.size():
		return 0.0
	
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append_array(file_data.slice(current_position, current_position + 8))
	current_position += 8
	
	return bytes.decode_double(0)

## Read buffer of specified length
func get_buffer(length: int) -> PackedByteArray:
	if not is_open or length <= 0:
		return PackedByteArray()
	
	var end_pos: int = min(current_position + length, file_data.size())
	var actual_length: int = end_pos - current_position
	
	if actual_length <= 0:
		return PackedByteArray()
	
	var buffer: PackedByteArray = file_data.slice(current_position, end_pos)
	current_position = end_pos
	
	return buffer

## Read line of text (until newline)
func get_line() -> String:
	if not is_open or eof_reached():
		return ""
	
	var line_bytes: PackedByteArray = PackedByteArray()
	
	while current_position < file_data.size():
		var byte_value: int = file_data[current_position]
		current_position += 1
		
		if byte_value == 10:  # '\n'
			break
		elif byte_value == 13:  # '\r'
			# Check for '\r\n' sequence
			if current_position < file_data.size() and file_data[current_position] == 10:
				current_position += 1
			break
		else:
			line_bytes.append(byte_value)
	
	return line_bytes.get_string_from_utf8()

## Read entire file as text
func get_as_text() -> String:
	if not is_open:
		return ""
	
	return file_data.get_string_from_utf8()

## Read CSV line and parse into array
func get_csv_line(delim: String = ",") -> PackedStringArray:
	var line: String = get_line()
	if line.is_empty():
		return PackedStringArray()
	
	return line.split(delim)

## Read Pascal string (length-prefixed)
func get_pascal_string() -> String:
	var length: int = get_8()
	if length <= 0:
		return ""
	
	var string_buffer: PackedByteArray = get_buffer(length)
	return string_buffer.get_string_from_utf8()

## Store operations (not supported for VP files - read-only)
func store_8(value: int) -> void:
	_unsupported_write_operation("store_8")

func store_16(value: int) -> void:
	_unsupported_write_operation("store_16")

func store_32(value: int) -> void:
	_unsupported_write_operation("store_32")

func store_64(value: int) -> void:
	_unsupported_write_operation("store_64")

func store_float(value: float) -> void:
	_unsupported_write_operation("store_float")

func store_double(value: float) -> void:
	_unsupported_write_operation("store_double")

func store_buffer(buffer: PackedByteArray) -> void:
	_unsupported_write_operation("store_buffer")

func store_string(string: String) -> void:
	_unsupported_write_operation("store_string")

func store_line(string: String) -> void:
	_unsupported_write_operation("store_line")

func store_csv_line(values: PackedStringArray, delim: String = ",") -> void:
	_unsupported_write_operation("store_csv_line")

func store_pascal_string(string: String) -> void:
	_unsupported_write_operation("store_pascal_string")

func store_var(value: Variant, full_objects: bool = false) -> void:
	_unsupported_write_operation("store_var")

## Helper function for unsupported write operations
func _unsupported_write_operation(operation: String) -> void:
	DebugManager.log_error(DebugManager.Category.FILE_IO, "Write operation %s not supported on VP files (read-only)" % operation)
	ErrorHandler.file_io_error("Attempted write operation on read-only VP file", file_path)

## Flush (no-op for read-only files)
func flush() -> void:
	# No operation needed for read-only VP files
	pass

## Get file error (compatibility function)
func get_error() -> Error:
	if not is_open:
		return Error.ERR_FILE_CANT_OPEN
	
	return Error.OK

## File operations that don't apply to VP files
func get_hidden_attribute() -> bool:
	return false

func set_hidden_attribute(hidden: bool) -> void:
	_unsupported_write_operation("set_hidden_attribute")

func get_read_only_attribute() -> bool:
	return true  # VP files are always read-only

func set_read_only_attribute(read_only: bool) -> void:
	_unsupported_write_operation("set_read_only_attribute")

## Get file modification time
func get_modified_time() -> int:
	if not is_open or file_entry == null:
		return 0
	
	return file_entry.write_time

## Destructor
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		close()

## Compatibility functions for common file operations

## Check if file exists in VP archive
static func file_exists_in_vp(vp_archive: VPArchive, file_path: String) -> bool:
	if vp_archive == null or not vp_archive.is_loaded:
		return false
	
	return vp_archive.has_file(file_path)

## Get file size without opening
static func get_file_size_in_vp(vp_archive: VPArchive, file_path: String) -> int:
	if vp_archive == null or not vp_archive.is_loaded:
		return -1
	
	var entry: VPArchive.VPFileEntry = vp_archive.get_file_entry(file_path)
	if entry == null or entry.is_directory():
		return -1
	
	return entry.size

## Get file modification time without opening
static func get_file_time_in_vp(vp_archive: VPArchive, file_path: String) -> int:
	if vp_archive == null or not vp_archive.is_loaded:
		return 0
	
	var entry: VPArchive.VPFileEntry = vp_archive.get_file_entry(file_path)
	if entry == null:
		return 0
	
	return entry.write_time
