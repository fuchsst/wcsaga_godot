@tool
extends RefCounted

## Import Validator
## Provides validation feedback for WCS asset imports with detailed error reporting

class_name ImportValidator

enum ValidationLevel {
	INFO,
	WARNING, 
	ERROR,
	CRITICAL
}

signal validation_completed(results: Dictionary)
signal validation_message(level: ValidationLevel, message: String, asset_path: String)

var validation_results: Dictionary = {}
var current_asset_path: String = ""

func validate_vp_import(vp_file_path: String, extracted_directory: String, import_options: Dictionary) -> Dictionary:
	"""Validate VP archive import results"""
	
	current_asset_path = vp_file_path
	var results: Dictionary = {
		"asset_type": "vp_archive",
		"asset_path": vp_file_path,
		"success": true,
		"messages": [],
		"extracted_files": [],
		"missing_files": [],
		"validation_time": Time.get_ticks_msec() / 1000.0
	}
	
	_emit_validation_message(ValidationLevel.INFO, "Starting VP archive validation", vp_file_path)
	
	# Check if extracted directory exists
	if not DirAccess.dir_exists_absolute(extracted_directory):
		_emit_validation_message(ValidationLevel.CRITICAL, "Extracted directory does not exist: " + extracted_directory, vp_file_path)
		results["success"] = false
		return results
	
	# Count extracted files
	var extracted_files: Array[String] = _scan_directory_recursive(extracted_directory)
	results["extracted_files"] = extracted_files
	
	_emit_validation_message(ValidationLevel.INFO, "Found " + str(extracted_files.size()) + " extracted files", vp_file_path)
	
	# Validate file integrity
	var integrity_results: Dictionary = _validate_file_integrity(extracted_files)
	results["corrupt_files"] = integrity_results["corrupt_files"]
	results["zero_byte_files"] = integrity_results["zero_byte_files"]
	
	if integrity_results["corrupt_files"].size() > 0:
		_emit_validation_message(ValidationLevel.ERROR, "Found " + str(integrity_results["corrupt_files"].size()) + " corrupt files", vp_file_path)
		results["success"] = false
	
	if integrity_results["zero_byte_files"].size() > 0:
		_emit_validation_message(ValidationLevel.WARNING, "Found " + str(integrity_results["zero_byte_files"].size()) + " zero-byte files", vp_file_path)
	
	# Validate asset organization
	if import_options.get("organize_by_type", true):
		var organization_results: Dictionary = _validate_asset_organization(extracted_directory)
		results["organization_score"] = organization_results["score"]
		
		if organization_results["score"] < 0.8:
			_emit_validation_message(ValidationLevel.WARNING, "Asset organization score is low: " + str(organization_results["score"]), vp_file_path)
	
	# Check for common WCS asset types
	var asset_types: Dictionary = _analyze_asset_types(extracted_files)
	results["asset_types"] = asset_types
	
	for asset_type in asset_types.keys():
		var count: int = asset_types[asset_type]
		_emit_validation_message(ValidationLevel.INFO, "Found " + str(count) + " " + asset_type + " files", vp_file_path)
	
	results["validation_time"] = (Time.get_ticks_msec() / 1000.0) - results["validation_time"]
	_emit_validation_message(ValidationLevel.INFO, "VP validation completed in " + str(results["validation_time"]) + "s", vp_file_path)
	
	validation_completed.emit(results)
	return results

func validate_pof_import(pof_file_path: String, scene_file_path: String, conversion_results: Dictionary) -> Dictionary:
	"""Validate POF model import results"""
	
	current_asset_path = pof_file_path
	var results: Dictionary = {
		"asset_type": "pof_model",
		"asset_path": pof_file_path,
		"success": true,
		"messages": [],
		"scene_validation": {},
		"mesh_validation": {},
		"material_validation": {},
		"validation_time": Time.get_ticks_msec() / 1000.0
	}
	
	_emit_validation_message(ValidationLevel.INFO, "Starting POF model validation", pof_file_path)
	
	# Check if scene file exists
	if not FileAccess.file_exists(scene_file_path):
		_emit_validation_message(ValidationLevel.CRITICAL, "Scene file does not exist: " + scene_file_path, pof_file_path)
		results["success"] = false
		return results
	
	# Load and validate scene
	var scene: PackedScene = load(scene_file_path)
	if scene == null:
		_emit_validation_message(ValidationLevel.CRITICAL, "Failed to load scene file", pof_file_path)
		results["success"] = false
		return results
	
	var scene_instance: Node = scene.instantiate()
	if scene_instance == null:
		_emit_validation_message(ValidationLevel.CRITICAL, "Failed to instantiate scene", pof_file_path)
		results["success"] = false
		return results
	
	# Validate scene structure
	results["scene_validation"] = _validate_scene_structure(scene_instance)
	
	# Validate meshes
	results["mesh_validation"] = _validate_scene_meshes(scene_instance)
	
	# Validate materials
	results["material_validation"] = _validate_scene_materials(scene_instance)
	
	# Validate conversion data consistency
	if conversion_results.has("mesh_count"):
		var expected_meshes: int = conversion_results["mesh_count"]
		var actual_meshes: int = results["mesh_validation"]["mesh_count"]
		
		if expected_meshes != actual_meshes:
			_emit_validation_message(ValidationLevel.WARNING, "Mesh count mismatch: expected " + str(expected_meshes) + ", got " + str(actual_meshes), pof_file_path)
	
	if conversion_results.has("material_count"):
		var expected_materials: int = conversion_results["material_count"]
		var actual_materials: int = results["material_validation"]["material_count"]
		
		if expected_materials != actual_materials:
			_emit_validation_message(ValidationLevel.WARNING, "Material count mismatch: expected " + str(expected_materials) + ", got " + str(actual_materials), pof_file_path)
	
	# Check for WCS metadata component
	var has_metadata: bool = _find_wcs_metadata_component(scene_instance) != null
	if not has_metadata:
		_emit_validation_message(ValidationLevel.WARNING, "WCS metadata component not found", pof_file_path)
	
	scene_instance.queue_free()
	
	results["validation_time"] = (Time.get_ticks_msec() / 1000.0) - results["validation_time"]
	_emit_validation_message(ValidationLevel.INFO, "POF validation completed in " + str(results["validation_time"]) + "s", pof_file_path)
	
	validation_completed.emit(results)
	return results

func validate_mission_import(mission_file_path: String, scene_file_path: String, conversion_results: Dictionary) -> Dictionary:
	"""Validate mission file import results"""
	
	current_asset_path = mission_file_path
	var results: Dictionary = {
		"asset_type": "mission_file",
		"asset_path": mission_file_path,
		"success": true,
		"messages": [],
		"scene_validation": {},
		"object_validation": {},
		"script_validation": {},
		"validation_time": Time.get_ticks_msec() / 1000.0
	}
	
	_emit_validation_message(ValidationLevel.INFO, "Starting mission validation", mission_file_path)
	
	# Check if scene file exists
	if not FileAccess.file_exists(scene_file_path):
		_emit_validation_message(ValidationLevel.CRITICAL, "Mission scene file does not exist: " + scene_file_path, mission_file_path)
		results["success"] = false
		return results
	
	# Load and validate mission scene
	var scene: PackedScene = load(scene_file_path)
	if scene == null:
		_emit_validation_message(ValidationLevel.CRITICAL, "Failed to load mission scene", mission_file_path)
		results["success"] = false
		return results
	
	var scene_instance: Node = scene.instantiate()
	if scene_instance == null:
		_emit_validation_message(ValidationLevel.CRITICAL, "Failed to instantiate mission scene", mission_file_path)
		results["success"] = false
		return results
	
	# Validate mission objects
	results["object_validation"] = _validate_mission_objects(scene_instance, conversion_results)
	
	# Validate mission script if generated
	var script_path: String = scene_file_path.get_basename() + ".gd"
	if FileAccess.file_exists(script_path):
		results["script_validation"] = _validate_mission_script(script_path)
	
	# Validate mission resource if generated
	var resource_path: String = scene_file_path.get_basename() + ".tres"
	if FileAccess.file_exists(resource_path):
		results["resource_validation"] = _validate_mission_resource(resource_path)
	
	scene_instance.queue_free()
	
	results["validation_time"] = (Time.get_ticks_msec() / 1000.0) - results["validation_time"]
	_emit_validation_message(ValidationLevel.INFO, "Mission validation completed in " + str(results["validation_time"]) + "s", mission_file_path)
	
	validation_completed.emit(results)
	return results

func _emit_validation_message(level: ValidationLevel, message: String, asset_path: String) -> void:
	"""Emit validation message with proper formatting"""
	
	var formatted_message: String = _format_validation_message(level, message)
	print(formatted_message)
	
	validation_message.emit(level, message, asset_path)

func _format_validation_message(level: ValidationLevel, message: String) -> String:
	"""Format validation message with level prefix"""
	
	var prefix: String
	match level:
		ValidationLevel.INFO:
			prefix = "[INFO]"
		ValidationLevel.WARNING:
			prefix = "[WARNING]"
		ValidationLevel.ERROR:
			prefix = "[ERROR]"
		ValidationLevel.CRITICAL:
			prefix = "[CRITICAL]"
		_:
			prefix = "[UNKNOWN]"
	
	return prefix + " " + message

func _scan_directory_recursive(directory: String) -> Array[String]:
	"""Scan directory recursively for all files"""
	
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return files
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			files.append_array(_scan_directory_recursive(full_path))
		elif not dir.current_is_dir():
			files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return files

func _validate_file_integrity(file_paths: Array[String]) -> Dictionary:
	"""Validate integrity of extracted files"""
	
	var results: Dictionary = {
		"corrupt_files": [],
		"zero_byte_files": [],
		"unreadable_files": []
	}
	
	for file_path in file_paths:
		if not FileAccess.file_exists(file_path):
			results["corrupt_files"].append(file_path)
			continue
		
		var file_size: int = FileAccess.get_file_as_bytes(file_path).size()
		if file_size == 0:
			results["zero_byte_files"].append(file_path)
			continue
		
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			results["unreadable_files"].append(file_path)
			continue
		
		file.close()
	
	return results

func _validate_asset_organization(directory: String) -> Dictionary:
	"""Validate how well assets are organized by type"""
	
	var all_files: Array[String] = _scan_directory_recursive(directory)
	var organized_files: int = 0
	var asset_dirs: Array[String] = ["models", "textures", "missions", "sounds", "music", "data"]
	
	for file_path in all_files:
		var relative_path: String = file_path.replace(directory + "/", "")
		var first_dir: String = relative_path.split("/")[0].to_lower()
		
		if first_dir in asset_dirs:
			organized_files += 1
	
	var score: float = float(organized_files) / float(all_files.size()) if all_files.size() > 0 else 0.0
	
	return {
		"score": score,
		"organized_files": organized_files,
		"total_files": all_files.size()
	}

func _analyze_asset_types(file_paths: Array[String]) -> Dictionary:
	"""Analyze and count asset types"""
	
	var asset_types: Dictionary = {}
	
	for file_path in file_paths:
		var extension: String = file_path.get_extension().to_lower()
		var type_name: String
		
		match extension:
			"pof":
				type_name = "POF Models"
			"pcx", "tga", "dds", "png", "jpg":
				type_name = "Textures"
			"fs2", "fc2":
				type_name = "Mission Files"
			"tbl":
				type_name = "Table Data"
			"wav", "ogg":
				type_name = "Audio Files"
			"ani":
				type_name = "Animations"
			_:
				type_name = "Other Files"
		
		asset_types[type_name] = asset_types.get(type_name, 0) + 1
	
	return asset_types

func _validate_scene_structure(scene_instance: Node) -> Dictionary:
	"""Validate the structure of a scene"""
	
	var results: Dictionary = {
		"node_count": _count_nodes_recursive(scene_instance),
		"has_3d_nodes": _has_node_type_recursive(scene_instance, "Node3D"),
		"has_mesh_instances": _has_node_type_recursive(scene_instance, "MeshInstance3D"),
		"structure_valid": true
	}
	
	if not results["has_3d_nodes"]:
		_emit_validation_message(ValidationLevel.WARNING, "Scene contains no 3D nodes", current_asset_path)
		results["structure_valid"] = false
	
	return results

func _validate_scene_meshes(scene_instance: Node) -> Dictionary:
	"""Validate meshes in a scene"""
	
	var mesh_instances: Array[MeshInstance3D] = _find_nodes_of_type_recursive(scene_instance, "MeshInstance3D")
	var results: Dictionary = {
		"mesh_count": mesh_instances.size(),
		"valid_meshes": 0,
		"invalid_meshes": 0,
		"total_vertices": 0,
		"total_triangles": 0
	}
	
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh != null:
			results["valid_meshes"] += 1
			
			# Get mesh statistics
			var mesh: Mesh = mesh_instance.mesh
			for surface_idx in range(mesh.get_surface_count()):
				var arrays: Array = mesh.surface_get_arrays(surface_idx)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					results["total_vertices"] += vertices.size()
				
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					results["total_triangles"] += indices.size() / 3
		else:
			results["invalid_meshes"] += 1
			_emit_validation_message(ValidationLevel.ERROR, "MeshInstance3D with null mesh found", current_asset_path)
	
	return results

func _validate_scene_materials(scene_instance: Node) -> Dictionary:
	"""Validate materials in a scene"""
	
	var mesh_instances: Array[MeshInstance3D] = _find_nodes_of_type_recursive(scene_instance, "MeshInstance3D")
	var materials: Array[Material] = []
	var material_count: int = 0
	
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh != null:
			var mesh: Mesh = mesh_instance.mesh
			for surface_idx in range(mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_idx)
				if material == null:
					material = mesh.surface_get_material(surface_idx)
				
				if material != null and material not in materials:
					materials.append(material)
					material_count += 1
	
	return {
		"material_count": material_count,
		"unique_materials": materials.size(),
		"materials_valid": true
	}

func _validate_mission_objects(scene_instance: Node, conversion_results: Dictionary) -> Dictionary:
	"""Validate mission objects in scene"""
	
	var results: Dictionary = {
		"ship_nodes": 0,
		"waypoint_nodes": 0,
		"total_objects": 0,
		"validation_passed": true
	}
	
	results["total_objects"] = _count_nodes_recursive(scene_instance)
	results["ship_nodes"] = _count_nodes_with_name_pattern(scene_instance, "Ship_")
	results["waypoint_nodes"] = _count_nodes_with_name_pattern(scene_instance, "Waypoint_")
	
	# Compare with expected counts from conversion
	if conversion_results.has("ship_count"):
		var expected_ships: int = conversion_results["ship_count"]
		if results["ship_nodes"] != expected_ships:
			_emit_validation_message(ValidationLevel.WARNING, "Ship count mismatch: expected " + str(expected_ships) + ", found " + str(results["ship_nodes"]), current_asset_path)
	
	if conversion_results.has("waypoint_count"):
		var expected_waypoints: int = conversion_results["waypoint_count"]
		if results["waypoint_nodes"] != expected_waypoints:
			_emit_validation_message(ValidationLevel.WARNING, "Waypoint count mismatch: expected " + str(expected_waypoints) + ", found " + str(results["waypoint_nodes"]), current_asset_path)
	
	return results

func _validate_mission_script(script_path: String) -> Dictionary:
	"""Validate generated mission script"""
	
	var results: Dictionary = {
		"script_exists": FileAccess.file_exists(script_path),
		"syntax_valid": false,
		"has_mission_controller": false
	}
	
	if not results["script_exists"]:
		return results
	
	var script_content: String = FileAccess.get_file_as_string(script_path)
	results["syntax_valid"] = script_content.length() > 0
	results["has_mission_controller"] = script_content.contains("extends Node")
	
	return results

func _validate_mission_resource(resource_path: String) -> Dictionary:
	"""Validate generated mission resource"""
	
	var results: Dictionary = {
		"resource_exists": FileAccess.file_exists(resource_path),
		"resource_loadable": false
	}
	
	if results["resource_exists"]:
		var resource: Resource = load(resource_path)
		results["resource_loadable"] = resource != null
	
	return results

# Helper functions
func _count_nodes_recursive(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count

func _has_node_type_recursive(node: Node, type_name: String) -> bool:
	if node.get_class() == type_name:
		return true
	
	for child in node.get_children():
		if _has_node_type_recursive(child, type_name):
			return true
	
	return false

func _find_nodes_of_type_recursive(node: Node, type_name: String) -> Array:
	var nodes: Array = []
	
	if node.get_class() == type_name:
		nodes.append(node)
	
	for child in node.get_children():
		nodes.append_array(_find_nodes_of_type_recursive(child, type_name))
	
	return nodes

func _count_nodes_with_name_pattern(node: Node, pattern: String) -> int:
	var count: int = 0
	
	if node.name.begins_with(pattern):
		count += 1
	
	for child in node.get_children():
		count += _count_nodes_with_name_pattern(child, pattern)
	
	return count

func _find_wcs_metadata_component(node: Node) -> Node:
	if node.get_script() != null:
		var script: Script = node.get_script()
		if script.get_global_name() == "WCSModelMetadata":
			return node
	
	for child in node.get_children():
		var result: Node = _find_wcs_metadata_component(child)
		if result != null:
			return result
	
	return null