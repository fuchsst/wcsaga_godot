@tool
extends GdUnitTestSuite

## Test suite for GFRED2 validation components
## Tests validation indicator, dependency graph view, and real-time validation

func test_validation_indicator_scene_instantiation():
	"""Test validation indicator scene can be instantiated."""
	
	var scene_path: String = "res://addons/gfred2/scenes/components/validation_indicator.tscn"
	assert_file_exists(scene_path)
	
	var scene: PackedScene = load(scene_path)
	assert_not_null(scene)
	
	var instance: ValidationIndicator = scene.instantiate()
	assert_not_null(instance)
	assert_that(instance).is_instance_of(ValidationIndicator)
	
	# Test basic properties
	assert_that(instance.indicator_size).is_equal(Vector2(16, 16))
	assert_bool(instance.show_tooltip).is_true()
	assert_bool(instance.animation_enabled).is_true()
	
	instance.queue_free()

func test_validation_indicator_status_updates():
	"""Test validation indicator status changes."""
	
	var indicator: ValidationIndicator = ValidationIndicator.new()
	add_child(indicator)
	
	# Test unknown status
	indicator.set_validation_status(ValidationIndicator.ValidationStatus.UNKNOWN)
	var summary: Dictionary = indicator.get_validation_summary()
	assert_that(summary.status).is_equal(ValidationIndicator.ValidationStatus.UNKNOWN)
	assert_bool(summary.is_valid).is_false()
	
	# Test valid status
	indicator.set_validation_status(ValidationIndicator.ValidationStatus.VALID)
	summary = indicator.get_validation_summary()
	assert_that(summary.status).is_equal(ValidationIndicator.ValidationStatus.VALID)
	assert_bool(summary.is_valid).is_true()
	
	# Test error status
	indicator.set_validation_status(ValidationIndicator.ValidationStatus.ERROR)
	summary = indicator.get_validation_summary()
	assert_that(summary.status).is_equal(ValidationIndicator.ValidationStatus.ERROR)
	assert_bool(summary.is_valid).is_false()
	
	indicator.queue_free()

func test_validation_indicator_with_validation_result():
	"""Test validation indicator with actual ValidationResult."""
	
	var indicator: ValidationIndicator = ValidationIndicator.new()
	add_child(indicator)
	
	# Create mock validation result
	var result: MockValidationResult = MockValidationResult.new()
	result.add_error("Test error")
	result.add_warning("Test warning")
	
	indicator.set_validation_result(result)
	
	var summary: Dictionary = indicator.get_validation_summary()
	assert_that(summary.error_count).is_equal(1)
	assert_bool(summary.has_result).is_true()
	assert_bool(summary.is_valid).is_false()
	
	indicator.queue_free()

func test_dependency_graph_view_scene_instantiation():
	"""Test dependency graph view scene can be instantiated."""
	
	var scene_path: String = "res://addons/gfred2/scenes/components/dependency_graph_view.tscn"
	assert_file_exists(scene_path)
	
	var scene: PackedScene = load(scene_path)
	assert_not_null(scene)
	
	var instance: DependencyGraphView = scene.instantiate()
	assert_not_null(instance)
	assert_that(instance).is_instance_of(DependencyGraphView)
	
	# Test basic properties
	assert_bool(instance.auto_layout).is_true()
	assert_bool(instance.show_validation_status).is_true()
	assert_that(instance.max_nodes_displayed).is_equal(100)
	
	instance.queue_free()

func test_dependency_graph_view_with_mock_data():
	"""Test dependency graph view with mock dependency data."""
	
	var graph_view: DependencyGraphView = DependencyGraphView.new()
	add_child(graph_view)
	
	# Create mock dependency graph
	var dependency_graph: MockDependencyGraph = MockDependencyGraph.new()
	dependency_graph.add_mock_dependency("ship1", "ship_class_asset", "GTF_Apollo")
	dependency_graph.add_mock_dependency("ship2", "ship_class_asset", "GTF_Ulysses")
	
	graph_view.set_dependency_graph(dependency_graph)
	
	# Test graph statistics
	var stats: Dictionary = graph_view.get_graph_statistics()
	assert_that(stats.displayed_nodes).is_greater_equal(0)
	assert_that(stats.current_filter).is_equal(DependencyGraphView.FilterType.ALL)
	
	graph_view.queue_free()

func test_validation_dock_scene_instantiation():
	"""Test validation dock scene can be instantiated."""
	
	var scene_path: String = "res://addons/gfred2/scenes/docks/validation_dock.tscn"
	assert_file_exists(scene_path)
	
	var scene: PackedScene = load(scene_path)
	assert_not_null(scene)
	
	var instance: ValidationDock = scene.instantiate()
	assert_not_null(instance)
	assert_that(instance).is_instance_of(ValidationDock)
	
	instance.queue_free()

func test_validation_dock_with_mock_controller():
	"""Test validation dock with mock validation controller."""
	
	var dock: ValidationDock = ValidationDock.new()
	add_child(dock)
	
	var controller: MockValidationController = MockValidationController.new()
	dock.set_validation_controller(controller)
	
	# Trigger mock validation
	controller.emit_mock_validation_completed()
	
	# Test validation summary
	var summary: Dictionary = dock.get_validation_summary()
	assert_that(summary).has_key("status")
	
	dock.queue_free()

func test_real_time_validation_controller():
	"""Test real-time validation controller functionality."""
	
	var controller: RealTimeValidationController = RealTimeValidationController.new()
	add_child(controller)
	
	# Test auto validation toggle
	controller.enable_auto_validation(false)
	assert_bool(controller.auto_validation_enabled).is_false()
	
	controller.enable_auto_validation(true)
	assert_bool(controller.auto_validation_enabled).is_true()
	
	# Test validation delay setting
	controller.set_validation_delay(1.0)
	assert_that(controller.validation_delay_seconds).is_equal(1.0)
	
	# Test minimum delay enforcement
	controller.set_validation_delay(0.05)  # Below minimum
	assert_that(controller.validation_delay_seconds).is_equal(0.1)  # Should be clamped
	
	controller.queue_free()

func test_validation_performance_requirements():
	"""Test that validation meets performance requirements."""
	
	var indicator: ValidationIndicator = ValidationIndicator.new()
	add_child(indicator)
	
	# Test scene instantiation time
	var start_time: int = Time.get_ticks_msec()
	
	var scene_path: String = "res://addons/gfred2/scenes/components/validation_indicator.tscn"
	var scene: PackedScene = load(scene_path)
	var instance: ValidationIndicator = scene.instantiate()
	add_child(instance)
	
	var instantiation_time: int = Time.get_ticks_msec() - start_time
	
	# Performance requirement: < 16ms scene instantiation
	assert_that(instantiation_time).is_less_than(16)
	
	# Test validation update performance
	start_time = Time.get_ticks_msec()
	
	var result: MockValidationResult = MockValidationResult.new()
	result.add_error("Performance test error")
	instance.set_validation_result(result)
	
	var update_time: int = Time.get_ticks_msec() - start_time
	
	# Should be very fast for single validation update
	assert_that(update_time).is_less_than(5)
	
	instance.queue_free()
	indicator.queue_free()

func test_validation_signal_integration():
	"""Test signal integration between validation components."""
	
	var controller: RealTimeValidationController = RealTimeValidationController.new()
	add_child(controller)
	
	var dock: ValidationDock = ValidationDock.new()
	add_child(dock)
	
	var graph_view: DependencyGraphView = DependencyGraphView.new()
	add_child(graph_view)
	
	# Connect components
	controller.validation_dock = dock
	controller.dependency_graph_view = graph_view
	
	# Monitor signals
	var signal_monitor: GdUnitSignalMonitor = monitor_signal(controller.validation_status_changed)
	
	# Trigger validation
	controller.trigger_immediate_validation()
	
	# Note: Since we don't have a real mission validation controller,
	# we can't test the full signal flow, but we can verify the setup
	assert_that(controller.validation_dock).is_same(dock)
	assert_that(controller.dependency_graph_view).is_same(graph_view)
	
	controller.queue_free()
	dock.queue_free()
	graph_view.queue_free()

## Mock classes for testing

class MockValidationResult:
	extends RefCounted
	
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	func add_error(error: String) -> void:
		errors.append(error)
	
	func add_warning(warning: String) -> void:
		warnings.append(warning)
	
	func is_valid() -> bool:
		return errors.is_empty()
	
	func get_errors() -> Array[String]:
		return errors
	
	func get_warnings() -> Array[String]:
		return warnings
	
	func get_error_count() -> int:
		return errors.size()
	
	func get_warning_count() -> int:
		return warnings.size()

class MockDependencyGraph:
	extends RefCounted
	
	var nodes: Dictionary = {}
	var edges: Dictionary = {}
	
	func add_mock_dependency(object_id: String, dep_type: String, dep_path: String) -> void:
		var dep_info: MockDependencyInfo = MockDependencyInfo.new()
		dep_info.object_id = object_id
		dep_info.dependency_type = dep_type
		dep_info.dependency_path = dep_path
		dep_info.is_valid = true
		
		nodes[dep_path] = dep_info
		
		if not edges.has(object_id):
			edges[object_id] = []
		edges[object_id].append(dep_path)
	
	func get_dependencies(object_id: String) -> Array:
		var deps: Array = []
		var dep_paths: Array = edges.get(object_id, [])
		for path in dep_paths:
			if nodes.has(path):
				deps.append(nodes[path])
		return deps

class MockDependencyInfo:
	extends RefCounted
	
	var object_id: String
	var dependency_type: String
	var dependency_path: String
	var is_valid: bool = true
	var error_message: String = ""

class MockValidationController:
	extends RefCounted
	
	signal validation_completed(result)
	signal validation_started()
	signal validation_progress(percentage: float, current_check: String)
	
	func emit_mock_validation_completed() -> void:
		var result: MockValidationDetailedResult = MockValidationDetailedResult.new()
		validation_completed.emit(result)
	
	func set_mission_data(data) -> void:
		pass
	
	func validate_mission() -> void:
		emit_mock_validation_completed()

class MockValidationDetailedResult:
	extends RefCounted
	
	var overall_result: MockValidationResult
	var statistics: Dictionary = {"total_errors": 0, "total_warnings": 0, "validation_time_ms": 50}
	
	func _init() -> void:
		overall_result = MockValidationResult.new()
	
	func is_valid() -> bool:
		return overall_result.is_valid()
	
	func get_total_errors() -> int:
		return overall_result.get_error_count()
	
	func get_total_warnings() -> int:
		return overall_result.get_warning_count()