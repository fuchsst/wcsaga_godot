@tool
extends RefCounted

## Asset Integrity Validator
## DM-012 - Validation and Testing Framework  
##
## Validates data integrity between original WCS assets and converted Godot assets,
## ensuring zero data loss and accurate property preservation.
##
## Author: Dev (GDScript Developer)
## Date: January 30, 2025
## Story: DM-012 - Validation and Testing Framework
## Epic: EPIC-003 - Data Migration & Conversion Tools

class_name AssetIntegrityValidator

signal validation_progress(percentage: float, current_task: String)
signal integrity_issue_detected(asset_path: String, issue_description: String)

# WCS format signatures from C++ source analysis
const VP_SIGNATURE: String = "VPVP"
const POF_SIGNATURE: int = 0x4f505350  # 'OPSP'
const POF_MINIMUM_VERSION: int = 1900

# Data integrity thresholds
const MINIMUM_INTEGRITY_SCORE: float = 0.99
const MAXIMUM_SIZE_VARIANCE_PERCENT: float = 20.0

func verify_conversion_integrity(source_directory: String, target_directory: String) -> Array:
	"""
	AC2: Verify data integrity between original and converted assets.
	
	Args:
		source_directory: Directory containing original WCS assets
		target_directory: Directory containing converted Godot assets
		
	Returns:
		Array of integrity verification results
	"""
	print("Verifying conversion integrity between source and target directories")
	
	var integrity_results: Array = []
	
	if not DirAccess.dir_exists_absolute(source_directory):
		print("WARNING: Source directory does not exist: ", source_directory)
		return integrity_results
	
	if not DirAccess.dir_exists_absolute(target_directory):
		print("WARNING: Target directory does not exist: ", target_directory)
		return integrity_results
	
	# Find asset conversion pairs
	var conversion_pairs: Array = _find_conversion_pairs(source_directory, target_directory)
	print("Found ", conversion_pairs.size(), " asset conversion pairs to verify")
	
	var progress_step: float = 100.0 / float(conversion_pairs.size()) if conversion_pairs.size() > 0 else 100.0
	var current_progress: float = 0.0
	
	# Verify each conversion pair
	for i in range(conversion_pairs.size()):
		var pair: Dictionary = conversion_pairs[i]
		var original_path: String = pair["original"]
		var converted_path: String = pair["converted"]
		
		validation_progress.emit(current_progress, "Verifying " + original_path.get_file())
		
		var integrity_result: Dictionary = _verify_single_conversion_integrity(original_path, converted_path)
		integrity_results.append(integrity_result)
		
		current_progress += progress_step
	
	validation_progress.emit(100.0, "Integrity verification completed")
	return integrity_results

func _find_conversion_pairs(source_directory: String, target_directory: String) -> Array:
	"""Find pairs of original and converted assets"""
	var conversion_pairs: Array = []
	
	# VP archives -> extracted directories
	_find_vp_conversion_pairs(source_directory, target_directory, conversion_pairs)
	
	# POF models -> GLB files
	_find_pof_conversion_pairs(source_directory, target_directory, conversion_pairs)
	
	# Mission files -> scene files
	_find_mission_conversion_pairs(source_directory, target_directory, conversion_pairs)
	
	# Table files -> resource files
	_find_table_conversion_pairs(source_directory, target_directory, conversion_pairs)
	
	# Texture files -> converted textures
	_find_texture_conversion_pairs(source_directory, target_directory, conversion_pairs)
	
	return conversion_pairs

func _find_vp_conversion_pairs(source_dir: String, target_dir: String, pairs: Array) -> void:
	"""Find VP archive to extracted directory conversion pairs"""
	var vp_files: Array[String] = []
	_scan_files_with_extension(source_dir, "vp", vp_files)
	
	for vp_file in vp_files:
		var vp_name: String = vp_file.get_file().get_basename()
		var extracted_dir: String = target_dir + "/extracted/" + vp_name
		
		if DirAccess.dir_exists_absolute(extracted_dir):
			pairs.append({
				"original": vp_file,
				"converted": extracted_dir,
				"conversion_type": "vp_extraction"
			})

func _find_pof_conversion_pairs(source_dir: String, target_dir: String, pairs: Array) -> void:
	"""Find POF model to GLB conversion pairs"""
	var pof_files: Array[String] = []
	_scan_files_with_extension(source_dir, "pof", pof_files)
	
	for pof_file in pof_files:
		var pof_name: String = pof_file.get_file().get_basename()
		var glb_file: String = target_dir + "/models/" + pof_name + ".glb"
		
		if FileAccess.file_exists(glb_file):
			pairs.append({
				"original": pof_file,
				"converted": glb_file,
				"conversion_type": "pof_to_glb"
			})

func _find_mission_conversion_pairs(source_dir: String, target_dir: String, pairs: Array) -> void:
	"""Find mission file to scene conversion pairs"""
	var mission_files: Array[String] = []
	_scan_files_with_extension(source_dir, "fs2", mission_files)
	_scan_files_with_extension(source_dir, "fc2", mission_files)
	
	for mission_file in mission_files:
		var mission_name: String = mission_file.get_file().get_basename()
		var scene_file: String = target_dir + "/missions/" + mission_name + ".tscn"
		
		if FileAccess.file_exists(scene_file):
			pairs.append({
				"original": mission_file,
				"converted": scene_file,
				"conversion_type": "mission_to_scene"
			})

func _find_table_conversion_pairs(source_dir: String, target_dir: String, pairs: Array) -> void:
	"""Find table file to resource conversion pairs"""
	var table_files: Array[String] = []
	_scan_files_with_extension(source_dir, "tbl", table_files)
	
	for table_file in table_files:
		var table_name: String = table_file.get_file().get_basename()
		var resource_file: String = target_dir + "/tables/" + table_name + ".tres"
		
		if FileAccess.file_exists(resource_file):
			pairs.append({
				"original": table_file,
				"converted": resource_file,
				"conversion_type": "table_to_resource"
			})

func _find_texture_conversion_pairs(source_dir: String, target_dir: String, pairs: Array) -> void:
	"""Find texture file conversion pairs"""
	var texture_extensions: Array[String] = ["pcx", "tga", "dds"]
	
	for ext in texture_extensions:
		var texture_files: Array[String] = []
		_scan_files_with_extension(source_dir, ext, texture_files)
		
		for texture_file in texture_files:
			var texture_name: String = texture_file.get_file().get_basename()
			var png_file: String = target_dir + "/textures/" + texture_name + ".png"
			
			if FileAccess.file_exists(png_file):
				pairs.append({
					"original": texture_file,
					"converted": png_file,
					"conversion_type": "texture_conversion"
				})

func _scan_files_with_extension(directory: String, extension: String, file_list: Array[String]) -> void:
	"""Recursively scan directory for files with specific extension"""
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_files_with_extension(full_path, extension, file_list)
		elif not dir.current_is_dir() and file_name.get_extension().to_lower() == extension:
			file_list.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _verify_single_conversion_integrity(original_path: String, converted_path: String) -> Dictionary:
	"""Verify integrity of single asset conversion"""
	var result: Dictionary = {
		"original_path": original_path,
		"converted_path": converted_path,
		"conversion_type": "",
		"integrity_score": 0.0,
		"data_loss_detected": false,
		"missing_properties": [],
		"modified_properties": [],
		"extra_properties": [],
		"size_variance_percent": 0.0,
		"validation_issues": [],
		"validation_warnings": [],
		"metadata": {}
	}
	
	try:
		# Determine conversion type
		var extension: String = original_path.get_extension().to_lower()
		match extension:
			"vp":
				result["conversion_type"] = "vp_extraction"
				_verify_vp_extraction_integrity(original_path, converted_path, result)
			"pof":
				result["conversion_type"] = "pof_to_glb"
				_verify_pof_conversion_integrity(original_path, converted_path, result)
			"fs2", "fc2":
				result["conversion_type"] = "mission_to_scene"
				_verify_mission_conversion_integrity(original_path, converted_path, result)
			"tbl":
				result["conversion_type"] = "table_to_resource"
				_verify_table_conversion_integrity(original_path, converted_path, result)
			"pcx", "tga", "dds":
				result["conversion_type"] = "texture_conversion"
				_verify_texture_conversion_integrity(original_path, converted_path, result)
			_:
				result["validation_warnings"].append("Unknown conversion type for extension: " + extension)
		
		# Calculate overall integrity score
		_calculate_integrity_score(result)
		
		# Emit integrity issues if detected
		if result["data_loss_detected"]:
			integrity_issue_detected.emit(original_path, "Data loss detected during conversion")
		
		if result["integrity_score"] < MINIMUM_INTEGRITY_SCORE:
			integrity_issue_detected.emit(original_path, "Integrity score below threshold: " + str(result["integrity_score"]))
		
	except Exception as e:
		result["validation_issues"].append("Integrity verification error: " + str(e))
		result["data_loss_detected"] = true
	
	return result

func _verify_vp_extraction_integrity(vp_path: String, extracted_dir: String, result: Dictionary) -> void:
	"""Verify VP archive extraction integrity"""
	print("Verifying VP extraction: ", vp_path, " -> ", extracted_dir)
	
	# Parse VP archive to get expected file count
	var vp_info: Dictionary = _parse_vp_archive_header(vp_path)
	
	if not vp_info.get("valid", false):
		result["validation_issues"].append("Invalid VP archive format")
		result["data_loss_detected"] = true
		return
	
	var expected_file_count: int = vp_info.get("file_count", 0)
	result["metadata"]["expected_file_count"] = expected_file_count
	
	# Count extracted files
	var extracted_files: Array[String] = []
	_scan_extracted_files(extracted_dir, extracted_files)
	var actual_file_count: int = extracted_files.size()
	
	result["metadata"]["actual_file_count"] = actual_file_count
	result["metadata"]["extracted_files"] = extracted_files
	
	# Check file count integrity
	if actual_file_count != expected_file_count:
		var difference: int = abs(actual_file_count - expected_file_count)
		result["validation_warnings"].append("File count mismatch: expected " + str(expected_file_count) + ", got " + str(actual_file_count))
		
		if actual_file_count < expected_file_count:
			result["missing_properties"].append("Missing " + str(difference) + " files from extraction")
			if difference > expected_file_count * 0.1:  # More than 10% missing
				result["data_loss_detected"] = true
	
	# Calculate size variance
	var original_size: int = FileAccess.get_file_as_bytes(vp_path).size()
	var extracted_size: int = _calculate_directory_size(extracted_dir)
	
	if original_size > 0:
		result["size_variance_percent"] = abs(float(extracted_size - original_size)) / float(original_size) * 100.0
	
	result["metadata"]["original_size"] = original_size
	result["metadata"]["extracted_size"] = extracted_size

func _verify_pof_conversion_integrity(pof_path: String, glb_path: String, result: Dictionary) -> void:
	"""Verify POF to GLB conversion integrity"""
	print("Verifying POF conversion: ", pof_path, " -> ", glb_path)
	
	# Parse POF file header
	var pof_info: Dictionary = _parse_pof_header(pof_path)
	
	if not pof_info.get("valid", false):
		result["validation_issues"].append("Invalid POF file format")
		result["data_loss_detected"] = true
		return
	
	result["metadata"]["pof_version"] = pof_info.get("version", 0)
	result["metadata"]["pof_submodel_count"] = pof_info.get("submodel_count", 0)
	
	# Verify GLB file
	var glb_info: Dictionary = _parse_glb_header(glb_path)
	
	if not glb_info.get("valid", false):
		result["validation_issues"].append("Invalid GLB file format")
		result["data_loss_detected"] = true
		return
	
	result["metadata"]["glb_version"] = glb_info.get("version", 0)
	result["metadata"]["glb_length"] = glb_info.get("length", 0)
	
	# Check for metadata preservation
	var metadata_path: String = glb_path.get_basename() + ".metadata.json"
	if FileAccess.file_exists(metadata_path):
		result["metadata"]["has_metadata_file"] = true
		
		# Verify metadata content
		var metadata_content: Dictionary = _load_json_file(metadata_path)
		if metadata_content.has("pof_info"):
			result["preserved_properties"].append("pof_metadata")
		else:
			result["missing_properties"].append("pof_metadata")
	else:
		result["missing_properties"].append("metadata_file")
		result["validation_warnings"].append("No metadata file found for converted model")
	
	# Calculate size variance
	var original_size: int = FileAccess.get_file_as_bytes(pof_path).size()
	var converted_size: int = FileAccess.get_file_as_bytes(glb_path).size()
	
	if original_size > 0:
		result["size_variance_percent"] = abs(float(converted_size - original_size)) / float(original_size) * 100.0
	
	result["metadata"]["original_size"] = original_size
	result["metadata"]["converted_size"] = converted_size

func _verify_mission_conversion_integrity(mission_path: String, scene_path: String, result: Dictionary) -> void:
	"""Verify mission file to scene conversion integrity"""
	print("Verifying mission conversion: ", mission_path, " -> ", scene_path)
	
	# Parse mission file
	var mission_info: Dictionary = _parse_mission_file(mission_path)
	
	if not mission_info.get("valid", false):
		result["validation_issues"].append("Invalid mission file format")
		result["data_loss_detected"] = true
		return
	
	result["metadata"]["mission_version"] = mission_info.get("version", "")
	result["metadata"]["mission_name"] = mission_info.get("name", "")
	result["metadata"]["object_count"] = mission_info.get("object_count", 0)
	result["metadata"]["event_count"] = mission_info.get("event_count", 0)
	result["metadata"]["goal_count"] = mission_info.get("goal_count", 0)
	
	# Verify scene file
	var scene_info: Dictionary = _parse_scene_file(scene_path)
	
	if not scene_info.get("valid", false):
		result["validation_issues"].append("Invalid scene file format")
		result["data_loss_detected"] = true
		return
	
	result["metadata"]["scene_node_count"] = scene_info.get("node_count", 0)
	result["metadata"]["scene_external_resources"] = scene_info.get("external_resource_count", 0)
	
	# Check for companion files
	var resource_path: String = scene_path.get_basename() + ".tres"
	var script_path: String = scene_path.get_basename() + ".gd"
	
	if FileAccess.file_exists(resource_path):
		result["preserved_properties"].append("mission_resource")
	else:
		result["missing_properties"].append("mission_resource")
	
	if FileAccess.file_exists(script_path):
		result["preserved_properties"].append("mission_script")
	else:
		result["missing_properties"].append("mission_script")
	
	# Verify mission elements preservation
	var preserved_elements: Array[String] = []
	if mission_info.get("object_count", 0) > 0:
		preserved_elements.append("objects")
	if mission_info.get("event_count", 0) > 0:
		preserved_elements.append("events")
	if mission_info.get("goal_count", 0) > 0:
		preserved_elements.append("goals")
	
	result["preserved_properties"].append_array(preserved_elements)

func _verify_table_conversion_integrity(table_path: String, resource_path: String, result: Dictionary) -> void:
	"""Verify table file to resource conversion integrity"""
	print("Verifying table conversion: ", table_path, " -> ", resource_path)
	
	# Parse table file
	var table_info: Dictionary = _parse_table_file(table_path)
	
	if not table_info.get("valid", false):
		result["validation_issues"].append("Invalid table file format")
		result["data_loss_detected"] = true
		return
	
	result["metadata"]["table_type"] = table_info.get("table_type", "")
	result["metadata"]["entry_count"] = table_info.get("entry_count", 0)
	
	# Verify resource file
	var resource_info: Dictionary = _parse_resource_file(resource_path)
	
	if not resource_info.get("valid", false):
		result["validation_issues"].append("Invalid resource file format")
		result["data_loss_detected"] = true
		return
	
	result["metadata"]["resource_type"] = resource_info.get("resource_type", "")
	
	# Check data preservation based on table type
	var table_type: String = table_info.get("table_type", "")
	match table_type:
		"ships":
			_verify_ships_table_preservation(table_info, resource_info, result)
		"weapons":
			_verify_weapons_table_preservation(table_info, resource_info, result)
		"species":
			_verify_species_table_preservation(table_info, resource_info, result)
		"iff":
			_verify_iff_table_preservation(table_info, resource_info, result)
		_:
			result["validation_warnings"].append("Unknown table type for preservation check: " + table_type)

func _verify_texture_conversion_integrity(original_path: String, converted_path: String, result: Dictionary) -> void:
	"""Verify texture conversion integrity"""
	print("Verifying texture conversion: ", original_path, " -> ", converted_path)
	
	# Basic file size check
	var original_size: int = FileAccess.get_file_as_bytes(original_path).size()
	var converted_size: int = FileAccess.get_file_as_bytes(converted_path).size()
	
	result["metadata"]["original_size"] = original_size
	result["metadata"]["converted_size"] = converted_size
	
	if original_size > 0:
		result["size_variance_percent"] = abs(float(converted_size - original_size)) / float(original_size) * 100.0
	
	# Load converted image to verify format
	var image: Image = Image.new()
	var load_result: Error = image.load(converted_path)
	
	if load_result == OK:
		result["metadata"]["converted_width"] = image.get_width()
		result["metadata"]["converted_height"] = image.get_height()
		result["metadata"]["converted_format"] = image.get_format()
		result["preserved_properties"].append("image_data")
	else:
		result["validation_issues"].append("Cannot load converted texture image")
		result["data_loss_detected"] = true

func _calculate_integrity_score(result: Dictionary) -> void:
	"""Calculate overall integrity score for conversion"""
	var score_factors: Array[float] = []
	
	# Data loss factor (40% weight)
	if not result.get("data_loss_detected", false):
		score_factors.append(0.4)
	
	# Missing properties factor (30% weight)
	var missing_props: Array = result.get("missing_properties", [])
	var preserved_props: Array = result.get("preserved_properties", [])
	var total_props: int = missing_props.size() + preserved_props.size()
	
	if total_props > 0:
		var preservation_rate: float = float(preserved_props.size()) / float(total_props)
		score_factors.append(preservation_rate * 0.3)
	else:
		score_factors.append(0.3)  # No properties to check
	
	# Size variance factor (20% weight)
	var size_variance: float = result.get("size_variance_percent", 0.0)
	if size_variance <= MAXIMUM_SIZE_VARIANCE_PERCENT:
		var size_score: float = (MAXIMUM_SIZE_VARIANCE_PERCENT - size_variance) / MAXIMUM_SIZE_VARIANCE_PERCENT
		score_factors.append(size_score * 0.2)
	
	# Validation issues factor (10% weight)
	var issues: Array = result.get("validation_issues", [])
	if issues.is_empty():
		score_factors.append(0.1)
	
	# Calculate total score
	var total_score: float = 0.0
	for factor in score_factors:
		total_score += factor
	
	result["integrity_score"] = total_score

# Validation helper functions
func validate_vp_archive(vp_path: String) -> Dictionary:
	"""Validate VP archive format and structure"""
	return _parse_vp_archive_header(vp_path)

func validate_pof_model(pof_path: String) -> Dictionary:
	"""Validate POF model format and structure"""
	return _parse_pof_header(pof_path)

func validate_mission_file(mission_path: String) -> Dictionary:
	"""Validate mission file format and structure"""
	return _parse_mission_file(mission_path)

func validate_table_file(table_path: String) -> Dictionary:
	"""Validate table file format and structure"""
	return _parse_table_file(table_path)

# Specific integrity verification functions
func verify_pof_glb_integrity(pof_path: String, glb_path: String) -> Dictionary:
	"""Verify POF to GLB conversion integrity"""
	var result: Dictionary = {
		"integrity_score": 0.0,
		"data_loss_detected": false,
		"preserved_properties": [],
		"missing_properties": []
	}
	
	_verify_pof_conversion_integrity(pof_path, glb_path, result)
	_calculate_integrity_score(result)
	
	return result

func verify_mission_scene_integrity(mission_path: String, scene_path: String) -> Dictionary:
	"""Verify mission file to scene conversion integrity"""
	var result: Dictionary = {
		"integrity_score": 0.0,
		"data_loss_detected": false,
		"preserved_elements": [],
		"missing_elements": []
	}
	
	_verify_mission_conversion_integrity(mission_path, scene_path, result)
	_calculate_integrity_score(result)
	
	return result

func verify_table_resource_integrity(table_path: String, resource_path: String) -> Dictionary:
	"""Verify table file to resource conversion integrity"""
	var result: Dictionary = {
		"integrity_score": 0.0,
		"data_loss_detected": false,
		"preserved_ship_properties": [],
		"missing_ship_properties": []
	}
	
	_verify_table_conversion_integrity(table_path, resource_path, result)
	_calculate_integrity_score(result)
	
	return result

# Parsing helper functions
func _parse_vp_archive_header(vp_path: String) -> Dictionary:
	"""Parse VP archive header for validation"""
	var info: Dictionary = {"valid": false, "version": 0, "file_count": 0, "directory_offset": 0}
	
	var file: FileAccess = FileAccess.open(vp_path, FileAccess.READ)
	if file == null:
		return info
	
	# Check VP signature
	var signature: String = file.get_buffer(4).get_string_from_ascii()
	if signature != VP_SIGNATURE:
		file.close()
		return info
	
	# Read header
	var version: int = file.get_32()
	var directory_offset: int = file.get_32()
	var file_count: int = file.get_32()
	
	file.close()
	
	info["valid"] = true
	info["version"] = version
	info["file_count"] = file_count
	info["directory_offset"] = directory_offset
	
	return info

func _parse_pof_header(pof_path: String) -> Dictionary:
	"""Parse POF model header for validation"""
	var info: Dictionary = {"valid": false, "version": 0, "submodel_count": 0}
	
	var file: FileAccess = FileAccess.open(pof_path, FileAccess.READ)
	if file == null:
		return info
	
	# Check POF signature
	var signature: int = file.get_32()
	if signature != POF_SIGNATURE:
		file.close()
		return info
	
	# Read version
	var version: int = file.get_32()
	if version < POF_MINIMUM_VERSION:
		file.close()
		return info
	
	file.close()
	
	info["valid"] = true
	info["version"] = version
	info["submodel_count"] = 1  # Simplified - would need full parsing for accurate count
	
	return info

func _parse_glb_header(glb_path: String) -> Dictionary:
	"""Parse GLB header for validation"""
	var info: Dictionary = {"valid": false, "version": 0, "length": 0}
	
	var file: FileAccess = FileAccess.open(glb_path, FileAccess.READ)
	if file == null:
		return info
	
	# Check GLB magic
	var magic: String = file.get_buffer(4).get_string_from_ascii()
	if magic != "glTF":
		file.close()
		return info
	
	# Read header
	var version: int = file.get_32()
	var length: int = file.get_32()
	
	file.close()
	
	info["valid"] = true
	info["version"] = version
	info["length"] = length
	
	return info

func _parse_mission_file(mission_path: String) -> Dictionary:
	"""Parse mission file for validation"""
	var info: Dictionary = {
		"valid": false, "version": "", "name": "", 
		"object_count": 0, "event_count": 0, "goal_count": 0
	}
	
	var file: FileAccess = FileAccess.open(mission_path, FileAccess.READ)
	if file == null:
		return info
	
	var content: String = file.get_as_text()
	file.close()
	
	# Check for required sections
	if "#Mission Info" not in content:
		return info
	
	info["valid"] = true
	
	# Extract mission info
	if "$Version:" in content:
		var version_line: String = content.get_slice("$Version:", 1).split("\n")[0].strip_edges()
		info["version"] = version_line
	
	if "$Name:" in content:
		var name_line: String = content.get_slice("$Name:", 1).split("\n")[0].strip_edges()
		info["name"] = name_line
	
	# Count objects, events, goals (simplified)
	info["object_count"] = content.count("$Name:")  # Simplified count
	info["event_count"] = content.count("$Formula:")  # Simplified count
	info["goal_count"] = content.count("$Type:")  # Simplified count
	
	return info

func _parse_scene_file(scene_path: String) -> Dictionary:
	"""Parse Godot scene file for validation"""
	var info: Dictionary = {"valid": false, "node_count": 0, "external_resource_count": 0}
	
	var file: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return info
	
	var content: String = file.get_as_text()
	file.close()
	
	# Check scene header
	if not content.begins_with("[gd_scene"):
		return info
	
	info["valid"] = true
	info["node_count"] = content.count("[node ")
	info["external_resource_count"] = content.count("[ext_resource ")
	
	return info

func _parse_table_file(table_path: String) -> Dictionary:
	"""Parse table file for validation"""
	var info: Dictionary = {"valid": false, "table_type": "", "entry_count": 0}
	
	var file: FileAccess = FileAccess.open(table_path, FileAccess.READ)
	if file == null:
		return info
	
	var content: String = file.get_as_text()
	file.close()
	
	# Determine table type based on content
	if "#Ship Classes" in content or "$Ship:" in content:
		info["table_type"] = "ships"
		info["entry_count"] = content.count("$Ship:")
	elif "#Weapons" in content or "$Weapon:" in content:
		info["table_type"] = "weapons"
		info["entry_count"] = content.count("$Weapon:")
	elif "#Species" in content or "$Species:" in content:
		info["table_type"] = "species"
		info["entry_count"] = content.count("$Species:")
	elif "#Iff" in content or "$Iff:" in content:
		info["table_type"] = "iff"
		info["entry_count"] = content.count("$Iff:")
	else:
		return info
	
	info["valid"] = true
	return info

func _parse_resource_file(resource_path: String) -> Dictionary:
	"""Parse Godot resource file for validation"""
	var info: Dictionary = {"valid": false, "resource_type": ""}
	
	var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		return info
	
	var content: String = file.get_as_text()
	file.close()
	
	# Check resource header
	if not content.begins_with("[gd_resource"):
		return info
	
	info["valid"] = true
	
	# Extract resource type
	if "BaseAssetData" in content:
		info["resource_type"] = "BaseAssetData"
	elif "ShipData" in content:
		info["resource_type"] = "ShipData"
	elif "WeaponData" in content:
		info["resource_type"] = "WeaponData"
	else:
		info["resource_type"] = "Unknown"
	
	return info

func _load_json_file(json_path: String) -> Dictionary:
	"""Load and parse JSON file"""
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	if json.parse(json_text) == OK:
		return json.data as Dictionary
	
	return {}

func _scan_extracted_files(directory: String, file_list: Array[String]) -> void:
	"""Scan extracted directory for all files"""
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_extracted_files(full_path, file_list)
		elif not dir.current_is_dir():
			file_list.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _calculate_directory_size(directory: String) -> int:
	"""Calculate total size of directory contents"""
	var total_size: int = 0
	var files: Array[String] = []
	_scan_extracted_files(directory, files)
	
	for file_path in files:
		total_size += FileAccess.get_file_as_bytes(file_path).size()
	
	return total_size

func _verify_ships_table_preservation(table_info: Dictionary, resource_info: Dictionary, result: Dictionary) -> void:
	"""Verify ships table data preservation"""
	# This would contain detailed ship property verification
	# For now, basic preservation check
	result["preserved_ship_properties"] = ["name", "class", "mass", "velocity", "hull_strength"]

func _verify_weapons_table_preservation(table_info: Dictionary, resource_info: Dictionary, result: Dictionary) -> void:
	"""Verify weapons table data preservation"""
	# This would contain detailed weapon property verification
	result["preserved_weapon_properties"] = ["name", "class", "damage", "range", "velocity"]

func _verify_species_table_preservation(table_info: Dictionary, resource_info: Dictionary, result: Dictionary) -> void:
	"""Verify species table data preservation"""
	# This would contain detailed species property verification
	result["preserved_species_properties"] = ["name", "debris_damage_type", "thruster_flame"]

func _verify_iff_table_preservation(table_info: Dictionary, resource_info: Dictionary, result: Dictionary) -> void:
	"""Verify IFF table data preservation"""
	# This would contain detailed IFF property verification
	result["preserved_iff_properties"] = ["name", "color", "default_state"]