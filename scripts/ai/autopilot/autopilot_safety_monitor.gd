class_name AutopilotSafetyMonitor
extends Node

## Safety monitoring system for autopilot operations
## Handles threat detection, collision prediction, and emergency disengagement

signal threat_detected(threat: Node3D, threat_level: float)
signal collision_imminent(obstacle: Node3D, time_to_collision: float)
signal safe_navigation_corridor_blocked(obstacle: Node3D)
signal emergency_situation_detected(situation: String, severity: float)

enum ThreatType {
	ENEMY_SHIP,
	INCOMING_WEAPON,
	STATIC_OBSTACLE,
	MOVING_OBSTACLE,
	HAZARD_ZONE,
	UNKNOWN
}

enum ThreatLevel {
	NONE = 0,
	LOW = 1,
	MEDIUM = 2,
	HIGH = 3,
	CRITICAL = 4
}

# Safety configuration
@export var threat_detection_radius: float = 2000.0
@export var collision_prediction_time: float = 5.0
@export var minimum_safe_distance: float = 100.0
@export var threat_monitoring_enabled: bool = true
@export var collision_monitoring_enabled: bool = true
@export var emergency_stop_threshold: float = 2.0  # seconds to collision

# System references
var player_ship: Node3D
var collision_detector: Node
var threat_scanner: Node3D

# Threat tracking
var active_threats: Dictionary = {}
var threat_history: Array[Dictionary] = []
var last_threat_scan_time: float = 0.0
var threat_scan_frequency: float = 0.2  # 5 times per second

# Collision prediction
var collision_predictions: Dictionary = {}
var safe_navigation_corridors: Array[Vector3] = []
var last_collision_check_time: float = 0.0
var collision_check_frequency: float = 0.1  # 10 times per second

# Emergency response
var emergency_situations: Dictionary = {}
var safety_override_active: bool = false
var emergency_stop_requested: bool = false

# Performance tracking
var threats_detected_count: int = 0
var false_positive_count: int = 0
var emergency_responses_count: int = 0

func _ready() -> void:
	_initialize_safety_systems()
	set_process(true)

func _process(delta: float) -> void:
	if not threat_monitoring_enabled:
		return
	
	_update_threat_detection(delta)
	_update_collision_prediction(delta)
	_update_emergency_monitoring(delta)
	_cleanup_expired_threats(delta)

# Public safety interface

func set_threat_monitoring_enabled(enabled: bool) -> void:
	"""Enable or disable threat monitoring"""
	threat_monitoring_enabled = enabled
	if not enabled:
		_clear_all_threats()

func set_collision_monitoring_enabled(enabled: bool) -> void:
	"""Enable or disable collision monitoring"""
	collision_monitoring_enabled = enabled
	if not enabled:
		collision_predictions.clear()

func has_active_threats() -> bool:
	"""Check if there are any active threats"""
	return not active_threats.is_empty()

func get_active_threats() -> Array:
	"""Get array of currently active threat objects"""
	var threats: Array = []
	for threat_data in active_threats.values():
		threats.append(threat_data.threat_object)
	return threats

func get_highest_threat_level() -> ThreatLevel:
	"""Get the highest current threat level"""
	var highest_level: ThreatLevel = ThreatLevel.NONE
	
	for threat_data in active_threats.values():
		if threat_data.threat_level > highest_level:
			highest_level = threat_data.threat_level
	
	return highest_level

func get_threat_info(threat: Node3D) -> Dictionary:
	"""Get detailed information about a specific threat"""
	var threat_id: String = str(threat.get_instance_id())
	if active_threats.has(threat_id):
		return active_threats[threat_id]
	return {}

func is_safe_to_navigate() -> bool:
	"""Check if it's safe for autopilot to continue navigation"""
	if has_active_threats():
		var highest_threat: ThreatLevel = get_highest_threat_level()
		if highest_threat >= ThreatLevel.HIGH:
			return false
	
	if _has_imminent_collision():
		return false
	
	if emergency_situations.size() > 0:
		return false
	
	return true

func get_safe_navigation_direction() -> Vector3:
	"""Get recommended safe navigation direction"""
	if not player_ship:
		return Vector3.ZERO
	
	var ship_position: Vector3 = player_ship.global_position
	var safe_direction: Vector3 = Vector3.ZERO
	
	# Analyze threat directions and find safest path
	var threat_directions: Array[Vector3] = []
	for threat_data in active_threats.values():
		var threat_pos: Vector3 = threat_data.threat_object.global_position
		var direction: Vector3 = (threat_pos - ship_position).normalized()
		threat_directions.append(direction)
	
	# Find direction with least threat concentration
	if threat_directions.size() > 0:
		safe_direction = _calculate_safest_direction(threat_directions, ship_position)
	
	return safe_direction

func request_emergency_stop() -> void:
	"""Request immediate emergency stop"""
	emergency_stop_requested = true
	safety_override_active = true
	emergency_responses_count += 1

func clear_emergency_override() -> void:
	"""Clear emergency safety override"""
	safety_override_active = false
	emergency_stop_requested = false

# Threat detection and analysis

func _update_threat_detection(delta: float) -> void:
	"""Update threat detection system"""
	var current_time: float = Time.get_time_from_start()
	if current_time - last_threat_scan_time < threat_scan_frequency:
		return
	
	last_threat_scan_time = current_time
	
	if not player_ship:
		return
	
	# Scan for threats around player ship
	var space_state: PhysicsDirectSpaceState3D = player_ship.get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = threat_detection_radius
	
	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform.origin = player_ship.global_position
	shape_query.collision_mask = 0b1111  # Check relevant collision layers
	
	var results: Array = space_state.intersect_shape(shape_query)
	
	# Process detected objects
	var current_detections: Dictionary = {}
	for result in results:
		var detected_object: Node3D = result["collider"] as Node3D
		if detected_object and detected_object != player_ship:
			_analyze_potential_threat(detected_object, current_detections)
	
	# Update active threats
	_update_threat_states(current_detections)

func _analyze_potential_threat(object: Node3D, current_detections: Dictionary) -> void:
	"""Analyze an object to determine if it's a threat"""
	var threat_type: ThreatType = _classify_object_threat_type(object)
	if threat_type == ThreatType.UNKNOWN:
		return
	
	var threat_level: ThreatLevel = _calculate_threat_level(object, threat_type)
	if threat_level == ThreatLevel.NONE:
		return
	
	var threat_id: String = str(object.get_instance_id())
	var threat_data: Dictionary = {
		"threat_object": object,
		"threat_type": threat_type,
		"threat_level": threat_level,
		"detection_time": Time.get_time_from_start(),
		"last_update_time": Time.get_time_from_start(),
		"distance": player_ship.global_position.distance_to(object.global_position),
		"relative_velocity": _calculate_relative_velocity(object),
		"approach_vector": _calculate_approach_vector(object),
		"time_to_closest_approach": _calculate_time_to_closest_approach(object)
	}
	
	current_detections[threat_id] = threat_data

func _classify_object_threat_type(object: Node3D) -> ThreatType:
	"""Classify object by threat type"""
	# Check object type through groups or class names
	if object.is_in_group("enemy_ships"):
		return ThreatType.ENEMY_SHIP
	elif object.is_in_group("weapons") or object.is_in_group("projectiles"):
		return ThreatType.INCOMING_WEAPON
	elif object.is_in_group("asteroids") or object.is_in_group("debris"):
		return ThreatType.STATIC_OBSTACLE
	elif object.has_method("get_velocity") and object.get_velocity().length() > 0:
		return ThreatType.MOVING_OBSTACLE
	elif object.is_in_group("hazards"):
		return ThreatType.HAZARD_ZONE
	
	# Additional classification based on object properties
	if object.has_method("get_team") and player_ship.has_method("get_team"):
		var object_team: int = object.get_team()
		var player_team: int = player_ship.get_team()
		if object_team != player_team and object_team > 0:
			return ThreatType.ENEMY_SHIP
	
	return ThreatType.UNKNOWN

func _calculate_threat_level(object: Node3D, threat_type: ThreatType) -> ThreatLevel:
	"""Calculate threat level for an object"""
	var base_threat: float = 0.0
	
	# Base threat by type
	match threat_type:
		ThreatType.ENEMY_SHIP:
			base_threat = 3.0
		ThreatType.INCOMING_WEAPON:
			base_threat = 4.0
		ThreatType.MOVING_OBSTACLE:
			base_threat = 2.0
		ThreatType.STATIC_OBSTACLE:
			base_threat = 1.0
		ThreatType.HAZARD_ZONE:
			base_threat = 2.5
	
	# Distance factor
	var distance: float = player_ship.global_position.distance_to(object.global_position)
	var distance_factor: float = 1.0 - clamp(distance / threat_detection_radius, 0.0, 1.0)
	
	# Approach factor
	var approach_factor: float = 1.0
	if object.has_method("get_velocity"):
		var relative_velocity: Vector3 = _calculate_relative_velocity(object)
		var approach_speed: float = -relative_velocity.dot((object.global_position - player_ship.global_position).normalized())
		approach_factor = clamp(approach_speed / 100.0, 0.0, 2.0)  # Max bonus for 100 m/s approach
	
	# Size factor
	var size_factor: float = 1.0
	if object.has_method("get_mass"):
		var mass: float = object.get_mass()
		size_factor = clamp(mass / 1000.0, 0.5, 2.0)  # Scale based on mass
	
	var final_threat: float = base_threat * distance_factor * approach_factor * size_factor
	
	# Convert to threat level enum
	if final_threat >= 3.5:
		return ThreatLevel.CRITICAL
	elif final_threat >= 2.5:
		return ThreatLevel.HIGH
	elif final_threat >= 1.5:
		return ThreatLevel.MEDIUM
	elif final_threat >= 0.5:
		return ThreatLevel.LOW
	else:
		return ThreatLevel.NONE

func _update_threat_states(current_detections: Dictionary) -> void:
	"""Update active threat states"""
	# Add new threats
	for threat_id in current_detections.keys():
		if not active_threats.has(threat_id):
			var threat_data: Dictionary = current_detections[threat_id]
			active_threats[threat_id] = threat_data
			threats_detected_count += 1
			threat_detected.emit(threat_data.threat_object, threat_data.threat_level)
		else:
			# Update existing threat
			active_threats[threat_id].last_update_time = Time.get_time_from_start()
			active_threats[threat_id].threat_level = current_detections[threat_id].threat_level
			active_threats[threat_id].distance = current_detections[threat_id].distance

func _cleanup_expired_threats(delta: float) -> void:
	"""Remove threats that are no longer detected"""
	var current_time: float = Time.get_time_from_start()
	var expired_threats: Array[String] = []
	
	for threat_id in active_threats.keys():
		var threat_data: Dictionary = active_threats[threat_id]
		var time_since_update: float = current_time - threat_data.last_update_time
		
		if time_since_update > 2.0:  # 2 second timeout for threat persistence
			expired_threats.append(threat_id)
	
	# Remove expired threats
	for threat_id in expired_threats:
		active_threats.erase(threat_id)

# Collision prediction

func _update_collision_prediction(delta: float) -> void:
	"""Update collision prediction system"""
	if not collision_monitoring_enabled:
		return
	
	var current_time: float = Time.get_time_from_start()
	if current_time - last_collision_check_time < collision_check_frequency:
		return
	
	last_collision_check_time = current_time
	
	collision_predictions.clear()
	
	# Check collision predictions for active threats
	for threat_data in active_threats.values():
		var threat: Node3D = threat_data.threat_object
		var collision_time: float = _predict_collision_time(threat)
		
		if collision_time > 0 and collision_time <= collision_prediction_time:
			collision_predictions[str(threat.get_instance_id())] = {
				"threat": threat,
				"collision_time": collision_time,
				"collision_point": _predict_collision_point(threat, collision_time)
			}
			
			if collision_time <= emergency_stop_threshold:
				collision_imminent.emit(threat, collision_time)

func _predict_collision_time(object: Node3D) -> float:
	"""Predict time to collision with an object"""
	if not player_ship or not object.has_method("get_velocity"):
		return -1.0
	
	var player_pos: Vector3 = player_ship.global_position
	var player_vel: Vector3 = player_ship.get_velocity() if player_ship.has_method("get_velocity") else Vector3.ZERO
	var object_pos: Vector3 = object.global_position
	var object_vel: Vector3 = object.get_velocity()
	
	var relative_pos: Vector3 = object_pos - player_pos
	var relative_vel: Vector3 = object_vel - player_vel
	
	# Check if objects are approaching
	if relative_vel.dot(relative_pos) >= 0:
		return -1.0  # Objects moving away from each other
	
	# Calculate closest approach time
	var closest_approach_time: float = -relative_pos.dot(relative_vel) / relative_vel.length_squared()
	
	if closest_approach_time < 0:
		return -1.0
	
	# Calculate closest approach distance
	var closest_approach_pos: Vector3 = relative_pos + relative_vel * closest_approach_time
	var closest_distance: float = closest_approach_pos.length()
	
	# Check if collision will occur
	var combined_radius: float = _get_object_radius(player_ship) + _get_object_radius(object)
	if closest_distance <= combined_radius:
		return closest_approach_time
	
	return -1.0

func _predict_collision_point(object: Node3D, collision_time: float) -> Vector3:
	"""Predict collision point"""
	if not player_ship:
		return Vector3.ZERO
	
	var player_vel: Vector3 = player_ship.get_velocity() if player_ship.has_method("get_velocity") else Vector3.ZERO
	return player_ship.global_position + player_vel * collision_time

func _has_imminent_collision() -> bool:
	"""Check if there's an imminent collision"""
	for prediction_data in collision_predictions.values():
		if prediction_data.collision_time <= emergency_stop_threshold:
			return true
	return false

# Emergency monitoring

func _update_emergency_monitoring(delta: float) -> void:
	"""Update emergency situation monitoring"""
	# Check for critical threat combinations
	if get_highest_threat_level() >= ThreatLevel.CRITICAL:
		var situation_id: String = "critical_threat_" + str(Time.get_time_from_start())
		emergency_situations[situation_id] = {
			"type": "critical_threat",
			"severity": 4.0,
			"description": "Critical threat level detected",
			"timestamp": Time.get_time_from_start()
		}
		emergency_situation_detected.emit("critical_threat", 4.0)
	
	# Check for multiple high-level threats
	var high_threat_count: int = 0
	for threat_data in active_threats.values():
		if threat_data.threat_level >= ThreatLevel.HIGH:
			high_threat_count += 1
	
	if high_threat_count >= 3:
		var situation_id: String = "multiple_threats_" + str(Time.get_time_from_start())
		emergency_situations[situation_id] = {
			"type": "multiple_threats",
			"severity": 3.0,
			"description": "Multiple high-level threats detected",
			"timestamp": Time.get_time_from_start()
		}
		emergency_situation_detected.emit("multiple_threats", 3.0)

# Utility functions

func _calculate_relative_velocity(object: Node3D) -> Vector3:
	"""Calculate relative velocity between player ship and object"""
	if not player_ship or not object.has_method("get_velocity"):
		return Vector3.ZERO
	
	var player_vel: Vector3 = player_ship.get_velocity() if player_ship.has_method("get_velocity") else Vector3.ZERO
	var object_vel: Vector3 = object.get_velocity()
	
	return object_vel - player_vel

func _calculate_approach_vector(object: Node3D) -> Vector3:
	"""Calculate approach vector from object to player ship"""
	if not player_ship:
		return Vector3.ZERO
	
	return (player_ship.global_position - object.global_position).normalized()

func _calculate_time_to_closest_approach(object: Node3D) -> float:
	"""Calculate time to closest approach"""
	var relative_velocity: Vector3 = _calculate_relative_velocity(object)
	if relative_velocity.length() < 0.1:
		return INF
	
	var relative_position: Vector3 = object.global_position - player_ship.global_position
	return -relative_position.dot(relative_velocity) / relative_velocity.length_squared()

func _calculate_safest_direction(threat_directions: Array[Vector3], ship_position: Vector3) -> Vector3:
	"""Calculate safest navigation direction avoiding threats"""
	var candidate_directions: Array[Vector3] = [
		Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT,
		Vector3.UP, Vector3.DOWN
	]
	
	var safest_direction: Vector3 = Vector3.FORWARD
	var best_safety_score: float = -1.0
	
	for direction in candidate_directions:
		var safety_score: float = _calculate_direction_safety_score(direction, threat_directions)
		if safety_score > best_safety_score:
			best_safety_score = safety_score
			safest_direction = direction
	
	return safest_direction

func _calculate_direction_safety_score(direction: Vector3, threat_directions: Array[Vector3]) -> float:
	"""Calculate safety score for a direction"""
	var safety_score: float = 1.0
	
	for threat_dir in threat_directions:
		var angle: float = direction.angle_to(threat_dir)
		var threat_factor: float = 1.0 - (angle / PI)  # Closer to opposite direction is safer
		safety_score *= threat_factor
	
	return safety_score

func _get_object_radius(object: Node3D) -> float:
	"""Get approximate radius of an object"""
	if object.has_method("get_radius"):
		return object.get_radius()
	elif object.has_method("get_mass"):
		# Rough estimate based on mass
		var mass: float = object.get_mass()
		return pow(mass / 100.0, 1.0/3.0) * 10.0
	else:
		return 10.0  # Default radius

func _clear_all_threats() -> void:
	"""Clear all active threats"""
	active_threats.clear()
	collision_predictions.clear()
	emergency_situations.clear()

func _initialize_safety_systems() -> void:
	"""Initialize safety monitoring systems"""
	# Systems will be initialized when player ship is assigned
	pass

# Debug interface

func get_safety_status() -> Dictionary:
	"""Get comprehensive safety status for debugging"""
	return {
		"threat_monitoring_enabled": threat_monitoring_enabled,
		"collision_monitoring_enabled": collision_monitoring_enabled,
		"active_threats_count": active_threats.size(),
		"highest_threat_level": ThreatLevel.keys()[get_highest_threat_level()],
		"collision_predictions_count": collision_predictions.size(),
		"emergency_situations_count": emergency_situations.size(),
		"safety_override_active": safety_override_active,
		"emergency_stop_requested": emergency_stop_requested,
		"threats_detected_total": threats_detected_count,
		"false_positives_total": false_positive_count,
		"emergency_responses_total": emergency_responses_count
	}