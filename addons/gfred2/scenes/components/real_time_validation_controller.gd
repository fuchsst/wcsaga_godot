@tool
class_name RealTimeValidationController
extends Node

## Real-time validation integration controller for GFRED2 mission editor
## Coordinates validation between mission data, validation dock, and dependency graph
## Part of mandatory scene-based UI architecture (EPIC-005)

signal validation_status_changed(status: String, details: Dictionary)
signal validation_item_focus_requested(item_type: String, item_id: String)

## Core references - set externally by main editor
var mission_validation_controller: MissionValidationController
var validation_dock: ValidationDock
var dependency_graph_view: DependencyGraphView
var mission_data: MissionData

## Real-time validation configuration
@export var auto_validation_enabled: bool = true
@export var validation_delay_seconds: float = 0.5
@export var performance_monitoring_enabled: bool = true

## Validation state tracking
var validation_timer: Timer
var pending_validation: bool = false
var last_validation_hash: String = ""

func _ready() -> void:
	name = "RealTimeValidationController"
	
	# Setup validation timer
	validation_timer = Timer.new()
	validation_timer.wait_time = validation_delay_seconds
	validation_timer.one_shot = true
	validation_timer.timeout.connect(_trigger_validation)
	add_child(validation_timer)
	
	# Connect to mission editor signals if possible
	call_deferred("_initialize_connections")

func _initialize_connections() -> void:
	"""Initialize connections to editor components once everything is ready."""
	
	# Find components in the scene tree if not set externally
	if not validation_dock:
		validation_dock = _find_node_by_type(ValidationDock)
	
	if not dependency_graph_view:
		dependency_graph_view = _find_node_by_type(DependencyGraphView)
	
	if not mission_validation_controller:
		mission_validation_controller = _find_node_by_type(MissionValidationController)
	
	# Setup connections
	_setup_component_connections()

func _find_node_by_type(node_type) -> Node:
	"""Find node of specific type in scene tree.
	Args:
		node_type: Class type to find
	Returns:
		First node of matching type or null"""
	
	var nodes: Array[Node] = []
	_find_nodes_recursive(get_tree().root, node_type, nodes)
	
	return nodes[0] if not nodes.is_empty() else null

func _find_nodes_recursive(node: Node, target_type, result_array: Array[Node]) -> void:
	"""Recursively find nodes of target type.
	Args:
		node: Node to search
		target_type: Type to match
		result_array: Array to store results"""
	
	if node.get_script() and node.get_script().get_global_name() == target_type.get_global_name():
		result_array.append(node)
	
	for child in node.get_children():
		_find_nodes_recursive(child, target_type, result_array)

func _setup_component_connections() -> void:
	"""Setup connections between validation components."""
	
	# Connect validation dock
	if validation_dock:
		validation_dock.validation_requested.connect(_on_manual_validation_requested)
		validation_dock.validation_item_selected.connect(_on_validation_item_selected)
		
		# Connect validation controller to dock
		if mission_validation_controller:
			validation_dock.set_validation_controller(mission_validation_controller)
	
	# Connect dependency graph view
	if dependency_graph_view:
		dependency_graph_view.node_selected.connect(_on_dependency_node_selected)
	
	# Connect mission validation controller
	if mission_validation_controller:
		mission_validation_controller.validation_completed.connect(_on_validation_completed)
		mission_validation_controller.dependency_analysis_completed.connect(_on_dependency_analysis_completed)
		mission_validation_controller.asset_dependency_error.connect(_on_asset_dependency_error)
		mission_validation_controller.sexp_validation_error.connect(_on_sexp_validation_error)

func set_mission_data(data: MissionData) -> void:
	"""Set mission data and setup validation.
	Args:
		data: Mission data to validate"""
	
	mission_data = data
	
	if mission_validation_controller:
		mission_validation_controller.set_mission_data(data)
	
	# Connect to mission data changes for real-time validation
	if mission_data and mission_data.has_signal("data_changed"):
		if not mission_data.data_changed.is_connected(_on_mission_data_changed):
			mission_data.data_changed.connect(_on_mission_data_changed)
	
	# Trigger initial validation
	if auto_validation_enabled:
		_schedule_validation()

func _on_mission_data_changed(property: String, old_value: Variant, new_value: Variant) -> void:
	"""Handle mission data changes for real-time validation.
	Args:
		property: Property that changed
		old_value: Previous value  
		new_value: New value"""
	
	if auto_validation_enabled:
		_schedule_validation()

func _schedule_validation() -> void:
	"""Schedule validation after a delay to avoid excessive validation."""
	
	if not validation_timer:
		return
	
	pending_validation = true
	validation_timer.start()

func _trigger_validation() -> void:
	"""Trigger validation if there are pending changes."""
	
	if not pending_validation or not mission_validation_controller:
		return
	
	pending_validation = false
	
	# Check if validation is actually needed by comparing data hash
	var current_hash: String = _calculate_mission_data_hash()
	if current_hash == last_validation_hash:
		return  # No changes since last validation
	
	last_validation_hash = current_hash
	
	# Trigger validation
	mission_validation_controller.validate_mission()

func _calculate_mission_data_hash() -> String:
	"""Calculate hash of mission data to detect changes.
	Returns:
		String hash of mission data"""
	
	if not mission_data:
		return ""
	
	# Create hash based on mission data properties
	var hash_data: String = ""
	
	# Include ship count and basic properties
	if mission_data.has("ships") and mission_data.ships:
		hash_data += "ships:%d;" % mission_data.ships.size()
		for i in range(min(10, mission_data.ships.size())):  # Sample first 10 ships
			var ship = mission_data.ships[i]
			if ship and ship.has("ship_name"):
				hash_data += ship.ship_name + ";"
	
	# Include event count and basic properties
	if mission_data.has("events") and mission_data.events:
		hash_data += "events:%d;" % mission_data.events.size()
	
	# Include wing count
	if mission_data.has("wings") and mission_data.wings:
		hash_data += "wings:%d;" % mission_data.wings.size()
	
	return hash_data.md5_text()

func _on_validation_completed(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Handle validation completion.
	Args:
		result: Completed validation result"""
	
	# Update dependency graph with validation results
	if dependency_graph_view and mission_validation_controller:
		var dependency_graph: MissionValidationController.DependencyGraph = mission_validation_controller.get_dependency_graph()
		dependency_graph_view.set_dependency_graph(dependency_graph)
		
		# Combine validation results for dependency display
		var combined_results: Dictionary = {}
		combined_results.merge(result.object_results)
		combined_results.merge(result.asset_results)
		combined_results.merge(result.sexp_results)
		
		dependency_graph_view.set_validation_results(combined_results)
	
	# Emit status change signal
	var status: String = "valid" if result.is_valid() else "invalid"
	var details: Dictionary = {
		"error_count": result.get_total_errors(),
		"warning_count": result.get_total_warnings(),
		"validation_time": result.validation_time_ms,
		"statistics": result.statistics
	}
	
	validation_status_changed.emit(status, details)

func _on_dependency_analysis_completed(dependencies: Array) -> void:
	"""Handle dependency analysis completion.
	Args:
		dependencies: Array of DependencyInfo objects"""
	
	# Additional processing for dependency analysis if needed
	pass

func _on_asset_dependency_error(asset_path: String, error_message: String) -> void:
	"""Handle asset dependency error.
	Args:
		asset_path: Path to problematic asset
		error_message: Error description"""
	
	push_warning("Asset dependency error: %s - %s" % [asset_path, error_message])

func _on_sexp_validation_error(expression: String, error_message: String) -> void:
	"""Handle SEXP validation error.
	Args:
		expression: SEXP expression with error
		error_message: Error description"""
	
	push_warning("SEXP validation error: %s - %s" % [expression, error_message])

func _on_manual_validation_requested() -> void:
	"""Handle manual validation request from UI."""
	
	if mission_validation_controller:
		# Clear cache to force fresh validation
		mission_validation_controller.clear_validation_cache()
		mission_validation_controller.validate_mission()

func _on_validation_item_selected(item_type: String, item_id: String) -> void:
	"""Handle validation item selection from dock.
	Args:
		item_type: Type of validation item
		item_id: Item identifier"""
	
	# Focus dependency graph on related item if possible
	if dependency_graph_view:
		match item_type:
			"object_error", "object_warning":
				dependency_graph_view.focus_on_node(item_id)
			"asset_error", "asset_warning":
				dependency_graph_view.focus_on_node(item_id)
	
	# Emit signal for other components to handle
	validation_item_focus_requested.emit(item_type, item_id)

func _on_dependency_node_selected(node_id: String, node_data: Dictionary) -> void:
	"""Handle dependency graph node selection.
	Args:
		node_id: Selected node ID
		node_data: Node data dictionary"""
	
	# Focus validation dock on related validation issues
	if validation_dock and node_data.has("type"):
		var item_type: String = ""
		match node_data.type:
			"dependency":
				if not node_data.get("is_valid", true):
					item_type = "asset_error"
			"object":
				if node_data.has("validation_result"):
					var result = node_data.validation_result
					if result.has_method("is_valid") and not result.is_valid():
						item_type = "object_error"
		
		if not item_type.is_empty():
			validation_dock.focus_on_item(item_type, node_id)

## Public API

func enable_auto_validation(enabled: bool) -> void:
	"""Enable or disable automatic validation.
	Args:
		enabled: Whether to enable auto validation"""
	
	auto_validation_enabled = enabled
	
	if mission_validation_controller:
		mission_validation_controller.set_real_time_validation(enabled)

func trigger_immediate_validation() -> void:
	"""Trigger immediate validation bypassing delay."""
	
	pending_validation = false
	validation_timer.stop()
	
	if mission_validation_controller:
		mission_validation_controller.validate_mission()

func get_validation_status() -> Dictionary:
	"""Get current validation status.
	Returns:
		Dictionary with current validation state"""
	
	if validation_dock:
		return validation_dock.get_validation_summary()
	else:
		return {"status": "unavailable", "message": "Validation dock not available"}

func focus_on_validation_issue(item_type: String, item_id: String) -> void:
	"""Focus UI on specific validation issue.
	Args:
		item_type: Type of validation issue
		item_id: Issue identifier"""
	
	# Focus validation dock
	if validation_dock:
		validation_dock.focus_on_item(item_type, item_id)
	
	# Focus dependency graph
	if dependency_graph_view:
		dependency_graph_view.focus_on_node(item_id)

func get_dependency_statistics() -> Dictionary:
	"""Get dependency graph statistics.
	Returns:
		Dictionary with dependency statistics"""
	
	if dependency_graph_view:
		return dependency_graph_view.get_graph_statistics()
	else:
		return {"error": "Dependency graph not available"}

func export_validation_report() -> String:
	"""Export comprehensive validation report.
	Returns:
		Formatted validation report string"""
	
	if mission_validation_controller:
		return mission_validation_controller.generate_validation_report()
	else:
		return "Validation system not available"

## Performance monitoring

func get_performance_metrics() -> Dictionary:
	"""Get validation performance metrics.
	Returns:
		Dictionary with performance data"""
	
	var metrics: Dictionary = {}
	
	if mission_validation_controller:
		metrics.merge(mission_validation_controller.get_validation_statistics())
	
	if dependency_graph_view:
		metrics["dependency_graph"] = dependency_graph_view.get_graph_statistics()
	
	metrics["auto_validation_enabled"] = auto_validation_enabled
	metrics["validation_delay"] = validation_delay_seconds
	metrics["pending_validation"] = pending_validation
	
	return metrics

func set_validation_delay(delay_seconds: float) -> void:
	"""Set validation delay for real-time updates.
	Args:
		delay_seconds: Delay in seconds"""
	
	validation_delay_seconds = max(0.1, delay_seconds)  # Minimum 100ms delay
	
	if validation_timer:
		validation_timer.wait_time = validation_delay_seconds