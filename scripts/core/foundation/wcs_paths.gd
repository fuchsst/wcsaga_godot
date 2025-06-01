extends Node

## Standard game directory paths with cross-platform compatibility.
## Defines all standard WCS directory structures using Godot's resource system.
## Provides centralized path management for all game systems.

# ========================================
# Base Game Directories
# ========================================

## Root game data directory
const GAME_DATA_DIR: String = "res://data/"

## Root user data directory (for saves, config, etc.)
const USER_DATA_DIR: String = "user://data/"

# ========================================
# Asset Directories
# ========================================

## Mission files (.fs2 format)
const MISSIONS_DIR: String = GAME_DATA_DIR + "missions/"

## Ship model files (.pof format)
const MODELS_DIR: String = GAME_DATA_DIR + "models/"

## Texture files (various formats)
const TEXTURES_DIR: String = GAME_DATA_DIR + "textures/"

## Sound effect files (.wav format)
const SOUNDS_DIR: String = GAME_DATA_DIR + "sounds/"

## Music files (.ogg format)  
const MUSIC_DIR: String = GAME_DATA_DIR + "music/"

## Animation files (.ani format)
const ANIMATIONS_DIR: String = GAME_DATA_DIR + "animations/"

## Interface graphics and HUD elements
const INTERFACE_DIR: String = GAME_DATA_DIR + "interface/"

## Background and skybox textures
const BACKGROUNDS_DIR: String = GAME_DATA_DIR + "backgrounds/"

## Nebula effect textures and data
const NEBULA_DIR: String = GAME_DATA_DIR + "nebula/"

## Effect and particle textures
const EFFECTS_DIR: String = GAME_DATA_DIR + "effects/"

## Font files for text rendering
const FONTS_DIR: String = GAME_DATA_DIR + "fonts/"

# ========================================
# Configuration Directories
# ========================================

## Table files (.tbl format) containing game data definitions
const TABLES_DIR: String = GAME_DATA_DIR + "tables/"

## Script files (.lua format) for mission scripting
const SCRIPTS_DIR: String = GAME_DATA_DIR + "scripts/"

## Campaign definition files
const CAMPAIGNS_DIR: String = GAME_DATA_DIR + "campaigns/"

## Localization and translation files
const LOCALIZATION_DIR: String = GAME_DATA_DIR + "localization/"

# ========================================
# User Data Directories  
# ========================================

## Player save files and pilot data
const SAVES_DIR: String = USER_DATA_DIR + "saves/"

## User configuration files
const CONFIG_DIR: String = USER_DATA_DIR + "config/"

## Screenshot storage
const SCREENSHOTS_DIR: String = USER_DATA_DIR + "screenshots/"

## User-created missions and mods
const USER_MISSIONS_DIR: String = USER_DATA_DIR + "missions/"

## Custom control configurations
const CONTROLS_DIR: String = CONFIG_DIR + "controls/"

## Replay files and recorded games
const REPLAYS_DIR: String = USER_DATA_DIR + "replays/"

# ========================================
# Cache Directories
# ========================================

## Temporary cache for converted assets
const CACHE_DIR: String = USER_DATA_DIR + "cache/"

## Converted model cache
const MODEL_CACHE_DIR: String = CACHE_DIR + "models/"

## Converted texture cache
const TEXTURE_CACHE_DIR: String = CACHE_DIR + "textures/"

## Compiled script cache
const SCRIPT_CACHE_DIR: String = CACHE_DIR + "scripts/"

# ========================================
# Standard File Extensions
# ========================================

## Mission file extension
const MISSION_EXT: String = ".fs2"

## WCS model file extension  
const MODEL_EXT: String = ".pof"

## WCS animation file extension
const ANIMATION_EXT: String = ".ani"

## Table file extension
const TABLE_EXT: String = ".tbl"

## Script file extension
const SCRIPT_EXT: String = ".lua"

## VP archive extension
const ARCHIVE_EXT: String = ".vp"

## Godot resource extension (for converted assets)
const RESOURCE_EXT: String = ".tres"

## Godot scene extension (for converted missions)
const SCENE_EXT: String = ".tscn"

# ========================================
# Utility Functions
# ========================================

## Combines path components with proper separators
static func combine_path(base_path: String, sub_path: String) -> String:
	var result: String = base_path
	if not result.ends_with("/"):
		result += "/"
	return result + sub_path

## Ensures a directory path ends with a separator
static func ensure_trailing_separator(path: String) -> String:
	if not path.ends_with("/"):
		return path + "/"
	return path

## Removes the file extension from a filename
static func remove_extension(filename: String) -> String:
	var dot_index: int = filename.rfind(".")
	if dot_index > 0:
		return filename.substr(0, dot_index)
	return filename

## Gets the file extension from a filename (including the dot)
static func get_extension(filename: String) -> String:
	var dot_index: int = filename.rfind(".")
	if dot_index >= 0:
		return filename.substr(dot_index)
	return ""

## Converts a WCS file path to Godot resource path format
static func wcs_to_godot_path(wcs_path: String) -> String:
	# Convert backslashes to forward slashes
	var godot_path: String = wcs_path.replace("\\", "/")
	
	# Ensure it starts with res:// if it's a game asset
	if not godot_path.begins_with("res://") and not godot_path.begins_with("user://"):
		godot_path = "res://" + godot_path
	
	return godot_path

## Creates all necessary directories for the game
static func create_directories() -> void:
	var dirs_to_create: PackedStringArray = [
		USER_DATA_DIR,
		SAVES_DIR,
		CONFIG_DIR,
		SCREENSHOTS_DIR,
		USER_MISSIONS_DIR,
		CONTROLS_DIR,
		REPLAYS_DIR,
		CACHE_DIR,
		MODEL_CACHE_DIR,
		TEXTURE_CACHE_DIR,
		SCRIPT_CACHE_DIR
	]
	
	for dir_path in dirs_to_create:
		if not DirAccess.dir_exists_absolute(dir_path):
			var error: Error = DirAccess.open("user://").make_dir_recursive(dir_path.replace("user://", ""))
			if error != OK:
				push_error("Failed to create directory: %s (Error: %d)" % [dir_path, error])

## Validates that a file path has a valid WCS extension
static func validate_wcs_file_extension(file_path: String, expected_ext: String) -> bool:
	var actual_ext: String = get_extension(file_path).to_lower()
	return actual_ext == expected_ext.to_lower()

## Gets the appropriate cache directory for a given file type
static func get_cache_dir_for_extension(extension: String) -> String:
	match extension.to_lower():
		MODEL_EXT:
			return MODEL_CACHE_DIR
		".pcx", ".jpg", ".png", ".tga", ".dds":
			return TEXTURE_CACHE_DIR
		SCRIPT_EXT:
			return SCRIPT_CACHE_DIR
		_:
			return CACHE_DIR

## Converts a game asset path to its cached equivalent
static func get_cached_path(original_path: String) -> String:
	var filename: String = original_path.get_file()
	var extension: String = get_extension(filename)
	var base_name: String = remove_extension(filename)
	
	var cache_dir: String = get_cache_dir_for_extension(extension)
	return combine_path(cache_dir, base_name + RESOURCE_EXT)

# ========================================
# Path Validation Functions
# ========================================

## Validates that a pathname is within WCS length limits
static func validate_pathname_length(pathname: String) -> bool:
	return pathname.length() <= WCSConstants.PATHNAME_LENGTH

## Validates that a filename is within WCS length limits  
static func validate_filename_length(filename: String) -> bool:
	return filename.length() <= WCSConstants.MAX_FILENAME_LEN

## Checks if a file exists at the given path
static func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)

## Checks if a directory exists at the given path
static func dir_exists(dir_path: String) -> bool:
	return DirAccess.dir_exists_absolute(dir_path)

## Gets the full path to a mission file
static func get_mission_path(mission_name: String) -> String:
	if not mission_name.ends_with(MISSION_EXT):
		mission_name += MISSION_EXT
	return combine_path(MISSIONS_DIR, mission_name)

## Gets the full path to a model file
static func get_model_path(model_name: String) -> String:
	if not model_name.ends_with(MODEL_EXT):
		model_name += MODEL_EXT
	return combine_path(MODELS_DIR, model_name)

## Gets the full path to a table file
static func get_table_path(table_name: String) -> String:
	if not table_name.ends_with(TABLE_EXT):
		table_name += TABLE_EXT
	return combine_path(TABLES_DIR, table_name)