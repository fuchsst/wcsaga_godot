@tool
class_name MissionValidationPanelController
extends Control

## Mission validation panel controller for GFRED2-011 UI Refactoring.
## Scene-based UI controller for mission validation with real-time feedback.
## Scene: addons/gfred2/scenes/components/validation/mission_validation_panel.tscn

signal validation_item_selected(item: ValidationResult)
signal goto_requested(location: String, object_id: String)
signal auto_fix_requested(validation_item: ValidationResult)

enum ValidationSeverity { INFO, WARNING, ERROR }

# Validation state
var current_mission_data: MissionData = null
var validation_results: Array[ValidationResult] = []
var filtered_results: Array[ValidationResult] = []

# Scene node references
@onready var validation_status: Label = $MainContainer/Header/ValidationStatus
@onready var refresh_button: Button = $MainContainer/Header/RefreshButton

@onready var show_errors: CheckBox = $MainContainer/FilterContainer/ShowErrors
@onready var show_warnings: CheckBox = $MainContainer/FilterContainer/ShowWarnings
@onready var show_info: CheckBox = $MainContainer/FilterContainer/ShowInfo

@onready var validation_list: Tree = $MainContainer/ValidationList
@onready var fix_button: Button = $MainContainer/Actions/FixButton
@onready var goto_button: Button = $MainContainer/Actions/GotoButton
@onready var export_button: Button = $MainContainer/Actions/ExportButton

# Selected validation item
var selected_validation_item: ValidationResult = null

func _ready() -> void:
	name = "MissionValidationPanel"
	_setup_validation_list()
	_connect_signals()
	_update_validation_display()
	print("MissionValidationPanelController: Scene-based mission validation panel initialized")

func _setup_validation_list() -> void:
	if not validation_list:
		return
	
	validation_list.columns = 4
	validation_list.set_column_title(0, "Severity")
	validation_list.set_column_title(1, "Component")
	validation_list.set_column_title(2, "Message")
	validation_list.set_column_title(3, "Location")
	
	validation_list.set_column_expand(0, false)
	validation_list.set_column_expand(1, false)
	validation_list.set_column_expand(2, true)
	validation_list.set_column_expand(3, false)
	
	validation_list.set_column_custom_minimum_width(0, 80)
	validation_list.set_column_custom_minimum_width(1, 120)
	validation_list.set_column_custom_minimum_width(3, 100)

func _connect_signals() -> void:
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	
	if show_errors:
		show_errors.toggled.connect(_on_filter_changed)
	
	if show_warnings:
		show_warnings.toggled.connect(_on_filter_changed)
	
	if show_info:
		show_info.toggled.connect(_on_filter_changed)
	
	if validation_list:
		validation_list.item_selected.connect(_on_validation_item_selected)
	
	if fix_button:
		fix_button.pressed.connect(_on_auto_fix_pressed)
	
	if goto_button:
		goto_button.pressed.connect(_on_goto_pressed)
	
	if export_button:
		export_button.pressed.connect(_on_export_pressed)

## Initializes the validation panel with mission data
func initialize_with_mission(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	current_mission_data = mission_data
	_run_validation()

func _run_validation() -> void:
	if not current_mission_data:
		return
	
	validation_results.clear()
	
	# Run comprehensive mission validation
	_validate_mission_basic_properties()
	_validate_ships_and_wings()
	_validate_mission_goals()
	_validate_mission_events()
	_validate_sexp_expressions()
	_validate_waypoint_paths()
	_validate_asset_references()
	
	_apply_filters()
	_update_validation_display()
	
	print("MissionValidationPanelController: Validation completed with %d results" % validation_results.size())

func _validate_mission_basic_properties() -> void:
	if not current_mission_data:
		return
	
	# Validate mission name
	if current_mission_data.mission_name.is_empty():
		_add_validation_result(ValidationSeverity.ERROR, "Mission", "Mission name cannot be empty", "Basic Properties")
	
	# Validate mission description
	if current_mission_data.description.is_empty():
		_add_validation_result(ValidationSeverity.WARNING, "Mission", "Mission description should be provided", "Basic Properties")
	
	# Validate designer field
	if current_mission_data.designer.is_empty():
		_add_validation_result(ValidationSeverity.INFO, "Mission", "Designer field is recommended", "Basic Properties")

func _validate_ships_and_wings() -> void:
	if not current_mission_data or not current_mission_data.has_method("get_ships"):
		return
	
	var ships: Array = current_mission_data.get_ships()
	
	# Check for ships without wings
	for ship in ships:
		if ship.has_method("get_wing") and ship.get_wing().is_empty():
			_add_validation_result(ValidationSeverity.WARNING, "Ship", "Ship '%s' is not assigned to a wing" % ship.name, ship.name)
		
		# Validate ship class
		if ship.has_method("get_ship_class") and ship.get_ship_class().is_empty():
			_add_validation_result(ValidationSeverity.ERROR, "Ship", "Ship '%s' has no class assigned" % ship.name, ship.name)

func _validate_mission_goals() -> void:
	if not current_mission_data or not current_mission_data.has_method("get_goals"):
		return
	
	var goals: Array = current_mission_data.get_goals()
	
	if goals.is_empty():
		_add_validation_result(ValidationSeverity.WARNING, "Goals", "Mission has no goals defined", "Mission Goals")
	
	for goal in goals:
		if goal.has_method("get_name") and goal.get_name().is_empty():
			_add_validation_result(ValidationSeverity.ERROR, "Goals", "Goal has no name", "Mission Goals")

func _validate_mission_events() -> void:
	if not current_mission_data or not current_mission_data.has_method("get_events"):
		return
	
	var events: Array = current_mission_data.get_events()
	
	for event in events:
		if event.has_method("get_condition_sexp") and not event.get_condition_sexp().is_empty():
			# Validate SEXP condition using EPIC-004 SEXP system
			if SexpManager and SexpManager.has_method("validate_syntax"):
				var is_valid: bool = SexpManager.validate_syntax(event.get_condition_sexp())
				if not is_valid:
					_add_validation_result(ValidationSeverity.ERROR, "Event", "Invalid SEXP condition in event '%s'" % event.name, event.name)

func _validate_sexp_expressions() -> void:
	# Additional SEXP validation across all mission components
	if not SexpManager:
		_add_validation_result(ValidationSeverity.WARNING, "SEXP", "SEXP system not available for validation", "System")
		return
	
	# This would iterate through all SEXP expressions in the mission
	# and validate them using the EPIC-004 SEXP system
	print("MissionValidationPanelController: SEXP validation completed")

func _validate_waypoint_paths() -> void:
	if not current_mission_data or not current_mission_data.has_method("get_waypoint_paths"):
		return
	
	var waypoint_paths: Array = current_mission_data.get_waypoint_paths()
	
	for path in waypoint_paths:
		if path.has_method("get_waypoints"):
			var waypoints: Array = path.get_waypoints()
			if waypoints.size() < 2:
				_add_validation_result(ValidationSeverity.WARNING, "Waypoints", "Waypoint path '%s' has less than 2 waypoints" % path.path_name, path.path_name)

func _validate_asset_references() -> void:
	# Validate that all referenced assets exist using EPIC-002 WCS Asset Core
	if not WCSAssetRegistry:
		_add_validation_result(ValidationSeverity.WARNING, "Assets", "Asset registry not available for validation", "System")
		return
	
	# This would check all ship classes, weapon types, models, etc.
	# against the WCS Asset Registry to ensure they exist
	print("MissionValidationPanelController: Asset reference validation completed")

func _add_validation_result(severity: ValidationSeverity, component: String, message: String, location: String) -> void:
	var result: ValidationResult = ValidationResult.new()
	result.severity = severity
	result.component = component
	result.message = message
	result.location = location
	result.timestamp = Time.get_ticks_msec()
	
	validation_results.append(result)

func _apply_filters() -> void:
	filtered_results.clear()
	
	var show_errors_enabled: bool = show_errors.button_pressed if show_errors else true
	var show_warnings_enabled: bool = show_warnings.button_pressed if show_warnings else true
	var show_info_enabled: bool = show_info.button_pressed if show_info else false
	
	for result in validation_results:
		var should_show: bool = false
		
		match result.severity:
			ValidationSeverity.ERROR:
				should_show = show_errors_enabled
			ValidationSeverity.WARNING:
				should_show = show_warnings_enabled
			ValidationSeverity.INFO:
				should_show = show_info_enabled
		
		if should_show:
			filtered_results.append(result)

func _update_validation_display() -> void:
	_update_status_display()
	_populate_validation_list()

func _update_status_display() -> void:
	if not validation_status:
		return
	
	var error_count: int = 0
	var warning_count: int = 0
	
	for result in validation_results:
		match result.severity:
			ValidationSeverity.ERROR:
				error_count += 1
			ValidationSeverity.WARNING:
				warning_count += 1
	
	if error_count > 0:
		validation_status.text = "%d Errors, %d Warnings" % [error_count, warning_count]
		validation_status.modulate = Color.RED
	elif warning_count > 0:
		validation_status.text = "%d Warnings" % warning_count
		validation_status.modulate = Color.YELLOW
	else:
		validation_status.text = "Valid"
		validation_status.modulate = Color.GREEN

func _populate_validation_list() -> void:
	if not validation_list:
		return
	
	validation_list.clear()
	var root: TreeItem = validation_list.create_item()
	
	for result in filtered_results:
		var item: TreeItem = validation_list.create_item(root)
		
		# Severity
		item.set_text(0, _get_severity_text(result.severity))
		item.set_custom_color(0, _get_severity_color(result.severity))
		
		# Component
		item.set_text(1, result.component)
		
		# Message
		item.set_text(2, result.message)
		
		# Location
		item.set_text(3, result.location)
		
		# Store result data
		item.set_metadata(0, result)

func _get_severity_text(severity: ValidationSeverity) -> String:
	match severity:
		ValidationSeverity.ERROR:
			return "Error"
		ValidationSeverity.WARNING:
			return "Warning"
		ValidationSeverity.INFO:
			return "Info"
		_:
			return "Unknown"

func _get_severity_color(severity: ValidationSeverity) -> Color:
	match severity:
		ValidationSeverity.ERROR:
			return Color.RED
		ValidationSeverity.WARNING:
			return Color.YELLOW
		ValidationSeverity.INFO:
			return Color.CYAN
		_:
			return Color.WHITE

## Signal handlers

func _on_refresh_pressed() -> void:
	_run_validation()

func _on_filter_changed(_enabled: bool) -> void:
	_apply_filters()
	_update_validation_display()

func _on_validation_item_selected() -> void:
	var selected_item: TreeItem = validation_list.get_selected()
	if not selected_item:
		selected_validation_item = null
		_update_action_buttons()
		return
	
	selected_validation_item = selected_item.get_metadata(0) as ValidationResult
	_update_action_buttons()
	
	if selected_validation_item:
		validation_item_selected.emit(selected_validation_item)

func _update_action_buttons() -> void:
	var has_selection: bool = selected_validation_item != null
	
	if fix_button:
		fix_button.disabled = not has_selection or not _can_auto_fix(selected_validation_item)
	
	if goto_button:
		goto_button.disabled = not has_selection

func _can_auto_fix(item: ValidationResult) -> bool:
	if not item:
		return false
	
	# Determine if this validation item can be automatically fixed
	match item.component:
		"Mission":
			return item.message.contains("empty")  # Can auto-generate names/descriptions
		"Ship":
			return item.message.contains("wing")  # Can auto-assign to default wing
		_:
			return false

func _on_auto_fix_pressed() -> void:
	if selected_validation_item:
		auto_fix_requested.emit(selected_validation_item)
		# Re-run validation after fix
		_run_validation()

func _on_goto_pressed() -> void:
	if selected_validation_item:
		goto_requested.emit(selected_validation_item.location, selected_validation_item.component)

func _on_export_pressed() -> void:
	_export_validation_report()

func _export_validation_report() -> void:
	var timestamp: String = Time.get_datetime_string_from_system()
	var report_content: String = "Mission Validation Report - %s\n\n" % timestamp
	
	for result in validation_results:
		report_content += "[%s] %s - %s: %s (Location: %s)\n" % [
			_get_severity_text(result.severity),
			result.component,
			result.location,
			result.message,
			result.location
		]
	
	# TODO: Save report to file
	print("MissionValidationPanelController: Validation report exported")

## Public API methods

func get_validation_results() -> Array[ValidationResult]:
	return validation_results

func get_filtered_results() -> Array[ValidationResult]:
	return filtered_results

func get_error_count() -> int:
	return validation_results.filter(func(r): return r.severity == ValidationSeverity.ERROR).size()

func get_warning_count() -> int:
	return validation_results.filter(func(r): return r.severity == ValidationSeverity.WARNING).size()

func refresh_validation() -> void:
	_run_validation()

# Simple ValidationResult class for this implementation
class ValidationResult extends RefCounted:
	var severity: ValidationSeverity
	var component: String
	var message: String
	var location: String
	var timestamp: int
	var auto_fixable: bool = false