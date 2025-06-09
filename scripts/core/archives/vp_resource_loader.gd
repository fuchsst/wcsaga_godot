class_name VPResourceFormatLoader
extends ResourceFormatLoader

## ResourceFormatLoader for VP Archive files
## Integrates VP archives with Godot's ResourceLoader system for seamless asset loading

const VPArchive = preload("res://scripts/core/archives/vp_archive.gd")

# Cache for loaded VP archives to avoid redundant file I/O
var _archive_cache: Dictionary = {}  # String (file_path) -> VPArchive
var _max_cache_size: int = 10
var _debug_enabled: bool = false

## Get the list of extensions this loader can handle
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["vp", "VP"])

## Check if this loader can load the given type
func _handles_type(type: StringName) -> bool:
	# Handle VPArchive resources and general Resource loading from VP files
	return type == "VPArchive" or type == "Resource"

## Get the resource type that this loader creates
func _get_resource_type(path: String) -> String:
	if path.get_extension().to_lower() == "vp":
		return "VPArchive"
	return ""

## Load a resource from the given path
func _load(path: String, original_path: String, use_sub_threads: bool, cache_mode: int) -> Variant:
	if _debug_enabled:
		print("VPResourceFormatLoader: Loading VP archive: %s" % path)
	
	# Check cache first
	if _archive_cache.has(path):
		if _debug_enabled:
			print("VPResourceFormatLoader: Using cached VP archive: %s" % path)
		return _archive_cache[path]
	
	# Load new VP archive
	var archive: VPArchive = VPArchive.load_archive(path)
	if archive == null:
		push_error("VPResourceFormatLoader: Failed to load VP archive: %s" % path)
		return ERR_FILE_CANT_OPEN
	
	# Add to cache
	_add_to_cache(path, archive)
	
	if _debug_enabled:
		print("VPResourceFormatLoader: Successfully loaded VP archive: %s (%d files)" % [path, archive.get_file_count()])
	
	return archive

## Add archive to cache with size management
func _add_to_cache(path: String, archive: VPArchive) -> void:
	# Remove oldest entries if cache is full
	if _archive_cache.size() >= _max_cache_size:
		var oldest_key: String = _archive_cache.keys()[0]
		_archive_cache.erase(oldest_key)
		if _debug_enabled:
			print("VPResourceFormatLoader: Removed oldest cache entry: %s" % oldest_key)
	
	_archive_cache[path] = archive

## Clear the VP archive cache
func clear_cache() -> void:
	_archive_cache.clear()
	if _debug_enabled:
		print("VPResourceFormatLoader: Cache cleared")

## Get cache statistics
func get_cache_info() -> Dictionary:
	return {
		"cached_archives": _archive_cache.size(),
		"max_cache_size": _max_cache_size,
		"cached_paths": _archive_cache.keys()
	}

## Enable or disable debug logging
func set_debug_enabled(enabled: bool) -> void:
	_debug_enabled = enabled

## Check if an archive is cached
func is_cached(path: String) -> bool:
	return _archive_cache.has(path)
