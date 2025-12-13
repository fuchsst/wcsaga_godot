# BTStealthPursuit - Hunt Stealth Ships
# Implements SM_STEALTH_FIND and SM_STEALTH_SWEEP submodes
# Based on legacy aicode.cpp stealth detection

@tool
extends BTAction

## Search mode variants
enum SearchMode {
	FIND, ## Target known but cloaked - search near last position
	SWEEP ## Lost target - sweep general area
}

@export var search_mode: SearchMode = SearchMode.FIND

## Search parameters
@export var search_radius: float = 500.0 ## Radius to search
@export var sweep_time: float = 15.0 ## Duration of sweep pattern
@export var last_pos_expire_time: float = 10.0 ## How long to use last known pos

## State tracking
var _last_known_pos: Vector3 = Vector3.ZERO
var _last_known_vel: Vector3 = Vector3.ZERO
var _time_since_visible: float = 0.0
var _sweep_angle: float = 0.0
var _search_point: Vector3 = Vector3.ZERO


func _generate_name() -> String:
	var mode_names = ["Find", "Sweep"]
	return "StealthPursuit (%s)" % mode_names[search_mode]


func _enter() -> void:
	_time_since_visible = 0.0
	_sweep_angle = 0.0
	_search_point = Vector3.ZERO


func _tick(delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	var target = blackboard.get_var("target")

	if not ship or not is_instance_valid(ship):
		return FAILURE

	_time_since_visible += delta

	# Check if target became visible
	if target and is_instance_valid(target):
		if _is_target_visible(ship, target):
			# Target found! Update last known and return success
			_last_known_pos = target.global_position
			_last_known_vel = target.velocity if "velocity" in target else Vector3.ZERO
			_time_since_visible = 0.0
			return SUCCESS

	# No visible target - execute search behavior
	match search_mode:
		SearchMode.FIND:
			_do_find_search(ship, delta)
		SearchMode.SWEEP:
			_do_sweep_search(ship, delta)

	# Check if should give up
	if _time_since_visible > sweep_time:
		blackboard.set_var("target", null)
		return FAILURE

	return RUNNING


func _is_target_visible(ship: Node, target: Node) -> bool:
	"""Check if stealth ship is visible"""
	# Stealth ships become visible when:
	# - Within close range
	# - Firing weapons
	# - Damaged recently
	# - AWACS in range

	var dist = ship.global_position.distance_to(target.global_position)

	# Very close range always reveals
	if dist < 100.0:
		return true

	# Check if target is firing (reveals position)
	if "is_firing" in target and target.is_firing:
		return true

	# Check if recently damaged
	if "last_hit_time" in target:
		var time_since_hit = Time.get_ticks_msec() / 1000.0 - target.last_hit_time
		if time_since_hit < 2.0:
			return true

	return false


func _do_find_search(ship: Node, delta: float) -> void:
	"""Search near predicted position"""
	# Predict where target moved to
	var predicted_pos = _last_known_pos + _last_known_vel * _time_since_visible

	# Add search offset that spirals outward
	var search_offset_dist = min(_time_since_visible * 30.0, search_radius)
	_sweep_angle += delta * 2.0

	var offset = Vector3(
		cos(_sweep_angle) * search_offset_dist,
		sin(_sweep_angle * 0.5) * search_offset_dist * 0.3,
		sin(_sweep_angle) * search_offset_dist
	)

	_search_point = predicted_pos + offset

	# Navigate to search point
	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(_search_point)
	blackboard.set_var("desired_position", _search_point)


func _do_sweep_search(ship: Node, delta: float) -> void:
	"""General area sweep pattern"""
	var ship_pos = ship.global_position

	# Box sweep pattern
	_sweep_angle += delta * 0.5

	var sweep_dist = search_radius
	var box_x = cos(_sweep_angle) * sweep_dist
	var box_z = sin(_sweep_angle * 1.5) * sweep_dist
	var box_y = sin(_sweep_angle * 0.3) * sweep_dist * 0.5

	if _last_known_pos == Vector3.ZERO:
		_search_point = ship_pos + Vector3(box_x, box_y, box_z)
	else:
		_search_point = _last_known_pos + Vector3(box_x, box_y, box_z)

	if ship.has_method("set_ai_target_position"):
		ship.set_ai_target_position(_search_point)
	blackboard.set_var("desired_position", _search_point)


## Update tracking when target was visible
func update_last_known(pos: Vector3, vel: Vector3 = Vector3.ZERO) -> void:
	"""Called when target position is known"""
	_last_known_pos = pos
	_last_known_vel = vel
	_time_since_visible = 0.0
