class_name FolderPaths
extends RefCounted

## Standardized folder paths and conventions for the WCS Asset Core addon.
## Provides centralized path management for asset organization and discovery.
## Used throughout the addon for consistent file and folder organization.

## Base asset directories
static var BASE_ASSETS_DIR: String = "res://assets/"
static var BASE_ADDON_DIR: String = "res://addons/wcs_asset_core/"
static var MIGRATED_ASSETS_DIR: String = "res://migrated_assets/"
static var CACHE_DIR: String = "user://cache/wcs_assets/"

## Asset type directories
static var SHIPS_DIR: String = "ships/"
static var WEAPONS_DIR: String = "weapons/"
static var ARMOR_DIR: String = "armor/"
static var MODELS_DIR: String = "models/"
static var TEXTURES_DIR: String = "textures/"
static var AUDIO_DIR: String = "audio/"
static var MISSIONS_DIR: String = "missions/"
static var CAMPAIGNS_DIR: String = "campaigns/"
static var EFFECTS_DIR: String = "effects/"
static var TABLES_DIR: String = "tables/"

## Specialized subdirectories
static var SHIP_CLASSES_DIR: String = "ships/classes/"
static var SHIP_VARIANTS_DIR: String = "ships/variants/"
static var PRIMARY_WEAPONS_DIR: String = "weapons/primary/"
static var SECONDARY_WEAPONS_DIR: String = "weapons/secondary/"
static var BEAM_WEAPONS_DIR: String = "weapons/beams/"
static var COUNTERMEASURES_DIR: String = "weapons/countermeasures/"
static var TURRETS_DIR: String = "weapons/turrets/"

## Model subdirectories
static var SHIP_MODELS_DIR: String = "models/ships/"
static var WEAPON_MODELS_DIR: String = "models/weapons/"
static var DEBRIS_MODELS_DIR: String = "models/debris/"
static var ASTEROID_MODELS_DIR: String = "models/asteroids/"

## Texture subdirectories
static var SHIP_TEXTURES_DIR: String = "textures/ships/"
static var WEAPON_TEXTURES_DIR: String = "textures/weapons/"
static var EFFECT_TEXTURES_DIR: String = "textures/effects/"
static var UI_TEXTURES_DIR: String = "textures/ui/"
static var INTERFACE_TEXTURES_DIR: String = "textures/interface/"

## Audio subdirectories
static var ENGINE_SOUNDS_DIR: String = "audio/engines/"
static var WEAPON_SOUNDS_DIR: String = "audio/weapons/"
static var EXPLOSION_SOUNDS_DIR: String = "audio/explosions/"
static var VOICE_SOUNDS_DIR: String = "audio/voice/"
static var MUSIC_DIR: String = "audio/music/"
static var AMBIENT_SOUNDS_DIR: String = "audio/ambient/"

## Effect subdirectories
static var PARTICLE_EFFECTS_DIR: String = "effects/particles/"
static var EXPLOSION_EFFECTS_DIR: String = "effects/explosions/"
static var TRAIL_EFFECTS_DIR: String = "effects/trails/"
static var BEAM_EFFECTS_DIR: String = "effects/beams/"
static var THRUSTER_EFFECTS_DIR: String = "effects/thrusters/"

## Table data subdirectories
static var SHIP_TABLES_DIR: String = "tables/ships/"
static var WEAPON_TABLES_DIR: String = "tables/weapons/"
static var ARMOR_TABLES_DIR: String = "tables/armor/"
static var STRING_TABLES_DIR: String = "tables/strings/"
static var CONFIG_TABLES_DIR: String = "tables/config/"

## File extensions
static var ASSET_EXTENSION: String = ".tres"
static var SCENE_EXTENSION: String = ".tscn"
static var TEXTURE_EXTENSION: String = ".png"
static var MODEL_EXTENSION: String = ".gltf"
static var AUDIO_EXTENSION: String = ".ogg"
static var TABLE_EXTENSION: String = ".tres"

## Path utility functions

static func get_asset_dir_for_type(asset_type: AssetTypes.Type) -> String:
	"""Get the base directory for a specific asset type.
	Args:
		asset_type: Asset type enum value
	Returns:
		Relative directory path for the asset type"""
	
	match asset_type:
		# Ships
		AssetTypes.Type.SHIP, AssetTypes.Type.SHIP_CLASS:
			return SHIPS_DIR
		AssetTypes.Type.SHIP_VARIANT:
			return SHIP_VARIANTS_DIR
		
		# Weapons
		AssetTypes.Type.WEAPON, AssetTypes.Type.PRIMARY_WEAPON:
			return PRIMARY_WEAPONS_DIR
		AssetTypes.Type.SECONDARY_WEAPON:
			return SECONDARY_WEAPONS_DIR
		AssetTypes.Type.BEAM_WEAPON:
			return BEAM_WEAPONS_DIR
		AssetTypes.Type.COUNTERMEASURE:
			return COUNTERMEASURES_DIR
		AssetTypes.Type.TURRET_WEAPON:
			return TURRETS_DIR
		
		# Armor
		AssetTypes.Type.ARMOR, AssetTypes.Type.SHIELD_ARMOR, AssetTypes.Type.HULL_ARMOR:
			return ARMOR_DIR
		
		# Models
		AssetTypes.Type.MODEL:
			return MODELS_DIR
		AssetTypes.Type.SHIP_MODEL:
			return SHIP_MODELS_DIR
		AssetTypes.Type.WEAPON_MODEL:
			return WEAPON_MODELS_DIR
		AssetTypes.Type.DEBRIS_MODEL:
			return DEBRIS_MODELS_DIR
		AssetTypes.Type.ASTEROID_MODEL:
			return ASTEROID_MODELS_DIR
		
		# Textures
		AssetTypes.Type.TEXTURE:
			return TEXTURES_DIR
		AssetTypes.Type.SHIP_TEXTURE:
			return SHIP_TEXTURES_DIR
		AssetTypes.Type.WEAPON_TEXTURE:
			return WEAPON_TEXTURES_DIR
		AssetTypes.Type.EFFECT_TEXTURE:
			return EFFECT_TEXTURES_DIR
		AssetTypes.Type.UI_TEXTURE:
			return UI_TEXTURES_DIR
		
		# Audio
		AssetTypes.Type.AUDIO:
			return AUDIO_DIR
		AssetTypes.Type.ENGINE_SOUND:
			return ENGINE_SOUNDS_DIR
		AssetTypes.Type.WEAPON_SOUND:
			return WEAPON_SOUNDS_DIR
		AssetTypes.Type.EXPLOSION_SOUND:
			return EXPLOSION_SOUNDS_DIR
		AssetTypes.Type.VOICE_SOUND:
			return VOICE_SOUNDS_DIR
		AssetTypes.Type.MUSIC:
			return MUSIC_DIR
		
		# Mission
		AssetTypes.Type.MISSION:
			return MISSIONS_DIR
		AssetTypes.Type.CAMPAIGN:
			return CAMPAIGNS_DIR
		
		# Effects
		AssetTypes.Type.EFFECT:
			return EFFECTS_DIR
		AssetTypes.Type.PARTICLE_EFFECT:
			return PARTICLE_EFFECTS_DIR
		AssetTypes.Type.EXPLOSION_EFFECT:
			return EXPLOSION_EFFECTS_DIR
		AssetTypes.Type.TRAIL_EFFECT:
			return TRAIL_EFFECTS_DIR
		AssetTypes.Type.BEAM_EFFECT:
			return BEAM_EFFECTS_DIR
		
		# Tables
		AssetTypes.Type.TABLE_DATA:
			return TABLES_DIR
		AssetTypes.Type.SHIP_TABLE:
			return SHIP_TABLES_DIR
		AssetTypes.Type.WEAPON_TABLE:
			return WEAPON_TABLES_DIR
		AssetTypes.Type.ARMOR_TABLE:
			return ARMOR_TABLES_DIR
		AssetTypes.Type.STRING_TABLE:
			return STRING_TABLES_DIR
		
		_:
			return ""

static func get_file_extension_for_type(asset_type: AssetTypes.Type) -> String:
	"""Get the expected file extension for a specific asset type.
	Args:
		asset_type: Asset type enum value
	Returns:
		File extension including the dot"""
	
	if AssetTypes.is_visual_type(asset_type):
		if asset_type >= AssetTypes.Type.MODEL and asset_type < AssetTypes.Type.TEXTURE:
			return MODEL_EXTENSION
		else:
			return TEXTURE_EXTENSION
	elif AssetTypes.is_audio_type(asset_type):
		return AUDIO_EXTENSION
	else:
		return ASSET_EXTENSION

static func build_asset_path(asset_type: AssetTypes.Type, asset_name: String, category: String = "") -> String:
	"""Build a complete asset path for a given type and name.
	Args:
		asset_type: Asset type enum value
		asset_name: Asset file name (without extension)
		category: Optional category subdirectory
	Returns:
		Complete asset path"""
	
	var base_dir: String = get_asset_dir_for_type(asset_type)
	var extension: String = get_file_extension_for_type(asset_type)
	
	var path: String = BASE_ASSETS_DIR + base_dir
	
	if not category.is_empty():
		path += category + "/"
	
	path += asset_name + extension
	
	return path

static func build_migrated_path(original_path: String) -> String:
	"""Build a migrated asset path from an original WCS path.
	Args:
		original_path: Original WCS asset path
	Returns:
		Migrated asset path in Godot format"""
	
	var clean_path: String = original_path.replace("\\", "/")
	if clean_path.begins_with("/"):
		clean_path = clean_path.substr(1)
	
	return MIGRATED_ASSETS_DIR + clean_path

static func get_cache_path(asset_path: String) -> String:
	"""Get the cache path for an asset.
	Args:
		asset_path: Original asset path
	Returns:
		Cache file path"""
	
	var cache_name: String = asset_path.replace("/", "_").replace(":", "_")
	return CACHE_DIR + cache_name + ".cache"

static func ensure_directory_exists(path: String) -> bool:
	"""Ensure a directory path exists, creating it if necessary.
	Args:
		path: Directory path to create
	Returns:
		true if directory exists or was created successfully"""
	
	var dir: DirAccess = DirAccess.open("res://")
	if dir == null:
		return false
	
	var dir_path: String = path
	if dir_path.ends_with("/"):
		dir_path = dir_path.substr(0, dir_path.length() - 1)
	
	return dir.make_dir_recursive(dir_path) == OK

static func normalize_path(path: String) -> String:
	"""Normalize a file path for consistent usage.
	Args:
		path: File path to normalize
	Returns:
		Normalized path with forward slashes"""
	
	return path.replace("\\", "/").simplify_path()

static func get_relative_path(full_path: String, base_path: String) -> String:
	"""Get a relative path from a full path and base path.
	Args:
		full_path: Complete file path
		base_path: Base directory path
	Returns:
		Relative path from base to full path"""
	
	var normalized_full: String = normalize_path(full_path)
	var normalized_base: String = normalize_path(base_path)
	
	if normalized_full.begins_with(normalized_base):
		return normalized_full.substr(normalized_base.length())
	
	return normalized_full

static func is_asset_path(path: String) -> bool:
	"""Check if a path points to an asset file.
	Args:
		path: File path to check
	Returns:
		true if path appears to be an asset file"""
	
	var extension: String = path.get_extension().to_lower()
	
	return extension in [
		"tres", "tscn", "png", "jpg", "jpeg", "webp",
		"gltf", "glb", "fbx", "obj", "dae",
		"ogg", "wav", "mp3", "aac"
	]

static func get_asset_type_from_path(path: String) -> AssetTypes.Type:
	"""Determine the asset type from a file path.
	Args:
		path: File path to analyze
	Returns:
		Best guess asset type based on path"""
	
	var normalized: String = normalize_path(path).to_lower()
	
	# Check by directory structure
	if SHIPS_DIR in normalized:
		return AssetTypes.Type.SHIP
	elif PRIMARY_WEAPONS_DIR in normalized or SECONDARY_WEAPONS_DIR in normalized:
		if "primary" in normalized:
			return AssetTypes.Type.PRIMARY_WEAPON
		else:
			return AssetTypes.Type.SECONDARY_WEAPON
	elif WEAPONS_DIR in normalized:
		return AssetTypes.Type.WEAPON
	elif ARMOR_DIR in normalized:
		return AssetTypes.Type.ARMOR
	elif MODELS_DIR in normalized:
		return AssetTypes.Type.MODEL
	elif TEXTURES_DIR in normalized:
		return AssetTypes.Type.TEXTURE
	elif AUDIO_DIR in normalized:
		return AssetTypes.Type.AUDIO
	elif MISSIONS_DIR in normalized:
		return AssetTypes.Type.MISSION
	elif EFFECTS_DIR in normalized:
		return AssetTypes.Type.EFFECT
	elif TABLES_DIR in normalized:
		return AssetTypes.Type.TABLE_DATA
	
	return AssetTypes.Type.UNKNOWN

static func get_all_asset_directories() -> Array[String]:
	"""Get all standard asset directories.
	Returns:
		Array of all asset directory paths"""
	
	return [
		SHIPS_DIR,
		WEAPONS_DIR,
		ARMOR_DIR,
		MODELS_DIR,
		TEXTURES_DIR,
		AUDIO_DIR,
		MISSIONS_DIR,
		CAMPAIGNS_DIR,
		EFFECTS_DIR,
		TABLES_DIR
	]
