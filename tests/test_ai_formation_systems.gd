extends GdUnitTestSuite

## Comprehensive test suite for AI formation flying systems

var formation_manager: FormationManager
var formation_collision_integration: FormationCollisionIntegration
var test_scene: Node3D
var test_ships: Array[Node3D] = []
var mock_ai_agents: Array[MockAIAgent] = []

func before_test() -> void:
	# Create test scene
	test_scene = Node3D.new()
	add_child(test_scene)
	
	# Create formation manager
	formation_manager = FormationManager.new()
	test_scene.add_child(formation_manager)
	
	# Create formation collision integration
	formation_collision_integration = FormationCollisionIntegration.new()
	formation_collision_integration.formation_manager = formation_manager
	test_scene.add_child(formation_collision_integration)
	
	# Create test ships with AI agents
	for i in range(4):
		var ship: Node3D = _create_test_ship(Vector3(i * 100.0, 0, 0))
		test_ships.append(ship)
		test_scene.add_child(ship)

func after_test() -> void:
	test_ships.clear()
	mock_ai_agents.clear()
	if test_scene:
		test_scene.queue_free()

func _create_test_ship(position: Vector3) -> Node3D:
	var ship: CharacterBody3D = CharacterBody3D.new()
	ship.global_position = position
	
	# Add collision shape
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 10.0
	collision_shape.shape = sphere_shape
	ship.add_child(collision_shape)
	
	# Add mock AI agent
	var ai_agent: MockAIAgent = MockAIAgent.new()
	ship.add_child(ai_agent)
	mock_ai_agents.append(ai_agent)
	
	# Add mock ship controller
	var controller: MockShipController = MockShipController.new()
	controller.physics_body = ship
	ai_agent.ship_controller = controller
	ship.add_child(controller)
	
	return ship

# === Formation Manager Tests ===

func test_formation_manager_initialization() -> void:
	assert_not_null(formation_manager)
	assert_int(formation_manager.get_active_formation_count()).is_equal(0)
	assert_dict(formation_manager.formation_templates).is_not_empty()

func test_formation_creation() -> void:
	var leader: Node3D = test_ships[0]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.DIAMOND)
	
	assert_string(formation_id).is_not_empty()
	assert_int(formation_manager.get_active_formation_count()).is_equal(1)
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	assert_not_null(formation)
	assert_that(formation.leader).is_equal(leader)
	assert_int(formation.formation_type).is_equal(FormationManager.FormationType.DIAMOND)

func test_formation_member_management() -> void:
	var leader: Node3D = test_ships[0]
	var member1: Node3D = test_ships[1]
	var member2: Node3D = test_ships[2]
	
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.VIC)
	
	# Add members
	var success1: bool = formation_manager.add_ship_to_formation(formation_id, member1)
	var success2: bool = formation_manager.add_ship_to_formation(formation_id, member2)
	
	assert_bool(success1).is_true()
	assert_bool(success2).is_true()
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	assert_int(formation.get_member_count()).is_equal(2)
	assert_array(formation.members).contains([member1, member2])

func test_formation_position_calculation() -> void:
	var leader: Node3D = test_ships[0]
	var member: Node3D = test_ships[1]
	
	leader.global_position = Vector3(0, 0, 0)
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.DIAMOND, 100.0)
	formation_manager.add_ship_to_formation(formation_id, member)
	
	# Update formation positions
	formation_manager.update_all_formations()
	
	var member_position: Vector3 = formation_manager.get_ship_formation_position(member)
	assert_vector3(member_position).is_not_equal(Vector3.ZERO)
	
	# Position should be offset from leader
	var distance_from_leader: float = leader.global_position.distance_to(member_position)
	assert_float(distance_from_leader).is_greater(50.0)  # Should be spaced away from leader

func test_formation_integrity_calculation() -> void:
	var leader: Node3D = test_ships[0]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.DIAMOND, 100.0)
	
	# Add members in perfect positions
	for i in range(1, 4):
		formation_manager.add_ship_to_formation(formation_id, test_ships[i])
	
	formation_manager.update_all_formations()
	
	# Place ships in formation positions
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	for i in range(formation.members.size()):
		var member: Node3D = formation.members[i]
		var target_pos: Vector3 = formation.get_formation_position(i)
		member.global_position = target_pos
	
	var integrity: float = formation_manager.get_formation_integrity(formation_id)
	assert_float(integrity).is_greater(0.8)  # Should be high integrity

func test_formation_leader_change() -> void:
	var old_leader: Node3D = test_ships[0]
	var new_leader: Node3D = test_ships[1]
	var member: Node3D = test_ships[2]
	
	var formation_id: String = formation_manager.create_formation(old_leader, FormationManager.FormationType.VIC)
	formation_manager.add_ship_to_formation(formation_id, member)
	
	# Change leader
	var success: bool = formation_manager.change_formation_leader(formation_id, new_leader)
	assert_bool(success).is_true()
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	assert_that(formation.leader).is_equal(new_leader)
	assert_array(formation.members).contains([member])
	assert_array(formation.members).not_contains([new_leader])

func test_formation_destruction() -> void:
	var leader: Node3D = test_ships[0]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.COLUMN)
	
	assert_int(formation_manager.get_active_formation_count()).is_equal(1)
	
	var success: bool = formation_manager.destroy_formation(formation_id)
	assert_bool(success).is_true()
	assert_int(formation_manager.get_active_formation_count()).is_equal(0)
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	assert_null(formation)

# === Formation Types Tests ===

func test_diamond_formation_positions() -> void:
	var leader: Node3D = test_ships[0]
	leader.global_position = Vector3.ZERO
	
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.DIAMOND, 100.0)
	
	# Add 3 members for diamond formation
	for i in range(1, 4):
		formation_manager.add_ship_to_formation(formation_id, test_ships[i])
	
	formation_manager.update_all_formations()
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	assert_int(formation.formation_positions.size()).is_equal(3)
	
	# Check that positions form a diamond pattern
	var pos0: Vector3 = formation.formation_positions[0]  # Right
	var pos1: Vector3 = formation.formation_positions[1]  # Left  
	var pos2: Vector3 = formation.formation_positions[2]  # Trailing
	
	assert_float(pos0.x).is_greater(0)  # Right side
	assert_float(pos1.x).is_less(0)   # Left side
	assert_float(pos2.z).is_less(0)   # Behind leader

func test_vic_formation_positions() -> void:
	var leader: Node3D = test_ships[0]
	leader.global_position = Vector3.ZERO
	
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.VIC, 120.0)
	
	# Add 2 members for vic formation
	formation_manager.add_ship_to_formation(formation_id, test_ships[1])
	formation_manager.add_ship_to_formation(formation_id, test_ships[2])
	
	formation_manager.update_all_formations()
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	assert_int(formation.formation_positions.size()).is_equal(2)
	
	# Check V formation pattern
	var pos0: Vector3 = formation.formation_positions[0]
	var pos1: Vector3 = formation.formation_positions[1]
	
	assert_float(pos0.x).is_greater(0)  # Right wingman
	assert_float(pos1.x).is_less(0)   # Left wingman
	assert_float(pos0.z).is_less(0)   # Both behind leader
	assert_float(pos1.z).is_less(0)

func test_line_abreast_formation() -> void:
	var leader: Node3D = test_ships[0]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.LINE_ABREAST, 80.0)
	
	# Add 3 members
	for i in range(1, 4):
		formation_manager.add_ship_to_formation(formation_id, test_ships[i])
	
	formation_manager.update_all_formations()
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	
	# All positions should be to the right of leader
	for pos in formation.formation_positions:
		assert_float(pos.x).is_greater(0)
		assert_float(abs(pos.z)).is_less(20.0)  # Roughly same Z level

func test_column_formation() -> void:
	var leader: Node3D = test_ships[0]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.COLUMN, 90.0)
	
	# Add 3 members
	for i in range(1, 4):
		formation_manager.add_ship_to_formation(formation_id, test_ships[i])
	
	formation_manager.update_all_formations()
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	
	# All positions should be behind leader with increasing distance
	var prev_z: float = 0.0
	for pos in formation.formation_positions:
		assert_float(abs(pos.x)).is_less(20.0)  # Roughly same X level
		assert_float(pos.z).is_less(prev_z)   # Progressively further back
		prev_z = pos.z

# === Formation Position Calculator Tests ===

func test_position_calculator_diamond() -> void:
	var positions: Array[Vector3] = FormationPositionCalculator.calculate_formation_positions(
		FormationPositionCalculator.FormationType.DIAMOND,
		Vector3.ZERO,
		Vector3.FORWARD,
		Vector3.RIGHT,
		Vector3.UP,
		100.0,
		3
	)
	
	assert_int(positions.size()).is_equal(3)
	
	# Verify diamond pattern
	assert_float(positions[0].x).is_greater(0)  # Right
	assert_float(positions[1].x).is_less(0)   # Left
	assert_float(positions[2].z).is_less(0)   # Back

func test_position_calculator_optimal_spacing() -> void:
	var ship_sizes: Array[float] = [20.0, 25.0, 15.0, 30.0]
	var spacing: float = FormationPositionCalculator.calculate_optimal_spacing(
		FormationPositionCalculator.FormationType.DIAMOND,
		ship_sizes,
		10.0
	)
	
	assert_float(spacing).is_greater(30.0 * 3.0)  # Should be larger than biggest ship * multiplier
	assert_float(spacing).is_less(200.0)  # But reasonable

func test_position_calculator_obstacle_avoidance() -> void:
	var original_positions: Array[Vector3] = [
		Vector3(100, 0, 0),
		Vector3(-100, 0, 0),
		Vector3(0, 0, -100)
	]
	
	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.global_position = Vector3(50, 0, 0)
	test_scene.add_child(obstacle)
	
	var adjusted_positions: Array[Vector3] = FormationPositionCalculator.adjust_formation_for_obstacles(
		original_positions,
		Vector3.ZERO,
		[obstacle],
		75.0
	)
	
	assert_int(adjusted_positions.size()).is_equal(3)
	
	# Position near obstacle should be adjusted
	var adjusted_pos: Vector3 = adjusted_positions[0]
	var distance_to_obstacle: float = adjusted_pos.distance_to(obstacle.global_position)
	assert_float(distance_to_obstacle).is_greater_equal(75.0)
	
	obstacle.queue_free()

# === Formation Behavior Tree Tests ===

func test_maintain_formation_action() -> void:
	var action: MaintainFormationAction = MaintainFormationAction.new()
	var ai_agent: MockAIAgent = MockAIAgent.new()
	var ship_controller: MockShipController = MockShipController.new()
	
	ai_agent.ship_controller = ship_controller
	action.ai_agent = ai_agent
	action.formation_manager = formation_manager
	
	# Create formation
	var leader: Node3D = test_ships[0]
	var member: Node3D = test_ships[1]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.VIC)
	formation_manager.add_ship_to_formation(formation_id, member)
	
	ship_controller.physics_body = member
	
	# Test action execution
	var result: int = action.execute_wcs_action(0.016)
	assert_int(result).is_equal(BTTask.RUNNING)  # Should be working to maintain formation
	
	action.queue_free()

func test_formation_move_action() -> void:
	var action: FormationMoveAction = FormationMoveAction.new()
	var ai_agent: MockAIAgent = MockAIAgent.new()
	var ship_controller: MockShipController = MockShipController.new()
	
	ai_agent.ship_controller = ship_controller
	action.ai_agent = ai_agent
	action.formation_manager = formation_manager
	
	# Set destination
	action.set_formation_destination(Vector3(500, 0, 0))
	
	# Create formation with leader
	var leader: Node3D = test_ships[0]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.DIAMOND)
	ship_controller.physics_body = leader
	
	# Test leader movement
	var result: int = action.execute_wcs_action(0.016)
	assert_int(result).is_equal(BTTask.RUNNING)
	
	action.queue_free()

# === Formation Collision Integration Tests ===

func test_formation_collision_integration_initialization() -> void:
	assert_not_null(formation_collision_integration)
	assert_not_null(formation_collision_integration.formation_manager)

func test_formation_collision_threat_assessment() -> void:
	var leader: Node3D = test_ships[0]
	var member: Node3D = test_ships[1]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.VIC)
	formation_manager.add_ship_to_formation(formation_id, member)
	
	# Create obstacle
	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.global_position = Vector3(150, 0, 0)
	test_scene.add_child(obstacle)
	
	# Test threat handling
	var threatened_members: Array[Node3D] = [member]
	var avoidance_mode: FormationCollisionIntegration.FormationAvoidanceMode = formation_collision_integration.handle_formation_collision_threat(
		formation_id,
		obstacle,
		threatened_members
	)
	
	assert_int(avoidance_mode).is_greater_equal(0)
	assert_int(avoidance_mode).is_less_equal(3)
	
	obstacle.queue_free()

func test_formation_collision_status_monitoring() -> void:
	var leader: Node3D = test_ships[0]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.DIAMOND)
	
	var status: Dictionary = formation_collision_integration.monitor_formation_collision_status(formation_id)
	assert_string(status.get("status", "")).is_equal("no_active_avoidance")

# === Integration Tests ===

func test_formation_with_collision_system() -> void:
	# Create formation
	var leader: Node3D = test_ships[0]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.DIAMOND)
	
	for i in range(1, 4):
		formation_manager.add_ship_to_formation(formation_id, test_ships[i])
	
	# Register for collision integration
	formation_collision_integration.register_formation_for_collision_integration(formation_id)
	
	# Verify integration
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	assert_not_null(formation)
	assert_int(formation.get_member_count()).is_equal(3)

func test_formation_integrity_monitoring() -> void:
	var leader: Node3D = test_ships[0]
	var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.VIC, 100.0)
	
	# Add members
	formation_manager.add_ship_to_formation(formation_id, test_ships[1])
	formation_manager.add_ship_to_formation(formation_id, test_ships[2])
	
	formation_manager.update_all_formations()
	
	# Test with good formation
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	for i in range(formation.members.size()):
		var member: Node3D = formation.members[i]
		member.global_position = formation.get_formation_position(i)
	
	var integrity: float = formation.get_formation_integrity()
	assert_float(integrity).is_greater(0.8)
	assert_bool(formation.is_formation_intact()).is_true()
	
	# Test with broken formation
	test_ships[1].global_position = Vector3(1000, 0, 1000)  # Move far away
	integrity = formation.get_formation_integrity()
	assert_float(integrity).is_less(0.8)

# === Performance Tests ===

func test_formation_update_performance() -> void:
	# Create multiple formations
	var formation_ids: Array[String] = []
	for i in range(5):
		var leader: Node3D = _create_test_ship(Vector3(i * 200.0, 0, 0))
		test_scene.add_child(leader)
		var formation_id: String = formation_manager.create_formation(leader, FormationManager.FormationType.DIAMOND)
		formation_ids.append(formation_id)
		
		# Add members to each formation
		for j in range(3):
			var member: Node3D = _create_test_ship(Vector3(i * 200.0 + (j + 1) * 50.0, 0, 0))
			test_scene.add_child(member)
			formation_manager.add_ship_to_formation(formation_id, member)
	
	# Measure update performance
	var start_time: float = Time.get_time_from_start()
	for i in range(100):  # 100 updates
		formation_manager.update_all_formations()
	var end_time: float = Time.get_time_from_start()
	
	var update_time: float = (end_time - start_time) / 100.0
	assert_float(update_time).is_less(0.01)  # Should be less than 10ms per update

# === Mock Classes ===

class MockShipController extends Node:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var physics_body: Node3D
	var target_position: Vector3 = Vector3.ZERO
	var throttle: float = 1.0
	
	func get_ship_position() -> Vector3:
		return physics_body.global_position if physics_body else position
	
	func get_ship_velocity() -> Vector3:
		return velocity
	
	func get_forward_vector() -> Vector3:
		return Vector3.FORWARD
	
	func get_physics_body() -> Node3D:
		return physics_body
	
	func set_target_position(pos: Vector3) -> void:
		target_position = pos
	
	func set_throttle(value: float) -> void:
		throttle = value
	
	func set_target_rotation(rotation: Vector3) -> void:
		pass

class MockAIAgent extends Node:
	var ship_controller: MockShipController
	var blackboard: AIBlackboard = AIBlackboard.new()
	var formation_leader: Node3D
	var formation_position_index: int = -1
	var formation_manager_ref: FormationManager
	var formation_id: String = ""
	var is_formation_leader: bool = false
	
	func get_world_3d() -> World3D:
		return get_viewport().get_world_3d()
	
	func get_skill_modifier() -> float:
		return 1.0
	
	func set_formation_leader(leader: Node3D) -> void:
		formation_leader = leader
	
	func set_formation_position_index(index: int) -> void:
		formation_position_index = index
	
	func set_formation_manager(manager: FormationManager) -> void:
		formation_manager_ref = manager
	
	func clear_formation_assignment() -> void:
		formation_leader = null
		formation_position_index = -1
		formation_manager_ref = null
		formation_id = ""
		is_formation_leader = false