class_name SpatialHash
extends RefCounted

## Grid-based spatial hash system for fast object queries and collision optimization.
## Provides efficient proximity detection and spatial partitioning for WCS space objects.
## 
## Based on WCS C++ linear object iteration but enhanced with modern spatial partitioning
## to achieve O(1) average case performance for spatial queries instead of O(n).

signal object_moved(object: Node3D, old_position: Vector3, new_position: Vector3)
signal partition_changed(object: Node3D, old_cells: Array[Vector3i], new_cells: Array[Vector3i])

# Performance constants from wcs_asset_core
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Grid configuration
var grid_size: float = 1000.0
var max_objects_per_cell: int = 50
var enable_multi_cell_objects: bool = true

# Spatial data structures
var grid_cells: Dictionary = {}  # Vector3i -> Array[WeakRef]
var object_to_cells: Dictionary = {}  # Node3D -> Array[Vector3i]
var object_positions: Dictionary = {}  # Node3D -> Vector3
var object_bounds: Dictionary = {}  # Node3D -> AABB

# Performance tracking
var query_count: int = 0
var total_query_time_ms: float = 0.0
var last_update_time_ms: float = 0.0
var partition_operations: int = 0

# Query cache for frequently requested searches
var query_cache: Dictionary = {}
var cache_timeout_ms: float = 100.0  # Cache results for 100ms
var max_cache_entries: int = 100

func _init(initial_grid_size: float = 1000.0) -> void:
	"""Initialize spatial hash with specified grid size.
	
	Args:
		initial_grid_size: Size of each grid cell in world units
	"""
	grid_size = max(100.0, initial_grid_size)  # Minimum sensible grid size
	_clear_all_data()

func add_object(object: Node3D, bounds: AABB = AABB()) -> bool:
	"""Add an object to the spatial hash system.
	
	Args:
		object: Object to add to spatial partitioning
		bounds: Object's bounding box (uses node's AABB if empty)
	
	Returns:
		true if object was successfully added
	"""
	if not is_instance_valid(object):
		push_error("SpatialHash: Cannot add invalid object")
		return false
	
	if object in object_positions:
		push_warning("SpatialHash: Object already in spatial hash, updating position")
		update_object_position(object)
		return true
	
	# Get object bounds
	var object_bounds_value: AABB = bounds
	if object_bounds_value.size == Vector3.ZERO:
		object_bounds_value = _get_object_bounds(object)
	
	# Store object data
	var position: Vector3 = object.global_position
	object_positions[object] = position
	object_bounds[object] = object_bounds_value
	
	# Calculate grid cells this object occupies
	var cells: Array[Vector3i] = _get_cells_for_bounds(object_bounds_value)
	object_to_cells[object] = cells
	
	# Add object to grid cells
	var weak_ref: WeakRef = weakref(object)
	for cell: Vector3i in cells:
		if cell not in grid_cells:
			grid_cells[cell] = []
		
		var cell_objects: Array = grid_cells[cell]
		if cell_objects.size() < max_objects_per_cell:
			cell_objects.append(weak_ref)
		else:
			push_warning("SpatialHash: Cell %s exceeded max objects (%d)" % [cell, max_objects_per_cell])
	
	partition_operations += 1
	_invalidate_cache()
	
	return true

func remove_object(object: Node3D) -> bool:
	"""Remove an object from the spatial hash system.
	
	Args:
		object: Object to remove from spatial partitioning
	
	Returns:
		true if object was successfully removed
	"""
	if object not in object_positions:
		return false
	
	# Get cells this object was in
	var cells: Array[Vector3i] = object_to_cells.get(object, [])
	
	# Remove from grid cells
	for cell: Vector3i in cells:
		if cell in grid_cells:
			var cell_objects: Array = grid_cells[cell]
			# Remove all weak references to this object
			for i in range(cell_objects.size() - 1, -1, -1):
				var weak_ref: WeakRef = cell_objects[i]
				if not weak_ref.get_ref() or weak_ref.get_ref() == object:
					cell_objects.remove_at(i)
			
			# Clean up empty cells
			if cell_objects.is_empty():
				grid_cells.erase(cell)
	
	# Remove from tracking dictionaries
	object_positions.erase(object)
	object_bounds.erase(object)
	object_to_cells.erase(object)
	
	partition_operations += 1
	_invalidate_cache()
	
	return true

func update_object_position(object: Node3D, new_bounds: AABB = AABB()) -> bool:
	"""Update an object's position in the spatial hash.
	
	Args:
		object: Object to update
		new_bounds: New bounding box (recalculates if empty)
	
	Returns:
		true if position was successfully updated
	"""
	if not is_instance_valid(object) or object not in object_positions:
		return false
	
	var old_position: Vector3 = object_positions[object]
	var new_position: Vector3 = object.global_position
	
	# Check if object actually moved significantly
	var movement_threshold: float = grid_size * 0.1  # 10% of grid size
	if old_position.distance_to(new_position) < movement_threshold:
		return true  # No significant movement
	
	# Update bounds if provided
	var bounds: AABB = new_bounds
	if bounds.size == Vector3.ZERO:
		bounds = _get_object_bounds(object)
	
	var old_cells: Array[Vector3i] = object_to_cells.get(object, [])
	var new_cells: Array[Vector3i] = _get_cells_for_bounds(bounds)
	
	# Check if cells changed
	if _arrays_equal(old_cells, new_cells):
		# Same cells, just update position
		object_positions[object] = new_position
		object_bounds[object] = bounds
		return true
	
	# Remove from old cells
	var weak_ref: WeakRef = weakref(object)
	for cell: Vector3i in old_cells:
		if cell in grid_cells:
			var cell_objects: Array = grid_cells[cell]
			for i in range(cell_objects.size() - 1, -1, -1):
				var ref: WeakRef = cell_objects[i]
				if ref.get_ref() == object:
					cell_objects.remove_at(i)
					break
			
			if cell_objects.is_empty():
				grid_cells.erase(cell)
	
	# Add to new cells
	for cell: Vector3i in new_cells:
		if cell not in grid_cells:
			grid_cells[cell] = []
		
		var cell_objects: Array = grid_cells[cell]
		if cell_objects.size() < max_objects_per_cell:
			cell_objects.append(weak_ref)
	
	# Update tracking data
	object_positions[object] = new_position
	object_bounds[object] = bounds
	object_to_cells[object] = new_cells
	
	# Emit signals for system integration
	object_moved.emit(object, old_position, new_position)
	partition_changed.emit(object, old_cells, new_cells)
	
	partition_operations += 1
	_invalidate_cache()
	
	return true

func get_objects_in_radius(center: Vector3, radius: float, type_filter: ObjectTypes.Type = ObjectTypes.Type.NONE) -> Array[Node3D]:
	"""Get all objects within a specified radius of a center point.
	
	Args:
		center: Center point for search
		radius: Search radius in world units
		type_filter: Optional object type filter (NONE = all types)
	
	Returns:
		Array of objects within radius, sorted by distance
	"""
	var start_time: int = Time.get_ticks_msec()
	
	# Check cache first
	var cache_key: String = "radius_%s_%.1f_%d" % [center, radius, type_filter]
	if cache_key in query_cache:
		var cached_data: Dictionary = query_cache[cache_key]
		if start_time - cached_data["timestamp"] < cache_timeout_ms:
			return cached_data["result"]
	
	var result: Array[Node3D] = []
	var radius_squared: float = radius * radius
	
	# Get cells that intersect with search radius
	var search_cells: Array[Vector3i] = _get_cells_for_sphere(center, radius)
	
	# Collect objects from relevant cells
	var checked_objects: Dictionary = {}  # Prevent duplicates
	
	for cell: Vector3i in search_cells:
		if cell not in grid_cells:
			continue
		
		var cell_objects: Array = grid_cells[cell]
		for weak_ref in cell_objects:
			var obj: Node3D = weak_ref.get_ref()
			if not is_instance_valid(obj) or obj in checked_objects:
				continue
			
			checked_objects[obj] = true
			
			# Apply type filter
			if type_filter != ObjectTypes.Type.NONE:
				var obj_type: ObjectTypes.Type = _get_object_type(obj)
				if obj_type != type_filter:
					continue
			
			# Check actual distance
			var obj_position: Vector3 = object_positions.get(obj, obj.global_position)
			var distance_squared: float = center.distance_squared_to(obj_position)
			
			if distance_squared <= radius_squared:
				result.append(obj)
	
	# Sort by distance (closest first)
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var pos_a: Vector3 = object_positions.get(a, a.global_position)
		var pos_b: Vector3 = object_positions.get(b, b.global_position)
		return center.distance_squared_to(pos_a) < center.distance_squared_to(pos_b)
	)
	
	# Cache result
	_cache_query_result(cache_key, result, start_time)
	
	# Update performance tracking
	var query_time: float = Time.get_ticks_msec() - start_time
	_update_performance_stats(query_time)
	
	return result

func get_nearest_objects(position: Vector3, count: int, type_filter: ObjectTypes.Type = ObjectTypes.Type.NONE) -> Array[Node3D]:
	"""Get the nearest N objects to a position.
	
	Args:
		position: Search center position
		count: Maximum number of objects to return
		type_filter: Optional object type filter
	
	Returns:
		Array of nearest objects, sorted by distance
	"""
	if count <= 0:
		return []
	
	# Start with a reasonable search radius and expand if needed
	var search_radius: float = grid_size
	var max_search_radius: float = grid_size * 10.0
	var found_objects: Array[Node3D] = []
	
	while search_radius <= max_search_radius and found_objects.size() < count:
		found_objects = get_objects_in_radius(position, search_radius, type_filter)
		if found_objects.size() >= count:
			break
		search_radius *= 2.0  # Exponential expansion
	
	# Return only the requested count
	if found_objects.size() > count:
		found_objects.resize(count)
	
	return found_objects

func get_objects_in_area(area: AABB, type_filter: ObjectTypes.Type = ObjectTypes.Type.NONE) -> Array[Node3D]:
	"""Get all objects within a specified 3D area.
	
	Args:
		area: Bounding box defining search area
		type_filter: Optional object type filter
	
	Returns:
		Array of objects within area
	"""
	var start_time: int = Time.get_ticks_msec()
	
	var result: Array[Node3D] = []
	var search_cells: Array[Vector3i] = _get_cells_for_bounds(area)
	var checked_objects: Dictionary = {}
	
	for cell: Vector3i in search_cells:
		if cell not in grid_cells:
			continue
		
		var cell_objects: Array = grid_cells[cell]
		for weak_ref in cell_objects:
			var obj: Node3D = weak_ref.get_ref()
			if not is_instance_valid(obj) or obj in checked_objects:
				continue
			
			checked_objects[obj] = true
			
			# Apply type filter
			if type_filter != ObjectTypes.Type.NONE:
				var obj_type: ObjectTypes.Type = _get_object_type(obj)
				if obj_type != type_filter:
					continue
			
			# Check if object is within area
			var obj_bounds: AABB = object_bounds.get(obj, _get_object_bounds(obj))
			if area.intersects(obj_bounds):
				result.append(obj)
	
	var query_time: float = Time.get_ticks_msec() - start_time
	_update_performance_stats(query_time)
	
	return result

func get_collision_candidates(object: Node3D, collision_radius: float = 0.0) -> Array[Node3D]:
	"""Get objects that could potentially collide with the given object.
	
	Args:
		object: Object to find collision candidates for
		collision_radius: Additional collision radius expansion
	
	Returns:
		Array of potential collision objects
	"""
	if object not in object_bounds:
		return []
	
	var bounds: AABB = object_bounds[object]
	if collision_radius > 0.0:
		bounds = bounds.grow(collision_radius)
	
	var candidates: Array[Node3D] = get_objects_in_area(bounds)
	
	# Remove the object itself from candidates
	var object_index: int = candidates.find(object)
	if object_index >= 0:
		candidates.remove_at(object_index)
	
	return candidates

func optimize_grid_size() -> void:
	"""Dynamically optimize grid size based on object distribution and density.
	
	Analyzes current object distribution and adjusts grid size for optimal performance.
	"""
	if object_positions.is_empty():
		return
	
	# Calculate object density statistics
	var total_objects: int = object_positions.size()
	var occupied_cells: int = grid_cells.size()
	var avg_objects_per_cell: float = float(total_objects) / max(1, occupied_cells)
	
	# Target 10-20 objects per cell for optimal performance
	var target_objects_per_cell: float = 15.0
	var density_ratio: float = avg_objects_per_cell / target_objects_per_cell
	
	# Adjust grid size based on density
	var new_grid_size: float = grid_size
	
	if density_ratio > 2.0:
		# Too many objects per cell, make grid smaller
		new_grid_size = grid_size * 0.7
	elif density_ratio < 0.5:
		# Too few objects per cell, make grid larger
		new_grid_size = grid_size * 1.4
	
	# Apply reasonable limits
	new_grid_size = clamp(new_grid_size, 100.0, 10000.0)
	
	if abs(new_grid_size - grid_size) / grid_size > 0.1:  # 10% change threshold
		_rebuild_with_new_grid_size(new_grid_size)

func clear_all() -> void:
	"""Clear all objects and reset the spatial hash system."""
	_clear_all_data()

func get_statistics() -> Dictionary:
	"""Get performance and usage statistics for the spatial hash system.
	
	Returns:
		Dictionary containing performance metrics and usage statistics
	"""
	var occupied_cells: int = grid_cells.size()
	var total_objects: int = object_positions.size()
	var avg_objects_per_cell: float = float(total_objects) / max(1, occupied_cells)
	var avg_query_time: float = total_query_time_ms / max(1, query_count)
	
	return {
		"total_objects": total_objects,
		"occupied_cells": occupied_cells,
		"grid_size": grid_size,
		"avg_objects_per_cell": avg_objects_per_cell,
		"query_count": query_count,
		"avg_query_time_ms": avg_query_time,
		"last_update_time_ms": last_update_time_ms,
		"partition_operations": partition_operations,
		"cache_entries": query_cache.size(),
		"cache_hit_ratio": _calculate_cache_hit_ratio()
	}

# Private helper methods

func _clear_all_data() -> void:
	"""Clear all internal data structures."""
	grid_cells.clear()
	object_to_cells.clear()
	object_positions.clear()
	object_bounds.clear()
	query_cache.clear()
	query_count = 0
	total_query_time_ms = 0.0
	partition_operations = 0

func _get_cells_for_bounds(bounds: AABB) -> Array[Vector3i]:
	"""Get all grid cells that intersect with the given bounds."""
	var cells: Array[Vector3i] = []
	
	var min_cell: Vector3i = _position_to_cell(bounds.position)
	var max_cell: Vector3i = _position_to_cell(bounds.position + bounds.size)
	
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for z in range(min_cell.z, max_cell.z + 1):
				cells.append(Vector3i(x, y, z))
	
	return cells

func _get_cells_for_sphere(center: Vector3, radius: float) -> Array[Vector3i]:
	"""Get all grid cells that intersect with a sphere."""
	var cells: Array[Vector3i] = []
	var radius_in_cells: int = int(ceil(radius / grid_size))
	var center_cell: Vector3i = _position_to_cell(center)
	
	for x in range(-radius_in_cells, radius_in_cells + 1):
		for y in range(-radius_in_cells, radius_in_cells + 1):
			for z in range(-radius_in_cells, radius_in_cells + 1):
				var cell: Vector3i = center_cell + Vector3i(x, y, z)
				
				# Check if cell intersects with sphere
				var cell_center: Vector3 = _cell_to_position(cell)
				var closest_point: Vector3 = _closest_point_in_cell(center, cell)
				
				if center.distance_to(closest_point) <= radius:
					cells.append(cell)
	
	return cells

func _position_to_cell(position: Vector3) -> Vector3i:
	"""Convert world position to grid cell coordinates."""
	return Vector3i(
		int(floor(position.x / grid_size)),
		int(floor(position.y / grid_size)),
		int(floor(position.z / grid_size))
	)

func _cell_to_position(cell: Vector3i) -> Vector3:
	"""Convert grid cell coordinates to world position (cell center)."""
	return Vector3(
		cell.x * grid_size + grid_size * 0.5,
		cell.y * grid_size + grid_size * 0.5,
		cell.z * grid_size + grid_size * 0.5
	)

func _closest_point_in_cell(point: Vector3, cell: Vector3i) -> Vector3:
	"""Find the closest point in a cell to the given point."""
	var cell_min: Vector3 = Vector3(cell) * grid_size
	var cell_max: Vector3 = cell_min + Vector3.ONE * grid_size
	
	return Vector3(
		clamp(point.x, cell_min.x, cell_max.x),
		clamp(point.y, cell_min.y, cell_max.y),
		clamp(point.z, cell_min.z, cell_max.z)
	)

func _get_object_bounds(object: Node3D) -> AABB:
	"""Get bounding box for an object, with fallback for different node types."""
	# Try to get AABB from various node types
	if object.has_method("get_aabb"):
		var aabb: AABB = object.get_aabb()
		if aabb.size != Vector3.ZERO:
			return aabb
	
	# Fallback: create small bounding box around object position
	var position: Vector3 = object.global_position
	var default_size: Vector3 = Vector3.ONE * 10.0  # 10 unit default size
	return AABB(position - default_size * 0.5, default_size)

func _get_object_type(object: Node3D) -> ObjectTypes.Type:
	"""Get the object type for filtering purposes."""
	# Try to get type from object if it has a type property
	if object.has_method("get_object_type"):
		return object.get_object_type()
	
	# Fallback: determine type based on node class name
	var script: Script = object.get_script()
	if script:
		var ship_class_name: String = script.get_global_name()
		
		if "Ship" in ship_class_name:
			return ObjectTypes.Type.SHIP
		elif "Weapon" in ship_class_name:
			return ObjectTypes.Type.WEAPON
		elif "Debris" in ship_class_name:
			return ObjectTypes.Type.DEBRIS
		elif "Asteroid" in ship_class_name:
			return ObjectTypes.Type.ASTEROID
	
	return ObjectTypes.Type.NONE

func _arrays_equal(a: Array[Vector3i], b: Array[Vector3i]) -> bool:
	"""Check if two Vector3i arrays contain the same elements."""
	if a.size() != b.size():
		return false
	
	# Sort both arrays for comparison
	var sorted_a: Array[Vector3i] = a.duplicate()
	var sorted_b: Array[Vector3i] = b.duplicate()
	sorted_a.sort()
	sorted_b.sort()
	
	for i in range(sorted_a.size()):
		if sorted_a[i] != sorted_b[i]:
			return false
	
	return true

func _cache_query_result(cache_key: String, result: Array[Node3D], timestamp: int) -> void:
	"""Cache a query result with timestamp."""
	if query_cache.size() >= max_cache_entries:
		_cleanup_old_cache_entries()
	
	query_cache[cache_key] = {
		"result": result,
		"timestamp": timestamp
	}

func _cleanup_old_cache_entries() -> void:
	"""Remove expired cache entries."""
	var current_time: int = Time.get_ticks_msec()
	var keys_to_remove: Array[String] = []
	
	for key: String in query_cache.keys():
		var entry: Dictionary = query_cache[key]
		if current_time - entry["timestamp"] > cache_timeout_ms:
			keys_to_remove.append(key)
	
	for key: String in keys_to_remove:
		query_cache.erase(key)

func _invalidate_cache() -> void:
	"""Invalidate the query cache due to object changes."""
	query_cache.clear()

func _update_performance_stats(query_time_ms: float) -> void:
	"""Update performance tracking statistics."""
	query_count += 1
	total_query_time_ms += query_time_ms
	last_update_time_ms = query_time_ms

func _calculate_cache_hit_ratio() -> float:
	"""Calculate cache hit ratio for performance monitoring."""
	# This would need proper hit/miss tracking in a real implementation
	return 0.0  # Placeholder

func _rebuild_with_new_grid_size(new_grid_size: float) -> void:
	"""Rebuild the spatial hash with a new grid size."""
	# Store current objects
	var objects_to_readd: Array[Node3D] = []
	var bounds_to_readd: Array[AABB] = []
	
	for obj: Node3D in object_positions.keys():
		if is_instance_valid(obj):
			objects_to_readd.append(obj)
			bounds_to_readd.append(object_bounds[obj])
	
	# Clear and rebuild
	grid_size = new_grid_size
	_clear_all_data()
	
	# Re-add all objects
	for i in range(objects_to_readd.size()):
		add_object(objects_to_readd[i], bounds_to_readd[i])
	
	print("SpatialHash: Rebuilt with grid size %.1f (objects: %d)" % [grid_size, objects_to_readd.size()])
