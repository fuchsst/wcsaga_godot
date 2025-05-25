class_name FilePathPropertyEditor
extends VBoxContainer

## File path property editor with browse dialog.
## Supports file and directory selection with filtering.

signal value_changed(new_value: String)
signal validation_error(error_message: String)

var property_name: String = ""
var current_value: String = ""
var options: Dictionary = {}
var validation_state: bool = true

@onready var label: Label = $Label
@onready var path_container: HBoxContainer = $PathContainer
@onready var path_edit: LineEdit = $PathContainer/PathEdit
@onready var browse_button: Button = $PathContainer/BrowseButton
@onready var validation_label: Label = $ValidationLabel

var file_dialog: FileDialog

func _ready() -> void:
	name = "FilePathPropertyEditor"
	_setup_ui()

func _setup_ui() -> void:
	"""Initialize the UI structure."""
	# Property label
	var prop_label: Label = Label.new()
	prop_label.name = "Label"
	add_child(prop_label)
	
	# Path container
	var path_hbox: HBoxContainer = HBoxContainer.new()
	path_hbox.name = "PathContainer"
	add_child(path_hbox)
	
	# Path edit
	var path_line_edit: LineEdit = LineEdit.new()
	path_line_edit.name = "PathEdit"
	path_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_line_edit.placeholder_text = "Enter file path or click Browse..."
	path_hbox.add_child(path_line_edit)
	
	# Browse button
	var browse_btn: Button = Button.new()
	browse_btn.name = "BrowseButton"
	browse_btn.text = "Browse"
	browse_btn.custom_minimum_size = Vector2(60, 24)
	path_hbox.add_child(browse_btn)
	
	# Validation label
	var val_label: Label = Label.new()
	val_label.name = "ValidationLabel"
	val_label.modulate = Color.RED
	val_label.visible = false
	add_child(val_label)
	
	# Update references
	label = prop_label
	path_container = path_hbox
	path_edit = path_line_edit
	browse_button = browse_btn
	validation_label = val_label
	
	# Connect signals
	path_edit.text_changed.connect(_on_path_changed)
	path_edit.focus_exited.connect(_on_focus_exited)
	browse_button.pressed.connect(_on_browse_pressed)

func setup_editor(prop_name: String, label_text: String, value: String, editor_options: Dictionary = {}) -> void:
	"""Setup the editor with property information."""
	property_name = prop_name
	current_value = value
	options = editor_options
	
	# Set label
	label.text = label_text + ":"
	if options.has("tooltip"):
		label.tooltip_text = options.tooltip
		path_edit.tooltip_text = options.tooltip
	
	# Set initial value
	path_edit.text = value
	
	# Setup file dialog
	_setup_file_dialog()

func _setup_file_dialog() -> void:
	"""Setup the file dialog based on options."""
	file_dialog = FileDialog.new()
	
	# Set dialog mode
	var dialog_mode: String = options.get("dialog_mode", "file")
	match dialog_mode:
		"file":
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		"directory":
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		"save":
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	
	# Set filters
	if options.has("file_filter"):
		var filters: String = options.file_filter
		for filter in filters.split(","):
			file_dialog.add_filter(filter.strip_edges())
	
	# Set initial directory
	var base_path: String = options.get("base_path", "res://")
	file_dialog.current_dir = base_path
	
	# Add to scene tree
	add_child(file_dialog)
	
	# Connect signals
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.dir_selected.connect(_on_dir_selected)

func set_value(new_value: String) -> void:
	"""Set the current value without triggering signals."""
	current_value = new_value
	path_edit.text = new_value

func get_value() -> String:
	"""Get the current editor value."""
	return current_value

func set_validation_state(is_valid: bool, error_message: String = "") -> void:
	"""Set the validation state and show/hide error message."""
	validation_state = is_valid
	
	if is_valid:
		validation_label.visible = false
		path_edit.modulate = Color.WHITE
	else:
		validation_label.text = error_message
		validation_label.visible = true
		path_edit.modulate = Color(1.0, 0.8, 0.8)  # Light red tint
		validation_error.emit(error_message)

func has_validation_error() -> bool:
	"""Check if editor has validation error."""
	return not validation_state

func get_property_name() -> String:
	"""Get the property name for search filtering."""
	return property_name

func _on_path_changed(new_path: String) -> void:
	"""Handle path text change."""
	current_value = new_path
	_validate_current_path()
	value_changed.emit(new_path)

func _on_focus_exited() -> void:
	"""Handle focus lost for final validation."""
	_validate_current_path()

func _on_browse_pressed() -> void:
	"""Handle browse button press."""
	# Set current path in dialog
	if not current_value.is_empty():
		var dir_path: String = current_value.get_base_dir()
		if DirAccess.dir_exists_absolute(dir_path):
			file_dialog.current_dir = dir_path
			file_dialog.current_file = current_value.get_file()
	
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_file_selected(path: String) -> void:
	"""Handle file selection from dialog."""
	# Convert to relative path if needed
	var final_path: String = _convert_to_relative_path(path)
	set_value(final_path)
	value_changed.emit(final_path)

func _on_dir_selected(path: String) -> void:
	"""Handle directory selection from dialog."""
	# Convert to relative path if needed
	var final_path: String = _convert_to_relative_path(path)
	set_value(final_path)
	value_changed.emit(final_path)

func _convert_to_relative_path(absolute_path: String) -> String:
	"""Convert absolute path to relative path if within project."""
	var use_relative: bool = options.get("use_relative_paths", true)
	if not use_relative:
		return absolute_path
	
	var project_path: String = ProjectSettings.globalize_path("res://")
	var globalized_path: String = ProjectSettings.globalize_path(absolute_path)
	
	if globalized_path.begins_with(project_path):
		# Convert to resource path
		return ProjectSettings.localize_path(absolute_path)
	
	return absolute_path

func _validate_current_path() -> void:
	"""Validate the current path."""
	var validation_result: Dictionary = _perform_validation(current_value)
	set_validation_state(validation_result.is_valid, validation_result.get("error_message", ""))

func _perform_validation(path: String) -> Dictionary:
	"""Perform validation on the given path."""
	var result: Dictionary = {"is_valid": true}
	
	# Required validation
	if options.get("required", false) and path.is_empty():
		result.is_valid = false
		result.error_message = "File path is required"
		return result
	
	# Empty path is valid if not required
	if path.is_empty():
		return result
	
	# File existence validation
	var check_exists: bool = options.get("must_exist", false)
	if check_exists:
		var dialog_mode: String = options.get("dialog_mode", "file")
		match dialog_mode:
			"file":
				if not FileAccess.file_exists(path):
					result.is_valid = false
					result.error_message = "File does not exist: %s" % path
					return result
			"directory":
				if not DirAccess.dir_exists_absolute(path):
					result.is_valid = false
					result.error_message = "Directory does not exist: %s" % path
					return result
	
	# Extension validation
	if options.has("required_extension"):
		var required_ext: String = options.required_extension
		if not path.get_extension().to_lower() == required_ext.to_lower():
			result.is_valid = false
			result.error_message = "File must have .%s extension" % required_ext
			return result
	
	return result