class_name TargetCoordinator
extends Node

## Formation-aware target coordination system
## Prevents target overlap and coordinates target assignments across formations

signal target_assigned(ship: Node3D, target: Node3D, assignment_type: String)
signal target_unassigned(ship: Node3D, target: Node3D, reason: String)
signal coordination_conflict_resolved(ship: Node3D, old_target: Node3D, new_target: Node3D)
signal formation_targeting_updated(formation_id: String, targets: Array[Node3D])

enum AssignmentType {
	PRIMARY,      # Primary target for ship
	SECONDARY,    # Secondary/fallback target
	OPPORTUNITY,  # Opportunistic target
	SUPPORT,      # Supporting another ship's attack
	COORDINATED   # Formation-coordinated assignment
}

enum CoordinationMode {
	DISABLED,     # No coordination
	BASIC,        # Basic overlap prevention
	OPTIMIZED,    # Optimal target distribution
	HIERARCHICAL, # Leader-based coordination
	ADAPTIVE      # Adaptive coordination based on situation
}

# Coordination parameters
@export var coordination_mode: CoordinationMode = CoordinationMode.OPTIMIZED
@export var max_attackers_per_target: int = 2
@export var target_assignment_timeout: float = 10.0
@export var coordination_update_frequency: float = 0.5

# Target distribution settings
@export var threat_distribution_weight: float = 0.6
@export var distance_distribution_weight: float = 0.3
@export var capability_distribution_weight: float = 0.1

# System references
var formation_manager: Node
var threat_assessment: ThreatAssessmentSystem
var tactical_doctrine: TacticalDoctrine

# Coordination state
var target_assignments: Dictionary = {}  # ship_id -> assignment_data
var target_attackers: Dictionary = {}    # target_id -> Array[ship_data]
var formation_coordinators: Dictionary = {} # formation_id -> coordinator_data
var pending_assignments: Array[Dictionary] = []

# Performance tracking
var last_coordination_update: float = 0.0
var coordination_frame_budget: float = 3.0  # milliseconds per frame

func _ready() -> void:
	_initialize_target_coordination()
	set_process(true)

func _process(delta: float) -> void:
	var current_time: float = Time.get_time_from_start()
	if current_time - last_coordination_update >= coordination_update_frequency:
		_update_target_coordination(delta)
		last_coordination_update = current_time

# Public interface

func initialize_with_systems(formation_mgr: Node, threat_assess: ThreatAssessmentSystem, doctrine: TacticalDoctrine) -> void:
	"""Initialize coordinator with required systems"""
	formation_manager = formation_mgr
	threat_assessment = threat_assess
	tactical_doctrine = doctrine
	
	# Connect to formation manager signals
	if formation_manager:
		if formation_manager.has_signal("formation_created"):
			formation_manager.formation_created.connect(_on_formation_created)
		if formation_manager.has_signal("formation_disbanded"):
			formation_manager.formation_disbanded.connect(_on_formation_disbanded)
		if formation_manager.has_signal("ship_added_to_formation"):
			formation_manager.ship_added_to_formation.connect(_on_ship_added_to_formation)
		if formation_manager.has_signal("ship_removed_from_formation"):
			formation_manager.ship_removed_from_formation.connect(_on_ship_removed_from_formation)

func request_target_assignment(ship: Node3D, preferred_targets: Array[Node3D] = []) -> Node3D:
	"""Request target assignment for ship"""
	if not ship or coordination_mode == CoordinationMode.DISABLED:
		return null
	
	var ship_id: String = str(ship.get_instance_id())
	var formation_id: String = _get_ship_formation(ship)
	
	# Get available targets
	var available_targets: Array[Node3D] = _get_available_targets_for_ship(ship, preferred_targets)
	
	if available_targets.is_empty():
		return null
	
	# Apply coordination logic
	var assigned_target: Node3D = null
	
	match coordination_mode:
		CoordinationMode.BASIC:
			assigned_target = _assign_target_basic(ship, available_targets)
		CoordinationMode.OPTIMIZED:
			assigned_target = _assign_target_optimized(ship, available_targets)
		CoordinationMode.HIERARCHICAL:
			assigned_target = _assign_target_hierarchical(ship, available_targets, formation_id)
		CoordinationMode.ADAPTIVE:
			assigned_target = _assign_target_adaptive(ship, available_targets, formation_id)
		_:
			assigned_target = available_targets[0] if not available_targets.is_empty() else null
	
	if assigned_target:
		_register_target_assignment(ship, assigned_target, AssignmentType.PRIMARY)
	
	return assigned_target

func get_coordinated_target(ship: Node3D, target_candidates: Array[Dictionary]) -> Node3D:
	"""Get coordinated target from list of candidates"""
	if coordination_mode == CoordinationMode.DISABLED or target_candidates.is_empty():
		return null
	
	var formation_id: String = _get_ship_formation(ship)
	var coordinated_target: Node3D = null
	
	# Apply formation coordination
	if not formation_id.is_empty():
		coordinated_target = _coordinate_formation_target(ship, target_candidates, formation_id)
	
	# Fall back to individual coordination
	if not coordinated_target:
		var targets: Array[Node3D] = []
		for candidate in target_candidates:
			var target: Node3D = candidate.get("target", null)
			if target:
				targets.append(target)
		
		coordinated_target = request_target_assignment(ship, targets)
	
	return coordinated_target

func should_switch_target(ship: Node3D, current_target: Node3D, new_target: Node3D) -> bool:
	"""Check if ship should switch targets based on coordination"""
	if coordination_mode == CoordinationMode.DISABLED:
		return false
	
	# Check if new target is oversaturated
	if _is_target_oversaturated(new_target):
		return false
	
	# Check if current target would become undefended
	if _would_target_become_undefended(current_target, ship):
		return false
	
	# Check formation coordination requirements
	var formation_id: String = _get_ship_formation(ship)
	if not formation_id.is_empty():
		return _formation_allows_target_switch(ship, current_target, new_target, formation_id)
	
	return true

func release_target_assignment(ship: Node3D, target: Node3D, reason: String = "manual") -> void:
	"""Release target assignment for ship"""
	if not ship:
		return
	
	var ship_id: String = str(ship.get_instance_id())
	
	# Remove assignment
	if target_assignments.has(ship_id):
		target_assignments.erase(ship_id)
	
	# Remove from target attackers
	if target:
		var target_id: String = str(target.get_instance_id())
		if target_attackers.has(target_id):
			var attackers: Array = target_attackers[target_id]
			for i in range(attackers.size() - 1, -1, -1):
				if attackers[i].get("ship", null) == ship:
					attackers.remove_at(i)
			
			# Clean up empty attacker lists
			if attackers.is_empty():
				target_attackers.erase(target_id)
	
	target_unassigned.emit(ship, target, reason)

func get_target_attackers(target: Node3D) -> Array[Node3D]:
	"""Get list of ships attacking target"""
	if not target:
		return []
	
	var target_id: String = str(target.get_instance_id())
	var attackers: Array[Node3D] = []
	
	if target_attackers.has(target_id):
		var attacker_data: Array = target_attackers[target_id]
		for data in attacker_data:
			var ship: Node3D = data.get("ship", null)
			if ship and is_instance_valid(ship):
				attackers.append(ship)
	
	return attackers

func get_ship_target_assignment(ship: Node3D) -> Dictionary:
	"""Get current target assignment for ship"""
	if not ship:
		return {}
	
	var ship_id: String = str(ship.get_instance_id())
	return target_assignments.get(ship_id, {})

func set_coordination_mode(mode: CoordinationMode) -> void:
	"""Set target coordination mode"""
	coordination_mode = mode
	
	# Clear existing assignments when changing modes
	if mode == CoordinationMode.DISABLED:
		_clear_all_assignments()

func get_coordination_debug_info() -> Dictionary:
	"""Get debug information about target coordination"""
	return {
		"coordination_mode": CoordinationMode.keys()[coordination_mode],
		"active_assignments": target_assignments.size(),
		"targets_under_attack": target_attackers.size(),
		"formation_coordinators": formation_coordinators.size(),
		"pending_assignments": pending_assignments.size(),
		"last_update": last_coordination_update,
		"max_attackers_per_target": max_attackers_per_target
	}

# Private implementation

func _initialize_target_coordination() -> void:
	"""Initialize target coordination system"""
	# Clear all data structures
	target_assignments.clear()
	target_attackers.clear()
	formation_coordinators.clear()
	pending_assignments.clear()

func _update_target_coordination(delta: float) -> void:
	"""Update target coordination system"""
	var start_time: float = Time.get_time_from_start() * 1000.0
	
	# Clean up expired assignments
	_cleanup_expired_assignments()
	
	# Process pending assignments
	_process_pending_assignments()
	
	# Update formation coordination
	_update_formation_coordination()
	
	# Check frame budget
	var elapsed_time: float = (Time.get_time_from_start() * 1000.0) - start_time
	if elapsed_time > coordination_frame_budget:
		# Split remaining work across frames
		return

func _get_available_targets_for_ship(ship: Node3D, preferred_targets: Array[Node3D] = []) -> Array[Node3D]:
	"""Get available targets for ship"""
	var available_targets: Array[Node3D] = []
	
	# Start with preferred targets if provided
	for target in preferred_targets:
		if _is_target_available_for_ship(ship, target):
			available_targets.append(target)
	
	# Add targets from threat assessment if needed
	if available_targets.size() < 3 and threat_assessment:
		var threat_targets: Array[Dictionary] = threat_assessment.get_targets_by_priority(ThreatAssessmentSystem.TargetPriority.LOW)
		
		for threat_data in threat_targets:
			var target: Node3D = threat_data.get("target", null)
			if target and target not in available_targets and _is_target_available_for_ship(ship, target):
				available_targets.append(target)
				
				if available_targets.size() >= 5:  # Limit search
					break
	
	return available_targets

func _is_target_available_for_ship(ship: Node3D, target: Node3D) -> bool:
	"""Check if target is available for ship to attack"""
	if not target or not is_instance_valid(target):
		return false
	
	# Check if target is oversaturated
	if _is_target_oversaturated(target):
		return false
	
	# Check distance
	var distance: float = ship.global_position.distance_to(target.global_position)
	if distance > 4000.0:  # Max coordination distance
		return false
	
	# Check if ship can engage this target type
	if tactical_doctrine:
		var ship_role: TacticalDoctrine.ShipRole = _get_ship_role(ship)
		var mission_type: TacticalDoctrine.MissionType = _get_mission_type()
		var preferences: Dictionary = tactical_doctrine.get_target_preferences(ship_role, mission_type)
		
		# Check excluded target types
		var excluded_types: Array = preferences.get("excluded_target_types", [])
		var threat_type: ThreatAssessmentSystem.ThreatType = _get_target_threat_type(target)
		
		if threat_type in excluded_types:
			return false
	
	return true

func _assign_target_basic(ship: Node3D, available_targets: Array[Node3D]) -> Node3D:
	"""Basic target assignment - first available non-oversaturated target"""
	for target in available_targets:
		if not _is_target_oversaturated(target):
			return target
	
	return null

func _assign_target_optimized(ship: Node3D, available_targets: Array[Node3D]) -> Node3D:
	"""Optimized target assignment based on threat and distance"""
	var best_target: Node3D = null
	var best_score: float = 0.0
	
	for target in available_targets:
		var score: float = _calculate_target_assignment_score(ship, target)
		
		if score > best_score:
			best_score = score
			best_target = target
	
	return best_target

func _assign_target_hierarchical(ship: Node3D, available_targets: Array[Node3D], formation_id: String) -> Node3D:
	"""Hierarchical target assignment based on formation leadership"""
	if formation_id.is_empty():
		return _assign_target_optimized(ship, available_targets)
	
	# Get formation leader
	var leader: Node3D = _get_formation_leader(formation_id)
	if not leader or leader == ship:
		return _assign_target_optimized(ship, available_targets)
	
	# Try to coordinate with leader's target
	var leader_target: Node3D = _get_ship_current_target(leader)
	if leader_target and leader_target in available_targets and not _is_target_oversaturated(leader_target):
		return leader_target
	
	return _assign_target_optimized(ship, available_targets)

func _assign_target_adaptive(ship: Node3D, available_targets: Array[Node3D], formation_id: String) -> Node3D:
	"""Adaptive target assignment based on situation"""
	# Assess situation
	var situation: Dictionary = _assess_tactical_situation(ship, formation_id)
	
	if situation.get("under_heavy_attack", false):
		# Prioritize immediate threats
		return _assign_target_defensive(ship, available_targets)
	elif situation.get("formation_dispersed", false):
		# Individual targeting
		return _assign_target_optimized(ship, available_targets)
	else:
		# Coordinated formation targeting
		return _assign_target_hierarchical(ship, available_targets, formation_id)

func _assign_target_defensive(ship: Node3D, available_targets: Array[Node3D]) -> Node3D:
	"""Defensive target assignment prioritizing immediate threats"""
	var closest_threat: Node3D = null
	var closest_distance: float = INF
	
	for target in available_targets:
		var distance: float = ship.global_position.distance_to(target.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_threat = target
	
	return closest_threat

func _calculate_target_assignment_score(ship: Node3D, target: Node3D) -> float:
	"""Calculate assignment score for target"""
	var score: float = 0.0
	
	# Threat score component
	if threat_assessment:
		var threat_score: float = threat_assessment.get_target_threat_score(target)
		score += threat_score * threat_distribution_weight
	
	# Distance component (closer is better)
	var distance: float = ship.global_position.distance_to(target.global_position)
	var distance_score: float = 1.0 - clamp(distance / 3000.0, 0.0, 1.0)
	score += distance_score * distance_distribution_weight
	
	# Capability component (ship suitability for target)
	var capability_score: float = _calculate_capability_match(ship, target)
	score += capability_score * capability_distribution_weight
	
	# Oversaturation penalty
	var current_attackers: int = get_target_attackers(target).size()
	if current_attackers > 0:
		score *= (1.0 - (current_attackers * 0.3))
	
	return max(0.0, score)

func _calculate_capability_match(ship: Node3D, target: Node3D) -> float:
	"""Calculate how well ship matches target"""
	if not tactical_doctrine:
		return 1.0
	
	var ship_role: TacticalDoctrine.ShipRole = _get_ship_role(ship)
	var threat_type: ThreatAssessmentSystem.ThreatType = _get_target_threat_type(target)
	
	return tactical_doctrine.get_threat_type_priority(ship_role, threat_type)

func _register_target_assignment(ship: Node3D, target: Node3D, assignment_type: AssignmentType) -> void:
	"""Register target assignment"""
	var ship_id: String = str(ship.get_instance_id())
	var target_id: String = str(target.get_instance_id())
	
	# Register assignment
	target_assignments[ship_id] = {
		"target": target,
		"ship": ship,
		"assignment_type": assignment_type,
		"assignment_time": Time.get_time_from_start(),
		"formation_id": _get_ship_formation(ship)
	}
	
	# Register attacker
	if not target_attackers.has(target_id):
		target_attackers[target_id] = []
	
	target_attackers[target_id].append({
		"ship": ship,
		"assignment_type": assignment_type,
		"assignment_time": Time.get_time_from_start()
	})
	
	target_assigned.emit(ship, target, AssignmentType.keys()[assignment_type])

func _is_target_oversaturated(target: Node3D) -> bool:
	"""Check if target has too many attackers"""
	var attackers: Array[Node3D] = get_target_attackers(target)
	
	# Base limit
	var limit: int = max_attackers_per_target
	
	# Adjust limit based on target size/type
	if target.has_method("get_mass"):
		var mass: float = target.get_mass()
		if mass > 1000.0:  # Large target
			limit = min(4, max_attackers_per_target + 2)
		elif mass < 50.0:  # Small target
			limit = 1
	
	return attackers.size() >= limit

func _would_target_become_undefended(target: Node3D, removing_ship: Node3D) -> bool:
	"""Check if target would become undefended if ship switches"""
	var attackers: Array[Node3D] = get_target_attackers(target)
	
	# Remove the switching ship from count
	var remaining_attackers: int = attackers.size()
	if removing_ship in attackers:
		remaining_attackers -= 1
	
	# Check if target is high priority and would become undefended
	if threat_assessment:
		var threat_score: float = threat_assessment.get_target_threat_score(target)
		if threat_score >= 6.0 and remaining_attackers == 0:
			return true
	
	return false

func _coordinate_formation_target(ship: Node3D, candidates: Array[Dictionary], formation_id: String) -> Node3D:
	"""Coordinate target selection within formation"""
	# Get formation members
	var formation_members: Array = _get_formation_members(formation_id)
	if formation_members.size() <= 1:
		return null
	
	# Analyze current formation targeting
	var formation_targets: Dictionary = _analyze_formation_targeting(formation_members)
	
	# Find best coordinated target
	var best_target: Node3D = null
	var best_coordination_score: float = 0.0
	
	for candidate in candidates:
		var target: Node3D = candidate.get("target", null)
		if not target:
			continue
		
		var coordination_score: float = _calculate_formation_coordination_score(
			ship, target, formation_members, formation_targets
		)
		
		if coordination_score > best_coordination_score:
			best_coordination_score = coordination_score
			best_target = target
	
	return best_target

func _calculate_formation_coordination_score(ship: Node3D, target: Node3D, formation_members: Array, current_targets: Dictionary) -> float:
	"""Calculate coordination score for formation targeting"""
	var score: float = 0.0
	
	# Base threat score
	if threat_assessment:
		score = threat_assessment.get_target_threat_score(target)
	
	# Formation coordination bonus
	var target_id: String = str(target.get_instance_id())
	var current_attackers: int = current_targets.get(target_id, []).size()
	
	# Prefer targets with some but not too many attackers
	if current_attackers == 1:
		score *= 1.3  # Good to have support
	elif current_attackers >= 2:
		score *= 0.6  # Already well covered
	
	# Distance penalty within formation context
	var avg_formation_distance: float = _calculate_average_formation_distance_to_target(formation_members, target)
	var ship_distance: float = ship.global_position.distance_to(target.global_position)
	
	if ship_distance < avg_formation_distance:
		score *= 1.2  # Ship is well positioned
	
	return score

func _cleanup_expired_assignments() -> void:
	"""Clean up expired target assignments"""
	var current_time: float = Time.get_time_from_start()
	var expired_ships: Array[String] = []
	
	for ship_id in target_assignments.keys():
		var assignment: Dictionary = target_assignments[ship_id]
		var assignment_time: float = assignment.get("assignment_time", 0.0)
		
		if current_time - assignment_time > target_assignment_timeout:
			expired_ships.append(ship_id)
		elif not is_instance_valid(assignment.get("ship", null)):
			expired_ships.append(ship_id)
		elif not is_instance_valid(assignment.get("target", null)):
			expired_ships.append(ship_id)
	
	# Remove expired assignments
	for ship_id in expired_ships:
		var assignment: Dictionary = target_assignments.get(ship_id, {})
		var ship: Node3D = assignment.get("ship", null)
		var target: Node3D = assignment.get("target", null)
		
		if ship and target:
			release_target_assignment(ship, target, "expired")

func _process_pending_assignments() -> void:
	"""Process pending target assignments"""
	# This would handle queued assignments that couldn't be processed immediately
	# For now, keep it simple
	pending_assignments.clear()

func _update_formation_coordination() -> void:
	"""Update formation-level coordination"""
	for formation_id in formation_coordinators.keys():
		var coordinator_data: Dictionary = formation_coordinators[formation_id]
		var formation_members: Array = coordinator_data.get("members", [])
		
		# Update formation targeting strategy
		_update_formation_targeting_strategy(formation_id, formation_members)

func _update_formation_targeting_strategy(formation_id: String, members: Array) -> void:
	"""Update targeting strategy for formation"""
	if members.size() <= 1:
		return
	
	# Analyze current formation targets
	var current_targets: Array[Node3D] = []
	for member in members:
		var target: Node3D = _get_ship_current_target(member)
		if target and target not in current_targets:
			current_targets.append(target)
	
	formation_targeting_updated.emit(formation_id, current_targets)

# Helper methods

func _get_ship_formation(ship: Node3D) -> String:
	"""Get formation ID for ship"""
	if formation_manager and formation_manager.has_method("get_ship_formation"):
		return formation_manager.get_ship_formation(ship)
	return ""

func _get_formation_members(formation_id: String) -> Array:
	"""Get formation members"""
	if formation_manager and formation_manager.has_method("get_formation_members"):
		return formation_manager.get_formation_members(formation_id)
	return []

func _get_formation_leader(formation_id: String) -> Node3D:
	"""Get formation leader"""
	if formation_manager and formation_manager.has_method("get_formation_leader"):
		return formation_manager.get_formation_leader(formation_id)
	return null

func _get_ship_current_target(ship: Node3D) -> Node3D:
	"""Get ship's current target"""
	if ship and ship.has_method("get_current_target"):
		return ship.get_current_target()
	elif ship and ship.has_method("get_target"):
		return ship.get_target()
	return null

func _get_ship_role(ship: Node3D) -> TacticalDoctrine.ShipRole:
	"""Get ship role"""
	if ship and ship.has_method("get_ship_role"):
		var role_string: String = ship.get_ship_role().to_lower()
		if "fighter" in role_string:
			return TacticalDoctrine.ShipRole.FIGHTER
		elif "bomber" in role_string:
			return TacticalDoctrine.ShipRole.BOMBER
		elif "interceptor" in role_string:
			return TacticalDoctrine.ShipRole.INTERCEPTOR
	
	return TacticalDoctrine.ShipRole.FIGHTER

func _get_mission_type() -> TacticalDoctrine.MissionType:
	"""Get current mission type"""
	# This would integrate with mission system
	return TacticalDoctrine.MissionType.PATROL

func _get_target_threat_type(target: Node3D) -> ThreatAssessmentSystem.ThreatType:
	"""Get target threat type"""
	if threat_assessment:
		for threat_id in threat_assessment.current_threats.keys():
			var threat_data: Dictionary = threat_assessment.current_threats[threat_id]
			if threat_data.get("target", null) == target:
				return threat_data.get("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN)
	
	return ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN

func _analyze_formation_targeting(formation_members: Array) -> Dictionary:
	"""Analyze current formation targeting patterns"""
	var target_analysis: Dictionary = {}
	
	for member in formation_members:
		var target: Node3D = _get_ship_current_target(member)
		if target:
			var target_id: String = str(target.get_instance_id())
			if not target_analysis.has(target_id):
				target_analysis[target_id] = []
			target_analysis[target_id].append(member)
	
	return target_analysis

func _calculate_average_formation_distance_to_target(formation_members: Array, target: Node3D) -> float:
	"""Calculate average distance from formation to target"""
	if formation_members.is_empty():
		return 0.0
	
	var total_distance: float = 0.0
	var valid_members: int = 0
	
	for member in formation_members:
		if member and is_instance_valid(member):
			total_distance += member.global_position.distance_to(target.global_position)
			valid_members += 1
	
	return total_distance / max(1, valid_members)

func _assess_tactical_situation(ship: Node3D, formation_id: String) -> Dictionary:
	"""Assess current tactical situation"""
	var situation: Dictionary = {
		"under_heavy_attack": false,
		"formation_dispersed": false,
		"outnumbered": false
	}
	
	# This would be expanded with actual threat analysis
	# For now, return baseline situation
	return situation

func _formation_allows_target_switch(ship: Node3D, current_target: Node3D, new_target: Node3D, formation_id: String) -> bool:
	"""Check if formation allows target switch"""
	# Check if formation coordination prevents the switch
	var formation_members: Array = _get_formation_members(formation_id)
	
	# Don't allow switch if it would leave high-priority target undefended
	if _would_target_become_undefended(current_target, ship):
		return false
	
	return true

func _clear_all_assignments() -> void:
	"""Clear all target assignments"""
	target_assignments.clear()
	target_attackers.clear()

# Signal handlers

func _on_formation_created(formation_id: String, leader: Node3D) -> void:
	"""Handle formation creation"""
	formation_coordinators[formation_id] = {
		"leader": leader,
		"members": [leader],
		"created_time": Time.get_time_from_start(),
		"targeting_strategy": "standard"
	}

func _on_formation_disbanded(formation_id: String) -> void:
	"""Handle formation disbanding"""
	formation_coordinators.erase(formation_id)

func _on_ship_added_to_formation(formation_id: String, ship: Node3D) -> void:
	"""Handle ship added to formation"""
	if formation_coordinators.has(formation_id):
		var members: Array = formation_coordinators[formation_id].get("members", [])
		if ship not in members:
			members.append(ship)

func _on_ship_removed_from_formation(formation_id: String, ship: Node3D) -> void:
	"""Handle ship removed from formation"""
	if formation_coordinators.has(formation_id):
		var members: Array = formation_coordinators[formation_id].get("members", [])
		var index: int = members.find(ship)
		if index >= 0:
			members.remove_at(index)
	
	# Release target assignment
	var ship_assignment: Dictionary = get_ship_target_assignment(ship)
	if not ship_assignment.is_empty():
		var target: Node3D = ship_assignment.get("target", null)
		if target:
			release_target_assignment(ship, target, "formation_removed")