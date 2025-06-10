@tool
extends EditorImportPlugin

## Mission File Import Plugin
## Enables direct import of WCS .fs2 mission files with scene generation and mission controller

const MissionConverter = preload("res://addons/wcs_converter/conversion/mission_converter.gd")

func _get_importer_name() -> String:
	return "wcs.mission_file"

func _get_visible_name() -> String:
	return "WCS Mission File"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["fs2", "fc2"])

func _get_save_extension() -> String:
	return "tscn"

func _get_resource_type() -> String:
	return "PackedScene"

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 0

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	match option_name:
		"custom_ship_models_path":
			return options.get("use_custom_ship_models", false)
		"sexp_validation_level":
			return options.get("convert_sexp_events", true)
		_:
			return true

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "convert_sexp_events",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "sexp_validation_level",
			"default_value": 1,
			"property_hint": PROPERTY_HINT_ENUM,
			"hint_string": "Basic,Strict,Debug",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "generate_waypoint_gizmos",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "use_custom_ship_models",
			"default_value": false,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "custom_ship_models_path",
			"default_value": "res://models/ships/",
			"property_hint": PROPERTY_HINT_DIR,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "preserve_coordinates",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "coordinate_scale",
			"default_value": 1.0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.01,100.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "generate_mission_resource",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		}
	]

func _get_preset_count() -> int:
	return 2

func _get_preset_name(preset_index: int) -> String:
	match preset_index:
		0:
			return "Default"
		1:
			return "Editor Mode (with Gizmos)"
		_:
			return "Unknown"

func _import(source_file: String, save_path: String, options: Dictionary,
			 platform_variants: Array[String], gen_files: Array[String]) -> Error:
	
	print("Importing mission file: ", source_file)
	
	# Initialize mission converter
	var converter: MissionConverter = MissionConverter.new()
	
	# Create progress dialog
	var progress_dialog: AcceptDialog = _create_progress_dialog()
	progress_dialog.popup_centered()
	
	# Convert mission file to Godot scene
	var conversion_result: Dictionary = converter.convert_mission_to_scene(
		source_file,
		save_path + ".tscn",
		options
	)
	
	progress_dialog.queue_free()
	
	if not conversion_result.get("success", false):
		push_error("Failed to convert mission file: " + conversion_result.get("error", "Unknown error"))
		return ERR_COMPILATION_FAILED
	
	# Verify scene file was created
	var scene_path: String = save_path + ".tscn"
	if not FileAccess.file_exists(scene_path):
		push_error("Mission scene file was not created: " + scene_path)
		return ERR_FILE_NOT_FOUND
	
	# Generate mission resource if requested
	if options.get("generate_mission_resource", true):
		var resource_result: Error = _generate_mission_resource(
			conversion_result,
			save_path + ".tres",
			gen_files
		)
		if resource_result != OK:
			push_warning("Failed to generate mission resource, but scene import succeeded")
	
	# Generate mission controller script if SEXP events were converted
	if options.get("convert_sexp_events", true) and conversion_result.has("converted_events"):
		var script_result: Error = _generate_mission_script(
			conversion_result,
			save_path + ".gd",
			gen_files
		)
		if script_result != OK:
			push_warning("Failed to generate mission script, but scene import succeeded")
	
	print("Mission file imported successfully: ", 
		  conversion_result.get("ship_count", 0), " ships, ",
		  conversion_result.get("waypoint_count", 0), " waypoints, ",
		  conversion_result.get("event_count", 0), " events")
	
	return OK

func _create_progress_dialog() -> AcceptDialog:
	"""Create progress dialog for mission conversion"""
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Converting Mission File"
	dialog.set_flag(Window.FLAG_RESIZE_DISABLED, true)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label: Label = Label.new()
	label.text = "Converting WCS mission file to Godot scene...\nParsing objects, events, and SEXP expressions."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(400, 20)
	progress_bar.value = 50  # Indeterminate progress
	vbox.add_child(progress_bar)
	
	EditorInterface.get_base_control().add_child(dialog)
	return dialog

func _generate_mission_resource(conversion_result: Dictionary, resource_path: String, 
								gen_files: Array[String]) -> Error:
	"""Generate mission resource file with metadata"""
	
	var mission_resource: MissionResource = MissionResource.new()
	mission_resource.mission_name = conversion_result.get("mission_name", "Unknown Mission")
	mission_resource.source_file = conversion_result.get("source_file", "")
	mission_resource.ship_count = conversion_result.get("ship_count", 0)
	mission_resource.waypoint_count = conversion_result.get("waypoint_count", 0)
	mission_resource.event_count = conversion_result.get("event_count", 0)
	mission_resource.goal_count = conversion_result.get("goal_count", 0)
	mission_resource.conversion_metadata = conversion_result
	
	var save_result: Error = ResourceSaver.save(mission_resource, resource_path)
	if save_result == OK:
		gen_files.append(resource_path)
	
	return save_result

func _generate_mission_script(conversion_result: Dictionary, script_path: String,
							  gen_files: Array[String]) -> Error:
	"""Generate mission controller script with converted SEXP events"""
	
	var script_content: String = _build_mission_script_content(conversion_result)
	
	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	
	file.store_string(script_content)
	file.close()
	
	gen_files.append(script_path)
	return OK

func _build_mission_script_content(conversion_result: Dictionary) -> String:
	"""Build the mission controller script content"""
	
	var mission_name: String = conversion_result.get("mission_name", "UnknownMission")
	var converted_events: Array = conversion_result.get("converted_events", [])
	var converted_goals: Array = conversion_result.get("converted_goals", [])
	
	var script_template: String = '''extends Node

## Mission Controller: {mission_name}
## Auto-generated from WCS mission file conversion

signal mission_completed()
signal mission_failed()
signal objective_completed(objective_name: String)
signal event_triggered(event_name: String)

@export var mission_name: String = "{mission_name}"
@export var auto_start: bool = true

var mission_state: Dictionary = {{}}
var objectives: Dictionary = {{}}
var active_events: Array[String] = []
var mission_time: float = 0.0

func _ready() -> void:
	print("Mission Controller initialized: ", mission_name)
	_initialize_mission_state()
	_setup_objectives()
	_setup_events()
	
	if auto_start:
		start_mission()

func _process(delta: float) -> void:
	mission_time += delta
	_update_mission_events(delta)
	_check_mission_objectives()

func start_mission() -> void:
	"""Start the mission and activate initial events"""
	print("Starting mission: ", mission_name)
	mission_state["started"] = true
	mission_state["start_time"] = Time.get_ticks_msec() / 1000.0
	
	# Trigger initial events
	for event_name in active_events:
		_evaluate_event(event_name)

func _initialize_mission_state() -> void:
	"""Initialize mission state variables"""
	mission_state = {{
		"started": false,
		"completed": false,
		"failed": false,
		"start_time": 0.0,
		"mission_time": 0.0
	}}

func _setup_objectives() -> void:
	"""Setup mission objectives from converted goals"""
{objectives_setup}

func _setup_events() -> void:
	"""Setup mission events from converted SEXP expressions"""
{events_setup}

func _update_mission_events(delta: float) -> void:
	"""Update and evaluate mission events each frame"""
	mission_state["mission_time"] = mission_time
	
	for event_name in active_events:
		_evaluate_event(event_name)

func _check_mission_objectives() -> void:
	"""Check mission objectives for completion"""
	for objective_name in objectives.keys():
		var objective: Dictionary = objectives[objective_name]
		if not objective.get("completed", false):
			if _evaluate_objective(objective):
				objective["completed"] = true
				objective_completed.emit(objective_name)
				print("Objective completed: ", objective_name)

func _evaluate_event(event_name: String) -> void:
	"""Evaluate a specific mission event"""
	# Event evaluation logic would be implemented here
	# This is a placeholder for the actual SEXP conversion
	pass

func _evaluate_objective(objective: Dictionary) -> bool:
	"""Evaluate if an objective is complete"""
	# Objective evaluation logic would be implemented here
	return false

{converted_functions}
'''
	
	# Build objectives setup code
	var objectives_code: String = ""
	for goal in converted_goals:
		if goal is Dictionary:
			var goal_dict: Dictionary = goal as Dictionary
			objectives_code += "\tobjectives[\"" + goal_dict.get("name", "unnamed") + "\"] = {\n"
			objectives_code += "\t\t\"description\": \"" + goal_dict.get("description", "") + "\",\n"
			objectives_code += "\t\t\"type\": \"" + goal_dict.get("type", "primary") + "\",\n"
			objectives_code += "\t\t\"completed\": false\n"
			objectives_code += "\t}\n"
	
	# Build events setup code
	var events_code: String = ""
	for event in converted_events:
		if event is Dictionary:
			var event_dict: Dictionary = event as Dictionary
			events_code += "\tactive_events.append(\"" + event_dict.get("name", "unnamed") + "\")\n"
	
	# Build converted functions placeholder
	var functions_code: String = "# Converted SEXP functions would be implemented here"
	
	return script_template.format({
		"mission_name": mission_name,
		"objectives_setup": objectives_code,
		"events_setup": events_code,
		"converted_functions": functions_code
	})
