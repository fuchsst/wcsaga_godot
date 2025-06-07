class_name WCSPathPlanner
extends Node

## Advanced path planning system for AI navigation with obstacle avoidance
## Supports A* pathfinding, dynamic replanning, and optimized route calculation

signal path_calculated(path: Array[Vector3])
signal path_calculation_failed(start: Vector3, goal: Vector3)
signal path_recalculated(new_path: Array[Vector3], reason: String)

# Path planning configuration
@export var grid_cell_size: float = 100.0  # Size of navigation grid cells
@export var max_planning_distance: float = 10000.0  # Maximum distance for path planning
@export var obstacle_clearance: float = 75.0  # Minimum clearance from obstacles
@export var path_smoothing_passes: int = 2  # Number of smoothing iterations

# Planning constraints
@export var max_path_nodes: int = 1000  # Maximum nodes in path search
@export var planning_timeout: float = 0.1  # Maximum time for path calculation (seconds)
@export var heuristic_weight: float = 1.2  # Weight for A* heuristic (1.0 = pure A*, higher = faster but less optimal)

# Dynamic replanning
@export var replan_threshold: float = 0.3  # How much of path must be blocked to trigger replan
@export var threat_avoidance_distance: float = 300.0  # Distance to avoid threats
@export var moving_obstacle_prediction: float = 2.0  # Seconds to predict moving obstacle positions

# Grid and navigation data
var navigation_grid: Dictionary = {}  # Grid cell -> NavigationCell
var obstacle_cache: Dictionary = {}  # Cached obstacle data for performance
var threat_cache: Dictionary = {}   # Cached threat positions
var last_grid_update: float = 0.0
var grid_update_interval: float = 1.0  # Update grid every second

# Path calculation state
var calculation_start_time: float
var current_calculation_id: int = 0

# Node data structure for A* pathfinding
class PathNode:
	var position: Vector3
	var g_cost: float = 0.0  # Distance from start
	var h_cost: float = 0.0  # Heuristic distance to goal
	var f_cost: float = 0.0  # Total cost
	var parent: PathNode = null
	var grid_coord: Vector2i
	
	func _init(pos: Vector3, grid_pos: Vector2i):
		position = pos
		grid_coord = grid_pos
	
	func calculate_f_cost() -> void:
		f_cost = g_cost + h_cost

# Navigation cell for grid-based pathfinding
class NavigationCell:
	var world_position: Vector3
	var is_passable: bool = true
	var obstacle_cost: float = 0.0  # Additional cost for challenging areas
	var threat_level: float = 0.0   # Threat assessment for this cell
	var last_update: float = 0.0
	
	func _init(pos: Vector3):
		world_position = pos
		last_update = Time.get_time_dict_from_system()["unix"]

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	# Periodic grid updates for dynamic obstacles
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	if current_time - last_grid_update > grid_update_interval:
		_update_dynamic_obstacles()
		last_grid_update = current_time

# Main path planning interface

func calculate_path(start: Vector3, goal: Vector3, constraints: Dictionary = {}) -> Array[Vector3]:
	"""Calculate optimal path from start to goal with given constraints"""
	current_calculation_id += 1
	calculation_start_time = Time.get_time_dict_from_system()["unix"]
	
	# Validate input parameters
	if start.distance_to(goal) > max_planning_distance:
		push_warning("WCSPathPlanner: Path distance exceeds maximum planning distance")
		path_calculation_failed.emit(start, goal)
		return []
	
	# Convert world positions to grid coordinates
	var start_grid: Vector2i = _world_to_grid(start)
	var goal_grid: Vector2i = _world_to_grid(goal)
	
	# Check if start and goal are in passable areas
	if not _is_cell_passable(start_grid) or not _is_cell_passable(goal_grid):
		# Try to find nearby passable cells
		start_grid = _find_nearest_passable_cell(start_grid)
		goal_grid = _find_nearest_passable_cell(goal_grid)
		
		if start_grid == Vector2i(-99999, -99999) or goal_grid == Vector2i(-99999, -99999):
			path_calculation_failed.emit(start, goal)
			return []
	
	# Perform A* pathfinding
	var path_nodes: Array[PathNode] = _a_star_search(start_grid, goal_grid, constraints)
	
	if path_nodes.is_empty():
		path_calculation_failed.emit(start, goal)
		return []
	
	# Convert nodes to world positions
	var world_path: Array[Vector3] = []
	for node in path_nodes:
		world_path.append(node.position)
	
	# Smooth the path
	world_path = _smooth_path(world_path)
	
	# Validate final path
	world_path = _validate_and_fix_path(world_path)
	
	path_calculated.emit(world_path)
	return world_path

func calculate_path_async(start: Vector3, goal: Vector3, constraints: Dictionary = {}) -> Array[Vector3]:
	"""Calculate path asynchronously to avoid frame drops"""
	# For now, just call synchronous version
	# Could be enhanced to use threading or time-sliced calculation
	return calculate_path(start, goal, constraints)

func recalculate_path(current_path: Array[Vector3], current_position: Vector3, goal: Vector3, blocked_segments: Array = []) -> Array[Vector3]:
	"""Recalculate path when obstacles block current route"""
	var reason: String = "obstacle_detected"
	
	# Find the furthest reachable point in current path
	var reachable_index: int = _find_furthest_reachable_waypoint(current_path, current_position)
	
	if reachable_index < 0:
		# No reachable waypoints, full recalculation needed
		reason = "full_replan_required"
		var new_path: Array[Vector3] = calculate_path(current_position, goal)
		if not new_path.is_empty():
			path_recalculated.emit(new_path, reason)
		return new_path
	
	# Partial recalculation from reachable point
	var intermediate_goal: Vector3 = current_path[reachable_index]
	var remaining_path: Array[Vector3] = current_path.slice(reachable_index)
	
	# Calculate new path segment
	var new_segment: Array[Vector3] = calculate_path(current_position, intermediate_goal)
	
	if new_segment.is_empty():
		# Fallback to full recalculation
		var new_path: Array[Vector3] = calculate_path(current_position, goal)
		if not new_path.is_empty():
			path_recalculated.emit(new_path, "fallback_replan")
		return new_path
	
	# Combine new segment with remaining path
	var combined_path: Array[Vector3] = new_segment
	for i in range(1, remaining_path.size()):  # Skip first point to avoid duplication
		combined_path.append(remaining_path[i])
	
	path_recalculated.emit(combined_path, reason)
	return combined_path

func check_path_validity(path: Array[Vector3]) -> Dictionary:
	"""Check if a path is still valid and identify blocked segments"""
	var result: Dictionary = {
		"is_valid": true,
		"blocked_segments": [],
		"blocked_percentage": 0.0,
		"first_blocked_index": -1
	}
	
	if path.size() < 2:
		return result
	
	var blocked_segments: Array = []
	var total_segments: int = path.size() - 1
	
	for i in range(path.size() - 1):
		if not _is_path_segment_clear(path[i], path[i + 1]):
			blocked_segments.append(i)
			if result.first_blocked_index == -1:
				result.first_blocked_index = i
	
	result.blocked_segments = blocked_segments
	result.blocked_percentage = float(blocked_segments.size()) / float(total_segments)
	result.is_valid = result.blocked_percentage < replan_threshold
	
	return result

# A* Pathfinding Implementation

func _a_star_search(start_grid: Vector2i, goal_grid: Vector2i, constraints: Dictionary) -> Array[PathNode]:
	"""A* pathfinding algorithm implementation"""
	var open_set: Array[PathNode] = []
	var closed_set: Dictionary = {}  # grid_coord -> PathNode
	var came_from: Dictionary = {}   # grid_coord -> PathNode
	
	# Create start node
	var start_node: PathNode = PathNode.new(_grid_to_world(start_grid), start_grid)
	start_node.g_cost = 0.0
	start_node.h_cost = _calculate_heuristic(start_grid, goal_grid)
	start_node.calculate_f_cost()
	
	open_set.append(start_node)
	var nodes_explored: int = 0
	
	while not open_set.is_empty() and nodes_explored < max_path_nodes:
		# Check timeout
		if Time.get_time_dict_from_system()["unix"] - calculation_start_time > planning_timeout:
			break
		
		nodes_explored += 1
		
		# Find node with lowest f_cost
		var current: PathNode = _get_lowest_f_cost_node(open_set)
		open_set.erase(current)
		closed_set[current.grid_coord] = current
		
		# Check if we've reached the goal
		if current.grid_coord == goal_grid:
			return _reconstruct_path(current)
		
		# Explore neighbors
		var neighbors: Array[Vector2i] = _get_neighbor_coordinates(current.grid_coord)
		
		for neighbor_coord in neighbors:
			if closed_set.has(neighbor_coord):
				continue
			
			if not _is_cell_passable(neighbor_coord):
				continue
			
			# Calculate movement cost
			var movement_cost: float = _calculate_movement_cost(current.grid_coord, neighbor_coord, constraints)
			var tentative_g_cost: float = current.g_cost + movement_cost
			
			# Find or create neighbor node
			var neighbor: PathNode = _find_node_in_open_set(open_set, neighbor_coord)
			var is_new_node: bool = (neighbor == null)
			
			if is_new_node:
				neighbor = PathNode.new(_grid_to_world(neighbor_coord), neighbor_coord)
				neighbor.g_cost = INF
			
			# Update if this path is better
			if tentative_g_cost < neighbor.g_cost:
				neighbor.parent = current
				neighbor.g_cost = tentative_g_cost
				neighbor.h_cost = _calculate_heuristic(neighbor_coord, goal_grid)
				neighbor.calculate_f_cost()
				
				if is_new_node:
					open_set.append(neighbor)
	
	# No path found
	return []

func _get_lowest_f_cost_node(open_set: Array[PathNode]) -> PathNode:
	"""Find node with lowest f_cost in open set"""
	var lowest: PathNode = open_set[0]
	
	for node in open_set:
		if node.f_cost < lowest.f_cost or (node.f_cost == lowest.f_cost and node.h_cost < lowest.h_cost):
			lowest = node
	
	return lowest

func _find_node_in_open_set(open_set: Array[PathNode], grid_coord: Vector2i) -> PathNode:
	"""Find node with given coordinates in open set"""
	for node in open_set:
		if node.grid_coord == grid_coord:
			return node
	return null

func _reconstruct_path(goal_node: PathNode) -> Array[PathNode]:
	"""Reconstruct path from goal node back to start"""
	var path: Array[PathNode] = []
	var current: PathNode = goal_node
	
	while current != null:
		path.push_front(current)
		current = current.parent
	
	return path

func _calculate_heuristic(from: Vector2i, to: Vector2i) -> float:
	"""Calculate heuristic distance between grid coordinates"""
	var dx: float = abs(to.x - from.x)
	var dy: float = abs(to.y - from.y)
	
	# Use octile distance (diagonal movement allowed)
	var diagonal: float = min(dx, dy)
	var straight: float = abs(dx - dy)
	
	return (diagonal * 1.414 + straight) * grid_cell_size * heuristic_weight

func _calculate_movement_cost(from: Vector2i, to: Vector2i, constraints: Dictionary) -> float:
	"""Calculate cost of moving between adjacent grid cells"""
	var base_cost: float = grid_cell_size
	
	# Diagonal movement costs more
	if abs(to.x - from.x) + abs(to.y - from.y) == 2:
		base_cost *= 1.414  # sqrt(2)
	
	# Add obstacle avoidance cost
	var cell: NavigationCell = _get_navigation_cell(to)
	if cell:
		base_cost += cell.obstacle_cost
		
		# Add threat avoidance cost
		if cell.threat_level > 0:
			base_cost += cell.threat_level * constraints.get("threat_avoidance_factor", 100.0)
	
	# Add terrain cost modifiers
	base_cost *= constraints.get("terrain_cost_multiplier", 1.0)
	
	return base_cost

func _get_neighbor_coordinates(grid_coord: Vector2i) -> Array[Vector2i]:
	"""Get coordinates of neighboring grid cells"""
	var neighbors: Array[Vector2i] = []
	
	# 8-directional movement
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			
			var neighbor: Vector2i = Vector2i(grid_coord.x + dx, grid_coord.y + dy)
			neighbors.append(neighbor)
	
	return neighbors

# Grid and obstacle management

func _world_to_grid(world_pos: Vector3) -> Vector2i:
	"""Convert world position to grid coordinates"""
	return Vector2i(
		int(world_pos.x / grid_cell_size),
		int(world_pos.z / grid_cell_size)
	)

func _grid_to_world(grid_coord: Vector2i) -> Vector3:
	"""Convert grid coordinates to world position"""
	return Vector3(
		grid_coord.x * grid_cell_size + grid_cell_size * 0.5,
		0.0,  # Y will be adjusted based on terrain
		grid_coord.y * grid_cell_size + grid_cell_size * 0.5
	)

func _is_cell_passable(grid_coord: Vector2i) -> bool:
	"""Check if a grid cell is passable"""
	var cell: NavigationCell = _get_navigation_cell(grid_coord)
	if not cell:
		# Unknown cell, check for obstacles
		_update_navigation_cell(grid_coord)
		cell = _get_navigation_cell(grid_coord)
	
	return cell and cell.is_passable

func _get_navigation_cell(grid_coord: Vector2i) -> NavigationCell:
	"""Get navigation cell for grid coordinates"""
	var key: String = str(grid_coord.x) + "," + str(grid_coord.y)
	return navigation_grid.get(key, null)

func _update_navigation_cell(grid_coord: Vector2i) -> void:
	"""Update navigation cell with current obstacle data"""
	var world_pos: Vector3 = _grid_to_world(grid_coord)
	var cell: NavigationCell = NavigationCell.new(world_pos)
	
	# Check for obstacles in this cell
	cell.is_passable = _check_cell_passable(world_pos)
	cell.obstacle_cost = _calculate_cell_obstacle_cost(world_pos)
	cell.threat_level = _calculate_cell_threat_level(world_pos)
	
	var key: String = str(grid_coord.x) + "," + str(grid_coord.y)
	navigation_grid[key] = cell

func _check_cell_passable(world_pos: Vector3) -> bool:
	"""Check if a world position is passable"""
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return true
	
	# Check for obstacles in cell area
	var cell_size: float = grid_cell_size * 0.5
	var query_points: Array[Vector3] = [
		world_pos,
		world_pos + Vector3(cell_size, 0, 0),
		world_pos + Vector3(-cell_size, 0, 0),
		world_pos + Vector3(0, 0, cell_size),
		world_pos + Vector3(0, 0, -cell_size)
	]
	
	for point in query_points:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			point + Vector3(0, 100, 0),  # Cast from above
			point - Vector3(0, 100, 0)   # Cast downward
		)
		query.collision_mask = _get_obstacle_collision_mask()
		
		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty():
			var hit_point: Vector3 = result.position
			if hit_point.y > point.y - obstacle_clearance:
				return false  # Obstacle too close
	
	return true

func _calculate_cell_obstacle_cost(world_pos: Vector3) -> float:
	"""Calculate additional cost for navigating near obstacles"""
	var cost: float = 0.0
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return cost
	
	# Check distance to nearest obstacles
	var check_radius: float = obstacle_clearance * 2.0
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = check_radius
	query.shape = sphere
	query.transform.origin = world_pos
	query.collision_mask = _get_obstacle_collision_mask()
	
	var results: Array[Dictionary] = space_state.intersect_shape(query, 10)
	
	# Increase cost based on nearby obstacles
	for result in results:
		var distance: float = world_pos.distance_to(result.get("position", world_pos))
		if distance < obstacle_clearance:
			cost += (obstacle_clearance - distance) * 10.0  # High cost for very close obstacles
		else:
			cost += (check_radius - distance) * 2.0  # Lower cost for nearby obstacles
	
	return cost

func _calculate_cell_threat_level(world_pos: Vector3) -> float:
	"""Calculate threat level for a grid cell"""
	var threat_level: float = 0.0
	
	# Check cached threats
	for threat_pos in threat_cache.values():
		if threat_pos is Vector3:
			var distance: float = world_pos.distance_to(threat_pos)
			if distance < threat_avoidance_distance:
				threat_level += (threat_avoidance_distance - distance) / threat_avoidance_distance
	
	return threat_level

func _get_obstacle_collision_mask() -> int:
	"""Get collision mask for obstacle detection"""
	var mask: int = 0
	
	if WCSConstants.COLLISION_LAYERS.has("ASTEROIDS"):
		mask |= 1 << WCSConstants.COLLISION_LAYERS.ASTEROIDS
	if WCSConstants.COLLISION_LAYERS.has("STRUCTURES"):
		mask |= 1 << WCSConstants.COLLISION_LAYERS.STRUCTURES
	if WCSConstants.COLLISION_LAYERS.has("TERRAIN"):
		mask |= 1 << WCSConstants.COLLISION_LAYERS.TERRAIN
	
	return mask if mask > 0 else 1

func _find_nearest_passable_cell(blocked_coord: Vector2i) -> Vector2i:
	"""Find nearest passable cell to a blocked coordinate"""
	var max_search_radius: int = 10
	
	for radius in range(1, max_search_radius + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue  # Only check perimeter
				
				var test_coord: Vector2i = Vector2i(blocked_coord.x + dx, blocked_coord.y + dy)
				if _is_cell_passable(test_coord):
					return test_coord
	
	return Vector2i(-99999, -99999)  # No passable cell found

# Path validation and optimization

func _smooth_path(path: Array[Vector3]) -> Array[Vector3]:
	"""Smooth path using multiple passes"""
	var smoothed: Array[Vector3] = path.duplicate()
	
	for pass in range(path_smoothing_passes):
		smoothed = _smooth_path_single_pass(smoothed)
	
	return smoothed

func _smooth_path_single_pass(path: Array[Vector3]) -> Array[Vector3]:
	"""Single pass of path smoothing"""
	if path.size() <= 2:
		return path
	
	var smoothed: Array[Vector3] = [path[0]]
	var i: int = 0
	
	while i < path.size() - 1:
		var start_point: Vector3 = path[i]
		var furthest_visible: int = i + 1
		
		# Find furthest point we can reach directly
		for j in range(i + 2, path.size()):
			if _is_path_segment_clear(start_point, path[j]):
				furthest_visible = j
			else:
				break
		
		smoothed.append(path[furthest_visible])
		i = furthest_visible
	
	return smoothed

func _validate_and_fix_path(path: Array[Vector3]) -> Array[Vector3]:
	"""Validate path and fix any issues"""
	if path.size() < 2:
		return path
	
	var fixed_path: Array[Vector3] = [path[0]]
	
	for i in range(1, path.size()):
		var current: Vector3 = path[i]
		var previous: Vector3 = fixed_path[-1]
		
		# Check if segment is clear
		if _is_path_segment_clear(previous, current):
			fixed_path.append(current)
		else:
			# Try to find alternative route around obstacle
			var detour: Array[Vector3] = _calculate_simple_detour(previous, current)
			if not detour.is_empty():
				for point in detour:
					fixed_path.append(point)
			else:
				# Skip this waypoint if no detour possible
				continue
	
	return fixed_path

func _calculate_simple_detour(start: Vector3, goal: Vector3) -> Array[Vector3]:
	"""Calculate simple detour around obstacle"""
	var direction: Vector3 = (goal - start).normalized()
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	var detour_distance: float = obstacle_clearance * 2.0
	
	# Try left detour
	var left_point: Vector3 = start + direction * 0.5 * start.distance_to(goal) - right * detour_distance
	if _is_path_segment_clear(start, left_point) and _is_path_segment_clear(left_point, goal):
		return [left_point]
	
	# Try right detour
	var right_point: Vector3 = start + direction * 0.5 * start.distance_to(goal) + right * detour_distance
	if _is_path_segment_clear(start, right_point) and _is_path_segment_clear(right_point, goal):
		return [right_point]
	
	return []

func _is_path_segment_clear(start: Vector3, end: Vector3) -> bool:
	"""Check if path segment is clear of obstacles"""
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return true
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
	query.collision_mask = _get_obstacle_collision_mask()
	
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()

func _find_furthest_reachable_waypoint(path: Array[Vector3], current_position: Vector3) -> int:
	"""Find furthest reachable waypoint in path"""
	for i in range(path.size() - 1, -1, -1):
		if _is_path_segment_clear(current_position, path[i]):
			return i
	
	return -1

func _update_dynamic_obstacles() -> void:
	"""Update navigation grid with dynamic obstacle positions"""
	# Clear old threat data
	threat_cache.clear()
	
	# Update with current threats (enemy ships, missiles, etc.)
	var threat_ships: Array = get_tree().get_nodes_in_group("enemy_ships")
	for i in range(threat_ships.size()):
		if threat_ships[i] is Node3D:
			threat_cache[i] = threat_ships[i].global_position
	
	# Update affected grid cells
	# This is a simplified version - could be optimized to only update changed areas
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	for key in navigation_grid:
		var cell: NavigationCell = navigation_grid[key]
		if current_time - cell.last_update > grid_update_interval:
			var grid_coord: Vector2i = _parse_grid_key(key)
			_update_navigation_cell(grid_coord)

func _parse_grid_key(key: String) -> Vector2i:
	"""Parse grid coordinate from string key"""
	var parts: PackedStringArray = key.split(",")
	if parts.size() == 2:
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return Vector2i.ZERO

# Public interface for external systems

func add_temporary_obstacle(position: Vector3, radius: float, duration: float = -1.0) -> void:
	"""Add temporary obstacle for dynamic avoidance"""
	# Implementation for temporary obstacles
	pass

func remove_temporary_obstacle(position: Vector3) -> void:
	"""Remove temporary obstacle"""
	# Implementation for removing obstacles
	pass

func update_threat_positions(threats: Array[Vector3]) -> void:
	"""Update known threat positions for avoidance"""
	threat_cache.clear()
	for i in range(threats.size()):
		threat_cache[i] = threats[i]

func get_path_statistics() -> Dictionary:
	"""Get path planning performance statistics"""
	return {
		"grid_cells": navigation_grid.size(),
		"last_calculation_time": Time.get_time_dict_from_system()["unix"] - calculation_start_time,
		"cache_hit_rate": 0.0,  # Could track cache performance
		"average_path_length": 0.0  # Could track path metrics
	}