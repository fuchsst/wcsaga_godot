class_name BeamPenetrationSystem
extends Node

## SHIP-013 AC7: Beam Penetration System
## Handles beam stopping, hull piercing, and shield interaction based on target characteristics
## Manages realistic beam penetration mechanics with WCS-authentic behavior

# EPIC-002 Asset Core Integration
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const ShipSizes = preload("res://addons/wcs_asset_core/constants/ship_sizes.gd")

# Signals
signal beam_penetration_calculated(beam_id: String, penetration_data: Dictionary)
signal beam_stopped(beam_id: String, stop_reason: String, stop_location: Vector3)
signal hull_pierced(beam_id: String, entry_point: Vector3, exit_point: Vector3)
signal shield_interaction(beam_id: String, shield_data: Dictionary, interaction_type: String)
signal penetration_limit_reached(beam_id: String, max_penetrations: int)

# Penetration behavior types
enum PenetrationBehavior {
	STOPS_ON_IMPACT = 0,     # Beam stops on first collision
	PIERCES_SMALL_SHIPS = 1,  # Pierces fighters/bombers
	PIERCES_ALL_SHIPS = 2,    # Pierces through all ship types
	SHIELD_ONLY = 3          # Only affects shields, passes through hull
}

# Shield interaction types
enum ShieldInteraction {
	BLOCKS_BEAM = 0,         # Shield completely blocks beam
	REDUCES_DAMAGE = 1,      # Shield reduces beam damage but allows passage
	PENETRATES_SHIELDS = 2,  # Beam passes through shields unchanged
	DRAINS_SHIELDS = 3       # Beam drains shield energy on contact
}

# Beam penetration characteristics
var penetration_configs: Dictionary = {
	0: {  # TYPE_A_STANDARD
		"behavior": PenetrationBehavior.PIERCES_ALL_SHIPS,
		"shield_interaction": ShieldInteraction.REDUCES_DAMAGE,
		"max_penetrations": 3,
		"damage_falloff": 0.15,
		"hull_pierce_threshold": 0.5,
		"shield_drain_rate": 0.3
	},
	1: {  # TYPE_B_SLASH
		"behavior": PenetrationBehavior.STOPS_ON_IMPACT,
		"shield_interaction": ShieldInteraction.BLOCKS_BEAM,
		"max_penetrations": 1,
		"damage_falloff": 0.0,
		"hull_pierce_threshold": 0.0,
		"shield_drain_rate": 0.5
	},
	2: {  # TYPE_C_TARGETING
		"behavior": PenetrationBehavior.STOPS_ON_IMPACT,
		"shield_interaction": ShieldInteraction.BLOCKS_BEAM,
		"max_penetrations": 1,
		"damage_falloff": 0.0,
		"hull_pierce_threshold": 0.0,
		"shield_drain_rate": 0.2
	},
	3: {  # TYPE_D_CHASING
		"behavior": PenetrationBehavior.PIERCES_SMALL_SHIPS,
		"shield_interaction": ShieldInteraction.REDUCES_DAMAGE,
		"max_penetrations": 2,
		"damage_falloff": 0.25,
		"hull_pierce_threshold": 0.3,
		"shield_drain_rate": 0.25
	},
	4: {  # TYPE_E_FIXED
		"behavior": PenetrationBehavior.PIERCES_ALL_SHIPS,
		"shield_interaction": ShieldInteraction.PENETRATES_SHIELDS,
		"max_penetrations": 5,
		"damage_falloff": 0.1,
		"hull_pierce_threshold": 0.7,
		"shield_drain_rate": 0.1
	}
}

# Active beam penetration tracking
var beam_penetration_data: Dictionary = {}  # beam_id -> penetration_tracking
var penetration_calculations: Dictionary = {}  # beam_id -> calculation_cache

# Performance tracking
var penetration_performance_stats: Dictionary = {
	"total_penetration_checks": 0,
	"hull_piercings": 0,
	"shield_interactions": 0,
	"beams_stopped": 0
}

# Configuration
@export var enable_penetration_debugging: bool = false
@export var enable_hull_piercing: bool = true
@export var enable_shield_interactions: bool = true
@export var penetration_calculation_caching: bool = true
@export var cache_validity_time: float = 0.1

# Ship size penetration modifiers
var ship_size_modifiers: Dictionary = {
	ShipSizes.Size.FIGHTER: {
		"hull_resistance": 0.2,
		"pierce_difficulty": 0.3,
		"always_pierceable": true
	},
	ShipSizes.Size.BOMBER: {
		"hull_resistance": 0.4,
		"pierce_difficulty": 0.5,
		"always_pierceable": false
	},
	ShipSizes.Size.CORVETTE: {
		"hull_resistance": 0.6,
		"pierce_difficulty": 0.7,
		"always_pierceable": false
	},
	ShipSizes.Size.FRIGATE: {
		"hull_resistance": 0.8,
		"pierce_difficulty": 0.9,
		"always_pierceable": false
	},
	ShipSizes.Size.DESTROYER: {
		"hull_resistance": 1.0,
		"pierce_difficulty": 1.2,
		"always_pierceable": false
	},
	ShipSizes.Size.CRUISER: {
		"hull_resistance": 1.5,
		"pierce_difficulty": 1.8,
		"always_pierceable": false
	},
	ShipSizes.Size.BATTLESHIP: {
		"hull_resistance": 2.0,
		"pierce_difficulty": 2.5,
		"always_pierceable": false
	},
	ShipSizes.Size.CAPITAL: {
		"hull_resistance": 3.0,
		"pierce_difficulty": 4.0,
		"always_pierceable": false
	}
}

# Armor penetration resistance
var armor_resistance_values: Dictionary = {
	ArmorTypes.Class.LIGHT: 0.1,
	ArmorTypes.Class.STANDARD: 0.3,
	ArmorTypes.Class.HEAVY: 0.6,
	ArmorTypes.Class.CAPITAL: 1.0,
	ArmorTypes.Class.SHIELDED: 0.8,
	ArmorTypes.Class.STEALTH: 0.2
}

func _ready() -> void:
	_setup_penetration_system()

## Initialize penetration system
func initialize_penetration_system() -> void:
	if enable_penetration_debugging:
		print("BeamPenetrationSystem: Initialized")

## Process beam collision for penetration
func process_beam_collision(beam_id: String, collision_data: Dictionary) -> Dictionary:
	var target = collision_data.get("target", null)
	var collision_point = collision_data.get("collision_point", Vector3.ZERO)
	
	if not target or not is_instance_valid(target):
		return {"penetrates": false, "reason": "invalid_target"}
	
	# Get or create beam penetration data
	if not beam_penetration_data.has(beam_id):
		beam_penetration_data[beam_id] = _create_beam_penetration_data(beam_id)
	
	var penetration_data = beam_penetration_data[beam_id]
	var beam_type = penetration_data.get("beam_type", 0)
	var config = penetration_configs.get(beam_type, penetration_configs[0])
	
	# Check penetration limits
	if penetration_data["penetration_count"] >= config["max_penetrations"]:
		penetration_limit_reached.emit(beam_id, config["max_penetrations"])
		_stop_beam(beam_id, "penetration_limit_exceeded", collision_point)
		return {"penetrates": false, "reason": "penetration_limit_exceeded"}
	
	# Calculate penetration result
	var penetration_result = _calculate_penetration(beam_id, target, collision_data, config)
	
	# Update penetration tracking
	if penetration_result.get("penetrates", false):
		penetration_data["penetration_count"] += 1
		penetration_data["targets_penetrated"].append(target)
		penetration_data["penetration_points"].append(collision_point)
		
		# Apply damage falloff
		var damage_falloff = config.get("damage_falloff", 0.0)
		penetration_data["current_damage_multiplier"] *= (1.0 - damage_falloff)
	else:
		# Beam stopped
		_stop_beam(beam_id, penetration_result.get("stop_reason", "collision"), collision_point)
	
	# Emit signals
	beam_penetration_calculated.emit(beam_id, penetration_result)
	
	penetration_performance_stats["total_penetration_checks"] += 1
	
	if enable_penetration_debugging:
		print("BeamPenetrationSystem: Beam %s penetration result: %s" % [
			beam_id, "penetrates" if penetration_result.get("penetrates", false) else "stopped"
		])
	
	return penetration_result

## Calculate penetration for target
func _calculate_penetration(beam_id: String, target: Node, collision_data: Dictionary, config: Dictionary) -> Dictionary:
	var penetration_behavior = config.get("behavior", PenetrationBehavior.STOPS_ON_IMPACT)
	var shield_interaction = config.get("shield_interaction", ShieldInteraction.BLOCKS_BEAM)
	
	# Check shields first
	var shield_result = _process_shield_interaction(beam_id, target, collision_data, shield_interaction)
	if not shield_result.get("beam_continues", true):
		return {
			"penetrates": false,
			"stop_reason": "blocked_by_shields",
			"shield_interaction": shield_result
		}
	
	# Process hull penetration
	var hull_result = _process_hull_penetration(beam_id, target, collision_data, penetration_behavior, config)
	
	return {
		"penetrates": hull_result.get("penetrates", false),
		"stop_reason": hull_result.get("stop_reason", ""),
		"shield_interaction": shield_result,
		"hull_interaction": hull_result,
		"damage_multiplier": shield_result.get("damage_multiplier", 1.0) * hull_result.get("damage_multiplier", 1.0)
	}

## Process shield interaction
func _process_shield_interaction(beam_id: String, target: Node, collision_data: Dictionary, shield_interaction_type: ShieldInteraction) -> Dictionary:
	if not enable_shield_interactions:
		return {"beam_continues": true, "damage_multiplier": 1.0}
	
	# Check if target has shields
	var has_shields = _target_has_shields(target)
	if not has_shields:
		return {"beam_continues": true, "damage_multiplier": 1.0, "no_shields": true}
	
	var shield_strength = _get_shield_strength(target, collision_data.get("collision_point", Vector3.ZERO))
	if shield_strength <= 0.0:
		return {"beam_continues": true, "damage_multiplier": 1.0, "shields_down": true}
	
	var interaction_result = {}
	
	match shield_interaction_type:
		ShieldInteraction.BLOCKS_BEAM:
			interaction_result = _process_shield_blocking(beam_id, target, shield_strength)
		
		ShieldInteraction.REDUCES_DAMAGE:
			interaction_result = _process_shield_damage_reduction(beam_id, target, shield_strength)
		
		ShieldInteraction.PENETRATES_SHIELDS:
			interaction_result = _process_shield_penetration(beam_id, target, shield_strength)
		
		ShieldInteraction.DRAINS_SHIELDS:
			interaction_result = _process_shield_draining(beam_id, target, shield_strength)
	
	# Emit shield interaction signal
	shield_interaction.emit(beam_id, interaction_result, str(shield_interaction_type))
	penetration_performance_stats["shield_interactions"] += 1
	
	return interaction_result

## Process hull penetration
func _process_hull_penetration(beam_id: String, target: Node, collision_data: Dictionary, penetration_behavior: PenetrationBehavior, config: Dictionary) -> Dictionary:
	if not enable_hull_piercing:
		return {"penetrates": false, "stop_reason": "hull_piercing_disabled"}
	
	match penetration_behavior:
		PenetrationBehavior.STOPS_ON_IMPACT:
			return {"penetrates": false, "stop_reason": "beam_design", "damage_multiplier": 1.0}
		
		PenetrationBehavior.PIERCES_SMALL_SHIPS:
			return _process_small_ship_piercing(target, config)
		
		PenetrationBehavior.PIERCES_ALL_SHIPS:
			return _process_all_ship_piercing(target, config)
		
		PenetrationBehavior.SHIELD_ONLY:
			return {"penetrates": false, "stop_reason": "shield_only_beam", "damage_multiplier": 0.0}
		
		_:
			return {"penetrates": false, "stop_reason": "unknown_behavior"}

## Process shield blocking
func _process_shield_blocking(beam_id: String, target: Node, shield_strength: float) -> Dictionary:
	# Shield completely blocks beam
	return {
		"beam_continues": false,
		"blocked_by_shields": true,
		"shield_strength": shield_strength,
		"damage_multiplier": 0.0
	}

## Process shield damage reduction
func _process_shield_damage_reduction(beam_id: String, target: Node, shield_strength: float) -> Dictionary:
	# Shield reduces damage but allows beam to continue
	var reduction_factor = shield_strength / 100.0  # Assuming max shield strength of 100
	reduction_factor = clamp(reduction_factor, 0.1, 0.8)  # 10-80% reduction
	
	var damage_multiplier = 1.0 - reduction_factor
	
	return {
		"beam_continues": true,
		"damage_reduced": true,
		"shield_strength": shield_strength,
		"damage_multiplier": damage_multiplier,
		"reduction_factor": reduction_factor
	}

## Process shield penetration
func _process_shield_penetration(beam_id: String, target: Node, shield_strength: float) -> Dictionary:
	# Beam passes through shields unchanged
	return {
		"beam_continues": true,
		"shield_penetrated": true,
		"shield_strength": shield_strength,
		"damage_multiplier": 1.0
	}

## Process shield draining
func _process_shield_draining(beam_id: String, target: Node, shield_strength: float) -> Dictionary:
	# Beam drains shield energy
	var penetration_data = beam_penetration_data.get(beam_id, {})
	var beam_type = penetration_data.get("beam_type", 0)
	var config = penetration_configs.get(beam_type, penetration_configs[0])
	var drain_rate = config.get("shield_drain_rate", 0.3)
	
	var drained_energy = shield_strength * drain_rate
	var remaining_strength = shield_strength - drained_energy
	
	# Apply shield drain to target
	if target.has_method("drain_shield_energy"):
		target.drain_shield_energy(drained_energy)
	
	return {
		"beam_continues": remaining_strength <= 0.0,
		"shield_drained": true,
		"shield_strength": shield_strength,
		"drained_energy": drained_energy,
		"remaining_strength": remaining_strength,
		"damage_multiplier": 1.0 if remaining_strength <= 0.0 else 0.5
	}

## Process small ship piercing
func _process_small_ship_piercing(target: Node, config: Dictionary) -> Dictionary:
	var ship_size = _get_ship_size(target)
	var size_modifier = ship_size_modifiers.get(ship_size, ship_size_modifiers[ShipSizes.Size.FIGHTER])
	
	# Small ships (fighters, bombers) can be pierced
	if ship_size <= ShipSizes.Size.BOMBER or size_modifier.get("always_pierceable", false):
		var entry_point = _calculate_entry_point(target)
		var exit_point = _calculate_exit_point(target, entry_point)
		
		hull_pierced.emit("beam_id", entry_point, exit_point)
		penetration_performance_stats["hull_piercings"] += 1
		
		return {
			"penetrates": true,
			"hull_pierced": true,
			"ship_size": ship_size,
			"entry_point": entry_point,
			"exit_point": exit_point,
			"damage_multiplier": 1.0 - size_modifier.get("hull_resistance", 0.2)
		}
	else:
		return {
			"penetrates": false,
			"stop_reason": "ship_too_large",
			"ship_size": ship_size,
			"damage_multiplier": 1.0
		}

## Process all ship piercing
func _process_all_ship_piercing(target: Node, config: Dictionary) -> Dictionary:
	var ship_size = _get_ship_size(target)
	var armor_type = _get_armor_type(target)
	var size_modifier = ship_size_modifiers.get(ship_size, ship_size_modifiers[ShipSizes.Size.FIGHTER])
	var armor_resistance = armor_resistance_values.get(armor_type, 0.3)
	
	var hull_pierce_threshold = config.get("hull_pierce_threshold", 0.5)
	var pierce_difficulty = size_modifier.get("pierce_difficulty", 0.3)
	
	# Calculate piercing probability
	var pierce_probability = hull_pierce_threshold - (pierce_difficulty * armor_resistance)
	pierce_probability = clamp(pierce_probability, 0.0, 1.0)
	
	# For deterministic behavior, use ship properties instead of random
	var can_pierce = pierce_probability > 0.4  # 40% threshold for piercing
	
	if can_pierce:
		var entry_point = _calculate_entry_point(target)
		var exit_point = _calculate_exit_point(target, entry_point)
		
		hull_pierced.emit("beam_id", entry_point, exit_point)
		penetration_performance_stats["hull_piercings"] += 1
		
		return {
			"penetrates": true,
			"hull_pierced": true,
			"ship_size": ship_size,
			"armor_type": armor_type,
			"pierce_probability": pierce_probability,
			"entry_point": entry_point,
			"exit_point": exit_point,
			"damage_multiplier": 1.0 - (size_modifier.get("hull_resistance", 0.2) + armor_resistance * 0.5)
		}
	else:
		return {
			"penetrates": false,
			"stop_reason": "hull_too_resistant",
			"ship_size": ship_size,
			"armor_type": armor_type,
			"pierce_probability": pierce_probability,
			"damage_multiplier": 1.0
		}

## Setup penetration system
func _setup_penetration_system() -> void:
	beam_penetration_data.clear()
	penetration_calculations.clear()
	
	# Reset performance stats
	penetration_performance_stats = {
		"total_penetration_checks": 0,
		"hull_piercings": 0,
		"shield_interactions": 0,
		"beams_stopped": 0
	}

## Create beam penetration data
func _create_beam_penetration_data(beam_id: String) -> Dictionary:
	# Get beam type from BeamWeaponSystem
	var beam_type = 0  # Default to Type A
	
	return {
		"beam_id": beam_id,
		"beam_type": beam_type,
		"penetration_count": 0,
		"targets_penetrated": [],
		"penetration_points": [],
		"current_damage_multiplier": 1.0,
		"creation_time": Time.get_ticks_msec() / 1000.0
	}

## Stop beam
func _stop_beam(beam_id: String, reason: String, location: Vector3) -> void:
	beam_stopped.emit(beam_id, reason, location)
	penetration_performance_stats["beams_stopped"] += 1
	
	# Clean up penetration data
	beam_penetration_data.erase(beam_id)
	penetration_calculations.erase(beam_id)

## Target property helpers
func _target_has_shields(target: Node) -> bool:
	return target.has_method("get_shield_strength") or target.has_property("shield_strength")

func _get_shield_strength(target: Node, collision_point: Vector3) -> float:
	if target.has_method("get_shield_strength_at_point"):
		return target.get_shield_strength_at_point(collision_point)
	elif target.has_method("get_shield_strength"):
		return target.get_shield_strength()
	elif target.has_property("shield_strength"):
		return target.shield_strength
	else:
		return 0.0

func _get_ship_size(target: Node) -> int:
	if target.has_method("get_ship_size"):
		return target.get_ship_size()
	elif target.has_property("ship_size"):
		return target.ship_size
	else:
		return ShipSizes.Size.FIGHTER

func _get_armor_type(target: Node) -> int:
	if target.has_method("get_armor_type"):
		return target.get_armor_type()
	elif target.has_property("armor_type"):
		return target.armor_type
	else:
		return ArmorTypes.Class.STANDARD

func _calculate_entry_point(target: Node) -> Vector3:
	# Calculate beam entry point on target hull
	if target.has_method("get_global_position"):
		return target.get_global_position()
	else:
		return target.global_position

func _calculate_exit_point(target: Node, entry_point: Vector3) -> Vector3:
	# Calculate beam exit point through target hull
	# For simplicity, assume beam travels straight through
	var target_position = _calculate_entry_point(target)
	var offset = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	return target_position + offset

## Get penetration statistics
func get_penetration_statistics() -> Dictionary:
	return penetration_performance_stats.duplicate()

## Get beam penetration data
func get_beam_penetration_data(beam_id: String) -> Dictionary:
	return beam_penetration_data.get(beam_id, {}).duplicate()