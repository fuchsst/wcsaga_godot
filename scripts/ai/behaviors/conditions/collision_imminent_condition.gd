class_name CollisionImminentCondition
extends WCSBTCondition

## Behavior tree condition that detects imminent collision threats
## Triggers emergency responses when collision is unavoidable

@export var critical_time: float = 2.0  # seconds
@export var critical_distance: float = 150.0  # meters
@export var prediction_accuracy: float = 0.8  # minimum confidence for trigger

var collision_detector: WCSCollisionDetector
var last_imminent_threat: Node3D

func _ready() -> void:
	super._ready()
	# Find collision detector in scene
	collision_detector = get_node("/root/AIManager/CollisionDetector") as WCSCollisionDetector
	if not collision_detector:
		collision_detector = ai_agent.get_parent().get_node("CollisionDetector") as WCSCollisionDetector

func execute_wcs_condition() -> bool:
	if not ai_agent or not ai_agent.ship_controller:
		return false
	
	if not collision_detector:
		# Fallback to basic proximity check
		return _check_basic_collision_proximity()
	
	# Get threats from collision detector
	var threats: Array = collision_detector.get_threats_for_ship(ai_agent.ship_controller.get_physics_body())
	
	var imminent_collision: bool = false
	var imminent_threat: Node3D = null
	
	for threat in threats:
		if threat is WCSCollisionDetector.CollisionThreat:
			if _is_collision_imminent(threat):
				imminent_collision = true
				imminent_threat = threat.threat_object
				break
	
	# Update blackboard with threat information
	ai_agent.blackboard.set_value("collision_imminent", imminent_collision)
	if imminent_threat:
		ai_agent.blackboard.set_value("imminent_threat", imminent_threat)
		ai_agent.blackboard.set_value("imminent_threat_distance", 
			ai_agent.ship_controller.get_ship_position().distance_to(imminent_threat.global_position))
		last_imminent_threat = imminent_threat
	elif last_imminent_threat:
		# Clear previous threat if no longer imminent
		ai_agent.blackboard.erase_value("imminent_threat")
		ai_agent.blackboard.erase_value("imminent_threat_distance")
		last_imminent_threat = null
	
	return imminent_collision

func _is_collision_imminent(threat: WCSCollisionDetector.CollisionThreat) -> bool:
	# Check time to collision
	if threat.time_to_collision > 0 and threat.time_to_collision <= critical_time:
		return true
	
	# Check distance
	if threat.closest_distance <= critical_distance:
		return true
	
	# Check threat level (high threat level indicates imminent danger)
	if threat.threat_level > prediction_accuracy:
		return true
	
	return false

func _check_basic_collision_proximity() -> bool:
	var ship_position: Vector3 = ai_agent.ship_controller.get_ship_position()
	var ship_velocity: Vector3 = ai_agent.ship_controller.get_ship_velocity()
	
	if ship_velocity.length() < 1.0:
		return false  # Not moving, no collision risk
	
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	if not space_state:
		return false
	
	# Check for obstacles in immediate path
	var velocity_direction: Vector3 = ship_velocity.normalized()
	var check_distance: float = ship_velocity.length() * critical_time
	var check_end: Vector3 = ship_position + velocity_direction * check_distance
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ship_position, check_end)
	query.collision_mask = 15  # All collision layers
	query.exclude = [ai_agent.ship_controller.get_physics_body()]
	
	var result: Dictionary = space_state.intersect_ray(query)
	if result.has("collider"):
		var obstacle: Node3D = result["collider"] as Node3D
		var distance_to_obstacle: float = ship_position.distance_to(result["position"])
		
		# Calculate time to collision based on current speed
		var time_to_collision: float = distance_to_obstacle / ship_velocity.length()
		
		if time_to_collision <= critical_time:
			ai_agent.blackboard.set_value("imminent_threat", obstacle)
			ai_agent.blackboard.set_value("imminent_threat_distance", distance_to_obstacle)
			return true
	
	return false

func get_imminent_threat() -> Node3D:
	return last_imminent_threat

func get_time_to_collision() -> float:
	if not collision_detector or not last_imminent_threat:
		return -1.0
	
	var threats: Array = collision_detector.get_threats_for_ship(ai_agent.ship_controller.get_physics_body())
	for threat in threats:
		if threat is WCSCollisionDetector.CollisionThreat and threat.threat_object == last_imminent_threat:
			return threat.time_to_collision
	
	return -1.0

func set_critical_parameters(time: float, distance: float, accuracy: float) -> void:
	critical_time = time
	critical_distance = distance
	prediction_accuracy = accuracy