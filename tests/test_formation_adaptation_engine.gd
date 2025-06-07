extends GdUnitTestSuite

## Unit tests for Formation Adaptation Engine (AI-014)
## Tests adaptation trigger identification, learning system, and emergency protocols

class_name TestFormationAdaptationEngine

# Test components
var adaptation_engine: FormationAdaptationEngine
var mock_formation: DynamicFormationManager.DynamicFormation
var mock_base_formation: FormationManager.Formation

func before_test() -> void:
	# Setup test environment
	_setup_adaptation_engine()
	_create_mock_formations()

func after_test() -> void:
	# Cleanup test environment
	if is_instance_valid(adaptation_engine):
		adaptation_engine.queue_free()

func _setup_adaptation_engine() -> void:
	# Create adaptation engine
	adaptation_engine = FormationAdaptationEngine.new()
	adaptation_engine.name = "TestAdaptationEngine"
	add_child(adaptation_engine)
	
	# Initialize with test parameters
	adaptation_engine.initialize_adaptation_parameters({
		"adaptation_threshold": 0.6,
		"emergency_threshold": 0.3,
		"transition_smoothness": 0.8,
		"learning_rate": 0.1
	})

func _create_mock_formations() -> void:
	# Create mock formation objects
	mock_base_formation = FormationManager.Formation.new(
		"test_formation",
		Node3D.new(),
		FormationManager.FormationType.DIAMOND,
		100.0
	)
	
	mock_formation = DynamicFormationManager.DynamicFormation.new("test_formation", mock_base_formation)
	mock_formation.current_type = DynamicFormationManager.AdvancedFormationType.DIAMOND

## Test adaptation trigger identification
func test_adaptation_trigger_identification() -> void:
	# Test threat escalation trigger
	var high_threat_context: Dictionary = {
		"overall_threat_level": 0.9,
		"terrain_complexity": 0.2,
		"formation_readiness": 0.8,
		"tactical_pressure": 0.8,
		"overall_effectiveness": 0.6
	}
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(mock_formation, high_threat_context)
	var triggers: Array = adaptation_analysis["adaptation_triggers"]
	
	# Should detect threat escalation trigger
	assert_that(triggers).contains(FormationAdaptationEngine.AdaptationTrigger.THREAT_ESCALATION)
	assert_that(adaptation_analysis["adaptation_required"]).is_true()
	assert_that(adaptation_analysis["adaptation_urgency"]).is_greater(0.6)

## Test damage accumulation trigger
func test_damage_accumulation_trigger() -> void:
	var damage_context: Dictionary = {
		"overall_threat_level": 0.4,
		"formation_readiness": 0.3,  # Low readiness due to damage
		"tactical_pressure": 0.5,
		"overall_effectiveness": 0.4
	}
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(mock_formation, damage_context)
	var triggers: Array = adaptation_analysis["adaptation_triggers"]
	
	# Should detect damage accumulation trigger
	assert_that(triggers).contains(FormationAdaptationEngine.AdaptationTrigger.DAMAGE_ACCUMULATION)

## Test tactical disadvantage trigger
func test_tactical_disadvantage_trigger() -> void:
	var disadvantage_context: Dictionary = {
		"overall_threat_level": 0.6,
		"formation_readiness": 0.7,
		"tactical_pressure": 0.6,
		"overall_effectiveness": 0.3  # Low effectiveness
	}
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(mock_formation, disadvantage_context)
	var triggers: Array = adaptation_analysis["adaptation_triggers"]
	
	# Should detect tactical disadvantage trigger
	assert_that(triggers).contains(FormationAdaptationEngine.AdaptationTrigger.TACTICAL_DISADVANTAGE)

## Test emergency response trigger
func test_emergency_response_trigger() -> void:
	var emergency_context: Dictionary = {
		"overall_threat_level": 0.7,
		"formation_readiness": 0.2,  # Very low readiness
		"tactical_pressure": 0.9,     # High pressure
		"overall_effectiveness": 0.2
	}
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(mock_formation, emergency_context)
	var triggers: Array = adaptation_analysis["adaptation_triggers"]
	
	# Should detect emergency response trigger
	assert_that(triggers).contains(FormationAdaptationEngine.AdaptationTrigger.EMERGENCY_RESPONSE)
	assert_that(adaptation_analysis["emergency_response"]).is_true()

## Test adaptation urgency calculation
func test_adaptation_urgency_calculation() -> void:
	# Test high urgency scenario
	var critical_context: Dictionary = {
		"overall_threat_level": 0.95,
		"formation_readiness": 0.1,
		"tactical_pressure": 0.9,
		"overall_effectiveness": 0.1
	}
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(mock_formation, critical_context)
	assert_that(adaptation_analysis["adaptation_urgency"]).is_greater(0.8)
	
	# Test low urgency scenario
	var calm_context: Dictionary = {
		"overall_threat_level": 0.2,
		"formation_readiness": 0.9,
		"tactical_pressure": 0.1,
		"overall_effectiveness": 0.8
	}
	
	adaptation_analysis = adaptation_engine.evaluate_adaptation_needs(mock_formation, calm_context)
	assert_that(adaptation_analysis["adaptation_urgency"]).is_less(0.4)

## Test recommendation generation
func test_recommendation_generation() -> void:
	var tactical_context: Dictionary = {
		"overall_threat_level": 0.8,
		"terrain_complexity": 0.3,
		"mission_urgency": 0.6,
		"formation_readiness": 0.7,
		"tactical_pressure": 0.7,
		"overall_effectiveness": 0.4
	}
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(mock_formation, tactical_context)
	var recommendations: Array = adaptation_analysis["recommendations"]
	
	assert_that(recommendations).is_not_empty()
	
	# Check recommendation structure
	var best_recommendation: Dictionary = adaptation_analysis["best_recommendation"]
	assert_that(best_recommendation).contains_keys(["formation_type", "confidence", "reasoning"])
	assert_that(best_recommendation["confidence"]).is_between(0.0, 1.0)
	assert_that(best_recommendation["reasoning"]).is_not_empty()

## Test learning system functionality
func test_learning_system() -> void:
	var learning_system: FormationAdaptationEngine.FormationLearningSystem = adaptation_engine.learning_system
	
	# Test learning enabled
	assert_that(learning_system.learning_enabled).is_true()
	
	# Record adaptation outcomes
	var tactical_context: Dictionary = {
		"overall_threat_level": 0.6,
		"terrain_complexity": 0.4,
		"mission_urgency": 0.7,
		"formation_readiness": 0.8
	}
	
	# Record successful adaptation
	learning_system.record_adaptation_outcome(
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
		tactical_context,
		0.5,  # Before effectiveness
		0.8   # After effectiveness (improvement)
	)
	
	# Get learning statistics
	var stats: Dictionary = learning_system.get_learning_statistics()
	assert_that(stats).contains_keys([
		"total_formations_learned", "total_patterns_discovered", 
		"learning_enabled", "learning_rate"
	])
	
	assert_that(stats["learning_enabled"]).is_true()
	assert_that(stats["learning_rate"]).is_equal(0.1)

## Test learning recommendation
func test_learning_recommendation() -> void:
	var learning_system: FormationAdaptationEngine.FormationLearningSystem = adaptation_engine.learning_system
	
	# Build up learning data
	var tactical_context: Dictionary = {
		"overall_threat_level": 0.7,
		"terrain_complexity": 0.3,
		"mission_urgency": 0.6,
		"formation_readiness": 0.8
	}
	
	# Record multiple successful outcomes for a specific formation
	for i in range(15):  # Build confidence
		learning_system.record_adaptation_outcome(
			DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE,
			tactical_context,
			0.4 + i * 0.01,  # Varying before effectiveness
			0.8 + i * 0.01   # Consistently high after effectiveness
		)
	
	# Get learning recommendation
	var recommendation: Dictionary = learning_system.get_formation_recommendation(tactical_context)
	
	assert_that(recommendation).contains_keys(["recommended_formation", "confidence", "reasoning", "learning_based"])
	assert_that(recommendation["learning_based"]).is_true()
	
	# Should have reasonable confidence after 15 successful adaptations
	assert_that(recommendation["confidence"]).is_greater(0.3)

## Test emergency protocols
func test_emergency_protocols() -> void:
	# Test emergency adaptation for critical threat
	var emergency_context: Dictionary = {
		"overall_threat_level": 0.95,
		"formation_readiness": 0.2,
		"tactical_pressure": 0.9,
		"overall_effectiveness": 0.1
	}
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(mock_formation, emergency_context)
	
	assert_that(adaptation_analysis["emergency_response"]).is_true()
	assert_that(adaptation_analysis["adaptation_required"]).is_true()
	
	# Check that emergency formations are recommended
	var best_recommendation: Dictionary = adaptation_analysis["best_recommendation"]
	var formation_type: DynamicFormationManager.AdvancedFormationType = best_recommendation["formation_type"]
	
	var emergency_formations: Array[DynamicFormationManager.AdvancedFormationType] = [
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE,
		DynamicFormationManager.AdvancedFormationType.MISSILE_SCREEN,
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_LAYERS,
		DynamicFormationManager.AdvancedFormationType.EMERGENCY_SCATTER
	]
	
	# Should recommend an emergency formation
	var is_emergency_formation: bool = formation_type in emergency_formations
	assert_that(is_emergency_formation).is_true()

## Test forced emergency adaptation
func test_forced_emergency_adaptation() -> void:
	var emergency_recommendation: Dictionary = adaptation_engine.force_emergency_adaptation(
		"test_formation",
		0.95,
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE
	)
	
	assert_that(emergency_recommendation["emergency"]).is_true()
	assert_that(emergency_recommendation["confidence"]).is_equal(1.0)
	assert_that(emergency_recommendation["formation_type"]).is_equal(DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE)
	assert_that(emergency_recommendation["reasoning"]).is_not_empty()

## Test adaptation performance tracking
func test_adaptation_performance_tracking() -> void:
	# Trigger several adaptations
	var contexts: Array[Dictionary] = [
		{"overall_threat_level": 0.8, "formation_readiness": 0.5, "tactical_pressure": 0.7, "overall_effectiveness": 0.3},
		{"overall_threat_level": 0.6, "formation_readiness": 0.3, "tactical_pressure": 0.6, "overall_effectiveness": 0.4},
		{"overall_threat_level": 0.9, "formation_readiness": 0.2, "tactical_pressure": 0.9, "overall_effectiveness": 0.2}
	]
	
	for context in contexts:
		adaptation_engine.evaluate_adaptation_needs(mock_formation, context)
	
	# Check performance statistics
	var stats: Dictionary = adaptation_engine.get_adaptation_performance_statistics()
	assert_that(stats).contains_keys([
		"total_evaluations", "adaptations_triggered", "adaptation_success_rate", "average_evaluation_time"
	])
	
	assert_that(stats["total_evaluations"]).is_greater_equal(3)
	assert_that(stats["adaptations_triggered"]).is_greater_equal(0)

## Test context signature generation
func test_context_signature_generation() -> void:
	var learning_system: FormationAdaptationEngine.FormationLearningSystem = adaptation_engine.learning_system
	
	var context1: Dictionary = {
		"overall_threat_level": 0.7,
		"terrain_complexity": 0.3,
		"mission_urgency": 0.6,
		"formation_readiness": 0.8
	}
	
	var context2: Dictionary = {
		"overall_threat_level": 0.7,  # Same as context1
		"terrain_complexity": 0.3,   # Same as context1
		"mission_urgency": 0.6,      # Same as context1
		"formation_readiness": 0.8   # Same as context1
	}
	
	var signature1: String = learning_system._generate_context_signature(context1)
	var signature2: String = learning_system._generate_context_signature(context2)
	
	# Identical contexts should generate identical signatures
	assert_that(signature1).is_equal(signature2)
	
	# Different contexts should generate different signatures
	var context3: Dictionary = {
		"overall_threat_level": 0.9,  # Different
		"terrain_complexity": 0.3,
		"mission_urgency": 0.6,
		"formation_readiness": 0.8
	}
	
	var signature3: String = learning_system._generate_context_signature(context3)
	assert_that(signature1).is_not_equal(signature3)

## Test signal emissions
func test_signal_emissions() -> void:
	# Monitor signals
	var signals_received: Array[String] = []
	
	# Connect to signals
	adaptation_engine.adaptation_evaluated.connect(func(id, analysis): signals_received.append("adaptation_evaluated"))
	adaptation_engine.emergency_adaptation_triggered.connect(func(id, threat, formation): signals_received.append("emergency_adaptation_triggered"))
	
	# Trigger adaptation evaluation
	var tactical_context: Dictionary = {
		"overall_threat_level": 0.8,
		"formation_readiness": 0.5,
		"overall_effectiveness": 0.3
	}
	
	adaptation_engine.evaluate_adaptation_needs(mock_formation, tactical_context)
	assert_that(signals_received).contains("adaptation_evaluated")
	
	# Trigger emergency adaptation
	var emergency_context: Dictionary = {
		"overall_threat_level": 0.95,
		"formation_readiness": 0.1,
		"tactical_pressure": 0.9,
		"overall_effectiveness": 0.1
	}
	
	adaptation_engine.evaluate_adaptation_needs(mock_formation, emergency_context)
	assert_that(signals_received).contains("emergency_adaptation_triggered")

## Test adaptation with no triggers
func test_no_adaptation_triggers() -> void:
	# Perfect scenario - no adaptation needed
	var perfect_context: Dictionary = {
		"overall_threat_level": 0.2,
		"terrain_complexity": 0.1,
		"formation_readiness": 0.9,
		"tactical_pressure": 0.1,
		"overall_effectiveness": 0.9
	}
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(mock_formation, perfect_context)
	
	assert_that(adaptation_analysis["adaptation_required"]).is_false()
	assert_that(adaptation_analysis["adaptation_urgency"]).is_less(0.5)
	assert_that(adaptation_analysis["emergency_response"]).is_false()

## Test edge cases and error handling
func test_edge_cases() -> void:
	# Test with empty context
	var empty_context: Dictionary = {}
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(mock_formation, empty_context)
	
	# Should handle gracefully without crashing
	assert_that(adaptation_analysis).is_not_empty()
	assert_that(adaptation_analysis).contains_key("adaptation_required")
	
	# Test with extreme values
	var extreme_context: Dictionary = {
		"overall_threat_level": 2.0,  # Above normal range
		"formation_readiness": -0.5,  # Below normal range
		"tactical_pressure": 1.5,     # Above normal range
		"overall_effectiveness": -1.0 # Below normal range
	}
	
	adaptation_analysis = adaptation_engine.evaluate_adaptation_needs(mock_formation, extreme_context)
	assert_that(adaptation_analysis).is_not_empty()

## Test adaptation history tracking
func test_adaptation_history_tracking() -> void:
	var formation_id: String = "test_formation"
	
	# Initially no history
	var history: Array = adaptation_engine.get_formation_adaptation_history(formation_id)
	assert_that(history).is_empty()
	
	# Trigger adaptation to create history
	var tactical_context: Dictionary = {
		"overall_threat_level": 0.8,
		"formation_readiness": 0.4,
		"overall_effectiveness": 0.3
	}
	
	adaptation_engine.evaluate_adaptation_needs(mock_formation, tactical_context)
	
	# Should have history entry
	history = adaptation_engine.get_formation_adaptation_history(formation_id)
	assert_that(history).is_not_empty()
	
	# Check history entry structure
	var entry: Dictionary = history[0]
	assert_that(entry).contains_keys(["timestamp", "from_formation", "to_formation", "urgency", "recommendation"])
	
	# Clear history
	adaptation_engine.clear_formation_adaptation_history(formation_id)
	history = adaptation_engine.get_formation_adaptation_history(formation_id)
	assert_that(history).is_empty()