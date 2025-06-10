@tool
extends EditorImportPlugin

## VP Archive Import Plugin
## Implements DM-001 VP Archive Extraction and DM-002 VP to Godot Resource Conversion

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

func _get_preset_count() -> int:
	return 1

func _get_preset_name(preset_index: int) -> String:
	return "Default"

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "extract_to_assets",
			"default_value": true,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Extract VP contents to assets/ directory"
		},
		{
			"name": "auto_import_extracted",
			"default_value": true,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Automatically import extracted assets"
		},
		{
			"name": "organize_by_type",
			"default_value": true,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Organize extracted files by asset type"
		}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> int:
	print("Importing VP archive: %s" % source_file)
	
	# Call Python VP extractor
	var python_script: String = get_script().get_path().get_base_dir() + "/vp_extractor.py"
	var output_dir: String = "res://assets/vp_extracted/" + source_file.get_file().get_basename()
	
	var args: PackedStringArray = PackedStringArray([
		python_script,
		"--extract",
		source_file,
		"--output", output_dir
	])
	
	if options.get("organize_by_type", true):
		args.append("--organize")
	
	# Execute Python extractor
	var python_exe: String = "/mnt/d/projects/wcsaga_godot_converter/target/venv/Scripts/python.exe"
	var result: int = OS.execute(python_exe, args, [], true)
	
	if result != 0:
		print_rich("[color=red]VP extraction failed: %s[/color]" % result)
		return FAILED
	
	# Create a simple resource to represent the extracted VP
	var vp_resource: Resource = Resource.new()
	vp_resource.set_meta("source_file", source_file)
	vp_resource.set_meta("extract_path", output_dir)
	vp_resource.set_meta("extraction_time", Time.get_unix_time_from_system())
	
	var save_result: Error = ResourceSaver.save(vp_resource, "%s.%s" % [save_path, _get_save_extension()])
	
	if save_result == OK:
		print("VP archive imported successfully: %s" % source_file)
		
		# Auto-import extracted assets if enabled
		if options.get("auto_import_extracted", true):
			_auto_import_extracted_assets(output_dir)
		
		return OK
	else:
		print_rich("[color=red]Failed to save VP resource[/color]")
		return FAILED

func _auto_import_extracted_assets(extract_dir: String) -> void:
	## Trigger re-import of extracted assets
	print("Auto-importing extracted assets from: %s" % extract_dir)
	# This will be handled by Godot's import system automatically
	# when it detects new files in the project
