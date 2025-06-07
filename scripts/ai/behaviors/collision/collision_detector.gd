class_name WCSCollisionDetector
extends Node3D

## Advanced collision detection system for AI ships
## Provides predictive collision detection and spatial partitioning

signal collision_predicted(ship: Node3D, threat: Node3D, time_to_collision: float)
signal collision_imminent(ship: Node3D, threat: Node3D, distance: float)
signal collision_avoided(ship: Node3D, threat: Node3D)

@export var detection_radius: float = 500.0
@export var prediction_time: float = 3.0
@export var critical_distance: float = 100.0
@export var update_frequency: float = 10.0  # Hz
@export var use_spatial_partitioning: bool = true
@export var grid_cell_size: float = 1000.0

var registered_ships: Array[Node3D] = []
var collision_threats: Dictionary = {}
var last_update_time: float = 0.0
var spatial_grid: Dictionary = {}
var performance_monitor: CollisionPerformanceMonitor

class CollisionThreat:
	var threat_object: Node3D
	var time_to_collision: float
	var closest_distance: float
	var collision_point: Vector3
	var threat_level: float
	var last_updated: float
	
	func _init(obj: Node3D, ttc: float, distance: float, point: Vector3, level: float) -> void:
		threat_object = obj
		time_to_collision = ttc
		closest_distance = distance
		collision_point = point
		threat_level = level
		last_updated = Time.get_time_dict_from_system()["unix"]

class CollisionPerformanceMonitor:
	var detection_times: Array[float] = []
	var ships_processed: int = 0
	var threats_detected: int = 0
	var frame_start_time: float = 0.0
	
	func start_frame() -> void:
		frame_start_time = Time.get_time_dict_from_system()["unix"] * 1000000.0  # microseconds
		ships_processed = 0
		threats_detected = 0
	
	func end_frame() -> void:
		var frame_time: float = Time.get_time_dict_from_system()["unix"] * 1000000.0 - frame_start_time
		detection_times.append(frame_time)
		if detection_times.size() > 60:  # Keep last 60 frames
			detection_times.pop_front()
	
	func get_average_detection_time() -> float:
		if detection_times.is_empty():
			return 0.0
		return detection_times.reduce(func(a, b): return a + b) / detection_times.size()

func _ready() -> void:
	performance_monitor = CollisionPerformanceMonitor.new()
	_initialize_spatial_grid()

func _process(delta: float) -> void:
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	if current_time - last_update_time >= 1.0 / update_frequency:
		_update_collision_detection()
		last_update_time = current_time

func register_ship(ship: Node3D) -> void:
	if ship not in registered_ships:
		registered_ships.append(ship)
		collision_threats[ship] = []

func unregister_ship(ship: Node3D) -> void:
	if ship in registered_ships:
		registered_ships.erase(ship)
		if collision_threats.has(ship):
			collision_threats.erase(ship)

func _update_collision_detection() -> void:
	performance_monitor.start_frame()
	
	if use_spatial_partitioning:
		_update_spatial_grid()
	
	for ship in registered_ships:
		if not is_instance_valid(ship):
			continue
		
		_detect_collisions_for_ship(ship)
		performance_monitor.ships_processed += 1
	
	_cleanup_old_threats()
	performance_monitor.end_frame()

func _initialize_spatial_grid() -> void:
	spatial_grid.clear()

func _update_spatial_grid() -> void:
	spatial_grid.clear()
	
	for ship in registered_ships:
		if not is_instance_valid(ship):
			continue
		
		var grid_coord: Vector2i = _world_to_grid(ship.global_position)
		if not spatial_grid.has(grid_coord):
			spatial_grid[grid_coord] = []
		spatial_grid[grid_coord].append(ship)

func _world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(world_pos.x / grid_cell_size),
		int(world_pos.z / grid_cell_size)
	)

func _get_nearby_grid_cells(center_cell: Vector2i, radius: int = 1) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(center_cell.x - radius, center_cell.x + radius + 1):
		for z in range(center_cell.y - radius, center_cell.y + radius + 1):
			cells.append(Vector2i(x, z))
	return cells

func _detect_collisions_for_ship(ship: Node3D) -> void:
	var ship_position: Vector3 = ship.global_position
	var potential_threats: Array[Node3D] = []
	
	if use_spatial_partitioning:
		potential_threats = _get_nearby_ships_spatial(ship)
	else:
		potential_threats = _get_nearby_ships_radius(ship)
	
	var current_threats: Array[CollisionThreat] = []
	
	for threat in potential_threats:
		if threat == ship or not is_instance_valid(threat):
			continue
		
		var collision_data: Dictionary = _analyze_collision_potential(ship, threat)
		if collision_data.get("collision_possible", false):
			var threat_obj: CollisionThreat = CollisionThreat.new(
				threat,
				collision_data.get("time_to_collision", 0.0),
				collision_data.get("closest_distance", 0.0),
				collision_data.get("collision_point", Vector3.ZERO),
				collision_data.get("threat_level", 0.0)
			)
			current_threats.append(threat_obj)
			performance_monitor.threats_detected += 1
			
			# Emit appropriate signals
			if threat_obj.closest_distance < critical_distance:
				collision_imminent.emit(ship, threat, threat_obj.closest_distance)
			elif threat_obj.time_to_collision < prediction_time:
				collision_predicted.emit(ship, threat, threat_obj.time_to_collision)
	
	# Update threats for this ship
	collision_threats[ship] = current_threats

func _get_nearby_ships_spatial(ship: Node3D) -> Array[Node3D]:
	var ship_grid: Vector2i = _world_to_grid(ship.global_position)
	var nearby_cells: Array[Vector2i] = _get_nearby_grid_cells(ship_grid, 2)
	var nearby_ships: Array[Node3D] = []
	
	for cell in nearby_cells:
		if spatial_grid.has(cell):
			nearby_ships.append_array(spatial_grid[cell])
	
	return nearby_ships

func _get_nearby_ships_radius(ship: Node3D) -> Array[Node3D]:
	var nearby_ships: Array[Node3D] = []
	var ship_position: Vector3 = ship.global_position
	
	for other_ship in registered_ships:
		if other_ship == ship or not is_instance_valid(other_ship):
			continue
		
		var distance: float = ship_position.distance_to(other_ship.global_position)
		if distance <= detection_radius:
			nearby_ships.append(other_ship)
	
	return nearby_ships

func _analyze_collision_potential(ship: Node3D, threat: Node3D) -> Dictionary:
	var ship_pos: Vector3 = ship.global_position
	var threat_pos: Vector3 = threat.global_position
	
	# Get velocities
	var ship_vel: Vector3 = Vector3.ZERO
	var threat_vel: Vector3 = Vector3.ZERO
	
	if ship.has_method("get_velocity"):
		ship_vel = ship.get_velocity()
	elif ship.has_method("get_linear_velocity"):
		ship_vel = ship.get_linear_velocity()
	
	if threat.has_method("get_velocity"):
		threat_vel = threat.get_velocity()
	elif threat.has_method("get_linear_velocity"):
		threat_vel = threat.get_linear_velocity()
	
	# Calculate relative motion
	var relative_position: Vector3 = threat_pos - ship_pos
	var relative_velocity: Vector3 = ship_vel - threat_vel
	
	# Check if objects are approaching
	if relative_velocity.dot(relative_position) <= 0:
		return {"collision_possible": false}
	
	# Calculate time to closest approach
	var relative_speed_sq: float = relative_velocity.length_squared()
	if relative_speed_sq < 0.01:  # Essentially stationary relative to each other
		return {"collision_possible": false}
	
	var time_to_closest: float = -relative_position.dot(relative_velocity) / relative_speed_sq
	if time_to_closest < 0:
		return {"collision_possible": false}
	
	# Calculate position at closest approach
	var closest_position: Vector3 = relative_position + relative_velocity * time_to_closest
	var closest_distance: float = closest_position.length()
	
	# Get combined collision radius
	var ship_radius: float = _get_collision_radius(ship)
	var threat_radius: float = _get_collision_radius(threat)
	var combined_radius: float = ship_radius + threat_radius
	
	# Determine if collision will occur
	var collision_possible: bool = closest_distance < combined_radius
	if not collision_possible:
		return {"collision_possible": false}
	
	# Calculate collision point
	var collision_point: Vector3 = ship_pos + ship_vel * time_to_closest
	
	# Calculate threat level based on relative speed and approach angle
	var relative_speed: float = relative_velocity.length()
	var approach_angle: float = abs(relative_velocity.normalized().dot(relative_position.normalized()))
	var threat_level: float = (relative_speed / 100.0) * approach_angle * (1.0 / max(time_to_closest, 0.1))
	
	return {
		"collision_possible": true,
		"time_to_collision": time_to_closest,
		"closest_distance": closest_distance,
		"collision_point": collision_point,
		"threat_level": threat_level,
		"relative_speed": relative_speed,
		"approach_angle": approach_angle
	}

func _get_collision_radius(object: Node3D) -> float:
	# Try various methods to get collision radius
	if object.has_method("get_collision_radius"):
		return object.get_collision_radius()
	
	# Check for CollisionShape3D children
	for child in object.get_children():
		if child is CollisionShape3D:
			var shape: Shape3D = child.shape
			if shape is SphereShape3D:
				return shape.radius
			elif shape is BoxShape3D:
				return max(shape.size.x, max(shape.size.y, shape.size.z)) * 0.5
			elif shape is CapsuleShape3D:
				return max(shape.radius, shape.height * 0.5)
	
	# Default based on scale (assuming ship is roughly 20 units across)
	var scale: Vector3 = object.scale
	return max(scale.x, max(scale.y, scale.z)) * 10.0

func _cleanup_old_threats() -> void:
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	var cleanup_threshold: float = 5.0  # Remove threats older than 5 seconds
	
	for ship in collision_threats.keys():
		if not is_instance_valid(ship):
			collision_threats.erase(ship)
			continue
		
		var threats: Array = collision_threats[ship]
		var valid_threats: Array[CollisionThreat] = []
		
		for threat in threats:
			if threat is CollisionThreat:
				if is_instance_valid(threat.threat_object) and (current_time - threat.last_updated) < cleanup_threshold:
					valid_threats.append(threat)
		
		collision_threats[ship] = valid_threats

func get_threats_for_ship(ship: Node3D) -> Array[CollisionThreat]:
	if collision_threats.has(ship):
		return collision_threats[ship]
	return []

func get_most_dangerous_threat(ship: Node3D) -> CollisionThreat:
	var threats: Array[CollisionThreat] = get_threats_for_ship(ship)
	if threats.is_empty():
		return null
	
	var most_dangerous: CollisionThreat = threats[0]
	for threat in threats:
		if threat.threat_level > most_dangerous.threat_level:
			most_dangerous = threat
	
	return most_dangerous

func get_performance_stats() -> Dictionary:
	return {
		"average_detection_time_us": performance_monitor.get_average_detection_time(),
		"ships_processed": performance_monitor.ships_processed,
		"threats_detected": performance_monitor.threats_detected,
		"registered_ships": registered_ships.size(),
		"spatial_grid_cells": spatial_grid.size()
	}

func set_detection_parameters(new_radius: float, new_prediction_time: float, new_critical_distance: float) -> void:
	detection_radius = new_radius
	prediction_time = new_prediction_time
	critical_distance = new_critical_distance

func enable_spatial_partitioning(enabled: bool, cell_size: float = 1000.0) -> void:
	use_spatial_partitioning = enabled
	if enabled:
		grid_cell_size = cell_size
		_initialize_spatial_grid()