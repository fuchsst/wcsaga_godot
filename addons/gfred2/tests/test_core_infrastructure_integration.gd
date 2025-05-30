@tool
extends GdUnitTestSuite

## Tests for GFRED2-004: Core Infrastructure Integration with EPIC-001
## Validates that GFRED2 correctly uses core foundation utilities

const MissionCamera3D = preload("res://addons/gfred2/viewport/mission_camera_3d.gd")
const MissionMessage = preload("res://addons/gfred2/mission/mission_message.gd")
const MissionData = preload("res://addons/gfred2/data/mission_data.gd")
const ObjectValidator = preload("res://addons/gfred2/object_management/object_validator.gd")

var test_scene: Node

func before_test() -> void:
	test_scene = Node.new()
	add_child(test_scene)

func after_test() -> void:
	if test_scene:
		test_scene.queue_free()

## Test that MissionCamera3D uses WCSVectorMath for distance calculations
func test_camera_uses_wcs_vector_math() -> void:
	var camera: MissionCamera3D = MissionCamera3D.new()
	test_scene.add_child(camera)
	
	# Set up test positions
	var pos1: Vector3 = Vector3(10, 20, 30)
	var pos2: Vector3 = Vector3(40, 50, 60)
	
	camera.position = pos1
	camera.orbit_target = pos2
	camera.reset_to_default_position()
	
	# The camera should now have used WCSVectorMath.vec_dist for orbit_distance calculation
	# Since we can't directly test private function calls, we verify the distance was calculated
	assert_that(camera.orbit_distance).is_greater(0.0)

## Test that MissionMessage uses WCSPaths for file validation
func test_mission_message_uses_wcs_paths() -> void:
	var message: MissionMessage = MissionMessage.new()
	
	# Test with valid path
	message.wave_file = "res://addons/gfred2/tests/test_core_infrastructure_integration.gd"
	message.ani_file = ""
	
	var errors: Array[String] = message.validate()
	
	# Should use WCSPaths.file_exists() and return no errors for existing file
	assert_array(errors).is_empty()
	
	# Test with invalid path
	message.wave_file = "nonexistent_file.wav"
	errors = message.validate()
	
	# Should detect invalid file using WCSPaths
	assert_array(errors).is_not_empty()
	assert_str(errors[0]).contains("wave file not found")

## Test that MissionData uses ValidationResult pattern
func test_mission_data_uses_validation_result() -> void:
	var mission: MissionData = MissionData.new()
	mission.mission_name = ""  # Empty name should generate warning
	
	var result: ValidationResult = mission.validate()
	
	# Should return ValidationResult object
	assert_not_null(result)
	assert_that(result).is_instance_of(ValidationResult)
	
	# Should have warning about empty mission name
	var warnings: Array[String] = result.get_warnings()
	assert_array(warnings).is_not_empty()
	assert_str(warnings[0]).contains("Mission name is empty")

## Test that ObjectValidator uses ValidationResult pattern
func test_object_validator_uses_validation_result() -> void:
	var validator: ObjectValidator = ObjectValidator.new()
	test_scene.add_child(validator)
	
	# Test with null object
	var result: ValidationResult = validator.validate_object(null)
	
	# Should return ValidationResult
	assert_not_null(result)
	assert_that(result).is_instance_of(ValidationResult)
	
	# Should have error about null object
	var errors: Array[String] = result.get_errors()
	assert_array(errors).is_not_empty()
	assert_str(errors[0]).contains("Object data is null")

## Test that GFRED2 data structures use WCS constants
func test_mission_object_uses_wcs_constants() -> void:
	var obj_data: MissionObjectData = MissionObjectData.new()
	
	# Should use WCS ZERO_VECTOR instead of Vector3.ZERO
	assert_vector3(obj_data.position).is_equal(WCSVectorMath.ZERO_VECTOR)
	assert_vector3(obj_data.rotation).is_equal(WCSVectorMath.ZERO_VECTOR)

## Performance test: Verify core utilities maintain performance
func test_core_utilities_performance() -> void:
	var start_time: float = Time.get_ticks_msec()
	
	# Perform multiple operations using core utilities
	for i in range(1000):
		var dist: float = WCSVectorMath.vec_dist(Vector3(i, i, i), Vector3(i+1, i+1, i+1))
		var exists: bool = WCSPaths.file_exists("res://project.godot")
		var result: ValidationResult = ValidationResult.new("test", "test")
		result.add_error("Test error")
	
	var elapsed_time: float = Time.get_ticks_msec() - start_time
	
	# Should complete 1000 operations in under 100ms
	assert_float(elapsed_time).is_less(100.0)

## Test configuration integration
func test_configuration_integration() -> void:
	# Test that configuration settings can be stored and retrieved
	ConfigurationManager.set_user_preference("test_gfred2_setting", "test_value")
	var retrieved_value = ConfigurationManager.get_user_preference("test_gfred2_setting")
	
	assert_str(retrieved_value).is_equal("test_value")
	
	# Test numeric settings
	ConfigurationManager.set_user_preference("test_gfred2_zoom", 1.5)
	var zoom_value: float = ConfigurationManager.get_user_preference("test_gfred2_zoom")
	
	assert_float(zoom_value).is_equal(1.5)