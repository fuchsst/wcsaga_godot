@tool
extends GdUnitTestSuite

## Performance tests for GFRED2 mission editor.
## Validates that all components meet the < 16ms scene instantiation 
## and 60+ FPS UI update requirements specified in the architecture.

# Performance thresholds
const MAX_SCENE_INSTANTIATION_MS: int = 16
const MIN_FPS_REQUIREMENT: float = 55.0  # Allow some margin below 60
const MAX_UI_UPDATE_MS: int = 16

# Test scenes to validate
var test_scenes: Array[String] = [
	"res://addons/gfred2/scenes/docks/main_editor_dock.tscn",
	"res://addons/gfred2/scenes/docks/asset_browser_dock.tscn", 
	"res://addons/gfred2/scenes/docks/sexp_editor_dock.tscn",
	"res://addons/gfred2/scenes/docks/object_inspector_dock.tscn",
	"res://addons/gfred2/scenes/docks/validation_dock.tscn",
	"res://addons/gfred2/scenes/docks/performance_profiler_dock.tscn"
]

func test_scene_instantiation_performance():
	# Test that all GFRED2 scenes meet < 16ms instantiation requirement
	for scene_path in test_scenes:
		if not ResourceLoader.exists(scene_path):
			continue
		
		var scene: PackedScene = load(scene_path)
		assert_not_null(scene, "Scene should load: %s" % scene_path)
		
		# Measure instantiation time
		var start_time: int = Time.get_ticks_msec()
		var instance: Node = scene.instantiate()
		var instantiation_time: int = Time.get_ticks_msec() - start_time
		
		# Verify meets performance requirement
		assert_int(instantiation_time).is_less_equal(MAX_SCENE_INSTANTIATION_MS, 
			"Scene instantiation must be <= %dms, got %dms for %s" % 
			[MAX_SCENE_INSTANTIATION_MS, instantiation_time, scene_path])
		
		# Cleanup
		instance.queue_free()

func test_dialog_instantiation_performance():
	# Test dialog scene instantiation performance
	var dialog_scenes: Array[String] = [
		"res://addons/gfred2/scenes/dialogs/base_dialog.tscn"
	]
	
	for scene_path in dialog_scenes:
		if not ResourceLoader.exists(scene_path):
			continue
		
		var scene: PackedScene = load(scene_path)
		var start_time: int = Time.get_ticks_msec()
		var instance: Node = scene.instantiate()
		var instantiation_time: int = Time.get_ticks_msec() - start_time
		
		assert_int(instantiation_time).is_less_equal(MAX_SCENE_INSTANTIATION_MS)
		instance.queue_free()

func test_component_instantiation_performance():
	# Test UI component instantiation performance
	var component_scenes: Array[String] = [
		"res://addons/gfred2/scenes/components/validation_indicator.tscn",
		"res://addons/gfred2/scenes/components/dependency_graph_view.tscn"
	]
	
	for scene_path in component_scenes:
		if not ResourceLoader.exists(scene_path):
			continue
		
		var scene: PackedScene = load(scene_path)
		var start_time: int = Time.get_ticks_msec()
		var instance: Node = scene.instantiate()
		var instantiation_time: int = Time.get_ticks_msec() - start_time
		
		assert_int(instantiation_time).is_less_equal(MAX_SCENE_INSTANTIATION_MS)
		instance.queue_free()

func test_multiple_scene_instantiation():
	# Test performance when instantiating multiple scenes simultaneously
	var instances: Array[Node] = []
	var total_start_time: int = Time.get_ticks_msec()
	
	# Instantiate multiple dock scenes
	for scene_path in test_scenes:
		if not ResourceLoader.exists(scene_path):
			continue
		
		var scene: PackedScene = load(scene_path)
		var instance: Node = scene.instantiate()
		instances.append(instance)
	
	var total_time: int = Time.get_ticks_msec() - total_start_time
	
	# Total time should be reasonable for all scenes
	var max_total_time: int = MAX_SCENE_INSTANTIATION_MS * instances.size()
	assert_int(total_time).is_less_equal(max_total_time)
	
	# Cleanup
	for instance in instances:
		instance.queue_free()

func test_ui_update_performance():
	# Test UI update performance for controllers
	var dock_scene: PackedScene = preload("res://addons/gfred2/scenes/docks/asset_browser_dock.tscn")
	var dock_instance: Control = dock_scene.instantiate()
	add_child(dock_instance)
	
	# Wait for ready
	await get_tree().process_frame
	
	# Get controller
	var controller: AssetBrowserDockController = dock_instance as AssetBrowserDockController
	if controller:
		# Measure UI update performance
		var start_time: int = Time.get_ticks_msec()
		
		# Perform UI updates
		for i in range(100):
			controller.refresh()
			await get_tree().process_frame
		
		var total_time: int = Time.get_ticks_msec() - start_time
		var average_time: float = float(total_time) / 100.0
		
		# Each update should be fast
		assert_float(average_time).is_less_equal(float(MAX_UI_UPDATE_MS))
	
	# Cleanup
	dock_instance.queue_free()

func test_sexp_validation_performance():
	# Test SEXP validation performance
	var sexp_editor: SexpEditorDockController = SexpEditorDockController.new()
	add_child(sexp_editor)
	
	# Wait for ready
	await get_tree().process_frame
	
	var test_expressions: Array[String] = [
		"(+ 1 2)",
		"(and true false)",
		"(or (> 5 3) (< 2 1))",
		"(when (is-event-true \"test\") (send-message \"cmd\" \"msg\" 1))"
	]
	
	var start_time: int = Time.get_ticks_msec()
	
	# Validate multiple expressions
	for expression in test_expressions:
		for i in range(25):  # 100 total validations
			sexp_editor.set_expression(expression)
			var is_valid: bool = sexp_editor.is_expression_valid()
			assert_that(is_valid).is_not_null()
	
	var total_time: int = Time.get_ticks_msec() - start_time
	
	# Should complete 100 validations quickly (< 50ms)
	assert_int(total_time).is_less(50)
	
	sexp_editor.queue_free()

func test_asset_loading_performance():
	# Test asset loading performance
	var asset_browser: AssetBrowserDockController = AssetBrowserDockController.new()
	add_child(asset_browser)
	
	await get_tree().process_frame
	
	var start_time: int = Time.get_ticks_msec()
	
	# Simulate asset refresh operations
	for i in range(10):
		asset_browser.refresh()
		await get_tree().process_frame
	
	var total_time: int = Time.get_ticks_msec() - start_time
	var average_time: float = float(total_time) / 10.0
	
	# Each refresh should be reasonably fast
	assert_float(average_time).is_less_equal(50.0)
	
	asset_browser.queue_free()

func test_memory_usage_stability():
	# Test memory usage doesn't grow excessively
	var initial_memory: int = OS.get_static_memory_usage_by_type()[TYPE_OBJECT]
	var instances: Array[Node] = []
	
	# Create and destroy scenes multiple times
	for cycle in range(5):
		# Create instances
		for scene_path in test_scenes:
			if not ResourceLoader.exists(scene_path):
				continue
			
			var scene: PackedScene = load(scene_path)
			var instance: Node = scene.instantiate()
			instances.append(instance)
		
		# Destroy instances
		for instance in instances:
			instance.queue_free()
		instances.clear()
		
		# Force garbage collection
		await get_tree().process_frame
		await get_tree().process_frame
	
	var final_memory: int = OS.get_static_memory_usage_by_type()[TYPE_OBJECT]
	var memory_growth: int = final_memory - initial_memory
	
	# Memory growth should be minimal (< 10MB)
	var max_growth: int = 10 * 1024 * 1024  # 10MB
	assert_int(memory_growth).is_less(max_growth)

func test_wcs_math_performance():
	# Test WCS math utilities performance
	var iterations: int = 10000
	var start_time: int = Time.get_ticks_msec()
	
	# Perform math operations
	for i in range(iterations):
		var vec: Vector3 = Vector3(i, i * 2, i * 3)
		var magnitude: float = WCSVectorMath.vec_mag(vec)
		var distance: float = WCSVectorMath.vec_dist(vec, Vector3.ZERO)
		var normalized: Vector3 = WCSVectorMath.vec_normalize_quick(vec)
		
		# Use results to prevent optimization
		assert_float(magnitude).is_greater_equal(0.0)
		assert_float(distance).is_greater_equal(0.0)
		assert_vector3(normalized).is_not_null()
	
	var elapsed_time: int = Time.get_ticks_msec() - start_time
	
	# Should complete 10000 operations quickly (< 100ms)
	assert_int(elapsed_time).is_less(100)

func test_plugin_initialization_performance():
	# Test GFRED2 plugin initialization performance
	var plugin: GFRED2Plugin = GFRED2Plugin.new()
	
	var start_time: int = Time.get_ticks_msec()
	
	# Initialize plugin (simulation of _enter_tree)
	plugin.name = "TestGFRED2Plugin"
	add_child(plugin)
	
	var init_time: int = Time.get_ticks_msec() - start_time
	
	# Plugin initialization should be fast (< 100ms)
	assert_int(init_time).is_less(100)
	
	plugin.queue_free()

func test_large_mission_performance():
	# Test performance with larger mission data sets
	var mission_data: MissionData = MissionData.new()
	
	# Create larger mission with many objects
	var start_time: int = Time.get_ticks_msec()
	
	for i in range(100):
		var obj: MissionObjectData = MissionObjectData.new()
		obj.object_name = "Object_%03d" % i
		obj.position = Vector3(i * 10, 0, 0)
		mission_data.objects.append(obj)
	
	var creation_time: int = Time.get_ticks_msec() - start_time
	
	# Creating 100 objects should be fast (< 50ms)
	assert_int(creation_time).is_less(50)
	
	# Test iteration performance
	start_time = Time.get_ticks_msec()
	
	for obj in mission_data.objects:
		var name: String = obj.object_name
		var pos: Vector3 = obj.position
		assert_str(name).is_not_empty()
		assert_vector3(pos).is_not_null()
	
	var iteration_time: int = Time.get_ticks_msec() - start_time
	
	# Iterating through 100 objects should be very fast (< 10ms)
	assert_int(iteration_time).is_less(10)

func test_concurrent_operations_performance():
	# Test performance of concurrent UI operations
	var asset_browser: AssetBrowserDockController = AssetBrowserDockController.new()
	var sexp_editor: SexpEditorDockController = SexpEditorDockController.new()
	
	add_child(asset_browser)
	add_child(sexp_editor)
	
	await get_tree().process_frame
	
	var start_time: int = Time.get_ticks_msec()
	
	# Perform concurrent operations
	for i in range(20):
		asset_browser.refresh()
		sexp_editor.set_expression("(+ %d %d)" % [i, i + 1])
		await get_tree().process_frame
	
	var total_time: int = Time.get_ticks_msec() - start_time
	
	# Concurrent operations should maintain good performance
	assert_int(total_time).is_less(500)  # 20 operations in < 500ms
	
	asset_browser.queue_free()
	sexp_editor.queue_free()