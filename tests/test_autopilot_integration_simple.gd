extends GdUnitTestSuite

## Simplified autopilot system integration test without external dependencies

func test_autopilot_system_files_exist() -> void:
	# Test that all autopilot system files were created
	var files_to_check: Array[String] = [
		"res://scripts/ai/autopilot/autopilot_manager.gd",
		"res://scripts/ai/autopilot/autopilot_safety_monitor.gd",
		"res://scripts/ai/autopilot/squadron_autopilot_coordinator.gd",
		"res://scripts/ai/behaviors/actions/autopilot_navigation_action.gd",
		"res://scripts/ai/behaviors/conditions/autopilot_engaged_condition.gd",
		"res://scripts/ai/behaviors/conditions/autopilot_safe_condition.gd"
	]
	
	for file_path in files_to_check:
		assert_bool(FileAccess.file_exists(file_path)).is_true()

func test_autopilot_classes_can_be_loaded() -> void:
	# Test that autopilot classes can be instantiated
	var autopilot_manager_script: GDScript = load("res://scripts/ai/autopilot/autopilot_manager.gd")
	assert_not_null(autopilot_manager_script)
	
	var safety_monitor_script: GDScript = load("res://scripts/ai/autopilot/autopilot_safety_monitor.gd")
	assert_not_null(safety_monitor_script)
	
	var squadron_coordinator_script: GDScript = load("res://scripts/ai/autopilot/squadron_autopilot_coordinator.gd")
	assert_not_null(squadron_coordinator_script)
	
	var navigation_action_script: GDScript = load("res://scripts/ai/behaviors/actions/autopilot_navigation_action.gd")
	assert_not_null(navigation_action_script)

func test_autopilot_mode_enums() -> void:
	# Test autopilot mode enumeration
	assert_int(AutopilotManager.AutopilotMode.DISABLED).is_equal(0)
	assert_int(AutopilotManager.AutopilotMode.WAYPOINT_NAV).is_equal(1)
	assert_int(AutopilotManager.AutopilotMode.PATH_FOLLOWING).is_equal(2)
	assert_int(AutopilotManager.AutopilotMode.FORMATION_FOLLOW).is_equal(3)
	assert_int(AutopilotManager.AutopilotMode.SQUADRON_AUTOPILOT).is_equal(4)
	assert_int(AutopilotManager.AutopilotMode.ASSIST_ONLY).is_equal(5)

func test_engagement_state_enums() -> void:
	# Test engagement state enumeration
	assert_int(AutopilotManager.EngagementState.DISENGAGED).is_equal(0)
	assert_int(AutopilotManager.EngagementState.ENGAGING).is_equal(1)
	assert_int(AutopilotManager.EngagementState.ENGAGED).is_equal(2)
	assert_int(AutopilotManager.EngagementState.DISENGAGING).is_equal(3)
	assert_int(AutopilotManager.EngagementState.EMERGENCY_STOP).is_equal(4)

func test_threat_level_enums() -> void:
	# Test threat level enumeration
	assert_int(AutopilotSafetyMonitor.ThreatLevel.NONE).is_equal(0)
	assert_int(AutopilotSafetyMonitor.ThreatLevel.LOW).is_equal(1)
	assert_int(AutopilotSafetyMonitor.ThreatLevel.MEDIUM).is_equal(2)
	assert_int(AutopilotSafetyMonitor.ThreatLevel.HIGH).is_equal(3)
	assert_int(AutopilotSafetyMonitor.ThreatLevel.CRITICAL).is_equal(4)

func test_coordination_mode_enums() -> void:
	# Test coordination mode enumeration
	assert_int(SquadronAutopilotCoordinator.CoordinationMode.DISABLED).is_equal(0)
	assert_int(SquadronAutopilotCoordinator.CoordinationMode.LOOSE_FORMATION).is_equal(1)
	assert_int(SquadronAutopilotCoordinator.CoordinationMode.TIGHT_FORMATION).is_equal(2)
	assert_int(SquadronAutopilotCoordinator.CoordinationMode.WAYPOINT_SYNC).is_equal(3)
	assert_int(SquadronAutopilotCoordinator.CoordinationMode.LEADER_FOLLOW).is_equal(4)
	assert_int(SquadronAutopilotCoordinator.CoordinationMode.AUTONOMOUS_COORDINATION).is_equal(5)

func test_autopilot_manager_basic_functionality() -> void:
	# Test basic autopilot manager functionality without dependencies
	var autopilot_manager: AutopilotManager = AutopilotManager.new()
	
	# Test initial state
	assert_false(autopilot_manager.is_autopilot_engaged())
	assert_int(autopilot_manager.current_mode).is_equal(AutopilotManager.AutopilotMode.DISABLED)
	assert_bool(autopilot_manager.can_engage_autopilot()).is_false()  # No player ship set
	
	# Test configuration methods
	autopilot_manager.set_threat_detection_enabled(false)
	autopilot_manager.set_formation_coordination_enabled(true)
	autopilot_manager.set_time_compression_enabled(true)
	autopilot_manager.set_navigation_speed(0.5)
	
	assert_float(autopilot_manager.default_navigation_speed).is_equal(0.5)
	assert_bool(autopilot_manager.formation_coordination_enabled).is_true()
	assert_bool(autopilot_manager.time_compression_enabled).is_true()
	
	autopilot_manager.queue_free()

func test_safety_monitor_basic_functionality() -> void:
	# Test basic safety monitor functionality
	var safety_monitor: AutopilotSafetyMonitor = AutopilotSafetyMonitor.new()
	
	# Test initial state
	assert_false(safety_monitor.has_active_threats())
	assert_int(safety_monitor.get_highest_threat_level()).is_equal(AutopilotSafetyMonitor.ThreatLevel.NONE)
	assert_bool(safety_monitor.is_safe_to_navigate()).is_true()
	
	# Test configuration methods
	safety_monitor.set_threat_monitoring_enabled(false)
	safety_monitor.set_collision_monitoring_enabled(false)
	
	assert_bool(safety_monitor.threat_monitoring_enabled).is_false()
	assert_bool(safety_monitor.collision_monitoring_enabled).is_false()
	
	# Test manual threat management
	var mock_threat: Node3D = Node3D.new()
	var threat_id: String = str(mock_threat.get_instance_id())
	
	safety_monitor.active_threats[threat_id] = {
		"threat_object": mock_threat,
		"threat_type": AutopilotSafetyMonitor.ThreatType.ENEMY_SHIP,
		"threat_level": AutopilotSafetyMonitor.ThreatLevel.HIGH,
		"detection_time": Time.get_time_from_start(),
		"last_update_time": Time.get_time_from_start()
	}
	
	assert_bool(safety_monitor.has_active_threats()).is_true()
	assert_int(safety_monitor.get_highest_threat_level()).is_equal(AutopilotSafetyMonitor.ThreatLevel.HIGH)
	assert_bool(safety_monitor.is_safe_to_navigate()).is_false()
	
	safety_monitor.queue_free()
	mock_threat.queue_free()

func test_squadron_coordinator_basic_functionality() -> void:
	# Test basic squadron coordinator functionality
	var squadron_coordinator: SquadronAutopilotCoordinator = SquadronAutopilotCoordinator.new()
	
	# Test initial state
	assert_int(squadron_coordinator.get_all_squadrons().size()).is_equal(0)
	assert_int(squadron_coordinator.max_squadron_size).is_equal(8)
	assert_float(squadron_coordinator.formation_spacing).is_equal(150.0)
	
	# Test configuration
	squadron_coordinator.max_squadron_size = 6
	squadron_coordinator.formation_spacing = 120.0
	
	assert_int(squadron_coordinator.max_squadron_size).is_equal(6)
	assert_float(squadron_coordinator.formation_spacing).is_equal(120.0)
	
	# Test ship management without actual ships
	var mock_ship: Node3D = Node3D.new()
	mock_ship.name = "mock_ship"
	
	assert_false(squadron_coordinator.is_ship_in_squadron(mock_ship))
	assert_string(squadron_coordinator.get_ship_squadron(mock_ship)).is_empty()
	
	squadron_coordinator.queue_free()
	mock_ship.queue_free()

func test_autopilot_action_basic_functionality() -> void:
	# Test basic autopilot navigation action functionality
	var action: AutopilotNavigationAction = AutopilotNavigationAction.new()
	
	# Test configuration
	action.navigation_speed = 0.7
	action.approach_distance = 150.0
	action.arrival_tolerance = 50.0
	
	assert_float(action.navigation_speed).is_equal(0.7)
	assert_float(action.approach_distance).is_equal(150.0)
	assert_float(action.arrival_tolerance).is_equal(50.0)
	
	# Test destination setting
	var destination: Vector3 = Vector3(1000, 0, 500)
	action.set_destination(destination)
	
	assert_vector3(action.destination).is_equal(destination)
	assert_int(action.path.size()).is_equal(1)
	assert_vector3(action.path[0]).is_equal(destination)
	
	# Test path setting
	var path: Array[Vector3] = [Vector3(500, 0, 0), Vector3(1000, 0, 0), Vector3(1500, 0, 500)]
	action.set_path(path)
	
	assert_int(action.path.size()).is_equal(3)
	assert_vector3(action.destination).is_equal(path[-1])
	
	action.queue_free()

func test_autopilot_conditions_basic_functionality() -> void:
	# Test autopilot engaged condition
	var engaged_condition: AutopilotEngagedCondition = AutopilotEngagedCondition.new()
	
	engaged_condition.check_safety_status = true
	engaged_condition.check_destination_set = true
	engaged_condition.check_navigation_active = true
	
	# Without autopilot manager, should return false
	assert_bool(engaged_condition.check_wcs_condition()).is_false()
	
	# Test autopilot safe condition
	var safe_condition: AutopilotSafeCondition = AutopilotSafeCondition.new()
	
	safe_condition.max_allowed_threat_level = AutopilotSafetyMonitor.ThreatLevel.MEDIUM
	safe_condition.check_collision_prediction = true
	safe_condition.check_emergency_situations = true
	
	# Without safety monitor, should return false
	assert_bool(safe_condition.check_wcs_condition()).is_false()
	
	engaged_condition.queue_free()
	safe_condition.queue_free()

func test_autopilot_system_architecture() -> void:
	# Verify the autopilot system follows expected architecture
	
	# Autopilot manager should exist
	assert_bool(FileAccess.file_exists("res://scripts/ai/autopilot/autopilot_manager.gd")).is_true()
	
	# Safety monitor should exist
	assert_bool(FileAccess.file_exists("res://scripts/ai/autopilot/autopilot_safety_monitor.gd")).is_true()
	
	# Squadron coordinator should exist
	assert_bool(FileAccess.file_exists("res://scripts/ai/autopilot/squadron_autopilot_coordinator.gd")).is_true()
	
	# Behavior tree components should exist
	assert_bool(FileAccess.file_exists("res://scripts/ai/behaviors/actions/autopilot_navigation_action.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://scripts/ai/behaviors/conditions/autopilot_engaged_condition.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://scripts/ai/behaviors/conditions/autopilot_safe_condition.gd")).is_true()

func test_autopilot_signal_definitions() -> void:
	# Test that key signal definitions exist and are properly typed
	var autopilot_manager: AutopilotManager = AutopilotManager.new()
	
	# Check signal existence (signals are automatically defined when declared)
	assert_bool(autopilot_manager.has_signal("autopilot_engaged")).is_true()
	assert_bool(autopilot_manager.has_signal("autopilot_disengaged")).is_true()
	assert_bool(autopilot_manager.has_signal("autopilot_destination_reached")).is_true()
	assert_bool(autopilot_manager.has_signal("autopilot_interrupted")).is_true()
	
	var safety_monitor: AutopilotSafetyMonitor = AutopilotSafetyMonitor.new()
	
	assert_bool(safety_monitor.has_signal("threat_detected")).is_true()
	assert_bool(safety_monitor.has_signal("collision_imminent")).is_true()
	assert_bool(safety_monitor.has_signal("emergency_situation_detected")).is_true()
	
	autopilot_manager.queue_free()
	safety_monitor.queue_free()

func test_autopilot_performance_constants() -> void:
	# Test that performance-related constants are reasonable
	var autopilot_manager: AutopilotManager = AutopilotManager.new()
	
	assert_float(autopilot_manager.default_navigation_speed).is_greater(0.0)
	assert_float(autopilot_manager.default_navigation_speed).is_less_equal(1.0)
	assert_float(autopilot_manager.threat_detection_radius).is_greater(100.0)
	assert_float(autopilot_manager.handoff_timeout).is_greater(0.0)
	
	var safety_monitor: AutopilotSafetyMonitor = AutopilotSafetyMonitor.new()
	
	assert_float(safety_monitor.threat_detection_radius).is_greater(500.0)
	assert_float(safety_monitor.collision_prediction_time).is_greater(0.0)
	assert_float(safety_monitor.minimum_safe_distance).is_greater(0.0)
	assert_float(safety_monitor.emergency_stop_threshold).is_greater(0.0)
	
	autopilot_manager.queue_free()
	safety_monitor.queue_free()

func test_autopilot_status_reporting() -> void:
	# Test status reporting functionality
	var autopilot_manager: AutopilotManager = AutopilotManager.new()
	
	var status: Dictionary = autopilot_manager.get_autopilot_status()
	
	# Should return proper status structure
	assert_bool(status.has("enabled")).is_true()
	assert_bool(status.has("mode")).is_true()
	assert_bool(status.has("state")).is_true()
	assert_bool(status.has("can_disengage")).is_true()
	
	var debug_info: Dictionary = autopilot_manager.get_debug_info()
	
	assert_bool(debug_info.has("mode")).is_true()
	assert_bool(debug_info.has("state")).is_true()
	assert_bool(debug_info.has("efficiency")).is_true()
	
	autopilot_manager.queue_free()