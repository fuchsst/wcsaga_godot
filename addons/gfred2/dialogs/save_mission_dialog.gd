@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

signal mission_saved(mission_data: MissionData, save_path: String)
signal export_completed(success: bool, export_path: String, errors: Array[String])

const MissionConverter = preload("res://addons/wcs_converter/conversion/mission_converter.gd")

var mission_data: MissionData
var mission_converter: MissionConverter

var name_edit: LineEdit
var title_edit: LineEdit
var author_edit: LineEdit
var description_edit: TextEdit

# Export controls
var export_checkbox: CheckBox
var export_path_edit: LineEdit
var export_browse_button: Button
var validate_checkbox: CheckBox

func _ready():
	super._ready()
	
	# Initialize EPIC-003 mission converter
	mission_converter = MissionConverter.new()
	
	# Get node references
	name_edit = $MarginContainer/VBoxContainer/GridContainer/NameEdit
	title_edit = $MarginContainer/VBoxContainer/GridContainer/TitleEdit
	author_edit = $MarginContainer/VBoxContainer/GridContainer/AuthorEdit
	description_edit = $MarginContainer/VBoxContainer/GridContainer/DescriptionEdit
	
	# Get export control references (these would need to be added to the scene)
	export_checkbox = $MarginContainer/VBoxContainer/ExportContainer/ExportCheckBox
	export_path_edit = $MarginContainer/VBoxContainer/ExportContainer/ExportPathEdit
	export_browse_button = $MarginContainer/VBoxContainer/ExportContainer/ExportBrowseButton
	validate_checkbox = $MarginContainer/VBoxContainer/ExportContainer/ValidateCheckBox
	
	# Connect button signals
	var save_button = $MarginContainer/VBoxContainer/ButtonContainer/SaveButton
	var cancel_button = $MarginContainer/VBoxContainer/ButtonContainer/CancelButton
	
	save_button.pressed.connect(_on_ok_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Connect export controls
	export_checkbox.toggled.connect(_on_export_toggled)
	export_browse_button.pressed.connect(_on_export_browse_pressed)
	
	# Initialize export settings
	_setup_export_defaults()

func show_dialog_with_mission(mission: MissionData):
	mission_data = mission
	
	# Populate fields
	title_edit.text = mission.title if mission.title else ""
	author_edit.text = mission.designer if mission.designer else ""
	description_edit.text = mission.description if mission.description else ""
	
	# Set default export path based on mission title
	var default_export_name: String = _sanitize_filename(mission.title) + ".fs2"
	export_path_edit.text = "res://exports/" + default_export_name
	
	show_dialog(Vector2(600, 500))

func _on_ok_pressed():
	# Update mission data
	mission_data.title = title_edit.text
	mission_data.designer = author_edit.text
	mission_data.description = description_edit.text
	
	# Save mission as Godot resource
	var save_path: String = "res://missions/" + _sanitize_filename(mission_data.title) + ".tres"
	var save_result: Error = ResourceSaver.save(mission_data, save_path)
	
	if save_result == OK:
		print("Mission saved successfully: %s" % save_path)
		mission_saved.emit(mission_data, save_path)
		
		# Export to FS2 format if requested
		if export_checkbox.button_pressed and not export_path_edit.text.is_empty():
			_export_mission_to_fs2()
	else:
		push_error("Failed to save mission: Error %d" % save_result)
	
	super._on_ok_pressed()

func _on_cancel_pressed():
	super._on_cancel_pressed()

func _setup_export_defaults() -> void:
	"""Initialize export settings with defaults"""
	export_checkbox.button_pressed = false
	validate_checkbox.button_pressed = true
	export_path_edit.editable = false
	export_browse_button.disabled = true

func _on_export_toggled(enabled: bool) -> void:
	"""Handle export checkbox toggle"""
	export_path_edit.editable = enabled
	export_browse_button.disabled = not enabled

func _on_export_browse_pressed() -> void:
	"""Show file dialog for export path selection"""
	var file_dialog: EditorFileDialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	file_dialog.add_filter("*.fs2", "FreeSpace 2 Mission Files")
	file_dialog.current_dir = "res://exports/"
	file_dialog.current_file = _sanitize_filename(mission_data.title) + ".fs2"
	
	# Connect and show dialog
	file_dialog.file_selected.connect(_on_export_file_selected)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(800, 600))

func _on_export_file_selected(path: String) -> void:
	"""Handle export file selection"""
	export_path_edit.text = path

func _sanitize_filename(filename: String) -> String:
	"""Sanitize filename for safe file system usage"""
	var sanitized: String = filename
	# Replace invalid characters with underscores
	sanitized = sanitized.replace(" ", "_")
	sanitized = sanitized.replace("/", "_")
	sanitized = sanitized.replace("\\", "_")
	sanitized = sanitized.replace(":", "_")
	sanitized = sanitized.replace("*", "_")
	sanitized = sanitized.replace("?", "_")
	sanitized = sanitized.replace("\"", "_")
	sanitized = sanitized.replace("<", "_")
	sanitized = sanitized.replace(">", "_")
	sanitized = sanitized.replace("|", "_")
	
	# Ensure it's not empty
	if sanitized.is_empty():
		sanitized = "untitled_mission"
	
	return sanitized

func _export_mission_to_fs2() -> void:
	"""Export mission to FS2 format using EPIC-003 MissionConverter"""
	var export_path: String = export_path_edit.text
	
	# Validate export path
	if export_path.is_empty():
		push_error("Export path is empty")
		return
	
	# Validate mission before export if requested
	if validate_checkbox.button_pressed:
		var validation_result: Dictionary = _validate_mission_for_export()
		if not validation_result.get("success", false):
			var errors: Array[String] = validation_result.get("errors", [])
			push_error("Mission validation failed: %s" % str(errors))
			export_completed.emit(false, export_path, errors)
			return
	
	# Prepare conversion options
	var options: Dictionary = {
		"convert_sexp_events": true,
		"sexp_validation_level": 1,  # Standard validation
		"generate_waypoint_gizmos": true,
		"preserve_coordinates": true,
		"coordinate_scale": 1.0,
		"use_custom_ship_models": false,
		"generate_mission_resource": false  # We're exporting, not importing
	}
	
	# Convert mission using EPIC-003 converter
	# Note: This assumes the mission is currently saved as a scene or has scene data
	var temp_scene_path: String = "res://temp/" + _sanitize_filename(mission_data.title) + ".tscn"
	
	# First save mission as scene (this would need to be implemented)
	var scene_save_result: Error = _save_mission_as_scene(temp_scene_path)
	if scene_save_result != OK:
		var errors: Array[String] = ["Failed to create temporary scene for export"]
		export_completed.emit(false, export_path, errors)
		return
	
	# Convert scene to FS2 format
	var conversion_result: Dictionary = mission_converter.convert_mission_to_scene(temp_scene_path, export_path, options)
	
	# Clean up temporary file
	DirAccess.remove_absolute(temp_scene_path)
	
	# Report result
	var success: bool = conversion_result.get("success", false)
	var errors: Array[String] = []
	if not success:
		errors.append(conversion_result.get("error", "Unknown conversion error"))
	
	export_completed.emit(success, export_path, errors)
	
	if success:
		print("Mission exported successfully to: %s" % export_path)
	else:
		push_error("Mission export failed: %s" % str(errors))

func _validate_mission_for_export() -> Dictionary:
	"""Validate mission data before export using EPIC-003 converter"""
	# Use mission data validation
	var validation_errors: Array = mission_data.validate()
	
	if validation_errors.is_empty():
		return {"success": true, "errors": []}
	else:
		return {"success": false, "errors": validation_errors}

func _save_mission_as_scene(scene_path: String) -> Error:
	"""Save mission data as Godot scene for conversion"""
	# This is a placeholder - the actual implementation would convert
	# MissionData to a proper Godot scene structure
	var scene: PackedScene = PackedScene.new()
	var root: Node3D = Node3D.new()
	root.name = "Mission_" + _sanitize_filename(mission_data.title)
	
	# Add mission objects as child nodes (placeholder implementation)
	for object_id in mission_data.objects:
		var mission_object = mission_data.objects[object_id]
		var object_node: Node3D = Node3D.new()
		object_node.name = mission_object.name if mission_object.name else "Object_" + str(object_id)
		root.add_child(object_node)
	
	# Pack and save scene
	var pack_result: Error = scene.pack(root)
	if pack_result != OK:
		return pack_result
	
	return ResourceSaver.save(scene, scene_path)
