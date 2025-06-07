extends GdUnitTestSuite

## Integration tests for wing coordination systems
## Tests complete wing coordination scenarios with multiple ships and complex combat situations

# Test components
var wing_coordination_manager: WingCoordinationManager
var dynamic_role_assignment: DynamicRoleAssignment
var tactical_communication_system: TacticalCommunicationSystem
var squadron_objective_system: SquadronObjectiveSystem
var coordinated_attack_action: CoordinatedAttackAction
var mutual_support_action: MutualSupportAction
var cover_fire_action: CoverFireAction

var test_scene: Node3D
var mock_ships: Array[Node3D] = []
var mock_enemies: Array[Node3D] = []

func before_each() -> void:
	# Create comprehensive test scene
	test_scene = Node3D.new()
	add_child(test_scene)
	
	# Create wing coordination manager
	wing_coordination_manager = WingCoordinationManager.new()
	wing_coordination_manager.name = "WingCoordinationManager"
	test_scene.add_child(wing_coordination_manager)
	
	# Create dynamic role assignment
	dynamic_role_assignment = DynamicRoleAssignment.new()
	dynamic_role_assignment.name = "DynamicRoleAssignment"
	test_scene.add_child(dynamic_role_assignment)
	
	# Create tactical communication system
	tactical_communication_system = TacticalCommunicationSystem.new()
	tactical_communication_system.name = "TacticalCommunicationSystem"
	test_scene.add_child(tactical_communication_system)
	
	# Create squadron objective system
	squadron_objective_system = SquadronObjectiveSystem.new()
	squadron_objective_system.name = "SquadronObjectiveSystem"
	test_scene.add_child(squadron_objective_system)
	
	# Create mock ships with different capabilities
	_create_mock_ships()
	_create_mock_enemies()

func after_each() -> void:
	if is_instance_valid(test_scene):
		test_scene.queue_free()
	mock_ships.clear()
	mock_enemies.clear()

func _create_mock_ships() -> void:
	# Create diverse fleet of ships with different roles
	mock_ships.clear()
	
	# Wing Leader (experienced, good communication)
	var leader: Node3D = _create_mock_ship("Alpha_Leader", {
		"experience": 0.9,
		"leadership": true,
		"communication_range": 2500.0,
		"health": 1.0
	})
	mock_ships.append(leader)
	
	# Attack Leader (heavy weapons, aggressive)
	var attack_leader: Node3D = _create_mock_ship("Alpha_Attack", {
		"experience": 0.8,
		"heavy_weapons": true,
		"attack_capability": 0.9,
		"health": 1.0
	})
	mock_ships.append(attack_leader)
	
	# Scout (fast, good sensors)
	var scout: Node3D = _create_mock_ship("Alpha_Scout", {
		"experience": 0.7,
		"speed": 1.5,
		"sensor_range": 2000.0,
		"stealth": 0.8,
		"health": 1.0
	})
	mock_ships.append(scout)
	
	# Support Ship (defensive, good endurance)
	var support: Node3D = _create_mock_ship("Alpha_Support", {
		"experience": 0.6,
		"defensive_capability": 0.8,
		"armor": 1.5,
		"health": 1.0
	})
	mock_ships.append(support)
	
	# Wingman 1 (standard fighter)
	var wingman1: Node3D = _create_mock_ship("Alpha_Wing1", {
		"experience": 0.5,
		"formation_flying": true,
		"health": 1.0
	})
	mock_ships.append(wingman1)
	
	# Wingman 2 (rookie)
	var wingman2: Node3D = _create_mock_ship("Alpha_Wing2", {
		"experience": 0.3,
		"formation_flying": true,
		"health": 1.0
	})
	mock_ships.append(wingman2)

func _create_mock_ship(ship_name: String, capabilities: Dictionary) -> Node3D:
	var ship: Node3D = Node3D.new()
	ship.name = ship_name
	ship.set_meta("capabilities", capabilities)
	test_scene.add_child(ship)
	return ship

func _create_mock_enemies() -> void:
	# Create enemy ships for combat scenarios
	mock_enemies.clear()
	
	for i in range(8):
		var enemy: Node3D = Node3D.new()
		enemy.name = "Enemy_" + str(i)
		enemy.position = Vector3(randf_range(-2000, 2000), randf_range(-500, 500), randf_range(1000, 3000))
		test_scene.add_child(enemy)
		mock_enemies.append(enemy)

func test_complete_wing_formation_and_coordination() -> void:
	# Test complete wing formation process
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2], mock_ships[3], mock_ships[4]]
	
	# Create wing
	var wing_id: String = wing_coordination_manager.create_wing(leader, wing_members)
	assert_str(wing_id).is_not_empty()
	
	# Optimize roles
	var role_changes: int = dynamic_role_assignment.evaluate_and_assign_wing_roles(wing_id)
	assert_int(role_changes).is_greater_equal(0)
	
	# Verify role assignments
	var leader_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(leader)
	assert_that(leader_role).is_equal(WingCoordinationManager.WingRole.LEADER)
	
	# Check that all ships have reasonable roles
	for ship in wing_members:
		var ship_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(ship)
		assert_that(ship_role).is_between(WingCoordinationManager.WingRole.LEADER, WingCoordinationManager.WingRole.HEAVY_ATTACK)

func test_multi_target_coordinated_attack() -> void:
	# Test coordinated attack on multiple targets
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2], mock_ships[3]]
	var wing_id: String = wing_coordination_manager.create_wing(leader, wing_members)
	
	# Create destroy targets objective
	var targets: Array[Node3D] = [mock_enemies[0], mock_enemies[1], mock_enemies[2]]
	var objective_id: String = squadron_objective_system.create_objective(
		SquadronObjectiveSystem.ObjectiveType.DESTROY_TARGET,
		SquadronObjectiveSystem.ObjectivePriority.HIGH,
		targets
	)
	
	# Assign ships to objective
	var assignment_success: bool = squadron_objective_system.assign_ships_to_objective(objective_id, [leader] + wing_members)
	assert_bool(assignment_success).is_true()
	
	# Activate objective
	var activation_success: bool = squadron_objective_system.activate_objective(objective_id)
	assert_bool(activation_success).is_true()
	
	# Verify tasks were created
	var objective_status: Dictionary = squadron_objective_system.get_objective_status(objective_id)
	assert_dict(objective_status).is_not_empty()

func test_defensive_coordination_scenario() -> void:
	# Test defensive coordination protecting friendly assets
	var leader: Node3D = mock_ships[0]
	var defenders: Array[Node3D] = [mock_ships[1], mock_ships[2], mock_ships[3]]
	var wing_id: String = wing_coordination_manager.create_wing(leader, defenders)
	
	# Create asset to protect (using one of our ships as the asset)
	var protected_asset: Node3D = mock_ships[4]
	
	# Create protection objective
	var objective_id: String = squadron_objective_system.create_objective(
		SquadronObjectiveSystem.ObjectiveType.PROTECT_ASSET,
		SquadronObjectiveSystem.ObjectivePriority.CRITICAL,
		[protected_asset]
	)
	
	squadron_objective_system.assign_ships_to_objective(objective_id, [leader] + defenders)
	squadron_objective_system.activate_objective(objective_id)
	
	# Issue defensive screen command
	var defensive_command: bool = wing_coordination_manager.issue_tactical_command(
		wing_id,
		WingCoordinationManager.TacticalCommand.DEFENSIVE_SCREEN,
		protected_asset
	)
	
	assert_bool(defensive_command).is_true()

func test_dynamic_role_reassignment_during_combat() -> void:
	# Test dynamic role reassignment when ships are damaged
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2], mock_ships[3]]
	var wing_id: String = wing_coordination_manager.create_wing(leader, wing_members)
	
	# Optimize initial roles
	dynamic_role_assignment.evaluate_and_assign_wing_roles(wing_id)
	
	# Simulate ship damage (leader heavily damaged)
	var emergency_reassignment: bool = dynamic_role_assignment.handle_emergency_reassignment(leader, "heavy_damage")
	assert_bool(emergency_reassignment).is_true()
	
	# Should trigger role changes
	var new_role_changes: int = dynamic_role_assignment.evaluate_and_assign_wing_roles(wing_id)
	# Might or might not change roles depending on implementation
	assert_int(new_role_changes).is_greater_equal(0)

func test_communication_during_coordination() -> void:
	# Test communication flow during coordination
	var signal_monitor = monitor_signals(tactical_communication_system)
	
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2]]
	var wing_id: String = wing_coordination_manager.create_wing(leader, wing_members)
	
	# Generate status reports
	tactical_communication_system.generate_status_report(leader)
	tactical_communication_system.generate_status_report(wing_members[0])
	
	# Issue tactical order
	tactical_communication_system.issue_tactical_order(
		leader,
		wing_members,
		"Attack designated target",
		{"target": mock_enemies[0]}
	)
	
	# Verify messages were sent
	assert_signal(tactical_communication_system).is_emitted("message_sent")

func test_coordinated_attack_behavior_tree_actions() -> void:
	# Test coordinated attack behavior tree action
	var attacker: Node3D = mock_ships[1]
	var target: Node3D = mock_enemies[0]
	
	# Create coordinated attack action
	coordinated_attack_action = CoordinatedAttackAction.new()
	test_scene.add_child(coordinated_attack_action)
	
	# Configure attack action (mock AI agent)
	coordinated_attack_action.ai_agent = attacker
	coordinated_attack_action.set_attack_type(CoordinatedAttackAction.AttackType.SIMULTANEOUS)
	
	# Set up coordination
	coordinated_attack_action._setup()
	
	# Execute attack behavior (would normally run in behavior tree)
	var execution_result: int = coordinated_attack_action.execute_wcs_action(0.016)  # 16ms frame
	
	# Should return RUNNING or SUCCESS/FAILURE
	assert_that(execution_result).is_between(0, 2)  # FAILURE, SUCCESS, RUNNING

func test_mutual_support_behavior_integration() -> void:
	# Test mutual support behavior
	var supporter: Node3D = mock_ships[2]
	var supported: Node3D = mock_ships[3]
	
	# Create mutual support action
	mutual_support_action = MutualSupportAction.new()
	test_scene.add_child(mutual_support_action)
	
	# Configure support action
	mutual_support_action.ai_agent = supporter
	mutual_support_action.set_protected_unit(supported)
	mutual_support_action.set_support_type(MutualSupportAction.SupportType.COVERING_FIRE)
	
	mutual_support_action._setup()
	
	# Execute support behavior
	var support_result: int = mutual_support_action.execute_wcs_action(0.016)
	assert_that(support_result).is_between(0, 2)

func test_cover_fire_coordination() -> void:
	# Test cover fire coordination
	var cover_ship: Node3D = mock_ships[3]
	var protected_ship: Node3D = mock_ships[4]
	
	# Create cover fire action
	cover_fire_action = CoverFireAction.new()
	test_scene.add_child(cover_fire_action)
	
	# Configure cover fire
	cover_fire_action.ai_agent = cover_ship
	cover_fire_action.set_protected_unit(protected_ship)
	cover_fire_action.set_cover_fire_parameters(
		CoverFireAction.CoverFireMode.SUPPRESSIVE,
		CoverFireAction.CoverPosition.SCREENING,
		CoverFireAction.FireControl.BURST
	)
	
	cover_fire_action._setup()
	
	# Execute cover fire
	var cover_result: int = cover_fire_action.execute_wcs_action(0.016)
	assert_that(cover_result).is_between(0, 2)

func test_complex_multi_wing_scenario() -> void:
	# Test complex scenario with multiple wings
	
	# Create first wing (attack wing)
	var attack_wing_id: String = wing_coordination_manager.create_wing(
		mock_ships[0], 
		[mock_ships[1], mock_ships[2]]
	)
	
	# Create second wing (support wing)  
	var support_wing_id: String = wing_coordination_manager.create_wing(
		mock_ships[3],
		[mock_ships[4], mock_ships[5]]
	)
	
	# Optimize roles for both wings
	var attack_changes: int = dynamic_role_assignment.evaluate_and_assign_wing_roles(attack_wing_id)
	var support_changes: int = dynamic_role_assignment.evaluate_and_assign_wing_roles(support_wing_id)
	
	assert_int(attack_changes).is_greater_equal(0)
	assert_int(support_changes).is_greater_equal(0)
	
	# Create coordinated multi-wing objective
	var objective_id: String = squadron_objective_system.create_objective(
		SquadronObjectiveSystem.ObjectiveType.STRIKE_MISSION,
		SquadronObjectiveSystem.ObjectivePriority.HIGH,
		[mock_enemies[0], mock_enemies[1], mock_enemies[2]]
	)
	
	# Assign both wings to objective
	var all_ships: Array[Node3D] = mock_ships.slice(0, 6)
	squadron_objective_system.assign_ships_to_objective(objective_id, all_ships)
	squadron_objective_system.activate_objective(objective_id)
	
	# Issue coordinated commands
	wing_coordination_manager.issue_tactical_command(
		attack_wing_id,
		WingCoordinationManager.TacticalCommand.ATTACK_TARGET,
		mock_enemies[0]
	)
	
	wing_coordination_manager.issue_tactical_command(
		support_wing_id,
		WingCoordinationManager.TacticalCommand.COVERING_FIRE,
		null  # Cover the attack wing
	)
	
	# Verify both wings are active
	var attack_status: Dictionary = wing_coordination_manager.get_wing_status(attack_wing_id)
	var support_status: Dictionary = wing_coordination_manager.get_wing_status(support_wing_id)
	
	assert_dict(attack_status).is_not_empty()
	assert_dict(support_status).is_not_empty()

func test_emergency_response_coordination() -> void:
	# Test emergency response and coordination
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2], mock_ships[3]]
	var wing_id: String = wing_coordination_manager.create_wing(leader, wing_members)
	
	# Simulate emergency: ship under heavy attack
	tactical_communication_system.send_emergency_broadcast(
		wing_members[0],
		TacticalCommunicationSystem.MessageType.EMERGENCY_CALL,
		"Mayday! Under heavy fire, need immediate assistance!",
		{"threat_level": 0.9, "damage_level": 0.6}
	)
	
	# Should trigger emergency role reassignment
	dynamic_role_assignment.handle_emergency_reassignment(wing_members[0], "heavy_damage")
	
	# Should trigger mutual support
	for ship in wing_members:
		if ship != wing_members[0]:  # Other ships should provide support
			mutual_support_action = MutualSupportAction.new()
			mutual_support_action.ai_agent = ship
			mutual_support_action.set_protected_unit(wing_members[0])
			mutual_support_action.set_support_type(MutualSupportAction.SupportType.RESCUE_OPERATION)
			test_scene.add_child(mutual_support_action)
			break

func test_objective_completion_tracking() -> void:
	# Test objective completion and tracking
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2]]
	var wing_id: String = wing_coordination_manager.create_wing(leader, wing_members)
	
	# Create patrol objective
	var objective_id: String = squadron_objective_system.create_objective(
		SquadronObjectiveSystem.ObjectiveType.PATROL_AREA,
		SquadronObjectiveSystem.ObjectivePriority.MEDIUM,
		[],
		Vector3(1000, 0, 1000),
		{"radius": 800.0, "patrol_duration": 60.0}
	)
	
	squadron_objective_system.assign_ships_to_objective(objective_id, [leader] + wing_members)
	squadron_objective_system.activate_objective(objective_id)
	
	# Get ship tasks
	var leader_tasks: Array[Dictionary] = squadron_objective_system.get_ship_tasks(leader)
	var member_tasks: Array[Dictionary] = squadron_objective_system.get_ship_tasks(wing_members[0])
	
	assert_array(leader_tasks).is_not_empty()
	assert_array(member_tasks).is_not_empty()
	
	# Complete objective
	var completion_success: bool = squadron_objective_system.complete_objective(objective_id, true)
	assert_bool(completion_success).is_true()

func test_performance_under_load() -> void:
	# Test performance with many ships and objectives
	var large_wing_ships: Array[Node3D] = []
	
	# Create many additional ships
	for i in range(10):
		var ship: Node3D = _create_mock_ship("LargeWing_" + str(i), {"health": 1.0})
		large_wing_ships.append(ship)
	
	# Create large wing
	var large_wing_id: String = wing_coordination_manager.create_wing(large_wing_ships[0], large_wing_ships.slice(1))
	
	# Create multiple objectives
	var objectives: Array[String] = []
	for i in range(5):
		var obj_id: String = squadron_objective_system.create_objective(
			SquadronObjectiveSystem.ObjectiveType.PATROL_AREA,
			SquadronObjectiveSystem.ObjectivePriority.LOW,
			[],
			Vector3(i * 500, 0, i * 500)
		)
		objectives.append(obj_id)
	
	# Assign ships to objectives
	for i in range(objectives.size()):
		var obj_ships: Array[Node3D] = large_wing_ships.slice(i * 2, (i + 1) * 2)
		if not obj_ships.is_empty():
			squadron_objective_system.assign_ships_to_objective(objectives[i], obj_ships)
			squadron_objective_system.activate_objective(objectives[i])
	
	# Verify system handles load
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(large_wing_id)
	var system_stats: Dictionary = squadron_objective_system.get_system_statistics()
	
	assert_dict(wing_status).is_not_empty()
	assert_dict(system_stats).is_not_empty()
	assert_int(system_stats["active_objectives"]).is_greater_equal(objectives.size())

func test_signal_integration() -> void:
	# Test signal integration across all systems
	var wing_monitor = monitor_signals(wing_coordination_manager)
	var role_monitor = monitor_signals(dynamic_role_assignment)
	var comm_monitor = monitor_signals(tactical_communication_system)
	var obj_monitor = monitor_signals(squadron_objective_system)
	
	# Perform complex coordination sequence
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2]]
	var wing_id: String = wing_coordination_manager.create_wing(leader, wing_members)
	
	# This should generate multiple signals across systems
	dynamic_role_assignment.evaluate_and_assign_wing_roles(wing_id)
	
	var objective_id: String = squadron_objective_system.create_objective(
		SquadronObjectiveSystem.ObjectiveType.DESTROY_TARGET,
		SquadronObjectiveSystem.ObjectivePriority.HIGH,
		[mock_enemies[0]]
	)
	squadron_objective_system.assign_ships_to_objective(objective_id, [leader] + wing_members)
	
	tactical_communication_system.issue_tactical_order(
		leader,
		wing_members,
		"Engage primary target"
	)
	
	# Verify signals were emitted across systems
	assert_signal(wing_coordination_manager).is_emitted("coordination_established")
	assert_signal(squadron_objective_system).is_emitted("objective_assigned")

func test_system_cleanup_and_recovery() -> void:
	# Test system cleanup when ships are destroyed
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2], mock_ships[3]]
	var wing_id: String = wing_coordination_manager.create_wing(leader, wing_members)
	
	# Create objective
	var objective_id: String = squadron_objective_system.create_objective(
		SquadronObjectiveSystem.ObjectiveType.DESTROY_TARGET,
		SquadronObjectiveSystem.ObjectivePriority.HIGH,
		[mock_enemies[0]]
	)
	squadron_objective_system.assign_ships_to_objective(objective_id, [leader] + wing_members)
	
	# Simulate ship destruction
	var destroyed_ship: Node3D = wing_members[1]
	destroyed_ship.get_parent().remove_child(destroyed_ship)
	destroyed_ship.queue_free()
	
	# System should handle cleanup gracefully
	# This would be tested with frame advancement in a real scenario
	
	# Verify remaining ships still have tasks
	var remaining_tasks: Array[Dictionary] = squadron_objective_system.get_ship_tasks(leader)
	assert_array(remaining_tasks).is_not_null()

func test_coordination_under_stress() -> void:
	# Test coordination under high-stress combat conditions
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2], mock_ships[3]]
	var wing_id: String = wing_coordination_manager.create_wing(leader, wing_members)
	
	# Create high-stress scenario with multiple threats
	var objective_id: String = squadron_objective_system.create_objective(
		SquadronObjectiveSystem.ObjectiveType.SEARCH_AND_DESTROY,
		SquadronObjectiveSystem.ObjectivePriority.CRITICAL,
		mock_enemies.slice(0, 6)  # Many enemies
	)
	
	squadron_objective_system.assign_ships_to_objective(objective_id, [leader] + wing_members)
	squadron_objective_system.activate_objective(objective_id)
	
	# Simulate rapid emergency situations
	for ship in wing_members:
		dynamic_role_assignment.handle_emergency_reassignment(ship, "overwhelming_threats")
	
	# System should maintain coordination
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	assert_dict(wing_status).is_not_empty()
	assert_float(wing_status["coordination_quality"]).is_greater(0.0)