@tool
extends RefCounted

## POF Model Converter Bridge  
## Interfaces with Python POF conversion pipeline for Godot import plugin integration

class_name POFConverter

const PYTHON_SCRIPT_PATH: String = "res://conversion_tools/pof_parser/cli.py"

func convert_pof_to_glb(pof_file_path: String, output_path: String, options: Dictionary) -> Dictionary:
	"""Convert POF model to GLB using Python backend and return conversion results"""
	
	# Validate input file
	if not FileAccess.file_exists(pof_file_path):
		return {
			"success": false,
			"error": "POF file does not exist: " + pof_file_path
		}
	
	# Prepare Python command
	var python_command: Array[String] = [
		ProjectSettings.globalize_path(PYTHON_SCRIPT_PATH),
		"convert",
		ProjectSettings.globalize_path(pof_file_path),
		"--output", ProjectSettings.globalize_path(output_path),
		"--format", "glb"
	]
	
	# Add texture search paths
	if options.get("auto_find_textures", true):
		python_command.append("--auto-textures")
		
		var texture_paths: PackedStringArray = options.get("texture_search_paths", PackedStringArray())
		for texture_path in texture_paths:
			python_command.append("--textures")
			python_command.append(ProjectSettings.globalize_path(texture_path))
	
	# Add LOD generation options
	if options.get("generate_lods", true):
		python_command.append("--generate-lods")
		python_command.append("--lod-distances")
		python_command.append(str(options.get("lod_distance_1", 50.0)))
		python_command.append(str(options.get("lod_distance_2", 150.0)))
		python_command.append(str(options.get("lod_distance_3", 300.0)))
	
	# Add optimization options
	if options.get("optimize_meshes", true):
		python_command.append("--optimize")
	
	# Add scale option
	var import_scale: float = options.get("import_scale", 1.0)
	if import_scale != 1.0:
		python_command.append("--scale")
		python_command.append(str(import_scale))
	
	# Add collision generation
	if options.get("generate_collision", true):
		var collision_type: int = options.get("collision_shape", 0)
		var collision_names: Array[String] = ["convex", "trimesh", "simplified"]
		python_command.append("--collision")
		python_command.append(collision_names[collision_type])
	
	# Add verbose output for debugging
	python_command.append("--verbose")
	
	# Execute Python conversion
	var start_time: float = Time.get_ticks_msec() / 1000.0
	var output: Array = []
	var exit_code: int = OS.execute("python3", python_command, output, true, true)
	var end_time: float = Time.get_ticks_msec() / 1000.0
	
	# Parse results
	if exit_code != 0:
		var error_message: String = "POF conversion failed with exit code: " + str(exit_code)
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
		"source_file": pof_file_path,
		"output_file": output_path,
		"conversion_time": end_time - start_time,
		"mesh_count": stats.get("mesh_count", 0),
		"material_count": stats.get("material_count", 0),
		"vertex_count": stats.get("vertex_count", 0),
		"texture_count": stats.get("texture_count", 0),
		"lod_meshes": stats.get("lod_meshes", []),
		"output_messages": output
	}

func _parse_conversion_output(output: Array) -> Dictionary:
	"""Parse conversion statistics from Python script output"""
	
	var stats: Dictionary = {
		"mesh_count": 0,
		"material_count": 0,
		"vertex_count": 0,
		"texture_count": 0,
		"lod_meshes": []
	}
	
	for line in output:
		var line_str: String = str(line).strip_edges()
		
		# Parse mesh count
		if line_str.begins_with("Converted") and line_str.contains("subobjects"):
			var parts: PackedStringArray = line_str.split(" ")
			for i in range(parts.size()):
				if parts[i] == "Converted" and i + 1 < parts.size():
					stats["mesh_count"] = parts[i + 1].to_int()
					break
		
		# Parse material count
		elif line_str.begins_with("Generated") and line_str.contains("materials"):
			var parts: PackedStringArray = line_str.split(" ")
			for i in range(parts.size()):
				if parts[i] == "Generated" and i + 1 < parts.size():
					stats["material_count"] = parts[i + 1].to_int()
					break
		
		# Parse vertex count
		elif line_str.begins_with("Total vertices:"):
			var parts: PackedStringArray = line_str.split(":")
			if parts.size() > 1:
				stats["vertex_count"] = parts[1].strip_edges().to_int()
		
		# Parse texture count
		elif line_str.begins_with("Found") and line_str.contains("textures"):
			var parts: PackedStringArray = line_str.split(" ")
			for i in range(parts.size()):
				if parts[i] == "Found" and i + 1 < parts.size():
					stats["texture_count"] = parts[i + 1].to_int()
					break
	
	return stats

func get_pof_file_info(pof_file_path: String) -> Dictionary:
	"""Get basic information about POF file without full conversion"""
	
	if not FileAccess.file_exists(pof_file_path):
		return {
			"success": false,
			"error": "POF file does not exist"
		}
	
	# Use Python script to analyze POF header
	var python_command: Array[String] = [
		ProjectSettings.globalize_path(PYTHON_SCRIPT_PATH),
		"analyze",
		ProjectSettings.globalize_path(pof_file_path),
		"--quick"
	]
	
	var output: Array = []
	var exit_code: int = OS.execute("python3", python_command, output, true, true)
	
	if exit_code != 0:
		return {
			"success": false,
			"error": "Failed to analyze POF file"
		}
	
	# Parse analysis output
	var info: Dictionary = _parse_analysis_output(output)
	info["success"] = true
	info["file_size"] = FileAccess.get_file_as_bytes(pof_file_path).size()
	
	return info

func _parse_analysis_output(output: Array) -> Dictionary:
	"""Parse POF analysis output for file information"""
	
	var info: Dictionary = {
		"subobject_count": 0,
		"texture_count": 0,
		"version": 0,
		"model_name": ""
	}
	
	for line in output:
		var line_str: String = str(line).strip_edges()
		
		if line_str.begins_with("Subobjects:"):
			var parts: PackedStringArray = line_str.split(":")
			if parts.size() > 1:
				info["subobject_count"] = parts[1].strip_edges().to_int()
		
		elif line_str.begins_with("Textures:"):
			var parts: PackedStringArray = line_str.split(":")
			if parts.size() > 1:
				info["texture_count"] = parts[1].strip_edges().to_int()
		
		elif line_str.begins_with("Version:"):
			var parts: PackedStringArray = line_str.split(":")
			if parts.size() > 1:
				info["version"] = parts[1].strip_edges().to_int()
		
		elif line_str.begins_with("Model name:"):
			var parts: PackedStringArray = line_str.split(":", false, 1)
			if parts.size() > 1:
				info["model_name"] = parts[1].strip_edges()
	
	return info

func validate_pof_file(pof_file_path: String) -> Dictionary:
	"""Validate POF file format and report any issues"""
	
	var python_command: Array[String] = [
		ProjectSettings.globalize_path(PYTHON_SCRIPT_PATH),
		"validate",
		ProjectSettings.globalize_path(pof_file_path)
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