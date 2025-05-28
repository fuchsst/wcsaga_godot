class_name VPArchiveManager
extends RefCounted

## VP Archive Manager for efficient loading and caching of VP archives.
## Provides centralized access to multiple VP archives with memory optimization.
## FOUNDATION SCOPE: Archive management infrastructure only.

const VPArchive = preload("res://scripts/core/archives/vp_archive.gd")
const VPFileAccess = preload("res://scripts/core/archives/vp_file_access.gd")
const DebugManager = preload("res://scripts/core/platform/debug_manager.gd")
const ErrorHandler = preload("res://scripts/core/platform/error_handler.gd")
const PlatformUtils = preload("res://scripts/core/platform/platform_utils.gd")

## Archive cache configuration
const DEFAULT_MAX_CACHED_ARCHIVES: int = 8
const DEFAULT_MAX_CACHED_FILES: int = 100
const DEFAULT_CACHE_SIZE_MB: int = 50

## Cached archive entry
class CachedArchive:
	var archive: VPArchive
	var last_access_time: float
	var access_count: int = 0
	var file_cache: Dictionary = {}  # file_path -> cached data
	var cache_size_bytes: int = 0

## File cache entry
class CachedFile:
	var data: PackedByteArray
	var last_access_time: float
	var access_count: int = 0
	var size_bytes: int = 0

## Singleton instance
static var _instance: VPArchiveManager

## Archive management
var cached_archives: Dictionary = {}  # archive_path -> CachedArchive
var archive_search_paths: PackedStringArray = PackedStringArray()
var max_cached_archives: int = DEFAULT_MAX_CACHED_ARCHIVES
var max_cached_files_per_archive: int = DEFAULT_MAX_CACHED_FILES
var max_cache_size_mb: int = DEFAULT_CACHE_SIZE_MB

## Statistics
var total_archives_loaded: int = 0
var total_files_accessed: int = 0
var cache_hits: int = 0
var cache_misses: int = 0

## Get singleton instance
static func get_instance() -> VPArchiveManager:
	if _instance == null:
		_instance = VPArchiveManager.new()
	return _instance

## Initialize archive manager
func initialize(search_paths: PackedStringArray = PackedStringArray()) -> void:
	archive_search_paths = search_paths.duplicate()
	
	# Add default search paths if none provided
	if archive_search_paths.is_empty():
		archive_search_paths.append("res://data/")
		archive_search_paths.append("user://data/")
		
		# Add WCS installation paths if they exist
		var wcs_paths: PackedStringArray = _detect_wcs_installation_paths()
		for path: String in wcs_paths:
			archive_search_paths.append(path)
	
	DebugManager.log_info(DebugManager.Category.FILE_IO, "VPArchiveManager initialized with %d search paths" % archive_search_paths.size())
	
	for path: String in archive_search_paths:
		DebugManager.log_debug(DebugManager.Category.FILE_IO, "VP search path: %s" % path)

## Detect WCS installation paths
func _detect_wcs_installation_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	
	# Common WCS installation directories
	var common_paths: PackedStringArray = [
		"C:/Games/Wing Commander Saga/",
		"C:/Program Files/Wing Commander Saga/",
		"C:/Program Files (x86)/Wing Commander Saga/",
		"/usr/games/wcsaga/",
		"/opt/wcsaga/",
		OS.get_user_data_dir() + "/Wing Commander Saga/"
	]
	
	for path: String in common_paths:
		if PlatformUtils.directory_exists(path):
			paths.append(path)
			DebugManager.log_debug(DebugManager.Category.FILE_IO, "Found WCS installation: %s" % path)
	
	return paths

## Set cache limits
func set_cache_limits(max_archives: int, max_files_per_archive: int, max_size_mb: int) -> void:
	max_cached_archives = max_archives
	max_cached_files_per_archive = max_files_per_archive
	max_cache_size_mb = max_size_mb
	
	DebugManager.log_info(DebugManager.Category.FILE_IO, "VP cache limits: %d archives, %d files/archive, %d MB" % [max_archives, max_files_per_archive, max_size_mb])
	
	# Trim caches if necessary
	_trim_archive_cache()

## Load VP archive (with caching)
func load_archive(archive_path: String) -> VPArchive:
	var normalized_path: String = PlatformUtils.normalize_path(archive_path)
	
	# Check if already cached
	if cached_archives.has(normalized_path):
		var cached: CachedArchive = cached_archives[normalized_path]
		cached.last_access_time = Time.get_unix_time_from_system()
		cached.access_count += 1
		cache_hits += 1
		
		DebugManager.log_trace(DebugManager.Category.FILE_IO, "Cache hit for VP archive: %s" % normalized_path)
		return cached.archive
	
	# Try to find archive in search paths
	var full_path: String = _find_archive_in_search_paths(normalized_path)
	if full_path.is_empty():
		DebugManager.log_warning(DebugManager.Category.FILE_IO, "VP archive not found: %s" % archive_path)
		return null
	
	# Load archive
	var archive: VPArchive = VPArchive.load_archive(full_path)
	if archive == null:
		DebugManager.log_error(DebugManager.Category.FILE_IO, "Failed to load VP archive: %s" % full_path)
		return null
	
	# Cache the archive
	var cached: CachedArchive = CachedArchive.new()
	cached.archive = archive
	cached.last_access_time = Time.get_unix_time_from_system()
	cached.access_count = 1
	
	cached_archives[normalized_path] = cached
	total_archives_loaded += 1
	cache_misses += 1
	
	DebugManager.log_info(DebugManager.Category.FILE_IO, "Loaded and cached VP archive: %s" % full_path)
	
	# Trim cache if necessary
	_trim_archive_cache()
	
	return archive

## Find archive in search paths
func _find_archive_in_search_paths(archive_name: String) -> String:
	# If it's already a full path, check if it exists
	if PlatformUtils.file_exists(archive_name):
		return archive_name
	
	# Search in all search paths
	for search_path: String in archive_search_paths:
		var full_path: String = search_path + archive_name
		if PlatformUtils.file_exists(full_path):
			return full_path
		
		# Also try with .vp extension if not present
		if not archive_name.ends_with(".vp"):
			var with_extension: String = search_path + archive_name + ".vp"
			if PlatformUtils.file_exists(with_extension):
				return with_extension
	
	return ""

## Get file from any loaded archive
func get_file_data(file_path: String) -> PackedByteArray:
	var normalized_path: String = file_path.replace("\\", "/").to_lower()
	
	# Search all cached archives
	for cached: CachedArchive in cached_archives.values():
		if cached.archive.has_file(normalized_path):
			# Check file cache first
			if cached.file_cache.has(normalized_path):
				var cached_file: CachedFile = cached.file_cache[normalized_path]
				cached_file.last_access_time = Time.get_unix_time_from_system()
				cached_file.access_count += 1
				cache_hits += 1
				total_files_accessed += 1
				return cached_file.data
			
			# Load file and cache it
			var file_data: PackedByteArray = cached.archive.get_file_data(normalized_path)
			if not file_data.is_empty():
				_cache_file_data(cached, normalized_path, file_data)
				cache_misses += 1
				total_files_accessed += 1
				return file_data
	
	DebugManager.log_warning(DebugManager.Category.FILE_IO, "File not found in any VP archive: %s" % file_path)
	return PackedByteArray()

## Cache file data
func _cache_file_data(cached_archive: CachedArchive, file_path: String, data: PackedByteArray) -> void:
	# Check cache size limits
	if cached_archive.file_cache.size() >= max_cached_files_per_archive:
		_trim_file_cache(cached_archive)
	
	var size_mb: float = data.size() / (1024.0 * 1024.0)
	if cached_archive.cache_size_bytes / (1024 * 1024) + size_mb > max_cache_size_mb:
		_trim_file_cache(cached_archive)
	
	# Cache the file
	var cached_file: CachedFile = CachedFile.new()
	cached_file.data = data
	cached_file.last_access_time = Time.get_unix_time_from_system()
	cached_file.access_count = 1
	cached_file.size_bytes = data.size()
	
	cached_archive.file_cache[file_path] = cached_file
	cached_archive.cache_size_bytes += data.size()
	
	DebugManager.log_trace(DebugManager.Category.FILE_IO, "Cached file data: %s (%d bytes)" % [file_path, data.size()])

## Open file for reading
func open_file(file_path: String) -> VPFileAccess:
	var normalized_path: String = file_path.replace("\\", "/").to_lower()
	
	# Search all cached archives
	for cached: CachedArchive in cached_archives.values():
		if cached.archive.has_file(normalized_path):
			cached.last_access_time = Time.get_unix_time_from_system()
			cached.access_count += 1
			return VPFileAccess.open(cached.archive, normalized_path)
	
	DebugManager.log_warning(DebugManager.Category.FILE_IO, "Cannot open file, not found in any VP archive: %s" % file_path)
	return null

## Check if file exists in any archive
func file_exists(file_path: String) -> bool:
	var normalized_path: String = file_path.replace("\\", "/").to_lower()
	
	for cached: CachedArchive in cached_archives.values():
		if cached.archive.has_file(normalized_path):
			return true
	
	return false

## Find files matching pattern across all archives
func find_files(pattern: String) -> PackedStringArray:
	var all_files: PackedStringArray = PackedStringArray()
	var found_files: Dictionary = {}  # Avoid duplicates
	
	for cached: CachedArchive in cached_archives.values():
		var archive_files: PackedStringArray = cached.archive.find_files(pattern)
		for file_path: String in archive_files:
			if not found_files.has(file_path):
				found_files[file_path] = true
				all_files.append(file_path)
	
	return all_files

## Discover and load all VP archives in search paths
func discover_archives() -> PackedStringArray:
	var discovered: PackedStringArray = PackedStringArray()
	
	for search_path: String in archive_search_paths:
		if not PlatformUtils.directory_exists(search_path):
			continue
		
		var vp_files: PackedStringArray = PlatformUtils.get_directory_files(search_path, "vp")
		for vp_file: String in vp_files:
			var full_path: String = search_path + vp_file
			var archive: VPArchive = load_archive(full_path)
			if archive != null:
				discovered.append(full_path)
	
	DebugManager.log_info(DebugManager.Category.FILE_IO, "Discovered %d VP archives" % discovered.size())
	return discovered

## Trim archive cache (LRU eviction)
func _trim_archive_cache() -> void:
	while cached_archives.size() > max_cached_archives:
		var oldest_time: float = Time.get_unix_time_from_system()
		var oldest_path: String = ""
		
		# Find least recently used archive
		for path: String in cached_archives.keys():
			var cached: CachedArchive = cached_archives[path]
			if cached.last_access_time < oldest_time:
				oldest_time = cached.last_access_time
				oldest_path = path
		
		if not oldest_path.is_empty():
			var cached: CachedArchive = cached_archives[oldest_path]
			cached.archive.close_archive()
			cached_archives.erase(oldest_path)
			DebugManager.log_debug(DebugManager.Category.FILE_IO, "Evicted archive from cache: %s" % oldest_path)

## Trim file cache for specific archive (LRU eviction)
func _trim_file_cache(cached_archive: CachedArchive) -> void:
	var files_to_remove: int = max(1, cached_archive.file_cache.size() - max_cached_files_per_archive + 1)
	
	# Create array of files sorted by access time
	var file_entries: Array[Dictionary] = []
	for file_path: String in cached_archive.file_cache.keys():
		var cached_file: CachedFile = cached_archive.file_cache[file_path]
		file_entries.append({
			"path": file_path,
			"time": cached_file.last_access_time,
			"size": cached_file.size_bytes
		})
	
	# Sort by access time (oldest first)
	file_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	
	# Remove oldest files
	for i: int in range(min(files_to_remove, file_entries.size())):
		var entry: Dictionary = file_entries[i]
		var file_path: String = entry["path"]
		cached_archive.file_cache.erase(file_path)
		cached_archive.cache_size_bytes -= entry["size"]
		DebugManager.log_trace(DebugManager.Category.FILE_IO, "Evicted file from cache: %s" % file_path)

## Get cache statistics
func get_cache_stats() -> Dictionary:
	var total_cached_files: int = 0
	var total_cache_size: int = 0
	
	for cached: CachedArchive in cached_archives.values():
		total_cached_files += cached.file_cache.size()
		total_cache_size += cached.cache_size_bytes
	
	var hit_rate: float = 0.0
	var total_requests: int = cache_hits + cache_misses
	if total_requests > 0:
		hit_rate = float(cache_hits) / float(total_requests)
	
	return {
		"cached_archives": cached_archives.size(),
		"total_cached_files": total_cached_files,
		"total_cache_size_mb": total_cache_size / (1024.0 * 1024.0),
		"total_archives_loaded": total_archives_loaded,
		"total_files_accessed": total_files_accessed,
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"cache_hit_rate": hit_rate,
		"search_paths": archive_search_paths
	}

## Clear all caches
func clear_caches() -> void:
	for cached: CachedArchive in cached_archives.values():
		cached.archive.close_archive()
	
	cached_archives.clear()
	cache_hits = 0
	cache_misses = 0
	
	DebugManager.log_info(DebugManager.Category.FILE_IO, "Cleared all VP archive caches")

## Preload important archives
func preload_archives(archive_names: PackedStringArray) -> void:
	DebugManager.log_info(DebugManager.Category.FILE_IO, "Preloading %d VP archives..." % archive_names.size())
	
	for archive_name: String in archive_names:
		var archive: VPArchive = load_archive(archive_name)
		if archive != null:
			DebugManager.log_debug(DebugManager.Category.FILE_IO, "Preloaded archive: %s" % archive_name)
		else:
			DebugManager.log_warning(DebugManager.Category.FILE_IO, "Failed to preload archive: %s" % archive_name)

## Shutdown manager
func shutdown() -> void:
	clear_caches()
	archive_search_paths.clear()
	DebugManager.log_info(DebugManager.Category.FILE_IO, "VPArchiveManager shutdown completed")
