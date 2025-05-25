class_name ReadOnlyPropertyEditor
extends HBoxContainer

## Read-only property display for non-editable values.
## Shows property name and value with copy functionality.

var property_name: String = ""
var current_value: String = ""

@onready var label: Label = $Label
@onready var value_label: Label = $ValueLabel
@onready var copy_button: Button = $CopyButton

func _ready() -> void:
	name = "ReadOnlyPropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Property label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	prop_label.custom_minimum_size.x = 100
	add_child(prop_label)
	
	# Value label
	var val_label: Label = Label.new()
	val_label.name = "ValueLabel"
	val_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_label.clip_contents = true
	val_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(val_label)
	
	# Copy button
	var copy_btn: Button = Button.new()
	copy_btn.name = "CopyButton"
	copy_btn.text = "Copy"
	copy_btn.custom_minimum_size = Vector2(40, 24)
	add_child(copy_btn)
	
	# Update references
	label = prop_label
	value_label = val_label
	copy_button = copy_btn
	
	# Connect signals
	copy_button.pressed.connect(_on_copy_pressed)

func setup_editor(prop_name: String, label_text: String, value: String, _options: Dictionary = {}) -> void:
	"""Setup the editor with property information."""
	property_name = prop_name
	current_value = value
	
	# Set label and value
	label.text = label_text + ":"
	value_label.text = value
	
	# Set tooltip with full value
	value_label.tooltip_text = value

func get_property_name() -> String:
	"""Get the property name for search filtering."""
	return property_name

func _on_copy_pressed() -> void:
	"""Handle copy button press."""
	DisplayServer.clipboard_set(current_value)
	_show_copy_feedback("Copied to clipboard")

func _show_copy_feedback(message: String) -> void:
	"""Show brief feedback for copy operation."""
	var original_text: String = copy_button.text
	copy_button.text = "✓"
	copy_button.disabled = true
	
	# Reset after delay
	await get_tree().create_timer(0.8).timeout
	copy_button.text = original_text
	copy_button.disabled = false