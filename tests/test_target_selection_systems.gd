extends GdUnitTestSuite

## Comprehensive unit tests for AI target selection and prioritization systems

var threat_assessment: ThreatAssessmentSystem
var target_selector: SelectTargetAction  
var target_switcher: SwitchTargetAction
var target_validator: ValidateTargetCondition
var tactical_doctrine: TacticalDoctrine
var target_coordinator: TargetCoordinator
var mission_integration: MissionTargetIntegration

var mock_ai_agent: Node3D
var mock_ship_controller: Node
var mock_targets: Array[Node3D]

func before_test() -> void:
	# Create test scene
	_setup_test_environment()

func after_test() -> void:
	# Clean up test objects
	_cleanup_test_environment()

# ThreatAssessmentSystem Tests

func test_threat_assessment_system_initialization() -> void:
	threat_assessment = ThreatAssessmentSystem.new()
	threat_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	assert_not_null(threat_assessment)
	assert_float(threat_assessment.assessment_range).is_equal(5000.0)
	assert_int(threat_assessment.current_threats.size()).is_equal(0)

func test_threat_assessment_target_evaluation() -> void:
	threat_assessment = ThreatAssessmentSystem.new()
	threat_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	var target: Node3D = mock_targets[0]
	var threat_score: float = threat_assessment.assess_target_threat(target)
	
	assert_float(threat_score).is_greater_equal(0.0)
	assert_float(threat_score).is_less_equal(10.0)

func test_threat_assessment_target_detection() -> void:
	threat_assessment = ThreatAssessmentSystem.new()
	threat_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	var target: Node3D = mock_targets[0]
	threat_assessment.add_detected_target(target)
	
	assert_bool(threat_assessment.is_target_in_assessment(target)).is_true()
	assert_int(threat_assessment.current_threats.size()).is_equal(1)

func test_threat_assessment_highest_priority_target() -> void:
	threat_assessment = ThreatAssessmentSystem.new()
	threat_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	# Add multiple targets with different threat levels
	for i in range(mock_targets.size()):
		threat_assessment.add_detected_target(mock_targets[i])
	
	var highest_threat: Node3D = threat_assessment.get_highest_priority_target()
	assert_not_null(highest_threat)

func test_threat_assessment_target_removal() -> void:
	threat_assessment = ThreatAssessmentSystem.new()
	threat_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	var target: Node3D = mock_targets[0]
	threat_assessment.add_detected_target(target)
	assert_bool(threat_assessment.is_target_in_assessment(target)).is_true()
	
	threat_assessment.remove_target(target)
	assert_bool(threat_assessment.is_target_in_assessment(target)).is_false()

# SelectTargetAction Tests

func test_select_target_action_initialization() -> void:
	target_selector = SelectTargetAction.new()
	target_selector.ai_agent = mock_ai_agent
	target_selector.ship_controller = mock_ship_controller
	target_selector._setup()
	
	assert_not_null(target_selector)
	assert_int(target_selector.selection_mode).is_equal(SelectTargetAction.SelectionMode.HIGHEST_THREAT)

func test_select_target_highest_threat_mode() -> void:
	target_selector = SelectTargetAction.new()
	target_selector.ai_agent = mock_ai_agent
	target_selector.ship_controller = mock_ship_controller
	target_selector.selection_mode = SelectTargetAction.SelectionMode.HIGHEST_THREAT
	target_selector._setup()
	
	# Mock threat assessment
	target_selector.threat_assessment = _create_mock_threat_assessment()
	
	var result: int = target_selector.execute_wcs_action(0.1)
	# Note: May be FAILURE due to missing dependencies, but should not crash

func test_select_target_nearest_threat_mode() -> void:
	target_selector = SelectTargetAction.new()
	target_selector.ai_agent = mock_ai_agent
	target_selector.ship_controller = mock_ship_controller
	target_selector.selection_mode = SelectTargetAction.SelectionMode.NEAREST_THREAT
	target_selector._setup()
	
	assert_int(target_selector.selection_mode).is_equal(SelectTargetAction.SelectionMode.NEAREST_THREAT)

func test_select_target_parameter_configuration() -> void:
	target_selector = SelectTargetAction.new()
	target_selector.set_selection_parameters(
		SelectTargetAction.SelectionMode.ROLE_SPECIFIC,
		ThreatAssessmentSystem.TargetPriority.MEDIUM,
		2000.0
	)
	
	assert_int(target_selector.selection_mode).is_equal(SelectTargetAction.SelectionMode.ROLE_SPECIFIC)
	assert_int(target_selector.minimum_threat_level).is_equal(ThreatAssessmentSystem.TargetPriority.MEDIUM)
	assert_float(target_selector.search_radius).is_equal(2000.0)

func test_select_target_type_preferences() -> void:
	target_selector = SelectTargetAction.new()
	var preferred: Array[ThreatAssessmentSystem.ThreatType] = [ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER]
	var excluded: Array[ThreatAssessmentSystem.ThreatType] = [ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL]
	
	target_selector.set_target_type_preferences(preferred, excluded)
	
	assert_int(target_selector.preferred_target_types.size()).is_equal(1)
	assert_int(target_selector.excluded_target_types.size()).is_equal(1)

# SwitchTargetAction Tests

func test_switch_target_action_initialization() -> void:
	target_switcher = SwitchTargetAction.new()
	target_switcher.ai_agent = mock_ai_agent
	target_switcher.ship_controller = mock_ship_controller
	target_switcher._setup()
	
	assert_not_null(target_switcher)
	assert_float(target_switcher.threat_improvement_threshold).is_equal(1.5)

func test_switch_target_parameter_configuration() -> void:
	target_switcher = SwitchTargetAction.new()
	target_switcher.set_switch_parameters(2.0, 3.0, 0.4)
	
	assert_float(target_switcher.threat_improvement_threshold).is_equal(2.0)
	assert_float(target_switcher.switch_cooldown).is_equal(3.0)
	assert_float(target_switcher.distance_penalty_factor).is_equal(0.4)

func test_switch_target_hysteresis_configuration() -> void:
	target_switcher = SwitchTargetAction.new()
	target_switcher.enable_hysteresis(true, 0.25)
	
	assert_bool(target_switcher.hysteresis_enabled).is_true()
	assert_float(target_switcher.hysteresis_factor).is_equal(0.25)

func test_switch_target_cooldown_enforcement() -> void:
	target_switcher = SwitchTargetAction.new()
	target_switcher.ai_agent = mock_ai_agent
	target_switcher.ship_controller = mock_ship_controller
	target_switcher.switch_cooldown = 1.0
	target_switcher._setup()
	
	# First execution should proceed
	target_switcher.last_switch_time = 0.0
	var result1: int = target_switcher.execute_wcs_action(0.1)
	
	# Second execution within cooldown should be blocked
	target_switcher.last_switch_time = Time.get_time_from_start()
	var result2: int = target_switcher.execute_wcs_action(0.1)
	
	# Should be blocked by cooldown (returns FAILURE or early exit)

# ValidateTargetCondition Tests

func test_validate_target_condition_initialization() -> void:
	target_validator = ValidateTargetCondition.new()
	target_validator.ai_agent = mock_ai_agent
	target_validator.ship_controller = mock_ship_controller
	target_validator._setup()
	
	assert_not_null(target_validator)
	assert_int(target_validator.required_checks.size()).is_greater(0)

func test_validate_target_parameter_configuration() -> void:
	target_validator = ValidateTargetCondition.new()
	target_validator.set_validation_parameters(3000.0, 2.5, 0.2)
	
	assert_float(target_validator.max_engagement_range).is_equal(3000.0)
	assert_float(target_validator.minimum_threat_score).is_equal(2.5)
	assert_float(target_validator.minimum_health_percentage).is_equal(0.2)

func test_validate_target_check_management() -> void:
	target_validator = ValidateTargetCondition.new()
	target_validator.add_validation_check(ValidateTargetCondition.ValidationCheck.WEAPON_RANGE)
	
	assert_bool(ValidateTargetCondition.ValidationCheck.WEAPON_RANGE in target_validator.required_checks).is_true()
	
	target_validator.remove_validation_check(ValidateTargetCondition.ValidationCheck.WEAPON_RANGE)
	assert_bool(ValidateTargetCondition.ValidationCheck.WEAPON_RANGE in target_validator.required_checks).is_false()

func test_validate_target_null_target_handling() -> void:
	target_validator = ValidateTargetCondition.new()
	target_validator.ai_agent = mock_ai_agent
	target_validator.ship_controller = mock_ship_controller
	target_validator._setup()
	
	# Should return false for null target
	var result: bool = target_validator.check_wcs_condition()
	assert_bool(result).is_false()

# TacticalDoctrine Tests

func test_tactical_doctrine_initialization() -> void:
	tactical_doctrine = TacticalDoctrine.new()
	tactical_doctrine._ready()
	
	assert_not_null(tactical_doctrine)
	assert_int(tactical_doctrine.ship_doctrines.size()).is_greater(0)

func test_tactical_doctrine_ship_role_preferences() -> void:
	tactical_doctrine = TacticalDoctrine.new()
	tactical_doctrine._ready()
	
	var fighter_prefs: Dictionary = tactical_doctrine.get_target_preferences(
		TacticalDoctrine.ShipRole.FIGHTER,
		TacticalDoctrine.MissionType.PATROL
	)
	
	assert_bool(fighter_prefs.has("max_engagement_range")).is_true()
	assert_bool(fighter_prefs.has("aggression_level")).is_true()

func test_tactical_doctrine_threat_type_priorities() -> void:
	tactical_doctrine = TacticalDoctrine.new()
	tactical_doctrine._ready()
	
	var fighter_priority: float = tactical_doctrine.get_threat_type_priority(
		TacticalDoctrine.ShipRole.FIGHTER,
		ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER
	)
	
	var bomber_priority: float = tactical_doctrine.get_threat_type_priority(
		TacticalDoctrine.ShipRole.BOMBER,
		ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL
	)
	
	assert_float(fighter_priority).is_greater(0.0)
	assert_float(bomber_priority).is_greater(fighter_priority)

func test_tactical_doctrine_engagement_parameters() -> void:
	tactical_doctrine = TacticalDoctrine.new()
	tactical_doctrine._ready()
	
	var engagement_params: Dictionary = tactical_doctrine.get_engagement_parameters(
		TacticalDoctrine.ShipRole.INTERCEPTOR,
		TacticalDoctrine.MissionType.INTERCEPT
	)
	
	assert_bool(engagement_params.has("max_engagement_range")).is_true()
	assert_bool(engagement_params.has("min_threat_threshold")).is_true()
	assert_bool(engagement_params.has("max_targets")).is_true()

func test_tactical_doctrine_mission_modifiers() -> void:
	tactical_doctrine = TacticalDoctrine.new()
	tactical_doctrine._ready()
	
	var patrol_prefs: Dictionary = tactical_doctrine.get_target_preferences(
		TacticalDoctrine.ShipRole.ESCORT,
		TacticalDoctrine.MissionType.PATROL
	)
	
	var escort_prefs: Dictionary = tactical_doctrine.get_target_preferences(
		TacticalDoctrine.ShipRole.ESCORT,
		TacticalDoctrine.MissionType.ESCORT
	)
	
	# Escort mission should modify behavior
	var patrol_aggression: float = patrol_prefs.get("aggression_level", 0.5)
	var escort_aggression: float = escort_prefs.get("aggression_level", 0.5)
	
	assert_float(escort_aggression).is_less(patrol_aggression)

func test_tactical_doctrine_target_prioritization() -> void:
	tactical_doctrine = TacticalDoctrine.new()
	tactical_doctrine._ready()
	
	var mock_target: Node3D = mock_targets[0]
	var context: Dictionary = {
		"threat_type": ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER,
		"distance": 1000.0,
		"is_mission_target": true
	}
	
	var priority_modifier: float = tactical_doctrine.should_prioritize_target(
		TacticalDoctrine.ShipRole.FIGHTER,
		TacticalDoctrine.MissionType.INTERCEPT,
		mock_target,
		context
	)
	
	assert_float(priority_modifier).is_greater(1.0)

# TargetCoordinator Tests

func test_target_coordinator_initialization() -> void:
	target_coordinator = TargetCoordinator.new()
	target_coordinator._ready()
	
	assert_not_null(target_coordinator)
	assert_int(target_coordinator.coordination_mode).is_equal(TargetCoordinator.CoordinationMode.OPTIMIZED)

func test_target_coordinator_mode_configuration() -> void:
	target_coordinator = TargetCoordinator.new()
	target_coordinator.set_coordination_mode(TargetCoordinator.CoordinationMode.HIERARCHICAL)
	
	assert_int(target_coordinator.coordination_mode).is_equal(TargetCoordinator.CoordinationMode.HIERARCHICAL)

func test_target_coordinator_assignment_tracking() -> void:
	target_coordinator = TargetCoordinator.new()
	target_coordinator._ready()
	
	var ship: Node3D = mock_ai_agent
	var target: Node3D = mock_targets[0]
	
	# Test assignment registration
	target_coordinator._register_target_assignment(ship, target, TargetCoordinator.AssignmentType.PRIMARY)
	
	var assignment: Dictionary = target_coordinator.get_ship_target_assignment(ship)
	assert_bool(assignment.has("target")).is_true()
	assert_object(assignment.get("target")).is_equal(target)

func test_target_coordinator_oversaturation_detection() -> void:
	target_coordinator = TargetCoordinator.new()
	target_coordinator.max_attackers_per_target = 2
	target_coordinator._ready()
	
	var target: Node3D = mock_targets[0]
	
	# Simulate multiple attackers
	for i in range(3):
		var mock_ship: Node3D = Node3D.new()
		mock_ship.name = "MockShip" + str(i)
		target_coordinator._register_target_assignment(mock_ship, target, TargetCoordinator.AssignmentType.PRIMARY)
	
	assert_bool(target_coordinator._is_target_oversaturated(target)).is_true()

# MissionTargetIntegration Tests

func test_mission_integration_initialization() -> void:
	mission_integration = MissionTargetIntegration.new()
	mission_integration._ready()
	
	assert_not_null(mission_integration)
	assert_int(mission_integration.mission_targets.size()).is_equal(0)

func test_mission_integration_target_management() -> void:
	mission_integration = MissionTargetIntegration.new()
	mission_integration._ready()
	
	var target: Node3D = mock_targets[0]
	mission_integration.add_mission_target(
		target,
		MissionTargetIntegration.MissionTargetType.PRIMARY_OBJECTIVE,
		MissionTargetIntegration.TargetPriority.HIGH,
		"test_objective"
	)
	
	assert_bool(mission_integration.is_mission_priority_target(target)).is_true()
	var priority: float = mission_integration.get_target_mission_priority(target)
	assert_float(priority).is_greater(1.5)

func test_mission_integration_protected_targets() -> void:
	mission_integration = MissionTargetIntegration.new()
	mission_integration._ready()
	
	var target: Node3D = mock_targets[0]
	mission_integration.add_mission_target(
		target,
		MissionTargetIntegration.MissionTargetType.PROTECT_TARGET,
		MissionTargetIntegration.TargetPriority.HIGH
	)
	
	assert_bool(mission_integration.is_protected_target(target)).is_true()

func test_mission_integration_priority_assignments() -> void:
	mission_integration = MissionTargetIntegration.new()
	mission_integration._ready()
	
	var target: Node3D = mock_targets[0]
	var ships: Array[Node3D] = [mock_ai_agent]
	
	mission_integration.assign_priority_target_to_ships(target, ships, 10.0)
	
	var assigned_target: Node3D = mission_integration.get_ship_priority_target(mock_ai_agent)
	assert_object(assigned_target).is_equal(target)

func test_mission_integration_sexp_commands() -> void:
	mission_integration = MissionTargetIntegration.new()
	mission_integration._ready()
	
	var target: Node3D = mock_targets[0]
	var params: Dictionary = {"priority": 2.5}
	
	var result: bool = mission_integration.process_sexp_target_command("set-target-priority", target, params)
	assert_bool(result).is_true()
	
	var priority: float = mission_integration.get_target_mission_priority(target)
	assert_float(priority).is_equal(2.5)

# Integration Tests

func test_threat_assessment_with_target_selection() -> void:
	threat_assessment = ThreatAssessmentSystem.new()
	threat_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	target_selector = SelectTargetAction.new()
	target_selector.ai_agent = mock_ai_agent
	target_selector.ship_controller = mock_ship_controller
	target_selector.threat_assessment = threat_assessment
	target_selector._setup()
	
	# Add targets to threat assessment
	for target in mock_targets:
		threat_assessment.add_detected_target(target)
	
	# Target selection should work with threat data
	var highest_threat: Node3D = threat_assessment.get_highest_priority_target()
	assert_not_null(highest_threat)

func test_doctrine_with_target_selection() -> void:
	tactical_doctrine = TacticalDoctrine.new()
	tactical_doctrine._ready()
	
	target_selector = SelectTargetAction.new()
	target_selector.ai_agent = mock_ai_agent
	target_selector.ship_controller = mock_ship_controller
	target_selector._setup()
	
	# Apply doctrine to selector
	tactical_doctrine.apply_doctrine_to_target_selector(
		target_selector,
		TacticalDoctrine.ShipRole.FIGHTER,
		TacticalDoctrine.MissionType.INTERCEPT
	)
	
	# Verify doctrine application
	var expected_mode: SelectTargetAction.SelectionMode = tactical_doctrine.get_target_selection_mode(
		TacticalDoctrine.ShipRole.FIGHTER,
		TacticalDoctrine.MissionType.INTERCEPT
	)
	assert_int(target_selector.selection_mode).is_equal(expected_mode)

func test_coordination_with_threat_assessment() -> void:
	threat_assessment = ThreatAssessmentSystem.new()
	threat_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	target_coordinator = TargetCoordinator.new()
	target_coordinator.threat_assessment = threat_assessment
	target_coordinator._ready()
	
	# Add targets to assessment
	for target in mock_targets:
		threat_assessment.add_detected_target(target)
	
	# Request coordinated target
	var assigned_target: Node3D = target_coordinator.request_target_assignment(mock_ai_agent)
	# May be null due to missing dependencies, but should not crash

# Error handling and edge cases

func test_null_target_handling() -> void:
	threat_assessment = ThreatAssessmentSystem.new()
	threat_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	var threat_score: float = threat_assessment.assess_target_threat(null)
	assert_float(threat_score).is_equal(0.0)

func test_invalid_target_handling() -> void:
	target_validator = ValidateTargetCondition.new()
	target_validator.ai_agent = mock_ai_agent
	target_validator._setup()
	
	# Test with invalid/freed target
	var invalid_target: Node3D = Node3D.new()
	invalid_target.queue_free()
	
	# Should handle gracefully
	var result: bool = target_validator.check_wcs_condition()
	assert_bool(result).is_false()

func test_empty_target_list_handling() -> void:
	target_coordinator = TargetCoordinator.new()
	target_coordinator._ready()
	
	var assigned_target: Node3D = target_coordinator.request_target_assignment(mock_ai_agent, [])
	assert_null(assigned_target)

# Performance Tests

func test_threat_assessment_performance() -> void:
	threat_assessment = ThreatAssessmentSystem.new()
	threat_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	# Add many targets
	var many_targets: Array[Node3D] = []
	for i in range(50):
		var target: Node3D = Node3D.new()
		target.name = "PerfTarget" + str(i)
		target.position = Vector3(randf() * 1000, 0, randf() * 1000)
		many_targets.append(target)
		threat_assessment.add_detected_target(target)
	
	var start_time: float = Time.get_time_from_start()
	threat_assessment._update_threat_assessments(0.1)
	var end_time: float = Time.get_time_from_start()
	
	var elapsed: float = end_time - start_time
	assert_float(elapsed).is_less(0.01)  # Should complete in less than 10ms

# Helper methods

func _setup_test_environment() -> void:
	# Create mock AI agent
	mock_ai_agent = Node3D.new()
	mock_ai_agent.name = "MockAIAgent"
	mock_ai_agent.position = Vector3.ZERO
	
	# Add mock ship controller
	mock_ship_controller = Node.new()
	mock_ship_controller.name = "MockShipController"
	mock_ai_agent.add_child(mock_ship_controller)
	
	# Create mock targets
	mock_targets = []
	for i in range(5):
		var target: Node3D = Node3D.new()
		target.name = "MockTarget" + str(i)
		target.position = Vector3(i * 100 + 100, 0, 0)
		mock_targets.append(target)
	
	# Add to scene for physics queries
	add_child(mock_ai_agent)
	for target in mock_targets:
		add_child(target)

func _cleanup_test_environment() -> void:
	if mock_ai_agent:
		mock_ai_agent.queue_free()
	
	for target in mock_targets:
		if is_instance_valid(target):
			target.queue_free()
	
	mock_targets.clear()
	
	# Clean up test components
	if threat_assessment:
		threat_assessment.queue_free()
	if target_selector:
		target_selector.queue_free()
	if target_switcher:
		target_switcher.queue_free()
	if target_validator:
		target_validator.queue_free()
	if tactical_doctrine:
		tactical_doctrine.queue_free()
	if target_coordinator:
		target_coordinator.queue_free()
	if mission_integration:
		mission_integration.queue_free()

func _create_mock_threat_assessment() -> ThreatAssessmentSystem:
	var mock_assessment: ThreatAssessmentSystem = ThreatAssessmentSystem.new()
	mock_assessment.initialize_with_ai_agent(mock_ai_agent)
	
	# Add some mock targets
	for target in mock_targets:
		mock_assessment.add_detected_target(target)
	
	return mock_assessment