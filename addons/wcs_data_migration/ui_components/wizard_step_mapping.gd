@tool
extends WizardStepBase
class_name WizardStepMapping

## Step 3: Create Asset Mapping
## Analyzes extracted assets and creates mapping to target Godot resource structure

# UI References
@onready var create_mapping_button: Button = $MappingContainer/TableCard/TableMargin/LeftPanel/MappingControls/CreateMappingButton
@onready var refresh_mapping_button: Button = $MappingContainer/TableCard/TableMargin/LeftPanel/MappingControls/RefreshMappingButton
@onready var mapping_filter: LineEdit = $MappingContainer/TableCard/TableMargin/LeftPanel/MappingControls/FilterHBox/MappingFilter
@onready var asset_table: Tree = $MappingContainer/TableCard/TableMargin/LeftPanel/HBoxContainer/AssetTable
@onready var total_label: Label = $MappingContainer/TableCard/TableMargin/LeftPanel/TableStats/TotalLabel
@onready var duplicates_label: Label = $MappingContainer/TableCard/TableMargin/LeftPanel/TableStats/DuplicatesLabel
@onready var conflicts_label: Label = $MappingContainer/TableCard/TableMargin/LeftPanel/TableStats/ConflictsLabel
@onready var asset_name_label: Label = $MappingContainer/TableCard/TableMargin/LeftPanel/HBoxContainer/DetailsCard/DetailsMargin/RightPanel/AssetDetails/DetailsVBox/AssetNameLabel
@onready var details_grid: GridContainer = $MappingContainer/TableCard/TableMargin/LeftPanel/HBoxContainer/DetailsCard/DetailsMargin/RightPanel/AssetDetails/DetailsVBox/DetailsGrid
@onready var dependencies_tree: Tree = $MappingContainer/TableCard/TableMargin/LeftPanel/HBoxContainer/DetailsCard/DetailsMargin/RightPanel/AssetDetails/DetailsVBox/DependenciesTree

# State
var asset_mappings: Array[Dictionary] = []
var filtered_mappings: Array[Dictionary] = []
var mapping_created: bool = false
var _mapping_thread: Thread

func _exit_tree() -> void:
	if _mapping_thread and _mapping_thread.is_started():
		_mapping_thread.wait_to_finish()

func _setup_step() -> void:
	step_number = 3
	step_title = "Create Asset Mapping"
	step_description = "Analyze extracted assets and create mapping to target Godot resource structure."
	_setup_table_columns()

func _connect_step_signals() -> void:
	create_mapping_button.pressed.connect(_on_create_mapping_pressed)
	refresh_mapping_button.pressed.connect(_on_refresh_mapping_pressed)
	mapping_filter.text_changed.connect(_on_mapping_filter_changed)
	asset_table.item_selected.connect(_on_asset_table_item_selected)

func _check_step_validity() -> bool:
	return mapping_created and asset_mappings.size() > 0

func _on_step_activated() -> void:
	# Ensure the latest data is loaded when the step becomes active
	_on_wizard_data_updated()
	refresh_mapping_button.disabled = not mapping_created
	
	# Automatically load mapping if it already exists from a previous session
	if not mapping_created and wizard_data.has("target_directory"):
		var target_directory: String = wizard_data.target_directory
		var output_file: String = target_directory.path_join("asset_mapping.json")
		if FileAccess.file_exists(output_file):
			wizard_data.asset_mapping_file = output_file
			_load_asset_mapping()
			mapping_created = true
			_validate_step()
			_emit_status("Loaded existing asset mapping.")

func _on_wizard_data_updated() -> void:
	if wizard_data.has("asset_mappings"):
		asset_mappings.assign(wizard_data.asset_mappings)
		_update_asset_table()

func _setup_table_columns() -> void:
	"""Configure the asset mapping table columns."""
	asset_table.set_column_title(0, "Source File")
	asset_table.set_column_title(1, "Target File") 
	asset_table.set_column_title(2, "Format")
	asset_table.set_column_title(3, "Status")
	asset_table.set_column_title(4, "Duplicate")
	asset_table.set_column_title(5, "Type")
	
	asset_table.set_column_expand(0, true)
	asset_table.set_column_expand(1, true)
	asset_table.set_column_expand(2, false)
	asset_table.set_column_expand(3, false)
	asset_table.set_column_expand(4, false)
	asset_table.set_column_expand(5, false)

func _create_asset_mapping() -> void:
	"""Create asset mapping using Python tools in a background thread."""
	if not wizard_data.has("extraction_directory"):
		_emit_status("Extraction directory not configured. Please complete the 'Paths' step.")
		return

	if not wizard_data.has("target_directory"):
		_emit_status("Target directory not configured. Please complete the 'Paths' step.")
		return

	_emit_status("Creating asset mapping... This may take a moment.")
	create_mapping_button.disabled = true
	refresh_mapping_button.disabled = true

	var python_path: String = wizard_data.get("python_path", "python")
	if python_path.is_empty():
		python_path = "python"

	var extraction_directory: String = wizard_data["extraction_directory"]
	var output_file: String = extraction_directory.path_join("asset_mapping.json")

	var module_path = "tools.asset_mapper"
	var args = ["-m", module_path, "--source", extraction_directory, "--output", output_file, "-v"]
	
	var addon_dir = ProjectSettings.globalize_path("res://addons/wcs_data_migration/")

	_mapping_thread = Thread.new()
	_mapping_thread.start(func():
		var output := []
		# Execute in a thread with the correct working directory to find the module.
		var exit_code := OS.execute(python_path, args, output, true, addon_dir)
		var result := { "exit_code": exit_code, "output": output, "output_file": output_file }
		call_deferred("_on_mapping_process_completed", result)
	)

func _on_mapping_process_completed(result: Dictionary) -> void:
	"""Handle the result from the background mapping process."""
	create_mapping_button.disabled = false
	refresh_mapping_button.disabled = false

	var exit_code = result.get("exit_code", -1)
	var output_lines: Array = result.get("output", [])

	if exit_code == 0:
		wizard_data.asset_mapping_file = result.get("output_file")
		_load_asset_mapping()
		mapping_created = true
		_validate_step()
		_emit_status("Asset mapping created successfully.")
	else:
		_emit_status("Failed to create asset mapping. See console for details.")
		printerr("Asset mapping script failed with exit code: ", exit_code)
		for line in output_lines:
			printerr("  ", line) # Indent for readability
	
	if _mapping_thread and _mapping_thread.is_started():
		_mapping_thread.wait_to_finish()
		_mapping_thread = null


func _load_asset_mapping() -> void:
	"""Load asset mapping from the generated JSON file."""
	if not wizard_data.has("asset_mapping_file"):
		_emit_status("Asset mapping file path not found in wizard data.")
		return

	var mapping_file: String = wizard_data.asset_mapping_file
	if not FileAccess.file_exists(mapping_file):
		_emit_status("Asset mapping file not found at: %s" % mapping_file)
		return

	var file = FileAccess.open(mapping_file, FileAccess.READ)
	if not file:
		_emit_status("Failed to open asset mapping file.")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		_emit_status("Failed to parse asset mapping JSON: %s" % json.get_error_message())
		printerr("JSON Parse Error: %s at line %d" % [json.get_error_message(), json.get_error_line()])
		return

	var mapping_data = json.data
	if not mapping_data is Dictionary or not mapping_data.has("entity_mappings"):
		_emit_status("Invalid data structure in asset mapping file.")
		return

	asset_mappings.clear()
	var entity_mappings: Dictionary = mapping_data.get("entity_mappings", {})

	for entity_name in entity_mappings:
		var entity_data: Dictionary = entity_mappings[entity_name]
		var entity_type = entity_data.get("entity_type", "unknown")
		var metadata = entity_data.get("metadata", {})
		var related_assets = entity_data.get("related_assets", [])

		var all_assets: Array[Dictionary] = []
		var primary_asset = entity_data.get("primary_asset")
		if primary_asset is Dictionary:
			all_assets.append(primary_asset)
		if related_assets is Array:
			all_assets.append_array(related_assets)

		for asset in all_assets:
			if not asset is Dictionary: continue
			
			var is_duplicate = metadata.get("is_duplicate", false)
			var mapping = {
				"entity_name": entity_name,
				"source_file": asset.get("source_path", ""),
				"target_file": asset.get("target_path", ""),
				"asset_type": asset.get("asset_type", ""),
				"status": "Duplicate" if is_duplicate else "Ready",
				"entity_type": entity_type,
				"duplicate": is_duplicate,
				"relationship_type": asset.get("relationship_type", ""),
				"related_assets": related_assets
			}
			asset_mappings.append(mapping)

	wizard_data.asset_mappings = asset_mappings.duplicate()
	_filter_mappings(mapping_filter.text)
	_emit_status("Loaded %d asset mappings." % asset_mappings.size())
	var stats = mapping_data.get("statistics", {})
	if stats:
		duplicates_label.text = "Duplicates: %d" % stats.get("duplicates_found", 0)


func _update_asset_table() -> void:
	"""Update asset table display with current mappings."""
	asset_table.clear()
	var root = asset_table.create_item()
	
	var total = 0
	var duplicates = 0
	
	for i in range(filtered_mappings.size()):
		var mapping = filtered_mappings[i]
		var item = asset_table.create_item(root)
		item.set_text(0, mapping.source_file)
		item.set_text(1, mapping.target_file)
		item.set_text(2, mapping.asset_type)
		item.set_text(3, mapping.status)
		item.set_text(4, "Yes" if mapping.duplicate else "No")
		item.set_text(5, mapping.entity_type)
		
		item.set_metadata(0, i)

		if mapping.status == "Duplicate":
			item.set_custom_color(3, Color.ORANGE)
			duplicates += 1
		else:
			item.set_custom_color(3, Color.GREEN)
		
		total += 1
	
	total_label.text = "Total: %d" % total
	# Duplicates count is now set from the JSON metadata in _load_asset_mapping


func _filter_mappings(filter_text: String) -> void:
	"""Filter asset mappings by search text."""
	filtered_mappings.clear()
	
	if filter_text.is_empty():
		filtered_mappings.assign(asset_mappings)
	else:
		var search_lower = filter_text.to_lower()
		for mapping in asset_mappings:
			if mapping.source_file.to_lower().contains(search_lower) or \
			   mapping.target_file.to_lower().contains(search_lower) or \
			   mapping.entity_name.to_lower().contains(search_lower):
				filtered_mappings.append(mapping)
	
	_update_asset_table()


func _show_asset_details(mapping: Dictionary) -> void:
	"""Show details for selected asset mapping."""
	asset_name_label.text = mapping.source_file
	
	for child in details_grid.get_children():
		child.queue_free()
	
	_add_detail_row("Entity:", mapping.entity_name)
	_add_detail_row("Target File:", mapping.target_file)
	_add_detail_row("Entity Type:", mapping.entity_type)
	_add_detail_row("Asset Type:", mapping.asset_type)
	_add_detail_row("Status:", mapping.status)
	_add_detail_row("Duplicate:", "Yes" if mapping.duplicate else "No")
	_add_detail_row("Relationship:", mapping.relationship_type)
	
	dependencies_tree.clear()
	var root = dependencies_tree.create_item()
	root.set_text(0, "Related Assets for '%s'" % mapping.entity_name)

	var related_assets = mapping.get("related_assets", [])
	if related_assets.size() > 0:
		for asset_rel in related_assets:
			if not asset_rel is Dictionary: continue
			var item = dependencies_tree.create_item(root)
			var text = "%s (%s)" % [asset_rel.get("source_path", "N/A"), asset_rel.get("relationship_type", "N/A")]
			item.set_text(0, text)


func _add_detail_row(label_text: String, value_text: String) -> void:
	var label = Label.new()
	label.text = label_text
	label.theme_type_variation = "LabelSmall"
	details_grid.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_grid.add_child(value)


func _on_create_mapping_pressed() -> void:
	_create_asset_mapping()


func _on_refresh_mapping_pressed() -> void:
	if mapping_created:
		_load_asset_mapping()
		_emit_status("Asset mapping refreshed.")


func _on_mapping_filter_changed(text: String) -> void:
	_filter_mappings(text)


func _on_asset_table_item_selected() -> void:
	var selected = asset_table.get_selected()
	if selected:
		var index = selected.get_metadata(0)
		if index != null and index >= 0 and index < filtered_mappings.size():
			_show_asset_details(filtered_mappings[index])
