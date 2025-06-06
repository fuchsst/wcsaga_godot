class_name SpatialQuery
extends RefCounted

## High-level spatial query interface for object proximity detection and searches.
## Provides convenient methods for common spatial queries used in WCS gameplay systems.
## 
## Integrates with SpatialHash for efficient O(1) average case performance while maintaining
## the same query interface as the original WCS linear search patterns.

signal query_completed(query_type: String, result_count: int, query_time_ms: float)
signal performance_warning(message: String, query_time_ms: float, object_count: int)

# Core dependencies
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Spatial hash instance for optimization
var spatial_hash: SpatialHash
var enable_performance_monitoring: bool = true
var performance_warning_threshold_ms: float = 1.0  # Warn if queries take >1ms

# Query cache for expensive operations
var advanced_query_cache: Dictionary = {}
var cache_timeout_ms: float = 50.0  # Shorter timeout for dynamic queries
var max_advanced_cache_entries: int = 50

func _init(hash_instance: SpatialHash = null) -> void:
	"""Initialize spatial query system with optional existing spatial hash.
	
	Args:
		hash_instance: Existing SpatialHash instance (creates new if null)
	"""
	if hash_instance:
		spatial_hash = hash_instance
	else:
		spatial_hash = SpatialHash.new(1000.0)

func get_objects_in_radius(center: Vector3, radius: float, options: Dictionary = {}) -> Array[Node3D]:
	"""Get all objects within a specified radius with advanced filtering options.
	
	Args:
		center: Center point for search
		radius: Search radius in world units
		options: Query options dictionary with keys:
			- type_filter: ObjectTypes.Type enum value
			- max_results: Maximum number of results
			- sort_by_distance: Sort results by distance (default: true)
			- exclude_objects: Array of objects to exclude
			- include_inactive: Include inactive objects (default: false)
	
	Returns:
		Array of objects within radius matching criteria
	"""
	var start_time: int = Time.get_ticks_msec()
	var query_type: String = "radius_query"
	
	# Extract options with defaults
	var type_filter: ObjectTypes.Type = options.get("type_filter", ObjectTypes.Type.NONE)
	var max_results: int = options.get("max_results", -1)
	var sort_by_distance: bool = options.get("sort_by_distance", true)
	var exclude_objects: Array = options.get("exclude_objects", [])
	var include_inactive: bool = options.get("include_inactive", false)
	
	# Use spatial hash for base query
	var base_results: Array[Node3D] = spatial_hash.get_objects_in_radius(center, radius, type_filter)
	
	# Apply additional filtering
	var filtered_results: Array[Node3D] = []
	for obj: Node3D in base_results:
		# Skip excluded objects
		if obj in exclude_objects:
			continue
		
		# Check active status if requested
		if not include_inactive and _is_object_inactive(obj):
			continue
		
		filtered_results.append(obj)
	
	# Apply result limit
	if max_results > 0 and filtered_results.size() > max_results:
		if sort_by_distance:
			# Already sorted by spatial hash
			filtered_results.resize(max_results)
		else:
			# Take first N results
			filtered_results.resize(max_results)
	
	# Performance monitoring
	var query_time: float = Time.get_ticks_msec() - start_time
	_emit_performance_signals(query_type, filtered_results.size(), query_time)
	
	return filtered_results

func get_nearest_object(position: Vector3, type_filter: ObjectTypes.Type = ObjectTypes.Type.NONE, exclude_objects: Array = []) -> Node3D:
	"""Get the single nearest object to a position.
	
	Args:
		position: Search center position
		type_filter: Optional object type filter
		exclude_objects: Objects to exclude from search
	
	Returns:
		Nearest object or null if none found
	"""
	var options: Dictionary = {
		"type_filter": type_filter,
		"max_results": 1,
		"exclude_objects": exclude_objects
	}
	
	var results: Array[Node3D] = get_objects_in_radius(position, 10000.0, options)  # Large radius
	return results[0] if results.size() > 0 else null

func get_objects_by_threat_level(center: Vector3, radius: float, min_threat: float = 0.0) -> Array[Node3D]:
	"""Get objects within radius filtered by threat level.
	
	Args:
		center: Center point for search
		radius: Search radius
		min_threat: Minimum threat level to include
	
	Returns:
		Array of threatening objects sorted by threat level (highest first)
	"""
	var start_time: int = Time.get_ticks_msec()
	var cache_key: String = "threat_%.3f_%.1f_%.2f" % [center.x, radius, min_threat]
	
	# Check cache
	if cache_key in advanced_query_cache:
		var cached_data: Dictionary = advanced_query_cache[cache_key]
		if start_time - cached_data["timestamp"] < cache_timeout_ms:
			return cached_data["result"]
	
	# Get potentially threatening object types
	var threat_types: Array[ObjectTypes.Type] = [
		ObjectTypes.Type.SHIP, ObjectTypes.Type.WEAPON, ObjectTypes.Type.BEAM,
		ObjectTypes.Type.FIGHTER, ObjectTypes.Type.BOMBER, ObjectTypes.Type.CAPITAL
	]
	
	var threatening_objects: Array[Node3D] = []
	
	for obj_type: ObjectTypes.Type in threat_types:
		var objects: Array[Node3D] = spatial_hash.get_objects_in_radius(center, radius, obj_type)
		for obj: Node3D in objects:
			var threat_level: float = _get_object_threat_level(obj)
			if threat_level >= min_threat:
				threatening_objects.append(obj)
	
	# Sort by threat level (highest first)
	threatening_objects.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _get_object_threat_level(a) > _get_object_threat_level(b)
	)
	
	# Cache result
	_cache_advanced_query(cache_key, threatening_objects, start_time)
	
	var query_time: float = Time.get_ticks_msec() - start_time
	_emit_performance_signals("threat_query", threatening_objects.size(), query_time)
	
	return threatening_objects

func get_objects_in_cone(origin: Vector3, direction: Vector3, max_distance: float, cone_angle_degrees: float, type_filter: ObjectTypes.Type = ObjectTypes.Type.NONE) -> Array[Node3D]:
	"""Get objects within a cone-shaped search area (useful for weapon targeting).
	
	Args:
		origin: Cone origin point
		direction: Cone direction vector (normalized)
		max_distance: Maximum distance along cone
		cone_angle_degrees: Cone angle in degrees (full angle, not half-angle)
		type_filter: Optional object type filter
	
	Returns:
		Array of objects within cone area
	"""
	var start_time: int = Time.get_ticks_msec()
	
	# Start with radius search as broad phase
	var broad_results: Array[Node3D] = spatial_hash.get_objects_in_radius(origin, max_distance, type_filter)
	var cone_results: Array[Node3D] = []
	
	var normalized_direction: Vector3 = direction.normalized()
	var half_cone_angle_rad: float = deg_to_rad(cone_angle_degrees * 0.5)
	var min_dot_product: float = cos(half_cone_angle_rad)
	
	for obj: Node3D in broad_results:
		var obj_position: Vector3 = obj.global_position
		var to_object: Vector3 = (obj_position - origin).normalized()
		var dot_product: float = normalized_direction.dot(to_object)
		
		# Check if object is within cone angle
		if dot_product >= min_dot_product:
			# Check actual distance
			var distance: float = origin.distance_to(obj_position)
			if distance <= max_distance:
				cone_results.append(obj)
	
	# Sort by distance
	cone_results.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	
	var query_time: float = Time.get_ticks_msec() - start_time
	_emit_performance_signals("cone_query", cone_results.size(), query_time)
	
	return cone_results

func get_line_of_sight_objects(start_position: Vector3, end_position: Vector3, type_filter: ObjectTypes.Type = ObjectTypes.Type.NONE, check_collision: bool = true) -> Array[Node3D]:
	"""Get objects along a line of sight between two points.
	
	Args:
		start_position: Line start position
		end_position: Line end position
		type_filter: Optional object type filter
		check_collision: Whether to check for collision blocking
	
	Returns:
		Array of objects along line of sight
	"""
	var start_time: int = Time.get_ticks_msec()
	
	# Create bounding box for line search area
	var line_direction: Vector3 = end_position - start_position
	var line_length: float = line_direction.length()
	var normalized_direction: Vector3 = line_direction.normalized()
	
	# Use cylinder approximation for line query
	var search_radius: float = 50.0  # Reasonable tolerance for "line of sight"
	var midpoint: Vector3 = start_position + line_direction * 0.5
	var max_distance: float = line_length * 0.5 + search_radius
	
	var candidates: Array[Node3D] = spatial_hash.get_objects_in_radius(midpoint, max_distance, type_filter)
	var line_objects: Array[Node3D] = []
	
	for obj: Node3D in candidates:
		var obj_position: Vector3 = obj.global_position
		
		# Calculate distance from point to line
		var to_point: Vector3 = obj_position - start_position
		var projection_length: float = to_point.dot(normalized_direction)
		
		# Check if projection is within line segment
		if projection_length >= 0.0 and projection_length <= line_length:
			var projection_point: Vector3 = start_position + normalized_direction * projection_length
			var distance_to_line: float = obj_position.distance_to(projection_point)
			
			if distance_to_line <= search_radius:
				# Check collision if requested
				if check_collision:
					# This would integrate with collision system
					# For now, assume no collision blocking
					line_objects.append(obj)
				else:
					line_objects.append(obj)
	
	# Sort by distance along line
	line_objects.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var dist_a: float = (a.global_position - start_position).dot(normalized_direction)
		var dist_b: float = (b.global_position - start_position).dot(normalized_direction)
		return dist_a < dist_b
	)
	
	var query_time: float = Time.get_ticks_msec() - start_time
	_emit_performance_signals("line_of_sight_query", line_objects.size(), query_time)
	
	return line_objects

func get_escort_formation_objects(leader: Node3D, formation_radius: float, preferred_positions: Array[Vector3] = []) -> Array[Node3D]:
	"""Get objects suitable for escort formation around a leader object.
	
	Args:
		leader: Leader object to form around
		formation_radius: Formation radius
		preferred_positions: Preferred relative positions for formation
	
	Returns:
		Array of objects suitable for escort formation
	"""
	if not is_instance_valid(leader):
		return []
	
	var options: Dictionary = {
		"type_filter": ObjectTypes.Type.SHIP,
		"exclude_objects": [leader],
		"include_inactive": false
	}
	
	var candidates: Array[Node3D] = get_objects_in_radius(leader.global_position, formation_radius, options)
	
	# Filter for ships that could serve as escorts
	var escort_candidates: Array[Node3D] = []
	for candidate: Node3D in candidates:
		if _is_suitable_for_escort(candidate, leader):
			escort_candidates.append(candidate)
	
	# Sort by suitability for escort role
	escort_candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _get_escort_suitability_score(a, leader) > _get_escort_suitability_score(b, leader)
	)
	
	return escort_candidates

func find_safe_spawn_position(preferred_position: Vector3, min_clearance: float, max_search_radius: float = 5000.0) -> Vector3:
	"""Find a safe position for spawning objects with minimum clearance from other objects.
	
	Args:
		preferred_position: Preferred spawn position
		min_clearance: Minimum distance from other objects
		max_search_radius: Maximum radius to search for alternative positions
	
	Returns:
		Safe spawn position or preferred_position if no conflicts
	"""
	# Check if preferred position is clear
	var nearby_objects: Array[Node3D] = spatial_hash.get_objects_in_radius(preferred_position, min_clearance)
	if nearby_objects.is_empty():
		return preferred_position
	
	# Search for alternative positions in expanding circles
	var search_attempts: int = 16  # Number of positions to try per radius
	var radius_step: float = min_clearance
	
	for search_radius in range(int(radius_step), int(max_search_radius), int(radius_step)):
		for i in range(search_attempts):
			var angle: float = (float(i) / search_attempts) * TAU
			var test_position: Vector3 = preferred_position + Vector3(
				cos(angle) * search_radius,
				0.0,  # Keep same Y level
				sin(angle) * search_radius
			)
			
			var conflicts: Array[Node3D] = spatial_hash.get_objects_in_radius(test_position, min_clearance)
			if conflicts.is_empty():
				return test_position
	
	# If no safe position found, return preferred position with warning
	push_warning("SpatialQuery: No safe spawn position found within %d units" % max_search_radius)
	return preferred_position

func get_performance_statistics() -> Dictionary:
	"""Get performance statistics for spatial queries.
	
	Returns:
		Dictionary containing query performance metrics
	"""
	var hash_stats: Dictionary = spatial_hash.get_statistics()
	
	hash_stats["advanced_cache_entries"] = advanced_query_cache.size()
	hash_stats["cache_timeout_ms"] = cache_timeout_ms
	hash_stats["performance_monitoring"] = enable_performance_monitoring
	
	return hash_stats

func clear_cache() -> void:
	"""Clear all query caches for memory management."""
	advanced_query_cache.clear()
	spatial_hash.query_cache.clear()

func optimize_performance() -> void:
	"""Optimize spatial query performance based on current usage patterns."""
	spatial_hash.optimize_grid_size()
	_cleanup_advanced_cache()

# Private helper methods

func _is_object_inactive(object: Node3D) -> bool:
	"""Check if an object is inactive and should be excluded from queries."""
	# Try to get activity status from object
	if object.has_method("is_active"):
		return not object.is_active()
	
	# Check if object is in scene tree and visible
	if not object.is_inside_tree():
		return true
	
	# Check basic visibility for visual objects
	if object.has_method("is_visible_in_tree"):
		return not object.is_visible_in_tree()
	
	# Default to active if no status information available
	return false

func _get_object_threat_level(object: Node3D) -> float:
	"""Calculate threat level for an object."""
	# Try to get threat level from object
	if object.has_method("get_threat_level"):
		return object.get_threat_level()
	
	# Estimate threat based on object type and properties
	var threat_level: float = 0.0
	var obj_type: ObjectTypes.Type = _get_object_type(object)
	
	match obj_type:
		ObjectTypes.Type.WEAPON, ObjectTypes.Type.BEAM:
			threat_level = 0.8
		ObjectTypes.Type.FIGHTER:
			threat_level = 0.6
		ObjectTypes.Type.BOMBER:
			threat_level = 0.7
		ObjectTypes.Type.CAPITAL:
			threat_level = 0.9
		ObjectTypes.Type.SHIP:
			threat_level = 0.5
		_:
			threat_level = 0.1
	
	return threat_level

func _get_object_type(object: Node3D) -> ObjectTypes.Type:
	"""Get object type for filtering and classification."""
	if object.has_method("get_object_type"):
		return object.get_object_type()
	
	# Fallback type detection based on class name
	var script: Script = object.get_script()
	if script:
		var class_name: String = script.get_global_name()
		
		if "Fighter" in class_name or "Interceptor" in class_name:
			return ObjectTypes.Type.FIGHTER
		elif "Bomber" in class_name:
			return ObjectTypes.Type.BOMBER
		elif "Capital" in class_name or "Destroyer" in class_name or "Cruiser" in class_name:
			return ObjectTypes.Type.CAPITAL
		elif "Ship" in class_name:
			return ObjectTypes.Type.SHIP
		elif "Weapon" in class_name or "Missile" in class_name:
			return ObjectTypes.Type.WEAPON
		elif "Beam" in class_name:
			return ObjectTypes.Type.BEAM
		elif "Debris" in class_name:
			return ObjectTypes.Type.DEBRIS
		elif "Asteroid" in class_name:
			return ObjectTypes.Type.ASTEROID
	
	return ObjectTypes.Type.NONE

func _is_suitable_for_escort(candidate: Node3D, leader: Node3D) -> bool:
	"""Check if a candidate object is suitable for escort duty."""
	# Basic checks
	if not is_instance_valid(candidate) or not is_instance_valid(leader):
		return false
	
	# Check if candidate is a ship
	var candidate_type: ObjectTypes.Type = _get_object_type(candidate)
	if not ObjectTypes.is_ship_type(candidate_type):
		return false
	
	# Check if candidate has escort capability
	if candidate.has_method("can_escort"):
		return candidate.can_escort(leader)
	
	# Default: fighters and smaller ships can escort
	return candidate_type in [ObjectTypes.Type.FIGHTER, ObjectTypes.Type.SHIP]

func _get_escort_suitability_score(candidate: Node3D, leader: Node3D) -> float:
	"""Calculate escort suitability score for ranking."""
	var score: float = 0.0
	
	# Distance factor (closer is better, but not too close)
	var distance: float = candidate.global_position.distance_to(leader.global_position)
	var ideal_distance: float = 200.0  # Ideal escort distance
	var distance_factor: float = 1.0 - abs(distance - ideal_distance) / ideal_distance
	score += clamp(distance_factor, 0.0, 1.0) * 0.4
	
	# Type factor
	var candidate_type: ObjectTypes.Type = _get_object_type(candidate)
	match candidate_type:
		ObjectTypes.Type.FIGHTER:
			score += 0.3  # Fighters make good escorts
		ObjectTypes.Type.SHIP:
			score += 0.2  # Generic ships are decent
		_:
			score += 0.1  # Other types less suitable
	
	# Speed compatibility (if available)
	if candidate.has_method("get_max_speed") and leader.has_method("get_max_speed"):
		var speed_ratio: float = candidate.get_max_speed() / max(1.0, leader.get_max_speed())
		score += clamp(speed_ratio, 0.0, 1.0) * 0.3
	
	return clamp(score, 0.0, 1.0)

func _cache_advanced_query(cache_key: String, result: Array[Node3D], timestamp: int) -> void:
	"""Cache an advanced query result."""
	if advanced_query_cache.size() >= max_advanced_cache_entries:
		_cleanup_advanced_cache()
	
	advanced_query_cache[cache_key] = {
		"result": result,
		"timestamp": timestamp
	}

func _cleanup_advanced_cache() -> void:
	"""Clean up expired entries from advanced query cache."""
	var current_time: int = Time.get_ticks_msec()
	var keys_to_remove: Array[String] = []
	
	for key: String in advanced_query_cache.keys():
		var entry: Dictionary = advanced_query_cache[key]
		if current_time - entry["timestamp"] > cache_timeout_ms:
			keys_to_remove.append(key)
	
	for key: String in keys_to_remove:
		advanced_query_cache.erase(key)

func _emit_performance_signals(query_type: String, result_count: int, query_time_ms: float) -> void:
	"""Emit performance monitoring signals."""
	if not enable_performance_monitoring:
		return
	
	query_completed.emit(query_type, result_count, query_time_ms)
	
	if query_time_ms > performance_warning_threshold_ms:
		var message: String = "Slow %s query: %.2fms for %d objects" % [query_type, query_time_ms, result_count]
		performance_warning.emit(message, query_time_ms, result_count)