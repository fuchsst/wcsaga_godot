# Enhanced ShipStats Resource with advanced validation and cross-references
# This resource represents comprehensive ship configuration from ships.tbl
class_name ShipStats
extends WCSDataResource

# Identity and classification
@export var ship_class: String = ""  # Military designation (F-86C Hellcat V)
@export var display_name: String = ""  # Common name (Hellcat V)
@export var species: String = ""  # Cross-reference to SpeciesData resource_path
@export var ship_role: int = 0  # 0=Fighter, 1=Bomber, 2=Capital, 3=Support
@export var ship_tier: String = ""  # Light, Medium, Heavy suffixes

# Physical specifications (from POF geometry)
@export var model_file: String = "" # Cross-reference to POF resource_path
@export var length_meters: float = 0.0
@export var mass_tons: float = 0.0
@export var armor_thickness: Dictionary = {
	"fore_cm": 0.0,
	"aft_cm": 0.0,
	"left_cm": 0.0,
	"right_cm": 0.0,
	"top_cm": 0.0,
	"bottom_cm": 0.0
}

# Movement and performance (6DOF physics)
@export var max_velocity: Vector3 = Vector3(0, 0, 66.31)  # m/s
@export var afterburner_velocity: Vector3 = Vector3(0, 0, 189.47)
@export var rotation_time: Vector3 = Vector3(6.0, 6.0, 6.0)  # seconds for 360° in pitch/yaw/roll
@export var movement_dampening: float = 0.6
@export var rotational_dampening: float = 1.2

# Shield systems
@export var shield_strength: int = 880  # Maximum shield hitpoints
@export var shield_regen_rate: float = 0.05  # Percent of max per second
@export var shield_color_primary: Color = Color(0, 100, 255, 255)
@export var shield_color_secondary: Color = Color(150, 200, 255, 255)
@export var shield_impact_sounds: Array[String] = []  # Cross-references to audio resources

# Hull integrity
@export var hull_hitpoints: int = 360
@export var subsystem_hitpoints: Dictionary = {}  # Subsystem name -> hitpoints
@export var explosion_effect: String = "" # Cross-reference to effect resource

# Weapon systems with cross-references
@export var allowed_primary_weapons: Array[String] = [] # Cross-references to WeaponData resources
@export var allowed_secondary_weapons: Array[String] = [] # Cross-references to WeaponData resources
@export var default_primary_loadouts: Array[String] = [] # Default weapon assignments
@export var default_secondary_loadouts: Array[String] = []
@export var weapon_mounts: Array[WeaponMount] = []

# Energy and power management
@export var max_weapon_energy: int = 60
@export var max_afterburner_fuel: float = 100.0
@export var energy_regen_rate: float = 2.5  # Energy per second
@export var reactor_type: String = "" # Cross-reference power system

# AI behavior parameters
@export var ai_aggressiveness: float = 0.5  # 0.0-1.0
@export var ai_skill_level: float = 0.8  # 0.0-1.0
@export var ai_reaction_time: float = 0.5  # seconds
@export var ai_optimal_range: float = 600.0  # meters

# Gameplay flags
@export var is_player_allowed: bool = true
@export var is_civilian: bool = false
@export var is_stealth: bool = false
@export var cargo_space: int = 0

signal validation_changed

class WeaponMount extends Resource:
	var mount_type: int = 0  # 0=Primary, 1=Secondary, 2=Special
	var position: Vector3 = Vector3.ZERO# Local coordinates on model
	var weapon_class: String = "" # Allowed weapon categories
	var fire_cooldown: float = 0.35
	var damage_multiplier: float = 1.0

func validate() -> bool:
	"""Enhanced validation with cross-reference checking"""
	validation_errors.clear()
	conversion_notes.clear()

	# Call parent validation
	if not super.validate():
		return false

	# Validate required fields
	if ship_class.is_empty():
		_add_validation_error("Ship class cannot be empty")

	if model_file.is_empty():
		_add_validation_error("Model file reference required")
	else:
		validate_cross_reference("model_file", model_file, "model must exist")

	# Validate weapon mounts
	for mount in weapon_mounts:
		if mount.weapon_class.is_empty():
			_add_validation_error("Weapon mount without specified class found")

	# Validate cross-referenced arrays
	validate_weapon_references()
	validate_species_reference()

	is_valid = validation_errors.size() == 0
	validation_changed.emit()
	return is_valid

func validate_cross_reference(ref_name: String, resource_path: String, error_context: String) -> void:
	"""Validate that a cross-referenced resource exists"""
	if not ResourceLoader.exists(resource_path):
		_add_validation_error("%s: %s" % [error_context, resource_path])

func validate_weapon_references() -> void:
	"""Validate all weapon cross-references"""
	var weapon_paths = allowed_primary_weapons + allowed_secondary_weapons
	for weapon_path in weapon_paths:
		if not weapon_path.is_empty():
			validate_cross_reference("weapon_ref", weapon_path, "Weapon reference invalid")

func validate_species_reference() -> void:
	"""Validate species cross-reference"""
	if not species.is_empty():
		validate_cross_reference("species", species, "Species reference invalid")
