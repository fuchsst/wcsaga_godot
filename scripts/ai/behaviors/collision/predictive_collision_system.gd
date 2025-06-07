class_name PredictiveCollisionSystem
extends Node

## Advanced predictive collision detection for moving objects
## Handles complex scenarios with multiple moving threats

signal future_collision_detected(ship: Node3D, threat: Node3D, prediction: Dictionary)
signal collision_course_changed(ship: Node3D, threat: Node3D, new_prediction: Dictionary)
signal safe_corridor_calculated(ship: Node3D, corridor_points: Array[Vector3])

@export var max_prediction_time: float = 5.0
@export var prediction_resolution: float = 0.1
@export var velocity_samples: int = 10
@export var acceleration_prediction: bool = true
@export var formation_awareness: bool = true

var active_predictions: Dictionary = {}
var safe_corridors: Dictionary = {}
var prediction_cache: Dictionary = {}

class CollisionPrediction:
	var ship: Node3D
	var threat: Node3D
	var collision_time: float
	var collision_point: Vector3
	var collision_probability: float
	var relative_speed: float
	var impact_severity: float
	var avoidance_options: Array[Dictionary]
	var last_calculated: float
	
	func _init(s: Node3D, t: Node3D) -> void:
		ship = s
		threat = t
		last_calculated = Time.get_time_dict_from_system()["unix"]

class SafeCorridor:
	var waypoints: Array[Vector3]
	var width: float
	var confidence: float
	var valid_until: float
	var threat_free_time: float
	
	func _init(points: Array[Vector3], w: float) -> void:
		waypoints = points
		width = w
		confidence = 1.0
		valid_until = Time.get_time_dict_from_system()["unix"] + 10.0  # Valid for 10 seconds

func predict_collision(ship: Node3D, threat: Node3D, max_time: float = 0.0) -> CollisionPrediction:
	if max_time <= 0.0:
		max_time = max_prediction_time
	
	var prediction: CollisionPrediction = CollisionPrediction.new(ship, threat)
	
	# Get current states
	var ship_state: Dictionary = _get_object_state(ship)
	var threat_state: Dictionary = _get_object_state(threat)
	
	# Calculate basic collision prediction
	var basic_result: Dictionary = _calculate_basic_collision(ship_state, threat_state)
	
	if basic_result.get("collision_possible", false):
		prediction.collision_time = basic_result.get("time_to_collision", max_time)
		prediction.collision_point = basic_result.get("collision_point", Vector3.ZERO)
		prediction.relative_speed = basic_result.get("relative_speed", 0.0)
		
		# Enhanced prediction with acceleration
		if acceleration_prediction:
			var enhanced_result: Dictionary = _predict_with_acceleration(ship_state, threat_state, prediction.collision_time)
			prediction.collision_time = enhanced_result.get("refined_time", prediction.collision_time)
			prediction.collision_point = enhanced_result.get("refined_point", prediction.collision_point)
		
		# Calculate collision probability and severity
		prediction.collision_probability = _calculate_collision_probability(ship_state, threat_state, prediction.collision_time)
		prediction.impact_severity = _calculate_impact_severity(ship_state, threat_state, prediction.relative_speed)
		
		# Generate avoidance options
		prediction.avoidance_options = _generate_avoidance_options(ship_state, threat_state, prediction)
		
		# Cache the prediction
		var cache_key: String = str(ship.get_instance_id()) + "_" + str(threat.get_instance_id())
		prediction_cache[cache_key] = prediction
	
	return prediction

func _get_object_state(object: Node3D) -> Dictionary:
	var state: Dictionary = {
		"position": object.global_position,
		"velocity": Vector3.ZERO,
		"acceleration": Vector3.ZERO,
		"angular_velocity": Vector3.ZERO,
		"radius": _get_object_radius(object),
		"mass": 1.0,
		"max_thrust": 100.0
	}
	
	# Get velocity
	if object.has_method("get_velocity"):
		state["velocity"] = object.get_velocity()
	elif object.has_method("get_linear_velocity"):
		state["velocity"] = object.get_linear_velocity()
	
	# Get acceleration
	if object.has_method("get_acceleration"):
		state["acceleration"] = object.get_acceleration()
	
	# Get angular velocity
	if object.has_method("get_angular_velocity"):
		state["angular_velocity"] = object.get_angular_velocity()
	
	# Get physical properties
	if object.has_method("get_mass"):
		state["mass"] = object.get_mass()
	
	if object.has_method("get_max_thrust"):
		state["max_thrust"] = object.get_max_thrust()
	
	return state

func _calculate_basic_collision(ship_state: Dictionary, threat_state: Dictionary) -> Dictionary:
	var ship_pos: Vector3 = ship_state["position"]
	var ship_vel: Vector3 = ship_state["velocity"]
	var threat_pos: Vector3 = threat_state["position"]
	var threat_vel: Vector3 = threat_state["velocity"]
	
	var relative_position: Vector3 = threat_pos - ship_pos
	var relative_velocity: Vector3 = ship_vel - threat_vel
	
	# Check if approaching
	if relative_velocity.dot(relative_position) <= 0:
		return {"collision_possible": false}
	
	# Solve for collision time
	var a: float = relative_velocity.length_squared()
	var b: float = 2.0 * relative_position.dot(relative_velocity)
	var combined_radius: float = ship_state["radius"] + threat_state["radius"]
	var c: float = relative_position.length_squared() - combined_radius * combined_radius
	
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0:
		return {"collision_possible": false}
	
	var t1: float = (-b - sqrt(discriminant)) / (2.0 * a)
	var t2: float = (-b + sqrt(discriminant)) / (2.0 * a)
	
	var collision_time: float = t1 if t1 > 0 else t2
	if collision_time <= 0 or collision_time > max_prediction_time:
		return {"collision_possible": false}
	
	var collision_point: Vector3 = ship_pos + ship_vel * collision_time
	var relative_speed: float = relative_velocity.length()
	
	return {
		"collision_possible": true,
		"time_to_collision": collision_time,
		"collision_point": collision_point,
		"relative_speed": relative_speed
	}

func _predict_with_acceleration(ship_state: Dictionary, threat_state: Dictionary, basic_time: float) -> Dictionary:
	var ship_pos: Vector3 = ship_state["position"]
	var ship_vel: Vector3 = ship_state["velocity"]
	var ship_acc: Vector3 = ship_state["acceleration"]
	var threat_pos: Vector3 = threat_state["position"]
	var threat_vel: Vector3 = threat_state["velocity"]
	var threat_acc: Vector3 = threat_state["acceleration"]
	
	# Iterative refinement with acceleration
	var refined_time: float = basic_time
	for i in range(5):  # 5 iterations for convergence
		# Predict positions with acceleration
		var ship_future_pos: Vector3 = ship_pos + ship_vel * refined_time + 0.5 * ship_acc * refined_time * refined_time
		var threat_future_pos: Vector3 = threat_pos + threat_vel * refined_time + 0.5 * threat_acc * refined_time * refined_time
		
		var distance: float = ship_future_pos.distance_to(threat_future_pos)
		var combined_radius: float = ship_state["radius"] + threat_state["radius"]
		
		if distance < combined_radius:
			# Collision confirmed, refine timing
			var time_adjustment: float = (combined_radius - distance) / (ship_vel.length() + threat_vel.length())
			refined_time = max(0.0, refined_time - time_adjustment * 0.5)
		else:
			break
	
	var refined_point: Vector3 = ship_pos + ship_vel * refined_time + 0.5 * ship_acc * refined_time * refined_time
	
	return {
		"refined_time": refined_time,
		"refined_point": refined_point
	}

func _calculate_collision_probability(ship_state: Dictionary, threat_state: Dictionary, collision_time: float) -> float:
	# Base probability from time factor
	var time_factor: float = 1.0 - (collision_time / max_prediction_time)
	
	# Velocity uncertainty factor
	var ship_speed: float = ship_state["velocity"].length()
	var threat_speed: float = threat_state["velocity"].length()
	var speed_uncertainty: float = 1.0 - min(1.0, (ship_speed + threat_speed) / 200.0)
	
	# Trajectory alignment factor
	var relative_position: Vector3 = threat_state["position"] - ship_state["position"]
	var relative_velocity: Vector3 = ship_state["velocity"] - threat_state["velocity"]
	var alignment: float = abs(relative_velocity.normalized().dot(relative_position.normalized()))
	
	# Combined probability
	var probability: float = time_factor * (1.0 - speed_uncertainty * 0.3) * alignment
	return clamp(probability, 0.0, 1.0)

func _calculate_impact_severity(ship_state: Dictionary, threat_state: Dictionary, relative_speed: float) -> float:
	var ship_mass: float = ship_state["mass"]
	var threat_mass: float = threat_state["mass"]
	var combined_mass: float = ship_mass + threat_mass
	
	# Kinetic energy based severity
	var kinetic_energy: float = 0.5 * combined_mass * relative_speed * relative_speed
	var severity: float = kinetic_energy / 10000.0  # Normalize to reasonable range
	
	return clamp(severity, 0.0, 1.0)

func _generate_avoidance_options(ship_state: Dictionary, threat_state: Dictionary, prediction: CollisionPrediction) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var ship_pos: Vector3 = ship_state["position"]
	var threat_pos: Vector3 = threat_state["position"]
	var collision_point: Vector3 = prediction.collision_point
	
	# Calculate avoidance vectors
	var to_collision: Vector3 = (collision_point - ship_pos).normalized()
	var perpendicular: Vector3 = Vector3.UP.cross(to_collision).normalized()
	
	# Option 1: Turn left
	var left_option: Dictionary = {
		"type": "turn_left",
		"vector": -perpendicular,
		"effectiveness": _calculate_avoidance_effectiveness(ship_state, threat_state, -perpendicular, prediction.collision_time),
		"required_time": prediction.collision_time * 0.7,
		"energy_cost": 0.3
	}
	options.append(left_option)
	
	# Option 2: Turn right
	var right_option: Dictionary = {
		"type": "turn_right", 
		"vector": perpendicular,
		"effectiveness": _calculate_avoidance_effectiveness(ship_state, threat_state, perpendicular, prediction.collision_time),
		"required_time": prediction.collision_time * 0.7,
		"energy_cost": 0.3
	}
	options.append(right_option)
	
	# Option 3: Climb
	var climb_option: Dictionary = {
		"type": "climb",
		"vector": Vector3.UP,
		"effectiveness": _calculate_avoidance_effectiveness(ship_state, threat_state, Vector3.UP, prediction.collision_time),
		"required_time": prediction.collision_time * 0.8,
		"energy_cost": 0.4
	}
	options.append(climb_option)
	
	# Option 4: Dive
	var dive_option: Dictionary = {
		"type": "dive",
		"vector": Vector3.DOWN,
		"effectiveness": _calculate_avoidance_effectiveness(ship_state, threat_state, Vector3.DOWN, prediction.collision_time),
		"required_time": prediction.collision_time * 0.8,
		"energy_cost": 0.4
	}
	options.append(dive_option)
	
	# Option 5: Hard brake
	var brake_option: Dictionary = {
		"type": "brake",
		"vector": -ship_state["velocity"].normalized(),
		"effectiveness": _calculate_braking_effectiveness(ship_state, threat_state, prediction.collision_time),
		"required_time": prediction.collision_time * 0.9,
		"energy_cost": 0.5
	}
	options.append(brake_option)
	
	# Sort by effectiveness
	options.sort_custom(func(a, b): return a["effectiveness"] > b["effectiveness"])
	
	return options

func _calculate_avoidance_effectiveness(ship_state: Dictionary, threat_state: Dictionary, avoidance_vector: Vector3, collision_time: float) -> float:
	var ship_thrust: float = ship_state["max_thrust"]
	var ship_mass: float = ship_state["mass"]
	var max_acceleration: float = ship_thrust / ship_mass
	
	# Calculate required displacement
	var required_displacement: float = ship_state["radius"] + threat_state["radius"] + 50.0  # Safety margin
	
	# Calculate achievable displacement
	var achievable_displacement: float = 0.5 * max_acceleration * collision_time * collision_time
	
	# Effectiveness based on ability to clear collision
	var effectiveness: float = min(1.0, achievable_displacement / required_displacement)
	
	# Penalty for opposing current velocity
	var current_velocity: Vector3 = ship_state["velocity"]
	if current_velocity.length() > 0.1:
		var velocity_alignment: float = avoidance_vector.dot(current_velocity.normalized())
		if velocity_alignment < 0:
			effectiveness *= (1.0 + velocity_alignment * 0.3)  # Reduce effectiveness for opposing moves
	
	return clamp(effectiveness, 0.0, 1.0)

func _calculate_braking_effectiveness(ship_state: Dictionary, threat_state: Dictionary, collision_time: float) -> float:
	var ship_velocity: Vector3 = ship_state["velocity"]
	var threat_velocity: Vector3 = threat_state["velocity"]
	var relative_velocity: Vector3 = ship_velocity - threat_velocity
	
	var ship_thrust: float = ship_state["max_thrust"]
	var ship_mass: float = ship_state["mass"]
	var max_deceleration: float = ship_thrust / ship_mass
	
	# Calculate speed reduction possible
	var speed_reduction: float = max_deceleration * collision_time
	var current_relative_speed: float = relative_velocity.length()
	
	# Effectiveness based on speed reduction
	var effectiveness: float = min(1.0, speed_reduction / current_relative_speed)
	
	return clamp(effectiveness, 0.0, 1.0)

func calculate_safe_corridor(ship: Node3D, destination: Vector3, threats: Array[Node3D]) -> SafeCorridor:
	var ship_pos: Vector3 = ship.global_position
	var direct_path: Vector3 = destination - ship_pos
	var path_length: float = direct_path.length()
	var path_direction: Vector3 = direct_path.normalized()
	
	# Generate corridor waypoints
	var waypoint_count: int = max(3, int(path_length / 500.0))  # One waypoint per 500 units
	var waypoints: Array[Vector3] = [ship_pos]
	
	for i in range(1, waypoint_count):
		var progress: float = float(i) / float(waypoint_count)
		var base_point: Vector3 = ship_pos + direct_path * progress
		
		# Adjust waypoint to avoid threats
		var adjusted_point: Vector3 = _adjust_waypoint_for_threats(base_point, threats, progress * path_length)
		waypoints.append(adjusted_point)
	
	waypoints.append(destination)
	
	# Calculate corridor width based on threat density
	var corridor_width: float = _calculate_optimal_corridor_width(waypoints, threats)
	
	var corridor: SafeCorridor = SafeCorridor.new(waypoints, corridor_width)
	corridor.confidence = _calculate_corridor_confidence(waypoints, threats)
	
	# Cache the corridor
	safe_corridors[ship] = corridor
	safe_corridor_calculated.emit(ship, waypoints)
	
	return corridor

func _adjust_waypoint_for_threats(base_point: Vector3, threats: Array[Node3D], distance_along_path: float) -> Vector3:
	var adjusted_point: Vector3 = base_point
	var max_adjustment: float = 200.0  # Maximum waypoint adjustment
	
	for threat in threats:
		if not is_instance_valid(threat):
			continue
		
		var threat_pos: Vector3 = threat.global_position
		var distance_to_threat: float = base_point.distance_to(threat_pos)
		var threat_radius: float = _get_object_radius(threat)
		var safe_distance: float = threat_radius + 100.0  # Safety margin
		
		if distance_to_threat < safe_distance:
			# Calculate avoidance vector
			var avoidance_vector: Vector3 = (base_point - threat_pos).normalized()
			var adjustment_strength: float = (safe_distance - distance_to_threat) / safe_distance
			var adjustment: Vector3 = avoidance_vector * adjustment_strength * max_adjustment
			
			adjusted_point += adjustment
	
	return adjusted_point

func _calculate_optimal_corridor_width(waypoints: Array[Vector3], threats: Array[Node3D]) -> float:
	var base_width: float = 100.0
	var max_width: float = 500.0
	
	# Increase width based on threat density
	var threat_density: float = 0.0
	for i in range(waypoints.size() - 1):
		var segment_start: Vector3 = waypoints[i]
		var segment_end: Vector3 = waypoints[i + 1]
		var segment_center: Vector3 = (segment_start + segment_end) * 0.5
		
		var nearby_threats: int = 0
		for threat in threats:
			if is_instance_valid(threat) and segment_center.distance_to(threat.global_position) < 300.0:
				nearby_threats += 1
		
		threat_density += nearby_threats
	
	var adjusted_width: float = base_width + (threat_density / waypoints.size()) * 100.0
	return min(adjusted_width, max_width)

func _calculate_corridor_confidence(waypoints: Array[Vector3], threats: Array[Node3D]) -> float:
	var confidence: float = 1.0
	
	# Reduce confidence based on proximity to threats
	for waypoint in waypoints:
		for threat in threats:
			if not is_instance_valid(threat):
				continue
			
			var distance: float = waypoint.distance_to(threat.global_position)
			var threat_radius: float = _get_object_radius(threat)
			
			if distance < threat_radius + 200.0:
				confidence *= 0.9  # Reduce confidence
	
	return clamp(confidence, 0.1, 1.0)

func _get_object_radius(object: Node3D) -> float:
	if object.has_method("get_collision_radius"):
		return object.get_collision_radius()
	
	# Default radius estimation
	var scale: Vector3 = object.scale
	return max(scale.x, max(scale.y, scale.z)) * 10.0

func get_cached_prediction(ship: Node3D, threat: Node3D) -> CollisionPrediction:
	var cache_key: String = str(ship.get_instance_id()) + "_" + str(threat.get_instance_id())
	if prediction_cache.has(cache_key):
		var prediction: CollisionPrediction = prediction_cache[cache_key]
		var current_time: float = Time.get_time_dict_from_system()["unix"]
		if current_time - prediction.last_calculated < 1.0:  # Cache valid for 1 second
			return prediction
	
	return null

func clear_cache() -> void:
	prediction_cache.clear()

func get_system_stats() -> Dictionary:
	return {
		"active_predictions": active_predictions.size(),
		"cached_predictions": prediction_cache.size(),
		"safe_corridors": safe_corridors.size(),
		"max_prediction_time": max_prediction_time,
		"acceleration_prediction": acceleration_prediction
	}