@tool
class_name ObjectInspectorDockController
extends Control

## Object inspector dock controller for GFRED2-011 UI Refactoring.
## Scene-based UI controller for mission object property editing.
## Scene: addons/gfred2/scenes/docks/object_inspector_dock.tscn

signal property_changed(object_data: MissionObjectData, property_name: String, new_value: Variant)
signal object_duplicated(object_data: MissionObjectData)
signal object_deleted(object_data: MissionObjectData)

# Current state
var current_object: MissionObjectData = null
var is_locked: bool = false
var property_editors: Dictionary = {}

# Scene node references
@onready var lock_button: Button = $MainContainer/Header/LockButton
@onready var object_name_label: Label = $MainContainer/ObjectInfo/ObjectNameLabel
@onready var object_type_label: Label = $MainContainer/ObjectInfo/ObjectTypeLabel

@onready var category_tabs: TabContainer = $MainContainer/PropertiesContainer/CategoryTabs
@onready var basic_properties: VBoxContainer = $MainContainer/PropertiesContainer/CategoryTabs/Basic/BasicProperties
@onready var transform_properties: VBoxContainer = $MainContainer/PropertiesContainer/CategoryTabs/Transform/TransformProperties
@onready var advanced_properties: VBoxContainer = $MainContainer/PropertiesContainer/CategoryTabs/Advanced/AdvancedProperties

@onready var duplicate_button: Button = $MainContainer/Actions/DuplicateButton
@onready var delete_button: Button = $MainContainer/Actions/DeleteButton
@onready var reset_button: Button = $MainContainer/Actions/ResetButton

func _ready() -> void:
	name = "ObjectInspectorDock"
	_connect_signals()
	_clear_inspector()
	print("ObjectInspectorDockController: Scene-based object inspector dock initialized")

func _connect_signals() -> void:
	if lock_button:
		lock_button.toggled.connect(_on_lock_toggled)
	
	if duplicate_button:
		duplicate_button.pressed.connect(_on_duplicate_pressed)
	
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)
	
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)

## Inspects the given mission object
func inspect_object(object_data: MissionObjectData) -> void:
	if is_locked:
		return
	
	current_object = object_data
	_update_inspector()

func _update_inspector() -> void:
	if not current_object:
		_clear_inspector()
		return
	
	_update_object_info()
	_populate_properties()

func _clear_inspector() -> void:
	current_object = null
	
	if object_name_label:
		object_name_label.text = "No object selected"
	
	if object_type_label:
		object_type_label.text = ""
	
	_clear_all_properties()
	_update_action_buttons()

func _update_object_info() -> void:
	if not current_object:
		return
	
	if object_name_label:
		object_name_label.text = current_object.name if current_object.has_method("get_name") else "Unknown Object"
	
	if object_type_label:
		var type_name: String = current_object.get_class() if current_object else "Unknown"
		object_type_label.text = "Type: %s" % type_name

func _populate_properties() -> void:
	if not current_object:
		return
	
	_clear_all_properties()
	
	# Populate basic properties
	_populate_basic_properties()
	
	# Populate transform properties
	_populate_transform_properties()
	
	# Populate advanced properties
	_populate_advanced_properties()
	
	_update_action_buttons()

func _populate_basic_properties() -> void:
	if not basic_properties or not current_object:
		return
	
	# Object name property
	_create_string_property(basic_properties, "Name", "name", current_object.name if current_object.has_method("get_name") else "")
	
	# Add other basic properties based on object type
	if current_object.has_method("get_class"):
		match current_object.get_class():
			"ShipData", "MissionShip":
				_create_ship_basic_properties()
			"WaypointPath":
				_create_waypoint_basic_properties()

func _populate_transform_properties() -> void:
	if not transform_properties or not current_object:
		return
	
	# Position property
	var position: Vector3 = current_object.position if current_object.has_method("get_position") else Vector3.ZERO
	_create_vector3_property(transform_properties, "Position", "position", position)
	
	# Rotation property
	var rotation: Vector3 = current_object.rotation if current_object.has_method("get_rotation") else Vector3.ZERO
	_create_vector3_property(transform_properties, "Rotation", "rotation", rotation)
	
	# Scale property (if applicable)
	if current_object.has_method("get_scale"):
		var scale: Vector3 = current_object.get_scale()
		_create_vector3_property(transform_properties, "Scale", "scale", scale)

func _populate_advanced_properties() -> void:
	if not advanced_properties or not current_object:
		return
	
	# Add advanced properties based on object type
	if current_object.has_method("get_class"):
		match current_object.get_class():
			"ShipData", "MissionShip":
				_create_ship_advanced_properties()
			"WaypointPath":
				_create_waypoint_advanced_properties()

func _create_ship_basic_properties() -> void:
	if not current_object:
		return
	
	# Ship class
	var ship_class: String = current_object.ship_class if current_object.has_method("get_ship_class") else ""
	_create_string_property(basic_properties, "Ship Class", "ship_class", ship_class)
	
	# Team
	var team: int = current_object.team if current_object.has_method("get_team") else 0
	_create_number_property(basic_properties, "Team", "team", team)

func _create_ship_advanced_properties() -> void:
	if not current_object:
		return
	
	# AI Behavior
	var ai_behavior: String = current_object.ai_behavior if current_object.has_method("get_ai_behavior") else ""
	_create_string_property(advanced_properties, "AI Behavior", "ai_behavior", ai_behavior)
	
	# Hull Percentage
	var hull_percentage: float = current_object.hull_percentage if current_object.has_method("get_hull_percentage") else 100.0
	_create_number_property(advanced_properties, "Hull %", "hull_percentage", hull_percentage)

func _create_waypoint_basic_properties() -> void:
	if not current_object:
		return
	
	# Path name
	var path_name: String = current_object.path_name if current_object.has_method("get_path_name") else ""
	_create_string_property(basic_properties, "Path Name", "path_name", path_name)

func _create_waypoint_advanced_properties() -> void:
	if not current_object:
		return
	
	# Waypoint count
	var waypoint_count: int = current_object.waypoints.size() if current_object.has_method("get_waypoints") else 0
	_create_readonly_property(advanced_properties, "Waypoint Count", str(waypoint_count))

func _create_string_property(container: VBoxContainer, label_text: String, property_name: String, value: String) -> void:
	var property_container: HBoxContainer = HBoxContainer.new()
	container.add_child(property_container)
	
	var label: Label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 100
	property_container.add_child(label)
	
	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = value
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_changed.connect(_on_string_property_changed.bind(property_name))
	property_container.add_child(line_edit)
	
	property_editors[property_name] = line_edit

func _create_number_property(container: VBoxContainer, label_text: String, property_name: String, value: float) -> void:
	var property_container: HBoxContainer = HBoxContainer.new()
	container.add_child(property_container)
	
	var label: Label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 100
	property_container.add_child(label)
	
	var spin_box: SpinBox = SpinBox.new()
	spin_box.value = value
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.value_changed.connect(_on_number_property_changed.bind(property_name))
	property_container.add_child(spin_box)
	
	property_editors[property_name] = spin_box

func _create_vector3_property(container: VBoxContainer, label_text: String, property_name: String, value: Vector3) -> void:
	var property_container: VBoxContainer = VBoxContainer.new()
	container.add_child(property_container)
	
	var label: Label = Label.new()
	label.text = label_text + ":"
	property_container.add_child(label)
	
	var components_container: HBoxContainer = HBoxContainer.new()
	property_container.add_child(components_container)
	
	# X component
	var x_spin: SpinBox = SpinBox.new()
	x_spin.value = value.x
	x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x_spin.value_changed.connect(_on_vector3_component_changed.bind(property_name, "x"))
	components_container.add_child(x_spin)
	
	# Y component
	var y_spin: SpinBox = SpinBox.new()
	y_spin.value = value.y
	y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	y_spin.value_changed.connect(_on_vector3_component_changed.bind(property_name, "y"))
	components_container.add_child(y_spin)
	
	# Z component
	var z_spin: SpinBox = SpinBox.new()
	z_spin.value = value.z
	z_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	z_spin.value_changed.connect(_on_vector3_component_changed.bind(property_name, "z"))
	components_container.add_child(z_spin)
	
	property_editors[property_name] = {"x": x_spin, "y": y_spin, "z": z_spin}

func _create_readonly_property(container: VBoxContainer, label_text: String, value: String) -> void:
	var property_container: HBoxContainer = HBoxContainer.new()
	container.add_child(property_container)
	
	var label: Label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 100
	property_container.add_child(label)
	
	var value_label: Label = Label.new()
	value_label.text = value
	value_label.modulate = Color(0.8, 0.8, 0.8)
	property_container.add_child(value_label)

func _clear_all_properties() -> void:
	property_editors.clear()
	
	for container in [basic_properties, transform_properties, advanced_properties]:
		if container:
			for child in container.get_children():
				child.queue_free()

func _update_action_buttons() -> void:
	var has_object: bool = current_object != null
	
	if duplicate_button:
		duplicate_button.disabled = not has_object
	
	if delete_button:
		delete_button.disabled = not has_object
	
	if reset_button:
		reset_button.disabled = not has_object

## Signal handlers

func _on_lock_toggled(enabled: bool) -> void:
	is_locked = enabled
	if lock_button:
		lock_button.text = "Unlock" if enabled else "Lock"

func _on_duplicate_pressed() -> void:
	if current_object:
		object_duplicated.emit(current_object)

func _on_delete_pressed() -> void:
	if current_object:
		object_deleted.emit(current_object)

func _on_reset_pressed() -> void:
	if current_object:
		# TODO: Implement object reset functionality
		print("ObjectInspectorDockController: Reset object functionality not yet implemented")

func _on_string_property_changed(property_name: String, new_value: String) -> void:
	if current_object and current_object.has_method("set_" + property_name):
		current_object.call("set_" + property_name, new_value)
		property_changed.emit(current_object, property_name, new_value)
		_update_object_info()  # Refresh display

func _on_number_property_changed(property_name: String, new_value: float) -> void:
	if current_object and current_object.has_method("set_" + property_name):
		current_object.call("set_" + property_name, new_value)
		property_changed.emit(current_object, property_name, new_value)

func _on_vector3_component_changed(property_name: String, component: String, new_value: float) -> void:
	if not current_object or not property_editors.has(property_name):
		return
	
	var editors: Dictionary = property_editors[property_name]
	var current_vector: Vector3 = Vector3.ZERO
	
	if current_object.has_method("get_" + property_name):
		current_vector = current_object.call("get_" + property_name)
	
	match component:
		"x":
			current_vector.x = new_value
		"y":
			current_vector.y = new_value
		"z":
			current_vector.z = new_value
	
	if current_object.has_method("set_" + property_name):
		current_object.call("set_" + property_name, current_vector)
		property_changed.emit(current_object, property_name, current_vector)

## Public API methods

func get_inspected_object() -> MissionObjectData:
	return current_object

func is_inspector_locked() -> bool:
	return is_locked

func lock_inspector(locked: bool) -> void:
	is_locked = locked
	if lock_button:
		lock_button.button_pressed = locked
		lock_button.text = "Unlock" if locked else "Lock"

func refresh_properties() -> void:
	if current_object:
		_populate_properties()