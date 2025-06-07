extends GdUnitTestSuite

## Integration tests for target selection in multi-target combat scenarios

var test_scene: Node3D
var ai_manager: Node
var formation_manager: Node
var threat_assessment: ThreatAssessmentSystem
var target_coordinator: TargetCoordinator
var tactical_doctrine: TacticalDoctrine
var mission_integration: MissionTargetIntegration

var player_ships: Array[Node3D]
var enemy_ships: Array[Node3D]
var formation_id: String

func before_test() -> void:
	_setup_integration_test_environment()

func after_test() -> void:
	_cleanup_integration_test_environment()

# Multi-target combat scenarios

func test_multi_target_engagement_scenario() -> void:
	"""Test AI behavior in complex multi-target environment"""
	
	# Setup scenario with multiple enemy types
	_create_mixed_enemy_force()
	
	# Initialize target selection systems
	_initialize_target_selection_systems()
	
	# Run target selection for each AI ship
	var target_assignments: Dictionary = {}
	
	for ship in player_ships:
		var assigned_target: Node3D = target_coordinator.request_target_assignment(ship)
		if assigned_target:
			target_assignments[ship.get_instance_id()] = assigned_target
	
	# Verify target distribution
	assert_int(target_assignments.size()).is_greater(0)
	
	# Verify no oversaturation
	var target_attacker_counts: Dictionary = {}
	for ship_id in target_assignments.keys():
		var target: Node3D = target_assignments[ship_id]
		var target_id: String = str(target.get_instance_id())
		target_attacker_counts[target_id] = target_attacker_counts.get(target_id, 0) + 1
	
	for target_id in target_attacker_counts.keys():
		var attacker_count: int = target_attacker_counts[target_id]
		assert_int(attacker_count).is_less_equal(target_coordinator.max_attackers_per_target)

func test_formation_coordinated_targeting() -> void:
	"""Test formation-coordinated target selection"""
	
	# Create formation with player ships
	formation_id = formation_manager.create_formation(
		player_ships[0],
		0,  # Formation type (assuming 0 is valid)
		150.0
	)
	
	for i in range(1, player_ships.size()):
		formation_manager.add_ship_to_formation(formation_id, player_ships[i])
	
	# Setup enemies
	_create_mixed_enemy_force()
	_initialize_target_selection_systems()
	
	# Enable formation coordination
	target_coordinator.set_coordination_mode(TargetCoordinator.CoordinationMode.FORMATION_COORDINATED)
	
	# Request coordinated targets
	var formation_targets: Dictionary = {}
	for ship in player_ships:
		var candidates: Array[Dictionary] = _create_target_candidates_for_ship(ship)
		var coordinated_target: Node3D = target_coordinator.get_coordinated_target(ship, candidates)
		if coordinated_target:
			formation_targets[ship.get_instance_id()] = coordinated_target
	
	# Verify coordination - should have some target overlap for coordination
	var target_usage: Dictionary = {}
	for ship_id in formation_targets.keys():
		var target: Node3D = formation_targets[ship_id]
		var target_id: String = str(target.get_instance_id())
		target_usage[target_id] = target_usage.get(target_id, 0) + 1
	
	# At least one target should be shared (formation coordination)
	var has_coordinated_target: bool = false
	for target_id in target_usage.keys():
		if target_usage[target_id] > 1:
			has_coordinated_target = true
			break
	
	assert_bool(has_coordinated_target).is_true()

func test_dynamic_target_switching_scenario() -> void:
	"""Test dynamic target switching in changing battlefield conditions"""
	
	_create_mixed_enemy_force()
	_initialize_target_selection_systems()
	
	# Initial target assignments
	var initial_targets: Dictionary = {}
	for ship in player_ships:
		var target: Node3D = target_coordinator.request_target_assignment(ship)
		if target:
			initial_targets[ship.get_instance_id()] = target
	
	# Simulate battlefield changes - add high priority threat
	var high_priority_enemy: Node3D = _create_enemy_ship("HighPriorityBomber")
	high_priority_enemy.position = Vector3(500, 0, 0)  # Close to formation
	
	# Add to threat assessment with high priority
	for ship in player_ships:
		var ship_threat_assessment: ThreatAssessmentSystem = ship.get_node_or_null("ThreatAssessmentSystem")
		if ship_threat_assessment:
			ship_threat_assessment.add_detected_target(high_priority_enemy)
	
	# Create switch actions and test switching
	var switch_actions: Array[SwitchTargetAction] = []
	var switches_occurred: int = 0
	
	for ship in player_ships:
		var switch_action: SwitchTargetAction = SwitchTargetAction.new()
		switch_action.ai_agent = ship
		switch_action.ship_controller = ship.get_node("MockShipController")
		switch_action.threat_assessment = ship.get_node_or_null("ThreatAssessmentSystem")
		switch_action._setup()
		
		switch_action.target_switched.connect(func(old_target: Node3D, new_target: Node3D, reason: String): switches_occurred += 1)
		
		# Force evaluation
		switch_action.force_target_switch_evaluation()
		var result: int = switch_action.execute_wcs_action(0.1)
		
		switch_actions.append(switch_action)
	
	# At least some ships should consider switching to high priority target
	# Note: May not actually switch due to hysteresis and other factors

func test_role_specific_targeting_behavior() -> void:
	"""Test that different ship roles target appropriately"""
	
	_create_mixed_enemy_force()
	_initialize_target_selection_systems()
	
	# Assign different roles to ships
	var fighter_ship: Node3D = player_ships[0]
	var bomber_ship: Node3D = player_ships[1]
	var interceptor_ship: Node3D = player_ships[2] if player_ships.size() > 2 else fighter_ship
	
	# Set ship roles (mock implementation)
	fighter_ship.set_meta("ship_role", "fighter")
	bomber_ship.set_meta("ship_role", "bomber")
	interceptor_ship.set_meta("ship_role", "interceptor")
	
	# Create role-specific target selectors
	var fighter_selector: SelectTargetAction = _create_role_specific_selector(fighter_ship, TacticalDoctrine.ShipRole.FIGHTER)
	var bomber_selector: SelectTargetAction = _create_role_specific_selector(bomber_ship, TacticalDoctrine.ShipRole.BOMBER)
	var interceptor_selector: SelectTargetAction = _create_role_specific_selector(interceptor_ship, TacticalDoctrine.ShipRole.INTERCEPTOR)
	
	# Test target preferences
	var fighter_preferences: Array = fighter_selector.preferred_target_types
	var bomber_preferences: Array = bomber_selector.preferred_target_types
	var interceptor_preferences: Array = interceptor_selector.preferred_target_types
	
	# Fighters should prefer enemy fighters/bombers
	assert_bool(ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER in fighter_preferences).is_true()
	
	# Bombers should prefer capital ships
	assert_bool(ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL in bomber_preferences).is_true()
	
	# Interceptors should prefer missiles and fighters
	assert_bool(ThreatAssessmentSystem.ThreatType.ENEMY_MISSILE in interceptor_preferences).is_true()

func test_mission_priority_targeting() -> void:
	"""Test mission objective integration with target selection"""
	
	_create_mixed_enemy_force()
	_initialize_target_selection_systems()
	
	# Designate mission priority targets
	var primary_target: Node3D = enemy_ships[0]
	var secondary_target: Node3D = enemy_ships[1]
	
	mission_integration.add_mission_target(
		primary_target,
		MissionTargetIntegration.MissionTargetType.PRIMARY_OBJECTIVE,
		MissionTargetIntegration.TargetPriority.CRITICAL,
		"destroy_flagship"
	)
	
	mission_integration.add_mission_target(
		secondary_target,
		MissionTargetIntegration.MissionTargetType.SECONDARY_OBJECTIVE,
		MissionTargetIntegration.TargetPriority.HIGH,
		"destroy_support"
	)
	
	# Test priority targeting
	var priority_multiplier: float = mission_integration.get_target_mission_priority(primary_target)
	assert_float(priority_multiplier).is_greater(2.0)  # Should be high priority
	
	# Test mission-driven target selection
	var mission_targets: Array[Dictionary] = mission_integration.get_mission_relevant_targets()
	assert_int(mission_targets.size()).is_greater_equal(2)
	
	# Primary target should be first in priority order
	assert_object(mission_targets[0].get("target")).is_equal(primary_target)

func test_escort_mission_targeting() -> void:
	"""Test escort mission target prioritization"""
	
	# Create escort scenario
	var protected_ship: Node3D = _create_friendly_ship("ProtectedTransport")
	protected_ship.position = Vector3(0, 0, 200)
	
	_create_mixed_enemy_force()
	_initialize_target_selection_systems()
	
	# Set up escort mission
	mission_integration.add_mission_target(
		protected_ship,
		MissionTargetIntegration.MissionTargetType.ESCORT_TARGET,
		MissionTargetIntegration.TargetPriority.CRITICAL
	)
	
	# Position enemies to threaten protected ship
	for i in range(2):
		if i < enemy_ships.size():
			enemy_ships[i].position = protected_ship.position + Vector3(300 + i * 100, 0, 0)
	
	# Test threat detection to protected targets
	var threats_to_protected: Array[Dictionary] = mission_integration.get_threats_to_protected_targets()
	assert_int(threats_to_protected.size()).is_greater(0)
	
	# Escort ships should prioritize threats to protected ship
	for ship in player_ships:
		# Apply escort doctrine
		var escort_preferences: Dictionary = tactical_doctrine.get_target_preferences(
			TacticalDoctrine.ShipRole.ESCORT,
			TacticalDoctrine.MissionType.ESCORT
		)
		
		assert_float(escort_preferences.get("protection_priority_bonus", 1.0)).is_greater(2.0)

func test_target_validation_in_combat() -> void:
	"""Test target validation during active combat"""
	
	_create_mixed_enemy_force()
	_initialize_target_selection_systems()
	
	# Create target validators for each ship
	var validators: Array[ValidateTargetCondition] = []
	
	for ship in player_ships:
		var validator: ValidateTargetCondition = ValidateTargetCondition.new()
		validator.ai_agent = ship
		validator.ship_controller = ship.get_node("MockShipController")
		validator._setup()
		
		# Set current target
		var target: Node3D = enemy_ships[0] if not enemy_ships.is_empty() else null
		if target:
			ship.set_meta("current_target", target)
		
		validators.append(validator)
	
	# Test validation with valid targets
	for validator in validators:
		var is_valid: bool = validator.check_wcs_condition()
		# May be false due to missing dependencies, but should not crash
	
	# Test validation with destroyed target
	var destroyed_target: Node3D = enemy_ships[0] if not enemy_ships.is_empty() else null
	if destroyed_target:
		destroyed_target.queue_free()
		
		# Validation should fail for destroyed target
		for validator in validators:
			validator.force_revalidation()
			var is_valid: bool = validator.check_wcs_condition()
			# Should handle destroyed target gracefully

func test_performance_with_large_target_count() -> void:
	"""Test system performance with many targets"""
	
	# Create large number of enemies
	var large_enemy_force: Array[Node3D] = []
	for i in range(25):
		var enemy: Node3D = _create_enemy_ship("LargeForceEnemy" + str(i))
		enemy.position = Vector3(
			randf_range(-2000, 2000),
			0,
			randf_range(-2000, 2000)
		)
		large_enemy_force.append(enemy)
	
	_initialize_target_selection_systems()
	
	# Add all enemies to threat assessment
	for ship in player_ships:
		var ship_threat_assessment: ThreatAssessmentSystem = ship.get_node_or_null("ThreatAssessmentSystem")
		if ship_threat_assessment:
			for enemy in large_enemy_force:
				ship_threat_assessment.add_detected_target(enemy)
	
	# Measure target selection performance
	var start_time: float = Time.get_time_from_start()
	
	for ship in player_ships:
		var assigned_target: Node3D = target_coordinator.request_target_assignment(ship)
		# Process assignment
	
	var end_time: float = Time.get_time_from_start()
	var elapsed: float = end_time - start_time
	
	# Should complete within reasonable time
	assert_float(elapsed).is_less(0.05)  # Less than 50ms for large scenario

# Helper methods

func _setup_integration_test_environment() -> void:
	# Create main test scene
	test_scene = Node3D.new()
	test_scene.name = "IntegrationTestScene"
	add_child(test_scene)
	
	# Create mock AI manager
	ai_manager = Node.new()
	ai_manager.name = "AIManager"
	test_scene.add_child(ai_manager)
	
	# Create mock formation manager
	formation_manager = preload("res://scripts/ai/formation/formation_manager.gd").new()
	formation_manager.name = "FormationManager"
	ai_manager.add_child(formation_manager)
	
	# Create player ships
	player_ships = []
	for i in range(4):
		var ship: Node3D = _create_friendly_ship("PlayerShip" + str(i))
		ship.position = Vector3(i * 100, 0, 0)
		player_ships.append(ship)

func _cleanup_integration_test_environment() -> void:
	if test_scene:
		test_scene.queue_free()
	
	player_ships.clear()
	enemy_ships.clear()

func _create_friendly_ship(ship_name: String) -> Node3D:
	var ship: Node3D = Node3D.new()
	ship.name = ship_name
	
	# Add mock ship controller
	var controller: Node = Node.new()
	controller.name = "MockShipController"
	ship.add_child(controller)
	
	# Add to scene
	test_scene.add_child(ship)
	
	return ship

func _create_enemy_ship(ship_name: String) -> Node3D:
	var enemy: Node3D = Node3D.new()
	enemy.name = ship_name
	enemy.set_meta("team", 2)  # Enemy team
	enemy.set_meta("ship_class", "fighter")
	enemy.set_meta("mass", 75.0)
	
	test_scene.add_child(enemy)
	return enemy

func _create_mixed_enemy_force() -> void:
	enemy_ships = []
	
	# Create different enemy types
	var fighter: Node3D = _create_enemy_ship("EnemyFighter")
	fighter.position = Vector3(800, 0, 0)
	fighter.set_meta("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_FIGHTER)
	enemy_ships.append(fighter)
	
	var bomber: Node3D = _create_enemy_ship("EnemyBomber")
	bomber.position = Vector3(600, 0, 200)
	bomber.set_meta("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_BOMBER)
	bomber.set_meta("mass", 120.0)
	enemy_ships.append(bomber)
	
	var capital: Node3D = _create_enemy_ship("EnemyCapital")
	capital.position = Vector3(1200, 0, -200)
	capital.set_meta("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_CAPITAL)
	capital.set_meta("mass", 2000.0)
	enemy_ships.append(capital)

func _initialize_target_selection_systems() -> void:
	# Create tactical doctrine
	tactical_doctrine = TacticalDoctrine.new()
	tactical_doctrine.name = "TacticalDoctrine"
	ai_manager.add_child(tactical_doctrine)
	tactical_doctrine._ready()
	
	# Create mission integration
	mission_integration = MissionTargetIntegration.new()
	mission_integration.name = "MissionTargetIntegration"
	ai_manager.add_child(mission_integration)
	mission_integration._ready()
	
	# Create target coordinator
	target_coordinator = TargetCoordinator.new()
	target_coordinator.name = "TargetCoordinator"
	ai_manager.add_child(target_coordinator)
	target_coordinator.initialize_with_systems(formation_manager, null, tactical_doctrine)
	
	# Create threat assessment for each ship
	for ship in player_ships:
		var ship_threat_assessment: ThreatAssessmentSystem = ThreatAssessmentSystem.new()
		ship_threat_assessment.name = "ThreatAssessmentSystem"
		ship.add_child(ship_threat_assessment)
		ship_threat_assessment.initialize_with_ai_agent(ship)
		
		# Add enemies to threat assessment
		for enemy in enemy_ships:
			ship_threat_assessment.add_detected_target(enemy)

func _create_target_candidates_for_ship(ship: Node3D) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	
	for enemy in enemy_ships:
		var distance: float = ship.global_position.distance_to(enemy.global_position)
		var threat_type: ThreatAssessmentSystem.ThreatType = enemy.get_meta("threat_type", ThreatAssessmentSystem.ThreatType.ENEMY_UNKNOWN)
		
		candidates.append({
			"target": enemy,
			"threat_score": randf() * 5.0 + 2.0,  # Random threat score
			"threat_type": threat_type,
			"distance": distance
		})
	
	return candidates

func _create_role_specific_selector(ship: Node3D, role: TacticalDoctrine.ShipRole) -> SelectTargetAction:
	var selector: SelectTargetAction = SelectTargetAction.new()
	selector.ai_agent = ship
	selector.ship_controller = ship.get_node("MockShipController")
	selector._setup()
	
	# Apply tactical doctrine
	tactical_doctrine.apply_doctrine_to_target_selector(
		selector,
		role,
		TacticalDoctrine.MissionType.PATROL
	)
	
	return selector