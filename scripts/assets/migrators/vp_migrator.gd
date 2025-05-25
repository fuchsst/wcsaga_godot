class_name VPMigrator
extends RefCounted

## VP Archive migration script for converting WCS VP files to Godot project structure.
## Extracts assets from VP archives and converts them to Godot-compatible formats.

signal migration_started(vp_path: String)
signal file_converted(source_file: String, target_file: String)
signal migration_completed(vp_path: String, files_converted: int)
signal migration_error(error_message: String)
signal progress_updated(current: int, total: int, current_file: String)

# Migration configuration
var output_directory: String = "res://migrated_assets/"
var preserve_directory_structure: bool = true
var overwrite_existing: bool = false
var convert_textures: bool = true
var convert_models: bool = true
var convert_audio: bool = true
var create_import_files: bool = true

# File type mappings for conversion
var texture_extensions: PackedStringArray = ["pcx", "tga", "jpg", "jpeg", "png", "dds"]
var model_extensions: PackedStringArray = ["pof"]
var audio_extensions: PackedStringArray = ["wav", "ogg"]
var data_extensions: PackedStringArray = ["tbl", "tbm", "cfg", "txt", "lua"]

# Conversion statistics
var files_processed: int = 0
var files_converted: int = 0
var files_skipped: int = 0
var errors_encountered: int = 0

func migrate_vp_archive(vp_path: String, vp_manager: VPManager = null) -> bool:
	"""Migrate an entire VP archive to Godot project structure."""
	
	if not FileAccess.file_exists(vp_path):
		migration_error.emit("VP file not found: %s" % vp_path)
		return false
	
	# Reset statistics
	files_processed = 0
	files_converted = 0
	files_skipped = 0
	errors_encountered = 0
	
	migration_started.emit(vp_path)
	
	# Load VP archive
	var archive: VPArchive
	if vp_manager != null:
		# Use existing manager if provided
		if not vp_manager.load_vp_archive(vp_path):
			migration_error.emit("Failed to load VP archive: %s" % vp_path)
			return false
		# Find the archive in the manager
		for loaded_archive in vp_manager.loaded_archives:
			if loaded_archive.archive_path == vp_path:
				archive = loaded_archive
				break
	else:
		# Create new archive instance
		archive = VPArchive.new()
		if not archive.load_archive(vp_path):
			migration_error.emit("Failed to load VP archive: %s" % vp_path)
			return false
	
	if archive == null:
		migration_error.emit("Archive not found in manager: %s" % vp_path)
		return false
	
	# Get list of all files in archive
	var file_list: Array[String] = archive.get_file_list()
	var total_files: int = file_list.size()
	
	print("VPMigrator: Starting migration of %d files from %s" % [total_files, vp_path])
	
	# Create output directory
	DirAccess.open("res://").make_dir_recursive(output_directory)
	
	# Process each file
	for i in range(file_list.size()):
		var file_path: String = file_list[i]
		progress_updated.emit(i + 1, total_files, file_path)
		
		if _should_migrate_file(file_path):
			_migrate_single_file(archive, file_path)
		else:
			files_skipped += 1
		
		files_processed += 1
	
	# Cleanup
	if vp_manager == null:
		archive.close_archive()
	
	print("VPMigrator: Migration completed - %d converted, %d skipped, %d errors" % 
		[files_converted, files_skipped, errors_encountered])
	
	migration_completed.emit(vp_path, files_converted)
	return errors_encountered == 0

func migrate_file_selective(vp_manager: VPManager, file_patterns: Array[String]) -> int:
	"""Migrate only files matching specific patterns from all loaded VP archives."""
	
	var converted_count: int = 0
	
	for pattern in file_patterns:
		var matching_files: Array[String] = _find_files_matching_pattern(vp_manager, pattern)
		
		for file_path in matching_files:
			if _migrate_file_from_manager(vp_manager, file_path):
				converted_count += 1
	
	return converted_count

## Private implementation

func _should_migrate_file(file_path: String) -> bool:
	"""Determine if a file should be migrated based on its extension and settings."""
	
	var extension: String = file_path.get_extension().to_lower()
	
	# Check if we should convert this file type
	if extension in texture_extensions:
		return convert_textures
	elif extension in model_extensions:
		return convert_models
	elif extension in audio_extensions:
		return convert_audio
	elif extension in data_extensions:
		return true  # Always convert data files
	
	return false  # Skip unknown file types

func _migrate_single_file(archive: VPArchive, file_path: String) -> bool:
	"""Migrate a single file from the archive."""
	
	var extension: String = file_path.get_extension().to_lower()
	var output_path: String = _get_output_path(file_path)
	
	# Check if file already exists and we shouldn't overwrite
	if not overwrite_existing and FileAccess.file_exists(output_path):
		files_skipped += 1
		return false
	
	# Extract file data
	var file_data: PackedByteArray = archive.extract_file(file_path)
	if file_data.is_empty() and archive.get_file_size(file_path) > 0:
		_log_error("Failed to extract file: %s" % file_path)
		return false
	
	# Convert based on file type
	var success: bool = false
	
	match extension:
		"pcx":
			success = _convert_pcx_to_png(file_data, output_path)
		"tga":
			success = _convert_tga_to_png(file_data, output_path)
		"dds":
			success = _convert_dds_to_png(file_data, output_path)
		"pof":
			success = _convert_pof_to_gltf(file_data, output_path, file_path)
		"tbl", "tbm":
			success = _convert_table_to_resource(file_data, output_path, file_path)
		_:
			# For other files, just copy directly
			success = _copy_file_direct(file_data, output_path)
	
	if success:
		files_converted += 1
		file_converted.emit(file_path, output_path)
		
		# Create Godot import file if needed
		if create_import_files:
			_create_import_file(output_path, extension)
	else:
		_log_error("Failed to convert file: %s" % file_path)
	
	return success

func _get_output_path(source_path: String) -> String:
	"""Generate output path for converted file."""
	
	var base_path: String = output_directory
	
	if preserve_directory_structure:
		# Keep directory structure but clean up the path
		var clean_path: String = source_path.replace("\\", "/")
		if clean_path.begins_with("/"):
			clean_path = clean_path.substr(1)
		base_path = base_path.path_join(clean_path)
	else:
		# Flatten to output directory
		base_path = base_path.path_join(source_path.get_file())
	
	# Convert extension to Godot-compatible format
	var extension: String = source_path.get_extension().to_lower()
	
	match extension:
		"pcx", "tga", "dds":
			base_path = base_path.get_basename() + ".png"
		"pof":
			base_path = base_path.get_basename() + ".gltf"
		"tbl", "tbm":
			base_path = base_path.get_basename() + ".tres"
	
	return base_path

func _convert_pcx_to_png(pcx_data: PackedByteArray, output_path: String) -> bool:
	"""Convert PCX image data to PNG format."""
	# This would implement PCX to PNG conversion
	# For now, just save as raw data and let Godot handle import
	return _copy_file_direct(pcx_data, output_path.get_basename() + ".pcx")

func _convert_tga_to_png(tga_data: PackedByteArray, output_path: String) -> bool:
	"""Convert TGA image data to PNG format."""
	# TGA conversion logic would go here
	# For now, save as TGA and let Godot import handle it
	return _copy_file_direct(tga_data, output_path.get_basename() + ".tga")

func _convert_dds_to_png(dds_data: PackedByteArray, output_path: String) -> bool:
	"""Convert DDS texture to PNG format."""
	# DDS conversion would be implemented here
	# For now, save as DDS for manual conversion
	return _copy_file_direct(dds_data, output_path.get_basename() + ".dds")

func _convert_pof_to_gltf(pof_data: PackedByteArray, output_path: String, source_path: String) -> bool:
	"""Convert POF model to GLTF format."""
	# This would use the POF importer to convert to GLTF
	# For now, save POF file and create a migration note
	var pof_path: String = output_path.get_basename() + ".pof"
	if _copy_file_direct(pof_data, pof_path):
		_create_migration_note(pof_path, "POF model - needs conversion to GLTF")
		return true
	return false

func _convert_table_to_resource(table_data: PackedByteArray, output_path: String, source_path: String) -> bool:
	"""Convert table file to Godot resource format."""
	# Parse table file and convert to appropriate resource
	var table_content: String = table_data.get_string_from_utf8()
	var parser: TableParser = TableParser.new()
	var parsed_data: Dictionary = parser.parse_table_file(table_content, source_path.get_file().get_basename())
	
	if parsed_data.is_empty():
		return false
	
	# Determine resource type based on table name
	var resource: Resource = _create_resource_from_table(parsed_data, source_path)
	
	if resource != null:
		var save_result: int = ResourceSaver.save(resource, output_path)
		return save_result == OK
	
	return false

func _copy_file_direct(file_data: PackedByteArray, output_path: String) -> bool:
	"""Copy file data directly to output path."""
	
	# Ensure output directory exists
	var output_dir: String = output_path.get_base_dir()
	if not output_dir.is_empty():
		DirAccess.open("res://").make_dir_recursive(output_dir)
	
	var output_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if output_file == null:
		return false
	
	output_file.store_buffer(file_data)
	output_file.close()
	return true

func _create_import_file(asset_path: String, original_extension: String) -> void:
	"""Create a .import file for Godot to properly handle the asset."""
	
	var import_path: String = asset_path + ".import"
	var import_config: ConfigFile = ConfigFile.new()
	
	# Set import settings based on file type
	match original_extension:
		"png", "jpg", "jpeg", "tga":
			import_config.set_value("remap", "importer", "texture")
			import_config.set_value("remap", "type", "CompressedTexture2D")
		"gltf":
			import_config.set_value("remap", "importer", "scene")
			import_config.set_value("remap", "type", "PackedScene")
		"wav", "ogg":
			import_config.set_value("remap", "importer", "wav")
			import_config.set_value("remap", "type", "AudioStreamWAV")
	
	import_config.save(import_path)

func _create_migration_note(file_path: String, note: String) -> void:
	"""Create a text file with migration notes for manual conversion."""
	
	var note_path: String = file_path + ".migration_note.txt"
	var note_file: FileAccess = FileAccess.open(note_path, FileAccess.WRITE)
	
	if note_file != null:
		note_file.store_string("Migration Note for: %s\n\n%s\n\nSource: WCS VP Archive\nGenerated: %s" % 
			[file_path.get_file(), note, Time.get_datetime_string_from_system()])
		note_file.close()

func _create_resource_from_table(table_data: Dictionary, source_path: String) -> Resource:
	"""Create appropriate Godot resource from parsed table data."""
	
	var table_name: String = source_path.get_file().get_basename().to_lower()
	
	# Determine resource type from table name
	if table_name.contains("ship"):
		return _create_ship_resources_from_table(table_data)
	elif table_name.contains("weapon"):
		return _create_weapon_resources_from_table(table_data)
	else:
		# Generic resource for other table types
		var generic_resource: Resource = Resource.new()
		generic_resource.set_meta("table_data", table_data)
		return generic_resource

func _create_ship_resources_from_table(table_data: Dictionary) -> Resource:
	"""Create ShipData resources from ships table."""
	# This would create multiple ShipData resources
	# For now, return the first ship as an example
	var entries: Array = table_data.get("entries", [])
	
	if not entries.is_empty():
		var first_entry: Dictionary = entries[0]
		var ship_data: ShipData = ShipData.new()
		ship_data.ship_name = first_entry.get("name", "Unknown Ship")
		# ... map other properties
		return ship_data
	
	return null

func _create_weapon_resources_from_table(table_data: Dictionary) -> Resource:
	"""Create WeaponData resources from weapons table."""
	# Similar to ship resources
	var entries: Array = table_data.get("entries", [])
	
	if not entries.is_empty():
		var first_entry: Dictionary = entries[0]
		var weapon_data: WeaponData = WeaponData.new()
		weapon_data.weapon_name = first_entry.get("name", "Unknown Weapon")
		# ... map other properties
		return weapon_data
	
	return null

func _find_files_matching_pattern(vp_manager: VPManager, pattern: String) -> Array[String]:
	"""Find files matching a wildcard pattern."""
	
	var all_files: Array[String] = vp_manager.get_file_list()
	var matching_files: Array[String] = []
	
	# Simple wildcard matching (could be improved with regex)
	for file_path in all_files:
		if pattern == "*" or file_path.match(pattern):
			matching_files.append(file_path)
	
	return matching_files

func _migrate_file_from_manager(vp_manager: VPManager, file_path: String) -> bool:
	"""Migrate a single file using VPManager."""
	
	if not vp_manager.has_file(file_path):
		return false
	
	var file_data: PackedByteArray = vp_manager.get_file_data(file_path)
	var output_path: String = _get_output_path(file_path)
	
	return _copy_file_direct(file_data, output_path)

func _log_error(message: String) -> void:
	"""Log an error and increment error counter."""
	
	errors_encountered += 1
	push_error("VPMigrator: " + message)
	migration_error.emit(message)

## Public configuration methods

func set_output_directory(path: String) -> void:
	"""Set the output directory for migrated assets."""
	output_directory = path

func set_conversion_settings(textures: bool, models: bool, audio: bool, data: bool = true) -> void:
	"""Configure which file types to convert."""
	convert_textures = textures
	convert_models = models
	convert_audio = audio
	# Data files are always converted

func get_migration_statistics() -> Dictionary:
	"""Get migration statistics."""
	return {
		"files_processed": files_processed,
		"files_converted": files_converted,
		"files_skipped": files_skipped,
		"errors_encountered": errors_encountered,
		"success_rate": float(files_converted) / max(1, files_processed) * 100.0
	}