@tool
class_name SceneDialogManagerController
extends Node

## Scene-based dialog manager controller for GFRED2-011 UI Refactoring.
## Replaces programmatic dialog instantiation with scene-based patterns.
## Scene: addons/gfred2/scenes/managers/scene_dialog_manager.tscn

signal dialog_opened(dialog_name: String, dialog_instance: BaseDialogController)
signal dialog_closed(dialog_name: String)

# Dialog scene registry
var dialog_scenes: Dictionary = {}
var active_dialogs: Dictionary = {}

# Scene node references
@onready var dialog_container: CanvasLayer = $DialogContainer

# Mission data reference
var mission_data: MissionData = null

func _ready() -> void:
	name = "SceneDialogManager"
	_register_dialog_scenes()
	print("SceneDialogManagerController: Scene-based dialog manager initialized")

func _register_dialog_scenes() -> void:
	# Register all available dialog scenes
	dialog_scenes = {
		"mission_specs": preload("res://addons/gfred2/dialogs/mission_specs_editor.tscn"),
		"ship_properties": preload("res://addons/gfred2/dialogs/ship_properties_editor.tscn"),
		"ship_special_damage": preload("res://addons/gfred2/dialogs/ship_special_damage_editor.tscn"),
		"ship_special_hitpoints": preload("res://addons/gfred2/dialogs/ship_special_hitpoints_editor.tscn"),
		"ship_textures": preload("res://addons/gfred2/dialogs/ship_textures_editor.tscn"),
		"wing_editor": preload("res://addons/gfred2/dialogs/wing_editor_dialog.tscn"),
		"mission_goals": preload("res://addons/gfred2/dialogs/mission_goals_dialog.tscn"),
		"mission_messages": preload("res://addons/gfred2/dialogs/mission_messages_dialog.tscn"),
		"open_mission": preload("res://addons/gfred2/dialogs/open_mission_dialog.tscn"),
		"save_mission": preload("res://addons/gfred2/dialogs/save_mission_dialog.tscn"),
		"restrict_paths": preload("res://addons/gfred2/dialogs/restrict_paths_dialog.tscn"),
		
		# New scene-based component editors from GFRED2-010
		"mission_component_editor": preload("res://addons/gfred2/scenes/dialogs/component_editors/mission_component_editor_dialog.tscn"),
		"advanced_ship_configuration": preload("res://addons/gfred2/scenes/dialogs/ship_editor/advanced_ship_configuration_dialog.tscn"),
		"briefing_editor": preload("res://addons/gfred2/scenes/dialogs/briefing_editor/briefing_editor_dialog.tscn"),
		"campaign_editor": preload("res://addons/gfred2/scenes/dialogs/campaign_editor/campaign_editor_dialog.tscn"),
		"mission_template_browser": preload("res://addons/gfred2/scenes/dialogs/template_library/mission_template_browser.tscn"),
		"template_customization": preload("res://addons/gfred2/scenes/dialogs/template_library/template_customization_dialog.tscn")
	}

## Sets mission data for dialogs that need it
func set_mission_data(data: MissionData) -> void:
	mission_data = data
	
	# Update all active dialogs with new mission data
	for dialog_name in active_dialogs:
		var dialog: BaseDialogController = active_dialogs[dialog_name]
		if dialog and dialog.has_method("set_mission_data"):
			dialog.set_mission_data(mission_data)

## Shows a dialog by name with optional initialization data
func show_dialog(dialog_name: String, init_data: Dictionary = {}) -> BaseDialogController:
	if not dialog_scenes.has(dialog_name):
		push_error("SceneDialogManagerController: Unknown dialog: %s" % dialog_name)
		return null
	
	# Check if dialog is already open
	if active_dialogs.has(dialog_name):
		var existing_dialog: BaseDialogController = active_dialogs[dialog_name]
		if is_instance_valid(existing_dialog):
			existing_dialog.show_dialog()
			return existing_dialog
		else:
			# Clean up invalid reference
			active_dialogs.erase(dialog_name)
	
	# Instantiate new dialog
	var dialog_scene: PackedScene = dialog_scenes[dialog_name]
	var dialog_instance: BaseDialogController = dialog_scene.instantiate() as BaseDialogController
	
	if not dialog_instance:
		push_error("SceneDialogManagerController: Failed to instantiate dialog: %s" % dialog_name)
		return null
	
	# Setup dialog
	_setup_dialog_instance(dialog_instance, dialog_name, init_data)
	
	# Add to scene tree
	dialog_container.add_child(dialog_instance)
	active_dialogs[dialog_name] = dialog_instance
	
	# Show dialog
	dialog_instance.show_dialog()
	
	dialog_opened.emit(dialog_name, dialog_instance)
	return dialog_instance

func _setup_dialog_instance(dialog: BaseDialogController, dialog_name: String, init_data: Dictionary) -> void:
	# Connect dialog signals
	dialog.confirmed.connect(_on_dialog_confirmed.bind(dialog_name))
	dialog.canceled.connect(_on_dialog_canceled.bind(dialog_name))
	
	if dialog.has_signal("dialog_applied"):
		dialog.dialog_applied.connect(_on_dialog_applied.bind(dialog_name))
	
	if dialog.has_signal("dialog_cancelled"):
		dialog.dialog_cancelled.connect(_on_dialog_cancelled.bind(dialog_name))
	
	# Set mission data if dialog supports it
	if mission_data and dialog.has_method("set_mission_data"):
		dialog.set_mission_data(mission_data)
	
	# Initialize with provided data
	if not init_data.is_empty():
		if dialog.has_method("initialize_with_data"):
			dialog.initialize_with_data(init_data)
		elif dialog.has_method("set_dialog_data"):
			dialog.set_dialog_data(init_data)
	
	# Set dialog-specific properties
	_configure_dialog_specifics(dialog, dialog_name)

func _configure_dialog_specifics(dialog: BaseDialogController, dialog_name: String) -> void:
	match dialog_name:
		"mission_specs":
			dialog.set_dialog_title("Mission Specifications")
			dialog.set_help_topic("mission_specs")
		
		"ship_properties":
			dialog.set_dialog_title("Ship Properties")
			dialog.set_help_topic("ship_properties")
		
		"wing_editor":
			dialog.set_dialog_title("Wing Editor")
			dialog.set_help_topic("wing_editor")
		
		"mission_goals":
			dialog.set_dialog_title("Mission Goals")
			dialog.set_help_topic("mission_goals")
		
		"mission_messages":
			dialog.set_dialog_title("Mission Messages")
			dialog.set_help_topic("mission_messages")
		
		"mission_component_editor":
			dialog.set_dialog_title("Mission Component Editor")
			dialog.set_help_topic("mission_components")
		
		"advanced_ship_configuration":
			dialog.set_dialog_title("Advanced Ship Configuration")
			dialog.set_help_topic("ship_configuration")
		
		"briefing_editor":
			dialog.set_dialog_title("Briefing Editor")
			dialog.set_help_topic("briefing_editor")
		
		"campaign_editor":
			dialog.set_dialog_title("Campaign Editor")
			dialog.set_help_topic("campaign_editor")

## Closes a dialog by name
func close_dialog(dialog_name: String) -> void:
	if not active_dialogs.has(dialog_name):
		return
	
	var dialog: BaseDialogController = active_dialogs[dialog_name]
	if is_instance_valid(dialog):
		dialog.hide()
		dialog.queue_free()
	
	active_dialogs.erase(dialog_name)
	dialog_closed.emit(dialog_name)

## Closes all active dialogs
func close_all_dialogs() -> void:
	for dialog_name in active_dialogs.keys():
		close_dialog(dialog_name)

## Gets an active dialog instance by name
func get_dialog(dialog_name: String) -> BaseDialogController:
	if active_dialogs.has(dialog_name):
		var dialog: BaseDialogController = active_dialogs[dialog_name]
		if is_instance_valid(dialog):
			return dialog
		else:
			# Clean up invalid reference
			active_dialogs.erase(dialog_name)
	
	return null

## Checks if a dialog is currently open
func is_dialog_open(dialog_name: String) -> bool:
	return active_dialogs.has(dialog_name) and is_instance_valid(active_dialogs[dialog_name])

## Gets all currently active dialog names
func get_active_dialog_names() -> Array[String]:
	var names: Array[String] = []
	
	for dialog_name in active_dialogs.keys():
		if is_instance_valid(active_dialogs[dialog_name]):
			names.append(dialog_name)
		else:
			# Clean up invalid reference
			active_dialogs.erase(dialog_name)
	
	return names

## Signal handlers

func _on_dialog_confirmed(dialog_name: String) -> void:
	# Handle dialog confirmation
	var dialog: BaseDialogController = get_dialog(dialog_name)
	if dialog and mission_data:
		_apply_dialog_changes(dialog, dialog_name)
	
	close_dialog(dialog_name)

func _on_dialog_canceled(dialog_name: String) -> void:
	# Handle dialog cancellation
	close_dialog(dialog_name)

func _on_dialog_applied(dialog_name: String) -> void:
	# Handle dialog apply (keep dialog open)
	var dialog: BaseDialogController = get_dialog(dialog_name)
	if dialog and mission_data:
		_apply_dialog_changes(dialog, dialog_name)

func _on_dialog_cancelled(dialog_name: String) -> void:
	# Handle dialog cancellation via custom signal
	close_dialog(dialog_name)

func _apply_dialog_changes(dialog: BaseDialogController, dialog_name: String) -> void:
	if not dialog or not mission_data:
		return
	
	# Apply changes based on dialog type
	match dialog_name:
		"mission_specs":
			_apply_mission_specs_changes(dialog)
		"ship_properties":
			_apply_ship_properties_changes(dialog)
		"wing_editor":
			_apply_wing_editor_changes(dialog)
		"mission_goals":
			_apply_mission_goals_changes(dialog)
		"mission_messages":
			_apply_mission_messages_changes(dialog)

func _apply_mission_specs_changes(dialog: BaseDialogController) -> void:
	# Apply mission specification changes
	if dialog.has_method("get_mission_specs_data"):
		var specs_data: Dictionary = dialog.get_mission_specs_data()
		
		# Update mission data with new specifications
		for property in specs_data:
			if mission_data.has_method("set_" + property):
				mission_data.call("set_" + property, specs_data[property])

func _apply_ship_properties_changes(dialog: BaseDialogController) -> void:
	# Apply ship properties changes
	if dialog.has_method("get_ship_data"):
		var ship_data: Dictionary = dialog.get_ship_data()
		
		# Update the appropriate ship in mission data
		# Implementation depends on specific ship data structure
		print("SceneDialogManagerController: Applying ship properties changes")

func _apply_wing_editor_changes(dialog: BaseDialogController) -> void:
	# Apply wing editor changes
	if dialog.has_method("get_wing_data"):
		var wing_data: Dictionary = dialog.get_wing_data()
		
		# Update wing data in mission
		print("SceneDialogManagerController: Applying wing editor changes")

func _apply_mission_goals_changes(dialog: BaseDialogController) -> void:
	# Apply mission goals changes
	if dialog.has_method("get_goals_data"):
		var goals_data: Array = dialog.get_goals_data()
		
		# Update mission goals
		if mission_data.has_method("set_goals"):
			mission_data.set_goals(goals_data)

func _apply_mission_messages_changes(dialog: BaseDialogController) -> void:
	# Apply mission messages changes
	if dialog.has_method("get_messages_data"):
		var messages_data: Array = dialog.get_messages_data()
		
		# Update mission messages
		if mission_data.has_method("set_messages"):
			mission_data.set_messages(messages_data)

## Registry management

func register_dialog_scene(dialog_name: String, scene: PackedScene) -> void:
	dialog_scenes[dialog_name] = scene

func unregister_dialog_scene(dialog_name: String) -> void:
	if dialog_scenes.has(dialog_name):
		# Close dialog if it's open
		if is_dialog_open(dialog_name):
			close_dialog(dialog_name)
		
		dialog_scenes.erase(dialog_name)

func get_registered_dialog_names() -> Array[String]:
	return dialog_scenes.keys()