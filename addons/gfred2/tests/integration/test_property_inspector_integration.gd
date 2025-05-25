class_name TestPropertyInspectorIntegration
extends GdUnitTestSuite

## Integration tests for Property Inspector with other FRED2 systems
## Tests real-world usage scenarios and system interactions

var inspector: ObjectPropertyInspector
var object_manager: MissionObjectManager
var validator: ObjectValidator
var test_scene: PackedScene
var main_ui: Fred2MainUI

func before_test() -> void:
	# Set up complete integration environment
	object_manager = MissionObjectManager.new()
	validator = ObjectValidator.new()
	inspector = ObjectPropertyInspector.new(null, validator, null)
	main_ui = Fred2MainUI.new()
	
	# Add to scene tree for full integration testing
	add_child(main_ui)
	main_ui.add_child(inspector)
	main_ui.add_child(object_manager)

func after_test() -> void:
	if main_ui and is_instance_valid(main_ui):
		main_ui.queue_free()

func test_mission_object_creation_and_editing() -> void:
	# Create a mission object through the manager
	var ship_data = {
		"name": "Alpha 1",
		"class": "GTF Apollo",
		"position": Vector3(1000, 500, 2000),
		"orientation": Vector3(0, 0, 0),
		"team": "Friendly",
		"arrival_condition": "(true)"
	}
	
	var ship = object_manager.create_object("ship", ship_data)
	assert_that(ship).is_not_null()
	
	# Edit the object in property inspector
	inspector.set_objects([ship])
	
	# Verify all properties are displayed
	assert_that(inspector.get_category_count()).is_greater(0)
	
	var name_editor = inspector.get_editor_by_property("name")
	assert_that(name_editor).is_not_null()
	assert_that(name_editor.get_value()).is_equal("Alpha 1")
	
	var pos_editor = inspector.get_editor_by_property("position")
	assert_that(pos_editor).is_not_null()
	assert_that(pos_editor.get_value()).is_equal(Vector3(1000, 500, 2000))

func test_multi_object_selection_editing() -> void:
	# Create multiple ships
	var ships: Array[MissionObject] = []
	for i in range(3):
		var ship_data = {
			"name": "Alpha %d" % (i + 1),
			"class": "GTF Apollo",
			"position": Vector3(i * 100, 0, 0),
			"team": "Friendly"
		}
		ships.append(object_manager.create_object("ship", ship_data))
	
	# Select all ships
	inspector.set_objects(ships)
	
	# Change a common property
	var signal_monitor = monitor_signals(inspector)
	inspector._on_property_changed("team", "Hostile")
	
	# All ships should be updated
	for ship in ships:
		assert_that(ship.team).is_equal("Hostile")
	
	assert_signal(signal_monitor).is_emitted("property_changed")

func test_validation_integration_with_object_manager() -> void:
	var ship = object_manager.create_object("ship", {
		"name": "Test Ship",
		"class": "GTF Apollo",
		"position": Vector3.ZERO
	})
	
	inspector.set_objects([ship])
	
	# Try to set invalid name (empty)
	var signal_monitor = monitor_signals(inspector)
	inspector._on_property_changed("name", "")
	
	# Should emit validation error
	assert_signal(signal_monitor).is_emitted("validation_error")
	
	# Object should not be updated with invalid value
	assert_that(ship.name).is_not_equal("")

func test_undo_redo_system_integration() -> void:
	var ship = object_manager.create_object("ship", {
		"name": "Original Name",
		"position": Vector3(100, 200, 300)
	})
	
	inspector.set_objects([ship])
	
	# Make changes
	inspector._on_property_changed("name", "New Name")
	inspector._on_property_changed("position", Vector3(500, 600, 700))
	
	assert_that(ship.name).is_equal("New Name")
	assert_that(ship.position).is_equal(Vector3(500, 600, 700))
	
	# Test undo system if available
	if object_manager.has_method("undo_last_operation"):
		object_manager.undo_last_operation()
		assert_that(ship.position).is_equal(Vector3(100, 200, 300))
		
		object_manager.undo_last_operation()
		assert_that(ship.name).is_equal("Original Name")

func test_copy_paste_integration() -> void:
	# Create source object
	var source_ship = object_manager.create_object("ship", {
		"name": "Source Ship",
		"class": "GTF Apollo",
		"position": Vector3(1000, 2000, 3000),
		"team": "Friendly"
	})
	
	# Create target object
	var target_ship = object_manager.create_object("ship", {
		"name": "Target Ship",
		"class": "GTF Hercules",
		"position": Vector3.ZERO,
		"team": "Hostile"
	})
	
	# Copy properties from source
	inspector.set_objects([source_ship])
	if inspector.has_method("copy_properties"):
		inspector.copy_properties()
	
	# Paste to target
	inspector.set_objects([target_ship])
	if inspector.has_method("paste_properties"):
		inspector.paste_properties()
		
		# Some properties should be copied
		assert_that(target_ship.position).is_equal(Vector3(1000, 2000, 3000))
		assert_that(target_ship.team).is_equal("Friendly")
		# Name and class might not be copied depending on implementation

func test_fred2_main_ui_coordination() -> void:
	var ship = object_manager.create_object("ship", {
		"name": "UI Test Ship",
		"position": Vector3(500, 1000, 1500)
	})
	
	# Simulate selection from main UI
	main_ui._on_object_selected([ship])
	
	# Property inspector should update
	assert_that(inspector.current_objects).contains(ship)
	
	# Test property change coordination
	var signal_monitor = monitor_signals(main_ui)
	inspector._on_property_changed("name", "Updated Name")
	
	# Main UI should be notified of changes
	assert_signal(signal_monitor).is_emitted("object_properties_changed")

func test_object_hierarchy_integration() -> void:
	# Create parent-child relationship
	var wing_leader = object_manager.create_object("ship", {
		"name": "Alpha 1",
		"class": "GTF Apollo",
		"position": Vector3.ZERO
	})
	
	var wingman = object_manager.create_object("ship", {
		"name": "Alpha 2",
		"class": "GTF Apollo",
		"position": Vector3(100, 0, 0),
		"parent": wing_leader
	})
	
	# Edit child object
	inspector.set_objects([wingman])
	
	# Change position - should maintain relative position to parent
	inspector._on_property_changed("position", Vector3(200, 0, 0))
	
	# Verify relationship is maintained
	assert_that(wingman.position).is_equal(Vector3(200, 0, 0))
	if wingman.has_method("get_world_position"):
		var world_pos = wingman.get_world_position()
		assert_that(world_pos).is_not_equal(wingman.position)  # Should be relative to parent

func test_real_time_validation_feedback() -> void:
	var ship = object_manager.create_object("ship", {
		"name": "Validation Test",
		"position": Vector3.ZERO,
		"arrival_condition": "(true)"
	})
	
	inspector.set_objects([ship])
	
	# Monitor validation signals
	var signal_monitor = monitor_signals(inspector)
	
	# Set invalid SEXP expression
	inspector._on_property_changed("arrival_condition", "(invalid sexp")
	
	# Should emit validation error immediately
	assert_signal(signal_monitor).is_emitted("validation_error")
	
	# Fix the SEXP
	inspector._on_property_changed("arrival_condition", "(and (true) (false))")
	
	# Should clear validation errors
	assert_signal(signal_monitor).is_emitted("validation_cleared")

func test_performance_with_large_missions() -> void:
	# Create a large number of objects
	var objects: Array[MissionObject] = []
	for i in range(100):
		var obj = object_manager.create_object("ship", {
			"name": "Ship_%03d" % i,
			"class": "GTF Apollo",
			"position": Vector3(i * 100, 0, 0)
		})
		objects.append(obj)
	
	# Test selection performance
	var start_time = Time.get_ticks_msec()
	inspector.set_objects(objects)
	var selection_time = Time.get_ticks_msec() - start_time
	
	# Should handle large selections reasonably quickly
	assert_that(selection_time).is_less(1000)  # Less than 1 second
	
	# Test property change performance
	start_time = Time.get_ticks_msec()
	inspector._on_property_changed("team", "Hostile")
	var change_time = Time.get_ticks_msec() - start_time
	
	# Should update all objects quickly
	assert_that(change_time).is_less(500)  # Less than 500ms
	
	# Verify all objects were updated
	for obj in objects:
		assert_that(obj.team).is_equal("Hostile")

func test_contextual_help_system() -> void:
	var ship = object_manager.create_object("ship", {
		"name": "Help Test Ship",
		"arrival_condition": "(true)"
	})
	
	inspector.set_objects([ship])
	
	# Request help for SEXP property
	var signal_monitor = monitor_signals(main_ui)
	if inspector.has_method("show_property_help"):
		inspector.show_property_help("arrival_condition")
		
		# Should show help in main UI
		assert_signal(signal_monitor).is_emitted("show_help")

func test_save_load_integration() -> void:
	var ship = object_manager.create_object("ship", {
		"name": "Save Test Ship",
		"position": Vector3(1000, 2000, 3000),
		"class": "GTF Apollo"
	})
	
	# Edit properties
	inspector.set_objects([ship])
	inspector._on_property_changed("name", "Modified Ship")
	inspector._on_property_changed("position", Vector3(5000, 6000, 7000))
	
	# Save mission
	var mission_data = object_manager.serialize_mission()
	assert_that(mission_data).is_not_null()
	
	# Clear and reload
	object_manager.clear_mission()
	assert_that(inspector.current_objects).is_empty()
	
	# Load mission
	object_manager.deserialize_mission(mission_data)
	var loaded_objects = object_manager.get_all_objects()
	
	assert_that(loaded_objects).has_size(1)
	var loaded_ship = loaded_objects[0]
	assert_that(loaded_ship.name).is_equal("Modified Ship")
	assert_that(loaded_ship.position).is_equal(Vector3(5000, 6000, 7000))

func test_error_recovery_invalid_objects() -> void:
	var ship = object_manager.create_object("ship", {
		"name": "Error Test Ship",
		"position": Vector3.ZERO
	})
	
	inspector.set_objects([ship])
	
	# Simulate object being deleted externally
	object_manager.delete_object(ship)
	
	# Property inspector should handle invalid object gracefully
	inspector._on_property_changed("name", "Should Not Crash")
	
	# Should clean up invalid references
	assert_that(inspector.current_objects).is_empty()

func test_plugin_lifecycle_integration() -> void:
	# Test integration with Godot plugin lifecycle
	var plugin = load("res://addons/gfred2/plugin.cfg")
	
	# Simulate plugin activation
	if main_ui.has_method("_on_plugin_activated"):
		main_ui._on_plugin_activated()
		
		# Property inspector should be properly initialized
		assert_that(inspector.property_registry).is_not_null()
		assert_that(inspector.validator).is_not_null()
	
	# Simulate plugin deactivation
	if main_ui.has_method("_on_plugin_deactivated"):
		var signal_monitor = monitor_signals(inspector)
		main_ui._on_plugin_deactivated()
		
		# Should clean up resources
		assert_signal(signal_monitor).is_emitted("cleanup_requested")

func test_mission_validation_workflow() -> void:
	# Create mission with validation issues
	var ship1 = object_manager.create_object("ship", {
		"name": "",  # Invalid empty name
		"position": Vector3.ZERO,
		"arrival_condition": "(invalid"  # Invalid SEXP
	})
	
	var ship2 = object_manager.create_object("ship", {
		"name": "Valid Ship",
		"position": Vector3(100, 200, 300),
		"arrival_condition": "(true)"
	})
	
	# Run mission-wide validation
	inspector.set_objects([ship1, ship2])
	
	if object_manager.has_method("validate_mission"):
		var validation_results = object_manager.validate_mission()
		
		# Should find validation errors
		assert_that(validation_results.get("errors", [])).is_not_empty()
		assert_that(validation_results.get("warnings", [])).is_not_empty()

func test_property_change_notifications() -> void:
	var ship = object_manager.create_object("ship", {
		"name": "Notification Test",
		"position": Vector3.ZERO
	})
	
	inspector.set_objects([ship])
	
	# Set up multiple listeners
	var ui_monitor = monitor_signals(main_ui)
	var manager_monitor = monitor_signals(object_manager)
	var inspector_monitor = monitor_signals(inspector)
	
	# Make property change
	inspector._on_property_changed("position", Vector3(1000, 2000, 3000))
	
	# All systems should be notified
	assert_signal(inspector_monitor).is_emitted("property_changed")
	assert_signal(ui_monitor).is_emitted("object_properties_changed")
	assert_signal(manager_monitor).is_emitted("object_modified")

func test_concurrent_editing_protection() -> void:
	var ship = object_manager.create_object("ship", {
		"name": "Concurrent Test",
		"position": Vector3.ZERO
	})
	
	# Simulate concurrent editing from different sources
	inspector.set_objects([ship])
	
	# External change
	ship.position = Vector3(100, 200, 300)
	object_manager._on_object_modified(ship)
	
	# Property inspector should detect external change
	var signal_monitor = monitor_signals(inspector)
	
	# Should emit notification about external change
	assert_signal(signal_monitor).is_emitted("external_change_detected")
	
	# Should refresh property values
	var pos_editor = inspector.get_editor_by_property("position")
	if pos_editor:
		assert_that(pos_editor.get_value()).is_equal(Vector3(100, 200, 300))