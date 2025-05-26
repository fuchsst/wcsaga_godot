class_name WeaponClassData
extends AssetData

## Weapon class data resource for WCS weapon definitions.
## Contains all necessary information for weapon classes including
## damage characteristics, ammunition, and compatibility requirements.

@export var weapon_name: String = ""
@export var weapon_type: String = ""  # Primary, Secondary, Turret
@export var damage_type: String = ""  # Energy, Kinetic, Missile
@export var damage_per_shot: float = 0.0
@export var firing_rate: float = 0.0  # shots per second
@export var energy_consumed: float = 0.0  # energy per shot

# Ammunition and capacity
@export var uses_ammunition: bool = false
@export var ammunition_capacity: int = 0
@export var ammunition_type: String = ""

# Range and accuracy
@export var weapon_range: float = 0.0
@export var projectile_speed: float = 0.0
@export var accuracy_rating: float = 1.0  # 0.0 to 1.0

# Special properties
@export var is_beam_weapon: bool = false
@export var is_seeking_weapon: bool = false
@export var area_of_effect: float = 0.0
@export var special_effects: Array[String] = []

# Compatibility
@export var compatible_ship_types: Array[String] = []
@export var faction_restrictions: Array[String] = []
@export var minimum_ship_class: String = ""

# Model and visual
@export var projectile_model: String = ""
@export var muzzle_flash_effect: String = ""
@export var impact_effect: String = ""
@export var sound_effect: String = ""

func _init() -> void:
	super()
	asset_type = "weapon_class"
	weapon_name = ""
	weapon_type = ""
	damage_type = ""
	damage_per_shot = 10.0
	firing_rate = 2.0
	energy_consumed = 5.0
	uses_ammunition = false
	ammunition_capacity = 0
	ammunition_type = ""
	weapon_range = 1000.0
	projectile_speed = 500.0
	accuracy_rating = 1.0
	is_beam_weapon = false
	is_seeking_weapon = false
	area_of_effect = 0.0
	special_effects = []
	compatible_ship_types = []
	faction_restrictions = []
	minimum_ship_class = ""
	projectile_model = ""
	muzzle_flash_effect = ""
	impact_effect = ""
	sound_effect = ""

## Get display name using weapon name if available
func get_display_name() -> String:
	return weapon_name if not weapon_name.is_empty() else asset_name

## Get weapon type classification
func get_weapon_type() -> String:
	return weapon_type

## Get damage type
func get_damage_type() -> String:
	return damage_type

## Get damage per shot
func get_damage_per_shot() -> float:
	return damage_per_shot

## Get firing rate in shots per second
func get_firing_rate() -> float:
	return firing_rate

## Get DPS (damage per second)
func get_dps() -> float:
	return damage_per_shot * firing_rate

## Get energy consumption per shot
func get_energy_consumption() -> float:
	return energy_consumed

## Get weapon range
func get_weapon_range() -> float:
	return weapon_range

## Check if this weapon requires ammunition
func requires_ammunition() -> bool:
	return uses_ammunition

## Check if this is a primary weapon
func is_primary_weapon() -> bool:
	return weapon_type == "Primary"

## Check if this is a secondary weapon
func is_secondary_weapon() -> bool:
	return weapon_type == "Secondary"

## Check if this is a turret weapon
func is_turret_weapon() -> bool:
	return weapon_type == "Turret"

## Check if this weapon is compatible with a ship type
func is_compatible_with_ship(ship_type: String) -> bool:
	if compatible_ship_types.is_empty():
		return true  # No restrictions
	return ship_type in compatible_ship_types

## Check if this weapon is allowed for a faction
func is_allowed_for_faction(faction: String) -> bool:
	if faction_restrictions.is_empty():
		return true  # No restrictions
	return faction in faction_restrictions

## Get weapon effectiveness rating based on target type
func get_effectiveness_vs_target(target_type: String) -> float:
	# Basic effectiveness calculation
	match damage_type:
		"Energy":
			match target_type:
				"Fighter":
					return 1.2
				"Bomber":
					return 1.0
				"Cruiser":
					return 0.8
				_:
					return 1.0
		"Kinetic":
			match target_type:
				"Fighter":
					return 0.8
				"Bomber":
					return 1.0
				"Cruiser":
					return 1.2
				_:
					return 1.0
		"Missile":
			match target_type:
				"Fighter":
					return 1.0
				"Bomber":
					return 1.5
				"Cruiser":
					return 1.8
				_:
					return 1.0
		_:
			return 1.0

## Validate weapon class data
func validate() -> Dictionary:
	var result: Dictionary = super.validate()
	
	if weapon_name.is_empty():
		result.is_valid = false
		result.errors.append("Weapon name cannot be empty")
	
	if weapon_type.is_empty():
		result.is_valid = false
		result.errors.append("Weapon type cannot be empty")
	
	if not weapon_type in ["Primary", "Secondary", "Turret"]:
		result.is_valid = false
		result.errors.append("Weapon type must be Primary, Secondary, or Turret")
	
	if damage_type.is_empty():
		result.is_valid = false
		result.errors.append("Damage type cannot be empty")
	
	if damage_per_shot <= 0.0:
		result.is_valid = false
		result.errors.append("Damage per shot must be greater than 0")
	
	if firing_rate <= 0.0:
		result.is_valid = false
		result.errors.append("Firing rate must be greater than 0")
	
	if energy_consumed < 0.0:
		result.is_valid = false
		result.errors.append("Energy consumption cannot be negative")
	
	if weapon_range <= 0.0:
		result.is_valid = false
		result.errors.append("Weapon range must be greater than 0")
	
	if projectile_speed <= 0.0:
		result.is_valid = false
		result.errors.append("Projectile speed must be greater than 0")
	
	if accuracy_rating < 0.0 or accuracy_rating > 1.0:
		result.is_valid = false
		result.errors.append("Accuracy rating must be between 0.0 and 1.0")
	
	if uses_ammunition and ammunition_capacity <= 0:
		result.is_valid = false
		result.errors.append("Ammunition capacity must be greater than 0 for ammo-based weapons")
	
	return result