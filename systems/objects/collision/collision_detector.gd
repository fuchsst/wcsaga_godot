class_name CollisionDetector
extends Node

## High-performance collision detection system with multi-layer support for WCS-Godot conversion.
## Handles collision detection between space objects while maintaining optimal performance through
## sophisticated filtering, caching, and multi-level detection algorithms based on WCS collision system.
##
## Key Features:
## - Multi-layer collision support (ships, weapons, debris, triggers)
## - Parent-child collision rejection to prevent inappropriate collisions
## - Collision group filtering for organized collision management
## - Performance optimization through collision pair caching and timestamping
## - Integration with Godot's physics engine for broad phase detection

signal collision_pair_detected(object_a: Node3D, object_b: Node3D, collision_info: Dictionary)
signal collision_resolved(collision_id: int, resolution_data: Dictionary)
signal collision_filtered(object_a: Node3D, object_b: Node3D, filter_reason: String)

# Core classes from EPIC-001 foundation
const WCSObject = preload("res://scripts/core/wcs_object.gd")
const CustomPhysicsBody = preload("res://scripts/core/custom_physics_body.gd")

# EPIC-002 Asset Core Integration - MANDATORY
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

# Collision system components
const CollisionFilter = preload("res://systems/objects/collision/collision_filter.gd")
const ShapeGenerator = preload("res://systems/objects/collision/shape_generator.gd")

# Configuration
@export var collision_enabled: bool = true
@export var max_collision_pairs: int = 10000  # Based on WCS MAX_PAIRS
@export var collision_check_interval_ms: int = 25  # WCS default check interval
@export var broad_phase_enabled: bool = true  # Use Godot physics for broad phase
@export var narrow_phase_enabled: bool = true  # Custom detailed collision checking
@export var enable_debug_visualization: bool = false

# Collision pair management (WCS-inspired)
var collision_pairs: Array[CollisionPair] = []
var collision_pair_pool: Array[CollisionPair] = []
var active_pairs_by_id: Dictionary = {}  # collision_id -> CollisionPair
var object_pair_cache: Dictionary = {}  # "obj_a_id:obj_b_id" -> CollisionPair

# Collision filtering and shape management
var collision_filter: CollisionFilter
var shape_generator: ShapeGenerator

# Performance tracking
var collision_checks_this_frame: int = 0
var collision_pairs_created: int = 0
var collision_pairs_cached: int = 0
var collision_performance_budget_ms: float = 1.0  # AC4: <1ms for 200 objects

# Multi-layer collision configuration (AC1)
var collision_layers_config: Dictionary = {
	"ships": {
		"layer": CollisionLayers.Layer.SHIPS,
		"mask": CollisionLayers.Layer.SHIPS | CollisionLayers.Layer.WEAPONS | CollisionLayers.Layer.DEBRIS | CollisionLayers.Layer.ASTEROIDS,
		"priority": 1  # Highest priority
	},
	"weapons": {
		"layer": CollisionLayers.Layer.WEAPONS,
		"mask": CollisionLayers.Layer.SHIPS | CollisionLayers.Layer.DEBRIS | CollisionLayers.Layer.ASTEROIDS,
		"priority": 2  # High priority
	},
	"debris": {
		"layer": CollisionLayers.Layer.DEBRIS,
		"mask": CollisionLayers.Layer.SHIPS | CollisionLayers.Layer.WEAPONS | CollisionLayers.Layer.DEBRIS,
		"priority": 3  # Medium priority
	},
	"triggers": {
		"layer": CollisionLayers.Layer.TRIGGERS,
		"mask": CollisionLayers.Layer.SHIPS | CollisionLayers.Layer.WEAPONS,
		"priority": 4  # Lower priority
	}
}

# Collision timing and optimization
var frame_counter: int = 0
var last_optimization_frame: int = 0

## Collision pair data structure inspired by WCS obj_pair
class CollisionPair:
	var object_a: Node3D
	var object_b: Node3D
	var collision_id: int
	var next_check_timestamp: int
	var check_collision_function: Callable
	var collision_type: int
	var last_collision_result: Dictionary
	var is_active: bool
	var creation_frame: int
	var last_checked_frame: int
	var collision_count: int
	
	func _init(obj_a: Node3D, obj_b: Node3D, collision_id_val: int) -> void:
		object_a = obj_a
		object_b = obj_b
		collision_id = collision_id_val
		next_check_timestamp = Time.get_ticks_msec()
		last_collision_result = {}
		is_active = true
		creation_frame = Engine.get_process_frames()
		last_checked_frame = 0
		collision_count = 0
		
		# Determine collision type and function based on object types
		_setup_collision_function()
	
	func _setup_collision_function() -> void:
		"""Setup collision checking function based on object types."""
		var type_a: ObjectTypes.Type = _get_object_type(object_a)
		var type_b: ObjectTypes.Type = _get_object_type(object_b)
		
		# Match WCS collision type determination
		collision_type = (type_a << 8) | type_b
		
		match collision_type:
			_get_collision_of(ObjectTypes.Type.SHIP, ObjectTypes.Type.WEAPON):
				check_collision_function = _check_ship_weapon_collision
			_get_collision_of(ObjectTypes.Type.WEAPON, ObjectTypes.Type.SHIP):
				check_collision_function = _check_weapon_ship_collision
			_get_collision_of(ObjectTypes.Type.DEBRIS, ObjectTypes.Type.WEAPON):
				check_collision_function = _check_debris_weapon_collision
			_get_collision_of(ObjectTypes.Type.WEAPON, ObjectTypes.Type.DEBRIS):
				check_collision_function = _check_weapon_debris_collision
			_get_collision_of(ObjectTypes.Type.SHIP, ObjectTypes.Type.SHIP):
				check_collision_function = _check_ship_ship_collision
			_get_collision_of(ObjectTypes.Type.ASTEROID, ObjectTypes.Type.WEAPON):
				check_collision_function = _check_asteroid_weapon_collision
			_get_collision_of(ObjectTypes.Type.WEAPON, ObjectTypes.Type.ASTEROID):
				check_collision_function = _check_weapon_asteroid_collision
			_:
				check_collision_function = _check_generic_collision
	
	func _get_object_type(obj: Node3D) -> ObjectTypes.Type:
		"""Get object type for collision determination."""
		if obj.has_method("get_object_type"):
			return obj.get_object_type()
		
		# Fallback to name-based detection
		if "ship" in obj.name.to_lower():
			return ObjectTypes.Type.SHIP
		elif "weapon" in obj.name.to_lower():
			return ObjectTypes.Type.WEAPON
		elif "debris" in obj.name.to_lower():
			return ObjectTypes.Type.DEBRIS
		elif "asteroid" in obj.name.to_lower():
			return ObjectTypes.Type.ASTEROID
		
		return ObjectTypes.Type.SHIP  # Default fallback
	
	func _get_collision_of(type_a: ObjectTypes.Type, type_b: ObjectTypes.Type) -> int:
		"""Generate collision type ID similar to WCS COLLISION_OF macro."""
		return (type_a << 8) | type_b
	
	func should_check_collision() -> bool:
		"""Check if this collision pair should be checked this frame."""
		return Time.get_ticks_msec() >= next_check_timestamp
	
	func update_next_check_time(interval_ms: int = 25) -> void:
		"""Update when this pair should next be checked."""
		next_check_timestamp = Time.get_ticks_msec() + interval_ms

func _ready() -> void:
	# Initialize collision subsystems
	collision_filter = CollisionFilter.new()
	shape_generator = ShapeGenerator.new()
	add_child(collision_filter)
	add_child(shape_generator)
	
	# Connect to physics manager for physics step integration
	var physics_manager: Node = get_node("/root/PhysicsManager")
	if physics_manager and physics_manager.has_signal("physics_step_completed"):
		physics_manager.physics_step_completed.connect(_on_physics_step_completed)
	
	# Initialize collision pair pool
	_initialize_collision_pair_pool()
	
	print("CollisionDetector: Initialized with multi-layer collision support")

func _initialize_collision_pair_pool() -> void:
	"""Initialize pool of collision pairs for efficient memory management."""
	collision_pair_pool.clear()
	
	# Pre-allocate collision pairs for performance (WCS-inspired)
	for i in range(2500):  # WCS MIN_PAIRS
		var dummy_pair: CollisionPair = CollisionPair.new(Node3D.new(), Node3D.new(), i)
		collision_pair_pool.append(dummy_pair)

## Register objects for collision detection (AC1)
func register_collision_object(object: Node3D, collision_layer: String = "ships") -> bool:
	"""Register a space object for collision detection with specific layer.
	
	Args:
		object: Node3D object to register for collision detection
		collision_layer: Collision layer name ("ships", "weapons", "debris", "triggers")
		
	Returns:
		true if registration successful
	"""
	if not collision_enabled:
		return false
		
	if not is_instance_valid(object):
		push_error("CollisionDetector: Cannot register invalid object")
		return false
	
	if not collision_layer in collision_layers_config:
		push_error("CollisionDetector: Unknown collision layer: %s" % collision_layer)
		return false
	
	# Configure object collision layer and mask (AC1)
	var layer_config: Dictionary = collision_layers_config[collision_layer]
	if object.has_method("set_collision_layer"):
		object.set_collision_layer(layer_config.layer)
	if object.has_method("set_collision_mask"):
		object.set_collision_mask(layer_config.mask)
	
	# Create collision pairs with existing registered objects
	_create_collision_pairs_for_new_object(object)
	
	print("CollisionDetector: Registered object %s on layer %s" % [object.name, collision_layer])
	return true

func unregister_collision_object(object: Node3D) -> void:
	"""Unregister an object from collision detection.
	
	Args:
		object: Node3D object to unregister
	"""
	if not is_instance_valid(object):
		return
	
	# Remove all collision pairs involving this object
	var pairs_to_remove: Array[CollisionPair] = []
	for pair in collision_pairs:
		if pair.object_a == object or pair.object_b == object:
			pairs_to_remove.append(pair)
	
	for pair in pairs_to_remove:
		_remove_collision_pair(pair)
	
	print("CollisionDetector: Unregistered object %s" % object.name)

## Create collision pairs for a newly registered object
func _create_collision_pairs_for_new_object(new_object: Node3D) -> void:
	"""Create collision pairs between new object and existing registered objects."""
	var existing_objects: Array[Node3D] = _get_all_registered_collision_objects()
	
	for existing_object in existing_objects:
		if existing_object == new_object:
			continue
			
		# Check if collision pair should be created (AC3: collision filtering)
		if collision_filter.should_create_collision_pair(new_object, existing_object):
			_add_collision_pair(new_object, existing_object)

func _get_all_registered_collision_objects() -> Array[Node3D]:
	"""Get all currently registered collision objects."""
	var objects: Array[Node3D] = []
	
	# Extract unique objects from collision pairs
	for pair in collision_pairs:
		if not objects.has(pair.object_a):
			objects.append(pair.object_a)
		if not objects.has(pair.object_b):
			objects.append(pair.object_b)
	
	return objects

## Add collision pair with filtering and validation (AC3)
func _add_collision_pair(object_a: Node3D, object_b: Node3D) -> CollisionPair:
	"""Add a collision pair with proper filtering and validation.
	
	Args:
		object_a: First collision object
		object_b: Second collision object
		
	Returns:
		CollisionPair instance or null if pair was rejected
	"""
	# Pre-validation checks
	if object_a == object_b:
		return null  # Don't check collisions with yourself
	
	if not _objects_have_collision_flags(object_a, object_b):
		collision_filtered.emit(object_a, object_b, "Missing collision flags")
		return null
	
	# Apply collision filtering (AC3)
	if not collision_filter.should_create_collision_pair(object_a, object_b):
		collision_filtered.emit(object_a, object_b, "Filtered by collision rules")
		return null
	
	# Check if pair already exists
	var pair_key: String = _generate_pair_key(object_a, object_b)
	if pair_key in object_pair_cache:
		return object_pair_cache[pair_key]
	
	# Create new collision pair
	var new_pair: CollisionPair = _get_collision_pair_from_pool()
	if not new_pair:
		push_warning("CollisionDetector: Maximum collision pairs reached")
		return null
	
	new_pair.object_a = object_a
	new_pair.object_b = object_b
	new_pair.collision_id = collision_pairs_created
	new_pair._setup_collision_function()
	
	collision_pairs.append(new_pair)
	active_pairs_by_id[new_pair.collision_id] = new_pair
	object_pair_cache[pair_key] = new_pair
	
	collision_pairs_created += 1
	return new_pair

func _objects_have_collision_flags(object_a: Node3D, object_b: Node3D) -> bool:
	"""Check if objects have proper collision flags set."""
	# Check if objects have collision capability
	var a_has_collision: bool = false
	var b_has_collision: bool = false
	
	if object_a.has_method("has_collision_enabled"):
		a_has_collision = object_a.has_collision_enabled()
	elif object_a is RigidBody3D or object_a is CharacterBody3D or object_a is Area3D:
		a_has_collision = true
	
	if object_b.has_method("has_collision_enabled"):
		b_has_collision = object_b.has_collision_enabled()
	elif object_b is RigidBody3D or object_b is CharacterBody3D or object_b is Area3D:
		b_has_collision = true
	
	return a_has_collision and b_has_collision

func _generate_pair_key(object_a: Node3D, object_b: Node3D) -> String:
	"""Generate unique key for collision pair caching."""
	var id_a: int = object_a.get_instance_id()
	var id_b: int = object_b.get_instance_id()
	
	# Ensure consistent ordering for cache lookup
	if id_a > id_b:
		return "%d:%d" % [id_b, id_a]
	else:
		return "%d:%d" % [id_a, id_b]

func _get_collision_pair_from_pool() -> CollisionPair:
	"""Get collision pair from pool or create new one."""
	if collision_pairs.size() >= max_collision_pairs:
		return null
	
	var pair: CollisionPair
	if collision_pair_pool.size() > 0:
		pair = collision_pair_pool.pop_back()
		collision_pairs_cached += 1
	else:
		pair = CollisionPair.new(Node3D.new(), Node3D.new(), collision_pairs_created)
	
	return pair

func _remove_collision_pair(pair: CollisionPair) -> void:
	"""Remove collision pair and return to pool."""
	collision_pairs.erase(pair)
	active_pairs_by_id.erase(pair.collision_id)
	
	# Remove from cache
	var pair_key: String = _generate_pair_key(pair.object_a, pair.object_b)
	object_pair_cache.erase(pair_key)
	
	# Return to pool for reuse
	pair.is_active = false
	collision_pair_pool.append(pair)

## Main collision detection processing (AC4: Multi-level collision detection)
func _on_physics_step_completed(delta: float) -> void:
	"""Process collision detection for this physics step."""
	if not collision_enabled:
		return
	
	var collision_start_time: float = Time.get_ticks_usec() / 1000.0
	collision_checks_this_frame = 0
	frame_counter += 1
	
	# Process collision pairs with timing optimization
	_process_collision_pairs()
	
	# Performance monitoring (AC4)
	var collision_end_time: float = Time.get_ticks_usec() / 1000.0
	var collision_time_ms: float = collision_end_time - collision_start_time
	
	# Check performance budget
	if collision_time_ms > collision_performance_budget_ms:
		_optimize_collision_performance()
	
	# Periodic optimization
	if frame_counter % 240 == 0:  # Every 4 seconds at 60 FPS
		_cleanup_inactive_pairs()

func _process_collision_pairs() -> void:
	"""Process all active collision pairs for collision detection."""
	for pair in collision_pairs:
		if not pair.is_active:
			continue
			
		if not is_instance_valid(pair.object_a) or not is_instance_valid(pair.object_b):
			_remove_collision_pair(pair)
			continue
		
		# Check timing for performance optimization
		if not pair.should_check_collision():
			continue
		
		# Perform collision check
		_check_collision_pair(pair)
		collision_checks_this_frame += 1
		
		# Update timing
		pair.update_next_check_time(collision_check_interval_ms)
		pair.last_checked_frame = frame_counter

## Multi-level collision checking (AC4)
func _check_collision_pair(pair: CollisionPair) -> void:
	"""Perform multi-level collision detection on a collision pair.
	
	Implements WCS-style collision detection:
	1. Broad phase: Quick bounding sphere/box check
	2. Narrow phase: Detailed collision shape analysis
	"""
	# Broad phase collision detection (AC4)
	if broad_phase_enabled:
		if not _broad_phase_collision_check(pair):
			return  # No collision in broad phase
	
	# Narrow phase collision detection (AC4)
	if narrow_phase_enabled:
		var collision_result: Dictionary = _narrow_phase_collision_check(pair)
		
		if not collision_result.is_empty():
			_handle_collision_detected(pair, collision_result)

func _broad_phase_collision_check(pair: CollisionPair) -> bool:
	"""Perform broad phase collision detection using simple shapes.
	
	Args:
		pair: CollisionPair to check
		
	Returns:
		true if objects might be colliding (pass to narrow phase)
	"""
	var pos_a: Vector3 = pair.object_a.global_position
	var pos_b: Vector3 = pair.object_b.global_position
	
	# Get bounding radii for quick sphere check
	var radius_a: float = _get_object_bounding_radius(pair.object_a)
	var radius_b: float = _get_object_bounding_radius(pair.object_b)
	
	var distance: float = pos_a.distance_to(pos_b)
	var min_collision_distance: float = radius_a + radius_b
	
	return distance <= min_collision_distance

func _narrow_phase_collision_check(pair: CollisionPair) -> Dictionary:
	"""Perform detailed narrow phase collision detection.
	
	Args:
		pair: CollisionPair to check
		
	Returns:
		Dictionary containing collision information or empty if no collision
	"""
	var collision_info: Dictionary = {}
	
	# Use the pair's specific collision function
	if pair.check_collision_function.is_valid():
		collision_info = pair.check_collision_function.call(pair)
	else:
		collision_info = _check_generic_collision(pair)
	
	return collision_info

func _get_object_bounding_radius(obj: Node3D) -> float:
	"""Get bounding radius for an object."""
	if obj.has_method("get_collision_radius"):
		return obj.get_collision_radius()
	
	# Fallback: estimate from collision shape
	if obj.has_method("get_child"):
		for child in obj.get_children():
			if child is CollisionShape3D:
				var shape: Shape3D = child.shape
				if shape is SphereShape3D:
					return shape.radius
				elif shape is BoxShape3D:
					return shape.size.length() * 0.5
				elif shape is CapsuleShape3D:
					return maxf(shape.radius, shape.height * 0.5)
	
	return 1.0  # Default radius

## Collision type-specific detection functions (based on WCS collision types)

func _check_ship_weapon_collision(pair: CollisionPair) -> Dictionary:
	"""Check collision between ship and weapon."""
	return _check_generic_collision_with_damage(pair, "ship_weapon")

func _check_weapon_ship_collision(pair: CollisionPair) -> Dictionary:
	"""Check collision between weapon and ship (swapped version)."""
	return _check_generic_collision_with_damage(pair, "weapon_ship")

func _check_debris_weapon_collision(pair: CollisionPair) -> Dictionary:
	"""Check collision between debris and weapon."""
	return _check_generic_collision_with_damage(pair, "debris_weapon")

func _check_weapon_debris_collision(pair: CollisionPair) -> Dictionary:
	"""Check collision between weapon and debris."""
	return _check_generic_collision_with_damage(pair, "weapon_debris")

func _check_ship_ship_collision(pair: CollisionPair) -> Dictionary:
	"""Check collision between two ships."""
	return _check_generic_collision_with_damage(pair, "ship_ship")

func _check_asteroid_weapon_collision(pair: CollisionPair) -> Dictionary:
	"""Check collision between asteroid and weapon."""
	return _check_generic_collision_with_damage(pair, "asteroid_weapon")

func _check_weapon_asteroid_collision(pair: CollisionPair) -> Dictionary:
	"""Check collision between weapon and asteroid."""
	return _check_generic_collision_with_damage(pair, "weapon_asteroid")

func _check_generic_collision(pair: CollisionPair) -> Dictionary:
	"""Generic collision detection for unspecified object type combinations."""
	return _check_generic_collision_with_damage(pair, "generic")

func _check_generic_collision_with_damage(pair: CollisionPair, collision_type: String) -> Dictionary:
	"""Generic collision detection with damage calculation."""
	var collision_info: Dictionary = {}
	
	# Use Godot's physics system for collision detection (AC6)
	var space_state: PhysicsDirectSpaceState3D = pair.object_a.get_world_3d().direct_space_state
	
	# Create collision query
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	
	# Get collision shapes from objects
	var shape_a: Shape3D = _get_collision_shape_from_object(pair.object_a)
	var shape_b: Shape3D = _get_collision_shape_from_object(pair.object_b)
	
	if not shape_a or not shape_b:
		return collision_info
	
	# Setup query parameters
	query.shape = shape_a
	query.transform = pair.object_a.global_transform
	query.collision_mask = _get_object_collision_mask(pair.object_b)
	
	# Perform collision query
	var collision_result: Array = space_state.intersect_shape(query)
	
	if collision_result.size() > 0:
		# Found collision - extract information
		var result: Dictionary = collision_result[0]
		collision_info = {
			"collision_detected": true,
			"collision_type": collision_type,
			"collision_point": result.get("point", Vector3.ZERO),
			"collision_normal": result.get("normal", Vector3.ZERO),
			"collider": result.get("collider"),
			"collision_id": pair.collision_id,
			"timestamp": Time.get_ticks_msec()
		}
		
		pair.collision_count += 1
	
	return collision_info

func _get_collision_shape_from_object(obj: Node3D) -> Shape3D:
	"""Extract collision shape from object."""
	for child in obj.get_children():
		if child is CollisionShape3D:
			return child.shape
	
	return null

func _get_object_collision_mask(obj: Node3D) -> int:
	"""Get collision mask from object."""
	if obj.has_method("get_collision_mask"):
		return obj.get_collision_mask()
	
	return 1  # Default mask

## Collision event handling
func _handle_collision_detected(pair: CollisionPair, collision_info: Dictionary) -> void:
	"""Handle detected collision between objects.
	
	Args:
		pair: CollisionPair that detected collision
		collision_info: Dictionary containing collision details
	"""
	pair.last_collision_result = collision_info
	
	# Emit collision signal
	collision_pair_detected.emit(pair.object_a, pair.object_b, collision_info)
	
	# Optional debug visualization (AC6)
	if enable_debug_visualization:
		_visualize_collision(pair, collision_info)

func _visualize_collision(pair: CollisionPair, collision_info: Dictionary) -> void:
	"""Visualize collision for debugging purposes."""
	var collision_point: Vector3 = collision_info.get("collision_point", Vector3.ZERO)
	var collision_normal: Vector3 = collision_info.get("collision_normal", Vector3.ZERO)
	
	print("COLLISION DETECTED: %s <-> %s at %s" % [
		pair.object_a.name, pair.object_b.name, collision_point
	])

## Performance optimization functions (AC4)
func _optimize_collision_performance() -> void:
	"""Optimize collision detection performance when budget is exceeded."""
	# Increase collision check intervals for non-critical pairs
	for pair in collision_pairs:
		if pair.collision_count == 0:  # Pairs that never collided
			pair.update_next_check_time(collision_check_interval_ms * 2)

func _cleanup_inactive_pairs() -> void:
	"""Clean up inactive or invalid collision pairs."""
	var pairs_to_remove: Array[CollisionPair] = []
	
	for pair in collision_pairs:
		if not is_instance_valid(pair.object_a) or not is_instance_valid(pair.object_b):
			pairs_to_remove.append(pair)
		elif not pair.is_active:
			pairs_to_remove.append(pair)
	
	for pair in pairs_to_remove:
		_remove_collision_pair(pair)

## Public API for external systems
func get_collision_pairs_for_object(obj: Node3D) -> Array[CollisionPair]:
	"""Get all collision pairs involving a specific object.
	
	Args:
		obj: Node3D object to find pairs for
		
	Returns:
		Array of CollisionPair instances involving the object
	"""
	var object_pairs: Array[CollisionPair] = []
	
	for pair in collision_pairs:
		if pair.object_a == obj or pair.object_b == obj:
			object_pairs.append(pair)
	
	return object_pairs

func get_collision_statistics() -> Dictionary:
	"""Get collision detection performance statistics.
	
	Returns:
		Dictionary containing collision system statistics
	"""
	return {
		"collision_pairs_active": collision_pairs.size(),
		"collision_pairs_created": collision_pairs_created,
		"collision_pairs_cached": collision_pairs_cached,
		"collision_checks_this_frame": collision_checks_this_frame,
		"collision_pair_pool_size": collision_pair_pool.size(),
		"collision_enabled": collision_enabled,
		"frame_counter": frame_counter
	}

func set_collision_enabled(enabled: bool) -> void:
	"""Enable or disable collision detection system.
	
	Args:
		enabled: true to enable collision detection, false to disable
	"""
	collision_enabled = enabled
	print("CollisionDetector: Collision detection %s" % ("enabled" if enabled else "disabled"))

func set_performance_budget_ms(budget_ms: float) -> void:
	"""Set collision detection performance budget.
	
	Args:
		budget_ms: Maximum time in milliseconds for collision detection per frame
	"""
	collision_performance_budget_ms = budget_ms
	print("CollisionDetector: Performance budget set to %.2fms" % budget_ms)