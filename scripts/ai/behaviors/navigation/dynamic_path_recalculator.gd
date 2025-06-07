class_name DynamicPathRecalculator
extends Node

## Dynamic path recalculation system for real-time obstacle and threat avoidance
## Monitors path validity and triggers replanning when needed

signal path_recalculation_triggered(agent_id: String, reason: String)
signal path_recalculated(agent_id: String, new_path: Array[Vector3])
signal recalculation_failed(agent_id: String, reason: String)

# Recalculation triggers and thresholds
@export var validity_check_interval: float = 0.5  # Check path validity every 500ms
@export var obstacle_prediction_time: float = 3.0  # Predict obstacle positions 3 seconds ahead
@export var threat_reaction_distance: float = 400.0  # Distance to react to threats
@export var path_deviation_threshold: float = 100.0  # Recalculate if ship deviates too far from path

# Performance settings
@export var max_recalculations_per_second: int = 10  # Rate limiting
@export var priority_agent_boost: int = 2  # Priority agents get more frequent updates
@export var background_processing: bool = true  # Process some updates in background

# Agent tracking data
var monitored_agents: Dictionary = {}  # agent_id -> AgentPathData
var recalculation_queue: Array[String] = []  # Queue of agents needing recalculation
var last_recalculation_times: Dictionary = {}  # agent_id -> timestamp
var recalculation_count: int = 0  # Total recalculations performed

# Obstacle and threat detection
var obstacle_detector: Node
var threat_assessor: Node
var path_planner: WCSPathPlanner

# Performance tracking
var recalculation_performance: Dictionary = {}
var update_timer: float = 0.0

class AgentPathData:
	var agent_id: String
	var current_path: Array[Vector3] = []
	var current_position: Vector3
	var target_position: Vector3
	var last_check_time: float = 0.0
	var path_start_time: float = 0.0
	var is_priority: bool = false
	var recalculation_count: int = 0
	var last_recalculation_reason: String = ""
	
	func _init(id: String):
		agent_id = id
		path_start_time = Time.get_time_dict_from_system()["unix"]

func _ready() -> void:
	_initialize_systems()
	set_process(true)

func _process(delta: float) -> void:
	update_timer += delta
	
	if update_timer >= validity_check_interval:
		_process_path_validity_checks()
		_process_recalculation_queue()
		update_timer = 0.0

# Public interface

func register_agent(agent_id: String, initial_path: Array[Vector3], is_priority: bool = false) -> void:
	"""Register an agent for path monitoring"""
	var agent_data: AgentPathData = AgentPathData.new(agent_id)
	agent_data.current_path = initial_path.duplicate()
	agent_data.is_priority = is_priority
	
	monitored_agents[agent_id] = agent_data
	
	if is_debug_enabled():
		print("DynamicPathRecalculator: Registered agent ", agent_id, " with ", initial_path.size(), " waypoints")

func unregister_agent(agent_id: String) -> void:
	"""Unregister an agent from path monitoring"""
	if monitored_agents.has(agent_id):
		monitored_agents.erase(agent_id)
		
	if last_recalculation_times.has(agent_id):
		last_recalculation_times.erase(agent_id)
	
	# Remove from queue if present
	if agent_id in recalculation_queue:
		recalculation_queue.erase(agent_id)

func update_agent_position(agent_id: String, position: Vector3) -> void:
	"""Update agent's current position for monitoring"""
	var agent_data: AgentPathData = monitored_agents.get(agent_id, null)
	if agent_data:
		agent_data.current_position = position

func update_agent_path(agent_id: String, new_path: Array[Vector3]) -> void:
	"""Update agent's current path"""
	var agent_data: AgentPathData = monitored_agents.get(agent_id, null)
	if agent_data:
		agent_data.current_path = new_path.duplicate()
		agent_data.path_start_time = Time.get_time_dict_from_system()["unix"]

func force_recalculation(agent_id: String, reason: String = "manual_trigger") -> void:
	"""Force immediate path recalculation for an agent"""
	if not monitored_agents.has(agent_id):
		return
	
	_add_to_recalculation_queue(agent_id, reason)

func set_agent_priority(agent_id: String, is_priority: bool) -> void:
	"""Set agent priority status for more frequent updates"""
	var agent_data: AgentPathData = monitored_agents.get(agent_id, null)
	if agent_data:
		agent_data.is_priority = is_priority

func check_path_validity_immediate(agent_id: String) -> Dictionary:
	"""Immediately check path validity for an agent"""
	var agent_data: AgentPathData = monitored_agents.get(agent_id, null)
	if not agent_data:
		return {"valid": false, "reason": "agent_not_found"}
	
	return _check_path_validity(agent_data)

# Path validity checking

func _process_path_validity_checks() -> void:
	"""Process path validity checks for all monitored agents"""
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	var checks_performed: int = 0
	var max_checks_per_frame: int = 5  # Limit checks per frame for performance
	
	for agent_id in monitored_agents:
		if checks_performed >= max_checks_per_frame:
			break
		
		var agent_data: AgentPathData = monitored_agents[agent_id]
		var check_interval: float = validity_check_interval
		
		# Priority agents get more frequent checks
		if agent_data.is_priority:
			check_interval *= 0.5
		
		if current_time - agent_data.last_check_time >= check_interval:
			var validity_result: Dictionary = _check_path_validity(agent_data)
			agent_data.last_check_time = current_time
			checks_performed += 1
			
			if not validity_result.get("valid", true):
				_add_to_recalculation_queue(agent_id, validity_result.get("reason", "unknown"))

func _check_path_validity(agent_data: AgentPathData) -> Dictionary:
	"""Check if agent's current path is still valid"""
	var result: Dictionary = {"valid": true, "reason": ""}
	
	if agent_data.current_path.is_empty():
		result.valid = false
		result.reason = "empty_path"
		return result
	
	# Check for obstacles blocking the path
	var obstacle_check: Dictionary = _check_path_obstacles(agent_data)
	if not obstacle_check.get("clear", true):
		result.valid = false
		result.reason = "obstacle_detected"
		result.details = obstacle_check
		return result
	
	# Check for threats requiring avoidance
	var threat_check: Dictionary = _check_path_threats(agent_data)
	if threat_check.get("threat_level", 0.0) > 0.5:
		result.valid = false
		result.reason = "threat_avoidance_required"
		result.details = threat_check
		return result
	
	# Check for path deviation
	var deviation_check: Dictionary = _check_path_deviation(agent_data)
	if not deviation_check.get("on_path", true):
		result.valid = false
		result.reason = "path_deviation"
		result.details = deviation_check
		return result
	
	# Check for moving obstacles in predicted path
	var prediction_check: Dictionary = _check_predicted_obstacles(agent_data)
	if not prediction_check.get("clear", true):
		result.valid = false
		result.reason = "predicted_collision"
		result.details = prediction_check
		return result
	
	return result

func _check_path_obstacles(agent_data: AgentPathData) -> Dictionary:
	"""Check for static obstacles blocking the path"""
	var result: Dictionary = {"clear": true, "blocked_segments": []}
	
	if agent_data.current_path.size() < 2:
		return result
	
	# Check segments of the path
	var blocked_segments: Array = []
	var check_distance: float = min(500.0, agent_data.current_position.distance_to(agent_data.current_path[-1]))
	var segments_to_check: int = min(5, agent_data.current_path.size() - 1)  # Check next 5 segments
	
	for i in range(segments_to_check):
		if i >= agent_data.current_path.size() - 1:
			break
		
		var segment_start: Vector3 = agent_data.current_path[i]
		var segment_end: Vector3 = agent_data.current_path[i + 1]
		
		# Skip if segment is too far away
		if agent_data.current_position.distance_to(segment_start) > check_distance:
			continue
		
		if not _is_path_segment_clear(segment_start, segment_end):
			blocked_segments.append(i)
	
	if not blocked_segments.is_empty():
		result.clear = false
		result.blocked_segments = blocked_segments
	
	return result

func _check_path_threats(agent_data: AgentPathData) -> Dictionary:
	"""Check for threats near the path requiring avoidance"""
	var result: Dictionary = {"threat_level": 0.0, "threats": []}
	
	if not threat_assessor:
		return result
	
	var threats: Array = []
	var max_threat_level: float = 0.0
	
	# Get nearby threats
	var nearby_threats: Array = _get_threats_near_path(agent_data.current_path, threat_reaction_distance)
	
	for threat in nearby_threats:
		if threat.has("position") and threat.has("threat_level"):
			var threat_pos: Vector3 = threat.position
			var threat_level: float = threat.threat_level
			
			# Calculate threat impact on path
			var closest_distance: float = _get_closest_distance_to_path(threat_pos, agent_data.current_path)
			
			if closest_distance < threat_reaction_distance:
				var impact_factor: float = 1.0 - (closest_distance / threat_reaction_distance)
				var adjusted_threat: float = threat_level * impact_factor
				
				threats.append({
					"position": threat_pos,
					"threat_level": adjusted_threat,
					"distance": closest_distance
				})
				
				max_threat_level = max(max_threat_level, adjusted_threat)
	
	result.threat_level = max_threat_level
	result.threats = threats
	
	return result

func _check_path_deviation(agent_data: AgentPathData) -> Dictionary:
	"""Check if agent has deviated too far from planned path"""
	var result: Dictionary = {"on_path": true, "deviation_distance": 0.0}
	
	if agent_data.current_path.is_empty():
		return result
	
	# Find closest point on path
	var closest_distance: float = _get_closest_distance_to_path(agent_data.current_position, agent_data.current_path)
	
	result.deviation_distance = closest_distance
	result.on_path = closest_distance <= path_deviation_threshold
	
	return result

func _check_predicted_obstacles(agent_data: AgentPathData) -> Dictionary:
	"""Check for predicted moving obstacle collisions"""
	var result: Dictionary = {"clear": true, "predicted_collisions": []}
	
	# Get moving obstacles (ships, missiles, etc.)
	var moving_obstacles: Array = _get_moving_obstacles_near_path(agent_data.current_path)
	var predicted_collisions: Array = []
	
	for obstacle in moving_obstacles:
		if not obstacle.has("position") or not obstacle.has("velocity"):
			continue
		
		var obstacle_pos: Vector3 = obstacle.position
		var obstacle_vel: Vector3 = obstacle.velocity
		
		# Predict obstacle position
		var predicted_pos: Vector3 = obstacle_pos + obstacle_vel * obstacle_prediction_time
		
		# Check if predicted position intersects with path
		var collision_risk: Dictionary = _check_obstacle_path_intersection(predicted_pos, agent_data.current_path)
		
		if collision_risk.get("collision", false):
			predicted_collisions.append({
				"obstacle": obstacle,
				"predicted_position": predicted_pos,
				"collision_time": collision_risk.get("time", 0.0),
				"collision_point": collision_risk.get("point", Vector3.ZERO)
			})
	
	if not predicted_collisions.is_empty():
		result.clear = false
		result.predicted_collisions = predicted_collisions
	
	return result

# Recalculation processing

func _process_recalculation_queue() -> void:
	"""Process the recalculation queue with rate limiting"""
	var max_recalculations: int = max_recalculations_per_second
	var recalculations_this_frame: int = 0
	
	while not recalculation_queue.is_empty() and recalculations_this_frame < max_recalculations:
		var agent_id: String = recalculation_queue.pop_front()
		
		if _perform_path_recalculation(agent_id):
			recalculations_this_frame += 1
			recalculation_count += 1

func _add_to_recalculation_queue(agent_id: String, reason: String) -> void:
	"""Add agent to recalculation queue"""
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	var last_recalc: float = last_recalculation_times.get(agent_id, 0.0)
	
	# Rate limiting - don't recalculate too frequently
	if current_time - last_recalc < 1.0:  # Min 1 second between recalculations
		return
	
	if agent_id not in recalculation_queue:
		recalculation_queue.append(agent_id)
		path_recalculation_triggered.emit(agent_id, reason)
		
		var agent_data: AgentPathData = monitored_agents.get(agent_id, null)
		if agent_data:
			agent_data.last_recalculation_reason = reason

func _perform_path_recalculation(agent_id: String) -> bool:
	"""Perform actual path recalculation for an agent"""
	var agent_data: AgentPathData = monitored_agents.get(agent_id, null)
	if not agent_data or not path_planner:
		return false
	
	var start_time: float = Time.get_time_dict_from_system()["unix"]
	last_recalculation_times[agent_id] = start_time
	
	# Determine target position
	var target_pos: Vector3
	if not agent_data.current_path.is_empty():
		target_pos = agent_data.current_path[-1]  # Last waypoint
	else:
		target_pos = agent_data.target_position
	
	if target_pos == Vector3.ZERO:
		recalculation_failed.emit(agent_id, "no_target_position")
		return false
	
	# Set up constraints for path planning
	var constraints: Dictionary = {
		"avoid_threats": true,
		"threat_avoidance_factor": 150.0,
		"terrain_cost_multiplier": 1.2
	}
	
	# Calculate new path
	var new_path: Array[Vector3] = path_planner.calculate_path(
		agent_data.current_position,
		target_pos,
		constraints
	)
	
	if new_path.is_empty():
		recalculation_failed.emit(agent_id, "no_path_found")
		return false
	
	# Update agent data
	agent_data.current_path = new_path
	agent_data.recalculation_count += 1
	agent_data.path_start_time = start_time
	
	# Record performance
	var calculation_time: float = Time.get_time_dict_from_system()["unix"] - start_time
	recalculation_performance[agent_id] = calculation_time
	
	path_recalculated.emit(agent_id, new_path)
	
	if is_debug_enabled():
		print("DynamicPathRecalculator: Recalculated path for ", agent_id, " (", new_path.size(), " waypoints, ", calculation_time, "s)")
	
	return true

# Utility methods

func _is_path_segment_clear(start: Vector3, end: Vector3) -> bool:
	"""Check if path segment is clear of obstacles"""
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return true
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
	query.collision_mask = _get_obstacle_collision_mask()
	
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()

func _get_closest_distance_to_path(point: Vector3, path: Array[Vector3]) -> float:
	"""Get closest distance from point to path"""
	if path.is_empty():
		return INF
	
	var min_distance: float = INF
	
	# Check distance to each path segment
	for i in range(path.size() - 1):
		var segment_start: Vector3 = path[i]
		var segment_end: Vector3 = path[i + 1]
		var distance: float = _point_to_line_segment_distance(point, segment_start, segment_end)
		min_distance = min(min_distance, distance)
	
	# Also check distance to individual waypoints
	for waypoint in path:
		var distance: float = point.distance_to(waypoint)
		min_distance = min(min_distance, distance)
	
	return min_distance

func _point_to_line_segment_distance(point: Vector3, line_start: Vector3, line_end: Vector3) -> float:
	"""Calculate distance from point to line segment"""
	var line_vector: Vector3 = line_end - line_start
	var point_vector: Vector3 = point - line_start
	
	var line_length_squared: float = line_vector.length_squared()
	if line_length_squared == 0.0:
		return point_vector.length()
	
	var projection: float = point_vector.dot(line_vector) / line_length_squared
	projection = clamp(projection, 0.0, 1.0)
	
	var closest_point: Vector3 = line_start + line_vector * projection
	return point.distance_to(closest_point)

func _get_threats_near_path(path: Array[Vector3], detection_radius: float) -> Array:
	"""Get threats near the path within detection radius"""
	var threats: Array = []
	
	# Get enemy ships and other threats
	var enemy_ships: Array = get_tree().get_nodes_in_group("enemy_ships")
	var missiles: Array = get_tree().get_nodes_in_group("missiles")
	
	for ship in enemy_ships:
		if ship is Node3D:
			var distance: float = _get_closest_distance_to_path(ship.global_position, path)
			if distance <= detection_radius:
				threats.append({
					"position": ship.global_position,
					"threat_level": 0.8,  # High threat level for enemy ships
					"type": "enemy_ship"
				})
	
	for missile in missiles:
		if missile is Node3D:
			var distance: float = _get_closest_distance_to_path(missile.global_position, path)
			if distance <= detection_radius:
				threats.append({
					"position": missile.global_position,
					"threat_level": 0.6,  # Medium threat level for missiles
					"type": "missile"
				})
	
	return threats

func _get_moving_obstacles_near_path(path: Array[Vector3]) -> Array:
	"""Get moving obstacles near the path"""
	var obstacles: Array = []
	
	# Get all ships (friendly and enemy)
	var ships: Array = get_tree().get_nodes_in_group("ships")
	
	for ship in ships:
		if ship is Node3D and ship.has_method("get_velocity"):
			var distance: float = _get_closest_distance_to_path(ship.global_position, path)
			if distance <= threat_reaction_distance:
				obstacles.append({
					"position": ship.global_position,
					"velocity": ship.get_velocity(),
					"type": "ship"
				})
	
	return obstacles

func _check_obstacle_path_intersection(obstacle_pos: Vector3, path: Array[Vector3]) -> Dictionary:
	"""Check if obstacle position intersects with path"""
	var result: Dictionary = {"collision": false}
	var collision_radius: float = 75.0  # Collision detection radius
	
	for i in range(path.size()):
		var distance: float = obstacle_pos.distance_to(path[i])
		if distance <= collision_radius:
			result.collision = true
			result.point = path[i]
			result.time = float(i)  # Simplified time calculation
			break
	
	return result

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

func _initialize_systems() -> void:
	"""Initialize required systems"""
	# Find path planner
	path_planner = get_node_or_null("../PathPlanner")
	if not path_planner:
		path_planner = WCSPathPlanner.new()
		add_child(path_planner)
	
	# Initialize performance tracking
	recalculation_performance.clear()

func is_debug_enabled() -> bool:
	"""Check if debug output is enabled"""
	return OS.is_debug_build()

# Public statistics interface

func get_recalculation_statistics() -> Dictionary:
	"""Get path recalculation performance statistics"""
	var avg_recalc_time: float = 0.0
	if not recalculation_performance.is_empty():
		var total_time: float = 0.0
		for time in recalculation_performance.values():
			total_time += time
		avg_recalc_time = total_time / recalculation_performance.size()
	
	return {
		"monitored_agents": monitored_agents.size(),
		"total_recalculations": recalculation_count,
		"queue_size": recalculation_queue.size(),
		"average_recalculation_time": avg_recalc_time,
		"performance_samples": recalculation_performance.size()
	}