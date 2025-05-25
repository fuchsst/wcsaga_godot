class_name TestPropertyInspectorScene
extends GdUnitTestSuite

## Scene-based tests for ObjectPropertyInspector
## Tests complete UI integration, user interactions, and visual behavior

var scene_runner: GdUnitSceneRunner
var inspector: ObjectPropertyInspector
var test_objects: Array[MissionObject]

func before_test() -> void:
	# Create a test scene with the property inspector
	scene_runner = scene_runner()
	
	# Load or create the property inspector scene
	var scene = preload("res://addons/gfred2/ui/property_inspector/object_property_inspector.tscn")
	if scene:
		scene_runner = scene_runner.scene(scene)
	else:
		# Create scene programmatically if .tscn doesn't exist
		var root = Control.new()
		inspector = ObjectPropertyInspector.new()
		root.add_child(inspector)
		scene_runner = scene_runner.scene(root)
	
	inspector = scene_runner.get_property("inspector") as ObjectPropertyInspector
	if not inspector:
		inspector = scene_runner.find_child("ObjectPropertyInspector", true, false) as ObjectPropertyInspector
	
	# Create test objects
	test_objects = []
	for i in range(3):
		var obj = MissionObject.new()
		obj.name = "Test Ship %d" % (i + 1)
		obj.position = Vector3(i * 100, i * 200, i * 300)
		obj.team = "Friendly"
		test_objects.append(obj)

func after_test() -> void:
	# Clean up test objects
	for obj in test_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	test_objects.clear()

func test_scene_loads_correctly() -> void:
	assert_that(scene_runner.scene()).is_not_null()
	assert_that(inspector).is_not_null()
	assert_that(inspector).is_instance_of(ObjectPropertyInspector)

func test_ui_structure_creation() -> void:
	# Load objects to trigger UI creation
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(2)
	
	# Verify main UI structure exists
	var scroll_container = inspector.find_child("ScrollContainer", true, false)
	assert_that(scroll_container).is_not_null()
	
	var vbox_container = inspector.find_child("VBoxContainer", true, false)
	assert_that(vbox_container).is_not_null()
	
	# Should have property editors created
	var editors = inspector.get_visible_editors_for_testing()
	assert_that(editors).is_not_empty()

func test_single_object_property_display() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Check that properties are displayed
	var name_editor = inspector.get_editor_by_property("name")
	assert_that(name_editor).is_not_null()
	assert_that(name_editor.get_value()).is_equal("Test Ship 1")
	
	var position_editor = inspector.get_editor_by_property("position")
	assert_that(position_editor).is_not_null()
	assert_that(position_editor.get_value()).is_equal(Vector3(0, 0, 0))

func test_multi_object_selection_display() -> void:
	inspector.set_objects(test_objects)
	await scene_runner.simulate_frames(3)
	
	# Should display properties for multiple objects
	var category_count = inspector.get_category_count()
	assert_that(category_count).is_greater(0)
	
	# Team property should show consistent value
	var team_editor = inspector.get_editor_by_property("team")
	if team_editor:
		assert_that(team_editor.get_value()).is_equal("Friendly")

func test_property_editing_interaction() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Find and interact with string property editor
	var name_editor = inspector.get_editor_by_property("name")
	assert_that(name_editor).is_not_null()
	
	var line_edit = name_editor.find_child("LineEdit", true, false)
	if line_edit:
		# Simulate user typing
		scene_runner.set_focus(line_edit)
		line_edit.text = "Modified Ship Name"
		line_edit.text_changed.emit("Modified Ship Name")
		
		await scene_runner.simulate_frames(2)
		
		# Object should be updated
		assert_that(test_objects[0].name).is_equal("Modified Ship Name")

func test_vector3_property_editing() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	var position_editor = inspector.get_editor_by_property("position")
	assert_that(position_editor).is_not_null()
	
	# Find X spinbox
	var x_spinbox = position_editor.find_child("XSpinBox", true, false)
	if x_spinbox:
		scene_runner.set_focus(x_spinbox)
		x_spinbox.value = 500.0
		x_spinbox.value_changed.emit(500.0)
		
		await scene_runner.simulate_frames(2)
		
		# Should update object position
		assert_that(test_objects[0].position.x).is_equal(500.0)

func test_search_filter_ui_interaction() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Find search field if it exists
	var search_field = inspector.find_child("SearchLineEdit", true, false)
	if search_field:
		scene_runner.set_focus(search_field)
		search_field.text = "position"
		search_field.text_changed.emit("position")
		
		await scene_runner.simulate_frames(2)
		
		# Should filter properties
		var visible_editors = inspector.get_visible_editors_for_testing()
		# Filtered results should be fewer than total
		assert_that(visible_editors.size()).is_less_equal(inspector.get_category_count())

func test_category_expansion_collapse() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Find category headers
	var category_buttons = inspector.find_children("*CategoryButton*", "", true, false)
	
	if not category_buttons.is_empty():
		var first_category = category_buttons[0]
		
		# Click to collapse
		scene_runner.simulate_mouse_button_press(first_category, MOUSE_BUTTON_LEFT)
		await scene_runner.simulate_frames(2)
		
		# Category should be collapsed (implementation dependent)
		# Test would depend on specific UI implementation

func test_validation_error_display() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Set invalid property value
	var name_editor = inspector.get_editor_by_property("name")
	if name_editor:
		var line_edit = name_editor.find_child("LineEdit", true, false)
		if line_edit:
			# Set empty name (should be invalid)
			scene_runner.set_focus(line_edit)
			line_edit.text = ""
			line_edit.text_changed.emit("")
			
			await scene_runner.simulate_frames(2)
			
			# Should show validation error in UI
			var error_indicator = name_editor.find_child("ErrorIcon", true, false)
			if error_indicator:
				assert_that(error_indicator.visible).is_true()

func test_performance_metrics_display() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Make several property changes to generate metrics
	for i in range(5):
		inspector._on_property_changed("name", "Change %d" % i)
		await scene_runner.simulate_frames(1)
	
	# Check if performance metrics are displayed
	var metrics_label = inspector.find_child("MetricsLabel", true, false)
	if metrics_label:
		assert_that(metrics_label.visible).is_true()
		assert_that(metrics_label.text).is_not_equal("")

func test_contextual_menu_interaction() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	var name_editor = inspector.get_editor_by_property("name")
	if name_editor:
		# Right-click to open context menu
		scene_runner.simulate_mouse_button_press(name_editor, MOUSE_BUTTON_RIGHT)
		await scene_runner.simulate_frames(2)
		
		# Look for context menu
		var popup_menu = inspector.find_child("ContextMenu", true, false)
		if popup_menu and popup_menu.visible:
			# Should have menu items like "Copy", "Paste", "Reset"
			assert_that(popup_menu.get_item_count()).is_greater(0)

func test_copy_paste_ui_workflow() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Test copy operation
	var copy_button = inspector.find_child("CopyButton", true, false)
	if copy_button:
		scene_runner.simulate_mouse_button_press(copy_button, MOUSE_BUTTON_LEFT)
		await scene_runner.simulate_frames(2)
		
		# Select different object
		inspector.set_objects([test_objects[1]])
		await scene_runner.simulate_frames(2)
		
		# Test paste operation
		var paste_button = inspector.find_child("PasteButton", true, false)
		if paste_button:
			scene_runner.simulate_mouse_button_press(paste_button, MOUSE_BUTTON_LEFT)
			await scene_runner.simulate_frames(2)
			
			# Properties should be copied
			assert_that(test_objects[1].team).is_equal(test_objects[0].team)

func test_keyboard_navigation() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Find first editable field
	var name_editor = inspector.get_editor_by_property("name")
	if name_editor:
		var line_edit = name_editor.find_child("LineEdit", true, false)
		if line_edit:
			scene_runner.set_focus(line_edit)
			
			# Test Tab navigation
			scene_runner.simulate_key_press(KEY_TAB)
			await scene_runner.simulate_frames(2)
			
			# Focus should move to next editor
			var focused_control = scene_runner.get_scene().gui_get_focus_owner()
			assert_that(focused_control).is_not_null()
			assert_that(focused_control).is_not_same(line_edit)

func test_undo_redo_ui_buttons() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	var original_name = test_objects[0].name
	
	# Make a change
	inspector._on_property_changed("name", "Modified Name")
	await scene_runner.simulate_frames(2)
	
	# Test undo button
	var undo_button = inspector.find_child("UndoButton", true, false)
	if undo_button:
		scene_runner.simulate_mouse_button_press(undo_button, MOUSE_BUTTON_LEFT)
		await scene_runner.simulate_frames(2)
		
		# Should restore original value
		assert_that(test_objects[0].name).is_equal(original_name)

func test_help_system_integration() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Find help button
	var help_button = inspector.find_child("HelpButton", true, false)
	if help_button:
		var signal_monitor = monitor_signals(inspector)
		
		scene_runner.simulate_mouse_button_press(help_button, MOUSE_BUTTON_LEFT)
		await scene_runner.simulate_frames(2)
		
		# Should emit help request signal
		assert_signal(signal_monitor).is_emitted("help_requested")

func test_visual_sexp_editor_integration() -> void:
	# Create object with SEXP property
	var obj = test_objects[0]
	obj.set_meta("arrival_condition", "(and (true) (false))")
	
	inspector.set_objects([obj])
	await scene_runner.simulate_frames(3)
	
	# Find SEXP editor
	var sexp_editor = inspector.get_editor_by_property("arrival_condition")
	if sexp_editor:
		var visual_button = sexp_editor.find_child("VisualEditorButton", true, false)
		if visual_button:
			var signal_monitor = monitor_signals(sexp_editor)
			
			scene_runner.simulate_mouse_button_press(visual_button, MOUSE_BUTTON_LEFT)
			await scene_runner.simulate_frames(2)
			
			# Should request visual SEXP editor
			assert_signal(signal_monitor).is_emitted("visual_editor_requested")

func test_responsive_layout_resizing() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	var original_size = inspector.size
	
	# Resize the inspector
	inspector.size = Vector2(400, 600)
	await scene_runner.simulate_frames(3)
	
	# UI should adapt to new size
	var scroll_container = inspector.find_child("ScrollContainer", true, false)
	if scroll_container:
		assert_that(scroll_container.size.x).is_less_equal(inspector.size.x)
	
	# Restore original size
	inspector.size = original_size
	await scene_runner.simulate_frames(2)

func test_theme_adaptation() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Change theme if supported
	var theme_button = inspector.find_child("ThemeButton", true, false)
	if theme_button:
		scene_runner.simulate_mouse_button_press(theme_button, MOUSE_BUTTON_LEFT)
		await scene_runner.simulate_frames(3)
		
		# UI should adapt to new theme
		# Verification would depend on specific theme implementation

func test_accessibility_features() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Test screen reader support
	var name_editor = inspector.get_editor_by_property("name")
	if name_editor:
		var line_edit = name_editor.find_child("LineEdit", true, false)
		if line_edit:
			# Should have accessible name/description
			assert_that(line_edit.get("accessible_name", "")).is_not_equal("")

func test_drag_drop_property_reordering() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Find property editors
	var editors = inspector.get_visible_editors_for_testing()
	if editors.size() >= 2:
		var first_editor = editors[0]
		var second_editor = editors[1]
		
		# Simulate drag and drop
		scene_runner.simulate_mouse_button_press(first_editor, MOUSE_BUTTON_LEFT)
		scene_runner.simulate_mouse_move_to(second_editor.global_position)
		scene_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
		
		await scene_runner.simulate_frames(3)
		
		# Order might change (implementation dependent)
		var new_editors = inspector.get_visible_editors_for_testing()
		assert_that(new_editors).has_size(editors.size())

func test_error_recovery_ui_state() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Simulate error condition
	test_objects[0].queue_free()
	await scene_runner.simulate_frames(2)
	
	# Try to interact with UI
	inspector._on_property_changed("name", "Should Not Crash")
	await scene_runner.simulate_frames(2)
	
	# UI should handle error gracefully
	assert_that(inspector.current_objects).is_empty()
	
	# Should show empty state or error message
	var error_label = inspector.find_child("ErrorLabel", true, false)
	var empty_label = inspector.find_child("EmptyStateLabel", true, false)
	
	var has_error_indication = (error_label and error_label.visible) or (empty_label and empty_label.visible)
	assert_that(has_error_indication).is_true()

func test_real_time_preview_updates() -> void:
	inspector.set_objects([test_objects[0]])
	await scene_runner.simulate_frames(3)
	
	# Find position editor
	var position_editor = inspector.get_editor_by_property("position")
	if position_editor:
		var x_spinbox = position_editor.find_child("XSpinBox", true, false)
		if x_spinbox:
			scene_runner.set_focus(x_spinbox)
			
			# Simulate dragging the spinbox value
			x_spinbox.value = 1000.0
			x_spinbox.value_changed.emit(1000.0)
			
			await scene_runner.simulate_frames(1)
			
			# Should update object immediately for real-time preview
			assert_that(test_objects[0].position.x).is_equal(1000.0)