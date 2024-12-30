@tool
extends Window

# Signals
signal confirmed
signal canceled

# Common dialog properties
var title_text: String
var ok_button: Button
var cancel_button: Button

func _ready():
	# Set up base dialog properties
	transient = true # Dialog will be modal
	exclusive = true # Block input to other windows
	unresizable = true # Most editor dialogs are fixed size
	close_requested.connect(_on_close_requested)
	
	# Create base layout
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Add content container that derived dialogs will populate
	var content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)
	
	# Add button row
	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 10)
	vbox.add_child(button_row)

func _on_ok_pressed():
	confirmed.emit()
	hide()

func _on_cancel_pressed():
	canceled.emit()
	hide()

func _on_close_requested():
	canceled.emit()
	hide()

func get_content_container() -> Control:
	return get_node("MarginContainer/VBoxContainer/Content")

func show_dialog(minsize: Vector2 = Vector2(0, 0)):
	# Set size if provided
	if minsize != Vector2.ZERO:
		size = minsize
	
	# Use built-in Window centering
	popup_centered()

# Helper to setup labels
func _create_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	return label
