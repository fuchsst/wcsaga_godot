class_name ObjectPropertyEditor
extends VBoxContainer

## Object property editor UI component for mission objects.
## Provides dynamic property editing interface with validation feedback.

signal property_changed(property_name: String, new_value: Variant)
signal validation_error(property_name: String, error_message: String)

var current_object: MissionObject
var property_fields: Dictionary = {}
var validation_labels: Dictionary = {}

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var properties_container: VBoxContainer = $ScrollContainer/PropertiesContainer

func _ready() -> void:
	name = "ObjectPropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	# Create scroll container if not in scene
	if not scroll_container:
		scroll_container = ScrollContainer.new()
		scroll_container.name = "ScrollContainer"
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(scroll_container)
	
	# Create properties container
	if not properties_container:
		properties_container = VBoxContainer.new()
		properties_container.name = "PropertiesContainer"
		scroll_container.add_child(properties_container)

func edit_object(object_data: MissionObject) -> void:
	"""Start editing the given mission object."""
	current_object = object_data
	_clear_properties()
	
	if not object_data:
		_show_no_selection()
		return
	
	_build_property_interface(object_data)

func _clear_properties() -> void:
	"""Clear all property controls."""
	for child in properties_container.get_children():
		child.queue_free()
	
	property_fields.clear()
	validation_labels.clear()

func _show_no_selection() -> void:
	"""Show message when no object is selected."""
	var label: Label = Label.new()
	label.text = "No object selected"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	properties_container.add_child(label)

func _build_property_interface(object_data: MissionObject) -> void:
	"""Build the property editing interface for the object."""
	# Object header
	var header: Label = Label.new()
	header.text = object_data.name if object_data.name else "Unnamed Object"
	header.add_theme_font_size_override("font_size", 16)
	properties_container.add_child(header)
	
	# Object type
	_add_readonly_property("Type", MissionObject.Type.keys()[object_data.type])
	
	# Separator
	var separator: HSeparator = HSeparator.new()
	properties_container.add_child(separator)
	
	# Basic properties
	_add_string_property("name", "Name", object_data.name)
	_add_vector3_property("position", "Position", object_data.position)
	_add_vector3_property("rotation", "Rotation", object_data.rotation)
	
	# Type-specific properties
	match object_data.type:
		MissionObject.Type.SHIP:
			_add_ship_properties(object_data)
		MissionObject.Type.WING:
			_add_ship_properties(object_data)  # Wings use ship properties
		MissionObject.Type.CARGO:
			_add_cargo_properties(object_data)
		MissionObject.Type.WAYPOINT:
			_add_waypoint_properties(object_data)

func _add_readonly_property(label_text: String, value: String) -> void:
	"""Add a read-only property display."""
	var container: HBoxContainer = HBoxContainer.new()
	properties_container.add_child(container)
	
	var label: Label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 100
	container.add_child(label)
	
	var value_label: Label = Label.new()
	value_label.text = value
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(value_label)

func _add_string_property(property_name: String, label_text: String, current_value: String) -> void:
	"""Add a string property editor."""
	var container: VBoxContainer = VBoxContainer.new()
	properties_container.add_child(container)
	
	# Label
	var label: Label = Label.new()
	label.text = label_text + ":"
	container.add_child(label)
	
	# Input field
	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = current_value
	line_edit.placeholder_text = "Enter " + label_text.to_lower()
	container.add_child(line_edit)
	
	# Validation label
	var validation_label: Label = Label.new()
	validation_label.modulate = Color.RED
	validation_label.visible = false
	container.add_child(validation_label)
	
	property_fields[property_name] = line_edit
	validation_labels[property_name] = validation_label
	
	# Connect signals
	line_edit.text_changed.connect(_on_string_property_changed.bind(property_name))
	line_edit.focus_exited.connect(_validate_object_property.bind(property_name))

func _add_vector3_property(property_name: String, label_text: String, current_value: Vector3) -> void:
	"""Add a Vector3 property editor."""
	var container: VBoxContainer = VBoxContainer.new()
	properties_container.add_child(container)
	
	# Label
	var label: Label = Label.new()
	label.text = label_text + ":"
	container.add_child(label)
	
	# Input container
	var input_container: HBoxContainer = HBoxContainer.new()
	container.add_child(input_container)
	
	# X, Y, Z fields
	var fields: Array[SpinBox] = []
	var components: Array[String] = ["X", "Y", "Z"]
	var values: Array[float] = [current_value.x, current_value.y, current_value.z]
	
	for i in range(3):
		var component_container: VBoxContainer = VBoxContainer.new()
		input_container.add_child(component_container)
		
		var component_label: Label = Label.new()
		component_label.text = components[i]
		component_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		component_container.add_child(component_label)
		
		var spin_box: SpinBox = SpinBox.new()
		spin_box.value = values[i]
		spin_box.step = 0.1
		spin_box.allow_greater = true
		spin_box.allow_lesser = true
		spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		component_container.add_child(spin_box)
		
		fields.append(spin_box)
		spin_box.value_changed.connect(_on_vector3_property_changed.bind(property_name, fields))
	
	# Validation label
	var validation_label: Label = Label.new()
	validation_label.modulate = Color.RED
	validation_label.visible = false
	container.add_child(validation_label)
	
	property_fields[property_name] = fields
	validation_labels[property_name] = validation_label

func _add_ship_properties(object_data: MissionObject) -> void:
	"""Add ship-specific properties."""
	var separator: HSeparator = HSeparator.new()
	properties_container.add_child(separator)
	
	var header: Label = Label.new()
	header.text = "Ship Properties"
	header.add_theme_font_size_override("font_size", 14)
	properties_container.add_child(header)
	
	# Add ship-specific properties here
	_add_readonly_property("Team", str(object_data.team))
	_add_readonly_property("AI Goals", str(object_data.ai_goals.size()) + " goals")

func _add_weapon_properties(object_data: MissionObject) -> void:
	"""Add weapon-specific properties."""
	var separator: HSeparator = HSeparator.new()
	properties_container.add_child(separator)
	
	var header: Label = Label.new()
	header.text = "Weapon Properties"
	header.add_theme_font_size_override("font_size", 14)
	properties_container.add_child(header)
	
	_add_readonly_property("Primary Banks", str(object_data.primary_banks.size()))
	_add_readonly_property("Secondary Banks", str(object_data.secondary_banks.size()))

func _add_cargo_properties(object_data: MissionObject) -> void:
	"""Add cargo-specific properties."""
	var separator: HSeparator = HSeparator.new()
	properties_container.add_child(separator)
	
	var header: Label = Label.new()
	header.text = "Cargo Properties"
	header.add_theme_font_size_override("font_size", 14)
	properties_container.add_child(header)
	
	_add_readonly_property("Scannable", str(object_data.scannable))
	_add_readonly_property("Cargo Known", str(object_data.cargo_known))

func _add_waypoint_properties(object_data: MissionObject) -> void:
	"""Add waypoint-specific properties."""
	var separator: HSeparator = HSeparator.new()
	properties_container.add_child(separator)
	
	var header: Label = Label.new()
	header.text = "Waypoint Properties"
	header.add_theme_font_size_override("font_size", 14)
	properties_container.add_child(header)
	
	_add_readonly_property("Position", str(object_data.position))

func _on_string_property_changed(property_name: String, new_value: String) -> void:
	"""Handle string property change."""
	if not current_object:
		return
	
	# Update the object data
	match property_name:
		"name":
			current_object.name = new_value
		_:
			# For custom properties that might be added later
			if current_object.has_method("set_property"):
				current_object.set_property(property_name, new_value)
	
	_validate_object_property(property_name)
	property_changed.emit(property_name, new_value)

func _on_vector3_property_changed(property_name: String, fields: Array[SpinBox], _value: float) -> void:
	"""Handle Vector3 property change."""
	if not current_object:
		return
	
	var new_vector: Vector3 = Vector3(
		fields[0].value,
		fields[1].value,
		fields[2].value
	)
	
	# Update the object data
	match property_name:
		"position":
			current_object.position = new_vector
		"rotation":
			current_object.rotation = new_vector
		_:
			# For custom properties that might be added later
			if current_object.has_method("set_property"):
				current_object.set_property(property_name, new_vector)
	
	_validate_object_property(property_name)
	property_changed.emit(property_name, new_vector)

func _validate_object_property(property_name: String) -> void:
	"""Validate a property and show error if invalid."""
	if not current_object:
		return
	
	var validation_label: Label = validation_labels.get(property_name)
	if not validation_label:
		return
	
	# Get validation result from ObjectValidator
	var validator: ObjectValidator = ObjectValidator.new()
	var validation_result: ValidationResult = validator.validate_object_property(
		current_object, 
		property_name
	)
	
	if validation_result.is_valid():
		validation_label.visible = false
	else:
		var errors: Array[String] = validation_result.get_errors()
		validation_label.text = errors[0] if not errors.is_empty() else "Validation error"
		validation_label.visible = true
		validation_error.emit(property_name, validation_label.text)

func refresh_properties() -> void:
	"""Refresh the property display with current object data."""
	if current_object:
		edit_object(current_object)

func has_validation_errors() -> bool:
	"""Check if there are any current validation errors."""
	for validation_label in validation_labels.values():
		if validation_label.visible:
			return true
	return false
