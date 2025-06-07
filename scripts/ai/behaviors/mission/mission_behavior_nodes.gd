## Mission-Specific Behavior Tree Nodes
##
## Provides specialized behavior tree nodes for mission-driven AI behavior,
## supporting escort missions, defensive operations, scripted sequences, and
## narrative-driven behaviors that respond to mission context and SEXP commands.

class_name MissionBehaviorNodes
extends RefCounted

const WCSBTAction = preload("res://scripts/ai/behaviors/wcs_bt_action.gd")
const WCSBTCondition = preload("res://scripts/ai/behaviors/wcs_bt_condition.gd")

## Mission Context Action - Adapts behavior based on mission context
class MissionContextAdaptationAction extends WCSBTAction:
	
	@export var adaptation_sensitivity: float = 1.0
	@export var context_update_frequency: float = 2.0
	
	var last_context_update: float = 0.0
	var current_context: Dictionary = {}
	var context_awareness_system: Node
	
	func _setup() -> void:
		super._setup()
		context_awareness_system = get_node_or_null("/root/AIContextAwarenessSystem")
		if not context_awareness_system:
			push_warning("MissionContextAdaptationAction: No context awareness system found")
	
	func execute_wcs_action(delta: float) -> int:
		var current_time: float = Time.get_time_ticks_msec() / 1000.0
		
		# Update context periodically
		if current_time - last_context_update >= context_update_frequency:
			_update_mission_context()
			last_context_update = current_time
		
		# Apply context-based adaptations
		var adaptation_success: bool = _apply_context_adaptations()
		
		if adaptation_success:
			return BTAction.SUCCESS
		else:
			return BTAction.RUNNING

	func _update_mission_context() -> void:
		if not context_awareness_system:
			return
		
		current_context = context_awareness_system.get_mission_context()
		
		# Store context in blackboard for other nodes
		ai_agent.blackboard.set_value("mission_context", current_context)
		ai_agent.blackboard.set_value("narrative_context", context_awareness_system.get_narrative_context())
		ai_agent.blackboard.set_value("environmental_context", context_awareness_system.get_environmental_context())
	
	func _apply_context_adaptations() -> bool:
		var current_phase: String = current_context.get("current_phase", "unknown")
		var threat_level: float = current_context.get("threat_level", 0.0)
		
		match current_phase:
			"briefing":
				return _apply_briefing_behavior()
			"approach":
				return _apply_approach_behavior(threat_level)
			"engagement":
				return _apply_engagement_behavior(threat_level)
			"extraction":
				return _apply_extraction_behavior()
			"debriefing":
				return _apply_debriefing_behavior()
			_:
				return _apply_default_behavior()
	
	func _apply_briefing_behavior() -> bool:
		# Formal, attentive behavior during briefing
		ai_agent.alertness_level = 0.3
		ai_agent.formation_precision = 1.2
		_set_ship_behavior_mode("ceremonial")
		return true
	
	func _apply_approach_behavior(threat_level: float) -> bool:
		# Cautious, tactical approach behavior
		ai_agent.alertness_level = 0.6 + (threat_level * 0.3)
		ai_agent.formation_precision = 1.1
		_set_ship_behavior_mode("tactical_approach")
		return true
	
	func _apply_engagement_behavior(threat_level: float) -> bool:
		# Combat-ready behavior
		ai_agent.alertness_level = 0.9 + (threat_level * 0.1)
		ai_agent.aggression_level = 0.7 + (threat_level * 0.3)
		_set_ship_behavior_mode("combat_ready")
		return true
	
	func _apply_extraction_behavior() -> bool:
		# Protective, speed-focused behavior
		ai_agent.alertness_level = 0.8
		ai_agent.formation_precision = 0.9  # Slightly looser for speed
		_set_ship_behavior_mode("extraction")
		return true
	
	func _apply_debriefing_behavior() -> bool:
		# Relaxed, parade formation behavior
		ai_agent.alertness_level = 0.2
		ai_agent.formation_precision = 1.3  # Very precise for ceremony
		_set_ship_behavior_mode("parade")
		return true
	
	func _apply_default_behavior() -> bool:
		ai_agent.alertness_level = 0.5
		ai_agent.formation_precision = 1.0
		_set_ship_behavior_mode("standard")
		return true
	
	func _set_ship_behavior_mode(mode: String) -> void:
		if ship_controller and ship_controller.has_method("set_behavior_mode"):
			ship_controller.set_behavior_mode(mode)

## Escort Mission Action - Specialized escort behavior
class EscortMissionAction extends WCSBTAction:
	
	@export var escort_distance: float = 200.0
	@export var protection_radius: float = 500.0
	@export var max_escort_distance: float = 1000.0
	
	var escort_target: Node3D
	var escort_formation_position: Vector3
	var threat_assessment_system: Node
	
	func _setup() -> void:
		super._setup()
		escort_target = ai_agent.blackboard.get_value("escort_target", null)
		threat_assessment_system = ai_agent.get_node_or_null("ThreatAssessmentSystem")
	
	func execute_wcs_action(delta: float) -> int:
		if not escort_target:
			escort_target = _find_escort_target()
			if not escort_target:
				return BTAction.FAILURE
		
		# Check if escort target is still valid
		if not _is_escort_target_valid():
			return BTAction.FAILURE
		
		# Update escort formation position
		_update_escort_position()
		
		# Check for threats near escort target
		var threats: Array = _scan_for_threats_near_escort()
		if not threats.is_empty():
			_respond_to_escort_threats(threats)
		
		# Move to escort position
		var distance_to_position: float = ai_agent.global_position.distance_to(escort_formation_position)
		
		if distance_to_position > 50.0:
			_move_to_escort_position()
			return BTAction.RUNNING
		else:
			# Maintain escort position
			_maintain_escort_formation()
			return BTAction.SUCCESS
	
	func _find_escort_target() -> Node3D:
		var goal_system: Node = ai_agent.get_node_or_null("AIGoalSystem")
		if goal_system:
			var current_goal: Node = goal_system.get_current_primary_goal()
			if current_goal and current_goal.goal_type == 2:  # ESCORT_TARGET
				return current_goal.target_node
		return null
	
	func _is_escort_target_valid() -> bool:
		if not escort_target or not is_instance_valid(escort_target):
			return false
		
		# Check if escort target is too far away
		var distance: float = ai_agent.global_position.distance_to(escort_target.global_position)
		return distance <= max_escort_distance
	
	func _update_escort_position() -> void:
		if not escort_target:
			return
		
		# Calculate optimal escort position based on threats and terrain
		var target_position: Vector3 = escort_target.global_position
		var target_velocity: Vector3 = Vector3.ZERO
		
		if escort_target.has_method("get_velocity"):
			target_velocity = escort_target.get_velocity()
		
		# Predict escort target's future position
		var prediction_time: float = 2.0
		var predicted_position: Vector3 = target_position + (target_velocity * prediction_time)
		
		# Calculate escort offset based on threat direction
		var threat_direction: Vector3 = _calculate_primary_threat_direction()
		var escort_offset: Vector3
		
		if threat_direction != Vector3.ZERO:
			# Position between escort target and threats
			escort_offset = -threat_direction.normalized() * escort_distance
		else:
			# Default escort position (slightly behind and to the side)
			var target_forward: Vector3 = _get_target_forward_direction()
			escort_offset = (-target_forward + target_forward.cross(Vector3.UP).normalized() * 0.5) * escort_distance
		
		escort_formation_position = predicted_position + escort_offset
	
	func _calculate_primary_threat_direction() -> Vector3:
		if not threat_assessment_system:
			return Vector3.ZERO
		
		var threats: Array = threat_assessment_system.get_nearby_threats(protection_radius)
		if threats.is_empty():
			return Vector3.ZERO
		
		var threat_center: Vector3 = Vector3.ZERO
		for threat in threats:
			threat_center += threat.global_position
		threat_center /= threats.size()
		
		return (threat_center - escort_target.global_position).normalized()
	
	func _get_target_forward_direction() -> Vector3:
		if escort_target.has_method("get_forward_direction"):
			return escort_target.get_forward_direction()
		else:
			return -escort_target.global_transform.basis.z
	
	func _scan_for_threats_near_escort() -> Array:
		if not threat_assessment_system:
			return []
		
		return threat_assessment_system.get_threats_near_position(
			escort_target.global_position, 
			protection_radius
		)
	
	func _respond_to_escort_threats(threats: Array) -> void:
		# Prioritize threats based on danger to escort target
		var priority_threat: Node3D = _select_priority_threat(threats)
		
		if priority_threat:
			ai_agent.blackboard.set_value("priority_threat", priority_threat)
			ai_agent.blackboard.set_value("escort_threat_response", true)
	
	func _select_priority_threat(threats: Array) -> Node3D:
		var closest_threat: Node3D = null
		var closest_distance: float = INF
		
		for threat in threats:
			var distance: float = threat.global_position.distance_to(escort_target.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_threat = threat
		
		return closest_threat
	
	func _move_to_escort_position() -> void:
		if ship_controller and ship_controller.has_method("set_target_position"):
			ship_controller.set_target_position(escort_formation_position)
	
	func _maintain_escort_formation() -> void:
		# Fine-tune position to maintain perfect escort formation
		var current_offset: Vector3 = ai_agent.global_position - escort_target.global_position
		var desired_offset: Vector3 = escort_formation_position - escort_target.global_position
		
		var correction: Vector3 = (desired_offset - current_offset) * 0.1
		var corrected_position: Vector3 = ai_agent.global_position + correction
		
		if ship_controller and ship_controller.has_method("set_target_position"):
			ship_controller.set_target_position(corrected_position)

## Defensive Operation Action - Specialized defensive mission behavior
class DefensiveOperationAction extends WCSBTAction:
	
	@export var defense_radius: float = 800.0
	@export var patrol_radius: float = 400.0
	@export var threat_engagement_range: float = 1200.0
	
	var defense_target: Node3D
	var defense_center: Vector3
	var patrol_angle: float = 0.0
	var patrol_speed: float = 1.0
	var active_threats: Array = []
	
	func _setup() -> void:
		super._setup()
		defense_target = ai_agent.blackboard.get_value("defense_target", null)
		if defense_target:
			defense_center = defense_target.global_position
		else:
			defense_center = ai_agent.blackboard.get_value("defense_position", ai_agent.global_position)
	
	func execute_wcs_action(delta: float) -> int:
		# Update defense center if defending a moving target
		if defense_target:
			defense_center = defense_target.global_position
		
		# Scan for threats in defense area
		_scan_defense_area()
		
		# Respond to threats based on priority
		if not active_threats.is_empty():
			return _engage_defensive_threats()
		else:
			return _maintain_defensive_patrol()
	
	func _scan_defense_area() -> void:
		active_threats.clear()
		
		var ships: Array = get_tree().get_nodes_in_group("ships")
		for ship in ships:
			if _is_threat_to_defense(ship):
				active_threats.append(ship)
		
		# Sort threats by priority (closest to defense target)
		active_threats.sort_custom(_compare_threat_priority)
	
	func _is_threat_to_defense(ship: Node3D) -> bool:
		if not ship or ship == ai_agent:
			return false
		
		# Check if ship is hostile
		if not _is_hostile_ship(ship):
			return false
		
		# Check if ship is within threat range
		var distance_to_defense: float = ship.global_position.distance_to(defense_center)
		return distance_to_defense <= threat_engagement_range
	
	func _is_hostile_ship(ship: Node3D) -> bool:
		# Implementation would check IFF/team affiliation
		if ship.has_method("get_team_id") and ai_agent.has_method("get_team_id"):
			return ship.get_team_id() != ai_agent.get_team_id()
		return false
	
	func _compare_threat_priority(threat_a: Node3D, threat_b: Node3D) -> bool:
		var distance_a: float = threat_a.global_position.distance_to(defense_center)
		var distance_b: float = threat_b.global_position.distance_to(defense_center)
		return distance_a < distance_b
	
	func _engage_defensive_threats() -> int:
		var primary_threat: Node3D = active_threats[0]
		
		# Set primary threat as target
		ai_agent.current_target = primary_threat
		ai_agent.blackboard.set_value("current_target", primary_threat)
		
		# Engage the threat while maintaining defensive position
		var threat_distance: float = primary_threat.global_position.distance_to(ai_agent.global_position)
		
		if threat_distance > 600.0:
			# Move closer to engage
			var intercept_position: Vector3 = _calculate_intercept_position(primary_threat)
			if ship_controller and ship_controller.has_method("set_target_position"):
				ship_controller.set_target_position(intercept_position)
		
		# Fire weapons if in range
		if threat_distance <= 500.0 and _is_facing_target(primary_threat):
			_fire_weapons_at_target(primary_threat)
		
		return BTAction.RUNNING
	
	func _maintain_defensive_patrol() -> int:
		# Patrol around defense center
		patrol_angle += patrol_speed * get_process_delta_time()
		if patrol_angle >= TAU:
			patrol_angle -= TAU
		
		var patrol_offset: Vector3 = Vector3(
			cos(patrol_angle) * patrol_radius,
			0.0,
			sin(patrol_angle) * patrol_radius
		)
		
		var patrol_position: Vector3 = defense_center + patrol_offset
		
		if ship_controller and ship_controller.has_method("set_target_position"):
			ship_controller.set_target_position(patrol_position)
		
		return BTAction.SUCCESS
	
	func _calculate_intercept_position(target: Node3D) -> Vector3:
		# Calculate intercept position that maintains defense coverage
		var target_direction: Vector3 = (target.global_position - defense_center).normalized()
		var intercept_distance: float = min(patrol_radius * 1.5, defense_radius * 0.8)
		
		return defense_center + (target_direction * intercept_distance)
	
	func _is_facing_target(target: Node3D) -> bool:
		var to_target: Vector3 = (target.global_position - ai_agent.global_position).normalized()
		var forward: Vector3 = -ai_agent.global_transform.basis.z
		var dot_product: float = forward.dot(to_target)
		return dot_product > 0.8  # Within ~36 degrees
	
	func _fire_weapons_at_target(target: Node3D) -> void:
		if ship_controller and ship_controller.has_method("fire_weapons"):
			ship_controller.fire_weapons(target)

## Scripted Sequence Action - Execute predefined mission sequences
class ScriptedSequenceAction extends WCSBTAction:
	
	@export var sequence_name: String = ""
	@export var allow_interruption: bool = false
	@export var sequence_timeout: float = 60.0
	
	var sequence_data: Dictionary = {}
	var current_step: int = 0
	var sequence_start_time: float = 0.0
	var is_sequence_running: bool = false
	
	func _setup() -> void:
		super._setup()
		sequence_data = ai_agent.blackboard.get_value("sequence_" + sequence_name, {})
		if sequence_data.is_empty():
			_load_sequence_data()
	
	func execute_wcs_action(delta: float) -> int:
		if not is_sequence_running:
			return _start_sequence()
		
		# Check for timeout
		var elapsed_time: float = Time.get_time_ticks_msec() / 1000.0 - sequence_start_time
		if elapsed_time >= sequence_timeout:
			return BTAction.FAILURE
		
		# Check for interruption conditions
		if allow_interruption and _should_interrupt_sequence():
			return BTAction.FAILURE
		
		# Execute current sequence step
		var step_result: int = _execute_sequence_step()
		
		match step_result:
			BTAction.SUCCESS:
				current_step += 1
				if current_step >= sequence_data.get("steps", []).size():
					return BTAction.SUCCESS  # Sequence complete
				else:
					return BTAction.RUNNING  # Continue to next step
			BTAction.FAILURE:
				return BTAction.FAILURE
			_:
				return BTAction.RUNNING
	
	func _start_sequence() -> int:
		if sequence_data.is_empty():
			push_error("ScriptedSequenceAction: No sequence data for " + sequence_name)
			return BTAction.FAILURE
		
		is_sequence_running = true
		sequence_start_time = Time.get_time_ticks_msec() / 1000.0
		current_step = 0
		
		# Set initial sequence context
		ai_agent.blackboard.set_value("in_scripted_sequence", true)
		ai_agent.blackboard.set_value("current_sequence", sequence_name)
		
		return BTAction.RUNNING
	
	func _load_sequence_data() -> void:
		# Load sequence data from mission files or predefined sequences
		match sequence_name:
			"victory_flyby":
				sequence_data = _create_victory_flyby_sequence()
			"formation_demonstration":
				sequence_data = _create_formation_demo_sequence()
			"ceremonial_approach":
				sequence_data = _create_ceremonial_approach_sequence()
			_:
				sequence_data = {}
	
	func _create_victory_flyby_sequence() -> Dictionary:
		return {
			"name": "victory_flyby",
			"description": "Victory celebration flyby sequence",
			"steps": [
				{
					"type": "formation_change",
					"formation": "victory_v",
					"duration": 3.0
				},
				{
					"type": "move_to_position",
					"position": "flyby_start",
					"speed": "parade"
				},
				{
					"type": "flyby_maneuver",
					"target": "victory_point",
					"altitude": 200.0,
					"speed": "ceremonial"
				},
				{
					"type": "victory_formation",
					"duration": 10.0
				}
			]
		}
	
	func _create_formation_demo_sequence() -> Dictionary:
		return {
			"name": "formation_demonstration",
			"description": "Formation flying demonstration",
			"steps": [
				{
					"type": "formation_change",
					"formation": "diamond",
					"duration": 2.0
				},
				{
					"type": "coordinated_turn",
					"angle": 90.0,
					"speed": "demonstration"
				},
				{
					"type": "formation_change",
					"formation": "line_abreast",
					"duration": 2.0
				},
				{
					"type": "coordinated_turn",
					"angle": -90.0,
					"speed": "demonstration"
				}
			]
		}
	
	func _create_ceremonial_approach_sequence() -> Dictionary:
		return {
			"name": "ceremonial_approach",
			"description": "Formal ceremonial approach",
			"steps": [
				{
					"type": "formation_change",
					"formation": "ceremonial_column",
					"duration": 3.0
				},
				{
					"type": "approach_target",
					"target": "ceremony_position",
					"speed": "ceremonial",
					"precision": "high"
				},
				{
					"type": "salute_maneuver",
					"duration": 5.0
				},
				{
					"type": "hold_position",
					"duration": -1  # Indefinite
				}
			]
		}
	
	func _execute_sequence_step() -> int:
		var steps: Array = sequence_data.get("steps", [])
		if current_step >= steps.size():
			return BTAction.SUCCESS
		
		var step: Dictionary = steps[current_step]
		var step_type: String = step.get("type", "")
		
		match step_type:
			"formation_change":
				return _execute_formation_change(step)
			"move_to_position":
				return _execute_move_to_position(step)
			"flyby_maneuver":
				return _execute_flyby_maneuver(step)
			"victory_formation":
				return _execute_victory_formation(step)
			"coordinated_turn":
				return _execute_coordinated_turn(step)
			"approach_target":
				return _execute_approach_target(step)
			"salute_maneuver":
				return _execute_salute_maneuver(step)
			"hold_position":
				return _execute_hold_position(step)
			_:
				push_warning("Unknown sequence step type: " + step_type)
				return BTAction.SUCCESS  # Skip unknown steps
	
	func _execute_formation_change(step: Dictionary) -> int:
		var formation: String = step.get("formation", "diamond")
		var duration: float = step.get("duration", 3.0)
		
		var formation_manager: Node = ai_agent.get_node_or_null("FormationManager")
		if formation_manager and formation_manager.has_method("request_formation_change"):
			formation_manager.request_formation_change(formation)
		
		# Wait for formation change to complete
		await get_tree().create_timer(duration).timeout
		return BTAction.SUCCESS
	
	func _execute_move_to_position(step: Dictionary) -> int:
		var position_name: String = step.get("position", "")
		var speed: String = step.get("speed", "standard")
		
		var target_position: Vector3 = _resolve_position(position_name)
		if ship_controller and ship_controller.has_method("set_target_position"):
			ship_controller.set_target_position(target_position)
			_set_movement_speed(speed)
		
		# Check if reached position
		var distance: float = ai_agent.global_position.distance_to(target_position)
		return BTAction.SUCCESS if distance < 100.0 else BTAction.RUNNING
	
	func _resolve_position(position_name: String) -> Vector3:
		# Resolve named positions from mission context
		var mission_positions: Dictionary = ai_agent.blackboard.get_value("mission_positions", {})
		return mission_positions.get(position_name, ai_agent.global_position)
	
	func _set_movement_speed(speed_type: String) -> void:
		var speed_modifier: float = 1.0
		
		match speed_type:
			"ceremonial":
				speed_modifier = 0.5
			"parade":
				speed_modifier = 0.7
			"demonstration":
				speed_modifier = 0.8
			"standard":
				speed_modifier = 1.0
			"urgent":
				speed_modifier = 1.3
		
		if ship_controller and ship_controller.has_method("set_speed_modifier"):
			ship_controller.set_speed_modifier(speed_modifier)
	
	func _should_interrupt_sequence() -> bool:
		# Check for conditions that should interrupt the sequence
		var threat_level: float = ai_agent.blackboard.get_value("threat_level", 0.0)
		if threat_level > 0.7:
			return true
		
		var emergency_event: bool = ai_agent.blackboard.get_value("emergency_event", false)
		return emergency_event
	
	# Placeholder implementations for other sequence step types
	func _execute_flyby_maneuver(step: Dictionary) -> int:
		# Implementation for flyby maneuver
		return BTAction.SUCCESS
	
	func _execute_victory_formation(step: Dictionary) -> int:
		# Implementation for victory formation
		return BTAction.SUCCESS
	
	func _execute_coordinated_turn(step: Dictionary) -> int:
		# Implementation for coordinated turn
		return BTAction.SUCCESS
	
	func _execute_approach_target(step: Dictionary) -> int:
		# Implementation for approach target
		return BTAction.SUCCESS
	
	func _execute_salute_maneuver(step: Dictionary) -> int:
		# Implementation for salute maneuver
		return BTAction.SUCCESS
	
	func _execute_hold_position(step: Dictionary) -> int:
		# Implementation for hold position
		return BTAction.SUCCESS

## Narrative Response Condition - Checks for narrative events
class NarrativeEventCondition extends WCSBTCondition:
	
	@export var event_type: String = ""
	@export var emotional_tone: String = ""
	@export var min_tension_level: float = 0.0
	
	func check_wcs_condition() -> bool:
		var narrative_context: Dictionary = ai_agent.blackboard.get_value("narrative_context", {})
		
		# Check event type
		if not event_type.is_empty():
			var last_event: String = narrative_context.get("last_event", "")
			if last_event != event_type:
				return false
		
		# Check emotional tone
		if not emotional_tone.is_empty():
			var current_tone: String = narrative_context.get("emotional_tone", "")
			if current_tone != emotional_tone:
				return false
		
		# Check tension level
		var tension: float = narrative_context.get("scene_tension", 0.0)
		if tension < min_tension_level:
			return false
		
		return true

## Mission Objective Condition - Checks mission objective status
class MissionObjectiveCondition extends WCSBTCondition:
	
	@export var objective_id: String = ""
	@export var required_status: String = "completed"
	
	func check_wcs_condition() -> bool:
		var mission_context: Dictionary = ai_agent.blackboard.get_value("mission_context", {})
		var objectives: Array = mission_context.get("primary_objectives", [])
		
		for objective in objectives:
			if objective.get("id", "") == objective_id:
				return objective.get("status", "") == required_status
		
		# Check secondary objectives
		var secondary_objectives: Array = mission_context.get("secondary_objectives", [])
		for objective in secondary_objectives:
			if objective.get("id", "") == objective_id:
				return objective.get("status", "") == required_status
		
		return false

## SEXP Command Condition - Checks for SEXP command execution
class SexpCommandCondition extends WCSBTCondition:
	
	@export var command_name: String = ""
	@export var check_result: bool = true
	
	func check_wcs_condition() -> bool:
		var sexp_commands: Array = ai_agent.blackboard.get_value("sexp_commands", [])
		
		for command in sexp_commands:
			if command.get("expression", "").begins_with(command_name):
				var result: bool = command.get("result", false)
				return result == check_result
		
		return false