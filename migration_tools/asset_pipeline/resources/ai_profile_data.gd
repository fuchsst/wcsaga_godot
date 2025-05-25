class_name AIProfileData
extends Resource

## WCS AI profile data resource containing AI behavior definitions from ai_profiles.tbl
## Defines how AI pilots behave in various combat and navigation scenarios

@export var profile_name: String = ""
@export var description: String = ""

# Basic AI skill parameters
@export var skill_level: int = 3  # 1-5 skill range (1=Rookie, 5=Ace)
@export var accuracy: float = 0.7  # Base accuracy multiplier
@export var evasion: float = 0.5  # Evasion capability
@export var courage: float = 0.5  # Willingness to engage
@export var patience: float = 0.5  # How long AI waits before acting

# Combat behavior
@export var max_attacking: int = 3  # Maximum ships that can attack single target
@export var max_attackers: int = 4  # Maximum attackers per target
@export var max_incoming_asteroids: int = 3  # Max asteroids AI will track
@export var max_attacking_big_ships: int = 2  # Max ships attacking capital ships
@export var max_attacking_small_ships: int = 6  # Max ships attacking fighters

# Turning and maneuvering
@export var turn_time_mult: float = 1.0  # Turn time multiplier
@export var glide_attack_percent: float = 0.0  # Glide usage in attacks
@export var circle_strafe_percent: float = 0.0  # Circle strafing usage
@export var glide_strafe_percent: float = 0.0  # Glide strafing usage
@export var random_sidethrust_percent: float = 0.0  # Random sidethrust usage
@export var stalemate_time_thresh: float = 0.0  # Stalemate detection time
@export var stalemate_dist_thresh: float = 0.0  # Stalemate distance threshold

# Afterburner usage
@export var afterburner_use_factor: float = 1.0  # Afterburner usage multiplier
@export var afterburner_rec_time: float = 2.0  # Recovery time after afterburner

# Shockwave avoidance
@export var shockwave_dodge_percent: float = 0.0  # Shockwave dodge chance
@export var get_away_chance: float = 0.0  # Chance to retreat
@export var secondary_range_mult: float = 1.0  # Secondary weapon range multiplier

# Advanced AI flags and behaviors
@export var flags: int = 0  # AI behavior flags bitmask

# Combat tactics
@export var auto_target_asteroid_preference: float = 0.0  # Asteroid targeting
@export var auto_target_capship_preference: float = 0.5  # Capital ship targeting
@export var auto_target_fighter_preference: float = 1.0  # Fighter targeting
@export var auto_target_transport_preference: float = 0.3  # Transport targeting

# Formation flying
@export var formation_flying_factor: float = 1.0  # Formation adherence
@export var formation_break_chance: float = 0.1  # Chance to break formation

# Weapon usage preferences
@export var primary_weapon_switch_time: float = 5.0  # Time between weapon switches
@export var secondary_weapon_switch_time: float = 3.0  # Secondary weapon switch time
@export var weapon_energy_conservation: float = 0.5  # Energy conservation level

# Target acquisition
@export var target_value_distance_factor: float = 1.0  # Distance affects target value
@export var target_value_dot_factor: float = 1.0  # Facing affects target value
@export var target_value_current_target_factor: float = 1.5  # Current target bias

# Countermeasures
@export var cmeasure_life_scale: float = 1.0  # Countermeasure effectiveness scale
@export var cmeasure_fire_chance: float = 0.7  # Chance to fire countermeasures

# Ship-specific modifiers
@export var big_ship_attack_scale: float = 1.0  # Big ship attack behavior scale
@export var kamikaze_damage_scale: float = 1.0  # Kamikaze damage threshold scale
@export var disable_retreat: bool = false  # Prevent AI from retreating

func _init() -> void:
	# Set reasonable default values
	pass

## Utility functions for AI profile

func get_effective_accuracy(base_accuracy: float) -> float:
	"""Calculate effective accuracy with AI skill modifiers."""
	var skill_modifier: float = 0.6 + (float(skill_level) * 0.1)  # 0.7 to 1.1 range
	return base_accuracy * accuracy * skill_modifier

func get_effective_evasion() -> float:
	"""Get effective evasion rating."""
	var skill_modifier: float = 0.5 + (float(skill_level) * 0.1)  # 0.6 to 1.0 range
	return evasion * skill_modifier

func get_effective_reaction_time() -> float:
	"""Get AI reaction time in seconds."""
	var base_reaction: float = 1.0  # Base 1 second reaction
	var skill_modifier: float = 1.5 - (float(skill_level) * 0.2)  # 1.3 to 0.7 range
	return base_reaction * skill_modifier * (2.0 - patience)

func should_use_afterburner(fuel_remaining: float) -> bool:
	"""Determine if AI should use afterburner."""
	if fuel_remaining <= 0.0:
		return false
	
	var use_threshold: float = 0.3 + (afterburner_use_factor * 0.4)
	return randf() < use_threshold

func should_dodge_shockwave() -> bool:
	"""Determine if AI should attempt shockwave dodge."""
	return randf() < shockwave_dodge_percent

func should_retreat(hull_percent: float, shield_percent: float) -> bool:
	"""Determine if AI should retreat from combat."""
	if disable_retreat:
		return false
	
	var danger_level: float = 1.0 - ((hull_percent + shield_percent) / 2.0)
	var retreat_threshold: float = (1.0 - courage) * 0.7
	
	return danger_level > retreat_threshold and randf() < get_away_chance

func get_target_preference(target_type: String) -> float:
	"""Get AI preference for targeting specific ship types."""
	match target_type.to_lower():
		"fighter", "interceptor":
			return auto_target_fighter_preference
		"bomber", "assault":
			return auto_target_fighter_preference * 1.2  # Slightly prefer bombers
		"corvette", "cruiser", "destroyer":
			return auto_target_capship_preference
		"freighter", "transport":
			return auto_target_transport_preference
		"asteroid":
			return auto_target_asteroid_preference
		_:
			return 0.5

func get_weapon_switch_time(is_primary: bool) -> float:
	"""Get time between weapon switches."""
	var base_time: float = primary_weapon_switch_time if is_primary else secondary_weapon_switch_time
	var skill_modifier: float = 1.5 - (float(skill_level) * 0.2)  # Skilled pilots switch faster
	return base_time * skill_modifier

func get_formation_adherence() -> float:
	"""Get how well AI follows formation."""
	return formation_flying_factor * (0.5 + float(skill_level) * 0.1)

func should_break_formation() -> bool:
	"""Determine if AI should break formation."""
	var skill_factor: float = float(skill_level) / 5.0
	var adjusted_chance: float = formation_break_chance * (1.0 - skill_factor)
	return randf() < adjusted_chance

func get_combat_aggressiveness() -> float:
	"""Get overall combat aggressiveness rating."""
	return (courage + accuracy) / 2.0

func get_skill_description() -> String:
	"""Get human-readable skill level description."""
	match skill_level:
		1:
			return "Rookie"
		2:
			return "Veteran"
		3:
			return "Officer"
		4:
			return "Ace"
		5:
			return "Supreme"
		_:
			return "Unknown"

func is_ace_pilot() -> bool:
	"""Check if this is an ace-level pilot."""
	return skill_level >= 4

func is_rookie_pilot() -> bool:
	"""Check if this is a rookie pilot."""
	return skill_level <= 1

func get_countermeasure_timing() -> float:
	"""Get optimal countermeasure firing time."""
	var base_timing: float = 0.8  # Fire at 80% of incoming missile time
	var skill_adjustment: float = float(skill_level) * 0.05  # Skilled pilots wait longer
	return base_timing + skill_adjustment

func clone_with_skill_adjustment(skill_adjustment: int) -> AIProfileData:
	"""Create a copy with adjusted skill level."""
	var clone: AIProfileData = AIProfileData.new()
	
	# Copy all properties
	clone.profile_name = profile_name + " (Modified)"
	clone.description = description
	clone.skill_level = clampi(skill_level + skill_adjustment, 1, 5)
	clone.accuracy = accuracy
	clone.evasion = evasion
	clone.courage = courage
	clone.patience = patience
	
	# Adjust skill-dependent values
	var skill_factor: float = float(clone.skill_level) / float(skill_level)
	clone.afterburner_use_factor = afterburner_use_factor * skill_factor
	clone.cmeasure_fire_chance = cmeasure_fire_chance * skill_factor
	clone.formation_flying_factor = formation_flying_factor * skill_factor
	
	return clone

func to_debug_string() -> String:
	"""Get debug information about this AI profile."""
	var debug_info: Array[String] = []
	
	debug_info.append("AI Profile: %s (%s)" % [profile_name, get_skill_description()])
	debug_info.append("Accuracy: %.1f%%, Evasion: %.1f%%" % [accuracy * 100, evasion * 100])
	debug_info.append("Courage: %.1f%%, Patience: %.1f%%" % [courage * 100, patience * 100])
	debug_info.append("Combat Style: %s" % ("Aggressive" if get_combat_aggressiveness() > 0.7 else "Defensive" if get_combat_aggressiveness() < 0.3 else "Balanced"))
	
	return "\n".join(debug_info)