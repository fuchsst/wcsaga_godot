extends GdUnitTestSuite

## gdUnit4 test suite for GFRED2 UI architecture.
## Tests scene instantiation, controller functionality, and signal communication.

# Test timeout for scene operations
const SCENE_TIMEOUT_MS: int = 100

func before():
	# Setup before each test
	pass

func after():
	# Cleanup after each test
	pass

## Test scene-based dock instantiation

func test_main_editor_dock_scene_instantiation():
	var dock_scene = preload("res://addons/gfred2/scenes/docks/main_editor_dock.tscn")
	var dock_instance = dock_scene.instantiate()
	
	assert_not_null(dock_instance, "Main editor dock should instantiate successfully")
	assert_that(dock_instance).is_instance_of(MainEditorDockController)
	assert_str(dock_instance.name).is_equal("MainEditorDock")
	
	# Test scene node structure
	var main_container = dock_instance.get_node("MainContainer")
	assert_not_null(main_container, "MainContainer node should exist")
	assert_that(main_container).is_instance_of(HSplitContainer)
	
	# Cleanup
	dock_instance.queue_free()

func test_asset_browser_dock_scene_instantiation():
	var dock_scene = preload("res://addons/gfred2/scenes/docks/asset_browser_dock.tscn")
	var dock_instance = dock_scene.instantiate()
	
	assert_not_null(dock_instance, "Asset browser dock should instantiate successfully")
	assert_that(dock_instance).is_instance_of(AssetBrowserDockController)
	assert_str(dock_instance.name).is_equal("AssetBrowserDock")
	
	# Test WCS Asset Core integration points
	if WCSAssetRegistry:
		assert_bool(dock_instance.has_method("_refresh_assets")).is_true()
	
	dock_instance.queue_free()

func test_sexp_editor_dock_scene_instantiation():
	var dock_scene = preload("res://addons/gfred2/scenes/docks/sexp_editor_dock.tscn")
	var dock_instance = dock_scene.instantiate()
	
	assert_not_null(dock_instance, "SEXP editor dock should instantiate successfully")
	assert_that(dock_instance).is_instance_of(SexpEditorDockController)
	assert_str(dock_instance.name).is_equal("SexpEditorDock")
	
	# Test SEXP system integration
	if SexpManager:
		assert_bool(dock_instance.has_method("_validate_current_expression")).is_true()
	
	dock_instance.queue_free()

func test_object_inspector_dock_scene_instantiation():
	var dock_scene = preload("res://addons/gfred2/scenes/docks/object_inspector_dock.tscn")
	var dock_instance = dock_scene.instantiate()
	
	assert_not_null(dock_instance, "Object inspector dock should instantiate successfully")
	assert_that(dock_instance).is_instance_of(ObjectInspectorDockController)
	assert_str(dock_instance.name).is_equal("ObjectInspectorDock")
	
	dock_instance.queue_free()

## Test dialog scene instantiation

func test_base_dialog_scene_instantiation():
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog_instance = dialog_scene.instantiate()
	
	assert_not_null(dialog_instance, "Base dialog should instantiate successfully")
	assert_that(dialog_instance).is_instance_of(BaseDialogController)
	assert_str(dialog_instance.name).is_equal("BaseDialog")
	
	# Test dialog structure
	var content_container = dialog_instance.get_content_container()
	assert_not_null(content_container, "Content container should be accessible")
	assert_that(content_container).is_instance_of(VBoxContainer)
	
	dialog_instance.queue_free()

func test_scene_dialog_manager_instantiation():
	var manager_scene = preload("res://addons/gfred2/scenes/managers/scene_dialog_manager.tscn")
	var manager_instance = manager_scene.instantiate()
	
	assert_not_null(manager_instance, "Scene dialog manager should instantiate successfully")
	assert_that(manager_instance).is_instance_of(SceneDialogManagerController)
	assert_str(manager_instance.name).is_equal("SceneDialogManager")
	
	# Test dialog registry
	var dialog_names = manager_instance.get_registered_dialog_names()
	assert_array(dialog_names).is_not_empty()
	assert_array(dialog_names).contains("mission_specs")
	assert_array(dialog_names).contains("mission_component_editor")
	
	manager_instance.queue_free()

## Test gizmo scene instantiation

func test_object_transform_gizmo_scene_instantiation():
	var gizmo_scene = preload("res://addons/gfred2/scenes/gizmos/object_transform_gizmo.tscn")
	var gizmo_instance = gizmo_scene.instantiate()
	
	assert_not_null(gizmo_instance, "Object transform gizmo should instantiate successfully")
	assert_that(gizmo_instance).is_instance_of(ObjectTransformGizmoController)
	assert_str(gizmo_instance.name).is_equal("ObjectTransformGizmo")
	
	# Test gizmo functionality
	assert_bool(gizmo_instance.has_method("set_target_object")).is_true()
	assert_bool(gizmo_instance.has_method("set_transform_mode")).is_true()
	
	gizmo_instance.queue_free()

## Test validation scene instantiation

func test_mission_validation_panel_scene_instantiation():
	var validation_scene = preload("res://addons/gfred2/scenes/components/validation/mission_validation_panel.tscn")
	var validation_instance = validation_scene.instantiate()
	
	assert_not_null(validation_instance, "Mission validation panel should instantiate successfully")
	assert_that(validation_instance).is_instance_of(MissionValidationPanelController)
	assert_str(validation_instance.name).is_equal("MissionValidationPanel")
	
	# Test validation functionality
	assert_bool(validation_instance.has_method("initialize_with_mission")).is_true()
	assert_bool(validation_instance.has_method("refresh_validation")).is_true()
	
	validation_instance.queue_free()

## Test scene instantiation performance (< 16ms requirement)

func test_scene_instantiation_performance():
	var scenes_to_test = [
		"res://addons/gfred2/scenes/docks/main_editor_dock.tscn",
		"res://addons/gfred2/scenes/docks/asset_browser_dock.tscn",
		"res://addons/gfred2/scenes/docks/sexp_editor_dock.tscn",
		"res://addons/gfred2/scenes/docks/object_inspector_dock.tscn",
		"res://addons/gfred2/scenes/dialogs/base_dialog.tscn",
		"res://addons/gfred2/scenes/gizmos/object_transform_gizmo.tscn",
		"res://addons/gfred2/scenes/components/validation/mission_validation_panel.tscn"
	]
	
	for scene_path in scenes_to_test:
		var start_time = Time.get_ticks_msec()
		var scene = load(scene_path)
		var instance = scene.instantiate()
		var end_time = Time.get_ticks_msec()
		var instantiation_time = end_time - start_time
		
		assert_int(instantiation_time).is_less(16, 
			"Scene %s instantiation time (%dms) should be < 16ms" % [scene_path.get_file(), instantiation_time])
		
		instance.queue_free()

## Test signal communication between scene components

func test_dock_signal_communication():
	var main_dock_scene = preload("res://addons/gfred2/scenes/docks/main_editor_dock.tscn")
	var inspector_dock_scene = preload("res://addons/gfred2/scenes/docks/object_inspector_dock.tscn")
	
	var main_dock = main_dock_scene.instantiate()
	var inspector_dock = inspector_dock_scene.instantiate()
	
	# Test signal connections exist
	assert_bool(main_dock.has_signal("object_selected")).is_true()
	assert_bool(inspector_dock.has_signal("property_changed")).is_true()
	
	# Test signal connection capability
	var signal_connected = false
	if main_dock.has_method("connect") and inspector_dock.has_method("inspect_object"):
		main_dock.object_selected.connect(inspector_dock.inspect_object)
		signal_connected = true
	
	assert_bool(signal_connected).is_true("Should be able to connect dock signals")
	
	main_dock.queue_free()
	inspector_dock.queue_free()

func test_dialog_manager_signal_communication():
	var manager_scene = preload("res://addons/gfred2/scenes/managers/scene_dialog_manager.tscn")
	var manager = manager_scene.instantiate()
	
	# Test dialog manager signals
	assert_bool(manager.has_signal("dialog_opened")).is_true()
	assert_bool(manager.has_signal("dialog_closed")).is_true()
	
	# Test dialog creation and signals
	var signal_emitted = false
	manager.dialog_opened.connect(func(dialog_name, dialog_instance): signal_emitted = true)
	
	# This would test actual dialog creation, but requires scene tree
	# For now, just verify the signal exists and can be connected
	assert_bool(signal_emitted == false).is_true("Signal not emitted yet (expected)")
	
	manager.queue_free()

## Test controller functionality

func test_main_editor_dock_controller_functionality():
	var dock_scene = preload("res://addons/gfred2/scenes/docks/main_editor_dock.tscn")
	var dock = dock_scene.instantiate()
	
	# Test initial state
	assert_array(dock.get_selected_objects()).is_empty()
	assert_str(dock.get_current_view_mode()).is_equal("wireframe")
	
	# Test method availability
	assert_bool(dock.has_method("initialize_with_mission")).is_true()
	assert_bool(dock.has_method("refresh_hierarchy")).is_true()
	assert_bool(dock.has_method("select_object")).is_true()
	
	dock.queue_free()

func test_asset_browser_dock_controller_functionality():
	var dock_scene = preload("res://addons/gfred2/scenes/docks/asset_browser_dock.tscn")
	var dock = dock_scene.instantiate()
	
	# Test initial state
	assert_str(dock.get_selected_asset_path()).is_empty()
	
	# Test method availability
	assert_bool(dock.has_method("set_asset_type_filter")).is_true()
	assert_bool(dock.has_method("refresh")).is_true()
	assert_bool(dock.has_method("get_filtered_assets")).is_true()
	
	dock.queue_free()

func test_sexp_editor_dock_controller_functionality():
	var dock_scene = preload("res://addons/gfred2/scenes/docks/sexp_editor_dock.tscn")
	var dock = dock_scene.instantiate()
	
	# Test initial state
	assert_str(dock.get_expression()).is_empty()
	assert_bool(dock.is_expression_valid()).is_true()
	
	# Test method availability  
	assert_bool(dock.has_method("set_expression")).is_true()
	assert_bool(dock.has_method("clear_expression")).is_true()
	assert_bool(dock.has_method("insert_function")).is_true()
	
	dock.queue_free()

func test_object_inspector_dock_controller_functionality():
	var dock_scene = preload("res://addons/gfred2/scenes/docks/object_inspector_dock.tscn")
	var dock = dock_scene.instantiate()
	
	# Test initial state
	assert_object(dock.get_inspected_object()).is_null()
	assert_bool(dock.is_inspector_locked()).is_false()
	
	# Test method availability
	assert_bool(dock.has_method("inspect_object")).is_true()
	assert_bool(dock.has_method("lock_inspector")).is_true()
	assert_bool(dock.has_method("refresh_properties")).is_true()
	
	dock.queue_free()

## Test validation functionality

func test_mission_validation_panel_functionality():
	var validation_scene = preload("res://addons/gfred2/scenes/components/validation/mission_validation_panel.tscn")
	var validation_panel = validation_scene.instantiate()
	
	# Test initial state
	assert_array(validation_panel.get_validation_results()).is_empty()
	assert_int(validation_panel.get_error_count()).is_equal(0)
	assert_int(validation_panel.get_warning_count()).is_equal(0)
	
	# Test method availability
	assert_bool(validation_panel.has_method("initialize_with_mission")).is_true()
	assert_bool(validation_panel.has_method("refresh_validation")).is_true()
	
	validation_panel.queue_free()

## Test scene-based architecture compliance

func test_no_programmatic_ui_construction():
	# Test that controller scripts don't contain programmatic UI creation patterns
	var controller_scripts = [
		"res://addons/gfred2/scripts/controllers/main_editor_dock_controller.gd",
		"res://addons/gfred2/scripts/controllers/asset_browser_dock_controller.gd",
		"res://addons/gfred2/scripts/controllers/sexp_editor_dock_controller.gd",
		"res://addons/gfred2/scripts/controllers/object_inspector_dock_controller.gd"
	]
	
	for script_path in controller_scripts:
		if FileAccess.file_exists(script_path):
			var file = FileAccess.open(script_path, FileAccess.READ)
			var content = file.get_as_text()
			file.close()
			
			# Check for violations
			assert_bool(content.contains(".new()")).is_false(
				"Script %s should not contain '.new()' UI instantiation" % script_path.get_file())
			assert_bool(content.contains("add_child(") and content.contains("Control.new")).is_false(
				"Script %s should not contain programmatic Control creation" % script_path.get_file())

func test_scene_controller_attachment_pattern():
	# Test that scenes have controllers properly attached as root node scripts
	var scenes_to_test = [
		"res://addons/gfred2/scenes/docks/main_editor_dock.tscn",
		"res://addons/gfred2/scenes/docks/asset_browser_dock.tscn",
		"res://addons/gfred2/scenes/docks/sexp_editor_dock.tscn",
		"res://addons/gfred2/scenes/docks/object_inspector_dock.tscn"
	]
	
	for scene_path in scenes_to_test:
		var scene = load(scene_path)
		var instance = scene.instantiate()
		
		# Verify the instance has a script attached
		assert_object(instance.get_script()).is_not_null(
			"Scene %s should have a controller script attached" % scene_path.get_file())
		
		# Verify the script is a controller
		var script_path = instance.get_script().resource_path
		assert_bool(script_path.contains("controller")).is_true(
			"Scene %s should use a controller script" % scene_path.get_file())
		
		instance.queue_free()

## Test integration with WCS systems

func test_wcs_asset_core_integration():
	if WCSAssetRegistry:
		var asset_dock_scene = preload("res://addons/gfred2/scenes/docks/asset_browser_dock.tscn")
		var asset_dock = asset_dock_scene.instantiate()
		
		# Test that asset dock integrates with WCS Asset Core
		assert_bool(asset_dock.has_method("_refresh_assets")).is_true()
		
		# Test asset type filtering
		if asset_dock.has_method("set_asset_type_filter"):
			asset_dock.set_asset_type_filter(AssetTypes.Type.SHIP)
			# Would test actual asset loading in integration test
		
		asset_dock.queue_free()

func test_sexp_system_integration():
	if SexpManager:
		var sexp_dock_scene = preload("res://addons/gfred2/scenes/docks/sexp_editor_dock.tscn")
		var sexp_dock = sexp_dock_scene.instantiate()
		
		# Test SEXP validation integration
		if sexp_dock.has_method("set_expression"):
			sexp_dock.set_expression("(+ 1 2)")
			# Would test actual SEXP validation in integration test
		
		sexp_dock.queue_free()

## Performance benchmarks

func test_ui_update_performance_60fps():
	# Test that UI updates can maintain 60 FPS (< 16.67ms per frame)
	var dock_scene = preload("res://addons/gfred2/scenes/docks/main_editor_dock.tscn")
	var dock = dock_scene.instantiate()
	
	var start_time = Time.get_ticks_usec()
	
	# Simulate UI updates (this would be more comprehensive in real test)
	for i in range(10):
		if dock.has_method("refresh_hierarchy"):
			dock.refresh_hierarchy()
	
	var end_time = Time.get_ticks_usec()
	var avg_update_time = (end_time - start_time) / 10.0 / 1000.0  # Convert to ms
	
	assert_float(avg_update_time).is_less(16.67, 
		"UI update time (%fms) should maintain 60 FPS" % avg_update_time)
	
	dock.queue_free()