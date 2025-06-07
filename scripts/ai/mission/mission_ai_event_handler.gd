class_name MissionAIEventHandler
extends Node

## Mission-driven AI Event Handler
##
## Responds to mission events and triggers appropriate AI behavior modifications.
## Provides the bridge between mission scripting and AI behavior systems, ensuring
## AI responds naturally to story events, objectives, and environmental changes.

signal ai_mission_response_triggered(event_type: String, ship_name: String, response: String)
signal ai_context_updated(context_type: String, context_data: Dictionary)
signal mission_ai_objective_assigned(ship_name: String, objective: String, parameters: Dictionary)

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Event trigger types
enum EventTriggerType {
	MISSION_PHASE_CHANGE,
	OBJECTIVE_STATUS_CHANGE,
	SHIP_EVENT,
	ENVIRONMENTAL_CHANGE,
	STORY_EVENT,
	COMBAT_EVENT,
	FORMATION_EVENT,
	EMERGENCY_EVENT
}

## Mission context for AI adaptation
var mission_context: Dictionary = {
	"current_phase": "briefing",
	"primary_objectives": [],
	"secondary_objectives": [],
	"environmental_factors": {},
	"story_state": {},
	"threat_level": 0.0,
	"mission_type": "patrol",
	"time_pressure": 0.0
}

## AI response templates for different events
var ai_response_templates: Dictionary = {}

## Active AI behavioral modifications
var active_modifications: Dictionary = {}

## Event processing queue for complex multi-stage responses
var event_queue: Array[Dictionary] = []

func _ready() -> void:
	_initialize_response_templates()
	_connect_to_mission_systems()
	
	# Register with mission event manager
	if has_node("/root/MissionEventManager"):
		var mission_manager: Node = get_node("/root/MissionEventManager")
		mission_manager.mission_event_triggered.connect(_on_mission_event)
		mission_manager.objective_updated.connect(_on_objective_updated)
		mission_manager.phase_transition.connect(_on_phase_transition)

func _initialize_response_templates() -> void:
	ai_response_templates = {
		"enemy_sighted": {
			"immediate": ["increase_alertness", "formation_combat_spread"],
			"conditions": {"threat_level": 0.3},
			"duration": 30.0
		},
		"ally_under_attack": {
			"immediate": ["divert_to_assist", "increase_aggression"],
			"conditions": {"distance_threshold": 2000.0},
			"duration": -1  # Until resolved
		},
		"objective_critical": {
			"immediate": ["prioritize_objective", "increase_speed"],
			"conditions": {"time_remaining": 300.0},
			"duration": -1
		},
		"environmental_hazard": {
			"immediate": ["evasive_formation", "reduce_speed"],
			"conditions": {"hazard_proximity": 500.0},
			"duration": 60.0
		},
		"story_revelation": {
			"immediate": ["dialogue_formation", "hold_position"],
			"conditions": {},
			"duration": 15.0
		},
		"mission_complete": {
			"immediate": ["victory_formation", "return_to_base"],
			"conditions": {},
			"duration": -1
		}
	}

func _connect_to_mission_systems() -> void:
	# Connect to SEXP system for mission script events
	if has_node("/root/SexpManager"):
		var sexp_manager: Node = get_node("/root/SexpManager")
		sexp_manager.expression_evaluated.connect(_on_sexp_evaluated)
	
	# Connect to AI manager for coordination
	if has_node("/root/AIManager"):
		var ai_manager: Node = get_node("/root/AIManager")
		ai_manager.ai_state_changed.connect(_on_ai_state_changed)

## Process mission events and trigger AI responses
func _on_mission_event(event_type: String, event_data: Dictionary) -> void:
	var trigger_type: EventTriggerType = _categorize_event(event_type)
	
	match trigger_type:
		EventTriggerType.MISSION_PHASE_CHANGE:
			_handle_phase_change(event_data)
		EventTriggerType.OBJECTIVE_STATUS_CHANGE:
			_handle_objective_change(event_data)
		EventTriggerType.SHIP_EVENT:
			_handle_ship_event(event_data)
		EventTriggerType.ENVIRONMENTAL_CHANGE:
			_handle_environmental_change(event_data)
		EventTriggerType.STORY_EVENT:
			_handle_story_event(event_data)
		EventTriggerType.COMBAT_EVENT:
			_handle_combat_event(event_data)
		EventTriggerType.FORMATION_EVENT:
			_handle_formation_event(event_data)
		EventTriggerType.EMERGENCY_EVENT:
			_handle_emergency_event(event_data)
	
	# Update mission context
	_update_mission_context(event_type, event_data)

func _handle_phase_change(event_data: Dictionary) -> void:
	var new_phase: String = event_data.get("phase", "unknown")
	var old_phase: String = mission_context.get("current_phase", "")
	
	mission_context["current_phase"] = new_phase
	
	# Apply phase-specific AI adaptations
	match new_phase:
		"approach":
			_apply_global_ai_adaptation({
				"formation_type": "approach",
				"alertness_level": 0.6,
				"engagement_rules": "defensive",
				"comm_discipline": true
			})
		
		"engagement":
			_apply_global_ai_adaptation({
				"formation_type": "combat",
				"alertness_level": 1.0,
				"engagement_rules": "aggressive",
				"target_prioritization": "threat_based"
			})
		
		"extraction":
			_apply_global_ai_adaptation({
				"formation_type": "escort",
				"alertness_level": 0.8,
				"engagement_rules": "cover",
				"movement_priority": "speed"
			})
		
		"debriefing":
			_apply_global_ai_adaptation({
				"formation_type": "parade",
				"alertness_level": 0.2,
				"engagement_rules": "hold_fire",
				"movement_priority": "formation"
			})
	
	ai_context_updated.emit("phase_change", {"old_phase": old_phase, "new_phase": new_phase})

func _handle_objective_change(event_data: Dictionary) -> void:
	var objective_id: String = event_data.get("objective_id", "")
	var status: String = event_data.get("status", "")
	var affected_ships: Array = event_data.get("ships", [])
	
	# Update objective tracking
	if status == "completed":
		_remove_objective_from_context(objective_id)
	elif status == "failed":
		_handle_objective_failure(objective_id, affected_ships)
	elif status == "assigned":
		_handle_objective_assignment(objective_id, event_data)
	
	# Notify affected AI agents
	for ship_name in affected_ships:
		var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
		if ai_agent:
			var goal_system: Node = ai_agent.get_node_or_null("AIGoalSystem")
			if goal_system:
				goal_system.update_objective_status(objective_id, status)

func _handle_ship_event(event_data: Dictionary) -> void:
	var ship_name: String = event_data.get("ship_name", "")
	var event_type: String = event_data.get("event", "")
	
	match event_type:
		"damage_critical":
			_trigger_emergency_behavior(ship_name, "damage_critical")
		"shields_down":
			_adapt_ship_behavior(ship_name, {"evasion_priority": 1.0, "weapon_conservation": true})
		"weapon_malfunction":
			_adapt_ship_behavior(ship_name, {"target_selection": "opportunity", "engagement_range": "long"})
		"systems_nominal":
			_restore_ship_behavior(ship_name)

func _handle_environmental_change(event_data: Dictionary) -> void:
	var environment_type: String = event_data.get("type", "")
	var intensity: float = event_data.get("intensity", 0.0)
	var affected_area: Dictionary = event_data.get("area", {})
	
	match environment_type:
		"nebula":
			_apply_environmental_adaptation({
				"sensor_range": 0.5,
				"formation_spacing": 1.5,
				"communication_delay": 0.2
			})
		"asteroid_field":
			_apply_environmental_adaptation({
				"navigation_difficulty": intensity,
				"collision_avoidance": 1.0,
				"formation_type": "single_file"
			})
		"gravity_well":
			_apply_environmental_adaptation({
				"maneuver_penalty": intensity,
				"energy_drain": intensity * 0.5,
				"formation_stability": 1.0 - intensity
			})

func _handle_story_event(event_data: Dictionary) -> void:
	var story_event: String = event_data.get("event", "")
	var narrative_context: Dictionary = event_data.get("context", {})
	
	# Apply story-specific AI behaviors
	match story_event:
		"dramatic_revelation":
			_apply_narrative_behavior("surprise", 5.0)
		"ally_betrayal":
			_apply_narrative_behavior("confusion", 3.0)
		"enemy_reinforcements":
			_apply_narrative_behavior("concern", 10.0)
		"victory_speech":
			_apply_narrative_behavior("celebration", 15.0)

func _handle_combat_event(event_data: Dictionary) -> void:
	var combat_event: String = event_data.get("event", "")
	var participants: Array = event_data.get("participants", [])
	
	match combat_event:
		"engagement_start":
			_initiate_combat_coordination(participants)
		"target_destroyed":
			_update_threat_assessment(event_data)
		"retreat_called":
			_coordinate_tactical_withdrawal(participants)

func _handle_formation_event(event_data: Dictionary) -> void:
	var formation_id: String = event_data.get("formation_id", "")
	var event_type: String = event_data.get("event", "")
	
	match event_type:
		"formation_broken":
			_respond_to_formation_break(formation_id)
		"leader_lost":
			_handle_leadership_succession(formation_id)
		"member_rejoined":
			_welcome_formation_member(formation_id, event_data.get("ship_name", ""))

func _handle_emergency_event(event_data: Dictionary) -> void:
	var emergency_type: String = event_data.get("type", "")
	var severity: float = event_data.get("severity", 1.0)
	var affected_ships: Array = event_data.get("ships", [])
	
	# Immediate emergency response protocols
	for ship_name in affected_ships:
		_trigger_emergency_behavior(ship_name, emergency_type)
	
	# Coordinate emergency response
	_coordinate_emergency_response(emergency_type, severity, affected_ships)

func _apply_global_ai_adaptation(adaptations: Dictionary) -> void:
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	
	for agent in ai_agents:
		_apply_adaptations_to_agent(agent, adaptations)
	
	active_modifications["global"] = adaptations

func _apply_adaptations_to_agent(ai_agent: Node, adaptations: Dictionary) -> void:
	for key in adaptations:
		match key:
			"formation_type":
				var formation_manager: Node = ai_agent.get_node_or_null("FormationManager")
				if formation_manager:
					formation_manager.set_preferred_formation_type(adaptations[key])
			
			"alertness_level":
				ai_agent.alertness_level = adaptations[key]
			
			"engagement_rules":
				var tactical_doctrine: Node = ai_agent.get_node_or_null("TacticalDoctrine")
				if tactical_doctrine:
					tactical_doctrine.set_engagement_rules(adaptations[key])
			
			"target_prioritization":
				var threat_system: Node = ai_agent.get_node_or_null("ThreatAssessmentSystem")
				if threat_system:
					threat_system.set_prioritization_mode(adaptations[key])

func _trigger_emergency_behavior(ship_name: String, emergency_type: String) -> void:
	var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
	if not ai_agent:
		return
	
	# Override current behavior with emergency protocols
	var emergency_behavior: Dictionary = _get_emergency_behavior(emergency_type)
	_apply_adaptations_to_agent(ai_agent, emergency_behavior)
	
	ai_mission_response_triggered.emit(emergency_type, ship_name, "emergency_protocol_activated")

func _get_emergency_behavior(emergency_type: String) -> Dictionary:
	match emergency_type:
		"damage_critical":
			return {
				"engagement_rules": "defensive",
				"evasion_priority": 1.0,
				"formation_behavior": "independent",
				"target_selection": "nearest_threat"
			}
		"shields_down":
			return {
				"evasion_priority": 0.9,
				"engagement_range": "long",
				"formation_position": "rear"
			}
		"weapon_malfunction":
			return {
				"engagement_rules": "support_only",
				"formation_role": "support",
				"target_selection": "opportunity"
			}
		_:
			return {}

func _adapt_ship_behavior(ship_name: String, adaptations: Dictionary) -> void:
	var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
	if ai_agent:
		_apply_adaptations_to_agent(ai_agent, adaptations)
		active_modifications[ship_name] = adaptations

func _restore_ship_behavior(ship_name: String) -> void:
	var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
	if ai_agent:
		# Restore to default/mission-appropriate behavior
		var default_behavior: Dictionary = _get_default_behavior_for_phase(mission_context["current_phase"])
		_apply_adaptations_to_agent(ai_agent, default_behavior)
		active_modifications.erase(ship_name)

func _update_mission_context(event_type: String, event_data: Dictionary) -> void:
	match event_type:
		"threat_level_change":
			mission_context["threat_level"] = event_data.get("level", 0.0)
		"time_pressure_change":
			mission_context["time_pressure"] = event_data.get("pressure", 0.0)
		"environmental_update":
			mission_context["environmental_factors"] = event_data.get("factors", {})

func _categorize_event(event_type: String) -> EventTriggerType:
	if event_type.begins_with("phase_"):
		return EventTriggerType.MISSION_PHASE_CHANGE
	elif event_type.begins_with("objective_"):
		return EventTriggerType.OBJECTIVE_STATUS_CHANGE
	elif event_type.begins_with("ship_"):
		return EventTriggerType.SHIP_EVENT
	elif event_type.begins_with("env_"):
		return EventTriggerType.ENVIRONMENTAL_CHANGE
	elif event_type.begins_with("story_"):
		return EventTriggerType.STORY_EVENT
	elif event_type.begins_with("combat_"):
		return EventTriggerType.COMBAT_EVENT
	elif event_type.begins_with("formation_"):
		return EventTriggerType.FORMATION_EVENT
	elif event_type.begins_with("emergency_"):
		return EventTriggerType.EMERGENCY_EVENT
	else:
		return EventTriggerType.SHIP_EVENT  # Default

func _get_ai_agent_for_ship(ship_name: String) -> Node:
	var ship: Node3D = _get_ship_node(ship_name)
	if not ship:
		return null
	
	var ai_agent: Node = ship.get_node_or_null("WCSAIAgent")
	if not ai_agent:
		for child in ship.get_children():
			if child.has_method("get_current_ai_state"):
				ai_agent = child
				break
	
	return ai_agent

func _get_ship_node(ship_name: String) -> Node3D:
	var ships: Array = get_tree().get_nodes_in_group("ships")
	for ship in ships:
		if ship.name == ship_name:
			return ship
	return null

func _get_default_behavior_for_phase(phase: String) -> Dictionary:
	match phase:
		"approach":
			return {"alertness_level": 0.6, "engagement_rules": "defensive"}
		"engagement":
			return {"alertness_level": 1.0, "engagement_rules": "aggressive"}
		"extraction":
			return {"alertness_level": 0.8, "engagement_rules": "cover"}
		_:
			return {"alertness_level": 0.5, "engagement_rules": "standard"}

## Mission Context Access
func get_mission_context() -> Dictionary:
	return mission_context.duplicate()

func get_active_modifications() -> Dictionary:
	return active_modifications.duplicate()

## Event Processing
func _on_phase_transition(old_phase: String, new_phase: String) -> void:
	_handle_phase_change({"phase": new_phase, "old_phase": old_phase})

func _on_objective_updated(objective_id: String, status: String, data: Dictionary) -> void:
	_handle_objective_change({"objective_id": objective_id, "status": status, "data": data})

func _on_sexp_evaluated(expression: String, result: SexpResult) -> void:
	# Process SEXP results that affect AI behavior
	if expression.begins_with("ai-"):
		# This is an AI command, track its execution
		var command_data: Dictionary = {
			"expression": expression,
			"result": result,
			"timestamp": Time.get_ticks_msec()
		}
		_process_ai_command_result(command_data)

func _process_ai_command_result(command_data: Dictionary) -> void:
	# Log AI command execution for mission reporting
	var expression: String = command_data["expression"]
	var result: SexpResult = command_data["result"]
	
	if result.is_error():
		push_error("AI command failed: " + expression + " - " + result.error_message)
	else:
		# Track successful AI modifications
		active_modifications["sexp_commands"] = active_modifications.get("sexp_commands", [])
		active_modifications["sexp_commands"].append(command_data)

func _on_ai_state_changed(agent: Node, old_state: String, new_state: String) -> void:
	# Track AI state changes for mission analysis
	ai_context_updated.emit("ai_state_change", {
		"agent": agent.name,
		"old_state": old_state,
		"new_state": new_state,
		"timestamp": Time.get_ticks_msec()
	})

## Support Functions
func _remove_objective_from_context(objective_id: String) -> void:
	mission_context["primary_objectives"] = mission_context["primary_objectives"].filter(
		func(obj): return obj.get("id") != objective_id
	)
	mission_context["secondary_objectives"] = mission_context["secondary_objectives"].filter(
		func(obj): return obj.get("id") != objective_id
	)

func _handle_objective_failure(objective_id: String, affected_ships: Array) -> void:
	# Apply failure-response behaviors
	for ship_name in affected_ships:
		_adapt_ship_behavior(ship_name, {
			"morale_penalty": 0.2,
			"aggression_modifier": -0.1,
			"formation_discipline": 0.8
		})

func _handle_objective_assignment(objective_id: String, event_data: Dictionary) -> void:
	var objective_type: String = event_data.get("type", "unknown")
	var assigned_ships: Array = event_data.get("ships", [])
	
	for ship_name in assigned_ships:
		mission_ai_objective_assigned.emit(ship_name, objective_type, event_data)

## More support functions for complex behaviors
func _apply_narrative_behavior(emotion: String, duration: float) -> void:
	# Apply emotion-based AI behavior modifications
	var emotional_behavior: Dictionary = _get_emotional_behavior(emotion)
	_apply_global_ai_adaptation(emotional_behavior)
	
	# Schedule restoration after duration
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		_apply_global_ai_adaptation(_get_default_behavior_for_phase(mission_context["current_phase"]))

func _get_emotional_behavior(emotion: String) -> Dictionary:
	match emotion:
		"surprise":
			return {"reaction_delay": 0.5, "formation_hold": true}
		"confusion":
			return {"decision_delay": 0.3, "communication_increase": true}
		"concern":
			return {"alertness_level": 0.9, "formation_tighten": true}
		"celebration":
			return {"formation_type": "victory", "weapon_discipline": "hold"}
		_:
			return {}

func _initiate_combat_coordination(participants: Array) -> void:
	# Coordinate combat behavior across multiple AI agents
	for ship_name in participants:
		var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
		if ai_agent:
			var combat_coordinator: Node = ai_agent.get_node_or_null("CombatCoordinator")
			if combat_coordinator:
				combat_coordinator.enter_coordinated_combat(participants)

func _update_threat_assessment(event_data: Dictionary) -> void:
	var destroyed_target: String = event_data.get("target", "")
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	
	for agent in ai_agents:
		var threat_system: Node = agent.get_node_or_null("ThreatAssessmentSystem")
		if threat_system:
			threat_system.remove_target(destroyed_target)

func _coordinate_tactical_withdrawal(participants: Array) -> void:
	# Implement coordinated retreat behavior
	for ship_name in participants:
		_adapt_ship_behavior(ship_name, {
			"engagement_rules": "disengage",
			"formation_behavior": "cover_retreat",
			"movement_priority": "escape"
		})

func _respond_to_formation_break(formation_id: String) -> void:
	# Handle formation disruption
	var formation_manager: Node = get_node_or_null("/root/AIManager/FormationManager")
	if formation_manager:
		var members: Array = formation_manager.get_formation_members(formation_id)
		for member in members:
			_adapt_ship_behavior(member.name, {
				"formation_behavior": "regroup",
				"priority": "formation_integrity"
			})

func _handle_leadership_succession(formation_id: String) -> void:
	# Handle formation leader change
	var formation_manager: Node = get_node_or_null("/root/AIManager/FormationManager")
	if formation_manager:
		formation_manager.elect_new_leader(formation_id)

func _welcome_formation_member(formation_id: String, ship_name: String) -> void:
	# Welcome rejoining formation member
	_adapt_ship_behavior(ship_name, {
		"formation_behavior": "rejoin",
		"movement_priority": "formation"
	})

func _coordinate_emergency_response(emergency_type: String, severity: float, affected_ships: Array) -> void:
	# Coordinate fleet-wide emergency response
	var response_plan: Dictionary = _get_emergency_response_plan(emergency_type, severity)
	
	# Apply response to all ships
	var all_ships: Array = get_tree().get_nodes_in_group("ships")
	for ship in all_ships:
		if ship.name not in affected_ships:
			_adapt_ship_behavior(ship.name, response_plan["support_behavior"])
	
	# Apply specific behavior to affected ships
	for ship_name in affected_ships:
		_adapt_ship_behavior(ship_name, response_plan["affected_behavior"])

func _get_emergency_response_plan(emergency_type: String, severity: float) -> Dictionary:
	match emergency_type:
		"ship_critical":
			return {
				"support_behavior": {"formation_role": "escort", "priority": "protect"},
				"affected_behavior": {"survival_mode": true, "assistance_needed": true}
			}
		"area_hazard":
			return {
				"support_behavior": {"formation_type": "safe_distance", "navigation": "cautious"},
				"affected_behavior": {"evasion_priority": 1.0, "assistance_request": true}
			}
		_:
			return {
				"support_behavior": {"alertness_level": 0.8},
				"affected_behavior": {"caution_level": 1.0}
			}

func _apply_environmental_adaptation(adaptations: Dictionary) -> void:
	# Apply environmental adaptations to all AI agents
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	
	for agent in ai_agents:
		var navigation_system: Node = agent.get_node_or_null("NavigationController")
		if navigation_system:
			navigation_system.apply_environmental_modifiers(adaptations)
		
		var formation_manager: Node = agent.get_node_or_null("FormationManager")
		if formation_manager:
			formation_manager.apply_environmental_constraints(adaptations)