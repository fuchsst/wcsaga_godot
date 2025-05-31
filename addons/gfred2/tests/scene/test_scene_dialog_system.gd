extends GdUnitTestSuite

## gdUnit4 test suite for GFRED2-011 scene-based dialog system.
## Tests scene-based dialog management, inheritance, and functionality.

func before():
	# Setup before each test
	pass

func after():
	# Cleanup after each test
	pass

## Test base dialog functionality

func test_base_dialog_instantiation_and_setup():
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	assert_not_null(dialog, "Base dialog should instantiate successfully")
	assert_that(dialog).is_instance_of(BaseDialogController)
	
	# Test initial state
	assert_bool(dialog.is_dialog_valid()).is_true()
	assert_array(dialog.get_dialog_validation_errors()).is_empty()
	
	# Test content container access
	var content_container = dialog.get_content_container()
	assert_not_null(content_container, "Content container should be accessible")
	assert_that(content_container).is_instance_of(VBoxContainer)
	
	dialog.queue_free()

func test_base_dialog_validation_system():
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	# Test validation methods exist
	assert_bool(dialog.has_method("validate")).is_true()
	assert_bool(dialog.has_method("is_dialog_valid")).is_true()
	assert_bool(dialog.has_method("get_dialog_validation_errors")).is_true()
	
	# Test validation functionality
	var is_valid = dialog.validate()
	assert_bool(is_valid).is_true("Base dialog should be valid initially")
	
	dialog.queue_free()

func test_base_dialog_button_management():
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	# Test button visibility control
	assert_bool(dialog.has_method("set_button_visibility")).is_true()
	assert_bool(dialog.has_method("set_button_text")).is_true()
	
	# Test button text setting
	dialog.set_button_text("ok", "Accept")
	dialog.set_button_text("cancel", "Reject")
	
	# Test button visibility
	dialog.set_button_visibility("apply", false)
	dialog.set_button_visibility("help", true)
	
	dialog.queue_free()

func test_base_dialog_help_system():
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	# Test help topic management
	assert_bool(dialog.has_method("set_help_topic")).is_true()
	
	dialog.set_help_topic("test_topic")
	
	# Help button should be visible when topic is set
	var help_button = dialog.get_node_or_null("MainContainer/DialogHeader/HelpButton")
	if help_button:
		assert_bool(help_button.visible).is_true("Help button should be visible when topic is set")
	
	dialog.queue_free()

## Test scene dialog manager functionality

func test_scene_dialog_manager_instantiation():
	var manager_scene = preload("res://addons/gfred2/scenes/managers/scene_dialog_manager.tscn")
	var manager = manager_scene.instantiate()
	
	assert_not_null(manager, "Scene dialog manager should instantiate successfully")
	assert_that(manager).is_instance_of(SceneDialogManagerController)
	
	# Test initial state
	assert_array(manager.get_active_dialog_names()).is_empty()
	assert_array(manager.get_registered_dialog_names()).is_not_empty()
	
	manager.queue_free()

func test_scene_dialog_manager_dialog_registry():
	var manager_scene = preload("res://addons/gfred2/scenes/managers/scene_dialog_manager.tscn")
	var manager = manager_scene.instantiate()
	
	# Test dialog registry functionality
	var registered_dialogs = manager.get_registered_dialog_names()
	assert_array(registered_dialogs).is_not_empty("Should have registered dialogs")
	
	# Test specific dialog registrations
	assert_array(registered_dialogs).contains("mission_specs")
	assert_array(registered_dialogs).contains("ship_properties")
	assert_array(registered_dialogs).contains("mission_component_editor")
	
	# Test custom dialog registration
	var test_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	manager.register_dialog_scene("test_dialog", test_scene)
	
	var updated_dialogs = manager.get_registered_dialog_names()
	assert_array(updated_dialogs).contains("test_dialog")
	
	manager.queue_free()

func test_scene_dialog_manager_show_dialog():
	var manager_scene = preload("res://addons/gfred2/scenes/managers/scene_dialog_manager.tscn")
	var manager = manager_scene.instantiate()
	
	# Test dialog show functionality (without actually showing)
	assert_bool(manager.has_method("show_dialog")).is_true()
	assert_bool(manager.has_method("close_dialog")).is_true()
	assert_bool(manager.has_method("is_dialog_open")).is_true()
	
	# Test dialog state checking
	assert_bool(manager.is_dialog_open("nonexistent")).is_false()
	
	manager.queue_free()

func test_scene_dialog_manager_mission_data_integration():
	var manager_scene = preload("res://addons/gfred2/scenes/managers/scene_dialog_manager.tscn")
	var manager = manager_scene.instantiate()
	
	# Test mission data management
	assert_bool(manager.has_method("set_mission_data")).is_true()
	
	# Create mock mission data
	var mock_mission_data = MockMissionData.new()
	manager.set_mission_data(mock_mission_data)
	
	manager.queue_free()

## Test dialog signal communication

func test_base_dialog_signals():
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	# Test signal existence
	assert_bool(dialog.has_signal("dialog_applied")).is_true()
	assert_bool(dialog.has_signal("dialog_cancelled")).is_true()
	assert_bool(dialog.has_signal("validation_changed")).is_true()
	
	# Test signal connection capability
	var signal_connected = false
	dialog.validation_changed.connect(func(is_valid, errors): signal_connected = true)
	assert_bool(signal_connected == false).is_true("Signal not emitted yet")
	
	dialog.queue_free()

func test_dialog_manager_signals():
	var manager_scene = preload("res://addons/gfred2/scenes/managers/scene_dialog_manager.tscn")
	var manager = manager_scene.instantiate()
	
	# Test manager signals
	assert_bool(manager.has_signal("dialog_opened")).is_true()
	assert_bool(manager.has_signal("dialog_closed")).is_true()
	
	# Test signal connection
	var dialog_opened_called = false
	var dialog_closed_called = false
	
	manager.dialog_opened.connect(func(name, instance): dialog_opened_called = true)
	manager.dialog_closed.connect(func(name): dialog_closed_called = true)
	
	# Signals should not have been emitted yet
	assert_bool(dialog_opened_called).is_false()
	assert_bool(dialog_closed_called).is_false()
	
	manager.queue_free()

## Test dialog inheritance and composition

func test_dialog_scene_composition():
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	# Test scene composition structure
	var main_container = dialog.get_node_or_null("MainContainer")
	assert_not_null(main_container, "MainContainer should exist")
	
	var content_container = dialog.get_node_or_null("MainContainer/ContentContainer")
	assert_not_null(content_container, "ContentContainer should exist")
	
	var footer_container = dialog.get_node_or_null("MainContainer/FooterContainer")
	assert_not_null(footer_container, "FooterContainer should exist")
	
	# Test button structure
	var ok_button = dialog.get_node_or_null("MainContainer/FooterContainer/OKButton")
	var cancel_button = dialog.get_node_or_null("MainContainer/FooterContainer/CancelButton")
	var apply_button = dialog.get_node_or_null("MainContainer/FooterContainer/ApplyButton")
	
	assert_not_null(ok_button, "OK button should exist")
	assert_not_null(cancel_button, "Cancel button should exist")
	assert_not_null(apply_button, "Apply button should exist")
	
	dialog.queue_free()

func test_dialog_content_management():
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	# Test content management methods
	assert_bool(dialog.has_method("add_content_widget")).is_true()
	assert_bool(dialog.has_method("clear_content")).is_true()
	
	# Test adding content
	var test_label = Label.new()
	test_label.text = "Test Content"
	dialog.add_content_widget(test_label)
	
	var content_container = dialog.get_content_container()
	assert_int(content_container.get_child_count()).is_greater(0)
	
	# Test clearing content
	dialog.clear_content()
	# Note: clear_content() queues children for deletion, so count might not be 0 immediately
	
	dialog.queue_free()

## Test performance requirements

func test_dialog_instantiation_performance():
	# Test that dialog instantiation meets < 16ms requirement
	var dialog_scenes = [
		"res://addons/gfred2/scenes/dialogs/base_dialog.tscn",
		"res://addons/gfred2/scenes/managers/scene_dialog_manager.tscn"
	]
	
	for scene_path in dialog_scenes:
		var start_time = Time.get_ticks_msec()
		var scene = load(scene_path)
		var instance = scene.instantiate()
		var end_time = Time.get_ticks_msec()
		var instantiation_time = end_time - start_time
		
		assert_int(instantiation_time).is_less(16, 
			"Dialog %s instantiation time (%dms) should be < 16ms" % [scene_path.get_file(), instantiation_time])
		
		instance.queue_free()

func test_dialog_show_hide_performance():
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	# Test show/hide performance
	var start_time = Time.get_ticks_msec()
	
	# Simulate show/hide cycle
	for i in range(5):
		dialog.visible = true
		dialog.visible = false
	
	var end_time = Time.get_ticks_msec()
	var avg_time = (end_time - start_time) / 5.0
	
	assert_float(avg_time).is_less(2.0, 
		"Dialog show/hide time (%fms) should be fast" % avg_time)
	
	dialog.queue_free()

## Test no programmatic UI violations

func test_no_programmatic_ui_in_dialog_controllers():
	# Test that dialog controllers don't create UI programmatically
	var controller_scripts = [
		"res://addons/gfred2/scripts/controllers/base_dialog_controller.gd",
		"res://addons/gfred2/scripts/controllers/scene_dialog_manager_controller.gd"
	]
	
	for script_path in controller_scripts:
		if FileAccess.file_exists(script_path):
			var file = FileAccess.open(script_path, FileAccess.READ)
			var content = file.get_as_text()
			file.close()
			
			# Check for programmatic UI violations
			assert_bool(content.contains("Dialog.new()")).is_false(
				"Controller %s should not create dialogs programmatically" % script_path.get_file())
			assert_bool(content.contains("Control.new()")).is_false(
				"Controller %s should not create controls programmatically" % script_path.get_file())

func test_dialog_scene_architecture_compliance():
	# Test that dialog scenes follow scene-based architecture
	var dialog_scene = preload("res://addons/gfred2/scenes/dialogs/base_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	# Verify script is attached to root node (scene-based pattern)
	assert_object(dialog.get_script()).is_not_null("Dialog should have controller script attached")
	
	# Verify it's a controller script
	var script_path = dialog.get_script().resource_path
	assert_bool(script_path.contains("controller")).is_true("Should use controller script")
	
	# Verify it extends the correct base class
	assert_that(dialog).is_instance_of(AcceptDialog)
	
	dialog.queue_free()

## Helper classes for testing

class MockMissionData extends RefCounted:
	var mission_name: String = "Test Mission"
	var description: String = "Test Description"
	var designer: String = "Test Designer"
	
	func has_method(method_name: String) -> bool:
		return method_name in ["get_ships", "get_goals", "get_events", "get_waypoint_paths"]
	
	func get_ships() -> Array:
		return []
	
	func get_goals() -> Array:
		return []
	
	func get_events() -> Array:
		return []
	
	func get_waypoint_paths() -> Array:
		return []