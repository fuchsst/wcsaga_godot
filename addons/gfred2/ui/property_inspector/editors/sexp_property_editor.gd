class_name SexpPropertyEditor
extends VBoxContainer

## SEXP property editor with visual editor integration.
## Provides text preview and button to open visual SEXP editor.
## Implements IPropertyEditor interface for comprehensive testing support.

signal edit_requested()
signal value_changed(new_value: Variant)
signal validation_error(error_message: String)
signal performance_metrics_updated(metrics: Dictionary)

var property_name: String = ""
var current_value: String = ""
var options: Dictionary = {}

@onready var label: Label = $Label
@onready var preview_container: HBoxContainer = $PreviewContainer
@onready var preview_text: Label = $PreviewContainer/PreviewText
@onready var edit_button: Button = $PreviewContainer/EditButton

func _ready() -> void:
	name = "SexpPropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Property label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	add_child(prop_label)
	
	# Preview container
	var preview_hbox: HBoxContainer = HBoxContainer.new()
	preview_hbox.name = "PreviewContainer"
	add_child(preview_hbox)
	
	# Preview text
	var preview_label: Label = Label.new()
	preview_label.name = "PreviewText"
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.clip_contents = true
	preview_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview_label.add_theme_color_override("font_color", Color.GRAY)
	preview_hbox.add_child(preview_label)
	
	# Edit button
	var edit_btn: Button = Button.new()
	edit_btn.name = "EditButton"
	edit_btn.text = "Edit SEXP"
	edit_btn.custom_minimum_size = Vector2(80, 24)
	preview_hbox.add_child(edit_btn)
	
	# Update references
	label = prop_label
	preview_container = preview_hbox
	preview_text = preview_label
	edit_button = edit_btn
	
	# Connect signals
	edit_button.pressed.connect(_on_edit_pressed)

func setup_editor(prop_name: String, label_text: String, value: String, editor_options: Dictionary = {}) -> void:
	"""Setup the editor with property information."""
	property_name = prop_name
	current_value = value
	options = editor_options
	
	# Set label
	label.text = label_text + ":"
	if options.has("tooltip"):
		label.tooltip_text = options.tooltip
	
	# Update preview
	_update_preview(value)

func set_value(new_value: String) -> void:
	"""Set the current value and update preview."""
	current_value = new_value
	_update_preview(new_value)

func get_value() -> Variant:
	"""Get the current SEXP expression."""
	return current_value

func set_validation_state(is_valid: bool, error_message: String = "") -> void:
	"""Set validation state for SEXP expression."""
	if is_valid:
		preview_text.modulate = Color.WHITE
	else:
		preview_text.modulate = Color.RED
		validation_error.emit(error_message)

func has_validation_error() -> bool:
	"""Check if editor has validation error."""
	return preview_text.modulate == Color.RED

func get_validation_state() -> Dictionary:
	"""Get validation state information."""
	return {
		"is_valid": not has_validation_error(),
		"property_name": property_name,
		"current_value": current_value,
		"is_empty": current_value.is_empty()
	}

func get_performance_metrics() -> Dictionary:
	"""Get performance metrics for testing."""
	return {
		"property_name": property_name,
		"editor_type": "sexp",
		"has_validation_error": has_validation_error(),
		"current_value": current_value,
		"expression_length": current_value.length(),
		"is_empty_expression": current_value.is_empty()
	}

func reset_performance_metrics() -> void:
	"""Reset performance metrics."""
	# Simple implementation since performance isn't critical
	pass

func can_handle_property_type(property_type: String) -> bool:
	"""Validate if this editor can handle the given property type."""
	return property_type in ["sexp", "SEXP", "expression", "arrival_cue", "departure_cue", "ai_goals"]

func get_property_name() -> String:
	"""Get the property name for search filtering."""
	return property_name

func _update_preview(sexp_expression: String) -> void:
	"""Update the preview text with formatted SEXP."""
	if sexp_expression.is_empty():
		preview_text.text = "(No expression)"
		preview_text.add_theme_color_override("font_color", Color.GRAY)
	else:
		# Format SEXP for preview
		var formatted_sexp: String = _format_sexp_preview(sexp_expression)
		preview_text.text = formatted_sexp
		preview_text.add_theme_color_override("font_color", Color.WHITE)
	
	# Update tooltip with full expression
	preview_text.tooltip_text = sexp_expression if not sexp_expression.is_empty() else "Click 'Edit SEXP' to create an expression"

func _format_sexp_preview(sexp: String) -> String:
	"""Format SEXP expression for compact preview."""
	# Remove extra whitespace
	var cleaned: String = sexp.strip_edges()
	
	# If it's short enough, show as-is
	if cleaned.length() <= 50:
		return cleaned
	
	# Try to extract the main operator for preview
	var main_op: String = _extract_main_operator(cleaned)
	if not main_op.is_empty():
		return "(%s ...)" % main_op
	
	# Fallback to truncated version
	return cleaned.substr(0, 47) + "..."

func _extract_main_operator(sexp: String) -> String:
	"""Extract the main operator from a SEXP expression."""
	# Remove outer parentheses
	var trimmed: String = sexp.strip_edges()
	if trimmed.begins_with("(") and trimmed.ends_with(")"):
		trimmed = trimmed.substr(1, trimmed.length() - 2).strip_edges()
	
	# Get first token (the operator)
	var space_pos: int = trimmed.find(" ")
	if space_pos > 0:
		return trimmed.substr(0, space_pos)
	else:
		return trimmed

func _on_edit_pressed() -> void:
	"""Handle edit button press to open visual SEXP editor."""
	edit_requested.emit()

func update_from_visual_editor(new_expression: String) -> void:
	"""Update the SEXP value from the visual editor."""
	if new_expression != current_value:
		current_value = new_expression
		_update_preview(new_expression)
		value_changed.emit(new_expression)