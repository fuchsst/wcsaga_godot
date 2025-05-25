class_name VPManager
extends RefCounted

## Manages multiple VP archives with precedence rules.
## Handles the WCS file system where multiple VP files can override each other
## based on loading order and directory type priorities.

signal archive_loaded(archive_path: String, file_count: int)
signal archive_failed(archive_path: String, error: String)
signal file_resolved(filename: String, archive_path: String)

# Archive management
var loaded_archives: Array[VPArchive] = []
var archive_precedence: Array[String] = []  # Paths in priority order
var file_cache: Dictionary = {}  # filename -> {archive: VPArchive, entry: VPFileEntry}
var directory_cache: Dictionary = {}  # directory -> merged file list

# Performance settings
var enable_file_caching: bool = true
var max_cache_entries: int = 1000
var cache_hit_count: int = 0
var cache_miss_count: int = 0

## Public API

func load_vp_archive(vp_file_path: String, priority: int = 0) -> bool:
	"""Load a VP archive with specified priority (higher = more important)."""
	
	if not FileAccess.file_exists(vp_file_path):
		push_error("VPManager: VP file does not exist: %s" % vp_file_path)
		archive_failed.emit(vp_file_path, "File not found")
		return false
	
	# Check if already loaded
	for archive in loaded_archives:
		if archive.archive_path == vp_file_path:
			push_warning("VPManager: Archive already loaded: %s" % vp_file_path)
			return true
	
	var archive: VPArchive = VPArchive.new()
	
	if not archive.load_archive(vp_file_path):
		push_error("VPManager: Failed to load VP archive: %s" % vp_file_path)
		archive_failed.emit(vp_file_path, "Failed to parse VP file")
		return false
	
	# Insert archive based on priority
	_insert_archive_by_priority(archive, priority)
	
	# Clear caches since file precedence may have changed
	_clear_caches()
	
	var info: Dictionary = archive.get_archive_info()
	print("VPManager: Loaded VP archive: %s (%d files)" % [vp_file_path, info.num_files])
	archive_loaded.emit(vp_file_path, info.num_files)
	
	return true

func load_vp_directory(directory_path: String, auto_priority: bool = true) -> int:
	"""Load all VP files from a directory. Returns number of archives loaded."""
	
	if not DirAccess.dir_exists_absolute(directory_path):
		push_error("VPManager: Directory does not exist: %s" % directory_path)
		return 0
	
	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null:
		push_error("VPManager: Failed to open directory: %s" % directory_path)
		return 0
	
	var vp_files: Array[String] = []
	
	# Find all VP files
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".vp") and dir.current_is_file():
			vp_files.append(directory_path.path_join(file_name))
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort VP files for consistent loading order
	vp_files.sort()
	
	var loaded_count: int = 0
	
	for i in range(vp_files.size()):
		var vp_path: String = vp_files[i]
		var priority: int = i if auto_priority else 0
		
		if load_vp_archive(vp_path, priority):
			loaded_count += 1
	
	print("VPManager: Loaded %d VP archives from %s" % [loaded_count, directory_path])
	return loaded_count

func unload_archive(archive_path: String) -> bool:
	"""Unload a specific VP archive."""
	
	for i in range(loaded_archives.size()):
		var archive: VPArchive = loaded_archives[i]
		
		if archive.archive_path == archive_path:
			archive.close_archive()
			loaded_archives.remove_at(i)
			archive_precedence.remove_at(archive_precedence.find(archive_path))
			_clear_caches()
			
			print("VPManager: Unloaded archive: %s" % archive_path)
			return true
	
	return false

func unload_all_archives() -> void:
	"""Unload all VP archives and clear caches."""
	
	for archive in loaded_archives:
		archive.close_archive()
	
	loaded_archives.clear()
	archive_precedence.clear()
	_clear_caches()
	
	print("VPManager: Unloaded all archives")

func has_file(filename: String) -> bool:
	"""Check if any loaded archive contains the specified file."""
	
	return _resolve_file(filename) != null

func get_file_data(filename: String) -> PackedByteArray:
	"""Get file data from the highest priority archive containing it."""
	
	var resolution: Dictionary = _resolve_file(filename)
	
	if resolution == null:
		push_error("VPManager: File not found: %s" % filename)
		return PackedByteArray()
	
	var archive: VPArchive = resolution.archive
	var data: PackedByteArray = archive.extract_file(filename)
	
	if not data.is_empty() or archive.get_file_size(filename) == 0:
		file_resolved.emit(filename, archive.archive_path)
	
	return data

func save_file_to_path(filename: String, output_path: String) -> bool:
	"""Save file from archives to a specific path."""
	
	var data: PackedByteArray = get_file_data(filename)
	
	if data.is_empty() and not has_file(filename):
		return false
	
	# Ensure output directory exists
	var output_dir: String = output_path.get_base_dir()
	if not output_dir.is_empty():
		DirAccess.open("res://").make_dir_recursive(output_dir)
	
	var output_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if output_file == null:
		push_error("VPManager: Failed to create output file: %s" % output_path)
		return false
	
	output_file.store_buffer(data)
	output_file.close()
	
	return true

func get_file_list(directory_filter: String = "") -> Array[String]:
	"""Get list of all available files, optionally filtered by directory."""
	
	var all_files: Dictionary = {}  # Use dict to avoid duplicates
	var filter_normalized: String = directory_filter.replace("\\", "/").to_lower()
	
	# Collect files from all archives (higher priority overwrites)
	for archive in loaded_archives:
		var archive_files: Array[String] = archive.get_file_list()
		
		for file_path in archive_files:
			var normalized: String = file_path.replace("\\", "/").to_lower()
			
			if filter_normalized.is_empty() or normalized.begins_with(filter_normalized):
				all_files[normalized] = file_path  # Keep original case in value
	
	var result: Array[String] = []
	for original_case in all_files.values():
		result.append(original_case)
	
	result.sort()
	return result

func get_directory_listing(directory: String = "") -> Array[String]:
	"""Get merged directory listing from all archives."""
	
	var normalized_dir: String = directory.replace("\\", "/").to_lower()
	
	# Check cache first
	if enable_file_caching and directory_cache.has(normalized_dir):
		cache_hit_count += 1
		return directory_cache[normalized_dir]
	
	cache_miss_count += 1
	
	# Merge directory listings from all archives
	var merged_files: Dictionary = {}
	
	for archive in loaded_archives:
		var archive_listing: Array[String] = archive.get_directory_listing(directory)
		
		for file_name in archive_listing:
			merged_files[file_name.to_lower()] = file_name  # Keep original case
	
	var result: Array[String] = []
	for original_case in merged_files.values():
		result.append(original_case)
	
	result.sort()
	
	# Cache result
	if enable_file_caching:
		directory_cache[normalized_dir] = result
		_trim_cache_if_needed()
	
	return result

func get_archive_info() -> Dictionary:
	"""Get information about all loaded archives."""
	
	var total_files: int = 0
	var archive_details: Array[Dictionary] = []
	
	for archive in loaded_archives:
		var info: Dictionary = archive.get_archive_info()
		archive_details.append(info)
		total_files += info.num_files
	
	return {
		"num_archives": loaded_archives.size(),
		"total_files": total_files,
		"cache_hits": cache_hit_count,
		"cache_misses": cache_miss_count,
		"cache_hit_ratio": float(cache_hit_count) / max(1, cache_hit_count + cache_miss_count),
		"archives": archive_details,
		"precedence_order": archive_precedence.duplicate()
	}

func clear_caches() -> void:
	"""Manually clear all caches."""
	
	_clear_caches()

## Private implementation

func _insert_archive_by_priority(archive: VPArchive, priority: int) -> void:
	"""Insert archive into the list based on priority (higher priority = later in list)."""
	
	var insert_index: int = loaded_archives.size()
	
	# Find insertion point (archives with lower or equal priority)
	for i in range(loaded_archives.size()):
		var existing_priority: int = archive_precedence.find(loaded_archives[i].archive_path)
		
		if priority > existing_priority:
			insert_index = i
			break
	
	loaded_archives.insert(insert_index, archive)
	archive_precedence.insert(insert_index, archive.archive_path)

func _resolve_file(filename: String) -> Dictionary:
	"""Find which archive contains the file (highest priority wins)."""
	
	var normalized: String = filename.replace("\\", "/").to_lower()
	
	# Check cache first
	if enable_file_caching and file_cache.has(normalized):
		cache_hit_count += 1
		return file_cache[normalized]
	
	cache_miss_count += 1
	
	# Search archives in reverse order (highest priority first)
	for i in range(loaded_archives.size() - 1, -1, -1):
		var archive: VPArchive = loaded_archives[i]
		
		if archive.has_file(filename):
			var resolution: Dictionary = {
				"archive": archive,
				"filename": filename,
				"normalized": normalized
			}
			
			# Cache result
			if enable_file_caching:
				file_cache[normalized] = resolution
				_trim_cache_if_needed()
			
			return resolution
	
	return {}  # File not found

func _clear_caches() -> void:
	"""Clear all internal caches."""
	
	file_cache.clear()
	directory_cache.clear()
	cache_hit_count = 0
	cache_miss_count = 0

func _trim_cache_if_needed() -> void:
	"""Trim cache if it exceeds maximum size."""
	
	var total_entries: int = file_cache.size() + directory_cache.size()
	
	if total_entries > max_cache_entries:
		# Simple LRU: clear oldest half of entries
		var entries_to_remove: int = total_entries - (max_cache_entries / 2)
		
		# Remove file cache entries first
		var file_keys: Array = file_cache.keys()
		var files_to_remove: int = min(entries_to_remove, file_keys.size())
		
		for i in range(files_to_remove):
			file_cache.erase(file_keys[i])
		
		entries_to_remove -= files_to_remove
		
		# Remove directory cache entries if needed
		if entries_to_remove > 0:
			var dir_keys: Array = directory_cache.keys()
			var dirs_to_remove: int = min(entries_to_remove, dir_keys.size())
			
			for i in range(dirs_to_remove):
				directory_cache.erase(dir_keys[i])

## Cleanup

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		unload_all_archives()