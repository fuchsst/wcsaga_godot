class_name InFormationCondition
extends WCSBTCondition

## Condition that checks if the AI agent is currently in formation

@export var max_distance_from_position: float = 50.0
@export var max_distance_from_leader: float = 200.0
@export var check_orientation_alignment: bool = true
@export var orientation_tolerance: float = 0.8  # Dot product threshold

func evaluate_wcs_condition(delta: float) -> bool:
	# Check if we have a formation leader
	var leader: Node = _get_formation_leader()
	if not leader:
		return false
	
	# Check if leader is still valid
	if not is_instance_valid(leader):
		return false
	
	var ship_pos: Vector3 = get_ship_position()
	var leader_pos: Vector3 = leader.global_position if leader.has_method("global_position") else Vector3.ZERO
	
	# Check distance to leader
	var distance_to_leader: float = ship_pos.distance_to(leader_pos)
	if distance_to_leader > max_distance_from_leader:
		return false
	
	# Get formation position from AI agent or calculate it
	var formation_position: Vector3 = _get_formation_position(leader)
	var distance_to_formation_pos: float = ship_pos.distance_to(formation_position)
	
	# Check if we're close enough to formation position
	if distance_to_formation_pos > max_distance_from_position:
		return false
	
	# Check orientation alignment if required
	if check_orientation_alignment:
		if not _is_orientation_aligned(leader):
			return false
	
	return true

func _get_formation_leader() -> Node:
	if ai_agent and ai_agent.has_method("get_formation_leader"):
		return ai_agent.get_formation_leader()
	return null

func _get_formation_position(leader: Node) -> Vector3:
	# Try to get formation position from AI agent first
	if ai_agent and ai_agent.has_method("get_formation_position"):
		return ai_agent.get_formation_position()
	
	# Fallback: calculate basic formation position
	var leader_pos: Vector3 = leader.global_position if leader.has_method("global_position") else Vector3.ZERO
	var leader_forward: Vector3 = _get_leader_forward(leader)
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	# Get formation offset (default if not available)
	var formation_offset: Vector3 = Vector3(50.0, 0.0, -50.0)
	if ai_agent and ai_agent.has_method("get_formation_offset"):
		formation_offset = ai_agent.get_formation_offset()
	
	# Transform to world space
	return leader_pos + (leader_right * formation_offset.x) + (Vector3.UP * formation_offset.y) + (leader_forward * formation_offset.z)

func _get_leader_forward(leader: Node) -> Vector3:
	if leader.has_method("get_forward_vector"):
		return leader.get_forward_vector()
	elif leader.has_method("get_global_transform"):
		return -leader.get_global_transform().basis.z
	return Vector3.FORWARD

func _is_orientation_aligned(leader: Node) -> bool:
	var ship_forward: Vector3 = get_ship_forward()
	var leader_forward: Vector3 = _get_leader_forward(leader)
	
	var alignment: float = ship_forward.dot(leader_forward)
	return alignment >= orientation_tolerance

func set_formation_tolerances(position_distance: float, leader_distance: float, orientation_tolerance_val: float) -> void:
	max_distance_from_position = position_distance
	max_distance_from_leader = leader_distance
	orientation_tolerance = clamp(orientation_tolerance_val, -1.0, 1.0)

func get_formation_debug_info() -> Dictionary:
	var leader: Node = _get_formation_leader()
	if not leader:
		return {"has_leader": false}
	
	var ship_pos: Vector3 = get_ship_position()
	var leader_pos: Vector3 = leader.global_position if leader.has_method("global_position") else Vector3.ZERO
	var formation_pos: Vector3 = _get_formation_position(leader)
	
	return {
		"has_leader": true,
		"distance_to_leader": ship_pos.distance_to(leader_pos),
		"distance_to_formation_position": ship_pos.distance_to(formation_pos),
		"orientation_aligned": _is_orientation_aligned(leader) if check_orientation_alignment else true,
		"formation_position": formation_pos,
		"leader_position": leader_pos
	}