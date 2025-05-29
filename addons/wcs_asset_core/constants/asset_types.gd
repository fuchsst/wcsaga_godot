class_name AssetTypes
extends RefCounted

## Asset type definitions and constants for the WCS Asset Core addon.
## Provides centralized type system for all asset management operations.
## Used throughout the addon for type checking, filtering, and organization.

## Core asset types
enum Type {
	# Base types
	UNKNOWN = -1,
	BASE_ASSET = 0,
	
	# Ship-related assets
	SHIP = 100,
	SHIP_CLASS = 101,
	SHIP_VARIANT = 102,
	SUBSYSTEM = 103,
	SUBSYSTEM_DEFINITION = 104,
	
	# Weapon-related assets
	WEAPON = 200,
	PRIMARY_WEAPON = 201,
	SECONDARY_WEAPON = 202,
	COUNTERMEASURE = 203,
	TURRET_WEAPON = 204,
	BEAM_WEAPON = 205,
	
	# Armor and defense assets
	ARMOR = 300,
	SHIELD_ARMOR = 301,
	HULL_ARMOR = 302,
	DAMAGE_TYPE = 303,
	
	# Model and visual assets
	MODEL = 400,
	SHIP_MODEL = 401,
	WEAPON_MODEL = 402,
	DEBRIS_MODEL = 403,
	ASTEROID_MODEL = 404,
	
	# Texture and material assets
	TEXTURE = 500,
	SHIP_TEXTURE = 501,
	WEAPON_TEXTURE = 502,
	EFFECT_TEXTURE = 503,
	UI_TEXTURE = 504,
	
	# Audio assets
	AUDIO = 600,
	ENGINE_SOUND = 601,
	WEAPON_SOUND = 602,
	EXPLOSION_SOUND = 603,
	VOICE_SOUND = 604,
	MUSIC = 605,
	
	# Mission and campaign assets
	MISSION = 700,
	CAMPAIGN = 701,
	MISSION_BRIEFING = 702,
	MISSION_GOALS = 703,
	
	# Effect and particle assets
	EFFECT = 800,
	PARTICLE_EFFECT = 801,
	EXPLOSION_EFFECT = 802,
	TRAIL_EFFECT = 803,
	BEAM_EFFECT = 804,
	
	# Table and data assets
	TABLE_DATA = 900,
	SHIP_TABLE = 901,
	WEAPON_TABLE = 902,
	ARMOR_TABLE = 903,
	STRING_TABLE = 904
}

## Asset category groupings
enum Category {
	CORE = 0,
	COMBAT = 1,
	VISUAL = 2,
	AUDIO = 3,
	MISSION = 4,
	EFFECT = 5,
	DATA = 6
}

## Type name mappings
static var TYPE_NAMES: Dictionary = {
	Type.UNKNOWN: "Unknown",
	Type.BASE_ASSET: "Base Asset",
	
	# Ships
	Type.SHIP: "Ship",
	Type.SHIP_CLASS: "Ship Class",
	Type.SHIP_VARIANT: "Ship Variant",
	Type.SUBSYSTEM: "Subsystem",
	Type.SUBSYSTEM_DEFINITION: "Subsystem Definition",
	
	# Weapons
	Type.WEAPON: "Weapon",
	Type.PRIMARY_WEAPON: "Primary Weapon",
	Type.SECONDARY_WEAPON: "Secondary Weapon",
	Type.COUNTERMEASURE: "Countermeasure",
	Type.TURRET_WEAPON: "Turret Weapon",
	Type.BEAM_WEAPON: "Beam Weapon",
	
	# Armor
	Type.ARMOR: "Armor",
	Type.SHIELD_ARMOR: "Shield Armor",
	Type.HULL_ARMOR: "Hull Armor",
	Type.DAMAGE_TYPE: "Damage Type",
	
	# Models
	Type.MODEL: "Model",
	Type.SHIP_MODEL: "Ship Model",
	Type.WEAPON_MODEL: "Weapon Model",
	Type.DEBRIS_MODEL: "Debris Model",
	Type.ASTEROID_MODEL: "Asteroid Model",
	
	# Textures
	Type.TEXTURE: "Texture",
	Type.SHIP_TEXTURE: "Ship Texture",
	Type.WEAPON_TEXTURE: "Weapon Texture",
	Type.EFFECT_TEXTURE: "Effect Texture",
	Type.UI_TEXTURE: "UI Texture",
	
	# Audio
	Type.AUDIO: "Audio",
	Type.ENGINE_SOUND: "Engine Sound",
	Type.WEAPON_SOUND: "Weapon Sound",
	Type.EXPLOSION_SOUND: "Explosion Sound",
	Type.VOICE_SOUND: "Voice Sound",
	Type.MUSIC: "Music",
	
	# Mission
	Type.MISSION: "Mission",
	Type.CAMPAIGN: "Campaign",
	Type.MISSION_BRIEFING: "Mission Briefing",
	Type.MISSION_GOALS: "Mission Goals",
	
	# Effects
	Type.EFFECT: "Effect",
	Type.PARTICLE_EFFECT: "Particle Effect",
	Type.EXPLOSION_EFFECT: "Explosion Effect",
	Type.TRAIL_EFFECT: "Trail Effect",
	Type.BEAM_EFFECT: "Beam Effect",
	
	# Tables
	Type.TABLE_DATA: "Table Data",
	Type.SHIP_TABLE: "Ship Table",
	Type.WEAPON_TABLE: "Weapon Table",
	Type.ARMOR_TABLE: "Armor Table",
	Type.STRING_TABLE: "String Table"
}

## Category mappings
static var TYPE_CATEGORIES: Dictionary = {
	Type.BASE_ASSET: Category.CORE,
	
	# Ships
	Type.SHIP: Category.CORE,
	Type.SHIP_CLASS: Category.CORE,
	Type.SHIP_VARIANT: Category.CORE,
	Type.SUBSYSTEM: Category.CORE,
	Type.SUBSYSTEM_DEFINITION: Category.CORE,
	
	# Weapons
	Type.WEAPON: Category.COMBAT,
	Type.PRIMARY_WEAPON: Category.COMBAT,
	Type.SECONDARY_WEAPON: Category.COMBAT,
	Type.COUNTERMEASURE: Category.COMBAT,
	Type.TURRET_WEAPON: Category.COMBAT,
	Type.BEAM_WEAPON: Category.COMBAT,
	
	# Armor
	Type.ARMOR: Category.COMBAT,
	Type.SHIELD_ARMOR: Category.COMBAT,
	Type.HULL_ARMOR: Category.COMBAT,
	Type.DAMAGE_TYPE: Category.COMBAT,
	
	# Models
	Type.MODEL: Category.VISUAL,
	Type.SHIP_MODEL: Category.VISUAL,
	Type.WEAPON_MODEL: Category.VISUAL,
	Type.DEBRIS_MODEL: Category.VISUAL,
	Type.ASTEROID_MODEL: Category.VISUAL,
	
	# Textures
	Type.TEXTURE: Category.VISUAL,
	Type.SHIP_TEXTURE: Category.VISUAL,
	Type.WEAPON_TEXTURE: Category.VISUAL,
	Type.EFFECT_TEXTURE: Category.VISUAL,
	Type.UI_TEXTURE: Category.VISUAL,
	
	# Audio
	Type.AUDIO: Category.AUDIO,
	Type.ENGINE_SOUND: Category.AUDIO,
	Type.WEAPON_SOUND: Category.AUDIO,
	Type.EXPLOSION_SOUND: Category.AUDIO,
	Type.VOICE_SOUND: Category.AUDIO,
	Type.MUSIC: Category.AUDIO,
	
	# Mission
	Type.MISSION: Category.MISSION,
	Type.CAMPAIGN: Category.MISSION,
	Type.MISSION_BRIEFING: Category.MISSION,
	Type.MISSION_GOALS: Category.MISSION,
	
	# Effects
	Type.EFFECT: Category.EFFECT,
	Type.PARTICLE_EFFECT: Category.EFFECT,
	Type.EXPLOSION_EFFECT: Category.EFFECT,
	Type.TRAIL_EFFECT: Category.EFFECT,
	Type.BEAM_EFFECT: Category.EFFECT,
	
	# Tables
	Type.TABLE_DATA: Category.DATA,
	Type.SHIP_TABLE: Category.DATA,
	Type.WEAPON_TABLE: Category.DATA,
	Type.ARMOR_TABLE: Category.DATA,
	Type.STRING_TABLE: Category.DATA
}

## Utility functions

static func get_type_name(asset_type: Type) -> String:
	"""Get human-readable name for an asset type.
	Args:
		asset_type: Asset type enum value
	Returns:
		Human-readable type name"""
	
	return TYPE_NAMES.get(asset_type, "Unknown")

static func get_type_category(asset_type: Type) -> Category:
	"""Get the category for an asset type.
	Args:
		asset_type: Asset type enum value
	Returns:
		Category enum value"""
	
	return TYPE_CATEGORIES.get(asset_type, Category.CORE)

static func get_types_in_category(category: Category) -> Array[Type]:
	"""Get all asset types in a specific category.
	Args:
		category: Category enum value
	Returns:
		Array of asset type enum values"""
	
	var types: Array[Type] = []
	
	for asset_type in TYPE_CATEGORIES.keys():
		if TYPE_CATEGORIES[asset_type] == category:
			types.append(asset_type)
	
	return types

static func is_ship_type(asset_type: Type) -> bool:
	"""Check if an asset type is ship-related.
	Args:
		asset_type: Asset type enum value
	Returns:
		true if type is ship-related"""
	
	return asset_type >= Type.SHIP and asset_type < Type.WEAPON

static func is_weapon_type(asset_type: Type) -> bool:
	"""Check if an asset type is weapon-related.
	Args:
		asset_type: Asset type enum value
	Returns:
		true if type is weapon-related"""
	
	return asset_type >= Type.WEAPON and asset_type < Type.ARMOR

static func is_armor_type(asset_type: Type) -> bool:
	"""Check if an asset type is armor-related.
	Args:
		asset_type: Asset type enum value
	Returns:
		true if type is armor-related"""
	
	return asset_type >= Type.ARMOR and asset_type < Type.MODEL

static func is_visual_type(asset_type: Type) -> bool:
	"""Check if an asset type is visual-related (models, textures).
	Args:
		asset_type: Asset type enum value
	Returns:
		true if type is visual-related"""
	
	return get_type_category(asset_type) == Category.VISUAL

static func is_audio_type(asset_type: Type) -> bool:
	"""Check if an asset type is audio-related.
	Args:
		asset_type: Asset type enum value
	Returns:
		true if type is audio-related"""
	
	return get_type_category(asset_type) == Category.AUDIO

static func parse_type_from_string(type_string: String) -> Type:
	"""Parse asset type from string representation.
	Args:
		type_string: String representation of type
	Returns:
		Parsed asset type or Type.UNKNOWN if not found"""
	
	var search_string: String = type_string.to_lower().strip_edges()
	
	# Search in type names
	for type_value in TYPE_NAMES.keys():
		var type_name: String = TYPE_NAMES[type_value].to_lower()
		if type_name == search_string:
			return type_value
	
	# Search for partial matches
	for type_value in TYPE_NAMES.keys():
		var type_name: String = TYPE_NAMES[type_value].to_lower()
		if type_name.contains(search_string) or search_string.contains(type_name):
			return type_value
	
	return Type.UNKNOWN

static func get_all_types() -> Array[Type]:
	"""Get all available asset types.
	Returns:
		Array of all asset type enum values"""
	
	var types: Array[Type] = []
	for type_value in TYPE_NAMES.keys():
		types.append(type_value)
	
	return types

static func get_category_name(category: Category) -> String:
	"""Get human-readable name for a category.
	Args:
		category: Category enum value
	Returns:
		Human-readable category name"""
	
	match category:
		Category.CORE:
			return "Core"
		Category.COMBAT:
			return "Combat"
		Category.VISUAL:
			return "Visual"
		Category.AUDIO:
			return "Audio"
		Category.MISSION:
			return "Mission"
		Category.EFFECT:
			return "Effect"
		Category.DATA:
			return "Data"
		_:
			return "Unknown"
