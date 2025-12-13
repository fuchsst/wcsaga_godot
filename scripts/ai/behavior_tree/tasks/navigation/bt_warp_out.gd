# BTWarpOut - Warp Departure Sequence
# Initiates warp out: finds legal direction, accelerates, engages warp
# Implements AIM_WARP_OUT from legacy aicode.cpp

@tool
extends BTAction

## Minimum distance from obstacles before warping
@export var safe_distance: float = 500.0

## Time to accelerate before warp
@export var warp_charge_time: float = 3.0

## Speed required for warp
@export var warp_speed: float = 200.0

var _warp_direction: Vector3 = Vector3.ZERO
var _charge_timer: float = 0.0
var _stage: int = 0 # 0=find dir, 1=align, 2=accelerate, 3=warp


func _generate_name() -> String:
	return "WarpOut"


func _enter() -> void:
	_warp_direction = Vector3.ZERO
	_charge_timer = 0.0
	_stage = 0


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	if not ship or not is_instance_valid(ship):
		return FAILURE

	match _stage:
		0: # Find safe warp direction
			_warp_direction = _find_warp_direction(ship)
			_stage = 1
			return RUNNING

		1: # Align to warp direction
			if _align_to_direction(ship):
				_stage = 2
			return RUNNING

		2: # Accelerate to warp speed
			_charge_timer += delta
			blackboard.set_var("use_afterburner", true)
			blackboard.set_var("desired_thrust", 1.0)

			var speed = ship.velocity.length() if "velocity" in ship else 0.0
			if speed >= warp_speed and _charge_timer >= warp_charge_time:
				_stage = 3

			return RUNNING

		3: # Initiate warp
			if ship.has_method("start_warp_out"):
				ship.start_warp_out()
			blackboard.set_var("warping_out", true)
			return SUCCESS

	return RUNNING


func _find_warp_direction(ship: Node) -> Vector3:
	"""Find a safe direction to warp (away from obstacles)"""
	var ship_pos: Vector3 = ship.global_position

	# Default: current forward direction
	var best_dir = - ship.global_transform.basis.z

	# Check for nearby obstacles
	var obstacles: Array = []
	if ship.has_method("get_nearby_obstacles"):
		obstacles = ship.get_nearby_obstacles(safe_distance * 2)

	for obs in obstacles:
		if not is_instance_valid(obs):
			continue
		var obs_pos = obs.global_position if "global_position" in obs else Vector3.ZERO
		var to_obs = obs_pos - ship_pos
		var dist = to_obs.length()

		if dist < safe_distance:
			# Bias direction away from obstacle
			best_dir -= to_obs.normalized() * (safe_distance / maxf(dist, 1.0))

	return best_dir.normalized()


func _align_to_direction(ship: Node) -> bool:
	"""Rotate ship to face warp direction"""
	var current_fwd = - ship.global_transform.basis.z
	var dot = current_fwd.dot(_warp_direction)

	# Set target position far in warp direction
	var warp_target = ship.global_position + _warp_direction * 10000.0
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(warp_target)
	else:
		blackboard.set_var("desired_position", warp_target)

	# Check if aligned (within 15 degrees)
	return dot > 0.966
