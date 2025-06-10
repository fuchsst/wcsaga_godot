@tool
extends Control

## WCS Conversion Dock
## Provides editor UI for WCS asset conversion with progress tracking and import management

class_name ConversionDock

signal conversion_started(asset_type: String)
signal conversion_completed(asset_type: String, success: bool)

# UI Elements
@onready var status_label: Label
@onready var progress_bar: ProgressBar
@onready var convert_vp_button: Button
@onready var convert_pof_button: Button
@onready var convert_mission_button: Button
@onready var batch_convert_button: Button
@onready var settings_button: Button
@onready var file_dialog: FileDialog
@onready var settings_dialog: AcceptDialog

# Conversion state
var current_conversion_type: String = ""
var conversion_in_progress: bool = false

func _init() -> void:
	name = "WCS Converter"
	set_custom_minimum_size(Vector2(250, 400))

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	"""Setup the conversion dock UI"""
	
	# Main container
	var main_vbox: VBoxContainer = VBoxContainer.new()
	add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Title
	var title_label: Label = Label.new()
	title_label.text = "WCS Asset Converter"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Status section
	var status_container: VBoxContainer = VBoxContainer.new()
	main_vbox.add_child(status_container)
	
	var status_title: Label = Label.new()
	status_title.text = "Status"
	status_title.add_theme_font_size_override("font_size", 12)
	status_container.add_child(status_title)
	
	status_label = Label.new()
	status_label.text = "Ready"
	status_label.add_theme_color_override("font_color", Color.GREEN)
	status_container.add_child(status_label)
	
	progress_bar = ProgressBar.new()
	progress_bar.visible = false
	progress_bar.custom_minimum_size = Vector2(0, 20)
	status_container.add_child(progress_bar)
	
	main_vbox.add_child(HSeparator.new())
	
	# Individual conversion buttons
	var convert_container: VBoxContainer = VBoxContainer.new()
	main_vbox.add_child(convert_container)
	
	var convert_title: Label = Label.new()
	convert_title.text = "Convert Individual Assets"
	convert_title.add_theme_font_size_override("font_size", 12)
	convert_container.add_child(convert_title)
	
	convert_vp_button = Button.new()
	convert_vp_button.text = "Import VP Archive"
	convert_vp_button.tooltip_text = "Import and extract WCS VP archive files"
	convert_container.add_child(convert_vp_button)
	
	convert_pof_button = Button.new()
	convert_pof_button.text = "Import POF Model"
	convert_pof_button.tooltip_text = "Import WCS POF 3D model files"
	convert_container.add_child(convert_pof_button)
	
	convert_mission_button = Button.new()
	convert_mission_button.text = "Import Mission File"
	convert_mission_button.tooltip_text = "Import WCS FS2 mission files"
	convert_container.add_child(convert_mission_button)
	
	main_vbox.add_child(HSeparator.new())
	
	# Batch conversion section
	var batch_container: VBoxContainer = VBoxContainer.new()
	main_vbox.add_child(batch_container)
	
	var batch_title: Label = Label.new()
	batch_title.text = "Batch Operations"
	batch_title.add_theme_font_size_override("font_size", 12)
	batch_container.add_child(batch_title)
	
	batch_convert_button = Button.new()
	batch_convert_button.text = "Convert WCS Directory"
	batch_convert_button.tooltip_text = "Convert entire WCS installation directory"
	batch_container.add_child(batch_convert_button)
	
	main_vbox.add_child(HSeparator.new())
	
	# Settings section
	var settings_container: VBoxContainer = VBoxContainer.new()
	main_vbox.add_child(settings_container)
	
	settings_button = Button.new()
	settings_button.text = "Conversion Settings"
	settings_button.tooltip_text = "Configure conversion options and paths"
	settings_container.add_child(settings_button)
	
	# Add spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 0)
	main_vbox.add_child(spacer)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Create file dialog
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	add_child(file_dialog)
	
	# Create settings dialog
	_create_settings_dialog()

func _connect_signals() -> void:
	"""Connect UI signals"""
	
	convert_vp_button.pressed.connect(_on_convert_vp_pressed)
	convert_pof_button.pressed.connect(_on_convert_pof_pressed)
	convert_mission_button.pressed.connect(_on_convert_mission_pressed)
	batch_convert_button.pressed.connect(_on_batch_convert_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.files_selected.connect(_on_files_selected)

func _create_settings_dialog() -> void:
	"""Create conversion settings dialog"""
	
	settings_dialog = AcceptDialog.new()
	settings_dialog.title = "WCS Conversion Settings"
	settings_dialog.set_flag(Window.FLAG_RESIZE_DISABLED, false)
	settings_dialog.size = Vector2(500, 400)
	
	var scroll_container: ScrollContainer = ScrollContainer.new()
	settings_dialog.add_child(scroll_container)
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.add_theme_constant_override("margin_left", 10)
	scroll_container.add_theme_constant_override("margin_right", 10)
	scroll_container.add_theme_constant_override("margin_top", 10)
	scroll_container.add_theme_constant_override("margin_bottom", 50)
	
	var settings_vbox: VBoxContainer = VBoxContainer.new()
	scroll_container.add_child(settings_vbox)
	
	# VP Archive Settings
	_add_settings_section(settings_vbox, "VP Archive Settings", [
		{"name": "Extract to subdirectory", "type": "bool", "default": true},
		{"name": "Organize by asset type", "type": "bool", "default": true},
		{"name": "Generate manifest", "type": "bool", "default": true}
	])
	
	# POF Model Settings
	_add_settings_section(settings_vbox, "POF Model Settings", [
		{"name": "Auto-find textures", "type": "bool", "default": true},
		{"name": "Generate collision", "type": "bool", "default": true},
		{"name": "Generate LODs", "type": "bool", "default": true},
		{"name": "Import scale", "type": "float", "default": 1.0, "range": "0.01,10.0,0.01"}
	])
	
	# Mission File Settings
	_add_settings_section(settings_vbox, "Mission File Settings", [
		{"name": "Convert SEXP events", "type": "bool", "default": true},
		{"name": "Generate waypoint gizmos", "type": "bool", "default": true},
		{"name": "Preserve coordinates", "type": "bool", "default": true}
	])
	
	add_child(settings_dialog)

func _add_settings_section(parent: VBoxContainer, title: String, settings: Array) -> void:
	"""Add a settings section to the dialog"""
	
	var section_label: Label = Label.new()
	section_label.text = title
	section_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(section_label)
	
	for setting in settings:
		var setting_container: HBoxContainer = HBoxContainer.new()
		parent.add_child(setting_container)
		
		var label: Label = Label.new()
		label.text = setting.get("name", "Unknown")
		label.custom_minimum_size = Vector2(200, 0)
		setting_container.add_child(label)
		
		match setting.get("type", "bool"):
			"bool":
				var checkbox: CheckBox = CheckBox.new()
				checkbox.button_pressed = setting.get("default", false)
				setting_container.add_child(checkbox)
			
			"float":
				var spinbox: SpinBox = SpinBox.new()
				spinbox.value = setting.get("default", 0.0)
				if setting.has("range"):
					var range_parts: PackedStringArray = setting["range"].split(",")
					if range_parts.size() >= 3:
						spinbox.min_value = range_parts[0].to_float()
						spinbox.max_value = range_parts[1].to_float()
						spinbox.step = range_parts[2].to_float()
				setting_container.add_child(spinbox)
			
			"string":
				var line_edit: LineEdit = LineEdit.new()
				line_edit.text = setting.get("default", "")
				line_edit.custom_minimum_size = Vector2(150, 0)
				setting_container.add_child(line_edit)
	
	parent.add_child(HSeparator.new())

# Button handlers
func _on_convert_vp_pressed() -> void:
	"""Handle VP archive conversion button"""
	if conversion_in_progress:
		return
	
	current_conversion_type = "vp"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.clear_filters()
	file_dialog.add_filter("*.vp", "WCS VP Archives")
	file_dialog.popup_centered(Vector2(800, 600))

func _on_convert_pof_pressed() -> void:
	"""Handle POF model conversion button"""
	if conversion_in_progress:
		return
	
	current_conversion_type = "pof"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.clear_filters()
	file_dialog.add_filter("*.pof", "WCS POF Models")
	file_dialog.popup_centered(Vector2(800, 600))

func _on_convert_mission_pressed() -> void:
	"""Handle mission file conversion button"""
	if conversion_in_progress:
		return
	
	current_conversion_type = "mission"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.clear_filters()
	file_dialog.add_filter("*.fs2;*.fc2", "WCS Mission Files")
	file_dialog.popup_centered(Vector2(800, 600))

func _on_batch_convert_pressed() -> void:
	"""Handle batch conversion button"""
	if conversion_in_progress:
		return
	
	current_conversion_type = "batch"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.popup_centered(Vector2(800, 600))

func _on_settings_pressed() -> void:
	"""Handle settings button"""
	settings_dialog.popup_centered()

func _on_file_selected(file_path: String) -> void:
	"""Handle single file selection"""
	_start_conversion([file_path])

func _on_files_selected(file_paths: PackedStringArray) -> void:
	"""Handle multiple file selection"""
	_start_conversion(Array(file_paths))

func _start_conversion(file_paths: Array) -> void:
	"""Start conversion process"""
	if conversion_in_progress:
		return
	
	conversion_in_progress = true
	_update_ui_for_conversion(true)
	
	conversion_started.emit(current_conversion_type)
	
	match current_conversion_type:
		"vp":
			_convert_vp_files(file_paths)
		"pof":
			_convert_pof_files(file_paths)
		"mission":
			_convert_mission_files(file_paths)
		"batch":
			_convert_directory_batch(file_paths[0] if file_paths.size() > 0 else "")

func _convert_vp_files(file_paths: Array) -> void:
	"""Convert VP archive files"""
	status_label.text = "Importing VP archives..."
	
	for file_path in file_paths:
		# Force import through Godot's import system
		EditorInterface.get_resource_filesystem().update_file(file_path)
	
	# Wait for import to complete
	await EditorInterface.get_resource_filesystem().filesystem_changed
	
	_finish_conversion(true, "VP archives imported successfully")

func _convert_pof_files(file_paths: Array) -> void:
	"""Convert POF model files"""
	status_label.text = "Importing POF models..."
	
	for file_path in file_paths:
		# Force import through Godot's import system
		EditorInterface.get_resource_filesystem().update_file(file_path)
	
	# Wait for import to complete
	await EditorInterface.get_resource_filesystem().filesystem_changed
	
	_finish_conversion(true, "POF models imported successfully")

func _convert_mission_files(file_paths: Array) -> void:
	"""Convert mission files"""
	status_label.text = "Importing mission files..."
	
	for file_path in file_paths:
		# Force import through Godot's import system
		EditorInterface.get_resource_filesystem().update_file(file_path)
	
	# Wait for import to complete
	await EditorInterface.get_resource_filesystem().filesystem_changed
	
	_finish_conversion(true, "Mission files imported successfully")

func _convert_directory_batch(directory_path: String) -> void:
	"""Convert entire directory using CLI tool"""
	status_label.text = "Running batch conversion..."
	
	# Use the CLI tool for batch operations
	var python_command: Array[String] = [
		ProjectSettings.globalize_path("res://conversion_tools/convert_wcs_assets.py"),
		"--source", directory_path,
		"--target", ProjectSettings.globalize_path("res://"),
		"--validate"
	]
	
	var output: Array = []
	var exit_code: int = OS.execute("python3", python_command, output, true, true)
	
	if exit_code == 0:
		EditorInterface.get_resource_filesystem().scan()
		_finish_conversion(true, "Batch conversion completed successfully")
	else:
		_finish_conversion(false, "Batch conversion failed: " + str(output))

func _update_ui_for_conversion(in_progress: bool) -> void:
	"""Update UI elements for conversion state"""
	
	conversion_in_progress = in_progress
	
	convert_vp_button.disabled = in_progress
	convert_pof_button.disabled = in_progress
	convert_mission_button.disabled = in_progress
	batch_convert_button.disabled = in_progress
	
	progress_bar.visible = in_progress
	
	if in_progress:
		progress_bar.value = 50  # Indeterminate progress
		status_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		progress_bar.visible = false

func _finish_conversion(success: bool, message: String) -> void:
	"""Finish conversion and update UI"""
	
	_update_ui_for_conversion(false)
	
	status_label.text = message
	if success:
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.add_theme_color_override("font_color", Color.RED)
	
	conversion_completed.emit(current_conversion_type, success)
	current_conversion_type = ""
	
	# Reset status after a delay
	await get_tree().create_timer(3.0).timeout
	if not conversion_in_progress:
		status_label.text = "Ready"
		status_label.add_theme_color_override("font_color", Color.GREEN)
