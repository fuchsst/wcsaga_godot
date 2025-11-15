# Species data for faction-specific attributes and behaviors
# Cross-referenced by ships, weapons, and other game entities
class_name SpeciesData
extends WCSDataResource

# Species identity
@export var species_name: String = ""           # Display name (Terran, Kilrathi, etc.)
@export var species_id: int = 0                 # Internal species identifier
@export var is_playable: bool = false           # Can player choose this species
@export var home_world: String = ""             # Cross-reference to stellar objects

# Military and political attributes
@export var military_doctrine: String = ""       # Aggressive, Defensive, Balanced
@export var ship_design_philosophy: String = ""  # Speed vs Armor vs Firepower
@export var preferred_combat_range: float = 600.0  # Meters
@export var fighter_tactics: String = ""        # Swarm, Hit-and-run, Dogfighting
@export var capital_tactics: String = ""        # Broadside, Artillery, Carrier

# Technology characteristics
@export var energy_weapon_preference: float = 0.5        # 0.0=Kinetic, 1.0=Energy
@export var shield_technology_level: int = 3             # 1-5 scale
@export var armor_technology_level: int = 3              # 1-5 scale
@export var engine_technology_level: int = 3             # 1-5 scale
@export var ai_development_level: int = 3               # 1-5 scale

# Visual and cultural attributes
@export var hud_color_primary: Color = Color(0, 100, 255)      # Species HUD color
@export var hud_color_secondary: Color = Color(150, 200, 255)
@export var ship_styling: String = ""                             # Visual design themes
@export var preferred_materials: Array[String] = []               # Ship material preferences

# Diplomatic relationships
@export var default_iff_status: Dictionary = {}                   # Species -> relationship mapping
@export var alliance_demands: String = ""                        # Diplomatic requirements
@export var betrayal_tolerance: float = 0.2                     # 0.0=Unforgiving, 1.0=Always forgive

# Audio characteristics
@export var communication_sounds: Array[String] = []             # Cross-references to audio
@export var ship_interior_ambient: String = ""                   # Cross-reference to audio
@export var victory_music: String = ""                            # Cross-reference to music
@export var defeat_music: String = ""                            # Cross-reference to music

# Economic factors
@export var resource_efficiency: float = 1.0                       # Ship cost multiplier
@export var production_speed: float = 1.0                         # Build time multiplier
@export var repair_efficiency: float = 1.0                        # Repair speed multiplier
@export var trade_preferences: Array[String] = []                 # Preferred trade goods

func calculate_military_strength() -> float:
	"""Calculate overall military capability score"""
	return (shield_technology_level + armor_technology_level + engine_technology_level + ai_development_level) / 20.0

func get_ai_personality_type() -> String:
	"""Determine AI personality based on species characteristics"""
	if military_doctrine == "Aggressive":
		return "Aggressor"
	elif military_doctrine == "Defensive":
		return "Defender"
	else:
		return "Balanced"

func validate() -> bool:
	"""Validate species data integrity"""
	validation_errors.clear()
	conversion_notes.clear()

	# Call parent validation
	if not super.validate():
		return false

	# Require positive technology values
	var tech_levels = [shield_technology_level, armor_technology_level, engine_technology_level, ai_development_level]
	for level in tech_levels:
		if level < 1 or level > 5:
			_add_validation_error("Technology levels must be between 1 and 5")
			break

	# Validate relationship values
	for species in default_iff_status.keys():
		var relationship = default_iff_status[species]
		if relationship < -1.0 or relationship > 1.0:
			_add_validation_error("IFF relationships must be between -1.0 (hostile) and 1.0 (friendly)")
			break

	# Validate audio references
	validate_audio_reference("communication_sounds")
	validate_audio_reference("ship_interior_ambient")
	validate_audio_reference("victory_music")
	validate_audio_reference("defeat_music")

	return validation_errors.size() == 0