class_name MutualSupportAction
extends WCSBTAction

## Mutual support behavior tree action for wing coordination and assistance.
## Provides tactical support to wingmen including covering fire, assistance, and rescue operations.

signal support_initiated(supported_ship: Node3D, support_type: SupportType)
signal support_completed(supported_ship: Node3D, success: bool)
signal rescue_operation_started(ship_in_distress: Node3D)
signal covering_fire_active(protected_ship: Node3D, threats: Array[Node3D])

## Types of mutual support operations
enum SupportType {
	COVERING_FIRE,       ## Provide covering fire for wingman
	THREAT_INTERCEPTION, ## Intercept threats targeting wingman
	DAMAGE_ASSISTANCE,   ## Assist damaged wingman
	AMMUNITION_SHARE,    ## Share ammunition/resources
	ESCORT_PROTECTION,   ## Escort vulnerable wingman
	RESCUE_OPERATION,    ## Rescue wingman in critical danger
	FORMATION_SUPPORT,   ## Help maintain formation integrity
	TARGET_MARKING      ## Mark targets for wingman attack
}

## Support priority levels
enum SupportPriority {
	EMERGENCY,   ## Critical life-threatening situation
	HIGH,        ## Significant threat or damage
	MEDIUM,      ## Standard support request
	LOW,         ## Optional assistance
	ROUTINE      ## Ongoing formation support
}

## Support operation states
enum SupportState {
	IDLE,           ## No active support operations
	ASSESSING,      ## Evaluating support needs
	RESPONDING,     ## Moving to provide support
	ENGAGING,       ## Actively providing support
	COORDINATING,   ## Coordinating with other supporters
	WITHDRAWING,    ## Completing support operation
	EMERGENCY_ABORT ## Emergency abort of support
}

# Support configuration
@export var max_support_range: float = 1500.0
@export var threat_intercept_range: float = 800.0
@export var emergency_response_time: float = 3.0
@export var support_effectiveness_threshold: float = 0.6

# Support monitoring
@export var wingman_health_threshold: float = 0.3
@export var threat_assessment_interval: float = 1.0
@export var support_duration_limit: float = 30.0

# Current support operation
var current_support_type: SupportType = SupportType.COVERING_FIRE
var support_priority: SupportPriority = SupportPriority.MEDIUM
var support_state: SupportState = SupportState.IDLE
var supported_ship: Node3D
var support_target: Node3D
var operation_start_time: float = 0.0

# Support tracking
var active_threats: Array[Node3D] = []
var support_effectiveness: float = 0.0
var support_requests: Array[Dictionary] = []
var emergency_situations: Array[Dictionary] = []

# Wing coordination
var wing_coordination_manager: WingCoordinationManager
var wing_members: Array[Node3D] = []
var support_coordination: Dictionary = {}

# Threat assessment
var threat_assessment_system: ThreatAssessmentSystem
var last_threat_assessment: float = 0.0

func _setup() -> void:
	super._setup()
	_initialize_support_systems()

func _initialize_support_systems() -> void:
	# Get necessary systems
	wing_coordination_manager = get_node("/root/AIManager/WingCoordinationManager") as WingCoordinationManager
	threat_assessment_system = ai_agent.get_node("ThreatAssessmentSystem") as ThreatAssessmentSystem
	
	# Initialize support tracking
	support_requests.clear()
	emergency_situations.clear()
	active_threats.clear()

func execute_wcs_action(delta: float) -> int:
	if not _validate_support_requirements():
		return FAILURE
	
	_update_wingman_status()
	_assess_support_needs(delta)
	
	match support_state:
		SupportState.IDLE:
			return _handle_idle_state(delta)
		SupportState.ASSESSING:
			return _handle_assessment_state(delta)
		SupportState.RESPONDING:
			return _handle_response_state(delta)
		SupportState.ENGAGING:
			return _handle_engagement_state(delta)
		SupportState.COORDINATING:
			return _handle_coordination_state(delta)
		SupportState.WITHDRAWING:
			return _handle_withdrawal_state(delta)
		SupportState.EMERGENCY_ABORT:
			return _handle_emergency_abort_state(delta)
	
	return RUNNING

func _validate_support_requirements() -> bool:
	# Validate that support systems are available
	if not wing_coordination_manager:
		return false
	
	# Get current wing members
	wing_members = _get_wing_members()
	if wing_members.is_empty():
		return false  # No wingmen to support
	
	return true

func _handle_idle_state(delta: float) -> int:
	# Look for support opportunities
	if not emergency_situations.is_empty():
		_transition_to_state(SupportState.ASSESSING)
		return RUNNING
	
	if not support_requests.is_empty():
		_transition_to_state(SupportState.ASSESSING)
		return RUNNING
	
	# Proactive support monitoring
	_monitor_wingman_threats()
	
	return SUCCESS  # Continue monitoring

func _handle_assessment_state(delta: float) -> int:
	# Assess the most critical support need
	var priority_request: Dictionary = _get_highest_priority_support_request()
	
	if priority_request.is_empty():
		_transition_to_state(SupportState.IDLE)
		return RUNNING
	
	# Setup support operation
	current_support_type = priority_request.get("support_type", SupportType.COVERING_FIRE)
	support_priority = priority_request.get("priority", SupportPriority.MEDIUM)
	supported_ship = priority_request.get("ship")
	support_target = priority_request.get("target")
	
	if _can_provide_support(priority_request):
		_transition_to_state(SupportState.RESPONDING)
		support_initiated.emit(supported_ship, current_support_type)
		operation_start_time = Time.get_time_dict_from_system()["unix"]
		return RUNNING
	else:
		# Cannot provide support, remove request
		support_requests.erase(priority_request)
		_transition_to_state(SupportState.IDLE)
		return RUNNING

func _handle_response_state(delta: float) -> int:
	# Move to provide support
	var response_result: int = _execute_support_response()
	
	if response_result == SUCCESS:
		_transition_to_state(SupportState.ENGAGING)
		return RUNNING
	elif response_result == FAILURE:
		_transition_to_state(SupportState.IDLE)
		return FAILURE
	
	return RUNNING

func _handle_engagement_state(delta: float) -> int:
	# Actively provide support
	var engagement_result: int = _execute_support_engagement(delta)
	
	# Check if support is still needed
	if not _is_support_still_needed():
		_transition_to_state(SupportState.WITHDRAWING)
		return RUNNING
	
	# Check for timeout
	var operation_time: float = Time.get_time_dict_from_system()["unix"] - operation_start_time
	if operation_time > support_duration_limit:
		_transition_to_state(SupportState.WITHDRAWING)
		return RUNNING
	
	return engagement_result

func _handle_coordination_state(delta: float) -> int:
	# Coordinate with other supporting ships
	var coordination_result: int = _execute_support_coordination(delta)
	
	if coordination_result == SUCCESS:
		_transition_to_state(SupportState.ENGAGING)
		return RUNNING
	elif coordination_result == FAILURE:
		_transition_to_state(SupportState.WITHDRAWING)
		return FAILURE
	
	return RUNNING

func _handle_withdrawal_state(delta: float) -> int:
	# Complete support operation and withdraw
	var withdrawal_result: int = _execute_support_withdrawal(delta)
	
	if withdrawal_result == SUCCESS:
		support_completed.emit(supported_ship, support_effectiveness > support_effectiveness_threshold)
		_transition_to_state(SupportState.IDLE)
		_reset_support_operation()
		return SUCCESS
	elif withdrawal_result == FAILURE:
		_transition_to_state(SupportState.EMERGENCY_ABORT)
		return RUNNING
	
	return RUNNING

func _handle_emergency_abort_state(delta: float) -> int:
	# Emergency abort of support operation
	_execute_emergency_abort()
	_reset_support_operation()
	_transition_to_state(SupportState.IDLE)
	return FAILURE

func _execute_support_response() -> int:
	# Move to position to provide support
	match current_support_type:
		SupportType.COVERING_FIRE:
			return _respond_for_covering_fire()
		SupportType.THREAT_INTERCEPTION:
			return _respond_for_threat_interception()
		SupportType.DAMAGE_ASSISTANCE:
			return _respond_for_damage_assistance()
		SupportType.ESCORT_PROTECTION:
			return _respond_for_escort_protection()
		SupportType.RESCUE_OPERATION:
			return _respond_for_rescue_operation()
		_:
			return _respond_for_general_support()

func _execute_support_engagement(delta: float) -> int:
	# Execute the support behavior
	match current_support_type:
		SupportType.COVERING_FIRE:
			return _provide_covering_fire(delta)
		SupportType.THREAT_INTERCEPTION:
			return _intercept_threats(delta)
		SupportType.DAMAGE_ASSISTANCE:
			return _assist_damaged_wingman(delta)
		SupportType.ESCORT_PROTECTION:
			return _provide_escort_protection(delta)
		SupportType.RESCUE_OPERATION:
			return _execute_rescue_operation(delta)
		SupportType.FORMATION_SUPPORT:
			return _provide_formation_support(delta)
		SupportType.TARGET_MARKING:
			return _provide_target_marking(delta)
		_:
			return _provide_general_support(delta)

func _provide_covering_fire(delta: float) -> int:
	# Provide covering fire for supported ship
	if not is_instance_valid(supported_ship):
		return FAILURE
	
	# Position between supported ship and threats
	var cover_position: Vector3 = _calculate_covering_fire_position()
	var distance_to_position: float = ai_agent.global_position.distance_to(cover_position)
	
	if distance_to_position > 100.0:
		set_ship_target_position(cover_position)
		return RUNNING
	
	# Engage threats threatening the supported ship
	var primary_threat: Node3D = _get_primary_threat_to_ship(supported_ship)
	if primary_threat:
		_engage_target(primary_threat)
		covering_fire_active.emit(supported_ship, [primary_threat])
		support_effectiveness += delta * 0.5
	
	return RUNNING

func _intercept_threats(delta: float) -> int:
	# Intercept incoming threats to supported ship
	if not is_instance_valid(supported_ship):
		return FAILURE
	
	var incoming_threat: Node3D = _get_most_immediate_threat(supported_ship)
	if not incoming_threat:
		return SUCCESS  # No threats to intercept
	
	# Move to intercept position
	var intercept_position: Vector3 = _calculate_intercept_position(incoming_threat, supported_ship)
	var distance_to_intercept: float = ai_agent.global_position.distance_to(intercept_position)
	
	if distance_to_intercept > 150.0:
		set_ship_target_position(intercept_position)
		return RUNNING
	else:
		# Engage the intercepted threat
		_engage_target(incoming_threat)
		support_effectiveness += delta * 0.7
		return RUNNING

func _assist_damaged_wingman(delta: float) -> int:
	# Assist a damaged wingman
	if not is_instance_valid(supported_ship):
		return FAILURE
	
	var wingman_health: float = _get_ship_health_percentage(supported_ship)
	if wingman_health > wingman_health_threshold:
		return SUCCESS  # Wingman no longer needs assistance
	
	# Provide close escort and target threats attacking the damaged ship
	var escort_position: Vector3 = _calculate_escort_position(supported_ship)
	var distance_to_escort: float = ai_agent.global_position.distance_to(escort_position)
	
	if distance_to_escort > 200.0:
		set_ship_target_position(escort_position)
		return RUNNING
	
	# Attack anything targeting the damaged wingman
	var attacker: Node3D = _get_ship_primary_attacker(supported_ship)
	if attacker:
		_engage_target(attacker)
		support_effectiveness += delta * 0.8
	
	return RUNNING

func _provide_escort_protection(delta: float) -> int:
	# Provide escort protection for vulnerable ship
	if not is_instance_valid(supported_ship):
		return FAILURE
	
	var escort_position: Vector3 = _calculate_dynamic_escort_position(supported_ship)
	var distance_to_position: float = ai_agent.global_position.distance_to(escort_position)
	
	if distance_to_position > 150.0:
		set_ship_target_position(escort_position)
		return RUNNING
	
	# Scan for and engage threats
	var nearest_threat: Node3D = _get_nearest_threat_to_ship(supported_ship, 1000.0)
	if nearest_threat:
		_engage_target(nearest_threat)
		support_effectiveness += delta * 0.6
	
	return RUNNING

func _execute_rescue_operation(delta: float) -> int:
	# Execute rescue operation for ship in critical danger
	if not is_instance_valid(supported_ship):
		return FAILURE
	
	rescue_operation_started.emit(supported_ship)
	
	# Move to defensive position around ship in distress
	var rescue_position: Vector3 = _calculate_rescue_position(supported_ship)
	var distance_to_rescue: float = ai_agent.global_position.distance_to(rescue_position)
	
	if distance_to_rescue > 100.0:
		set_ship_target_position(rescue_position)
		return RUNNING
	
	# Aggressively engage all threats to the ship in distress
	var all_threats: Array[Node3D] = _get_all_threats_to_ship(supported_ship)
	for threat in all_threats:
		if ai_agent.global_position.distance_to(threat.global_position) < threat_intercept_range:
			_engage_target(threat)
			support_effectiveness += delta * 1.0  # High effectiveness for rescue
			break  # Focus on one threat at a time
	
	return RUNNING

func _provide_formation_support(delta: float) -> int:
	# Help maintain formation integrity
	if not wing_coordination_manager:
		return FAILURE
	
	# Check formation status of wing
	var wing_id: String = _get_ship_wing_id()
	if wing_id.is_empty():
		return FAILURE
	
	# Assist ships that are out of formation
	var out_of_formation_ship: Node3D = _find_ship_out_of_formation()
	if out_of_formation_ship:
		# Move to guide ship back to formation
		var guide_position: Vector3 = _calculate_formation_guide_position(out_of_formation_ship)
		set_ship_target_position(guide_position)
		support_effectiveness += delta * 0.4
	
	return RUNNING

func _provide_target_marking(delta: float) -> int:
	# Mark targets for wingman attack
	if not is_instance_valid(supported_ship):
		return FAILURE
	
	# Find priority target for supported ship
	var priority_target: Node3D = _find_priority_target_for_ship(supported_ship)
	if priority_target:
		# "Mark" target by engaging it briefly to draw attention
		_mark_target_for_wingman(priority_target, supported_ship)
		support_effectiveness += delta * 0.3
	
	return RUNNING

func _provide_general_support(delta: float) -> int:
	# General support behavior
	if not is_instance_valid(supported_ship):
		return FAILURE
	
	# Stay near supported ship and engage threats
	var support_position: Vector3 = _calculate_general_support_position(supported_ship)
	var distance_to_position: float = ai_agent.global_position.distance_to(support_position)
	
	if distance_to_position > 200.0:
		set_ship_target_position(support_position)
		return RUNNING
	
	# Engage nearby threats
	var nearby_threat: Node3D = _get_nearest_threat_to_ship(supported_ship, 800.0)
	if nearby_threat:
		_engage_target(nearby_threat)
		support_effectiveness += delta * 0.5
	
	return RUNNING

func _assess_support_needs(delta: float) -> void:
	# Continuously assess support needs of wing members
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	if current_time - last_threat_assessment < threat_assessment_interval:
		return
	
	last_threat_assessment = current_time
	
	# Check each wing member for support needs
	for wingman in wing_members:
		if wingman == ai_agent:
			continue
		
		_assess_wingman_support_needs(wingman)

func _assess_wingman_support_needs(wingman: Node3D) -> void:
	# Assess specific support needs of a wingman
	var health_percentage: float = _get_ship_health_percentage(wingman)
	var threat_count: int = _count_threats_targeting_ship(wingman)
	var distance_from_formation: float = _get_distance_from_formation(wingman)
	
	# Emergency situation assessment
	if health_percentage < 0.2 and threat_count > 0:
		_add_emergency_situation(wingman, SupportType.RESCUE_OPERATION, SupportPriority.EMERGENCY)
	elif health_percentage < wingman_health_threshold:
		_add_support_request(wingman, SupportType.DAMAGE_ASSISTANCE, SupportPriority.HIGH)
	elif threat_count > 2:
		_add_support_request(wingman, SupportType.COVERING_FIRE, SupportPriority.MEDIUM)
	elif distance_from_formation > 500.0:
		_add_support_request(wingman, SupportType.FORMATION_SUPPORT, SupportPriority.LOW)

func _add_support_request(ship: Node3D, support_type: SupportType, priority: SupportPriority) -> void:
	# Add a support request to the queue
	var request: Dictionary = {
		"ship": ship,
		"support_type": support_type,
		"priority": priority,
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"target": _get_primary_threat_to_ship(ship)
	}
	
	# Avoid duplicate requests
	for existing_request in support_requests:
		if existing_request["ship"] == ship and existing_request["support_type"] == support_type:
			return
	
	support_requests.append(request)

func _add_emergency_situation(ship: Node3D, support_type: SupportType, priority: SupportPriority) -> void:
	# Add emergency situation requiring immediate response
	var emergency: Dictionary = {
		"ship": ship,
		"support_type": support_type,
		"priority": priority,
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"target": _get_primary_threat_to_ship(ship)
	}
	
	emergency_situations.append(emergency)

func _get_highest_priority_support_request() -> Dictionary:
	# Get the highest priority support request
	var all_requests: Array[Dictionary] = emergency_situations + support_requests
	
	if all_requests.is_empty():
		return {}
	
	# Sort by priority and timestamp
	all_requests.sort_custom(_compare_support_priority)
	
	return all_requests[0]

func _compare_support_priority(a: Dictionary, b: Dictionary) -> bool:
	# Compare support request priorities
	var priority_a: SupportPriority = a.get("priority", SupportPriority.LOW)
	var priority_b: SupportPriority = b.get("priority", SupportPriority.LOW)
	
	if priority_a != priority_b:
		return priority_a < priority_b  # Lower enum value = higher priority
	
	# Same priority, prefer older requests
	return a.get("timestamp", 0.0) < b.get("timestamp", 0.0)

func _can_provide_support(request: Dictionary) -> bool:
	# Check if we can provide the requested support
	var ship: Node3D = request.get("ship")
	var support_type: SupportType = request.get("support_type", SupportType.COVERING_FIRE)
	
	if not is_instance_valid(ship):
		return false
	
	var distance_to_ship: float = ai_agent.global_position.distance_to(ship.global_position)
	if distance_to_ship > max_support_range:
		return false
	
	# Check if we have the capability for this support type
	match support_type:
		SupportType.AMMUNITION_SHARE:
			return false  # Not implemented yet
		_:
			return true

func _transition_to_state(new_state: SupportState) -> void:
	support_state = new_state

func _reset_support_operation() -> void:
	# Reset support operation variables
	supported_ship = null
	support_target = null
	operation_start_time = 0.0
	support_effectiveness = 0.0
	current_support_type = SupportType.COVERING_FIRE

func _is_support_still_needed() -> bool:
	# Check if support is still needed
	if not is_instance_valid(supported_ship):
		return false
	
	match current_support_type:
		SupportType.DAMAGE_ASSISTANCE:
			return _get_ship_health_percentage(supported_ship) < wingman_health_threshold
		SupportType.RESCUE_OPERATION:
			return _get_ship_health_percentage(supported_ship) < 0.3
		_:
			return _count_threats_targeting_ship(supported_ship) > 0

# Position calculation functions
func _calculate_covering_fire_position() -> Vector3:
	if not is_instance_valid(supported_ship):
		return ai_agent.global_position
	
	var primary_threat: Node3D = _get_primary_threat_to_ship(supported_ship)
	if not primary_threat:
		return supported_ship.global_position + Vector3.RIGHT * 200.0
	
	# Position between supported ship and threat
	var threat_to_ship: Vector3 = supported_ship.global_position - primary_threat.global_position
	var cover_position: Vector3 = supported_ship.global_position - threat_to_ship.normalized() * 300.0
	
	return cover_position

func _calculate_intercept_position(threat: Node3D, protected_ship: Node3D) -> Vector3:
	# Calculate position to intercept incoming threat
	var threat_velocity: Vector3 = Vector3.ZERO  # Placeholder - would get actual velocity
	var intercept_time: float = 2.0  # Estimated intercept time
	var predicted_threat_pos: Vector3 = threat.global_position + threat_velocity * intercept_time
	
	# Position between threat and protected ship
	var intercept_vector: Vector3 = (protected_ship.global_position - predicted_threat_pos).normalized()
	return predicted_threat_pos + intercept_vector * 200.0

func _calculate_escort_position(escorted_ship: Node3D) -> Vector3:
	# Calculate escort position relative to escorted ship
	var ship_forward: Vector3 = escorted_ship.transform.basis.z
	var escort_offset: Vector3 = ship_forward * -150.0 + Vector3.RIGHT * 100.0
	return escorted_ship.global_position + escort_offset

func _calculate_dynamic_escort_position(escorted_ship: Node3D) -> Vector3:
	# Dynamic escort position based on threat locations
	var threats: Array[Node3D] = _get_all_threats_to_ship(escorted_ship)
	if threats.is_empty():
		return _calculate_escort_position(escorted_ship)
	
	# Position between escorted ship and average threat position
	var avg_threat_pos: Vector3 = Vector3.ZERO
	for threat in threats:
		avg_threat_pos += threat.global_position
	avg_threat_pos /= threats.size()
	
	var threat_vector: Vector3 = (escorted_ship.global_position - avg_threat_pos).normalized()
	return escorted_ship.global_position - threat_vector * 250.0

func _calculate_rescue_position(ship_in_distress: Node3D) -> Vector3:
	# Position for rescue operations
	return ship_in_distress.global_position + Vector3.UP * 50.0

func _calculate_formation_guide_position(out_of_formation_ship: Node3D) -> Vector3:
	# Position to guide ship back to formation
	# This would use formation manager to get proper position
	return out_of_formation_ship.global_position + Vector3.FORWARD * 100.0

func _calculate_general_support_position(supported_ship: Node3D) -> Vector3:
	# General support position
	return supported_ship.global_position + Vector3.LEFT * 150.0 + Vector3.BACK * 100.0

# Helper functions for ship status and threats
func _get_wing_members() -> Array[Node3D]:
	# Get current wing members
	if not wing_coordination_manager:
		return []
	
	var wing_id: String = _get_ship_wing_id()
	if wing_id.is_empty():
		return []
	
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	return wing_status.get("members", [])

func _get_ship_wing_id() -> String:
	# Get wing ID for this ship
	if wing_coordination_manager:
		for wing_id in wing_coordination_manager.get_active_wings():
			var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
			var members: Array = wing_status.get("members", [])
			if ai_agent in members:
				return wing_id
	return ""

func _get_ship_health_percentage(ship: Node3D) -> float:
	# Get health percentage of ship
	return 1.0  # Placeholder implementation

func _count_threats_targeting_ship(ship: Node3D) -> int:
	# Count threats currently targeting the ship
	return 0  # Placeholder implementation

func _get_distance_from_formation(ship: Node3D) -> float:
	# Get distance of ship from proper formation position
	return 0.0  # Placeholder implementation

func _get_primary_threat_to_ship(ship: Node3D) -> Node3D:
	# Get the primary threat to a specific ship
	return null  # Placeholder implementation

func _get_most_immediate_threat(ship: Node3D) -> Node3D:
	# Get the most immediate threat to ship
	return null  # Placeholder implementation

func _get_nearest_threat_to_ship(ship: Node3D, max_distance: float) -> Node3D:
	# Get nearest threat within max_distance
	return null  # Placeholder implementation

func _get_all_threats_to_ship(ship: Node3D) -> Array[Node3D]:
	# Get all threats currently targeting ship
	return []  # Placeholder implementation

func _get_ship_primary_attacker(ship: Node3D) -> Node3D:
	# Get the primary attacker of a ship
	return null  # Placeholder implementation

func _find_ship_out_of_formation() -> Node3D:
	# Find a wing member that is out of formation
	return null  # Placeholder implementation

func _find_priority_target_for_ship(ship: Node3D) -> Node3D:
	# Find a priority target for the ship to attack
	return null  # Placeholder implementation

func _engage_target(target: Node3D) -> void:
	# Engage the specified target
	if ship_controller:
		ship_controller.set_target(target)
		ship_controller.fire_primary_weapons()

func _mark_target_for_wingman(target: Node3D, wingman: Node3D) -> void:
	# Mark target for wingman (could use targeting system)
	pass

func _monitor_wingman_threats() -> void:
	# Monitor threats to all wingmen for proactive support
	for wingman in wing_members:
		if wingman == ai_agent:
			continue
		
		var immediate_threats: Array[Node3D] = _get_all_threats_to_ship(wingman)
		if immediate_threats.size() > 1:  # Multiple threats - needs support
			_add_support_request(wingman, SupportType.COVERING_FIRE, SupportPriority.MEDIUM)

func _update_wingman_status() -> void:
	# Update status of all wingmen
	for wingman in wing_members:
		if wingman == ai_agent:
			continue
		
		if not is_instance_valid(wingman):
			wing_members.erase(wingman)

func _execute_support_coordination(delta: float) -> int:
	# Coordinate with other ships providing support
	return SUCCESS  # Placeholder implementation

func _execute_support_withdrawal(delta: float) -> int:
	# Complete support operation
	return SUCCESS  # Placeholder implementation

func _execute_emergency_abort() -> void:
	# Emergency abort of support operation
	pass

# Response functions
func _respond_for_covering_fire() -> int:
	return SUCCESS if ai_agent.global_position.distance_to(supported_ship.global_position) < max_support_range else RUNNING

func _respond_for_threat_interception() -> int:
	return SUCCESS if ai_agent.global_position.distance_to(supported_ship.global_position) < threat_intercept_range else RUNNING

func _respond_for_damage_assistance() -> int:
	return SUCCESS if ai_agent.global_position.distance_to(supported_ship.global_position) < 300.0 else RUNNING

func _respond_for_escort_protection() -> int:
	return SUCCESS if ai_agent.global_position.distance_to(supported_ship.global_position) < 250.0 else RUNNING

func _respond_for_rescue_operation() -> int:
	return SUCCESS if ai_agent.global_position.distance_to(supported_ship.global_position) < 200.0 else RUNNING

func _respond_for_general_support() -> int:
	return SUCCESS if ai_agent.global_position.distance_to(supported_ship.global_position) < max_support_range else RUNNING

## Sets the type of support to provide
func set_support_type(type: SupportType) -> void:
	current_support_type = type

## Sets support parameters
func set_support_parameters(range: float, response_time: float, duration: float) -> void:
	max_support_range = range
	emergency_response_time = response_time
	support_duration_limit = duration

## Gets current support status
func get_support_status() -> Dictionary:
	return {
		"state": SupportState.keys()[support_state],
		"supported_ship": supported_ship,
		"support_type": SupportType.keys()[current_support_type],
		"priority": SupportPriority.keys()[support_priority],
		"effectiveness": support_effectiveness,
		"active_requests": support_requests.size(),
		"emergency_situations": emergency_situations.size()
	}