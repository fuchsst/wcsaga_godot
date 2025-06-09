extends GdUnitTestSuite

## Unit tests for WingCoordinationManager
## Tests wing creation, role assignment, tactical commands, and coordination

# Test nodes and mocks
var wing_coordination_manager: WingCoordinationManager
var mock_ships: Array[Node3D] = []
var test_scene: Node3D

func before_each() -> void:
	# Create test scene
	test_scene = Node3D.new()
	add_child(test_scene)
	
	# Create wing coordination manager
	wing_coordination_manager = WingCoordinationManager.new()
	test_scene.add_child(wing_coordination_manager)
	
	# Create mock ships
	mock_ships.clear()
	for i in range(5):
		var ship: Node3D = Node3D.new()
		ship.name = "TestShip" + str(i)
		test_scene.add_child(ship)
		mock_ships.append(ship)

func after_each() -> void:
	# Clean up
	if is_instance_valid(test_scene):
		test_scene.queue_free()
	mock_ships.clear()

func test_wing_creation() -> void:
	# Test creating a new wing
	var leader: Node3D = mock_ships[0]
	var initial_members: Array[Node3D] = [mock_ships[1], mock_ships[2]]
	
	var wing_id: String = wing_coordination_manager.create_wing(leader, initial_members)
	
	# Verify wing was created
	assert_str(wing_id).is_not_empty()
	assert_str(wing_id).starts_with("wing_")
	
	# Verify wing status
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	assert_dict(wing_status).is_not_empty()
	assert_that(wing_status["leader"]).is_equal(leader)
	assert_int(wing_status["member_count"]).is_equal(3)  # Leader + 2 members

func test_wing_member_management() -> void:
	# Test adding and removing wing members
	var leader: Node3D = mock_ships[0]
	var wing_id: String = wing_coordination_manager.create_wing(leader)
	
	# Add members
	var add_success1: bool = wing_coordination_manager.add_ship_to_wing(wing_id, mock_ships[1])
	var add_success2: bool = wing_coordination_manager.add_ship_to_wing(wing_id, mock_ships[2])
	
	assert_bool(add_success1).is_true()
	assert_bool(add_success2).is_true()
	
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	assert_int(wing_status["member_count"]).is_equal(3)
	
	# Remove member
	var remove_success: bool = wing_coordination_manager.remove_ship_from_wing(wing_id, mock_ships[1])
	assert_bool(remove_success).is_true()
	
	wing_status = wing_coordination_manager.get_wing_status(wing_id)
	assert_int(wing_status["member_count"]).is_equal(2)

func test_role_assignment() -> void:
	# Test role assignment and changes
	var leader: Node3D = mock_ships[0]
	var wingman: Node3D = mock_ships[1]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [wingman])
	
	# Check initial roles
	var leader_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(leader)
	var wingman_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(wingman)
	
	assert_that(leader_role).is_equal(WingCoordinationManager.WingRole.LEADER)
	assert_that(wingman_role).is_equal(WingCoordinationManager.WingRole.WINGMAN)
	
	# Change role
	var role_change_success: bool = wing_coordination_manager.change_ship_role(wingman, WingCoordinationManager.WingRole.SCOUT)
	assert_bool(role_change_success).is_true()
	
	var new_role: WingCoordinationManager.WingRole = wing_coordination_manager.get_ship_role(wingman)
	assert_that(new_role).is_equal(WingCoordinationManager.WingRole.SCOUT)

func test_coordination_mode() -> void:
	# Test setting coordination modes
	var leader: Node3D = mock_ships[0]
	var wing_id: String = wing_coordination_manager.create_wing(leader)
	
	# Set coordination mode
	var mode_success: bool = wing_coordination_manager.set_coordination_mode(wing_id, WingCoordinationManager.CoordinationMode.TIGHT)
	assert_bool(mode_success).is_true()
	
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	assert_str(wing_status["coordination_mode"]).is_equal("TIGHT")

func test_tactical_commands() -> void:
	# Test issuing tactical commands
	var leader: Node3D = mock_ships[0]
	var target: Node3D = mock_ships[4]  # Use a ship as target
	var wing_id: String = wing_coordination_manager.create_wing(leader, [mock_ships[1], mock_ships[2]])
	
	# Issue attack command
	var command_success: bool = wing_coordination_manager.issue_tactical_command(
		wing_id,
		WingCoordinationManager.TacticalCommand.ATTACK_TARGET,
		target,
		{"attack_type": "coordinated"}
	)
	
	assert_bool(command_success).is_true()
	
	# Check wing status reflects command
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	assert_dict(wing_status["current_objective"]).is_not_empty()

func test_coordinated_attack_initiation() -> void:
	# Test initiating coordinated attacks
	var leader: Node3D = mock_ships[0]
	var target: Node3D = mock_ships[4]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [mock_ships[1], mock_ships[2]])
	
	var attack_success: bool = wing_coordination_manager.initiate_coordinated_attack(wing_id, target, "pincer")
	assert_bool(attack_success).is_true()

func test_ships_by_role() -> void:
	# Test getting ships by role
	var leader: Node3D = mock_ships[0]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [mock_ships[1], mock_ships[2], mock_ships[3]])
	
	# Assign different roles
	wing_coordination_manager.change_ship_role(mock_ships[1], WingCoordinationManager.WingRole.SCOUT)
	wing_coordination_manager.change_ship_role(mock_ships[2], WingCoordinationManager.WingRole.SUPPORT)
	
	# Get ships by role
	var leaders: Array[Node3D] = wing_coordination_manager.get_ships_by_role(wing_id, WingCoordinationManager.WingRole.LEADER)
	var scouts: Array[Node3D] = wing_coordination_manager.get_ships_by_role(wing_id, WingCoordinationManager.WingRole.SCOUT)
	var support: Array[Node3D] = wing_coordination_manager.get_ships_by_role(wing_id, WingCoordinationManager.WingRole.SUPPORT)
	
	assert_int(leaders.size()).is_equal(1)
	assert_that(leaders[0]).is_equal(leader)
	
	assert_int(scouts.size()).is_equal(1)
	assert_that(scouts[0]).is_equal(mock_ships[1])
	
	assert_int(support.size()).is_equal(1)
	assert_that(support[0]).is_equal(mock_ships[2])

func test_wing_dissolution() -> void:
	# Test dissolving wings
	var leader: Node3D = mock_ships[0]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [mock_ships[1]])
	
	# Verify wing exists
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	assert_dict(wing_status).is_not_empty()
	
	# Dissolve wing
	var dissolve_success: bool = wing_coordination_manager.dissolve_wing(wing_id, "test_dissolution")
	assert_bool(dissolve_success).is_true()
	
	# Verify wing no longer exists
	wing_status = wing_coordination_manager.get_wing_status(wing_id)
	assert_dict(wing_status).is_empty()

func test_active_wings_tracking() -> void:
	# Test tracking active wings
	var initial_wings: Array[String] = wing_coordination_manager.get_active_wings()
	var initial_count: int = initial_wings.size()
	
	# Create wings
	var wing1_id: String = wing_coordination_manager.create_wing(mock_ships[0])
	var wing2_id: String = wing_coordination_manager.create_wing(mock_ships[2])
	
	var active_wings: Array[String] = wing_coordination_manager.get_active_wings()
	assert_int(active_wings.size()).is_equal(initial_count + 2)
	
	assert_array(active_wings).contains(wing1_id)
	assert_array(active_wings).contains(wing2_id)

func test_coordination_performance_tracking() -> void:
	# Test performance tracking
	var leader: Node3D = mock_ships[0]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [mock_ships[1]])
	
	var performance: Dictionary = wing_coordination_manager.get_coordination_performance()
	assert_dict(performance).is_not_empty()
	assert_int(performance["total_wings"]).is_greater_equal(1)

func test_invalid_wing_operations() -> void:
	# Test operations on invalid wings
	var invalid_wing_id: String = "invalid_wing"
	
	# Try to add ship to invalid wing
	var add_result: bool = wing_coordination_manager.add_ship_to_wing(invalid_wing_id, mock_ships[0])
	assert_bool(add_result).is_false()
	
	# Try to get status of invalid wing
	var status: Dictionary = wing_coordination_manager.get_wing_status(invalid_wing_id)
	assert_dict(status).is_empty()
	
	# Try to issue command to invalid wing
	var command_result: bool = wing_coordination_manager.issue_tactical_command(
		invalid_wing_id,
		WingCoordinationManager.TacticalCommand.ATTACK_TARGET,
		mock_ships[0]
	)
	assert_bool(command_result).is_false()

func test_wing_integrity_validation() -> void:
	# Test wing integrity when ships are destroyed
	var leader: Node3D = mock_ships[0]
	var wingman: Node3D = mock_ships[1]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [wingman])
	
	# Verify initial state
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	assert_int(wing_status["member_count"]).is_equal(2)
	
	# Simulate ship destruction by removing from scene
	wingman.get_parent().remove_child(wingman)
	wingman.queue_free()
	
	# Allow time for validation (would need to trigger update manually in test)
	# This would be tested with integration tests that can advance time

func test_signal_emissions() -> void:
	# Test that proper signals are emitted
	var signal_monitor = monitor_signals(wing_coordination_manager)
	
	var leader: Node3D = mock_ships[0]
	var wing_id: String = wing_coordination_manager.create_wing(leader)
	
	# Check coordination established signal
	assert_signal(wing_coordination_manager).is_emitted("coordination_established")
	
	# Issue command and check signal
	wing_coordination_manager.issue_tactical_command(
		wing_id,
		WingCoordinationManager.TacticalCommand.ATTACK_TARGET,
		mock_ships[2]
	)
	
	assert_signal(wing_coordination_manager).is_emitted("tactical_command_issued")

func test_role_change_signals() -> void:
	# Test role change signals
	var signal_monitor = monitor_signals(wing_coordination_manager)
	
	var leader: Node3D = mock_ships[0]
	var wingman: Node3D = mock_ships[1]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [wingman])
	
	# Change role and check signal
	wing_coordination_manager.change_ship_role(wingman, WingCoordinationManager.WingRole.SCOUT)
	
	assert_signal(wing_coordination_manager).is_emitted("role_assignment_changed")

func test_coordinated_attack_signals() -> void:
	# Test coordinated attack signals
	var signal_monitor = monitor_signals(wing_coordination_manager)
	
	var leader: Node3D = mock_ships[0]
	var target: Node3D = mock_ships[3]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [mock_ships[1]])
	
	wing_coordination_manager.initiate_coordinated_attack(wing_id, target, "standard")
	
	assert_signal(wing_coordination_manager).is_emitted("coordinated_attack_initiated")

func test_multiple_wings() -> void:
	# Test managing multiple wings simultaneously
	var wing1_id: String = wing_coordination_manager.create_wing(mock_ships[0], [mock_ships[1]])
	var wing2_id: String = wing_coordination_manager.create_wing(mock_ships[2], [mock_ships[3]])
	
	# Verify both wings exist
	var wing1_status: Dictionary = wing_coordination_manager.get_wing_status(wing1_id)
	var wing2_status: Dictionary = wing_coordination_manager.get_wing_status(wing2_id)
	
	assert_dict(wing1_status).is_not_empty()
	assert_dict(wing2_status).is_not_empty()
	
	assert_str(wing1_id).is_not_equal(wing2_id)
	assert_that(wing1_status["leader"]).is_not_equal(wing2_status["leader"])

func test_wing_coordination_modes() -> void:
	# Test all coordination modes
	var leader: Node3D = mock_ships[0]
	var wing_id: String = wing_coordination_manager.create_wing(leader)
	
	var modes: Array[WingCoordinationManager.CoordinationMode] = [
		WingCoordinationManager.CoordinationMode.LOOSE,
		WingCoordinationManager.CoordinationMode.STANDARD,
		WingCoordinationManager.CoordinationMode.TIGHT,
		WingCoordinationManager.CoordinationMode.FORMATION_COMBAT,
		WingCoordinationManager.CoordinationMode.SWARM,
		WingCoordinationManager.CoordinationMode.DEFENSIVE
	]
	
	for mode in modes:
		var success: bool = wing_coordination_manager.set_coordination_mode(wing_id, mode)
		assert_bool(success).is_true()
		
		var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
		var mode_name: String = WingCoordinationManager.CoordinationMode.keys()[mode]
		assert_str(wing_status["coordination_mode"]).is_equal(mode_name)

func test_all_tactical_commands() -> void:
	# Test all tactical command types
	var leader: Node3D = mock_ships[0]
	var target: Node3D = mock_ships[3]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [mock_ships[1]])
	
	var commands: Array[WingCoordinationManager.TacticalCommand] = [
		WingCoordinationManager.TacticalCommand.ATTACK_TARGET,
		WingCoordinationManager.TacticalCommand.BREAK_AND_ATTACK,
		WingCoordinationManager.TacticalCommand.PINCER_ATTACK,
		WingCoordinationManager.TacticalCommand.COVERING_FIRE,
		WingCoordinationManager.TacticalCommand.DEFENSIVE_SCREEN,
		WingCoordinationManager.TacticalCommand.TACTICAL_RETREAT,
		WingCoordinationManager.TacticalCommand.REGROUP,
		WingCoordinationManager.TacticalCommand.SUPPORT_WINGMAN,
		WingCoordinationManager.TacticalCommand.MISSILE_STRIKE,
		WingCoordinationManager.TacticalCommand.STRAFE_RUN
	]
	
	for command in commands:
		var success: bool = wing_coordination_manager.issue_tactical_command(wing_id, command, target)
		assert_bool(success).is_true()
		
		# Verify command was recorded
		var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
		assert_dict(wing_status["current_objective"]).is_not_empty()

func test_wing_coordination_quality() -> void:
	# Test coordination quality tracking
	var leader: Node3D = mock_ships[0]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [mock_ships[1], mock_ships[2]])
	
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	var coordination_quality: float = wing_status.get("coordination_quality", 0.0)
	
	# Should have some quality value
	assert_float(coordination_quality).is_greater_equal(0.0)
	assert_float(coordination_quality).is_less_equal(1.0)

func test_edge_cases() -> void:
	# Test edge cases and error conditions
	
	# Create wing with null leader (should fail gracefully)
	# Note: This would need error handling in the actual implementation
	
	# Create wing with same ship multiple times
	var leader: Node3D = mock_ships[0]
	var wing_id: String = wing_coordination_manager.create_wing(leader, [leader])  # Leader as member too
	
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	# Should handle duplicate gracefully (implementation dependent)
	assert_dict(wing_status).is_not_empty()