@tool
class_name BTFireWeapons
extends BTAction

## Behavior Tree Action: Fire Weapons
## Fires ship weapons if target is within range and angle

@export var target_var: String = "target"
@export var fire_range: float = 1000.0
@export var fire_angle: float = 15.0 # Degrees
@export var burst_duration: float = 1.0
@export var cooldown: float = 0.5

var _burst_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _is_firing: bool = false

func _tick(delta: float) -> Status:
	var ship: ShipEntity = agent as ShipEntity
	if not ship: return FAILURE

	var target = blackboard.get_var(target_var) as Node3D
	if not is_instance_valid(target): return FAILURE

	var to_target = target.global_position - ship.global_position
	var dist = to_target.length()

	if dist > fire_range:
		# Too far
		if _is_firing:
			ship.stop_firing_weapon(0)
			_is_firing = false
		return FAILURE

	# Check angle
	var forward = - ship.global_transform.basis.z
	var angle = rad_to_deg(forward.angle_to(to_target))

	if angle > fire_angle:
		# Not aiming at target
		if _is_firing:
			ship.stop_firing_weapon(0)
			_is_firing = false
		return FAILURE

	# Fire logic (simple burst)
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
		return RUNNING

	if not _is_firing:
		_is_firing = true
		_burst_timer = burst_duration
		ship.fire_weapon(0) # Primary

	_burst_timer -= delta
	if _burst_timer <= 0:
		_is_firing = false
		ship.stop_firing_weapon(0)
		_cooldown_timer = cooldown

	return RUNNING
