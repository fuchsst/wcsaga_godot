class_name SpeciesData
extends BaseAssetData

## Species data resource for the WCS Asset Core addon.
## Comprehensive species specifications extracted from the existing WCS codebase.
## Contains all properties needed to define a species in the WCS-Godot conversion.

# Asset type setup
func _init() -> void:
	asset_type = AssetTypes.Type.SPECIES

## Species Information
@export var species_name: String = "" # species_defs.Name
@export var fred_species_name: String = "" # species_defs.FRED_Name

## Thruster Animations
@export var thruster_pri_normal: String = "" # species_defs.ThrustAnims.Pri_Normal
@export var thruster_pri_afterburn: String = "" # species_defs.ThrustAnims.Pri_Afterburn
@export var thruster_sec_normal: String = "" # species_defs.ThrustAnims.Sec_Normal
@export var thruster_sec_afterburn: String = "" # species_defs.ThrustAnims.Sec_Afterburn

## Thruster Glows
@export var thruster_glow_normal: String = "" # species_defs.ThrustGlows.Normal
@export var thruster_glow_afterburn: String = "" # species_defs.ThrustGlows.Afterburn

## Debris Properties
@export var max_debris_speed: float = 100.0 # species_defs.Max_debris_speed
@export var debris_damage_type: String = "" # species_defs.Debris_damage_type_str
@export var debris_damage_multiplier: float = 1.0 # species_defs.Debris_damage_mult
@export var debris_density: float = 1.0 # species_defs.Debris_density
@export var debris_fire_threshold: float = 50.0 # species_defs.Debris_fire_threshold
@export var debris_fire_spread: float = 0.1 # species_defs.Debris_fire_spread
@export var debris_fire_lifetime: float = 10.0 # species_defs.Debris_fire_lifetime

## Override validation to include species-specific checks
func get_validation_errors() -> Array[String]:
	"""Get validation errors specific to species data.
	Returns:
		Array of validation error messages"""
	
	var errors: Array[String] = super.get_validation_errors()
	
	# Species-specific validation
	if species_name.is_empty():
		errors.append("Species name is required")
	
	if max_debris_speed <= 0.0:
		errors.append("Max debris speed must be positive")
	
	if debris_damage_multiplier < 0.0:
		errors.append("Debris damage multiplier cannot be negative")
	
	if debris_density <= 0.0:
		errors.append("Debris density must be positive")
	
	if debris_fire_threshold < 0.0:
		errors.append("Debris fire threshold cannot be negative")
	
	if debris_fire_spread < 0.0 or debris_fire_spread > 1.0:
		errors.append("Debris fire spread must be between 0.0 and 1.0")
	
	if debris_fire_lifetime < 0.0:
		errors.append("Debris fire lifetime cannot be negative")
	
	return errors

## Species Configuration Functions

func has_thruster_animations() -> bool:
	"""Check if species has thruster animations configured.
	Returns:
		true if any thruster animations are defined"""
	
	return (not thruster_pri_normal.is_empty() or 
			not thruster_pri_afterburn.is_empty() or
			not thruster_sec_normal.is_empty() or
			not thruster_sec_afterburn.is_empty())

func has_thruster_glows() -> bool:
	"""Check if species has thruster glow textures configured.
	Returns:
		true if any thruster glows are defined"""
	
	return (not thruster_glow_normal.is_empty() or 
			not thruster_glow_afterburn.is_empty())

func get_primary_thruster_animation(afterburner: bool = false) -> String:
	"""Get primary thruster animation for current state.
	Args:
		afterburner: true if afterburner is active
	Returns:
		Animation filename for primary thrusters"""
	
	if afterburner and not thruster_pri_afterburn.is_empty():
		return thruster_pri_afterburn
	elif not thruster_pri_normal.is_empty():
		return thruster_pri_normal
	else:
		return ""

func get_secondary_thruster_animation(afterburner: bool = false) -> String:
	"""Get secondary thruster animation for current state.
	Args:
		afterburner: true if afterburner is active
	Returns:
		Animation filename for secondary thrusters"""
	
	if afterburner and not thruster_sec_afterburn.is_empty():
		return thruster_sec_afterburn
	elif not thruster_sec_normal.is_empty():
		return thruster_sec_normal
	else:
		return ""

func get_thruster_glow(afterburner: bool = false) -> String:
	"""Get thruster glow texture for current state.
	Args:
		afterburner: true if afterburner is active
	Returns:
		Glow texture filename"""
	
	if afterburner and not thruster_glow_afterburn.is_empty():
		return thruster_glow_afterburn
	elif not thruster_glow_normal.is_empty():
		return thruster_glow_normal
	else:
		return ""

## Debris System Functions

func calculate_debris_damage(base_damage: float) -> float:
	"""Calculate debris damage with species multiplier.
	Args:
		base_damage: Base debris damage amount
	Returns:
		Actual debris damage after species modifier"""
	
	return base_damage * debris_damage_multiplier

func is_debris_on_fire(damage_taken: float) -> bool:
	"""Check if debris should catch fire based on damage.
	Args:
		damage_taken: Amount of damage taken
	Returns:
		true if debris should catch fire"""
	
	return damage_taken >= debris_fire_threshold

func calculate_fire_spread_chance() -> float:
	"""Get fire spread chance for this species.
	Returns:
		Fire spread probability (0.0 to 1.0)"""
	
	return debris_fire_spread

func get_debris_speed_range() -> Vector2:
	"""Get debris speed range for this species.
	Returns:
		Vector2 with min and max debris speeds"""
	
	# Use a reasonable range based on max speed
	var min_speed: float = max_debris_speed * 0.1
	return Vector2(min_speed, max_debris_speed)

## Utility Functions

func get_display_name() -> String:
	"""Get species display name.
	Returns:
		Species name for UI display"""
	
	return species_name if not species_name.is_empty() else "Unknown Species"

func get_editor_name() -> String:
	"""Get species name for mission editor.
	Returns:
		FRED species name if available, otherwise display name"""
	
	return fred_species_name if not fred_species_name.is_empty() else get_display_name()

func is_compatible_with_ship(ship_species: String) -> bool:
	"""Check if this species is compatible with a ship.
	Args:
		ship_species: Species name from ship data
	Returns:
		true if compatible"""
	
	return (ship_species == species_name or 
			ship_species == fred_species_name or
			ship_species.is_empty())  # Empty species means generic

## Enhanced memory size calculation
func get_memory_size() -> int:
	"""Calculate estimated memory usage for this species data.
	Returns:
		Estimated memory size in bytes"""
	
	var size: int = super.get_memory_size()
	
	# Add species-specific data sizes
	size += species_name.length() + fred_species_name.length()
	size += thruster_pri_normal.length() + thruster_pri_afterburn.length()
	size += thruster_sec_normal.length() + thruster_sec_afterburn.length()
	size += thruster_glow_normal.length() + thruster_glow_afterburn.length()
	size += debris_damage_type.length()
	
	# Numeric properties (8 floats)
	size += 8 * 8  # 64 bytes for float properties
	
	return size

## Conversion utilities

func to_dictionary() -> Dictionary:
	"""Convert species data to dictionary representation.
	Returns:
		Complete dictionary representation of species data"""
	
	var dict: Dictionary = super.to_dictionary()
	
	# Add species-specific fields
	dict["species_name"] = species_name
	dict["fred_species_name"] = fred_species_name
	dict["thruster_pri_normal"] = thruster_pri_normal
	dict["thruster_pri_afterburn"] = thruster_pri_afterburn
	dict["thruster_sec_normal"] = thruster_sec_normal
	dict["thruster_sec_afterburn"] = thruster_sec_afterburn
	dict["thruster_glow_normal"] = thruster_glow_normal
	dict["thruster_glow_afterburn"] = thruster_glow_afterburn
	dict["max_debris_speed"] = max_debris_speed
	dict["debris_damage_type"] = debris_damage_type
	dict["debris_damage_multiplier"] = debris_damage_multiplier
	dict["debris_density"] = debris_density
	dict["debris_fire_threshold"] = debris_fire_threshold
	dict["debris_fire_spread"] = debris_fire_spread
	dict["debris_fire_lifetime"] = debris_fire_lifetime
	
	return dict

func apply_from_dictionary(dict: Dictionary) -> void:
	"""Apply species data from dictionary representation.
	Args:
		dict: Dictionary containing species data"""
	
	super.apply_from_dictionary(dict)
	
	# Apply species-specific fields
	species_name = dict.get("species_name", "")
	fred_species_name = dict.get("fred_species_name", "")
	thruster_pri_normal = dict.get("thruster_pri_normal", "")
	thruster_pri_afterburn = dict.get("thruster_pri_afterburn", "")
	thruster_sec_normal = dict.get("thruster_sec_normal", "")
	thruster_sec_afterburn = dict.get("thruster_sec_afterburn", "")
	thruster_glow_normal = dict.get("thruster_glow_normal", "")
	thruster_glow_afterburn = dict.get("thruster_glow_afterburn", "")
	max_debris_speed = dict.get("max_debris_speed", 100.0)
	debris_damage_type = dict.get("debris_damage_type", "")
	debris_damage_multiplier = dict.get("debris_damage_multiplier", 1.0)
	debris_density = dict.get("debris_density", 1.0)
	debris_fire_threshold = dict.get("debris_fire_threshold", 50.0)
	debris_fire_spread = dict.get("debris_fire_spread", 0.1)
	debris_fire_lifetime = dict.get("debris_fire_lifetime", 10.0)