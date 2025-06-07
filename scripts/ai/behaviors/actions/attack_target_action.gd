class_name AttackTargetAction
extends WCSBTAction

## Combat action for AI ships to attack their current target
## Handles weapon selection, firing timing, and attack positioning

@export var weapon_range: float = 1000.0
@export var optimal_attack_distance: float = 500.0
@export var min_firing_angle: float = 0.9  # Dot product threshold for firing
@export var strafe_behavior: bool = true
@export var weapon_group: int = 0  # Which weapon group to fire

var attack_position: Vector3
var last_fire_time: float = 0.0
var fire_cooldown: float = 0.5

func execute_wcs_action(delta: float) -> int:
	var target: Node = get_current_target()
	if not target:
		return 0  # FAILURE - No target
	
	# Check if target is still alive and valid
	if target.has_method("is_alive") and not target.is_alive():
		return 0  # FAILURE - Target is dead
	
	var ship_pos: Vector3 = get_ship_position()
	var target_pos: Vector3 = target.global_position if target.has_method("global_position") else Vector3.ZERO
	var distance: float = ship_pos.distance_to(target_pos)
	
	# If target is too far, fail the attack action
	if distance > weapon_range * 1.5:
		return 0  # FAILURE - Target out of range
	
	# Calculate optimal attack position
	_calculate_attack_position(target, target_pos)
	
	# Move to attack position
	_move_to_attack_position()
	
	# Check if we can fire weapons
	if _can_fire_weapons(target, distance):
		_fire_weapons()
	
	# Continue attacking as long as target is valid
	return 2  # RUNNING

func _calculate_attack_position(target: Node, target_pos: Vector3) -> void:
	var ship_pos: Vector3 = get_ship_position()
	var target_velocity: Vector3 = Vector3.ZERO
	
	# Get target velocity for prediction
	if target.has_method("get_velocity"):
		target_velocity = target.get_velocity()
	
	# Calculate intercept position with basic prediction
	var time_to_target: float = ship_pos.distance_to(target_pos) / 100.0  # Assume projectile speed of 100
	var predicted_pos: Vector3 = target_pos + (target_velocity * time_to_target)
	
	# Calculate attack direction
	var to_target: Vector3 = (predicted_pos - ship_pos).normalized()
	
	if strafe_behavior:
		# Add some lateral movement for strafing attacks
		var strafe_direction: Vector3 = to_target.cross(Vector3.UP).normalized()
		var strafe_factor: float = sin(Time.get_time_from_start() * 2.0) * 0.3
		attack_position = predicted_pos - (to_target * optimal_attack_distance) + (strafe_direction * strafe_factor * 200.0)
	else:
		# Direct attack approach
		attack_position = predicted_pos - (to_target * optimal_attack_distance)

func _move_to_attack_position() -> void:
	set_ship_target_position(attack_position)
	
	# Adjust throttle based on distance to attack position
	var distance_to_attack_pos: float = get_ship_position().distance_to(attack_position)
	var throttle: float = clamp(distance_to_attack_pos / 100.0, 0.2, 1.0) * get_skill_modifier()
	
	if ship_controller and ship_controller.has_method("set_throttle"):
		ship_controller.set_throttle(throttle)

func _can_fire_weapons(target: Node, distance: float) -> bool:
	# Check weapon range
	if distance > weapon_range:
		return false
	
	# Check firing angle
	if not is_facing_target(target, 1.0 - min_firing_angle):
		return false
	
	# Check firing cooldown
	if Time.get_time_from_start() - last_fire_time < fire_cooldown:
		return false
	
	# Check if we have line of sight
	if not has_line_of_sight(target):
		return false
	
	return true

func _fire_weapons() -> void:
	if ship_controller and ship_controller.has_method("fire_weapons"):
		ship_controller.fire_weapons(weapon_group)
		last_fire_time = Time.get_time_from_start()
		
		# Adjust fire rate based on skill level
		fire_cooldown = 0.5 / max(get_skill_modifier(), 0.2)

func set_weapon_parameters(range: float, optimal_dist: float, firing_angle: float) -> void:
	weapon_range = range
	optimal_attack_distance = optimal_dist
	min_firing_angle = firing_angle

func get_distance_to_target() -> float:
	var target: Node = get_current_target()
	if not target:
		return INF
	return distance_to_target(target)

func is_in_firing_position() -> bool:
	var target: Node = get_current_target()
	if not target:
		return false
	
	var distance: float = distance_to_target(target)
	return distance <= weapon_range and is_facing_target(target, 1.0 - min_firing_angle)