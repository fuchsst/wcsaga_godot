@tool
extends WizardStepBase
class_name WizardStepConversion

## Step 4: Convert Assets
## Selects which asset types to convert and runs the conversion process

# UI References
@onready var asset_types_list: ItemList = $ConversionContainer/OptionsPanel/AssetTypesList
@onready var convert_selected_button: Button = $ConversionContainer/OptionsPanel/ConversionButtons/ConvertSelectedButton
@onready var convert_all_button: Button = $ConversionContainer/OptionsPanel/ConversionButtons/ConvertAllButton
@onready var conversion_log: TextEdit = $ConversionContainer/LogPanel/ConversionLog
@onready var conversion_progress: ProgressBar = $ConversionContainer/LogPanel/ConversionProgress

# State
var available_asset_types: Array[String] = []
var conversion_in_progress: bool = false

func _setup_step() -> void:
	step_number = 4
	step_title = "Convert Assets"
	step_description = "Select which asset types to convert and run the conversion process."

func _connect_step_signals() -> void:
	convert_selected_button.pressed.connect(_on_convert_selected_pressed)
	convert_all_button.pressed.connect(_on_convert_all_pressed)
	asset_types_list.item_selected.connect(_on_asset_type_selected)

func _check_step_validity() -> bool:
	return wizard_data.has("asset_mappings") and wizard_data.asset_mappings.size() > 0

func _on_step_activated() -> void:
	_populate_asset_types_list()
	_update_conversion_buttons()

func _on_wizard_data_updated() -> void:
	if wizard_data.has("asset_mappings"):
		_populate_asset_types_list()

func _populate_asset_types_list() -> void:
	"""Populate asset types list from current mapping."""
	asset_types_list.clear()
	available_asset_types.clear()
	
	if not wizard_data.has("asset_mappings"):
		return
	
	var types_set = {}
	for mapping in wizard_data.asset_mappings:
		var asset_type = mapping.get("type", "Unknown")
		types_set[asset_type] = true
	
	available_asset_types.assign(types_set.keys())
	available_asset_types.sort()
	
	for asset_type in available_asset_types:
		var count = _count_assets_by_type(asset_type)
		var display_text = "%s (%d assets)" % [asset_type, count]
		asset_types_list.add_item(display_text)
	
	# Select all by default
	for i in range(asset_types_list.item_count):
		asset_types_list.select(i, false)

func _count_assets_by_type(asset_type: String) -> int:
	"""Count assets of specified type."""
	var count = 0
	for mapping in wizard_data.asset_mappings:
		if mapping.get("type", "") == asset_type:
			count += 1
	return count

func _update_conversion_buttons() -> void:
	"""Update conversion button states."""
	var has_selection = _get_selected_asset_types().size() > 0
	var has_assets = available_asset_types.size() > 0
	
	convert_selected_button.disabled = not has_selection or conversion_in_progress
	convert_all_button.disabled = not has_assets or conversion_in_progress

func _get_selected_asset_types() -> Array[String]:
	"""Get list of selected asset types."""
	var selected_types: Array[String] = []
	
	for i in range(asset_types_list.item_count):
		if asset_types_list.is_selected(i):
			selected_types.append(available_asset_types[i])
	
	return selected_types

func _run_conversion(asset_types: Array[String]) -> void:
	"""Run conversion for specified asset types."""
	if conversion_in_progress:
		_log_message("Conversion already in progress")
		return
	
	if not wizard_data.has("asset_mappings"):
		_log_message("No asset mappings available")
		return
	
	conversion_in_progress = true
	conversion_progress.visible = true
	conversion_progress.value = 0
	
	_log_message("Starting conversion for %d asset types..." % asset_types.size())
	_update_conversion_buttons()
	
	var python_path = ProjectSettings.globalize_path("res://venv/Scripts/python.exe")
	var converter_script = ProjectSettings.globalize_path("res://addons/wcs_data_migration/tools/table_conversion_cli.py")
	
	var total_types = asset_types.size()
	var successful_types = 0
	
	for i in range(total_types):
		var asset_type = asset_types[i]
		_log_message("Converting %s assets..." % asset_type)
		
		var result = await _convert_asset_type(asset_type, python_path, converter_script)
		if result:
			successful_types += 1
			_log_message("✓ %s conversion completed" % asset_type)
		else:
			_log_message("✗ %s conversion failed" % asset_type)
		
		conversion_progress.value = float(i + 1) / total_types * 100
		await get_tree().process_frame
	
	conversion_in_progress = false
	conversion_progress.visible = false
	_update_conversion_buttons()
	
	_log_message("\nConversion completed: %d/%d asset types successful" % [successful_types, total_types])
	
	if successful_types > 0:
		complete_step()
		_emit_status("Asset conversion completed successfully")
	else:
		_emit_status("Asset conversion failed")

func _convert_asset_type(asset_type: String, python_path: String, converter_script: String) -> bool:
	"""Convert assets of specified type."""
	var args = [
		converter_script,
		"--type", asset_type,
		"--source", wizard_data.extraction_directory,
		"--target", wizard_data.target_directory
	]
	
	var output = []
	var result = OS.execute(python_path, args, output)
	
	# Log output
	for line in output:
		_log_message(line)
	
	return result == 0

func _log_message(message: String) -> void:
	"""Add message to conversion log."""
	var timestamp = Time.get_datetime_string_from_system()
	var log_line = "[%s] %s\n" % [timestamp, message]
	conversion_log.text += log_line
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	conversion_log.scroll_vertical = conversion_log.get_line_count()

func _clear_log() -> void:
	"""Clear conversion log."""
	conversion_log.text = ""

func _on_convert_selected_pressed() -> void:
	var selected_types = _get_selected_asset_types()
	if selected_types.size() == 0:
		_log_message("No asset types selected")
		return
	
	_run_conversion(selected_types)

func _on_convert_all_pressed() -> void:
	if available_asset_types.size() == 0:
		_log_message("No asset types available")
		return
	
	_run_conversion(available_asset_types)

func _on_asset_type_selected(_index: int) -> void:
	_update_conversion_buttons()
