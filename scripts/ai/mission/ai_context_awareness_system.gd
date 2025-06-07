class_name AIContextAwarenessSystem
extends Node

## AI Context Awareness System
##
## Provides contextual awareness for AI agents based on mission phase, objectives,
## and narrative requirements. This system enables AI to adapt behavior naturally
## to changing mission conditions while maintaining authentic WCS tactical behavior.

signal context_updated(context_type: String, old_context: Dictionary, new_context: Dictionary)
signal behavioral_adaptation_applied(agent_name: String, adaptation_type: String, parameters: Dictionary)
signal narrative_behavior_triggered(event_name: String, affected_agents: Array, duration: float)

## Context categories for AI adaptation
enum ContextType {
	MISSION_PHASE,
	OBJECTIVE_STATUS,
	NARRATIVE_STATE,
	ENVIRONMENTAL,
	TACTICAL_SITUATION,
	TEAM_STATUS,
	TIME_PRESSURE,
	THREAT_LEVEL
}

## Mission context state
var mission_contexts: Dictionary = {}

## Narrative context tracking
var narrative_state: Dictionary = {
	"current_act": 1,
	"scene_tension": 0.5,
	"character_relationships": {},
	"plot_momentum": 0.5,
	"emotional_tone": "neutral"
}

## Environmental context factors
var environmental_context: Dictionary = {
	"hazards": [],
	"visibility": 1.0,
	"gravity_effects": 1.0,
	"electromagnetic_interference": 0.0,
	"asteroid_density": 0.0,
	"nebula_effects": {}
}

## Tactical context analysis
var tactical_context: Dictionary = {
	"threat_assessment": {},
	"force_balance": 0.5,
	"strategic_position": "neutral",
	"engagement_range": "medium",
	"formation_effectiveness": 1.0
}

## Time-based context
var temporal_context: Dictionary = {
	"mission_time_elapsed": 0.0,
	"objective_deadlines": {},
	"time_pressure_level": 0.0,
	"phase_duration": 0.0
}

## Context adaptation rules
var adaptation_rules: Dictionary = {}

## Active adaptations tracking
var active_adaptations: Dictionary = {}

func _ready() -> void:
	_initialize_contexts()
	_setup_adaptation_rules()
	_connect_to_systems()

func _initialize_contexts() -> void:
	mission_contexts[ContextType.MISSION_PHASE] = {
		"current_phase": "briefing",
		"phase_objectives": [],
		"phase_constraints": {},
		"expected_duration": 0.0
	}
	
	mission_contexts[ContextType.OBJECTIVE_STATUS] = {
		"primary_objectives": [],
		"secondary_objectives": [],
		"completed_objectives": [],
		"failed_objectives": [],
		"objective_priorities": {}
	}
	
	mission_contexts[ContextType.THREAT_LEVEL] = {
		"overall_threat": 0.0,
		"immediate_threats": [],
		"potential_threats": [],
		"threat_trajectory": "stable"
	}
	
	mission_contexts[ContextType.TEAM_STATUS] = {
		"team_health": 1.0,
		"team_morale": 1.0,
		"formation_integrity": 1.0,
		"communication_quality": 1.0,
		"coordination_effectiveness": 1.0
	}

func _setup_adaptation_rules() -> void:
	adaptation_rules = {
		ContextType.MISSION_PHASE: {
			"briefing": {
				"formation_behavior": "parade",
				"alertness_level": 0.2,
				"communication_style": "formal",
				"movement_restrictions": true
			},
			"approach": {
				"formation_behavior": "tactical",
				"alertness_level": 0.6,
				"communication_style": "tactical",
				"stealth_emphasis": true
			},
			"engagement": {
				"formation_behavior": "combat",
				"alertness_level": 1.0,
				"communication_style": "combat",
				"aggression_modifier": 1.2
			},
			"extraction": {
				"formation_behavior": "escort",
				"alertness_level": 0.8,
				"communication_style": "urgent",
				"speed_priority": true
			},
			"debriefing": {
				"formation_behavior": "ceremonial",
				"alertness_level": 0.3,
				"communication_style": "casual",
				"weapon_discipline": "safe"
			}
		},
		
		ContextType.NARRATIVE_STATE: {
			"high_tension": {
				"reaction_sensitivity": 1.5,
				"formation_tightness": 1.3,
				"communication_frequency": 1.4
			},
			"dramatic_moment": {
				"response_delay": 0.5,
				"formation_hold": true,
				"attention_focus": "narrative"
			},
			"comic_relief": {
				"formation_relaxation": 0.8,
				"communication_casualness": 1.2,
				"alertness_reduction": 0.9
			}
		},
		
		ContextType.THREAT_LEVEL: {
			"low": {
				"patrol_spacing": 1.2,
				"engagement_range": "standard",
				"formation_flexibility": 1.1
			},
			"medium": {
				"patrol_spacing": 1.0,
				"engagement_range": "adaptive",
				"formation_discipline": 1.1
			},
			"high": {
				"patrol_spacing": 0.8,
				"engagement_range": "aggressive",
				"formation_discipline": 1.3
			},
			"critical": {
				"emergency_protocols": true,
				"formation_type": "defensive",
				"engagement_rules": "survival"
			}
		}
	}

func _connect_to_systems() -> void:
	# Connect to mission event system
	if has_node("/root/MissionEventManager"):
		var mission_manager: Node = get_node("/root/MissionEventManager")
		mission_manager.mission_phase_changed.connect(_on_mission_phase_changed)
		mission_manager.objective_updated.connect(_on_objective_updated)
		mission_manager.narrative_event.connect(_on_narrative_event)
	
	# Connect to environmental systems
	if has_node("/root/EnvironmentManager"):
		var env_manager: Node = get_node("/root/EnvironmentManager")
		env_manager.environmental_change.connect(_on_environmental_change)
	
	# Connect to tactical analysis
	if has_node("/root/TacticalAnalyzer"):
		var tactical_analyzer: Node = get_node("/root/TacticalAnalyzer")
		tactical_analyzer.tactical_situation_changed.connect(_on_tactical_situation_changed)

## Context Update Methods
func update_mission_phase_context(phase: String, objectives: Array = [], constraints: Dictionary = {}) -> void:
	var old_context: Dictionary = mission_contexts[ContextType.MISSION_PHASE].duplicate()
	
	mission_contexts[ContextType.MISSION_PHASE]["current_phase"] = phase
	mission_contexts[ContextType.MISSION_PHASE]["phase_objectives"] = objectives
	mission_contexts[ContextType.MISSION_PHASE]["phase_constraints"] = constraints
	mission_contexts[ContextType.MISSION_PHASE]["phase_start_time"] = Time.get_ticks_msec()
	
	context_updated.emit("mission_phase", old_context, mission_contexts[ContextType.MISSION_PHASE])
	_apply_phase_adaptations(phase)

func update_narrative_context(event_type: String, emotional_tone: String, tension_level: float) -> void:
	var old_state: Dictionary = narrative_state.duplicate()
	
	narrative_state["emotional_tone"] = emotional_tone
	narrative_state["scene_tension"] = tension_level
	narrative_state["last_event"] = event_type
	narrative_state["event_timestamp"] = Time.get_ticks_msec()
	
	context_updated.emit("narrative", old_state, narrative_state)
	_apply_narrative_adaptations(event_type, emotional_tone, tension_level)

func update_environmental_context(environmental_factors: Dictionary) -> void:
	var old_context: Dictionary = environmental_context.duplicate()
	
	for key in environmental_factors:
		environmental_context[key] = environmental_factors[key]
	
	context_updated.emit("environmental", old_context, environmental_context)
	_apply_environmental_adaptations(environmental_factors)

func update_tactical_context(threat_level: float, force_balance: float, engagement_parameters: Dictionary) -> void:
	var old_context: Dictionary = tactical_context.duplicate()
	
	tactical_context["threat_assessment"]["overall"] = threat_level
	tactical_context["force_balance"] = force_balance
	tactical_context.merge(engagement_parameters)
	
	mission_contexts[ContextType.THREAT_LEVEL]["overall_threat"] = threat_level
	
	context_updated.emit("tactical", old_context, tactical_context)
	_apply_tactical_adaptations(threat_level, force_balance)

func update_temporal_context(time_pressure: float, deadlines: Dictionary = {}) -> void:
	temporal_context["time_pressure_level"] = time_pressure
	temporal_context["objective_deadlines"].merge(deadlines)
	temporal_context["mission_time_elapsed"] = Time.get_ticks_msec() / 1000.0
	
	mission_contexts[ContextType.TIME_PRESSURE] = {
		"pressure_level": time_pressure,
		"active_deadlines": deadlines,
		"urgency_factor": _calculate_urgency_factor()
	}
	
	_apply_temporal_adaptations(time_pressure)

## Adaptation Application Methods
func _apply_phase_adaptations(phase: String) -> void:
	var phase_rules: Dictionary = adaptation_rules[ContextType.MISSION_PHASE].get(phase, {})
	if phase_rules.is_empty():
		return
	
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	for agent in ai_agents:
		_apply_adaptations_to_agent(agent, phase_rules, "phase_" + phase)
	
	behavioral_adaptation_applied.emit("all_agents", "mission_phase", phase_rules)

func _apply_narrative_adaptations(event_type: String, emotional_tone: String, tension_level: float) -> void:
	var narrative_rules: Dictionary = _generate_narrative_adaptation_rules(event_type, emotional_tone, tension_level)
	
	var affected_agents: Array = _get_narrative_affected_agents(event_type)
	for agent in affected_agents:
		_apply_adaptations_to_agent(agent, narrative_rules, "narrative_" + event_type)
	
	# Apply temporary behavioral modifications
	var duration: float = _calculate_narrative_duration(event_type, tension_level)
	_schedule_adaptation_removal("narrative_" + event_type, duration)
	
	narrative_behavior_triggered.emit(event_type, affected_agents.map(func(a): return a.name), duration)

func _apply_environmental_adaptations(environmental_factors: Dictionary) -> void:
	var adaptation_rules_env: Dictionary = _generate_environmental_adaptation_rules(environmental_factors)
	
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	for agent in ai_agents:
		_apply_adaptations_to_agent(agent, adaptation_rules_env, "environmental")

func _apply_tactical_adaptations(threat_level: float, force_balance: float) -> void:
	var threat_category: String = _categorize_threat_level(threat_level)
	var tactical_rules: Dictionary = adaptation_rules[ContextType.THREAT_LEVEL].get(threat_category, {})
	
	# Add force balance considerations
	tactical_rules["aggression_modifier"] = force_balance
	tactical_rules["risk_tolerance"] = force_balance * 0.8
	
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	for agent in ai_agents:
		_apply_adaptations_to_agent(agent, tactical_rules, "tactical")

func _apply_temporal_adaptations(time_pressure: float) -> void:
	var urgency_rules: Dictionary = {
		"movement_speed_modifier": 1.0 + (time_pressure * 0.5),
		"decision_speed_modifier": 1.0 + (time_pressure * 0.3),
		"formation_discipline": max(0.5, 1.0 - (time_pressure * 0.3)),
		"risk_tolerance": 1.0 + (time_pressure * 0.4)
	}
	
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	for agent in ai_agents:
		_apply_adaptations_to_agent(agent, urgency_rules, "temporal")

func _apply_adaptations_to_agent(ai_agent: Node, adaptations: Dictionary, adaptation_id: String) -> void:
	for key in adaptations:
		match key:
			"formation_behavior":
				_modify_formation_behavior(ai_agent, adaptations[key])
			"alertness_level":
				ai_agent.alertness_level = adaptations[key]
			"communication_style":
				_modify_communication_style(ai_agent, adaptations[key])
			"aggression_modifier":
				ai_agent.aggression_level *= adaptations[key]
			"formation_tightness":
				_modify_formation_spacing(ai_agent, adaptations[key])
			"reaction_sensitivity":
				_modify_reaction_timing(ai_agent, adaptations[key])
			"movement_speed_modifier":
				_modify_movement_parameters(ai_agent, {"speed_modifier": adaptations[key]})
			"formation_discipline":
				_modify_formation_discipline(ai_agent, adaptations[key])
			"engagement_rules":
				_modify_engagement_rules(ai_agent, adaptations[key])
			"weapon_discipline":
				_modify_weapon_discipline(ai_agent, adaptations[key])
	
	# Track active adaptation
	if not active_adaptations.has(ai_agent.name):
		active_adaptations[ai_agent.name] = {}
	active_adaptations[ai_agent.name][adaptation_id] = {
		"rules": adaptations,
		"timestamp": Time.get_ticks_msec(),
		"active": true
	}

## Helper Methods for Adaptation Application
func _modify_formation_behavior(ai_agent: Node, behavior_type: String) -> void:
	var formation_manager: Node = ai_agent.get_node_or_null("FormationManager")
	if formation_manager:
		formation_manager.set_behavior_mode(behavior_type)

func _modify_communication_style(ai_agent: Node, style: String) -> void:
	var comm_system: Node = ai_agent.get_node_or_null("CommunicationSystem")
	if comm_system:
		comm_system.set_communication_style(style)

func _modify_formation_spacing(ai_agent: Node, multiplier: float) -> void:
	var formation_manager: Node = ai_agent.get_node_or_null("FormationManager")
	if formation_manager:
		formation_manager.modify_spacing_multiplier(multiplier)

func _modify_reaction_timing(ai_agent: Node, sensitivity: float) -> void:
	ai_agent.decision_frequency *= sensitivity
	var behavior_tree: Node = ai_agent.get_node_or_null("BehaviorTree")
	if behavior_tree:
		behavior_tree.update_frequency *= sensitivity

func _modify_movement_parameters(ai_agent: Node, parameters: Dictionary) -> void:
	var ship_controller: Node = ai_agent.get_node_or_null("ShipController")
	if ship_controller:
		ship_controller.apply_movement_modifiers(parameters)

func _modify_formation_discipline(ai_agent: Node, discipline_level: float) -> void:
	var formation_manager: Node = ai_agent.get_node_or_null("FormationManager")
	if formation_manager:
		formation_manager.set_discipline_level(discipline_level)

func _modify_engagement_rules(ai_agent: Node, rules: String) -> void:
	var tactical_doctrine: Node = ai_agent.get_node_or_null("TacticalDoctrine")
	if tactical_doctrine:
		tactical_doctrine.set_engagement_rules(rules)

func _modify_weapon_discipline(ai_agent: Node, discipline: String) -> void:
	var weapon_system: Node = ai_agent.get_node_or_null("WeaponSystem")
	if weapon_system:
		weapon_system.set_firing_discipline(discipline)

## Context Analysis Methods
func analyze_mission_context() -> Dictionary:
	var analysis: Dictionary = {
		"phase_appropriateness": _evaluate_phase_behavior_match(),
		"narrative_alignment": _evaluate_narrative_alignment(),
		"environmental_awareness": _evaluate_environmental_adaptation(),
		"tactical_responsiveness": _evaluate_tactical_responsiveness(),
		"temporal_pressure_handling": _evaluate_temporal_adaptation()
	}
	
	analysis["overall_context_score"] = _calculate_overall_context_score(analysis)
	return analysis

func _evaluate_phase_behavior_match() -> float:
	var current_phase: String = mission_contexts[ContextType.MISSION_PHASE]["current_phase"]
	var phase_start: int = mission_contexts[ContextType.MISSION_PHASE].get("phase_start_time", 0)
	var adaptation_delay: float = (Time.get_ticks_msec() - phase_start) / 1000.0
	
	# Score based on how quickly and appropriately AI adapted to phase change
	return max(0.0, 1.0 - (adaptation_delay / 5.0))  # Penalize slow adaptation

func _evaluate_narrative_alignment() -> float:
	var tension: float = narrative_state["scene_tension"]
	var tone: String = narrative_state["emotional_tone"]
	
	# Check if AI behavior matches narrative requirements
	return _calculate_narrative_behavior_match(tension, tone)

func _evaluate_environmental_adaptation() -> float:
	var adaptation_score: float = 0.0
	var factor_count: int = 0
	
	for factor in environmental_context:
		if environmental_context[factor] != 0:
			adaptation_score += _get_adaptation_score_for_factor(factor)
			factor_count += 1
	
	return adaptation_score / max(1, factor_count)

func _evaluate_tactical_responsiveness() -> float:
	var threat_level: float = tactical_context["threat_assessment"].get("overall", 0.0)
	var response_appropriateness: float = _measure_threat_response_quality(threat_level)
	return response_appropriateness

func _evaluate_temporal_adaptation() -> float:
	var time_pressure: float = temporal_context["time_pressure_level"]
	var urgency_response: float = _measure_urgency_response_quality(time_pressure)
	return urgency_response

## Utility Methods
func _generate_narrative_adaptation_rules(event_type: String, emotional_tone: String, tension_level: float) -> Dictionary:
	var base_rules: Dictionary = adaptation_rules[ContextType.NARRATIVE_STATE].get(emotional_tone, {})
	
	# Modify rules based on tension level
	var modified_rules: Dictionary = base_rules.duplicate()
	for key in modified_rules:
		if modified_rules[key] is float:
			modified_rules[key] *= (1.0 + tension_level * 0.3)
	
	# Add event-specific modifications
	match event_type:
		"character_death":
			modified_rules["formation_mourning"] = true
			modified_rules["alertness_reduction"] = 0.7
		"surprise_attack":
			modified_rules["reaction_speed"] = 2.0
			modified_rules["formation_scatter"] = true
		"mission_success":
			modified_rules["celebration_behavior"] = true
			modified_rules["weapon_discipline"] = "safe"
	
	return modified_rules

func _generate_environmental_adaptation_rules(environmental_factors: Dictionary) -> Dictionary:
	var rules: Dictionary = {}
	
	for factor in environmental_factors:
		match factor:
			"visibility":
				rules["sensor_range_modifier"] = environmental_factors[factor]
				rules["formation_spacing_modifier"] = 2.0 - environmental_factors[factor]
			"gravity_effects":
				rules["maneuver_difficulty"] = 2.0 - environmental_factors[factor]
				rules["energy_consumption"] = 2.0 - environmental_factors[factor]
			"electromagnetic_interference":
				rules["communication_quality"] = 1.0 - environmental_factors[factor]
				rules["targeting_accuracy"] = 1.0 - (environmental_factors[factor] * 0.3)
			"asteroid_density":
				rules["collision_avoidance_priority"] = environmental_factors[factor]
				rules["formation_flexibility"] = 1.0 + environmental_factors[factor]
	
	return rules

func _get_narrative_affected_agents(event_type: String) -> Array:
	# Determine which agents are affected by narrative events
	match event_type:
		"character_death", "surprise_attack":
			return get_tree().get_nodes_in_group("ai_agents")  # All agents
		"dialogue_scene":
			return _get_agents_in_vicinity(1000.0)  # Nearby agents
		"personal_revelation":
			return _get_specific_character_agents(event_type)
		_:
			return get_tree().get_nodes_in_group("ai_agents")

func _get_agents_in_vicinity(radius: float) -> Array:
	# Implementation would find agents within radius
	return get_tree().get_nodes_in_group("ai_agents")

func _get_specific_character_agents(event_type: String) -> Array:
	# Implementation would find specific character agents
	return []

func _calculate_narrative_duration(event_type: String, tension_level: float) -> float:
	var base_duration: float = 5.0  # Base 5 seconds
	
	match event_type:
		"dialogue_scene":
			return base_duration * 2.0
		"dramatic_revelation":
			return base_duration * (1.0 + tension_level)
		"action_sequence":
			return base_duration * 0.5
		_:
			return base_duration

func _schedule_adaptation_removal(adaptation_id: String, duration: float) -> void:
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		_remove_adaptation(adaptation_id)

func _remove_adaptation(adaptation_id: String) -> void:
	for agent_name in active_adaptations:
		if active_adaptations[agent_name].has(adaptation_id):
			active_adaptations[agent_name][adaptation_id]["active"] = false
			# Apply removal logic here
			_restore_default_behavior(agent_name, adaptation_id)

func _restore_default_behavior(agent_name: String, adaptation_id: String) -> void:
	var agent: Node = get_tree().get_nodes_in_group("ai_agents").filter(
		func(a): return a.name == agent_name
	)[0] if not get_tree().get_nodes_in_group("ai_agents").is_empty() else null
	
	if agent:
		# Restore default behaviors based on current context
		var default_rules: Dictionary = _get_default_behavior_for_current_context()
		_apply_adaptations_to_agent(agent, default_rules, "default_restore")

func _get_default_behavior_for_current_context() -> Dictionary:
	var current_phase: String = mission_contexts[ContextType.MISSION_PHASE]["current_phase"]
	return adaptation_rules[ContextType.MISSION_PHASE].get(current_phase, {})

func _categorize_threat_level(threat_level: float) -> String:
	if threat_level >= 0.8:
		return "critical"
	elif threat_level >= 0.6:
		return "high"
	elif threat_level >= 0.3:
		return "medium"
	else:
		return "low"

func _calculate_urgency_factor() -> float:
	var pressure: float = temporal_context["time_pressure_level"]
	var deadline_pressure: float = 0.0
	
	for deadline in temporal_context["objective_deadlines"]:
		var time_remaining: float = temporal_context["objective_deadlines"][deadline] - temporal_context["mission_time_elapsed"]
		if time_remaining > 0:
			deadline_pressure = max(deadline_pressure, 1.0 - (time_remaining / 300.0))  # 5 minutes baseline
	
	return max(pressure, deadline_pressure)

## Event Handlers
func _on_mission_phase_changed(old_phase: String, new_phase: String) -> void:
	update_mission_phase_context(new_phase)

func _on_objective_updated(objective_id: String, status: String, data: Dictionary) -> void:
	var obj_context: Dictionary = mission_contexts[ContextType.OBJECTIVE_STATUS]
	
	match status:
		"assigned":
			obj_context["primary_objectives"].append({"id": objective_id, "data": data})
		"completed":
			obj_context["completed_objectives"].append({"id": objective_id, "timestamp": Time.get_ticks_msec()})
		"failed":
			obj_context["failed_objectives"].append({"id": objective_id, "timestamp": Time.get_ticks_msec()})
	
	context_updated.emit("objective", {}, obj_context)

func _on_narrative_event(event_type: String, event_data: Dictionary) -> void:
	var emotional_tone: String = event_data.get("emotional_tone", "neutral")
	var tension_level: float = event_data.get("tension_level", 0.5)
	update_narrative_context(event_type, emotional_tone, tension_level)

func _on_environmental_change(change_type: String, change_data: Dictionary) -> void:
	update_environmental_context(change_data)

func _on_tactical_situation_changed(situation_data: Dictionary) -> void:
	var threat_level: float = situation_data.get("threat_level", 0.0)
	var force_balance: float = situation_data.get("force_balance", 0.5)
	update_tactical_context(threat_level, force_balance, situation_data)

## Context Query Methods
func get_current_context(context_type: ContextType) -> Dictionary:
	return mission_contexts.get(context_type, {}).duplicate()

func get_narrative_context() -> Dictionary:
	return narrative_state.duplicate()

func get_environmental_context() -> Dictionary:
	return environmental_context.duplicate()

func get_tactical_context() -> Dictionary:
	return tactical_context.duplicate()

func get_temporal_context() -> Dictionary:
	return temporal_context.duplicate()

func get_active_adaptations_for_agent(agent_name: String) -> Dictionary:
	return active_adaptations.get(agent_name, {}).duplicate()

func is_adaptation_active(agent_name: String, adaptation_id: String) -> bool:
	return active_adaptations.get(agent_name, {}).get(adaptation_id, {}).get("active", false)

## Context Performance Evaluation
func _calculate_overall_context_score(analysis: Dictionary) -> float:
	var total_score: float = 0.0
	var score_count: int = 0
	
	for key in analysis:
		if analysis[key] is float:
			total_score += analysis[key]
			score_count += 1
	
	return total_score / max(1, score_count)

func _calculate_narrative_behavior_match(tension: float, tone: String) -> float:
	# Evaluate how well current AI behavior matches narrative requirements
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	var total_match: float = 0.0
	
	for agent in ai_agents:
		var agent_behavior: Dictionary = _analyze_agent_behavior(agent)
		var expected_behavior: Dictionary = _get_expected_narrative_behavior(tension, tone)
		total_match += _compare_behaviors(agent_behavior, expected_behavior)
	
	return total_match / max(1, ai_agents.size())

func _analyze_agent_behavior(agent: Node) -> Dictionary:
	return {
		"alertness": agent.get("alertness_level", 0.5),
		"aggression": agent.get("aggression_level", 0.5),
		"formation_discipline": agent.get("formation_precision", 1.0),
		"reaction_speed": agent.get("decision_frequency", 0.1)
	}

func _get_expected_narrative_behavior(tension: float, tone: String) -> Dictionary:
	var base_behavior: Dictionary = {
		"alertness": 0.5,
		"aggression": 0.5,
		"formation_discipline": 1.0,
		"reaction_speed": 0.1
	}
	
	# Modify based on tension
	base_behavior["alertness"] = min(1.0, 0.3 + tension * 0.7)
	base_behavior["reaction_speed"] = max(0.05, 0.15 - tension * 0.05)
	
	# Modify based on emotional tone
	match tone:
		"tense":
			base_behavior["formation_discipline"] *= 1.2
		"relaxed":
			base_behavior["formation_discipline"] *= 0.8
		"aggressive":
			base_behavior["aggression"] *= 1.3
		"cautious":
			base_behavior["aggression"] *= 0.7
	
	return base_behavior

func _compare_behaviors(actual: Dictionary, expected: Dictionary) -> float:
	var match_score: float = 0.0
	var comparison_count: int = 0
	
	for key in expected:
		if actual.has(key):
			var difference: float = abs(actual[key] - expected[key])
			match_score += max(0.0, 1.0 - difference)
			comparison_count += 1
	
	return match_score / max(1, comparison_count)

func _get_adaptation_score_for_factor(factor: String) -> float:
	# Evaluate how well AI has adapted to specific environmental factors
	return 0.8  # Placeholder implementation

func _measure_threat_response_quality(threat_level: float) -> float:
	# Evaluate quality of AI response to threat levels
	return 0.8  # Placeholder implementation

func _measure_urgency_response_quality(time_pressure: float) -> float:
	# Evaluate quality of AI response to time pressure
	return 0.8  # Placeholder implementation