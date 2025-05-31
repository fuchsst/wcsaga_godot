@tool
class_name MissionComponentEditorDialog
extends AcceptDialog

## Unified mission component editor for GFRED2-010 Mission Component Editors.
## Scene-based UI controller implementing mandatory scene-based architecture.
## Provides specialized editors for all mission components.
## Scene: addons/gfred2/scenes/dialogs/component_editors/mission_component_editor_dialog.tscn

signal component_updated(component_type: String, component_data: Resource)
signal validation_changed(is_valid: bool, errors: Array[String])
signal export_requested(component_type: String)

# Current mission data
var current_mission_data: MissionData = null

# Scene node references
@onready var component_tabs: TabContainer = $VBoxContainer/ComponentTabs
@onready var validation_panel: ValidationResultsPanel = $VBoxContainer/ValidationPanel
@onready var button_container: HBoxContainer = $VBoxContainer/ButtonContainer

# Component editor tabs
@onready var reinforcement_editor: ReinforcementEditorPanel = $VBoxContainer/ComponentTabs/ReinforcementEditor
@onready var goals_editor: MissionGoalsEditorPanel = $VBoxContainer/ComponentTabs/GoalsEditor
@onready var messages_editor: MissionMessagesEditorPanel = $VBoxContainer/ComponentTabs/MessagesEditor
@onready var waypoints_editor: WaypointPathEditorPanel = $VBoxContainer/ComponentTabs/WaypointsEditor
@onready var environment_editor: EnvironmentEditorPanel = $VBoxContainer/ComponentTabs/EnvironmentEditor
@onready var variables_editor: MissionVariablesEditorPanel = $VBoxContainer/ComponentTabs/VariablesEditor

# Buttons
@onready var validate_button: Button = $VBoxContainer/ButtonContainer/ValidateButton
@onready var export_button: Button = $VBoxContainer/ButtonContainer/ExportButton
@onready var apply_button: Button = $VBoxContainer/ButtonContainer/ApplyButton
@onready var close_button: Button = $VBoxContainer/ButtonContainer/CloseButton

# Performance tracking
var last_validation_time: int = 0
var auto_validation_enabled: bool = true

func _ready() -> void:
	name = "MissionComponentEditorDialog"
	
	# Setup dialog properties
	title = "Mission Component Editor"
	size = Vector2i(1000, 700)
	min_size = Vector2i(800, 600)
	
	# Setup UI
	_setup_component_tabs()
	_setup_validation_panel()
	_setup_buttons()
	_connect_signals()
	
	# Initialize validation
	_setup_auto_validation()
	
	print("MissionComponentEditorDialog: Component editor initialized")

## Initializes the component editor with mission data
func initialize_with_mission(mission_data: MissionData) -> void:
	if not mission_data:
		push_error("MissionComponentEditorDialog: Cannot initialize with null mission data")
		return
	
	current_mission_data = mission_data
	
	# Initialize each component editor with mission data
	if reinforcement_editor:
		reinforcement_editor.initialize_with_mission(mission_data)
	
	if goals_editor:
		goals_editor.initialize_with_mission(mission_data)
	
	if messages_editor:
		messages_editor.initialize_with_mission(mission_data)
	
	if waypoints_editor:
		waypoints_editor.initialize_with_mission(mission_data)
	
	if environment_editor:
		environment_editor.initialize_with_mission(mission_data)
	
	if variables_editor:
		variables_editor.initialize_with_mission(mission_data)
	
	# Trigger initial validation
	_validate_all_components()
	
	print("MissionComponentEditorDialog: Initialized with mission: %s" % mission_data.mission_name)

## Sets up component tabs
func _setup_component_tabs() -> void:
	if not component_tabs:
		return
	
	# Configure tab container
	component_tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	component_tabs.use_hidden_tabs_for_min_size = true
	
	# Set tab names and icons (if scenes have proper names)
	if component_tabs.get_tab_count() >= 6:
		component_tabs.set_tab_title(0, "Reinforcements")
		component_tabs.set_tab_title(1, "Goals")
		component_tabs.set_tab_title(2, "Messages")
		component_tabs.set_tab_title(3, "Waypoints")
		component_tabs.set_tab_title(4, "Environment")
		component_tabs.set_tab_title(5, "Variables")
	
	# Connect tab change signal
	component_tabs.tab_changed.connect(_on_tab_changed)

## Sets up validation panel
func _setup_validation_panel() -> void:
	if not validation_panel:
		return
	
	# Connect validation panel signals
	validation_panel.validation_item_selected.connect(_on_validation_item_selected)
	
	# Initially hide validation panel
	validation_panel.visible = false

## Sets up buttons
func _setup_buttons() -> void:
	if validate_button:
		validate_button.text = "Validate All"
		validate_button.pressed.connect(_on_validate_pressed)
	
	if export_button:
		export_button.text = "Export Components"
		export_button.pressed.connect(_on_export_pressed)
	
	if apply_button:
		apply_button.text = "Apply Changes"
		apply_button.pressed.connect(_on_apply_pressed)
	
	if close_button:
		close_button.text = "Close"
		close_button.pressed.connect(_on_close_pressed)

## Connects component editor signals
func _connect_signals() -> void:
	# Reinforcement editor
	if reinforcement_editor:
		reinforcement_editor.component_updated.connect(_on_reinforcement_updated)
		reinforcement_editor.validation_changed.connect(_on_component_validation_changed.bind("reinforcements"))
	
	# Goals editor
	if goals_editor:
		goals_editor.goal_updated.connect(_on_goal_updated)
		goals_editor.validation_changed.connect(_on_component_validation_changed.bind("goals"))
	
	# Messages editor
	if messages_editor:
		messages_editor.message_updated.connect(_on_message_updated)
		messages_editor.validation_changed.connect(_on_component_validation_changed.bind("messages"))
	
	# Waypoints editor
	if waypoints_editor:
		waypoints_editor.waypoint_path_updated.connect(_on_waypoint_path_updated)
		waypoints_editor.validation_changed.connect(_on_component_validation_changed.bind("waypoints"))
	
	# Environment editor
	if environment_editor:
		environment_editor.environment_updated.connect(_on_environment_updated)
		environment_editor.validation_changed.connect(_on_component_validation_changed.bind("environment"))
	
	# Variables editor
	if variables_editor:
		variables_editor.variable_updated.connect(_on_variable_updated)
		variables_editor.validation_changed.connect(_on_component_validation_changed.bind("variables"))

## Sets up auto-validation timer
func _setup_auto_validation() -> void:
	if not auto_validation_enabled:
		return
	
	# Create validation timer
	var validation_timer: Timer = Timer.new()
	validation_timer.wait_time = 2.0  # Validate every 2 seconds
	validation_timer.timeout.connect(_validate_all_components)
	validation_timer.autostart = true
	add_child(validation_timer)

## Validates all mission components
func _validate_all_components() -> void:
	if not current_mission_data:
		return
	
	var start_time: int = Time.get_ticks_msec()
	var all_errors: Array[String] = []
	var component_results: Dictionary = {}
	
	# Validate each component
	component_results["reinforcements"] = _validate_component(reinforcement_editor)
	component_results["goals"] = _validate_component(goals_editor)
	component_results["messages"] = _validate_component(messages_editor)
	component_results["waypoints"] = _validate_component(waypoints_editor)
	component_results["environment"] = _validate_component(environment_editor)
	component_results["variables"] = _validate_component(variables_editor)
	
	# Collect all errors
	for component_type in component_results:
		var result: Dictionary = component_results[component_type]
		if not result["is_valid"]:
			for error in result["errors"]:
				all_errors.append("%s: %s" % [component_type.capitalize(), error])
	
	# Update validation panel
	if validation_panel:
		validation_panel.update_validation_results(all_errors)
		validation_panel.visible = all_errors.size() > 0
	
	# Track performance
	last_validation_time = Time.get_ticks_msec() - start_time
	
	# Emit validation signal
	var is_valid: bool = all_errors.is_empty()
	validation_changed.emit(is_valid, all_errors)
	
	print("MissionComponentEditorDialog: Validation completed in %dms, %s" % [last_validation_time, "valid" if is_valid else "invalid"])

## Validates a single component editor
func _validate_component(editor: Control) -> Dictionary:
	if not editor or not editor.has_method("validate_component"):
		return {"is_valid": true, "errors": []}
	
	return editor.validate_component()

## Signal handlers

func _on_tab_changed(tab_index: int) -> void:
	print("MissionComponentEditorDialog: Switched to tab %d" % tab_index)
	
	# Trigger validation for the current tab
	if auto_validation_enabled:
		call_deferred("_validate_current_tab")

func _validate_current_tab() -> void:
	var current_tab_index: int = component_tabs.current_tab
	var current_editor: Control = component_tabs.get_current_tab_control()
	
	if current_editor and current_editor.has_method("validate_component"):
		var result: Dictionary = current_editor.validate_component()
		var component_type: String = _get_component_type_for_tab(current_tab_index)
		_on_component_validation_changed(component_type, result["is_valid"], result["errors"])

func _get_component_type_for_tab(tab_index: int) -> String:
	match tab_index:
		0: return "reinforcements"
		1: return "goals"
		2: return "messages"
		3: return "waypoints"
		4: return "environment"
		5: return "variables"
		_: return "unknown"

func _on_reinforcement_updated(reinforcement_data: Resource) -> void:
	component_updated.emit("reinforcement", reinforcement_data)

func _on_goal_updated(goal_data: Resource) -> void:
	component_updated.emit("goal", goal_data)

func _on_message_updated(message_data: Resource) -> void:
	component_updated.emit("message", message_data)

func _on_waypoint_path_updated(path_data: Resource) -> void:
	component_updated.emit("waypoint_path", path_data)

func _on_environment_updated(environment_data: Resource) -> void:
	component_updated.emit("environment", environment_data)

func _on_variable_updated(variable_data: Resource) -> void:
	component_updated.emit("variable", variable_data)

func _on_component_validation_changed(component_type: String, is_valid: bool, errors: Array[String]) -> void:
	print("MissionComponentEditorDialog: %s validation changed: %s" % [component_type, "valid" if is_valid else "invalid"])
	
	# Update tab visual indicator based on validation
	_update_tab_validation_indicator(component_type, is_valid)

func _update_tab_validation_indicator(component_type: String, is_valid: bool) -> void:
	# TODO: Add visual validation indicators to tabs (color coding, icons)
	pass

func _on_validation_item_selected(error_message: String) -> void:
	# Parse component type from error message and switch to appropriate tab
	for i in range(component_tabs.get_tab_count()):
		var tab_component_type: String = _get_component_type_for_tab(i)
		if error_message.to_lower().begins_with(tab_component_type):
			component_tabs.current_tab = i
			break

func _on_validate_pressed() -> void:
	_validate_all_components()

func _on_export_pressed() -> void:
	var current_tab_index: int = component_tabs.current_tab
	var component_type: String = _get_component_type_for_tab(current_tab_index)
	export_requested.emit(component_type)

func _on_apply_pressed() -> void:
	# Apply all changes to mission data
	if not current_mission_data:
		return
	
	# Apply changes from each editor
	if reinforcement_editor and reinforcement_editor.has_method("apply_changes"):
		reinforcement_editor.apply_changes(current_mission_data)
	
	if goals_editor and goals_editor.has_method("apply_changes"):
		goals_editor.apply_changes(current_mission_data)
	
	if messages_editor and messages_editor.has_method("apply_changes"):
		messages_editor.apply_changes(current_mission_data)
	
	if waypoints_editor and waypoints_editor.has_method("apply_changes"):
		waypoints_editor.apply_changes(current_mission_data)
	
	if environment_editor and environment_editor.has_method("apply_changes"):
		environment_editor.apply_changes(current_mission_data)
	
	if variables_editor and variables_editor.has_method("apply_changes"):
		variables_editor.apply_changes(current_mission_data)
	
	print("MissionComponentEditorDialog: Applied all changes to mission data")

func _on_close_pressed() -> void:
	hide()

## Public API

## Gets current mission data
func get_current_mission_data() -> MissionData:
	return current_mission_data

## Enables or disables auto-validation
func set_auto_validation(enabled: bool) -> void:
	auto_validation_enabled = enabled

func is_auto_validation_enabled() -> bool:
	return auto_validation_enabled

## Switches to specific component tab
func switch_to_component(component_type: String) -> void:
	match component_type.to_lower():
		"reinforcements": component_tabs.current_tab = 0
		"goals": component_tabs.current_tab = 1
		"messages": component_tabs.current_tab = 2
		"waypoints": component_tabs.current_tab = 3
		"environment": component_tabs.current_tab = 4
		"variables": component_tabs.current_tab = 5

func get_current_component_type() -> String:
	return _get_component_type_for_tab(component_tabs.current_tab)

## Exports specific component type
func export_component(component_type: String) -> Dictionary:
	var current_editor: Control = null
	
	match component_type.to_lower():
		"reinforcements": current_editor = reinforcement_editor
		"goals": current_editor = goals_editor
		"messages": current_editor = messages_editor
		"waypoints": current_editor = waypoints_editor
		"environment": current_editor = environment_editor
		"variables": current_editor = variables_editor
	
	if current_editor and current_editor.has_method("export_component"):
		return current_editor.export_component()
	
	return {}

## Gets validation status for all components
func get_validation_status() -> Dictionary:
	return {
		"last_validation_time": last_validation_time,
		"auto_validation_enabled": auto_validation_enabled,
		"has_errors": validation_panel.visible if validation_panel else false
	}

## Forces validation of all components
func validate_all() -> bool:
	_validate_all_components()
	return not validation_panel.visible if validation_panel else true