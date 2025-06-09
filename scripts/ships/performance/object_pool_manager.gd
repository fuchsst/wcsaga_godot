class_name ObjectPoolManager
extends Node

## SHIP-016 AC3: Object Pool Manager for efficient instance reuse
## Manages ship, projectile, and effect instances to minimize garbage collection and allocation overhead
## Implements comprehensive pooling system for all game objects

signal pool_created(pool_name: String, initial_size: int, max_size: int)
signal pool_resized(pool_name: String, old_size: int, new_size: int)
signal object_acquired(pool_name: String, object: Node, pool_remaining: int)
signal object_returned(pool_name: String, object: Node, pool_size: int)
signal pool_exhausted(pool_name: String, requested_objects: int, available: int)
signal memory_pressure_detected(total_pooled_objects: int, memory_estimate_mb: float)

# Pool management configuration
@export var enable_object_pooling: bool = true
@export var auto_resize_pools: bool = true
@export var memory_pressure_threshold_mb: float = 500.0
@export var cleanup_frequency: float = 30.0  # Cleanup unused objects every 30 seconds
@export var statistics_update_frequency: float = 1.0  # Update stats every second

# Pool definitions
var object_pools: Dictionary = {}  # pool_name -> ObjectPool
var pool_statistics: Dictionary = {}  # pool_name -> PoolStatistics
var cleanup_timer: float = 0.0
var stats_timer: float = 0.0

# Default pool configurations
var default_pool_configs: Dictionary = {
	"ship": {
		"initial_size": 20,
		"max_size": 100,
		"grow_size": 10,
		"shrink_threshold": 0.3,
		"cleanup_threshold": 60.0
	},
	"projectile": {
		"initial_size": 100,
		"max_size": 500,
		"grow_size": 50,
		"shrink_threshold": 0.2,
		"cleanup_threshold": 30.0
	},
	"effect": {
		"initial_size": 50,
		"max_size": 200,
		"grow_size": 25,
		"shrink_threshold": 0.25,
		"cleanup_threshold": 45.0
	},
	"weapon": {
		"initial_size": 30,
		"max_size": 150,
		"grow_size": 15,
		"shrink_threshold": 0.3,
		"cleanup_threshold": 60.0
	},
	"debris": {
		"initial_size": 25,
		"max_size": 100,
		"grow_size": 10,
		"shrink_threshold": 0.2,
		"cleanup_threshold": 45.0
	},
	"audio": {
		"initial_size": 40,
		"max_size": 120,
		"grow_size": 20,
		"shrink_threshold": 0.3,
		"cleanup_threshold": 30.0
	}
}

# Object pool class
class ObjectPool:
	var pool_name: String
	var available_objects: Array[Node] = []
	var active_objects: Array[Node] = []
	var object_template: PackedScene = null
	var object_script: Script = null
	var initial_size: int
	var max_size: int
	var grow_size: int
	var shrink_threshold: float
	var cleanup_threshold: float
	var last_cleanup_time: float = 0.0
	var total_created: int = 0
	var total_acquired: int = 0
	var total_returned: int = 0
	var peak_active: int = 0
	
	func _init(name: String, config: Dictionary) -> void:
		pool_name = name
		initial_size = config.get("initial_size", 10)
		max_size = config.get("max_size", 50)
		grow_size = config.get("grow_size", 5)
		shrink_threshold = config.get("shrink_threshold", 0.3)
		cleanup_threshold = config.get("cleanup_threshold", 60.0)
	
	func get_size() -> int:
		return available_objects.size()
	
	func get_active_count() -> int:
		return active_objects.size()
	
	func get_total_count() -> int:
		return available_objects.size() + active_objects.size()

# Pool statistics class
class PoolStatistics:
	var pool_name: String
	var current_size: int = 0
	var active_objects: int = 0
	var peak_active: int = 0
	var total_acquired: int = 0
	var total_returned: int = 0
	var total_created: int = 0
	var memory_estimate_mb: float = 0.0
	var efficiency_rating: float = 100.0  # Percentage of objects reused vs created
	var last_update_time: float = 0.0
	
	func update_efficiency() -> void:
		if total_created > 0:
			efficiency_rating = (float(total_returned) / float(total_created)) * 100.0
		else:
			efficiency_rating = 100.0

func _ready() -> void:
	set_process(enable_object_pooling)
	_initialize_default_pools()
	print("ObjectPoolManager: Efficient instance reuse system initialized")

## Initialize default object pools
func _initialize_default_pools() -> void:
	for pool_name in default_pool_configs.keys():
		var config: Dictionary = default_pool_configs[pool_name]
		create_pool(pool_name, config)

func _process(delta: float) -> void:
	if not enable_object_pooling:
		return
	
	cleanup_timer += delta
	stats_timer += delta
	
	# Periodic cleanup
	if cleanup_timer >= cleanup_frequency:
		_cleanup_unused_objects()
		cleanup_timer = 0.0
	
	# Statistics update
	if stats_timer >= statistics_update_frequency:
		_update_pool_statistics()
		stats_timer = 0.0

## Create a new object pool
func create_pool(pool_name: String, config: Dictionary, template: PackedScene = null, script: Script = null) -> bool:
	if object_pools.has(pool_name):
		push_warning("ObjectPoolManager: Pool '%s' already exists" % pool_name)
		return false
	
	var pool: ObjectPool = ObjectPool.new(pool_name, config)
	pool.object_template = template
	pool.object_script = script
	
	object_pools[pool_name] = pool
	pool_statistics[pool_name] = PoolStatistics.new()
	pool_statistics[pool_name].pool_name = pool_name
	
	# Pre-populate pool
	_populate_pool(pool, pool.initial_size)
	
	pool_created.emit(pool_name, pool.initial_size, pool.max_size)
	print("ObjectPoolManager: Created pool '%s' with %d initial objects" % [pool_name, pool.initial_size])
	return true

## Populate pool with specified number of objects
func _populate_pool(pool: ObjectPool, count: int) -> void:
	for i in range(count):
		var obj: Node = _create_pooled_object(pool)
		if obj:
			pool.available_objects.append(obj)
			pool.total_created += 1

## Create a new pooled object
func _create_pooled_object(pool: ObjectPool) -> Node:
	var obj: Node = null
	
	# Create from template if available
	if pool.object_template:
		obj = pool.object_template.instantiate()
	elif pool.object_script:
		obj = Node.new()
		obj.set_script(pool.object_script)
	else:
		# Create based on pool type
		obj = _create_default_object_for_pool(pool.pool_name)
	
	if obj:
		# Configure for pooling
		_prepare_object_for_pooling(obj, pool.pool_name)
		
		# Add to tree but deactivate
		add_child(obj)
		_deactivate_pooled_object(obj)
	
	return obj

## Create default object for pool type
func _create_default_object_for_pool(pool_name: String) -> Node:
	match pool_name:
		"ship":
			return _create_ship_object()
		"projectile":
			return _create_projectile_object()
		"effect":
			return _create_effect_object()
		"weapon":
			return _create_weapon_object()
		"debris":
			return _create_debris_object()
		"audio":
			return _create_audio_object()
		_:
			return Node3D.new()

## Create ship object for pooling
func _create_ship_object() -> Node3D:
	var ship: Node3D = Node3D.new()
	ship.name = "PooledShip"
	
	# Add basic components for ship
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	ship.add_child(mesh_instance)
	
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	ship.add_child(collision_shape)
	
	return ship

## Create projectile object for pooling
func _create_projectile_object() -> Node3D:
	var projectile: RigidBody3D = RigidBody3D.new()
	projectile.name = "PooledProjectile"
	
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	projectile.add_child(mesh_instance)
	
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	projectile.add_child(collision_shape)
	
	return projectile

## Create effect object for pooling
func _create_effect_object() -> Node3D:
	var effect: Node3D = Node3D.new()
	effect.name = "PooledEffect"
	
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Particles"
	effect.add_child(particles)
	
	return effect

## Create weapon object for pooling
func _create_weapon_object() -> Node3D:
	var weapon: Node3D = Node3D.new()
	weapon.name = "PooledWeapon"
	
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	weapon.add_child(mesh_instance)
	
	return weapon

## Create debris object for pooling
func _create_debris_object() -> Node3D:
	var debris: RigidBody3D = RigidBody3D.new()
	debris.name = "PooledDebris"
	
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	debris.add_child(mesh_instance)
	
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	debris.add_child(collision_shape)
	
	return debris

## Create audio object for pooling
func _create_audio_object() -> Node3D:
	var audio_container: Node3D = Node3D.new()
	audio_container.name = "PooledAudio"
	
	var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio_player.name = "AudioPlayer"
	audio_container.add_child(audio_player)
	
	return audio_container

## Prepare object for pooling
func _prepare_object_for_pooling(obj: Node, pool_name: String) -> void:
	# Add pooling metadata
	obj.set_meta("pool_name", pool_name)
	obj.set_meta("pooled", true)
	obj.set_meta("acquired_time", 0.0)
	
	# Connect cleanup signals if object supports them
	if obj.has_signal("tree_exiting"):
		if not obj.tree_exiting.is_connected(_on_pooled_object_destroyed):
			obj.tree_exiting.connect(_on_pooled_object_destroyed.bind(obj))

## Acquire object from pool
func acquire_object(pool_name: String) -> Node:
	if not enable_object_pooling or not object_pools.has(pool_name):
		return null
	
	var pool: ObjectPool = object_pools[pool_name]
	var obj: Node = null
	
	# Get object from available pool
	if pool.available_objects.size() > 0:
		obj = pool.available_objects.pop_back()
	else:
		# Try to grow pool if possible
		if pool.get_total_count() < pool.max_size:
			obj = _create_pooled_object(pool)
			if obj:
				pool.total_created += 1
		else:
			# Pool exhausted
			pool_exhausted.emit(pool_name, 1, 0)
			return null
	
	if obj:
		# Activate object
		_activate_pooled_object(obj)
		pool.active_objects.append(obj)
		pool.total_acquired += 1
		pool.peak_active = max(pool.peak_active, pool.get_active_count())
		
		# Set acquisition time
		obj.set_meta("acquired_time", Time.get_ticks_usec() / 1000000.0)
		
		object_acquired.emit(pool_name, obj, pool.get_size())
	
	return obj

## Return object to pool
func return_object(obj: Node) -> bool:
	if not obj or not obj.has_meta("pool_name"):
		return false
	
	var pool_name: String = obj.get_meta("pool_name")
	if not object_pools.has(pool_name):
		return false
	
	var pool: ObjectPool = object_pools[pool_name]
	var active_index: int = pool.active_objects.find(obj)
	
	if active_index == -1:
		return false  # Object not in active list
	
	# Remove from active list
	pool.active_objects.remove_at(active_index)
	
	# Reset object state
	_reset_pooled_object(obj)
	
	# Deactivate and return to pool
	_deactivate_pooled_object(obj)
	pool.available_objects.append(obj)
	pool.total_returned += 1
	
	object_returned.emit(pool_name, obj, pool.get_size())
	return true

## Activate pooled object
func _activate_pooled_object(obj: Node) -> void:
	obj.set_process_mode(Node.PROCESS_MODE_INHERIT)
	obj.visible = true
	
	# Call activation method if available
	if obj.has_method("activate_from_pool"):
		obj.activate_from_pool()

## Deactivate pooled object
func _deactivate_pooled_object(obj: Node) -> void:
	obj.set_process_mode(Node.PROCESS_MODE_DISABLED)
	obj.visible = false
	
	# Call deactivation method if available
	if obj.has_method("deactivate_to_pool"):
		obj.deactivate_to_pool()

## Reset pooled object to default state
func _reset_pooled_object(obj: Node) -> void:
	# Reset transform
	if obj is Node3D:
		var node_3d: Node3D = obj as Node3D
		node_3d.global_position = Vector3.ZERO
		node_3d.global_rotation = Vector3.ZERO
		node_3d.scale = Vector3.ONE
	
	# Reset physics
	if obj is RigidBody3D:
		var rigid_body: RigidBody3D = obj as RigidBody3D
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
		rigid_body.freeze = false
	
	# Call reset method if available
	if obj.has_method("reset_for_pool"):
		obj.reset_for_pool()

## Handle pooled object destruction
func _on_pooled_object_destroyed(obj: Node) -> void:
	if not obj.has_meta("pool_name"):
		return
	
	var pool_name: String = obj.get_meta("pool_name")
	if not object_pools.has(pool_name):
		return
	
	var pool: ObjectPool = object_pools[pool_name]
	
	# Remove from active list
	var active_index: int = pool.active_objects.find(obj)
	if active_index != -1:
		pool.active_objects.remove_at(active_index)
	
	# Remove from available list
	var available_index: int = pool.available_objects.find(obj)
	if available_index != -1:
		pool.available_objects.remove_at(available_index)

## Cleanup unused objects from pools
func _cleanup_unused_objects() -> void:
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	
	for pool in object_pools.values():
		if current_time - pool.last_cleanup_time < pool.cleanup_threshold:
			continue
		
		var initial_size: int = pool.get_size()
		var target_size: int = max(pool.initial_size, int(pool.peak_active * 1.5))
		
		# Remove excess objects
		while pool.get_size() > target_size and pool.available_objects.size() > 0:
			var obj: Node = pool.available_objects.pop_back()
			if is_instance_valid(obj):
				obj.queue_free()
		
		if pool.get_size() != initial_size:
			pool_resized.emit(pool.pool_name, initial_size, pool.get_size())
		
		pool.last_cleanup_time = current_time
		pool.peak_active = pool.get_active_count()  # Reset peak tracking

## Update pool statistics
func _update_pool_statistics() -> void:
	var total_memory: float = 0.0
	
	for pool_name in object_pools.keys():
		var pool: ObjectPool = object_pools[pool_name]
		var stats: PoolStatistics = pool_statistics[pool_name]
		
		# Update basic statistics
		stats.current_size = pool.get_size()
		stats.active_objects = pool.get_active_count()
		stats.peak_active = pool.peak_active
		stats.total_acquired = pool.total_acquired
		stats.total_returned = pool.total_returned
		stats.total_created = pool.total_created
		stats.last_update_time = Time.get_ticks_usec() / 1000000.0
		
		# Estimate memory usage
		stats.memory_estimate_mb = _estimate_pool_memory_usage(pool)
		total_memory += stats.memory_estimate_mb
		
		# Update efficiency
		stats.update_efficiency()
	
	# Check for memory pressure
	if total_memory > memory_pressure_threshold_mb:
		memory_pressure_detected.emit(_get_total_pooled_objects(), total_memory)

## Estimate memory usage for a pool
func _estimate_pool_memory_usage(pool: ObjectPool) -> float:
	var total_objects: int = pool.get_total_count()
	var bytes_per_object: float = _get_estimated_object_size(pool.pool_name)
	
	return (total_objects * bytes_per_object) / (1024.0 * 1024.0)  # Convert to MB

## Get estimated object size in bytes
func _get_estimated_object_size(pool_name: String) -> float:
	match pool_name:
		"ship":
			return 50000.0  # ~50KB per ship
		"projectile":
			return 5000.0   # ~5KB per projectile
		"effect":
			return 10000.0  # ~10KB per effect
		"weapon":
			return 15000.0  # ~15KB per weapon
		"debris":
			return 8000.0   # ~8KB per debris
		"audio":
			return 12000.0  # ~12KB per audio
		_:
			return 5000.0   # Default estimate

## Get total number of pooled objects
func _get_total_pooled_objects() -> int:
	var total: int = 0
	for pool in object_pools.values():
		total += pool.get_total_count()
	return total

# Public API

## Get pool statistics
func get_pool_statistics(pool_name: String = "") -> Dictionary:
	if pool_name != "" and pool_statistics.has(pool_name):
		var stats: PoolStatistics = pool_statistics[pool_name]
		return {
			"pool_name": stats.pool_name,
			"current_size": stats.current_size,
			"active_objects": stats.active_objects,
			"peak_active": stats.peak_active,
			"total_acquired": stats.total_acquired,
			"total_returned": stats.total_returned,
			"total_created": stats.total_created,
			"memory_estimate_mb": stats.memory_estimate_mb,
			"efficiency_rating": stats.efficiency_rating
		}
	else:
		# Return all pool statistics
		var all_stats: Dictionary = {}
		for name in pool_statistics.keys():
			all_stats[name] = get_pool_statistics(name)
		return all_stats

## Get comprehensive pooling statistics
func get_comprehensive_statistics() -> Dictionary:
	var total_objects: int = _get_total_pooled_objects()
	var total_active: int = 0
	var total_memory: float = 0.0
	var total_efficiency: float = 0.0
	var pool_count: int = 0
	
	for stats in pool_statistics.values():
		total_active += stats.active_objects
		total_memory += stats.memory_estimate_mb
		total_efficiency += stats.efficiency_rating
		pool_count += 1
	
	var average_efficiency: float = total_efficiency / max(1, pool_count)
	
	return {
		"total_pools": object_pools.size(),
		"total_objects": total_objects,
		"total_active_objects": total_active,
		"total_available_objects": total_objects - total_active,
		"total_memory_mb": total_memory,
		"average_efficiency": average_efficiency,
		"pooling_enabled": enable_object_pooling,
		"memory_pressure_threshold": memory_pressure_threshold_mb,
		"cleanup_frequency": cleanup_frequency
	}

## Resize pool
func resize_pool(pool_name: String, new_size: int) -> bool:
	if not object_pools.has(pool_name):
		return false
	
	var pool: ObjectPool = object_pools[pool_name]
	var old_size: int = pool.get_size()
	
	if new_size > old_size:
		# Grow pool
		_populate_pool(pool, new_size - old_size)
	elif new_size < old_size:
		# Shrink pool
		var objects_to_remove: int = old_size - new_size
		for i in range(objects_to_remove):
			if pool.available_objects.size() > 0:
				var obj: Node = pool.available_objects.pop_back()
				if is_instance_valid(obj):
					obj.queue_free()
	
	pool_resized.emit(pool_name, old_size, pool.get_size())
	return true

## Clear pool
func clear_pool(pool_name: String) -> bool:
	if not object_pools.has(pool_name):
		return false
	
	var pool: ObjectPool = object_pools[pool_name]
	
	# Free all available objects
	for obj in pool.available_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	
	# Force return active objects (emergency cleanup)
	for obj in pool.active_objects:
		if is_instance_valid(obj):
			return_object(obj)
	
	pool.available_objects.clear()
	pool.active_objects.clear()
	
	print("ObjectPoolManager: Cleared pool '%s'" % pool_name)
	return true

## Set pooling enabled/disabled
func set_pooling_enabled(enabled: bool) -> void:
	enable_object_pooling = enabled
	set_process(enabled)
	
	if not enabled:
		# Return all active objects to pools
		for pool in object_pools.values():
			for obj in pool.active_objects.duplicate():
				return_object(obj)
	
	print("ObjectPoolManager: Object pooling %s" % ("enabled" if enabled else "disabled"))

## Force cleanup all pools
func force_cleanup_all_pools() -> void:
	for pool in object_pools.values():
		pool.last_cleanup_time = 0.0  # Force cleanup
	
	_cleanup_unused_objects()
	print("ObjectPoolManager: Forced cleanup of all pools completed")