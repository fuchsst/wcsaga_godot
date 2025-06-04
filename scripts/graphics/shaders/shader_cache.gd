class_name ShaderCache
extends RefCounted

## Shader compilation caching system for WCS effects
## Manages shader compilation results, hot-reload support, and performance optimization

signal shader_compilation_started(shader_path: String)
signal shader_compilation_completed(shader_path: String, success: bool)
signal shader_cache_cleared()
signal shader_hot_reloaded(shader_path: String)

var compiled_shaders: Dictionary = {}
var compilation_errors: Dictionary = {}
var shader_timestamps: Dictionary = {}
var compilation_stats: Dictionary = {}
var hot_reload_enabled: bool = false
var cache_dirty: bool = false

# Cache configuration
var max_cache_size: int = 100
var cache_file_path: String = "user://shader_cache.dat"
var enable_persistent_cache: bool = true

func _init() -> void:
	_initialize_cache()
	print("ShaderCache: Initialized with persistent caching")

## Initialize the shader cache system
func _initialize_cache() -> void:
	compilation_stats = {
		"total_compilations": 0,
		"successful_compilations": 0,
		"failed_compilations": 0,
		"cache_hits": 0,
		"cache_misses": 0,
		"average_compilation_time": 0.0,
		"total_compilation_time": 0.0
	}
	
	if enable_persistent_cache:
		_load_persistent_cache()

## Get a compiled shader from cache or compile if needed
func get_shader(shader_path: String) -> Shader:
	# Check if we have it cached
	if shader_path in compiled_shaders:
		compilation_stats["cache_hits"] += 1
		
		# Check for hot reload if enabled
		if hot_reload_enabled:
			if _should_reload_shader(shader_path):
				return _reload_shader(shader_path)
		
		return compiled_shaders[shader_path]
	
	# Cache miss - need to compile
	compilation_stats["cache_misses"] += 1
	return _compile_and_cache_shader(shader_path)

## Compile and cache a shader
func _compile_and_cache_shader(shader_path: String) -> Shader:
	shader_compilation_started.emit(shader_path)
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Check if shader file exists
	if not ResourceLoader.exists(shader_path):
		var error_msg: String = "Shader file not found: " + shader_path
		compilation_errors[shader_path] = error_msg
		compilation_stats["failed_compilations"] += 1
		push_error("ShaderCache: " + error_msg)
		shader_compilation_completed.emit(shader_path, false)
		return null
	
	# Load and compile shader
	var shader: Shader = load(shader_path)
	var end_time: float = Time.get_ticks_msec() / 1000.0
	var compilation_time: float = end_time - start_time
	
	compilation_stats["total_compilations"] += 1
	compilation_stats["total_compilation_time"] += compilation_time
	compilation_stats["average_compilation_time"] = compilation_stats["total_compilation_time"] / compilation_stats["total_compilations"]
	
	if shader:
		# Successfully compiled
		_store_in_cache(shader_path, shader)
		compilation_stats["successful_compilations"] += 1
		
		# Clear any previous errors
		if shader_path in compilation_errors:
			compilation_errors.erase(shader_path)
		
		print("ShaderCache: Compiled shader '%s' in %.3fs" % [shader_path.get_file(), compilation_time])
		shader_compilation_completed.emit(shader_path, true)
	else:
		# Compilation failed
		var error_msg: String = "Failed to compile shader: " + shader_path
		compilation_errors[shader_path] = error_msg
		compilation_stats["failed_compilations"] += 1
		push_error("ShaderCache: " + error_msg)
		shader_compilation_completed.emit(shader_path, false)
	
	return shader

## Store shader in cache
func _store_in_cache(shader_path: String, shader: Shader) -> void:
	# Check cache size limits
	if compiled_shaders.size() >= max_cache_size:
		_evict_oldest_shader()
	
	compiled_shaders[shader_path] = shader
	shader_timestamps[shader_path] = FileAccess.get_modified_time(shader_path)
	cache_dirty = true
	
	# Update persistent cache periodically
	if enable_persistent_cache and cache_dirty:
		_save_persistent_cache()

## Evict the oldest shader from cache
func _evict_oldest_shader() -> void:
	if compiled_shaders.is_empty():
		return
	
	var oldest_path: String = ""
	var oldest_time: int = 0
	
	for shader_path in shader_timestamps:
		var timestamp: int = shader_timestamps[shader_path]
		if oldest_path.is_empty() or timestamp < oldest_time:
			oldest_time = timestamp
			oldest_path = shader_path
	
	if not oldest_path.is_empty():
		compiled_shaders.erase(oldest_path)
		shader_timestamps.erase(oldest_path)
		print("ShaderCache: Evicted oldest shader: " + oldest_path.get_file())

## Check if a shader should be reloaded (hot reload)
func _should_reload_shader(shader_path: String) -> bool:
	if not hot_reload_enabled:
		return false
	
	if not shader_path in shader_timestamps:
		return true
	
	var cached_timestamp: int = shader_timestamps[shader_path]
	var current_timestamp: int = FileAccess.get_modified_time(shader_path)
	
	return current_timestamp > cached_timestamp

## Reload a shader for hot reload
func _reload_shader(shader_path: String) -> Shader:
	print("ShaderCache: Hot reloading shader: " + shader_path.get_file())
	
	# Remove from cache
	compiled_shaders.erase(shader_path)
	shader_timestamps.erase(shader_path)
	
	# Recompile
	var reloaded_shader: Shader = _compile_and_cache_shader(shader_path)
	
	if reloaded_shader:
		shader_hot_reloaded.emit(shader_path)
		print("ShaderCache: Hot reload successful: " + shader_path.get_file())
	else:
		print("ShaderCache: Hot reload failed: " + shader_path.get_file())
	
	return reloaded_shader

## Enable or disable hot reload functionality
func set_hot_reload_enabled(enabled: bool) -> void:
	hot_reload_enabled = enabled
	print("ShaderCache: Hot reload %s" % ("enabled" if enabled else "disabled"))

## Precompile a list of shaders
func precompile_shaders(shader_paths: Array[String]) -> Dictionary:
	var results: Dictionary = {
		"successful": [],
		"failed": [],
		"total_time": 0.0
	}
	
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	for shader_path in shader_paths:
		var shader: Shader = get_shader(shader_path)
		if shader:
			results["successful"].append(shader_path)
		else:
			results["failed"].append(shader_path)
	
	var end_time: float = Time.get_ticks_msec() / 1000.0
	results["total_time"] = end_time - start_time
	
	print("ShaderCache: Precompiled %d shaders (%d successful, %d failed) in %.3fs" % [
		shader_paths.size(), results["successful"].size(), results["failed"].size(), results["total_time"]
	])
	
	return results

## Get shader compilation error for a specific shader
func get_shader_error(shader_path: String) -> String:
	return compilation_errors.get(shader_path, "")

## Check if shader has compilation errors
func has_shader_error(shader_path: String) -> bool:
	return shader_path in compilation_errors

## Get all shader paths with compilation errors
func get_failed_shaders() -> Array[String]:
	return compilation_errors.keys()

## Clear specific shader from cache
func clear_shader(shader_path: String) -> bool:
	var had_shader: bool = shader_path in compiled_shaders
	
	compiled_shaders.erase(shader_path)
	shader_timestamps.erase(shader_path)
	compilation_errors.erase(shader_path)
	
	if had_shader:
		cache_dirty = true
		print("ShaderCache: Cleared shader from cache: " + shader_path.get_file())
	
	return had_shader

## Clear entire shader cache
func clear_cache() -> void:
	var shader_count: int = compiled_shaders.size()
	
	compiled_shaders.clear()
	shader_timestamps.clear()
	compilation_errors.clear()
	cache_dirty = true
	
	# Reset stats
	compilation_stats["cache_hits"] = 0
	compilation_stats["cache_misses"] = 0
	
	if enable_persistent_cache:
		_clear_persistent_cache()
	
	shader_cache_cleared.emit()
	print("ShaderCache: Cleared cache (%d shaders removed)" % shader_count)

## Get cache statistics
func get_cache_stats() -> Dictionary:
	var cache_stats: Dictionary = compilation_stats.duplicate()
	cache_stats.merge({
		"cached_shaders": compiled_shaders.size(),
		"shaders_with_errors": compilation_errors.size(),
		"cache_hit_rate": _calculate_hit_rate(),
		"max_cache_size": max_cache_size,
		"hot_reload_enabled": hot_reload_enabled,
		"persistent_cache_enabled": enable_persistent_cache
	})
	return cache_stats

## Calculate cache hit rate
func _calculate_hit_rate() -> float:
	var total_requests: int = compilation_stats["cache_hits"] + compilation_stats["cache_misses"]
	if total_requests == 0:
		return 0.0
	return float(compilation_stats["cache_hits"]) / float(total_requests) * 100.0

## Get list of all cached shader paths
func get_cached_shader_paths() -> Array[String]:
	return compiled_shaders.keys()

## Check if shader is cached
func is_shader_cached(shader_path: String) -> bool:
	return shader_path in compiled_shaders

## Save persistent cache to disk
func _save_persistent_cache() -> void:
	if not enable_persistent_cache:
		return
	
	var cache_data: Dictionary = {
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"shader_timestamps": shader_timestamps,
		"compilation_stats": compilation_stats
	}
	
	var file: FileAccess = FileAccess.open(cache_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cache_data))
		file.close()
		cache_dirty = false
		print("ShaderCache: Saved persistent cache (%d shaders)" % compiled_shaders.size())
	else:
		push_error("ShaderCache: Failed to save persistent cache to: " + cache_file_path)

## Load persistent cache from disk
func _load_persistent_cache() -> void:
	if not FileAccess.file_exists(cache_file_path):
		return
	
	var file: FileAccess = FileAccess.open(cache_file_path, FileAccess.READ)
	if not file:
		push_error("ShaderCache: Failed to open persistent cache file: " + cache_file_path)
		return
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	
	if parse_result != OK:
		push_error("ShaderCache: Failed to parse persistent cache JSON")
		return
	
	var cache_data: Dictionary = json.data as Dictionary
	
	# Validate cache version
	var version: String = cache_data.get("version", "")
	if version != "1.0":
		print("ShaderCache: Cache version mismatch, clearing old cache")
		_clear_persistent_cache()
		return
	
	# Restore shader timestamps and stats
	shader_timestamps = cache_data.get("shader_timestamps", {})
	compilation_stats.merge(cache_data.get("compilation_stats", {}))
	
	print("ShaderCache: Loaded persistent cache (%d shader timestamps)" % shader_timestamps.size())

## Clear persistent cache file
func _clear_persistent_cache() -> void:
	if FileAccess.file_exists(cache_file_path):
		DirAccess.remove_absolute(cache_file_path)
		print("ShaderCache: Cleared persistent cache file")

## Validate cache integrity
func validate_cache() -> Dictionary:
	var validation_results: Dictionary = {
		"valid_shaders": [],
		"invalid_shaders": [],
		"missing_files": [],
		"timestamp_mismatches": []
	}
	
	for shader_path in compiled_shaders.keys():
		# Check if file still exists
		if not ResourceLoader.exists(shader_path):
			validation_results["missing_files"].append(shader_path)
			continue
		
		# Check if shader is still valid
		var shader: Shader = compiled_shaders[shader_path]
		if not shader:
			validation_results["invalid_shaders"].append(shader_path)
			continue
		
		# Check timestamp for changes
		if shader_path in shader_timestamps:
			var cached_timestamp: int = shader_timestamps[shader_path]
			var current_timestamp: int = FileAccess.get_modified_time(shader_path)
			if current_timestamp > cached_timestamp:
				validation_results["timestamp_mismatches"].append(shader_path)
				continue
		
		validation_results["valid_shaders"].append(shader_path)
	
	print("ShaderCache: Cache validation - Valid: %d, Invalid: %d, Missing: %d, Changed: %d" % [
		validation_results["valid_shaders"].size(),
		validation_results["invalid_shaders"].size(),
		validation_results["missing_files"].size(),
		validation_results["timestamp_mismatches"].size()
	])
	
	return validation_results

## Clean up invalid cache entries
func cleanup_invalid_entries() -> int:
	var validation: Dictionary = validate_cache()
	var cleaned_count: int = 0
	
	# Remove missing files
	for shader_path in validation["missing_files"]:
		clear_shader(shader_path)
		cleaned_count += 1
	
	# Remove invalid shaders
	for shader_path in validation["invalid_shaders"]:
		clear_shader(shader_path)
		cleaned_count += 1
	
	if cleaned_count > 0:
		print("ShaderCache: Cleaned up %d invalid cache entries" % cleaned_count)
	
	return cleaned_count

## Set maximum cache size
func set_max_cache_size(new_max_size: int) -> void:
	max_cache_size = max(1, new_max_size)
	
	# Evict excess shaders if needed
	while compiled_shaders.size() > max_cache_size:
		_evict_oldest_shader()
	
	print("ShaderCache: Max cache size set to %d" % max_cache_size)

## Enable or disable persistent caching
func set_persistent_cache_enabled(enabled: bool) -> void:
	enable_persistent_cache = enabled
	
	if enabled and cache_dirty:
		_save_persistent_cache()
	elif not enabled:
		_clear_persistent_cache()
	
	print("ShaderCache: Persistent caching %s" % ("enabled" if enabled else "disabled"))