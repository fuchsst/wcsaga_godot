class_name MemoryOptimizer
extends Node

## SHIP-016 AC6: Memory Optimizer for leak prevention and resource management
## Implements comprehensive memory monitoring, leak detection, and garbage collection optimization
## Maintains memory usage under 2GB during large combat scenarios

signal memory_warning(threshold_exceeded: String, current_mb: float, limit_mb: float)
signal memory_leak_detected(resource_type: String, leak_size_mb: float, growth_rate: float)
signal garbage_collection_triggered(reason: String, freed_mb: float, collection_time_ms: float)
signal resource_cleanup_completed(resource_type: String, freed_count: int, freed_mb: float)

# Memory monitoring configuration
@export var enable_memory_monitoring: bool = true
@export var memory_check_interval: float = 1.0  # Check every second
@export var memory_warning_threshold_mb: float = 1536.0  # 1.5GB warning
@export var memory_critical_threshold_mb: float = 1792.0  # 1.75GB critical
@export var memory_leak_threshold_mb: float = 50.0  # 50MB growth before leak warning
@export var auto_cleanup_enabled: bool = true

# Garbage collection settings
@export var gc_trigger_threshold_mb: float = 100.0  # Trigger GC when 100MB+ ready for collection
@export var gc_max_frequency: float = 10.0  # Maximum GC frequency per second
@export var gc_defer_during_combat: bool = true  # Defer GC during intense combat

# Resource tracking
var last_memory_usage_mb: float = 0.0
var memory_usage_history: Array[float] = []
var last_memory_check_time: float = 0.0
var last_gc_time: float = 0.0
var total_gc_collections: int = 0

# Resource tracking dictionaries
var tracked_resources: Dictionary = {}  # resource_type -> MemoryResourceTracker
var resource_pools: Dictionary = {}  # pool_name -> PoolInfo
var texture_cache: Dictionary = {}  # texture_path -> CacheInfo
var audio_cache: Dictionary = {}  # audio_path -> CacheInfo

# Memory statistics
var memory_stats: Dictionary = {
	"peak_usage_mb": 0.0,
	"average_usage_mb": 0.0,
	"gc_collections": 0,
	"gc_time_total_ms": 0.0,
	"leaks_detected": 0,
	"auto_cleanups": 0,
	"resources_freed": 0
}

# Resource tracker structure
class MemoryResourceTracker:
	var resource_type: String
	var instance_count: int = 0
	var memory_usage_mb: float = 0.0
	var last_cleanup_time: float = 0.0
	var growth_rate_per_second: float = 0.0
	var peak_count: int = 0
	var total_allocated: int = 0
	var total_freed: int = 0
	
	func _init(type: String) -> void:
		resource_type = type

# Pool information structure
class PoolInfo:
	var pool_name: String
	var total_objects: int = 0
	var active_objects: int = 0
	var pooled_objects: int = 0
	var memory_per_object_mb: float = 0.0
	var last_cleanup_time: float = 0.0
	
	func _init(name: String) -> void:
		pool_name = name

# Cache information structure
class CacheInfo:
	var resource_path: String
	var memory_size_mb: float = 0.0
	var last_access_time: float = 0.0
	var access_count: int = 0
	var ref_count: int = 0
	
	func _init(path: String) -> void:
		resource_path = path

func _ready() -> void:
	set_process(enable_memory_monitoring)
	_initialize_resource_tracking()
	print("MemoryOptimizer: Memory monitoring and leak prevention system initialized")

## Initialize resource tracking for common types
func _initialize_resource_tracking() -> void:
	# Track common game resource types
	tracked_resources["ships"] = MemoryResourceTracker.new("ships")
	tracked_resources["weapons"] = MemoryResourceTracker.new("weapons")
	tracked_resources["projectiles"] = MemoryResourceTracker.new("projectiles")
	tracked_resources["effects"] = MemoryResourceTracker.new("effects")
	tracked_resources["particles"] = MemoryResourceTracker.new("particles")
	tracked_resources["audio"] = MemoryResourceTracker.new("audio")
	tracked_resources["textures"] = MemoryResourceTracker.new("textures")
	tracked_resources["meshes"] = MemoryResourceTracker.new("meshes")
	tracked_resources["materials"] = MemoryResourceTracker.new("materials")
	tracked_resources["scenes"] = MemoryResourceTracker.new("scenes")

func _process(delta: float) -> void:
	if not enable_memory_monitoring:
		return
	
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Check memory at specified intervals
	if current_time - last_memory_check_time >= memory_check_interval:
		_check_memory_usage()
		last_memory_check_time = current_time
	
	# Check for automatic cleanup needs
	if auto_cleanup_enabled:
		_check_automatic_cleanup()

## Check current memory usage and detect issues
func _check_memory_usage() -> void:
	var current_memory_mb: float = _get_current_memory_usage_mb()
	memory_usage_history.append(current_memory_mb)
	
	# Keep history to reasonable size (last 5 minutes at 1 second intervals)
	if memory_usage_history.size() > 300:
		memory_usage_history.pop_front()
	
	# Update statistics
	memory_stats["peak_usage_mb"] = max(memory_stats["peak_usage_mb"], current_memory_mb)
	_calculate_average_memory_usage()
	
	# Check warning thresholds
	if current_memory_mb > memory_critical_threshold_mb:
		memory_warning.emit("CRITICAL", current_memory_mb, memory_critical_threshold_mb)
		if auto_cleanup_enabled:
			_trigger_emergency_cleanup("CRITICAL_MEMORY")
	elif current_memory_mb > memory_warning_threshold_mb:
		memory_warning.emit("WARNING", current_memory_mb, memory_warning_threshold_mb)
	
	# Check for memory leaks
	_detect_memory_leaks(current_memory_mb)
	
	last_memory_usage_mb = current_memory_mb

## Get current memory usage in MB
func _get_current_memory_usage_mb() -> float:
	# Use OS memory info if available
	var memory_info: Dictionary = OS.get_memory_info()
	if memory_info.has("physical"):
		return memory_info["physical"] / (1024.0 * 1024.0)
	
	# Fallback estimation based on tracked resources
	var estimated_mb: float = 0.0
	for tracker in tracked_resources.values():
		estimated_mb += tracker.memory_usage_mb
	
	return estimated_mb

## Calculate average memory usage
func _calculate_average_memory_usage() -> void:
	if memory_usage_history.is_empty():
		return
	
	var total: float = 0.0
	for usage in memory_usage_history:
		total += usage
	
	memory_stats["average_usage_mb"] = total / memory_usage_history.size()

## Detect potential memory leaks
func _detect_memory_leaks(current_memory_mb: float) -> void:
	if memory_usage_history.size() < 10:  # Need enough history
		return
	
	# Calculate memory growth rate over last 10 samples
	var recent_samples: Array[float] = memory_usage_history.slice(-10)
	var oldest_sample: float = recent_samples[0]
	var growth_mb: float = current_memory_mb - oldest_sample
	var time_span: float = memory_check_interval * recent_samples.size()
	var growth_rate: float = growth_mb / time_span  # MB per second
	
	# Check for sustained growth indicating leak
	if growth_mb > memory_leak_threshold_mb and growth_rate > 1.0:  # Growing >1MB/sec
		var leak_type: String = _identify_leak_source(growth_rate)
		memory_leak_detected.emit(leak_type, growth_mb, growth_rate)
		memory_stats["leaks_detected"] += 1
		
		if auto_cleanup_enabled:
			_trigger_leak_cleanup(leak_type)

## Identify likely source of memory leak
func _identify_leak_source(growth_rate: float) -> String:
	# Analyze resource tracker growth patterns
	var fastest_growing: String = "unknown"
	var max_growth: float = 0.0
	
	for resource_type in tracked_resources:
		var tracker: MemoryResourceTracker = tracked_resources[resource_type]
		if tracker.growth_rate_per_second > max_growth:
			max_growth = tracker.growth_rate_per_second
			fastest_growing = resource_type
	
	return fastest_growing

## Check for automatic cleanup opportunities
func _check_automatic_cleanup() -> void:
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Check garbage collection needs
	if _should_trigger_garbage_collection():
		_trigger_garbage_collection("AUTO_THRESHOLD")
	
	# Check resource cache cleanup
	_check_cache_cleanup(current_time)
	
	# Check object pool cleanup
	_check_pool_cleanup(current_time)

## Check if garbage collection should be triggered
func _should_trigger_garbage_collection() -> bool:
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Rate limiting
	if current_time - last_gc_time < (1.0 / gc_max_frequency):
		return false
	
	# Defer during combat if enabled
	if gc_defer_during_combat and _is_combat_active():
		return false
	
	# Check if enough garbage has accumulated
	var estimated_garbage_mb: float = _estimate_garbage_collection_potential()
	return estimated_garbage_mb > gc_trigger_threshold_mb

## Estimate potential memory freed by garbage collection
func _estimate_garbage_collection_potential() -> float:
	# Conservative estimate based on tracked resource growth
	var potential_mb: float = 0.0
	
	for tracker in tracked_resources.values():
		# Assume 10% of current usage could be freed
		potential_mb += tracker.memory_usage_mb * 0.1
	
	return potential_mb

## Check if combat is currently active
func _is_combat_active() -> bool:
	# Check with combat scaling controller if available
	var combat_controller = get_node_or_null("/root/CombatScalingController")
	if combat_controller and combat_controller.has_method("get_combat_statistics"):
		var stats: Dictionary = combat_controller.get_combat_statistics()
		var intensity: String = stats.get("battle_intensity", "PEACEFUL")
		return intensity in ["ENGAGEMENT", "BATTLE", "MASSIVE_BATTLE"]
	
	return false

## Trigger garbage collection
func _trigger_garbage_collection(reason: String) -> void:
	var start_time: float = Time.get_ticks_usec() / 1000.0
	var memory_before: float = _get_current_memory_usage_mb()
	
	# Force garbage collection (Godot automatically manages GC)
	# We can only suggest cleanup by nullifying references
	_force_cleanup_references()
	
	var end_time: float = Time.get_ticks_usec() / 1000.0
	var collection_time_ms: float = end_time - start_time
	var memory_after: float = _get_current_memory_usage_mb()
	var freed_mb: float = memory_before - memory_after
	
	# Update statistics
	last_gc_time = start_time / 1000.0
	total_gc_collections += 1
	memory_stats["gc_collections"] += 1
	memory_stats["gc_time_total_ms"] += collection_time_ms
	
	garbage_collection_triggered.emit(reason, freed_mb, collection_time_ms)
	print("MemoryOptimizer: GC triggered (%s) - Freed %.2fMB in %.2fms" % [reason, freed_mb, collection_time_ms])

## Check cache cleanup opportunities
func _check_cache_cleanup(current_time: float) -> void:
	# Cleanup old texture cache entries
	_cleanup_cache(texture_cache, "texture", current_time, 300.0)  # 5 minutes
	
	# Cleanup old audio cache entries
	_cleanup_cache(audio_cache, "audio", current_time, 180.0)  # 3 minutes

## Cleanup cache entries older than threshold
func _cleanup_cache(cache: Dictionary, cache_type: String, current_time: float, max_age: float) -> void:
	var entries_to_remove: Array[String] = []
	var freed_memory: float = 0.0
	
	for path in cache:
		var cache_info: CacheInfo = cache[path]
		var age: float = current_time - cache_info.last_access_time
		
		# Remove old entries with low reference count
		if age > max_age and cache_info.ref_count <= 1:
			entries_to_remove.append(path)
			freed_memory += cache_info.memory_size_mb
	
	# Remove identified entries
	for path in entries_to_remove:
		cache.erase(path)
		# Unload resource if it's still loaded
		if ResourceLoader.has_cached(path):
			ResourceLoader.set_abort_on_missing_resources(false)
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if entries_to_remove.size() > 0:
		resource_cleanup_completed.emit(cache_type, entries_to_remove.size(), freed_memory)
		memory_stats["auto_cleanups"] += 1
		memory_stats["resources_freed"] += entries_to_remove.size()

## Check object pool cleanup opportunities
func _check_pool_cleanup(current_time: float) -> void:
	for pool_name in resource_pools:
		var pool_info: PoolInfo = resource_pools[pool_name]
		var age: float = current_time - pool_info.last_cleanup_time
		
		# Cleanup pool if it has excessive unused objects
		if age > 60.0 and pool_info.pooled_objects > pool_info.active_objects * 2:
			_cleanup_pool(pool_name, pool_info)

## Cleanup excess objects from pool
func _cleanup_pool(pool_name: String, pool_info: PoolInfo) -> void:
	# Get pool manager if available
	var pool_manager = get_node_or_null("/root/ObjectPoolManager")
	if pool_manager and pool_manager.has_method("cleanup_pool"):
		var freed_count: int = pool_manager.cleanup_pool(pool_name)
		var freed_memory: float = freed_count * pool_info.memory_per_object_mb
		
		pool_info.last_cleanup_time = Time.get_ticks_usec() / 1000000.0
		pool_info.pooled_objects = max(0, pool_info.pooled_objects - freed_count)
		
		resource_cleanup_completed.emit("pool_" + pool_name, freed_count, freed_memory)
		memory_stats["auto_cleanups"] += 1
		memory_stats["resources_freed"] += freed_count

## Trigger emergency cleanup during critical memory conditions
func _trigger_emergency_cleanup(reason: String) -> void:
	print("MemoryOptimizer: Emergency cleanup triggered - %s" % reason)
	
	# Force immediate garbage collection
	_trigger_garbage_collection("EMERGENCY")
	
	# Aggressive cache cleanup (reduce max age)
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	_cleanup_cache(texture_cache, "texture", current_time, 60.0)  # 1 minute
	_cleanup_cache(audio_cache, "audio", current_time, 30.0)     # 30 seconds
	
	# Cleanup all pools
	for pool_name in resource_pools:
		var pool_info: PoolInfo = resource_pools[pool_name]
		_cleanup_pool(pool_name, pool_info)
	
	# Force unload unused resources
	_force_unload_unused_resources()

## Trigger leak-specific cleanup
func _trigger_leak_cleanup(leak_type: String) -> void:
	print("MemoryOptimizer: Leak cleanup triggered for %s" % leak_type)
	
	# Targeted cleanup based on leak type
	match leak_type:
		"textures":
			_cleanup_cache(texture_cache, "texture", Time.get_ticks_usec() / 1000000.0, 30.0)
		"audio":
			_cleanup_cache(audio_cache, "audio", Time.get_ticks_usec() / 1000000.0, 15.0)
		"effects", "particles":
			_cleanup_effects_leak()
		"projectiles", "weapons":
			_cleanup_combat_objects_leak()
		_:
			# General cleanup
			_trigger_garbage_collection("LEAK_CLEANUP")

## Cleanup effects-related memory leaks
func _cleanup_effects_leak() -> void:
	# Find all particle systems and force cleanup of completed ones
	var particle_nodes: Array[Node] = get_tree().get_nodes_in_group("particles")
	var cleaned_count: int = 0
	
	for node in particle_nodes:
		if node is GPUParticles3D:
			var particles: GPUParticles3D = node as GPUParticles3D
			if not particles.emitting and particles.finished:
				particles.queue_free()
				cleaned_count += 1
	
	print("MemoryOptimizer: Cleaned up %d finished particle systems" % cleaned_count)

## Cleanup combat objects memory leaks
func _cleanup_combat_objects_leak() -> void:
	# Force cleanup of destroyed projectiles and weapons
	var combat_objects: Array[Node] = get_tree().get_nodes_in_group("combat_objects")
	var cleaned_count: int = 0
	
	for node in combat_objects:
		if node.has_method("is_destroyed") and node.is_destroyed():
			node.queue_free()
			cleaned_count += 1
	
	print("MemoryOptimizer: Cleaned up %d destroyed combat objects" % cleaned_count)

## Force cleanup of references to help GC
func _force_cleanup_references() -> void:
	# Clear completed animations and temporary objects
	for node in get_tree().get_nodes_in_group("temporary_objects"):
		if is_instance_valid(node) and node.has_method("cleanup"):
			node.cleanup()

## Force unload unused resources
func _force_unload_unused_resources() -> void:
	# In Godot 4, we can't directly access cached resources
	# Instead, we focus on cleaning up our tracked resources
	var unloaded_count: int = 0
	
	# Clear cache dictionaries of old entries
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Clear old texture cache entries
	var textures_to_remove: Array[String] = []
	for path in texture_cache:
		var cache_info: CacheInfo = texture_cache[path]
		if current_time - cache_info.last_access_time > 60.0:  # 1 minute old
			textures_to_remove.append(path)
	
	for path in textures_to_remove:
		texture_cache.erase(path)
		unloaded_count += 1
	
	# Clear old audio cache entries
	var audio_to_remove: Array[String] = []
	for path in audio_cache:
		var cache_info: CacheInfo = audio_cache[path]
		if current_time - cache_info.last_access_time > 60.0:  # 1 minute old
			audio_to_remove.append(path)
	
	for path in audio_to_remove:
		audio_cache.erase(path)
		unloaded_count += 1
	
	print("MemoryOptimizer: Force unloaded %d unused cache entries" % unloaded_count)

# Public API

## Register resource for tracking
func register_resource(resource_type: String, memory_mb: float = 0.0) -> bool:
	if not tracked_resources.has(resource_type):
		tracked_resources[resource_type] = MemoryResourceTracker.new(resource_type)
	
	var tracker: MemoryResourceTracker = tracked_resources[resource_type]
	tracker.instance_count += 1
	tracker.memory_usage_mb += memory_mb
	tracker.total_allocated += 1
	tracker.peak_count = max(tracker.peak_count, tracker.instance_count)
	
	return true

## Unregister resource from tracking
func unregister_resource(resource_type: String, memory_mb: float = 0.0) -> bool:
	if not tracked_resources.has(resource_type):
		return false
	
	var tracker: MemoryResourceTracker = tracked_resources[resource_type]
	tracker.instance_count = max(0, tracker.instance_count - 1)
	tracker.memory_usage_mb = max(0.0, tracker.memory_usage_mb - memory_mb)
	tracker.total_freed += 1
	
	return true

## Register object pool for monitoring
func register_pool(pool_name: String, memory_per_object_mb: float) -> bool:
	if resource_pools.has(pool_name):
		return false
	
	var pool_info: PoolInfo = PoolInfo.new(pool_name)
	pool_info.memory_per_object_mb = memory_per_object_mb
	resource_pools[pool_name] = pool_info
	
	return true

## Update pool statistics
func update_pool_stats(pool_name: String, total_objects: int, active_objects: int) -> bool:
	if not resource_pools.has(pool_name):
		return false
	
	var pool_info: PoolInfo = resource_pools[pool_name]
	pool_info.total_objects = total_objects
	pool_info.active_objects = active_objects
	pool_info.pooled_objects = total_objects - active_objects
	
	return true

## Track texture cache usage
func track_texture_cache(texture_path: String, memory_mb: float) -> void:
	if not texture_cache.has(texture_path):
		texture_cache[texture_path] = CacheInfo.new(texture_path)
	
	var cache_info: CacheInfo = texture_cache[texture_path]
	cache_info.memory_size_mb = memory_mb
	cache_info.last_access_time = Time.get_ticks_usec() / 1000000.0
	cache_info.access_count += 1
	cache_info.ref_count = ResourceLoader.get_resource_uid(texture_path)

## Track audio cache usage
func track_audio_cache(audio_path: String, memory_mb: float) -> void:
	if not audio_cache.has(audio_path):
		audio_cache[audio_path] = CacheInfo.new(audio_path)
	
	var cache_info: CacheInfo = audio_cache[audio_path]
	cache_info.memory_size_mb = memory_mb
	cache_info.last_access_time = Time.get_ticks_usec() / 1000000.0
	cache_info.access_count += 1

## Force memory optimization
func force_memory_optimization() -> Dictionary:
	var start_memory: float = _get_current_memory_usage_mb()
	
	# Trigger all cleanup systems
	_trigger_garbage_collection("MANUAL")
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	_cleanup_cache(texture_cache, "texture", current_time, 0.0)  # Clean all
	_cleanup_cache(audio_cache, "audio", current_time, 0.0)     # Clean all
	
	# Cleanup all pools
	for pool_name in resource_pools:
		var pool_info: PoolInfo = resource_pools[pool_name]
		_cleanup_pool(pool_name, pool_info)
	
	_force_unload_unused_resources()
	
	var end_memory: float = _get_current_memory_usage_mb()
	var freed_mb: float = start_memory - end_memory
	
	return {
		"memory_before_mb": start_memory,
		"memory_after_mb": end_memory,
		"freed_mb": freed_mb,
		"optimization_effective": freed_mb > 10.0
	}

## Get comprehensive memory statistics
func get_memory_statistics() -> Dictionary:
	var current_memory: float = _get_current_memory_usage_mb()
	
	var stats: Dictionary = memory_stats.duplicate()
	stats["current_memory_mb"] = current_memory
	stats["memory_usage_history"] = memory_usage_history.duplicate()
	stats["warning_threshold_mb"] = memory_warning_threshold_mb
	stats["critical_threshold_mb"] = memory_critical_threshold_mb
	stats["tracked_resource_types"] = tracked_resources.size()
	stats["monitored_pools"] = resource_pools.size()
	stats["texture_cache_entries"] = texture_cache.size()
	stats["audio_cache_entries"] = audio_cache.size()
	stats["monitoring_enabled"] = enable_memory_monitoring
	stats["auto_cleanup_enabled"] = auto_cleanup_enabled
	
	return stats

## Get resource tracking details
func get_resource_tracking_details() -> Dictionary:
	var details: Dictionary = {}
	
	for resource_type in tracked_resources:
		var tracker: MemoryResourceTracker = tracked_resources[resource_type]
		details[resource_type] = {
			"instance_count": tracker.instance_count,
			"memory_usage_mb": tracker.memory_usage_mb,
			"growth_rate_per_second": tracker.growth_rate_per_second,
			"peak_count": tracker.peak_count,
			"total_allocated": tracker.total_allocated,
			"total_freed": tracker.total_freed,
			"efficiency_ratio": tracker.total_freed / max(1.0, tracker.total_allocated)
		}
	
	return details

## Set memory monitoring enabled/disabled
func set_memory_monitoring_enabled(enabled: bool) -> void:
	enable_memory_monitoring = enabled
	set_process(enabled)
	
	if enabled:
		print("MemoryOptimizer: Memory monitoring enabled")
	else:
		print("MemoryOptimizer: Memory monitoring disabled")

## Set automatic cleanup enabled/disabled
func set_auto_cleanup_enabled(enabled: bool) -> void:
	auto_cleanup_enabled = enabled
	print("MemoryOptimizer: Automatic cleanup %s" % ("enabled" if enabled else "disabled"))

## Check if memory usage is healthy
func is_memory_usage_healthy() -> bool:
	var current_memory: float = _get_current_memory_usage_mb()
	return current_memory < memory_warning_threshold_mb

## Get memory health status
func get_memory_health_status() -> Dictionary:
	var current_memory: float = _get_current_memory_usage_mb()
	var health_ratio: float = current_memory / memory_critical_threshold_mb
	
	var status: String = "HEALTHY"
	if current_memory > memory_critical_threshold_mb:
		status = "CRITICAL"
	elif current_memory > memory_warning_threshold_mb:
		status = "WARNING"
	
	return {
		"status": status,
		"current_memory_mb": current_memory,
		"health_ratio": health_ratio,
		"warning_threshold_mb": memory_warning_threshold_mb,
		"critical_threshold_mb": memory_critical_threshold_mb,
		"estimated_time_to_critical_minutes": _estimate_time_to_critical_memory()
	}

## Estimate time until critical memory condition
func _estimate_time_to_critical_memory() -> float:
	if memory_usage_history.size() < 5:
		return -1.0  # Not enough data
	
	# Calculate recent growth rate
	var recent_samples: Array[float] = memory_usage_history.slice(-5)
	var growth_per_check: float = (recent_samples[-1] - recent_samples[0]) / recent_samples.size()
	
	if growth_per_check <= 0.0:
		return -1.0  # Memory not growing
	
	var current_memory: float = _get_current_memory_usage_mb()
	var memory_to_critical: float = memory_critical_threshold_mb - current_memory
	var checks_to_critical: float = memory_to_critical / growth_per_check
	var seconds_to_critical: float = checks_to_critical * memory_check_interval
	
	return seconds_to_critical / 60.0  # Convert to minutes