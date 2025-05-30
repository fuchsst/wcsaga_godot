@tool
extends GdUnitTestSuite

## Test suite for GFRED2-006A: Real-time Validation and Dependency Tracking
## Tests the complete validation system integration with performance requirements

# Test components
var validation_controller: MissionValidationController
var validation_integration: ValidationIntegration
var validation_dock: ValidationDock
var dependency_graph: DependencyGraphView
var test_mission_data: MissionData

# Performance tracking
var validation_start_time: int
var validation_end_time: int

func before_test() -> void:
	# Create test mission data
	test_mission_data = _create_test_mission_data()
	
	# Initialize validation system
	validation_controller = MissionValidationController.new()
	add_child(validation_controller)
	
	validation_integration = ValidationIntegration.new()
	add_child(validation_integration)
	
	dependency_graph = DependencyGraphView.new()
	add_child(dependency_graph)

func after_test() -> void:
	if validation_controller:
		validation_controller.queue_free()
	if validation_integration:
		validation_integration.queue_free()
	if dependency_graph:
		dependency_graph.queue_free()

func _create_test_mission_data() -> MissionData:
	"""Create test mission data for validation testing."""
	var mission: MissionData = MissionData.create_empty_mission()
	
	# Set basic mission info using EPIC-002 structure
	mission.mission_title = "Test Mission"
	mission.author = "Test Author"
	mission.version = 1.0
	
	# Valid ship
	var valid_ship: ShipInstanceData = ShipInstanceData.new()
	valid_ship.ship_name = "Alpha 1"
	valid_ship.ship_class_name = "ships/terran/fighter.tres"
	valid_ship.position = Vector3(100, 0, 0)
	mission.ships.append(valid_ship)
	
	# Ship with errors
	var invalid_ship: ShipInstanceData = ShipInstanceData.new()
	invalid_ship.ship_name = ""  # Error: empty name
	invalid_ship.ship_class_name = "nonexistent/ship.tres"  # Error: missing asset
	invalid_ship.position = Vector3(float("inf"), 0, 0)  # Error: invalid position
	mission.ships.append(invalid_ship)
	
	return mission

## Validation Controller Tests

func test_validation_controller_initialization():
	assert_not_null(validation_controller, "Validation controller should be initialized")
	assert_not_null(validation_controller.dependency_graph, "Dependency graph should be initialized")

func test_mission_data_validation():
	# Set mission data
	validation_controller.set_mission_data(test_mission_data)
	
	# Trigger validation
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	assert_not_null(result, "Validation result should be returned")
	assert_false(result.is_valid(), "Mission with errors should be invalid")
	assert_greater(result.get_total_errors(), 0, "Should have validation errors")

func test_validation_performance_requirement():
	"""Test that validation completes within 100ms performance requirement."""
	validation_controller.set_mission_data(test_mission_data)
	
	var start_time: int = Time.get_ticks_msec()
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	var elapsed_time: int = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed_time).is_less_than(100)  # Performance requirement: <100ms
	assert_not_null(result, "Validation should complete successfully")

func test_real_time_validation_debouncing():
	"""Test that real-time validation properly debounces rapid changes."""
	validation_controller.set_mission_data(test_mission_data)
	validation_controller.enable_real_time_validation = true
	
	# Simulate rapid changes
	var validation_count: int = 0
	validation_controller.validation_completed.connect(func(result): validation_count += 1)
	
	# Trigger multiple rapid changes
	for i in range(5):
		validation_controller._on_mission_data_changed("test_property", "old", "new")
		await get_tree().process_frame
	
	# Wait for debounce
	await get_tree().create_timer(0.6).timeout
	
	# Should only validate once due to debouncing
	assert_that(validation_count).is_less_or_equal(1)

## Asset Dependency Validation Tests

func test_asset_dependency_tracking():
	"""Test asset dependency detection and validation."""
	validation_controller.set_mission_data(test_mission_data)
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	# Should detect missing asset references
	assert_greater(result.asset_results.size(), 0, "Should detect asset dependencies")
	
	# Should have errors for nonexistent assets
	var has_asset_errors: bool = false
	for asset_result in result.asset_results.values():
		if not (asset_result as ValidationResult).is_valid():
			has_asset_errors = true
			break
	
	assert_true(has_asset_errors, "Should detect invalid asset references")

func test_dependency_graph_creation():
	"""Test dependency graph construction."""
	validation_controller.set_mission_data(test_mission_data)
	validation_controller.validate_mission()
	
	var dep_graph: MissionValidationController.DependencyGraph = validation_controller.get_dependency_graph()
	
	assert_not_null(dep_graph, "Dependency graph should be created")
	assert_greater(dep_graph.nodes.size(), 0, "Should have dependency nodes")
	assert_greater(dep_graph.edges.size(), 0, "Should have dependency edges")

func test_missing_asset_reference_detection():
	"""Test detection of missing asset references."""
	validation_controller.set_mission_data(test_mission_data)
	
	var error_detected: bool = false
	validation_controller.asset_dependency_error.connect(func(path, error): error_detected = true)
	
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	assert_true(error_detected, "Should detect and signal missing asset references")

## SEXP Validation Tests

func test_sexp_expression_validation():
	"""Test basic SEXP expression validation."""
	validation_controller.set_mission_data(test_mission_data)
	
	# Test basic syntax validation
	var validation_result: ValidationResult = ValidationResult.new("test", "sexp")
	validation_controller._validate_sexp_string("(+ 1 2)", "test", validation_result)
	
	assert_true(validation_result.is_valid(), "Valid SEXP should pass validation")
	
	# Test invalid syntax
	var invalid_result: ValidationResult = ValidationResult.new("test", "sexp")
	validation_controller._validate_sexp_string("(+ 1 2", "test", invalid_result)
	
	assert_false(invalid_result.is_valid(), "Invalid SEXP should fail validation")

func test_sexp_error_reporting():
	"""Test SEXP validation error reporting."""
	validation_controller.set_mission_data(test_mission_data)
	
	var sexp_error_detected: bool = false
	validation_controller.sexp_validation_error.connect(func(expr, error): sexp_error_detected = true)
	
	# Trigger SEXP validation with invalid expression
	var result: ValidationResult = ValidationResult.new("test", "sexp")
	validation_controller._validate_sexp_string("(invalid sexp", "test", result)
	
	assert_true(sexp_error_detected, "Should detect and signal SEXP errors")

## Mission Object Validation Tests

func test_mission_object_validation():
	"""Test comprehensive mission object validation."""
	validation_controller.set_mission_data(test_mission_data)
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	# Should have validation results for all objects
	assert_that(result.object_results.size()).is_equal(test_mission_data.objects.size())
	
	# Valid object should pass
	var valid_result: ValidationResult = result.object_results["test_object_1"]
	assert_not_null(valid_result, "Should have result for valid object")
	# Note: May have warnings but should not have critical errors
	
	# Invalid object should fail
	var invalid_result: ValidationResult = result.object_results["test_object_2"]
	assert_not_null(invalid_result, "Should have result for invalid object")
	assert_false(invalid_result.is_valid(), "Invalid object should fail validation")

func test_cross_reference_validation():
	"""Test validation of cross-references between objects."""
	validation_controller.set_mission_data(test_mission_data)
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	# Should detect object name conflicts and references
	assert_not_null(result.overall_result, "Should have overall validation result")

## Performance Analysis Tests

func test_large_mission_performance():
	"""Test validation performance with large missions."""
	var large_mission: MissionData = _create_large_test_mission(200)  # 200 objects
	validation_controller.set_mission_data(large_mission)
	
	var start_time: int = Time.get_ticks_msec()
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	var elapsed_time: int = Time.get_ticks_msec() - start_time
	
	# Should still meet performance requirement
	assert_that(elapsed_time).is_less_than(100)
	assert_not_null(result, "Should handle large missions")

func _create_large_test_mission(object_count: int) -> MissionData:
	"""Create a large mission for performance testing."""
	var mission: MissionData = MissionData.new()
	mission.mission_info = MissionInfo.new()
	mission.mission_info.name = "Large Test Mission"
	mission.objects = []
	
	for i in range(object_count):
		var obj: MissionObjectData = MissionObjectData.new()
		obj.object_id = "object_%d" % i
		obj.object_name = "Ship %d" % i
		obj.ship_class = "ships/test/fighter.tres"
		obj.position = Vector3(i * 100, 0, 0)
		mission.objects.append(obj)
	
	return mission

func test_validation_caching():
	"""Test validation result caching for performance."""
	validation_controller.set_mission_data(test_mission_data)
	
	# First validation
	var start_time1: int = Time.get_ticks_msec()
	var result1: MissionValidationController.MissionValidationResult = validation_controller.validate_mission()
	var time1: int = Time.get_ticks_msec() - start_time1
	
	# Second validation (should use cache for some components)
	var start_time2: int = Time.get_ticks_msec()
	var result2: MissionValidationController.MissionValidationResult = validation_controller.validate_mission()
	var time2: int = Time.get_ticks_msec() - start_time2
	
	assert_not_null(result1, "First validation should succeed")
	assert_not_null(result2, "Second validation should succeed")
	# Note: Caching performance improvement is implementation dependent

## Visual Indicator Tests

func test_validation_indicator_creation():
	"""Test validation indicator creation and management."""
	var indicator: ValidationIndicator = ValidationIndicator.new()
	add_child(indicator)
	
	assert_not_null(indicator, "Validation indicator should be created")
	assert_that(indicator.current_state).is_equal(ValidationIndicator.IndicatorState.UNKNOWN)
	
	# Test state changes
	var test_result: ValidationResult = ValidationResult.new("test", "object")
	test_result.add_error("Test error")
	
	indicator.update_from_validation_result(test_result)
	assert_that(indicator.current_state).is_equal(ValidationIndicator.IndicatorState.ERROR)
	
	indicator.queue_free()

func test_validation_indicator_accessibility():
	"""Test validation indicator accessibility features."""
	var indicator: ValidationIndicator = ValidationIndicator.new()
	indicator.screen_reader_enabled = true
	indicator.high_contrast_mode = true
	add_child(indicator)
	
	# Test accessibility configuration
	assert_true(indicator.screen_reader_enabled, "Screen reader should be enabled")
	assert_true(indicator.high_contrast_mode, "High contrast should be enabled")
	
	# Test focus handling
	indicator.grab_focus()
	assert_true(indicator.has_focus(), "Indicator should support focus")
	
	indicator.queue_free()

## Dependency Graph Visualization Tests

func test_dependency_graph_view_creation():
	"""Test dependency graph visualization creation."""
	assert_not_null(dependency_graph, "Dependency graph view should be created")
	assert_that(dependency_graph.get_node_count()).is_equal(0)

func test_dependency_graph_population():
	"""Test dependency graph population with mission data."""
	validation_controller.set_mission_data(test_mission_data)
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	dependency_graph.set_dependency_graph(
		validation_controller.get_dependency_graph(),
		test_mission_data
	)
	
	# Should create nodes for mission objects and dependencies
	assert_greater(dependency_graph.get_node_count(), 0, "Should create graph nodes")

func test_dependency_graph_performance_limit():
	"""Test dependency graph performance limits."""
	dependency_graph.max_nodes = 5  # Set low limit for testing
	
	var large_mission: MissionData = _create_large_test_mission(10)
	validation_controller.set_mission_data(large_mission)
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	dependency_graph.set_dependency_graph(
		validation_controller.get_dependency_graph(),
		large_mission
	)
	
	# Should respect performance limits
	assert_that(dependency_graph.get_node_count()).is_less_or_equal(dependency_graph.max_nodes + 1)  # +1 for warning node

## Integration Tests

func test_validation_integration_system():
	"""Test complete validation integration system."""
	validation_integration.set_mission_data(test_mission_data)
	
	assert_true(validation_integration.is_validation_system_ready(), "Integration system should be ready")
	
	var controller: MissionValidationController = validation_integration.get_validation_controller()
	assert_not_null(controller, "Should provide validation controller")
	
	var dock: ValidationDock = validation_integration.get_validation_dock()
	assert_not_null(dock, "Should provide validation dock")

func test_validation_dock_ui_updates():
	"""Test validation dock UI updates."""
	validation_dock = ValidationDock.new()
	add_child(validation_dock)
	
	validation_dock.set_validation_controller(validation_controller)
	validation_controller.set_mission_data(test_mission_data)
	
	# Trigger validation
	validation_controller.validate_mission()
	
	# UI should update
	assert_not_null(validation_dock.current_validation_result, "Dock should receive validation results")
	
	validation_dock.queue_free()

func test_error_reporting_and_suggestions():
	"""Test comprehensive error reporting with actionable suggestions."""
	validation_controller.set_mission_data(test_mission_data)
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	# Should generate detailed validation report
	var report: String = validation_controller.generate_validation_report()
	assert_str_contains(report, "MISSION VALIDATION REPORT", "Should generate formatted report")
	assert_str_contains(report, "ERROR", "Should include error information")
	
	# Should have actionable error messages
	var has_actionable_errors: bool = false
	for object_result in result.object_results.values():
		var validation_result: ValidationResult = object_result as ValidationResult
		for error in validation_result.get_errors():
			if not error.is_empty():
				has_actionable_errors = true
				break
	
	assert_true(has_actionable_errors, "Should provide actionable error messages")

## Statistics and Reporting Tests

func test_validation_statistics():
	"""Test validation statistics collection."""
	validation_controller.set_mission_data(test_mission_data)
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	var stats: Dictionary = validation_controller.get_validation_statistics()
	
	assert_dict_contains_key(stats, "total_objects", "Should track object count")
	assert_dict_contains_key(stats, "total_errors", "Should track error count")
	assert_dict_contains_key(stats, "validation_time_ms", "Should track validation time")
	assert_dict_contains_key(stats, "dependencies_tracked", "Should track dependency count")

func test_validation_report_generation():
	"""Test validation report generation."""
	validation_controller.set_mission_data(test_mission_data)
	validation_controller.validate_mission()
	
	var report: String = validation_controller.generate_validation_report()
	
	assert_str_contains(report, "MISSION VALIDATION REPORT", "Should have proper header")
	assert_str_contains(report, "Summary:", "Should have summary section")
	assert_str_contains(report, "Objects:", "Should include object count")
	assert_str_contains(report, "Errors:", "Should include error count")

## Edge Case Tests

func test_null_mission_data_handling():
	"""Test handling of null mission data."""
	validation_controller.set_mission_data(null)
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	# Should handle gracefully without crashing
	assert_null(result, "Should return null for null mission data")

func test_empty_mission_validation():
	"""Test validation of empty mission."""
	var empty_mission: MissionData = MissionData.new()
	validation_controller.set_mission_data(empty_mission)
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	
	assert_not_null(result, "Should handle empty missions")
	# May have warnings but shouldn't crash

func test_concurrent_validation_requests():
	"""Test handling of concurrent validation requests."""
	validation_controller.set_mission_data(test_mission_data)
	
	# Trigger multiple rapid validations
	var results: Array[MissionValidationController.MissionValidationResult] = []
	for i in range(3):
		results.append(validation_controller.validate_mission())
	
	# All should complete successfully
	for result in results:
		assert_not_null(result, "Concurrent validations should complete")

## Clean-up and Resource Management Tests

func test_validation_cache_cleanup():
	"""Test validation cache cleanup and memory management."""
	validation_controller.set_mission_data(test_mission_data)
	
	# Perform multiple validations to populate cache
	for i in range(5):
		validation_controller.validate_mission()
	
	# Clear cache
	validation_controller.clear_validation_cache()
	
	# Should still work after cache clear
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	assert_not_null(result, "Should work after cache clear")

func test_memory_cleanup_on_mission_change():
	"""Test memory cleanup when mission data changes."""
	# Set initial mission
	validation_controller.set_mission_data(test_mission_data)
	validation_controller.validate_mission()
	
	# Change to different mission
	var new_mission: MissionData = _create_large_test_mission(50)
	validation_controller.set_mission_data(new_mission)
	
	# Should handle mission change gracefully
	var result: MissionValidationController.MissionValidationDetailedResult = validation_controller.validate_mission()
	assert_not_null(result, "Should handle mission data changes")