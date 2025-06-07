class_name MoveToAction
extends WCSBTAction

## Basic movement action for AI ships
## Moves the ship to a specified target position

@export var target_position: Vector3
@export var approach_distance: float = 50.0
@export var max_speed_factor: float = 1.0

var blackboard_position_key: String = "target_position"

func execute_wcs_action(delta: float) -> int:
	# Get target position from blackboard if not set directly
	var target: Vector3 = target_position
	if target == Vector3.ZERO and blackboard:
		target = blackboard.get_var(blackboard_position_key, Vector3.ZERO)
	
	if target == Vector3.ZERO:
		return 0  # FAILURE
	
	var ship_pos: Vector3 = get_ship_position()
	var distance: float = ship_pos.distance_to(target)
	
	# Check if we've reached the target
	if distance <= approach_distance:
		return 1  # SUCCESS
	
	# Calculate movement direction
	var direction: Vector3 = (target - ship_pos).normalized()
	
	# Set ship movement target
	set_ship_target_position(target)
	
	# Adjust speed based on distance and skill
	var speed_factor: float = max_speed_factor * get_skill_modifier()
	
	# Slow down as we approach the target
	if distance < approach_distance * 3.0:
		speed_factor *= (distance / (approach_distance * 3.0))
		speed_factor = max(speed_factor, 0.2)  # Minimum speed
	
	# Apply movement (this would interface with the ship's movement system)
	if ship_controller and ship_controller.has_method("set_throttle"):
		ship_controller.set_throttle(speed_factor)
	
	return 2  # RUNNING

func set_target_from_blackboard(key: String) -> void:
	blackboard_position_key = key

func set_target_position_direct(pos: Vector3) -> void:
	target_position = pos

func get_distance_to_target() -> float:
	var target: Vector3 = target_position
	if target == Vector3.ZERO and blackboard:
		target = blackboard.get_var(blackboard_position_key, Vector3.ZERO)
	
	return get_ship_position().distance_to(target)