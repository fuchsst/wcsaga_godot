extends GdUnitTestSuite

## Comprehensive Validation Framework Tests
## DM-012 - Validation and Testing Framework
##
## Tests the comprehensive validation framework ensuring conversion accuracy,
## data integrity, and visual fidelity across all WCS asset types.
##
## Author: Dev (GDScript Developer)
## Date: January 30, 2025
## Story: DM-012 - Validation and Testing Framework
## Epic: EPIC-003 - Data Migration & Conversion Tools

const ComprehensiveValidator = preload("res://validation_framework/comprehensive_validation_manager.gd")
const AssetIntegrityValidator = preload("res://validation_framework/asset_integrity_validator.gd")
const VisualFidelityValidator = preload("res://validation_framework/visual_fidelity_validator.gd")
const ValidationReportGenerator = preload("res://validation_framework/validation_report_generator.gd")

var temp_dir: String
var test_assets_dir: String
var validator: ComprehensiveValidator

func before_test() -> void:
	# Create temporary directory for test assets
	temp_dir = "user://test_validation_" + str(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(temp_dir)
	
	test_assets_dir = temp_dir + "/test_assets"
	DirAccess.make_dir_recursive_absolute(test_assets_dir)
	
	# Initialize validator
	validator = ComprehensiveValidator.new()
	
	# Create test assets
	_create_test_assets()

func after_test() -> void:
	# Clean up temporary files
	_remove_directory_recursive(temp_dir)

func _create_test_assets() -> void:
	"""Create comprehensive test assets for validation testing"""
	
	# Create test VP archive
	_create_test_vp_archive()
	
	# Create test POF model
	_create_test_pof_model()
	
	# Create test mission file
	_create_test_mission_file()
	
	# Create test table files
	_create_test_table_files()
	
	# Create test texture files
	_create_test_texture_files()
	
	# Create converted Godot assets
	_create_converted_godot_assets()

func _create_test_vp_archive() -> void:
	"""Create mock VP archive for testing"""
	var vp_path: String = test_assets_dir + "/test_data.vp"
	var file: FileAccess = FileAccess.open(vp_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	# Write VP header signature
	file.store_buffer("VPVP".to_ascii_buffer())
	file.store_32(2)  # Version
	file.store_32(36) # Directory offset
	file.store_32(3)  # Number of files
	
	# Mock file data
	for i in range(20):
		file.store_8(0)
	
	# Directory entries
	file.store_32(0)   # File 1 offset
	file.store_32(100) # File 1 size
	var name1: String = "fighter.pof"
	file.store_buffer(name1.to_ascii_buffer().resize(32))
	
	file.store_32(100) # File 2 offset
	file.store_32(50)  # File 2 size
	var name2: String = "engine.pcx"
	file.store_buffer(name2.to_ascii_buffer().resize(32))
	
	file.store_32(150) # File 3 offset
	file.store_32(200) # File 3 size
	var name3: String = "mission1.fs2"
	file.store_buffer(name3.to_ascii_buffer().resize(32))
	
	file.close()

func _create_test_pof_model() -> void:
	"""Create mock POF model file for testing"""
	var pof_path: String = test_assets_dir + "/fighter.pof"
	var file: FileAccess = FileAccess.open(pof_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	# Write POF signature and header
	file.store_32(0x4f505350)  # 'OPSP' 
	file.store_32(1900)        # Version
	file.store_32(100)         # File size
	file.store_32(1)           # Number of submodels
	
	# Mock submodel data
	for i in range(50):
		file.store_8(i % 256)
	
	file.close()

func _create_test_mission_file() -> void:
	"""Create mock mission file for testing"""
	var mission_path: String = test_assets_dir + "/test_mission.fs2"
	var file: FileAccess = FileAccess.open(mission_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	var mission_content: String = '''#Mission Info
$Version: 1.00
$Name: Test Mission
$Author: Validation Framework

#Objects
$Name: Player
$Class: GTF Ulysses
$Team: Friendly
$Location: 0, 0, 1000
$Orientation:
	1.0, 0.0, 0.0,
	0.0, 1.0, 0.0,
	0.0, 0.0, 1.0

#Events

$Formula: ( true )
$Message: Welcome to the test mission!
$Priority: High

#Goals

$Type: Primary
$Name: Survive
+Formula: ( true )

#End
'''
	
	file.store_string(mission_content)
	file.close()

func _create_test_table_files() -> void:
	"""Create mock table files for testing"""
	
	# Ships table
	var ships_path: String = test_assets_dir + "/ships.tbl"
	var file: FileAccess = FileAccess.open(ships_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	var ships_content: String = '''#Ship Classes

$Ship: GTF Ulysses
$Name: Ulysses
$Short name: Ulysses
$Species: Terran
$Type: Fighter

$Manufacturer: Galactic Terran-Vasudan Alliance
$Description: Standard fighter

$POF file: fighter.pof
$Detail distance: ( 0, 50, 200, 500 )
$ND: fighter_closeup.pcx
$HD: fighter_closeup.pcx

$Mass: 15.0
$Velocity: 70.0, 140.0, 55.0, 0.2, 0.7, 1.4, 2.0
$Rotation: 1.5, 3.0, 1.2
$Shields: 280
$Hull: 150
$Subsystems: ( "engines", 25.0, -12.5, 0 )

#End
'''
	
	file.store_string(ships_content)
	file.close()
	
	# Weapons table
	var weapons_path: String = test_assets_dir + "/weapons.tbl"
	file = FileAccess.open(weapons_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	var weapons_content: String = '''#Weapons

$Weapon: Subach HL-7
$Name: Subach HL-7
$Type: Primary
$Tech Title: Subach HL-7
$Tech Anim: Tech_Subach
$Tech Description: Standard laser cannon

$Model file: laser.pof
$Mass: 0.1
$Velocity: 450.0
$Fire Wait: 0.17
$Damage: 8
$Damage Type: Laser
$Arm time: 0.0
$Arm range: 0.0
$Arm radius: 0.0

#End
'''
	
	file.store_string(weapons_content)
	file.close()

func _create_test_texture_files() -> void:
	"""Create mock texture files for testing"""
	
	# Create a simple test image
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color.BLUE)
	
	# Save as different formats
	image.save_png(test_assets_dir + "/test_texture.png")
	
	# Create mock PCX file (simplified)
	var pcx_path: String = test_assets_dir + "/engine.pcx"
	var file: FileAccess = FileAccess.open(pcx_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	# PCX header (simplified)
	file.store_8(10)  # Manufacturer
	file.store_8(5)   # Version
	file.store_8(1)   # Encoding
	file.store_8(8)   # Bits per pixel
	
	# Mock image data
	for i in range(100):
		file.store_8(i % 256)
	
	file.close()

func _create_converted_godot_assets() -> void:
	"""Create mock converted Godot assets for comparison testing"""
	
	var converted_dir: String = test_assets_dir + "/converted"
	DirAccess.make_dir_recursive_absolute(converted_dir)
	
	# Create converted GLB model
	var glb_path: String = converted_dir + "/fighter.glb"
	var file: FileAccess = FileAccess.open(glb_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	# GLB header
	file.store_buffer("glTF".to_ascii_buffer())
	file.store_32(2)    # Version
	file.store_32(500)  # Total length
	
	# Mock GLB data
	for i in range(100):
		file.store_8(i % 256)
	
	file.close()
	
	# Create converted Godot scene
	var scene_path: String = converted_dir + "/test_mission.tscn"
	file = FileAccess.open(scene_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	var scene_content: String = '''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/mission_controller.gd" id="1"]

[node name="TestMission" type="Node3D"]
script = ExtResource("1")

[node name="Player" type="CharacterBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1000)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Player"]
'''
	
	file.store_string(scene_content)
	file.close()
	
	# Create converted table resource
	var table_path: String = converted_dir + "/ships.tres"
	file = FileAccess.open(table_path, FileAccess.WRITE)
	assert_that(file).is_not_null()
	
	var table_content: String = '''[gd_resource type="BaseAssetData" format=3]

[resource]
asset_id = "GTF_Ulysses"
asset_type = "SHIP"
display_name = "Ulysses"
description = "Standard fighter"
metadata = {
"mass": 15.0,
"max_velocity": Vector3(70.0, 140.0, 55.0),
"hull_strength": 150.0,
"shield_strength": 280.0
}
'''
	
	file.store_string(table_content)
	file.close()

# Asset Format Validation Tests (AC1)
func test_comprehensive_asset_validation() -> void:
	"""Test comprehensive asset validation against WCS specifications"""
	
	var validation_results: Array = validator.validate_asset_formats(test_assets_dir)
	
	# Verify validation results structure
	assert_that(validation_results).is_not_empty()
	
	# Check that all test assets were validated
	var validated_files: Array[String] = []
	for result in validation_results:
		validated_files.append(result.get("file_path", ""))
	
	assert_that(validated_files).contains(test_assets_dir + "/test_data.vp")
	assert_that(validated_files).contains(test_assets_dir + "/fighter.pof")
	assert_that(validated_files).contains(test_assets_dir + "/test_mission.fs2")

func test_vp_archive_validation() -> void:
	"""Test VP archive format validation"""
	
	var vp_validator: AssetIntegrityValidator = AssetIntegrityValidator.new()
	var result: Dictionary = vp_validator.validate_vp_archive(test_assets_dir + "/test_data.vp")
	
	assert_that(result.get("is_valid", false)).is_true()
	assert_that(result.get("file_count", 0)).is_greater(0)
	assert_that(result).contains_keys(["format_version", "directory_entries", "total_size"])

func test_pof_model_validation() -> void:
	"""Test POF model format validation"""
	
	var model_validator: AssetIntegrityValidator = AssetIntegrityValidator.new()
	var result: Dictionary = model_validator.validate_pof_model(test_assets_dir + "/fighter.pof")
	
	assert_that(result.get("is_valid", false)).is_true()
	assert_that(result).contains_keys(["pof_version", "submodel_count", "file_size"])

func test_mission_file_validation() -> void:
	"""Test mission file format validation"""
	
	var mission_validator: AssetIntegrityValidator = AssetIntegrityValidator.new()
	var result: Dictionary = mission_validator.validate_mission_file(test_assets_dir + "/test_mission.fs2")
	
	assert_that(result.get("is_valid", false)).is_true()
	assert_that(result).contains_keys(["mission_info", "object_count", "event_count", "goal_count"])
	
	# Verify required mission sections
	var mission_info: Dictionary = result.get("mission_info", {})
	assert_that(mission_info).contains_keys(["name", "author", "version"])

func test_table_data_validation() -> void:
	"""Test table data format validation"""
	
	var table_validator: AssetIntegrityValidator = AssetIntegrityValidator.new()
	
	# Test ships table
	var ships_result: Dictionary = table_validator.validate_table_file(test_assets_dir + "/ships.tbl")
	assert_that(ships_result.get("is_valid", false)).is_true()
	assert_that(ships_result.get("table_type", "")).is_equal("ships")
	assert_that(ships_result.get("entry_count", 0)).is_greater(0)
	
	# Test weapons table
	var weapons_result: Dictionary = table_validator.validate_table_file(test_assets_dir + "/weapons.tbl")
	assert_that(weapons_result.get("is_valid", false)).is_true()
	assert_that(weapons_result.get("table_type", "")).is_equal("weapons")
	assert_that(weapons_result.get("entry_count", 0)).is_greater(0)

# Data Integrity Verification Tests (AC2)
func test_data_integrity_verification() -> void:
	"""Test data integrity verification between original and converted assets"""
	
	var integrity_validator: AssetIntegrityValidator = AssetIntegrityValidator.new()
	var results: Array = integrity_validator.verify_conversion_integrity(
		test_assets_dir, 
		test_assets_dir + "/converted"
	)
	
	assert_that(results).is_not_empty()
	
	# Check integrity results structure
	for result in results:
		assert_that(result).contains_keys([
			"original_path", "converted_path", "integrity_score", 
			"data_loss_detected", "missing_properties", "extra_properties"
		])
		
		var integrity_score: float = result.get("integrity_score", 0.0)
		assert_that(integrity_score).is_between(0.0, 1.0)

func test_pof_to_glb_integrity() -> void:
	"""Test POF to GLB conversion integrity"""
	
	var integrity_validator: AssetIntegrityValidator = AssetIntegrityValidator.new()
	var result: Dictionary = integrity_validator.verify_pof_glb_integrity(
		test_assets_dir + "/fighter.pof",
		test_assets_dir + "/converted/fighter.glb"
	)
	
	assert_that(result.get("integrity_score", 0.0)).is_greater(0.8)
	assert_that(result.get("data_loss_detected", true)).is_false()
	
	# Check for preserved model properties
	var preserved_properties: Array = result.get("preserved_properties", [])
	assert_that(preserved_properties).contains("vertex_count")
	assert_that(preserved_properties).contains("material_count")

func test_mission_to_scene_integrity() -> void:
	"""Test mission file to Godot scene conversion integrity"""
	
	var integrity_validator: AssetIntegrityValidator = AssetIntegrityValidator.new()
	var result: Dictionary = integrity_validator.verify_mission_scene_integrity(
		test_assets_dir + "/test_mission.fs2",
		test_assets_dir + "/converted/test_mission.tscn"
	)
	
	assert_that(result.get("integrity_score", 0.0)).is_greater(0.9)
	
	# Verify mission elements preservation
	var preserved_elements: Array = result.get("preserved_elements", [])
	assert_that(preserved_elements).contains("mission_info")
	assert_that(preserved_elements).contains("objects")
	assert_that(preserved_elements).contains("events")
	assert_that(preserved_elements).contains("goals")

func test_table_to_resource_integrity() -> void:
	"""Test table file to Godot resource conversion integrity"""
	
	var integrity_validator: AssetIntegrityValidator = AssetIntegrityValidator.new()
	var result: Dictionary = integrity_validator.verify_table_resource_integrity(
		test_assets_dir + "/ships.tbl",
		test_assets_dir + "/converted/ships.tres"
	)
	
	assert_that(result.get("integrity_score", 0.0)).is_greater(0.95)
	assert_that(result.get("data_loss_detected", true)).is_false()
	
	# Verify ship data preservation
	var ship_properties: Array = result.get("preserved_ship_properties", [])
	assert_that(ship_properties).contains("name")
	assert_that(ship_properties).contains("mass")
	assert_that(ship_properties).contains("velocity")
	assert_that(ship_properties).contains("hull_strength")

# Visual Fidelity Testing Tests (AC3)
func test_visual_fidelity_validation() -> void:
	"""Test visual fidelity validation framework"""
	
	var visual_validator: VisualFidelityValidator = VisualFidelityValidator.new()
	var results: Array = visual_validator.validate_visual_fidelity(
		test_assets_dir,
		test_assets_dir + "/converted"
	)
	
	# Visual validation should handle missing pairs gracefully
	assert_that(results).is_not_null()

func test_texture_conversion_fidelity() -> void:
	"""Test texture conversion visual fidelity"""
	
	var visual_validator: VisualFidelityValidator = VisualFidelityValidator.new()
	
	# Create comparable texture files
	var original_image: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	original_image.fill(Color.RED)
	original_image.save_png(test_assets_dir + "/original_texture.png")
	
	var converted_image: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	converted_image.fill(Color.RED)
	converted_image.save_png(test_assets_dir + "/converted_texture.png")
	
	var result: Dictionary = visual_validator.compare_texture_fidelity(
		test_assets_dir + "/original_texture.png",
		test_assets_dir + "/converted_texture.png"
	)
	
	assert_that(result.get("similarity_score", 0.0)).is_greater(0.95)
	assert_that(result.get("acceptable_quality", false)).is_true()

func test_model_visual_comparison() -> void:
	"""Test 3D model visual comparison capabilities"""
	
	var visual_validator: VisualFidelityValidator = VisualFidelityValidator.new()
	var result: Dictionary = visual_validator.compare_model_visual_fidelity(
		test_assets_dir + "/fighter.pof",
		test_assets_dir + "/converted/fighter.glb"
	)
	
	# Visual comparison should provide structural analysis
	assert_that(result).contains_keys(["visual_similarity", "structural_changes", "material_differences"])

# Test Report Generation (AC4)
func test_validation_report_generation() -> void:
	"""Test comprehensive validation report generation"""
	
	var report_generator: ValidationReportGenerator = ValidationReportGenerator.new()
	
	# Create mock validation data
	var validation_data: Dictionary = {
		"validation_id": "test_validation_001",
		"timestamp": Time.get_datetime_string_from_system(),
		"source_directory": test_assets_dir,
		"target_directory": test_assets_dir + "/converted",
		"asset_validation_results": [],
		"integrity_verification_results": [],
		"visual_fidelity_results": [],
		"summary_statistics": {
			"total_assets": 5,
			"successful_validations": 4,
			"failed_validations": 1,
			"overall_success_rate": 0.8
		}
	}
	
	var report_path: String = temp_dir + "/validation_report.json"
	var success: bool = report_generator.generate_json_report(validation_data, report_path)
	
	assert_that(success).is_true()
	assert_that(FileAccess.file_exists(report_path)).is_true()
	
	# Verify report content
	var file: FileAccess = FileAccess.open(report_path, FileAccess.READ)
	assert_that(file).is_not_null()
	
	var report_content: String = file.get_as_text()
	file.close()
	
	assert_that(report_content).contains("validation_id")
	assert_that(report_content).contains("test_validation_001")
	assert_that(report_content).contains("summary_statistics")

func test_html_report_generation() -> void:
	"""Test HTML validation report generation"""
	
	var report_generator: ValidationReportGenerator = ValidationReportGenerator.new()
	
	var validation_data: Dictionary = {
		"validation_id": "test_validation_002",
		"timestamp": Time.get_datetime_string_from_system(),
		"summary_statistics": {
			"total_assets": 10,
			"successful_validations": 9,
			"failed_validations": 1,
			"overall_success_rate": 0.9
		},
		"critical_issues": ["Data loss detected in model conversion"],
		"recommendations": ["Improve model conversion algorithm"]
	}
	
	var html_path: String = temp_dir + "/validation_report.html"
	var success: bool = report_generator.generate_html_report(validation_data, html_path)
	
	assert_that(success).is_true()
	assert_that(FileAccess.file_exists(html_path)).is_true()
	
	# Verify HTML structure
	var file: FileAccess = FileAccess.open(html_path, FileAccess.READ)
	assert_that(file).is_not_null()
	
	var html_content: String = file.get_as_text()
	file.close()
	
	assert_that(html_content).contains("<!DOCTYPE html>")
	assert_that(html_content).contains("WCS-Godot Validation Report")
	assert_that(html_content).contains("test_validation_002")

# CI/CD Integration Tests (AC5)
func test_automated_test_suite_integration() -> void:
	"""Test automated test suite integration for CI/CD"""
	
	var validator: ComprehensiveValidator = ComprehensiveValidator.new()
	
	# Test CI/CD compatible validation
	var ci_results: Dictionary = validator.run_ci_validation(
		test_assets_dir,
		test_assets_dir + "/converted"
	)
	
	assert_that(ci_results).contains_keys([
		"exit_code", "summary", "detailed_results", "execution_time"
	])
	
	# Verify CI/CD format
	var exit_code: int = ci_results.get("exit_code", -1)
	assert_that(exit_code).is_between(0, 1)  # 0 = success, 1 = failure

func test_regression_detection() -> void:
	"""Test regression detection capabilities"""
	
	var validator: ComprehensiveValidator = ComprehensiveValidator.new()
	
	# Create baseline validation data
	var baseline_data: Dictionary = {
		"validation_success_rate": 0.95,
		"average_integrity_score": 0.98,
		"visual_fidelity_score": 0.92
	}
	
	# Create current validation data (simulating regression)
	var current_data: Dictionary = {
		"validation_success_rate": 0.85,  # Regression: 10% decrease
		"average_integrity_score": 0.97,  # Slight decrease
		"visual_fidelity_score": 0.91     # Slight decrease
	}
	
	var regression_result: Dictionary = validator.detect_regressions(baseline_data, current_data)
	
	assert_that(regression_result.get("regressions_detected", false)).is_true()
	
	var regressions: Array = regression_result.get("regression_details", [])
	assert_that(regressions).is_not_empty()
	
	# Check for specific regression detection
	var success_rate_regression: bool = false
	for regression in regressions:
		if regression.get("metric", "") == "validation_success_rate":
			success_rate_regression = true
			break
	
	assert_that(success_rate_regression).is_true()

func test_continuous_validation_workflow() -> void:
	"""Test continuous validation workflow"""
	
	var validator: ComprehensiveValidator = ComprehensiveValidator.new()
	
	# Test workflow steps
	var workflow_steps: Array[String] = [
		"initialize_validation",
		"scan_assets", 
		"validate_formats",
		"verify_integrity",
		"check_visual_fidelity",
		"generate_reports",
		"check_regressions",
		"finalize_results"
	]
	
	for step in workflow_steps:
		var step_result: bool = validator.execute_workflow_step(step, {
			"source_dir": test_assets_dir,
			"target_dir": test_assets_dir + "/converted"
		})
		
		assert_that(step_result).is_true(), "Workflow step failed: " + step

# Performance and Reliability Tests
func test_validation_framework_performance() -> void:
	"""Test validation framework performance with multiple assets"""
	
	var start_time: int = Time.get_ticks_msec()
	
	var validator: ComprehensiveValidator = ComprehensiveValidator.new()
	var results: Dictionary = validator.validate_comprehensive(
		test_assets_dir,
		test_assets_dir + "/converted"
	)
	
	var end_time: int = Time.get_ticks_msec()
	var execution_time: float = (end_time - start_time) / 1000.0
	
	# Validation should complete within reasonable time
	assert_that(execution_time).is_less_than(30.0)  # 30 seconds max
	
	# Results should be comprehensive
	assert_that(results).contains_keys([
		"validation_summary", "detailed_results", "execution_metrics"
	])

func test_error_handling_robustness() -> void:
	"""Test validation framework error handling robustness"""
	
	var validator: ComprehensiveValidator = ComprehensiveValidator.new()
	
	# Test with non-existent directories
	var result: Dictionary = validator.validate_comprehensive(
		"non_existent_source",
		"non_existent_target"
	)
	
	assert_that(result.get("validation_errors", [])).is_not_empty()
	assert_that(result.get("execution_successful", true)).is_false()
	
	# Test with corrupted files
	var corrupted_file: String = test_assets_dir + "/corrupted.vp"
	var file: FileAccess = FileAccess.open(corrupted_file, FileAccess.WRITE)
	file.store_string("corrupted data")
	file.close()
	
	var corruption_result: Dictionary = validator.validate_asset_formats(test_assets_dir)
	assert_that(corruption_result).is_not_null()  # Should handle gracefully

func test_memory_efficiency() -> void:
	"""Test validation framework memory efficiency"""
	
	var validator: ComprehensiveValidator = ComprehensiveValidator.new()
	
	# Monitor memory usage during validation
	var initial_memory: int = OS.get_static_memory_usage()
	
	validator.validate_comprehensive(
		test_assets_dir,
		test_assets_dir + "/converted"
	)
	
	var final_memory: int = OS.get_static_memory_usage()
	var memory_increase: int = final_memory - initial_memory
	
	# Memory increase should be reasonable (less than 100MB)
	assert_that(memory_increase).is_less_than(100 * 1024 * 1024)

# Helper functions
func _remove_directory_recursive(directory: String) -> void:
	"""Remove directory and all contents recursively"""
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_remove_directory_recursive(full_path)
			dir.remove(file_name)
		elif not dir.current_is_dir():
			dir.remove(file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	dir.remove(directory)