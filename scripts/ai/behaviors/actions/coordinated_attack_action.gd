class_name CoordinatedAttackAction
extends WCSBTAction

## Coordinated attack behavior tree action for multi-ship tactical attacks.
## Synchronizes attacks with other wing members for maximum effectiveness.

signal coordinated_attack_started(target: Node3D, attack_type: AttackType)
signal coordinated_attack_completed(target: Node3D, success: bool, damage_dealt: float)
signal waiting_for_coordination(target: Node3D, time_remaining: float)
signal attack_phase_changed(old_phase: AttackPhase, new_phase: AttackPhase)

## Attack coordination types
enum AttackType {
	SIMULTANEOUS,     ## All ships attack at the same time
	SEQUENTIAL,       ## Ships attack one after another
	PINCER,          ## Split attack from multiple angles
	COVERING_ADVANCE, ## Some ships cover while others advance
	ALPHA_STRIKE,    ## Concentrated firepower on single target
	DISTRACTION      ## Some ships distract while others flank
}

## Attack execution phases
enum AttackPhase {
	COORDINATION,    ## Coordinating with other ships
	POSITIONING,     ## Moving to attack positions
	WAITING,         ## Waiting for coordination signal
	ATTACKING,       ## Executing attack run
	SUPPORTING,      ## Providing support fire
	WITHDRAWING,     ## Tactical withdrawal after attack
	COMPLETED        ## Attack sequence finished
}

## Coordination states for multi-ship attacks
enum CoordinationState {
	REQUESTING,      ## Requesting coordination with wing
	ACKNOWLEDGED,    ## Coordination request acknowledged
	SYNCHRONIZED,    ## All ships ready for coordinated attack
	EXECUTING,       ## Attack in progress
	FAILED,          ## Coordination failed
	ABORTED         ## Attack aborted due to conditions
}

# Attack configuration
@export var attack_type: AttackType = AttackType.SIMULTANEOUS
@export var coordination_timeout: float = 10.0
@export var max_coordination_distance: float = 2000.0
@export var attack_effectiveness_threshold: float = 0.7

# Coordination parameters
@export var synchronization_window: float = 2.0
@export var position_tolerance: float = 100.0
@export var timing_precision: float = 0.5

# Attack phases and timing
var current_phase: AttackPhase = AttackPhase.COORDINATION
var coordination_state: CoordinationState = CoordinationState.REQUESTING
var coordination_start_time: float = 0.0
var attack_start_time: float = 0.0
var coordination_id: String = ""

# Wing coordination
var wing_coordination_manager: WingCoordinationManager
var coordinating_ships: Array[Node3D] = []
var attack_assignments: Dictionary = {}
var coordination_responses: Dictionary = {}

# Attack tracking
var target_node: Node3D
var attack_position: Vector3
var attack_vector: Vector3
var expected_attack_time: float = 0.0
var actual_damage_dealt: float = 0.0

func _setup() -> void:
	super._setup()
	_initialize_coordination_system()

func _initialize_coordination_system() -> void:
	# Get wing coordination manager
	wing_coordination_manager = get_node("/root/AIManager/WingCoordinationManager") as WingCoordinationManager
	if not wing_coordination_manager:
		push_warning("WingCoordinationManager not found for coordinated attack")
		return
	
	# Connect to coordination signals
	if not wing_coordination_manager.tactical_command_issued.is_connected(_on_tactical_command_issued):
		wing_coordination_manager.tactical_command_issued.connect(_on_tactical_command_issued)

func execute_wcs_action(delta: float) -> int:
	if not _validate_coordination_requirements():
		return FAILURE
	
	match current_phase:
		AttackPhase.COORDINATION:
			return _handle_coordination_phase(delta)
		AttackPhase.POSITIONING:
			return _handle_positioning_phase(delta)
		AttackPhase.WAITING:
			return _handle_waiting_phase(delta)
		AttackPhase.ATTACKING:
			return _handle_attacking_phase(delta)
		AttackPhase.SUPPORTING:
			return _handle_supporting_phase(delta)
		AttackPhase.WITHDRAWING:
			return _handle_withdrawal_phase(delta)
		AttackPhase.COMPLETED:
			return SUCCESS
	
	return RUNNING

func _validate_coordination_requirements() -> bool:
	# Validate basic requirements for coordinated attack
	if not is_instance_valid(target_node):
		target_node = get_current_target()
	
	if not target_node:
		return false
	
	if not wing_coordination_manager:
		return false
	
	# Check if we have wingmen available for coordination
	var wing_id: String = _get_ship_wing_id()
	if wing_id.is_empty():
		return false
	
	return true

func _handle_coordination_phase(delta: float) -> int:
	match coordination_state:
		CoordinationState.REQUESTING:
			return _request_attack_coordination()
		CoordinationState.ACKNOWLEDGED:
			return _wait_for_coordination_synchronization(delta)
		CoordinationState.SYNCHRONIZED:
			_transition_to_phase(AttackPhase.POSITIONING)
			return RUNNING
		CoordinationState.FAILED, CoordinationState.ABORTED:
			return FAILURE
	
	return RUNNING

func _handle_positioning_phase(delta: float) -> int:
	# Move to designated attack position
	var target_pos: Vector3 = _calculate_attack_position()
	var ship_pos: Vector3 = ai_agent.global_position
	var distance_to_position: float = ship_pos.distance_to(target_pos)
	
	if distance_to_position > position_tolerance:
		set_ship_target_position(target_pos)
		return RUNNING
	else:
		_transition_to_phase(AttackPhase.WAITING)
		return RUNNING

func _handle_waiting_phase(delta: float) -> int:
	# Wait for coordination signal or timeout
	var wait_time: float = Time.get_time_dict_from_system()["unix"] - coordination_start_time
	
	if wait_time > coordination_timeout:
		coordination_state = CoordinationState.FAILED
		return FAILURE
	
	# Check if all ships are ready
	if _are_all_ships_ready():
		_transition_to_phase(AttackPhase.ATTACKING)
		expected_attack_time = Time.get_time_dict_from_system()["unix"]
		return RUNNING
	
	waiting_for_coordination.emit(target_node, coordination_timeout - wait_time)
	return RUNNING

func _handle_attacking_phase(delta: float) -> int:
	# Execute the coordinated attack
	if not _is_attack_position_valid():
		_transition_to_phase(AttackPhase.POSITIONING)
		return RUNNING
	
	# Execute attack based on type and role
	var attack_result: int = _execute_coordinated_attack_behavior(delta)
	
	if attack_result == SUCCESS:
		_transition_to_phase(AttackPhase.WITHDRAWING)
		return RUNNING
	elif attack_result == FAILURE:
		return FAILURE
	
	return RUNNING

func _handle_supporting_phase(delta: float) -> int:
	# Provide supporting fire while other ships attack
	var supporting_result: int = _execute_support_behavior(delta)
	
	# Check if primary attack is complete
	if _is_primary_attack_complete():
		_transition_to_phase(AttackPhase.WITHDRAWING)
		return RUNNING
	
	return supporting_result

func _handle_withdrawal_phase(delta: float) -> int:
	# Execute tactical withdrawal
	var withdrawal_result: int = _execute_withdrawal_behavior(delta)
	
	if withdrawal_result == SUCCESS:
		_transition_to_phase(AttackPhase.COMPLETED)
		coordinated_attack_completed.emit(target_node, true, actual_damage_dealt)
		return SUCCESS
	elif withdrawal_result == FAILURE:
		return FAILURE
	
	return RUNNING

func _request_attack_coordination() -> int:
	# Request coordination with wing for attack
	var wing_id: String = _get_ship_wing_id()
	if wing_id.is_empty():
		return FAILURE
	
	coordination_id = "coord_attack_" + str(randi())
	coordination_start_time = Time.get_time_dict_from_system()["unix"]
	
	# Create coordination request
	var coord_params: Dictionary = {
		"attack_type": AttackType.keys()[attack_type],
		"target": target_node,
		"requesting_ship": ai_agent,
		"coordination_id": coordination_id,
		"max_participants": 4,
		"timeout": coordination_timeout
	}
	
	var success: bool = wing_coordination_manager.issue_tactical_command(
		wing_id, 
		WingCoordinationManager.TacticalCommand.ATTACK_TARGET, 
		target_node, 
		coord_params
	)
	
	if success:
		coordination_state = CoordinationState.ACKNOWLEDGED
		coordinated_attack_started.emit(target_node, attack_type)
		return RUNNING
	else:
		coordination_state = CoordinationState.FAILED
		return FAILURE

func _wait_for_coordination_synchronization(delta: float) -> bool:
	# Wait for other ships to acknowledge coordination
	var elapsed_time: float = Time.get_time_dict_from_system()["unix"] - coordination_start_time
	
	if elapsed_time > coordination_timeout:
		coordination_state = CoordinationState.FAILED
		return false
	
	# Check coordination responses
	var required_ships: int = _get_required_coordination_count()
	var responding_ships: int = coordination_responses.size()
	
	if responding_ships >= required_ships:
		coordination_state = CoordinationState.SYNCHRONIZED
		return true
	
	return false

func _calculate_attack_position() -> Vector3:
	# Calculate optimal attack position based on attack type and role
	var target_pos: Vector3 = target_node.global_position
	var attack_role: String = attack_assignments.get(ai_agent, "primary")
	
	match attack_type:
		AttackType.SIMULTANEOUS:
			return _calculate_simultaneous_attack_position(target_pos, attack_role)
		AttackType.PINCER:
			return _calculate_pincer_attack_position(target_pos, attack_role)
		AttackType.COVERING_ADVANCE:
			return _calculate_covering_advance_position(target_pos, attack_role)
		AttackType.ALPHA_STRIKE:
			return _calculate_alpha_strike_position(target_pos, attack_role)
		_:
			return _calculate_standard_attack_position(target_pos)

func _calculate_simultaneous_attack_position(target_pos: Vector3, role: String) -> Vector3:
	# Position for simultaneous attack
	var attack_distance: float = 800.0
	var ship_index: int = coordinating_ships.find(ai_agent)
	var total_ships: int = coordinating_ships.size()
	
	if total_ships <= 1:
		return target_pos + Vector3.FORWARD * attack_distance
	
	# Spread ships in arc around target
	var arc_angle: float = PI / 2  # 90 degree arc
	var start_angle: float = -arc_angle / 2
	var angle_per_ship: float = arc_angle / (total_ships - 1) if total_ships > 1 else 0.0
	var ship_angle: float = start_angle + (angle_per_ship * ship_index)
	
	var offset: Vector3 = Vector3(
		cos(ship_angle) * attack_distance,
		0,
		sin(ship_angle) * attack_distance
	)
	
	return target_pos + offset

func _calculate_pincer_attack_position(target_pos: Vector3, role: String) -> Vector3:
	# Position for pincer attack
	var attack_distance: float = 1000.0
	var lateral_offset: float = 600.0
	
	if role == "left_flank":
		return target_pos + Vector3(-lateral_offset, 0, attack_distance)
	elif role == "right_flank":
		return target_pos + Vector3(lateral_offset, 0, attack_distance)
	else:
		return target_pos + Vector3(0, 0, attack_distance)

func _calculate_covering_advance_position(target_pos: Vector3, role: String) -> Vector3:
	# Position for covering advance attack
	if role == "covering":
		return ai_agent.global_position  # Stay in current position for cover
	else:
		return target_pos + Vector3.FORWARD * 500.0  # Advance position

func _calculate_alpha_strike_position(target_pos: Vector3, role: String) -> Vector3:
	# Position for concentrated alpha strike
	var base_position: Vector3 = target_pos + Vector3.FORWARD * 600.0
	var ship_index: int = coordinating_ships.find(ai_agent)
	
	# Tight formation for maximum firepower concentration
	var formation_offset: Vector3 = Vector3(
		(ship_index - coordinating_ships.size() / 2) * 80.0,
		0,
		0
	)
	
	return base_position + formation_offset

func _calculate_standard_attack_position(target_pos: Vector3) -> Vector3:
	# Standard attack position
	return target_pos + Vector3.FORWARD * 700.0

func _execute_coordinated_attack_behavior(delta: float) -> int:
	# Execute the actual attack behavior
	match attack_type:
		AttackType.SIMULTANEOUS:
			return _execute_simultaneous_attack(delta)
		AttackType.SEQUENTIAL:
			return _execute_sequential_attack(delta)
		AttackType.PINCER:
			return _execute_pincer_attack_behavior(delta)
		AttackType.COVERING_ADVANCE:
			return _execute_covering_advance_attack(delta)
		AttackType.ALPHA_STRIKE:
			return _execute_alpha_strike(delta)
		_:
			return _execute_standard_attack(delta)

func _execute_simultaneous_attack(delta: float) -> int:
	# All ships attack at the same time
	if _is_within_timing_window():
		_fire_weapons_at_target()
		actual_damage_dealt += _calculate_damage_contribution()
		return SUCCESS
	
	return RUNNING

func _execute_sequential_attack(delta: float) -> int:
	# Ships attack in sequence
	var attack_order: int = coordinating_ships.find(ai_agent)
	var time_since_attack_start: float = Time.get_time_dict_from_system()["unix"] - expected_attack_time
	var my_attack_time: float = attack_order * 1.5  # 1.5 second intervals
	
	if time_since_attack_start >= my_attack_time:
		_fire_weapons_at_target()
		actual_damage_dealt += _calculate_damage_contribution()
		return SUCCESS
	
	return RUNNING

func _execute_pincer_attack_behavior(delta: float) -> int:
	# Execute pincer attack from assigned flank
	var role: String = attack_assignments.get(ai_agent, "primary")
	var target_vector: Vector3 = (target_node.global_position - ai_agent.global_position).normalized()
	
	# Check if we're in position for flank attack
	if _is_in_flank_position(role):
		_fire_weapons_at_target()
		actual_damage_dealt += _calculate_damage_contribution()
		return SUCCESS
	
	return RUNNING

func _execute_covering_advance_attack(delta: float) -> int:
	# Execute covering advance behavior
	var role: String = attack_assignments.get(ai_agent, "advance")
	
	if role == "covering":
		# Provide covering fire
		_fire_weapons_at_target()
		return RUNNING  # Continue providing cover
	else:
		# Advance and attack
		if _is_in_attack_range():
			_fire_weapons_at_target()
			actual_damage_dealt += _calculate_damage_contribution()
			return SUCCESS
	
	return RUNNING

func _execute_alpha_strike(delta: float) -> int:
	# Execute concentrated firepower attack
	if _are_all_ships_in_position() and _is_within_timing_window():
		_fire_all_weapons_at_target()
		actual_damage_dealt += _calculate_damage_contribution() * 1.5  # Bonus for concentration
		return SUCCESS
	
	return RUNNING

func _execute_standard_attack(delta: float) -> int:
	# Standard coordinated attack
	if _is_in_attack_range():
		_fire_weapons_at_target()
		actual_damage_dealt += _calculate_damage_contribution()
		return SUCCESS
	
	return RUNNING

func _execute_support_behavior(delta: float) -> int:
	# Provide supporting fire for other ships
	if _is_in_weapon_range(target_node):
		_fire_weapons_at_target()
		return RUNNING
	else:
		# Move to support position
		var support_position: Vector3 = _calculate_support_position()
		set_ship_target_position(support_position)
		return RUNNING

func _execute_withdrawal_behavior(delta: float) -> int:
	# Execute coordinated withdrawal
	var withdrawal_position: Vector3 = _calculate_withdrawal_position()
	var distance_to_withdrawal: float = ai_agent.global_position.distance_to(withdrawal_position)
	
	if distance_to_withdrawal < 200.0:
		return SUCCESS
	
	set_ship_target_position(withdrawal_position)
	return RUNNING

func _calculate_support_position() -> Vector3:
	# Calculate optimal support position
	var target_pos: Vector3 = target_node.global_position
	return target_pos + Vector3.BACK * 900.0 + Vector3.RIGHT * 300.0

func _calculate_withdrawal_position() -> Vector3:
	# Calculate withdrawal position
	var target_pos: Vector3 = target_node.global_position
	var withdrawal_vector: Vector3 = (ai_agent.global_position - target_pos).normalized()
	return ai_agent.global_position + withdrawal_vector * 1500.0

func _transition_to_phase(new_phase: AttackPhase) -> void:
	var old_phase: AttackPhase = current_phase
	current_phase = new_phase
	attack_phase_changed.emit(old_phase, new_phase)

func _are_all_ships_ready() -> bool:
	# Check if all coordinating ships are ready
	for ship in coordinating_ships:
		if not _is_ship_ready_for_attack(ship):
			return false
	return true

func _are_all_ships_in_position() -> bool:
	# Check if all ships are in their assigned positions
	for ship in coordinating_ships:
		if not _is_ship_in_position(ship):
			return false
	return true

func _is_ship_ready_for_attack(ship: Node3D) -> bool:
	# Check if a ship is ready for coordinated attack
	return coordination_responses.has(ship)

func _is_ship_in_position(ship: Node3D) -> bool:
	# Check if ship is in correct position for attack
	return true  # Placeholder implementation

func _is_attack_position_valid() -> bool:
	# Validate current attack position
	var target_pos: Vector3 = target_node.global_position
	var ship_pos: Vector3 = ai_agent.global_position
	var distance: float = ship_pos.distance_to(target_pos)
	return distance < 1200.0 and distance > 300.0

func _is_within_timing_window() -> bool:
	# Check if we're within the coordination timing window
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	var time_diff: float = abs(current_time - expected_attack_time)
	return time_diff <= timing_precision

func _is_primary_attack_complete() -> bool:
	# Check if the primary attack phase is complete
	return Time.get_time_dict_from_system()["unix"] - expected_attack_time > 5.0

func _is_in_flank_position(role: String) -> bool:
	# Check if ship is in correct flank position
	var target_pos: Vector3 = target_node.global_position
	var ship_pos: Vector3 = ai_agent.global_position
	var relative_pos: Vector3 = ship_pos - target_pos
	
	match role:
		"left_flank":
			return relative_pos.x < -200.0
		"right_flank":
			return relative_pos.x > 200.0
		_:
			return true

func _is_in_attack_range() -> bool:
	# Check if ship is in optimal attack range
	var distance: float = ai_agent.global_position.distance_to(target_node.global_position)
	return distance >= 300.0 and distance <= 800.0

func _fire_weapons_at_target() -> void:
	# Fire weapons at the coordinated target
	if ship_controller:
		ship_controller.fire_primary_weapons()

func _fire_all_weapons_at_target() -> void:
	# Fire all available weapons for alpha strike
	if ship_controller:
		ship_controller.fire_primary_weapons()
		ship_controller.fire_secondary_weapons()

func _calculate_damage_contribution() -> float:
	# Calculate expected damage contribution from this ship
	return randf_range(10.0, 25.0)  # Placeholder damage calculation

func _get_ship_wing_id() -> String:
	# Get the wing ID for this ship
	if wing_coordination_manager:
		for wing_id in wing_coordination_manager.get_active_wings():
			var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
			var members: Array = wing_status.get("members", [])
			if ai_agent in members:
				return wing_id
	return ""

func _get_required_coordination_count() -> int:
	# Get number of ships required for this attack type
	match attack_type:
		AttackType.PINCER:
			return 2
		AttackType.ALPHA_STRIKE:
			return 3
		_:
			return 2

func _on_tactical_command_issued(wing_id: String, command: String, ships: Array[Node3D]) -> void:
	# Handle tactical command from wing coordination manager
	if ai_agent in ships and command == "ATTACK_TARGET":
		# Join the coordination
		coordinating_ships = ships
		coordination_responses[ai_agent] = true

## Sets the attack type for coordinated attack
func set_attack_type(type: AttackType) -> void:
	attack_type = type

## Sets coordination parameters
func set_coordination_parameters(timeout: float, distance: float, window: float) -> void:
	coordination_timeout = timeout
	max_coordination_distance = distance
	synchronization_window = window

## Gets current attack status
func get_attack_status() -> Dictionary:
	return {
		"phase": AttackPhase.keys()[current_phase],
		"coordination_state": CoordinationState.keys()[coordination_state],
		"target": target_node,
		"coordinating_ships": coordinating_ships.size(),
		"damage_dealt": actual_damage_dealt,
		"coordination_id": coordination_id
	}