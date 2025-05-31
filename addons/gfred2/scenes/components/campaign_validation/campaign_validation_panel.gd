@tool
class_name CampaignValidationPanel
extends Control

## Campaign validation panel component for GFRED2-008 Campaign Editor Integration.
## Provides comprehensive campaign testing and validation tools.

signal validation_requested()
signal test_campaign_requested()
signal export_validation_requested()

# Campaign data reference
var campaign_data: CampaignData = null
var progression_manager: CampaignProgressionManager = null
var validation_results: Array[String] = []
var is_validating: bool = false

# UI component references
@onready var validation_status: VBoxContainer = $VBoxContainer/ValidationStatus
@onready var status_icon: TextureRect = $VBoxContainer/ValidationStatus/StatusHeader/StatusIcon
@onready var status_label: Label = $VBoxContainer/ValidationStatus/StatusHeader/StatusLabel
@onready var validation_progress: ProgressBar = $VBoxContainer/ValidationStatus/ValidationProgress

# Validation controls
@onready var validation_controls: HBoxContainer = $VBoxContainer/ValidationControls
@onready var validate_button: Button = $VBoxContainer/ValidationControls/ValidateButton
@onready var test_campaign_button: Button = $VBoxContainer/ValidationControls/TestCampaignButton
@onready var export_report_button: Button = $VBoxContainer/ValidationControls/ExportReportButton
@onready var clear_results_button: Button = $VBoxContainer/ValidationControls/ClearResultsButton

# Validation results
@onready var results_panel: VBoxContainer = $VBoxContainer/ValidationResults
@onready var results_list: VBoxContainer = $VBoxContainer/ValidationResults/ResultsList
@onready var summary_label: Label = $VBoxContainer/ValidationResults/SummaryLabel

# Campaign statistics
@onready var statistics_panel: VBoxContainer = $VBoxContainer/CampaignStatistics
@onready var statistics_grid: GridContainer = $VBoxContainer/CampaignStatistics/StatisticsGrid

# Validation types
@onready var validation_options: VBoxContainer = $VBoxContainer/ValidationOptions
@onready var structure_validation_check: CheckBox = $VBoxContainer/ValidationOptions/StructureValidationCheck
@onready var progression_validation_check: CheckBox = $VBoxContainer/ValidationOptions/ProgressionValidationCheck
@onready var variable_validation_check: CheckBox = $VBoxContainer/ValidationOptions/VariableValidationCheck
@onready var file_validation_check: CheckBox = $VBoxContainer/ValidationOptions/FileValidationCheck
@onready var performance_validation_check: CheckBox = $VBoxContainer/ValidationOptions/PerformanceValidationCheck

# Validation result items
var result_items: Array[Control] = []

func _ready() -> void:
	name = "CampaignValidationPanel"
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Setup validation options
	_setup_validation_options()
	
	# Initialize empty state
	_clear_validation_results()
	_update_ui_state()
	
	print("CampaignValidationPanel: Validation panel initialized")

## Sets up the validation panel with campaign data
func setup_validation_panel(target_campaign: CampaignData) -> void:
	campaign_data = target_campaign
	
	# Initialize progression manager for testing
	if campaign_data:
		progression_manager = CampaignProgressionManager.new()
		progression_manager.setup_campaign_progression(campaign_data)
	
	# Update statistics display
	_update_campaign_statistics()
	_update_ui_state()

## Connects all UI signal handlers
func _connect_ui_signals() -> void:
	# Validation control buttons
	validate_button.pressed.connect(_on_validate_pressed)
	test_campaign_button.pressed.connect(_on_test_campaign_pressed)
	export_report_button.pressed.connect(_on_export_report_pressed)
	clear_results_button.pressed.connect(_on_clear_results_pressed)

## Sets up validation options
func _setup_validation_options() -> void:
	structure_validation_check.button_pressed = true
	structure_validation_check.text = "Campaign Structure"
	
	progression_validation_check.button_pressed = true
	progression_validation_check.text = "Mission Progression"
	
	variable_validation_check.button_pressed = true
	variable_validation_check.text = "Variable References"
	
	file_validation_check.button_pressed = false
	file_validation_check.text = "Mission File Integrity"
	
	performance_validation_check.button_pressed = false
	performance_validation_check.text = "Performance Analysis"

## Shows validation results
func show_validation_results(is_valid: bool, errors: Array[String]) -> void:
	validation_results = errors.duplicate()
	
	# Update status display
	_update_validation_status(is_valid)
	
	# Update results list
	_update_validation_results_list()
	
	# Update summary
	_update_validation_summary()
	
	_update_ui_state()

## Updates validation status display
func _update_validation_status(is_valid: bool) -> void:
	if is_valid:
		status_label.text = "Campaign Validation: PASSED"
		status_label.add_theme_color_override("font_color", Color.GREEN)
		# TODO: Set success icon
	else:
		status_label.text = "Campaign Validation: FAILED"
		status_label.add_theme_color_override("font_color", Color.RED)
		# TODO: Set error icon
	
	validation_progress.visible = false

## Updates validation results list
func _update_validation_results_list() -> void:
	# Clear existing result items
	for item in result_items:
		item.queue_free()
	result_items.clear()
	
	# Create result items
	for error in validation_results:
		var result_item: Control = _create_validation_result_item(error)
		results_list.add_child(result_item)
		result_items.append(result_item)

## Creates a validation result item
func _create_validation_result_item(error_text: String) -> Control:
	var item: PanelContainer = PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 30)
	
	# Add error style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.2, 0.2, 0.3)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color.RED
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	item.add_theme_stylebox_override("panel", style)
	
	# Item content
	var content: HBoxContainer = HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.add_child(content)
	
	# Error icon
	var icon: Label = Label.new()
	icon.text = "⚠"
	icon.custom_minimum_size = Vector2(24, 24)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_color_override("font_color", Color.RED)
	content.add_child(icon)
	
	# Error text
	var label: Label = Label.new()
	label.text = error_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	
	return item

## Updates validation summary
func _update_validation_summary() -> void:
	var error_count: int = validation_results.size()
	
	if error_count == 0:
		summary_label.text = "✓ Campaign validation passed with no errors"
		summary_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		summary_label.text = "✗ Campaign validation failed with %d error%s" % [error_count, "s" if error_count > 1 else ""]
		summary_label.add_theme_color_override("font_color", Color.RED)

## Updates campaign statistics display
func _update_campaign_statistics() -> void:
	# Clear existing statistics
	for child in statistics_grid.get_children():
		child.queue_free()
	
	if not campaign_data:
		return
	
	# Set grid columns
	statistics_grid.columns = 2
	
	# Campaign basic info
	_add_statistic_row("Campaign Name", campaign_data.campaign_name)
	_add_statistic_row("Total Missions", str(campaign_data.missions.size()))
	_add_statistic_row("Campaign Variables", str(campaign_data.campaign_variables.size()))
	
	# Mission breakdown
	var required_missions: int = 0
	var optional_missions: int = 0
	var total_branches: int = 0
	
	for mission in campaign_data.missions:
		if mission.is_required:
			required_missions += 1
		else:
			optional_missions += 1
		total_branches += mission.mission_branches.size()
	
	_add_statistic_row("Required Missions", str(required_missions))
	_add_statistic_row("Optional Missions", str(optional_missions))
	_add_statistic_row("Total Branches", str(total_branches))
	
	# Complexity metrics
	var max_prerequisites: int = 0
	var avg_prerequisites: float = 0.0
	var total_prerequisites: int = 0
	
	for mission in campaign_data.missions:
		var prereq_count: int = mission.prerequisite_missions.size()
		total_prerequisites += prereq_count
		max_prerequisites = max(max_prerequisites, prereq_count)
	
	if campaign_data.missions.size() > 0:
		avg_prerequisites = float(total_prerequisites) / float(campaign_data.missions.size())
	
	_add_statistic_row("Max Prerequisites", str(max_prerequisites))
	_add_statistic_row("Avg Prerequisites", "%.1f" % avg_prerequisites)
	
	# Progression analysis
	if progression_manager:
		var validation_errors: Array[String] = progression_manager.validate_campaign_progression()
		_add_statistic_row("Progression Issues", str(validation_errors.size()))

## Adds a statistic row to the grid
func _add_statistic_row(label_text: String, value_text: String) -> void:
	var label: Label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	statistics_grid.add_child(label)
	
	var value: Label = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1))
	statistics_grid.add_child(value)

## Clears validation results
func _clear_validation_results() -> void:
	validation_results.clear()
	
	# Clear UI
	for item in result_items:
		item.queue_free()
	result_items.clear()
	
	status_label.text = "Campaign Validation: Not Run"
	status_label.add_theme_color_override("font_color", Color.WHITE)
	summary_label.text = ""
	validation_progress.visible = false

## Updates UI state based on current context
func _update_ui_state() -> void:
	var has_campaign: bool = campaign_data != null
	var has_results: bool = validation_results.size() > 0
	
	# Update button states
	validate_button.disabled = not has_campaign or is_validating
	test_campaign_button.disabled = not has_campaign or is_validating
	export_report_button.disabled = not has_results
	clear_results_button.disabled = not has_results
	
	# Update validation text
	if is_validating:
		validate_button.text = "Validating..."
		validation_progress.visible = true
	else:
		validate_button.text = "Validate Campaign"
		validation_progress.visible = false

## Runs comprehensive campaign validation
func _run_campaign_validation() -> void:
	if not campaign_data:
		return
	
	is_validating = true
	_update_ui_state()
	
	var all_errors: Array[String] = []
	
	# Campaign structure validation
	if structure_validation_check.button_pressed:
		var structure_errors: Array[String] = _validate_campaign_structure()
		all_errors.append_array(structure_errors)
	
	# Mission progression validation
	if progression_validation_check.button_pressed:
		var progression_errors: Array[String] = _validate_mission_progression()
		all_errors.append_array(progression_errors)
	
	# Variable reference validation
	if variable_validation_check.button_pressed:
		var variable_errors: Array[String] = _validate_variable_references()
		all_errors.append_array(variable_errors)
	
	# Mission file validation
	if file_validation_check.button_pressed:
		var file_errors: Array[String] = _validate_mission_files()
		all_errors.append_array(file_errors)
	
	# Performance validation
	if performance_validation_check.button_pressed:
		var performance_errors: Array[String] = _validate_performance()
		all_errors.append_array(performance_errors)
	
	is_validating = false
	show_validation_results(all_errors.is_empty(), all_errors)

## Validates campaign structure
func _validate_campaign_structure() -> Array[String]:
	return campaign_data.validate_campaign()

## Validates mission progression logic
func _validate_mission_progression() -> Array[String]:
	if progression_manager:
		return progression_manager.validate_campaign_progression()
	return []

## Validates variable references
func _validate_variable_references() -> Array[String]:
	var errors: Array[String] = []
	
	# Check for undefined variable references in branch conditions
	for mission in campaign_data.missions:
		for i in range(mission.mission_branches.size()):
			var branch: CampaignMissionBranch = mission.mission_branches[i]
			if branch.branch_type == CampaignMissionBranch.BranchType.CONDITION:
				var undefined_vars: Array[String] = _find_undefined_variables(branch.branch_condition)
				for var_name in undefined_vars:
					errors.append("Mission '%s' branch %d references undefined variable '%s'" % [mission.mission_name, i + 1, var_name])
	
	return errors

## Finds undefined variables in a SEXP expression
func _find_undefined_variables(expression: String) -> Array[String]:
	var undefined: Array[String] = []
	
	# Simple regex to find variable references (e.g., $variable_name)
	var regex: RegEx = RegEx.new()
	regex.compile("\\$([a-zA-Z_][a-zA-Z0-9_]*)")
	var results: Array[RegExMatch] = regex.search_all(expression)
	
	for result in results:
		if result.get_group_count() > 0:
			var var_name: String = result.get_string(1)
			if not campaign_data.get_campaign_variable(var_name):
				if not undefined.has(var_name):
					undefined.append(var_name)
	
	return undefined

## Validates mission file integrity
func _validate_mission_files() -> Array[String]:
	var errors: Array[String] = []
	
	for mission in campaign_data.missions:
		if mission.mission_filename.is_empty():
			errors.append("Mission '%s' has no filename specified" % mission.mission_name)
			continue
		
		# Check if mission file exists
		var file_path: String = "res://missions/" + mission.mission_filename
		if not FileAccess.file_exists(file_path):
			errors.append("Mission file not found: %s" % file_path)
	
	return errors

## Validates performance characteristics
func _validate_performance() -> Array[String]:
	var errors: Array[String] = []
	
	# Check for performance issues
	if campaign_data.missions.size() > 50:
		errors.append("Campaign has %d missions, which may impact performance" % campaign_data.missions.size())
	
	if campaign_data.campaign_variables.size() > 100:
		errors.append("Campaign has %d variables, which may impact performance" % campaign_data.campaign_variables.size())
	
	# Check for complex branch networks
	var max_branches: int = 0
	for mission in campaign_data.missions:
		max_branches = max(max_branches, mission.mission_branches.size())
	
	if max_branches > 10:
		errors.append("Some missions have %d branches, which may be difficult to manage" % max_branches)
	
	return errors

## Simulates campaign progression for testing
func _simulate_campaign_progression() -> Dictionary:
	if not progression_manager:
		return {}
	
	# Reset progression manager for testing
	progression_manager.setup_campaign_progression(campaign_data)
	
	var simulation_results: Dictionary = {}
	simulation_results["starting_missions"] = progression_manager.get_unlocked_missions().duplicate()
	simulation_results["completion_sequence"] = []
	simulation_results["unreachable_missions"] = []
	
	# Simulate completing all unlocked missions
	var completed_count: int = 0
	var max_iterations: int = 100  # Prevent infinite loops
	var iteration: int = 0
	
	while progression_manager.get_unlocked_missions().size() > completed_count and iteration < max_iterations:
		var unlocked: Array[String] = progression_manager.get_unlocked_missions()
		
		for mission_id in unlocked:
			if not progression_manager.is_mission_completed(mission_id):
				# Simulate mission completion
				progression_manager.complete_mission(mission_id, true, 100.0)
				simulation_results["completion_sequence"].append(mission_id)
				completed_count += 1
				break
		
		iteration += 1
	
	# Find unreachable missions
	for mission in campaign_data.missions:
		if not progression_manager.is_mission_unlocked(mission.mission_id):
			simulation_results["unreachable_missions"].append(mission.mission_id)
	
	simulation_results["completion_percentage"] = progression_manager.get_campaign_completion_percentage()
	simulation_results["statistics"] = progression_manager.get_campaign_statistics()
	
	return simulation_results

## Signal Handlers

func _on_validate_pressed() -> void:
	_run_campaign_validation()
	validation_requested.emit()

func _on_test_campaign_pressed() -> void:
	# Run campaign progression simulation
	var simulation_results: Dictionary = _simulate_campaign_progression()
	
	# Create test report
	var test_errors: Array[String] = []
	
	if simulation_results.has("unreachable_missions") and simulation_results["unreachable_missions"].size() > 0:
		test_errors.append("Campaign test found %d unreachable missions" % simulation_results["unreachable_missions"].size())
	
	if simulation_results.has("completion_percentage"):
		var completion: float = simulation_results["completion_percentage"]
		if completion < 100.0:
			test_errors.append("Campaign test only reached %.1f%% completion" % completion)
	
	show_validation_results(test_errors.is_empty(), test_errors)
	test_campaign_requested.emit()

func _on_export_report_pressed() -> void:
	_export_validation_report()
	export_validation_requested.emit()

func _on_clear_results_pressed() -> void:
	_clear_validation_results()
	_update_ui_state()

## Exports validation report to file
func _export_validation_report() -> void:
	if validation_results.is_empty():
		return
	
	var report_content: String = "Campaign Validation Report\n"
	report_content += "Generated: %s\n" % Time.get_datetime_string_from_system()
	report_content += "Campaign: %s\n" % (campaign_data.campaign_name if campaign_data else "Unknown")
	report_content += "=" * 50 + "\n\n"
	
	if validation_results.is_empty():
		report_content += "✓ No validation errors found\n"
	else:
		report_content += "✗ Found %d validation errors:\n\n" % validation_results.size()
		for i in range(validation_results.size()):
			report_content += "%d. %s\n" % [i + 1, validation_results[i]]
	
	# TODO: Save report to file
	print("CampaignValidationPanel: Report content:\n%s" % report_content)

## Public API

## Gets current validation results
func get_validation_results() -> Array[String]:
	return validation_results.duplicate()

## Checks if validation is currently running
func is_validation_running() -> bool:
	return is_validating

## Triggers validation programmatically
func trigger_validation() -> void:
	_run_campaign_validation()

## Gets campaign statistics
func get_campaign_statistics() -> Dictionary:
	if progression_manager:
		return progression_manager.get_campaign_statistics()
	return {}