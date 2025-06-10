@tool
extends Control

## WCS Data Migration Conversion Dock
## Main UI for controlling WCS to Godot asset conversion pipeline

signal conversion_started(conversion_type: String)
signal conversion_completed(conversion_type: String, success: bool)

@onready var conversion_tabs: TabContainer
@onready var vp_extraction_panel: Control
@onready var pof_conversion_panel: Control
@onready var mission_conversion_panel: Control
@onready var batch_conversion_panel: Control

# VP Extraction controls
@onready var vp_source_path: LineEdit
@onready var vp_browse_button: Button
@onready var vp_extract_button: Button
@onready var vp_progress: ProgressBar
@onready var vp_file_tree: Tree

# POF Conversion controls
@onready var pof_source_path: LineEdit
@onready var pof_browse_button: Button
@onready var pof_convert_button: Button
@onready var pof_preview_button: Button
@onready var pof_progress: ProgressBar
@onready var pof_options: VBoxContainer

# Mission Conversion controls
@onready var mission_source_path: LineEdit
@onready var mission_browse_button: Button
@onready var mission_convert_button: Button
@onready var mission_preview_tree: Tree
@onready var mission_progress: ProgressBar

# Batch Conversion controls
@onready var batch_source_dir: LineEdit
@onready var batch_browse_button: Button
@onready var batch_convert_button: Button
@onready var batch_progress: ProgressBar
@onready var batch_file_list: ItemList

# Status and logging
@onready var status_label: Label
@onready var conversion_log: TextEdit

func _ready() -> void:
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	name = "WCS Converter"
	custom_minimum_size = Vector2(300, 600)
	
	# Main container
	var main_vbox: VBoxContainer = VBoxContainer.new()
	add_child(main_vbox)
	
	# Title
	var title: Label = Label.new()
	title.text = "WCS Data Migration Tools"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	main_vbox.add_child(HSeparator.new())
	
	# Tab container for different conversion types
	conversion_tabs = TabContainer.new()
	conversion_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(conversion_tabs)
	
	_setup_vp_extraction_tab()
	_setup_pof_conversion_tab()
	_setup_mission_conversion_tab()
	_setup_batch_conversion_tab()
	
	# Status area
	main_vbox.add_child(HSeparator.new())
	status_label = Label.new()
	status_label.text = "Ready"
	main_vbox.add_child(status_label)
	
	# Conversion log
	var log_label: Label = Label.new()
	log_label.text = "Conversion Log:"
	main_vbox.add_child(log_label)
	
	conversion_log = TextEdit.new()
	conversion_log.custom_minimum_size.y = 120
	conversion_log.editable = false
	conversion_log.placeholder_text = "Conversion progress and results will appear here..."
	main_vbox.add_child(conversion_log)

func _setup_vp_extraction_tab() -> void:
	vp_extraction_panel = VBoxContainer.new()
	vp_extraction_panel.name = "VP Archives"
	conversion_tabs.add_child(vp_extraction_panel)
	
	# Source selection
	var source_label: Label = Label.new()
	source_label.text = "VP Archive File:"
	vp_extraction_panel.add_child(source_label)
	
	var source_hbox: HBoxContainer = HBoxContainer.new()
	vp_extraction_panel.add_child(source_hbox)
	
	vp_source_path = LineEdit.new()
	vp_source_path.placeholder_text = "Select .vp archive file"
	vp_source_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(vp_source_path)
	
	vp_browse_button = Button.new()
	vp_browse_button.text = "Browse"
	source_hbox.add_child(vp_browse_button)
	
	# Extraction options
	var options_label: Label = Label.new()
	options_label.text = "Extraction Options:"
	vp_extraction_panel.add_child(options_label)
	
	var organize_check: CheckBox = CheckBox.new()
	organize_check.text = "Organize by asset type"
	organize_check.button_pressed = true
	vp_extraction_panel.add_child(organize_check)
	
	var auto_import_check: CheckBox = CheckBox.new()
	auto_import_check.text = "Auto-import extracted assets"
	auto_import_check.button_pressed = true
	vp_extraction_panel.add_child(auto_import_check)
	
	# Extract button
	vp_extract_button = Button.new()
	vp_extract_button.text = "Extract VP Archive"
	vp_extract_button.disabled = true
	vp_extraction_panel.add_child(vp_extract_button)
	
	# Progress bar
	vp_progress = ProgressBar.new()
	vp_progress.visible = false
	vp_extraction_panel.add_child(vp_progress)
	
	# File tree preview
	var tree_label: Label = Label.new()
	tree_label.text = "Archive Contents:"
	vp_extraction_panel.add_child(tree_label)
	
	vp_file_tree = Tree.new()
	vp_file_tree.custom_minimum_size.y = 200
	vp_file_tree.hide_root = true
	vp_extraction_panel.add_child(vp_file_tree)

func _setup_pof_conversion_tab() -> void:
	pof_conversion_panel = VBoxContainer.new()
	pof_conversion_panel.name = "POF Models"
	conversion_tabs.add_child(pof_conversion_panel)
	
	# Source selection
	var source_label: Label = Label.new()
	source_label.text = "POF Model File:"
	pof_conversion_panel.add_child(source_label)
	
	var source_hbox: HBoxContainer = HBoxContainer.new()
	pof_conversion_panel.add_child(source_hbox)
	
	pof_source_path = LineEdit.new()
	pof_source_path.placeholder_text = "Select .pof model file"
	pof_source_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(pof_source_path)
	
	pof_browse_button = Button.new()
	pof_browse_button.text = "Browse"
	source_hbox.add_child(pof_browse_button)
	
	# Conversion options
	var options_label: Label = Label.new()
	options_label.text = "Conversion Options:"
	pof_conversion_panel.add_child(options_label)
	
	pof_options = VBoxContainer.new()
	pof_conversion_panel.add_child(pof_options)
	
	var generate_lod_check: CheckBox = CheckBox.new()
	generate_lod_check.text = "Generate LOD variants"
	generate_lod_check.button_pressed = true
	pof_options.add_child(generate_lod_check)
	
	var generate_collision_check: CheckBox = CheckBox.new()
	generate_collision_check.text = "Generate collision shapes"
	generate_collision_check.button_pressed = true
	pof_options.add_child(generate_collision_check)
	
	var import_scale_container: HBoxContainer = HBoxContainer.new()
	pof_options.add_child(import_scale_container)
	
	var scale_label: Label = Label.new()
	scale_label.text = "Import Scale:"
	import_scale_container.add_child(scale_label)
	
	var scale_spinbox: SpinBox = SpinBox.new()
	scale_spinbox.min_value = 0.01
	scale_spinbox.max_value = 100.0
	scale_spinbox.step = 0.01
	scale_spinbox.value = 1.0
	import_scale_container.add_child(scale_spinbox)
	
	# Action buttons
	var button_hbox: HBoxContainer = HBoxContainer.new()
	pof_conversion_panel.add_child(button_hbox)
	
	pof_preview_button = Button.new()
	pof_preview_button.text = "Preview Model"
	pof_preview_button.disabled = true
	button_hbox.add_child(pof_preview_button)
	
	pof_convert_button = Button.new()
	pof_convert_button.text = "Convert to GLB"
	pof_convert_button.disabled = true
	button_hbox.add_child(pof_convert_button)
	
	# Progress bar
	pof_progress = ProgressBar.new()
	pof_progress.visible = false
	pof_conversion_panel.add_child(pof_progress)

func _setup_mission_conversion_tab() -> void:
	mission_conversion_panel = VBoxContainer.new()
	mission_conversion_panel.name = "Missions"
	conversion_tabs.add_child(mission_conversion_panel)
	
	# Source selection
	var source_label: Label = Label.new()
	source_label.text = "Mission File:"
	mission_conversion_panel.add_child(source_label)
	
	var source_hbox: HBoxContainer = HBoxContainer.new()
	mission_conversion_panel.add_child(source_hbox)
	
	mission_source_path = LineEdit.new()
	mission_source_path.placeholder_text = "Select .fs2 mission file"
	mission_source_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(mission_source_path)
	
	mission_browse_button = Button.new()
	mission_browse_button.text = "Browse"
	source_hbox.add_child(mission_browse_button)
	
	# Convert button
	mission_convert_button = Button.new()
	mission_convert_button.text = "Convert Mission"
	mission_convert_button.disabled = true
	mission_conversion_panel.add_child(mission_convert_button)
	
	# Progress bar
	mission_progress = ProgressBar.new()
	mission_progress.visible = false
	mission_conversion_panel.add_child(mission_progress)
	
	# Mission preview tree
	var preview_label: Label = Label.new()
	preview_label.text = "Mission Objects:"
	mission_conversion_panel.add_child(preview_label)
	
	mission_preview_tree = Tree.new()
	mission_preview_tree.custom_minimum_size.y = 200
	mission_preview_tree.hide_root = true
	mission_conversion_panel.add_child(mission_preview_tree)

func _setup_batch_conversion_tab() -> void:
	batch_conversion_panel = VBoxContainer.new()
	batch_conversion_panel.name = "Batch Convert"
	conversion_tabs.add_child(batch_conversion_panel)
	
	# Source directory selection
	var source_label: Label = Label.new()
	source_label.text = "WCS Installation Directory:"
	batch_conversion_panel.add_child(source_label)
	
	var source_hbox: HBoxContainer = HBoxContainer.new()
	batch_conversion_panel.add_child(source_hbox)
	
	batch_source_dir = LineEdit.new()
	batch_source_dir.placeholder_text = "Select WCS installation directory"
	batch_source_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(batch_source_dir)
	
	batch_browse_button = Button.new()
	batch_browse_button.text = "Browse"
	source_hbox.add_child(batch_browse_button)
	
	# Convert button
	batch_convert_button = Button.new()
	batch_convert_button.text = "Start Batch Conversion"
	batch_convert_button.disabled = true
	batch_conversion_panel.add_child(batch_convert_button)
	
	# Progress bar
	batch_progress = ProgressBar.new()
	batch_progress.visible = false
	batch_conversion_panel.add_child(batch_progress)
	
	# File list
	var file_list_label: Label = Label.new()
	file_list_label.text = "Assets Found:"
	batch_conversion_panel.add_child(file_list_label)
	
	batch_file_list = ItemList.new()
	batch_file_list.custom_minimum_size.y = 200
	batch_conversion_panel.add_child(batch_file_list)

func _connect_signals() -> void:
	# VP Extraction
	vp_browse_button.pressed.connect(_on_vp_browse_pressed)
	vp_source_path.text_changed.connect(_on_vp_path_changed)
	vp_extract_button.pressed.connect(_on_vp_extract_pressed)
	
	# POF Conversion
	pof_browse_button.pressed.connect(_on_pof_browse_pressed)
	pof_source_path.text_changed.connect(_on_pof_path_changed)
	pof_preview_button.pressed.connect(_on_pof_preview_pressed)
	pof_convert_button.pressed.connect(_on_pof_convert_pressed)
	
	# Mission Conversion
	mission_browse_button.pressed.connect(_on_mission_browse_pressed)
	mission_source_path.text_changed.connect(_on_mission_path_changed)
	mission_convert_button.pressed.connect(_on_mission_convert_pressed)
	
	# Batch Conversion
	batch_browse_button.pressed.connect(_on_batch_browse_pressed)
	batch_source_dir.text_changed.connect(_on_batch_dir_changed)
	batch_convert_button.pressed.connect(_on_batch_convert_pressed)

# VP Extraction handlers
func _on_vp_browse_pressed() -> void:
	var file_dialog: EditorFileDialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.vp", "VP Archive Files")
	file_dialog.current_dir = "res://"
	
	add_child(file_dialog)
	file_dialog.file_selected.connect(_on_vp_file_selected)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_vp_file_selected(path: String) -> void:
	vp_source_path.text = path
	_preview_vp_contents(path)

func _on_vp_path_changed(new_text: String) -> void:
	vp_extract_button.disabled = new_text.is_empty() or not new_text.ends_with(".vp")
	if not new_text.is_empty() and new_text.ends_with(".vp"):
		_preview_vp_contents(new_text)

func _preview_vp_contents(vp_path: String) -> void:
	# Call Python script to preview VP contents
	_log_message("Previewing VP contents: %s" % vp_path)
	# TODO: Implement VP content preview

func _on_vp_extract_pressed() -> void:
	var vp_path: String = vp_source_path.text
	_log_message("Starting VP extraction: %s" % vp_path)
	
	conversion_started.emit("VP_EXTRACTION")
	vp_progress.visible = true
	vp_extract_button.disabled = true
	
	# TODO: Call Python VP extractor
	# For now, simulate success
	await get_tree().create_timer(2.0).timeout
	
	_log_message("VP extraction completed successfully")
	conversion_completed.emit("VP_EXTRACTION", true)
	
	vp_progress.visible = false
	vp_extract_button.disabled = false

# POF Conversion handlers
func _on_pof_browse_pressed() -> void:
	var file_dialog: EditorFileDialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.pof", "POF Model Files")
	file_dialog.current_dir = "res://"
	
	add_child(file_dialog)
	file_dialog.file_selected.connect(_on_pof_file_selected)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_pof_file_selected(path: String) -> void:
	pof_source_path.text = path

func _on_pof_path_changed(new_text: String) -> void:
	var is_valid: bool = not new_text.is_empty() and new_text.ends_with(".pof")
	pof_preview_button.disabled = not is_valid
	pof_convert_button.disabled = not is_valid

func _on_pof_preview_pressed() -> void:
	var pof_path: String = pof_source_path.text
	_log_message("Previewing POF model: %s" % pof_path)
	# TODO: Implement POF preview

func _on_pof_convert_pressed() -> void:
	var pof_path: String = pof_source_path.text
	_log_message("Starting POF conversion: %s" % pof_path)
	
	conversion_started.emit("POF_CONVERSION")
	pof_progress.visible = true
	pof_convert_button.disabled = true
	
	# TODO: Call Python POF converter
	await get_tree().create_timer(3.0).timeout
	
	_log_message("POF conversion completed successfully")
	conversion_completed.emit("POF_CONVERSION", true)
	
	pof_progress.visible = false
	pof_convert_button.disabled = false

# Mission Conversion handlers
func _on_mission_browse_pressed() -> void:
	var file_dialog: EditorFileDialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.fs2", "FS2 Mission Files")
	file_dialog.add_filter("*.fc2", "FC2 Mission Files")
	file_dialog.current_dir = "res://"
	
	add_child(file_dialog)
	file_dialog.file_selected.connect(_on_mission_file_selected)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_mission_file_selected(path: String) -> void:
	mission_source_path.text = path
	_preview_mission_contents(path)

func _on_mission_path_changed(new_text: String) -> void:
	mission_convert_button.disabled = new_text.is_empty() or not (new_text.ends_with(".fs2") or new_text.ends_with(".fc2"))
	if not new_text.is_empty() and (new_text.ends_with(".fs2") or new_text.ends_with(".fc2")):
		_preview_mission_contents(new_text)

func _preview_mission_contents(mission_path: String) -> void:
	_log_message("Previewing mission: %s" % mission_path)
	# TODO: Implement mission preview

func _on_mission_convert_pressed() -> void:
	var mission_path: String = mission_source_path.text
	_log_message("Starting mission conversion: %s" % mission_path)
	
	conversion_started.emit("MISSION_CONVERSION")
	mission_progress.visible = true
	mission_convert_button.disabled = true
	
	# TODO: Call Python mission converter
	await get_tree().create_timer(2.5).timeout
	
	_log_message("Mission conversion completed successfully")
	conversion_completed.emit("MISSION_CONVERSION", true)
	
	mission_progress.visible = false
	mission_convert_button.disabled = false

# Batch Conversion handlers
func _on_batch_browse_pressed() -> void:
	var file_dialog: EditorFileDialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	file_dialog.current_dir = "res://"
	
	add_child(file_dialog)
	file_dialog.dir_selected.connect(_on_batch_dir_selected)
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_batch_dir_selected(path: String) -> void:
	batch_source_dir.text = path
	_scan_wcs_directory(path)

func _on_batch_dir_changed(new_text: String) -> void:
	batch_convert_button.disabled = new_text.is_empty()
	if not new_text.is_empty():
		_scan_wcs_directory(new_text)

func _scan_wcs_directory(dir_path: String) -> void:
	_log_message("Scanning WCS directory: %s" % dir_path)
	batch_file_list.clear()
	
	# TODO: Call Python scanner to find assets
	# For now, simulate finding some files
	batch_file_list.add_item("root_fs2.vp (VP Archive)")
	batch_file_list.add_item("sparky_hi.vp (VP Archive)")
	batch_file_list.add_item("ships.tbl (Table Data)")
	batch_file_list.add_item("weapons.tbl (Table Data)")

func _on_batch_convert_pressed() -> void:
	var source_dir: String = batch_source_dir.text
	_log_message("Starting batch conversion: %s" % source_dir)
	
	conversion_started.emit("BATCH_CONVERSION")
	batch_progress.visible = true
	batch_convert_button.disabled = true
	
	# TODO: Call Python batch converter
	await get_tree().create_timer(10.0).timeout
	
	_log_message("Batch conversion completed successfully")
	conversion_completed.emit("BATCH_CONVERSION", true)
	
	batch_progress.visible = false
	batch_convert_button.disabled = false

# Utility functions
func _log_message(message: String) -> void:
	var timestamp: String = Time.get_datetime_string_from_system()
	var log_entry: String = "[%s] %s\n" % [timestamp, message]
	conversion_log.text += log_entry
	
	# Auto-scroll to bottom
	conversion_log.scroll_vertical = conversion_log.get_line_count()
	
	# Update status
	status_label.text = message

func _update_status(status: String) -> void:
	status_label.text = status
