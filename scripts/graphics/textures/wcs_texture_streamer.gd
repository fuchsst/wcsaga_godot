class_name WCSTextureStreamer
extends Node

## Dynamic texture streaming and management system for WCS-Godot
## Provides efficient texture loading, caching, and memory management

signal texture_loaded(texture_path: String, texture: Texture2D)
signal texture_loading_started(texture_path: String, priority: int)
signal texture_loading_failed(texture_path: String, error: String)
signal texture_unloaded(texture_path: String)
signal memory_usage_updated(vram_mb: int, system_mb: int)
signal memory_pressure_detected(usage_percent: float)
signal cache_size_changed(texture_count: int, memory_mb: int)
signal texture_quality_changed(quality_level: int)
signal texture_compression_completed(texture_path: String, compression_ratio: float)

# Texture cache and management
var texture_cache: Dictionary = {}
var texture_metadata: Dictionary = {}
var loading_queue: Array[String] = []
var priority_queue: Array[Dictionary] = []

# Memory management
var cache_size_limit: int = 512 * 1024 * 1024  # 512 MB default
var system_memory_limit: int = 256 * 1024 * 1024  # 256 MB system memory
var current_cache_size: int = 0
var current_system_memory: int = 0
var memory_pressure_threshold: float = 0.85  # 85% usage triggers pressure

# Quality settings
var current_quality_level: int = 2  # Medium quality default
var quality_settings: Dictionary = {}

# Loading management
var is_loading: bool = false
var max_concurrent_loads: int = 3
var active_loads: int = 0

# Performance tracking
var load_time_tracker: Dictionary = {}
var cache_hit_stats: Dictionary = {"hits": 0, "misses": 0}

func _ready() -> void:
	name = "WCSTextureStreamer"
	_initialize_quality_settings()
	_start_memory_monitoring()
	print("WCSTextureStreamer: Initialized with %d MB cache limit" % (cache_size_limit / (1024 * 1024)))

func _initialize_quality_settings() -> void:
	quality_settings = {
		0: {"scale": 0.25, "compression": true, "mipmap": false},   # Ultra Low
		1: {"scale": 0.5, "compression": true, "mipmap": true},    # Low
		2: {"scale": 0.75, "compression": false, "mipmap": true},  # Medium
		3: {"scale": 1.0, "compression": false, "mipmap": true},   # High
		4: {"scale": 1.0, "compression": false, "mipmap": true}    # Ultra
	}

func _start_memory_monitoring() -> void:
	# Monitor memory usage every 2 seconds
	var timer: Timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_update_memory_statistics)
	add_child(timer)

func load_texture(texture_path: String, priority: int = 5) -> Texture2D:
	# Check cache first
	if texture_path in texture_cache:
		_update_texture_access_time(texture_path)
		cache_hit_stats.hits += 1
		return texture_cache[texture_path]
	
	cache_hit_stats.misses += 1
	
	# Check if already in loading queue
	if texture_path in loading_queue:
		return null  # Will be available soon
	
	# Add to priority queue for loading
	var load_request: Dictionary = {
		"path": texture_path,
		"priority": priority,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	priority_queue.append(load_request)
	priority_queue.sort_custom(_compare_load_priority)
	loading_queue.append(texture_path)
	
	texture_loading_started.emit(texture_path, priority)
	
	# Start loading if not at capacity
	if active_loads < max_concurrent_loads:
		_process_loading_queue()
	
	return null

func load_texture_sync(texture_path: String) -> Texture2D:
	# Synchronous loading for critical textures
	if texture_path in texture_cache:
		_update_texture_access_time(texture_path)
		return texture_cache[texture_path]
	
	var texture: Texture2D = _load_texture_from_file(texture_path)
	if texture:
		_cache_texture(texture_path, texture)
		texture_loaded.emit(texture_path, texture)
	
	return texture

func preload_textures(texture_paths: Array[String], priority: int = 3) -> void:
	# Preload a batch of textures
	print("WCSTextureStreamer: Preloading %d textures" % texture_paths.size())
	
	for texture_path in texture_paths:
		if texture_path not in texture_cache and texture_path not in loading_queue:
			load_texture(texture_path, priority)

func unload_texture(texture_path: String) -> void:
	if texture_path in texture_cache:
		var texture: Texture2D = texture_cache[texture_path]
		var texture_size: int = _estimate_texture_memory_size(texture)
		
		texture_cache.erase(texture_path)
		texture_metadata.erase(texture_path)
		current_cache_size -= texture_size
		
		texture_unloaded.emit(texture_path)
		cache_size_changed.emit(texture_cache.size(), current_cache_size / (1024 * 1024))

func set_quality_level(quality_level: int) -> void:
	if quality_level < 0 or quality_level >= quality_settings.size():
		push_error("Invalid quality level: " + str(quality_level))
		return
	
	if quality_level == current_quality_level:
		return
	
	var old_quality: int = current_quality_level
	current_quality_level = quality_level
	
	print("WCSTextureStreamer: Quality changed from %d to %d" % [old_quality, quality_level])
	texture_quality_changed.emit(quality_level)
	
	# Optionally reload textures with new quality settings
	if quality_level > old_quality:
		_upgrade_cached_textures()
	elif quality_level < old_quality:
		_downgrade_cached_textures()

func get_cache_statistics() -> Dictionary:
	return {
		"cache_size_mb": current_cache_size / (1024 * 1024),
		"cache_limit_mb": cache_size_limit / (1024 * 1024),
		"texture_count": texture_cache.size(),
		"cache_hit_rate": float(cache_hit_stats.hits) / max(1, cache_hit_stats.hits + cache_hit_stats.misses),
		"loading_queue_size": loading_queue.size(),
		"active_loads": active_loads,
		"memory_pressure": get_memory_pressure_level()
	}

func get_memory_pressure_level() -> float:
	var vram_pressure: float = float(current_cache_size) / cache_size_limit
	var system_pressure: float = float(current_system_memory) / system_memory_limit
	return max(vram_pressure, system_pressure)

func clear_cache() -> void:
	var cleared_count: int = texture_cache.size()
	texture_cache.clear()
	texture_metadata.clear()
	current_cache_size = 0
	
	print("WCSTextureStreamer: Cleared %d textures from cache" % cleared_count)
	cache_size_changed.emit(0, 0)

func _process_loading_queue() -> void:
	if priority_queue.is_empty() or active_loads >= max_concurrent_loads:
		return
	
	var load_request: Dictionary = priority_queue.pop_front()
	var texture_path: String = load_request.path
	
	active_loads += 1
	
	# Load texture asynchronously
	_load_texture_async(texture_path)

func _load_texture_async(texture_path: String) -> void:
	# Simulate async loading by deferring to next frame
	await get_tree().process_frame
	
	var start_time: float = Time.get_ticks_msec()
	var texture: Texture2D = _load_texture_from_file(texture_path)
	var load_time: float = Time.get_ticks_msec() - start_time
	
	active_loads -= 1
	loading_queue.erase(texture_path)
	
	if texture:
		_cache_texture(texture_path, texture)
		texture_loaded.emit(texture_path, texture)
		
		# Track loading performance
		load_time_tracker[texture_path] = load_time
		
		print("WCSTextureStreamer: Loaded texture %s in %.1fms" % [texture_path.get_file(), load_time])
	else:
		texture_loading_failed.emit(texture_path, "Failed to load texture file")
		push_warning("Failed to load texture: " + texture_path)
	
	# Process next item in queue
	if not priority_queue.is_empty():
		_process_loading_queue()

func _load_texture_from_file(texture_path: String) -> Texture2D:
	var texture: Texture2D = null
	
	# Try loading through ResourceLoader first
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path) as Texture2D
	elif FileAccess.file_exists(texture_path):
		# Load as image file and convert to texture
		var image: Image = Image.new()
		var error: Error = image.load(texture_path)
		
		if error == OK:
			# Apply quality settings
			_apply_image_quality_settings(image)
			
			texture = ImageTexture.new()
			texture.create_from_image(image)
		else:
			push_error("Failed to load image: " + texture_path + " (Error: " + str(error) + ")")
	else:
		push_warning("Texture file not found: " + texture_path)
	
	return texture

func _apply_image_quality_settings(image: Image) -> void:
	var quality: Dictionary = quality_settings[current_quality_level]
	
	# Scale image if needed
	if quality.scale < 1.0:
		var new_width: int = int(image.get_width() * quality.scale)
		var new_height: int = int(image.get_height() * quality.scale)
		image.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
	
	# Apply compression if enabled
	if quality.compression:
		# For now, just convert to RGB8 format for compression
		image.convert(Image.FORMAT_RGB8)
	
	# Generate mipmaps if enabled
	if quality.mipmap and not image.has_mipmaps():
		image.generate_mipmaps()

func _cache_texture(texture_path: String, texture: Texture2D) -> void:
	# Check if cache is full
	var texture_size: int = _estimate_texture_memory_size(texture)
	
	while current_cache_size + texture_size > cache_size_limit and not texture_cache.is_empty():
		_evict_least_recently_used()
	
	# Add to cache
	texture_cache[texture_path] = texture
	texture_metadata[texture_path] = {
		"size": texture_size,
		"last_access": Time.get_unix_time_from_system(),
		"load_time": load_time_tracker.get(texture_path, 0.0),
		"quality_level": current_quality_level
	}
	
	current_cache_size += texture_size
	cache_size_changed.emit(texture_cache.size(), current_cache_size / (1024 * 1024))

func _evict_least_recently_used() -> void:
	if texture_cache.is_empty():
		return
	
	var oldest_path: String = ""
	var oldest_time: float = INF
	
	for texture_path in texture_metadata:
		var last_access: float = texture_metadata[texture_path].last_access
		if last_access < oldest_time:
			oldest_time = last_access
			oldest_path = texture_path
	
	if not oldest_path.is_empty():
		print("WCSTextureStreamer: Evicting LRU texture: ", oldest_path.get_file())
		unload_texture(oldest_path)

func _update_texture_access_time(texture_path: String) -> void:
	if texture_path in texture_metadata:
		texture_metadata[texture_path].last_access = Time.get_unix_time_from_system()

func _estimate_texture_memory_size(texture: Texture2D) -> int:
	if texture is ImageTexture:
		var image: Image = texture.get_image()
		if image:
			var pixel_count: int = image.get_width() * image.get_height()
			var bytes_per_pixel: int = _get_bytes_per_pixel(image.get_format())
			var mipmap_factor: float = 1.33 if image.has_mipmaps() else 1.0
			return int(pixel_count * bytes_per_pixel * mipmap_factor)
	
	# Fallback estimate
	return 1024 * 1024  # 1MB default

func _get_bytes_per_pixel(format: Image.Format) -> int:
	match format:
		Image.FORMAT_L8, Image.FORMAT_R8:
			return 1
		Image.FORMAT_LA8, Image.FORMAT_RG8:
			return 2
		Image.FORMAT_RGB8:
			return 3
		Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBA4444, Image.FORMAT_RGBA5551:
			return 4
		_:
			return 4  # Default to 4 bytes

func _compare_load_priority(a: Dictionary, b: Dictionary) -> bool:
	# Higher priority first, then older timestamp
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.timestamp < b.timestamp

func _update_memory_statistics() -> void:
	# Update memory usage statistics
	var old_cache_size: int = current_cache_size
	current_cache_size = 0
	
	# Recalculate cache size
	for texture_path in texture_cache:
		var texture: Texture2D = texture_cache[texture_path]
		current_cache_size += _estimate_texture_memory_size(texture)
	
	# Estimate system memory usage (rough approximation)
	current_system_memory = current_cache_size / 2  # Rough estimate
	
	# Emit memory usage update
	memory_usage_updated.emit(
		current_cache_size / (1024 * 1024),
		current_system_memory / (1024 * 1024)
	)
	
	# Check for memory pressure
	var pressure_level: float = get_memory_pressure_level()
	if pressure_level > memory_pressure_threshold:
		memory_pressure_detected.emit(pressure_level)
		_handle_memory_pressure()

func _handle_memory_pressure() -> void:
	print("WCSTextureStreamer: Memory pressure detected, cleaning up cache")
	
	# More aggressive LRU eviction
	var target_size: int = int(cache_size_limit * 0.7)  # Target 70% of limit
	
	while current_cache_size > target_size and not texture_cache.is_empty():
		_evict_least_recently_used()
	
	# If still under pressure, consider reducing quality
	if get_memory_pressure_level() > memory_pressure_threshold and current_quality_level > 1:
		set_quality_level(current_quality_level - 1)

func _upgrade_cached_textures() -> void:
	# Re-load cached textures with higher quality (expensive operation)
	print("WCSTextureStreamer: Upgrading cached textures to quality level ", current_quality_level)
	
	var texture_paths: Array[String] = []
	for path in texture_cache.keys():
		texture_paths.append(path)
	
	# Clear cache and reload with new quality
	clear_cache()
	preload_textures(texture_paths, 7)  # High priority for upgrades

func _downgrade_cached_textures() -> void:
	# Re-load cached textures with lower quality to save memory
	print("WCSTextureStreamer: Downgrading cached textures to quality level ", current_quality_level)
	
	var texture_paths: Array[String] = []
	for path in texture_cache.keys():
		if texture_metadata[path].quality_level > current_quality_level:
			texture_paths.append(path)
	
	# Reload only textures that were higher quality
	for path in texture_paths:
		unload_texture(path)
		load_texture(path, 5)  # Normal priority for downgrades

func set_cache_size_limit(size_mb: int) -> void:
	cache_size_limit = size_mb * 1024 * 1024
	print("WCSTextureStreamer: Cache size limit set to %d MB" % size_mb)
	
	# If current cache exceeds new limit, evict textures
	while current_cache_size > cache_size_limit and not texture_cache.is_empty():
		_evict_least_recently_used()

func get_texture_info(texture_path: String) -> Dictionary:
	if texture_path in texture_metadata:
		var info: Dictionary = texture_metadata[texture_path].duplicate()
		info["cached"] = true
		info["texture"] = texture_cache.get(texture_path)
		return info
	else:
		return {"cached": false, "exists": FileAccess.file_exists(texture_path)}

func warm_cache_for_scene(scene_textures: Array[String]) -> void:
	# Preload textures commonly used in a scene
	print("WCSTextureStreamer: Warming cache for scene with %d textures" % scene_textures.size())
	preload_textures(scene_textures, 8)  # Very high priority for scene warming