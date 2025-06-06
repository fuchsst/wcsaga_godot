class_name CollisionOptimizer
extends RefCounted

## Collision detection optimization using spatial partitioning to reduce unnecessary collision checks.
## Integrates with the spatial hash system to provide efficient broad-phase collision detection.
## 
## Replaces WCS's linear O(n²) collision checking with spatially-aware O(1) average case performance
## while maintaining compatibility with WCS collision pair management patterns.

signal collision_pair_created(obj_a: Node3D, obj_b: Node3D, pair_type: String)
signal collision_pair_destroyed(obj_a: Node3D, obj_b: Node3D, reason: String)
signal broad_phase_completed(candidates: int, pairs: int, time_ms: float)
signal performance_warning(message: String, check_time_ms: float)

# Dependencies
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")

# Core systems
var spatial_hash: SpatialHash
var collision_matrix: Dictionary = {}  # Define which types can collide
var active_pairs: Dictionary = {}  # Currently active collision pairs
var pair_timestamps: Dictionary = {}  # Last check timestamps for pairs

# Performance settings
var enable_temporal_coherence: bool = true  # Use timing to skip checks
var collision_check_interval_ms: int = 25  # Default interval between checks
var max_collision_checks_per_frame: int = 200  # Performance limit
var broad_phase_expansion: float = 50.0  # Extra radius for broad phase

# Collision categories from WCS
enum CollisionCategory {
	SHIP_TO_SHIP,
	SHIP_TO_WEAPON,
	SHIP_TO_DEBRIS,
	WEAPON_TO_WEAPON,
	WEAPON_TO_DEBRIS,
	DEBRIS_TO_DEBRIS,
	BEAM_TO_SHIP,
	BEAM_TO_DEBRIS,
	SHOCKWAVE_TO_SHIP,
	ASTEROID_TO_SHIP,
	ASTEROID_TO_WEAPON
}

# Performance tracking
var total_broad_phase_checks: int = 0
var total_narrow_phase_checks: int = 0
var total_collisions_detected: int = 0
var frame_collision_checks: int = 0
var last_performance_reset: int = 0

func _init(hash_instance: SpatialHash) -> void:
	"""Initialize collision optimizer with spatial hash system.
	
	Args:
		hash_instance: SpatialHash instance for spatial queries
	"""
	spatial_hash = hash_instance
	_setup_collision_matrix()
	last_performance_reset = Time.get_ticks_msec()
	
	# Connect to spatial hash signals for optimization
	if spatial_hash.has_signal("object_moved"):
		spatial_hash.object_moved.connect(_on_object_moved)

func _setup_collision_matrix() -> void:
	"""Setup collision matrix defining which object types can collide.
	
	Based on WCS object collision rules from objcollide.cpp
	"""
	# Ship collisions
	_add_collision_rule(ObjectTypes.Type.SHIP, ObjectTypes.Type.WEAPON, CollisionCategory.SHIP_TO_WEAPON)
	_add_collision_rule(ObjectTypes.Type.SHIP, ObjectTypes.Type.DEBRIS, CollisionCategory.SHIP_TO_DEBRIS)
	_add_collision_rule(ObjectTypes.Type.SHIP, ObjectTypes.Type.ASTEROID, CollisionCategory.ASTEROID_TO_SHIP)
	_add_collision_rule(ObjectTypes.Type.SHIP, ObjectTypes.Type.SHOCKWAVE, CollisionCategory.SHOCKWAVE_TO_SHIP)
	
	# Fighter/Bomber specific (inherit ship rules)
	_add_collision_rule(ObjectTypes.Type.FIGHTER, ObjectTypes.Type.WEAPON, CollisionCategory.SHIP_TO_WEAPON)
	_add_collision_rule(ObjectTypes.Type.FIGHTER, ObjectTypes.Type.DEBRIS, CollisionCategory.SHIP_TO_DEBRIS)
	_add_collision_rule(ObjectTypes.Type.BOMBER, ObjectTypes.Type.WEAPON, CollisionCategory.SHIP_TO_WEAPON)
	_add_collision_rule(ObjectTypes.Type.BOMBER, ObjectTypes.Type.DEBRIS, CollisionCategory.SHIP_TO_DEBRIS)
	
	# Capital ship collisions
	_add_collision_rule(ObjectTypes.Type.CAPITAL, ObjectTypes.Type.WEAPON, CollisionCategory.SHIP_TO_WEAPON)
	_add_collision_rule(ObjectTypes.Type.CAPITAL, ObjectTypes.Type.DEBRIS, CollisionCategory.SHIP_TO_DEBRIS)
	_add_collision_rule(ObjectTypes.Type.CAPITAL, ObjectTypes.Type.SHIP, CollisionCategory.SHIP_TO_SHIP)
	
	# Weapon collisions
	_add_collision_rule(ObjectTypes.Type.WEAPON, ObjectTypes.Type.DEBRIS, CollisionCategory.WEAPON_TO_DEBRIS)
	_add_collision_rule(ObjectTypes.Type.WEAPON, ObjectTypes.Type.ASTEROID, CollisionCategory.ASTEROID_TO_WEAPON)
	
	# Beam weapon collisions
	_add_collision_rule(ObjectTypes.Type.BEAM, ObjectTypes.Type.SHIP, CollisionCategory.BEAM_TO_SHIP)
	_add_collision_rule(ObjectTypes.Type.BEAM, ObjectTypes.Type.DEBRIS, CollisionCategory.BEAM_TO_DEBRIS)
	_add_collision_rule(ObjectTypes.Type.BEAM, ObjectTypes.Type.FIGHTER, CollisionCategory.BEAM_TO_SHIP)
	_add_collision_rule(ObjectTypes.Type.BEAM, ObjectTypes.Type.BOMBER, CollisionCategory.BEAM_TO_SHIP)
	_add_collision_rule(ObjectTypes.Type.BEAM, ObjectTypes.Type.CAPITAL, CollisionCategory.BEAM_TO_SHIP)
	
	# Debris collisions
	_add_collision_rule(ObjectTypes.Type.DEBRIS, ObjectTypes.Type.DEBRIS, CollisionCategory.DEBRIS_TO_DEBRIS)

func get_collision_candidates(object: Node3D, collision_radius: float = 0.0) -> Array[Node3D]:
	"""Get objects that could potentially collide with the given object.
	
	Args:
		object: Object to find collision candidates for
		collision_radius: Additional collision radius expansion
	
	Returns:
		Array of potential collision objects
	"""
	var start_time: int = Time.get_ticks_msec()
	
	# Get object type for collision filtering
	var object_type: ObjectTypes.Type = _get_object_type(object)
	if object_type == ObjectTypes.Type.NONE:
		return []
	
	# Calculate search radius
	var search_radius: float = _get_object_collision_radius(object) + collision_radius + broad_phase_expansion
	
	# Get spatial candidates
	var spatial_candidates: Array[Node3D] = spatial_hash.get_objects_in_radius(
		object.global_position, 
		search_radius
	)
	
	# Filter by collision rules
	var collision_candidates: Array[Node3D] = []
	for candidate: Node3D in spatial_candidates:
		if candidate == object:
			continue
		
		var candidate_type: ObjectTypes.Type = _get_object_type(candidate)
		if _can_collide(object_type, candidate_type):
			collision_candidates.append(candidate)
	
	# Performance tracking
	total_broad_phase_checks += 1
	frame_collision_checks += collision_candidates.size()
	
	var query_time: float = Time.get_ticks_msec() - start_time
	broad_phase_completed.emit(spatial_candidates.size(), collision_candidates.size(), query_time)
	
	return collision_candidates

func update_collision_pairs(objects: Array[Node3D]) -> int:
	"""Update collision pairs for a set of objects with temporal coherence optimization.
	
	Args:
		objects: Objects to update collision pairs for
	
	Returns:
		Number of collision pairs processed
	"""
	var start_time: int = Time.get_ticks_msec()
	var pairs_processed: int = 0
	var current_time: int = Time.get_ticks_msec()
	
	# Reset frame counter
	frame_collision_checks = 0
	
	for object: Node3D in objects:
		if not is_instance_valid(object):
			continue
		
		# Check frame budget
		if frame_collision_checks >= max_collision_checks_per_frame:
			break
		
		# Get collision candidates
		var candidates: Array[Node3D] = get_collision_candidates(object)
		
		for candidate: Node3D in candidates:
			# Create pair identifier
			var pair_id: String = _create_pair_id(object, candidate)
			
			# Check temporal coherence (skip if recently checked)
			if enable_temporal_coherence and _should_skip_pair_check(pair_id, current_time):
				continue
			
			# Update pair timestamp
			pair_timestamps[pair_id] = current_time
			
			# Check if this is a new pair
			if pair_id not in active_pairs:
				_create_collision_pair(object, candidate, pair_id)
			
			pairs_processed += 1
			total_narrow_phase_checks += 1
	
	# Clean up old pairs
	_cleanup_expired_pairs(current_time)
	
	var update_time: float = Time.get_ticks_msec() - start_time
	if update_time > 5.0:  # Warn if update takes >5ms
		performance_warning.emit("Slow collision pair update: %.2fms" % update_time, update_time)
	
	return pairs_processed

func optimize_collision_detection_for_object(object: Node3D) -> Dictionary:
	"""Optimize collision detection settings for a specific object based on its properties.
	
	Args:
		object: Object to optimize collision detection for
	
	Returns:
		Dictionary with optimization settings and recommendations
	"""
	var object_type: ObjectTypes.Type = _get_object_type(object)
	var optimization: Dictionary = {
		"check_interval_ms": collision_check_interval_ms,
		"collision_radius": _get_object_collision_radius(object),
		"priority": _get_collision_priority(object_type),
		"enable_continuous": false,
		"use_compound_shapes": false
	}
	
	# Type-specific optimizations
	match object_type:
		ObjectTypes.Type.WEAPON, ObjectTypes.Type.BEAM:
			# Weapons need frequent collision checks
			optimization["check_interval_ms"] = 0  # Every frame
			optimization["enable_continuous"] = true
			optimization["priority"] = UpdateFrequencies.Frequency.CRITICAL
		
		ObjectTypes.Type.FIGHTER, ObjectTypes.Type.BOMBER:
			# Fighter craft need responsive collision
			optimization["check_interval_ms"] = 16  # ~60 FPS
			optimization["priority"] = UpdateFrequencies.Frequency.HIGH
		
		ObjectTypes.Type.CAPITAL:
			# Capital ships can use slower checks but compound shapes
			optimization["check_interval_ms"] = 33  # ~30 FPS
			optimization["use_compound_shapes"] = true
			optimization["priority"] = UpdateFrequencies.Frequency.MEDIUM
		
		ObjectTypes.Type.DEBRIS, ObjectTypes.Type.ASTEROID:
			# Environmental objects can use slower checks
			optimization["check_interval_ms"] = 100  # ~10 FPS
			optimization["priority"] = UpdateFrequencies.Frequency.LOW
		
		ObjectTypes.Type.SHOCKWAVE, ObjectTypes.Type.FIREBALL:
			# Effects need broad collision detection
			optimization["collision_radius"] *= 1.5
			optimization["check_interval_ms"] = 16
			optimization["priority"] = UpdateFrequencies.Frequency.HIGH
	
	# Performance-based adjustments
	if frame_collision_checks > max_collision_checks_per_frame * 0.8:
		# Reduce frequency when under load
		optimization["check_interval_ms"] = int(optimization["check_interval_ms"] * 1.5)
	
	return optimization

func get_collision_statistics() -> Dictionary:
	"""Get collision detection performance statistics.
	
	Returns:
		Dictionary containing collision detection metrics
	"""
	var current_time: int = Time.get_ticks_msec()
	var elapsed_time: float = current_time - last_performance_reset
	
	var stats: Dictionary = {
		"total_broad_phase_checks": total_broad_phase_checks,
		"total_narrow_phase_checks": total_narrow_phase_checks,
		"total_collisions_detected": total_collisions_detected,
		"active_collision_pairs": active_pairs.size(),
		"frame_collision_checks": frame_collision_checks,
		"max_collision_checks_per_frame": max_collision_checks_per_frame,
		"broad_phase_expansion": broad_phase_expansion,
		"enable_temporal_coherence": enable_temporal_coherence,
		"collision_check_interval_ms": collision_check_interval_ms
	}
	
	# Calculate rates
	if elapsed_time > 0:
		stats["broad_phase_rate"] = total_broad_phase_checks / (elapsed_time / 1000.0)
		stats["narrow_phase_rate"] = total_narrow_phase_checks / (elapsed_time / 1000.0)
		stats["collision_rate"] = total_collisions_detected / (elapsed_time / 1000.0)
	
	return stats

func reset_performance_counters() -> void:
	"""Reset performance tracking counters."""
	total_broad_phase_checks = 0
	total_narrow_phase_checks = 0
	total_collisions_detected = 0
	frame_collision_checks = 0
	last_performance_reset = Time.get_ticks_msec()

func clear_collision_pairs() -> int:
	"""Clear all active collision pairs.
	
	Returns:
		Number of pairs cleared
	"""
	var cleared_count: int = active_pairs.size()
	active_pairs.clear()
	pair_timestamps.clear()
	return cleared_count

# Private helper methods

func _add_collision_rule(type_a: ObjectTypes.Type, type_b: ObjectTypes.Type, category: CollisionCategory) -> void:
	"""Add a collision rule to the collision matrix."""
	var key: String = "%d_%d" % [min(type_a, type_b), max(type_a, type_b)]
	collision_matrix[key] = category

func _can_collide(type_a: ObjectTypes.Type, type_b: ObjectTypes.Type) -> bool:
	"""Check if two object types can collide according to collision matrix."""
	var key: String = "%d_%d" % [min(type_a, type_b), max(type_a, type_b)]
	return key in collision_matrix

func _get_object_type(object: Node3D) -> ObjectTypes.Type:
	"""Get the object type for collision filtering."""
	if object.has_method("get_object_type"):
		return object.get_object_type()
	
	# Fallback type detection
	var script: Script = object.get_script()
	if script:
		var class_name: String = script.get_global_name()
		
		if "Fighter" in class_name:
			return ObjectTypes.Type.FIGHTER
		elif "Bomber" in class_name:
			return ObjectTypes.Type.BOMBER
		elif "Capital" in class_name:
			return ObjectTypes.Type.CAPITAL
		elif "Ship" in class_name:
			return ObjectTypes.Type.SHIP
		elif "Weapon" in class_name:
			return ObjectTypes.Type.WEAPON
		elif "Beam" in class_name:
			return ObjectTypes.Type.BEAM
		elif "Debris" in class_name:
			return ObjectTypes.Type.DEBRIS
		elif "Asteroid" in class_name:
			return ObjectTypes.Type.ASTEROID
		elif "Shockwave" in class_name:
			return ObjectTypes.Type.SHOCKWAVE
		elif "Fireball" in class_name:
			return ObjectTypes.Type.FIREBALL
	
	return ObjectTypes.Type.NONE

func _get_object_collision_radius(object: Node3D) -> float:
	"""Get the collision radius for an object."""
	# Try to get radius from object
	if object.has_method("get_collision_radius"):
		return object.get_collision_radius()
	
	# Try to get AABB and calculate radius
	if object.has_method("get_aabb"):
		var aabb: AABB = object.get_aabb()
		if aabb.size != Vector3.ZERO:
			return aabb.size.length() * 0.5
	
	# Default radius based on object type
	var object_type: ObjectTypes.Type = _get_object_type(object)
	match object_type:
		ObjectTypes.Type.FIGHTER:
			return 15.0
		ObjectTypes.Type.BOMBER:
			return 20.0
		ObjectTypes.Type.CAPITAL:
			return 100.0
		ObjectTypes.Type.SHIP:
			return 25.0
		ObjectTypes.Type.WEAPON:
			return 5.0
		ObjectTypes.Type.DEBRIS:
			return 10.0
		ObjectTypes.Type.ASTEROID:
			return 30.0
		_:
			return 20.0  # Default radius

func _get_collision_priority(object_type: ObjectTypes.Type) -> UpdateFrequencies.Frequency:
	"""Get collision detection priority for an object type."""
	match object_type:
		ObjectTypes.Type.WEAPON, ObjectTypes.Type.BEAM:
			return UpdateFrequencies.Frequency.CRITICAL
		ObjectTypes.Type.FIGHTER, ObjectTypes.Type.BOMBER:
			return UpdateFrequencies.Frequency.HIGH
		ObjectTypes.Type.SHIP, ObjectTypes.Type.CAPITAL:
			return UpdateFrequencies.Frequency.MEDIUM
		ObjectTypes.Type.DEBRIS, ObjectTypes.Type.ASTEROID:
			return UpdateFrequencies.Frequency.LOW
		_:
			return UpdateFrequencies.Frequency.MEDIUM

func _create_pair_id(obj_a: Node3D, obj_b: Node3D) -> String:
	"""Create a unique identifier for a collision pair."""
	var id_a: int = obj_a.get_instance_id()
	var id_b: int = obj_b.get_instance_id()
	return "%d_%d" % [min(id_a, id_b), max(id_a, id_b)]

func _should_skip_pair_check(pair_id: String, current_time: int) -> bool:
	"""Check if a collision pair should be skipped due to temporal coherence."""
	if pair_id not in pair_timestamps:
		return false
	
	var last_check: int = pair_timestamps[pair_id]
	var time_since_check: int = current_time - last_check
	
	return time_since_check < collision_check_interval_ms

func _create_collision_pair(obj_a: Node3D, obj_b: Node3D, pair_id: String) -> void:
	"""Create a new collision pair."""
	var type_a: ObjectTypes.Type = _get_object_type(obj_a)
	var type_b: ObjectTypes.Type = _get_object_type(obj_b)
	
	var collision_key: String = "%d_%d" % [min(type_a, type_b), max(type_a, type_b)]
	var category: CollisionCategory = collision_matrix.get(collision_key, CollisionCategory.SHIP_TO_SHIP)
	
	active_pairs[pair_id] = {
		"obj_a": obj_a,
		"obj_b": obj_b,
		"category": category,
		"created_time": Time.get_ticks_msec()
	}
	
	collision_pair_created.emit(obj_a, obj_b, _get_category_name(category))

func _cleanup_expired_pairs(current_time: int) -> int:
	"""Clean up expired collision pairs that are no longer valid."""
	var cleanup_threshold: int = 1000  # 1 second timeout
	var removed_count: int = 0
	var pairs_to_remove: Array[String] = []
	
	for pair_id: String in active_pairs.keys():
		var pair_data: Dictionary = active_pairs[pair_id]
		var obj_a: Node3D = pair_data["obj_a"]
		var obj_b: Node3D = pair_data["obj_b"]
		
		# Check if objects are still valid
		if not is_instance_valid(obj_a) or not is_instance_valid(obj_b):
			pairs_to_remove.append(pair_id)
			continue
		
		# Check if pair has been inactive too long
		if pair_id in pair_timestamps:
			var last_check: int = pair_timestamps[pair_id]
			if current_time - last_check > cleanup_threshold:
				pairs_to_remove.append(pair_id)
	
	# Remove expired pairs
	for pair_id: String in pairs_to_remove:
		var pair_data: Dictionary = active_pairs[pair_id]
		collision_pair_destroyed.emit(pair_data["obj_a"], pair_data["obj_b"], "expired")
		active_pairs.erase(pair_id)
		pair_timestamps.erase(pair_id)
		removed_count += 1
	
	return removed_count

func _get_category_name(category: CollisionCategory) -> String:
	"""Get human-readable name for collision category."""
	match category:
		CollisionCategory.SHIP_TO_SHIP:
			return "ship_to_ship"
		CollisionCategory.SHIP_TO_WEAPON:
			return "ship_to_weapon"
		CollisionCategory.SHIP_TO_DEBRIS:
			return "ship_to_debris"
		CollisionCategory.WEAPON_TO_WEAPON:
			return "weapon_to_weapon"
		CollisionCategory.WEAPON_TO_DEBRIS:
			return "weapon_to_debris"
		CollisionCategory.DEBRIS_TO_DEBRIS:
			return "debris_to_debris"
		CollisionCategory.BEAM_TO_SHIP:
			return "beam_to_ship"
		CollisionCategory.BEAM_TO_DEBRIS:
			return "beam_to_debris"
		CollisionCategory.SHOCKWAVE_TO_SHIP:
			return "shockwave_to_ship"
		CollisionCategory.ASTEROID_TO_SHIP:
			return "asteroid_to_ship"
		CollisionCategory.ASTEROID_TO_WEAPON:
			return "asteroid_to_weapon"
		_:
			return "unknown"

func _on_object_moved(object: Node3D, old_position: Vector3, new_position: Vector3) -> void:
	"""Handle object movement for collision pair invalidation."""
	# Invalidate collision pairs for moved objects
	var pairs_to_update: Array[String] = []
	
	for pair_id: String in active_pairs.keys():
		var pair_data: Dictionary = active_pairs[pair_id]
		if pair_data["obj_a"] == object or pair_data["obj_b"] == object:
			pairs_to_update.append(pair_id)
	
	# Mark pairs for immediate recheck
	for pair_id: String in pairs_to_update:
		if pair_id in pair_timestamps:
			pair_timestamps[pair_id] = 0  # Force immediate recheck