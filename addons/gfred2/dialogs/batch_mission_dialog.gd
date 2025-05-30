@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

## Batch Mission Import/Export Dialog using EPIC-003 MissionConverter
## Provides batch processing capabilities for multiple mission files

signal batch_operation_completed(success: bool, results: Dictionary)
signal progress_updated(current_file: String, progress: float)

const MissionConverter = preload("res://addons/wcs_converter/conversion/mission_converter.gd")

enum OperationType {
	IMPORT,
	EXPORT
}

var operation_type: OperationType = OperationType.IMPORT
var mission_converter: MissionConverter

# UI components
var operation_tabs: TabContainer
var source_path_edit: LineEdit
var source_browse_button: Button
var destination_path_edit: LineEdit
var destination_browse_button: Button
var file_list: ItemList
var progress_bar: ProgressBar
var progress_label: Label
var start_button: Button
var options_container: VBoxContainer

# Operation settings
var import_options: Dictionary = {
	"convert_sexp_events": true,
	"sexp_validation_level": 1,
	"generate_waypoint_gizmos": true,
	"preserve_coordinates": true,
	"coordinate_scale": 1.0,
	"use_custom_ship_models": false,
	"generate_mission_resource": true
}

var export_options: Dictionary = {
	"convert_sexp_events": true,
	"sexp_validation_level": 1,
	"generate_waypoint_gizmos": true,
	"preserve_coordinates": true,
	"coordinate_scale": 1.0,
	"use_custom_ship_models": false,
	"generate_mission_resource": false
}

# Batch processing state
var current_files: Array[String] = []
var processed_files: Array[String] = []
var failed_files: Array[String] = []
var is_processing: bool = false

func _ready() -> void:
	super._ready()
	
	# Initialize mission converter
	mission_converter = MissionConverter.new()
	
	# Setup UI components
	_setup_ui()
	
	# Connect signals
	_connect_signals()

func _setup_ui() -> void:
	"""Setup the batch dialog UI"""
	# Set dialog size
	size = Vector2(800, 600)
	
	# Create main container
	var main_container: VBoxContainer = VBoxContainer.new()
	add_child(main_container)
	
	# Header
	var header_label: Label = Label.new()
	header_label.text = "Batch Mission Operations"
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.add_theme_color_override("font_color", Color.WHITE)
	main_container.add_child(header_label)
	
	# Operation tabs
	operation_tabs = TabContainer.new()
	operation_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(operation_tabs)
	
	# Setup import and export tabs
	_setup_import_tab()
	_setup_export_tab()
	
	# Progress section
	_setup_progress_section(main_container)
	
	# Button container
	_setup_buttons(main_container)

func _setup_import_tab() -> void:
	"""Setup the import operations tab"""
	var import_tab: VBoxContainer = VBoxContainer.new()
	import_tab.name = "Import FS2 to Godot"
	operation_tabs.add_child(import_tab)
	
	# Source directory selection
	var source_container: HBoxContainer = HBoxContainer.new()
	import_tab.add_child(source_container)
	
	var source_label: Label = Label.new()
	source_label.text = "Source Directory:"
	source_label.custom_minimum_size.x = 120
	source_container.add_child(source_label)
	
	source_path_edit = LineEdit.new()
	source_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_path_edit.placeholder_text = "Select directory containing .fs2/.fc2 files"
	source_container.add_child(source_path_edit)
	
	source_browse_button = Button.new()
	source_browse_button.text = "Browse"
	source_container.add_child(source_browse_button)
	
	# Destination directory selection
	var dest_container: HBoxContainer = HBoxContainer.new()
	import_tab.add_child(dest_container)
	
	var dest_label: Label = Label.new()
	dest_label.text = "Destination:"
	dest_label.custom_minimum_size.x = 120
	dest_container.add_child(dest_label)
	
	destination_path_edit = LineEdit.new()
	destination_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_path_edit.placeholder_text = "Output directory for converted scenes"
	destination_path_edit.text = "res://missions/imported/"
	dest_container.add_child(destination_path_edit)
	
	destination_browse_button = Button.new()
	destination_browse_button.text = "Browse"
	dest_container.add_child(destination_browse_button)
	
	# File list
	var files_label: Label = Label.new()
	files_label.text = "Files to Import:"
	import_tab.add_child(files_label)
	
	file_list = ItemList.new()
	file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	file_list.custom_minimum_size.y = 200
	import_tab.add_child(file_list)
	
	# Import options
	_setup_import_options(import_tab)

func _setup_export_tab() -> void:
	"""Setup the export operations tab"""
	var export_tab: VBoxContainer = VBoxContainer.new()
	export_tab.name = "Export Godot to FS2"
	operation_tabs.add_child(export_tab)
	
	# TODO: Implement export tab UI
	var placeholder: Label = Label.new()
	placeholder.text = "Export functionality to be implemented"
	export_tab.add_child(placeholder)

func _setup_import_options(parent: Control) -> void:
	"""Setup import options controls"""
	var options_label: Label = Label.new()
	options_label.text = "Import Options:"
	parent.add_child(options_label)
	
	options_container = VBoxContainer.new()
	parent.add_child(options_container)
	
	# SEXP conversion option
	var sexp_checkbox: CheckBox = CheckBox.new()
	sexp_checkbox.text = "Convert SEXP events to GDScript"
	sexp_checkbox.button_pressed = import_options.convert_sexp_events
	sexp_checkbox.toggled.connect(func(pressed): import_options.convert_sexp_events = pressed)
	options_container.add_child(sexp_checkbox)
	
	# Waypoint gizmos option
	var waypoint_checkbox: CheckBox = CheckBox.new()
	waypoint_checkbox.text = "Generate waypoint gizmos"
	waypoint_checkbox.button_pressed = import_options.generate_waypoint_gizmos
	waypoint_checkbox.toggled.connect(func(pressed): import_options.generate_waypoint_gizmos = pressed)
	options_container.add_child(waypoint_checkbox)
	
	# Coordinate preservation option
	var coords_checkbox: CheckBox = CheckBox.new()
	coords_checkbox.text = "Preserve original coordinates"
	coords_checkbox.button_pressed = import_options.preserve_coordinates
	coords_checkbox.toggled.connect(func(pressed): import_options.preserve_coordinates = pressed)
	options_container.add_child(coords_checkbox)

func _setup_progress_section(parent: Control) -> void:
	"""Setup progress tracking UI"""
	var progress_container: VBoxContainer = VBoxContainer.new()
	parent.add_child(progress_container)
	
	progress_label = Label.new()
	progress_label.text = "Ready to begin batch operation"
	progress_container.add_child(progress_label)
	
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_container.add_child(progress_bar)

func _setup_buttons(parent: Control) -> void:
	"""Setup dialog buttons"""
	var button_container: HBoxContainer = HBoxContainer.new()
	parent.add_child(button_container)
	
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(spacer)
	
	start_button = Button.new()
	start_button.text = "Start Batch Operation"
	button_container.add_child(start_button)
	
	var cancel_button: Button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)

func _connect_signals() -> void:
	"""Connect UI signals"""
	source_browse_button.pressed.connect(_on_source_browse_pressed)
	destination_browse_button.pressed.connect(_on_destination_browse_pressed)
	source_path_edit.text_changed.connect(_on_source_path_changed)
	start_button.pressed.connect(_on_start_batch_operation)
	operation_tabs.tab_changed.connect(_on_operation_tab_changed)

func show_batch_dialog(operation: OperationType = OperationType.IMPORT) -> void:
	"""Show the batch dialog with specified operation"""
	operation_type = operation
	operation_tabs.current_tab = int(operation)
	_update_ui_for_operation()
	show_dialog(Vector2(800, 600))

func _update_ui_for_operation() -> void:
	"""Update UI based on current operation type"""
	match operation_type:
		OperationType.IMPORT:
			start_button.text = "Start Batch Import"
		OperationType.EXPORT:
			start_button.text = "Start Batch Export"

func _on_operation_tab_changed(tab_index: int) -> void:
	"""Handle operation tab change"""
	operation_type = tab_index as OperationType
	_update_ui_for_operation()

func _on_source_browse_pressed() -> void:
	"""Show directory selection dialog for source"""
	var dir_dialog: EditorFileDialog = EditorFileDialog.new()
	dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dir_dialog.current_dir = "res://assets/"
	
	dir_dialog.dir_selected.connect(_on_source_directory_selected)
	add_child(dir_dialog)
	dir_dialog.popup_centered(Vector2(800, 600))

func _on_destination_browse_pressed() -> void:
	"""Show directory selection dialog for destination"""
	var dir_dialog: EditorFileDialog = EditorFileDialog.new()
	dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dir_dialog.current_dir = "res://missions/"
	
	dir_dialog.dir_selected.connect(_on_destination_directory_selected)
	add_child(dir_dialog)
	dir_dialog.popup_centered(Vector2(800, 600))

func _on_source_directory_selected(path: String) -> void:
	"""Handle source directory selection"""
	source_path_edit.text = path
	_on_source_path_changed(path)

func _on_destination_directory_selected(path: String) -> void:
	"""Handle destination directory selection"""
	destination_path_edit.text = path

func _on_source_path_changed(path: String) -> void:
	"""Handle source path text change"""
	_scan_source_directory(path)

func _scan_source_directory(directory_path: String) -> void:
	"""Scan source directory for mission files"""
	file_list.clear()
	current_files.clear()
	
	if directory_path.is_empty() or not DirAccess.dir_exists_absolute(directory_path):
		return
	
	# Find mission files in directory
	var mission_files: Array[String] = _find_mission_files_in_directory(directory_path)
	
	for file_path in mission_files:
		var file_name: String = file_path.get_file()
		file_list.add_item(file_name)
		current_files.append(file_path)
	
	# Update start button state
	start_button.disabled = current_files.is_empty() or is_processing

func _find_mission_files_in_directory(directory_path: String) -> Array[String]:
	"""Find all mission files in the specified directory"""
	var files: Array[String] = []
	var extensions: Array[String] = ["fs2", "fc2"]
	
	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null:
		return files
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var extension: String = file_name.get_extension().to_lower()
			if extension in extensions:
				files.append(directory_path + "/" + file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return files

func _on_start_batch_operation() -> void:
	"""Start the batch operation"""
	if is_processing or current_files.is_empty():
		return
	
	is_processing = true
	processed_files.clear()
	failed_files.clear()
	
	start_button.disabled = true
	progress_bar.value = 0.0
	
	match operation_type:
		OperationType.IMPORT:
			await _perform_batch_import()
		OperationType.EXPORT:
			await _perform_batch_export()
	
	is_processing = false
	start_button.disabled = false
	
	# Emit completion signal
	var results: Dictionary = {
		"total_files": current_files.size(),
		"processed_files": processed_files,
		"failed_files": failed_files,
		"success_count": processed_files.size(),
		"failure_count": failed_files.size()
	}
	
	batch_operation_completed.emit(processed_files.size() == current_files.size(), results)

func _perform_batch_import() -> void:
	"""Perform batch import operation"""
	var total_files: int = current_files.size()
	
	for i in range(total_files):
		var file_path: String = current_files[i]
		var file_name: String = file_path.get_file()
		
		# Update progress
		var progress: float = (float(i) / float(total_files)) * 100.0
		progress_bar.value = progress
		progress_label.text = "Processing: %s (%d/%d)" % [file_name, i + 1, total_files]
		progress_updated.emit(file_name, progress)
		
		# Wait for frame to update UI
		await get_tree().process_frame
		
		# Convert mission file
		var output_path: String = destination_path_edit.text + "/" + file_name.get_basename() + ".tscn"
		var result: Dictionary = mission_converter.convert_mission_to_scene(file_path, output_path, import_options)
		
		if result.get("success", false):
			processed_files.append(file_path)
			print("Successfully imported: %s -> %s" % [file_name, output_path])
		else:
			failed_files.append(file_path)
			push_error("Failed to import %s: %s" % [file_name, result.get("error", "Unknown error")])
	
	# Final progress update
	progress_bar.value = 100.0
	progress_label.text = "Batch import completed: %d succeeded, %d failed" % [processed_files.size(), failed_files.size()]

func _perform_batch_export() -> void:
	"""Perform batch export operation"""
	# TODO: Implement batch export
	progress_label.text = "Batch export not yet implemented"

func _on_cancel_pressed() -> void:
	"""Handle cancel button press"""
	if is_processing:
		# TODO: Implement operation cancellation
		pass
	
	super._on_cancel_pressed()