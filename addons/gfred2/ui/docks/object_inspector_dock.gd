@tool
extends Control

## Object Inspector Dock for GFRED2
## Provides property editing interface for selected mission objects.

signal property_changed(object: MissionObject, property_name: String, new_value: Variant)

# UI components
var title_label: Label
var scroll_container: ScrollContainer
var property_container: VBoxContainer
var no_selection_label: Label

# Current state
var selected_objects: Array[MissionObject] = []
var property_editors: Dictionary = {}

# Theme manager reference
var theme_manager: GFRED2ThemeManager

func _ready() -> void:
	_setup_ui()
	name = "ObjectInspector"

func set_theme_manager(manager: GFRED2ThemeManager) -> void:
	"""Set the theme manager for proper styling."""
	theme_manager = manager
	if theme_manager and is_inside_tree():
		theme_manager.apply_theme_to_control(self)

func _setup_ui() -> void:
	"""Setup the dock UI components."""
	# Set minimum size
	custom_minimum_size = Vector2(250, 300)
	
	# Main container
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Title bar
	var title_bar = _create_title_bar()
	main_vbox.add_child(title_bar)
	
	# Content area
	scroll_container = ScrollContainer.new()
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll_container)
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Property container
	property_container = VBoxContainer.new()
	property_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(property_container)
	
	# No selection message
	no_selection_label = Label.new()
	no_selection_label.text = "No objects selected"
	no_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	property_container.add_child(no_selection_label)

func _create_title_bar() -> Control:
	"""Create the dock title bar."""
	var title_bar = Panel.new()
	title_bar.custom_minimum_size = Vector2(0, 30)
	
	var hbox = HBoxContainer.new()
	title_bar.add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	
	# Title
	title_label = Label.new()
	title_label.text = "Object Inspector"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_label)
	
	# Options button
	var options_button = Button.new()
	options_button.text = "⋮"
	options_button.custom_minimum_size = Vector2(24, 24)
	options_button.tooltip_text = "Inspector Options"
	options_button.focus_mode = Control.FOCUS_ALL
	options_button.pressed.connect(_show_options_menu)
	hbox.add_child(options_button)
	
	return title_bar

func set_selected_objects(objects: Array[MissionObject]) -> void:
	"""Set the objects to inspect."""
	selected_objects = objects.duplicate()
	_update_inspector()

func _update_inspector() -> void:
	"""Update the inspector display based on current selection."""
	_clear_property_editors()
	
	if selected_objects.is_empty():
		no_selection_label.visible = true
		no_selection_label.text = "No objects selected"
		return
	
	no_selection_label.visible = false
	
	if selected_objects.size() == 1:
		_show_single_object_properties(selected_objects[0])
	else:
		_show_multi_object_properties()

func _show_single_object_properties(obj: MissionObject) -> void:
	"""Display properties for a single object."""
	title_label.text = "Object Inspector - " + obj.object_name
	
	# Create property sections
	_create_property_section("Basic Properties", obj, [
		"object_name", "object_type", "position", "rotation"
	])
	
	# Add object-type specific properties
	match obj.object_type:
		MissionObject.ObjectType.SHIP:
			_create_property_section("Ship Properties", obj, [
				"ship_class", "team", "ai_behavior"
			])
		MissionObject.ObjectType.WAYPOINT:
			_create_property_section("Waypoint Properties", obj, [
				"waypoint_radius", "waypoint_type"
			])

func _show_multi_object_properties() -> void:
	"""Display properties for multiple objects."""
	title_label.text = "Object Inspector - %d objects" % selected_objects.size()
	
	# Show common properties that can be edited for multiple objects
	_create_multi_property_section("Common Properties", [
		"position", "rotation", "team"
	])

func _create_property_section(section_title: String, obj: MissionObject, properties: Array[String]) -> void:
	"""Create a property section for a single object."""
	# Section header
	var section_label = _create_section_header(section_title)
	property_container.add_child(section_label)
	
	# Property editors
	for property_name in properties:
		var property_editor = _create_property_editor(obj, property_name)
		if property_editor:
			property_container.add_child(property_editor)
			property_editors[property_name] = property_editor

func _create_multi_property_section(section_title: String, properties: Array[String]) -> void:
	"""Create a property section for multiple objects."""
	# Section header
	var section_label = _create_section_header(section_title)
	property_container.add_child(section_label)
	
	# Multi-object property editors
	for property_name in properties:
		var property_editor = _create_multi_property_editor(property_name)
		if property_editor:
			property_container.add_child(property_editor)
			property_editors[property_name] = property_editor

func _create_section_header(title: String) -> Control:
	"""Create a section header label."""
	var header_container = HBoxContainer.new()
	
	var separator1 = HSeparator.new()
	separator1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(separator1)
	
	var label = Label.new()
	label.text = " " + title + " "
	label.add_theme_font_size_override("font_size", 12)
	header_container.add_child(label)
	
	var separator2 = HSeparator.new()
	separator2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(separator2)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(header_container)
	
	return margin

func _create_property_editor(obj: MissionObject, property_name: String) -> Control:
	"""Create a property editor for a specific property."""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	
	# Property label
	var label = Label.new()
	label.text = property_name.capitalize() + ":"
	label.custom_minimum_size = Vector2(100, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	container.add_child(label)
	
	# Property editor based on type
	var editor: Control = null
	var property_value = obj.get(property_name) if obj.has_method("get") else null
	
	if property_value is String:
		editor = _create_string_editor(obj, property_name, property_value)
	elif property_value is int:
		editor = _create_int_editor(obj, property_name, property_value)
	elif property_value is float:
		editor = _create_float_editor(obj, property_name, property_value)
	elif property_value is Vector3:
		editor = _create_vector3_editor(obj, property_name, property_value)
	elif property_value is bool:
		editor = _create_bool_editor(obj, property_name, property_value)
	else:
		# Generic string representation
		editor = _create_string_editor(obj, property_name, str(property_value))
	
	if editor:
		editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(editor)
	
	return container

func _create_multi_property_editor(property_name: String) -> Control:
	"""Create a property editor for multiple objects."""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	
	# Property label
	var label = Label.new()
	label.text = property_name.capitalize() + ":"
	label.custom_minimum_size = Vector2(100, 0)
	container.add_child(label)
	
	# Multi-value editor (shows <multiple values> if different)
	var editor = LineEdit.new()
	editor.placeholder_text = "<multiple values>"
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.focus_mode = Control.FOCUS_ALL
	editor.text_changed.connect(_on_multi_property_changed.bind(property_name))
	container.add_child(editor)
	
	return container

func _create_string_editor(obj: MissionObject, property_name: String, value: String) -> LineEdit:
	"""Create a string property editor."""
	var editor = LineEdit.new()
	editor.text = value
	editor.focus_mode = Control.FOCUS_ALL
	editor.text_changed.connect(_on_property_changed.bind(obj, property_name))
	return editor

func _create_int_editor(obj: MissionObject, property_name: String, value: int) -> SpinBox:
	"""Create an integer property editor."""
	var editor = SpinBox.new()
	editor.value = value
	editor.step = 1
	editor.allow_greater = true
	editor.allow_lesser = true
	editor.focus_mode = Control.FOCUS_ALL
	editor.value_changed.connect(_on_property_changed.bind(obj, property_name))
	return editor

func _create_float_editor(obj: MissionObject, property_name: String, value: float) -> SpinBox:
	"""Create a float property editor."""
	var editor = SpinBox.new()
	editor.value = value
	editor.step = 0.1
	editor.allow_greater = true
	editor.allow_lesser = true
	editor.focus_mode = Control.FOCUS_ALL
	editor.value_changed.connect(_on_property_changed.bind(obj, property_name))
	return editor

func _create_vector3_editor(obj: MissionObject, property_name: String, value: Vector3) -> Control:
	"""Create a Vector3 property editor."""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	
	# X component
	var x_editor = SpinBox.new()
	x_editor.value = value.x
	x_editor.step = 0.1
	x_editor.allow_greater = true
	x_editor.allow_lesser = true
	x_editor.custom_minimum_size = Vector2(60, 0)
	x_editor.focus_mode = Control.FOCUS_ALL
	x_editor.value_changed.connect(_on_vector3_component_changed.bind(obj, property_name, "x"))
	container.add_child(x_editor)
	
	# Y component
	var y_editor = SpinBox.new()
	y_editor.value = value.y
	y_editor.step = 0.1
	y_editor.allow_greater = true
	y_editor.allow_lesser = true
	y_editor.custom_minimum_size = Vector2(60, 0)
	y_editor.focus_mode = Control.FOCUS_ALL
	y_editor.value_changed.connect(_on_vector3_component_changed.bind(obj, property_name, "y"))
	container.add_child(y_editor)
	
	# Z component
	var z_editor = SpinBox.new()
	z_editor.value = value.z
	z_editor.step = 0.1
	z_editor.allow_greater = true
	z_editor.allow_lesser = true
	z_editor.custom_minimum_size = Vector2(60, 0)
	z_editor.focus_mode = Control.FOCUS_ALL
	z_editor.value_changed.connect(_on_vector3_component_changed.bind(obj, property_name, "z"))
	container.add_child(z_editor)
	
	return container

func _create_bool_editor(obj: MissionObject, property_name: String, value: bool) -> CheckBox:
	"""Create a boolean property editor."""
	var editor = CheckBox.new()
	editor.button_pressed = value
	editor.focus_mode = Control.FOCUS_ALL
	editor.toggled.connect(_on_property_changed.bind(obj, property_name))
	return editor

func _on_property_changed(obj: MissionObject, property_name: String, new_value: Variant) -> void:
	"""Handle property value changes."""
	if obj.has_method("set"):
		obj.set(property_name, new_value)
	property_changed.emit(obj, property_name, new_value)

func _on_vector3_component_changed(obj: MissionObject, property_name: String, component: String, new_value: float) -> void:
	"""Handle Vector3 component changes."""
	var current_value: Vector3 = obj.get(property_name) if obj.has_method("get") else Vector3.ZERO
	
	match component:
		"x":
			current_value.x = new_value
		"y":
			current_value.y = new_value
		"z":
			current_value.z = new_value
	
	if obj.has_method("set"):
		obj.set(property_name, current_value)
	property_changed.emit(obj, property_name, current_value)

func _on_multi_property_changed(property_name: String, new_value: String) -> void:
	"""Handle multi-object property changes."""
	for obj in selected_objects:
		if obj.has_method("set"):
			obj.set(property_name, new_value)
		property_changed.emit(obj, property_name, new_value)

func _clear_property_editors() -> void:
	"""Clear all property editors."""
	for child in property_container.get_children():
		if child != no_selection_label:
			child.queue_free()
	property_editors.clear()

func _show_options_menu() -> void:
	"""Show the inspector options menu."""
	var popup = PopupMenu.new()
	popup.add_item("Reset Properties", 0)
	popup.add_item("Copy Properties", 1)
	popup.add_item("Paste Properties", 2)
	popup.add_separator()
	popup.add_item("Expand All", 3)
	popup.add_item("Collapse All", 4)
	
	popup.id_pressed.connect(_on_options_menu_selected)
	add_child(popup)
	popup.popup_centered()

func _on_options_menu_selected(id: int) -> void:
	"""Handle options menu selection."""
	match id:
		0: # Reset Properties
			_reset_properties()
		1: # Copy Properties
			_copy_properties()
		2: # Paste Properties
			_paste_properties()
		3: # Expand All
			pass # TODO: Implement section expansion
		4: # Collapse All
			pass # TODO: Implement section collapsing

func _reset_properties() -> void:
	"""Reset selected objects' properties to defaults."""
	# TODO: Implement property reset functionality
	pass

func _copy_properties() -> void:
	"""Copy selected objects' properties to clipboard."""
	# TODO: Implement property copying
	pass

func _paste_properties() -> void:
	"""Paste properties from clipboard to selected objects."""
	# TODO: Implement property pasting
	pass