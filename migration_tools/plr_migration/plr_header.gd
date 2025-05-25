class_name PLRHeader
extends Resource

## PLR file header structure for WCS pilot files.
## Contains metadata and validation information for PLR file parsing.

const PLR_SIGNATURE: int = 0x46505346  ## "FPSF" signature
const MIN_SUPPORTED_VERSION: int = 140  ## Minimum PLR version we support
const MAX_SUPPORTED_VERSION: int = 242  ## Maximum PLR version we support

# --- Header Data ---
@export var signature: int = 0           ## File signature (should be 0x46505346)
@export var version: int = 0             ## PLR file version
@export var pilot_name: String = ""      ## Pilot callsign from header
@export var file_size: int = 0           ## Total file size in bytes
@export var header_size: int = 0         ## Size of header section
@export var data_checksum: int = 0       ## Checksum of data section

# --- File Information ---
@export var is_multiplayer: bool = false ## Whether this is a multiplayer pilot
@export var creation_time: int = 0       ## File creation timestamp
@export var last_modified: int = 0       ## Last modification timestamp

# --- Validation State ---
@export var is_valid: bool = false       ## Whether header is valid
@export var validation_errors: Array[String] = [] ## Validation error messages

func _init() -> void:
	validation_errors = []

## Parse PLR header from file
static func parse_from_file(file: FileAccess) -> PLRHeader:
	var header: PLRHeader = PLRHeader.new()
	
	if not file:
		header.validation_errors.append("Invalid file handle")
		return header
	
	# Save current position
	var start_pos: int = file.get_position()
	
	# Read signature (4 bytes)
	header.signature = file.get_32()
	
	# Validate signature
	if header.signature != PLR_SIGNATURE:
		header.validation_errors.append("Invalid PLR signature: 0x" + String.num_int64(header.signature, 16))
		return header
	
	# Read version (4 bytes)
	header.version = file.get_32()
	
	# Validate version
	if header.version < MIN_SUPPORTED_VERSION or header.version > MAX_SUPPORTED_VERSION:
		header.validation_errors.append("Unsupported PLR version: " + str(header.version))
		return header
	
	# Read header size (4 bytes) - for versions that support it
	if header.version >= 200:
		header.header_size = file.get_32()
	else:
		header.header_size = 256  # Fixed size for older versions
	
	# Read pilot name (32 bytes, null-terminated)
	var name_bytes: PackedByteArray = file.get_buffer(32)
	header.pilot_name = _extract_null_terminated_string(name_bytes)
	
	# Read file size (4 bytes)
	header.file_size = file.get_32()
	
	# Read data checksum (4 bytes) - for versions that support it
	if header.version >= 180:
		header.data_checksum = file.get_32()
	
	# Read timestamps (8 bytes each) - for newer versions
	if header.version >= 220:
		header.creation_time = file.get_64()
		header.last_modified = file.get_64()
	
	# Determine if multiplayer based on version and flags
	header.is_multiplayer = header.version >= 200
	
	# Mark as valid if we got this far
	header.is_valid = true
	
	return header

## Extract null-terminated string from byte array
static func _extract_null_terminated_string(bytes: PackedByteArray) -> String:
	var result: PackedByteArray = PackedByteArray()
	
	for byte in bytes:
		if byte == 0:
			break
		result.append(byte)
	
	return result.get_string_from_utf8()

## Validate header data
func validate_header() -> bool:
	validation_errors.clear()
	
	# Check signature
	if signature != PLR_SIGNATURE:
		validation_errors.append("Invalid signature")
	
	# Check version range
	if version < MIN_SUPPORTED_VERSION or version > MAX_SUPPORTED_VERSION:
		validation_errors.append("Unsupported version: " + str(version))
	
	# Check pilot name
	if pilot_name.is_empty():
		validation_errors.append("Empty pilot name")
	elif pilot_name.length() > 31:
		validation_errors.append("Pilot name too long")
	
	# Check file size
	if file_size <= 0:
		validation_errors.append("Invalid file size")
	elif file_size > 100 * 1024 * 1024:  # 100MB limit
		validation_errors.append("File size too large: " + str(file_size))
	
	# Check header size consistency
	if header_size > 0 and header_size > file_size:
		validation_errors.append("Header size larger than file size")
	
	is_valid = validation_errors.is_empty()
	return is_valid

## Get version name for display
func get_version_name() -> String:
	match version:
		140..159: return "Release " + str(version)
		160..179: return "Early Patch " + str(version)
		180..199: return "Standard " + str(version)
		200..219: return "Enhanced " + str(version)
		220..242: return "Modern " + str(version)
		_: return "Unknown " + str(version)

## Get pilot type description
func get_pilot_type() -> String:
	return "Multiplayer" if is_multiplayer else "Single Player"

## Check if version supports specific features
func supports_checksums() -> bool:
	return version >= 180

func supports_timestamps() -> bool:
	return version >= 220

func supports_extended_stats() -> bool:
	return version >= 200

func supports_campaign_persistence() -> bool:
	return version >= 160

## Get header summary for debugging
func get_header_summary() -> Dictionary:
	return {
		"signature": "0x" + String.num_int64(signature, 16),
		"version": version,
		"version_name": get_version_name(),
		"pilot_name": pilot_name,
		"pilot_type": get_pilot_type(),
		"file_size": file_size,
		"header_size": header_size,
		"has_checksum": data_checksum > 0,
		"has_timestamps": creation_time > 0,
		"is_valid": is_valid,
		"validation_errors": validation_errors
	}

## Calculate expected data size
func get_expected_data_size() -> int:
	if header_size > 0:
		return file_size - header_size
	else:
		return file_size - 256  # Default header size

## Export to dictionary
func export_to_dictionary() -> Dictionary:
	return {
		"signature": signature,
		"version": version,
		"pilot_name": pilot_name,
		"file_size": file_size,
		"header_size": header_size,
		"data_checksum": data_checksum,
		"is_multiplayer": is_multiplayer,
		"creation_time": creation_time,
		"last_modified": last_modified,
		"is_valid": is_valid,
		"validation_errors": validation_errors
	}

## Import from dictionary
func import_from_dictionary(data: Dictionary) -> bool:
	if not data.has("signature") or not data.has("version"):
		return false
	
	signature = data.get("signature", 0)
	version = data.get("version", 0)
	pilot_name = data.get("pilot_name", "")
	file_size = data.get("file_size", 0)
	header_size = data.get("header_size", 0)
	data_checksum = data.get("data_checksum", 0)
	is_multiplayer = data.get("is_multiplayer", false)
	creation_time = data.get("creation_time", 0)
	last_modified = data.get("last_modified", 0)
	is_valid = data.get("is_valid", false)
	validation_errors = data.get("validation_errors", [])
	
	return validate_header()

## Create a test header for debugging
static func create_test_header(pilot_name: String, version: int = 242) -> PLRHeader:
	var header: PLRHeader = PLRHeader.new()
	header.signature = PLR_SIGNATURE
	header.version = version
	header.pilot_name = pilot_name
	header.file_size = 50000  # Example size
	header.header_size = 256
	header.data_checksum = 12345
	header.is_multiplayer = version >= 200
	header.creation_time = Time.get_unix_time_from_system()
	header.last_modified = header.creation_time
	header.is_valid = true
	return header