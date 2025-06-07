class_name MissionTargetIntegration
extends Node

## Integration system for mission objectives and SEXP priority targets
## Links AI target selection with mission-driven priorities

signal mission_target_updated(target: Node3D, priority: float)
signal priority_target_assigned(target: Node3D, ships: Array[Node3D])
signal mission_objective_target_destroyed(target: Node3D, objective_id: String)
signal escort_target_changed(old_target: Node3D, new_target: Node3D)

enum MissionTargetType {
	PRIMARY_OBJECTIVE,   # Main mission target
	SECONDARY_OBJECTIVE, # Secondary mission target
	PROTECT_TARGET,      # Target to protect
	ESCORT_TARGET,       # Target to escort
	BONUS_TARGET,        # Bonus/optional target
	WAYPOINT_TARGET,     # Navigation waypoint
	SCRIPTED_TARGET      # SEXP-driven target
}

enum TargetPriority {
	IGNORE = 0,
	LOW = 1,
	MEDIUM = 2,
	HIGH = 3,
	CRITICAL = 4
}

# Mission integration
var mission_manager: Node
var sexp_interpreter: Node
var current_mission_context: Dictionary = {}

# Target tracking
var mission_targets: Dictionary = {}      # target_id -> mission_target_data
var priority_assignments: Dictionary = {} # ship_id -> priority_target_data
var protected_targets: Array[Node3D] = []
var escort_targets: Array[Node3D] = []

# SEXP integration
var sexp_target_priorities: Dictionary = {} # SEXP-driven target priorities
var dynamic_target_assignments: Dictionary = {} # Dynamic SEXP assignments

# Update timing
var integration_update_frequency: float = 1.0
var last_integration_update: float = 0.0

func _ready() -> void:
	_initialize_mission_integration()
	set_process(true)

func _process(delta: float) -> void:
	var current_time: float = Time.get_time_from_start()
	if current_time - last_integration_update >= integration_update_frequency:
		_update_mission_integration(delta)
		last_integration_update = current_time

# Public interface

func initialize_with_systems(mission_mgr: Node, sexp_interp: Node) -> void:
	"""Initialize with mission and SEXP systems"""
	mission_manager = mission_mgr
	sexp_interpreter = sexp_interp
	
	# Connect to mission manager signals
	if mission_manager:
		if mission_manager.has_signal("mission_started"):
			mission_manager.mission_started.connect(_on_mission_started)
		if mission_manager.has_signal("objective_updated"):
			mission_manager.objective_updated.connect(_on_objective_updated)
		if mission_manager.has_signal("target_destroyed"):
			mission_manager.target_destroyed.connect(_on_target_destroyed)
	
	# Connect to SEXP interpreter signals  
	if sexp_interpreter:
		if sexp_interpreter.has_signal("target_priority_changed"):
			sexp_interpreter.target_priority_changed.connect(_on_sexp_target_priority_changed)
		if sexp_interpreter.has_signal("escort_target_assigned"):
			sexp_interpreter.escort_target_assigned.connect(_on_sexp_escort_assigned)

func add_mission_target(target: Node3D, target_type: MissionTargetType, priority: TargetPriority, objective_id: String = "") -> void:
	"""Add mission target with priority"""
	if not target:
		return
	
	var target_id: String = str(target.get_instance_id())
	mission_targets[target_id] = {
		"target": target,
		"target_type": target_type,
		"priority": priority,
		"objective_id": objective_id,
		"added_time": Time.get_time_from_start(),
		"is_active": true
	}
	
	# Add to appropriate tracking arrays
	match target_type:
		MissionTargetType.PROTECT_TARGET:
			if target not in protected_targets:
				protected_targets.append(target)
		MissionTargetType.ESCORT_TARGET:
			if target not in escort_targets:
				escort_targets.append(target)
	
	mission_target_updated.emit(target, float(priority))

func remove_mission_target(target: Node3D) -> void:
	"""Remove mission target"""
	if not target:
		return
	
	var target_id: String = str(target.get_instance_id())
	if mission_targets.has(target_id):
		var target_data: Dictionary = mission_targets[target_id]
		var target_type: MissionTargetType = target_data.get("target_type", MissionTargetType.BONUS_TARGET)
		
		# Remove from tracking arrays
		match target_type:
			MissionTargetType.PROTECT_TARGET:
				protected_targets.erase(target)
			MissionTargetType.ESCORT_TARGET:
				escort_targets.erase(target)
		
		mission_targets.erase(target_id)

func get_target_mission_priority(target: Node3D) -> float:
	"""Get mission priority for target"""
	if not target:
		return 0.0
	
	var target_id: String = str(target.get_instance_id())
	
	# Check mission targets
	if mission_targets.has(target_id):
		var target_data: Dictionary = mission_targets[target_id]
		var priority: TargetPriority = target_data.get("priority", TargetPriority.IGNORE)
		return _priority_to_multiplier(priority)
	
	# Check SEXP targets
	if sexp_target_priorities.has(target_id):
		return sexp_target_priorities[target_id]
	
	return 1.0  # Neutral priority

func is_mission_priority_target(target: Node3D) -> bool:
	"""Check if target is a mission priority target"""
	var priority: float = get_target_mission_priority(target)
	return priority > 1.5  # Above normal priority

func is_protected_target(target: Node3D) -> bool:
	"""Check if target is under protection"""
	return target in protected_targets

func is_escort_target(target: Node3D) -> bool:
	"""Check if target is an escort target"""
	return target in escort_targets

func get_mission_relevant_targets(threat_level: ThreatAssessmentSystem.TargetPriority = ThreatAssessmentSystem.TargetPriority.LOW) -> Array[Dictionary]:
	"""Get targets relevant to current mission"""
	var relevant_targets: Array[Dictionary] = []
	
	for target_id in mission_targets.keys():
		var target_data: Dictionary = mission_targets[target_id]
		var target: Node3D = target_data.get("target", null)
		
		if not target or not is_instance_valid(target):
			continue
		
		if not target_data.get("is_active", true):
			continue
		
		var mission_priority: TargetPriority = target_data.get("priority", TargetPriority.IGNORE)
		if mission_priority >= TargetPriority.LOW:
			relevant_targets.append({
				"target": target,
				"mission_priority": mission_priority,
				"target_type": target_data.get("target_type", MissionTargetType.BONUS_TARGET),
				"objective_id": target_data.get("objective_id", ""),
				"priority_multiplier": _priority_to_multiplier(mission_priority)
			})
	
	# Sort by priority
	relevant_targets.sort_custom(func(a, b): return a.get("mission_priority", 0) > b.get("mission_priority", 0))
	
	return relevant_targets

func assign_priority_target_to_ships(target: Node3D, ships: Array[Node3D], duration: float = -1.0) -> void:
	"""Assign priority target to specific ships"""
	if not target or ships.is_empty():
		return
	
	var assignment_time: float = Time.get_time_from_start()
	
	for ship in ships:
		if not ship or not is_instance_valid(ship):
			continue
		
		var ship_id: String = str(ship.get_instance_id())
		priority_assignments[ship_id] = {
			"target": target,
			"ship": ship,
			"assignment_time": assignment_time,
			"duration": duration,
			"priority_type": "scripted"
		}
	
	priority_target_assigned.emit(target, ships)

func get_ship_priority_target(ship: Node3D) -> Node3D:
	"""Get priority target for ship"""
	if not ship:
		return null
	
	var ship_id: String = str(ship.get_instance_id())
	if not priority_assignments.has(ship_id):
		return null
	
	var assignment: Dictionary = priority_assignments[ship_id]
	var target: Node3D = assignment.get("target", null)
	
	# Check if assignment is still valid
	if not target or not is_instance_valid(target):
		priority_assignments.erase(ship_id)
		return null
	
	# Check if assignment has expired
	var duration: float = assignment.get("duration", -1.0)
	if duration > 0.0:
		var assignment_time: float = assignment.get("assignment_time", 0.0)
		if Time.get_time_from_start() - assignment_time > duration:
			priority_assignments.erase(ship_id)
			return null
	
	return target

func clear_ship_priority_target(ship: Node3D) -> void:
	"""Clear priority target for ship"""
	if not ship:
		return
	
	var ship_id: String = str(ship.get_instance_id())
	priority_assignments.erase(ship_id)

func update_mission_context(context: Dictionary) -> void:
	"""Update mission context information"""
	current_mission_context = context.duplicate()
	current_mission_context["update_time"] = Time.get_time_from_start()

func get_threats_to_protected_targets() -> Array[Dictionary]:
	"""Get threats to protected targets"""
	var threats: Array[Dictionary] = []
	
	for protected_target in protected_targets:
		if not is_instance_valid(protected_target):
			continue
		
		# Find threats near protected target
		var nearby_threats: Array = _find_threats_near_target(protected_target, 1500.0)
		
		for threat in nearby_threats:
			threats.append({
				"threat": threat,
				"protected_target": protected_target,
				"distance": protected_target.global_position.distance_to(threat.global_position),
				"priority": TargetPriority.HIGH
			})
	
	return threats

func process_sexp_target_command(command: String, target: Node3D, parameters: Dictionary = {}) -> bool:
	"""Process SEXP target command"""
	match command:
		"set-target-priority":
			var priority: float = parameters.get("priority", 1.0)
			var target_id: String = str(target.get_instance_id())
			sexp_target_priorities[target_id] = priority
			mission_target_updated.emit(target, priority)
			return true
		
		"assign-escort-target":
			if target not in escort_targets:
				escort_targets.append(target)
			var ships: Array = parameters.get("ships", [])
			if not ships.is_empty():
				assign_priority_target_to_ships(target, ships)
			return true
		
		"protect-target":
			if target not in protected_targets:
				protected_targets.append(target)
			add_mission_target(target, MissionTargetType.PROTECT_TARGET, TargetPriority.HIGH)
			return true
		
		"remove-target-priority":
			var target_id: String = str(target.get_instance_id())
			sexp_target_priorities.erase(target_id)
			remove_mission_target(target)
			return true
		
		_:
			return false

func get_integration_debug_info() -> Dictionary:
	"""Get debug information about mission integration"""
	return {
		"mission_targets": mission_targets.size(),
		"priority_assignments": priority_assignments.size(),
		"protected_targets": protected_targets.size(),
		"escort_targets": escort_targets.size(),
		"sexp_target_priorities": sexp_target_priorities.size(),
		"mission_context": current_mission_context,
		"last_update": last_integration_update
	}

# Private implementation

func _initialize_mission_integration() -> void:
	"""Initialize mission integration system"""
	# Clear all data
	mission_targets.clear()
	priority_assignments.clear()
	protected_targets.clear()
	escort_targets.clear()
	sexp_target_priorities.clear()
	dynamic_target_assignments.clear()
	
	# Try to find systems
	mission_manager = get_node_or_null("/root/MissionManager")
	sexp_interpreter = get_node_or_null("/root/SexpManager")

func _update_mission_integration(delta: float) -> void:
	"""Update mission integration"""
	# Clean up invalid targets
	_cleanup_invalid_targets()
	
	# Update priority assignments
	_update_priority_assignments()
	
	# Process dynamic SEXP assignments
	_process_dynamic_assignments()

func _cleanup_invalid_targets() -> void:
	"""Clean up invalid or destroyed targets"""
	var invalid_targets: Array[String] = []
	
	# Check mission targets
	for target_id in mission_targets.keys():
		var target_data: Dictionary = mission_targets[target_id]
		var target: Node3D = target_data.get("target", null)
		
		if not target or not is_instance_valid(target):
			invalid_targets.append(target_id)
	
	# Remove invalid targets
	for target_id in invalid_targets:
		var target_data: Dictionary = mission_targets.get(target_id, {})
		var target: Node3D = target_data.get("target", null)
		var objective_id: String = target_data.get("objective_id", "")
		
		mission_targets.erase(target_id)
		sexp_target_priorities.erase(target_id)
		
		if target:
			protected_targets.erase(target)
			escort_targets.erase(target)
			
			if not objective_id.is_empty():
				mission_objective_target_destroyed.emit(target, objective_id)
	
	# Clean up priority assignments
	var invalid_ships: Array[String] = []
	for ship_id in priority_assignments.keys():
		var assignment: Dictionary = priority_assignments[ship_id]
		var ship: Node3D = assignment.get("ship", null)
		var target: Node3D = assignment.get("target", null)
		
		if not ship or not is_instance_valid(ship) or not target or not is_instance_valid(target):
			invalid_ships.append(ship_id)
	
	for ship_id in invalid_ships:
		priority_assignments.erase(ship_id)

func _update_priority_assignments() -> void:
	"""Update priority target assignments"""
	# Check for expired assignments
	var current_time: float = Time.get_time_from_start()
	var expired_assignments: Array[String] = []
	
	for ship_id in priority_assignments.keys():
		var assignment: Dictionary = priority_assignments[ship_id]
		var duration: float = assignment.get("duration", -1.0)
		var assignment_time: float = assignment.get("assignment_time", 0.0)
		
		if duration > 0.0 and current_time - assignment_time > duration:
			expired_assignments.append(ship_id)
	
	for ship_id in expired_assignments:
		priority_assignments.erase(ship_id)

func _process_dynamic_assignments() -> void:
	"""Process dynamic SEXP-driven assignments"""
	# This would process queued SEXP commands for target assignments
	# For now, keep it as a placeholder for future expansion
	pass

func _find_threats_near_target(target: Node3D, radius: float) -> Array:
	"""Find threats near protected target"""
	var threats: Array = []
	
	if not target:
		return threats
	
	# Query physics space for nearby threats
	var space_state: PhysicsDirectSpaceState3D = target.get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = target.global_position
	
	var results: Array[Dictionary] = space_state.intersect_shape(query)
	
	for result in results:
		var collider: Node = result.get("collider", null)
		if collider and collider != target:
			# Check if it's a threat (hostile ship)
			if _is_threat_to_target(collider, target):
				threats.append(collider)
	
	return threats

func _is_threat_to_target(potential_threat: Node, protected_target: Node3D) -> bool:
	"""Check if entity is a threat to protected target"""
	if not potential_threat or not protected_target:
		return false
	
	# Check team allegiance
	if potential_threat.has_method("get_team") and protected_target.has_method("get_team"):
		var threat_team: int = potential_threat.get_team()
		var target_team: int = protected_target.get_team()
		
		if threat_team != target_team and threat_team != 0:  # Different teams, not neutral
			return true
	
	return false

func _priority_to_multiplier(priority: TargetPriority) -> float:
	"""Convert priority enum to multiplier"""
	match priority:
		TargetPriority.IGNORE:
			return 0.0
		TargetPriority.LOW:
			return 1.2
		TargetPriority.MEDIUM:
			return 1.5
		TargetPriority.HIGH:
			return 2.0
		TargetPriority.CRITICAL:
			return 3.0
		_:
			return 1.0

# Signal handlers

func _on_mission_started(mission_data: Dictionary) -> void:
	"""Handle mission start"""
	update_mission_context(mission_data)
	
	# Clear previous mission data
	mission_targets.clear()
	priority_assignments.clear()
	protected_targets.clear()
	escort_targets.clear()
	
	# Load mission targets from mission data
	var targets: Array = mission_data.get("targets", [])
	for target_info in targets:
		var target: Node3D = target_info.get("target", null)
		var target_type_str: String = target_info.get("type", "bonus")
		var priority_str: String = target_info.get("priority", "low")
		var objective_id: String = target_info.get("objective_id", "")
		
		if target:
			var target_type: MissionTargetType = _string_to_target_type(target_type_str)
			var priority: TargetPriority = _string_to_priority(priority_str)
			add_mission_target(target, target_type, priority, objective_id)

func _on_objective_updated(objective_id: String, status: String, target: Node3D) -> void:
	"""Handle objective update"""
	if not target:
		return
	
	match status:
		"completed":
			remove_mission_target(target)
		"failed":
			remove_mission_target(target)
		"activated":
			# Check if we need to add this target
			var target_id: String = str(target.get_instance_id())
			if not mission_targets.has(target_id):
				add_mission_target(target, MissionTargetType.PRIMARY_OBJECTIVE, TargetPriority.HIGH, objective_id)

func _on_target_destroyed(target: Node3D) -> void:
	"""Handle target destruction"""
	remove_mission_target(target)

func _on_sexp_target_priority_changed(target: Node3D, priority: float) -> void:
	"""Handle SEXP target priority change"""
	if not target:
		return
	
	var target_id: String = str(target.get_instance_id())
	sexp_target_priorities[target_id] = priority
	mission_target_updated.emit(target, priority)

func _on_sexp_escort_assigned(escort_target: Node3D, escort_ships: Array) -> void:
	"""Handle SEXP escort assignment"""
	if not escort_target:
		return
	
	var old_escort: Node3D = null
	if not escort_targets.is_empty():
		old_escort = escort_targets[0]  # Assume single escort for now
	
	escort_targets.clear()
	escort_targets.append(escort_target)
	
	# Assign escort ships
	var ships: Array[Node3D] = []
	for ship in escort_ships:
		if ship is Node3D:
			ships.append(ship)
	
	if not ships.is_empty():
		assign_priority_target_to_ships(escort_target, ships)
	
	escort_target_changed.emit(old_escort, escort_target)

# Utility functions

func _string_to_target_type(type_str: String) -> MissionTargetType:
	"""Convert string to target type"""
	match type_str.to_lower():
		"primary", "primary_objective":
			return MissionTargetType.PRIMARY_OBJECTIVE
		"secondary", "secondary_objective":
			return MissionTargetType.SECONDARY_OBJECTIVE
		"protect", "protect_target":
			return MissionTargetType.PROTECT_TARGET
		"escort", "escort_target":
			return MissionTargetType.ESCORT_TARGET
		"bonus", "bonus_target":
			return MissionTargetType.BONUS_TARGET
		"waypoint", "waypoint_target":
			return MissionTargetType.WAYPOINT_TARGET
		"scripted", "scripted_target":
			return MissionTargetType.SCRIPTED_TARGET
		_:
			return MissionTargetType.BONUS_TARGET

func _string_to_priority(priority_str: String) -> TargetPriority:
	"""Convert string to priority"""
	match priority_str.to_lower():
		"ignore":
			return TargetPriority.IGNORE
		"low":
			return TargetPriority.LOW
		"medium":
			return TargetPriority.MEDIUM
		"high":
			return TargetPriority.HIGH
		"critical":
			return TargetPriority.CRITICAL
		_:
			return TargetPriority.LOW