class_name FileManager
extends RefCounted

## Unified file system abstraction layer for WCS-Godot conversion.
## Provides transparent access to files from filesystem, VP archives, and Godot resources.
## Implements WCS-style path type resolution and file caching for optimal performance.

signal file_accessed(file_path: String, access_type: String)
signal cache_status_changed(used_memory: int, max_memory: int)

# WCS path types corresponding to original CF_TYPE_* constants
enum PathType {
	INVALID = 0,
	ROOT = 1,
	DATA = 2,
	MAPS = 3,
	TEXT = 4,
	MODELS = 5,
	TABLES = 6,
	SOUNDS = 7,
	SOUNDS_8B22K = 8,
	SOUNDS_16B11K = 9,
	VOICE = 10,
	VOICE_BRIEFINGS = 11,
	VOICE_CMD_BRIEF = 12,
	VOICE_DEBRIEFINGS = 13,
	VOICE_PERSONAS = 14,
	VOICE_SPECIAL = 15,
	VOICE_TRAINING = 16,
	MUSIC = 17,
	MOVIES = 18,
	INTERFACE = 19,
	FONT = 20,
	EFFECTS = 21,
	HUD = 22,
	PLAYERS = 23,
	PLAYER_IMAGES = 24,
	SQUAD_IMAGES = 25,
	SINGLE_PLAYERS = 26,
	MULTI_PLAYERS = 27,
	CACHE = 28,
	MULTI_CACHE = 29,
	MISSIONS = 30,
	CONFIG = 31,
	DEMOS = 32,
	CBANIMS = 33,
	INTEL_ANIMS = 34,
	SCRIPTS = 35,
	FICTION = 36,
	ANY = -1  # Special value for searching all path types
}

# File access modes
enum AccessMode {
	READ,
	WRITE,
	READ_WRITE
}

# File seek origins  
enum SeekOrigin {
	SET = 0,  # From beginning of file
	CUR = 1,  # From current position
	END = 2   # From end of file
}

# Path type configuration structure
class PathTypeConfig:
	var type: PathType
	var path: String
	var extensions: PackedStringArray
	var parent_type: PathType

	func _init(p_type: PathType, p_path: String, p_extensions: PackedStringArray, p_parent: PathType) -> void:
		type = p_type
		path = p_path
		extensions = p_extensions
		parent_type = p_parent

# File cache entry for performance optimization
class CacheEntry:
	var file_path: String
	var data: PackedByteArray
	var access_time: int
	var file_size: int
	var path_type: PathType

	func _init(p_path: String, p_data: PackedByteArray, p_type: PathType) -> void:
		file_path = p_path
		data = p_data
		path_type = p_type
		file_size = p_data.size()
		access_time = Time.get_ticks_msec()

# Static instance for singleton pattern
static var _instance: FileManager = null

# Core configuration
var _root_directory: String = ""
var _user_directory: String = ""
var _path_configs: Dictionary = {}
var _vp_archive_manager: VPArchiveManager = null

# File caching system
var _file_cache: Dictionary = {}  # String -> CacheEntry
var _cache_max_size: int = 50 * 1024 * 1024  # 50MB default
var _cache_current_size: int = 0
var _cache_enabled: bool = true

# Access tracking
var _access_stats: Dictionary = {}  # String -> int (access count)

func _init() -> void:
	_initialize_path_configs()
	_vp_archive_manager = VPArchiveManager.get_instance()

## Get singleton instance of FileManager
static func get_instance() -> FileManager:
	if _instance == null:
		_instance = FileManager.new()
	return _instance

## Initialize the file system with root directory and optional user directory
func initialize(root_dir: String, user_dir: String = "") -> bool:
	if root_dir.is_empty():
		push_error("FileManager: Root directory cannot be empty")
		return false
	
	_root_directory = root_dir.path_join("")  # Normalize path
	if not DirAccess.dir_exists_absolute(_root_directory):
		push_error("FileManager: Root directory does not exist: " + _root_directory)
		return false
	
	if user_dir.is_empty():
		_user_directory = OS.get_user_data_dir().path_join("wcs_godot")
	else:
		_user_directory = user_dir
	
	# Ensure user directory exists
	if not DirAccess.dir_exists_absolute(_user_directory):
		var dir_access: DirAccess = DirAccess.open("/")
		if dir_access == null:
			push_error("FileManager: Failed to create user directory access")
			return false
		
		var error: Error = dir_access.make_dir_recursive_absolute(_user_directory)
		if error != OK:
			push_error("FileManager: Failed to create user directory: " + error_string(error))
			return false
	
	print("FileManager: Initialized with root='%s', user='%s'" % [_root_directory, _user_directory])
	return true

## Open a file for reading/writing with automatic path resolution
func open_file(filename: String, mode: AccessMode = AccessMode.READ, path_type: PathType = PathType.ANY) -> FileAccess:
	if filename.is_empty():
		push_error("FileManager: Filename cannot be empty")
		return null
	
	# Track access for statistics
	_track_file_access(filename, _access_mode_to_string(mode))
	
	# Try to resolve the full file path
	var full_path: String = _resolve_file_path(filename, path_type)
	if full_path.is_empty():
		push_warning("FileManager: Could not resolve file path for: " + filename)
		return null
	
	# Check if file is in VP archive first
	if mode == AccessMode.READ:
		var vp_file: VPFileAccess = _try_open_from_vp(filename, path_type)
		if vp_file != null:
			return vp_file
	
	# Try to open from filesystem
	var file_access: FileAccess = null
	match mode:
		AccessMode.READ:
			file_access = FileAccess.open(full_path, FileAccess.READ)
		AccessMode.WRITE:
			file_access = FileAccess.open(full_path, FileAccess.WRITE)
		AccessMode.READ_WRITE:
			file_access = FileAccess.open(full_path, FileAccess.READ_WRITE)
	
	if file_access == null:
		var error: Error = FileAccess.get_open_error()
		push_warning("FileManager: Failed to open file '%s': %s" % [full_path, error_string(error)])
		return null
	
	return file_access

## Read entire file contents as bytes with automatic caching
func read_file_bytes(filename: String, path_type: PathType = PathType.ANY) -> PackedByteArray:
	if filename.is_empty():
		push_error("FileManager: Filename cannot be empty")
		return PackedByteArray()
	
	# Check cache first
	var cache_key: String = _get_cache_key(filename, path_type)
	if _cache_enabled and _file_cache.has(cache_key):
		var entry: CacheEntry = _file_cache[cache_key]
		entry.access_time = Time.get_ticks_msec()
		_track_file_access(filename, "cache_hit")
		return entry.data
	
	# Open and read file
	var file: FileAccess = open_file(filename, AccessMode.READ, path_type)
	if file == null:
		return PackedByteArray()
	
	var data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	# Cache the data if caching is enabled and file is small enough
	if _cache_enabled and data.size() <= _cache_max_size / 10:  # Don't cache files larger than 10% of cache
		_cache_file_data(filename, data, path_type)
	
	return data

## Read entire file contents as string
func read_file_text(filename: String, path_type: PathType = PathType.ANY) -> String:
	var data: PackedByteArray = read_file_bytes(filename, path_type)
	if data.is_empty():
		return ""
	
	return data.get_string_from_utf8()

## Write data to file
func write_file_bytes(filename: String, data: PackedByteArray, path_type: PathType = PathType.ANY) -> bool:
	if filename.is_empty():
		push_error("FileManager: Filename cannot be empty")
		return false
	
	var file: FileAccess = open_file(filename, AccessMode.WRITE, path_type)
	if file == null:
		return false
	
	file.store_buffer(data)
	var error: Error = file.get_error()
	file.close()
	
	if error != OK:
		push_error("FileManager: Failed to write file '%s': %s" % [filename, error_string(error)])
		return false
	
	# Invalidate cache entry if it exists
	var cache_key: String = _get_cache_key(filename, path_type)
	if _file_cache.has(cache_key):
		var entry: CacheEntry = _file_cache[cache_key]
		_cache_current_size -= entry.file_size
		_file_cache.erase(cache_key)
	
	_track_file_access(filename, "write")
	return true

## Write string to file
func write_file_text(filename: String, text: String, path_type: PathType = PathType.ANY) -> bool:
	return write_file_bytes(filename, text.to_utf8_buffer(), path_type)

## Check if file exists (filesystem and VP archives)
func file_exists(filename: String, path_type: PathType = PathType.ANY) -> bool:
	if filename.is_empty():
		return false
	
	# Check VP archives first
	if _vp_archive_manager.file_exists(filename):
		return true
	
	# Check filesystem
	var full_path: String = _resolve_file_path(filename, path_type)
	if full_path.is_empty():
		return false
	
	return FileAccess.file_exists(full_path)

## Get file size in bytes
func get_file_size(filename: String, path_type: PathType = PathType.ANY) -> int:
	if not file_exists(filename, path_type):
		return -1
	
	# Try VP archives first
	var vp_file: VPFileAccess = _try_open_from_vp(filename, path_type)
	if vp_file != null:
		var size: int = vp_file.get_length()
		vp_file.close()
		return size
	
	# Try filesystem
	var full_path: String = _resolve_file_path(filename, path_type)
	if full_path.is_empty():
		return -1
	
	var file: FileAccess = FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		return -1
	
	var size: int = file.get_length()
	file.close()
	return size

## Delete a file from filesystem (VP archives are read-only)
func delete_file(filename: String, path_type: PathType = PathType.ANY) -> bool:
	if filename.is_empty():
		push_error("FileManager: Filename cannot be empty")
		return false
	
	var full_path: String = _resolve_file_path(filename, path_type)
	if full_path.is_empty():
		return false
	
	if not FileAccess.file_exists(full_path):
		return false
	
	var error: Error = DirAccess.remove_absolute(full_path)
	if error != OK:
		push_error("FileManager: Failed to delete file '%s': %s" % [full_path, error_string(error)])
		return false
	
	# Remove from cache if present
	var cache_key: String = _get_cache_key(filename, path_type)
	if _file_cache.has(cache_key):
		var entry: CacheEntry = _file_cache[cache_key]
		_cache_current_size -= entry.file_size
		_file_cache.erase(cache_key)
	
	_track_file_access(filename, "delete")
	return true

## Get file access statistics
func get_access_stats() -> Dictionary:
	return _access_stats.duplicate()

## Clear file access statistics
func clear_access_stats() -> void:
	_access_stats.clear()

## Get cache statistics
func get_cache_stats() -> Dictionary:
	return {
		"enabled": _cache_enabled,
		"current_size": _cache_current_size,
		"max_size": _cache_max_size,
		"entry_count": _file_cache.size(),
		"hit_ratio": _calculate_cache_hit_ratio()
	}

## Configure cache settings
func configure_cache(enabled: bool, max_size_mb: int = 50) -> void:
	_cache_enabled = enabled
	_cache_max_size = max_size_mb * 1024 * 1024
	
	if not enabled:
		clear_cache()
	elif _cache_current_size > _cache_max_size:
		_evict_cache_entries()

## Clear all cached file data
func clear_cache() -> void:
	_file_cache.clear()
	_cache_current_size = 0
	cache_status_changed.emit(0, _cache_max_size)

## PRIVATE METHODS

func _initialize_path_configs() -> void:
	# Initialize WCS path type configurations based on original Pathtypes array
	_path_configs[PathType.ROOT] = PathTypeConfig.new(PathType.ROOT, "", PackedStringArray([".mve", ".ogg"]), PathType.ROOT)
	_path_configs[PathType.DATA] = PathTypeConfig.new(PathType.DATA, "data", PackedStringArray([".cfg", ".log", ".txt"]), PathType.ROOT)
	_path_configs[PathType.MAPS] = PathTypeConfig.new(PathType.MAPS, "data/maps", PackedStringArray([".pcx", ".ani", ".eff", ".tga", ".jpg", ".png", ".dds"]), PathType.DATA)
	_path_configs[PathType.TEXT] = PathTypeConfig.new(PathType.TEXT, "data/text", PackedStringArray([".txt", ".net"]), PathType.DATA)
	_path_configs[PathType.MODELS] = PathTypeConfig.new(PathType.MODELS, "data/models", PackedStringArray([".pof"]), PathType.DATA)
	_path_configs[PathType.TABLES] = PathTypeConfig.new(PathType.TABLES, "data/tables", PackedStringArray([".tbl", ".tbm"]), PathType.DATA)
	_path_configs[PathType.SOUNDS] = PathTypeConfig.new(PathType.SOUNDS, "data/sounds", PackedStringArray([".wav", ".ogg"]), PathType.DATA)
	_path_configs[PathType.SOUNDS_8B22K] = PathTypeConfig.new(PathType.SOUNDS_8B22K, "data/sounds/8b22k", PackedStringArray([".wav", ".ogg"]), PathType.SOUNDS)
	_path_configs[PathType.SOUNDS_16B11K] = PathTypeConfig.new(PathType.SOUNDS_16B11K, "data/sounds/16b11k", PackedStringArray([".wav", ".ogg"]), PathType.SOUNDS)
	_path_configs[PathType.VOICE] = PathTypeConfig.new(PathType.VOICE, "data/voice", PackedStringArray(), PathType.DATA)
	_path_configs[PathType.VOICE_BRIEFINGS] = PathTypeConfig.new(PathType.VOICE_BRIEFINGS, "data/voice/briefing", PackedStringArray([".wav", ".ogg"]), PathType.VOICE)
	_path_configs[PathType.VOICE_CMD_BRIEF] = PathTypeConfig.new(PathType.VOICE_CMD_BRIEF, "data/voice/command_briefings", PackedStringArray([".wav", ".ogg"]), PathType.VOICE)
	_path_configs[PathType.VOICE_DEBRIEFINGS] = PathTypeConfig.new(PathType.VOICE_DEBRIEFINGS, "data/voice/debriefing", PackedStringArray([".wav", ".ogg"]), PathType.VOICE)
	_path_configs[PathType.VOICE_PERSONAS] = PathTypeConfig.new(PathType.VOICE_PERSONAS, "data/voice/personas", PackedStringArray([".wav", ".ogg"]), PathType.VOICE)
	_path_configs[PathType.VOICE_SPECIAL] = PathTypeConfig.new(PathType.VOICE_SPECIAL, "data/voice/special", PackedStringArray([".wav", ".ogg"]), PathType.VOICE)
	_path_configs[PathType.VOICE_TRAINING] = PathTypeConfig.new(PathType.VOICE_TRAINING, "data/voice/training", PackedStringArray([".wav", ".ogg"]), PathType.VOICE)
	_path_configs[PathType.MUSIC] = PathTypeConfig.new(PathType.MUSIC, "data/music", PackedStringArray([".wav", ".ogg"]), PathType.DATA)
	_path_configs[PathType.MOVIES] = PathTypeConfig.new(PathType.MOVIES, "data/movies", PackedStringArray([".mve", ".msb", ".ogg"]), PathType.DATA)
	_path_configs[PathType.INTERFACE] = PathTypeConfig.new(PathType.INTERFACE, "data/interface", PackedStringArray([".pcx", ".ani", ".dds", ".tga", ".eff", ".png", ".jpg"]), PathType.DATA)
	_path_configs[PathType.FONT] = PathTypeConfig.new(PathType.FONT, "data/fonts", PackedStringArray([".vf", ".ttf"]), PathType.DATA)
	_path_configs[PathType.EFFECTS] = PathTypeConfig.new(PathType.EFFECTS, "data/effects", PackedStringArray([".ani", ".eff", ".pcx", ".neb", ".tga", ".jpg", ".png", ".dds", ".sdr"]), PathType.DATA)
	_path_configs[PathType.HUD] = PathTypeConfig.new(PathType.HUD, "data/hud", PackedStringArray([".pcx", ".ani", ".eff", ".tga", ".jpg", ".png", ".dds"]), PathType.DATA)
	_path_configs[PathType.PLAYERS] = PathTypeConfig.new(PathType.PLAYERS, "data/players", PackedStringArray([".hcf"]), PathType.DATA)
	_path_configs[PathType.PLAYER_IMAGES] = PathTypeConfig.new(PathType.PLAYER_IMAGES, "data/players/images", PackedStringArray([".pcx", ".png", ".dds"]), PathType.PLAYERS)
	_path_configs[PathType.SQUAD_IMAGES] = PathTypeConfig.new(PathType.SQUAD_IMAGES, "data/players/squads", PackedStringArray([".pcx", ".png", ".dds"]), PathType.PLAYERS)
	_path_configs[PathType.SINGLE_PLAYERS] = PathTypeConfig.new(PathType.SINGLE_PLAYERS, "data/players/single", PackedStringArray([".pl2", ".cs2", ".plr", ".csg", ".css"]), PathType.PLAYERS)
	_path_configs[PathType.MULTI_PLAYERS] = PathTypeConfig.new(PathType.MULTI_PLAYERS, "data/players/multi", PackedStringArray([".plr"]), PathType.PLAYERS)
	_path_configs[PathType.CACHE] = PathTypeConfig.new(PathType.CACHE, "data/cache", PackedStringArray([".clr", ".tmp", ".ibx", ".tsb"]), PathType.DATA)
	_path_configs[PathType.MULTI_CACHE] = PathTypeConfig.new(PathType.MULTI_CACHE, "data/multidata", PackedStringArray([".pcx", ".png", ".dds", ".fs2", ".txt"]), PathType.DATA)
	_path_configs[PathType.MISSIONS] = PathTypeConfig.new(PathType.MISSIONS, "data/missions", PackedStringArray([".fs2", ".fc2", ".ntl", ".ssv"]), PathType.DATA)
	_path_configs[PathType.CONFIG] = PathTypeConfig.new(PathType.CONFIG, "data/config", PackedStringArray([".cfg"]), PathType.DATA)
	_path_configs[PathType.DEMOS] = PathTypeConfig.new(PathType.DEMOS, "data/demos", PackedStringArray([".fsd"]), PathType.DATA)
	_path_configs[PathType.CBANIMS] = PathTypeConfig.new(PathType.CBANIMS, "data/cbanims", PackedStringArray([".pcx", ".ani", ".eff", ".tga", ".jpg", ".png", ".dds"]), PathType.DATA)
	_path_configs[PathType.INTEL_ANIMS] = PathTypeConfig.new(PathType.INTEL_ANIMS, "data/intelanims", PackedStringArray([".pcx", ".ani", ".eff", ".tga", ".jpg", ".png", ".dds"]), PathType.DATA)
	_path_configs[PathType.SCRIPTS] = PathTypeConfig.new(PathType.SCRIPTS, "data/scripts", PackedStringArray([".lua", ".lc"]), PathType.DATA)
	_path_configs[PathType.FICTION] = PathTypeConfig.new(PathType.FICTION, "data/fiction", PackedStringArray([".txt"]), PathType.DATA)

func _resolve_file_path(filename: String, path_type: PathType) -> String:
	# If path type is ANY, try to determine from file extension
	if path_type == PathType.ANY:
		path_type = _determine_path_type_from_extension(filename)
	
	# If we still don't have a valid path type, try root
	if path_type == PathType.ANY or not _path_configs.has(path_type):
		path_type = PathType.ROOT
	
	var config: PathTypeConfig = _path_configs[path_type]
	var base_path: String = _root_directory
	
	if not config.path.is_empty():
		base_path = base_path.path_join(config.path)
	
	return base_path.path_join(filename)

func _determine_path_type_from_extension(filename: String) -> PathType:
	var ext: String = "." + filename.get_extension().to_lower()
	
	# Search through all path configs to find matching extension
	for path_type in _path_configs.keys():
		var config: PathTypeConfig = _path_configs[path_type]
		if ext in config.extensions:
			return path_type
	
	return PathType.ROOT

func _try_open_from_vp(filename: String, path_type: PathType) -> VPFileAccess:
	# Try to open file from VP archives
	return _vp_archive_manager.open_file(filename)

func _track_file_access(filename: String, access_type: String) -> void:
	var key: String = filename + ":" + access_type
	_access_stats[key] = _access_stats.get(key, 0) + 1
	file_accessed.emit(filename, access_type)

func _access_mode_to_string(mode: AccessMode) -> String:
	match mode:
		AccessMode.READ:
			return "read"
		AccessMode.WRITE:
			return "write"
		AccessMode.READ_WRITE:
			return "read_write"
		_:
			return "unknown"

func _get_cache_key(filename: String, path_type: PathType) -> String:
	return "%s:%d" % [filename, path_type]

func _cache_file_data(filename: String, data: PackedByteArray, path_type: PathType) -> void:
	var cache_key: String = _get_cache_key(filename, path_type)
	var entry: CacheEntry = CacheEntry.new(filename, data, path_type)
	
	# Remove existing entry if present
	if _file_cache.has(cache_key):
		var old_entry: CacheEntry = _file_cache[cache_key]
		_cache_current_size -= old_entry.file_size
	
	# Check if we need to evict entries
	while _cache_current_size + entry.file_size > _cache_max_size and not _file_cache.is_empty():
		_evict_least_recently_used()
	
	# Add new entry
	_file_cache[cache_key] = entry
	_cache_current_size += entry.file_size
	cache_status_changed.emit(_cache_current_size, _cache_max_size)

func _evict_cache_entries() -> void:
	while _cache_current_size > _cache_max_size and not _file_cache.is_empty():
		_evict_least_recently_used()

func _evict_least_recently_used() -> void:
	var oldest_time: int = Time.get_ticks_msec()
	var oldest_key: String = ""
	
	for key in _file_cache.keys():
		var entry: CacheEntry = _file_cache[key]
		if entry.access_time < oldest_time:
			oldest_time = entry.access_time
			oldest_key = key
	
	if not oldest_key.is_empty():
		var entry: CacheEntry = _file_cache[oldest_key]
		_cache_current_size -= entry.file_size
		_file_cache.erase(oldest_key)

func _calculate_cache_hit_ratio() -> float:
	var hits: int = _access_stats.get("cache_hit", 0)
	var total_reads: int = 0
	
	for key in _access_stats.keys():
		if key.ends_with(":read") or key.ends_with(":cache_hit"):
			total_reads += _access_stats[key]
	
	if total_reads == 0:
		return 0.0
	
	return float(hits) / float(total_reads)