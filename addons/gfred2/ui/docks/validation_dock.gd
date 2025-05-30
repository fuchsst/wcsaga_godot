@tool
class_name ValidationDock
extends Control

## Main validation dock for GFRED2 mission editor
## Provides comprehensive validation results display with dependency graph
## Integrates with MissionValidationController for real-time validation feedback

signal validation_item_selected(validation_result: ValidationResult, object_id: String)
signal fix_suggestion_applied(object_id: String, property: String, suggested_value: Variant)
signal dependency_view_requested(dependency_info: MissionValidationController.DependencyInfo)

## UI components
@onready var main_container: VBoxContainer
@onready var validation_summary: ValidationSummaryPanel
@onready var validation_tree: ValidationResultsTree
@onready var dependency_graph: DependencyGraphView
@onready var toolbar: HBoxContainer
@onready var tab_container: TabContainer

## Validation controller reference
var validation_controller: MissionValidationController
var current_validation_result: MissionValidationController.MissionValidationDetailedResult

## Configuration
@export var auto_expand_errors: bool = true
@export var show_performance_stats: bool = true
@export var enable_fix_suggestions: bool = true
@export var max_suggestions_per_item: int = 3

class ValidationSummaryPanel:
	extends Panel
	
	var error_count_label: Label
	var warning_count_label: Label
	var validation_time_label: Label
	var overall_status_indicator: ValidationIndicator
	var statistics_button: Button
	
	func _init() -> void:
		custom_minimum_size = Vector2(0, 80)
		
		var hbox: HBoxContainer = HBoxContainer.new()
		add_child(hbox)
		
		# Overall status indicator
		overall_status_indicator = ValidationIndicator.new()
		overall_status_indicator.indicator_size = Vector2(24, 24)
		overall_status_indicator.show_text_label = false
		hbox.add_child(overall_status_indicator)
		
		# Status labels
		var status_vbox: VBoxContainer = VBoxContainer.new()
		hbox.add_child(status_vbox)
		
		error_count_label = Label.new()
		error_count_label.text = "Errors: 0"
		status_vbox.add_child(error_count_label)
		
		warning_count_label = Label.new()
		warning_count_label.text = "Warnings: 0"
		status_vbox.add_child(warning_count_label)
		
		hbox.add_child(VSeparator.new())
		
		# Performance info
		var perf_vbox: VBoxContainer = VBoxContainer.new()
		hbox.add_child(perf_vbox)
		
		validation_time_label = Label.new()
		validation_time_label.text = "Validation: --ms"
		perf_vbox.add_child(validation_time_label)
		
		# Statistics button
		statistics_button = Button.new()
		statistics_button.text = "Statistics"
		statistics_button.pressed.connect(_on_statistics_pressed)
		hbox.add_child(statistics_button)
	
	func update_summary(result: MissionValidationController.MissionValidationDetailedResult) -> void:
		if not result:
			error_count_label.text = "Errors: --"
			warning_count_label.text = "Warnings: --"
			validation_time_label.text = "Validation: --ms"
			overall_status_indicator.set_unknown()
			return
		
		var total_errors: int = result.get_total_errors()
		var total_warnings: int = result.get_total_warnings()
		
		error_count_label.text = "Errors: %d" % total_errors
		warning_count_label.text = "Warnings: %d" % total_warnings
		validation_time_label.text = "Validation: %dms" % result.validation_time_ms
		
		# Update overall indicator
		if total_errors > 0:
			overall_status_indicator.set_error(result.overall_result)
		elif total_warnings > 0:
			overall_status_indicator.set_warning(result.overall_result)
		else:
			overall_status_indicator.set_valid(result.overall_result)
	
	func _on_statistics_pressed() -> void:
		# TODO: Show detailed statistics dialog
		pass

class ValidationResultsTree:
	extends Tree
	
	var dock_parent: ValidationDock
	var root_item: TreeItem
	
	func _init(parent_dock: ValidationDock) -> void:
		dock_parent = parent_dock
		
		# Configure tree
		hide_root = false
		columns = 3
		set_column_title(0, "Item")
		set_column_title(1, "Type") 
		set_column_title(2, "Message")
		
		set_column_expand(0, true)
		set_column_expand(1, false)
		set_column_expand(2, true)
		
		set_column_custom_minimum_width(1, 80)
		
		# Connect signals
		item_selected.connect(_on_item_selected)
		button_clicked.connect(_on_button_clicked)
	
	func populate_results(result: MissionValidationController.MissionValidationDetailedResult) -> void:
		clear()
		
		if not result:
			return
		
		root_item = create_item()
		root_item.set_text(0, "Mission Validation Results")
		root_item.set_icon(0, get_theme_icon("Script", "EditorIcons"))
		
		# Overall mission issues
		if not result.overall_result.is_valid() or result.overall_result.has_warnings():
			_add_validation_category("Mission", result.overall_result, root_item)
		
		# Object validation results
		if not result.object_results.is_empty():
			var objects_category: TreeItem = create_item(root_item)
			objects_category.set_text(0, "Mission Objects")
			objects_category.set_icon(0, get_theme_icon("Node3D", "EditorIcons"))
			
			for object_id in result.object_results.keys():
				var object_result: ValidationResult = result.object_results[object_id]
				if not object_result.is_valid() or object_result.has_warnings():
					_add_validation_category(object_id, object_result, objects_category)
		
		# Asset validation results
		if not result.asset_results.is_empty():
			var assets_category: TreeItem = create_item(root_item)
			assets_category.set_text(0, "Asset Dependencies")
			assets_category.set_icon(0, get_theme_icon("FileList", "EditorIcons"))
			
			for asset_path in result.asset_results.keys():
				var asset_result: ValidationResult = result.asset_results[asset_path]
				if not asset_result.is_valid() or asset_result.has_warnings():
					var asset_name: String = asset_path.get_file()
					_add_validation_category(asset_name, asset_result, assets_category)
		
		# SEXP validation results
		if not result.sexp_results.is_empty():
			var sexp_category: TreeItem = create_item(root_item)
			sexp_category.set_text(0, "SEXP Expressions")
			sexp_category.set_icon(0, get_theme_icon("CodeEdit", "EditorIcons"))
			
			for sexp_id in result.sexp_results.keys():
				var sexp_result: ValidationResult = result.sexp_results[sexp_id]
				if not sexp_result.is_valid() or sexp_result.has_warnings():
					_add_validation_category(sexp_id, sexp_result, sexp_category)
		
		# Auto-expand error categories
		if dock_parent.auto_expand_errors:
			_expand_error_categories(root_item)
	
	func _add_validation_category(name: String, result: ValidationResult, parent: TreeItem) -> void:
		var category_item: TreeItem = create_item(parent)
		category_item.set_text(0, name)
		category_item.set_metadata(0, {"type": "category", "result": result, "object_id": name})
		
		# Set category icon based on severity
		if not result.is_valid():
			category_item.set_icon(0, get_theme_icon("StatusError", "EditorIcons"))
		elif result.has_warnings():
			category_item.set_icon(0, get_theme_icon("StatusWarning", "EditorIcons"))
		else:
			category_item.set_icon(0, get_theme_icon("StatusSuccess", "EditorIcons"))
		
		# Add errors
		for error in result.get_errors():
			var error_item: TreeItem = create_item(category_item)
			error_item.set_text(0, "")
			error_item.set_text(1, "ERROR")
			error_item.set_text(2, error)
			error_item.set_icon(1, get_theme_icon("StatusError", "EditorIcons"))
			error_item.set_custom_color(1, Color.RED)
			error_item.set_metadata(0, {"type": "error", "message": error, "object_id": name})
			
			# Add fix suggestion button if available
			if dock_parent.enable_fix_suggestions:
				_add_fix_suggestions(error_item, name, error)
		
		# Add warnings
		for warning in result.get_warnings():
			var warning_item: TreeItem = create_item(category_item)
			warning_item.set_text(0, "")
			warning_item.set_text(1, "WARNING")
			warning_item.set_text(2, warning)
			warning_item.set_icon(1, get_theme_icon("StatusWarning", "EditorIcons"))
			warning_item.set_custom_color(1, Color.YELLOW)
			warning_item.set_metadata(0, {"type": "warning", "message": warning, "object_id": name})
			
			# Add fix suggestion button if available
			if dock_parent.enable_fix_suggestions:
				_add_fix_suggestions(warning_item, name, warning)
	
	func _add_fix_suggestions(item: TreeItem, object_id: String, message: String) -> void:
		# TODO: Implement intelligent fix suggestions based on error type
		# For now, add a generic "Fix" button for demonstration
		
		var suggestions: Array[String] = _generate_fix_suggestions(message)
		
		if not suggestions.is_empty():
			item.add_button(2, get_theme_icon("Tools", "EditorIcons"), 0, false, "Apply Fix")
			item.set_button_tooltip_text(2, 0, "Click to apply suggested fix")
	
	func _generate_fix_suggestions(error_message: String) -> Array[String]:
		var suggestions: Array[String] = []
		
		# Simple pattern matching for common errors
		if "empty" in error_message.to_lower():
			suggestions.append("Set default value")
		elif "invalid" in error_message.to_lower():
			suggestions.append("Reset to valid range")
		elif "missing" in error_message.to_lower():
			suggestions.append("Add required reference")
		
		return suggestions
	
	func _expand_error_categories(item: TreeItem) -> void:
		if item == null:
			return
		
		var metadata: Dictionary = item.get_metadata(0)
		if metadata.has("type") and metadata.type == "category":
			var result: ValidationResult = metadata.result
			if not result.is_valid():
				item.set_collapsed(false)
		
		# Recursively expand children
		for child in item.get_children():
			_expand_error_categories(child)
	
	func _on_item_selected() -> void:
		var selected: TreeItem = get_selected()
		if not selected:
			return
		
		var metadata: Dictionary = selected.get_metadata(0)
		if metadata.has("result") and metadata.has("object_id"):
			var result: ValidationResult = metadata.result
			var object_id: String = metadata.object_id
			dock_parent.validation_item_selected.emit(result, object_id)
	
	func _on_button_clicked(item: TreeItem, column: int, id: int, mouse_button: int) -> void:
		if mouse_button != MOUSE_BUTTON_LEFT:
			return
		
		var metadata: Dictionary = item.get_metadata(0)
		if metadata.has("object_id") and metadata.has("message"):
			var object_id: String = metadata.object_id
			var message: String = metadata.message
			
			# Apply fix suggestion
			_apply_fix_suggestion(object_id, message)
	
	func _apply_fix_suggestion(object_id: String, error_message: String) -> void:
		# TODO: Implement intelligent fix application
		# For now, emit signal for parent to handle
		dock_parent.fix_suggestion_applied.emit(object_id, "", null)

func _init() -> void:
	name = "ValidationDock"
	
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the validation dock UI."""
	
	# Main container
	main_container = VBoxContainer.new()
	add_child(main_container)
	
	# Toolbar
	toolbar = HBoxContainer.new()
	main_container.add_child(toolbar)
	
	var validate_button: Button = Button.new()
	validate_button.text = "Validate Mission"
	validate_button.pressed.connect(_on_validate_pressed)
	toolbar.add_child(validate_button)
	
	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_button)
	
	toolbar.add_child(VSeparator.new())
	
	var auto_validate_check: CheckBox = CheckBox.new()
	auto_validate_check.text = "Auto-validate"
	auto_validate_check.button_pressed = true
	auto_validate_check.toggled.connect(_on_auto_validate_toggled)
	toolbar.add_child(auto_validate_check)
	
	# Tab container for different views
	tab_container = TabContainer.new()
	main_container.add_child(tab_container)
	
	# Results tab
	var results_tab: VBoxContainer = VBoxContainer.new()
	results_tab.name = "Results"
	tab_container.add_child(results_tab)
	
	# Validation summary
	validation_summary = ValidationSummaryPanel.new()
	results_tab.add_child(validation_summary)
	
	# Validation results tree
	validation_tree = ValidationResultsTree.new(self)
	results_tab.add_child(validation_tree)
	
	# Dependencies tab
	var dependencies_tab: VBoxContainer = VBoxContainer.new()
	dependencies_tab.name = "Dependencies"
	tab_container.add_child(dependencies_tab)
	
	# Dependency graph
	dependency_graph = DependencyGraphView.new()
	dependency_graph.custom_minimum_size = Vector2(400, 300)
	dependencies_tab.add_child(dependency_graph)
	
	# Connect dependency graph signals
	dependency_graph.node_selected.connect(_on_dependency_node_selected)

func set_validation_controller(controller: MissionValidationController) -> void:
	"""Set the validation controller reference.
	Args:
		controller: MissionValidationController instance"""
	
	if validation_controller:
		# Disconnect old signals
		if validation_controller.validation_completed.is_connected(_on_validation_completed):
			validation_controller.validation_completed.disconnect(_on_validation_completed)
		if validation_controller.validation_progress.is_connected(_on_validation_progress):
			validation_controller.validation_progress.disconnect(_on_validation_progress)
	
	validation_controller = controller
	
	if validation_controller:
		# Connect new signals
		validation_controller.validation_completed.connect(_on_validation_completed)
		validation_controller.validation_progress.connect(_on_validation_progress)
		validation_controller.dependency_analysis_completed.connect(_on_dependency_analysis_completed)

func _on_validation_completed(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Handle validation completion.
	Args:
		result: Validation result"""
	
	current_validation_result = result
	
	# Update summary
	validation_summary.update_summary(result)
	
	# Update results tree
	validation_tree.populate_results(result)
	
	# Show appropriate tab based on results
	if result.get_total_errors() > 0 or result.get_total_warnings() > 0:
		tab_container.current_tab = 0  # Results tab
	
	# Update validation indicators throughout the UI
	_update_validation_indicators()

func _on_validation_progress(percentage: float, current_check: String) -> void:
	"""Handle validation progress updates.
	Args:
		percentage: Progress percentage (0-100)
		current_check: Description of current validation step"""
	
	# TODO: Show progress bar during validation
	pass

func _on_dependency_analysis_completed(dependencies: Array[MissionValidationController.DependencyInfo]) -> void:
	"""Handle dependency analysis completion.
	Args:
		dependencies: Array of dependency information"""
	
	if validation_controller and validation_controller.mission_data:
		dependency_graph.set_dependency_graph(
			validation_controller.get_dependency_graph(),
			validation_controller.mission_data
		)

func _update_validation_indicators() -> void:
	"""Update validation indicators throughout the editor UI."""
	
	# TODO: Find and update ValidationIndicator components in property editors
	# This would integrate with the property inspector dock and other UI components
	pass

func _on_dependency_node_selected(node_id: String, dependency_info: MissionValidationController.DependencyInfo) -> void:
	"""Handle dependency graph node selection.
	Args:
		node_id: Selected node ID
		dependency_info: Associated dependency information"""
	
	if dependency_info:
		dependency_view_requested.emit(dependency_info)

func _on_validate_pressed() -> void:
	"""Handle manual validation request."""
	
	if validation_controller:
		validation_controller.validate_mission()

func _on_refresh_pressed() -> void:
	"""Handle refresh request."""
	
	if current_validation_result:
		validation_summary.update_summary(current_validation_result)
		validation_tree.populate_results(current_validation_result)

func _on_auto_validate_toggled(enabled: bool) -> void:
	"""Handle auto-validation toggle.
	Args:
		enabled: Whether auto-validation is enabled"""
	
	if validation_controller:
		validation_controller.set_real_time_validation(enabled)

## Public API

func trigger_validation() -> void:
	"""Manually trigger mission validation."""
	_on_validate_pressed()

func get_current_result() -> MissionValidationController.MissionValidationDetailedResult:
	"""Get the current validation result.
	Returns:
		Current validation result or null"""
	
	return current_validation_result

func show_dependency_graph() -> void:
	"""Switch to dependency graph view."""
	tab_container.current_tab = 1

func show_validation_results() -> void:
	"""Switch to validation results view."""
	tab_container.current_tab = 0

func highlight_validation_issue(object_id: String) -> void:
	"""Highlight a specific validation issue in the UI.
	Args:
		object_id: Object ID to highlight"""
	
	# TODO: Implement issue highlighting in results tree
	pass

func clear_validation_results() -> void:
	"""Clear all validation results from the display."""
	
	current_validation_result = null
	validation_summary.update_summary(null)
	validation_tree.clear()

func export_validation_report() -> String:
	"""Export current validation results as a text report.
	Returns:
		Formatted validation report"""
	
	if validation_controller:
		return validation_controller.generate_validation_report()
	else:
		return "No validation data available"