extends GdUnitTestSuite

## Unit tests for Dynamic Formation Management and Advanced Formation Adaptation (AI-014)
## Tests dynamic formation transitions, adaptation engine, and complex multi-squadron coordination

class_name TestDynamicFormationManagement

# Test components
var dynamic_formation_manager: DynamicFormationManager
var formation_manager: FormationManager
var tactical_analyzer: TacticalSituationAnalyzer
var effectiveness_calculator: FormationEffectivenessCalculator
var adaptation_engine: FormationAdaptationEngine

# Test ships
var leader_ship: Node3D
var wingman_1: Node3D
var wingman_2: Node3D
var wingman_3: Node3D
var test_ships: Array[Node3D]

# Test formation data
var test_formation_id: String
var test_dynamic_formation: DynamicFormationManager.DynamicFormation

func before_test() -> void:
	# Setup test environment for dynamic formation management tests
	_create_test_ships()
	_setup_formation_managers()
	_create_test_formation()

func after_test() -> void:
	# Cleanup test environment
	_cleanup_test_ships()
	_cleanup_formation_managers()

func _create_test_ships() -> void:
	# Create test ships with AI agents
	leader_ship = _create_test_ship("Leader", Vector3(0, 0, 0))
	wingman_1 = _create_test_ship("Wingman1", Vector3(100, 0, 0))
	wingman_2 = _create_test_ship("Wingman2", Vector3(-100, 0, 0))
	wingman_3 = _create_test_ship("Wingman3", Vector3(0, 0, 100))
	
	test_ships = [leader_ship, wingman_1, wingman_2, wingman_3]

func _create_test_ship(ship_name: String, position: Vector3) -> Node3D:
	# Create a test ship with AI agent
	var ship: CharacterBody3D = CharacterBody3D.new()
	ship.name = ship_name
	ship.global_position = position
	
	# Add collision shape
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(10, 5, 20)
	collision.shape = box_shape
	ship.add_child(collision)
	
	# Add AI agent
	var ai_agent: WCSAIAgent = WCSAIAgent.new()
	ai_agent.name = "WCSAIAgent"
	ship.add_child(ai_agent)
	
	# Add to scene
	add_child(ship)
	
	return ship

func _setup_formation_managers() -> void:
	# Setup formation management systems
	formation_manager = FormationManager.new()
	formation_manager.name = "FormationManager"
	add_child(formation_manager)
	
	dynamic_formation_manager = DynamicFormationManager.new()
	dynamic_formation_manager.name = "DynamicFormationManager"
	add_child(dynamic_formation_manager)
	
	tactical_analyzer = TacticalSituationAnalyzer.new()
	tactical_analyzer.name = "TacticalAnalyzer"
	add_child(tactical_analyzer)
	
	effectiveness_calculator = FormationEffectivenessCalculator.new()
	effectiveness_calculator.name = "EffectivenessCalculator"
	add_child(effectiveness_calculator)
	
	adaptation_engine = FormationAdaptationEngine.new()
	adaptation_engine.name = "AdaptationEngine"
	add_child(adaptation_engine)
	
	# Initialize systems
	dynamic_formation_manager.formation_manager = formation_manager
	dynamic_formation_manager.tactical_analyzer = tactical_analyzer
	dynamic_formation_manager.effectiveness_calculator = effectiveness_calculator
	dynamic_formation_manager.adaptation_engine = adaptation_engine

func _create_test_formation() -> void:
	# Create test dynamic formation
	test_formation_id = dynamic_formation_manager.create_dynamic_formation(
		leader_ship,
		DynamicFormationManager.AdvancedFormationType.DIAMOND,
		120.0,
		[wingman_1, wingman_2, wingman_3]
	)
	
	assert_that(test_formation_id).is_not_empty()
	test_dynamic_formation = dynamic_formation_manager.dynamic_formations[test_formation_id]

func _cleanup_test_ships() -> void:
	# Cleanup test ships
	for ship in test_ships:
		if is_instance_valid(ship):
			ship.queue_free()
	test_ships.clear()

func _cleanup_formation_managers() -> void:
	# Cleanup formation managers
	if is_instance_valid(dynamic_formation_manager):
		dynamic_formation_manager.queue_free()
	if is_instance_valid(formation_manager):
		formation_manager.queue_free()
	if is_instance_valid(tactical_analyzer):
		tactical_analyzer.queue_free()
	if is_instance_valid(effectiveness_calculator):
		effectiveness_calculator.queue_free()
	if is_instance_valid(adaptation_engine):
		adaptation_engine.queue_free()

## Test advanced formation creation and management
func test_advanced_formation_creation() -> void:
	# Test creation of advanced formation types
	var combat_spread_id: String = dynamic_formation_manager.create_dynamic_formation(
		leader_ship,
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
		150.0,
		[wingman_1, wingman_2]
	)
	
	assert_that(combat_spread_id).is_not_empty()
	assert_that(dynamic_formation_manager.dynamic_formations).contains_key(combat_spread_id)
	
	var formation: DynamicFormationManager.DynamicFormation = dynamic_formation_manager.dynamic_formations[combat_spread_id]
	assert_that(formation.current_type).is_equal(DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD)
	assert_that(formation.base_formation.members.size()).is_equal(2)

## Test formation transition system
func test_formation_transitions() -> void:
	# Test smooth formation transition
	var initial_type: DynamicFormationManager.AdvancedFormationType = test_dynamic_formation.current_type
	var target_type: DynamicFormationManager.AdvancedFormationType = DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD
	
	# Initiate transition
	var transition_success: bool = dynamic_formation_manager.initiate_formation_transition(
		test_formation_id,
		target_type,
		DynamicFormationManager.TransitionType.SMOOTH
	)
	
	assert_that(transition_success).is_true()
	assert_that(test_dynamic_formation.transition_state.is_transitioning).is_true()
	assert_that(test_dynamic_formation.target_type).is_equal(target_type)
	
	# Wait for transition to complete
	await get_tree().create_timer(6.0).timeout
	assert_that(test_dynamic_formation.transition_state.is_transitioning).is_false()
	assert_that(test_dynamic_formation.current_type).is_equal(target_type)

## Test immediate emergency transitions
func test_emergency_transitions() -> void:
	# Test immediate emergency transition
	var emergency_type: DynamicFormationManager.AdvancedFormationType = DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE
	
	var transition_success: bool = dynamic_formation_manager.initiate_formation_transition(
		test_formation_id,
		emergency_type,
		DynamicFormationManager.TransitionType.IMMEDIATE
	)
	
	assert_that(transition_success).is_true()
	
	# Should complete immediately
	await get_tree().process_frame
	assert_that(test_dynamic_formation.current_type).is_equal(emergency_type)
	assert_that(test_dynamic_formation.transition_state.is_transitioning).is_false()

## Test multi-squadron coordination
func test_multi_squadron_coordination() -> void:
	# Create multiple squadrons
	var squadron_1_id: String = dynamic_formation_manager.create_dynamic_formation(
		leader_ship,
		DynamicFormationManager.AdvancedFormationType.VIC,
		100.0,
		[wingman_1]
	)
	
	var squadron_2_id: String = dynamic_formation_manager.create_dynamic_formation(
		wingman_2,
		DynamicFormationManager.AdvancedFormationType.LINE_ABREAST,
		100.0,
		[wingman_3]
	)
	
	# Create multi-squadron coordination
	var coordinator_id: String = dynamic_formation_manager.create_multi_squadron_coordination(
		[squadron_1_id, squadron_2_id],
		{
			"formation_type": DynamicFormationManager.AdvancedFormationType.FLEET_BATTLE_LINE,
			"coordination_priority": 0.8
		}
	)
	
	assert_that(coordinator_id).is_not_empty()
	assert_that(dynamic_formation_manager.squadron_coordinators).contains_key(coordinator_id)
	
	var coordinator: DynamicFormationManager.SquadronCoordinator = dynamic_formation_manager.squadron_coordinators[coordinator_id]
	assert_that(coordinator.coordinated_squadrons.size()).is_equal(2)
	assert_that(coordinator.coordinated_squadrons).contains(squadron_1_id)
	assert_that(coordinator.coordinated_squadrons).contains(squadron_2_id)

## Test tactical situation analysis
func test_tactical_situation_analysis() -> void:
	# Test tactical context analysis
	var tactical_context: Dictionary = tactical_analyzer.analyze_formation_context(test_dynamic_formation)
	
	assert_that(tactical_context).contains_keys([
		"formation_id", "timestamp", "threat_analysis", "terrain_analysis",
		"mission_analysis", "damage_analysis", "energy_analysis",
		"overall_threat_level", "terrain_complexity", "formation_readiness"
	])
	
	assert_that(tactical_context["formation_id"]).is_equal(test_formation_id)
	assert_that(tactical_context["overall_threat_level"]).is_between(0.0, 1.0)
	assert_that(tactical_context["terrain_complexity"]).is_between(0.0, 1.0)
	assert_that(tactical_context["formation_readiness"]).is_between(0.0, 1.0)

## Test formation effectiveness calculation
func test_formation_effectiveness_calculation() -> void:
	# Test effectiveness calculation
	var effectiveness: Dictionary = effectiveness_calculator.calculate_formation_effectiveness(test_dynamic_formation)
	
	assert_that(effectiveness).contains_keys([
		"overall_effectiveness", "positioning_effectiveness", "coverage_effectiveness",
		"tactical_effectiveness", "coordination_effectiveness", "adaptation_effectiveness",
		"formation_type", "ship_count", "effectiveness_grade"
	])
	
	assert_that(effectiveness["overall_effectiveness"]).is_between(0.0, 1.0)
	assert_that(effectiveness["ship_count"]).is_equal(4)  # Leader + 3 wingmen
	assert_that(effectiveness["effectiveness_grade"]).is_not_empty()
	
	# Test individual effectiveness components
	var positioning: Dictionary = effectiveness["positioning_effectiveness"]
	assert_that(positioning["score"]).is_between(0.0, 1.0)
	assert_that(positioning["formation_integrity"]).is_between(0.0, 1.0)
	
	var coverage: Dictionary = effectiveness["coverage_effectiveness"]
	assert_that(coverage["score"]).is_between(0.0, 1.0)
	assert_that(coverage["area_coverage"]).is_between(0.0, 1.0)

## Test formation adaptation engine
func test_formation_adaptation_engine() -> void:
	# Create tactical context for adaptation testing
	var tactical_context: Dictionary = {
		"overall_threat_level": 0.8,  # High threat
		"terrain_complexity": 0.3,
		"mission_urgency": 0.6,
		"formation_readiness": 0.7,
		"tactical_pressure": 0.7,
		"overall_effectiveness": 0.4  # Low effectiveness
	}
	
	# Test adaptation evaluation
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(test_dynamic_formation, tactical_context)
	
	assert_that(adaptation_analysis).contains_keys([
		"formation_id", "adaptation_required", "current_effectiveness",
		"adaptation_urgency", "adaptation_triggers", "recommendations",
		"best_recommendation", "emergency_response"
	])
	
	assert_that(adaptation_analysis["formation_id"]).is_equal(test_formation_id)
	assert_that(adaptation_analysis["adaptation_urgency"]).is_between(0.0, 1.0)
	assert_that(adaptation_analysis["recommendations"]).is_not_empty()
	
	# Should recommend adaptation due to high threat and low effectiveness
	assert_that(adaptation_analysis["adaptation_required"]).is_true()

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
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(test_dynamic_formation, high_threat_context)
	var triggers: Array = adaptation_analysis["adaptation_triggers"]
	
	# Should detect threat escalation trigger
	assert_that(triggers).contains(FormationAdaptationEngine.AdaptationTrigger.THREAT_ESCALATION)
	
	# Test formation breakdown trigger
	test_dynamic_formation.base_formation.formation_spacing = 50.0  # Force tight formation
	_move_ships_out_of_formation()
	
	var breakdown_context: Dictionary = {
		"overall_threat_level": 0.3,
		"formation_readiness": 0.9,
		"tactical_pressure": 0.2,
		"overall_effectiveness": 0.3
	}
	
	adaptation_analysis = adaptation_engine.evaluate_adaptation_needs(test_dynamic_formation, breakdown_context)
	triggers = adaptation_analysis["adaptation_triggers"]
	
	# Should detect formation breakdown trigger
	assert_that(triggers).contains(FormationAdaptationEngine.AdaptationTrigger.FORMATION_BREAKDOWN)

func _move_ships_out_of_formation() -> void:
	# Move ships far from formation positions to simulate breakdown
	wingman_1.global_position = Vector3(500, 0, 0)
	wingman_2.global_position = Vector3(-500, 0, 0)
	wingman_3.global_position = Vector3(0, 0, 500)

## Test adaptation learning system
func test_adaptation_learning_system() -> void:
	# Test learning system functionality
	var learning_system: FormationAdaptationEngine.FormationLearningSystem = adaptation_engine.learning_system
	
	# Record adaptation outcomes
	var tactical_context: Dictionary = {
		"overall_threat_level": 0.6,
		"terrain_complexity": 0.4,
		"mission_urgency": 0.7,
		"formation_readiness": 0.8
	}
	
	learning_system.record_adaptation_outcome(
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
		tactical_context,
		0.5,  # Before effectiveness
		0.8   # After effectiveness
	)
	
	# Get learning recommendation
	var recommendation: Dictionary = learning_system.get_formation_recommendation(tactical_context)
	
	assert_that(recommendation).contains_keys(["recommended_formation", "confidence", "reasoning", "learning_based"])
	assert_that(recommendation["learning_based"]).is_true()
	
	# Get learning statistics
	var stats: Dictionary = learning_system.get_learning_statistics()
	assert_that(stats).contains_keys([
		"total_formations_learned", "total_patterns_discovered", 
		"learning_enabled", "learning_rate"
	])

## Test emergency adaptation protocols
func test_emergency_adaptation_protocols() -> void:
	# Test emergency adaptation for critical threat
	var emergency_context: Dictionary = {
		"overall_threat_level": 0.95,  # Critical threat
		"formation_readiness": 0.2,    # Low readiness
		"tactical_pressure": 0.9,      # High pressure
		"overall_effectiveness": 0.1   # Very low effectiveness
	}
	
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(test_dynamic_formation, emergency_context)
	
	assert_that(adaptation_analysis["emergency_response"]).is_true()
	assert_that(adaptation_analysis["adaptation_required"]).is_true()
	assert_that(adaptation_analysis["adaptation_urgency"]).is_greater(0.8)
	
	# Test forced emergency adaptation
	var emergency_recommendation: Dictionary = adaptation_engine.force_emergency_adaptation(
		test_formation_id,
		0.95,
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE
	)
	
	assert_that(emergency_recommendation["emergency"]).is_true()
	assert_that(emergency_recommendation["confidence"]).is_equal(1.0)
	assert_that(emergency_recommendation["formation_type"]).is_equal(DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE)

## Test formation pattern application
func test_advanced_formation_patterns() -> void:
	# Test different advanced formation patterns
	var formation_types: Array[DynamicFormationManager.AdvancedFormationType] = [
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE,
		DynamicFormationManager.AdvancedFormationType.ESCORT_SCREEN,
		DynamicFormationManager.AdvancedFormationType.STRIKE_WEDGE,
		DynamicFormationManager.AdvancedFormationType.PATROL_SWEEP
	]
	
	for formation_type in formation_types:
		# Create formation of each type
		var formation_id: String = dynamic_formation_manager.create_dynamic_formation(
			leader_ship,
			formation_type,
			150.0,
			[wingman_1, wingman_2]
		)
		
		assert_that(formation_id).is_not_empty()
		
		var formation: DynamicFormationManager.DynamicFormation = dynamic_formation_manager.dynamic_formations[formation_id]
		assert_that(formation.current_type).is_equal(formation_type)
		
		# Verify formation positions are calculated
		formation.base_formation.update_formation_positions()
		assert_that(formation.base_formation.formation_positions.size()).is_greater(0)
		
		# Cleanup
		dynamic_formation_manager.destroy_dynamic_formation(formation_id)

## Test formation status and debug information
func test_formation_status_and_debugging() -> void:
	# Test formation status retrieval
	var status: Dictionary = dynamic_formation_manager.get_dynamic_formation_status(test_formation_id)
	
	assert_that(status).contains_keys([
		"formation_id", "current_type", "target_type", "is_transitioning",
		"transition_progress", "effectiveness_metrics", "adaptation_parameters"
	])
	
	assert_that(status["formation_id"]).is_equal(test_formation_id)
	assert_that(status["current_type"]).is_not_empty()
	
	# Test performance statistics
	var performance: Dictionary = dynamic_formation_manager.get_formation_performance_statistics()
	assert_that(performance).contains_keys([
		"formations_created", "transitions_completed", "adaptations_triggered"
	])
	
	# Test adaptation performance statistics
	var adaptation_stats: Dictionary = adaptation_engine.get_adaptation_performance_statistics()
	assert_that(adaptation_stats).contains_keys([
		"total_evaluations", "adaptations_triggered", "adaptation_success_rate"
	])

## Test integrated formation management workflow
func test_integrated_formation_workflow() -> void:
	# Test complete workflow: analysis -> adaptation -> transition -> effectiveness
	
	# 1. Analyze tactical situation
	var tactical_context: Dictionary = tactical_analyzer.analyze_formation_context(test_dynamic_formation)
	assert_that(tactical_context).is_not_empty()
	
	# 2. Calculate current effectiveness
	var initial_effectiveness: Dictionary = effectiveness_calculator.calculate_formation_effectiveness(test_dynamic_formation)
	var initial_score: float = initial_effectiveness["overall_effectiveness"]
	
	# 3. Evaluate adaptation needs
	var adaptation_analysis: Dictionary = adaptation_engine.evaluate_adaptation_needs(test_dynamic_formation, tactical_context)
	
	# 4. If adaptation recommended, perform transition
	if adaptation_analysis["adaptation_required"]:
		var best_recommendation: Dictionary = adaptation_analysis["best_recommendation"]
		var new_formation_type: DynamicFormationManager.AdvancedFormationType = best_recommendation["formation_type"]
		
		var transition_success: bool = dynamic_formation_manager.initiate_formation_transition(
			test_formation_id,
			new_formation_type,
			DynamicFormationManager.TransitionType.SMOOTH
		)
		
		assert_that(transition_success).is_true()
		
		# Wait for transition
		await get_tree().create_timer(6.0).timeout
		
		# 5. Calculate final effectiveness
		var final_effectiveness: Dictionary = effectiveness_calculator.calculate_formation_effectiveness(test_dynamic_formation)
		var final_score: float = final_effectiveness["overall_effectiveness"]
		
		# 6. Record adaptation outcome for learning
		adaptation_engine.record_adaptation_outcome(
			test_formation_id,
			test_dynamic_formation.current_type,
			new_formation_type,
			tactical_context,
			initial_score,
			final_score
		)
		
		# Verify workflow completed successfully
		assert_that(test_dynamic_formation.current_type).is_equal(new_formation_type)

## Test performance under load
func test_formation_management_performance() -> void:
	# Create multiple formations for performance testing
	var formations: Array[String] = []
	var formation_count: int = 10
	
	var start_time: float = Time.get_time_from_system() * 1000.0
	
	# Create formations
	for i in range(formation_count):
		var formation_id: String = dynamic_formation_manager.create_dynamic_formation(
			leader_ship,
			DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
			120.0,
			[wingman_1, wingman_2]
		)
		formations.append(formation_id)
	
	var creation_time: float = (Time.get_time_from_system() * 1000.0) - start_time
	
	# Test effectiveness calculation performance
	start_time = Time.get_time_from_system() * 1000.0
	
	for formation_id in formations:
		var formation: DynamicFormationManager.DynamicFormation = dynamic_formation_manager.dynamic_formations[formation_id]
		effectiveness_calculator.calculate_formation_effectiveness(formation)
	
	var calculation_time: float = (Time.get_time_from_system() * 1000.0) - start_time
	
	# Performance assertions
	assert_that(creation_time).is_less(100.0)  # Should create 10 formations in under 100ms
	assert_that(calculation_time).is_less(50.0)  # Should calculate effectiveness in under 50ms
	
	# Cleanup
	for formation_id in formations:
		dynamic_formation_manager.destroy_dynamic_formation(formation_id)

## Test error handling and edge cases
func test_error_handling() -> void:
	# Test invalid formation transitions
	var invalid_transition: bool = dynamic_formation_manager.initiate_formation_transition(
		"invalid_id",
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD
	)
	assert_that(invalid_transition).is_false()
	
	# Test adaptation with empty formation
	var empty_formation: DynamicFormationManager.DynamicFormation = DynamicFormationManager.DynamicFormation.new("empty", null)
	var empty_context: Dictionary = {}
	
	# Should handle gracefully without crashing
	var adaptation_result: Dictionary = adaptation_engine.evaluate_adaptation_needs(empty_formation, empty_context)
	assert_that(adaptation_result).is_not_empty()
	
	# Test status retrieval for non-existent formation
	var invalid_status: Dictionary = dynamic_formation_manager.get_dynamic_formation_status("invalid_id")
	assert_that(invalid_status).is_empty()

## Test signal emissions
func test_signal_emissions() -> void:
	# Monitor signals
	var formation_signals: Array[String] = []
	var adaptation_signals: Array[String] = []
	
	# Connect to signals
	dynamic_formation_manager.formation_transition_started.connect(func(id, old, new): formation_signals.append("transition_started"))
	dynamic_formation_manager.formation_transition_completed.connect(func(id, new, time): formation_signals.append("transition_completed"))
	adaptation_engine.adaptation_evaluated.connect(func(id, analysis): adaptation_signals.append("adaptation_evaluated"))
	
	# Trigger adaptation and transition
	var tactical_context: Dictionary = {
		"overall_threat_level": 0.8,
		"formation_readiness": 0.5,
		"overall_effectiveness": 0.3
	}
	
	adaptation_engine.evaluate_adaptation_needs(test_dynamic_formation, tactical_context)
	assert_that(adaptation_signals).contains("adaptation_evaluated")
	
	# Trigger transition
	dynamic_formation_manager.initiate_formation_transition(
		test_formation_id,
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD,
		DynamicFormationManager.TransitionType.IMMEDIATE
	)
	
	assert_that(formation_signals).contains("transition_started")
	
	# Wait for transition completion
	await get_tree().process_frame
	assert_that(formation_signals).contains("transition_completed")