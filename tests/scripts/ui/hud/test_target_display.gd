extends GdUnitTestSuite

## EPIC-012 HUD-005: Target Display and Information Panel Unit Tests
## Comprehensive testing for target display system, tactical assessment, and targeting components

# Test components
var target_display: TargetDisplay
var target_info_panel: TargetInfoPanel
var target_status_visualizer: TargetStatusVisualizer
var subsystem_display: SubsystemDisplay
var tactical_analyzer: TacticalAnalyzer
var engagement_calculator: EngagementCalculator
var target_data_processor: TargetDataProcessor
var target_tracking_optimizer: TargetTrackingOptimizer

# Mock objects
var mock_target: Node
var mock_player: Node
var test_screen_size: Vector2 = Vector2(1920, 1080)

func before_test() -> void:
	# Initialize test components
	target_display = TargetDisplay.new()
	target_info_panel = TargetInfoPanel.new()
	target_status_visualizer = TargetStatusVisualizer.new()
	subsystem_display = SubsystemDisplay.new()
	tactical_analyzer = TacticalAnalyzer.new()
	engagement_calculator = EngagementCalculator.new()
	target_data_processor = TargetDataProcessor.new()
	target_tracking_optimizer = TargetTrackingOptimizer.new()
	
	# Setup tactical analyzer
	tactical_analyzer.setup()
	
	# Create mock objects
	_create_mock_objects()

func after_test() -> void:
	# Cleanup
	if mock_target:
		mock_target.queue_free()
	if mock_player:
		mock_player.queue_free()

## Target Display Core Tests

func test_target_display_initialization() -> void:
	assert_that(target_display).is_not_null()
	assert_that(target_display.element_id).is_equal("target_display")
	assert_that(target_display.element_name).is_equal("Target Display")
	assert_that(target_display.element_category).is_equal("targeting")

func test_set_target() -> void:
	# Test setting a target
	target_display.set_target(mock_target)
	assert_that(target_display.current_target).is_equal(mock_target)
	
	# Test clearing target
	target_display.set_target(null)
	assert_that(target_display.current_target).is_null()

func test_target_data_update() -> void:
	target_display.set_target(mock_target)
	target_display.update_target_info(mock_target)
	
	var target_data = target_display.get_element_data()
	assert_that(target_data).contains_key("name")
	assert_that(target_data).contains_key("class")
	assert_that(target_data).contains_key("hull_percentage")
	assert_that(target_data).contains_key("distance")

func test_target_validation() -> void:
	var validation_result = target_display.validate_element()
	assert_that(validation_result).contains_key("is_valid")
	assert_that(validation_result).contains_key("errors")
	assert_that(validation_result).contains_key("warnings")

## Target Information Panel Tests

func test_target_info_panel_initialization() -> void:
	assert_that(target_info_panel).is_not_null()
	assert_that(target_info_panel.name).is_equal("TargetInfoPanel")

func test_update_target_info() -> void:
	var test_data = {
		"name": "Test Fighter",
		"class": "Light Fighter",
		"type": "Interceptor",
		"hull_percentage": 75.0,
		"shield_percentage": 50.0,
		"distance": 1500.0,
		"velocity": Vector3(100, 0, 50),
		"hostility": "hostile"
	}
	
	target_info_panel.update_target_info(test_data)
	var stored_data = target_info_panel.get_target_data()
	
	assert_that(stored_data["name"]).is_equal("Test Fighter")
	assert_that(stored_data["hull_percentage"]).is_equal(75.0)
	assert_that(stored_data["hostility"]).is_equal("hostile")

func test_distance_formatting() -> void:
	# Test different distance units
	target_info_panel.set_distance_unit("m")
	assert_that(target_info_panel.distance_unit).is_equal("m")
	
	target_info_panel.set_distance_unit("km")
	assert_that(target_info_panel.distance_unit).is_equal("km")

func test_clear_target_info_display() -> void:
	# Set some data first
	var test_data = {"name": "Test Target", "hull_percentage": 50.0}
	target_info_panel.update_target_info(test_data)
	
	# Clear the display
	target_info_panel.clear_display()
	var stored_data = target_info_panel.get_target_data()
	
	assert_that(stored_data).is_empty()

func test_target_info_panel_validation() -> void:
	var validation_result = target_info_panel.validate_panel()
	assert_that(validation_result).contains_key("is_valid")
	assert_that(validation_result).contains_key("errors")

## Target Status Visualizer Tests

func test_status_visualizer_initialization() -> void:
	assert_that(target_status_visualizer).is_not_null()
	assert_that(target_status_visualizer.name).is_equal("TargetStatusVisualizer")

func test_hull_display_update() -> void:
	target_status_visualizer.update_hull_display(75.0)
	var status = target_status_visualizer.get_current_status()
	assert_that(status["hull_percentage"]).is_equal(75.0)

func test_shield_display_update() -> void:
	var shield_quadrants = [80.0, 60.0, 40.0, 90.0]
	target_status_visualizer.update_shield_display(shield_quadrants)
	
	var status = target_status_visualizer.get_current_status()
	assert_that(status["shield_quadrants"]).contains_exactly(shield_quadrants)

func test_critical_hull_detection() -> void:
	var critical_triggered = false
	target_status_visualizer.hull_critical.connect(func(percentage): critical_triggered = true)
	
	target_status_visualizer.update_hull_display(20.0)  # Below critical threshold
	assert_that(critical_triggered).is_true()

func test_shields_down_detection() -> void:
	var shields_down_triggered = false
	target_status_visualizer.shields_down.connect(func(): shields_down_triggered = true)
	
	var no_shields = [0.0, 0.0, 0.0, 0.0]
	target_status_visualizer.update_shield_display(no_shields)
	assert_that(shields_down_triggered).is_true()

func test_threat_display_update() -> void:
	var threat_assessment = {"threat_level": 3}
	target_status_visualizer.update_threat_display(threat_assessment)
	
	var status = target_status_visualizer.get_current_status()
	assert_that(status["threat_level"]).is_equal(3)

func test_clear_status_display() -> void:
	# Set some status first
	target_status_visualizer.update_hull_display(50.0)
	target_status_visualizer.update_shield_display([25.0, 25.0, 25.0, 25.0])
	
	# Clear the display
	target_status_visualizer.clear_display()
	var status = target_status_visualizer.get_current_status()
	
	assert_that(status["hull_percentage"]).is_equal(0.0)
	assert_that(status["shield_quadrants"]).contains_exactly([0.0, 0.0, 0.0, 0.0])

func test_status_visualizer_validation() -> void:
	var validation_result = target_status_visualizer.validate_component()
	assert_that(validation_result).contains_key("is_valid")

## Subsystem Display Tests

func test_subsystem_display_initialization() -> void:
	assert_that(subsystem_display).is_not_null()
	assert_that(subsystem_display.name).is_equal("SubsystemDisplay")

func test_subsystem_status_update() -> void:
	var subsystem_data = {
		"engines": {"health": 80.0, "operational": true},
		"weapons": {"health": 60.0, "operational": true},
		"sensors": {"health": 40.0, "operational": false}
	}
	
	subsystem_display.update_subsystem_status(subsystem_data)
	var current_subsystems = subsystem_display.get_current_subsystems()
	
	assert_that(current_subsystems).contains_key("engines")
	assert_that(current_subsystems["engines"]["health"]).is_equal(80.0)
	assert_that(current_subsystems["sensors"]["operational"]).is_false()

func test_subsystem_selection() -> void:
	# Setup subsystem first
	var subsystem_data = {"engines": {"health": 100.0, "operational": true}}
	subsystem_display.update_subsystem_status(subsystem_data)
	
	# Select subsystem
	subsystem_display.select_subsystem("engines")
	assert_that(subsystem_display.get_selected_subsystem()).is_equal("engines")

func test_subsystem_critical_detection() -> void:
	var critical_triggered = false
	var critical_subsystem = ""
	subsystem_display.subsystem_critical.connect(func(name, health): 
		critical_triggered = true
		critical_subsystem = name
	)
	
	var critical_data = {"weapons": {"health": 20.0, "operational": true, "critical": true}}
	subsystem_display.update_subsystem_status(critical_data)
	
	assert_that(critical_triggered).is_true()
	assert_that(critical_subsystem).is_equal("weapons")

func test_clear_subsystem_display() -> void:
	# Set some data first
	var test_data = {"engines": {"health": 50.0, "operational": true}}
	subsystem_display.update_subsystem_status(test_data)
	
	# Clear display
	subsystem_display.clear_display()
	var current_subsystems = subsystem_display.get_current_subsystems()
	
	assert_that(current_subsystems).is_empty()
	assert_that(subsystem_display.get_selected_subsystem()).is_equal("")

func test_subsystem_targeting() -> void:
	var target_triggered = false
	var targeted_subsystem = ""
	subsystem_display.subsystem_targeted.connect(func(name):
		target_triggered = true
		targeted_subsystem = name
	)
	
	# Setup and target subsystem
	var test_data = {"weapons": {"health": 75.0, "operational": true}}
	subsystem_display.update_subsystem_status(test_data)
	subsystem_display.select_subsystem("weapons")
	
	# Simulate targeting (would normally be triggered by input)
	subsystem_display.subsystem_targeted.emit("weapons")
	
	assert_that(target_triggered).is_true()
	assert_that(targeted_subsystem).is_equal("weapons")

func test_subsystem_display_validation() -> void:
	var validation_result = subsystem_display.validate_component()
	assert_that(validation_result).contains_key("is_valid")

## Tactical Analyzer Tests

func test_tactical_analyzer_initialization() -> void:
	assert_that(tactical_analyzer).is_not_null()

func test_threat_assessment() -> void:
	var assessment = tactical_analyzer.assess_target_threat(mock_target)
	
	assert_that(assessment).is_not_null()
	assert_that(assessment.threat_level).is_greater_equal(TacticalAnalyzer.ThreatLevel.MINIMAL)
	assert_that(assessment.threat_level).is_less_equal(TacticalAnalyzer.ThreatLevel.EXTREME)
	assert_that(assessment.engagement_priority).is_greater_equal(1)
	assert_that(assessment.engagement_priority).is_less_equal(10)

func test_optimal_engagement_range_calculation() -> void:
	var player_weapons = [
		{"name": "laser_cannon", "range": 1000.0, "projectile_speed": 1500.0},
		{"name": "missile_launcher", "range": 2000.0, "projectile_speed": 800.0}
	]
	
	var optimal_range = tactical_analyzer.calculate_optimal_engagement_range(mock_target, player_weapons)
	assert_that(optimal_range).is_greater(0.0)
	assert_that(optimal_range).is_less_equal(5000.0)

func test_target_maneuverability_evaluation() -> void:
	var maneuverability = tactical_analyzer.evaluate_target_maneuverability(mock_target)
	assert_that(maneuverability).is_greater_equal(0.0)
	assert_that(maneuverability).is_less_equal(1.0)

func test_target_classification() -> void:
	# This tests the private _classify_target method indirectly through assess_target_threat
	var assessment = tactical_analyzer.assess_target_threat(mock_target)
	assert_that(assessment.target_class).is_greater_equal(TacticalAnalyzer.TargetClass.FIGHTER)
	assert_that(assessment.target_class).is_less_equal(TacticalAnalyzer.TargetClass.UNKNOWN)

func test_weapon_capability_analysis() -> void:
	var assessment = tactical_analyzer.assess_target_threat(mock_target)
	assert_that(assessment.weapon_capabilities).is_not_null()
	# Weapon capabilities should be an array of strings
	for capability in assessment.weapon_capabilities:
		assert_that(capability is String).is_true()

func test_tactical_assessment_caching() -> void:
	# First assessment
	var assessment1 = tactical_analyzer.assess_target_threat(mock_target)
	
	# Second assessment (should be cached)
	var assessment2 = tactical_analyzer.assess_target_threat(mock_target)
	
	# Should be the same object/data
	assert_that(assessment1.threat_level).is_equal(assessment2.threat_level)
	assert_that(assessment1.optimal_range).is_equal(assessment2.optimal_range)

func test_clear_tactical_cache() -> void:
	# Create an assessment to populate cache
	tactical_analyzer.assess_target_threat(mock_target)
	
	# Clear cache
	tactical_analyzer.clear_cache()
	
	# Should still work after cache clear
	var new_assessment = tactical_analyzer.assess_target_threat(mock_target)
	assert_that(new_assessment).is_not_null()

## Engagement Calculator Tests

func test_engagement_calculator_initialization() -> void:
	assert_that(engagement_calculator).is_not_null()

func test_engagement_parameters_calculation() -> void:
	var weapons = [{"name": "laser", "projectile_speed": 1000.0, "range": 1500.0}]
	var parameters = engagement_calculator.calculate_engagement_parameters(mock_target, mock_player, weapons)
	
	assert_that(parameters).contains_key("distance")
	assert_that(parameters).contains_key("time_to_intercept")
	assert_that(parameters).contains_key("optimal_attack_angle")
	assert_that(parameters).contains_key("weapon_solutions")

func test_intercept_course_calculation() -> void:
	var intercept_solution = engagement_calculator.calculate_intercept_course(mock_target, mock_player, 5.0)
	
	assert_that(intercept_solution).contains_key("is_possible")
	assert_that(intercept_solution).contains_key("intercept_time")
	assert_that(intercept_solution).contains_key("intercept_position")
	assert_that(intercept_solution).contains_key("success_probability")

func test_lead_angle_calculation() -> void:
	var weapon_speed = 1000.0
	var lead_solution = engagement_calculator.calculate_lead_angle(mock_target, mock_player, weapon_speed)
	
	assert_that(lead_solution).contains_key("lead_angle_horizontal")
	assert_that(lead_solution).contains_key("time_to_target")
	assert_that(lead_solution).contains_key("hit_probability")
	assert_that(lead_solution).contains_key("predicted_position")

func test_weapon_firing_solutions() -> void:
	var weapons = [
		{"name": "laser_cannon", "projectile_speed": 1500.0, "range": 1000.0, "reload_time": 0.5},
		{"name": "missile", "projectile_speed": 800.0, "range": 2000.0, "reload_time": 2.0}
	]
	
	var parameters = engagement_calculator.calculate_engagement_parameters(mock_target, mock_player, weapons)
	var solutions = parameters.get("weapon_solutions", [])
	
	assert_that(solutions.size()).is_equal(2)
	for solution in solutions:
		assert_that(solution).contains_key("weapon_name")
		assert_that(solution).contains_key("in_range")
		assert_that(solution).contains_key("hit_probability")

## Target Data Processor Tests

func test_target_data_processor_initialization() -> void:
	assert_that(target_data_processor).is_not_null()

func test_target_data_processing() -> void:
	var processed_data = target_data_processor.process_target_data(mock_target)
	
	assert_that(processed_data).contains_key("name")
	assert_that(processed_data).contains_key("position")
	assert_that(processed_data).contains_key("hull_percentage")
	assert_that(processed_data).contains_key("data_timestamp")

func test_data_validation() -> void:
	# Test with valid data - should process successfully
	var processed_data = target_data_processor.process_target_data(mock_target)
	assert_that(processed_data).is_not_empty()

func test_data_caching() -> void:
	# First processing
	var data1 = target_data_processor.process_target_data(mock_target)
	
	# Second processing (should use cache)
	var data2 = target_data_processor.process_target_data(mock_target)
	
	# Should have same timestamp if cached
	assert_that(data1.get("data_timestamp")).is_equal(data2.get("data_timestamp"))

func test_cache_statistics() -> void:
	# Process some data to populate cache
	target_data_processor.process_target_data(mock_target)
	
	var stats = target_data_processor.get_cache_statistics()
	assert_that(stats).contains_key("cache_size")
	assert_that(stats).contains_key("average_data_age")
	assert_that(stats["cache_size"]).is_greater(0)

func test_clear_data_cache() -> void:
	# Populate cache
	target_data_processor.process_target_data(mock_target)
	
	# Clear cache
	target_data_processor.clear_cache()
	
	var stats = target_data_processor.get_cache_statistics()
	assert_that(stats["cache_size"]).is_equal(0)

## Target Tracking Optimizer Tests

func test_tracking_optimizer_initialization() -> void:
	assert_that(target_tracking_optimizer).is_not_null()

func test_target_tracking_optimization() -> void:
	var optimization = target_tracking_optimizer.optimize_target_tracking(mock_target, mock_player)
	
	assert_that(optimization).contains_key("update_frequency")
	assert_that(optimization).contains_key("lod_level")
	assert_that(optimization).contains_key("priority_score")
	assert_that(optimization["update_frequency"]).is_greater(0.0)

func test_target_switch_optimization() -> void:
	var switch_result = target_tracking_optimizer.optimize_target_switch(null, mock_target)
	
	assert_that(switch_result).contains_key("new_target_id")
	assert_that(switch_result).contains_key("switch_duration")
	assert_that(switch_result["switch_duration"]).is_greater_equal(0.0)

func test_performance_monitoring() -> void:
	var metrics = target_tracking_optimizer.monitor_performance()
	
	assert_that(metrics).contains_key("frame_time")
	assert_that(metrics).contains_key("memory_usage")
	assert_that(metrics).contains_key("tracked_targets_count")

func test_stale_target_cleanup() -> void:
	# Optimize a target to add it to tracking
	target_tracking_optimizer.optimize_target_tracking(mock_target, mock_player)
	
	# Clean up stale targets
	var removed_count = target_tracking_optimizer.cleanup_stale_targets()
	assert_that(removed_count).is_greater_equal(0)

func test_tracking_statistics() -> void:
	# Add some tracking data
	target_tracking_optimizer.optimize_target_tracking(mock_target, mock_player)
	
	var stats = target_tracking_optimizer.get_tracking_statistics()
	assert_that(stats).contains_key("tracked_targets_count")
	assert_that(stats).contains_key("average_priority")

func test_clear_optimizations() -> void:
	# Add optimization data
	target_tracking_optimizer.optimize_target_tracking(mock_target, mock_player)
	
	# Clear all optimizations
	target_tracking_optimizer.clear_all_optimizations()
	
	var stats = target_tracking_optimizer.get_tracking_statistics()
	assert_that(stats["tracked_targets_count"]).is_equal(0)

## Integration Tests

func test_full_target_display_workflow() -> void:
	# Set target
	target_display.set_target(mock_target)
	
	# Update displays
	target_display.update_target_info(mock_target)
	target_display.display_target_status(75.0, 50.0)
	
	var subsystem_data = {
		"engines": {"health": 80.0, "operational": true},
		"weapons": {"health": 90.0, "operational": true}
	}
	target_display.show_subsystem_status(subsystem_data)
	
	# Verify data flow
	var target_data = target_display.get_element_data()
	assert_that(target_data).is_not_empty()
	assert_that(target_data).contains_key("name")

func test_target_switching_performance() -> void:
	# Set initial target
	target_display.set_target(mock_target)
	
	# Switch to new target (null in this case)
	var switch_start = Time.get_ticks_msec()
	target_display.set_target(null)
	var switch_duration = Time.get_ticks_msec() - switch_start
	
	# Should be fast (under 50ms)
	assert_that(switch_duration).is_less(50)

func test_tactical_data_integration() -> void:
	# Process target data
	var processed_data = target_data_processor.process_target_data(mock_target)
	
	# Perform tactical assessment
	var assessment = tactical_analyzer.assess_target_threat(mock_target)
	
	# Calculate engagement parameters
	var weapons = [{"name": "test_weapon", "projectile_speed": 1000.0, "range": 1500.0}]
	var engagement_params = engagement_calculator.calculate_engagement_parameters(mock_target, mock_player, weapons)
	
	# All should return valid data
	assert_that(processed_data).is_not_empty()
	assert_that(assessment).is_not_null()
	assert_that(engagement_params).is_not_empty()

func test_real_time_updates() -> void:
	# Set target and get initial data
	target_display.set_target(mock_target)
	var initial_data = target_display.get_element_data()
	
	# Simulate time passing and update
	await get_tree().process_frame
	target_display.update_target_info(mock_target)
	
	var updated_data = target_display.get_element_data()
	
	# Should have updated timestamp
	assert_that(updated_data.get("data_timestamp", 0.0)).is_greater_equal(initial_data.get("data_timestamp", 0.0))

func test_error_handling_invalid_targets() -> void:
	# Test with null target
	target_display.set_target(null)
	var null_data = target_display.get_element_data()
	assert_that(null_data).is_empty()
	
	# Test tactical analysis with null target
	var null_assessment = tactical_analyzer.assess_target_threat(null)
	assert_that(null_assessment.threat_level).is_equal(TacticalAnalyzer.ThreatLevel.MINIMAL)

## Utility functions for test setup

func _create_mock_objects() -> void:
	# Create mock target
	mock_target = Node3D.new()
	mock_target.name = "TestTarget"
	
	# Add methods that the targeting system expects
	mock_target.set_script(preload("res://tests/scripts/ui/hud/mocks/mock_target.gd"))
	
	# Create mock player
	mock_player = Node3D.new()
	mock_player.name = "TestPlayer"
	mock_player.set_script(preload("res://tests/scripts/ui/hud/mocks/mock_player.gd"))
	
	# Set positions
	mock_target.global_position = Vector3(1000, 0, 500)
	mock_player.global_position = Vector3(0, 0, 0)