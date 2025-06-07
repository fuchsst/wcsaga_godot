class_name FollowLeaderAction
extends WCSBTAction

## Formation following action for AI ships
## Maintains position relative to formation leader

@export var formation_offset: Vector3 = Vector3(50.0, 0.0, -50.0)
@export var max_distance_from_leader: float = 200.0
@export var formation_tightness: float = 1.0  # How strictly to maintain formation
@export var catch_up_speed_multiplier: float = 1.5

var target_formation_position: Vector3
var is_catching_up: bool = false

func execute_wcs_action(delta: float) -> int:
	var leader: Node = _get_formation_leader()
	if not leader:
		return 0  # FAILURE - No formation leader
	
	# Check if leader is still valid
	if not is_instance_valid(leader):
		return 0  # FAILURE - Invalid leader
	
	var leader_pos: Vector3 = leader.global_position if leader.has_method("global_position") else Vector3.ZERO
	var leader_forward: Vector3 = _get_leader_forward(leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	var leader_up: Vector3 = Vector3.UP
	
	# Calculate target formation position relative to leader
	_calculate_formation_position(leader_pos, leader_forward, leader_right, leader_up)
	
	var ship_pos: Vector3 = get_ship_position()
	var distance_to_formation_pos: float = ship_pos.distance_to(target_formation_position)
	var distance_to_leader: float = ship_pos.distance_to(leader_pos)
	
	# Check if we're too far from leader (formation broken)
	if distance_to_leader > max_distance_from_leader:
		is_catching_up = true
	elif distance_to_formation_pos < 20.0:  # Close enough to formation position
		is_catching_up = false
	
	# Move to formation position
	_move_to_formation_position()
	
	# Match leader's orientation when in formation
	if distance_to_formation_pos < 50.0:
		_match_leader_orientation(leader_forward)
	
	return 2  # RUNNING - Always continue following

func _get_formation_leader() -> Node:
	if ai_agent and ai_agent.has_method("get_formation_leader"):
		return ai_agent.get_formation_leader()
	return null

func _get_leader_forward(leader: Node) -> Vector3:
	if leader.has_method("get_forward_vector"):
		return leader.get_forward_vector()
	elif leader.has_method("get_global_transform"):
		return -leader.get_global_transform().basis.z
	return Vector3.FORWARD

func _calculate_formation_position(leader_pos: Vector3, leader_forward: Vector3, leader_right: Vector3, leader_up: Vector3) -> void:
	# Create formation position based on leader's coordinate system
	var local_offset: Vector3 = formation_offset
	
	# Add some dynamic variation based on formation tightness and skill
	var skill_factor: float = get_skill_modifier()
	var formation_variance: float = (1.0 - formation_tightness) * (1.0 - skill_factor) * 20.0
	
	# Add small random variation for more natural formation flying
	var time_factor: float = sin(Time.get_time_from_start() * 0.5 + ai_agent.get_instance_id()) * formation_variance
	local_offset.y += time_factor
	
	# Transform local offset to world space
	target_formation_position = leader_pos + (leader_right * local_offset.x) + (leader_up * local_offset.y) + (leader_forward * local_offset.z)

func _move_to_formation_position() -> void:
	set_ship_target_position(target_formation_position)
	
	var distance: float = get_ship_position().distance_to(target_formation_position)
	var speed_factor: float = 1.0
	
	if is_catching_up:
		# Move faster when catching up to formation
		speed_factor = catch_up_speed_multiplier
	else:
		# Adjust speed based on distance to formation position
		speed_factor = clamp(distance / 50.0, 0.3, 1.0)
	
	# Apply skill modifier
	speed_factor *= get_skill_modifier()
	
	if ship_controller and ship_controller.has_method("set_throttle"):
		ship_controller.set_throttle(speed_factor)

func _match_leader_orientation(leader_forward: Vector3) -> void:
	# Gradually align with leader's orientation
	var current_forward: Vector3 = get_ship_forward()
	var target_forward: Vector3 = leader_forward
	
	# Smooth interpolation towards leader's orientation
	var alignment_speed: float = 2.0 * formation_tightness * get_skill_modifier()
	var new_forward: Vector3 = current_forward.lerp(target_forward, alignment_speed * get_process_delta_time())
	
	if ship_controller and ship_controller.has_method("set_target_rotation"):
		# Convert forward vector to rotation
		var target_transform: Transform3D = Transform3D.IDENTITY
		target_transform = target_transform.looking_at(get_ship_position() + new_forward, Vector3.UP)
		ship_controller.set_target_rotation(target_transform.basis.get_euler())

func set_formation_parameters(offset: Vector3, max_dist: float, tightness: float) -> void:
	formation_offset = offset
	max_distance_from_leader = max_dist
	formation_tightness = clamp(tightness, 0.0, 1.0)

func get_formation_status() -> Dictionary:
	var leader: Node = _get_formation_leader()
	if not leader:
		return {"in_formation": false, "distance_to_leader": INF, "distance_to_position": INF}
	
	var distance_to_leader: float = get_ship_position().distance_to(leader.global_position)
	var distance_to_position: float = get_ship_position().distance_to(target_formation_position)
	
	return {
		"in_formation": distance_to_position < 50.0 and distance_to_leader < max_distance_from_leader,
		"distance_to_leader": distance_to_leader,
		"distance_to_position": distance_to_position,
		"is_catching_up": is_catching_up,
		"formation_position": target_formation_position
	}

func is_in_formation() -> bool:
	var status: Dictionary = get_formation_status()
	return status.get("in_formation", false)