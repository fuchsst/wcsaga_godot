# SpeciesData - Comprehensive Faction Configuration Resource
# Represents complete species/faction data from Species_defs.tbl with political,
# military, and technological characteristics for Wing Commander Saga

class_name SpeciesData
extends "res://scripts/resources/core/wcs_base_resource.gd"

# === IDENTITY AND CULTURE ===
@export_group("Identity", "identity_")
@export var species_name: String = "" # Display name (Terran, Kilrathi)
@export var species_internal_id: int = 0 # Internal species identifier
@export var species_mnemonic: String = "" # Short code (TERRAN, KILRATHI)
@export var is_playable: bool = false # Available for player selection
@export var species_description: String = "" # General description of species
@export var cultural_background: String = "" # Cultural/historical background
@export var home_world_name: String = "" # Cross-reference to stellar object
@export var government_type: String = "" # Political system structure
@export var founding_year: int = 0 # Calendar year of founding

# === MILITARY DOCTRINE ===
@export_group("Military Doctrine", "military_")
@export var military_doctrine: String = "" # Aggressive, Defensive, Balanced
@export var ship_design_philosophy: String = "" # Speed vs Armor vs Firepower focus
@export var fleet_composition_preference: String = "" # Preferred fleet mix
@export var preferred_combat_range: float = 600.0 # Optimal engagement range (meters)
@export var fighter_tactics: String = "" # Swarm, Hit-and-run, Dogfighting
@export var capital_ship_tactics: String = "" # Broadside, Artillery, Carrier-based
@export var boarding_preference: String = "" # Boarding combat style
@export var retreat_threshold: float = 0.3 # When to retreat (0.0-1.0)

# === TECHNOLOGY LEVELS ===
@export_group("Technology", "tech_")
@export var energy_weapon_preference: float = 0.5 # 0.0=Kinetic, 1.0=Energy preference
@export var shield_technology_level: int = 3 # 1-5 scale
@export var armor_technology_level: int = 3 # 1-5 scale
@export var engine_technology_level: int = 3 # 1-5 scale
@export var ai_development_level: int = 3 # 1-5 scale
@export var sensor_technology_level: int = 3 # 1-5 scale
@export var communication_technology_level: int = 3 # 1-5 scale
@export var manufacturing_technology_level: int = 3 # 1-5 scale
@export var research_efficiency_level: int = 3 # 1-5 scale

# === SHIP CONSTRUCTION ===
@export_group("Shipbuilding", "shipbuilding_")
@export var preferred_ship_tonnage: String = "" # Light/Medium/Heavy preference
@export var ship_material_preferences: Array[String] = [] # Preferred construction materials
@export var reactor_type_preference: String = "" # Preferred power systems
@export var weapon_mount_style: String = "" # Preferred weapon configurations
@export var defensive_system_priority: String = "" # Shields vs Armor priority
@export var fighter_design_schools: Array[String] = [] # Fighter design philosophies
@export var capital_design_schools: Array[String] = [] # Capital ship design philosophies

# === VISUAL IDENTITY ===
@export_group("Visual Identity", "visual_")
@export var hull_color_primary: Color = Color(0, 100, 255) # Primary hull color
@export var hull_color_secondary: Color = Color(150, 200, 255) # Secondary hull color
@export var hud_color_primary: Color = Color(0, 100, 255) # Species UI color
@export var hud_color_secondary: Color = Color(150, 200, 255) # Secondary UI color
@export var engine_exhaust_color: Color = Color(255, 200, 0) # Engine exhaust color
@export var shield_visual_effect: String = "" # Cross-reference to effect
@export var ship_styling_keywords: Array[String] = [] # Visual design descriptors
@export var cultural_aesthetics: String = "" # Cultural design principles

# === DIPLOMATIC RELATIONSHIPS ===
@export_group("Diplomacy", "diplomacy_")
@export var default_iff_status: Dictionary = {} # Species -> relationship mapping
@export var diplomatic_stance: String = "" # Current diplomatic posture
@export var alliance_demands: Array[String] = [] # Requirements for alliance
@export var betrayal_tolerance: float = 0.2 # 0.0=Unforgiving, 1.0=Always forgive
@export var war_preparation_time_months: int = 6 # Months to prepare for war
@export var peace_negotiation_willingness: float = 0.5 # Willingness to negotiate peace
@export var trade_preference_list: Array[String] = [] # Preferred trade goods
@export var embargo_targets: Array[String] = [] # Who they embargo

# === AI PERSONALITY SYSTEM ===
@export_group("AI Personality", "ai_")
@export var base_ai_aggressiveness: float = 0.5 # Base aggression (0.0-1.0)
@export var base_ai_skill_level: float = 0.7 # Base skill (0.0-1.0)
@export var ai_reaction_time_factor: float = 1.0 # Reaction time multiplier
@export var ai_targeting_accuracy_bonus: float = 0.0 # Accuracy modifier
@export var ai_morale_factor: float = 1.0 # Morale effect on performance
@export var ai_tactical_adaptability: float = 0.5 # Adaptability to enemy tactics
@export var ai_resource_conservation: float = 0.6 # Ammunition/fuel conservation
@export var ai_specialization_focus: String = "" # Tactical specialization

# === ECONOMIC FACTORS ===
@export_group("Economics", "econ_")
@export var resource_efficiency_multiplier: float = 1.0 # Ship cost multiplier
@export var production_speed_multiplier: float = 1.0 # Build time multiplier
@export var repair_efficiency_multiplier: float = 1.0 # Repair speed multiplier
@export var research_cost_multiplier: float = 1.0 # Research cost modifier
@export var trade_efficiency_multiplier: float = 1.0 # Trade profit modifier
@export var population_growth_rate: float = 0.01 # Annual population growth
@export var technological_advancement_rate: float = 0.02 # Tech advancement speed

# === AUDIO CULTURE ===
@export_group("Audio Culture", "audio_")
@export var communication_sound_styles: Array[String] = [] # Cross-references to audio
@export var music_preferences: Array[String] = [] # Preferred musical styles
@export var victory_music_theme: String = "" # Cross-reference to music
@export var defeat_music_theme: String = "" # Cross-reference to music
@export var ambient_interior_sounds: Array[String] = [] # Ship interior ambience
@export var bridge_command_sounds: Array[String] = [] # Command acknowledgment sounds
@export var alert_sound_styles: Array[String] = [] # Alert notification styles

# === SPECIAL CAPABILITIES ===
@export_group("Special Abilities", "special_")
@export var has_cloaking_technology: bool = false # Access to cloaking tech
@export var has_energy_shielding: bool = true # Advanced shield systems
@export var has_jump_drive_technology: bool = false # Jump drive capability
@export var has_artificial_gravity: bool = true # Artificial gravity systems
@export var has_advanced_sensors: bool = false # Superior sensor technology
@export var has_psionic_technology: bool = false # Telepathic/psionic abilities
@export var special_weapon_access: Array[String] = [] # Unique weapon technologies
@export var unique_subsystems: Array[String] = [] # Species-specific subsystems

# === STRATEGIC INTELLIGENCE ===
@export_group("Strategic Intelligence", "strategic_")
@export var fleet_size_preference: int = 12 # Preferred squadron size
@export var formation_tactics: Array[String] = [] # Preferred formations
@export var escort_behavior: String = "" # Escort mission preferences
@export var patrol_patterns: Array[String] = [] # Patrol route preferences
@export var ambush_preference: float = 0.3 # Likelihood of ambush tactics
@export var hit_and_run_preference: float = 0.4 # Preference for hit-and-run
@export var resource_raiding_preference: float = 0.2 # Tendency to raid resources

# === HOMEWORLD CHARACTERISTICS ===
@export_group("Homeworld", "homeworld_")
@export var homeworld_climate: String = "" # Climate type
@export var homeworld_gravity: float = 1.0 # Standard gravity multiplier
@export var homeworld_atmosphere: String = "" # Atmosphere composition
@export var homeworld_temperature_range: Vector2 = Vector2(0, 30) # Temperature range
@export var homeworld_dominant_terrain: String = "" # Primary terrain type
@export var homeworld_special_conditions: Array[String] = [] # Special environmental conditions

# Validation signals
signal diplomacy_changed()
signal technology_level_changed()
signal military_doctrine_changed()
signal visual_identity_changed()

# ================== VALIDATION METHODS ==================

func get_resource_type() -> String:
	return "species_data"

func validate() -> bool:
	"""Comprehensive species data validation"""
	validation_errors.clear()
	validation_warnings.clear()

	# Call parent validation first
	if not super.validate():
		return false

	# Validate identity and culture
	_validate_identity()
	_validate_military_doctrine()
	_validate_technology_levels()
	_validate_shipbuilding_preferences()
	_validate_visual_identity()
	_validate_diplomatic_relationships()
	_validate_ai_personality()
	_validate_economic_factors()
	_validate_special_capabilities()
	_validate_audio_references()

	# Final validation status
	is_valid = validation_errors.size() == 0
	validation_status_changed.emit(is_valid)

	return is_valid

func _validate_identity() -> void:
	"""Validate species identity properties"""
	if species_name.is_empty():
		_add_validation_error("Species name cannot be empty")

	if species_mnemonic.is_empty():
		_add_validation_error("Species mnemonic is required")
	elif species_mnemonic.length() > 8:
		_add_validation_warning("Species mnemonic should be brief (≤8 characters)")

	if species_internal_id < 0:
		_add_validation_error("Species internal ID cannot be negative")

	if government_type.is_empty():
		_add_validation_warning("Government type not specified")

	if not home_world_name.is_empty():
		add_cross_reference_dependency("res://scripts/resources/stellar_object_data.gd")

func _validate_military_doctrine() -> void:
	"""Validate military doctrine properties"""
	var valid_doctrines = ["Aggressive", "Defensive", "Balanced", "Guerrilla", "Terror", ""]
	if not military_doctrine in valid_doctrines:
		_add_validation_error("Invalid military doctrine: %s" % military_doctrine)

	if preferred_combat_range <= 0:
		_add_validation_error("Preferred combat range must be positive")

	if retreat_threshold < 0 or retreat_threshold > 1:
		_add_validation_error("Retreat threshold must be between 0.0 and 1.0")

	var valid_tactics = ["Swarm", "Hit-and-run", "Dogfighting", "Boom-and-Zoom", "Energy Fighting"]
	if not fighter_tactics in valid_tactics and not fighter_tactics.is_empty():
		_add_validation_warning("Unknown fighter tactics: %s" % fighter_tactics)

	var valid_cap_tactics = ["Broadside", "Artillery", "Carrier-based", "Ramming", ""]
	if not capital_ship_tactics in valid_cap_tactics and not capital_ship_tactics.is_empty():
		_add_validation_warning("Unknown capital tactics: %s" % capital_ship_tactics)

func _validate_technology_levels() -> void:
	"""Validate technology level properties"""
	var tech_levels = [
		shield_technology_level,
		armor_technology_level,
		engine_technology_level,
		ai_development_level,
		sensor_technology_level,
		communication_technology_level,
		manufacturing_technology_level,
		research_efficiency_level
	]

	for level in tech_levels:
		if level < 1 or level > 5:
			_add_validation_error("Technology levels must be between 1 and 5")
			break

	if energy_weapon_preference < 0 or energy_weapon_preference > 1:
		_add_validation_error("Energy weapon preference must be between 0.0 and 1.0")

func _validate_shipbuilding_preferences() -> void:
	"""Validate shipbuilding preferences"""
	var valid_tonnages = ["Light", "Medium", "Heavy", "Mixed", ""]
	if not preferred_ship_tonnage in valid_tonnages:
		_add_validation_warning("Unknown ship tonnage preference: %s" % preferred_ship_tonnage)

	if ship_material_preferences.is_empty():
		_add_validation_warning("No ship material preferences specified")

func _validate_visual_identity() -> void:
	"""Validate visual identity properties"""
	# Validate HUD colors
	var primary_alpha = hud_color_primary.a
	var secondary_alpha = hud_color_secondary.a

	if primary_alpha < 0.5:
		_add_validation_warning("Primary HUD color may be too transparent")

	if secondary_alpha < 0.3:
		_add_validation_warning("Secondary HUD color may be too transparent")

	# Validate visual effect references
	if not shield_visual_effect.is_empty():
		add_cross_reference_dependency(shield_visual_effect)

func _validate_diplomatic_relationships() -> void:
	"""Validate diplomatic relationships"""
	# Validate individual relationship values
	for species in default_iff_status.keys():
		var relationship = default_iff_status[species]
		if relationship < -1.0 or relationship > 1.0:
			_add_validation_error("IFF relationships must be between -1.0 (hostile) and 1.0 (friendly)")
			break

	if war_preparation_time_months < 0:
		_add_validation_error("War preparation time cannot be negative")

	if peace_negotiation_willingness < 0 or peace_negotiation_willingness > 1:
		_add_validation_error("Peace negotiation willingness must be between 0.0 and 1.0")

	if betrayal_tolerance < 0 or betrayal_tolerance > 1:
		_add_validation_error("Betrayal tolerance must be between 0.0 and 1.0")

func _validate_ai_personality() -> void:
	"""Validate AI personality parameters"""
	var ai_params = [
		base_ai_aggressiveness,
		base_ai_skill_level,
		ai_targeting_accuracy_bonus,
		ai_morale_factor,
		ai_tactical_adaptability,
		ai_resource_conservation
	]

	for param in ai_params:
		if param < 0 or param > 1:
			_add_validation_error("AI personality parameters must be between 0.0 and 1.0")
			break

	if ai_reaction_time_factor <= 0:
		_add_validation_error("AI reaction time factor must be positive")

func _validate_economic_factors() -> void:
	"""Validate economic multipliers"""
	var economic_multipliers = [
		resource_efficiency_multiplier,
		production_speed_multiplier,
		repair_efficiency_multiplier,
		research_cost_multiplier,
		trade_efficiency_multiplier
	]

	for multiplier in economic_multipliers:
		if multiplier <= 0:
			_add_validation_error("Economic multipliers must be positive")
			break

	if population_growth_rate < 0 or population_growth_rate > 0.1:
		_add_validation_warning("Population growth rate seems unusual")

	if technological_advancement_rate < 0 or technological_advancement_rate > 0.1:
		_add_validation_warning("Technological advancement rate seems unusual")

func _validate_special_capabilities() -> void:
	"""Validate special capabilities"""
	if not special_weapon_access.is_empty():
		for weapon in special_weapon_access:
			add_cross_reference_dependency(weapon)
			
	if not unique_subsystems.is_empty():
		for subsystem in unique_subsystems:
			# Assuming subsystems might be resources too, but for now just check they are strings
			pass

func _validate_audio_references() -> void:
	"""Validate audio resource references"""
	var audio_refs = []
	audio_refs.append_array(communication_sound_styles)
	audio_refs.append_array(music_preferences)
	audio_refs.append_array(ambient_interior_sounds)
	audio_refs.append_array(bridge_command_sounds)
	audio_refs.append_array(alert_sound_styles)

	for audio_ref in audio_refs:
		if not audio_ref.is_empty():
			add_cross_reference_dependency(audio_ref)

	if not victory_music_theme.is_empty():
		add_cross_reference_dependency(victory_music_theme)
	if not defeat_music_theme.is_empty():
		add_cross_reference_dependency(defeat_music_theme)

# ================== STRATEGIC ANALYSIS METHODS ==================

func calculate_military_strength() -> float:
	"""Calculate overall military capability score (0.0-1.0)"""
	var military_techs = [
		shield_technology_level,
		armor_technology_level,
		engine_technology_level,
		ai_development_level
	]

	var tech_sum = 0.0
	for tech in military_techs:
		tech_sum += float(tech)

	var tech_score = tech_sum / (military_techs.size() * 5.0) # Max level is 5

	# Factor in military doctrine
	var doctrine_bonus = 0.0
	match military_doctrine:
		"Aggressive": doctrine_bonus = 0.1
		"Defensive": doctrine_bonus = 0.05
		"Balanced": doctrine_bonus = 0.075

	return clamp(tech_score + doctrine_bonus, 0.0, 1.0)

func calculate_economic_strength() -> float:
	"""Calculate economic capability score (0.0-1.0)"""
	var econ_factors = [
		resource_efficiency_multiplier,
		production_speed_multiplier,
		repair_efficiency_multiplier,
		trade_efficiency_multiplier,
		manufacturing_technology_level / 5.0
	]

	var econ_sum = 0.0
	for factor in econ_factors:
		econ_sum += float(factor)

	return clamp(econ_sum / econ_factors.size(), 0.0, 1.0)

func calculate_technological_strength() -> float:
	"""Calculate technological advancement score (0.0-1.0)"""
	var tech_fields = [
		shield_technology_level,
		armor_technology_level,
		engine_technology_level,
		ai_development_level,
		sensor_technology_level,
		manufacturing_technology_level,
		research_efficiency_level
	]

	var tech_sum = 0.0
	for tech in tech_fields:
		tech_sum += float(tech)

	return clamp(tech_sum / (tech_fields.size() * 5.0), 0.0, 1.0)

func get_ai_personality_type() -> String:
	"""Determine AI personality based on species military doctrine"""
	if base_ai_aggressiveness > 0.7:
		return "Aggressor"
	elif base_ai_aggressiveness < 0.3:
		return "Defender"
	elif ai_tactical_adaptability > 0.6:
		return "Tactician"
	elif ai_resource_conservation > 0.8:
		return "Conservationist"
	else:
		return "Balanced Operator"

func get_relationship_with(other_species: String) -> float:
	"""Get diplomatic relationship value with another species"""
	return default_iff_status.get(other_species, 0.0)

func set_relationship_with(other_species: String, relationship: float) -> void:
	"""Set diplomatic relationship with another species"""
	relationship = clamp(relationship, -1.0, 1.0)
	default_iff_status[other_species] = relationship
	diplomacy_changed.emit()

func is_hostile_to(other_species: String) -> bool:
	"""Check if this species is hostile to another species"""
	var relationship = get_relationship_with(other_species)
	return relationship < -0.3 # Below -0.3 is considered hostile

func is_allied_with(other_species: String) -> bool:
	"""Check if this species is allied with another species"""
	var relationship = get_relationship_with(other_species)
	return relationship > 0.7 # Above 0.7 is considered allied

func get_combined_strength_score() -> float:
	"""Calculate overall species strength considering military, economic, and technological factors"""
	var military = calculate_military_strength()
	var economic = calculate_economic_strength()
	var technological = calculate_technological_strength()

	# Weighted combination - military is most important for space combat
	return (military * 0.5 + economic * 0.25 + technological * 0.25)

func serialize_diplomatic_status() -> Dictionary:
	"""Serialize diplomatic relationships for save/load"""
	return {
		"default_iff_status": default_iff_status.duplicate(),
		"diplomatic_stance": diplomatic_stance,
		"alliance_demands": alliance_demands.duplicate(),
		"war_preparation_remaining": war_preparation_time_months,
		"peace_willingness": peace_negotiation_willingness
	}

func deserialize_diplomatic_status(diplo_data: Dictionary) -> void:
	"""Restore diplomatic relationships from save data"""
	for key in diplo_data.keys():
		match key:
			"default_iff_status":
				default_iff_status = diplo_data[key]
			"diplomatic_stance":
				diplomatic_stance = diplo_data[key]
			"alliance_demands":
				alliance_demands = diplo_data[key]
			"war_preparation_remaining":
				war_preparation_time_months = diplo_data[key]
			"peace_willingness":
				peace_negotiation_willingness = diplo_data[key]

	diplomacy_changed.emit()
