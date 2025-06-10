@tool
extends BaseConversionPanel
class_name VPExtractionPanel

## VP Archive Extraction Panel
## Single Responsibility: VP archive extraction UI and logic only

@onready var source_path_input: LineEdit
@onready var browse_button: Button
@onready var extract_button: Button
@onready var progress_bar: ProgressBar
@onready var file_tree: Tree
@onready var organize_check: CheckBox
@onready var auto_import_check: CheckBox

func _initialize_panel() -> void:
	name = "VP Archives"
	conversion_script_path = "vp_extractor.py"

func _setup_ui_components() -> void:
	_create_source_selection()
	_create_extraction_options()
	_create_action_controls()
	_create_file_preview()

func _create_source_selection() -> void:
	"""Create source file selection UI"""
	var source_label: Label = Label.new()
	source_label.text = "VP Archive File:"
	add_child(source_label)
	
	var source_hbox: HBoxContainer = HBoxContainer.new()
	add_child(source_hbox)
	
	source_path_input = LineEdit.new()
	source_path_input.placeholder_text = "Select .vp archive file"
	source_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(source_path_input)
	
	browse_button = Button.new()
	browse_button.text = "Browse"
	source_hbox.add_child(browse_button)

func _create_extraction_options() -> void:
	"""Create extraction options UI"""
	var options_label: Label = Label.new()
	options_label.text = "Extraction Options:"
	add_child(options_label)
	
	organize_check = CheckBox.new()
	organize_check.text = "Organize by asset type"
	organize_check.button_pressed = true
	add_child(organize_check)
	
	auto_import_check = CheckBox.new()
	auto_import_check.text = "Auto-import extracted assets"
	auto_import_check.button_pressed = true
	add_child(auto_import_check)

func _create_action_controls() -> void:
	"""Create action buttons and progress"""
	extract_button = Button.new()
	extract_button.text = "Extract VP Archive"
	extract_button.disabled = true
	add_child(extract_button)
	
	progress_bar = ProgressBar.new()
	progress_bar.visible = false
	add_child(progress_bar)

func _create_file_preview() -> void:
	"""Create file tree preview"""
	var tree_label: Label = Label.new()
	tree_label.text = "Archive Contents:"
	add_child(tree_label)
	
	file_tree = Tree.new()
	file_tree.custom_minimum_size.y = 200
	file_tree.hide_root = true
	add_child(file_tree)

func _connect_panel_signals() -> void:
	"""Connect VP extraction specific signals"""
	browse_button.pressed.connect(_on_browse_pressed)
	source_path_input.text_changed.connect(_on_path_changed)
	extract_button.pressed.connect(_on_extract_pressed)

func _on_browse_pressed() -> void:
	"""Handle browse button press"""
	var filters: PackedStringArray = PackedStringArray(["*.vp;VP Archive Files"])
	show_file_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, filters, _on_file_selected)

func _on_file_selected(path: String) -> void:
	"""Handle file selection"""
	source_path_input.text = path
	_preview_vp_contents(path)

func _on_path_changed(new_text: String) -> void:
	"""Handle path input change"""
	extract_button.disabled = new_text.is_empty() or not new_text.ends_with(".vp")
	if not new_text.is_empty() and new_text.ends_with(".vp"):
		_preview_vp_contents(new_text)

func _preview_vp_contents(vp_path: String) -> void:
	"""Preview VP archive contents"""
	_emit_status("Previewing VP contents: " + vp_path)
	file_tree.clear()
	
	# TODO: Call Python script to get VP contents
	# For now, show placeholder
	var root: TreeItem = file_tree.create_item()
	root.set_text(0, "VP Contents")
	
	var item: TreeItem = file_tree.create_item(root)
	item.set_text(0, "Preview not yet implemented")

func _on_extract_pressed() -> void:
	"""Handle extract button press"""
	var vp_path: String = source_path_input.text
	_emit_status("Starting VP extraction: " + vp_path)
	
	_emit_conversion_started("VP_EXTRACTION")
	progress_bar.visible = true
	extract_button.disabled = true
	
	_perform_vp_extraction(vp_path)

func _perform_vp_extraction(vp_path: String) -> void:
	"""Perform the actual VP extraction"""
	var output_dir: String = "res://assets/vp_extracted/" + vp_path.get_file().get_basename()
	
	var args: PackedStringArray = PackedStringArray([
		conversion_script_path,
		"--extract", vp_path,
		"--output", output_dir
	])
	
	if organize_check.button_pressed:
		args.append("--organize")
	
	# Execute extraction in a separate thread to avoid blocking UI
	var success: bool = await _execute_extraction_async(args)
	
	_extraction_completed(success)

func _execute_extraction_async(args: PackedStringArray) -> bool:
	"""Execute extraction asynchronously"""
	# Simulate async operation for now
	await get_tree().create_timer(2.0).timeout
	
	# TODO: Implement actual Python script execution
	var success: bool = execute_conversion_command(args)
	return success

func _extraction_completed(success: bool) -> void:
	"""Handle extraction completion"""
	progress_bar.visible = false
	extract_button.disabled = false
	
	if success:
		_emit_status("VP extraction completed successfully")
		
		# Auto-import extracted assets if enabled
		if auto_import_check.button_pressed:
			_trigger_auto_import()
	else:
		_emit_status("VP extraction failed")
	
	_emit_conversion_completed("VP_EXTRACTION", success)

func _trigger_auto_import() -> void:
	"""Trigger auto-import of extracted assets"""
	_emit_status("Auto-importing extracted assets...")
	# This will be handled by Godot's import system automatically
