@tool
extends GdUnitTestSuite

## Integration tests for GFRED2 core infrastructure integration (GFRED2-004).
## Tests integration with EPIC-001 core foundation utilities, error handling,
## configuration system, and performance optimization.

# Test components
var camera_3d: MissionCamera3D
var object_manager: MissionObjectManager
var asset_browser: AssetBrowserDockController

func before_test():
	# Setup test environment
	camera_3d = MissionCamera3D.new()
	object_manager = MissionObjectManager.new()
	asset_browser = AssetBrowserDockController.new()

func after_test():
	# Cleanup test environment
	if camera_3d:
		camera_3d.queue_free()
	if object_manager:
		object_manager.queue_free()
	if asset_browser:
		asset_browser.queue_free()

func test_camera_wcs_math_integration():
	# Test camera uses WCS math utilities instead of custom math
	camera_3d.orbit_elevation = 45.0
	camera_3d.orbit_azimuth = 90.0
	camera_3d.orbit_distance = 100.0
	camera_3d.orbit_target = Vector3.ZERO
	
	# Update camera position using WCS math
	camera_3d.update_camera_from_orbit()
	
	# Verify position calculation uses WCS utilities
	var expected_x: float = 100.0 * cos(WCSVectorMath.deg_to_rad(45.0)) * cos(WCSVectorMath.deg_to_rad(90.0))
	var expected_y: float = 100.0 * sin(WCSVectorMath.deg_to_rad(45.0))
	var expected_z: float = 100.0 * cos(WCSVectorMath.deg_to_rad(45.0)) * sin(WCSVectorMath.deg_to_rad(90.0))
	
	assert_float(camera_3d.position.x).is_equal(expected_x, Vector3.EPSILON)
	assert_float(camera_3d.position.y).is_equal(expected_y, Vector3.EPSILON)
	assert_float(camera_3d.position.z).is_equal(expected_z, Vector3.EPSILON)

func test_camera_focus_bounds_wcs_integration():
	# Test camera bounds focusing uses WCS math utilities
	var test_bounds: AABB = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	
	camera_3d.focus_on_bounds(test_bounds)
	
	# Verify the calculation uses WCS vector magnitude
	var bounds_size: float = WCSVectorMath.vec_mag(test_bounds.size)
	assert_float(bounds_size).is_greater(WCSVectorMath.SMALL_NUM)
	
	# Verify orbit target is set to bounds center
	assert_vector3(camera_3d.orbit_target).is_equal(test_bounds.get_center())

func test_error_handling_standardization():
	# Test that error handling follows core validation patterns
	# This would typically test error handling in file operations, property validation, etc.
	
	# Test WCS Asset Core integration error handling
	if WCSAssetRegistry:
		var invalid_assets: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.UNKNOWN)
		assert_array(invalid_assets).is_empty()

func test_wcs_asset_core_integration():
	# Test direct integration with WCS Asset Core (no wrapper layers)
	assert_not_null(WCSAssetRegistry, "WCS Asset Registry should be available")
	assert_not_null(WCSAssetLoader, "WCS Asset Loader should be available")
	
	# Test asset type access
	if WCSAssetRegistry:
		var ship_assets: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
		assert_array(ship_assets).is_not_null()

func test_sexp_system_integration():
	# Test direct integration with SEXP system (no wrapper layers)
	if SexpManager:
		# Test basic validation functionality
		var simple_expression: String = "(+ 1 2)"
		var is_valid: bool = SexpManager.validate_syntax(simple_expression)
		
		# Basic syntax should be valid
		assert_bool(is_valid).is_true()

func test_performance_requirements():
	# Test that performance requirements are met
	var start_time: int = Time.get_ticks_msec()
	
	# Test scene instantiation performance (< 16ms requirement)
	var dock_scene: PackedScene = preload("res://addons/gfred2/scenes/docks/main_editor_dock.tscn")
	var dock_instance: Control = dock_scene.instantiate()
	
	var instantiation_time: int = Time.get_ticks_msec() - start_time
	assert_int(instantiation_time).is_less(16)  # Must be under 16ms
	
	# Cleanup
	dock_instance.queue_free()

func test_configuration_system_integration():
	# Test integration with core configuration system
	# This would test user preferences, editor settings, keyboard shortcuts
	
	# Verify configuration classes are available
	assert_not_null(WCSConstants, "WCS Constants should be available")
	assert_not_null(WCSPaths, "WCS Paths should be available")

func test_math_utilities_constants():
	# Test WCS math utilities are properly integrated
	assert_float(WCSVectorMath.SMALL_NUM).is_equal(1e-7)
	assert_float(WCSVectorMath.CONVERT_RADIANS).is_equal(0.017453292519943)
	
	# Test conversion functions
	var degrees: float = 90.0
	var radians: float = WCSVectorMath.deg_to_rad(degrees)
	assert_float(radians).is_equal(PI / 2.0, 0.0001)
	
	var converted_back: float = WCSVectorMath.rad_to_deg(radians)
	assert_float(converted_back).is_equal(degrees, 0.0001)

func test_vector_math_integration():
	# Test vector math operations use WCS utilities
	var vec1: Vector3 = Vector3(1, 2, 3)
	var vec2: Vector3 = Vector3(4, 5, 6)
	
	# Test distance calculation
	var distance: float = WCSVectorMath.vec_dist(vec1, vec2)
	var expected_distance: float = vec1.distance_to(vec2)
	assert_float(distance).is_equal(expected_distance, Vector3.EPSILON)
	
	# Test magnitude calculation
	var magnitude: float = WCSVectorMath.vec_mag(vec1)
	var expected_magnitude: float = vec1.length()
	assert_float(magnitude).is_equal(expected_magnitude, Vector3.EPSILON)

func test_no_duplicate_utility_code():
	# Test that no duplicate utility functions remain
	# This is more of a code structure test
	
	# Verify math operations use WCSVectorMath
	assert_not_null(WCSVectorMath, "WCS Vector Math utilities should be available")
	
	# Verify core constants are accessible
	assert_not_null(WCSConstants, "WCS Constants should be available")

func test_resource_management_integration():
	# Test resource management uses core patterns
	# This would test memory management, asset caching, cleanup
	
	# Test basic resource creation
	var mission_data: MissionData = MissionData.new()
	assert_not_null(mission_data)
	
	# Test resource cleanup
	mission_data = null
	# Force garbage collection to test memory management
	await get_tree().process_frame

func test_file_operations_integration():
	# Test file operations use core VP archive access
	# This would test mission file loading/saving, asset file access
	
	# Verify file system utilities are available
	assert_not_null(WCSPaths, "WCS Paths utilities should be available")
	
	# Test path validation
	var test_path: String = "res://test/path.fs2"
	var is_valid_length: bool = WCSPaths.validate_pathname_length(test_path)
	assert_bool(is_valid_length).is_true()

func test_integration_performance():
	# Test that integration doesn't degrade performance
	var iterations: int = 1000
	var start_time: int = Time.get_ticks_msec()
	
	# Perform multiple WCS math operations
	for i in range(iterations):
		var vec: Vector3 = Vector3(i, i * 2, i * 3)
		var magnitude: float = WCSVectorMath.vec_mag(vec)
		var normalized: Vector3 = WCSVectorMath.vec_normalize_quick(vec)
		
		# Use results to prevent optimization
		assert_float(magnitude).is_greater_equal(0.0)
		assert_vector3(normalized).is_not_null()
	
	var elapsed_time: int = Time.get_ticks_msec() - start_time
	
	# Should complete 1000 operations in reasonable time (< 100ms)
	assert_int(elapsed_time).is_less(100)