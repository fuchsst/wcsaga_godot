class_name FormationAdaptationEngine
extends Node

## Formation adaptation engine for dynamic formation management.
## Evaluates tactical situations and recommends formation adaptations with learning capabilities.

signal adaptation_evaluated(formation_id: String, adaptation_analysis: Dictionary)
signal emergency_adaptation_triggered(formation_id: String, threat_level: float, recommended_formation: int)
signal learning_pattern_discovered(pattern_type: String, effectiveness_improvement: float)
signal adaptation_strategy_updated(formation_id: String, new_strategy: Dictionary)

## Adaptation trigger types
enum AdaptationTrigger {
	THREAT_ESCALATION,     ## Threat level increased significantly
	TACTICAL_DISADVANTAGE, ## Current formation is ineffective
	DAMAGE_ACCUMULATION,   ## Ships damaged, need protective formation
	TERRAIN_CHANGE,        ## Environment changed requiring adaptation
	MISSION_PHASE_CHANGE,  ## Mission phase shifted requiring different formation
	EMERGENCY_RESPONSE,    ## Immediate threat requiring emergency formation
	OPPORTUNITY_EXPLOIT,   ## Tactical opportunity to exploit
	ENERGY_CONSERVATION,   ## Need to conserve energy/resources
	FORMATION_BREAKDOWN,   ## Current formation integrity compromised
	LEARNING_OPTIMIZATION  ## AI learning suggests better formation
}

## Adaptation strategies
enum AdaptationStrategy {
	REACTIVE,      ## React to immediate threats and changes
	PROACTIVE,     ## Anticipate and prepare for likely scenarios
	CONSERVATIVE,  ## Minimize risk, prefer defensive formations
	AGGRESSIVE,    ## Maximize offensive potential
	BALANCED,      ## Balance offensive and defensive considerations
	LEARNING       ## Use AI learning to optimize adaptations
}

## Learning system for formation effectiveness
class FormationLearningSystem extends RefCounted:
	var formation_performance_data: Dictionary = {}
	var adaptation_success_rates: Dictionary = {}
	var tactical_pattern_library: Dictionary = {}
	var learning_enabled: bool = true
	var learning_rate: float = 0.1
	var pattern_recognition_threshold: float = 0.75
	
	func _init() -> void:
		_initialize_learning_system()
	
	func _initialize_learning_system() -> void:
		formation_performance_data = {}
		adaptation_success_rates = {}
		tactical_pattern_library = {}
	
	func record_adaptation_outcome(formation_type: DynamicFormationManager.AdvancedFormationType, tactical_context: Dictionary, effectiveness_before: float, effectiveness_after: float) -> void:
		if not learning_enabled:
			return
		
		var context_signature: String = _generate_context_signature(tactical_context)
		var success_rate: float = (effectiveness_after - effectiveness_before) / max(effectiveness_before, 0.1)
		
		# Update performance data
		if not formation_performance_data.has(formation_type):
			formation_performance_data[formation_type] = {}
		
		if not formation_performance_data[formation_type].has(context_signature):
			formation_performance_data[formation_type][context_signature] = {
				"total_adaptations": 0,
				"average_success_rate": 0.0,
				"best_success_rate": -1.0,
				"worst_success_rate": 1.0,
				"confidence": 0.0
			}
		
		var data: Dictionary = formation_performance_data[formation_type][context_signature]
		data["total_adaptations"] += 1
		data["average_success_rate"] = ((data["average_success_rate"] * (data["total_adaptations"] - 1)) + success_rate) / data["total_adaptations"]
		data["best_success_rate"] = max(data["best_success_rate"], success_rate)
		data["worst_success_rate"] = min(data["worst_success_rate"], success_rate)
		data["confidence"] = min(data["total_adaptations"] / 10.0, 1.0)  # Build confidence over time
		
		# Update adaptation success rates
		if not adaptation_success_rates.has(formation_type):
			adaptation_success_rates[formation_type] = 0.0
		
		adaptation_success_rates[formation_type] = (adaptation_success_rates[formation_type] * 0.9) + (success_rate * 0.1)
		
		# Check for pattern discovery
		_check_for_tactical_patterns(formation_type, context_signature, success_rate)
	
	func _generate_context_signature(tactical_context: Dictionary) -> String:
		# Generate signature for tactical context
		var threat_level: String = _quantize_value(tactical_context.get("overall_threat_level", 0.0), 5)
		var terrain_complexity: String = _quantize_value(tactical_context.get("terrain_complexity", 0.0), 5)
		var mission_urgency: String = _quantize_value(tactical_context.get("mission_urgency", 0.5), 3)
		var formation_readiness: String = _quantize_value(tactical_context.get("formation_readiness", 1.0), 3)
		
		return "T%s_TR%s_M%s_R%s" % [threat_level, terrain_complexity, mission_urgency, formation_readiness]
	
	func _quantize_value(value: float, levels: int) -> String:
		# Quantize continuous value into discrete levels
		var level: int = clamp(int(value * levels), 0, levels - 1)
		return str(level)
	
	func _check_for_tactical_patterns(formation_type: DynamicFormationManager.AdvancedFormationType, context_signature: String, success_rate: float) -> void:
		# Check for discovery of effective tactical patterns
		var pattern_key: String = str(formation_type) + "_" + context_signature
		
		if not tactical_pattern_library.has(pattern_key):
			tactical_pattern_library[pattern_key] = {
				"pattern_strength": 0.0,
				"discovery_confidence": 0.0,
				"applications": 0
			}
		
		var pattern: Dictionary = tactical_pattern_library[pattern_key]
		pattern["applications"] += 1
		pattern["pattern_strength"] = (pattern["pattern_strength"] * 0.8) + (success_rate * 0.2)
		pattern["discovery_confidence"] = min(pattern["applications"] / 15.0, 1.0)
		
		# Emit pattern discovery if threshold reached
		if pattern["pattern_strength"] > pattern_recognition_threshold and pattern["discovery_confidence"] > 0.7:
			# Pattern discovered signal would be emitted by parent
			pass
	
	func get_formation_recommendation(tactical_context: Dictionary) -> Dictionary:
		# Get AI-learned formation recommendation
		var context_signature: String = _generate_context_signature(tactical_context)
		var best_formation: DynamicFormationManager.AdvancedFormationType = DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD
		var best_confidence: float = 0.0
		var reasoning: Array[String] = []
		
		# Search learning data for best formation
		for formation_type in formation_performance_data:
			if formation_performance_data[formation_type].has(context_signature):
				var data: Dictionary = formation_performance_data[formation_type][context_signature]
				var confidence: float = data["confidence"] * (data["average_success_rate"] + 1.0) * 0.5
				
				if confidence > best_confidence:
					best_confidence = confidence
					best_formation = formation_type
					reasoning = ["AI learning suggests this formation type based on %d previous successes" % data["total_adaptations"]]
		
		return {
			"recommended_formation": best_formation,
			"confidence": best_confidence,
			"reasoning": reasoning,
			"learning_based": true
		}
	
	func get_learning_statistics() -> Dictionary:
		return {
			"total_formations_learned": formation_performance_data.size(),
			"total_patterns_discovered": tactical_pattern_library.size(),
			"learning_enabled": learning_enabled,
			"learning_rate": learning_rate,
			"pattern_recognition_threshold": pattern_recognition_threshold
		}

# Core adaptation system
var learning_system: FormationLearningSystem
var adaptation_parameters: Dictionary = {}
var adaptation_history: Dictionary = {}
var emergency_response_protocols: Dictionary = {}

# Configuration parameters
var adaptation_threshold: float = 0.6
var emergency_threshold: float = 0.3
var transition_smoothness: float = 0.8
var learning_rate: float = 0.1
var evaluation_frequency: float = 2.0

# Performance tracking
var adaptation_performance: Dictionary = {}
var last_evaluation_time: float = 0.0

func _ready() -> void:
	_initialize_adaptation_engine()
	_setup_emergency_protocols()

func _initialize_adaptation_engine() -> void:
	learning_system = FormationLearningSystem.new()
	
	adaptation_performance = {
		"total_evaluations": 0,
		"adaptations_triggered": 0,
		"emergency_adaptations": 0,
		"adaptation_success_rate": 0.0,
		"average_evaluation_time": 0.0
	}
	
	adaptation_history = {}

func _setup_emergency_protocols() -> void:
	## Setup emergency response protocols for critical situations
	emergency_response_protocols = {
		AdaptationTrigger.EMERGENCY_RESPONSE: {
			"formation_priorities": [
				DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE,
				DynamicFormationManager.AdvancedFormationType.MISSILE_SCREEN,
				DynamicFormationManager.AdvancedFormationType.DEFENSIVE_LAYERS
			],
			"response_time": 0.5,
			"effectiveness_threshold": 0.2
		},
		AdaptationTrigger.FORMATION_BREAKDOWN: {
			"formation_priorities": [
				DynamicFormationManager.AdvancedFormationType.EMERGENCY_SCATTER,
				DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
				DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE
			],
			"response_time": 1.0,
			"effectiveness_threshold": 0.3
		},
		AdaptationTrigger.THREAT_ESCALATION: {
			"formation_priorities": [
				DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE,
				DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
				DynamicFormationManager.AdvancedFormationType.MISSILE_SCREEN
			],
			"response_time": 1.5,
			"effectiveness_threshold": 0.4
		}
	}

func initialize_adaptation_parameters(parameters: Dictionary) -> void:
	## Initialize adaptation engine parameters
	adaptation_parameters.merge(parameters, true)
	adaptation_threshold = adaptation_parameters.get("adaptation_threshold", 0.6)
	emergency_threshold = adaptation_parameters.get("emergency_threshold", 0.3)
	transition_smoothness = adaptation_parameters.get("transition_smoothness", 0.8)
	learning_rate = adaptation_parameters.get("learning_rate", 0.1)

func _process(delta: float) -> void:
	# Periodically check for adaptation opportunities
	if Time.get_time_from_start() - last_evaluation_time > evaluation_frequency:
		_evaluate_global_adaptation_needs()
		last_evaluation_time = Time.get_time_from_start()

func _evaluate_global_adaptation_needs() -> void:
	# Global evaluation for adaptation opportunities (would be called with specific formations)
	adaptation_performance["total_evaluations"] += 1

## Evaluates adaptation needs for a formation
func evaluate_adaptation_needs(dynamic_formation: DynamicFormationManager.DynamicFormation, tactical_context: Dictionary) -> Dictionary:
	var start_time: float = Time.get_time_from_system() * 1000.0
	var formation_id: String = dynamic_formation.formation_id
	
	# Analyze current formation effectiveness
	var current_effectiveness: float = tactical_context.get("overall_effectiveness", 0.5)
	var formation_readiness: float = tactical_context.get("formation_readiness", 1.0)
	var tactical_pressure: float = tactical_context.get("tactical_pressure", 0.0)
	
	# Determine adaptation triggers
	var triggers: Array[AdaptationTrigger] = _identify_adaptation_triggers(dynamic_formation, tactical_context)
	
	# Calculate adaptation urgency
	var urgency: float = _calculate_adaptation_urgency(triggers, current_effectiveness, tactical_pressure)
	
	# Generate adaptation recommendations
	var recommendations: Array[Dictionary] = _generate_adaptation_recommendations(dynamic_formation, tactical_context, triggers)
	
	# Select best recommendation
	var best_recommendation: Dictionary = _select_best_adaptation(recommendations, urgency)
	
	# Check if adaptation is required
	var adaptation_required: bool = _should_trigger_adaptation(current_effectiveness, urgency, best_recommendation)
	
	# Compile adaptation analysis
	var adaptation_analysis: Dictionary = {
		"formation_id": formation_id,
		"adaptation_required": adaptation_required,
		"current_effectiveness": current_effectiveness,
		"adaptation_urgency": urgency,
		"adaptation_triggers": triggers,
		"trigger_count": triggers.size(),
		"recommendations": recommendations,
		"best_recommendation": best_recommendation,
		"emergency_response": urgency > 0.8,
		"evaluation_timestamp": Time.get_time_from_start(),
		"tactical_context": tactical_context
	}
	
	# Update performance tracking
	var evaluation_time: float = (Time.get_time_from_system() * 1000.0) - start_time
	_update_evaluation_performance(evaluation_time)
	
	# Emit signals for adaptation results
	adaptation_evaluated.emit(formation_id, adaptation_analysis)
	
	if adaptation_required and urgency > 0.8:
		emergency_adaptation_triggered.emit(formation_id, tactical_pressure, best_recommendation.get("formation_type", 0))
	
	# Record for learning system
	if adaptation_required:
		_record_adaptation_attempt(dynamic_formation, tactical_context, best_recommendation)
	
	return adaptation_analysis

func _identify_adaptation_triggers(dynamic_formation: DynamicFormationManager.DynamicFormation, tactical_context: Dictionary) -> Array[AdaptationTrigger]:
	# Identify what triggers are causing adaptation need
	var triggers: Array[AdaptationTrigger] = []
	
	var threat_level: float = tactical_context.get("overall_threat_level", 0.0)
	var terrain_complexity: float = tactical_context.get("terrain_complexity", 0.0)
	var formation_readiness: float = tactical_context.get("formation_readiness", 1.0)
	var tactical_pressure: float = tactical_context.get("tactical_pressure", 0.0)
	
	# Check for threat escalation
	if threat_level > 0.7:
		triggers.append(AdaptationTrigger.THREAT_ESCALATION)
	
	# Check for tactical disadvantage
	var current_effectiveness: float = tactical_context.get("overall_effectiveness", 0.5)
	if current_effectiveness < 0.5:
		triggers.append(AdaptationTrigger.TACTICAL_DISADVANTAGE)
	
	# Check for damage accumulation
	if formation_readiness < 0.6:
		triggers.append(AdaptationTrigger.DAMAGE_ACCUMULATION)
	
	# Check for terrain changes
	if terrain_complexity > 0.6:
		triggers.append(AdaptationTrigger.TERRAIN_CHANGE)
	
	# Check for formation breakdown
	var formation_integrity: float = dynamic_formation.base_formation.get_formation_integrity()
	if formation_integrity < 0.4:
		triggers.append(AdaptationTrigger.FORMATION_BREAKDOWN)
	
	# Check for emergency response needs
	if tactical_pressure > 0.8 or formation_readiness < 0.3:
		triggers.append(AdaptationTrigger.EMERGENCY_RESPONSE)
	
	# Check for mission phase changes (would integrate with mission system)
	var mission_urgency: float = tactical_context.get("mission_urgency", 0.5)
	if mission_urgency > 0.8:
		triggers.append(AdaptationTrigger.MISSION_PHASE_CHANGE)
	
	# Check for opportunities to exploit
	if threat_level < 0.3 and current_effectiveness > 0.7:
		triggers.append(AdaptationTrigger.OPPORTUNITY_EXPLOIT)
	
	# Check for energy conservation needs
	var energy_analysis: Dictionary = tactical_context.get("energy_analysis", {})
	if energy_analysis.get("energy_crisis", false):
		triggers.append(AdaptationTrigger.ENERGY_CONSERVATION)
	
	# Check for learning optimization opportunities
	if learning_system.learning_enabled and _has_learning_optimization_opportunity(dynamic_formation, tactical_context):
		triggers.append(AdaptationTrigger.LEARNING_OPTIMIZATION)
	
	return triggers

func _has_learning_optimization_opportunity(dynamic_formation: DynamicFormationManager.DynamicFormation, tactical_context: Dictionary) -> bool:
	# Check if learning system suggests an optimization opportunity
	var learning_recommendation: Dictionary = learning_system.get_formation_recommendation(tactical_context)
	var recommended_formation: DynamicFormationManager.AdvancedFormationType = learning_recommendation.get("recommended_formation", dynamic_formation.current_type)
	var confidence: float = learning_recommendation.get("confidence", 0.0)
	
	return recommended_formation != dynamic_formation.current_type and confidence > 0.7

func _calculate_adaptation_urgency(triggers: Array[AdaptationTrigger], current_effectiveness: float, tactical_pressure: float) -> float:
	# Calculate urgency for adaptation
	var base_urgency: float = 0.0
	var trigger_weights: Dictionary = {
		AdaptationTrigger.EMERGENCY_RESPONSE: 1.0,
		AdaptationTrigger.FORMATION_BREAKDOWN: 0.9,
		AdaptationTrigger.THREAT_ESCALATION: 0.8,
		AdaptationTrigger.DAMAGE_ACCUMULATION: 0.7,
		AdaptationTrigger.TACTICAL_DISADVANTAGE: 0.6,
		AdaptationTrigger.TERRAIN_CHANGE: 0.5,
		AdaptationTrigger.MISSION_PHASE_CHANGE: 0.5,
		AdaptationTrigger.ENERGY_CONSERVATION: 0.4,
		AdaptationTrigger.OPPORTUNITY_EXPLOIT: 0.3,
		AdaptationTrigger.LEARNING_OPTIMIZATION: 0.2
	}
	
	# Calculate urgency from triggers
	for trigger in triggers:
		var weight: float = trigger_weights.get(trigger, 0.1)
		base_urgency += weight
	
	# Normalize urgency by trigger count
	if triggers.size() > 0:
		base_urgency /= triggers.size()
	
	# Adjust urgency based on effectiveness and pressure
	var effectiveness_factor: float = 1.0 - current_effectiveness
	var pressure_factor: float = tactical_pressure
	
	var final_urgency: float = (base_urgency + effectiveness_factor * 0.3 + pressure_factor * 0.4) / 1.7
	
	return clamp(final_urgency, 0.0, 1.0)

func _generate_adaptation_recommendations(dynamic_formation: DynamicFormationManager.DynamicFormation, tactical_context: Dictionary, triggers: Array[AdaptationTrigger]) -> Array[Dictionary]:
	# Generate adaptation recommendations based on triggers and context
	var recommendations: Array[Dictionary] = []
	var current_type: DynamicFormationManager.AdvancedFormationType = dynamic_formation.current_type
	
	# Generate trigger-based recommendations
	for trigger in triggers:
		var trigger_recommendations: Array[Dictionary] = _get_trigger_specific_recommendations(trigger, tactical_context)
		recommendations.append_array(trigger_recommendations)
	
	# Generate tactical analysis recommendations
	var tactical_recommendations: Array[Dictionary] = _get_tactical_analysis_recommendations(dynamic_formation, tactical_context)
	recommendations.append_array(tactical_recommendations)
	
	# Generate learning-based recommendations
	if learning_system.learning_enabled:
		var learning_recommendation: Dictionary = learning_system.get_formation_recommendation(tactical_context)
		if learning_recommendation.get("confidence", 0.0) > 0.5:
			learning_recommendation["priority"] = learning_recommendation["confidence"]
			learning_recommendation["reasoning"] = learning_recommendation.get("reasoning", ["AI learning recommendation"])
			recommendations.append(learning_recommendation)
	
	# Remove duplicates and current formation
	recommendations = _deduplicate_recommendations(recommendations, current_type)
	
	# Sort by priority/confidence
	recommendations.sort_custom(func(a, b): return a.get("priority", 0.0) > b.get("priority", 0.0))
	
	return recommendations

func _get_trigger_specific_recommendations(trigger: AdaptationTrigger, tactical_context: Dictionary) -> Array[Dictionary]:
	# Get recommendations specific to adaptation triggers
	var recommendations: Array[Dictionary] = []
	var threat_level: float = tactical_context.get("overall_threat_level", 0.0)
	var terrain_complexity: float = tactical_context.get("terrain_complexity", 0.0)
	
	match trigger:
		AdaptationTrigger.THREAT_ESCALATION:
			recommendations.append(_create_recommendation(
				DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE,
				0.8,
				["High threat level requires defensive posture"]
			))
			recommendations.append(_create_recommendation(
				DynamicFormationManager.AdvancedFormationType.MISSILE_SCREEN,
				0.7,
				["Missile screen formation for threat mitigation"]
			))
		
		AdaptationTrigger.FORMATION_BREAKDOWN:
			if emergency_response_protocols.has(trigger):
				var protocol: Dictionary = emergency_response_protocols[trigger]
				for formation_type in protocol["formation_priorities"]:
					recommendations.append(_create_recommendation(
						formation_type,
						0.9,
						["Emergency protocol for formation breakdown"]
					))
		
		AdaptationTrigger.TACTICAL_DISADVANTAGE:
			recommendations.append(_create_recommendation(
				DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
				0.7,
				["Combat spread formation for tactical advantage"]
			))
		
		AdaptationTrigger.DAMAGE_ACCUMULATION:
			recommendations.append(_create_recommendation(
				DynamicFormationManager.AdvancedFormationType.DEFENSIVE_LAYERS,
				0.8,
				["Multi-layer defense for damaged ships"]
			))
		
		AdaptationTrigger.TERRAIN_CHANGE:
			if terrain_complexity > 0.6:
				recommendations.append(_create_recommendation(
					DynamicFormationManager.AdvancedFormationType.COLUMN,
					0.6,
					["Column formation for terrain navigation"]
				))
		
		AdaptationTrigger.OPPORTUNITY_EXPLOIT:
			recommendations.append(_create_recommendation(
				DynamicFormationManager.AdvancedFormationType.STRIKE_WEDGE,
				0.7,
				["Strike wedge to exploit tactical opportunity"]
			))
		
		AdaptationTrigger.ENERGY_CONSERVATION:
			recommendations.append(_create_recommendation(
				DynamicFormationManager.AdvancedFormationType.PATROL_SWEEP,
				0.6,
				["Energy-efficient patrol formation"]
			))
	
	return recommendations

func _get_tactical_analysis_recommendations(dynamic_formation: DynamicFormationManager.DynamicFormation, tactical_context: Dictionary) -> Array[Dictionary]:
	# Get recommendations based on tactical analysis
	var recommendations: Array[Dictionary] = []
	var threat_level: float = tactical_context.get("overall_threat_level", 0.0)
	var mission_urgency: float = tactical_context.get("mission_urgency", 0.5)
	var formation_readiness: float = tactical_context.get("formation_readiness", 1.0)
	
	# High threat situations
	if threat_level > 0.6:
		recommendations.append(_create_recommendation(
			DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
			0.6 + threat_level * 0.2,
			["High threat level favors combat spread formation"]
		))
	
	# High urgency missions
	if mission_urgency > 0.7:
		recommendations.append(_create_recommendation(
			DynamicFormationManager.AdvancedFormationType.STRIKE_WEDGE,
			0.5 + mission_urgency * 0.3,
			["High mission urgency suggests aggressive formation"]
		))
	
	# Low readiness formations
	if formation_readiness < 0.5:
		recommendations.append(_create_recommendation(
			DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE,
			0.7 + (1.0 - formation_readiness) * 0.2,
			["Low formation readiness requires defensive posture"]
		))
	
	# Balanced situations
	if threat_level > 0.3 and threat_level < 0.6 and formation_readiness > 0.6:
		recommendations.append(_create_recommendation(
			DynamicFormationManager.AdvancedFormationType.ESCORT_SCREEN,
			0.6,
			["Balanced conditions suitable for escort screen"]
		))
	
	return recommendations

func _create_recommendation(formation_type: DynamicFormationManager.AdvancedFormationType, priority: float, reasoning: Array[String]) -> Dictionary:
	# Create a recommendation dictionary
	return {
		"formation_type": formation_type,
		"recommended_formation": formation_type,  # For compatibility
		"priority": priority,
		"confidence": priority,  # For compatibility
		"reasoning": reasoning
	}

func _deduplicate_recommendations(recommendations: Array[Dictionary], current_type: DynamicFormationManager.AdvancedFormationType) -> Array[Dictionary]:
	# Remove duplicate recommendations and current formation
	var unique_recommendations: Array[Dictionary] = []
	var seen_formations: Array[DynamicFormationManager.AdvancedFormationType] = []
	
	for recommendation in recommendations:
		var formation_type: DynamicFormationManager.AdvancedFormationType = recommendation.get("formation_type", current_type)
		
		# Skip current formation and duplicates
		if formation_type == current_type or formation_type in seen_formations:
			continue
		
		seen_formations.append(formation_type)
		unique_recommendations.append(recommendation)
	
	return unique_recommendations

func _select_best_adaptation(recommendations: Array[Dictionary], urgency: float) -> Dictionary:
	# Select the best adaptation from recommendations
	if recommendations.is_empty():
		return {}
	
	var best_recommendation: Dictionary = recommendations[0]
	
	# In emergency situations, prioritize emergency protocols
	if urgency > 0.8:
		for recommendation in recommendations:
			var formation_type: DynamicFormationManager.AdvancedFormationType = recommendation.get("formation_type", 0)
			if _is_emergency_formation(formation_type):
				best_recommendation = recommendation
				break
	
	return best_recommendation

func _is_emergency_formation(formation_type: DynamicFormationManager.AdvancedFormationType) -> bool:
	# Check if formation type is suitable for emergency situations
	return formation_type in [
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE,
		DynamicFormationManager.AdvancedFormationType.MISSILE_SCREEN,
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_LAYERS,
		DynamicFormationManager.AdvancedFormationType.EMERGENCY_SCATTER
	]

func _should_trigger_adaptation(current_effectiveness: float, urgency: float, best_recommendation: Dictionary) -> bool:
	# Determine if adaptation should be triggered
	var adaptation_confidence: float = best_recommendation.get("confidence", 0.0)
	
	# Emergency situations always trigger adaptation
	if urgency > 0.8:
		return true
	
	# Low effectiveness with good recommendation
	if current_effectiveness < adaptation_threshold and adaptation_confidence > 0.6:
		return true
	
	# High confidence learning recommendations
	if adaptation_confidence > 0.8:
		return true
	
	return false

func _record_adaptation_attempt(dynamic_formation: DynamicFormationManager.DynamicFormation, tactical_context: Dictionary, recommendation: Dictionary) -> void:
	# Record adaptation attempt for performance tracking
	adaptation_performance["adaptations_triggered"] += 1
	
	var formation_id: String = dynamic_formation.formation_id
	if not adaptation_history.has(formation_id):
		adaptation_history[formation_id] = []
	
	var attempt_record: Dictionary = {
		"timestamp": Time.get_time_from_start(),
		"from_formation": dynamic_formation.current_type,
		"to_formation": recommendation.get("formation_type", dynamic_formation.current_type),
		"urgency": _calculate_adaptation_urgency([], tactical_context.get("overall_effectiveness", 0.5), tactical_context.get("tactical_pressure", 0.0)),
		"recommendation": recommendation,
		"tactical_context": tactical_context
	}
	
	adaptation_history[formation_id].append(attempt_record)
	
	# Keep only recent history
	if adaptation_history[formation_id].size() > 20:
		adaptation_history[formation_id] = adaptation_history[formation_id].slice(-20)

func _update_evaluation_performance(evaluation_time: float) -> void:
	# Update evaluation performance tracking
	var total_evaluations: int = adaptation_performance["total_evaluations"]
	var current_avg: float = adaptation_performance["average_evaluation_time"]
	
	adaptation_performance["average_evaluation_time"] = (current_avg * (total_evaluations - 1) + evaluation_time) / total_evaluations

## Records the outcome of an adaptation for learning
func record_adaptation_outcome(formation_id: String, old_formation: DynamicFormationManager.AdvancedFormationType, new_formation: DynamicFormationManager.AdvancedFormationType, tactical_context: Dictionary, effectiveness_before: float, effectiveness_after: float) -> void:
	# Record adaptation outcome for learning system
	learning_system.record_adaptation_outcome(new_formation, tactical_context, effectiveness_before, effectiveness_after)
	
	# Update success rate tracking
	var success: bool = effectiveness_after > effectiveness_before
	var current_rate: float = adaptation_performance["adaptation_success_rate"]
	var total_adaptations: int = adaptation_performance["adaptations_triggered"]
	
	if total_adaptations > 0:
		var success_value: float = 1.0 if success else 0.0
		adaptation_performance["adaptation_success_rate"] = (current_rate * (total_adaptations - 1) + success_value) / total_adaptations

## Gets adaptation performance statistics
func get_adaptation_performance_statistics() -> Dictionary:
	var stats: Dictionary = adaptation_performance.duplicate()
	stats["learning_statistics"] = learning_system.get_learning_statistics()
	return stats

## Gets adaptation history for formation
func get_formation_adaptation_history(formation_id: String) -> Array:
	return adaptation_history.get(formation_id, [])

## Clears adaptation history for formation
func clear_formation_adaptation_history(formation_id: String) -> void:
	adaptation_history.erase(formation_id)

## Updates adaptation strategy for formation
func update_formation_adaptation_strategy(formation_id: String, strategy: AdaptationStrategy, parameters: Dictionary = {}) -> void:
	# Update adaptation strategy (for future enhancement)
	adaptation_strategy_updated.emit(formation_id, {
		"strategy": strategy,
		"parameters": parameters,
		"timestamp": Time.get_time_from_start()
	})

## Forces emergency adaptation for formation
func force_emergency_adaptation(formation_id: String, threat_level: float, preferred_formation: DynamicFormationManager.AdvancedFormationType = DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE) -> Dictionary:
	# Force emergency adaptation
	emergency_adaptation_triggered.emit(formation_id, threat_level, preferred_formation)
	
	return {
		"formation_type": preferred_formation,
		"confidence": 1.0,
		"reasoning": ["Emergency adaptation forced due to critical threat level %.2f" % threat_level],
		"emergency": true
	}