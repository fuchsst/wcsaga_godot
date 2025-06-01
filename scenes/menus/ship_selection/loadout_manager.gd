class_name LoadoutManager
extends Node

## Weapon loadout validation and configuration management for WCS-Godot conversion.
## Handles loadout persistence, validation, and configuration for ship selection.
## Integrates with WCS Asset Core for weapon data and pilot preferences.

signal loadout_saved(pilot_id: String, loadout_data: Dictionary)
signal loadout_loaded(pilot_id: String, loadout_data: Dictionary)
signal loadout_validation_completed(ship_class: String, result: Dictionary)

# Persistence and preferences
var saved_loadouts: Dictionary = {}  # pilot_id -> ship_class -> loadout_data
var pilot_preferences: Dictionary = {}  # pilot_id -> preferences
var mission_constraints: Dictionary = {}

# WCS Asset Core integration
var wcs_asset_loader: Node = null
var weapon_cache: Dictionary = {}  # weapon_name -> WeaponData

# Configuration
@export var enable_persistence: bool = true
@export var enable_validation: bool = true
@export var enable_auto_save: bool = true
@export var validation_timeout: float = 5.0

func _ready() -> void:
	"""Initialize loadout manager."""
	_setup_asset_integration()
	_load_saved_loadouts()
	name = "LoadoutManager"

func _setup_asset_integration() -> void:
	"""Setup WCS Asset Core integration."""
	await get_tree().process_frame
	
	if has_node("/root/WCSAssetLoader"):
		wcs_asset_loader = get_node("/root/WCSAssetLoader")

# ============================================================================
# PUBLIC API
# ============================================================================

func validate_loadout(ship_data: ShipData, loadout: Dictionary, mission_data: MissionData = null) -> Dictionary:
	"""Validate a complete weapon loadout for a ship."""
	var result: Dictionary = {
		"is_valid": false,
		"errors": [],
		"warnings": [],
		"performance_score": 0.0,
		"recommendations": []
	}
	
	if not ship_data:
		result.errors.append("Ship data is required for validation")
		return result
	
	if loadout.is_empty():
		result.errors.append("Loadout cannot be empty")
		return result
	
	# Validate primary weapons
	result = _validate_primary_weapons(ship_data, loadout, result)
	
	# Validate secondary weapons
	result = _validate_secondary_weapons(ship_data, loadout, result)
	
	# Validate mission constraints
	if mission_data:
		result = _validate_mission_constraints(ship_data, loadout, mission_data, result)
	
	# Calculate performance score
	result.performance_score = _calculate_loadout_performance(ship_data, loadout)
	
	# Generate recommendations
	result.recommendations = _generate_loadout_recommendations(ship_data, loadout, result)
	
	# Final validation status
	result.is_valid = result.errors.is_empty()
	
	loadout_validation_completed.emit(ship_data.ship_name, result)
	return result

func save_pilot_loadout(pilot_id: String, ship_class: String, loadout: Dictionary) -> bool:
	"""Save loadout for a pilot and ship class."""
	if not enable_persistence:
		return false
	
	if pilot_id.is_empty() or ship_class.is_empty():
		return false
	
	# Initialize pilot loadouts if needed
	if not saved_loadouts.has(pilot_id):
		saved_loadouts[pilot_id] = {}
	
	# Save loadout
	saved_loadouts[pilot_id][ship_class] = loadout.duplicate(true)
	
	# Persist to file
	if enable_auto_save:
		_save_loadouts_to_file()
	
	loadout_saved.emit(pilot_id, {"ship_class": ship_class, "loadout": loadout})
	return true

func load_pilot_loadout(pilot_id: String, ship_class: String) -> Dictionary:
	"""Load saved loadout for a pilot and ship class."""
	if not enable_persistence or pilot_id.is_empty() or ship_class.is_empty():
		return {}
	
	var pilot_loadouts: Dictionary = saved_loadouts.get(pilot_id, {})
	var loadout: Dictionary = pilot_loadouts.get(ship_class, {})
	
	if not loadout.is_empty():
		loadout_loaded.emit(pilot_id, {"ship_class": ship_class, "loadout": loadout})
	
	return loadout

func get_pilot_preferences(pilot_id: String) -> Dictionary:
	"""Get pilot weapon preferences."""
	return pilot_preferences.get(pilot_id, {
		"preferred_primary_weapons": [],
		"preferred_secondary_weapons": [],
		"weapon_experience": {},
		"favorite_loadouts": {}
	})

func set_pilot_preferences(pilot_id: String, preferences: Dictionary) -> void:
	"""Set pilot weapon preferences."""
	pilot_preferences[pilot_id] = preferences.duplicate(true)
	
	if enable_auto_save:
		_save_loadouts_to_file()

func create_balanced_loadout(ship_data: ShipData, mission_type: String = "general") -> Dictionary:
	"""Create a balanced weapon loadout for a ship based on mission type."""
	var loadout: Dictionary = {
		"primary_weapons": [],
		"secondary_weapons": []
	}
	
	# Configure primary weapons
	var primary_count: int = ship_data.get_primary_bank_count() if ship_data.has_method("get_primary_bank_count") else 0
	for i in range(primary_count):
		var weapon: String = _get_recommended_primary_weapon(ship_data, i, mission_type)
		loadout.primary_weapons.append(weapon)
	
	# Configure secondary weapons
	var secondary_count: int = ship_data.get_secondary_bank_count() if ship_data.has_method("get_secondary_bank_count") else 0
	for i in range(secondary_count):
		var weapon: String = _get_recommended_secondary_weapon(ship_data, i, mission_type)
		loadout.secondary_weapons.append(weapon)
	
	return loadout

func optimize_loadout_for_mission(ship_data: ShipData, current_loadout: Dictionary, mission_data: MissionData) -> Dictionary:
	"""Optimize a loadout for specific mission requirements."""
	var optimized_loadout: Dictionary = current_loadout.duplicate(true)
	
	# Analyze mission threats
	var threat_analysis: Dictionary = _analyze_mission_threats(mission_data)
	
	# Optimize primary weapons
	optimized_loadout = _optimize_primary_weapons(ship_data, optimized_loadout, threat_analysis)
	
	# Optimize secondary weapons
	optimized_loadout = _optimize_secondary_weapons(ship_data, optimized_loadout, threat_analysis)
	
	return optimized_loadout

func get_weapon_compatibility(ship_data: ShipData) -> Dictionary:
	"""Get weapon compatibility information for a ship."""
	var compatibility: Dictionary = {
		"primary_banks": [],
		"secondary_banks": []
	}
	
	# Get primary bank compatibility
	var primary_count: int = ship_data.get_primary_bank_count() if ship_data.has_method("get_primary_bank_count") else 0
	for i in range(primary_count):
		var bank_weapons: Array[String] = _get_compatible_primary_weapons(ship_data, i)
		compatibility.primary_banks.append(bank_weapons)
	
	# Get secondary bank compatibility
	var secondary_count: int = ship_data.get_secondary_bank_count() if ship_data.has_method("get_secondary_bank_count") else 0
	for i in range(secondary_count):
		var bank_weapons: Array[String] = _get_compatible_secondary_weapons(ship_data, i)
		compatibility.secondary_banks.append(bank_weapons)
	
	return compatibility

func calculate_loadout_cost(loadout: Dictionary) -> Dictionary:
	"""Calculate resource cost for a loadout."""
	var cost: Dictionary = {
		"credits": 0,
		"research_points": 0,
		"maintenance": 0,
		"ammunition": 0
	}
	
	# Calculate primary weapon costs
	var primary_weapons: Array = loadout.get("primary_weapons", [])
	for weapon_name in primary_weapons:
		if not weapon_name.is_empty():
			var weapon_cost: Dictionary = _get_weapon_cost(weapon_name)
			cost.credits += weapon_cost.get("credits", 0)
			cost.research_points += weapon_cost.get("research_points", 0)
			cost.maintenance += weapon_cost.get("maintenance", 0)
	
	# Calculate secondary weapon costs
	var secondary_weapons: Array = loadout.get("secondary_weapons", [])
	for weapon_name in secondary_weapons:
		if not weapon_name.is_empty():
			var weapon_cost: Dictionary = _get_weapon_cost(weapon_name)
			cost.credits += weapon_cost.get("credits", 0)
			cost.research_points += weapon_cost.get("research_points", 0)
			cost.ammunition += weapon_cost.get("ammunition", 0)
	
	return cost

# ============================================================================
# VALIDATION METHODS
# ============================================================================

func _validate_primary_weapons(ship_data: ShipData, loadout: Dictionary, result: Dictionary) -> Dictionary:
	"""Validate primary weapon configuration."""
	var primary_weapons: Array = loadout.get("primary_weapons", [])
	var expected_count: int = ship_data.get_primary_bank_count() if ship_data.has_method("get_primary_bank_count") else 0
	
	if primary_weapons.size() != expected_count:
		result.errors.append("Primary weapon count mismatch: expected %d, got %d" % [expected_count, primary_weapons.size()])
		return result
	
	# Validate each weapon
	for i in range(primary_weapons.size()):
		var weapon_name: String = primary_weapons[i]
		if weapon_name.is_empty():
			result.warnings.append("Primary bank %d has no weapon assigned" % (i + 1))
			continue
		
		var weapon_data: WeaponData = _get_weapon_data(weapon_name)
		if not weapon_data:
			result.errors.append("Primary weapon '%s' not found" % weapon_name)
			continue
		
		# Check compatibility
		if not _is_weapon_compatible_with_bank(ship_data, weapon_data, i, true):
			result.errors.append("Primary weapon '%s' not compatible with bank %d" % [weapon_name, i + 1])
		
		# Check weapon type
		if not _is_primary_weapon(weapon_data):
			result.errors.append("Weapon '%s' is not a primary weapon" % weapon_name)
	
	return result

func _validate_secondary_weapons(ship_data: ShipData, loadout: Dictionary, result: Dictionary) -> Dictionary:
	"""Validate secondary weapon configuration."""
	var secondary_weapons: Array = loadout.get("secondary_weapons", [])
	var expected_count: int = ship_data.get_secondary_bank_count() if ship_data.has_method("get_secondary_bank_count") else 0
	
	if secondary_weapons.size() != expected_count:
		result.errors.append("Secondary weapon count mismatch: expected %d, got %d" % [expected_count, secondary_weapons.size()])
		return result
	
	# Validate each weapon
	for i in range(secondary_weapons.size()):
		var weapon_name: String = secondary_weapons[i]
		if weapon_name.is_empty():
			result.warnings.append("Secondary bank %d has no weapon assigned" % (i + 1))
			continue
		
		var weapon_data: WeaponData = _get_weapon_data(weapon_name)
		if not weapon_data:
			result.errors.append("Secondary weapon '%s' not found" % weapon_name)
			continue
		
		# Check compatibility
		if not _is_weapon_compatible_with_bank(ship_data, weapon_data, i, false):
			result.errors.append("Secondary weapon '%s' not compatible with bank %d" % [weapon_name, i + 1])
		
		# Check weapon type
		if not _is_secondary_weapon(weapon_data):
			result.errors.append("Weapon '%s' is not a secondary weapon" % weapon_name)
	
	return result

func _validate_mission_constraints(ship_data: ShipData, loadout: Dictionary, mission_data: MissionData, result: Dictionary) -> Dictionary:
	"""Validate loadout against mission constraints."""
	# Check for mission-specific weapon restrictions
	if mission_data.has_method("get_weapon_restrictions"):
		var restrictions: Array = mission_data.get_weapon_restrictions()
		for restriction in restrictions:
			# Implementation depends on how mission constraints are defined
			pass
	
	# Check for required weapon types
	var mission_type: String = _determine_mission_type(mission_data)
	match mission_type:
		"anti_capital":
			if not _has_anti_capital_weapons(loadout):
				result.warnings.append("Mission against capital ships - consider anti-capital weapons")
		"anti_fighter":
			if not _has_anti_fighter_weapons(loadout):
				result.warnings.append("Mission against fighters - consider rapid-fire weapons")
		"assault":
			if not _has_assault_weapons(loadout):
				result.warnings.append("Assault mission - consider high-damage weapons")
	
	return result

# ============================================================================
# WEAPON DATA METHODS
# ============================================================================

func _get_weapon_data(weapon_name: String) -> WeaponData:
	"""Get weapon data from cache or asset loader."""
	if weapon_cache.has(weapon_name):
		return weapon_cache[weapon_name]
	
	if not wcs_asset_loader:
		return null
	
	var weapon_path: String = "weapons/" + weapon_name.to_lower().replace(" ", "_") + ".tres"
	var weapon_data: WeaponData = null
	
	if wcs_asset_loader.has_method("load_asset"):
		weapon_data = wcs_asset_loader.load_asset(weapon_path) as WeaponData
	
	if weapon_data:
		weapon_cache[weapon_name] = weapon_data
	
	return weapon_data

func _is_weapon_compatible_with_bank(ship_data: ShipData, weapon_data: WeaponData, bank_index: int, is_primary: bool) -> bool:
	"""Check if weapon is compatible with ship bank."""
	if ship_data.has_method("can_use_weapon"):
		return ship_data.can_use_weapon(weapon_data.weapon_name, bank_index, is_primary)
	
	# Basic compatibility check
	return true

func _is_primary_weapon(weapon_data: WeaponData) -> bool:
	"""Check if weapon is a primary weapon."""
	return weapon_data.subtype == 0  # Assuming 0 = primary weapon

func _is_secondary_weapon(weapon_data: WeaponData) -> bool:
	"""Check if weapon is a secondary weapon."""
	return weapon_data.subtype == 1  # Assuming 1 = secondary weapon

func _get_compatible_primary_weapons(ship_data: ShipData, bank_index: int) -> Array[String]:
	"""Get list of primary weapons compatible with bank."""
	var compatible_weapons: Array[String] = []
	
	# This would be implemented with proper weapon compatibility checking
	# For now, return a basic list
	var basic_primaries: Array[String] = ["Subach HL-7", "Prometheus R", "Akheton SDG", "Maul"]
	return basic_primaries

func _get_compatible_secondary_weapons(ship_data: ShipData, bank_index: int) -> Array[String]:
	"""Get list of secondary weapons compatible with bank."""
	var compatible_weapons: Array[String] = []
	
	# This would be implemented with proper weapon compatibility checking
	# For now, return a basic list
	var basic_secondaries: Array[String] = ["MX-50", "Harpoon", "Hornet", "Tornado"]
	return basic_secondaries

func _get_weapon_cost(weapon_name: String) -> Dictionary:
	"""Get cost information for a weapon."""
	var weapon_data: WeaponData = _get_weapon_data(weapon_name)
	if not weapon_data:
		return {}
	
	# Calculate costs based on weapon properties
	var base_cost: int = 100
	var credits: int = base_cost
	var research_points: int = 0
	var maintenance: int = base_cost / 10
	var ammunition: int = 0
	
	# Adjust costs based on weapon type and properties
	if _is_secondary_weapon(weapon_data):
		ammunition = base_cost / 5
	
	return {
		"credits": credits,
		"research_points": research_points,
		"maintenance": maintenance,
		"ammunition": ammunition
	}

# ============================================================================
# RECOMMENDATION METHODS
# ============================================================================

func _get_recommended_primary_weapon(ship_data: ShipData, bank_index: int, mission_type: String) -> String:
	"""Get recommended primary weapon for a bank and mission type."""
	var compatible_weapons: Array[String] = _get_compatible_primary_weapons(ship_data, bank_index)
	
	if compatible_weapons.is_empty():
		return ""
	
	# Select weapon based on mission type
	match mission_type:
		"anti_capital":
			for weapon in compatible_weapons:
				if "Prometheus" in weapon or "Maul" in weapon:
					return weapon
		"anti_fighter":
			for weapon in compatible_weapons:
				if "Subach" in weapon or "Akheton" in weapon:
					return weapon
		_:
			# Default to first available
			return compatible_weapons[0]
	
	return compatible_weapons[0] if not compatible_weapons.is_empty() else ""

func _get_recommended_secondary_weapon(ship_data: ShipData, bank_index: int, mission_type: String) -> String:
	"""Get recommended secondary weapon for a bank and mission type."""
	var compatible_weapons: Array[String] = _get_compatible_secondary_weapons(ship_data, bank_index)
	
	if compatible_weapons.is_empty():
		return ""
	
	# Select weapon based on mission type
	match mission_type:
		"anti_capital":
			for weapon in compatible_weapons:
				if "Tornado" in weapon or "Harpoon" in weapon:
					return weapon
		"anti_fighter":
			for weapon in compatible_weapons:
				if "Hornet" in weapon or "MX-50" in weapon:
					return weapon
		_:
			# Default to first available
			return compatible_weapons[0]
	
	return compatible_weapons[0] if not compatible_weapons.is_empty() else ""

func _generate_loadout_recommendations(ship_data: ShipData, loadout: Dictionary, validation_result: Dictionary) -> Array[String]:
	"""Generate loadout improvement recommendations."""
	var recommendations: Array[String] = []
	
	# Check for missing weapons
	var primary_weapons: Array = loadout.get("primary_weapons", [])
	var secondary_weapons: Array = loadout.get("secondary_weapons", [])
	
	var empty_primaries: int = 0
	for weapon in primary_weapons:
		if weapon.is_empty():
			empty_primaries += 1
	
	var empty_secondaries: int = 0
	for weapon in secondary_weapons:
		if weapon.is_empty():
			empty_secondaries += 1
	
	if empty_primaries > 0:
		recommendations.append("Consider filling %d empty primary weapon banks" % empty_primaries)
	
	if empty_secondaries > 0:
		recommendations.append("Consider filling %d empty secondary weapon banks" % empty_secondaries)
	
	# Check for weapon synergy
	if not _has_weapon_synergy(loadout):
		recommendations.append("Consider weapons with complementary roles")
	
	# Check for balanced loadout
	if not _is_loadout_balanced(loadout):
		recommendations.append("Consider balancing weapon types for versatility")
	
	return recommendations

# ============================================================================
# ANALYSIS METHODS
# ============================================================================

func _calculate_loadout_performance(ship_data: ShipData, loadout: Dictionary) -> float:
	"""Calculate overall performance score for a loadout."""
	var score: float = 0.0
	var max_score: float = 100.0
	
	# Score primary weapons
	var primary_weapons: Array = loadout.get("primary_weapons", [])
	var primary_score: float = 0.0
	for weapon_name in primary_weapons:
		if not weapon_name.is_empty():
			primary_score += _calculate_weapon_score(weapon_name)
	
	# Score secondary weapons
	var secondary_weapons: Array = loadout.get("secondary_weapons", [])
	var secondary_score: float = 0.0
	for weapon_name in secondary_weapons:
		if not weapon_name.is_empty():
			secondary_score += _calculate_weapon_score(weapon_name)
	
	# Combine scores
	score = (primary_score + secondary_score) / 2.0
	
	# Bonus for filled banks
	var total_banks: int = primary_weapons.size() + secondary_weapons.size()
	var filled_banks: int = 0
	for weapon in primary_weapons + secondary_weapons:
		if not weapon.is_empty():
			filled_banks += 1
	
	if total_banks > 0:
		var completion_bonus: float = (float(filled_banks) / float(total_banks)) * 20.0
		score += completion_bonus
	
	return clamp(score, 0.0, max_score)

func _calculate_weapon_score(weapon_name: String) -> float:
	"""Calculate performance score for a weapon."""
	var weapon_data: WeaponData = _get_weapon_data(weapon_name)
	if not weapon_data:
		return 0.0
	
	# Base score from weapon properties
	var score: float = 50.0  # Base score
	
	# Add score based on damage
	if weapon_data.has_method("get_damage"):
		score += weapon_data.get_damage() * 0.1
	
	# Add score based on range
	if weapon_data.has_method("get_range"):
		score += weapon_data.get_range() * 0.05
	
	# Add score based on fire rate
	if weapon_data.has_method("get_fire_rate"):
		score += weapon_data.get_fire_rate() * 2.0
	
	return clamp(score, 0.0, 100.0)

func _analyze_mission_threats(mission_data: MissionData) -> Dictionary:
	"""Analyze mission to identify threat types."""
	var threats: Dictionary = {
		"fighters": 0,
		"bombers": 0,
		"capital_ships": 0,
		"unknown": 0
	}
	
	# Analyze enemy ships
	for ship in mission_data.ships:
		var ship_instance: ShipInstanceData = ship as ShipInstanceData
		if ship_instance and ship_instance.team != 0:  # Non-friendly
			var threat_type: String = _classify_ship_threat(ship_instance.ship_class_name)
			threats[threat_type] = threats.get(threat_type, 0) + 1
	
	return threats

func _classify_ship_threat(ship_class_name: String) -> String:
	"""Classify ship threat type."""
	var name_upper: String = ship_class_name.to_upper()
	
	if "CORVETTE" in name_upper or "DESTROYER" in name_upper or "CRUISER" in name_upper:
		return "capital_ships"
	elif "BOMBER" in name_upper or "GTB" in name_upper or "GVB" in name_upper:
		return "bombers"
	elif "FIGHTER" in name_upper or "GTF" in name_upper or "GVF" in name_upper:
		return "fighters"
	else:
		return "unknown"

func _determine_mission_type(mission_data: MissionData) -> String:
	"""Determine primary mission type."""
	var threat_analysis: Dictionary = _analyze_mission_threats(mission_data)
	
	if threat_analysis.get("capital_ships", 0) > 0:
		return "anti_capital"
	elif threat_analysis.get("bombers", 0) > threat_analysis.get("fighters", 0):
		return "anti_bomber"
	elif threat_analysis.get("fighters", 0) > 0:
		return "anti_fighter"
	else:
		return "general"

# ============================================================================
# WEAPON ANALYSIS METHODS
# ============================================================================

func _has_anti_capital_weapons(loadout: Dictionary) -> bool:
	"""Check if loadout has anti-capital ship weapons."""
	var secondary_weapons: Array = loadout.get("secondary_weapons", [])
	for weapon_name in secondary_weapons:
		if "Tornado" in weapon_name or "Harpoon" in weapon_name:
			return true
	return false

func _has_anti_fighter_weapons(loadout: Dictionary) -> bool:
	"""Check if loadout has anti-fighter weapons."""
	var primary_weapons: Array = loadout.get("primary_weapons", [])
	for weapon_name in primary_weapons:
		if "Subach" in weapon_name or "Akheton" in weapon_name:
			return true
	return false

func _has_assault_weapons(loadout: Dictionary) -> bool:
	"""Check if loadout has high-damage assault weapons."""
	var primary_weapons: Array = loadout.get("primary_weapons", [])
	for weapon_name in primary_weapons:
		if "Prometheus" in weapon_name or "Maul" in weapon_name:
			return true
	return false

func _has_weapon_synergy(loadout: Dictionary) -> bool:
	"""Check if weapons work well together."""
	# Simple synergy check - mix of weapon types
	var primary_weapons: Array = loadout.get("primary_weapons", [])
	var secondary_weapons: Array = loadout.get("secondary_weapons", [])
	
	return primary_weapons.size() > 1 and secondary_weapons.size() > 0

func _is_loadout_balanced(loadout: Dictionary) -> bool:
	"""Check if loadout is balanced between weapon types."""
	var primary_weapons: Array = loadout.get("primary_weapons", [])
	var secondary_weapons: Array = loadout.get("secondary_weapons", [])
	
	var filled_primaries: int = 0
	for weapon in primary_weapons:
		if not weapon.is_empty():
			filled_primaries += 1
	
	var filled_secondaries: int = 0
	for weapon in secondary_weapons:
		if not weapon.is_empty():
			filled_secondaries += 1
	
	# Balanced if both types have weapons
	return filled_primaries > 0 and filled_secondaries > 0

# ============================================================================
# OPTIMIZATION METHODS
# ============================================================================

func _optimize_primary_weapons(ship_data: ShipData, loadout: Dictionary, threat_analysis: Dictionary) -> Dictionary:
	"""Optimize primary weapons for mission threats."""
	var optimized_loadout: Dictionary = loadout.duplicate(true)
	var primary_weapons: Array = optimized_loadout.get("primary_weapons", [])
	
	# Determine optimal weapon type
	var optimal_type: String = "general"
	if threat_analysis.get("capital_ships", 0) > 0:
		optimal_type = "anti_capital"
	elif threat_analysis.get("fighters", 0) > 0:
		optimal_type = "anti_fighter"
	
	# Replace weapons if better options available
	for i in range(primary_weapons.size()):
		var current_weapon: String = primary_weapons[i]
		var recommended_weapon: String = _get_recommended_primary_weapon(ship_data, i, optimal_type)
		
		if not recommended_weapon.is_empty() and recommended_weapon != current_weapon:
			var current_score: float = _calculate_weapon_score(current_weapon) if not current_weapon.is_empty() else 0.0
			var recommended_score: float = _calculate_weapon_score(recommended_weapon)
			
			if recommended_score > current_score:
				primary_weapons[i] = recommended_weapon
	
	optimized_loadout["primary_weapons"] = primary_weapons
	return optimized_loadout

func _optimize_secondary_weapons(ship_data: ShipData, loadout: Dictionary, threat_analysis: Dictionary) -> Dictionary:
	"""Optimize secondary weapons for mission threats."""
	var optimized_loadout: Dictionary = loadout.duplicate(true)
	var secondary_weapons: Array = optimized_loadout.get("secondary_weapons", [])
	
	# Determine optimal weapon type
	var optimal_type: String = "general"
	if threat_analysis.get("capital_ships", 0) > 0:
		optimal_type = "anti_capital"
	elif threat_analysis.get("bombers", 0) > 0:
		optimal_type = "anti_bomber"
	
	# Replace weapons if better options available
	for i in range(secondary_weapons.size()):
		var current_weapon: String = secondary_weapons[i]
		var recommended_weapon: String = _get_recommended_secondary_weapon(ship_data, i, optimal_type)
		
		if not recommended_weapon.is_empty() and recommended_weapon != current_weapon:
			var current_score: float = _calculate_weapon_score(current_weapon) if not current_weapon.is_empty() else 0.0
			var recommended_score: float = _calculate_weapon_score(recommended_weapon)
			
			if recommended_score > current_score:
				secondary_weapons[i] = recommended_weapon
	
	optimized_loadout["secondary_weapons"] = secondary_weapons
	return optimized_loadout

# ============================================================================
# PERSISTENCE METHODS
# ============================================================================

func _load_saved_loadouts() -> void:
	"""Load saved loadouts from file."""
	if not enable_persistence:
		return
	
	var save_path: String = "user://ship_loadouts.save"
	if not FileAccess.file_exists(save_path):
		return
	
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	
	var save_data: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(save_data)
	if parse_result != OK:
		push_error("Failed to parse loadout save file")
		return
	
	var data: Dictionary = json.data
	saved_loadouts = data.get("loadouts", {})
	pilot_preferences = data.get("preferences", {})

func _save_loadouts_to_file() -> void:
	"""Save loadouts to file."""
	if not enable_persistence:
		return
	
	var save_data: Dictionary = {
		"loadouts": saved_loadouts,
		"preferences": pilot_preferences,
		"version": "1.0"
	}
	
	var save_path: String = "user://ship_loadouts.save"
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open loadout save file for writing")
		return
	
	var json_string: String = JSON.stringify(save_data)
	file.store_string(json_string)
	file.close()

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_loadout_manager() -> LoadoutManager:
	"""Create a new loadout manager instance."""
	var manager: LoadoutManager = LoadoutManager.new()
	return manager