class_name SelectWeaponAction
extends WCSBTAction

## Intelligent weapon selection behavior tree action
## Selects optimal weapons based on target type, distance, and tactical situation

enum WeaponType {
	PRIMARY_GUNS,     # Energy weapons, lasers, cannons
	SECONDARY_GUNS,   # Heavier guns, autocannons  
	MISSILES,         # Heat-seeking missiles
	TORPEDOES,        # Heavy anti-ship torpedoes
	SPECIAL_WEAPONS,  # Bombs, mines, special ordnance
	DEFENSIVE_WEAPONS # Point defense, flak
}

enum SelectionCriteria {
	OPTIMAL_RANGE,       # Select based on optimal engagement range
	TARGET_TYPE,         # Select based on target ship class/type
	AMMUNITION_EFFICIENCY, # Consider ammo conservation
	DAMAGE_MAXIMIZATION, # Maximum damage potential
	TACTICAL_SITUATION,  # Formation, escort, etc.
	ENERGY_MANAGEMENT    # Consider energy levels
}

enum TargetClass {
	FIGHTER,          # Small, fast, agile targets
	BOMBER,           # Medium, armed, slower targets
	CORVETTE,         # Small capital ships
	FRIGATE,          # Medium capital ships
	DESTROYER,        # Large capital ships
	CRUISER,          # Very large capital ships
	BATTLESHIP,       # Massive capital ships
	TRANSPORT,        # Unarmed/lightly armed
	INSTALLATION,     # Stationary targets
	UNKNOWN           # Unidentified targets
}

@export var selection_criteria: SelectionCriteria = SelectionCriteria.OPTIMAL_RANGE
@export var auto_weapon_selection: bool = true
@export var preferred_weapon_type: WeaponType = WeaponType.PRIMARY_GUNS
@export var range_consideration_factor: float = 1.0
@export var ammo_conservation_factor: float = 0.7

var current_weapon_selection: WeaponType
var weapon_effectiveness_history: Dictionary = {}
var target_class_cache: Dictionary = {}
var last_selection_time: float = 0.0
var selection_cache_duration: float = 2.0

# Weapon range and effectiveness data
var weapon_specifications: Dictionary = {
	WeaponType.PRIMARY_GUNS: {
		"optimal_range": 600.0,
		"max_range": 1200.0,
		"damage_vs_fighter": 1.0,
		"damage_vs_bomber": 0.8,
		"damage_vs_capital": 0.3,
		"energy_cost": 1.0,
		"fire_rate": 5.0,
		"projectile_speed": 1500.0
	},
	WeaponType.SECONDARY_GUNS: {
		"optimal_range": 800.0,
		"max_range": 1600.0,
		"damage_vs_fighter": 0.6,
		"damage_vs_bomber": 1.2,
		"damage_vs_capital": 0.8,
		"energy_cost": 2.0,
		"fire_rate": 2.0,
		"projectile_speed": 1000.0
	},
	WeaponType.MISSILES: {
		"optimal_range": 2000.0,
		"max_range": 4000.0,
		"damage_vs_fighter": 1.5,
		"damage_vs_bomber": 2.0,
		"damage_vs_capital": 1.0,
		"energy_cost": 0.0,
		"fire_rate": 0.5,
		"projectile_speed": 800.0,
		"ammo_limited": true
	},
	WeaponType.TORPEDOES: {
		"optimal_range": 3000.0,
		"max_range": 6000.0,
		"damage_vs_fighter": 0.3,
		"damage_vs_bomber": 1.0,
		"damage_vs_capital": 3.0,
		"energy_cost": 0.0,
		"fire_rate": 0.2,
		"projectile_speed": 600.0,
		"ammo_limited": true
	}
}

signal weapon_selected(weapon_type: WeaponType, target: Node3D, selection_reason: String)
signal weapon_selection_failed(reason: String)
signal weapon_effectiveness_updated(weapon_type: WeaponType, effectiveness: float)

func _setup() -> void:
	super._setup()
	current_weapon_selection = WeaponType.PRIMARY_GUNS
	last_selection_time = 0.0
	
	# Initialize weapon effectiveness tracking
	for weapon_type in WeaponType.values():
		weapon_effectiveness_history[weapon_type] = []

func execute_wcs_action(delta: float) -> int:
	var target: Node3D = get_current_target()
	if not target:
		weapon_selection_failed.emit("No target available")
		return 0  # FAILURE
	
	# Check if we need to reselect weapon
	var current_time: float = Time.get_time_from_start()
	if current_time - last_selection_time < selection_cache_duration:
		return 1  # SUCCESS (using cached selection)
	
	# Analyze target and select optimal weapon
	var target_analysis: Dictionary = _analyze_target(target)
	var weapon_selection: WeaponType = _select_optimal_weapon(target, target_analysis)
	
	# Validate weapon selection
	if not _validate_weapon_selection(weapon_selection, target):
		weapon_selection_failed.emit("Selected weapon not available or viable")
		return 0  # FAILURE
	
	# Apply weapon selection
	current_weapon_selection = weapon_selection
	last_selection_time = current_time
	
	# Notify ship controller of weapon selection
	_apply_weapon_selection(weapon_selection, target)
	
	weapon_selected.emit(weapon_selection, target, _get_selection_reason(target_analysis))
	
	return 1  # SUCCESS

func _analyze_target(target: Node3D) -> Dictionary:
	"""Analyze target characteristics for weapon selection"""
	var analysis: Dictionary = {}
	
	# Distance analysis
	var distance: float = get_ship_position().distance_to(target.global_position)
	analysis["distance"] = distance
	analysis["distance_category"] = _categorize_distance(distance)
	
	# Target class analysis
	var target_class: TargetClass = _determine_target_class(target)
	analysis["target_class"] = target_class
	analysis["size_factor"] = _get_target_size_factor(target)
	
	# Velocity and maneuverability analysis
	analysis["target_velocity"] = _get_target_velocity(target)
	analysis["relative_velocity"] = _calculate_relative_velocity(target)
	analysis["maneuverability"] = _assess_target_maneuverability(target)
	
	# Threat assessment
	analysis["threat_level"] = _assess_target_threat_level(target)
	analysis["shield_status"] = _get_target_shield_status(target)
	analysis["armor_rating"] = _get_target_armor_rating(target)
	
	# Tactical context
	analysis["formation_threat"] = _assess_formation_threat_context(target)
	analysis["mission_priority"] = _get_mission_priority_context(target)
	
	return analysis

func _select_optimal_weapon(target: Node3D, analysis: Dictionary) -> WeaponType:
	"""Select optimal weapon based on target analysis and selection criteria"""
	
	if auto_weapon_selection:
		return _auto_select_weapon(target, analysis)
	else:
		return _criteria_based_selection(target, analysis)

func _auto_select_weapon(target: Node3D, analysis: Dictionary) -> WeaponType:
	"""Automatic weapon selection using weighted scoring"""
	var weapon_scores: Dictionary = {}
	
	# Score each available weapon type
	for weapon_type in WeaponType.values():
		if not _is_weapon_available(weapon_type):
			continue
		
		var score: float = _calculate_weapon_score(weapon_type, analysis)
		weapon_scores[weapon_type] = score
	
	# Select highest scoring weapon
	var best_weapon: WeaponType = WeaponType.PRIMARY_GUNS
	var best_score: float = 0.0
	
	for weapon_type in weapon_scores:
		if weapon_scores[weapon_type] > best_score:
			best_score = weapon_scores[weapon_type]
			best_weapon = weapon_type
	
	return best_weapon

func _criteria_based_selection(target: Node3D, analysis: Dictionary) -> WeaponType:
	"""Selection based on specific criteria"""
	match selection_criteria:
		SelectionCriteria.OPTIMAL_RANGE:
			return _select_by_range(analysis["distance"])
		
		SelectionCriteria.TARGET_TYPE:
			return _select_by_target_type(analysis["target_class"])
		
		SelectionCriteria.AMMUNITION_EFFICIENCY:
			return _select_by_ammo_efficiency(analysis)
		
		SelectionCriteria.DAMAGE_MAXIMIZATION:
			return _select_by_damage_potential(analysis)
		
		SelectionCriteria.TACTICAL_SITUATION:
			return _select_by_tactical_situation(analysis)
		
		SelectionCriteria.ENERGY_MANAGEMENT:
			return _select_by_energy_considerations(analysis)
		
		_:
			return preferred_weapon_type

func _calculate_weapon_score(weapon_type: WeaponType, analysis: Dictionary) -> float:
	"""Calculate overall weapon effectiveness score"""
	var specs: Dictionary = weapon_specifications.get(weapon_type, {})
	var score: float = 0.0
	
	# Range score
	var distance: float = analysis["distance"]
	var optimal_range: float = specs.get("optimal_range", 600.0)
	var max_range: float = specs.get("max_range", 1200.0)
	
	var range_score: float = 0.0
	if distance <= optimal_range:
		range_score = 1.0
	elif distance <= max_range:
		range_score = 1.0 - (distance - optimal_range) / (max_range - optimal_range)
	
	score += range_score * range_consideration_factor
	
	# Damage effectiveness score
	var target_class: TargetClass = analysis["target_class"]
	var damage_factor: float = _get_damage_factor_for_target(weapon_type, target_class)
	score += damage_factor * 0.8
	
	# Ammunition consideration
	if specs.get("ammo_limited", false):
		var ammo_factor: float = _get_ammo_conservation_factor(weapon_type)
		score *= ammo_factor
	
	# Energy consideration
	var energy_cost: float = specs.get("energy_cost", 1.0)
	var energy_level: float = _get_ship_energy_level()
	var energy_factor: float = min(1.0, energy_level / energy_cost) if energy_cost > 0.0 else 1.0
	score *= energy_factor
	
	# Historical effectiveness
	var historical_effectiveness: float = _get_historical_effectiveness(weapon_type)
	score *= (0.7 + historical_effectiveness * 0.3)
	
	return score

func _select_by_range(distance: float) -> WeaponType:
	"""Select weapon optimal for current engagement range"""
	var best_weapon: WeaponType = WeaponType.PRIMARY_GUNS
	var best_score: float = 0.0
	
	for weapon_type in WeaponType.values():
		if not _is_weapon_available(weapon_type):
			continue
		
		var specs: Dictionary = weapon_specifications.get(weapon_type, {})
		var optimal_range: float = specs.get("optimal_range", 600.0)
		var max_range: float = specs.get("max_range", 1200.0)
		
		var score: float = 0.0
		if distance <= optimal_range:
			score = 1.0
		elif distance <= max_range:
			score = 1.0 - (distance - optimal_range) / (max_range - optimal_range)
		
		if score > best_score:
			best_score = score
			best_weapon = weapon_type
	
	return best_weapon

func _select_by_target_type(target_class: TargetClass) -> WeaponType:
	"""Select weapon based on target type"""
	match target_class:
		TargetClass.FIGHTER:
			if _is_weapon_available(WeaponType.MISSILES):
				return WeaponType.MISSILES
			return WeaponType.PRIMARY_GUNS
		
		TargetClass.BOMBER:
			if _is_weapon_available(WeaponType.SECONDARY_GUNS):
				return WeaponType.SECONDARY_GUNS
			return WeaponType.PRIMARY_GUNS
		
		TargetClass.CORVETTE, TargetClass.FRIGATE:
			if _is_weapon_available(WeaponType.TORPEDOES):
				return WeaponType.TORPEDOES
			return WeaponType.SECONDARY_GUNS
		
		TargetClass.DESTROYER, TargetClass.CRUISER, TargetClass.BATTLESHIP:
			if _is_weapon_available(WeaponType.TORPEDOES):
				return WeaponType.TORPEDOES
			return WeaponType.SECONDARY_GUNS
		
		TargetClass.TRANSPORT:
			return WeaponType.PRIMARY_GUNS
		
		_:
			return WeaponType.PRIMARY_GUNS

func _select_by_ammo_efficiency(analysis: Dictionary) -> WeaponType:
	"""Select weapon considering ammunition conservation"""
	var target_threat: float = analysis.get("threat_level", 0.5)
	var mission_priority: float = analysis.get("mission_priority", 0.5)
	
	# High priority targets justify special weapon usage
	if target_threat > 0.8 or mission_priority > 0.8:
		var target_class: TargetClass = analysis["target_class"]
		if target_class in [TargetClass.DESTROYER, TargetClass.CRUISER, TargetClass.BATTLESHIP]:
			if _is_weapon_available(WeaponType.TORPEDOES):
				return WeaponType.TORPEDOES
	
	# Default to energy weapons for conservation
	if _get_ship_energy_level() > 0.5:
		return WeaponType.PRIMARY_GUNS
	else:
		# Even with low energy, avoid using limited ammo
		return WeaponType.PRIMARY_GUNS

func _determine_target_class(target: Node3D) -> TargetClass:
	"""Determine target ship class from ship data"""
	if target_class_cache.has(target):
		return target_class_cache[target]
	
	var target_class: TargetClass = TargetClass.UNKNOWN
	
	# Try to get ship class from metadata or method
	if target.has_method("get_ship_class"):
		var ship_class: String = target.get_ship_class().to_lower()
		target_class = _map_ship_class_to_target_class(ship_class)
	elif target.has_meta("ship_class"):
		var ship_class: String = str(target.get_meta("ship_class")).to_lower()
		target_class = _map_ship_class_to_target_class(ship_class)
	else:
		# Fallback: estimate based on size or mass
		target_class = _estimate_target_class_from_size(target)
	
	target_class_cache[target] = target_class
	return target_class

func _map_ship_class_to_target_class(ship_class: String) -> TargetClass:
	"""Map WCS ship class strings to target class enum"""
	if "fighter" in ship_class or "interceptor" in ship_class:
		return TargetClass.FIGHTER
	elif "bomber" in ship_class:
		return TargetClass.BOMBER
	elif "corvette" in ship_class:
		return TargetClass.CORVETTE
	elif "frigate" in ship_class:
		return TargetClass.FRIGATE
	elif "destroyer" in ship_class:
		return TargetClass.DESTROYER
	elif "cruiser" in ship_class:
		return TargetClass.CRUISER
	elif "battleship" in ship_class or "dreadnought" in ship_class:
		return TargetClass.BATTLESHIP
	elif "transport" in ship_class or "cargo" in ship_class:
		return TargetClass.TRANSPORT
	elif "installation" in ship_class or "station" in ship_class:
		return TargetClass.INSTALLATION
	else:
		return TargetClass.UNKNOWN

func _get_damage_factor_for_target(weapon_type: WeaponType, target_class: TargetClass) -> float:
	"""Get weapon damage effectiveness factor for target type"""
	var specs: Dictionary = weapon_specifications.get(weapon_type, {})
	
	match target_class:
		TargetClass.FIGHTER, TargetClass.BOMBER:
			return specs.get("damage_vs_fighter", 1.0)
		TargetClass.CORVETTE, TargetClass.FRIGATE, TargetClass.TRANSPORT:
			return specs.get("damage_vs_bomber", 1.0)
		TargetClass.DESTROYER, TargetClass.CRUISER, TargetClass.BATTLESHIP, TargetClass.INSTALLATION:
			return specs.get("damage_vs_capital", 1.0)
		_:
			return 1.0

func _validate_weapon_selection(weapon_type: WeaponType, target: Node3D) -> bool:
	"""Validate that selected weapon is available and viable"""
	# Check weapon availability
	if not _is_weapon_available(weapon_type):
		return false
	
	# Check range viability
	var distance: float = get_ship_position().distance_to(target.global_position)
	var specs: Dictionary = weapon_specifications.get(weapon_type, {})
	var max_range: float = specs.get("max_range", 1200.0)
	
	if distance > max_range * 1.2:  # Allow some buffer
		return false
	
	# Check ammo availability for limited weapons
	if specs.get("ammo_limited", false):
		var ammo_count: int = _get_weapon_ammo_count(weapon_type)
		if ammo_count <= 0:
			return false
	
	# Check energy availability
	var energy_cost: float = specs.get("energy_cost", 0.0)
	var energy_level: float = _get_ship_energy_level()
	if energy_cost > 0.0 and energy_level < energy_cost * 0.1:
		return false
	
	return true

func _apply_weapon_selection(weapon_type: WeaponType, target: Node3D) -> void:
	"""Apply weapon selection to ship controller"""
	if ship_controller and ship_controller.has_method("set_active_weapon_group"):
		var weapon_group: int = _get_weapon_group_for_type(weapon_type)
		ship_controller.set_active_weapon_group(weapon_group)
	
	# Set targeting mode
	if ship_controller and ship_controller.has_method("set_targeting_mode"):
		var targeting_mode: String = _get_targeting_mode_for_weapon(weapon_type)
		ship_controller.set_targeting_mode(targeting_mode)

func _get_selection_reason(analysis: Dictionary) -> String:
	"""Get human-readable reason for weapon selection"""
	var target_class: String = TargetClass.keys()[analysis.get("target_class", TargetClass.UNKNOWN)]
	var distance: float = analysis.get("distance", 0.0)
	var weapon_name: String = WeaponType.keys()[current_weapon_selection]
	
	return "Selected %s for %s target at %.0fm" % [weapon_name, target_class, distance]

# Helper methods for weapon system integration
func _is_weapon_available(weapon_type: WeaponType) -> bool:
	"""Check if weapon type is available on ship"""
	if not ship_controller:
		return false
	
	var weapon_group: int = _get_weapon_group_for_type(weapon_type)
	
	if ship_controller.has_method("has_weapon_group"):
		return ship_controller.has_weapon_group(weapon_group)
	
	# Fallback assumption
	return true

func _get_weapon_ammo_count(weapon_type: WeaponType) -> int:
	"""Get current ammunition count for weapon type"""
	if not ship_controller:
		return 0
	
	var weapon_group: int = _get_weapon_group_for_type(weapon_type)
	
	if ship_controller.has_method("get_weapon_ammo"):
		return ship_controller.get_weapon_ammo(weapon_group)
	
	# Fallback
	return 10

func _get_ship_energy_level() -> float:
	"""Get current ship energy level (0.0-1.0)"""
	if ship_controller and ship_controller.has_method("get_energy_level"):
		return ship_controller.get_energy_level()
	
	if ai_agent and ai_agent.has_method("get_energy_level"):
		return ai_agent.get_energy_level()
	
	return 1.0

func _get_weapon_group_for_type(weapon_type: WeaponType) -> int:
	"""Map weapon type to weapon group index"""
	match weapon_type:
		WeaponType.PRIMARY_GUNS:
			return 0
		WeaponType.SECONDARY_GUNS:
			return 1
		WeaponType.MISSILES:
			return 2
		WeaponType.TORPEDOES:
			return 3
		WeaponType.SPECIAL_WEAPONS:
			return 4
		WeaponType.DEFENSIVE_WEAPONS:
			return 5
		_:
			return 0

func _get_targeting_mode_for_weapon(weapon_type: WeaponType) -> String:
	"""Get appropriate targeting mode for weapon type"""
	match weapon_type:
		WeaponType.PRIMARY_GUNS, WeaponType.SECONDARY_GUNS:
			return "direct_fire"
		WeaponType.MISSILES:
			return "heat_seeking"
		WeaponType.TORPEDOES:
			return "torpedo_lock"
		WeaponType.SPECIAL_WEAPONS:
			return "special_ordnance"
		_:
			return "direct_fire"

func _categorize_distance(distance: float) -> String:
	"""Categorize engagement distance"""
	if distance < 300.0:
		return "close"
	elif distance < 800.0:
		return "medium"
	elif distance < 2000.0:
		return "long"
	else:
		return "extreme"

func _get_target_velocity(target: Node3D) -> Vector3:
	"""Get target velocity vector"""
	if target.has_method("get_velocity"):
		return target.get_velocity()
	elif target.has_method("get_linear_velocity"):
		return target.get_linear_velocity()
	else:
		return Vector3.ZERO

func _calculate_relative_velocity(target: Node3D) -> Vector3:
	"""Calculate relative velocity between ship and target"""
	var target_velocity: Vector3 = _get_target_velocity(target)
	var ship_velocity: Vector3 = get_ship_velocity()
	return target_velocity - ship_velocity

func _assess_target_maneuverability(target: Node3D) -> float:
	"""Assess target maneuverability (0.0-1.0)"""
	var velocity: Vector3 = _get_target_velocity(target)
	var speed: float = velocity.length()
	
	# Estimate maneuverability based on speed and size
	var size_factor: float = _get_target_size_factor(target)
	var maneuverability: float = min(1.0, speed / 200.0) / size_factor
	
	return clamp(maneuverability, 0.0, 1.0)

func _assess_target_threat_level(target: Node3D) -> float:
	"""Assess target threat level (0.0-1.0)"""
	if target.has_method("get_threat_rating"):
		return target.get_threat_rating()
	
	# Basic threat assessment based on size and weapons
	var size_factor: float = _get_target_size_factor(target)
	var base_threat: float = min(1.0, size_factor * 0.5)
	
	return base_threat

func _get_target_size_factor(target: Node3D) -> float:
	"""Get target size factor for calculations"""
	if target.has_method("get_mass"):
		var mass: float = target.get_mass()
		return mass / 100.0  # Normalize to reasonable scale
	
	# Fallback: estimate from bounding box
	return 1.0

func _get_target_shield_status(target: Node3D) -> float:
	"""Get target shield status (0.0-1.0)"""
	if target.has_method("get_shield_percentage"):
		return target.get_shield_percentage()
	
	return 0.5  # Assume moderate shields

func _get_target_armor_rating(target: Node3D) -> float:
	"""Get target armor rating"""
	if target.has_method("get_armor_rating"):
		return target.get_armor_rating()
	
	return 1.0  # Default armor rating

func _assess_formation_threat_context(target: Node3D) -> float:
	"""Assess threat level considering formation context"""
	# Check if target is in formation with other threats
	var nearby_enemies: int = _count_nearby_enemies(target.global_position, 1000.0)
	return min(1.0, nearby_enemies / 5.0)

func _get_mission_priority_context(target: Node3D) -> float:
	"""Get mission priority for this target"""
	if ai_agent and ai_agent.has_method("get_target_mission_priority"):
		return ai_agent.get_target_mission_priority(target)
	
	return 0.5  # Default priority

func _count_nearby_enemies(position: Vector3, radius: float) -> int:
	"""Count enemy ships near position"""
	# This would integrate with threat detection systems
	return 1  # Placeholder

func _estimate_target_class_from_size(target: Node3D) -> TargetClass:
	"""Estimate target class from size when ship class is unknown"""
	var size_factor: float = _get_target_size_factor(target)
	
	if size_factor < 2.0:
		return TargetClass.FIGHTER
	elif size_factor < 10.0:
		return TargetClass.BOMBER
	elif size_factor < 50.0:
		return TargetClass.CORVETTE
	elif size_factor < 200.0:
		return TargetClass.FRIGATE
	else:
		return TargetClass.DESTROYER

func _select_by_damage_potential(analysis: Dictionary) -> WeaponType:
	"""Select weapon for maximum damage potential"""
	var target_class: TargetClass = analysis["target_class"]
	var best_weapon: WeaponType = WeaponType.PRIMARY_GUNS
	var best_damage: float = 0.0
	
	for weapon_type in WeaponType.values():
		if not _is_weapon_available(weapon_type):
			continue
		
		var damage_factor: float = _get_damage_factor_for_target(weapon_type, target_class)
		if damage_factor > best_damage:
			best_damage = damage_factor
			best_weapon = weapon_type
	
	return best_weapon

func _select_by_tactical_situation(analysis: Dictionary) -> WeaponType:
	"""Select weapon based on tactical situation"""
	var formation_threat: float = analysis.get("formation_threat", 0.0)
	var mission_priority: float = analysis.get("mission_priority", 0.5)
	
	# High threat formation - use area weapons if available
	if formation_threat > 0.7:
		if _is_weapon_available(WeaponType.SPECIAL_WEAPONS):
			return WeaponType.SPECIAL_WEAPONS
	
	# High priority mission target - use best available
	if mission_priority > 0.8:
		return _select_by_target_type(analysis["target_class"])
	
	# Default to range-based selection
	return _select_by_range(analysis["distance"])

func _select_by_energy_considerations(analysis: Dictionary) -> WeaponType:
	"""Select weapon considering energy management"""
	var energy_level: float = _get_ship_energy_level()
	
	# Low energy - prefer ammo-based weapons
	if energy_level < 0.3:
		if _is_weapon_available(WeaponType.MISSILES):
			return WeaponType.MISSILES
		if _is_weapon_available(WeaponType.TORPEDOES):
			return WeaponType.TORPEDOES
	
	# Moderate energy - use efficient energy weapons
	if energy_level < 0.7:
		return WeaponType.PRIMARY_GUNS
	
	# High energy - any weapon is viable
	return _select_by_target_type(analysis["target_class"])

func _get_ammo_conservation_factor(weapon_type: WeaponType) -> float:
	"""Get ammunition conservation factor"""
	var specs: Dictionary = weapon_specifications.get(weapon_type, {})
	if not specs.get("ammo_limited", false):
		return 1.0
	
	var ammo_count: int = _get_weapon_ammo_count(weapon_type)
	var ammo_threshold: int = 5  # Conservative threshold
	
	if ammo_count <= ammo_threshold:
		return ammo_conservation_factor
	else:
		return 1.0

func _get_historical_effectiveness(weapon_type: WeaponType) -> float:
	"""Get historical effectiveness of weapon type"""
	var history: Array = weapon_effectiveness_history.get(weapon_type, [])
	if history.is_empty():
		return 0.5  # Default neutral effectiveness
	
	var total: float = 0.0
	for effectiveness in history:
		total += effectiveness
	
	return total / history.size()

func record_weapon_effectiveness(weapon_type: WeaponType, effectiveness: float) -> void:
	"""Record weapon effectiveness for learning"""
	var history: Array = weapon_effectiveness_history.get(weapon_type, [])
	history.append(effectiveness)
	
	# Keep only recent history
	if history.size() > 10:
		history.pop_front()
	
	weapon_effectiveness_history[weapon_type] = history
	weapon_effectiveness_updated.emit(weapon_type, effectiveness)

func get_current_weapon_selection() -> WeaponType:
	"""Get currently selected weapon type"""
	return current_weapon_selection

func get_weapon_selection_info() -> Dictionary:
	"""Get detailed weapon selection information"""
	return {
		"current_weapon": WeaponType.keys()[current_weapon_selection],
		"selection_time": last_selection_time,
		"cache_remaining": selection_cache_duration - (Time.get_time_from_start() - last_selection_time),
		"available_weapons": _get_available_weapons_list(),
		"effectiveness_history": weapon_effectiveness_history
	}

func _get_available_weapons_list() -> Array[String]:
	"""Get list of available weapon type names"""
	var available: Array[String] = []
	for weapon_type in WeaponType.values():
		if _is_weapon_available(weapon_type):
			available.append(WeaponType.keys()[weapon_type])
	return available

func force_weapon_selection(weapon_type: WeaponType) -> bool:
	"""Force selection of specific weapon type"""
	if not _is_weapon_available(weapon_type):
		return false
	
	current_weapon_selection = weapon_type
	last_selection_time = Time.get_time_from_start()
	
	var target: Node3D = get_current_target()
	if target:
		_apply_weapon_selection(weapon_type, target)
		weapon_selected.emit(weapon_type, target, "Manual weapon selection")
	
	return true