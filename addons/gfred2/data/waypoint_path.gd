@tool
class_name WaypointPath
extends Resource

## Waypoint path data structure for GFRED2-010 Mission Component Editors.
## Defines a path of waypoints that ships can follow with 3D coordinates.

signal path_changed(property_name: String, old_value: Variant, new_value: Variant)
signal waypoint_added(waypoint_index: int, position: Vector3)
signal waypoint_removed(waypoint_index: int)
signal waypoint_moved(waypoint_index: int, old_position: Vector3, new_position: Vector3)

# Basic path properties
@export var path_id: String = ""
@export var path_name: String = ""
@export var description: String = ""

# Waypoint data
@export var waypoints: Array[Vector3] = []

# Ship assignment
@export var assigned_ships: Array[String] = []
@export var assigned_wings: Array[String] = []

# Path properties
@export var path_flags: Array[String] = []
@export var speed_multiplier: float = 1.0
@export var arrival_delay: float = 0.0

# Navigation properties
@export var looped: bool = false
@export var patrol_mode: bool = false
@export var reverse_on_complete: bool = false

func _init() -> void:
	# Initialize with default values
	path_id = "waypoint_path_" + str(randi() % 10000)
	path_name = "New Waypoint Path"
	speed_multiplier = 1.0
	arrival_delay = 0.0
	looped = false
	patrol_mode = false
	reverse_on_complete = false

func _set(property: StringName, value: Variant) -> bool:
	var old_value: Variant = get(property)
	var result: bool = false
	
	match property:
		"path_id":
			path_id = value as String
			result = true
		"path_name":
			path_name = value as String
			result = true
		"description":
			description = value as String
			result = true
		"waypoints":
			waypoints = value as Array[Vector3]
			result = true
		"assigned_ships":
			assigned_ships = value as Array[String]
			result = true
		"assigned_wings":
			assigned_wings = value as Array[String]
			result = true
		"path_flags":
			path_flags = value as Array[String]
			result = true
		"speed_multiplier":
			speed_multiplier = max(0.1, value as float)
			result = true
		"arrival_delay":
			arrival_delay = max(0.0, value as float)
			result = true
		"looped":
			looped = value as bool
			result = true
		"patrol_mode":
			patrol_mode = value as bool
			result = true
		"reverse_on_complete":
			reverse_on_complete = value as bool
			result = true
	
	if result:
		path_changed.emit(property, old_value, value)
	
	return result

## Adds a waypoint to the path
func add_waypoint(position: Vector3, index: int = -1) -> void:
	if index < 0 or index >= waypoints.size():
		waypoints.append(position)
		waypoint_added.emit(waypoints.size() - 1, position)
	else:
		waypoints.insert(index, position)
		waypoint_added.emit(index, position)
	
	path_changed.emit("waypoints", waypoints, waypoints)

## Removes a waypoint from the path
func remove_waypoint(index: int) -> bool:
	if index < 0 or index >= waypoints.size():
		return false
	
	waypoints.remove_at(index)
	waypoint_removed.emit(index)
	path_changed.emit("waypoints", waypoints, waypoints)
	return true

## Moves a waypoint to a new position
func move_waypoint(index: int, new_position: Vector3) -> bool:
	if index < 0 or index >= waypoints.size():
		return false
	
	var old_position: Vector3 = waypoints[index]
	waypoints[index] = new_position
	waypoint_moved.emit(index, old_position, new_position)
	path_changed.emit("waypoints", waypoints, waypoints)
	return true

## Gets waypoint at index
func get_waypoint(index: int) -> Vector3:
	if index >= 0 and index < waypoints.size():
		return waypoints[index]
	return Vector3.ZERO

## Gets the total length of the path
func get_path_length() -> float:
	if waypoints.size() < 2:
		return 0.0
	
	var total_length: float = 0.0
	for i in range(waypoints.size() - 1):
		total_length += waypoints[i].distance_to(waypoints[i + 1])
	
	if looped and waypoints.size() > 2:
		total_length += waypoints[-1].distance_to(waypoints[0])
	
	return total_length

## Gets the bounding box of all waypoints
func get_bounding_box() -> AABB:
	if waypoints.is_empty():
		return AABB()
	
	var min_point: Vector3 = waypoints[0]
	var max_point: Vector3 = waypoints[0]
	
	for waypoint in waypoints:
		min_point = Vector3(
			min(min_point.x, waypoint.x),
			min(min_point.y, waypoint.y),
			min(min_point.z, waypoint.z)
		)
		max_point = Vector3(
			max(max_point.x, waypoint.x),
			max(max_point.y, waypoint.y),
			max(max_point.z, waypoint.z)
		)
	
	return AABB(min_point, max_point - min_point)

## Gets the center point of the path
func get_center_point() -> Vector3:
	if waypoints.is_empty():
		return Vector3.ZERO
	
	var sum: Vector3 = Vector3.ZERO
	for waypoint in waypoints:
		sum += waypoint
	
	return sum / waypoints.size()

## Assigns a ship to this path
func assign_ship(ship_name: String) -> void:
	if not ship_name in assigned_ships:
		assigned_ships.append(ship_name)
		path_changed.emit("assigned_ships", assigned_ships, assigned_ships)

## Unassigns a ship from this path
func unassign_ship(ship_name: String) -> bool:
	var index: int = assigned_ships.find(ship_name)
	if index >= 0:
		assigned_ships.remove_at(index)
		path_changed.emit("assigned_ships", assigned_ships, assigned_ships)
		return true
	return false

## Assigns a wing to this path
func assign_wing(wing_name: String) -> void:
	if not wing_name in assigned_wings:
		assigned_wings.append(wing_name)
		path_changed.emit("assigned_wings", assigned_wings, assigned_wings)

## Unassigns a wing from this path
func unassign_wing(wing_name: String) -> bool:
	var index: int = assigned_wings.find(wing_name)
	if index >= 0:
		assigned_wings.remove_at(index)
		path_changed.emit("assigned_wings", assigned_wings, assigned_wings)
		return true
	return false

## Validates the waypoint path
func validate() -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	
	# Validate basic properties
	if path_id.is_empty():
		result.add_error("Path ID cannot be empty")
	
	if path_name.is_empty():
		result.add_error("Path name cannot be empty")
	
	# Validate waypoints
	if waypoints.size() < 2:
		result.add_error("Path must have at least 2 waypoints")
	
	# Check for duplicate waypoints
	for i in range(waypoints.size()):
		for j in range(i + 1, waypoints.size()):
			if waypoints[i].distance_to(waypoints[j]) < 1.0:
				result.add_warning("Waypoints %d and %d are very close (< 1 unit)" % [i + 1, j + 1])
	
	# Validate path configuration
	if speed_multiplier <= 0.0:
		result.add_error("Speed multiplier must be greater than 0")
	
	if arrival_delay < 0.0:
		result.add_error("Arrival delay cannot be negative")
	
	# Validate logical constraints
	if looped and waypoints.size() < 3:
		result.add_error("Looped paths must have at least 3 waypoints")
	
	if patrol_mode and not looped:
		result.add_warning("Patrol mode is most effective with looped paths")
	
	return result

## Duplicates the waypoint path
func duplicate(deep: bool = true) -> WaypointPath:
	var copy: WaypointPath = WaypointPath.new()
	
	copy.path_id = path_id + "_copy"
	copy.path_name = path_name + " Copy"
	copy.description = description
	copy.speed_multiplier = speed_multiplier
	copy.arrival_delay = arrival_delay
	copy.looped = looped
	copy.patrol_mode = patrol_mode
	copy.reverse_on_complete = reverse_on_complete
	
	# Deep copy arrays
	copy.waypoints = waypoints.duplicate()
	copy.assigned_ships = assigned_ships.duplicate()
	copy.assigned_wings = assigned_wings.duplicate()
	copy.path_flags = path_flags.duplicate()
	
	return copy

## Exports to WCS mission format
func export_to_wcs() -> Dictionary:
	return {
		"name": path_name,
		"id": path_id,
		"waypoints": waypoints.map(func(wp): return {"x": wp.x, "y": wp.y, "z": wp.z}),
		"assigned_ships": assigned_ships,
		"assigned_wings": assigned_wings,
		"speed_multiplier": speed_multiplier,
		"arrival_delay": arrival_delay,
		"looped": looped,
		"patrol_mode": patrol_mode,
		"reverse_on_complete": reverse_on_complete,
		"flags": path_flags
	}

## Gets a display string for UI representation
func get_display_string() -> String:
	var assignment_info: String = ""
	if assigned_ships.size() > 0:
		assignment_info = " (ships: %d)" % assigned_ships.size()
	elif assigned_wings.size() > 0:
		assignment_info = " (wings: %d)" % assigned_wings.size()
	
	return "%s [%d waypoints]%s" % [path_name, waypoints.size(), assignment_info]

## Gets path summary for tooltips/info
func get_summary() -> Dictionary:
	return {
		"name": path_name,
		"id": path_id,
		"waypoint_count": waypoints.size(),
		"assigned_ships_count": assigned_ships.size(),
		"assigned_wings_count": assigned_wings.size(),
		"path_length": get_path_length(),
		"is_looped": looped,
		"is_patrol": patrol_mode,
		"speed_multiplier": speed_multiplier,
		"description": description
	}

## Optimizes the path by removing redundant waypoints
func optimize_path(tolerance: float = 5.0) -> int:
	if waypoints.size() < 3:
		return 0
	
	var removed_count: int = 0
	var i: int = 1  # Start from second waypoint
	
	while i < waypoints.size() - 1:
		var prev: Vector3 = waypoints[i - 1]
		var current: Vector3 = waypoints[i]
		var next: Vector3 = waypoints[i + 1]
		
		# Check if current waypoint is approximately on the line between prev and next
		var line_dir: Vector3 = (next - prev).normalized()
		var to_current: Vector3 = current - prev
		var projected: Vector3 = prev + line_dir * to_current.dot(line_dir)
		var distance_to_line: float = current.distance_to(projected)
		
		if distance_to_line < tolerance:
			# Remove redundant waypoint
			waypoints.remove_at(i)
			removed_count += 1
			# Don't increment i as we removed an element
		else:
			i += 1
	
	if removed_count > 0:
		path_changed.emit("waypoints", waypoints, waypoints)
	
	return removed_count

## Reverses the order of waypoints
func reverse_path() -> void:
	waypoints.reverse()
	path_changed.emit("waypoints", waypoints, waypoints)

## Smooths the path using simple averaging
func smooth_path(iterations: int = 1, strength: float = 0.5) -> void:
	if waypoints.size() < 3:
		return
	
	for iter in range(iterations):
		# Create smoothed copy (preserve first and last waypoints)
		var smoothed: Array[Vector3] = waypoints.duplicate()
		
		for i in range(1, waypoints.size() - 1):
			var prev: Vector3 = waypoints[i - 1]
			var current: Vector3 = waypoints[i]
			var next: Vector3 = waypoints[i + 1]
			
			var averaged: Vector3 = (prev + current + next) / 3.0
			smoothed[i] = current.lerp(averaged, strength)
		
		waypoints = smoothed
	
	path_changed.emit("waypoints", waypoints, waypoints)

## Gets estimated travel time for the path (assuming average ship speed)
func get_estimated_travel_time(ship_speed: float = 100.0) -> float:
	var path_length: float = get_path_length()
	var effective_speed: float = ship_speed * speed_multiplier
	
	if effective_speed <= 0.0:
		return 0.0
	
	return (path_length / effective_speed) + arrival_delay