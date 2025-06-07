class_name FormationCollisionIntegration
extends Node

## Integration between formation flying and collision avoidance systems
## Ensures formation members avoid collisions while maintaining formation integrity

signal formation_collision_avoidance_activated(ship: Node3D, formation_id: String)
signal formation_member_collision(ship: Node3D, obstacle: Node3D, formation_id: String)
signal formation_integrity_threatened(formation_id: String, threat_level: float)

var formation_manager: FormationManager
var collision_avoidance_integration: CollisionAvoidanceIntegration
var active_formation_adjustments: Dictionary = {}
var formation_safety_margins: Dictionary = {}

enum FormationAvoidanceMode {
	MAINTAIN_FORMATION,    ## Prioritize formation integrity
	EMERGENCY_SCATTER,     ## Break formation for emergency avoidance  
	COORDINATED_MANEUVER,  ## Coordinate avoidance with formation leader
	REFORM_AFTER_AVOID     ## Avoid obstacle then return to formation
}

class FormationCollisionData:
	var formation_id: String
	var threatened_members: Array[Node3D] = []
	var obstacle: Node3D
	var avoidance_mode: FormationAvoidanceMode
	var coordination_time: float
	var estimated_avoidance_duration: float
	var original_formation_positions: Dictionary = {}
	
	func _init(id: String, obstacle_ref: Node3D, mode: FormationAvoidanceMode) -> void:
		formation_id = id
		obstacle = obstacle_ref
		avoidance_mode = mode
		coordination_time = Time.get_time_from_start()

func _ready() -> void:
	# Find required managers
	formation_manager = get_node("/root/AIManager/FormationManager") as FormationManager
	collision_avoidance_integration = get_node("/root/AIManager/CollisionAvoidanceIntegration") as CollisionAvoidanceIntegration
	
	if not formation_manager:
		formation_manager = get_tree().get_first_node_in_group("formation_managers") as FormationManager
	
	if not collision_avoidance_integration:
		collision_avoidance_integration = get_tree().get_first_node_in_group("collision_integration") as CollisionAvoidanceIntegration
	
	# Connect to collision system signals
	if collision_avoidance_integration:
		collision_avoidance_integration.connect("collision_avoidance_activated", _on_collision_avoidance_activated)
		collision_avoidance_integration.connect("avoidance_completed", _on_collision_avoidance_completed)

func register_formation_for_collision_integration(formation_id: String) -> void:
	## Registers a formation for collision-aware coordination
	if not formation_manager:
		return
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	if not formation:
		return
	
	# Set default safety margins
	formation_safety_margins[formation_id] = {
		"member_spacing": formation.formation_spacing * 0.8,
		"obstacle_clearance": 150.0,
		"emergency_break_distance": 200.0
	}
	
	# Register all formation members with collision system
	for member in formation.members:
		if is_instance_valid(member) and collision_avoidance_integration:
			collision_avoidance_integration.register_ship(member)

func handle_formation_collision_threat(
	formation_id: String, 
	obstacle: Node3D, 
	threatened_members: Array[Node3D]
) -> FormationAvoidanceMode:
	## Determines how formation should handle collision threat
	
	if not formation_manager:
		return FormationAvoidanceMode.EMERGENCY_SCATTER
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	if not formation:
		return FormationAvoidanceMode.EMERGENCY_SCATTER
	
	# Assess threat severity
	var threat_level: float = _assess_formation_threat_level(formation, obstacle, threatened_members)
	
	# Determine avoidance mode based on threat level and formation status
	var avoidance_mode: FormationAvoidanceMode
	
	if threat_level > 0.8:
		# Critical threat - emergency scatter
		avoidance_mode = FormationAvoidanceMode.EMERGENCY_SCATTER
	elif threatened_members.size() == 1:
		# Single member threatened - individual avoidance
		avoidance_mode = FormationAvoidanceMode.REFORM_AFTER_AVOID
	elif formation.get_formation_integrity() > 0.7:
		# Formation in good shape - coordinated maneuver
		avoidance_mode = FormationAvoidanceMode.COORDINATED_MANEUVER
	else:
		# Formation already loose - maintain what we can
		avoidance_mode = FormationAvoidanceMode.MAINTAIN_FORMATION
	
	# Create collision data and execute avoidance
	var collision_data: FormationCollisionData = FormationCollisionData.new(formation_id, obstacle, avoidance_mode)
	collision_data.threatened_members = threatened_members
	active_formation_adjustments[formation_id] = collision_data
	
	_execute_formation_collision_avoidance(collision_data, formation)
	
	formation_integrity_threatened.emit(formation_id, threat_level)
	return avoidance_mode

func _execute_formation_collision_avoidance(collision_data: FormationCollisionData, formation: FormationManager.Formation) -> void:
	## Executes the chosen formation collision avoidance strategy
	
	match collision_data.avoidance_mode:
		FormationAvoidanceMode.MAINTAIN_FORMATION:
			_execute_maintain_formation_avoidance(collision_data, formation)
		FormationAvoidanceMode.EMERGENCY_SCATTER:
			_execute_emergency_scatter_avoidance(collision_data, formation)
		FormationAvoidanceMode.COORDINATED_MANEUVER:
			_execute_coordinated_formation_maneuver(collision_data, formation)
		FormationAvoidanceMode.REFORM_AFTER_AVOID:
			_execute_reform_after_avoidance(collision_data, formation)

func _execute_maintain_formation_avoidance(collision_data: FormationCollisionData, formation: FormationManager.Formation) -> void:
	## Maintains formation while avoiding obstacle
	
	# Adjust formation spacing temporarily
	var original_spacing: float = formation.formation_spacing
	formation.formation_spacing *= 1.3  # Increase spacing
	
	# Store original spacing for restoration
	collision_data.original_formation_positions["spacing"] = original_spacing
	
	# Signal all members to maintain loose formation
	for member in formation.members:
		if is_instance_valid(member):
			var ai_agent: WCSAIAgent = _get_ai_agent(member)
			if ai_agent:
				ai_agent.blackboard.set_value("formation_loose_avoidance", true)
				ai_agent.blackboard.set_value("formation_avoid_obstacle", collision_data.obstacle)

func _execute_emergency_scatter_avoidance(collision_data: FormationCollisionData, formation: FormationManager.Formation) -> void:
	## Emergency formation break-up for critical threats
	
	# Store original formation for later reformation
	for i in range(formation.members.size()):
		var member: Node3D = formation.members[i]
		if is_instance_valid(member):
			collision_data.original_formation_positions[member] = formation.get_formation_position(i)
	
	# Signal emergency scatter to all members
	for member in formation.members:
		if is_instance_valid(member):
			var ai_agent: WCSAIAgent = _get_ai_agent(member)
			if ai_agent:
				ai_agent.blackboard.set_value("formation_emergency_scatter", true)
				ai_agent.blackboard.set_value("formation_scatter_obstacle", collision_data.obstacle)
				ai_agent.blackboard.set_value("formation_reform_timer", 10.0)  # Reform after 10 seconds

func _execute_coordinated_formation_maneuver(collision_data: FormationCollisionData, formation: FormationManager.Formation) -> void:
	## Coordinates formation-wide avoidance maneuver
	
	# Calculate formation-wide avoidance vector
	var formation_center: Vector3 = _calculate_formation_center(formation)
	var obstacle_pos: Vector3 = collision_data.obstacle.global_position
	var avoidance_vector: Vector3 = (formation_center - obstacle_pos).normalized()
	
	# Apply perpendicular offset for formation maneuver
	var leader_forward: Vector3 = formation._get_ship_forward(formation.leader)
	var maneuver_vector: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	
	# Choose left or right maneuver based on obstacle position
	var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
	var obstacle_relative: Vector3 = obstacle_pos - formation.leader.global_position
	if obstacle_relative.dot(leader_right) > 0:
		maneuver_vector = -maneuver_vector  # Go left if obstacle is on right
	
	# Signal coordinated maneuver to formation leader
	var leader_ai: WCSAIAgent = _get_ai_agent(formation.leader)
	if leader_ai:
		leader_ai.blackboard.set_value("formation_coordinated_maneuver", true)
		leader_ai.blackboard.set_value("formation_maneuver_vector", maneuver_vector)
		leader_ai.blackboard.set_value("formation_maneuver_duration", 5.0)

func _execute_reform_after_avoidance(collision_data: FormationCollisionData, formation: FormationManager.Formation) -> void:
	## Individual avoidance with formation reformation
	
	# Only threatened members perform avoidance
	for member in collision_data.threatened_members:
		if is_instance_valid(member):
			var ai_agent: WCSAIAgent = _get_ai_agent(member)
			if ai_agent:
				ai_agent.blackboard.set_value("formation_individual_avoid", true)
				ai_agent.blackboard.set_value("formation_avoid_obstacle", collision_data.obstacle)
				ai_agent.blackboard.set_value("formation_reform_after_avoid", true)
				ai_agent.blackboard.set_value("formation_reform_timer", 3.0)

func _assess_formation_threat_level(formation: FormationManager.Formation, obstacle: Node3D, threatened_members: Array[Node3D]) -> float:
	## Assesses the severity of collision threat to formation
	
	var formation_center: Vector3 = _calculate_formation_center(formation)
	var obstacle_pos: Vector3 = obstacle.global_position
	var distance_to_obstacle: float = formation_center.distance_to(obstacle_pos)
	
	# Calculate threat factors
	var distance_factor: float = 1.0 - clamp(distance_to_obstacle / 500.0, 0.0, 1.0)
	var member_factor: float = float(threatened_members.size()) / float(formation.members.size())
	var speed_factor: float = 0.5  # Would calculate based on relative velocities
	
	# Combine factors
	var threat_level: float = (distance_factor * 0.4) + (member_factor * 0.4) + (speed_factor * 0.2)
	return clamp(threat_level, 0.0, 1.0)

func _calculate_formation_center(formation: FormationManager.Formation) -> Vector3:
	## Calculates the geometric center of the formation
	
	var center: Vector3 = formation.leader.global_position
	var ship_count: int = 1
	
	for member in formation.members:
		if is_instance_valid(member):
			center += member.global_position
			ship_count += 1
	
	return center / ship_count

func monitor_formation_collision_status(formation_id: String) -> Dictionary:
	## Returns current collision status for formation
	
	if not active_formation_adjustments.has(formation_id):
		return {"status": "no_active_avoidance"}
	
	var collision_data: FormationCollisionData = active_formation_adjustments[formation_id]
	var current_time: float = Time.get_time_from_start()
	var avoidance_duration: float = current_time - collision_data.coordination_time
	
	return {
		"status": "active_avoidance",
		"avoidance_mode": FormationAvoidanceMode.keys()[collision_data.avoidance_mode],
		"threatened_members": collision_data.threatened_members.size(),
		"avoidance_duration": avoidance_duration,
		"obstacle": collision_data.obstacle.name if is_instance_valid(collision_data.obstacle) else "Invalid"
	}

func complete_formation_collision_avoidance(formation_id: String) -> void:
	## Completes formation collision avoidance and restores formation
	
	if not active_formation_adjustments.has(formation_id):
		return
	
	var collision_data: FormationCollisionData = active_formation_adjustments[formation_id]
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	
	if formation:
		# Restore original formation parameters
		if collision_data.original_formation_positions.has("spacing"):
			formation.formation_spacing = collision_data.original_formation_positions["spacing"]
		
		# Clear avoidance blackboard values for all members
		for member in formation.members:
			if is_instance_valid(member):
				var ai_agent: WCSAIAgent = _get_ai_agent(member)
				if ai_agent:
					_clear_avoidance_blackboard_values(ai_agent)
		
		# Clear leader avoidance values
		var leader_ai: WCSAIAgent = _get_ai_agent(formation.leader)
		if leader_ai:
			_clear_avoidance_blackboard_values(leader_ai)
	
	# Remove from active adjustments
	active_formation_adjustments.erase(formation_id)

func _clear_avoidance_blackboard_values(ai_agent: WCSAIAgent) -> void:
	## Clears collision avoidance blackboard values
	
	ai_agent.blackboard.erase_value("formation_loose_avoidance")
	ai_agent.blackboard.erase_value("formation_avoid_obstacle")
	ai_agent.blackboard.erase_value("formation_emergency_scatter")
	ai_agent.blackboard.erase_value("formation_scatter_obstacle")
	ai_agent.blackboard.erase_value("formation_reform_timer")
	ai_agent.blackboard.erase_value("formation_coordinated_maneuver")
	ai_agent.blackboard.erase_value("formation_maneuver_vector")
	ai_agent.blackboard.erase_value("formation_maneuver_duration")
	ai_agent.blackboard.erase_value("formation_individual_avoid")
	ai_agent.blackboard.erase_value("formation_reform_after_avoid")

func _get_ai_agent(ship: Node3D) -> WCSAIAgent:
	## Helper to get AI agent from ship
	if ship.has_method("get_ai_agent"):
		return ship.get_ai_agent()
	return ship.get_node("WCSAIAgent") as WCSAIAgent

func _on_collision_avoidance_activated(ship: Node3D, avoidance_mode: String) -> void:
	## Handles when collision avoidance is activated for a ship
	
	if not formation_manager:
		return
	
	var formation_id: String = formation_manager.get_ship_formation_id(ship)
	if not formation_id.is_empty():
		formation_collision_avoidance_activated.emit(ship, formation_id)

func _on_collision_avoidance_completed(ship: Node3D) -> void:
	## Handles when collision avoidance is completed for a ship
	
	if not formation_manager:
		return
	
	var formation_id: String = formation_manager.get_ship_formation_id(ship)
	if not formation_id.is_empty():
		# Check if all formation members have completed avoidance
		_check_formation_avoidance_completion(formation_id)

func _check_formation_avoidance_completion(formation_id: String) -> void:
	## Checks if formation collision avoidance is complete
	
	if not active_formation_adjustments.has(formation_id):
		return
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	if not formation:
		return
	
	# Check if any members are still in active avoidance
	var members_in_avoidance: int = 0
	for member in formation.members:
		if is_instance_valid(member):
			var ai_agent: WCSAIAgent = _get_ai_agent(member)
			if ai_agent and collision_avoidance_integration:
				var status: Dictionary = collision_avoidance_integration.get_avoidance_status(member)
				if status.get("avoidance_mode", "none") != "none":
					members_in_avoidance += 1
	
	# If no members are in active avoidance, complete formation avoidance
	if members_in_avoidance == 0:
		complete_formation_collision_avoidance(formation_id)