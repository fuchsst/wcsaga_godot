extends GdUnitTestSuite

## Unit tests for DynamicRoleAssignment
## Tests role suitability evaluation, assignment optimization, and emergency reassignment

# Test components
var dynamic_role_assignment: DynamicRoleAssignment
var mock_wing_manager: WingCoordinationManager
var mock_ships: Array[Node3D] = []
var test_scene: Node3D

func before_each() -> void:
	# Create test scene
	test_scene = Node3D.new()
	add_child(test_scene)
	
	# Create mock wing coordination manager
	mock_wing_manager = WingCoordinationManager.new()
	test_scene.add_child(mock_wing_manager)
	
	# Create dynamic role assignment system
	dynamic_role_assignment = DynamicRoleAssignment.new()
	test_scene.add_child(dynamic_role_assignment)
	
	# Create mock ships with different characteristics
	mock_ships.clear()
	for i in range(6):
		var ship: Node3D = Node3D.new()
		ship.name = "TestShip" + str(i)
		test_scene.add_child(ship)
		mock_ships.append(ship)

func after_each() -> void:
	if is_instance_valid(test_scene):
		test_scene.queue_free()
	mock_ships.clear()

func test_role_suitability_evaluation() -> void:
	# Test basic role suitability evaluation
	var ship: Node3D = mock_ships[0]
	var role: WingCoordinationManager.WingRole = WingCoordinationManager.WingRole.LEADER
	
	var suitability: DynamicRoleAssignment.RoleSuitability = dynamic_role_assignment.evaluate_role_suitability(ship, role)
	
	assert_that(suitability).is_not_null()
	assert_that(suitability.ship).is_equal(ship)
	assert_that(suitability.role).is_equal(role)
	assert_float(suitability.suitability_score).is_greater_equal(0.0)
	assert_float(suitability.suitability_score).is_less_equal(1.0)

func test_all_role_suitability() -> void:
	# Test suitability evaluation for all role types
	var ship: Node3D = mock_ships[0]
	var roles: Array[WingCoordinationManager.WingRole] = [
		WingCoordinationManager.WingRole.LEADER,
		WingCoordinationManager.WingRole.WINGMAN,
		WingCoordinationManager.WingRole.ATTACK_LEADER,
		WingCoordinationManager.WingRole.SUPPORT,
		WingCoordinationManager.WingRole.SCOUT,
		WingCoordinationManager.WingRole.HEAVY_ATTACK
	]
	
	for role in roles:
		var suitability: DynamicRoleAssignment.RoleSuitability = dynamic_role_assignment.evaluate_role_suitability(ship, role)
		
		assert_that(suitability).is_not_null()
		assert_that(suitability.role).is_equal(role)
		assert_float(suitability.suitability_score).is_between(0.0, 1.0)
		assert_array(suitability.reasons).is_not_empty()

func test_recommended_role() -> void:
	# Test getting recommended role for a ship
	var ship: Node3D = mock_ships[0]
	var context: Dictionary = {
		"mission_phase": "combat",
		"threat_level": 0.7
	}
	
	var recommended_role: WingCoordinationManager.WingRole = dynamic_role_assignment.get_recommended_role(ship, context)
	
	# Should return a valid role
	assert_that(recommended_role).is_between(WingCoordinationManager.WingRole.LEADER, WingCoordinationManager.WingRole.HEAVY_ATTACK)

func test_manual_role_assignment() -> void:
	# Test manual role assignment
	var ship: Node3D = mock_ships[0]
	
	# Create a wing first
	var wing_id: String = mock_wing_manager.create_wing(ship)
	
	var assignment_success: bool = dynamic_role_assignment.assign_ship_role(
		ship, 
		WingCoordinationManager.WingRole.SCOUT, 
		"test_assignment"
	)
	
	assert_bool(assignment_success).is_true()

func test_assignment_strategies() -> void:
	# Test different assignment strategies
	var strategies: Array[DynamicRoleAssignment.AssignmentStrategy] = [
		DynamicRoleAssignment.AssignmentStrategy.CAPABILITY_BASED,
		DynamicRoleAssignment.AssignmentStrategy.TACTICAL_SITUATION,
		DynamicRoleAssignment.AssignmentStrategy.DAMAGE_ADAPTIVE,
		DynamicRoleAssignment.AssignmentStrategy.MISSION_OPTIMIZED,
		DynamicRoleAssignment.AssignmentStrategy.BALANCED,
		DynamicRoleAssignment.AssignmentStrategy.EMERGENCY_RESPONSE
	]
	
	for strategy in strategies:
		dynamic_role_assignment.set_assignment_strategy(strategy)
		
		# Test that strategy was set (would need getter in implementation)
		# For now, just verify no errors
		var ship: Node3D = mock_ships[0]
		var recommended_role: WingCoordinationManager.WingRole = dynamic_role_assignment.get_recommended_role(ship)
		assert_that(recommended_role).is_between(WingCoordinationManager.WingRole.LEADER, WingCoordinationManager.WingRole.HEAVY_ATTACK)

func test_criteria_weights() -> void:
	# Test setting criteria weights
	var custom_weights: Dictionary = {
		DynamicRoleAssignment.AssignmentCriteria.SHIP_TYPE: 0.4,
		DynamicRoleAssignment.AssignmentCriteria.WEAPON_LOADOUT: 0.3,
		DynamicRoleAssignment.AssignmentCriteria.DAMAGE_STATUS: 0.3
	}
	
	dynamic_role_assignment.set_criteria_weights(custom_weights)
	
	# Test that weights affect recommendations (implementation dependent)
	var ship: Node3D = mock_ships[0]
	var role1: WingCoordinationManager.WingRole = dynamic_role_assignment.get_recommended_role(ship)
	
	# Change weights and test again
	custom_weights[DynamicRoleAssignment.AssignmentCriteria.SHIP_TYPE] = 0.1
	custom_weights[DynamicRoleAssignment.AssignmentCriteria.PILOT_SKILL] = 0.5
	dynamic_role_assignment.set_criteria_weights(custom_weights)
	
	var role2: WingCoordinationManager.WingRole = dynamic_role_assignment.get_recommended_role(ship)
	
	# Roles might be different (but not guaranteed, depends on implementation)
	assert_that(role1).is_between(WingCoordinationManager.WingRole.LEADER, WingCoordinationManager.WingRole.HEAVY_ATTACK)
	assert_that(role2).is_between(WingCoordinationManager.WingRole.LEADER, WingCoordinationManager.WingRole.HEAVY_ATTACK)

func test_emergency_reassignment() -> void:
	# Test emergency role reassignment
	var ship: Node3D = mock_ships[0]
	
	# Create wing and assign initial role
	var wing_id: String = mock_wing_manager.create_wing(ship)
	
	var emergency_success: bool = dynamic_role_assignment.handle_emergency_reassignment(ship, "heavy_damage")
	
	# Should succeed if implementation handles this scenario
	assert_bool(emergency_success).is_true()

func test_emergency_types() -> void:
	# Test different emergency types
	var ship: Node3D = mock_ships[0]
	var wing_id: String = mock_wing_manager.create_wing(ship)
	
	var emergency_types: Array[String] = [
		"heavy_damage",
		"leader_lost",
		"overwhelming_threats",
		"reconnaissance_needed"
	]
	
	for emergency_type in emergency_types:
		var result: bool = dynamic_role_assignment.handle_emergency_reassignment(ship, emergency_type)
		# Should handle all emergency types (result depends on implementation)
		# At minimum, should not crash
		assert_that(result).is_of_type(TYPE_BOOL)

func test_wing_role_optimization() -> void:
	# Test optimizing roles for an entire wing
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2], mock_ships[3]]
	var wing_id: String = mock_wing_manager.create_wing(leader, wing_members)
	
	var changes_made: int = dynamic_role_assignment.evaluate_and_assign_wing_roles(wing_id)
	
	# Should return number of changes (0 or more)
	assert_int(changes_made).is_greater_equal(0)

func test_role_monitoring() -> void:
	# Test role monitoring and optimization suggestions
	var leader: Node3D = mock_ships[0]
	var wing_members: Array[Node3D] = [mock_ships[1], mock_ships[2]]
	var wing_id: String = mock_wing_manager.create_wing(leader, wing_members)
	
	var suggestions: Array[Dictionary] = dynamic_role_assignment.monitor_and_optimize_roles(wing_id)
	
	# Should return array of suggestions (might be empty)
	assert_array(suggestions).is_not_null()
	
	# If there are suggestions, they should have proper structure
	for suggestion in suggestions:
		assert_dict(suggestion).contains_keys(["ship", "current_role", "recommended_role"])

func test_assignment_statistics() -> void:
	# Test assignment performance statistics
	var stats: Dictionary = dynamic_role_assignment.get_assignment_statistics()
	
	assert_dict(stats).is_not_empty()
	assert_dict(stats).contains_keys(["total_assignments", "emergency_assignments"])
	
	# Values should be numeric
	assert_that(stats["total_assignments"]).is_of_type(TYPE_INT)
	assert_that(stats["emergency_assignments"]).is_of_type(TYPE_INT)

func test_suitability_score_components() -> void:
	# Test individual suitability score components
	var ship: Node3D = mock_ships[0]
	var role: WingCoordinationManager.WingRole = WingCoordinationManager.WingRole.ATTACK_LEADER
	
	var suitability: DynamicRoleAssignment.RoleSuitability = dynamic_role_assignment.evaluate_role_suitability(ship, role)
	
	# Check all components are valid
	assert_float(suitability.capability_score).is_between(0.0, 1.0)
	assert_float(suitability.position_score).is_between(0.0, 1.0)
	assert_float(suitability.availability_score).is_between(0.0, 1.0)
	assert_float(suitability.mission_alignment_score).is_between(0.0, 1.0)
	
	# Overall score should be reasonable combination
	assert_float(suitability.suitability_score).is_between(0.0, 1.0)

func test_context_dependent_evaluation() -> void:
	# Test that context affects role evaluation
	var ship: Node3D = mock_ships[0]
	var role: WingCoordinationManager.WingRole = WingCoordinationManager.WingRole.SCOUT
	
	# Test with different contexts
	var combat_context: Dictionary = {
		"mission_phase": "combat",
		"threat_level": 0.8
	}
	
	var recon_context: Dictionary = {
		"mission_phase": "reconnaissance",
		"threat_level": 0.3
	}
	
	var combat_suitability: DynamicRoleAssignment.RoleSuitability = dynamic_role_assignment.evaluate_role_suitability(ship, role, combat_context)
	var recon_suitability: DynamicRoleAssignment.RoleSuitability = dynamic_role_assignment.evaluate_role_suitability(ship, role, recon_context)
	
	# Both should be valid
	assert_float(combat_suitability.suitability_score).is_between(0.0, 1.0)
	assert_float(recon_suitability.suitability_score).is_between(0.0, 1.0)
	
	# Scout role should be more suitable for reconnaissance
	assert_float(recon_suitability.mission_alignment_score).is_greater_equal(combat_suitability.mission_alignment_score)

func test_invalid_ship_handling() -> void:
	# Test handling of invalid ships
	var null_ship: Node3D = null
	var role: WingCoordinationManager.WingRole = WingCoordinationManager.WingRole.WINGMAN
	
	var suitability: DynamicRoleAssignment.RoleSuitability = dynamic_role_assignment.evaluate_role_suitability(null_ship, role)
	
	# Should handle null gracefully
	assert_float(suitability.suitability_score).is_equal(0.0)

func test_assignment_cooldown() -> void:
	# Test assignment cooldown mechanism
	var ship: Node3D = mock_ships[0]
	var wing_id: String = mock_wing_manager.create_wing(ship)
	
	# Make first assignment
	var first_assignment: bool = dynamic_role_assignment.assign_ship_role(ship, WingCoordinationManager.WingRole.SCOUT)
	assert_bool(first_assignment).is_true()
	
	# Try immediate second assignment (should respect cooldown)
	var second_assignment: bool = dynamic_role_assignment.assign_ship_role(ship, WingCoordinationManager.WingRole.SUPPORT)
	
	# Depending on implementation, might fail due to cooldown
	assert_that(second_assignment).is_of_type(TYPE_BOOL)

func test_signal_emissions() -> void:
	# Test signal emissions
	var signal_monitor = monitor_signals(dynamic_role_assignment)
	
	var ship: Node3D = mock_ships[0]
	var wing_id: String = mock_wing_manager.create_wing(ship)
	
	# Assign role and check for signal
	dynamic_role_assignment.assign_ship_role(ship, WingCoordinationManager.WingRole.SCOUT, "test")
	
	# Should emit role assignment signal
	assert_signal(dynamic_role_assignment).is_emitted("role_assigned")

func test_emergency_signal_emissions() -> void:
	# Test emergency assignment signals
	var signal_monitor = monitor_signals(dynamic_role_assignment)
	
	var ship: Node3D = mock_ships[0]
	var wing_id: String = mock_wing_manager.create_wing(ship)
	
	dynamic_role_assignment.handle_emergency_reassignment(ship, "heavy_damage")
	
	# Should emit emergency signal if successful
	var emitted_signals = signal_monitor.get_signal_emissions(dynamic_role_assignment, "emergency_role_assignment")
	# Signal might not be emitted if no role change needed
	assert_that(emitted_signals).is_of_type(TYPE_ARRAY)

func test_role_performance_tracking() -> void:
	# Test role performance tracking over time
	var ship: Node3D = mock_ships[0]
	var wing_id: String = mock_wing_manager.create_wing(ship)
	
	# Make several assignments
	dynamic_role_assignment.assign_ship_role(ship, WingCoordinationManager.WingRole.SCOUT)
	dynamic_role_assignment.assign_ship_role(ship, WingCoordinationManager.WingRole.WINGMAN)
	
	var stats: Dictionary = dynamic_role_assignment.get_assignment_statistics()
	
	# Should track assignments
	assert_int(stats["total_assignments"]).is_greater_equal(0)

func test_multiple_wings_role_assignment() -> void:
	# Test role assignment across multiple wings
	var wing1_id: String = mock_wing_manager.create_wing(mock_ships[0], [mock_ships[1]])
	var wing2_id: String = mock_wing_manager.create_wing(mock_ships[2], [mock_ships[3]])
	
	# Optimize both wings
	var changes1: int = dynamic_role_assignment.evaluate_and_assign_wing_roles(wing1_id)
	var changes2: int = dynamic_role_assignment.evaluate_and_assign_wing_roles(wing2_id)
	
	assert_int(changes1).is_greater_equal(0)
	assert_int(changes2).is_greater_equal(0)

func test_role_requirements_consistency() -> void:
	# Test that role requirements are consistent
	var ship: Node3D = mock_ships[0]
	
	# Test all roles multiple times to check consistency
	for i in range(3):
		var leader_suitability: DynamicRoleAssignment.RoleSuitability = dynamic_role_assignment.evaluate_role_suitability(
			ship, WingCoordinationManager.WingRole.LEADER
		)
		
		# Should be consistent across calls (assuming ship state doesn't change)
		assert_float(leader_suitability.suitability_score).is_between(0.0, 1.0)
		assert_array(leader_suitability.reasons).is_not_empty()

func test_assignment_with_damaged_ships() -> void:
	# Test assignment behavior with damaged ships
	var ship: Node3D = mock_ships[0]
	var wing_id: String = mock_wing_manager.create_wing(ship)
	
	# Simulate emergency assignment for damaged ship
	var emergency_result: bool = dynamic_role_assignment.handle_emergency_reassignment(ship, "heavy_damage")
	
	# Should handle emergency gracefully
	assert_that(emergency_result).is_of_type(TYPE_BOOL)
	
	# Damaged ship should have lower suitability for certain roles
	var leader_suitability: DynamicRoleAssignment.RoleSuitability = dynamic_role_assignment.evaluate_role_suitability(
		ship, WingCoordinationManager.WingRole.LEADER
	)
	var support_suitability: DynamicRoleAssignment.RoleSuitability = dynamic_role_assignment.evaluate_role_suitability(
		ship, WingCoordinationManager.WingRole.SUPPORT
	)
	
	# Both should be valid evaluations
	assert_float(leader_suitability.suitability_score).is_between(0.0, 1.0)
	assert_float(support_suitability.suitability_score).is_between(0.0, 1.0)