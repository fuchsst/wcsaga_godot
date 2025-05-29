@tool
extends RefCounted

## Mission File Converter Bridge
## Interfaces with Python mission conversion pipeline for Godot import plugin integration

class_name MissionConverter

const PYTHON_SCRIPT_PATH: String = "res://conversion_tools/mission_converter/mission_file_converter.py"

func convert_mission_to_scene(mission_file_path: String, output_path: String, options: Dictionary) -> Dictionary:
	"""Convert FS2 mission file to Godot scene using Python backend"""
	
	# Validate input file
	if not FileAccess.file_exists(mission_file_path):
		return {
			"success": false,
			"error": "Mission file does not exist: " + mission_file_path
		}
	
	# Prepare Python command
	var python_command: Array[String] = [
		ProjectSettings.globalize_path(PYTHON_SCRIPT_PATH),
		"convert",
		ProjectSettings.globalize_path(mission_file_path),
		"--output", ProjectSettings.globalize_path(output_path)
	]
	
	# Add SEXP conversion options
	if options.get("convert_sexp_events", true):
		python_command.append("--convert-sexp")
		
		var validation_level: int = options.get("sexp_validation_level", 1)
		var validation_names: Array[String] = ["basic", "strict", "debug"]
		python_command.append("--sexp-validation")
		python_command.append(validation_names[validation_level])
	
	# Add waypoint gizmo options
	if options.get("generate_waypoint_gizmos", true):
		python_command.append("--waypoint-gizmos")
	
	# Add coordinate system options
	if options.get("preserve_coordinates", true):
		python_command.append("--preserve-coords")
	
	var coord_scale: float = options.get("coordinate_scale", 1.0)
	if coord_scale != 1.0:
		python_command.append("--coord-scale")
		python_command.append(str(coord_scale))
	
	# Add custom ship models path
	if options.get("use_custom_ship_models", false):
		python_command.append("--ship-models")
		python_command.append(ProjectSettings.globalize_path(options.get("custom_ship_models_path", "res://models/ships/")))
	
	# Add resource generation option
	if options.get("generate_mission_resource", true):
		python_command.append("--generate-resource")
	
	# Add verbose output
	python_command.append("--verbose")
	
	# Execute Python conversion
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var output: Array = []
	var exit_code: int = OS.execute("python3", python_command, output, true, true)
	var end_time: float = Time.get_ticks_msec() / 1000.0
	
	# Parse results
	if exit_code != 0:
		var error_message: String = "Mission conversion failed with exit code: " + str(exit_code)
		if output.size() > 0:
			error_message += "\nOutput: " + str(output)
		
		return {
			"success": false,
			"error": error_message
		}
	
	# Parse conversion statistics from output
	var stats: Dictionary = _parse_conversion_output(output)
	
	return {
		"success": true,
		"source_file": mission_file_path,
		"output_file": output_path,
		"conversion_time": end_time - start_time,
		"mission_name": stats.get("mission_name", "Unknown"),
		"ship_count": stats.get("ship_count", 0),
		"waypoint_count": stats.get("waypoint_count", 0),
		"event_count": stats.get("event_count", 0),
		"goal_count": stats.get("goal_count", 0),
		"converted_events": stats.get("converted_events", []),
		"converted_goals": stats.get("converted_goals", []),
		"output_messages": output
	}

func _parse_conversion_output(output: Array) -> Dictionary:
	"""Parse conversion statistics from Python script output"""
	
	var stats: Dictionary = {
		"mission_name": "Unknown",
		"ship_count": 0,
		"waypoint_count": 0,
		"event_count": 0,
		"goal_count": 0,
		"converted_events": [],
		"converted_goals": []
	}
	
	for line in output:
		var line_str: String = str(line).strip_edges()
		
		# Parse mission name
		if line_str.begins_with("Mission name:"):
			var parts: PackedStringArray = line_str.split(":", false, 1)
			if parts.size() > 1:
				stats["mission_name"] = parts[1].strip_edges()
		
		# Parse ship count
		elif line_str.begins_with("Ships:") or line_str.contains("ship objects"):
			var parts: PackedStringArray = line_str.split(" ")
			for i in range(parts.size()):
				if parts[i].to_int() > 0:
					stats["ship_count"] = parts[i].to_int()
					break
		
		# Parse waypoint count
		elif line_str.begins_with("Waypoints:") or line_str.contains("waypoint"):
			var parts: PackedStringArray = line_str.split(" ")
			for i in range(parts.size()):
				if parts[i].to_int() > 0:
					stats["waypoint_count"] = parts[i].to_int()
					break
		
		# Parse event count
		elif line_str.begins_with("Events:") or line_str.contains("events converted"):
			var parts: PackedStringArray = line_str.split(" ")
			for i in range(parts.size()):
				if parts[i].to_int() > 0:
					stats["event_count"] = parts[i].to_int()
					break
		
		# Parse goal count
		elif line_str.begins_with("Goals:") or line_str.contains("goals converted"):
			var parts: PackedStringArray = line_str.split(" ")
			for i in range(parts.size()):
				if parts[i].to_int() > 0:
					stats["goal_count"] = parts[i].to_int()
					break
	
	return stats

func get_mission_file_info(mission_file_path: String) -> Dictionary:
	"""Get basic information about mission file without full conversion"""
	
	if not FileAccess.file_exists(mission_file_path):
		return {
			"success": false,
			"error": "Mission file does not exist"
		}
	
	# Use Python script to analyze mission header
	var python_command: Array[String] = [
		ProjectSettings.globalize_path(PYTHON_SCRIPT_PATH),
		"analyze",
		ProjectSettings.globalize_path(mission_file_path),
		"--quick"
	]
	
	var output: Array = []
	var exit_code: int = OS.execute("python3", python_command, output, true, true)
	
	if exit_code != 0:
		return {
			"success": false,
			"error": "Failed to analyze mission file"
		}
	
	# Parse analysis output
	var info: Dictionary = _parse_analysis_output(output)
	info["success"] = true
	info["file_size"] = FileAccess.get_file_as_bytes(mission_file_path).size()
	
	return info

func _parse_analysis_output(output: Array) -> Dictionary:
	"""Parse mission analysis output for file information"""
	
	var info: Dictionary = {
		"mission_name": "Unknown",
		"ship_count": 0,
		"waypoint_count": 0,
		"event_count": 0,
		"goal_count": 0,
		"wing_count": 0
	}
	
	for line in output:
		var line_str: String = str(line).strip_edges()
		
		if line_str.begins_with("Mission:"):
			var parts: PackedStringArray = line_str.split(":", false, 1)
			if parts.size() > 1:
				info["mission_name"] = parts[1].strip_edges()
		
		elif line_str.begins_with("Ships:"):
			var parts: PackedStringArray = line_str.split(":")
			if parts.size() > 1:
				info["ship_count"] = parts[1].strip_edges().to_int()
		
		elif line_str.begins_with("Waypoints:"):
			var parts: PackedStringArray = line_str.split(":")
			if parts.size() > 1:
				info["waypoint_count"] = parts[1].strip_edges().to_int()
		
		elif line_str.begins_with("Events:"):
			var parts: PackedStringArray = line_str.split(":")
			if parts.size() > 1:
				info["event_count"] = parts[1].strip_edges().to_int()
		
		elif line_str.begins_with("Goals:"):
			var parts: PackedStringArray = line_str.split(":")
			if parts.size() > 1:
				info["goal_count"] = parts[1].strip_edges().to_int()
		
		elif line_str.begins_with("Wings:"):
			var parts: PackedStringArray = line_str.split(":")
			if parts.size() > 1:
				info["wing_count"] = parts[1].strip_edges().to_int()
	
	return info

func validate_mission_file(mission_file_path: String) -> Dictionary:
	"""Validate mission file format and report any issues"""
	
	var python_command: Array[String] = [
		ProjectSettings.globalize_path(PYTHON_SCRIPT_PATH),
		"validate",
		ProjectSettings.globalize_path(mission_file_path)
	]
	
	var output: Array = []
	var exit_code: int = OS.execute("python3", python_command, output, true, true)
	
	return {
		"success": exit_code == 0,
		"validation_output": output,
		"errors": _extract_errors_from_output(output),
		"warnings": _extract_warnings_from_output(output)
	}

func _extract_errors_from_output(output: Array) -> Array[String]:
	"""Extract error messages from validation output"""
	var errors: Array[String] = []
	
	for line in output:
		var line_str: String = str(line).strip_edges()
		if line_str.begins_with("ERROR:") or line_str.contains("error"):
			errors.append(line_str)
	
	return errors

func _extract_warnings_from_output(output: Array) -> Array[String]:
	"""Extract warning messages from validation output"""
	var warnings: Array[String] = []
	
	for line in output:
		var line_str: String = str(line).strip_edges()
		if line_str.begins_with("WARNING:") or line_str.contains("warning"):
			warnings.append(line_str)
	
	return warnings

func convert_mission_directory(directory_path: String, output_directory: String, options: Dictionary) -> Dictionary:
	"""Convert all mission files in a directory"""
	
	var results: Dictionary = {
		"success": true,
		"converted_missions": [],
		"failed_missions": [],
		"total_count": 0
	}
	
	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null:
		return {
			"success": false,
			"error": "Failed to open directory: " + directory_path
		}
	
	# Find all mission files
	var mission_files: Array[String] = _find_mission_files(directory_path)
	results["total_count"] = mission_files.size()
	
	# Convert each mission file
	for mission_file in mission_files:
		var mission_name: String = mission_file.get_file().get_basename()
		var output_path: String = output_directory + "/" + mission_name + ".tscn"
		
		var conversion_result: Dictionary = convert_mission_to_scene(mission_file, output_path, options)
		
		if conversion_result.get("success", false):
			results["converted_missions"].append({
				"source": mission_file,
				"output": output_path,
				"result": conversion_result
			})
		else:
			results["failed_missions"].append({
				"source": mission_file,
				"error": conversion_result.get("error", "Unknown error")
			})
	
	results["success"] = results["failed_missions"].size() == 0
	return results

func _find_mission_files(directory: String) -> Array[String]:
	"""Find all mission files in directory"""
	var files: Array[String] = []
	var extensions: Array[String] = ["fs2", "fc2"]
	
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return files
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var extension: String = file_name.get_extension().to_lower()
			if extension in extensions:
				files.append(directory + "/" + file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return files