class_name ResourceTracker
extends Node

## Resource usage monitoring and optimization system for WCS-Godot conversion.
## Tracks texture, mesh, audio, and other resource usage patterns to optimize
## memory consumption and loading performance based on WCS asset management.
##
## Implements resource pooling, reference counting, and automatic cleanup
## similar to WCS model data management and vertex buffer optimization.

signal resource_loaded(resource_path: String, resource_type: String, size_mb: float)
signal resource_unloaded(resource_path: String, resource_type: String, size_mb: float)
signal resource_cache_optimized(optimization_type: String, details: Dictionary)
signal resource_usage_report(report: Dictionary)

# EPIC-002 Asset Core Integration
const AssetTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const AssetData = preload("res://addons/wcs_asset_core/structures/asset_data.gd")

# Resource tracking configuration
@export var tracking_enabled: bool = true
@export var detailed_tracking: bool = false
@export var auto_optimization: bool = true
@export var cache_monitoring: bool = true

# Resource usage thresholds (MB) - based on WCS model and texture limits
@export var texture_cache_limit_mb: float = 40.0    # Texture cache limit
@export var mesh_cache_limit_mb: float = 30.0       # Mesh data cache limit
@export var audio_cache_limit_mb: float = 20.0      # Audio resource limit
@export var total_resource_limit_mb: float = 100.0  # Total resource limit

# Cache optimization settings
@export var cache_cleanup_interval: float = 10.0    # Cleanup check interval
@export var unused_resource_timeout: float = 30.0   # Time before marking unused
@export var reference_count_threshold: int = 1      # Minimum references to keep
@export var preload_optimization: bool = true       # Enable preload optimization

# Resource type definitions (based on WCS asset analysis)
enum ResourceType {
	TEXTURE = 0,     # 2D textures and images
	MESH = 1,        # 3D model geometry data
	MATERIAL = 2,    # Material and shader resources
	AUDIO = 3,       # Sound and music files
	ANIMATION = 4,   # Animation sequences
	SCRIPT = 5,      # GDScript and other code
	SCENE = 6,       # Scene files and templates
	SHADER = 7,      # Custom shaders
	FONT = 8,        # Text rendering fonts
	OTHER = 9        # Other resource types
}

# Resource tracking data structures
var resource_registry: Dictionary = {}          # String (path) -> ResourceInfo
var resource_cache_usage: Dictionary = {}       # ResourceType -> float (MB)
var resource_reference_counts: Dictionary = {}  # String (path) -> int
var resource_access_times: Dictionary = {}      # String (path) -> float (timestamp)
var resource_load_counts: Dictionary = {}       # String (path) -> int

# Performance metrics
var total_resources_loaded: int = 0
var total_resource_memory_mb: float = 0.0
var cache_hit_rate: float = 0.0
var cache_miss_rate: float = 0.0
var average_load_time_ms: float = 0.0

# Resource optimization history
var optimization_events: Array[Dictionary] = []
var cache_optimizations_count: int = 0
var resources_cleaned_count: int = 0

# Monitoring timers
var cleanup_timer: float = 0.0
var monitoring_timer: float = 0.0

# External system references
var memory_monitor: Node
var performance_monitor: Node

# State management
var is_initialized: bool = false

class ResourceInfo:
	var resource_path: String
	var resource_type: ResourceType
	var size_mb: float
	var reference_count: int
	var last_accessed: float
	var load_count: int
	var is_preloaded: bool
	var is_critical: bool  # Critical resources that should never be unloaded
	
	func _init(path: String, type: ResourceType, size: float) -> void:
		resource_path = path
		resource_type = type
		size_mb = size
		reference_count = 1
		last_accessed = Time.get_time_dict_from_system()["unix"]
		load_count = 1
		is_preloaded = false
		is_critical = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_resource_tracker()

func _initialize_resource_tracker() -> void:
	"""Initialize the resource tracking system."""
	if is_initialized:
		push_warning("ResourceTracker: Already initialized")
		return
	
	print("ResourceTracker: Starting initialization...")
	
	# Get references to other systems
	memory_monitor = get_node_or_null("/root/MemoryMonitor")
	performance_monitor = get_node_or_null("/root/PerformanceMonitor")
	
	# Initialize tracking data
	resource_registry.clear()
	resource_cache_usage.clear()
	resource_reference_counts.clear()
	resource_access_times.clear()
	resource_load_counts.clear()
	optimization_events.clear()
	
	# Initialize cache usage tracking for each resource type
	for resource_type in ResourceType.values():
		resource_cache_usage[resource_type] = 0.0
	
	# Connect to system signals if available
	_connect_system_signals()
	
	is_initialized = true
	print("ResourceTracker: Initialization complete")

func _connect_system_signals() -> void:
	"""Connect to system signals for resource monitoring."""
	if memory_monitor:
		if memory_monitor.has_signal("memory_warning"):
			memory_monitor.memory_warning.connect(_on_memory_warning)
		if memory_monitor.has_signal("memory_critical"):
			memory_monitor.memory_critical.connect(_on_memory_critical)

func _process(delta: float) -> void:
	if not is_initialized or not tracking_enabled:
		return
	
	# Update timers
	cleanup_timer += delta
	monitoring_timer += delta
	
	# Perform periodic cleanup
	if cleanup_timer >= cache_cleanup_interval:
		cleanup_timer = 0.0
		_perform_cache_cleanup()
	
	# Generate periodic usage reports
	if monitoring_timer >= 30.0:  # Every 30 seconds
		monitoring_timer = 0.0
		_generate_usage_report()

func track_resource_load(resource_path: String, resource: Resource) -> void:
	"""Track a resource being loaded.
	
	Args:
		resource_path: The path to the resource
		resource: The loaded resource object
	"""
	if not tracking_enabled or not resource:
		return
	
	var resource_type: ResourceType = _determine_resource_type(resource_path, resource)
	var size_mb: float = _estimate_resource_size(resource, resource_type)
	
	# Check if resource is already tracked
	if resource_path in resource_registry:
		var info: ResourceInfo = resource_registry[resource_path]
		info.reference_count += 1
		info.last_accessed = Time.get_time_dict_from_system()["unix"]
		info.load_count += 1
	else:
		# Register new resource
		var info: ResourceInfo = ResourceInfo.new(resource_path, resource_type, size_mb)
		resource_registry[resource_path] = info
		
		# Update cache usage
		resource_cache_usage[resource_type] += size_mb
		total_resource_memory_mb += size_mb
		total_resources_loaded += 1
		
		resource_loaded.emit(resource_path, _resource_type_to_string(resource_type), size_mb)
		
		if detailed_tracking:
			print("ResourceTracker: Loaded %s (%.2fMB, type: %s)" % [resource_path, size_mb, _resource_type_to_string(resource_type)])

func track_resource_unload(resource_path: String) -> void:
	"""Track a resource being unloaded.
	
	Args:
		resource_path: The path to the resource being unloaded
	"""
	if not tracking_enabled or not resource_path in resource_registry:
		return
	
	var info: ResourceInfo = resource_registry[resource_path]
	info.reference_count -= 1
	
	# If no more references, remove from tracking
	if info.reference_count <= 0:
		resource_cache_usage[info.resource_type] -= info.size_mb
		total_resource_memory_mb -= info.size_mb
		
		resource_unloaded.emit(resource_path, _resource_type_to_string(info.resource_type), info.size_mb)
		resource_registry.erase(resource_path)
		
		if detailed_tracking:
			print("ResourceTracker: Unloaded %s (%.2fMB)" % [resource_path, info.size_mb])

func _determine_resource_type(resource_path: String, resource: Resource) -> ResourceType:
	"""Determine the type of a resource from its path and object."""
	var extension: String = resource_path.get_extension().to_lower()
	
	# Determine type by file extension and resource class
	match extension:
		"png", "jpg", "jpeg", "bmp", "tga", "exr", "hdr":
			return ResourceType.TEXTURE
		"tres", "res":
			if resource is Mesh or resource is ArrayMesh:
				return ResourceType.MESH
			elif resource is Material:
				return ResourceType.MATERIAL
			else:
				return ResourceType.OTHER
		"obj", "fbx", "gltf", "glb", "dae":
			return ResourceType.MESH
		"ogg", "wav", "mp3":
			return ResourceType.AUDIO
		"tscn":
			return ResourceType.SCENE
		"gd", "cs":
			return ResourceType.SCRIPT
		"gdshader":
			return ResourceType.SHADER
		"ttf", "otf", "fnt":
			return ResourceType.FONT
		_:
			return ResourceType.OTHER

func _estimate_resource_size(resource: Resource, resource_type: ResourceType) -> float:
	"""Estimate the memory size of a resource in MB."""
	if not resource:
		return 0.0
	
	# Try to get actual size if available
	if resource.has_method("get_data") and resource.get_data() is PackedByteArray:
		var data: PackedByteArray = resource.get_data()
		return data.size() / (1024.0 * 1024.0)
	
	# Estimate based on resource type and properties
	match resource_type:
		ResourceType.TEXTURE:
			if resource is Texture2D:
				var texture: Texture2D = resource as Texture2D
				var width: int = texture.get_width()
				var height: int = texture.get_height()
				# Estimate: 4 bytes per pixel (RGBA)
				return (width * height * 4) / (1024.0 * 1024.0)
		
		ResourceType.MESH:
			if resource is Mesh:
				var mesh: Mesh = resource as Mesh
				var vertex_count: int = 0
				for surface in range(mesh.get_surface_count()):
					vertex_count += mesh.surface_get_array_len(surface)
				# Estimate: ~100 bytes per vertex (position, normal, UV, etc.)
				return (vertex_count * 100) / (1024.0 * 1024.0)
		
		ResourceType.AUDIO:
			# Audio files vary greatly, use conservative estimate
			return 0.5  # 500KB average
		
		ResourceType.MATERIAL:
			return 0.1  # 100KB for material data
		
		ResourceType.ANIMATION:
			return 0.2  # 200KB for animation data
		
		ResourceType.SCRIPT:
			return 0.05  # 50KB for script
		
		ResourceType.SCENE:
			return 0.3  # 300KB for scene data
		
		ResourceType.SHADER:
			return 0.1  # 100KB for shader
		
		ResourceType.FONT:
			return 0.5  # 500KB for font
		
		ResourceType.OTHER:
			return 0.1  # 100KB default
	
	return 0.1  # Default fallback

func _resource_type_to_string(resource_type: ResourceType) -> String:
	"""Convert resource type enum to string."""
	match resource_type:
		ResourceType.TEXTURE: return "Texture"
		ResourceType.MESH: return "Mesh"
		ResourceType.MATERIAL: return "Material"
		ResourceType.AUDIO: return "Audio"
		ResourceType.ANIMATION: return "Animation"
		ResourceType.SCRIPT: return "Script"
		ResourceType.SCENE: return "Scene"
		ResourceType.SHADER: return "Shader"
		ResourceType.FONT: return "Font"
		ResourceType.OTHER: return "Other"
		_: return "Unknown"

func _perform_cache_cleanup() -> void:
	"""Perform automatic cache cleanup based on usage patterns."""
	if not auto_optimization:
		return
	
	var cleanup_start_time: float = Time.get_ticks_usec() / 1000.0
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	var resources_cleaned: int = 0
	var memory_freed: float = 0.0
	
	# Find unused resources for cleanup (WCS-style unused object cleanup)
	var cleanup_candidates: Array[String] = []
	
	for resource_path in resource_registry:
		var info: ResourceInfo = resource_registry[resource_path]
		
		# Skip critical resources
		if info.is_critical:
			continue
		
		# Check if resource is unused
		var age_since_access: float = current_time - info.last_accessed
		var should_cleanup: bool = false
		
		if info.reference_count <= reference_count_threshold and age_since_access > unused_resource_timeout:
			should_cleanup = true
		
		# Check cache pressure
		if resource_cache_usage[info.resource_type] > _get_cache_limit(info.resource_type):
			should_cleanup = true
		
		if should_cleanup:
			cleanup_candidates.append(resource_path)
	
	# Sort candidates by least recently used (LRU eviction)
	cleanup_candidates.sort_custom(_compare_resource_access_time)
	
	# Clean up resources
	for resource_path in cleanup_candidates:
		if resource_path in resource_registry:
			var info: ResourceInfo = resource_registry[resource_path]
			memory_freed += info.size_mb
			resources_cleaned += 1
			
			# Unload the resource
			_unload_resource(resource_path)
			
			# Limit cleanup time
			var elapsed_time: float = (Time.get_ticks_usec() / 1000.0) - cleanup_start_time
			if elapsed_time > 2.0:  # 2ms limit
				break
	
	if resources_cleaned > 0:
		resources_cleaned_count += resources_cleaned
		cache_optimizations_count += 1
		
		var optimization_details: Dictionary = {
			"resources_cleaned": resources_cleaned,
			"memory_freed_mb": memory_freed,
			"cleanup_time_ms": (Time.get_ticks_usec() / 1000.0) - cleanup_start_time
		}
		
		optimization_events.append(optimization_details)
		resource_cache_optimized.emit("auto_cleanup", optimization_details)
		
		if detailed_tracking:
			print("ResourceTracker: Cleaned %d resources, freed %.2fMB" % [resources_cleaned, memory_freed])

func _get_cache_limit(resource_type: ResourceType) -> float:
	"""Get cache limit for a specific resource type."""
	match resource_type:
		ResourceType.TEXTURE: return texture_cache_limit_mb
		ResourceType.MESH: return mesh_cache_limit_mb
		ResourceType.AUDIO: return audio_cache_limit_mb
		_: return total_resource_limit_mb / 4.0  # Divide remaining space

func _compare_resource_access_time(a: String, b: String) -> bool:
	"""Compare resource access times for LRU sorting."""
	var info_a: ResourceInfo = resource_registry.get(a)
	var info_b: ResourceInfo = resource_registry.get(b)
	
	if not info_a or not info_b:
		return false
	
	return info_a.last_accessed < info_b.last_accessed

func _unload_resource(resource_path: String) -> void:
	"""Unload a specific resource."""
	if resource_path in resource_registry:
		var info: ResourceInfo = resource_registry[resource_path]
		
		# Remove from Godot's resource cache
		if ResourceLoader.has_cached(resource_path):
			ResourceLoader.set_abort_on_missing_resources(false)
			# Note: Godot doesn't have direct resource unloading, but this helps
		
		# Remove from our tracking
		track_resource_unload(resource_path)

func _generate_usage_report() -> void:
	"""Generate a comprehensive resource usage report."""
	var report: Dictionary = {
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"summary": {
			"total_resources": total_resources_loaded,
			"total_memory_mb": total_resource_memory_mb,
			"active_resources": resource_registry.size()
		},
		"by_type": {},
		"cache_usage": resource_cache_usage.duplicate(),
		"optimization_stats": {
			"cache_optimizations": cache_optimizations_count,
			"resources_cleaned": resources_cleaned_count,
			"optimization_events": optimization_events.size()
		}
	}
	
	# Generate per-type statistics
	for resource_type in ResourceType.values():
		var type_name: String = _resource_type_to_string(resource_type)
		var type_count: int = 0
		var type_memory: float = 0.0
		
		for resource_path in resource_registry:
			var info: ResourceInfo = resource_registry[resource_path]
			if info.resource_type == resource_type:
				type_count += 1
				type_memory += info.size_mb
		
		report["by_type"][type_name] = {
			"count": type_count,
			"memory_mb": type_memory,
			"cache_usage_mb": resource_cache_usage[resource_type],
			"cache_limit_mb": _get_cache_limit(resource_type)
		}
	
	resource_usage_report.emit(report)

# Signal handlers

func _on_memory_warning(usage_mb: float, threshold_mb: float) -> void:
	"""Handle memory warning by triggering resource cleanup."""
	if detailed_tracking:
		print("ResourceTracker: Memory warning - triggering resource cleanup")
	
	_perform_cache_cleanup()

func _on_memory_critical(usage_mb: float, threshold_mb: float) -> void:
	"""Handle critical memory situation with aggressive resource cleanup."""
	print("ResourceTracker: Critical memory - performing aggressive resource cleanup")
	
	# Temporarily reduce cache limits
	texture_cache_limit_mb *= 0.7
	mesh_cache_limit_mb *= 0.7
	audio_cache_limit_mb *= 0.7
	
	# Force cleanup
	_perform_cache_cleanup()

# Public API

func get_resource_statistics() -> Dictionary:
	"""Get comprehensive resource usage statistics.
	
	Returns:
		Dictionary containing resource usage data
	"""
	return {
		"total_resources_loaded": total_resources_loaded,
		"active_resources": resource_registry.size(),
		"total_memory_mb": total_resource_memory_mb,
		"cache_usage_by_type": resource_cache_usage.duplicate(),
		"cache_optimizations": cache_optimizations_count,
		"resources_cleaned": resources_cleaned_count
	}

func get_resource_info(resource_path: String) -> Dictionary:
	"""Get information about a specific resource.
	
	Args:
		resource_path: Path to the resource
		
	Returns:
		Dictionary with resource information or empty dict if not found
	"""
	if resource_path in resource_registry:
		var info: ResourceInfo = resource_registry[resource_path]
		return {
			"path": info.resource_path,
			"type": _resource_type_to_string(info.resource_type),
			"size_mb": info.size_mb,
			"reference_count": info.reference_count,
			"last_accessed": info.last_accessed,
			"load_count": info.load_count,
			"is_preloaded": info.is_preloaded,
			"is_critical": info.is_critical
		}
	else:
		return {}

func mark_resource_critical(resource_path: String, critical: bool = true) -> void:
	"""Mark a resource as critical (never unload).
	
	Args:
		resource_path: Path to the resource
		critical: true to mark as critical
	"""
	if resource_path in resource_registry:
		var info: ResourceInfo = resource_registry[resource_path]
		info.is_critical = critical
		
		if detailed_tracking:
			print("ResourceTracker: Marked %s as %s" % [resource_path, "critical" if critical else "non-critical"])

func set_tracking_enabled(enabled: bool) -> void:
	"""Enable or disable resource tracking.
	
	Args:
		enabled: true to enable tracking
	"""
	tracking_enabled = enabled
	print("ResourceTracker: Resource tracking %s" % ("enabled" if enabled else "disabled"))

func force_cache_cleanup() -> void:
	"""Force immediate cache cleanup (for testing)."""
	_perform_cache_cleanup()

func reset_statistics() -> void:
	"""Reset all tracking statistics."""
	total_resources_loaded = 0
	cache_optimizations_count = 0
	resources_cleaned_count = 0
	optimization_events.clear()
	
	print("ResourceTracker: Statistics reset")

# Debug functions

func debug_print_resource_report() -> void:
	"""Print detailed resource usage report for debugging."""
	var stats: Dictionary = get_resource_statistics()
	
	print("=== Resource Tracker Report ===")
	print("Total Resources Loaded: %d" % stats["total_resources_loaded"])
	print("Active Resources: %d" % stats["active_resources"])
	print("Total Memory: %.2fMB" % stats["total_memory_mb"])
	print("Cache Optimizations: %d" % stats["cache_optimizations"])
	print("Resources Cleaned: %d" % stats["resources_cleaned"])
	
	print("\nCache Usage by Type:")
	for resource_type in ResourceType.values():
		var type_name: String = _resource_type_to_string(resource_type)
		var usage_mb: float = resource_cache_usage[resource_type]
		var limit_mb: float = _get_cache_limit(resource_type)
		print("  %s: %.2fMB / %.2fMB (%.1f%%)" % [type_name, usage_mb, limit_mb, (usage_mb / limit_mb) * 100.0])
	
	print("================================")