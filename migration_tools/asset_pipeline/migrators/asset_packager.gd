class_name AssetPackager
extends RefCounted

## Asset packaging tool for organizing converted WCS assets into Godot-friendly structure
## Creates proper directory hierarchies, import configurations, and asset collections

signal packaging_progress(current: int, total: int)
signal packaging_complete(success: bool, output_directory: String)
signal packaging_error(error: String)

# Packaging settings
@export var output_directory: String = "res://migrated_assets/"
@export var create_asset_collections: bool = true
@export var generate_import_presets: bool = true
@export var preserve_vp_structure: bool = false
@export var create_debug_manifests: bool = true
@export var compress_textures: bool = true
@export var optimize_models: bool = true

# Directory structure
const ASSET_STRUCTURE: Dictionary = {
	"tables": "data/",
	"ships": "ships/",
	"weapons": "weapons/",
	"missions": "missions/", 
	"campaigns": "campaigns/",
	"models": "models/",
	"textures": "textures/",
	"audio": "audio/",
	"effects": "effects/",
	"ui": "interface/",
	"scripts": "scripts/"
}

# File type mappings
const FILE_TYPE_MAPPING: Dictionary = {
	"tres": "tables",
	"tscn": "models",
	"png": "textures",
	"jpg": "textures",
	"dds": "textures",
	"wav": "audio",
	"ogg": "audio",
	"fs2": "missions",
	"fc2": "campaigns",
	"pof": "models",
	"ani": "effects"
}

# Packaging statistics
var packaging_stats: Dictionary = {}

func _init() -> void:
	packaging_stats = {
		"total_files": 0,
		"organized_files": 0,
		"collections_created": 0,
		"import_presets_created": 0,
		"start_time": 0.0,
		"end_time": 0.0
	}

## Public API

func package_migrated_assets(source_directory: String) -> bool:
	"""Package all migrated assets from source directory into organized structure."""
	
	if not DirAccess.dir_exists_absolute(source_directory):
		_emit_error("Source directory does not exist: %s" % source_directory)
		return false
	
	packaging_stats.start_time = Time.get_time_dict_from_system()["unix"]
	
	print("AssetPackager: Starting packaging from %s to %s" % [source_directory, output_directory])
	
	# Create output directory structure
	if not _create_directory_structure():
		return false
	
	# Find all assets to package
	var asset_files: Array[String] = _find_all_assets(source_directory)
	packaging_stats.total_files = asset_files.size()
	
	if asset_files.is_empty():
		_emit_error("No assets found to package")
		return false
	
	print("AssetPackager: Found %d assets to package" % asset_files.size())
	
	# Organize assets by type
	var organized_assets: Dictionary = _organize_assets_by_type(asset_files)
	
	# Package each asset type
	var success: bool = true
	var current_file: int = 0
	
	for asset_type in organized_assets.keys():
		var files: Array[String] = organized_assets[asset_type]
		
		print("AssetPackager: Packaging %d %s assets" % [files.size(), asset_type])
		
		for file_path in files:
			packaging_progress.emit(current_file + 1, packaging_stats.total_files)
			
			if not _package_asset_file(file_path, asset_type):
				success = false
				print("AssetPackager: Warning - Failed to package %s" % file_path)
			else:
				packaging_stats.organized_files += 1
			
			current_file += 1
	
	# Create asset collections
	if create_asset_collections:
		_create_asset_collections(organized_assets)
	
	# Generate import presets
	if generate_import_presets:
		_generate_import_presets()
	
	# Create debug manifests
	if create_debug_manifests:
		_create_debug_manifests(organized_assets)
	
	packaging_stats.end_time = Time.get_time_dict_from_system()["unix"]
	
	_print_packaging_summary()
	packaging_complete.emit(success, output_directory)
	
	return success

func package_specific_assets(asset_paths: Array[String], asset_type: String) -> bool:
	"""Package specific assets of a given type."""
	
	if asset_paths.is_empty():
		_emit_error("No asset paths provided")
		return false
	
	if not ASSET_STRUCTURE.has(asset_type):
		_emit_error("Unknown asset type: %s" % asset_type)
		return false
	
	print("AssetPackager: Packaging %d %s assets" % [asset_paths.size(), asset_type])
	
	var success: bool = true
	
	for i in range(asset_paths.size()):
		var asset_path: String = asset_paths[i]
		packaging_progress.emit(i + 1, asset_paths.size())
		
		if not _package_asset_file(asset_path, asset_type):
			success = false
			print("AssetPackager: Warning - Failed to package %s" % asset_path)
		else:
			packaging_stats.organized_files += 1
	
	return success

func get_packaging_stats() -> Dictionary:
	"""Get detailed packaging statistics."""
	return packaging_stats.duplicate()

## Private implementation

func _create_directory_structure() -> bool:
	"""Create the organized directory structure."""
	
	var dir: DirAccess = DirAccess.open("res://")
	if not dir:
		_emit_error("Cannot access resource directory")
		return false
	
	# Create main output directory
	if not dir.dir_exists(output_directory):
		dir.make_dir_recursive(output_directory)
	
	# Create subdirectories for each asset type
	for asset_type in ASSET_STRUCTURE.keys():
		var subdirectory: String = output_directory + ASSET_STRUCTURE[asset_type]
		if not dir.dir_exists(subdirectory):
			dir.make_dir_recursive(subdirectory)
			print("AssetPackager: Created directory %s" % subdirectory)
	
	return true

func _find_all_assets(source_directory: String) -> Array[String]:
	"""Find all asset files in source directory."""
	var asset_files: Array[String] = []
	
	var dir: DirAccess = DirAccess.open(source_directory)
	if not dir:
		_emit_error("Cannot access source directory: %s" % source_directory)
		return asset_files
	
	_find_assets_recursive(dir, source_directory, asset_files)
	
	return asset_files

func _find_assets_recursive(dir: DirAccess, current_path: String, asset_files: Array[String]) -> void:
	"""Recursively find assets in directory."""
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = current_path + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recurse into subdirectory
			var sub_dir: DirAccess = DirAccess.open(full_path)
			if sub_dir:
				_find_assets_recursive(sub_dir, full_path, asset_files)
		else:
			# Check if it's an asset file we care about
			var extension: String = file_name.get_extension().to_lower()
			if FILE_TYPE_MAPPING.has(extension):
				asset_files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _organize_assets_by_type(asset_files: Array[String]) -> Dictionary:
	"""Organize assets by type."""
	var organized: Dictionary = {}
	
	# Initialize categories
	for asset_type in ASSET_STRUCTURE.keys():
		organized[asset_type] = []
	
	# Categorize files
	for file_path in asset_files:
		var extension: String = file_path.get_extension().to_lower()
		var asset_type: String = FILE_TYPE_MAPPING.get(extension, "")
		
		if not asset_type.is_empty() and organized.has(asset_type):
			organized[asset_type].append(file_path)
		else:
			# Try to categorize by content or path
			asset_type = _determine_asset_type_by_content(file_path)
			if organized.has(asset_type):
				organized[asset_type].append(file_path)
	
	return organized

func _determine_asset_type_by_content(file_path: String) -> String:
	"""Determine asset type by analyzing file content or path."""
	
	var filename: String = file_path.get_file().to_lower()
	var path_lower: String = file_path.to_lower()
	
	# Check path for hints
	if "ship" in path_lower:
		return "ships"
	elif "weapon" in path_lower:
		return "weapons"
	elif "mission" in path_lower:
		return "missions"
	elif "campaign" in path_lower:
		return "campaigns"
	elif "model" in path_lower:
		return "models"
	elif "texture" in path_lower or "map" in path_lower:
		return "textures"
	elif "sound" in path_lower or "music" in path_lower:
		return "audio"
	elif "effect" in path_lower:
		return "effects"
	elif "interface" in path_lower or "ui" in path_lower:
		return "ui"
	
	# Check filename for hints
	if filename.begins_with("ship") or filename.begins_with("gvf") or filename.begins_with("gtf"):
		return "ships"
	elif filename.begins_with("weapon"):
		return "weapons"
	elif filename.ends_with("_data.tres"):
		return "tables"
	
	# Default fallback
	return "tables"

func _package_asset_file(source_path: String, asset_type: String) -> bool:
	"""Package a single asset file."""
	
	if not ASSET_STRUCTURE.has(asset_type):
		_emit_error("Unknown asset type: %s" % asset_type)
		return false
	
	var filename: String = source_path.get_file()
	var target_directory: String = output_directory + ASSET_STRUCTURE[asset_type]
	var target_path: String = target_directory + filename
	
	# Create subdirectories if preserving VP structure
	if preserve_vp_structure:
		var relative_path: String = _get_relative_vp_path(source_path)
		if not relative_path.is_empty():
			target_directory = target_directory + relative_path.get_base_dir() + "/"
			target_path = target_directory + filename
			
			var dir: DirAccess = DirAccess.open("res://")
			if dir and not dir.dir_exists(target_directory):
				dir.make_dir_recursive(target_directory)
	
	# Copy the file
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if not source_file:
		_emit_error("Cannot read source file: %s" % source_path)
		return false
	
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if not target_file:
		_emit_error("Cannot create target file: %s" % target_path)
		source_file.close()
		return false
	
	# Copy file content
	var file_data: PackedByteArray = source_file.get_buffer(source_file.get_length())
	target_file.store_buffer(file_data)
	
	source_file.close()
	target_file.close()
	
	# Create import file if needed
	if generate_import_presets:
		_create_import_file(target_path, asset_type)
	
	return true

func _get_relative_vp_path(full_path: String) -> String:
	"""Get relative path as it would appear in VP structure."""
	
	# This is a simplified implementation
	# In a full implementation, you'd track the original VP structure
	
	var path_parts: PackedStringArray = full_path.split("/")
	
	# Look for VP-like structure markers
	for i in range(path_parts.size()):
		var part: String = path_parts[i].to_lower()
		if part in ["data", "models", "textures", "missions", "campaigns"]:
			# Found VP structure marker, return path from here
			var relative_parts: PackedStringArray = []
			for j in range(i + 1, path_parts.size()):
				relative_parts.append(path_parts[j])
			return "/".join(relative_parts)
	
	return ""

func _create_import_file(asset_path: String, asset_type: String) -> void:
	"""Create Godot import file for asset."""
	
	var import_path: String = asset_path + ".import"
	var import_file: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
	
	if not import_file:
		return
	
	var extension: String = asset_path.get_extension().to_lower()
	
	# Write import configuration based on asset type
	import_file.store_line("[remap]")
	import_file.store_line("")
	
	match extension:
		"png", "jpg":
			import_file.store_line("importer=\"texture\"")
			import_file.store_line("type=\"CompressedTexture2D\"")
			import_file.store_line("uid=\"uid://b%d\"" % hash(asset_path))
			import_file.store_line("path=\"res://.godot/imported/%s-%s.ctex\"" % [asset_path.get_file(), asset_path.md5_text().substr(0, 8)])
			import_file.store_line("")
			import_file.store_line("[deps]")
			import_file.store_line("")
			import_file.store_line("source_file=\"%s\"" % asset_path)
			import_file.store_line("dest_files=[\"res://.godot/imported/%s-%s.ctex\"]" % [asset_path.get_file(), asset_path.md5_text().substr(0, 8)])
			import_file.store_line("")
			import_file.store_line("[params]")
			import_file.store_line("")
			import_file.store_line("compress/mode=%d" % (3 if compress_textures else 0))
			import_file.store_line("compress/high_quality=false")
			import_file.store_line("compress/lossy_quality=0.7")
			import_file.store_line("compress/hdr_compression=1")
			import_file.store_line("compress/normal_map=0")
			import_file.store_line("compress/channel_pack=0")
			import_file.store_line("mipmaps/generate=true")
			import_file.store_line("mipmaps/limit=-1")
			import_file.store_line("roughness/mode=0")
			import_file.store_line("roughness/src_normal=\"\"")
			import_file.store_line("process/fix_alpha_border=true")
			import_file.store_line("process/premult_alpha=false")
			import_file.store_line("process/normal_map_invert_y=false")
			import_file.store_line("process/hdr_as_srgb=false")
			import_file.store_line("process/hdr_clamp_exposure=false")
			import_file.store_line("process/size_limit=0")
			import_file.store_line("detect_3d/compress_to=1")
		
		"wav", "ogg":
			import_file.store_line("importer=\"wav\"" if extension == "wav" else "importer=\"oggvorbisstr\"")
			import_file.store_line("type=\"AudioStreamWAV\"" if extension == "wav" else "type=\"AudioStreamOggVorbis\"")
			import_file.store_line("uid=\"uid://c%d\"" % hash(asset_path))
			import_file.store_line("path=\"res://.godot/imported/%s-%s.sample\"" % [asset_path.get_file(), asset_path.md5_text().substr(0, 8)])
			import_file.store_line("")
			import_file.store_line("[deps]")
			import_file.store_line("")
			import_file.store_line("source_file=\"%s\"" % asset_path)
			import_file.store_line("dest_files=[\"res://.godot/imported/%s-%s.sample\"]" % [asset_path.get_file(), asset_path.md5_text().substr(0, 8)])
			import_file.store_line("")
			import_file.store_line("[params]")
			import_file.store_line("")
			import_file.store_line("force/8_bit=false")
			import_file.store_line("force/mono=false")
			import_file.store_line("force/max_rate=false")
			import_file.store_line("force/max_rate_hz=44100")
			import_file.store_line("edit/trim=false")
			import_file.store_line("edit/normalize=false")
			import_file.store_line("edit/loop_mode=0")
			import_file.store_line("edit/loop_begin=0")
			import_file.store_line("edit/loop_end=-1")
			import_file.store_line("compress/mode=0")
		
		"tscn":
			import_file.store_line("importer=\"scene\"")
			import_file.store_line("importer_version=1")
			import_file.store_line("type=\"PackedScene\"")
			import_file.store_line("uid=\"uid://d%d\"" % hash(asset_path))
			import_file.store_line("path=\"res://.godot/imported/%s-%s.scn\"" % [asset_path.get_file(), asset_path.md5_text().substr(0, 8)])
	
	import_file.close()
	packaging_stats.import_presets_created += 1

func _create_asset_collections(organized_assets: Dictionary) -> void:
	"""Create asset collection resources for easy access."""
	
	for asset_type in organized_assets.keys():
		var files: Array[String] = organized_assets[asset_type]
		
		if files.is_empty():
			continue
		
		var collection: Resource = Resource.new()
		collection.set_meta("asset_type", asset_type)
		collection.set_meta("file_count", files.size())
		collection.set_meta("creation_date", Time.get_datetime_string_from_system())
		collection.set_meta("asset_paths", files)
		
		var collection_path: String = output_directory + asset_type + "_collection.tres"
		ResourceSaver.save(collection, collection_path)
		
		packaging_stats.collections_created += 1
		print("AssetPackager: Created %s collection with %d assets" % [asset_type, files.size()])

func _generate_import_presets() -> void:
	"""Generate Godot import presets for optimal asset handling."""
	
	var preset_path: String = output_directory + "import_presets.cfg"
	var config: ConfigFile = ConfigFile.new()
	
	# Texture import preset
	config.set_value("preset_texture_wcs", "importer", "texture")
	config.set_value("preset_texture_wcs", "compress/mode", 3 if compress_textures else 0)
	config.set_value("preset_texture_wcs", "mipmaps/generate", true)
	config.set_value("preset_texture_wcs", "detect_3d/compress_to", 1)
	
	# Audio import preset
	config.set_value("preset_audio_wcs", "importer", "wav")
	config.set_value("preset_audio_wcs", "force/max_rate", false)
	config.set_value("preset_audio_wcs", "edit/loop_mode", 0)
	
	# Model import preset
	config.set_value("preset_model_wcs", "importer", "scene")
	config.set_value("preset_model_wcs", "meshes/optimize", optimize_models)
	config.set_value("preset_model_wcs", "meshes/create_shadow_meshes", true)
	
	config.save(preset_path)
	print("AssetPackager: Created import presets at %s" % preset_path)

func _create_debug_manifests(organized_assets: Dictionary) -> void:
	"""Create debug manifests with asset information."""
	
	var manifest_path: String = output_directory + "asset_manifest.json"
	var manifest_data: Dictionary = {
		"packaging_date": Time.get_datetime_string_from_system(),
		"total_files": packaging_stats.total_files,
		"organized_files": packaging_stats.organized_files,
		"asset_types": {}
	}
	
	for asset_type in organized_assets.keys():
		var files: Array[String] = organized_assets[asset_type]
		manifest_data.asset_types[asset_type] = {
			"count": files.size(),
			"files": files
		}
	
	var manifest_file: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file:
		manifest_file.store_string(JSON.stringify(manifest_data, "\t"))
		manifest_file.close()
		print("AssetPackager: Created asset manifest at %s" % manifest_path)

func _emit_error(error_message: String) -> void:
	"""Emit error signal and print error message."""
	print("AssetPackager Error: %s" % error_message)
	packaging_error.emit(error_message)

func _print_packaging_summary() -> void:
	"""Print summary of packaging results."""
	var elapsed_time: float = packaging_stats.end_time - packaging_stats.start_time
	
	print("=== Asset Packaging Summary ===")
	print("Total Files Found: %d" % packaging_stats.total_files)
	print("Successfully Organized: %d" % packaging_stats.organized_files)
	print("Collections Created: %d" % packaging_stats.collections_created)
	print("Import Presets Created: %d" % packaging_stats.import_presets_created)
	print("Output Directory: %s" % output_directory)
	print("Elapsed Time: %.2f seconds" % elapsed_time)
	print("================================")