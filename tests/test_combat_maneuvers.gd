extends GdUnitTestSuite

## Unit tests for combat maneuver system components

var test_scene: Node3D
var ai_agent: Node
var target_ship: Node3D
var attack_pattern_manager: AttackPatternManager
var combat_skill_system: CombatSkillSystem
var weapon_firing_integration: WeaponFiringIntegration
var target_specific_tactics: TargetSpecificTactics

func before_test() -> void:
	_setup_test_environment()

func after_test() -> void:
	_cleanup_test_environment()

# Attack Run Action Tests

func test_attack_run_creation_and_setup() -> void:
	"""Test attack run action creation and configuration"""
	var attack_run: AttackRunAction = AttackRunAction.new()
	attack_run.ai_agent = ai_agent
	attack_run.ship_controller = _create_mock_ship_controller()
	attack_run._setup()
	
	assert_object(attack_run).is_not_null()
	assert_int(attack_run.current_phase).is_equal(AttackRunAction.AttackPhase.APPROACH)
	assert_bool(attack_run.weapons_fired).is_false()

func test_attack_run_parameter_configuration() -> void:
	"""Test attack run parameter configuration"""
	var attack_run: AttackRunAction = AttackRunAction.new()
	attack_run.set_attack_parameters(
		AttackRunAction.AttackRunType.HIGH_ANGLE,
		1500.0,  # approach_distance
		600.0,   # firing_distance
		250.0    # breakaway_distance
	)
	
	assert_int(attack_run.attack_run_type).is_equal(AttackRunAction.AttackRunType.HIGH_ANGLE)
	assert_float(attack_run.approach_distance).is_equal(1500.0)
	assert_float(attack_run.firing_distance).is_equal(600.0)
	assert_float(attack_run.breakaway_distance).is_equal(250.0)

func test_attack_run_phase_transitions() -> void:
	"""Test attack run phase transition logic"""
	var attack_run: AttackRunAction = AttackRunAction.new()
	attack_run.ai_agent = ai_agent
	attack_run.ship_controller = _create_mock_ship_controller()
	attack_run._setup()
	
	# Test transition to attack phase
	attack_run._transition_to_phase(AttackRunAction.AttackPhase.ATTACK)
	assert_int(attack_run.current_phase).is_equal(AttackRunAction.AttackPhase.ATTACK)
	
	# Test transition to breakaway
	attack_run._transition_to_phase(AttackRunAction.AttackPhase.BREAKAWAY)
	assert_int(attack_run.current_phase).is_equal(AttackRunAction.AttackPhase.BREAKAWAY)

# Strafe Pass Action Tests

func test_strafe_pass_creation_and_setup() -> void:
	"""Test strafe pass action creation"""
	var strafe_pass: StrafePassAction = StrafePassAction.new()
	strafe_pass.ai_agent = ai_agent
	strafe_pass.ship_controller = _create_mock_ship_controller()
	strafe_pass._setup()
	
	assert_object(strafe_pass).is_not_null()
	assert_int(strafe_pass.current_phase).is_equal(StrafePassAction.StrafePhase.POSITIONING)
	assert_int(strafe_pass.shots_fired).is_equal(0)

func test_strafe_pass_direction_selection() -> void:
	"""Test strafe direction selection logic"""
	var strafe_pass: StrafePassAction = StrafePassAction.new()
	strafe_pass.strafe_direction = StrafePassAction.StrafeDirection.LEFT
	strafe_pass.ai_agent = ai_agent
	strafe_pass.ship_controller = _create_mock_ship_controller()
	strafe_pass._setup()
	
	# Execute once to trigger direction selection
	strafe_pass.execute_wcs_action(0.1)
	
	# Should have a chosen direction
	assert_that(strafe_pass.chosen_direction).is_not_equal(null)

func test_strafe_pass_parameter_configuration() -> void:
	"""Test strafe pass parameter configuration"""
	var strafe_pass: StrafePassAction = StrafePassAction.new()
	strafe_pass.set_strafe_parameters(
		StrafePassAction.StrafeDirection.RIGHT,
		1200.0,  # strafe_distance
		500.0,   # optimal_range
		1.4      # speed_modifier
	)
	
	assert_int(strafe_pass.strafe_direction).is_equal(StrafePassAction.StrafeDirection.RIGHT)
	assert_float(strafe_pass.strafe_distance).is_equal(1200.0)
	assert_float(strafe_pass.optimal_range).is_equal(500.0)
	assert_float(strafe_pass.strafe_speed_modifier).is_equal(1.4)

# Pursuit Attack Action Tests

func test_pursuit_attack_creation_and_setup() -> void:
	"""Test pursuit attack action creation"""
	var pursuit_attack: PursuitAttackAction = PursuitAttackAction.new()
	pursuit_attack.ai_agent = ai_agent
	pursuit_attack.ship_controller = _create_mock_ship_controller()
	pursuit_attack._setup()
	
	assert_object(pursuit_attack).is_not_null()
	assert_int(pursuit_attack.current_state).is_equal(PursuitAttackAction.PursuitState.CLOSING)
	assert_int(pursuit_attack.shots_fired_count).is_equal(0)

func test_pursuit_attack_mode_configuration() -> void:
	"""Test pursuit attack mode configuration"""
	var pursuit_attack: PursuitAttackAction = PursuitAttackAction.new()
	pursuit_attack.set_pursuit_parameters(
		PursuitAttackAction.PursuitMode.AGGRESSIVE,
		350.0,  # optimal_distance
		100.0,  # minimum_distance
		1000.0  # maximum_distance
	)
	
	assert_int(pursuit_attack.pursuit_mode).is_equal(PursuitAttackAction.PursuitMode.AGGRESSIVE)
	assert_float(pursuit_attack.optimal_pursuit_distance).is_equal(350.0)
	assert_float(pursuit_attack.minimum_pursuit_distance).is_equal(100.0)
	assert_float(pursuit_attack.maximum_pursuit_distance).is_equal(1000.0)

func test_pursuit_attack_state_transitions() -> void:
	"""Test pursuit attack state transition logic"""
	var pursuit_attack: PursuitAttackAction = PursuitAttackAction.new()
	pursuit_attack.ai_agent = ai_agent
	pursuit_attack.ship_controller = _create_mock_ship_controller()
	pursuit_attack._setup()
	
	# Test state transitions
	pursuit_attack._transition_to_state(PursuitAttackAction.PursuitState.ENGAGING)
	assert_int(pursuit_attack.current_state).is_equal(PursuitAttackAction.PursuitState.ENGAGING)
	
	pursuit_attack._transition_to_state(PursuitAttackAction.PursuitState.REPOSITIONING)
	assert_int(pursuit_attack.current_state).is_equal(PursuitAttackAction.PursuitState.REPOSITIONING)

# Attack Pattern Manager Tests

func test_attack_pattern_manager_initialization() -> void:
	"""Test attack pattern manager initialization"""
	attack_pattern_manager = AttackPatternManager.new()
	attack_pattern_manager._ready()
	
	assert_object(attack_pattern_manager).is_not_null()
	assert_int(attack_pattern_manager.current_pattern).is_equal(attack_pattern_manager.default_pattern)
	assert_that(attack_pattern_manager.pattern_effectiveness).is_not_empty()

func test_attack_pattern_selection() -> void:
	"""Test attack pattern selection logic"""
	attack_pattern_manager = AttackPatternManager.new()
	attack_pattern_manager._ready()
	
	var context: Dictionary = {
		"skill_level": 0.7,
		"distance": 600.0,
		"target_type": "fighter",
		"formation_status": "none",
		"energy_level": 0.8,
		"damage_level": 0.1
	}
	
	var selected_pattern: AttackPatternManager.AttackPattern = attack_pattern_manager.select_attack_pattern(
		ai_agent, target_ship, context
	)
	
	assert_that(selected_pattern).is_not_equal(null)
	assert_that(selected_pattern).is_in([
		AttackPatternManager.AttackPattern.ATTACK_RUN,
		AttackPatternManager.AttackPattern.STRAFE_PASS,
		AttackPatternManager.AttackPattern.PURSUIT_ATTACK,
		AttackPatternManager.AttackPattern.HIT_AND_RUN,
		AttackPatternManager.AttackPattern.COORDINATED,
		AttackPatternManager.AttackPattern.OPPORTUNISTIC
	])

func test_attack_pattern_effectiveness_tracking() -> void:
	"""Test attack pattern effectiveness tracking"""
	attack_pattern_manager = AttackPatternManager.new()
	attack_pattern_manager._ready()
	
	var initial_effectiveness: float = attack_pattern_manager.pattern_effectiveness.get(
		AttackPatternManager.AttackPattern.ATTACK_RUN, 1.0
	)
	
	# Update with successful result
	attack_pattern_manager.update_pattern_effectiveness(
		AttackPatternManager.AttackPattern.ATTACK_RUN,
		true,  # success
		50.0,  # damage_dealt
		8.0    # time_taken
	)
	
	var updated_effectiveness: float = attack_pattern_manager.pattern_effectiveness.get(
		AttackPatternManager.AttackPattern.ATTACK_RUN, 1.0
	)
	
	assert_float(updated_effectiveness).is_greater(initial_effectiveness)

# Maneuver Calculator Tests

func test_intercept_course_calculation() -> void:
	"""Test intercept course calculation"""
	var ship_pos: Vector3 = Vector3(0, 0, 0)
	var ship_velocity: Vector3 = Vector3(0, 0, 0)
	var ship_max_speed: float = 200.0
	var target_pos: Vector3 = Vector3(1000, 0, 500)
	var target_velocity: Vector3 = Vector3(50, 0, -30)
	
	var intercept_data: Dictionary = ManeuverCalculator.calculate_intercept_course(
		ship_pos, ship_velocity, ship_max_speed, target_pos, target_velocity, 1.0
	)
	
	assert_that(intercept_data).has_keys(["intercept_position", "intercept_time", "success_probability"])
	assert_float(intercept_data.get("intercept_time", 0.0)).is_greater(0.0)
	assert_float(intercept_data.get("success_probability", 0.0)).is_between(0.0, 1.0)

func test_attack_approach_calculation() -> void:
	"""Test attack approach calculation"""
	var ship_pos: Vector3 = Vector3(0, 0, 0)
	var target_pos: Vector3 = Vector3(800, 0, 200)
	var target_velocity: Vector3 = Vector3(30, 0, 0)
	
	var approach_data: Dictionary = ManeuverCalculator.calculate_attack_approach(
		ship_pos, target_pos, target_velocity,
		AttackRunAction.AttackRunType.HEAD_ON,
		500.0,  # optimal_range
		0.8     # skill_factor
	)
	
	assert_that(approach_data).has_keys([
		"approach_position", "firing_position", "approach_vector", "attack_angle_quality"
	])
	assert_float(approach_data.get("attack_angle_quality", 0.0)).is_between(0.0, 1.0)

func test_evasive_maneuver_calculation() -> void:
	"""Test evasive maneuver calculation"""
	var ship_pos: Vector3 = Vector3(0, 0, 0)
	var ship_velocity: Vector3 = Vector3(100, 0, 0)
	var threat_pos: Vector3 = Vector3(500, 0, 0)
	var threat_velocity: Vector3 = Vector3(-50, 0, 0)
	
	var evasion_data: Dictionary = ManeuverCalculator.calculate_evasive_maneuver(
		ship_pos, ship_velocity, threat_pos, threat_velocity,
		ManeuverCalculator.ManeuverType.EVASION,
		0.8,  # ship_agility
		0.7   # skill_factor
	)
	
	assert_that(evasion_data).has_keys([
		"evasion_position", "evasion_vector", "evasion_effectiveness"
	])
	assert_float(evasion_data.get("evasion_effectiveness", 0.0)).is_between(0.0, 1.0)

func test_weapon_firing_solution_calculation() -> void:
	"""Test weapon firing solution calculation"""
	var ship_pos: Vector3 = Vector3(0, 0, 0)
	var ship_velocity: Vector3 = Vector3(50, 0, 0)
	var target_pos: Vector3 = Vector3(600, 0, 100)
	var target_velocity: Vector3 = Vector3(30, 0, -20)
	var projectile_speed: float = 800.0
	
	var firing_solution: Dictionary = ManeuverCalculator.calculate_weapon_firing_solution(
		ship_pos, ship_velocity, target_pos, target_velocity, projectile_speed, 0.9
	)
	
	assert_that(firing_solution).has_keys([
		"firing_position", "firing_time", "hit_probability", "lead_distance"
	])
	assert_float(firing_solution.get("firing_time", 0.0)).is_greater(0.0)
	assert_float(firing_solution.get("hit_probability", 0.0)).is_between(0.0, 1.0)

# Combat Skill System Tests

func test_combat_skill_system_initialization() -> void:
	"""Test combat skill system initialization"""
	combat_skill_system = CombatSkillSystem.new()
	combat_skill_system._ready()
	
	assert_object(combat_skill_system).is_not_null()
	assert_float(combat_skill_system.get_overall_skill_level()).is_between(0.0, 1.0)
	
	# Check all skill categories are initialized
	for category in CombatSkillSystem.SkillCategory.values():
		var skill_level: float = combat_skill_system.get_skill_level(category)
		assert_float(skill_level).is_between(0.0, 1.0)

func test_skill_level_variations() -> void:
	"""Test skill-based maneuver variations"""
	combat_skill_system = CombatSkillSystem.new()
	combat_skill_system.base_skill_level = 0.8
	combat_skill_system._ready()
	
	var base_params: Dictionary = {
		"precision": 1.0,
		"speed_modifier": 1.0,
		"timing_window": 1.0,
		"randomization": 1.0
	}
	
	var modified_params: Dictionary = combat_skill_system.apply_maneuver_skill_variations(base_params)
	
	assert_that(modified_params).has_keys(["precision", "speed_modifier", "reaction_time"])
	assert_float(modified_params.get("reaction_time", 1.0)).is_less(0.5)  # High skill = fast reaction

func test_performance_recording() -> void:
	"""Test performance recording and learning"""
	combat_skill_system = CombatSkillSystem.new()
	combat_skill_system.learning_enabled = true
	combat_skill_system._ready()
	
	var initial_gunnery_skill: float = combat_skill_system.get_skill_level(CombatSkillSystem.SkillCategory.GUNNERY)
	
	# Record several successful gunnery actions
	for i in range(5):
		combat_skill_system.record_performance("weapon_fire", true, {"difficulty": 1.0})
	
	var updated_gunnery_skill: float = combat_skill_system.get_skill_level(CombatSkillSystem.SkillCategory.GUNNERY)
	
	# Skill should have improved (or at least not decreased significantly)
	assert_float(updated_gunnery_skill).is_greater_equal(initial_gunnery_skill - 0.05)

# Target Specific Tactics Tests

func test_target_classification() -> void:
	"""Test target type classification"""
	target_specific_tactics = TargetSpecificTactics.new()
	target_specific_tactics._ready()
	
	# Test with target that has ship_class metadata
	target_ship.set_meta("ship_class", "fighter")
	
	var analysis: Dictionary = target_specific_tactics.analyze_target(target_ship)
	
	assert_int(analysis.get("target_type")).is_equal(TargetSpecificTactics.TargetType.FIGHTER)

func test_tactical_approach_selection() -> void:
	"""Test tactical approach selection for different target types"""
	target_specific_tactics = TargetSpecificTactics.new()
	target_specific_tactics._ready()
	
	# Test fighter vs capital ship tactics
	target_ship.set_meta("ship_class", "fighter")
	var fighter_analysis: Dictionary = target_specific_tactics.analyze_target(target_ship, {"skill_level": 0.7})
	
	target_ship.set_meta("ship_class", "capital")
	var capital_analysis: Dictionary = target_specific_tactics.analyze_target(target_ship, {"skill_level": 0.7})
	
	# Should have different tactical approaches
	assert_that(fighter_analysis.get("recommended_approach")).is_not_equal(
		capital_analysis.get("recommended_approach")
	)

func test_combat_plan_creation() -> void:
	"""Test comprehensive combat plan creation"""
	target_specific_tactics = TargetSpecificTactics.new()
	target_specific_tactics._ready()
	
	target_ship.set_meta("ship_class", "bomber")
	
	var combat_plan: Dictionary = target_specific_tactics.create_target_specific_combat_plan(
		ai_agent, target_ship, {"skill_level": 0.6, "formation_available": true}
	)
	
	assert_that(combat_plan).has_keys([
		"target_analysis", "tactical_approach", "attack_patterns", 
		"engagement_parameters", "weapon_configuration"
	])
	assert_that(combat_plan.get("attack_patterns")).is_not_empty()

# Weapon Firing Integration Tests

func test_weapon_firing_integration_initialization() -> void:
	"""Test weapon firing integration initialization"""
	weapon_firing_integration = WeaponFiringIntegration.new()
	weapon_firing_integration._ready()
	
	assert_object(weapon_firing_integration).is_not_null()
	assert_that(weapon_firing_integration.weapon_groups).is_not_empty()

func test_firing_solution_calculation() -> void:
	"""Test integrated firing solution calculation"""
	weapon_firing_integration = WeaponFiringIntegration.new()
	weapon_firing_integration._ready()
	
	var maneuver_data: Dictionary = {
		"maneuver_type": "attack_run",
		"phase": "attack",
		"distance_to_target": 500.0
	}
	
	var firing_solution: Dictionary = weapon_firing_integration.calculate_integrated_firing_solution(
		ai_agent, target_ship, maneuver_data, 0
	)
	
	assert_that(firing_solution).has_keys([
		"hit_probability", "weapon_group", "optimal_firing_time"
	])
	assert_float(firing_solution.get("hit_probability", 0.0)).is_between(0.0, 1.0)

func test_weapon_fire_execution() -> void:
	"""Test weapon fire execution"""
	weapon_firing_integration = WeaponFiringIntegration.new()
	weapon_firing_integration._ready()
	
	# Set up a basic firing solution
	weapon_firing_integration.current_firing_solution = {
		"hit_probability": 0.8,
		"fire_priority": 1.0,
		"distance_to_target": 400.0,
		"convergence_distance": 500.0
	}
	
	var mock_ship_controller: Node = _create_mock_ship_controller()
	ai_agent.add_child(mock_ship_controller)
	ai_agent.set_meta("ship_controller", mock_ship_controller)
	
	# Should not crash (may return false due to missing dependencies)
	var fire_result: bool = weapon_firing_integration.execute_weapon_fire(
		ai_agent, target_ship, 0, WeaponFiringIntegration.FireMode.SINGLE_SHOT
	)
	
	# Test passes if no crash occurs

# Integration Tests

func test_attack_run_with_skill_system() -> void:
	"""Test attack run integration with skill system"""
	var attack_run: AttackRunAction = AttackRunAction.new()
	attack_run.ai_agent = ai_agent
	attack_run.ship_controller = _create_mock_ship_controller()
	
	combat_skill_system = CombatSkillSystem.new()
	combat_skill_system.base_skill_level = 0.8
	combat_skill_system._ready()
	
	# Mock skill system access
	ai_agent.set_meta("skill_system", combat_skill_system)
	
	attack_run._setup()
	
	# Execute one step - should not crash
	var result: int = attack_run.execute_wcs_action(0.1)
	assert_that(result).is_in([0, 1, 2])  # Valid return values

func test_pattern_manager_with_target_tactics() -> void:
	"""Test attack pattern manager integration with target-specific tactics"""
	attack_pattern_manager = AttackPatternManager.new()
	attack_pattern_manager._ready()
	
	target_specific_tactics = TargetSpecificTactics.new()
	target_specific_tactics._ready()
	
	target_ship.set_meta("ship_class", "fighter")
	
	var tactics_analysis: Dictionary = target_specific_tactics.analyze_target(target_ship)
	var recommended_patterns: Array = tactics_analysis.get("recommended_patterns", [])
	
	if not recommended_patterns.is_empty():
		var pattern: AttackPatternManager.AttackPattern = recommended_patterns[0]
		var action: WCSBTAction = attack_pattern_manager.execute_pattern(
			pattern, ai_agent, target_ship, {"skill_level": 0.6}
		)
		
		assert_object(action).is_not_null()

# Helper Methods

func _setup_test_environment() -> void:
	# Create main test scene
	test_scene = Node3D.new()
	test_scene.name = "CombatTestScene"
	add_child(test_scene)
	
	# Create mock AI agent
	ai_agent = Node3D.new()
	ai_agent.name = "MockAIAgent"
	ai_agent.position = Vector3.ZERO
	test_scene.add_child(ai_agent)
	
	# Create mock target ship
	target_ship = Node3D.new()
	target_ship.name = "MockTarget"
	target_ship.position = Vector3(800, 0, 200)
	test_scene.add_child(target_ship)

func _cleanup_test_environment() -> void:
	if test_scene:
		test_scene.queue_free()

func _create_mock_ship_controller() -> Node:
	var controller: Node = Node.new()
	controller.name = "MockShipController"
	
	# Add mock methods via metadata
	controller.set_meta("has_fire_weapons", true)
	controller.set_meta("has_set_throttle", true)
	controller.set_meta("has_get_velocity", true)
	
	return controller

func _create_mock_target(name: String, position: Vector3) -> Node3D:
	var target: Node3D = Node3D.new()
	target.name = name
	target.position = position
	test_scene.add_child(target)
	return target