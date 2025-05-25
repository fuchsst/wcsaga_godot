class_name EnumPropertyEditor
extends VBoxContainer

## Enum property editor with dropdown selection.
## Supports custom option lists with display names and values.

signal value_changed(new_value: int)

var property_name: String = ""
var current_value: int = 0
var options: Dictionary = {}
var enum_options: Array[String] = []

@onready var label: Label = $Label
@onready var option_button: OptionButton = $OptionButton

func _ready() -> void:
	name = "EnumPropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Property label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	add_child(prop_label)
	
	# Option button
	var opt_button: OptionButton = OptionButton.new()
	opt_button.name = "OptionButton"
	opt_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(opt_button)
	
	# Update references
	label = prop_label
	option_button = opt_button
	
	# Connect signals
	option_button.item_selected.connect(_on_item_selected)

func setup_editor(prop_name: String, label_text: String, value: int, editor_options: Dictionary = {}) -> void:
	"""Setup the editor with property information."""
	property_name = prop_name
	current_value = value
	options = editor_options
	
	# Set label
	label.text = label_text + ":"
	if options.has("tooltip"):
		label.tooltip_text = options.tooltip
		option_button.tooltip_text = options.tooltip
	
	# Setup options
	_setup_options()
	
	# Set initial value
	_set_selected_value(value)

func _setup_options() -> void:
	"""Setup the option button with enum values."""
	option_button.clear()
	
	if options.has("options"):
		enum_options = options.options
		
		for i in range(enum_options.size()):
			var option_text: String = enum_options[i]
			option_button.add_item(option_text, i)
	else:
		# Default options if none provided
		enum_options = ["Option 0", "Option 1", "Option 2"]
		for i in range(enum_options.size()):
			option_button.add_item(enum_options[i], i)

func set_value(new_value: int) -> void:
	"""Set the current value without triggering signals."""
	current_value = new_value
	_set_selected_value(new_value)

func _set_selected_value(value: int) -> void:
	"""Set the selected option without triggering signals."""
	# Find the item with matching ID
	for i in range(option_button.get_item_count()):
		if option_button.get_item_id(i) == value:
			option_button.select(i)
			return
	
	# If no matching ID found, select first item
	if option_button.get_item_count() > 0:
		option_button.select(0)

func get_value() -> int:
	"""Get the current editor value."""
	return current_value

func get_property_name() -> String:
	"""Get the property name for search filtering."""
	return property_name

func _on_item_selected(index: int) -> void:
	"""Handle option selection."""
	current_value = option_button.get_item_id(index)
	value_changed.emit(current_value)