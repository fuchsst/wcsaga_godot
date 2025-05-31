@tool
class_name BaseDialogController
extends AcceptDialog

## Base dialog controller for GFRED2-011 UI Refactoring.
## Scene-based UI controller providing common dialog functionality.
## Scene: addons/gfred2/scenes/dialogs/base_dialog.tscn

signal dialog_applied()
signal dialog_cancelled()
signal validation_changed(is_valid: bool, errors: Array[String])

# Dialog state
var is_valid: bool = true
var validation_errors: Array[String] = []
var dialog_data: Dictionary = {}

# Scene node references
@onready var main_container: VBoxContainer = $MainContainer
@onready var title_label: Label = $MainContainer/DialogHeader/TitleLabel
@onready var help_button: Button = $MainContainer/DialogHeader/HelpButton
@onready var content_container: VBoxContainer = $MainContainer/ContentContainer
@onready var validation_label: Label = $MainContainer/FooterContainer/ValidationLabel
@onready var apply_button: Button = $MainContainer/FooterContainer/ApplyButton
@onready var cancel_button: Button = $MainContainer/FooterContainer/CancelButton
@onready var ok_button: Button = $MainContainer/FooterContainer/OKButton

# Help system
var help_topic: String = ""

func _ready() -> void:
	name = "BaseDialog"
	_setup_dialog()
	_connect_signals()
	_setup_validation()
	print("BaseDialogController: Scene-based base dialog initialized")

func _setup_dialog() -> void:
	# Set dialog properties
	resizable = true
	size = Vector2i(600, 400)
	
	# Set title if not already set
	if title_label and title_label.text == "Dialog Title":
		title_label.text = title

func _connect_signals() -> void:
	if help_button:
		help_button.pressed.connect(_on_help_pressed)
	
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	
	# Connect base dialog signals
	confirmed.connect(_on_dialog_confirmed)
	canceled.connect(_on_dialog_canceled)

func _setup_validation() -> void:
	_update_validation_display()

## Virtual methods for subclasses to override

func _validate_dialog() -> bool:
	# Override this in subclasses to implement validation
	return true

func _get_validation_errors() -> Array[String]:
	# Override this in subclasses to provide specific validation errors
	return []

func _apply_changes() -> void:
	# Override this in subclasses to implement apply functionality
	pass

func _reset_to_defaults() -> void:
	# Override this in subclasses to implement reset functionality
	pass

func _show_help() -> void:
	# Override this in subclasses to show context-specific help
	print("BaseDialogController: Help requested for topic: %s" % help_topic)

## Validation system

func validate() -> bool:
	is_valid = _validate_dialog()
	validation_errors = _get_validation_errors()
	
	_update_validation_display()
	validation_changed.emit(is_valid, validation_errors)
	
	return is_valid

func _update_validation_display() -> void:
	if not validation_label:
		return
	
	if is_valid:
		validation_label.text = ""
		validation_label.visible = false
	else:
		var error_text: String = "Errors: " + "; ".join(validation_errors)
		validation_label.text = error_text
		validation_label.visible = true
		validation_label.modulate = Color.RED
	
	# Update button states
	_update_button_states()

func _update_button_states() -> void:
	if ok_button:
		ok_button.disabled = not is_valid
	
	if apply_button:
		apply_button.disabled = not is_valid

## Button management

func set_button_visibility(button_name: String, visible: bool) -> void:
	match button_name.to_lower():
		"apply":
			if apply_button:
				apply_button.visible = visible
		"cancel":
			if cancel_button:
				cancel_button.visible = visible
		"ok":
			if ok_button:
				ok_button.visible = visible
		"help":
			if help_button:
				help_button.visible = visible

func set_button_text(button_name: String, text: String) -> void:
	match button_name.to_lower():
		"apply":
			if apply_button:
				apply_button.text = text
		"cancel":
			if cancel_button:
				cancel_button.text = text
		"ok":
			if ok_button:
				ok_button.text = text

## Signal handlers

func _on_help_pressed() -> void:
	_show_help()

func _on_apply_pressed() -> void:
	if validate():
		_apply_changes()
		dialog_applied.emit()

func _on_cancel_pressed() -> void:
	_on_dialog_canceled()

func _on_ok_pressed() -> void:
	if validate():
		_apply_changes()
		_on_dialog_confirmed()

func _on_dialog_confirmed() -> void:
	# Base confirmed signal already emitted by AcceptDialog
	hide()

func _on_dialog_canceled() -> void:
	dialog_cancelled.emit()
	hide()

## Public API methods

func set_dialog_title(new_title: String) -> void:
	title = new_title
	if title_label:
		title_label.text = new_title

func get_dialog_title() -> String:
	return title_label.text if title_label else title

func set_help_topic(topic: String) -> void:
	help_topic = topic
	if help_button:
		help_button.visible = not topic.is_empty()

func get_content_container() -> VBoxContainer:
	return content_container

func add_content_widget(widget: Control) -> void:
	if content_container:
		content_container.add_child(widget)

func clear_content() -> void:
	if content_container:
		for child in content_container.get_children():
			child.queue_free()

func set_dialog_data(data: Dictionary) -> void:
	dialog_data = data

func get_dialog_data() -> Dictionary:
	return dialog_data

func show_dialog() -> void:
	validate()
	popup_centered()

func is_dialog_valid() -> bool:
	return is_valid

func get_dialog_validation_errors() -> Array[String]:
	return validation_errors

## Size and positioning helpers

func resize_to_content() -> void:
	# Calculate minimum size needed for content
	var min_size: Vector2 = Vector2(400, 300)  # Minimum dialog size
	
	if content_container:
		content_container.queue_redraw()
		await get_tree().process_frame  # Wait for layout
		var content_size: Vector2 = content_container.get_combined_minimum_size()
		min_size.x = max(min_size.x, content_size.x + 50)  # Add padding
		min_size.y = max(min_size.y, content_size.y + 150)  # Add header/footer space
	
	size = Vector2i(min_size)

func center_on_parent() -> void:
	if get_parent():
		popup_centered()
	else:
		position = (get_viewport().get_visible_rect().size - size) / 2