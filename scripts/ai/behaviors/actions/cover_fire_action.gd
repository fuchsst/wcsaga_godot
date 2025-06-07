class_name CoverFireAction
extends WCSBTAction

## Cover fire behavior tree action for suppressive fire and tactical positioning.
## Provides covering fire to support wingman operations and tactical maneuvers.

signal cover_fire_initiated(protected_target: Node3D, threats: Array[Node3D])
signal cover_fire_completed(protected_target: Node3D, success: bool, threats_suppressed: int)
signal suppression_effective(target: Node3D, suppression_level: float)
signal position_compromised(new_position_required: bool)

## Cover fire modes determining tactical approach
enum CoverFireMode {
	SUPPRESSIVE,          ## Continuous fire to suppress enemy activity
	PROTECTIVE,           ## Focused protection of specific friendly unit
	DIVERSIONARY,         ## Draw enemy attention away from primary operation
	OVERWATCH,            ## Long-range cover from elevated/distant position
	DEFENSIVE_SCREEN,     ## Create defensive barrier of fire
	HARASSMENT,           ## Persistent harassment of enemy positions
	AREA_DENIAL          ## Deny enemy access to specific area
}

## Cover position types
enum CoverPosition {
	FLANKING,     ## Position on enemy flank for crossfire
	OVERWATCH,    ## Elevated or distant observation position
	SCREENING,    ## Between protected unit and threats
	SUPPORT,      ## Close support position
	AMBUSH,       ## Concealed position for surprise fire
	MOBILE        ## Moving cover position
}

## Fire control modes for cover fire
enum FireControl {
	CONTINUOUS,    ## Continuous sustained fire
	BURST,         ## Controlled burst fire
	PRECISION,     ## Aimed precision shots
	SUPPRESSION,   ## High volume suppressive fire
	SELECTIVE,     ## Selective engagement of priority targets
	DISCIPLINED    ## Careful ammunition management
}

# Cover fire configuration
@export var cover_fire_mode: CoverFireMode = CoverFireMode.SUPPRESSIVE
@export var cover_position_type: CoverPosition = CoverPosition.SCREENING
@export var fire_control_mode: FireControl = FireControl.BURST
@export var max_cover_range: float = 1200.0
@export var optimal_cover_distance: float = 800.0

# Fire parameters
@export var suppression_duration: float = 15.0
@export var ammunition_conservation_rate: float = 0.7
@export var position_change_threshold: float = 300.0
@export var threat_engagement_priority: float = 0.8

# Protected unit and threats
var protected_unit: Node3D
var active_threats: Array[Node3D] = []
var primary_threat: Node3D
var cover_start_time: float = 0.0

# Position management
var cover_position: Vector3
var fallback_positions: Array[Vector3] = []
var position_compromised: bool = false
var last_position_update: float = 0.0

# Fire effectiveness tracking
var rounds_fired: int = 0
var threats_suppressed: int = 0
var suppression_effectiveness: float = 0.0
var ammunition_remaining: float = 1.0

# Wing coordination
var wing_coordination_manager: WingCoordinationManager
var coordinated_cover_fire: bool = false
var cover_fire_coordination_id: String = ""

func _setup() -> void:
	super._setup()
	_initialize_cover_fire_systems()

func _initialize_cover_fire_systems() -> void:
	# Get wing coordination manager
	wing_coordination_manager = get_node("/root/AIManager/WingCoordinationManager") as WingCoordinationManager
	
	# Initialize tracking variables
	active_threats.clear()
	fallback_positions.clear()
	_reset_effectiveness_tracking()

func execute_wcs_action(delta: float) -> int:
	if not _validate_cover_fire_requirements():
		return FAILURE
	
	_update_threat_assessment()
	_update_ammunition_status()
	
	# Check if cover fire is still needed
	if not _is_cover_fire_needed():
		cover_fire_completed.emit(protected_unit, true, threats_suppressed)
		return SUCCESS
	
	# Execute cover fire behavior
	var cover_result: int = _execute_cover_fire_behavior(delta)
	_update_effectiveness_tracking(delta)
	
	return cover_result

func _validate_cover_fire_requirements() -> bool:
	# Validate that we can provide cover fire
	if not is_instance_valid(protected_unit):
		protected_unit = _get_protected_unit()
	
	if not protected_unit:
		return false
	
	# Check distance to protected unit
	var distance_to_protected: float = ai_agent.global_position.distance_to(protected_unit.global_position)
	if distance_to_protected > max_cover_range:
		return false
	
	# Check ammunition status
	if ammunition_remaining < 0.1:  # Less than 10% ammo
		return false
	
	return true

func _execute_cover_fire_behavior(delta: float) -> int:
	# Main cover fire execution logic
	var position_result: int = _maintain_cover_position(delta)
	if position_result == FAILURE:
		return FAILURE
	
	var fire_result: int = _execute_fire_mission(delta)
	if fire_result == FAILURE:
		return FAILURE
	
	return RUNNING

func _maintain_cover_position(delta: float) -> int:
	# Maintain optimal cover fire position
	if position_compromised or _should_reposition():
		var new_position: Vector3 = _calculate_optimal_cover_position()
		if not new_position.is_equal_approx(cover_position):
			cover_position = new_position
			position_compromised.emit(true)
			position_compromised = false
	
	# Move to cover position if not there
	var distance_to_position: float = ai_agent.global_position.distance_to(cover_position)
	if distance_to_position > 100.0:
		set_ship_target_position(cover_position)
		return RUNNING
	
	return SUCCESS

func _execute_fire_mission(delta: float) -> int:
	# Execute the cover fire mission
	match cover_fire_mode:
		CoverFireMode.SUPPRESSIVE:
			return _execute_suppressive_fire(delta)
		CoverFireMode.PROTECTIVE:
			return _execute_protective_fire(delta)
		CoverFireMode.DIVERSIONARY:
			return _execute_diversionary_fire(delta)
		CoverFireMode.OVERWATCH:
			return _execute_overwatch_fire(delta)
		CoverFireMode.DEFENSIVE_SCREEN:
			return _execute_defensive_screen_fire(delta)
		CoverFireMode.HARASSMENT:
			return _execute_harassment_fire(delta)
		CoverFireMode.AREA_DENIAL:
			return _execute_area_denial_fire(delta)
	
	return RUNNING

func _execute_suppressive_fire(delta: float) -> int:
	# Continuous suppressive fire on threats
	if active_threats.is_empty():
		return SUCCESS
	
	# Rotate through threats for suppression
	var suppression_target: Node3D = _get_next_suppression_target()
	if not suppression_target:
		return SUCCESS
	
	# Engage with appropriate fire control
	match fire_control_mode:
		FireControl.CONTINUOUS:
			_fire_continuous_at_target(suppression_target, delta)
		FireControl.SUPPRESSION:
			_fire_suppression_pattern_at_target(suppression_target, delta)
		FireControl.BURST:
			_fire_burst_at_target(suppression_target, delta)
		_:
			_fire_standard_at_target(suppression_target, delta)
	
	return RUNNING

func _execute_protective_fire(delta: float) -> int:
	# Focused protection of the protected unit
	var immediate_threat: Node3D = _get_immediate_threat_to_protected()
	if not immediate_threat:
		return SUCCESS
	
	# Prioritize threats by proximity to protected unit
	var threat_distance: float = protected_unit.global_position.distance_to(immediate_threat.global_position)
	var fire_urgency: float = max(0.5, 1.0 - (threat_distance / 600.0))
	
	_fire_with_urgency(immediate_threat, fire_urgency, delta)
	
	return RUNNING

func _execute_diversionary_fire(delta: float) -> int:
	# Draw enemy attention away from protected unit
	if active_threats.is_empty():
		return SUCCESS
	
	# Target multiple threats to draw their attention
	var attention_target: Node3D = _get_highest_priority_attention_target()
	if attention_target:
		# Use flashy weapons or continuous fire to draw attention
		_fire_attention_drawing_pattern(attention_target, delta)
	
	return RUNNING

func _execute_overwatch_fire(delta: float) -> int:
	# Long-range precision overwatch fire
	var overwatch_target: Node3D = _get_best_overwatch_target()
	if not overwatch_target:
		return SUCCESS
	
	# Use precision fire from overwatch position
	match fire_control_mode:
		FireControl.PRECISION:
			_fire_precision_shot(overwatch_target, delta)
		FireControl.SELECTIVE:
			_fire_selective_engagement(overwatch_target, delta)
		_:
			_fire_disciplined_shot(overwatch_target, delta)
	
	return RUNNING

func _execute_defensive_screen_fire(delta: float) -> int:
	# Create defensive screen of fire
	var screen_threats: Array[Node3D] = _get_threats_in_screen_zone()
	if screen_threats.is_empty():
		return SUCCESS
	
	# Engage multiple threats to create defensive barrier
	for threat in screen_threats:
		if _is_within_screen_engagement_range(threat):
			_fire_screen_pattern(threat, delta)
			break  # Focus on one at a time but maintain screen
	
	return RUNNING

func _execute_harassment_fire(delta: float) -> int:
	# Persistent harassment of enemy positions
	var harassment_target: Node3D = _get_harassment_target()
	if not harassment_target:
		return SUCCESS
	
	# Use sporadic, unpredictable fire to harass
	if _should_fire_harassment_round(delta):
		_fire_harassment_shot(harassment_target, delta)
	
	return RUNNING

func _execute_area_denial_fire(delta: float) -> int:
	# Deny enemy access to specific area
	var denial_area: Vector3 = _get_area_denial_focus_point()
	var threats_in_area: Array[Node3D] = _get_threats_in_denial_area(denial_area)
	
	if not threats_in_area.is_empty():
		# Aggressively engage anything in the denied area
		var area_threat: Node3D = threats_in_area[0]
		_fire_area_denial_pattern(area_threat, delta)
	else:
		# Patrol fire in the denied area
		_fire_patrol_shots_in_area(denial_area, delta)
	
	return RUNNING

func _calculate_optimal_cover_position() -> Vector3:
	# Calculate the optimal position for cover fire
	match cover_position_type:
		CoverPosition.FLANKING:
			return _calculate_flanking_position()
		CoverPosition.OVERWATCH:
			return _calculate_overwatch_position()
		CoverPosition.SCREENING:
			return _calculate_screening_position()
		CoverPosition.SUPPORT:
			return _calculate_support_position()
		CoverPosition.AMBUSH:
			return _calculate_ambush_position()
		CoverPosition.MOBILE:
			return _calculate_mobile_position()
	
	return ai_agent.global_position

func _calculate_flanking_position() -> Vector3:
	# Position for flanking fire
	if active_threats.is_empty() or not protected_unit:
		return ai_agent.global_position
	
	var avg_threat_pos: Vector3 = _calculate_average_threat_position()
	var protected_pos: Vector3 = protected_unit.global_position
	
	# Position 90 degrees to the side of the threat-protected line
	var threat_to_protected: Vector3 = (protected_pos - avg_threat_pos).normalized()
	var flank_vector: Vector3 = Vector3(threat_to_protected.z, 0, -threat_to_protected.x)  # Perpendicular
	
	return avg_threat_pos + flank_vector * optimal_cover_distance

func _calculate_overwatch_position() -> Vector3:
	# Elevated or distant overwatch position
	if not protected_unit:
		return ai_agent.global_position
	
	var protected_pos: Vector3 = protected_unit.global_position
	var overwatch_distance: float = optimal_cover_distance * 1.5
	
	# Position behind and above the protected unit
	var overwatch_pos: Vector3 = protected_pos + Vector3.BACK * overwatch_distance + Vector3.UP * 200.0
	
	return overwatch_pos

func _calculate_screening_position() -> Vector3:
	# Position between protected unit and threats
	if active_threats.is_empty() or not protected_unit:
		return ai_agent.global_position
	
	var avg_threat_pos: Vector3 = _calculate_average_threat_position()
	var protected_pos: Vector3 = protected_unit.global_position
	
	# Position between threats and protected unit
	var screen_vector: Vector3 = (avg_threat_pos - protected_pos).normalized()
	var screen_distance: float = optimal_cover_distance * 0.7
	
	return protected_pos + screen_vector * screen_distance

func _calculate_support_position() -> Vector3:
	# Close support position near protected unit
	if not protected_unit:
		return ai_agent.global_position
	
	var protected_pos: Vector3 = protected_unit.global_position
	var support_offset: Vector3 = Vector3.RIGHT * 200.0 + Vector3.BACK * 150.0
	
	return protected_pos + support_offset

func _calculate_ambush_position() -> Vector3:
	# Concealed ambush position
	if active_threats.is_empty():
		return ai_agent.global_position
	
	var avg_threat_pos: Vector3 = _calculate_average_threat_position()
	
	# Position to the side with good concealment
	var ambush_vector: Vector3 = Vector3.RIGHT * optimal_cover_distance
	return avg_threat_pos + ambush_vector

func _calculate_mobile_position() -> Vector3:
	# Dynamic mobile position
	var base_position: Vector3 = _calculate_screening_position()
	
	# Add movement offset based on time
	var time_offset: float = Time.get_time_dict_from_system()["unix"] * 0.1
	var movement_radius: float = 200.0
	var movement_offset: Vector3 = Vector3(
		cos(time_offset) * movement_radius,
		0,
		sin(time_offset) * movement_radius
	)
	
	return base_position + movement_offset

func _calculate_average_threat_position() -> Vector3:
	# Calculate average position of all active threats
	if active_threats.is_empty():
		return ai_agent.global_position
	
	var total_pos: Vector3 = Vector3.ZERO
	for threat in active_threats:
		total_pos += threat.global_position
	
	return total_pos / active_threats.size()

# Fire execution functions
func _fire_continuous_at_target(target: Node3D, delta: float) -> void:
	# Continuous fire at target
	if ship_controller:
		ship_controller.set_target(target)
		ship_controller.fire_primary_weapons()
		rounds_fired += int(delta * 10)  # Estimate rounds per second

func _fire_suppression_pattern_at_target(target: Node3D, delta: float) -> void:
	# High-volume suppression fire pattern
	if ship_controller:
		ship_controller.set_target(target)
		ship_controller.fire_primary_weapons()
		# Could add spread pattern here
		rounds_fired += int(delta * 15)  # Higher rate for suppression

func _fire_burst_at_target(target: Node3D, delta: float) -> void:
	# Controlled burst fire
	var fire_time: float = fmod(Time.get_time_dict_from_system()["unix"], 2.0)
	if fire_time < 0.5:  # Fire for 0.5 seconds every 2 seconds
		if ship_controller:
			ship_controller.set_target(target)
			ship_controller.fire_primary_weapons()
			rounds_fired += int(delta * 8)

func _fire_standard_at_target(target: Node3D, delta: float) -> void:
	# Standard fire at target
	if ship_controller:
		ship_controller.set_target(target)
		ship_controller.fire_primary_weapons()
		rounds_fired += int(delta * 6)

func _fire_with_urgency(target: Node3D, urgency: float, delta: float) -> void:
	# Fire with specified urgency level
	var fire_rate: float = 6.0 + urgency * 10.0  # Scale fire rate with urgency
	if ship_controller:
		ship_controller.set_target(target)
		ship_controller.fire_primary_weapons()
		rounds_fired += int(delta * fire_rate)

func _fire_attention_drawing_pattern(target: Node3D, delta: float) -> void:
	# Fire pattern designed to draw attention
	if ship_controller:
		ship_controller.set_target(target)
		ship_controller.fire_primary_weapons()
		# Could add visual effects or tracers here
		rounds_fired += int(delta * 12)

func _fire_precision_shot(target: Node3D, delta: float) -> void:
	# Precision aimed shot
	var fire_time: float = fmod(Time.get_time_dict_from_system()["unix"], 3.0)
	if fire_time < 0.1:  # Single shot every 3 seconds
		if ship_controller:
			ship_controller.set_target(target)
			ship_controller.fire_primary_weapons()
			rounds_fired += 1

func _fire_selective_engagement(target: Node3D, delta: float) -> void:
	# Selective engagement of priority targets
	if _is_priority_target(target):
		_fire_burst_at_target(target, delta)

func _fire_disciplined_shot(target: Node3D, delta: float) -> void:
	# Disciplined, ammunition-conserving shot
	var fire_time: float = fmod(Time.get_time_dict_from_system()["unix"], 4.0)
	if fire_time < 0.2:  # Short burst every 4 seconds
		if ship_controller:
			ship_controller.set_target(target)
			ship_controller.fire_primary_weapons()
			rounds_fired += 2

func _fire_screen_pattern(target: Node3D, delta: float) -> void:
	# Fire pattern for defensive screen
	_fire_burst_at_target(target, delta)

func _fire_harassment_shot(target: Node3D, delta: float) -> void:
	# Sporadic harassment fire
	if ship_controller:
		ship_controller.set_target(target)
		ship_controller.fire_primary_weapons()
		rounds_fired += 1

func _fire_area_denial_pattern(target: Node3D, delta: float) -> void:
	# Aggressive area denial fire
	_fire_continuous_at_target(target, delta)

func _fire_patrol_shots_in_area(area_center: Vector3, delta: float) -> void:
	# Patrol shots in denied area
	var patrol_time: float = fmod(Time.get_time_dict_from_system()["unix"], 5.0)
	if patrol_time < 0.3:  # Occasional patrol shots
		# Fire at area center
		rounds_fired += 1

# Threat assessment functions
func _update_threat_assessment() -> void:
	# Update assessment of threats
	active_threats.clear()
	
	if not protected_unit:
		return
	
	# Get threats within engagement range
	var potential_threats: Array[Node3D] = _get_threats_near_protected_unit()
	for threat in potential_threats:
		if _is_valid_cover_fire_target(threat):
			active_threats.append(threat)
	
	# Update primary threat
	primary_threat = _get_highest_priority_threat()

func _get_protected_unit() -> Node3D:
	# Get the unit we're protecting (could be assigned or automatic)
	# For now, use blackboard or wing coordination
	return null  # Placeholder implementation

func _get_threats_near_protected_unit() -> Array[Node3D]:
	# Get threats near the protected unit
	return []  # Placeholder implementation

func _is_valid_cover_fire_target(threat: Node3D) -> bool:
	# Check if threat is valid for cover fire engagement
	if not is_instance_valid(threat):
		return false
	
	var distance: float = ai_agent.global_position.distance_to(threat.global_position)
	return distance <= max_cover_range

func _get_highest_priority_threat() -> Node3D:
	# Get the highest priority threat
	if active_threats.is_empty():
		return null
	
	# For now, return closest threat
	var closest_threat: Node3D = active_threats[0]
	var closest_distance: float = ai_agent.global_position.distance_to(closest_threat.global_position)
	
	for threat in active_threats:
		var distance: float = ai_agent.global_position.distance_to(threat.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_threat = threat
	
	return closest_threat

func _get_next_suppression_target() -> Node3D:
	# Get next target for suppression fire rotation
	return primary_threat

func _get_immediate_threat_to_protected() -> Node3D:
	# Get most immediate threat to protected unit
	return primary_threat

func _get_highest_priority_attention_target() -> Node3D:
	# Get target that will draw most attention
	return primary_threat

func _get_best_overwatch_target() -> Node3D:
	# Get best target for overwatch engagement
	return primary_threat

func _get_threats_in_screen_zone() -> Array[Node3D]:
	# Get threats in the defensive screen zone
	return active_threats

func _get_harassment_target() -> Node3D:
	# Get target for harassment fire
	return primary_threat

func _get_area_denial_focus_point() -> Vector3:
	# Get focus point for area denial
	return protected_unit.global_position if protected_unit else ai_agent.global_position

func _get_threats_in_denial_area(area_center: Vector3) -> Array[Node3D]:
	# Get threats in the denied area
	var area_threats: Array[Node3D] = []
	var denial_radius: float = 400.0
	
	for threat in active_threats:
		if threat.global_position.distance_to(area_center) <= denial_radius:
			area_threats.append(threat)
	
	return area_threats

# Condition checking functions
func _is_cover_fire_needed() -> bool:
	# Check if cover fire is still needed
	if not protected_unit:
		return false
	
	if active_threats.is_empty():
		return false
	
	# Check if we've been providing cover for too long
	var cover_duration: float = Time.get_time_dict_from_system()["unix"] - cover_start_time
	if cover_duration > suppression_duration:
		return false
	
	return true

func _should_reposition() -> bool:
	# Check if we should change position
	var time_since_last_move: float = Time.get_time_dict_from_system()["unix"] - last_position_update
	
	# Reposition if we've been in the same spot too long
	if time_since_last_move > 15.0:
		return true
	
	# Reposition if taking too much fire
	if _is_taking_heavy_fire():
		return true
	
	# Reposition if position is no longer optimal
	if not _is_position_still_optimal():
		return true
	
	return false

func _is_taking_heavy_fire() -> bool:
	# Check if we're taking heavy incoming fire
	return false  # Placeholder implementation

func _is_position_still_optimal() -> bool:
	# Check if current position is still optimal
	return true  # Placeholder implementation

func _is_within_screen_engagement_range(threat: Node3D) -> bool:
	# Check if threat is within screen engagement range
	var distance: float = ai_agent.global_position.distance_to(threat.global_position)
	return distance <= optimal_cover_distance

func _should_fire_harassment_round(delta: float) -> bool:
	# Determine if we should fire a harassment round
	var harassment_interval: float = randf_range(2.0, 8.0)
	var time_since_start: float = Time.get_time_dict_from_system()["unix"] - cover_start_time
	return fmod(time_since_start, harassment_interval) < delta

func _is_priority_target(target: Node3D) -> bool:
	# Check if target is high priority
	return target == primary_threat

func _update_ammunition_status() -> void:
	# Update ammunition tracking
	if rounds_fired > 0:
		ammunition_remaining = max(0.0, ammunition_remaining - (rounds_fired * 0.001))

func _update_effectiveness_tracking(delta: float) -> void:
	# Update effectiveness metrics
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	if cover_start_time == 0.0:
		cover_start_time = current_time
	
	# Update suppression effectiveness based on fire activity
	if rounds_fired > 0:
		suppression_effectiveness += delta * 0.1
		suppression_effectiveness = min(1.0, suppression_effectiveness)
	
	# Check for suppressed threats
	for threat in active_threats:
		if _is_threat_suppressed(threat):
			threats_suppressed += 1
			suppression_effective.emit(threat, suppression_effectiveness)

func _is_threat_suppressed(threat: Node3D) -> bool:
	# Check if threat is effectively suppressed
	return false  # Placeholder implementation

func _reset_effectiveness_tracking() -> void:
	# Reset effectiveness tracking variables
	rounds_fired = 0
	threats_suppressed = 0
	suppression_effectiveness = 0.0
	cover_start_time = 0.0

## Sets the protected unit for cover fire
func set_protected_unit(unit: Node3D) -> void:
	protected_unit = unit

## Sets cover fire mode and position type
func set_cover_fire_parameters(mode: CoverFireMode, position: CoverPosition, control: FireControl) -> void:
	cover_fire_mode = mode
	cover_position_type = position
	fire_control_mode = control

## Gets current cover fire status
func get_cover_fire_status() -> Dictionary:
	return {
		"mode": CoverFireMode.keys()[cover_fire_mode],
		"position_type": CoverPosition.keys()[cover_position_type],
		"fire_control": FireControl.keys()[fire_control_mode],
		"protected_unit": protected_unit,
		"active_threats": active_threats.size(),
		"rounds_fired": rounds_fired,
		"threats_suppressed": threats_suppressed,
		"effectiveness": suppression_effectiveness,
		"ammunition_remaining": ammunition_remaining
	}