class_name ShipSelectionDataManager
extends Node

## Ship selection data processing and loadout management for WCS-Godot conversion.
## Handles ship availability, weapon loadout validation, and pilot restrictions.
## Integrates with WCS Asset Core for ship and weapon data.

signal ship_data_loaded(ship_classes: Array[ShipData])
signal loadout_changed(ship_class: String, loadout: Dictionary)
signal loadout_validated(ship_class: String, is_valid: bool, errors: Array[String])
signal pilot_restrictions_updated(available_ships: Array[String])

# WCS Asset Core integration
var wcs_asset_loader: Node = null
var wcs_asset_registry: Node = null

# Current state
var available_ship_classes: Array[ShipData] = []
var current_pilot_data: PlayerProfile = null
var current_mission_data: MissionData = null
var current_loadouts: Dictionary = {}  # ship_class -> loadout_data

# Configuration
@export var enable_pilot_restrictions: bool = true
@export var enable_mission_constraints: bool = true
@export var enable_rank_restrictions: bool = true
@export var enable_loadout_validation: bool = true

func _ready() -> void:
	"""Initialize ship selection data manager."""
	_setup_asset_integration()
	name = "ShipSelectionDataManager"

func _setup_asset_integration() -> void:
	"""Setup WCS Asset Core integration."""
	# Wait for autoloads to be ready
	await get_tree().process_frame
	
	# Find asset loader and registry
	if has_node("/root/WCSAssetLoader"):
		wcs_asset_loader = get_node("/root/WCSAssetLoader")
	if has_node("/root/WCSAssetRegistry"):
		wcs_asset_registry = get_node("/root/WCSAssetRegistry")

# ============================================================================
# PUBLIC API
# ============================================================================

func load_ship_data_for_mission(mission_data: MissionData, pilot_data: PlayerProfile) -> bool:
	"""Load available ship data for the specified mission and pilot."""
	if not mission_data or not pilot_data:
		return false
	
	current_mission_data = mission_data
	current_pilot_data = pilot_data
	
	# Get available ship classes from mission
	var ship_choices: Array[String] = _get_mission_ship_choices(mission_data)
	if ship_choices.is_empty():
		push_warning("No ship choices found in mission data")
		return false
	
	# Load ship data from Asset Core
	available_ship_classes.clear()
	for ship_class_name in ship_choices:
		var ship_data: ShipData = _load_ship_data(ship_class_name)
		if ship_data and _is_ship_available_to_pilot(ship_data, pilot_data):
			available_ship_classes.append(ship_data)
	
	if available_ship_classes.is_empty():
		push_error("No ships available for pilot in mission")
		return false
	
	# Initialize default loadouts
	_initialize_default_loadouts()
	
	ship_data_loaded.emit(available_ship_classes)
	return true

func get_available_ships() -> Array[ShipData]:
	"""Get currently available ship classes."""
	return available_ship_classes

func get_ship_loadout(ship_class: String) -> Dictionary:
	"""Get current loadout for a ship class."""
	return current_loadouts.get(ship_class, {})

func set_ship_loadout(ship_class: String, loadout: Dictionary) -> bool:
	"""Set loadout for a ship class with validation."""
	if not _validate_loadout(ship_class, loadout):
		return false
	
	current_loadouts[ship_class] = loadout.duplicate(true)
	loadout_changed.emit(ship_class, loadout)
	return true

func validate_ship_loadout(ship_class: String) -> Dictionary:
	"""Validate a ship's loadout and return validation result."""
	var result: Dictionary = {
		"is_valid": false,
		"errors": [],
		"warnings": []
	}
	
	var ship_data: ShipData = _get_ship_data_by_class(ship_class)
	if not ship_data:
		result.errors.append("Ship class not found: " + ship_class)
		return result
	
	var loadout: Dictionary = current_loadouts.get(ship_class, {})
	if loadout.is_empty():
		result.errors.append("No loadout configured for ship: " + ship_class)
		return result
	
	# Validate weapon banks
	result = _validate_weapon_banks(ship_data, loadout, result)
	
	# Validate mission constraints
	if enable_mission_constraints and current_mission_data:
		result = _validate_mission_constraints(ship_data, loadout, result)
	
	result.is_valid = result.errors.is_empty()
	loadout_validated.emit(ship_class, result.is_valid, result.errors)
	return result

func get_ship_specifications(ship_class: String) -> Dictionary:
	"""Get detailed ship specifications for display."""
	var ship_data: ShipData = _get_ship_data_by_class(ship_class)
	if not ship_data:
		return {}
	
	return {
		"name": ship_data.ship_name,
		"class": ship_data.short_name if not ship_data.short_name.is_empty() else ship_data.ship_name,
		"manufacturer": ship_data.manufacturer,
		"description": ship_data.ship_description,
		"tech_description": ship_data.tech_description,
		"length": ship_data.ship_length,
		"max_speed": ship_data.get_max_speed(),
		"afterburner_speed": ship_data.get_afterburner_speed() if ship_data.has_method("get_afterburner_speed") else 0.0,
		"hull_strength": ship_data.get_hull_strength() if ship_data.has_method("get_hull_strength") else 0.0,
		"shield_strength": ship_data.get_shield_strength() if ship_data.has_method("get_shield_strength") else 0.0,
		"primary_banks": ship_data.num_primary_banks if ship_data.has_method("num_primary_banks") else 0,
		"secondary_banks": ship_data.num_secondary_banks if ship_data.has_method("num_secondary_banks") else 0,
		"cargo_capacity": ship_data.cargo_size if ship_data.has_method("cargo_size") else 0,
		"flags": ship_data.get_ship_flags() if ship_data.has_method("get_ship_flags") else [],
		"model_file": ship_data.pof_file
	}

func get_weapon_bank_info(ship_class: String) -> Dictionary:
	"""Get weapon bank configuration for a ship."""
	var ship_data: ShipData = _get_ship_data_by_class(ship_class)
	if not ship_data:
		return {}
	
	var bank_info: Dictionary = {
		"primary_banks": [],
		"secondary_banks": []
	}
	
	# Get primary weapon banks
	if ship_data.has_method("get_primary_bank_count"):
		var primary_count: int = ship_data.get_primary_bank_count()
		for i in range(primary_count):
			var bank_data: Dictionary = {
				"bank_index": i,
				"weapon_class": "",
				"ammo_capacity": 0,
				"fire_wait": 0.0,
				"available_weapons": _get_available_primary_weapons(ship_data, i)
			}
			bank_info.primary_banks.append(bank_data)
	
	# Get secondary weapon banks
	if ship_data.has_method("get_secondary_bank_count"):
		var secondary_count: int = ship_data.get_secondary_bank_count()
		for i in range(secondary_count):
			var bank_data: Dictionary = {
				"bank_index": i,
				"weapon_class": "",
				"ammo_capacity": 0,
				"fire_wait": 0.0,
				"available_weapons": _get_available_secondary_weapons(ship_data, i)
			}
			bank_info.secondary_banks.append(bank_data)
	
	return bank_info

func generate_ship_recommendations() -> Array[Dictionary]:
	"""Generate ship recommendations based on mission and pilot."""
	var recommendations: Array[Dictionary] = []
	
	if not current_mission_data or available_ship_classes.is_empty():
		return recommendations
	
	# Analyze mission requirements
	var mission_analysis: Dictionary = _analyze_mission_requirements()
	
	# Score ships based on mission fit
	for ship_data in available_ship_classes:
		var score: float = _calculate_ship_mission_score(ship_data, mission_analysis)
		var recommendation: Dictionary = {
			"ship_class": ship_data.ship_name,
			"score": score,
			"reason": _generate_recommendation_reason(ship_data, mission_analysis),
			"priority": _get_recommendation_priority(score)
		}
		recommendations.append(recommendation)
	
	# Sort by score
	recommendations.sort_custom(func(a, b): return a.score > b.score)
	
	return recommendations

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _get_mission_ship_choices(mission_data: MissionData) -> Array[String]:
	"""Extract available ship choices from mission data."""
	var ship_choices: Array[String] = []
	
	# Check player start data for ship loadout choices
	for player_start in mission_data.player_starts:
		var start_data: PlayerStartData = player_start as PlayerStartData
		if start_data and not start_data.ship_loadout_choices.is_empty():
			for choice in start_data.ship_loadout_choices:
				var loadout_choice: ShipLoadoutChoice = choice as ShipLoadoutChoice
				if loadout_choice and not loadout_choice.ship_class_name.is_empty():
					if not ship_choices.has(loadout_choice.ship_class_name):
						ship_choices.append(loadout_choice.ship_class_name)
	
	# Fallback: check ship instances for common fighter classes
	if ship_choices.is_empty():
		for ship in mission_data.ships:
			var ship_instance: ShipInstanceData = ship as ShipInstanceData
			if ship_instance and _is_fighter_class(ship_instance.ship_class_name):
				if not ship_choices.has(ship_instance.ship_class_name):
					ship_choices.append(ship_instance.ship_class_name)
	
	return ship_choices

func _load_ship_data(ship_class_name: String) -> ShipData:
	"""Load ship data from WCS Asset Core."""
	if not wcs_asset_loader:
		push_warning("WCS Asset Loader not available")
		return null
	
	var ship_path: String = "ships/" + ship_class_name.to_lower().replace(" ", "_") + ".tres"
	
	if wcs_asset_loader.has_method("load_asset"):
		return wcs_asset_loader.load_asset(ship_path) as ShipData
	else:
		# Fallback to standard loading
		if ResourceLoader.exists("res://assets/" + ship_path):
			return load("res://assets/" + ship_path) as ShipData
	
	return null

func _is_ship_available_to_pilot(ship_data: ShipData, pilot_data: PlayerProfile) -> bool:
	"""Check if ship is available to the pilot based on restrictions."""
	if not enable_pilot_restrictions:
		return true
	
	# Check rank restrictions
	if enable_rank_restrictions:
		var required_rank: int = ship_data.get_required_rank() if ship_data.has_method("get_required_rank") else 0
		var pilot_rank: int = pilot_data.get_current_rank() if pilot_data.has_method("get_current_rank") else 0
		if pilot_rank < required_rank:
			return false
	
	# Check pilot skill requirements
	var required_skills: Array = ship_data.get_required_skills() if ship_data.has_method("get_required_skills") else []
	for skill in required_skills:
		if not pilot_data.has_skill(skill):
			return false
	
	return true

func _initialize_default_loadouts() -> void:
	"""Initialize default loadouts for all available ships."""
	current_loadouts.clear()
	
	for ship_data in available_ship_classes:
		var loadout: Dictionary = _create_default_loadout(ship_data)
		current_loadouts[ship_data.ship_name] = loadout

func _create_default_loadout(ship_data: ShipData) -> Dictionary:
	"""Create default weapon loadout for a ship."""
	var loadout: Dictionary = {
		"primary_weapons": [],
		"secondary_weapons": []
	}
	
	# Set default primary weapons
	var primary_count: int = ship_data.get_primary_bank_count() if ship_data.has_method("get_primary_bank_count") else 0
	for i in range(primary_count):
		var default_weapon: String = ship_data.get_default_primary_weapon(i) if ship_data.has_method("get_default_primary_weapon") else ""
		loadout.primary_weapons.append(default_weapon)
	
	# Set default secondary weapons
	var secondary_count: int = ship_data.get_secondary_bank_count() if ship_data.has_method("get_secondary_bank_count") else 0
	for i in range(secondary_count):
		var default_weapon: String = ship_data.get_default_secondary_weapon(i) if ship_data.has_method("get_default_secondary_weapon") else ""
		loadout.secondary_weapons.append(default_weapon)
	
	return loadout

func _validate_loadout(ship_class: String, loadout: Dictionary) -> bool:
	"""Validate a weapon loadout for a ship class."""
	var validation_result: Dictionary = validate_ship_loadout(ship_class)
	return validation_result.is_valid

func _validate_weapon_banks(ship_data: ShipData, loadout: Dictionary, result: Dictionary) -> Dictionary:
	"""Validate weapon bank configuration."""
	# Validate primary weapons
	var primary_weapons: Array = loadout.get("primary_weapons", [])
	var primary_count: int = ship_data.get_primary_bank_count() if ship_data.has_method("get_primary_bank_count") else 0
	
	if primary_weapons.size() != primary_count:
		result.errors.append("Primary weapon count mismatch: expected %d, got %d" % [primary_count, primary_weapons.size()])
	
	for i in range(primary_weapons.size()):
		if i < primary_count:
			var weapon_name: String = primary_weapons[i]
			if not weapon_name.is_empty() and not _is_valid_primary_weapon(ship_data, i, weapon_name):
				result.errors.append("Invalid primary weapon '%s' for bank %d" % [weapon_name, i])
	
	# Validate secondary weapons
	var secondary_weapons: Array = loadout.get("secondary_weapons", [])
	var secondary_count: int = ship_data.get_secondary_bank_count() if ship_data.has_method("get_secondary_bank_count") else 0
	
	if secondary_weapons.size() != secondary_count:
		result.errors.append("Secondary weapon count mismatch: expected %d, got %d" % [secondary_count, secondary_weapons.size()])
	
	for i in range(secondary_weapons.size()):
		if i < secondary_count:
			var weapon_name: String = secondary_weapons[i]
			if not weapon_name.is_empty() and not _is_valid_secondary_weapon(ship_data, i, weapon_name):
				result.errors.append("Invalid secondary weapon '%s' for bank %d" % [weapon_name, i])
	
	return result

func _validate_mission_constraints(ship_data: ShipData, loadout: Dictionary, result: Dictionary) -> Dictionary:
	"""Validate loadout against mission constraints."""
	# Check mission-specific weapon restrictions
	if current_mission_data.has_method("get_weapon_restrictions"):
		var restrictions: Array = current_mission_data.get_weapon_restrictions()
		for restriction in restrictions:
			# Implementation depends on mission constraint format
			pass
	
	return result

func _get_ship_data_by_class(ship_class: String) -> ShipData:
	"""Get ship data by class name."""
	for ship_data in available_ship_classes:
		if ship_data.ship_name == ship_class:
			return ship_data
	return null

func _get_available_primary_weapons(ship_data: ShipData, bank_index: int) -> Array[String]:
	"""Get available primary weapons for a specific bank."""
	var weapons: Array[String] = []
	
	if wcs_asset_registry and wcs_asset_registry.has_method("get_weapons_by_type"):
		var primary_weapons: Array = wcs_asset_registry.get_weapons_by_type("primary")
		for weapon_path in primary_weapons:
			var weapon_data: WeaponData = wcs_asset_loader.load_asset(weapon_path) as WeaponData
			if weapon_data and _can_ship_use_weapon(ship_data, weapon_data, bank_index, true):
				weapons.append(weapon_data.weapon_name)
	
	return weapons

func _get_available_secondary_weapons(ship_data: ShipData, bank_index: int) -> Array[String]:
	"""Get available secondary weapons for a specific bank."""
	var weapons: Array[String] = []
	
	if wcs_asset_registry and wcs_asset_registry.has_method("get_weapons_by_type"):
		var secondary_weapons: Array = wcs_asset_registry.get_weapons_by_type("secondary")
		for weapon_path in secondary_weapons:
			var weapon_data: WeaponData = wcs_asset_loader.load_asset(weapon_path) as WeaponData
			if weapon_data and _can_ship_use_weapon(ship_data, weapon_data, bank_index, false):
				weapons.append(weapon_data.weapon_name)
	
	return weapons

func _can_ship_use_weapon(ship_data: ShipData, weapon_data: WeaponData, bank_index: int, is_primary: bool) -> bool:
	"""Check if a ship can use a specific weapon in a specific bank."""
	# Check weapon class compatibility
	if ship_data.has_method("can_use_weapon"):
		return ship_data.can_use_weapon(weapon_data.weapon_name, bank_index, is_primary)
	
	# Basic compatibility check
	return true

func _is_valid_primary_weapon(ship_data: ShipData, bank_index: int, weapon_name: String) -> bool:
	"""Check if a primary weapon is valid for a ship bank."""
	var available_weapons: Array[String] = _get_available_primary_weapons(ship_data, bank_index)
	return available_weapons.has(weapon_name)

func _is_valid_secondary_weapon(ship_data: ShipData, bank_index: int, weapon_name: String) -> bool:
	"""Check if a secondary weapon is valid for a ship bank."""
	var available_weapons: Array[String] = _get_available_secondary_weapons(ship_data, bank_index)
	return available_weapons.has(weapon_name)

func _is_fighter_class(ship_class_name: String) -> bool:
	"""Check if a ship class is a fighter (player-flyable)."""
	var fighter_indicators: Array[String] = ["GTF", "GVF", "GTB", "GVB", "SF", "Fighter", "Bomber"]
	var upper_name: String = ship_class_name.to_upper()
	
	for indicator in fighter_indicators:
		if upper_name.contains(indicator):
			return true
	
	return false

func _analyze_mission_requirements() -> Dictionary:
	"""Analyze mission to determine ship requirements."""
	var analysis: Dictionary = {
		"mission_type": "unknown",
		"primary_threats": [],
		"required_capabilities": [],
		"recommended_loadout": "balanced"
	}
	
	if not current_mission_data:
		return analysis
	
	# Analyze mission objectives
	for goal in current_mission_data.goals:
		var objective: MissionObjectiveData = goal as MissionObjectiveData
		if objective:
			var obj_type: String = _determine_objective_type(objective.objective_text)
			if not analysis.required_capabilities.has(obj_type):
				analysis.required_capabilities.append(obj_type)
	
	# Analyze enemy ships
	for ship in current_mission_data.ships:
		var ship_instance: ShipInstanceData = ship as ShipInstanceData
		if ship_instance and ship_instance.team != 0:  # Non-friendly
			var threat_level: String = _assess_ship_threat(ship_instance.ship_class_name)
			if not analysis.primary_threats.has(threat_level):
				analysis.primary_threats.append(threat_level)
	
	# Determine mission type
	analysis.mission_type = _determine_mission_type(analysis)
	
	return analysis

func _calculate_ship_mission_score(ship_data: ShipData, mission_analysis: Dictionary) -> float:
	"""Calculate how well a ship fits the mission requirements."""
	var score: float = 0.0
	
	# Base score from ship type
	var ship_type: String = _get_ship_type(ship_data)
	match mission_analysis.mission_type:
		"assault":
			if ship_type in ["bomber", "heavy_fighter"]:
				score += 50.0
		"defense":
			if ship_type in ["interceptor", "fighter"]:
				score += 50.0
		"reconnaissance":
			if ship_type in ["scout", "light_fighter"]:
				score += 50.0
		_:
			score += 25.0  # Neutral score
	
	# Score based on required capabilities
	for capability in mission_analysis.required_capabilities:
		if _ship_has_capability(ship_data, capability):
			score += 20.0
	
	# Score based on threat level
	for threat in mission_analysis.primary_threats:
		if _ship_counters_threat(ship_data, threat):
			score += 15.0
	
	# Bonus for pilot familiarity
	if current_pilot_data and current_pilot_data.has_method("get_ship_experience"):
		var experience: float = current_pilot_data.get_ship_experience(ship_data.ship_name)
		score += experience * 0.1
	
	return clamp(score, 0.0, 100.0)

func _generate_recommendation_reason(ship_data: ShipData, mission_analysis: Dictionary) -> String:
	"""Generate human-readable reason for ship recommendation."""
	var reasons: Array[String] = []
	
	var ship_type: String = _get_ship_type(ship_data)
	match mission_analysis.mission_type:
		"assault":
			if ship_type in ["bomber", "heavy_fighter"]:
				reasons.append("Excellent for assault missions")
		"defense":
			if ship_type in ["interceptor", "fighter"]:
				reasons.append("Ideal for defensive operations")
		"reconnaissance":
			if ship_type in ["scout", "light_fighter"]:
				reasons.append("Perfect for reconnaissance missions")
	
	if ship_data.get_max_speed() > 80.0:
		reasons.append("High speed and maneuverability")
	
	if ship_data.get_hull_strength() > 200.0:
		reasons.append("Heavy armor for survivability")
	
	if reasons.is_empty():
		reasons.append("Versatile multi-role fighter")
	
	return reasons[0]  # Return primary reason

func _get_recommendation_priority(score: float) -> int:
	"""Convert score to priority level (1-5 stars)."""
	if score >= 80.0:
		return 5
	elif score >= 60.0:
		return 4
	elif score >= 40.0:
		return 3
	elif score >= 20.0:
		return 2
	else:
		return 1

func _determine_objective_type(objective_text: String) -> String:
	"""Determine objective type from text."""
	var text_lower: String = objective_text.to_lower()
	
	if "destroy" in text_lower or "attack" in text_lower:
		return "assault"
	elif "protect" in text_lower or "defend" in text_lower:
		return "defense"
	elif "scan" in text_lower or "recon" in text_lower:
		return "reconnaissance"
	elif "escort" in text_lower:
		return "escort"
	else:
		return "general"

func _assess_ship_threat(ship_class_name: String) -> String:
	"""Assess threat level of enemy ship."""
	var upper_name: String = ship_class_name.to_upper()
	
	if "CORVETTE" in upper_name or "DESTROYER" in upper_name or "CRUISER" in upper_name:
		return "capital"
	elif "BOMBER" in upper_name or "GTB" in upper_name or "GVB" in upper_name:
		return "bomber"
	elif "FIGHTER" in upper_name or "GTF" in upper_name or "GVF" in upper_name:
		return "fighter"
	else:
		return "unknown"

func _determine_mission_type(analysis: Dictionary) -> String:
	"""Determine overall mission type from analysis."""
	var capabilities: Array = analysis.required_capabilities
	
	if "assault" in capabilities:
		return "assault"
	elif "defense" in capabilities:
		return "defense"
	elif "reconnaissance" in capabilities:
		return "reconnaissance"
	elif "escort" in capabilities:
		return "escort"
	else:
		return "general"

func _get_ship_type(ship_data: ShipData) -> String:
	"""Get ship type classification."""
	var name: String = ship_data.ship_name.to_upper()
	
	if "BOMBER" in name or "GTB" in name or "GVB" in name:
		return "bomber"
	elif "INTERCEPTOR" in name or "SCOUT" in name:
		return "interceptor"
	elif "HEAVY" in name or "ASSAULT" in name:
		return "heavy_fighter"
	elif "FIGHTER" in name or "GTF" in name or "GVF" in name:
		return "fighter"
	else:
		return "unknown"

func _ship_has_capability(ship_data: ShipData, capability: String) -> bool:
	"""Check if ship has specific capability."""
	match capability:
		"assault":
			return ship_data.get_primary_bank_count() >= 2 if ship_data.has_method("get_primary_bank_count") else false
		"defense":
			return ship_data.get_max_speed() > 60.0 if ship_data.has_method("get_max_speed") else false
		"reconnaissance":
			return ship_data.get_max_speed() > 80.0 if ship_data.has_method("get_max_speed") else false
		_:
			return false

func _ship_counters_threat(ship_data: ShipData, threat: String) -> bool:
	"""Check if ship effectively counters threat type."""
	match threat:
		"capital":
			return ship_data.get_secondary_bank_count() >= 2 if ship_data.has_method("get_secondary_bank_count") else false
		"bomber":
			return ship_data.get_max_speed() > 70.0 if ship_data.has_method("get_max_speed") else false
		"fighter":
			return ship_data.get_primary_bank_count() >= 2 if ship_data.has_method("get_primary_bank_count") else false
		_:
			return false

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_ship_selection_data_manager() -> ShipSelectionDataManager:
	"""Create a new ship selection data manager instance."""
	var manager: ShipSelectionDataManager = ShipSelectionDataManager.new()
	return manager