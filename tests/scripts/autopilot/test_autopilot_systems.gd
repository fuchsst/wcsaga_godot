extends GdUnitTestSuite

## Comprehensive test suite for autopilot systems
## Tests autopilot manager, safety monitor, squadron coordination, and behavior tree actions

var autopilot_manager: AutopilotManager
var safety_monitor: AutopilotSafetyMonitor
var squadron_coordinator: SquadronAutopilotCoordinator
var test_scene: Node3D
var test_player_ship: Node3D
var test_ships: Array[Node3D] = []
var mock_navigation_controller: MockNavigationController
var mock_ship_controller: MockShipController

func before_test() -> void:
	# Create test scene
	test_scene = Node3D.new()
	add_child(test_scene)
	
	# Create test player ship
	test_player_ship = _create_test_ship(Vector3.ZERO, "player_ship")
	test_player_ship.add_to_group("player_ships")
	test_scene.add_child(test_player_ship)
	
	# Create additional test ships
	for i in range(4):
		var ship: Node3D = _create_test_ship(Vector3(i * 100.0, 0, 0), "test_ship_" + str(i))
		test_ships.append(ship)
		test_scene.add_child(ship)
	
	# Create autopilot manager
	autopilot_manager = AutopilotManager.new()
	autopilot_manager.name = "AutopilotManager"
	autopilot_manager.player_ship = test_player_ship
	test_scene.add_child(autopilot_manager)
	
	# Create safety monitor
	safety_monitor = AutopilotSafetyMonitor.new()
	safety_monitor.name = "AutopilotSafetyMonitor"
	safety_monitor.player_ship = test_player_ship
	autopilot_manager.add_child(safety_monitor)
	
	# Create squadron coordinator
	squadron_coordinator = SquadronAutopilotCoordinator.new()
	squadron_coordinator.name = "SquadronAutopilotCoordinator"
	test_scene.add_child(squadron_coordinator)
	
	# Setup mock controllers
	mock_navigation_controller = MockNavigationController.new()
	mock_navigation_controller.name = "NavigationController"
	test_player_ship.add_child(mock_navigation_controller)
	
	mock_ship_controller = MockShipController.new()
	mock_ship_controller.name = "AIShipController"
	test_player_ship.add_child(mock_ship_controller)

func after_test() -> void:
	test_ships.clear()
	if test_scene:
		test_scene.queue_free()

func _create_test_ship(position: Vector3, ship_name: String) -> Node3D:
	var ship: CharacterBody3D = CharacterBody3D.new()
	ship.name = ship_name
	ship.global_position = position
	
	# Add collision shape
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 15.0
	collision_shape.shape = sphere_shape
	ship.add_child(collision_shape)
	
	return ship

# === Autopilot Manager Tests ===

func test_autopilot_manager_initialization() -> void:
	assert_not_null(autopilot_manager)
	assert_not_null(autopilot_manager.player_ship)
	assert_false(autopilot_manager.is_autopilot_engaged())
	assert_int(autopilot_manager.current_mode).is_equal(AutopilotManager.AutopilotMode.DISABLED)

func test_autopilot_engagement_to_position() -> void:
	var destination: Vector3 = Vector3(1000, 0, 0)
	var success: bool = autopilot_manager.engage_autopilot_to_position(destination)
	
	assert_bool(success).is_true()
	assert_bool(autopilot_manager.is_autopilot_engaged()).is_true()
	assert_int(autopilot_manager.current_mode).is_equal(AutopilotManager.AutopilotMode.WAYPOINT_NAV)
	assert_vector3(autopilot_manager.current_destination).is_equal(destination)

func test_autopilot_engagement_along_path() -> void:
	var path: Array[Vector3] = [Vector3(500, 0, 0), Vector3(1000, 0, 0), Vector3(1500, 0, 0)]
	var success: bool = autopilot_manager.engage_autopilot_along_path(path)
	
	assert_bool(success).is_true()
	assert_bool(autopilot_manager.is_autopilot_engaged()).is_true()
	assert_int(autopilot_manager.current_mode).is_equal(AutopilotManager.AutopilotMode.PATH_FOLLOWING)
	assert_vector3(autopilot_manager.current_destination).is_equal(path[-1])
	assert_int(autopilot_manager.current_path.size()).is_equal(3)

func test_autopilot_disengagement() -> void:
	# First engage autopilot
	var destination: Vector3 = Vector3(1000, 0, 0)
	autopilot_manager.engage_autopilot_to_position(destination)
	
	# Then disengage
	autopilot_manager.disengage_autopilot(AutopilotManager.DisengagementReason.MANUAL_REQUEST)
	
	assert_false(autopilot_manager.is_autopilot_engaged())
	assert_int(autopilot_manager.current_mode).is_equal(AutopilotManager.AutopilotMode.DISABLED)

func test_autopilot_status_reporting() -> void:
	var destination: Vector3 = Vector3(1000, 0, 0)
	autopilot_manager.engage_autopilot_to_position(destination)
	
	var status: Dictionary = autopilot_manager.get_autopilot_status()
	
	assert_bool(status.get("enabled", false)).is_true()
	assert_string(status.get("mode", "")).is_equal("WAYPOINT_NAV")
	assert_vector3(status.get("destination", Vector3.ZERO)).is_equal(destination)
	assert_bool(status.get("can_disengage", false)).is_true()

func test_autopilot_assist_mode() -> void:
	var success: bool = autopilot_manager.toggle_autopilot_assist()
	
	assert_bool(success).is_true()
	assert_int(autopilot_manager.current_mode).is_equal(AutopilotManager.AutopilotMode.ASSIST_ONLY)

func test_autopilot_emergency_stop() -> void:
	# Engage autopilot first
	autopilot_manager.engage_autopilot_to_position(Vector3(1000, 0, 0))
	
	# Trigger emergency stop
	autopilot_manager.emergency_stop()
	
	assert_false(autopilot_manager.is_autopilot_engaged())
	assert_int(autopilot_manager.emergency_disengagements).is_greater(0)

func test_autopilot_invalid_destination() -> void:
	var success: bool = autopilot_manager.engage_autopilot_to_position(Vector3.ZERO)
	
	assert_bool(success).is_false()
	assert_false(autopilot_manager.is_autopilot_engaged())

# === Safety Monitor Tests ===

func test_safety_monitor_initialization() -> void:
	assert_not_null(safety_monitor)
	assert_not_null(safety_monitor.player_ship)
	assert_false(safety_monitor.has_active_threats())
	assert_bool(safety_monitor.is_safe_to_navigate()).is_true()

func test_threat_detection_system() -> void:
	# Create a threat object
	var threat_ship: Node3D = _create_test_ship(Vector3(100, 0, 0), "enemy_ship")
	threat_ship.add_to_group("enemy_ships")
	test_scene.add_child(threat_ship)
	
	# Simulate threat detection by adding to active threats
	var threat_id: String = str(threat_ship.get_instance_id())
	safety_monitor.active_threats[threat_id] = {
		"threat_object": threat_ship,
		"threat_type": AutopilotSafetyMonitor.ThreatType.ENEMY_SHIP,
		"threat_level": AutopilotSafetyMonitor.ThreatLevel.HIGH,
		"detection_time": Time.get_time_from_start(),
		"last_update_time": Time.get_time_from_start(),
		"distance": 100.0,
		"relative_velocity": Vector3.ZERO,
		"approach_vector": Vector3.ZERO,
		"time_to_closest_approach": 10.0
	}
	
	assert_bool(safety_monitor.has_active_threats()).is_true()
	assert_int(safety_monitor.get_highest_threat_level()).is_equal(AutopilotSafetyMonitor.ThreatLevel.HIGH)
	assert_int(safety_monitor.get_active_threats().size()).is_equal(1)
	
	threat_ship.queue_free()

func test_threat_level_calculation() -> void:
	var threat_ship: Node3D = _create_test_ship(Vector3(500, 0, 0), "test_threat")
	test_scene.add_child(threat_ship)
	
	var threat_level: AutopilotSafetyMonitor.ThreatLevel = safety_monitor._calculate_threat_level(threat_ship, AutopilotSafetyMonitor.ThreatType.ENEMY_SHIP)
	
	assert_int(threat_level).is_greater_equal(AutopilotSafetyMonitor.ThreatLevel.NONE)
	assert_int(threat_level).is_less_equal(AutopilotSafetyMonitor.ThreatLevel.CRITICAL)
	
	threat_ship.queue_free()

func test_safe_navigation_assessment() -> void:
	# Initially should be safe
	assert_bool(safety_monitor.is_safe_to_navigate()).is_true()
	
	# Add a high-level threat
	var threat_id: String = "test_threat"
	safety_monitor.active_threats[threat_id] = {
		"threat_object": test_ships[0],
		"threat_type": AutopilotSafetyMonitor.ThreatType.ENEMY_SHIP,
		"threat_level": AutopilotSafetyMonitor.ThreatLevel.CRITICAL,
		"detection_time": Time.get_time_from_start(),
		"last_update_time": Time.get_time_from_start()
	}
	
	# Should no longer be safe
	assert_bool(safety_monitor.is_safe_to_navigate()).is_false()
	
	# Clear threats
	safety_monitor.active_threats.clear()
	assert_bool(safety_monitor.is_safe_to_navigate()).is_true()

func test_collision_prediction() -> void:
	# Create a moving object on collision course
	var obstacle: Node3D = _create_test_ship(Vector3(200, 0, 0), "obstacle")
	test_scene.add_child(obstacle)
	
	# Add velocity method to obstacle
	obstacle.set_script(load("res://tests/mocks/mock_moving_object.gd"))
	obstacle.velocity = Vector3(-100, 0, 0)  # Moving toward player
	
	var collision_time: float = safety_monitor._predict_collision_time(obstacle)
	
	# Should predict a collision
	assert_float(collision_time).is_greater(0.0)
	assert_float(collision_time).is_less(10.0)  # Within reasonable time
	
	obstacle.queue_free()

func test_emergency_situation_detection() -> void:
	# Add multiple high-level threats
	for i in range(3):
		var threat_id: String = "threat_" + str(i)
		safety_monitor.active_threats[threat_id] = {
			"threat_object": test_ships[i],
			"threat_type": AutopilotSafetyMonitor.ThreatType.ENEMY_SHIP,
			"threat_level": AutopilotSafetyMonitor.ThreatLevel.HIGH,
			"detection_time": Time.get_time_from_start(),
			"last_update_time": Time.get_time_from_start()
		}
	
	# Process emergency monitoring
	safety_monitor._update_emergency_monitoring(0.016)
	
	assert_int(safety_monitor.emergency_situations.size()).is_greater(0)

# === Squadron Coordinator Tests ===

func test_squadron_creation() -> void:
	var leader: Node3D = test_player_ship
	var members: Array[Node3D] = [test_ships[0], test_ships[1]]
	
	var squadron_id: String = squadron_coordinator.create_squadron(leader, members)
	
	assert_string(squadron_id).is_not_empty()
	assert_int(squadron_coordinator.active_squadrons.size()).is_equal(1)
	assert_bool(squadron_coordinator.is_ship_in_squadron(leader)).is_true()
	assert_bool(squadron_coordinator.is_ship_in_squadron(test_ships[0])).is_true()

func test_squadron_dissolution() -> void:
	var leader: Node3D = test_player_ship
	var members: Array[Node3D] = [test_ships[0], test_ships[1]]
	var squadron_id: String = squadron_coordinator.create_squadron(leader, members)
	
	var success: bool = squadron_coordinator.dissolve_squadron(squadron_id)
	
	assert_bool(success).is_true()
	assert_int(squadron_coordinator.active_squadrons.size()).is_equal(0)
	assert_false(squadron_coordinator.is_ship_in_squadron(leader))
	assert_false(squadron_coordinator.is_ship_in_squadron(test_ships[0]))

func test_squadron_destination_setting() -> void:
	var leader: Node3D = test_player_ship
	var members: Array[Node3D] = [test_ships[0]]
	var squadron_id: String = squadron_coordinator.create_squadron(leader, members)
	var destination: Vector3 = Vector3(2000, 0, 0)
	
	var success: bool = squadron_coordinator.set_squadron_destination(squadron_id, destination)
	
	assert_bool(success).is_true()
	
	var status: Dictionary = squadron_coordinator.get_squadron_status(squadron_id)
	assert_vector3(status.get("destination", Vector3.ZERO)).is_equal(destination)

func test_squadron_leader_change() -> void:
	var leader: Node3D = test_player_ship
	var members: Array[Node3D] = [test_ships[0], test_ships[1]]
	var squadron_id: String = squadron_coordinator.create_squadron(leader, members)
	var new_leader: Node3D = test_ships[0]
	
	var success: bool = squadron_coordinator.change_squadron_leader(squadron_id, new_leader)
	
	assert_bool(success).is_true()
	
	var status: Dictionary = squadron_coordinator.get_squadron_status(squadron_id)
	assert_string(status.get("leader", "")).is_equal(new_leader.name)

func test_squadron_member_management() -> void:
	var leader: Node3D = test_player_ship
	var members: Array[Node3D] = [test_ships[0]]
	var squadron_id: String = squadron_coordinator.create_squadron(leader, members)
	
	# Add member
	var success_add: bool = squadron_coordinator.add_ship_to_squadron(squadron_id, test_ships[1])
	assert_bool(success_add).is_true()
	
	var status: Dictionary = squadron_coordinator.get_squadron_status(squadron_id)
	assert_int(status.get("member_count", 0)).is_equal(3)  # leader + 2 members
	
	# Remove member
	var success_remove: bool = squadron_coordinator.remove_ship_from_squadron(squadron_id, test_ships[1])
	assert_bool(success_remove).is_true()
	
	status = squadron_coordinator.get_squadron_status(squadron_id)
	assert_int(status.get("member_count", 0)).is_equal(2)  # leader + 1 member

func test_squadron_coordination_modes() -> void:
	var leader: Node3D = test_player_ship
	var members: Array[Node3D] = [test_ships[0]]
	var squadron_id: String = squadron_coordinator.create_squadron(leader, members)
	
	# Test changing coordination mode
	var success: bool = squadron_coordinator.set_coordination_mode(squadron_id, SquadronAutopilotCoordinator.CoordinationMode.TIGHT_FORMATION)
	
	assert_bool(success).is_true()
	
	var status: Dictionary = squadron_coordinator.get_squadron_status(squadron_id)
	assert_string(status.get("coordination_mode", "")).is_equal("TIGHT_FORMATION")

# === Behavior Tree Action Tests ===

func test_autopilot_navigation_action() -> void:
	var action: AutopilotNavigationAction = AutopilotNavigationAction.new()
	action.ai_agent = _create_mock_ai_agent()
	action.destination = Vector3(1000, 0, 0)
	
	# Mock the setup
	action.ship_controller = mock_ship_controller
	action.navigation_controller = mock_navigation_controller
	action.autopilot_manager = autopilot_manager
	action.safety_monitor = safety_monitor
	
	var result: int = action.execute_wcs_action(0.016)
	
	# Should start navigation
	assert_int(result).is_equal(BTTask.RUNNING)
	
	action.queue_free()

func test_autopilot_engaged_condition() -> void:
	var condition: AutopilotEngagedCondition = AutopilotEngagedCondition.new()
	condition.autopilot_manager = autopilot_manager
	
	# Initially should be false
	assert_bool(condition.check_wcs_condition()).is_false()
	
	# Engage autopilot
	autopilot_manager.engage_autopilot_to_position(Vector3(1000, 0, 0))
	
	# Should now be true
	assert_bool(condition.check_wcs_condition()).is_true()
	
	condition.queue_free()

func test_autopilot_safe_condition() -> void:
	var condition: AutopilotSafeCondition = AutopilotSafeCondition.new()
	condition.safety_monitor = safety_monitor
	
	# Initially should be safe
	assert_bool(condition.check_wcs_condition()).is_true()
	
	# Add a high-level threat
	var threat_id: String = "test_threat"
	safety_monitor.active_threats[threat_id] = {
		"threat_object": test_ships[0],
		"threat_type": AutopilotSafetyMonitor.ThreatType.ENEMY_SHIP,
		"threat_level": AutopilotSafetyMonitor.ThreatLevel.CRITICAL,
		"detection_time": Time.get_time_from_start(),
		"last_update_time": Time.get_time_from_start()
	}
	
	# Should no longer be safe
	assert_bool(condition.check_wcs_condition()).is_false()
	
	condition.queue_free()

# === Integration Tests ===

func test_autopilot_with_safety_monitor_integration() -> void:
	# Engage autopilot
	var destination: Vector3 = Vector3(1000, 0, 0)
	autopilot_manager.engage_autopilot_to_position(destination)
	
	assert_bool(autopilot_manager.is_autopilot_engaged()).is_true()
	
	# Simulate threat detection that should disengage autopilot
	var threat_ship: Node3D = _create_test_ship(Vector3(50, 0, 0), "threat")
	test_scene.add_child(threat_ship)
	
	# Manually trigger threat detection
	safety_monitor._on_threat_detected(threat_ship, AutopilotSafetyMonitor.ThreatLevel.CRITICAL)
	
	# Autopilot should be disengaged
	assert_false(autopilot_manager.is_autopilot_engaged())
	
	threat_ship.queue_free()

func test_squadron_autopilot_integration() -> void:
	# Create squadron with multiple ships
	var leader: Node3D = test_player_ship
	var members: Array[Node3D] = [test_ships[0], test_ships[1]]
	
	var squadron_id: String = squadron_coordinator.create_squadron(leader, members, SquadronAutopilotCoordinator.CoordinationMode.LOOSE_FORMATION)
	
	assert_string(squadron_id).is_not_empty()
	
	# Set squadron destination
	var destination: Vector3 = Vector3(2000, 0, 0)
	var success: bool = squadron_coordinator.set_squadron_destination(squadron_id, destination)
	
	assert_bool(success).is_true()
	
	# Verify squadron status
	var status: Dictionary = squadron_coordinator.get_squadron_status(squadron_id)
	assert_int(status.get("member_count", 0)).is_equal(3)
	assert_vector3(status.get("destination", Vector3.ZERO)).is_equal(destination)

# === Performance Tests ===

func test_autopilot_performance_tracking() -> void:
	# Engage autopilot and simulate operation
	autopilot_manager.engage_autopilot_to_position(Vector3(1000, 0, 0))
	
	# Simulate some autopilot time
	autopilot_manager.total_autopilot_time = 30.0
	autopilot_manager.successful_navigations = 5
	
	var status: Dictionary = autopilot_manager.get_autopilot_status()
	assert_float(status.get("efficiency", 0.0)).is_greater(0.0)
	
	var debug_info: Dictionary = autopilot_manager.get_debug_info()
	assert_float(debug_info.get("total_time", 0.0)).is_equal(30.0)
	assert_int(debug_info.get("successful_navigations", 0)).is_equal(5)

func test_safety_monitor_performance() -> void:
	# Test with multiple threats
	for i in range(10):
		var threat_id: String = "threat_" + str(i)
		safety_monitor.active_threats[threat_id] = {
			"threat_object": test_ships[i % test_ships.size()],
			"threat_type": AutopilotSafetyMonitor.ThreatType.ENEMY_SHIP,
			"threat_level": AutopilotSafetyMonitor.ThreatLevel.MEDIUM,
			"detection_time": Time.get_time_from_start(),
			"last_update_time": Time.get_time_from_start()
		}
	
	var start_time: float = Time.get_time_from_start()
	
	# Process threat updates
	for i in range(100):
		safety_monitor._update_threat_detection(0.016)
	
	var end_time: float = Time.get_time_from_start()
	var processing_time: float = end_time - start_time
	
	# Should process efficiently
	assert_float(processing_time).is_less(0.1)  # Less than 100ms for 100 updates

# === Utility Methods ===

func _create_mock_ai_agent() -> Node:
	var mock_agent: Node = Node.new()
	mock_agent.set_script(load("res://tests/mocks/mock_ai_agent.gd"))
	mock_agent.ship_controller = mock_ship_controller
	return mock_agent

# === Mock Classes ===

class MockNavigationController extends Node:
	var current_state: String = "IDLE"
	var navigation_mode: String = "AI_CONTROLLED"
	
	func navigate_to_position(destination: Vector3, mode: String) -> bool:
		current_state = "NAVIGATING"
		navigation_mode = mode
		return true
	
	func navigate_along_path(path: Array[Vector3], mode: String) -> bool:
		current_state = "NAVIGATING"
		navigation_mode = mode
		return true
	
	func get_navigation_status() -> Dictionary:
		return {
			"state": current_state,
			"mode": navigation_mode,
			"distance_to_destination": 500.0,
			"estimated_arrival_time": 10.0,
			"navigation_efficiency": 0.9
		}
	
	func get_autopilot_status() -> Dictionary:
		return get_navigation_status()
	
	func interrupt_navigation(reason: String) -> void:
		current_state = "INTERRUPTED"

class MockShipController extends Node:
	var ai_control_enabled: bool = false
	var speed_factor: float = 1.0
	var movement_target: Vector3 = Vector3.ZERO
	
	func enable_ai_control() -> void:
		ai_control_enabled = true
	
	func disable_ai_control() -> void:
		ai_control_enabled = false
	
	func set_speed_factor(factor: float) -> void:
		speed_factor = factor
	
	func set_movement_target(target: Vector3) -> void:
		movement_target = target
	
	func stop_movement() -> void:
		movement_target = Vector3.ZERO
	
	func get_ship_position() -> Vector3:
		return get_parent().global_position if get_parent() is Node3D else Vector3.ZERO
	
	func get_ship_velocity() -> Vector3:
		return Vector3.ZERO
	
	func is_ship_destroyed() -> bool:
		return false