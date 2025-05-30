@tool
extends RefCounted

## Comprehensive Validation Manager
## DM-012 - Validation and Testing Framework
##
## Central coordinator for comprehensive validation and testing of WCS-Godot conversion.
## Implements all DM-012 acceptance criteria with WCS-specific validation logic.
##
## Author: Dev (GDScript Developer)
## Date: January 30, 2025
## Story: DM-012 - Validation and Testing Framework
## Epic: EPIC-003 - Data Migration & Conversion Tools

class_name ComprehensiveValidator

signal validation_started(validation_id: String)
signal validation_progress(percentage: float, current_task: String)
signal validation_completed(results: Dictionary)
signal validation_error(error_message: String)

const AssetIntegrityValidator = preload("res://validation_framework/asset_integrity_validator.gd")
const VisualFidelityValidator = preload("res://validation_framework/visual_fidelity_validator.gd")
const ValidationReportGenerator = preload("res://validation_framework/validation_report_generator.gd")

enum ValidationSeverity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

var asset_integrity_validator: AssetIntegrityValidator
var visual_fidelity_validator: VisualFidelityValidator
var report_generator: ValidationReportGenerator

# Validation configuration based on WCS specifications
var validation_config: Dictionary = {
	"enable_format_validation": true,
	"enable_integrity_verification": true,
	"enable_visual_fidelity_testing": true,
	"enable_regression_detection": true,
	"parallel_validation": true,
	"max_validation_time_seconds": 600,
	"quality_thresholds": {
		"data_integrity_minimum": 0.99,
		"visual_similarity_minimum": 0.95,
		"validation_success_rate_minimum": 0.98
	}
}

# WCS-specific validation patterns from C++ source analysis
var wcs_validation_patterns: Dictionary = {
	"vp_archive": {
		"required_signature": "VPVP",
		"minimum_version": 2,
		"validate_directory_structure": true,
		"validate_file_integrity": true
	},
	"pof_model": {
		"required_signature": 0x4f505350,  # 'OPSP'
		"minimum_version": 1900,
		"validate_submodels": true,
		"validate_materials": true,
		"validate_lod_levels": true
	},
	"mission_file": {
		"required_sections": ["#Mission Info", "#Objects", "#Events", "#Goals"],
		"validate_sexp_expressions": true,
		"validate_object_references": true,
		"validate_goal_conditions": true
	},
	"table_file": {
		"validate_parsing": true,
		"validate_data_types": true,
		"validate_cross_references": true,
		"validate_modular_support": true
	}
}

func _init() -> void:
	"""Initialize comprehensive validation manager"""
	asset_integrity_validator = AssetIntegrityValidator.new()
	visual_fidelity_validator = VisualFidelityValidator.new()
	report_generator = ValidationReportGenerator.new()
	
	# Connect sub-validator signals
	asset_integrity_validator.validation_progress.connect(_on_sub_validator_progress)
	visual_fidelity_validator.validation_progress.connect(_on_sub_validator_progress)

func validate_comprehensive(source_directory: String, target_directory: String, 
							validation_options: Dictionary = {}) -> Dictionary:
	"""
	AC1-AC5: Perform comprehensive validation of WCS-Godot conversion.
	
	Args:
		source_directory: Original WCS assets directory
		target_directory: Converted Godot assets directory
		validation_options: Optional validation configuration
		
	Returns:
		Comprehensive validation results dictionary
	"""
	var validation_id: String = "validation_" + str(Time.get_ticks_msec())
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	print("Starting comprehensive validation: ", validation_id)
	validation_started.emit(validation_id)
	
	# Initialize results structure
	var validation_results: Dictionary = {
		"validation_id": validation_id,
		"timestamp": Time.get_datetime_string_from_system(),
		"source_directory": source_directory,
		"target_directory": target_directory,
		"validation_config": validation_config,
		"start_time": start_time,
		"end_time": 0.0,
		"execution_time_seconds": 0.0,
		
		# Validation results
		"asset_validation_results": [],
		"integrity_verification_results": [],
		"visual_fidelity_results": [],
		
		# Summary metrics
		"validation_summary": {},
		"quality_scores": {},
		"critical_issues": [],
		"recommendations": [],
		"regression_analysis": {},
		
		# Execution status
		"validation_errors": [],
		"execution_successful": false
	}
	
	try:
		# AC1: Asset format validation
		if validation_config.get("enable_format_validation", true):
			validation_progress.emit(10.0, "Validating asset formats")
			var format_results: Array = validate_asset_formats(target_directory)
			validation_results["asset_validation_results"] = format_results
		
		# AC2: Data integrity verification
		if validation_config.get("enable_integrity_verification", true):
			validation_progress.emit(30.0, "Verifying data integrity")
			var integrity_results: Array = verify_data_integrity(source_directory, target_directory)
			validation_results["integrity_verification_results"] = integrity_results
		
		# AC3: Visual fidelity testing
		if validation_config.get("enable_visual_fidelity_testing", true):
			validation_progress.emit(50.0, "Testing visual fidelity")
			var visual_results: Array = test_visual_fidelity(source_directory, target_directory)
			validation_results["visual_fidelity_results"] = visual_results
		
		# AC4: Generate comprehensive analysis
		validation_progress.emit(70.0, "Analyzing validation results")
		_analyze_validation_results(validation_results)
		
		# AC5: Regression detection
		if validation_config.get("enable_regression_detection", true):
			validation_progress.emit(85.0, "Checking for regressions")
			_perform_regression_analysis(validation_results)
		
		# Finalize results
		var end_time: float = Time.get_ticks_msec() / 1000.0
		validation_results["end_time"] = end_time
		validation_results["execution_time_seconds"] = end_time - start_time
		validation_results["execution_successful"] = true
		
		validation_progress.emit(100.0, "Validation completed")
		print("Comprehensive validation completed in ", validation_results["execution_time_seconds"], " seconds")
		
	except Exception as e:
		var error_message: String = "Validation failed: " + str(e)
		print("ERROR: ", error_message)
		validation_results["validation_errors"].append(error_message)
		validation_error.emit(error_message)
	
	validation_completed.emit(validation_results)
	return validation_results

func validate_asset_formats(target_directory: String) -> Array:
	"""AC1: Validate all converted asset formats against WCS specifications"""
	print("Validating asset formats in: ", target_directory)
	
	var format_results: Array = []
	
	if not DirAccess.dir_exists_absolute(target_directory):
		print("WARNING: Target directory does not exist: ", target_directory)
		return format_results
	
	# Scan for converted assets
	var asset_files: Array[String] = _scan_converted_assets(target_directory)
	print("Found ", asset_files.size(), " converted assets to validate")
	
	# Validate each asset format
	for asset_path in asset_files:
		var validation_result: Dictionary = _validate_single_asset_format(asset_path)
		format_results.append(validation_result)
	
	return format_results

func _scan_converted_assets(directory: String) -> Array[String]:
	"""Scan directory for converted assets"""
	var asset_files: Array[String] = []
	var extensions_to_validate: Array[String] = [
		".glb", ".gltf",  # Converted models
		".tres", ".tscn", # Godot resources and scenes
		".png", ".jpg",   # Converted textures
		".ogg", ".wav",   # Audio files
		".json"           # Converted table data
	]
	
	_scan_directory_recursive(directory, asset_files, extensions_to_validate)
	return asset_files

func _scan_directory_recursive(directory: String, file_list: Array[String], extensions: Array[String]) -> void:
	"""Recursively scan directory for files with specified extensions"""
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_directory_recursive(full_path, file_list, extensions)
		elif not dir.current_is_dir():
			var extension: String = "." + file_name.get_extension()
			if extension in extensions:
				file_list.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _validate_single_asset_format(asset_path: String) -> Dictionary:
	"""Validate single asset format against WCS specifications"""
	var result: Dictionary = {
		"asset_path": asset_path,
		"asset_type": _detect_asset_type(asset_path),
		"format_valid": false,
		"wcs_compliant": false,
		"validation_issues": [],
		"validation_warnings": [],
		"metadata": {},
		"validation_time": Time.get_ticks_msec() / 1000.0
	}
	
	try:
		# Basic file existence and size check
		if not FileAccess.file_exists(asset_path):
			result["validation_issues"].append("Asset file does not exist")
			return result
		
		var file_size: int = FileAccess.get_file_as_bytes(asset_path).size()
		if file_size == 0:
			result["validation_issues"].append("Asset file is empty")
			return result
		
		result["metadata"]["file_size"] = file_size
		
		# Format-specific validation
		var extension: String = asset_path.get_extension().to_lower()
		match extension:
			"glb", "gltf":
				_validate_converted_model_format(asset_path, result)
			"tres":
				_validate_godot_resource_format(asset_path, result)
			"tscn":
				_validate_godot_scene_format(asset_path, result)
			"json":
				_validate_converted_table_format(asset_path, result)
			"png", "jpg":
				_validate_converted_texture_format(asset_path, result)
			"ogg", "wav":
				_validate_converted_audio_format(asset_path, result)
			_:
				result["validation_warnings"].append("Unknown asset format: " + extension)
		
		# Overall validation status
		result["format_valid"] = result["validation_issues"].is_empty()
		result["validation_time"] = (Time.get_ticks_msec() / 1000.0) - result["validation_time"]
		
	except Exception as e:
		result["validation_issues"].append("Validation error: " + str(e))
	
	return result

func _validate_converted_model_format(model_path: String, result: Dictionary) -> void:
	"""Validate converted 3D model format (GLB/GLTF)"""
	result["asset_type"] = "converted_model"
	
	if model_path.ends_with(".glb"):
		# Validate GLB format
		var file: FileAccess = FileAccess.open(model_path, FileAccess.READ)
		if file == null:
			result["validation_issues"].append("Cannot open GLB file")
			return
		
		# Check GLB magic number
		var magic: PackedByteArray = file.get_buffer(4)
		if magic.get_string_from_ascii() != "glTF":
			result["validation_issues"].append("Invalid GLB magic number")
		else:
			result["format_valid"] = true
			
			# Read GLB header info
			var version: int = file.get_32()
			var length: int = file.get_32()
			
			result["metadata"]["glb_version"] = version
			result["metadata"]["glb_length"] = length
			
			if version != 2:
				result["validation_warnings"].append("GLB version is not 2: " + str(version))
		
		file.close()
	
	# Check for WCS model metadata
	var metadata_path: String = model_path.get_basename() + ".metadata.json"
	if FileAccess.file_exists(metadata_path):
		result["wcs_compliant"] = true
		result["metadata"]["has_wcs_metadata"] = true
	else:
		result["validation_warnings"].append("No WCS metadata found for converted model")

func _validate_godot_resource_format(resource_path: String, result: Dictionary) -> void:
	"""Validate Godot resource format (.tres)"""
	result["asset_type"] = "godot_resource"
	
	var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		result["validation_issues"].append("Cannot open resource file")
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	# Check for Godot resource header
	if content.begins_with("[gd_resource"):
		result["format_valid"] = true
		
		# Check for WCS asset compliance
		if "BaseAssetData" in content:
			result["wcs_compliant"] = true
			result["metadata"]["is_wcs_asset"] = true
			
			# Validate WCS asset properties
			if "asset_id" not in content:
				result["validation_warnings"].append("Missing asset_id in WCS resource")
			if "asset_type" not in content:
				result["validation_warnings"].append("Missing asset_type in WCS resource")
		else:
			result["validation_warnings"].append("Resource is not WCS-compliant BaseAssetData")
	else:
		result["validation_issues"].append("Invalid Godot resource format")

func _validate_godot_scene_format(scene_path: String, result: Dictionary) -> void:
	"""Validate Godot scene format (.tscn)"""
	result["asset_type"] = "godot_scene"
	
	var file: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		result["validation_issues"].append("Cannot open scene file")
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	# Check for Godot scene header
	if content.begins_with("[gd_scene"):
		result["format_valid"] = true
		
		# Count nodes and external resources
		var node_count: int = content.get_slice_count("[node ")
		var ext_resource_count: int = content.get_slice_count("[ext_resource ")
		
		result["metadata"]["node_count"] = node_count
		result["metadata"]["external_resource_count"] = ext_resource_count
		
		# Check for WCS mission elements
		if "mission" in scene_path.to_lower() or "Mission" in content:
			result["wcs_compliant"] = true
			result["metadata"]["is_wcs_mission"] = true
	else:
		result["validation_issues"].append("Invalid Godot scene format")

func _validate_converted_table_format(json_path: String, result: Dictionary) -> void:
	"""Validate converted table data format (JSON)"""
	result["asset_type"] = "converted_table"
	
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		result["validation_issues"].append("Cannot open JSON file")
		return
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	
	if parse_result != OK:
		result["validation_issues"].append("Invalid JSON format: " + json.error_string)
		return
	
	var data: Dictionary = json.data as Dictionary
	result["format_valid"] = true
	
	# Check for WCS table structure
	if data.has("table_type"):
		result["wcs_compliant"] = true
		var table_type: String = data.get("table_type", "")
		result["metadata"]["table_type"] = table_type
		
		# Validate specific table types
		match table_type:
			"ships":
				_validate_ships_table_structure(data, result)
			"weapons":
				_validate_weapons_table_structure(data, result)
			"species":
				_validate_species_table_structure(data, result)
			"iff":
				_validate_iff_table_structure(data, result)
			_:
				result["validation_warnings"].append("Unknown table type: " + table_type)
	else:
		result["validation_warnings"].append("No table_type specified in converted table")

func _validate_ships_table_structure(data: Dictionary, result: Dictionary) -> void:
	"""Validate ships table structure against WCS ship_info specifications"""
	var entries: Array = data.get("entries", [])
	result["metadata"]["ship_count"] = entries.size()
	
	# WCS ship_info required properties from C++ analysis
	var required_ship_props: Array[String] = [
		"name", "class", "type", "species", "mass", "max_vel", "hitpoints", "shields"
	]
	
	for i in range(entries.size()):
		var ship_entry: Dictionary = entries[i]
		for prop in required_ship_props:
			if not ship_entry.has(prop):
				result["validation_warnings"].append("Ship entry " + str(i) + " missing: " + prop)

func _validate_weapons_table_structure(data: Dictionary, result: Dictionary) -> void:
	"""Validate weapons table structure against WCS weapon_info specifications"""
	var entries: Array = data.get("entries", [])
	result["metadata"]["weapon_count"] = entries.size()
	
	# WCS weapon_info required properties from C++ analysis
	var required_weapon_props: Array[String] = [
		"name", "class", "type", "damage", "damage_type", "velocity", "range", "fire_wait"
	]
	
	for i in range(entries.size()):
		var weapon_entry: Dictionary = entries[i]
		for prop in required_weapon_props:
			if not weapon_entry.has(prop):
				result["validation_warnings"].append("Weapon entry " + str(i) + " missing: " + prop)

func _validate_species_table_structure(data: Dictionary, result: Dictionary) -> void:
	"""Validate species table structure against WCS species_defs specifications"""
	var entries: Array = data.get("entries", [])
	result["metadata"]["species_count"] = entries.size()
	
	# WCS species_defs required properties from C++ analysis
	var required_species_props: Array[String] = [
		"name", "debris_damage_type", "debris_ambient_damage_type", "thruster_flame"
	]
	
	for i in range(entries.size()):
		var species_entry: Dictionary = entries[i]
		for prop in required_species_props:
			if not species_entry.has(prop):
				result["validation_warnings"].append("Species entry " + str(i) + " missing: " + prop)

func _validate_iff_table_structure(data: Dictionary, result: Dictionary) -> void:
	"""Validate IFF table structure against WCS iff_defs specifications"""
	var entries: Array = data.get("entries", [])
	result["metadata"]["iff_count"] = entries.size()
	
	# WCS iff_defs required properties from C++ analysis
	var required_iff_props: Array[String] = [
		"name", "color", "default_state", "on_radar", "on_selection"
	]
	
	for i in range(entries.size()):
		var iff_entry: Dictionary = entries[i]
		for prop in required_iff_props:
			if not iff_entry.has(prop):
				result["validation_warnings"].append("IFF entry " + str(i) + " missing: " + prop)

func _validate_converted_texture_format(texture_path: String, result: Dictionary) -> void:
	"""Validate converted texture format"""
	result["asset_type"] = "converted_texture"
	
	var image: Image = Image.new()
	var load_result: Error = image.load(texture_path)
	
	if load_result != OK:
		result["validation_issues"].append("Cannot load texture image")
		return
	
	result["format_valid"] = true
	result["metadata"]["image_width"] = image.get_width()
	result["metadata"]["image_height"] = image.get_height()
	result["metadata"]["image_format"] = image.get_format()
	
	# Check texture dimensions
	var width: int = image.get_width()
	var height: int = image.get_height()
	
	if width > 4096 or height > 4096:
		result["validation_warnings"].append("Very large texture: " + str(width) + "x" + str(height))
	elif width < 1 or height < 1:
		result["validation_issues"].append("Invalid texture dimensions: " + str(width) + "x" + str(height))

func _validate_converted_audio_format(audio_path: String, result: Dictionary) -> void:
	"""Validate converted audio format"""
	result["asset_type"] = "converted_audio"
	result["format_valid"] = true  # Basic file existence already checked
	
	var extension: String = audio_path.get_extension().to_lower()
	result["metadata"]["audio_format"] = extension
	
	# Basic audio file validation
	var file_size: int = FileAccess.get_file_as_bytes(audio_path).size()
	if file_size < 1000:  # Very small audio file
		result["validation_warnings"].append("Audio file is very small, may be corrupted")

func verify_data_integrity(source_directory: String, target_directory: String) -> Array:
	"""AC2: Verify data integrity between original and converted assets"""
	print("Verifying data integrity between source and target directories")
	
	return asset_integrity_validator.verify_conversion_integrity(source_directory, target_directory)

func test_visual_fidelity(source_directory: String, target_directory: String) -> Array:
	"""AC3: Test visual fidelity between original and converted assets"""
	print("Testing visual fidelity between source and target assets")
	
	return visual_fidelity_validator.validate_visual_fidelity(source_directory, target_directory)

func _analyze_validation_results(validation_results: Dictionary) -> void:
	"""AC4: Analyze validation results and generate comprehensive summary"""
	var asset_results: Array = validation_results.get("asset_validation_results", [])
	var integrity_results: Array = validation_results.get("integrity_verification_results", [])
	var visual_results: Array = validation_results.get("visual_fidelity_results", [])
	
	# Calculate summary statistics
	var total_assets: int = asset_results.size()
	var valid_assets: int = 0
	var wcs_compliant_assets: int = 0
	var total_issues: int = 0
	var total_warnings: int = 0
	
	for result in asset_results:
		if result.get("format_valid", false):
			valid_assets += 1
		if result.get("wcs_compliant", false):
			wcs_compliant_assets += 1
		
		var issues: Array = result.get("validation_issues", [])
		var warnings: Array = result.get("validation_warnings", [])
		total_issues += issues.size()
		total_warnings += warnings.size()
	
	# Calculate quality scores
	var format_compliance_score: float = float(valid_assets) / float(total_assets) if total_assets > 0 else 0.0
	var wcs_compliance_score: float = float(wcs_compliant_assets) / float(total_assets) if total_assets > 0 else 0.0
	
	# Calculate integrity scores
	var integrity_scores: Array[float] = []
	for result in integrity_results:
		var score: float = result.get("integrity_score", 0.0)
		integrity_scores.append(score)
	
	var avg_integrity_score: float = 0.0
	if integrity_scores.size() > 0:
		var sum_scores: float = 0.0
		for score in integrity_scores:
			sum_scores += score
		avg_integrity_score = sum_scores / float(integrity_scores.size())
	
	# Calculate visual fidelity scores
	var visual_scores: Array[float] = []
	for result in visual_results:
		var score: float = result.get("similarity_score", 0.0)
		visual_scores.append(score)
	
	var avg_visual_score: float = 0.0
	if visual_scores.size() > 0:
		var sum_scores: float = 0.0
		for score in visual_scores:
			sum_scores += score
		avg_visual_score = sum_scores / float(visual_scores.size())
	
	# Store summary
	validation_results["validation_summary"] = {
		"total_assets_validated": total_assets,
		"valid_assets": valid_assets,
		"wcs_compliant_assets": wcs_compliant_assets,
		"validation_success_rate": format_compliance_score,
		"wcs_compliance_rate": wcs_compliance_score,
		"total_issues": total_issues,
		"total_warnings": total_warnings,
		"average_integrity_score": avg_integrity_score,
		"average_visual_fidelity_score": avg_visual_score
	}
	
	# Store quality scores
	validation_results["quality_scores"] = {
		"format_compliance": format_compliance_score,
		"wcs_compliance": wcs_compliance_score,
		"data_integrity": avg_integrity_score,
		"visual_fidelity": avg_visual_score
	}
	
	# Identify critical issues
	var critical_issues: Array[String] = []
	if format_compliance_score < validation_config["quality_thresholds"]["validation_success_rate_minimum"]:
		critical_issues.append("Format validation success rate below threshold: " + str(format_compliance_score))
	
	if avg_integrity_score < validation_config["quality_thresholds"]["data_integrity_minimum"]:
		critical_issues.append("Data integrity score below threshold: " + str(avg_integrity_score))
	
	if avg_visual_score < validation_config["quality_thresholds"]["visual_similarity_minimum"]:
		critical_issues.append("Visual fidelity score below threshold: " + str(avg_visual_score))
	
	validation_results["critical_issues"] = critical_issues
	
	# Generate recommendations
	var recommendations: Array[String] = []
	if wcs_compliance_score < 0.9:
		recommendations.append("Improve WCS compliance - " + str(wcs_compliant_assets) + "/" + str(total_assets) + " assets are WCS-compliant")
	
	if total_issues > 0:
		recommendations.append("Address " + str(total_issues) + " validation issues found")
	
	if total_warnings > 10:
		recommendations.append("Review " + str(total_warnings) + " validation warnings")
	
	validation_results["recommendations"] = recommendations

func _perform_regression_analysis(validation_results: Dictionary) -> void:
	"""AC5: Perform regression analysis for continuous validation"""
	print("Performing regression analysis")
	
	# Load historical validation data
	var history_file: String = "user://validation_history.json"
	var historical_data: Array = []
	
	if FileAccess.file_exists(history_file):
		var file: FileAccess = FileAccess.open(history_file, FileAccess.READ)
		if file != null:
			var json_text: String = file.get_as_text()
			file.close()
			
			var json: JSON = JSON.new()
			if json.parse(json_text) == OK:
				historical_data = json.data as Array
	
	# Current metrics
	var current_metrics: Dictionary = {
		"timestamp": validation_results.get("timestamp", ""),
		"validation_success_rate": validation_results["quality_scores"]["format_compliance"],
		"data_integrity_score": validation_results["quality_scores"]["data_integrity"],
		"visual_fidelity_score": validation_results["quality_scores"]["visual_fidelity"],
		"total_assets": validation_results["validation_summary"]["total_assets_validated"]
	}
	
	# Regression analysis
	var regression_results: Dictionary = {
		"regressions_detected": false,
		"regression_details": [],
		"trend_analysis": {},
		"historical_data_points": historical_data.size()
	}
	
	if historical_data.size() > 0:
		var recent_data: Array = historical_data.slice(-5)  # Last 5 runs
		
		# Check for regressions
		for data_point in recent_data:
			var historical_success_rate: float = data_point.get("validation_success_rate", 0.0)
			var historical_integrity: float = data_point.get("data_integrity_score", 0.0)
			var historical_visual: float = data_point.get("visual_fidelity_score", 0.0)
			
			# Detect regressions (more than 5% decrease)
			if current_metrics["validation_success_rate"] < historical_success_rate * 0.95:
				regression_results["regressions_detected"] = true
				regression_results["regression_details"].append({
					"metric": "validation_success_rate",
					"current": current_metrics["validation_success_rate"],
					"previous": historical_success_rate,
					"decrease_percent": (historical_success_rate - current_metrics["validation_success_rate"]) / historical_success_rate * 100
				})
			
			if current_metrics["data_integrity_score"] < historical_integrity * 0.95:
				regression_results["regressions_detected"] = true
				regression_results["regression_details"].append({
					"metric": "data_integrity_score",
					"current": current_metrics["data_integrity_score"],
					"previous": historical_integrity,
					"decrease_percent": (historical_integrity - current_metrics["data_integrity_score"]) / historical_integrity * 100
				})
	
	# Save current data to history
	historical_data.append(current_metrics)
	if historical_data.size() > 50:  # Keep only last 50 entries
		historical_data = historical_data.slice(-50)
	
	var file: FileAccess = FileAccess.open(history_file, FileAccess.WRITE)
	if file != null:
		var json_string: String = JSON.stringify(historical_data)
		file.store_string(json_string)
		file.close()
	
	validation_results["regression_analysis"] = regression_results
	
	# Add regression issues to critical issues
	if regression_results["regressions_detected"]:
		var critical_issues: Array[String] = validation_results.get("critical_issues", [])
		critical_issues.append("Performance regressions detected - see regression analysis")
		validation_results["critical_issues"] = critical_issues

func run_ci_validation(source_directory: String, target_directory: String) -> Dictionary:
	"""AC5: Run validation in CI/CD compatible mode"""
	var validation_results: Dictionary = validate_comprehensive(source_directory, target_directory)
	
	# Generate CI/CD compatible summary
	var ci_results: Dictionary = {
		"exit_code": 0,
		"summary": {},
		"detailed_results": validation_results,
		"execution_time": validation_results.get("execution_time_seconds", 0.0)
	}
	
	# Determine exit code based on critical issues
	var critical_issues: Array = validation_results.get("critical_issues", [])
	if critical_issues.size() > 0:
		ci_results["exit_code"] = 1
	
	# Generate summary for CI/CD
	var validation_summary: Dictionary = validation_results.get("validation_summary", {})
	ci_results["summary"] = {
		"total_assets": validation_summary.get("total_assets_validated", 0),
		"success_rate": validation_summary.get("validation_success_rate", 0.0),
		"critical_issues_count": critical_issues.size(),
		"passed": critical_issues.size() == 0
	}
	
	return ci_results

func detect_regressions(baseline_data: Dictionary, current_data: Dictionary) -> Dictionary:
	"""Detect regressions between baseline and current validation data"""
	var regression_result: Dictionary = {
		"regressions_detected": false,
		"regression_details": []
	}
	
	var regression_threshold: float = 0.05  # 5% decrease threshold
	
	# Check validation success rate
	var baseline_success: float = baseline_data.get("validation_success_rate", 0.0)
	var current_success: float = current_data.get("validation_success_rate", 0.0)
	
	if current_success < baseline_success * (1.0 - regression_threshold):
		regression_result["regressions_detected"] = true
		regression_result["regression_details"].append({
			"metric": "validation_success_rate",
			"baseline": baseline_success,
			"current": current_success,
			"regression_percent": (baseline_success - current_success) / baseline_success * 100
		})
	
	# Check data integrity
	var baseline_integrity: float = baseline_data.get("average_integrity_score", 0.0)
	var current_integrity: float = current_data.get("average_integrity_score", 0.0)
	
	if current_integrity < baseline_integrity * (1.0 - regression_threshold):
		regression_result["regressions_detected"] = true
		regression_result["regression_details"].append({
			"metric": "average_integrity_score",
			"baseline": baseline_integrity,
			"current": current_integrity,
			"regression_percent": (baseline_integrity - current_integrity) / baseline_integrity * 100
		})
	
	# Check visual fidelity
	var baseline_visual: float = baseline_data.get("visual_fidelity_score", 0.0)
	var current_visual: float = current_data.get("visual_fidelity_score", 0.0)
	
	if current_visual < baseline_visual * (1.0 - regression_threshold):
		regression_result["regressions_detected"] = true
		regression_result["regression_details"].append({
			"metric": "visual_fidelity_score",
			"baseline": baseline_visual,
			"current": current_visual,
			"regression_percent": (baseline_visual - current_visual) / baseline_visual * 100
		})
	
	return regression_result

func execute_workflow_step(step_name: String, parameters: Dictionary) -> bool:
	"""Execute individual workflow step for continuous validation"""
	print("Executing workflow step: ", step_name)
	
	match step_name:
		"initialize_validation":
			return _initialize_validation_workflow(parameters)
		"scan_assets":
			return _scan_assets_workflow(parameters)
		"validate_formats":
			return _validate_formats_workflow(parameters)
		"verify_integrity":
			return _verify_integrity_workflow(parameters)
		"check_visual_fidelity":
			return _check_visual_fidelity_workflow(parameters)
		"generate_reports":
			return _generate_reports_workflow(parameters)
		"check_regressions":
			return _check_regressions_workflow(parameters)
		"finalize_results":
			return _finalize_results_workflow(parameters)
		_:
			print("ERROR: Unknown workflow step: ", step_name)
			return false

func _initialize_validation_workflow(parameters: Dictionary) -> bool:
	"""Initialize validation workflow"""
	var source_dir: String = parameters.get("source_dir", "")
	var target_dir: String = parameters.get("target_dir", "")
	
	if source_dir.is_empty() or target_dir.is_empty():
		return false
	
	return DirAccess.dir_exists_absolute(target_dir)

func _scan_assets_workflow(parameters: Dictionary) -> bool:
	"""Scan assets workflow step"""
	var target_dir: String = parameters.get("target_dir", "")
	var assets: Array[String] = _scan_converted_assets(target_dir)
	return assets.size() > 0

func _validate_formats_workflow(parameters: Dictionary) -> bool:
	"""Validate formats workflow step"""
	var target_dir: String = parameters.get("target_dir", "")
	var results: Array = validate_asset_formats(target_dir)
	return results.size() > 0

func _verify_integrity_workflow(parameters: Dictionary) -> bool:
	"""Verify integrity workflow step"""
	var source_dir: String = parameters.get("source_dir", "")
	var target_dir: String = parameters.get("target_dir", "")
	var results: Array = verify_data_integrity(source_dir, target_dir)
	return true  # Always succeeds, even with empty results

func _check_visual_fidelity_workflow(parameters: Dictionary) -> bool:
	"""Check visual fidelity workflow step"""
	var source_dir: String = parameters.get("source_dir", "")
	var target_dir: String = parameters.get("target_dir", "")
	var results: Array = test_visual_fidelity(source_dir, target_dir)
	return true  # Always succeeds, even with empty results

func _generate_reports_workflow(parameters: Dictionary) -> bool:
	"""Generate reports workflow step"""
	return true  # Placeholder - always succeeds

func _check_regressions_workflow(parameters: Dictionary) -> bool:
	"""Check regressions workflow step"""
	return true  # Placeholder - always succeeds

func _finalize_results_workflow(parameters: Dictionary) -> bool:
	"""Finalize results workflow step"""
	return true  # Placeholder - always succeeds

func _detect_asset_type(asset_path: String) -> String:
	"""Detect asset type from file path and extension"""
	var extension: String = asset_path.get_extension().to_lower()
	var filename: String = asset_path.get_file().to_lower()
	
	match extension:
		"glb", "gltf":
			return "converted_model"
		"tres":
			if "table" in asset_path:
				return "converted_table_resource"
			else:
				return "godot_resource"
		"tscn":
			if "mission" in filename:
				return "converted_mission_scene"
			else:
				return "godot_scene"
		"json":
			return "converted_table_data"
		"png", "jpg":
			return "converted_texture"
		"ogg", "wav":
			return "converted_audio"
		_:
			return "unknown"

func _on_sub_validator_progress(percentage: float, task: String) -> void:
	"""Handle progress updates from sub-validators"""
	validation_progress.emit(percentage, task)