class_name IFFData
extends BaseAssetData

## IFF (Identification Friend or Foe) data resource for the WCS Asset Core addon.
## Comprehensive faction specifications extracted from the existing WCS codebase.
## Contains all properties needed to define a faction in the WCS-Godot conversion.

# Asset type setup
func _init() -> void:
	asset_type = AssetTypes.Type.FACTION

## IFF Information
@export var iff_name: String = "" # iff_info.iff_name

## Core Colors
@export var selection_color: Color = Color.WHITE # iff_info.colors.selection
@export var message_color: Color = Color.WHITE # iff_info.colors.message
@export var tagged_color: Color = Color.YELLOW # iff_info.colors.tagged
@export var iff_color: Color = Color.WHITE # iff_info.colors.default

## Radar Blip Colors
@export var missile_blip_color: Color = Color.RED # iff_info.colors.missile_blip
@export var navbuoy_blip_color: Color = Color.GREEN # iff_info.colors.navbuoy_blip
@export var warping_blip_color: Color = Color.YELLOW # iff_info.colors.warping_blip
@export var node_blip_color: Color = Color.BLUE # iff_info.colors.node_blip
@export var tagged_blip_color: Color = Color.YELLOW # iff_info.colors.tagged_blip

## Display Properties
@export var dimmed_iff_brightness: float = 0.5 # iff_info.dimmed_iff_brightness
@export var use_alternate_blip_coloring: bool = false # iff_info.use_alternate_blip_coloring

## Faction Relations
@export var attacks: Array[String] = [] # iff_info.attacks (list of enemy faction names)
@export var sees_as: Dictionary = {} # iff_info.sees_as (faction_name -> Color mapping)
@export var iff_flags: Array[String] = [] # iff_info.flags

## Advanced IFF Properties
@export var default_reputation: float = 0.0 # Default reputation with this faction (-100 to 100)
@export var hostile_threshold: float = -10.0 # Reputation threshold for hostility
@export var friendly_threshold: float = 10.0 # Reputation threshold for friendliness
@export var ally_threshold: float = 50.0 # Reputation threshold for alliance

## Communication Settings
@export var accepts_hails: bool = true # Whether this faction accepts communication
@export var hail_response_type: String = "default" # Type of hail response behavior
@export var message_frequency: float = 1.0 # Frequency multiplier for messages from this faction

## Tactical Behavior
@export var aggression_level: float = 1.0 # Base aggression multiplier (0.0 = passive, 2.0 = very aggressive)
@export var formation_preference: String = "standard" # Preferred formation type
@export var pursuit_distance: float = 10000.0 # Maximum pursuit distance in meters
@export var retreat_threshold: float = 0.25 # Hull percentage to trigger retreat

## Override validation to include IFF-specific checks
func get_validation_errors() -> Array[String]:
	"""Get validation errors specific to IFF data.
	Returns:
		Array of validation error messages"""
	
	var errors: Array[String] = super.get_validation_errors()
	
	# IFF-specific validation
	if iff_name.is_empty():
		errors.append("IFF name is required")
	
	if dimmed_iff_brightness < 0.0 or dimmed_iff_brightness > 1.0:
		errors.append("Dimmed IFF brightness must be between 0.0 and 1.0")
	
	if default_reputation < -100.0 or default_reputation > 100.0:
		errors.append("Default reputation must be between -100.0 and 100.0")
	
	if hostile_threshold > friendly_threshold:
		errors.append("Hostile threshold cannot be greater than friendly threshold")
	
	if friendly_threshold > ally_threshold:
		errors.append("Friendly threshold cannot be greater than ally threshold")
	
	if aggression_level < 0.0:
		errors.append("Aggression level cannot be negative")
	
	if pursuit_distance < 0.0:
		errors.append("Pursuit distance cannot be negative")
	
	if retreat_threshold < 0.0 or retreat_threshold > 1.0:
		errors.append("Retreat threshold must be between 0.0 and 1.0")
	
	return errors

## Faction Relationship Functions

func is_hostile_to(faction_name: String) -> bool:
	"""Check if this faction is hostile to another faction.
	Args:
		faction_name: Name of the faction to check
	Returns:
		true if this faction attacks the specified faction"""
	
	return faction_name in attacks

func add_enemy_faction(faction_name: String) -> void:
	"""Add a faction to the enemies list.
	Args:
		faction_name: Name of the faction to add as enemy"""
	
	if faction_name not in attacks:
		attacks.append(faction_name)

func remove_enemy_faction(faction_name: String) -> void:
	"""Remove a faction from the enemies list.
	Args:
		faction_name: Name of the faction to remove as enemy"""
	
	var index: int = attacks.find(faction_name)
	if index >= 0:
		attacks.remove_at(index)

func set_sees_as_color(faction_name: String, color: Color) -> void:
	"""Set how this faction sees another faction (color coding).
	Args:
		faction_name: Name of the faction
		color: Color to display for that faction"""
	
	sees_as[faction_name] = color

func get_sees_as_color(faction_name: String) -> Color:
	"""Get the color this faction uses to see another faction.
	Args:
		faction_name: Name of the faction to check
	Returns:
		Color used to display the faction, or default color if not specified"""
	
	return sees_as.get(faction_name, iff_color)

func get_relationship_status(reputation: float) -> String:
	"""Get relationship status based on reputation.
	Args:
		reputation: Current reputation value (-100 to 100)
	Returns:
		String describing the relationship status"""
	
	if reputation >= ally_threshold:
		return "ally"
	elif reputation >= friendly_threshold:
		return "friendly"
	elif reputation >= hostile_threshold:
		return "neutral"
	else:
		return "hostile"

func is_ally(reputation: float) -> bool:
	"""Check if reputation indicates alliance.
	Args:
		reputation: Current reputation value
	Returns:
		true if reputation indicates alliance"""
	
	return reputation >= ally_threshold

func is_friendly(reputation: float) -> bool:
	"""Check if reputation indicates friendliness.
	Args:
		reputation: Current reputation value
	Returns:
		true if reputation indicates friendliness or better"""
	
	return reputation >= friendly_threshold

func is_neutral(reputation: float) -> bool:
	"""Check if reputation indicates neutrality.
	Args:
		reputation: Current reputation value
	Returns:
		true if reputation indicates neutrality"""
	
	return reputation >= hostile_threshold and reputation < friendly_threshold

func is_hostile(reputation: float) -> bool:
	"""Check if reputation indicates hostility.
	Args:
		reputation: Current reputation value
	Returns:
		true if reputation indicates hostility"""
	
	return reputation < hostile_threshold

## Color Management Functions

func get_faction_color(context: String = "default") -> Color:
	"""Get faction color for specific context.
	Args:
		context: Context for color usage ("selection", "message", "tagged", "default")
	Returns:
		Appropriate color for the context"""
	
	match context:
		"selection":
			return selection_color
		"message":
			return message_color
		"tagged":
			return tagged_color
		"missile":
			return missile_blip_color
		"navbuoy":
			return navbuoy_blip_color
		"warping":
			return warping_blip_color
		"node":
			return node_blip_color
		"tagged_blip":
			return tagged_blip_color
		_:
			return iff_color

func set_faction_color(context: String, color: Color) -> void:
	"""Set faction color for specific context.
	Args:
		context: Context for color usage
		color: Color to set"""
	
	match context:
		"selection":
			selection_color = color
		"message":
			message_color = color
		"tagged":
			tagged_color = color
		"missile":
			missile_blip_color = color
		"navbuoy":
			navbuoy_blip_color = color
		"warping":
			warping_blip_color = color
		"node":
			node_blip_color = color
		"tagged_blip":
			tagged_blip_color = color
		"default":
			iff_color = color

func get_dimmed_color(base_color: Color) -> Color:
	"""Get dimmed version of a color based on IFF brightness setting.
	Args:
		base_color: Original color to dim
	Returns:
		Dimmed color"""
	
	return Color(
		base_color.r * dimmed_iff_brightness,
		base_color.g * dimmed_iff_brightness,
		base_color.b * dimmed_iff_brightness,
		base_color.a
	)

## Flag Management Functions

func has_flag(flag_name: String) -> bool:
	"""Check if faction has a specific flag.
	Args:
		flag_name: Name of the flag to check
	Returns:
		true if flag is present"""
	
	return flag_name in iff_flags

func add_flag(flag_name: String) -> void:
	"""Add a flag to the faction.
	Args:
		flag_name: Name of the flag to add"""
	
	if flag_name not in iff_flags:
		iff_flags.append(flag_name)

func remove_flag(flag_name: String) -> void:
	"""Remove a flag from the faction.
	Args:
		flag_name: Name of the flag to remove"""
	
	var index: int = iff_flags.find(flag_name)
	if index >= 0:
		iff_flags.remove_at(index)

## Communication Functions

func can_communicate() -> bool:
	"""Check if this faction accepts communication.
	Returns:
		true if faction accepts hails"""
	
	return accepts_hails

func get_hail_response_frequency() -> float:
	"""Get frequency of hail responses.
	Returns:
		Message frequency multiplier"""
	
	return message_frequency if accepts_hails else 0.0

## Tactical Behavior Functions

func get_effective_aggression(base_aggression: float) -> float:
	"""Calculate effective aggression level.
	Args:
		base_aggression: Base aggression value
	Returns:
		Modified aggression level"""
	
	return base_aggression * aggression_level

func should_pursue(distance: float) -> bool:
	"""Check if faction should pursue targets at given distance.
	Args:
		distance: Distance to target in meters
	Returns:
		true if should pursue"""
	
	return distance <= pursuit_distance

func should_retreat(hull_percentage: float) -> bool:
	"""Check if faction should retreat based on hull damage.
	Args:
		hull_percentage: Current hull as percentage (0.0 to 1.0)
	Returns:
		true if should retreat"""
	
	return hull_percentage <= retreat_threshold

## Utility Functions

func get_display_name() -> String:
	"""Get faction display name.
	Returns:
		Faction name for UI display"""
	
	return iff_name if not iff_name.is_empty() else "Unknown Faction"

func get_enemy_count() -> int:
	"""Get number of enemy factions.
	Returns:
		Count of factions in attacks list"""
	
	return attacks.size()

func get_allied_factions() -> Array[String]:
	"""Get list of factions this faction sees as allies.
	Returns:
		Array of faction names that are not in attacks list"""
	
	var allies: Array[String] = []
	
	for faction in sees_as.keys():
		if faction not in attacks:
			allies.append(faction)
	
	return allies

## Enhanced memory size calculation
func get_memory_size() -> int:
	"""Calculate estimated memory usage for this IFF data.
	Returns:
		Estimated memory size in bytes"""
	
	var size: int = super.get_memory_size()
	
	# Add IFF-specific data sizes
	size += iff_name.length() + hail_response_type.length() + formation_preference.length()
	
	# Color properties (8 Color objects, ~16 bytes each)
	size += 8 * 16
	
	# Arrays
	size += attacks.size() * 20  # Estimate 20 bytes per faction name
	size += iff_flags.size() * 15  # Estimate 15 bytes per flag
	
	# Dictionary (sees_as)
	size += sees_as.size() * 35  # Estimate 35 bytes per entry (name + color)
	
	# Float properties (8 floats)
	size += 8 * 8  # 64 bytes for float properties
	
	return size

## Conversion utilities

func to_dictionary() -> Dictionary:
	"""Convert IFF data to dictionary representation.
	Returns:
		Complete dictionary representation of IFF data"""
	
	var dict: Dictionary = super.to_dictionary()
	
	# Add IFF-specific fields
	dict["iff_name"] = iff_name
	dict["selection_color"] = var_to_str(selection_color)
	dict["message_color"] = var_to_str(message_color)
	dict["tagged_color"] = var_to_str(tagged_color)
	dict["iff_color"] = var_to_str(iff_color)
	dict["missile_blip_color"] = var_to_str(missile_blip_color)
	dict["navbuoy_blip_color"] = var_to_str(navbuoy_blip_color)
	dict["warping_blip_color"] = var_to_str(warping_blip_color)
	dict["node_blip_color"] = var_to_str(node_blip_color)
	dict["tagged_blip_color"] = var_to_str(tagged_blip_color)
	dict["dimmed_iff_brightness"] = dimmed_iff_brightness
	dict["use_alternate_blip_coloring"] = use_alternate_blip_coloring
	dict["attacks"] = attacks
	dict["sees_as"] = sees_as
	dict["iff_flags"] = iff_flags
	dict["default_reputation"] = default_reputation
	dict["aggression_level"] = aggression_level
	dict["formation_preference"] = formation_preference
	
	return dict

func apply_from_dictionary(dict: Dictionary) -> void:
	"""Apply IFF data from dictionary representation.
	Args:
		dict: Dictionary containing IFF data"""
	
	super.apply_from_dictionary(dict)
	
	# Apply IFF-specific fields
	iff_name = dict.get("iff_name", "")
	dimmed_iff_brightness = dict.get("dimmed_iff_brightness", 0.5)
	use_alternate_blip_coloring = dict.get("use_alternate_blip_coloring", false)
	attacks = dict.get("attacks", [])
	sees_as = dict.get("sees_as", {})
	iff_flags = dict.get("iff_flags", [])
	default_reputation = dict.get("default_reputation", 0.0)
	aggression_level = dict.get("aggression_level", 1.0)
	formation_preference = dict.get("formation_preference", "standard")
	
	# Handle color conversions if they exist
	if "selection_color" in dict:
		selection_color = str_to_var(dict["selection_color"])
	if "message_color" in dict:
		message_color = str_to_var(dict["message_color"])
	if "tagged_color" in dict:
		tagged_color = str_to_var(dict["tagged_color"])
	if "iff_color" in dict:
		iff_color = str_to_var(dict["iff_color"])