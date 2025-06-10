@tool
extends EditorImportPlugin

## VP Archive Import Plugin
## Enables direct import of WCS .vp files with automatic extraction and organization

const VPExtractor = preload("res://addons/wcs_converter/conversion/vp_extractor.gd")

func _get_importer_name() -> String:
	return "wcs.vp_archive"

func _get_visible_name() -> String:
	return "WCS VP Archive"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["vp"])

func _get_save_extension() -> String:
	return "tres"

func _get_resource_type() -> String:
	return "Resource"

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 0

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "extract_to_subdir",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "organize_by_type",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "generate_manifest",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "auto_import_assets",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		}
	]

func _get_preset_count() -> int:
	return 1

func _get_preset_name(preset_index: int) -> String:
	return "Default"

func _import(source_file: String, save_path: String, options: Dictionary, 
			 platform_variants: Array[String], gen_files: Array[String]) -> Error:
	
	print("Importing VP archive: ", source_file)
	
	# Initialize VP extractor
	var extractor: VPExtractor = VPExtractor.new()
	
	# Determine output directory
	var source_path: String = source_file.get_base_dir()
	var vp_name: String = source_file.get_file().get_basename()
	var output_dir: String
	
	if options.get("extract_to_subdir", true):
		output_dir = source_path + "/" + vp_name + "_extracted"
	else:
		output_dir = source_path + "/extracted_assets"
	
	# Progress tracking
	var progress_dialog: AcceptDialog = _create_progress_dialog()
	progress_dialog.popup_centered()
	
	# Extract VP archive
	var extraction_result: Dictionary = extractor.extract_vp_archive(
		source_file, 
		output_dir, 
		options
	)
	
	progress_dialog.queue_free()
	
	if not extraction_result.get("success", false):
		push_error("Failed to extract VP archive: " + extraction_result.get("error", "Unknown error"))
		return ERR_COMPILATION_FAILED
	
	# Create import resource with metadata
	var import_resource: VPImportResource = VPImportResource.new()
	import_resource.source_vp_file = source_file
	import_resource.extracted_directory = output_dir
	import_resource.file_count = extraction_result.get("file_count", 0)
	import_resource.extraction_time = extraction_result.get("extraction_time", 0.0)
	import_resource.manifest_data = extraction_result.get("manifest", {})
	
	# Save import resource
	var save_result: Error = ResourceSaver.save(import_resource, save_path + ".tres")
	if save_result != OK:
		push_error("Failed to save VP import resource")
		return save_result
	
	# Auto-import extracted assets if requested
	if options.get("auto_import_assets", true):
		_auto_import_extracted_assets(output_dir)
	
	# Refresh filesystem to show extracted files
	EditorInterface.get_resource_filesystem().scan()
	
	print("VP archive imported successfully: ", extraction_result.get("file_count", 0), " files extracted")
	return OK

func _create_progress_dialog() -> AcceptDialog:
	"""Create progress dialog for VP extraction"""
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Extracting VP Archive"
	dialog.set_flag(Window.FLAG_RESIZE_DISABLED, true)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label: Label = Label.new()
	label.text = "Extracting WCS VP archive files...\nThis may take a moment."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(300, 20)
	progress_bar.value = 50  # Indeterminate progress
	vbox.add_child(progress_bar)
	
	EditorInterface.get_base_control().add_child(dialog)
	return dialog

func _auto_import_extracted_assets(output_dir: String) -> void:
	"""Automatically trigger import for common asset types in extracted directory"""
	var dir: DirAccess = DirAccess.open(output_dir)
	if dir == null:
		return
	
	# Find POF models for auto-import
	var pof_files: Array[String] = _find_files_by_extension(output_dir, "pof")
	for pof_file in pof_files:
		# Mark for reimport with POF plugin
		EditorInterface.get_resource_filesystem().update_file(pof_file)
	
	# Find texture files for auto-import
	var texture_extensions: Array[String] = ["pcx", "tga", "dds", "png", "jpg"]
	for ext in texture_extensions:
		var texture_files: Array[String] = _find_files_by_extension(output_dir, ext)
		for texture_file in texture_files:
			EditorInterface.get_resource_filesystem().update_file(texture_file)

func _find_files_by_extension(directory: String, extension: String) -> Array[String]:
	"""Find all files with given extension in directory (recursive)"""
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return files
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recurse into subdirectory
			files.append_array(_find_files_by_extension(full_path, extension))
		elif file_name.get_extension().to_lower() == extension.to_lower():
			files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return files
