class_name ObjectPropertyInspector
extends Control

## Enhanced property inspector for mission objects with dependency injection.
## Designed for comprehensive gdUnit4 testing with mock object support.

signal property_changed(property_name: String, new_value: Variant)
signal validation_error(property_name: String, error_message: String)
signal sexp_edit_requested(property_name: String, current_expression: String)
signal validation_completed(results: Array[Dictionary])
signal editor_state_changed(editor_id: String, state: Dictionary)
signal performance_metrics_updated(metrics: Dictionary)

var current_objects: Array[MissionObjectData] = []
var property_categories: Dictionary = {}
var property_editors: Dictionary = {}
var validation_labels: Dictionary = {}
var search_filter: String = ""
var is_multi_select: bool = false

# Injected dependencies for testability
var editor_registry: PropertyEditorRegistry
var validator: ObjectValidator
var performance_monitor: PropertyPerformanceMonitor
var contextual_help: ContextualHelp

@onready var header_container: VBoxContainer = $VBoxContainer/Header
@onready var search_bar: LineEdit = $VBoxContainer/Header/SearchBar
@onready var object_info: Label = $VBoxContainer/Header/ObjectInfo
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var categories_container: VBoxContainer = $VBoxContainer/ScrollContainer/CategoriesContainer

## Constructor with dependency injection for testing.
func _init(
	custom_registry: PropertyEditorRegistry = null,
	custom_validator: ObjectValidator = null,
	custom_monitor: PropertyPerformanceMonitor = null,
	custom_help: ContextualHelp = null
) -> void:
	editor_registry = custom_registry if custom_registry else PropertyEditorRegistry.new()
	validator = custom_validator if custom_validator else ObjectValidator.new()
	performance_monitor = custom_monitor if custom_monitor else PropertyPerformanceMonitor.get_instance()
	contextual_help = custom_help if custom_help else ContextualHelp

func _ready() -> void:
	name = "TestableObjectPropertyInspector"
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	performance_monitor.start_timing("ui_setup")
	
	# Main layout
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.name = "VBoxContainer"
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)
	
	# Header section
	var header: VBoxContainer = VBoxContainer.new()
	header.name = "Header"
	main_vbox.add_child(header)
	
	# Search bar
	var search: LineEdit = LineEdit.new()
	search.name = "SearchBar"
	search.placeholder_text = "Search properties..."
	search.clear_button_enabled = true
	header.add_child(search)
	
	# Object info label
	var info: Label = Label.new()
	info.name = "ObjectInfo"
	info.text = "No objects selected"
	info.add_theme_font_size_override("font_size", 12)
	header.add_child(info)
	
	# Separator
	var separator: HSeparator = HSeparator.new()
	header.add_child(separator)
	
	# Scroll container
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	# Categories container
	var categories: VBoxContainer = VBoxContainer.new()
	categories.name = "CategoriesContainer"
	scroll.add_child(categories)
	
	# Update references
	header_container = header
	search_bar = search
	object_info = info
	scroll_container = scroll
	categories_container = categories
	
	var setup_time: float = performance_monitor.end_timing("ui_setup")
	performance_metrics_updated.emit({"ui_setup_time_ms": setup_time})

func _connect_signals() -> void:
	"""Connect UI signals."""
	search_bar.text_changed.connect(_on_search_text_changed)

func edit_objects(objects: Array[MissionObjectData]) -> void:
	"""Start editing the given mission objects (single or multi-select)."""
	var operation_name: String = "edit_objects_%d" % objects.size()
	performance_monitor.start_timing(operation_name)
	performance_monitor.take_memory_snapshot("before_edit_objects")
	
	current_objects = objects
	is_multi_select = objects.size() > 1
	
	_clear_properties()
	
	if objects.is_empty():
		_show_no_selection()
	else:
		_update_object_info()
		_build_property_interface()
	
	performance_monitor.take_memory_snapshot("after_edit_objects")
	var edit_time: float = performance_monitor.end_timing(operation_name)
	
	# Emit performance metrics
	var metrics: Dictionary = {
		"edit_objects_time_ms": edit_time,
		"object_count": objects.size(),
		"is_multi_select": is_multi_select,
		"memory_usage_mb": performance_monitor.get_memory_usage()
	}
	performance_metrics_updated.emit(metrics)
	
	# Emit state change
	editor_state_changed.emit("object_selection", {
		"object_count": objects.size(),
		"is_multi_select": is_multi_select,
		"has_objects": not objects.is_empty()
	})

func _clear_properties() -> void:
	"""Clear all property controls and categories."""
	performance_monitor.start_timing("clear_properties")
	
	for child in categories_container.get_children():
		child.queue_free()
	
	property_categories.clear()
	property_editors.clear()
	validation_labels.clear()
	
	performance_monitor.end_timing("clear_properties")

func _show_no_selection() -> void:
	"""Show message when no object is selected."""
	object_info.text = "No objects selected"
	
	var label: Label = Label.new()
	label.text = "Select one or more objects to edit their properties"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	categories_container.add_child(label)

func _update_object_info() -> void:
	"""Update the object information display."""
	if is_multi_select:
		object_info.text = "%d objects selected (Multi-edit mode)" % current_objects.size()
	else:
		var obj: MissionObjectData = current_objects[0]
		var obj_name: String = obj.object_name if obj.object_name else "Unnamed Object"
		var obj_type: String = MissionObjectData.ObjectType.keys()[obj.object_type]
		object_info.text = "%s (%s)" % [obj_name, obj_type]

func _build_property_interface() -> void:
	"""Build the categorized property interface."""
	performance_monitor.start_timing("build_property_interface")
	
	if is_multi_select:
		_build_multi_select_interface()
	else:
		_build_single_object_interface()
	
	var build_time: float = performance_monitor.end_timing("build_property_interface")
	performance_metrics_updated.emit({"build_interface_time_ms": build_time})

func _build_single_object_interface() -> void:
	"""Build interface for single object editing."""
	var obj: MissionObjectData = current_objects[0]
	
	# Create property categories
	_create_transform_category(obj)
	_create_visual_category(obj)
	_create_behavior_category(obj)
	_create_mission_logic_category(obj)
	_create_advanced_category(obj)

func _build_multi_select_interface() -> void:
	"""Build interface for multi-object editing."""
	# Show common properties only
	_create_common_properties_category()
	
	# Add multi-select specific controls
	_create_batch_operations_category()

func _create_transform_category(obj: MissionObjectData) -> void:
	"""Create the Transform properties category."""
	var category: PropertyCategory = _create_property_category(
		"Transform", 
		"Transform properties (position, rotation, scale)",
		"res://addons/gfred2/icons/transform.svg"
	)
	
	# Position with performance monitoring
	performance_monitor.time_editor_creation("vector3", func(): 
		_add_vector3_property_to_category(category, "position", "Position", obj.position, {
			"tooltip": contextual_help.get_property_tooltip("position"),
			"step": 0.1,
			"allow_reset": true,
			"reset_value": Vector3.ZERO
		})
	)
	
	# Rotation
	performance_monitor.time_editor_creation("vector3", func():
		_add_vector3_property_to_category(category, "rotation", "Rotation", obj.rotation, {
			"tooltip": contextual_help.get_property_tooltip("rotation"),
			"step": 1.0,
			"suffix": "°",
			"min_value": -360.0,
			"max_value": 360.0,
			"allow_reset": true,
			"reset_value": Vector3.ZERO
		})
	)
	
	# Scale
	performance_monitor.time_editor_creation("vector3", func():
		_add_vector3_property_to_category(category, "scale", "Scale", obj.scale, {
			"tooltip": contextual_help.get_property_tooltip("scale"),
			"step": 0.01,
			"min_value": 0.01,
			"allow_reset": true,
			"reset_value": Vector3.ONE
		})
	)

func _create_visual_category(obj: MissionObjectData) -> void:
	"""Create the Visual properties category."""
	var category: PropertyCategory = _create_property_category(
		"Visual", 
		"Visual appearance and model properties",
		"res://addons/gfred2/icons/visual.svg"
	)
	
	# Model file (if applicable)
	if obj.object_type == MissionObjectData.ObjectType.SHIP:
		performance_monitor.time_editor_creation("file_path", func():
			_add_file_path_property_to_category(category, "model_file", "Model File", 
				obj.properties.get("model_file", ""), {
					"tooltip": contextual_help.get_property_tooltip("model_file"),
					"file_filter": "*.pof,*.glb,*.gltf",
					"base_path": "res://assets/models/"
				})
		)
	
	# Visual flags
	performance_monitor.time_editor_creation("boolean", func():
		_add_boolean_property_to_category(category, "visible", "Visible", 
			obj.properties.get("visible", true), {
				"tooltip": contextual_help.get_property_tooltip("visible")
			})
	)

func _create_behavior_category(obj: MissionObjectData) -> void:
	"""Create the Behavior properties category."""
	var category: PropertyCategory = _create_property_category(
		"Behavior", 
		"AI behavior, orders, and ship configuration",
		"res://addons/gfred2/icons/behavior.svg"
	)
	
	match obj.object_type:
		MissionObjectData.ObjectType.SHIP:
			_add_ship_behavior_properties(category, obj)
		MissionObjectData.ObjectType.WEAPON:
			_add_weapon_behavior_properties(category, obj)
		MissionObjectData.ObjectType.WAYPOINT:
			_add_waypoint_behavior_properties(category, obj)

func _create_mission_logic_category(obj: MissionObjectData) -> void:
	"""Create the Mission Logic properties category."""
	var category: PropertyCategory = _create_property_category(
		"Mission Logic", 
		"Goals, events, and SEXP expressions",
		"res://addons/gfred2/icons/mission_logic.svg"
	)
	
	# Arrival cue (SEXP expression)
	performance_monitor.time_editor_creation("sexp", func():
		_add_sexp_property_to_category(category, "arrival_cue", "Arrival Cue", 
			obj.properties.get("arrival_cue", ""), {
				"tooltip": contextual_help.get_property_tooltip("arrival_cue")
			})
	)
	
	# Departure cue (SEXP expression)
	performance_monitor.time_editor_creation("sexp", func():
		_add_sexp_property_to_category(category, "departure_cue", "Departure Cue", 
			obj.properties.get("departure_cue", ""), {
				"tooltip": contextual_help.get_property_tooltip("departure_cue")
			})
	)
	
	# Goals (if ship)
	if obj.object_type == MissionObjectData.ObjectType.SHIP:
		performance_monitor.time_editor_creation("string", func():
			_add_string_property_to_category(category, "initial_orders", "Initial Orders", 
				obj.properties.get("initial_orders", ""), {
					"tooltip": contextual_help.get_property_tooltip("initial_orders")
				})
		)

func _create_advanced_category(obj: MissionObjectData) -> void:
	"""Create the Advanced properties category."""
	var category: PropertyCategory = _create_property_category(
		"Advanced", 
		"Advanced and debug properties",
		"res://addons/gfred2/icons/advanced.svg"
	)
	category.collapsed = true  # Start collapsed
	
	# Object flags
	performance_monitor.time_editor_creation("string", func():
		_add_string_property_to_category(category, "flags", "Object Flags", 
			obj.properties.get("flags", ""), {
				"tooltip": contextual_help.get_property_tooltip("flags")
			})
	)
	
	# Debug info
	_add_readonly_property_to_category(category, "object_id", "Object ID", str(obj.get_instance_id()))

func _create_common_properties_category() -> void:
	"""Create category with properties common to all selected objects."""
	var category: PropertyCategory = _create_property_category(
		"Common Properties", 
		"Properties shared by all selected objects",
		"res://addons/gfred2/icons/multi_select.svg"
	)
	
	# Only show properties that are common to all objects
	var common_props: Array[String] = _get_common_properties()
	
	for prop_name in common_props:
		match prop_name:
			"position":
				_add_multi_vector3_property(category, "position", "Position")
			"rotation":
				_add_multi_vector3_property(category, "rotation", "Rotation")
			"scale":
				_add_multi_vector3_property(category, "scale", "Scale")
			"visible":
				_add_multi_boolean_property(category, "visible", "Visible")

func _create_batch_operations_category() -> void:
	"""Create category with batch operation controls."""
	var category: PropertyCategory = _create_property_category(
		"Batch Operations", 
		"Operations for multiple selected objects",
		"res://addons/gfred2/icons/batch.svg"
	)
	
	# Align operations
	var align_container: HBoxContainer = HBoxContainer.new()
	category.add_property_control(align_container)
	
	var align_label: Label = Label.new()
	align_label.text = "Align:"
	align_container.add_child(align_label)
	
	var align_x_btn: Button = Button.new()
	align_x_btn.text = "X"
	align_x_btn.custom_minimum_size = Vector2(30, 24)
	align_x_btn.pressed.connect(_align_objects_x)
	align_container.add_child(align_x_btn)
	
	var align_y_btn: Button = Button.new()
	align_y_btn.text = "Y"
	align_y_btn.custom_minimum_size = Vector2(30, 24)
	align_y_btn.pressed.connect(_align_objects_y)
	align_container.add_child(align_y_btn)
	
	var align_z_btn: Button = Button.new()
	align_z_btn.text = "Z"
	align_z_btn.custom_minimum_size = Vector2(30, 24)
	align_z_btn.pressed.connect(_align_objects_z)
	align_container.add_child(align_z_btn)

func _create_property_category(title: String, description: String, icon_path: String = "") -> PropertyCategory:
	"""Create a new property category."""
	var category: PropertyCategory = PropertyCategory.new()
	category.setup_category(title, description, icon_path)
	categories_container.add_child(category)
	
	property_categories[title] = category
	
	# Connect category signals
	category.category_toggled.connect(_on_category_toggled.bind(title))
	
	return category

# Property addition methods with performance monitoring
func _add_vector3_property_to_category(category: PropertyCategory, prop_name: String, 
	label_text: String, current_value: Vector3, options: Dictionary = {}) -> void:
	"""Add a Vector3 property editor to a category."""
	var editor = editor_registry.create_vector3_editor(prop_name, label_text, current_value, options)
	category.add_property_control(editor)
	
	property_editors[prop_name] = editor
	
	# Connect signals
	editor.value_changed.connect(_on_property_changed.bind(prop_name))

func _add_string_property_to_category(category: PropertyCategory, prop_name: String, 
	label_text: String, current_value: String, options: Dictionary = {}) -> void:
	"""Add a string property editor to a category."""
	var editor = editor_registry.create_string_editor(prop_name, label_text, current_value, options)
	category.add_property_control(editor)
	
	property_editors[prop_name] = editor
	
	# Connect signals
	editor.value_changed.connect(_on_property_changed.bind(prop_name))

func _add_sexp_property_to_category(category: PropertyCategory, prop_name: String, 
	label_text: String, current_value: String, options: Dictionary = {}) -> void:
	"""Add a SEXP property editor to a category."""
	var editor = editor_registry.create_sexp_editor(prop_name, label_text, current_value, options)
	category.add_property_control(editor)
	
	property_editors[prop_name] = editor
	
	# Connect signals
	editor.edit_requested.connect(_on_sexp_edit_requested.bind(prop_name))

func _add_boolean_property_to_category(category: PropertyCategory, prop_name: String, 
	label_text: String, current_value: bool, options: Dictionary = {}) -> void:
	"""Add a boolean property editor to a category."""
	var editor = editor_registry.create_boolean_editor(prop_name, label_text, current_value, options)
	category.add_property_control(editor)
	
	property_editors[prop_name] = editor
	
	# Connect signals
	editor.value_changed.connect(_on_property_changed.bind(prop_name))

func _add_file_path_property_to_category(category: PropertyCategory, prop_name: String, 
	label_text: String, current_value: String, options: Dictionary = {}) -> void:
	"""Add a file path property editor to a category."""
	var editor = editor_registry.create_file_path_editor(prop_name, label_text, current_value, options)
	category.add_property_control(editor)
	
	property_editors[prop_name] = editor
	
	# Connect signals
	editor.value_changed.connect(_on_property_changed.bind(prop_name))

func _add_readonly_property_to_category(category: PropertyCategory, prop_name: String, 
	label_text: String, value: String) -> void:
	"""Add a read-only property display to a category."""
	var editor = editor_registry.create_readonly_editor(prop_name, label_text, value)
	category.add_property_control(editor)

func _add_multi_vector3_property(category: PropertyCategory, prop_name: String, label_text: String) -> void:
	"""Add a Vector3 property editor for multi-object editing."""
	var editor = editor_registry.create_multi_vector3_editor(prop_name, label_text, current_objects)
	category.add_property_control(editor)
	
	property_editors[prop_name] = editor
	
	# Connect signals
	editor.value_changed.connect(_on_multi_property_changed.bind(prop_name))

func _add_multi_boolean_property(category: PropertyCategory, prop_name: String, label_text: String) -> void:
	"""Add a boolean property editor for multi-object editing."""
	var editor = editor_registry.create_multi_boolean_editor(prop_name, label_text, current_objects)
	category.add_property_control(editor)
	
	property_editors[prop_name] = editor
	
	# Connect signals
	editor.value_changed.connect(_on_multi_property_changed.bind(prop_name))

func _add_ship_behavior_properties(category: PropertyCategory, obj: MissionObjectData) -> void:
	"""Add ship-specific behavior properties."""
	performance_monitor.time_editor_creation("string", func():
		_add_string_property_to_category(category, "ship_class", "Ship Class", 
			obj.properties.get("ship_class", ""), {
				"tooltip": contextual_help.get_property_tooltip("ship_class")
			})
	)

func _add_weapon_behavior_properties(category: PropertyCategory, obj: MissionObjectData) -> void:
	"""Add weapon-specific behavior properties."""
	performance_monitor.time_editor_creation("string", func():
		_add_string_property_to_category(category, "weapon_type", "Weapon Type", 
			obj.properties.get("weapon_type", ""), {
				"tooltip": contextual_help.get_property_tooltip("weapon_type")
			})
	)

func _add_waypoint_behavior_properties(category: PropertyCategory, obj: MissionObjectData) -> void:
	"""Add waypoint-specific behavior properties."""
	performance_monitor.time_editor_creation("string", func():
		_add_string_property_to_category(category, "waypoint_path", "Waypoint Path", 
			obj.properties.get("waypoint_path", ""), {
				"tooltip": contextual_help.get_property_tooltip("waypoint_path")
			})
	)

func _get_common_properties() -> Array[String]:
	"""Get properties that are common to all selected objects."""
	if current_objects.is_empty():
		return []
	
	# Start with properties from first object
	var common_props: Array[String] = []
	var first_obj: MissionObjectData = current_objects[0]
	
	# Core properties that all objects have
	common_props.append_array(["position", "rotation", "scale"])
	
	# Check properties that exist in all objects
	for prop_name in first_obj.properties.keys():
		var exists_in_all: bool = true
		for obj in current_objects:
			if not obj.properties.has(prop_name):
				exists_in_all = false
				break
		
		if exists_in_all:
			common_props.append(prop_name)
	
	return common_props

# Event handlers with validation timing
func _on_search_text_changed(new_text: String) -> void:
	"""Handle search text change to filter properties."""
	search_filter = new_text.to_lower()
	performance_monitor.time_validation("search_filter", func(): _apply_search_filter())

func _apply_search_filter() -> void:
	"""Apply search filter to property categories."""
	for category_name in property_categories.keys():
		var category: PropertyCategory = property_categories[category_name]
		var has_visible_properties: bool = category.apply_search_filter(search_filter)
		category.visible = has_visible_properties or search_filter.is_empty()

func _on_category_toggled(category_name: String, collapsed: bool) -> void:
	"""Handle category collapse/expand."""
	var category: PropertyCategory = property_categories.get(category_name)
	if category:
		category.collapsed = collapsed

func _on_property_changed(property_name: String, new_value: Variant) -> void:
	"""Handle single object property change."""
	if current_objects.is_empty():
		return
	
	var validation_time: float = performance_monitor.time_validation(property_name, func():
		var obj: MissionObjectData = current_objects[0]
		_apply_property_change(obj, property_name, new_value)
	)
	
	property_changed.emit(property_name, new_value)
	performance_metrics_updated.emit({"validation_time_ms": validation_time})

func _on_multi_property_changed(property_name: String, new_value: Variant) -> void:
	"""Handle multi-object property change."""
	var validation_time: float = performance_monitor.time_validation(property_name, func():
		for obj in current_objects:
			_apply_property_change(obj, property_name, new_value)
	)
	
	property_changed.emit(property_name, new_value)
	performance_metrics_updated.emit({"multi_validation_time_ms": validation_time})

func _apply_property_change(obj: MissionObjectData, property_name: String, new_value: Variant) -> void:
	"""Apply property change to an object."""
	match property_name:
		"position":
			obj.position = new_value
		"rotation":
			obj.rotation = new_value
		"scale":
			obj.scale = new_value
		"object_name":
			obj.object_name = new_value
		_:
			obj.properties[property_name] = new_value
	
	# Validate the property
	_validate_object_property(obj, property_name)

func _validate_object_property(obj: MissionObjectData, property_name: String) -> void:
	"""Validate a property and show feedback."""
	var validation_result: Dictionary = validator.validate_object_property(obj, property_name)
	
	var editor = property_editors.get(property_name)
	if editor and editor.has_method("set_validation_state"):
		editor.set_validation_state(validation_result.is_valid, validation_result.get("error_message", ""))
	
	if not validation_result.is_valid:
		validation_error.emit(property_name, validation_result.error_message)
	
	# Emit validation completed
	validation_completed.emit([validation_result])

func _on_sexp_edit_requested(property_name: String) -> void:
	"""Handle request to edit SEXP expression."""
	var current_expression: String = ""
	if not current_objects.is_empty():
		var obj: MissionObjectData = current_objects[0]
		current_expression = obj.properties.get(property_name, "")
	
	sexp_edit_requested.emit(property_name, current_expression)

func _align_objects_x() -> void:
	"""Align all selected objects on X axis to first object."""
	if current_objects.size() < 2:
		return
	
	var target_x: float = current_objects[0].position.x
	for i in range(1, current_objects.size()):
		var obj: MissionObjectData = current_objects[i]
		obj.position.x = target_x
	
	_refresh_properties()

func _align_objects_y() -> void:
	"""Align all selected objects on Y axis to first object."""
	if current_objects.size() < 2:
		return
	
	var target_y: float = current_objects[0].position.y
	for i in range(1, current_objects.size()):
		var obj: MissionObjectData = current_objects[i]
		obj.position.y = target_y
	
	_refresh_properties()

func _align_objects_z() -> void:
	"""Align all selected objects on Z axis to first object."""
	if current_objects.size() < 2:
		return
	
	var target_z: float = current_objects[0].position.z
	for i in range(1, current_objects.size()):
		var obj: MissionObjectData = current_objects[i]
		obj.position.z = target_z
	
	_refresh_properties()

func _refresh_properties() -> void:
	"""Refresh the property display."""
	edit_objects(current_objects)

func refresh_current_objects() -> void:
	"""Refresh display for currently edited objects."""
	if not current_objects.is_empty():
		edit_objects(current_objects)

func has_validation_errors() -> bool:
	"""Check if there are any current validation errors."""
	for editor in property_editors.values():
		if editor.has_method("has_validation_error") and editor.has_validation_error():
			return true
	return false

# Performance and testing utilities

func get_performance_metrics() -> Dictionary:
	"""Get comprehensive performance metrics for testing."""
	return performance_monitor.get_performance_summary()

func reset_performance_metrics() -> void:
	"""Reset performance metrics."""
	performance_monitor.reset_metrics()

func get_editor_count() -> int:
	"""Get number of property editors (for testing)."""
	return property_editors.size()

func get_category_count() -> int:
	"""Get number of property categories (for testing)."""
	return property_categories.size()

func get_editor_by_property(property_name: String) -> Variant:
	"""Get property editor by property name (for testing)."""
	return property_editors.get(property_name)

func get_category_by_name(category_name: String) -> PropertyCategory:
	"""Get property category by name (for testing)."""
	return property_categories.get(category_name)

func set_search_filter_for_testing(filter_text: String) -> void:
	"""Set search filter programmatically (for testing)."""
	search_bar.text = filter_text
	_on_search_text_changed(filter_text)