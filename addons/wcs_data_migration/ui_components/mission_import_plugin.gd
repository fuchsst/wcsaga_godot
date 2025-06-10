@tool
extends EditorImportPlugin

## Mission File Import Plugin  
## Implements DM-007 Mission File Format Conversion

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

func _get_preset_count() -> int:
	return 1

func _get_preset_name(preset_index: int) -> String:
	return "Default"

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "coordinate_scale",
			"default_value": 1.0,
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.01,100.0,0.01"
		},
		{
			"name": "generate_waypoint_gizmos",
			"default_value": true,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Generate 3D gizmos for waypoints"
		},
		{
			"name": "convert_sexp_events",
			"default_value": true,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Convert SEXP expressions to GDScript"
		},
		{
			"name": "create_mission_controller",
			"default_value": true,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Create mission controller script"
		}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> int:
	print("Importing mission file: %s" % source_file)
	
	# Get the Python converter directory
	var converter_dir: String = get_script().get_path().get_base_dir().path_join("..")
	var python_script: String = converter_dir.path_join("mission_converter/mission_file_converter.py")
	var output_dir: String = save_path.get_base_dir()
	
	var args: PackedStringArray = PackedStringArray([
		python_script,
		source_file,
		"--output", output_dir,
		"--scale", str(options.get("coordinate_scale", 1.0))
	])
	
	# Add conversion options
	if options.get("generate_waypoint_gizmos", true):
		args.append("--waypoint-gizmos")
	
	if options.get("convert_sexp_events", true):
		args.append("--convert-sexp")
	
	if options.get("create_mission_controller", true):
		args.append("--mission-controller")
	
	# Execute Python mission converter
	var python_exe: String = _get_python_executable()
	var output: Array = []
	var result: int = OS.execute(python_exe, args, output, true)
	
	if result != 0:
		print_rich("[color=red]Mission conversion failed: %s[/color]" % str(output))
		return FAILED
	
	# Look for generated scene file
	var expected_scene: String = output_dir.path_join(source_file.get_file().get_basename() + ".tscn")
	
	if not FileAccess.file_exists(expected_scene):
		print_rich("[color=red]Mission scene not created: %s[/color]" % expected_scene)
		return FAILED
	
	# Load the generated scene
	var scene: PackedScene = load(expected_scene)
	if not scene:
		print_rich("[color=red]Failed to load generated mission scene[/color]")
		return FAILED
	
	# Save to final location
	var save_result: Error = ResourceSaver.save(scene, "%s.%s" % [save_path, _get_save_extension()])
	
	if save_result == OK:
		print("Mission file imported successfully: %s" % source_file)
		
		# Generate resource files list for gen_files
		var mission_name: String = source_file.get_file().get_basename()
		var resource_files: PackedStringArray = PackedStringArray([
			output_dir.path_join(mission_name + "_data.tres"),
			output_dir.path_join(mission_name + "_events.tres"),
			output_dir.path_join(mission_name + "_controller.gd")
		])
		
		for resource_file in resource_files:
			if FileAccess.file_exists(resource_file):
				gen_files.append(resource_file)
		
		return OK
	else:
		print_rich("[color=red]Failed to save mission scene[/color]")
		return FAILED

func _get_python_executable() -> String:
	## Get the Python executable path for the conversion tools
	
	# Try to find Python executable
	var possible_paths: PackedStringArray = PackedStringArray([
		"/mnt/d/projects/wcsaga_godot_converter/target/venv/Scripts/python.exe",
		"/mnt/d/projects/wcsaga_godot_converter/target/venv/bin/python",
		"python",
		"python3"
	])
	
	for path in possible_paths:
		if FileAccess.file_exists(path) or _check_command_exists(path):
			return path
	
	# Fallback
	return "python"

func _check_command_exists(command: String) -> bool:
	## Check if a command exists in the system PATH
	var output: Array = []
	var result: int = OS.execute("which", [command], output, true)
	return result == 0
