@tool
class_name ValidationDock
extends Control

## Real-time validation dock for GFRED2 mission editor
## Displays validation status, errors, warnings, and dependency information

signal validation_requested()
signal validation_item_selected(item_type: String, item_id: String)
signal validation_help_requested(help_topic: String)

## UI nodes - configured in scene, accessed via onready
@onready var validation_tree: Tree = $VBoxContainer/ValidationTree
@onready var status_bar: HBoxContainer = $VBoxContainer/StatusBar
@onready var status_label: Label = $VBoxContainer/StatusBar/StatusLabel
@onready var refresh_button: Button = $VBoxContainer/StatusBar/RefreshButton
@onready var settings_button: Button = $VBoxContainer/StatusBar/SettingsButton
@onready var validation_indicator: ValidationIndicator = $VBoxContainer/StatusBar/ValidationIndicator

## Validation state
var validation_controller: MissionValidationController
var current_validation_result: MissionValidationController.MissionValidationDetailedResult
var auto_refresh: bool = true

## Tree structure
var tree_root: TreeItem
var error_category: TreeItem
var warning_category: TreeItem
var asset_category: TreeItem
var sexp_category: TreeItem
var performance_category: TreeItem

func _ready() -> void:
	name = "ValidationDock"
	
	# Setup validation tree
	if validation_tree:
		validation_tree.item_selected.connect(_on_validation_item_selected)
		validation_tree.item_activated.connect(_on_validation_item_activated)
		validation_tree.set_column_titles_visible(true)
		validation_tree.set_column_title(0, "Validation Issues")
		validation_tree.set_column_title(1, "Type")
		validation_tree.set_column_title(2, "Status")
		validation_tree.columns = 3
		
		_setup_tree_structure()
	
	# Setup toolbar
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_requested)
		refresh_button.text = "Refresh"
		refresh_button.tooltip_text = "Refresh validation results"
	
	if settings_button:
		settings_button.pressed.connect(_on_settings_requested)
		settings_button.text = "Settings"
		settings_button.tooltip_text = "Configure validation settings"
	
	# Setup validation indicator
	if validation_indicator:
		validation_indicator.validation_help_requested.connect(_on_validation_help_requested)
		validation_indicator.validation_detail_requested.connect(_on_validation_details_requested)

func _setup_tree_structure() -> void:
	"""Setup the basic tree structure for validation results."""
	
	if not validation_tree:
		return
	
	validation_tree.clear()
	tree_root = validation_tree.create_item()
	tree_root.set_text(0, "Mission Validation")
	tree_root.set_icon(0, _get_tree_icon("mission"))
	
	# Create category items
	error_category = tree_root.create_child()
	error_category.set_text(0, "Errors")
	error_category.set_text(1, "Critical")
	error_category.set_icon(0, _get_tree_icon("error"))
	error_category.set_metadata(0, {"type": "category", "category": "errors"})
	
	warning_category = tree_root.create_child()
	warning_category.set_text(0, "Warnings")
	warning_category.set_text(1, "Advisory")
	warning_category.set_icon(0, _get_tree_icon("warning"))
	warning_category.set_metadata(0, {"type": "category", "category": "warnings"})
	
	asset_category = tree_root.create_child()
	asset_category.set_text(0, "Asset Issues")
	asset_category.set_text(1, "Dependencies")
	asset_category.set_icon(0, _get_tree_icon("asset"))
	asset_category.set_metadata(0, {"type": "category", "category": "assets"})
	
	sexp_category = tree_root.create_child()
	sexp_category.set_text(0, "SEXP Issues")
	sexp_category.set_text(1, "Logic")
	sexp_category.set_icon(0, _get_tree_icon("sexp"))
	sexp_category.set_metadata(0, {"type": "category", "category": "sexp"})
	
	performance_category = tree_root.create_child()
	performance_category.set_text(0, "Performance")
	performance_category.set_text(1, "Optimization")
	performance_category.set_icon(0, _get_tree_icon("performance"))
	performance_category.set_metadata(0, {"type": "category", "category": "performance"})

func set_validation_controller(controller: MissionValidationController) -> void:
	"""Set the validation controller and connect to its signals.
	Args:
		controller: MissionValidationController to connect to"""
	
	if validation_controller:
		# Disconnect old controller
		if validation_controller.validation_completed.is_connected(_on_validation_completed):
			validation_controller.validation_completed.disconnect(_on_validation_completed)
		if validation_controller.validation_started.is_connected(_on_validation_started):
			validation_controller.validation_started.disconnect(_on_validation_started)
		if validation_controller.validation_progress.is_connected(_on_validation_progress):
			validation_controller.validation_progress.disconnect(_on_validation_progress)
	
	validation_controller = controller
	
	if validation_controller:
		# Connect to new controller
		validation_controller.validation_completed.connect(_on_validation_completed)
		validation_controller.validation_started.connect(_on_validation_started)
		validation_controller.validation_progress.connect(_on_validation_progress)
		
		# Get current validation result if available
		var current_result: MissionValidationController.MissionValidationDetailedResult = validation_controller.get_current_validation_result()
		if current_result:
			_update_validation_display(current_result)

func _update_validation_display(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Update the validation display with new results.
	Args:
		result: Validation result to display"""
	
	current_validation_result = result
	
	# Clear previous results
	_clear_validation_tree()
	
	# Update overall status
	_update_status_display(result)
	
	# Populate validation tree
	_populate_validation_tree(result)
	
	# Update validation indicator
	if validation_indicator:
		validation_indicator.set_validation_result(result.overall_result)

func _clear_validation_tree() -> void:
	"""Clear all validation items from the tree while keeping category structure."""
	
	if not validation_tree:
		return
	
	# Remove all children from category items
	var categories: Array[TreeItem] = [error_category, warning_category, asset_category, sexp_category, performance_category]
	
	for category in categories:
		if not category:
			continue
		
		# Remove all child items
		var child: TreeItem = category.get_first_child()
		while child:
			var next_child: TreeItem = child.get_next_in_tree()
			child.free()
			child = next_child

func _update_status_display(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Update status bar with validation summary.
	Args:
		result: Validation result to summarize"""
	
	if not status_label:
		return
	
	var stats: Dictionary = result.statistics
	var error_count: int = result.get_total_errors()
	var warning_count: int = result.get_total_warnings()
	var validation_time: int = stats.get("validation_time_ms", 0)
	
	var status_text: String = ""
	
	if error_count > 0:
		status_text = "❌ %d errors" % error_count
	elif warning_count > 0:
		status_text = "⚠️ %d warnings" % warning_count
	else:
		status_text = "✅ Validation passed"
	
	status_text += " (%dms)" % validation_time
	
	status_label.text = status_text

func _populate_validation_tree(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Populate validation tree with result details.
	Args:
		result: Validation result to display"""
	
	# Add overall mission errors/warnings
	_add_overall_issues(result.overall_result)
	
	# Add object validation issues
	_add_object_issues(result.object_results)
	
	# Add asset validation issues
	_add_asset_issues(result.asset_results)
	
	# Add SEXP validation issues
	_add_sexp_issues(result.sexp_results)
	
	# Add performance issues
	_add_performance_issues(result)
	
	# Update category counts
	_update_category_counts()
	
	# Expand categories with issues
	_expand_categories_with_issues()

func _add_overall_issues(overall_result: MissionValidationResult) -> void:
	"""Add overall mission validation issues to tree.
	Args:
		overall_result: Overall validation result"""
	
	if not overall_result:
		return
	
	# Add errors
	if overall_result.has_method("get_errors"):
		var errors: Array[String] = overall_result.get_errors()
		for error in errors:
			_add_validation_item(error_category, "Mission", error, "error", {"type": "mission_error", "message": error})
	
	# Add warnings
	if overall_result.has_method("get_warnings"):
		var warnings: Array[String] = overall_result.get_warnings()
		for warning in warnings:
			_add_validation_item(warning_category, "Mission", warning, "warning", {"type": "mission_warning", "message": warning})

func _add_object_issues(object_results: Dictionary) -> void:
	"""Add object validation issues to tree.
	Args:
		object_results: Dictionary of object validation results"""
	
	for object_id in object_results.keys():
		var result = object_results[object_id]
		if not result or not result.has_method("is_valid"):
			continue
		
		if not result.is_valid():
			# Add object errors
			if result.has_method("get_errors"):
				var errors: Array[String] = result.get_errors()
				for error in errors:
					_add_validation_item(error_category, object_id, error, "error", {"type": "object_error", "object_id": object_id, "message": error})
		
		# Add object warnings
		if result.has_method("get_warnings"):
			var warnings: Array[String] = result.get_warnings()
			for warning in warnings:
				_add_validation_item(warning_category, object_id, warning, "warning", {"type": "object_warning", "object_id": object_id, "message": warning})

func _add_asset_issues(asset_results: Dictionary) -> void:
	"""Add asset validation issues to tree.
	Args:
		asset_results: Dictionary of asset validation results"""
	
	for asset_path in asset_results.keys():
		var result = asset_results[asset_path]
		if not result or not result.has_method("is_valid"):
			continue
		
		var asset_name: String = asset_path.get_file()
		
		if not result.is_valid():
			# Add asset errors
			if result.has_method("get_errors"):
				var errors: Array[String] = result.get_errors()
				for error in errors:
					_add_validation_item(asset_category, asset_name, error, "error", {"type": "asset_error", "asset_path": asset_path, "message": error})
		
		# Add asset warnings
		if result.has_method("get_warnings"):
			var warnings: Array[String] = result.get_warnings()
			for warning in warnings:
				_add_validation_item(asset_category, asset_name, warning, "warning", {"type": "asset_warning", "asset_path": asset_path, "message": warning})

func _add_sexp_issues(sexp_results: Dictionary) -> void:
	"""Add SEXP validation issues to tree.
	Args:
		sexp_results: Dictionary of SEXP validation results"""
	
	for sexp_id in sexp_results.keys():
		var result = sexp_results[sexp_id]
		if not result or not result.has_method("is_valid"):
			continue
		
		if not result.is_valid():
			# Add SEXP errors
			if result.has_method("get_errors"):
				var errors: Array[String] = result.get_errors()
				for error in errors:
					_add_validation_item(sexp_category, sexp_id, error, "error", {"type": "sexp_error", "sexp_id": sexp_id, "message": error})
		
		# Add SEXP warnings
		if result.has_method("get_warnings"):
			var warnings: Array[String] = result.get_warnings()
			for warning in warnings:
				_add_validation_item(sexp_category, sexp_id, warning, "warning", {"type": "sexp_warning", "sexp_id": sexp_id, "message": warning})

func _add_performance_issues(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Add performance-related issues to tree.
	Args:
		result: Full validation result"""
	
	var stats: Dictionary = result.statistics
	
	# Check validation time performance
	var validation_time: int = stats.get("validation_time_ms", 0)
	if validation_time > 100:  # Performance requirement: < 100ms
		var message: String = "Validation took %dms (should be < 100ms)" % validation_time
		_add_validation_item(performance_category, "Validation", message, "warning", {"type": "performance_warning", "metric": "validation_time", "value": validation_time})
	
	# Check mission size performance
	var ship_count: int = stats.get("total_ships", 0)
	if ship_count > 500:
		var message: String = "Large mission with %d ships - may impact performance" % ship_count
		var severity: String = "warning" if ship_count <= 1000 else "error"
		_add_validation_item(performance_category, "Mission Size", message, severity, {"type": "performance_issue", "metric": "ship_count", "value": ship_count})

func _add_validation_item(parent: TreeItem, source: String, message: String, severity: String, metadata: Dictionary) -> TreeItem:
	"""Add a validation item to the tree.
	Args:
		parent: Parent tree item
		source: Source of the issue
		message: Issue description
		severity: Severity level (error/warning)
		metadata: Additional metadata
	Returns:
		Created TreeItem"""
	
	if not parent:
		return null
	
	var item: TreeItem = parent.create_child()
	item.set_text(0, "%s: %s" % [source, message])
	item.set_text(1, source)
	item.set_text(2, severity.capitalize())
	
	# Set icon based on severity
	var icon: Texture2D = _get_tree_icon(severity)
	if icon:
		item.set_icon(0, icon)
	
	# Set color based on severity
	var color: Color = Color.RED if severity == "error" else Color.ORANGE
	item.set_custom_color(2, color)
	
	# Store metadata
	item.set_metadata(0, metadata)
	
	return item

func _update_category_counts() -> void:
	"""Update category labels with issue counts."""
	
	var categories: Array[Dictionary] = [
		{"item": error_category, "name": "Errors"},
		{"item": warning_category, "name": "Warnings"},
		{"item": asset_category, "name": "Asset Issues"},
		{"item": sexp_category, "name": "SEXP Issues"},
		{"item": performance_category, "name": "Performance"}
	]
	
	for category_info in categories:
		var category_item: TreeItem = category_info.item
		var category_name: String = category_info.name
		
		if not category_item:
			continue
		
		var child_count: int = category_item.get_child_count()
		category_item.set_text(0, "%s (%d)" % [category_name, child_count])

func _expand_categories_with_issues() -> void:
	"""Expand categories that have validation issues."""
	
	var categories: Array[TreeItem] = [error_category, warning_category, asset_category, sexp_category, performance_category]
	
	for category in categories:
		if not category:
			continue
		
		if category.get_child_count() > 0:
			category.set_collapsed(false)
		else:
			category.set_collapsed(true)
	
	# Always expand root
	if tree_root:
		tree_root.set_collapsed(false)

func _get_tree_icon(icon_type: String) -> Texture2D:
	"""Get appropriate icon for tree item.
	Args:
		icon_type: Type of icon to get
	Returns:
		Icon texture"""
	
	var editor_theme: Theme = EditorInterface.get_editor_theme() if Engine.is_editor_hint() else null
	
	if editor_theme:
		match icon_type:
			"mission":
				return editor_theme.get_icon("PackedScene", "EditorIcons")
			"error":
				return editor_theme.get_icon("StatusError", "EditorIcons")
			"warning":
				return editor_theme.get_icon("StatusWarning", "EditorIcons")
			"asset":
				return editor_theme.get_icon("ResourcePreloader", "EditorIcons")
			"sexp":
				return editor_theme.get_icon("Script", "EditorIcons")
			"performance":
				return editor_theme.get_icon("SpeedHigh", "EditorIcons")
	
	return null

## Event handlers

func _on_validation_completed(result: MissionValidationController.MissionValidationDetailedResult) -> void:
	"""Handle validation completion.
	Args:
		result: Completed validation result"""
	
	_update_validation_display(result)

func _on_validation_started() -> void:
	"""Handle validation start."""
	
	if validation_indicator:
		validation_indicator.set_validation_status(ValidationIndicator.IndicatorState.VALIDATING)
	
	if status_label:
		status_label.text = "Validating mission..."

func _on_validation_progress(percentage: float, current_check: String) -> void:
	"""Handle validation progress update.
	Args:
		percentage: Progress percentage
		current_check: Current validation phase"""
	
	if status_label:
		status_label.text = "Validating: %s (%.0f%%)" % [current_check, percentage]

func _on_validation_item_selected() -> void:
	"""Handle selection of validation item in tree."""
	
	var selected: TreeItem = validation_tree.get_selected()
	if not selected:
		return
	
	var metadata: Dictionary = selected.get_metadata(0)
	if metadata.is_empty():
		return
	
	var item_type: String = metadata.get("type", "")
	var item_id: String = ""
	
	match item_type:
		"object_error", "object_warning":
			item_id = metadata.get("object_id", "")
		"asset_error", "asset_warning":
			item_id = metadata.get("asset_path", "")
		"sexp_error", "sexp_warning":
			item_id = metadata.get("sexp_id", "")
	
	if not item_id.is_empty():
		validation_item_selected.emit(item_type, item_id)

func _on_validation_item_activated() -> void:
	"""Handle activation (double-click) of validation item."""
	
	var selected: TreeItem = validation_tree.get_selected()
	if not selected:
		return
	
	var metadata: Dictionary = selected.get_metadata(0)
	if metadata.is_empty():
		return
	
	# For now, same as selection - can be enhanced for different behavior
	_on_validation_item_selected()

func _on_refresh_requested() -> void:
	"""Handle refresh button press."""
	
	validation_requested.emit()

func _on_settings_requested() -> void:
	"""Handle settings button press."""
	
	validation_help_requested.emit("validation_settings")

func _on_validation_help_requested(help_topic: String) -> void:
	"""Handle validation help request from indicator.
	Args:
		help_topic: Help topic requested"""
	
	validation_help_requested.emit(help_topic)

func _on_validation_details_requested(result: ValidationResult) -> void:
	"""Handle validation details request from indicator.
	Args:
		result: ValidationResult to show details for"""
	
	# Focus on the tree to show details
	if validation_tree:
		validation_tree.grab_focus()

## Public API

func refresh_validation() -> void:
	"""Request validation refresh."""
	
	if validation_controller:
		validation_controller.validate_mission()

func focus_on_item(item_type: String, item_id: String) -> void:
	"""Focus on specific validation item.
	Args:
		item_type: Type of item to focus
		item_id: ID of item to focus"""
	
	if not validation_tree:
		return
	
	# Search through tree items to find matching item
	_search_and_select_item(tree_root, item_type, item_id)

func _search_and_select_item(item: TreeItem, target_type: String, target_id: String) -> bool:
	"""Recursively search and select matching tree item.
	Args:
		item: TreeItem to search
		target_type: Type to match
		target_id: ID to match
	Returns:
		True if item was found and selected"""
	
	if not item:
		return false
	
	# Check current item
	var metadata: Dictionary = item.get_metadata(0)
	if metadata.has("type") and metadata.type == target_type:
		var item_id: String = ""
		match target_type:
			"object_error", "object_warning":
				item_id = metadata.get("object_id", "")
			"asset_error", "asset_warning":
				item_id = metadata.get("asset_path", "")
			"sexp_error", "sexp_warning":
				item_id = metadata.get("sexp_id", "")
		
		if item_id == target_id:
			validation_tree.set_selected(item, 0)
			validation_tree.ensure_cursor_is_visible()
			return true
	
	# Search children
	var child: TreeItem = item.get_first_child()
	while child:
		if _search_and_select_item(child, target_type, target_id):
			return true
		child = child.get_next_in_tree()
	
	return false

func get_validation_summary() -> Dictionary:
	"""Get summary of current validation state.
	Returns:
		Dictionary with validation summary"""
	
	if not current_validation_result:
		return {"status": "no_validation", "message": "No validation performed"}
	
	return {
		"status": "valid" if current_validation_result.is_valid() else "invalid",
		"error_count": current_validation_result.get_total_errors(),
		"warning_count": current_validation_result.get_total_warnings(),
		"validation_time": current_validation_result.validation_time_ms,
		"statistics": current_validation_result.statistics
	}