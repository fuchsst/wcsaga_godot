class_name DynamicRoleAssignment
extends Node

## Dynamic role assignment system for wing coordination.
## Automatically assigns and reassigns tactical roles based on changing battle conditions.

signal role_assigned(ship: Node3D, role: WingCoordinationManager.WingRole, reason: String)
signal role_changed(ship: Node3D, old_role: WingCoordinationManager.WingRole, new_role: WingCoordinationManager.WingRole, reason: String)
signal role_optimization_completed(wing_id: String, changes_made: int)
signal emergency_role_assignment(ship: Node3D, role: WingCoordinationManager.WingRole, emergency_type: String)

## Role assignment strategies
enum AssignmentStrategy {
	CAPABILITY_BASED,    ## Assign based on ship capabilities
	TACTICAL_SITUATION,  ## Assign based on current tactical needs
	DAMAGE_ADAPTIVE,     ## Adapt to ship damage and performance
	MISSION_OPTIMIZED,   ## Optimize for current mission objectives
	BALANCED,            ## Balance multiple factors
	EMERGENCY_RESPONSE   ## Rapid reassignment for emergencies
}

## Assignment criteria weights
enum AssignmentCriteria {
	SHIP_TYPE,           ## Ship class and capabilities
	WEAPON_LOADOUT,      ## Available weapons and ammunition
	DAMAGE_STATUS,       ## Current damage and system status
	PILOT_SKILL,         ## Pilot skill and experience level
	TACTICAL_POSITION,   ## Current position relative to threats/objectives
	MISSION_REQUIREMENTS ## Current mission needs and priorities
}

## Role suitability factors
class RoleSuitability:
	var ship: Node3D
	var role: WingCoordinationManager.WingRole
	var suitability_score: float = 0.0
	var capability_score: float = 0.0
	var position_score: float = 0.0
	var availability_score: float = 0.0
	var mission_alignment_score: float = 0.0
	var reasons: Array[String] = []
	
	func _init(target_ship: Node3D, target_role: WingCoordinationManager.WingRole) -> void:
		ship = target_ship
		role = target_role

# Assignment configuration
@export var assignment_strategy: AssignmentStrategy = AssignmentStrategy.BALANCED
@export var reassignment_cooldown: float = 10.0  # Minimum time between role changes
@export var emergency_override_threshold: float = 0.3  # Health threshold for emergency reassignment
@export var role_stability_preference: float = 0.8  # Preference for keeping current roles

# Criteria weights for assignment scoring
var criteria_weights: Dictionary = {
	AssignmentCriteria.SHIP_TYPE: 0.25,
	AssignmentCriteria.WEAPON_LOADOUT: 0.20,
	AssignmentCriteria.DAMAGE_STATUS: 0.20,
	AssignmentCriteria.PILOT_SKILL: 0.15,
	AssignmentCriteria.TACTICAL_POSITION: 0.15,
	AssignmentCriteria.MISSION_REQUIREMENTS: 0.05
}

# Role requirements and preferences
var role_requirements: Dictionary = {}
var role_priorities: Dictionary = {}

# Assignment tracking
var last_assignment_time: Dictionary = {}
var assignment_history: Array[Dictionary] = []
var role_performance_tracking: Dictionary = {}

# Dependencies
var wing_coordination_manager: WingCoordinationManager
var threat_assessment_system: ThreatAssessmentSystem

func _ready() -> void:
	_initialize_role_assignment_system()
	_setup_role_requirements()
	_setup_performance_tracking()

func _initialize_role_assignment_system() -> void:
	# Get necessary systems
	wing_coordination_manager = get_node("/root/AIManager/WingCoordinationManager") as WingCoordinationManager
	
	# Initialize tracking dictionaries
	last_assignment_time.clear()
	assignment_history.clear()
	role_performance_tracking.clear()

func _setup_role_requirements() -> void:
	# Define requirements for each role
	role_requirements = {
		WingCoordinationManager.WingRole.LEADER: {
			"min_experience": 0.7,
			"leadership_capability": true,
			"communication_range": 2000.0,
			"tactical_awareness": 0.8
		},
		WingCoordinationManager.WingRole.ATTACK_LEADER: {
			"min_experience": 0.6,
			"heavy_weapons": true,
			"attack_capability": 0.8,
			"survivability": 0.6
		},
		WingCoordinationManager.WingRole.WINGMAN: {
			"min_experience": 0.3,
			"formation_flying": true,
			"responsiveness": 0.7
		},
		WingCoordinationManager.WingRole.SUPPORT: {
			"min_experience": 0.4,
			"defensive_capability": 0.6,
			"communication_range": 1500.0
		},
		WingCoordinationManager.WingRole.SCOUT: {
			"min_experience": 0.5,
			"speed": 1.2,
			"sensor_range": 1800.0,
			"stealth_capability": 0.7
		},
		WingCoordinationManager.WingRole.HEAVY_ATTACK: {
			"min_experience": 0.7,
			"heavy_weapons": true,
			"armor": 1.5,
			"long_range_capability": true
		}
	}

func _setup_performance_tracking() -> void:
	# Initialize performance tracking for role effectiveness
	role_performance_tracking = {
		"role_effectiveness": {},
		"assignment_success_rate": {},
		"role_duration_average": {},
		"emergency_assignments": 0
	}

## Evaluates and assigns optimal roles for all ships in a wing
func evaluate_and_assign_wing_roles(wing_id: String) -> int:
	if not wing_coordination_manager:
		return 0
	
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	if wing_status.is_empty():
		return 0
	
	var wing_members: Array = wing_status.get("members", [])
	if wing_members.is_empty():
		return 0
	
	# Evaluate current situation
	var tactical_situation: Dictionary = _analyze_tactical_situation(wing_members)
	var role_needs: Dictionary = _assess_role_needs(tactical_situation)
	
	# Generate role assignments
	var optimal_assignments: Dictionary = _generate_optimal_assignments(wing_members, role_needs, tactical_situation)
	
	# Apply assignments
	var changes_made: int = _apply_role_assignments(wing_id, optimal_assignments)
	
	role_optimization_completed.emit(wing_id, changes_made)
	return changes_made

## Assigns a specific role to a ship with reasoning
func assign_ship_role(ship: Node3D, new_role: WingCoordinationManager.WingRole, reason: String = "manual_assignment") -> bool:
	if not is_instance_valid(ship) or not wing_coordination_manager:
		return false
	
	# Check cooldown
	if not _can_reassign_ship(ship):
		return false
	
	# Get current role
	var current_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(ship)
	
	# Apply role change
	var success: bool = wing_coordination_manager.change_ship_role(ship, new_role)
	
	if success:
		# Track assignment
		_track_role_assignment(ship, current_role, new_role, reason)
		
		if current_role != new_role:
			role_changed.emit(ship, current_role, new_role, reason)
		else:
			role_assigned.emit(ship, new_role, reason)
	
	return success

## Evaluates role suitability for a specific ship and role combination
func evaluate_role_suitability(ship: Node3D, role: WingCoordinationManager.WingRole, context: Dictionary = {}) -> RoleSuitability:
	var suitability: RoleSuitability = RoleSuitability.new(ship, role)
	
	if not is_instance_valid(ship):
		return suitability
	
	# Evaluate different aspects of suitability
	suitability.capability_score = _evaluate_capability_fit(ship, role)
	suitability.position_score = _evaluate_positional_suitability(ship, role, context)
	suitability.availability_score = _evaluate_availability(ship, role)
	suitability.mission_alignment_score = _evaluate_mission_alignment(ship, role, context)
	
	# Calculate overall suitability score
	suitability.suitability_score = _calculate_overall_suitability(suitability)
	
	# Generate reasons for suitability score
	suitability.reasons = _generate_suitability_reasons(suitability)
	
	return suitability

## Handles emergency role reassignment for critical situations
func handle_emergency_reassignment(ship: Node3D, emergency_type: String) -> bool:
	if not is_instance_valid(ship) or not wing_coordination_manager:
		return false
	
	var emergency_role: WingCoordinationManager.WingRole = _determine_emergency_role(ship, emergency_type)
	var current_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(ship)
	
	if emergency_role == current_role:
		return false  # No change needed
	
	# Override cooldown for emergency
	var success: bool = wing_coordination_manager.change_ship_role(ship, emergency_role)
	
	if success:
		_track_emergency_assignment(ship, current_role, emergency_role, emergency_type)
		emergency_role_assignment.emit(ship, emergency_role, emergency_type)
		role_performance_tracking["emergency_assignments"] += 1
	
	return success

## Gets recommended role for a ship based on current situation
func get_recommended_role(ship: Node3D, context: Dictionary = {}) -> WingCoordinationManager.WingRole:
	if not is_instance_valid(ship):
		return WingCoordinationManager.WingRole.WINGMAN
	
	var best_role: WingCoordinationManager.WingRole = WingCoordinationManager.WingRole.WINGMAN
	var best_score: float = 0.0
	
	# Evaluate all possible roles
	for role_int in range(WingCoordinationManager.WingRole.size()):
		var role: WingCoordinationManager.WingRole = role_int as WingCoordinationManager.WingRole
		var suitability: RoleSuitability = evaluate_role_suitability(ship, role, context)
		
		if suitability.suitability_score > best_score:
			best_score = suitability.suitability_score
			best_role = role
	
	return best_role

## Monitors wing roles and suggests optimizations
func monitor_and_optimize_roles(wing_id: String) -> Array[Dictionary]:
	if not wing_coordination_manager:
		return []
	
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	var wing_members: Array = wing_status.get("members", [])
	var suggestions: Array[Dictionary] = []
	
	# Analyze each ship's role effectiveness
	for ship in wing_members:
		var ship_node: Node3D = ship as Node3D
		var current_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(ship_node)
		var recommended_role: WingCoordinationManager.WingRole = get_recommended_role(ship_node)
		
		if current_role != recommended_role:
			var suitability: RoleSuitability = evaluate_role_suitability(ship_node, recommended_role)
			if suitability.suitability_score > 0.7:  # Only suggest if significantly better
				suggestions.append({
					"ship": ship_node,
					"current_role": current_role,
					"recommended_role": recommended_role,
					"improvement_score": suitability.suitability_score,
					"reasons": suitability.reasons
				})
	
	return suggestions

func _analyze_tactical_situation(wing_members: Array) -> Dictionary:
	# Analyze the current tactical situation
	var situation: Dictionary = {
		"threat_level": 0.5,
		"mission_phase": "combat",
		"formation_integrity": 1.0,
		"casualties": 0,
		"ammunition_status": 1.0,
		"enemy_composition": {},
		"terrain_factors": {},
		"time_pressure": 0.3
	}
	
	# Analyze threats
	var total_threats: int = 0
	var high_priority_threats: int = 0
	
	# Analyze wing status
	var damaged_ships: int = 0
	var low_ammo_ships: int = 0
	
	for ship in wing_members:
		var ship_node: Node3D = ship as Node3D
		if _get_ship_health_percentage(ship_node) < 0.6:
			damaged_ships += 1
		if _get_ship_ammunition_percentage(ship_node) < 0.3:
			low_ammo_ships += 1
	
	situation["casualties"] = damaged_ships
	situation["ammunition_status"] = 1.0 - (low_ammo_ships / float(wing_members.size()))
	
	return situation

func _assess_role_needs(tactical_situation: Dictionary) -> Dictionary:
	# Assess what roles are needed based on tactical situation
	var role_needs: Dictionary = {}
	
	# Base role needs
	role_needs[WingCoordinationManager.WingRole.LEADER] = 1
	role_needs[WingCoordinationManager.WingRole.WINGMAN] = 2
	role_needs[WingCoordinationManager.WingRole.SUPPORT] = 1
	
	# Adjust based on situation
	var threat_level: float = tactical_situation.get("threat_level", 0.5)
	var mission_phase: String = tactical_situation.get("mission_phase", "combat")
	
	if threat_level > 0.7:
		role_needs[WingCoordinationManager.WingRole.ATTACK_LEADER] = role_needs.get(WingCoordinationManager.WingRole.ATTACK_LEADER, 0) + 1
		role_needs[WingCoordinationManager.WingRole.HEAVY_ATTACK] = role_needs.get(WingCoordinationManager.WingRole.HEAVY_ATTACK, 0) + 1
	
	if mission_phase == "reconnaissance":
		role_needs[WingCoordinationManager.WingRole.SCOUT] = role_needs.get(WingCoordinationManager.WingRole.SCOUT, 0) + 2
	
	return role_needs

func _generate_optimal_assignments(wing_members: Array, role_needs: Dictionary, tactical_situation: Dictionary) -> Dictionary:
	# Generate optimal role assignments
	var assignments: Dictionary = {}
	var available_ships: Array[Node3D] = []
	
	# Convert to Node3D array
	for ship in wing_members:
		available_ships.append(ship as Node3D)
	
	# Assign roles in priority order
	var role_priority_order: Array[WingCoordinationManager.WingRole] = [
		WingCoordinationManager.WingRole.LEADER,
		WingCoordinationManager.WingRole.ATTACK_LEADER,
		WingCoordinationManager.WingRole.HEAVY_ATTACK,
		WingCoordinationManager.WingRole.SCOUT,
		WingCoordinationManager.WingRole.SUPPORT,
		WingCoordinationManager.WingRole.WINGMAN
	]
	
	for role in role_priority_order:
		var needed_count: int = role_needs.get(role, 0)
		
		for i in range(needed_count):
			var best_ship: Node3D = _find_best_ship_for_role(available_ships, role, tactical_situation)
			if best_ship:
				assignments[best_ship] = role
				available_ships.erase(best_ship)
	
	# Assign remaining ships as wingmen
	for remaining_ship in available_ships:
		assignments[remaining_ship] = WingCoordinationManager.WingRole.WINGMAN
	
	return assignments

func _find_best_ship_for_role(available_ships: Array[Node3D], role: WingCoordinationManager.WingRole, context: Dictionary) -> Node3D:
	# Find the best ship for a specific role
	var best_ship: Node3D = null
	var best_score: float = 0.0
	
	for ship in available_ships:
		var suitability: RoleSuitability = evaluate_role_suitability(ship, role, context)
		
		# Apply stability preference for current role holders
		var current_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(ship)
		if current_role == role:
			suitability.suitability_score *= (1.0 + role_stability_preference)
		
		if suitability.suitability_score > best_score:
			best_score = suitability.suitability_score
			best_ship = ship
	
	return best_ship

func _apply_role_assignments(wing_id: String, assignments: Dictionary) -> int:
	# Apply the role assignments to ships
	var changes_made: int = 0
	
	for ship in assignments:
		var ship_node: Node3D = ship as Node3D
		var new_role: WingCoordinationManager.WingRole = assignments[ship]
		var current_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(ship_node)
		
		if current_role != new_role and _can_reassign_ship(ship_node):
			if assign_ship_role(ship_node, new_role, "optimization"):
				changes_made += 1
	
	return changes_made

func _evaluate_capability_fit(ship: Node3D, role: WingCoordinationManager.WingRole) -> float:
	# Evaluate how well ship capabilities match role requirements
	var requirements: Dictionary = role_requirements.get(role, {})
	var ship_capabilities: Dictionary = _analyze_ship_capabilities(ship)
	var fit_score: float = 0.0
	var requirement_count: int = 0
	
	for requirement in requirements:
		requirement_count += 1
		var required_value = requirements[requirement]
		var ship_value = ship_capabilities.get(requirement, 0.0)
		
		match typeof(required_value):
			TYPE_FLOAT:
				# Numeric requirement
				if ship_value >= required_value:
					fit_score += 1.0
				else:
					fit_score += ship_value / required_value
			TYPE_BOOL:
				# Boolean requirement
				if ship_value == required_value:
					fit_score += 1.0
			_:
				# String or other type
				if ship_value == required_value:
					fit_score += 1.0
	
	return fit_score / requirement_count if requirement_count > 0 else 0.5

func _evaluate_positional_suitability(ship: Node3D, role: WingCoordinationManager.WingRole, context: Dictionary) -> float:
	# Evaluate positional suitability for role
	var position_score: float = 0.5  # Base score
	
	# Role-specific positional evaluation
	match role:
		WingCoordinationManager.WingRole.LEADER:
			# Leaders should be centrally positioned
			position_score = _evaluate_central_position(ship, context)
		WingCoordinationManager.WingRole.SCOUT:
			# Scouts should be at the front
			position_score = _evaluate_forward_position(ship, context)
		WingCoordinationManager.WingRole.SUPPORT:
			# Support should be at the back
			position_score = _evaluate_rear_position(ship, context)
		WingCoordinationManager.WingRole.HEAVY_ATTACK:
			# Heavy attack should have clear firing lanes
			position_score = _evaluate_firing_position(ship, context)
		_:
			position_score = 0.7  # Neutral score for other roles
	
	return position_score

func _evaluate_availability(ship: Node3D, role: WingCoordinationManager.WingRole) -> float:
	# Evaluate ship availability for role
	var availability: float = 1.0
	
	# Check damage status
	var health: float = _get_ship_health_percentage(ship)
	availability *= health
	
	# Check system status
	var systems_functional: float = _get_ship_systems_status(ship)
	availability *= systems_functional
	
	# Check if already assigned critical role
	var current_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(ship)
	if current_role == WingCoordinationManager.WingRole.LEADER and role != WingCoordinationManager.WingRole.LEADER:
		availability *= 0.5  # Penalty for removing leader
	
	return availability

func _evaluate_mission_alignment(ship: Node3D, role: WingCoordinationManager.WingRole, context: Dictionary) -> float:
	# Evaluate how well role aligns with current mission
	var mission_phase: String = context.get("mission_phase", "combat")
	var alignment: float = 0.5
	
	match mission_phase:
		"reconnaissance":
			if role == WingCoordinationManager.WingRole.SCOUT:
				alignment = 1.0
			elif role == WingCoordinationManager.WingRole.SUPPORT:
				alignment = 0.7
		"assault":
			if role == WingCoordinationManager.WingRole.ATTACK_LEADER or role == WingCoordinationManager.WingRole.HEAVY_ATTACK:
				alignment = 1.0
			elif role == WingCoordinationManager.WingRole.SUPPORT:
				alignment = 0.8
		"defense":
			if role == WingCoordinationManager.WingRole.SUPPORT:
				alignment = 1.0
			elif role == WingCoordinationManager.WingRole.HEAVY_ATTACK:
				alignment = 0.8
		_:
			alignment = 0.7  # Default alignment
	
	return alignment

func _calculate_overall_suitability(suitability: RoleSuitability) -> float:
	# Calculate overall suitability score using weighted factors
	var overall_score: float = 0.0
	
	# Weight the different scores
	overall_score += suitability.capability_score * 0.4
	overall_score += suitability.position_score * 0.2
	overall_score += suitability.availability_score * 0.3
	overall_score += suitability.mission_alignment_score * 0.1
	
	return overall_score

func _generate_suitability_reasons(suitability: RoleSuitability) -> Array[String]:
	# Generate human-readable reasons for suitability score
	var reasons: Array[String] = []
	
	if suitability.capability_score > 0.8:
		reasons.append("Excellent capability match for role")
	elif suitability.capability_score > 0.6:
		reasons.append("Good capability match for role")
	elif suitability.capability_score < 0.4:
		reasons.append("Poor capability match for role")
	
	if suitability.availability_score < 0.5:
		reasons.append("Limited availability due to damage/status")
	
	if suitability.position_score > 0.7:
		reasons.append("Well positioned for role")
	elif suitability.position_score < 0.3:
		reasons.append("Poorly positioned for role")
	
	if suitability.mission_alignment_score > 0.8:
		reasons.append("Role aligns well with current mission")
	
	if reasons.is_empty():
		reasons.append("Standard suitability for role")
	
	return reasons

func _determine_emergency_role(ship: Node3D, emergency_type: String) -> WingCoordinationManager.WingRole:
	# Determine appropriate emergency role based on situation
	match emergency_type:
		"heavy_damage":
			return WingCoordinationManager.WingRole.SUPPORT  # Move to support role
		"leader_lost":
			# Promote most capable ship to leader
			return WingCoordinationManager.WingRole.LEADER
		"overwhelming_threats":
			return WingCoordinationManager.WingRole.HEAVY_ATTACK  # Need more firepower
		"reconnaissance_needed":
			return WingCoordinationManager.WingRole.SCOUT
		_:
			return WingCoordinationManager.WingRole.WINGMAN  # Default safe role

func _can_reassign_ship(ship: Node3D) -> bool:
	# Check if ship can be reassigned (cooldown, etc.)
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	var last_assignment: float = last_assignment_time.get(ship, 0.0)
	
	return current_time - last_assignment >= reassignment_cooldown

func _track_role_assignment(ship: Node3D, old_role: WingCoordinationManager.WingRole, new_role: WingCoordinationManager.WingRole, reason: String) -> void:
	# Track role assignment for analysis
	var assignment_record: Dictionary = {
		"ship": ship,
		"old_role": old_role,
		"new_role": new_role,
		"reason": reason,
		"timestamp": Time.get_time_dict_from_system()["unix"]
	}
	
	assignment_history.append(assignment_record)
	last_assignment_time[ship] = assignment_record["timestamp"]
	
	# Limit history size
	if assignment_history.size() > 100:
		assignment_history.remove_at(0)

func _track_emergency_assignment(ship: Node3D, old_role: WingCoordinationManager.WingRole, new_role: WingCoordinationManager.WingRole, emergency_type: String) -> void:
	# Track emergency assignment
	_track_role_assignment(ship, old_role, new_role, "emergency_" + emergency_type)

# Ship analysis helper functions
func _analyze_ship_capabilities(ship: Node3D) -> Dictionary:
	# Analyze ship capabilities for role assignment
	return {
		"min_experience": 0.6,  # Placeholder
		"heavy_weapons": false,
		"speed": 1.0,
		"armor": 1.0,
		"sensor_range": 1000.0,
		"communication_range": 1500.0,
		"leadership_capability": false,
		"formation_flying": true,
		"stealth_capability": 0.5
	}

func _get_ship_health_percentage(ship: Node3D) -> float:
	# Get ship health as percentage
	return 1.0  # Placeholder

func _get_ship_ammunition_percentage(ship: Node3D) -> float:
	# Get ship ammunition as percentage
	return 1.0  # Placeholder

func _get_ship_systems_status(ship: Node3D) -> float:
	# Get ship systems status
	return 1.0  # Placeholder

# Position evaluation helper functions
func _evaluate_central_position(ship: Node3D, context: Dictionary) -> float:
	# Evaluate if ship is in central position for leadership
	return 0.7  # Placeholder

func _evaluate_forward_position(ship: Node3D, context: Dictionary) -> float:
	# Evaluate if ship is in forward position for scouting
	return 0.7  # Placeholder

func _evaluate_rear_position(ship: Node3D, context: Dictionary) -> float:
	# Evaluate if ship is in rear position for support
	return 0.7  # Placeholder

func _evaluate_firing_position(ship: Node3D, context: Dictionary) -> float:
	# Evaluate if ship has good firing position
	return 0.7  # Placeholder

## Sets assignment strategy
func set_assignment_strategy(strategy: AssignmentStrategy) -> void:
	assignment_strategy = strategy

## Sets criteria weights for assignment scoring
func set_criteria_weights(weights: Dictionary) -> void:
	for criteria in weights:
		if criteria in criteria_weights:
			criteria_weights[criteria] = weights[criteria]

## Gets assignment performance statistics
func get_assignment_statistics() -> Dictionary:
	return {
		"total_assignments": assignment_history.size(),
		"emergency_assignments": role_performance_tracking.get("emergency_assignments", 0),
		"average_assignment_interval": _calculate_average_assignment_interval(),
		"role_distribution": _calculate_role_distribution(),
		"assignment_success_rate": role_performance_tracking.get("assignment_success_rate", {})
	}

func _calculate_average_assignment_interval() -> float:
	# Calculate average time between assignments
	if assignment_history.size() < 2:
		return 0.0
	
	var total_time: float = 0.0
	for i in range(1, assignment_history.size()):
		var prev_time: float = assignment_history[i-1]["timestamp"]
		var curr_time: float = assignment_history[i]["timestamp"]
		total_time += curr_time - prev_time
	
	return total_time / (assignment_history.size() - 1)

func _calculate_role_distribution() -> Dictionary:
	# Calculate current role distribution
	var distribution: Dictionary = {}
	
	for record in assignment_history:
		var role: WingCoordinationManager.WingRole = record["new_role"]
		var role_name: String = WingCoordinationManager.WingRole.keys()[role]
		distribution[role_name] = distribution.get(role_name, 0) + 1
	
	return distribution