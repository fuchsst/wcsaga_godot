class_name MaintainFormationAction
extends WCSBTAction

## Behavior tree action that maintains formation position and orientation
## Integrates with FormationManager to coordinate with other formation members

@export var position_tolerance: float = 25.0  # Acceptable distance from formation position
@export var orientation_tolerance: float = 0.9  # Dot product threshold for orientation alignment
@export var formation_speed_factor: float = 1.0  # Speed adjustment when in formation
@export var catch_up_speed_multiplier: float = 1.5  # Speed when catching up to formation
@export var smoothing_factor: float = 0.8  # How smoothly to approach formation position

var formation_manager: FormationManager
var target_formation_position: Vector3
var target_formation_orientation: Vector3
var is_in_position: bool = false
var is_catching_up: bool = false
var formation_id: String = ""

func _ready() -> void:
	super._ready()
	# Find formation manager in scene
	formation_manager = get_node("/root/AIManager/FormationManager") as FormationManager
	if not formation_manager:
		formation_manager = get_tree().get_first_node_in_group("formation_managers") as FormationManager

func execute_wcs_action(delta: float) -> int:
	if not ai_agent or not ai_agent.ship_controller:
		return BTTask.FAILURE
	
	# Check if we have formation assignment
	var ship: Node3D = ai_agent.ship_controller.get_physics_body()
	if not ship:
		return BTTask.FAILURE
	
	if not formation_manager:
		return BTTask.FAILURE
	
	# Get formation information
	formation_id = formation_manager.get_ship_formation_id(ship)
	if formation_id.is_empty():
		return BTTask.FAILURE  # Not in any formation
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	if not formation:
		return BTTask.FAILURE
	
	# Update formation position and orientation targets
	_update_formation_targets(ship)
	
	# Check if we're the formation leader
	if ship == formation.leader:
		return _execute_leader_behavior(delta)
	else:
		return _execute_member_behavior(delta)

func _update_formation_targets(ship: Node3D) -> void:
	## Updates target position and orientation from formation manager
	target_formation_position = formation_manager.get_ship_formation_position(ship)
	target_formation_orientation = formation_manager.get_ship_formation_orientation(ship)

func _execute_leader_behavior(delta: float) -> int:
	## Formation leader behavior - just maintain current course
	var ship_pos: Vector3 = ai_agent.ship_controller.get_ship_position()
	var ship_forward: Vector3 = ai_agent.ship_controller.get_forward_vector()
	
	# Store leader position for debugging
	ai_agent.blackboard.set_value("formation_leader_position", ship_pos)
	ai_agent.blackboard.set_value("formation_leader_forward", ship_forward)
	
	# Formation leaders maintain their current navigation
	return BTTask.SUCCESS

func _execute_member_behavior(delta: float) -> int:
	## Formation member behavior - maintain position relative to leader
	var ship_pos: Vector3 = ai_agent.ship_controller.get_ship_position()
	var ship_forward: Vector3 = ai_agent.ship_controller.get_forward_vector()
	
	# Calculate distances and status
	var distance_to_formation_pos: float = ship_pos.distance_to(target_formation_position)
	var orientation_alignment: float = ship_forward.dot(target_formation_orientation)
	
	# Update formation status
	is_in_position = distance_to_formation_pos <= position_tolerance
	var is_oriented: bool = orientation_alignment >= orientation_tolerance
	
	# Determine if we need to catch up
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	var distance_to_leader: float = ship_pos.distance_to(formation.leader.global_position)
	var max_formation_distance: float = formation.formation_spacing * 3.0
	
	if distance_to_leader > max_formation_distance:
		is_catching_up = true
	elif is_in_position:
		is_catching_up = false
	
	# Execute formation maneuver
	_execute_formation_movement(delta, distance_to_formation_pos, is_oriented)
	
	# Update blackboard with formation status
	_update_formation_blackboard(distance_to_formation_pos, orientation_alignment, is_oriented)
	
	# Return status based on formation compliance
	if is_in_position and is_oriented:
		return BTTask.SUCCESS
	else:
		return BTTask.RUNNING

func _execute_formation_movement(delta: float, distance_to_position: float, is_oriented: bool) -> void:
	## Executes movement to maintain formation position
	
	# Calculate movement approach
	if distance_to_position > position_tolerance * 3.0:
		# Far from position - direct approach
		_move_direct_to_formation_position()
	else:
		# Close to position - smooth approach
		_move_smooth_to_formation_position(delta)
	
	# Handle orientation alignment
	if not is_oriented:
		_align_formation_orientation(delta)
	
	# Adjust speed based on formation status
	_adjust_formation_speed()

func _move_direct_to_formation_position() -> void:
	## Direct movement to formation position when far away
	set_ship_target_position(target_formation_position)

func _move_smooth_to_formation_position(delta: float) -> void:
	## Smooth approach to formation position when nearby
	var ship_pos: Vector3 = ai_agent.ship_controller.get_ship_position()
	var smooth_target: Vector3 = ship_pos.lerp(target_formation_position, smoothing_factor * delta)
	set_ship_target_position(smooth_target)

func _align_formation_orientation(delta: float) -> void:
	## Gradually align with formation orientation
	var ship_forward: Vector3 = ai_agent.ship_controller.get_forward_vector()
	var alignment_speed: float = 2.0 * delta
	
	# Apply skill level modifier
	var skill_modifier: float = get_skill_modifier()
	alignment_speed *= skill_modifier
	
	# Smooth orientation interpolation
	var new_forward: Vector3 = ship_forward.slerp(target_formation_orientation, alignment_speed)
	
	# Convert to rotation and apply
	if ai_agent.ship_controller.has_method("set_target_rotation"):
		var target_transform: Transform3D = Transform3D.IDENTITY
		target_transform = target_transform.looking_at(ai_agent.ship_controller.get_ship_position() + new_forward, Vector3.UP)
		ai_agent.ship_controller.set_target_rotation(target_transform.basis.get_euler())

func _adjust_formation_speed() -> void:
	## Adjusts ship speed based on formation status
	var speed_factor: float = formation_speed_factor
	
	if is_catching_up:
		speed_factor = catch_up_speed_multiplier
	elif is_in_position:
		# Reduce speed when in position to avoid overshooting
		speed_factor = formation_speed_factor * 0.8
	else:
		# Normal formation speed
		speed_factor = formation_speed_factor
	
	# Apply skill modifier
	speed_factor *= get_skill_modifier()
	
	# Set throttle
	if ai_agent.ship_controller.has_method("set_throttle"):
		ai_agent.ship_controller.set_throttle(speed_factor)

func _update_formation_blackboard(distance_to_position: float, orientation_alignment: float, is_oriented: bool) -> void:
	## Updates AI blackboard with formation status information
	ai_agent.blackboard.set_value("formation_id", formation_id)
	ai_agent.blackboard.set_value("formation_distance_to_position", distance_to_position)
	ai_agent.blackboard.set_value("formation_orientation_alignment", orientation_alignment)
	ai_agent.blackboard.set_value("formation_in_position", is_in_position)
	ai_agent.blackboard.set_value("formation_oriented", is_oriented)
	ai_agent.blackboard.set_value("formation_catching_up", is_catching_up)
	ai_agent.blackboard.set_value("formation_target_position", target_formation_position)
	ai_agent.blackboard.set_value("formation_target_orientation", target_formation_orientation)

func get_formation_status() -> Dictionary:
	## Returns detailed formation status for debugging and monitoring
	return {
		"formation_id": formation_id,
		"in_position": is_in_position,
		"catching_up": is_catching_up,
		"distance_to_position": ai_agent.ship_controller.get_ship_position().distance_to(target_formation_position),
		"target_position": target_formation_position,
		"target_orientation": target_formation_orientation,
		"position_tolerance": position_tolerance,
		"orientation_tolerance": orientation_tolerance
	}

func set_formation_parameters(pos_tolerance: float, orient_tolerance: float, speed_factor: float) -> void:
	## Configures formation behavior parameters
	position_tolerance = pos_tolerance
	orientation_tolerance = clamp(orient_tolerance, -1.0, 1.0)
	formation_speed_factor = clamp(speed_factor, 0.1, 2.0)

func is_formation_compliant() -> bool:
	## Returns true if ship is maintaining formation correctly
	return is_in_position and target_formation_orientation.dot(ai_agent.ship_controller.get_forward_vector()) >= orientation_tolerance

func handle_formation_disruption() -> void:
	## Handles recovery from formation disruption
	is_catching_up = true
	is_in_position = false
	
	# Signal formation disruption
	if ai_agent.has_signal("formation_disrupted"):
		ai_agent.emit_signal("formation_disrupted", formation_id)

func get_formation_priority() -> float:
	## Returns the priority of maintaining formation (0.0 = low, 1.0 = high)
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id) if formation_manager else null
	if not formation:
		return 0.0
	
	# Higher priority when formation integrity is threatened
	var integrity: float = formation.get_formation_integrity()
	var priority: float = 1.0 - integrity
	
	# Increase priority if we're far from position
	var distance_factor: float = ai_agent.ship_controller.get_ship_position().distance_to(target_formation_position) / (position_tolerance * 4.0)
	priority = max(priority, clamp(distance_factor, 0.0, 1.0))
	
	return priority