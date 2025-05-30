@tool
class_name RealTimeValidationIntegration
extends VBoxContainer

## Real-time validation integration for GFRED2 mission editor
## Scene: addons/gfred2/scenes/components/real_time_validation_panel.tscn
## Coordinates validation controller, visual indicators, and dependency tracking
## Provides unified interface for all validation-related functionality

## Scene node references
@onready var mission_indicator: ValidationIndicator = $ValidationStatusHeader/MissionValidationIndicator
@onready var refresh_button: Button = $ValidationStatusHeader/RefreshButton
@onready var error_count_label: Label = $StatisticsContainer/ErrorCountValue
@onready var warning_count_label: Label = $StatisticsContainer/WarningCountValue
@onready var validation_time_label: Label = $StatisticsContainer/ValidationTimeValue
@onready var dependency_count_label: Label = $StatisticsContainer/DependencyCountValue
@onready var performance_status_label: Label = $PerformanceContainer/PerformanceGrid/PerformanceStatusValue
@onready var threshold_label: Label = $PerformanceContainer/PerformanceGrid/ThresholdValue
@onready var real_time_check: CheckBox = $ControlsContainer/EnableRealTimeCheck
@onready var show_dependencies_button: Button = $ControlsContainer/ShowDependenciesButton
@onready var export_report_button: Button = $ControlsContainer/ExportReportButton

signal validation_status_changed(is_valid: bool, error_count: int, warning_count: int)
signal dependency_graph_updated(graph: MissionValidationController.DependencyGraph)
signal validation_performance_warning(validation_time_ms: int)

## Core components
var validation_controller: MissionValidationController
var dependency_graph_view: DependencyGraphView
var validation_indicators: Dictionary = {}  # object_id -> ValidationIndicator

## Performance monitoring
@export var performance_threshold_ms: int = 100  # AC8 requirement
@export var update_interval_ms: int = 16  # 60 FPS requirement
@export var enable_performance_warnings: bool = true

## Validation state
var current_mission_data: MissionData
var validation_timer: Timer
var last_validation_time: int = 0
var validation_cache: Dictionary = {}

## Statistics tracking (AC9 requirement)
var validation_statistics: Dictionary = {
	"total_validations": 0,
	"average_validation_time_ms": 0.0,
	"error_count_history": [],
	"warning_count_history": [],
	"performance_warnings": 0
}

func _ready() -> void:
	name = "RealTimeValidationIntegration"
	
	# Initialize components
	_initialize_validation_controller()
	_setup_validation_timer()
	_connect_validation_signals()
	_connect_ui_signals()
	_initialize_ui_state()

func _initialize_validation_controller() -> void:
	"""Initialize the mission validation controller."""
	
	validation_controller = MissionValidationController.new()
	add_child(validation_controller)
	
	# Configure for real-time performance (AC8)
	validation_controller.enable_real_time_validation = true
	validation_controller.validation_delay_ms = 500
	validation_controller.max_validation_time_ms = performance_threshold_ms
	validation_controller.enable_dependency_tracking = true
	validation_controller.enable_visual_indicators = true

func _setup_validation_timer() -> void:
	"""Setup timer for regular validation updates."""
	
	validation_timer = Timer.new()
	validation_timer.wait_time = update_interval_ms / 1000.0
	validation_timer.timeout.connect(_on_validation_update_timer)
	add_child(validation_timer)
	validation_timer.start()

func _connect_validation_signals() -> void:
	"""Connect validation controller signals."""
	
	if validation_controller:
		validation_controller.validation_completed.connect(_on_validation_completed)
		validation_controller.dependency_analysis_completed.connect(_on_dependency_analysis_completed)
		validation_controller.asset_dependency_error.connect(_on_asset_dependency_error)
		validation_controller.sexp_validation_error.connect(_on_sexp_validation_error)

func _connect_ui_signals() -> void:
	"""Connect UI component signals."""
	
	refresh_button.pressed.connect(_on_refresh_pressed)
	real_time_check.toggled.connect(_on_real_time_toggled)
	show_dependencies_button.pressed.connect(_on_show_dependencies_pressed)
	export_report_button.pressed.connect(_on_export_report_pressed)

func _initialize_ui_state() -> void:
	"""Initialize UI component states."""
	
	threshold_label.text = "%dms" % performance_threshold_ms
	_update_ui_from_statistics()
	
	# Register mission indicator
	register_validation_indicator("mission", mission_indicator)

func set_mission_data(mission_data: MissionData) -> void:
	"""Set mission data and start real-time validation.
	Args:
		mission_data: Mission data to validate"""
	
	current_mission_data = mission_data
	
	if validation_controller:
		validation_controller.set_mission_data(mission_data)

func register_validation_indicator(object_id: String, indicator: ValidationIndicator) -> void:
	"""Register a validation indicator for real-time updates (AC5).
	Args:
		object_id: Object to track validation for
		indicator: Visual indicator to update"""
	
	validation_indicators[object_id] = indicator
	
	# Set initial state
	indicator.set_unknown()
	
	# Connect click signal for detailed error display
	indicator.indicator_clicked.connect(_on_indicator_clicked)

func unregister_validation_indicator(object_id: String) -> void:
	"""Unregister a validation indicator.
	Args:
		object_id: Object to stop tracking"""
	
	if validation_indicators.has(object_id):
		var indicator: ValidationIndicator = validation_indicators[object_id]
		if indicator.indicator_clicked.is_connected(_on_indicator_clicked):
			indicator.indicator_clicked.disconnect(_on_indicator_clicked)
		validation_indicators.erase(object_id)

func set_dependency_graph_view(graph_view: DependencyGraphView) -> void:
	"""Set dependency graph view for visualization (AC6).
	Args:
		graph_view: Dependency graph visualization component"""
	
	dependency_graph_view = graph_view
	
	if dependency_graph_view:
		dependency_graph_view.node_selected.connect(_on_dependency_node_selected)
		dependency_graph_view.dependency_highlighted.connect(_on_dependency_highlighted)

func trigger_manual_validation() -> void:
	"""Manually trigger validation for immediate results."""
	
	if validation_controller and current_mission_data:
		validation_controller.validate_mission()

func get_validation_statistics() -> Dictionary:
	"""Get validation performance statistics (AC9).
	Returns:
		Statistics dictionary with performance metrics"""
	
	return validation_statistics.duplicate()

func generate_validation_report() -> String:
	"""Generate comprehensive validation report (AC7).
	Returns:
		Human-readable validation report"""
	
	if not validation_controller:
		return "Validation system not initialized"
	
	return validation_controller.generate_validation_report()

## Signal Handlers

func _on_validation_update_timer() -> void:
	"""Handle regular validation update timer."""
	
	# Update statistics display and check for performance issues
	if validation_controller:
		var stats: Dictionary = validation_controller.get_validation_statistics()
		_update_validation_statistics(stats)

func _on_validation_completed(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Handle validation completion (AC1, AC2, AC3, AC4).
	Args:
		result: Detailed validation result"""
	
	if not result:
		return
	
	# Update statistics
	validation_statistics["total_validations"] += 1
	
	# Calculate average validation time
	var current_time: float = result.validation_time_ms
	var total_validations: int = validation_statistics["total_validations"]
	var current_avg: float = validation_statistics["average_validation_time_ms"]
	validation_statistics["average_validation_time_ms"] = ((current_avg * (total_validations - 1)) + current_time) / total_validations
	
	# Track error/warning counts
	var error_count: int = result.get_total_errors()
	var warning_count: int = result.get_total_warnings()
	
	validation_statistics["error_count_history"].append(error_count)
	validation_statistics["warning_count_history"].append(warning_count)
	
	# Keep only last 100 entries for performance
	if validation_statistics["error_count_history"].size() > 100:
		validation_statistics["error_count_history"] = validation_statistics["error_count_history"].slice(-100)
	if validation_statistics["warning_count_history"].size() > 100:
		validation_statistics["warning_count_history"] = validation_statistics["warning_count_history"].slice(-100)
	
	# Performance warning check (AC8)
	if enable_performance_warnings and result.validation_time_ms > performance_threshold_ms:
		validation_statistics["performance_warnings"] += 1
		validation_performance_warning.emit(result.validation_time_ms)
	
	# Update visual indicators (AC5)
	_update_validation_indicators(result)
	
	# Update UI display
	_update_ui_from_statistics()
	
	# Emit status change
	validation_status_changed.emit(result.is_valid(), error_count, warning_count)

func _on_dependency_analysis_completed(dependencies: Array[MissionValidationController.DependencyInfo]) -> void:
	"""Handle dependency analysis completion (AC2, AC6).
	Args:
		dependencies: Array of dependency information"""
	
	if dependency_graph_view and validation_controller:
		var graph: MissionValidationController.DependencyGraph = validation_controller.get_dependency_graph()
		dependency_graph_view.set_dependency_graph(graph, current_mission_data)
		dependency_graph_updated.emit(graph)

func _on_asset_dependency_error(asset_path: String, error_message: String) -> void:
	"""Handle asset dependency error (AC2).
	Args:
		asset_path: Path to problematic asset
		error_message: Error description"""
	
	push_warning("Asset dependency error: %s - %s" % [asset_path, error_message])
	
	# TODO: Update UI to show asset-specific errors

func _on_sexp_validation_error(expression: String, error_message: String) -> void:
	"""Handle SEXP validation error (AC3).
	Args:
		expression: SEXP expression with error
		error_message: Error description"""
	
	push_warning("SEXP validation error: %s - %s" % [expression, error_message])
	
	# TODO: Update SEXP editor to show expression-specific errors

func _on_indicator_clicked(validation_result: ValidationResult) -> void:
	"""Handle validation indicator click for detailed error display (AC7).
	Args:
		validation_result: Validation result to display"""
	
	if validation_result and not validation_result.is_valid():
		# TODO: Show detailed error dialog
		var errors: Array[String] = validation_result.get_errors()
		var warnings: Array[String] = validation_result.get_warnings()
		
		var message: String = "Validation Issues:\n\n"
		
		if not errors.is_empty():
			message += "Errors:\n"
			for error in errors:
				message += "• " + error + "\n"
			message += "\n"
		
		if not warnings.is_empty():
			message += "Warnings:\n"
			for warning in warnings:
				message += "• " + warning + "\n"
		
		# Display in editor or console
		print("Validation Details: ", message)

func _on_dependency_node_selected(node_id: String, dependency_info: MissionValidationController.DependencyInfo) -> void:
	"""Handle dependency graph node selection.
	Args:
		node_id: Selected node ID
		dependency_info: Associated dependency information"""
	
	if dependency_info:
		print("Selected dependency: %s -> %s (valid: %s)" % [dependency_info.object_id, dependency_info.dependency_path, dependency_info.is_valid])

func _on_dependency_highlighted(from_id: String, to_id: String) -> void:
	"""Handle dependency path highlighting.
	Args:
		from_id: Source node ID
		to_id: Target node ID"""
	
	print("Highlighted dependency path: %s -> %s" % [from_id, to_id])

## UI Signal Handlers

func _on_refresh_pressed() -> void:
	"""Handle manual validation trigger."""
	trigger_manual_validation()

func _on_real_time_toggled(pressed: bool) -> void:
	"""Handle real-time validation toggle."""
	enable_real_time_validation(pressed)

func _on_show_dependencies_pressed() -> void:
	"""Handle show dependencies button."""
	# TODO: Show dependency graph dialog
	print("Show dependencies requested")

func _on_export_report_pressed() -> void:
	"""Handle export report button."""
	var report: String = generate_validation_report()
	print("Validation Report:\n", report)
	# TODO: Save to file or show in dialog

func _update_ui_from_statistics() -> void:
	"""Update UI elements from current statistics."""
	
	var error_count: int = 0
	var warning_count: int = 0
	var validation_time: float = validation_statistics.get("average_validation_time_ms", 0.0)
	var dependency_count: int = get_dependency_count()
	
	# Get latest counts from history
	var error_history: Array = validation_statistics.get("error_count_history", [])
	var warning_history: Array = validation_statistics.get("warning_count_history", [])
	
	if not error_history.is_empty():
		error_count = error_history[-1]
	if not warning_history.is_empty():
		warning_count = warning_history[-1]
	
	# Update labels
	error_count_label.text = str(error_count)
	warning_count_label.text = str(warning_count)
	validation_time_label.text = "%.1fms" % validation_time
	dependency_count_label.text = str(dependency_count)
	
	# Update performance status
	if validation_time <= performance_threshold_ms:
		performance_status_label.text = "Good"
		performance_status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2, 1))
	else:
		performance_status_label.text = "Slow"
		performance_status_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))

## Private Methods

func _update_validation_indicators(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Update all registered validation indicators (AC5).
	Args:
		result: Validation result to use for updates"""
	
	# Update overall mission indicator
	if validation_indicators.has("mission"):
		var mission_indicator: ValidationIndicator = validation_indicators["mission"]
		mission_indicator.update_from_validation_result(result.overall_result)
	
	# Update object-specific indicators (AC4)
	for object_id in result.object_results.keys():
		if validation_indicators.has(object_id):
			var indicator: ValidationIndicator = validation_indicators[object_id]
			var object_result: ValidationResult = result.object_results[object_id]
			indicator.update_from_validation_result(object_result)
	
	# Update asset-specific indicators (AC2)
	for asset_path in result.asset_results.keys():
		var asset_id: String = "asset_" + asset_path.get_file().get_basename()
		if validation_indicators.has(asset_id):
			var indicator: ValidationIndicator = validation_indicators[asset_id]
			var asset_result: ValidationResult = result.asset_results[asset_path]
			indicator.update_from_validation_result(asset_result)
	
	# Update SEXP-specific indicators (AC3)
	for sexp_id in result.sexp_results.keys():
		if validation_indicators.has(sexp_id):
			var indicator: ValidationIndicator = validation_indicators[sexp_id]
			var sexp_result: ValidationResult = result.sexp_results[sexp_id]
			indicator.update_from_validation_result(sexp_result)

func _update_validation_statistics(stats: Dictionary) -> void:
	"""Update internal validation statistics.
	Args:
		stats: Statistics from validation controller"""
	
	# Merge with internal statistics
	for key in stats.keys():
		validation_statistics[key] = stats[key]

## Public API

func enable_real_time_validation(enabled: bool) -> void:
	"""Enable or disable real-time validation.
	Args:
		enabled: Whether to enable real-time validation"""
	
	if validation_controller:
		validation_controller.set_real_time_validation(enabled)

func set_performance_threshold(threshold_ms: int) -> void:
	"""Set performance warning threshold (AC8).
	Args:
		threshold_ms: Threshold in milliseconds"""
	
	performance_threshold_ms = threshold_ms
	if validation_controller:
		validation_controller.max_validation_time_ms = threshold_ms

func clear_validation_cache() -> void:
	"""Clear validation cache to force fresh validation."""
	
	if validation_controller:
		validation_controller.clear_validation_cache()
	validation_cache.clear()

func export_validation_statistics() -> Dictionary:
	"""Export validation statistics for analysis (AC9).
	Returns:
		Complete statistics with performance data"""
	
	var export_data: Dictionary = validation_statistics.duplicate(true)
	
	# Add current validation controller stats
	if validation_controller:
		var controller_stats: Dictionary = validation_controller.get_validation_statistics()
		export_data["controller_stats"] = controller_stats
	
	# Add timing information
	export_data["export_timestamp"] = Time.get_unix_time_from_system()
	export_data["update_interval_ms"] = update_interval_ms
	export_data["performance_threshold_ms"] = performance_threshold_ms
	
	return export_data

func get_dependency_count() -> int:
	"""Get current dependency count for dashboard (AC9).
	Returns:
		Number of tracked dependencies"""
	
	if validation_controller:
		var graph: MissionValidationController.DependencyGraph = validation_controller.get_dependency_graph()
		return graph.nodes.size() if graph else 0
	return 0

func validate_mission_performance() -> Dictionary:
	"""Validate mission performance characteristics (AC8).
	Returns:
		Performance analysis result"""
	
	var performance_result: Dictionary = {
		"validation_time_ms": validation_statistics.get("average_validation_time_ms", 0.0),
		"meets_performance_threshold": false,
		"dependency_count": get_dependency_count(),
		"total_validations": validation_statistics.get("total_validations", 0),
		"performance_warnings": validation_statistics.get("performance_warnings", 0)
	}
	
	performance_result["meets_performance_threshold"] = performance_result["validation_time_ms"] <= performance_threshold_ms
	
	return performance_result