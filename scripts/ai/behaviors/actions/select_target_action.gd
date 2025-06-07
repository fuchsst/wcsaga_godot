class_name SelectTargetAction
extends WCSBTAction

## Behavior tree action for intelligent target selection
## Uses threat assessment system to choose optimal combat targets

signal target_selected(target: Node3D, threat_score: float)
signal no_target_found()
signal target_selection_failed(reason: String)

enum SelectionMode {
	HIGHEST_THREAT,      # Select target with highest threat score
	NEAREST_THREAT,      # Select closest threatening target
	ROLE_SPECIFIC,       # Select based on ship role and doctrine
	MISSION_PRIORITY,    # Prioritize mission-designated targets
	FORMATION_COORDINATED # Coordinate with formation members
}

# Target selection parameters
@export var selection_mode: SelectionMode = SelectionMode.HIGHEST_THREAT
@export var minimum_threat_level: ThreatAssessmentSystem.TargetPriority = ThreatAssessmentSystem.TargetPriority.LOW
@export var search_radius: float = 3000.0
@export var require_line_of_sight: bool = true
@export var avoid_friendly_fire: bool = true

# Role-specific targeting
@export var preferred_target_types: Array[ThreatAssessmentSystem.ThreatType] = []
@export var excluded_target_types: Array[ThreatAssessmentSystem.ThreatType] = []

# Selection state
var threat_assessment: ThreatAssessmentSystem
var target_coordinator: Node
var last_selection_time: float = 0.0
var selection_cooldown: float = 0.5
var current_doctrine: Node

func _setup() -> void:
	super._setup()
	_initialize_target_selection()

func execute_wcs_action(delta: float) -> int:
	if not _validate_prerequisites():
		return BTTask.FAILURE
	
	# Check selection cooldown
	var current_time: float = Time.get_time_from_start()
	if current_time - last_selection_time < selection_cooldown:
		return BTTask.RUNNING
	
	# Perform target selection
	var selected_target: Node3D = _perform_target_selection()
	
	if selected_target:
		_assign_target_to_agent(selected_target)
		last_selection_time = current_time
		return BTTask.SUCCESS
	else:
		no_target_found.emit()
		return BTTask.FAILURE

func set_selection_parameters(mode: SelectionMode, min_threat: ThreatAssessmentSystem.TargetPriority, radius: float) -> void:
	"""Configure target selection parameters"""
	selection_mode = mode
	minimum_threat_level = min_threat
	search_radius = radius

func set_target_type_preferences(preferred: Array[ThreatAssessmentSystem.ThreatType], excluded: Array[ThreatAssessmentSystem.ThreatType] = []) -> void:
	"""Set preferred and excluded target types"""
	preferred_target_types = preferred.duplicate()
	excluded_target_types = excluded.duplicate()

func force_target_reselection() -> void:
	"""Force immediate target reselection on next execution"""
	last_selection_time = 0.0

# Private implementation

func _initialize_target_selection() -> void:
	"""Initialize target selection system"""
	# Find threat assessment system
	if ai_agent:
		threat_assessment = ai_agent.get_node_or_null("ThreatAssessmentSystem")
		if not threat_assessment:
			# Try to find global threat assessment
			threat_assessment = get_node_or_null("/root/AIManager/ThreatAssessmentSystem")
	
	# Find target coordinator
	target_coordinator = get_node_or_null("/root/AIManager/TargetCoordinator")
	
	# Find tactical doctrine
	current_doctrine = get_node_or_null("/root/AIManager/TacticalDoctrine")

func _validate_prerequisites() -> bool:
	"""Validate that target selection can proceed"""
	if not ai_agent:
		target_selection_failed.emit("No AI agent available")
		return false
	
	if not threat_assessment:
		target_selection_failed.emit("No threat assessment system available")
		return false
	
	if not ship_controller:
		target_selection_failed.emit("No ship controller available")
		return false
	
	return true

func _perform_target_selection() -> Node3D:
	"""Perform target selection based on current mode"""
	var candidates: Array[Dictionary] = _get_target_candidates()
	
	if candidates.is_empty():
		return null
	
	# Apply selection mode
	var selected_target: Node3D = null
	
	match selection_mode:
		SelectionMode.HIGHEST_THREAT:
			selected_target = _select_highest_threat_target(candidates)
		SelectionMode.NEAREST_THREAT:
			selected_target = _select_nearest_threat_target(candidates)
		SelectionMode.ROLE_SPECIFIC:
			selected_target = _select_role_specific_target(candidates)
		SelectionMode.MISSION_PRIORITY:
			selected_target = _select_mission_priority_target(candidates)
		SelectionMode.FORMATION_COORDINATED:
			selected_target = _select_formation_coordinated_target(candidates)
		_:
			selected_target = _select_highest_threat_target(candidates)
	
	# Validate final selection
	if selected_target and _validate_target_selection(selected_target):
		return selected_target
	
	return null

func _get_target_candidates() -> Array[Dictionary]:
	"""Get list of potential target candidates"""
	if not threat_assessment:
		return []
	
	var all_threats: Array[Dictionary] = threat_assessment.get_targets_by_priority(minimum_threat_level)
	var candidates: Array[Dictionary] = []
	
	for threat_data in all_threats:
		var target: Node3D = threat_data.get("target", null)
		if not target or not is_instance_valid(target):
			continue
		
		# Check distance
		var distance: float = ai_agent.global_position.distance_to(target.global_position)
		if distance > search_radius:
			continue
		
		# Check target type preferences
		var threat_type: ThreatAssessmentSystem.ThreatType = threat_data.get("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN)
		if not excluded_target_types.is_empty() and threat_type in excluded_target_types:
			continue
		
		# Check line of sight if required
		if require_line_of_sight and not _has_line_of_sight_to_target(target):
			continue
		
		# Check friendly fire risk
		if avoid_friendly_fire and _has_friendly_fire_risk(target):
			continue
		
		candidates.append(threat_data)
	
	return candidates

func _select_highest_threat_target(candidates: Array[Dictionary]) -> Node3D:
	"""Select target with highest threat score"""
	if candidates.is_empty():
		return null
	
	var best_target: Node3D = null
	var highest_score: float = 0.0
	
	for threat_data in candidates:
		var threat_score: float = threat_data.get("threat_score", 0.0)
		if threat_score > highest_score:
			highest_score = threat_score
			best_target = threat_data.get("target", null)
	
	if best_target:
		target_selected.emit(best_target, highest_score)
	
	return best_target

func _select_nearest_threat_target(candidates: Array[Dictionary]) -> Node3D:
	"""Select nearest threatening target"""
	if candidates.is_empty():
		return null
	
	var best_target: Node3D = null
	var shortest_distance: float = INF
	var best_threat_score: float = 0.0
	
	for threat_data in candidates:
		var target: Node3D = threat_data.get("target", null)
		var distance: float = threat_data.get("distance", INF)
		var threat_score: float = threat_data.get("threat_score", 0.0)
		
		if distance < shortest_distance:
			shortest_distance = distance
			best_target = target
			best_threat_score = threat_score
	
	if best_target:
		target_selected.emit(best_target, best_threat_score)
	
	return best_target

func _select_role_specific_target(candidates: Array[Dictionary]) -> Node3D:
	"""Select target based on ship role and tactical doctrine"""
	if candidates.is_empty():
		return null
	
	# Apply preferred target type filtering
	var preferred_candidates: Array[Dictionary] = []
	
	if not preferred_target_types.is_empty():
		for threat_data in candidates:
			var threat_type: ThreatAssessmentSystem.ThreatType = threat_data.get("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN)
			if threat_type in preferred_target_types:
				preferred_candidates.append(threat_data)
		
		# Use preferred candidates if available, otherwise fall back to all candidates
		if not preferred_candidates.is_empty():
			candidates = preferred_candidates
	
	# Get ship role if available
	var ship_role: String = _get_ship_role()
	
	# Apply role-specific selection logic
	match ship_role:
		"fighter":
			return _select_fighter_role_target(candidates)
		"bomber":
			return _select_bomber_role_target(candidates)
		"interceptor":
			return _select_interceptor_role_target(candidates)
		"escort":
			return _select_escort_role_target(candidates)
		_:
			return _select_highest_threat_target(candidates)

func _select_mission_priority_target(candidates: Array[Dictionary]) -> Node3D:
	"""Select target based on mission priorities"""
	if candidates.is_empty():
		return null
	
	# Look for mission priority targets first
	var priority_candidates: Array[Dictionary] = []
	
	for threat_data in candidates:
		if threat_data.get("is_priority_target", false):
			priority_candidates.append(threat_data)
	
	# Use priority targets if available
	if not priority_candidates.is_empty():
		return _select_highest_threat_target(priority_candidates)
	
	# Fall back to standard selection
	return _select_highest_threat_target(candidates)

func _select_formation_coordinated_target(candidates: Array[Dictionary]) -> Node3D:
	"""Select target with formation coordination"""
	if candidates.is_empty():
		return null
	
	# Check with target coordinator for formation-aware selection
	if target_coordinator and target_coordinator.has_method("get_coordinated_target"):
		var coordinated_target: Node3D = target_coordinator.get_coordinated_target(ai_agent, candidates)
		if coordinated_target:
			var threat_score: float = threat_assessment.get_target_threat_score(coordinated_target)
			target_selected.emit(coordinated_target, threat_score)
			return coordinated_target
	
	# Fall back to highest threat if no coordination available
	return _select_highest_threat_target(candidates)

func _select_fighter_role_target(candidates: Array[Dictionary]) -> Node3D:
	"""Select target appropriate for fighter role"""
	# Fighters prioritize other fighters and bombers
	var fighter_targets: Array[Dictionary] = []
	var bomber_targets: Array[Dictionary] = []
	
	for threat_data in candidates:
		var threat_type: ThreatAssessmentSystem.ThreatType = threat_data.get("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN)
		if threat_type == ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER:
			fighter_targets.append(threat_data)
		elif threat_type == ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER:
			bomber_targets.append(threat_data)
	
	# Prioritize bombers, then fighters, then others
	if not bomber_targets.is_empty():
		return _select_highest_threat_target(bomber_targets)
	elif not fighter_targets.is_empty():
		return _select_highest_threat_target(fighter_targets)
	else:
		return _select_nearest_threat_target(candidates)

func _select_bomber_role_target(candidates: Array[Dictionary]) -> Node3D:
	"""Select target appropriate for bomber role"""
	# Bombers prioritize capital ships and installations
	var capital_targets: Array[Dictionary] = []
	
	for threat_data in candidates:
		var threat_type: ThreatAssessmentSystem.ThreatType = threat_data.get("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN)
		if threat_type in [ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL, ThreatAssessmentSystem.ThreatType.ENEMY_INSTALLATION]:
			capital_targets.append(threat_data)
	
	if not capital_targets.is_empty():
		return _select_highest_threat_target(capital_targets)
	else:
		return _select_highest_threat_target(candidates)

func _select_interceptor_role_target(candidates: Array[Dictionary]) -> Node3D:
	"""Select target appropriate for interceptor role"""
	# Interceptors prioritize fast-moving threats
	var missile_targets: Array[Dictionary] = []
	var fighter_targets: Array[Dictionary] = []
	
	for threat_data in candidates:
		var threat_type: ThreatAssessmentSystem.ThreatType = threat_data.get("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN)
		if threat_type == ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE:
			missile_targets.append(threat_data)
		elif threat_type == ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER:
			fighter_targets.append(threat_data)
	
	# Prioritize missiles, then fighters
	if not missile_targets.is_empty():
		return _select_nearest_threat_target(missile_targets)
	elif not fighter_targets.is_empty():
		return _select_highest_threat_target(fighter_targets)
	else:
		return _select_nearest_threat_target(candidates)

func _select_escort_role_target(candidates: Array[Dictionary]) -> Node3D:
	"""Select target appropriate for escort role"""
	# Escorts prioritize threats to protected assets
	var threatening_targets: Array[Dictionary] = []
	
	for threat_data in candidates:
		var target: Node3D = threat_data.get("target", null)
		if _is_target_threatening_protected_assets(target):
			threatening_targets.append(threat_data)
	
	if not threatening_targets.is_empty():
		return _select_highest_threat_target(threatening_targets)
	else:
		return _select_nearest_threat_target(candidates)

func _assign_target_to_agent(target: Node3D) -> void:
	"""Assign selected target to AI agent"""
	if not ai_agent or not target:
		return
	
	# Set target on AI agent
	if ai_agent.has_method("set_target"):
		ai_agent.set_target(target)
	elif ai_agent.has_method("set_current_target"):
		ai_agent.set_current_target(target)
	
	# Set target on ship controller
	if ship_controller and ship_controller.has_method("set_target"):
		ship_controller.set_target(target)
	
	# Notify blackboard
	var blackboard: AIBlackboard = get_blackboard()
	if blackboard:
		blackboard.set_var("current_target", target)
		blackboard.set_var("target_selection_time", Time.get_time_from_start())
	
	# Get threat score for signal
	var threat_score: float = 0.0
	if threat_assessment:
		threat_score = threat_assessment.get_target_threat_score(target)
	
	target_selected.emit(target, threat_score)

func _validate_target_selection(target: Node3D) -> bool:
	"""Validate that target selection is valid"""
	if not target or not is_instance_valid(target):
		return false
	
	# Check if target is still in range
	var distance: float = ai_agent.global_position.distance_to(target.global_position)
	if distance > search_radius:
		return false
	
	# Check if target is hostile
	if target.has_method("get_team") and ai_agent.has_method("get_team"):
		if target.get_team() == ai_agent.get_team():
			return false  # Don't target friendlies
	
	return true

func _has_line_of_sight_to_target(target: Node3D) -> bool:
	"""Check if AI agent has line of sight to target"""
	if not target or not ai_agent:
		return false
	
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ai_agent.global_position,
		target.global_position
	)
	
	# Exclude self and target from ray cast
	query.exclude = [ai_agent.get_rid(), target.get_rid()]
	
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()  # No obstruction means clear line of sight

func _has_friendly_fire_risk(target: Node3D) -> bool:
	"""Check if targeting this target would risk friendly fire"""
	if not target or not ai_agent:
		return false
	
	# Simple check: see if any friendlies are close to the target
	var nearby_ships: Array = _get_nearby_ships(target.global_position, 200.0)
	
	for ship in nearby_ships:
		if ship != target and ship != ai_agent:
			if ship.has_method("get_team") and ai_agent.has_method("get_team"):
				if ship.get_team() == ai_agent.get_team():
					return true  # Friendly too close to target
	
	return false

func _get_nearby_ships(position: Vector3, radius: float) -> Array:
	"""Get ships near specified position"""
	var nearby_ships: Array = []
	
	# Query physics space for nearby objects
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = position
	
	var results: Array[Dictionary] = space_state.intersect_shape(query)
	
	for result in results:
		var collider: Node = result.get("collider", null)
		if collider and collider.has_method("get_team"):
			nearby_ships.append(collider)
	
	return nearby_ships

func _get_ship_role() -> String:
	"""Get ship role for role-specific targeting"""
	if ai_agent and ai_agent.has_method("get_ship_role"):
		return ai_agent.get_ship_role()
	elif ship_controller and ship_controller.has_method("get_ship_role"):
		return ship_controller.get_ship_role()
	elif ai_agent and ai_agent.has_method("get_ship_class"):
		var ship_class: String = ai_agent.get_ship_class().to_lower()
		if "fighter" in ship_class:
			return "fighter"
		elif "bomber" in ship_class:
			return "bomber"
		elif "interceptor" in ship_class:
			return "interceptor"
		elif "escort" in ship_class:
			return "escort"
	
	return "fighter"  # Default role

func _is_target_threatening_protected_assets(target: Node3D) -> bool:
	"""Check if target is threatening protected assets"""
	if not threat_assessment:
		return false
	
	# This would be implemented based on mission objectives
	# For now, return false as placeholder
	return false

# Configuration methods

func set_selection_cooldown(cooldown_seconds: float) -> void:
	"""Set target selection cooldown"""
	selection_cooldown = max(0.1, cooldown_seconds)

func set_search_radius(radius_meters: float) -> void:
	"""Set target search radius"""
	search_radius = max(100.0, radius_meters)

func enable_line_of_sight_check(enabled: bool) -> void:
	"""Enable/disable line of sight requirement"""
	require_line_of_sight = enabled

func enable_friendly_fire_avoidance(enabled: bool) -> void:
	"""Enable/disable friendly fire avoidance"""
	avoid_friendly_fire = enabled