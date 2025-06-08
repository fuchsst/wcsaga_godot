extends GdUnitTestSuite

## Comprehensive test suite for AI collision detection and avoidance systems

var collision_detector: WCSCollisionDetector
var predictive_system: PredictiveCollisionSystem
var avoidance_integration: CollisionAvoidanceIntegration
var test_scene: Node3D
var test_ship: Node3D
var test_obstacle: Node3D

func before_test() -> void:
	# Create test scene
	test_scene = Node3D.new()
	add_child(test_scene)
	
	# Create collision detector
	collision_detector = WCSCollisionDetector.new()
	collision_detector.detection_radius = 500.0
	collision_detector.prediction_time = 3.0
	collision_detector.critical_distance = 100.0
	test_scene.add_child(collision_detector)
	
	# Create predictive system
	predictive_system = PredictiveCollisionSystem.new()
	test_scene.add_child(predictive_system)
	
	# Create avoidance integration
	avoidance_integration = CollisionAvoidanceIntegration.new()
	avoidance_integration.collision_detector = collision_detector
	avoidance_integration.predictive_system = predictive_system
	test_scene.add_child(avoidance_integration)
	
	# Create test ship
	test_ship = _create_test_ship(Vector3.ZERO)
	test_scene.add_child(test_ship)
	
	# Create test obstacle
	test_obstacle = _create_test_obstacle(Vector3(200, 0, 0))
	test_scene.add_child(test_obstacle)

func after_test() -> void:
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
	
	# Add mock ship controller
	var controller: MockShipController = MockShipController.new()
	controller.physics_body = ship
	ship.add_child(controller)
	
	# Add mock AI agent
	var ai_agent: MockAIAgent = MockAIAgent.new()
	ai_agent.ship_controller = controller
	ship.add_child(ai_agent)
	
	return ship

func _create_test_obstacle(position: Vector3) -> Node3D:
	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.global_position = position
	
	# Add collision shape
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(20, 20, 20)
	collision_shape.shape = box_shape
	obstacle.add_child(collision_shape)
	
	return obstacle

# === Collision Detector Tests ===

func test_collision_detector_initialization() -> void:
	assert_not_null(collision_detector)
	assert_float(collision_detector.detection_radius).is_equal(500.0)
	assert_float(collision_detector.prediction_time).is_equal(3.0)
	assert_float(collision_detector.critical_distance).is_equal(100.0)

func test_ship_registration() -> void:
	collision_detector.register_ship(test_ship)
	assert_array(collision_detector.registered_ships).contains([test_ship])
	
	collision_detector.unregister_ship(test_ship)
	assert_array(collision_detector.registered_ships).not_contains([test_ship])

func test_threat_detection_basic() -> void:
	collision_detector.register_ship(test_ship)
	
	# Move ship toward obstacle
	test_ship.global_position = Vector3(150, 0, 0)
	var controller: MockShipController = test_ship.get_node("MockShipController")
	controller.velocity = Vector3(50, 0, 0)  # Moving toward obstacle
	
	# Force collision detection update
	collision_detector._update_collision_detection()
	
	var threats: Array = collision_detector.get_threats_for_ship(test_ship)
	assert_int(threats.size()).is_greater(0)

func test_spatial_partitioning() -> void:
	collision_detector.enable_spatial_partitioning(true, 1000.0)
	
	# Add multiple ships in different grid cells
	var ship1: Node3D = _create_test_ship(Vector3(0, 0, 0))
	var ship2: Node3D = _create_test_ship(Vector3(1500, 0, 0))  # Different grid cell
	var ship3: Node3D = _create_test_ship(Vector3(100, 0, 100))  # Same grid cell as ship1
	
	test_scene.add_child(ship1)
	test_scene.add_child(ship2)
	test_scene.add_child(ship3)
	
	collision_detector.register_ship(ship1)
	collision_detector.register_ship(ship2)
	collision_detector.register_ship(ship3)
	
	collision_detector._update_collision_detection()
	
	# Ships in same grid cell should detect each other
	var nearby_ship1: Array = collision_detector._get_nearby_ships_spatial(ship1)
	assert_array(nearby_ship1).contains([ship3])
	
	# Ships in different grid cells should not
	assert_array(nearby_ship1).not_contains([ship2])

func test_collision_analysis() -> void:
	# Set up collision scenario
	var ship_state: Dictionary = {
		"position": Vector3(0, 0, 0),
		"velocity": Vector3(100, 0, 0),
		"radius": 10.0
	}
	
	var threat_state: Dictionary = {
		"position": Vector3(200, 0, 0),
		"velocity": Vector3(-50, 0, 0),
		"radius": 15.0
	}
	
	var collision_data: Dictionary = collision_detector._analyze_collision_potential(
		_create_mock_object(ship_state),
		_create_mock_object(threat_state)
	)
	
	assert_bool(collision_data.get("collision_possible", false)).is_true()
	assert_float(collision_data.get("time_to_collision", 0.0)).is_greater(0.0)

func test_performance_monitoring() -> void:
	collision_detector.register_ship(test_ship)
	
	# Run multiple detection cycles
	for i in range(10):
		collision_detector._update_collision_detection()
	
	var stats: Dictionary = collision_detector.get_performance_stats()
	assert_int(stats.get("ships_processed", 0)).is_greater(0)
	assert_float(stats.get("average_detection_time_us", 0.0)).is_greater_equal(0.0)

# === Predictive Collision System Tests ===

func test_predictive_system_initialization() -> void:
	assert_not_null(predictive_system)
	assert_float(predictive_system.max_prediction_time).is_equal(5.0)

func test_basic_collision_prediction() -> void:
	var ship: Node3D = _create_test_ship(Vector3(0, 0, 0))
	var threat: Node3D = _create_test_ship(Vector3(100, 0, 0))
	
	# Set up collision course
	var ship_controller: MockShipController = ship.get_node("MockShipController")
	var threat_controller: MockShipController = threat.get_node("MockShipController")
	ship_controller.velocity = Vector3(50, 0, 0)
	threat_controller.velocity = Vector3(-50, 0, 0)
	
	test_scene.add_child(ship)
	test_scene.add_child(threat)
	
	var prediction: PredictiveCollisionSystem.CollisionPrediction = predictive_system.predict_collision(ship, threat)
	
	assert_not_null(prediction)
	assert_float(prediction.collision_time).is_greater(0.0)
	assert_float(prediction.collision_probability).is_greater(0.0)

func test_avoidance_options_generation() -> void:
	var ship: Node3D = _create_test_ship(Vector3(0, 0, 0))
	var threat: Node3D = _create_test_ship(Vector3(100, 0, 0))
	
	var ship_controller: MockShipController = ship.get_node("MockShipController")
	ship_controller.velocity = Vector3(50, 0, 0)
	
	test_scene.add_child(ship)
	test_scene.add_child(threat)
	
	var prediction: PredictiveCollisionSystem.CollisionPrediction = predictive_system.predict_collision(ship, threat)
	
	assert_not_null(prediction)
	assert_array(prediction.avoidance_options).is_not_empty()
	
	# Check that options include expected maneuvers
	var option_types: Array[String] = []
	for option in prediction.avoidance_options:
		option_types.append(option.get("type", ""))
	
	assert_array(option_types).contains(["turn_left", "turn_right", "climb", "dive", "brake"])

func test_safe_corridor_calculation() -> void:
	var ship: Node3D = _create_test_ship(Vector3(0, 0, 0))
	var destination: Vector3 = Vector3(500, 0, 0)
	var threats: Array[Node3D] = [_create_test_obstacle(Vector3(250, 0, 0))]
	
	test_scene.add_child(ship)
	for threat in threats:
		test_scene.add_child(threat)
	
	var corridor: PredictiveCollisionSystem.SafeCorridor = predictive_system.calculate_safe_corridor(ship, destination, threats)
	
	assert_not_null(corridor)
	assert_array(corridor.waypoints).is_not_empty()
	assert_float(corridor.width).is_greater(0.0)
	assert_float(corridor.confidence).is_between(0.0, 1.0)

func test_collision_prediction_with_acceleration() -> void:
	var ship: Node3D = _create_test_ship(Vector3(0, 0, 0))
	var threat: Node3D = _create_test_ship(Vector3(200, 0, 0))
	
	var ship_controller: MockShipController = ship.get_node("MockShipController")
	var threat_controller: MockShipController = threat.get_node("MockShipController")
	
	ship_controller.velocity = Vector3(50, 0, 0)
	ship_controller.acceleration = Vector3(10, 0, 0)  # Accelerating
	threat_controller.velocity = Vector3(-30, 0, 0)
	
	test_scene.add_child(ship)
	test_scene.add_child(threat)
	
	predictive_system.acceleration_prediction = true
	var prediction: PredictiveCollisionSystem.CollisionPrediction = predictive_system.predict_collision(ship, threat)
	
	assert_not_null(prediction)
	assert_float(prediction.collision_time).is_greater(0.0)

# === Avoidance Integration Tests ===

func test_avoidance_integration_initialization() -> void:
	assert_not_null(avoidance_integration)
	assert_not_null(avoidance_integration.collision_detector)
	assert_not_null(avoidance_integration.predictive_system)

func test_ship_registration_integration() -> void:
	var nav_controller: MockNavigationController = MockNavigationController.new()
	
	avoidance_integration.register_ship(test_ship, nav_controller)
	
	assert_dict(avoidance_integration.integrated_ships).contains_key(test_ship)
	assert_dict(avoidance_integration.navigation_controllers).contains_key_value(test_ship, nav_controller)

func test_avoidance_mode_transitions() -> void:
	avoidance_integration.register_ship(test_ship)
	
	var state: CollisionAvoidanceIntegration.ShipAvoidanceState = avoidance_integration.avoidance_states[test_ship]
	
	# Test transition to standard avoidance
	avoidance_integration._transition_avoidance_mode(test_ship, state, CollisionAvoidanceIntegration.AvoidanceMode.STANDARD_AVOIDANCE)
	assert_int(state.current_mode).is_equal(CollisionAvoidanceIntegration.AvoidanceMode.STANDARD_AVOIDANCE)
	
	# Test transition to emergency avoidance
	avoidance_integration._transition_avoidance_mode(test_ship, state, CollisionAvoidanceIntegration.AvoidanceMode.EMERGENCY_AVOIDANCE)
	assert_int(state.current_mode).is_equal(CollisionAvoidanceIntegration.AvoidanceMode.EMERGENCY_AVOIDANCE)

func test_avoidance_status_reporting() -> void:
	avoidance_integration.register_ship(test_ship)
	
	var status: Dictionary = avoidance_integration.get_avoidance_status(test_ship)
	assert_dict(status).contains_keys(["avoidance_mode", "active_threats", "avoidance_time"])
	assert_string(status.get("avoidance_mode", "")).is_equal("none")

# === Behavior Tree Node Tests ===

func test_avoid_obstacle_action() -> void:
	var action: AvoidObstacleAction = AvoidObstacleAction.new()
	var ai_agent: MockAIAgent = MockAIAgent.new()
	var ship_controller: MockShipController = MockShipController.new()
	
	ai_agent.ship_controller = ship_controller
	action.ai_agent = ai_agent
	
	# Test with no obstacles
	ship_controller.position = Vector3(0, 0, 0)
	var result: int = action.execute_wcs_action(0.016)
	assert_int(result).is_equal(BTTask.SUCCESS)
	
	action.queue_free()

func test_emergency_avoidance_action() -> void:
	var action: EmergencyAvoidanceAction = EmergencyAvoidanceAction.new()
	var ai_agent: MockAIAgent = MockAIAgent.new()
	var ship_controller: MockShipController = MockShipController.new()
	
	ai_agent.ship_controller = ship_controller
	action.ai_agent = ai_agent
	
	# Test with no immediate threats
	ship_controller.position = Vector3(0, 0, 0)
	ship_controller.velocity = Vector3(10, 0, 0)
	var result: int = action.execute_wcs_action(0.016)
	assert_int(result).is_equal(BTTask.SUCCESS)
	
	action.queue_free()

func test_obstacle_detected_condition() -> void:
	var condition: ObstacleDetectedCondition = ObstacleDetectedCondition.new()
	var ai_agent: MockAIAgent = MockAIAgent.new()
	var ship_controller: MockShipController = MockShipController.new()
	
	ai_agent.ship_controller = ship_controller
	condition.ai_agent = ai_agent
	
	# Test with no obstacles in detection range
	ship_controller.position = Vector3(0, 0, 0)
	var result: bool = condition.execute_wcs_condition()
	assert_bool(result).is_false()
	
	condition.queue_free()

func test_collision_imminent_condition() -> void:
	var condition: CollisionImminentCondition = CollisionImminentCondition.new()
	var ai_agent: MockAIAgent = MockAIAgent.new()
	var ship_controller: MockShipController = MockShipController.new()
	
	ai_agent.ship_controller = ship_controller
	condition.ai_agent = ai_agent
	
	# Test with no imminent collisions
	ship_controller.position = Vector3(0, 0, 0)
	ship_controller.velocity = Vector3(10, 0, 0)
	var result: bool = condition.execute_wcs_condition()
	assert_bool(result).is_false()
	
	condition.queue_free()

# === Stress Tests ===

func test_many_ships_collision_detection() -> void:
	var ship_count: int = 20
	var ships: Array[Node3D] = []
	
	# Create many ships in close proximity
	for i in range(ship_count):
		var angle: float = (float(i) / float(ship_count)) * TAU
		var radius: float = 100.0
		var position: Vector3 = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		
		var ship: Node3D = _create_test_ship(position)
		var controller: MockShipController = ship.get_node("MockShipController")
		controller.velocity = Vector3(randf_range(-50, 50), 0, randf_range(-50, 50))
		
		ships.append(ship)
		test_scene.add_child(ship)
		collision_detector.register_ship(ship)
	
	# Run collision detection
	var start_time: float = Time.get_time_dict_from_system()["unix"] * 1000000.0
	collision_detector._update_collision_detection()
	var end_time: float = Time.get_time_dict_from_system()["unix"] * 1000000.0
	
	var detection_time: float = end_time - start_time
	assert_float(detection_time).is_less(50000.0)  # Less than 50ms for 20 ships
	
	# Clean up
	for ship in ships:
		ship.queue_free()

func test_collision_system_performance() -> void:
	var iterations: int = 100
	var total_time: float = 0.0
	
	collision_detector.register_ship(test_ship)
	
	for i in range(iterations):
		var start_time: float = Time.get_time_dict_from_system()["unix"] * 1000000.0
		collision_detector._update_collision_detection()
		var end_time: float = Time.get_time_dict_from_system()["unix"] * 1000000.0
		total_time += (end_time - start_time)
	
	var average_time: float = total_time / iterations
	assert_float(average_time).is_less(5000.0)  # Less than 5ms average

# === Helper Functions and Mock Classes ===

func _create_mock_object(state: Dictionary) -> Node3D:
	var mock: MockObject = MockObject.new()
	mock.global_position = state.get("position", Vector3.ZERO)
	mock.velocity = state.get("velocity", Vector3.ZERO)
	mock.collision_radius = state.get("radius", 10.0)
	return mock

# Mock classes for testing
class MockShipController extends Node:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var acceleration: Vector3 = Vector3.ZERO
	var physics_body: Node3D
	
	func get_ship_position() -> Vector3:
		return position
	
	func get_ship_velocity() -> Vector3:
		return velocity
	
	func get_forward_vector() -> Vector3:
		return Vector3.FORWARD
	
	func get_right_vector() -> Vector3:
		return Vector3.RIGHT
	
	func get_up_vector() -> Vector3:
		return Vector3.UP
	
	func get_physics_body() -> Node3D:
		return physics_body
	
	func get_collision_radius() -> float:
		return 10.0
	
	func get_max_thrust() -> float:
		return 100.0

class MockAIAgent extends Node:
	var ship_controller: MockShipController
	var blackboard: MockBlackboard = MockBlackboard.new()
	
	func get_world_3d() -> World3D:
		return get_viewport().get_world_3d()

class MockBlackboard:
	var values: Dictionary = {}
	
	func set_value(key: String, value: Variant) -> void:
		values[key] = value
	
	func get_value(key: String, default_value: Variant = null) -> Variant:
		return values.get(key, default_value)
	
	func has_value(key: String) -> bool:
		return values.has(key)
	
	func erase_value(key: String) -> void:
		values.erase(key)

class MockNavigationController extends Node:
	var current_destination: Vector3 = Vector3.ZERO
	
	func set_destination(dest: Vector3) -> void:
		current_destination = dest
	
	func get_current_destination() -> Vector3:
		return current_destination

class MockObject extends Node3D:
	var velocity: Vector3 = Vector3.ZERO
	var collision_radius: float = 10.0
	
	func get_velocity() -> Vector3:
		return velocity
	
	func get_collision_radius() -> float:
		return collision_radius