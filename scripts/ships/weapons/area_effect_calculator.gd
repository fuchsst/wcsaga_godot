class_name AreaEffectCalculator
extends Node

## SHIP-014 AC5: Area Effect Calculator
## Provides accurate range-based damage scaling with inner/outer radius effectiveness zones
## Manages area effect calculations for special weapons with authentic WCS scaling formulas

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")
const ShipSizes = preload("res://addons/wcs_asset_core/constants/ship_sizes.gd")

# Signals
signal area_effect_calculated(effect_id: String, affected_targets: int, total_damage: float)
signal damage_scaling_applied(target: Node, distance: float, scale_factor: float)
signal effectiveness_zone_determined(target: Node, zone_type: String, effectiveness: float)

# Area effect types
enum AreaEffectType {
	EMP_PULSE,
	FLAK_BURST,
	SWARM_EXPLOSION,
	CONCUSSION_WAVE,
	ENERGY_DISCHARGE,
	CHAIN_REACTION
}

# Effectiveness zones
enum EffectivenessZone {
	INNER_RADIUS,     # 100% effectiveness
	MIDDLE_RADIUS,    # Linear scaling
	OUTER_RADIUS,     # Minimum effectiveness
	BEYOND_RANGE      # No effect
}

# Area effect configurations
var area_effect_configs: Dictionary = {
	AreaEffectType.EMP_PULSE: {
		"inner_radius": 50.0,
		"outer_radius": 200.0,
		"minimum_effectiveness": 0.0,  # EMP can be completely ineffective at range
		"falloff_curve": "linear",
		"penetration_factor": 0.8,     # 80% penetration through shields
		"ship_size_modifier": true,
		"damage_type": DamageTypes.Type.ENERGY
	},
	AreaEffectType.FLAK_BURST: {
		"inner_radius": 20.0,
		"outer_radius": 80.0,
		"minimum_effectiveness": 0.1,  # 10% minimum damage at edge
		"falloff_curve": "quadratic",
		"penetration_factor": 1.0,     # Full kinetic damage
		"ship_size_modifier": false,
		"damage_type": DamageTypes.Type.KINETIC
	},
	AreaEffectType.SWARM_EXPLOSION: {
		"inner_radius": 15.0,
		"outer_radius": 60.0,
		"minimum_effectiveness": 0.2,  # 20% minimum
		"falloff_curve": "exponential",
		"penetration_factor": 0.9,
		"ship_size_modifier": false,
		"damage_type": DamageTypes.Type.ENERGY
	},
	AreaEffectType.CONCUSSION_WAVE: {
		"inner_radius": 30.0,
		"outer_radius": 120.0,
		"minimum_effectiveness": 0.05, # 5% minimum
		"falloff_curve": "cubic",
		"penetration_factor": 0.6,     # Reduced penetration
		"ship_size_modifier": true,
		"damage_type": DamageTypes.Type.KINETIC
	},
	AreaEffectType.ENERGY_DISCHARGE: {
		"inner_radius": 40.0,
		"outer_radius": 160.0,
		"minimum_effectiveness": 0.15,
		"falloff_curve": "sqrt",        # Square root falloff
		"penetration_factor": 0.7,
		"ship_size_modifier": true,
		"damage_type": DamageTypes.Type.ENERGY
	},
	AreaEffectType.CHAIN_REACTION: {
		"inner_radius": 25.0,
		"outer_radius": 100.0,
		"minimum_effectiveness": 0.0,  # Can chain or not at all
		"falloff_curve": "step",       # Step function for chain reactions
		"penetration_factor": 1.0,
		"ship_size_modifier": false,
		"damage_type": DamageTypes.Type.ENERGY
	}
}

# Ship size modifiers for area effects
var ship_size_modifiers: Dictionary = {
	ShipSizes.Size.FIGHTER: 1.0,      # Standard modifier
	ShipSizes.Size.BOMBER: 0.9,       # 10% reduction
	ShipSizes.Size.CORVETTE: 0.8,     # 20% reduction
	ShipSizes.Size.FRIGATE: 0.7,      # 30% reduction
	ShipSizes.Size.DESTROYER: 0.6,    # 40% reduction
	ShipSizes.Size.CRUISER: 0.5,      # 50% reduction
	ShipSizes.Size.BATTLESHIP: 0.4,   # 60% reduction
	ShipSizes.Size.CAPITAL: 0.3       # 70% reduction
}

# Configuration
@export var enable_area_debugging: bool = false
@export var enable_ship_size_modifiers: bool = true
@export var enable_penetration_calculations: bool = true
@export var enable_effectiveness_zones: bool = true
@export var enable_line_of_sight_checks: bool = false

# Performance tracking
var calculation_performance_stats: Dictionary = {
	"total_calculations": 0,
	"targets_processed": 0,
	"effectiveness_determinations": 0,
	"line_of_sight_checks": 0,
	"calculation_time_ms": 0.0
}

# Cache for expensive calculations
var calculation_cache: Dictionary = {}
var cache_lifetime: float = 1.0  # 1 second cache
var last_cache_cleanup: float = 0.0

func _ready() -> void:
	_setup_area_effect_calculator()

## Calculate area effect for targets in range
func calculate_area_effect(effect_data: Dictionary) -> Dictionary:
	var start_time = Time.get_ticks_usec()
	
	var effect_type = effect_data.get("effect_type", AreaEffectType.EMP_PULSE)
	var center_position = effect_data.get("center_position", Vector3.ZERO)
	var base_damage = effect_data.get("base_damage", 100.0)
	var targets = effect_data.get("targets", [])
	var firing_team = effect_data.get("firing_team", TeamTypes.Type.UNKNOWN)
	var custom_config = effect_data.get("custom_config", {})
	
	# Get effect configuration
	var config = _get_effect_config(effect_type, custom_config)
	
	var results = {
		"effect_id": "area_effect_%d" % Time.get_ticks_msec(),
		"effect_type": effect_type,
		"center_position": center_position,
		"affected_targets": [],
		"total_damage_dealt": 0.0,
		"targets_in_range": 0,
		"effectiveness_distribution": {}
	}
	
	var total_damage = 0.0
	var targets_affected = 0
	
	# Process each target
	for target in targets:
		var target_result = _calculate_target_effect(target, center_position, base_damage, config, firing_team)
		
		if target_result["affected"]:
			results["affected_targets"].append(target_result)
			total_damage += target_result["damage_dealt"]
			targets_affected += 1
			
			# Track effectiveness distribution
			var zone = target_result["effectiveness_zone"]
			if not results["effectiveness_distribution"].has(zone):
				results["effectiveness_distribution"][zone] = 0
			results["effectiveness_distribution"][zone] += 1
	
	results["total_damage_dealt"] = total_damage
	results["targets_in_range"] = targets_affected
	
	# Update performance stats
	var calculation_time = (Time.get_ticks_usec() - start_time) / 1000.0
	calculation_performance_stats["total_calculations"] += 1
	calculation_performance_stats["targets_processed"] += targets.size()
	calculation_performance_stats["calculation_time_ms"] += calculation_time
	
	area_effect_calculated.emit(results["effect_id"], targets_affected, total_damage)
	
	if enable_area_debugging:
		print("AreaEffectCalculator: Processed %d targets, %d affected, %.1f total damage" % [
			targets.size(), targets_affected, total_damage
		])
	
	return results

## Calculate effect on specific target
func _calculate_target_effect(target: Node, center_position: Vector3, base_damage: float, config: Dictionary, firing_team: int) -> Dictionary:
	var target_position = target.global_position
	var distance = center_position.distance_to(target_position)
	
	var result = {
		"target": target,
		"distance": distance,
		"affected": false,
		"damage_dealt": 0.0,
		"scale_factor": 0.0,
		"effectiveness_zone": EffectivenessZone.BEYOND_RANGE,
		"line_of_sight": true,
		"ship_size_modifier": 1.0,
		"penetration_modifier": 1.0
	}
	
	# Check if target is in range
	var outer_radius = config["outer_radius"]
	if distance > outer_radius:
		return result
	
	# Check line of sight if enabled
	if enable_line_of_sight_checks:
		result["line_of_sight"] = _check_line_of_sight(center_position, target_position)
		if not result["line_of_sight"]:
			return result
		calculation_performance_stats["line_of_sight_checks"] += 1
	
	# Check friendly fire
	if _is_friendly_fire(firing_team, target):
		return result
	
	# Calculate distance-based scaling
	var scale_factor = _calculate_distance_scale_factor(distance, config)
	result["scale_factor"] = scale_factor
	
	# Determine effectiveness zone
	result["effectiveness_zone"] = _determine_effectiveness_zone(distance, config)
	calculation_performance_stats["effectiveness_determinations"] += 1
	
	# Apply ship size modifier if enabled
	if enable_ship_size_modifiers and config["ship_size_modifier"]:
		result["ship_size_modifier"] = _calculate_ship_size_modifier(target)
		scale_factor *= result["ship_size_modifier"]
	
	# Apply penetration modifier
	if enable_penetration_calculations:
		result["penetration_modifier"] = _calculate_penetration_modifier(target, config)
		scale_factor *= result["penetration_modifier"]
	
	# Calculate final damage
	var final_damage = base_damage * scale_factor
	
	# Apply damage if significant
	if final_damage > 1.0:  # Minimum 1 damage to be considered
		result["affected"] = true
		result["damage_dealt"] = final_damage
		
		damage_scaling_applied.emit(target, distance, scale_factor)
		effectiveness_zone_determined.emit(target, _get_zone_name(result["effectiveness_zone"]), scale_factor)
	
	return result

## Calculate distance-based scale factor
func _calculate_distance_scale_factor(distance: float, config: Dictionary) -> float:
	var inner_radius = config["inner_radius"]
	var outer_radius = config["outer_radius"]
	var minimum_effectiveness = config["minimum_effectiveness"]
	var falloff_curve = config["falloff_curve"]
	
	# Full effectiveness within inner radius
	if distance <= inner_radius:
		return 1.0
	
	# No effect beyond outer radius
	if distance >= outer_radius:
		return 0.0
	
	# Calculate normalized distance (0.0 to 1.0)
	var normalized_distance = (distance - inner_radius) / (outer_radius - inner_radius)
	
	# Apply falloff curve
	var falloff_factor = _apply_falloff_curve(normalized_distance, falloff_curve)
	
	# Scale between 1.0 and minimum effectiveness
	return lerp(1.0, minimum_effectiveness, falloff_factor)

## Apply different falloff curve types
func _apply_falloff_curve(normalized_distance: float, curve_type: String) -> float:
	match curve_type:
		"linear":
			return normalized_distance
		"quadratic":
			return normalized_distance * normalized_distance
		"cubic":
			return normalized_distance * normalized_distance * normalized_distance
		"exponential":
			return 1.0 - exp(-3.0 * normalized_distance)  # Exponential decay
		"sqrt":
			return sqrt(normalized_distance)
		"step":
			return 1.0 if normalized_distance < 0.5 else 0.0  # Step function
		_:
			return normalized_distance  # Default to linear

## Determine effectiveness zone for target
func _determine_effectiveness_zone(distance: float, config: Dictionary) -> int:
	var inner_radius = config["inner_radius"]
	var outer_radius = config["outer_radius"]
	var middle_radius = inner_radius + (outer_radius - inner_radius) * 0.6  # 60% point
	
	if distance <= inner_radius:
		return EffectivenessZone.INNER_RADIUS
	elif distance <= middle_radius:
		return EffectivenessZone.MIDDLE_RADIUS
	elif distance <= outer_radius:
		return EffectivenessZone.OUTER_RADIUS
	else:
		return EffectivenessZone.BEYOND_RANGE

## Calculate ship size modifier
func _calculate_ship_size_modifier(target: Node) -> float:
	var ship_size = _get_ship_size(target)
	return ship_size_modifiers.get(ship_size, 1.0)

## Calculate penetration modifier based on shields/armor
func _calculate_penetration_modifier(target: Node, config: Dictionary) -> float:
	var penetration_factor = config["penetration_factor"]
	
	# Check if target has shields
	var has_active_shields = false
	if target.has_method("get_shield_strength"):
		var shield_strength = target.get_shield_strength()
		has_active_shields = shield_strength > 0.0
	elif target.has_method("has_shields"):
		has_active_shields = target.has_shields()
	
	# Penetration factor applies when shields are present
	if has_active_shields:
		return penetration_factor
	else:
		return 1.0  # Full damage to unshielded targets

## Check line of sight between positions
func _check_line_of_sight(start_position: Vector3, end_position: Vector3) -> bool:
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start_position, end_position)
	query.collision_mask = 0b1000  # Obstacle layer
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()  # True if no obstacles found

## Check if attack would be friendly fire
func _is_friendly_fire(firing_team: int, target: Node) -> bool:
	var target_team = _get_target_team(target)
	
	# No friendly fire on same team
	if firing_team == target_team and firing_team != TeamTypes.Type.UNKNOWN:
		return true
	
	# Friendly teams don't attack each other
	if firing_team == TeamTypes.Type.FRIENDLY and target_team == TeamTypes.Type.FRIENDLY:
		return true
	
	return false

## Get target team
func _get_target_team(target: Node) -> int:
	if target.has_method("get_team"):
		return target.get_team()
	elif target.has_property("team"):
		return target.team
	elif target.has_method("get_ship_controller"):
		var ship = target.get_ship_controller()
		if ship and ship.has_method("get_team"):
			return ship.get_team()
	
	return TeamTypes.Type.UNKNOWN

## Get ship size
func _get_ship_size(target: Node) -> int:
	if target.has_method("get_ship_size"):
		return target.get_ship_size()
	elif target.has_method("get_ship_class"):
		var ship_class = target.get_ship_class()
		if ship_class and ship_class.has_method("get", "ship_size"):
			return ship_class.ship_size
	
	return ShipSizes.Size.FIGHTER  # Default

## Get effect configuration with custom overrides
func _get_effect_config(effect_type: int, custom_config: Dictionary) -> Dictionary:
	var base_config = area_effect_configs.get(effect_type, area_effect_configs[AreaEffectType.EMP_PULSE])
	var config = base_config.duplicate()
	
	# Apply custom overrides
	for key in custom_config.keys():
		config[key] = custom_config[key]
	
	return config

## Get zone name for debugging/display
func _get_zone_name(zone: int) -> String:
	match zone:
		EffectivenessZone.INNER_RADIUS:
			return "inner_radius"
		EffectivenessZone.MIDDLE_RADIUS:
			return "middle_radius"
		EffectivenessZone.OUTER_RADIUS:
			return "outer_radius"
		EffectivenessZone.BEYOND_RANGE:
			return "beyond_range"
		_:
			return "unknown"

## Find targets in area using physics query
func find_targets_in_area(center_position: Vector3, radius: float, collision_mask: int = 0b111) -> Array:
	var targets_in_area: Array = []
	
	# Use cached result if available
	var cache_key = "%s_%.1f_%d" % [center_position, radius, collision_mask]
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if calculation_cache.has(cache_key):
		var cached_data = calculation_cache[cache_key]
		if current_time - cached_data["timestamp"] < cache_lifetime:
			return cached_data["targets"]
	
	# Perform physics query
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Create sphere shape for query
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = radius
	query.shape = sphere_shape
	query.transform.origin = center_position
	query.collision_mask = collision_mask
	
	# Execute query
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var collider = result["collider"]
		
		# Filter for valid targets
		if _is_valid_area_target(collider):
			var target = collider
			if collider.has_method("get_ship_controller"):
				target = collider.get_ship_controller()
			
			if target and not targets_in_area.has(target):
				targets_in_area.append(target)
	
	# Cache results
	calculation_cache[cache_key] = {
		"targets": targets_in_area,
		"timestamp": current_time
	}
	
	return targets_in_area

## Check if object is valid area effect target
func _is_valid_area_target(target: Node) -> bool:
	# Ships are primary targets
	if target.has_method("get_ship_controller") or target.has_method("is_ship"):
		return true
	
	# Missiles and projectiles can be affected
	if target.has_method("is_missile") or target.has_method("is_projectile"):
		return true
	
	# Asteroids and debris
	if target.has_method("is_asteroid") or target.has_method("is_debris"):
		return true
	
	# Turrets and subsystems
	if target.has_method("is_turret") or target.has_method("is_subsystem"):
		return true
	
	return false

## Calculate optimal area effect parameters
func calculate_optimal_parameters(targets: Array, desired_coverage: float = 0.8) -> Dictionary:
	if targets.is_empty():
		return {}
	
	# Find center point (centroid of targets)
	var center = Vector3.ZERO
	for target in targets:
		center += target.global_position
	center /= targets.size()
	
	# Calculate distances from center
	var distances: Array[float] = []
	for target in targets:
		distances.append(center.distance_to(target.global_position))
	
	distances.sort()
	
	# Determine radii based on coverage
	var coverage_index = int(distances.size() * desired_coverage)
	var inner_radius = distances[min(coverage_index / 2, distances.size() - 1)]
	var outer_radius = distances[min(coverage_index, distances.size() - 1)]
	
	return {
		"optimal_center": center,
		"inner_radius": inner_radius,
		"outer_radius": outer_radius,
		"targets_in_inner": _count_targets_in_radius(targets, center, inner_radius),
		"targets_in_outer": _count_targets_in_radius(targets, center, outer_radius),
		"coverage_percentage": float(_count_targets_in_radius(targets, center, outer_radius)) / targets.size()
	}

## Count targets within radius
func _count_targets_in_radius(targets: Array, center: Vector3, radius: float) -> int:
	var count = 0
	for target in targets:
		if center.distance_to(target.global_position) <= radius:
			count += 1
	return count

## Get area effect calculator status
func get_area_calculator_status() -> Dictionary:
	return {
		"available_effect_types": area_effect_configs.keys().size(),
		"cache_entries": calculation_cache.size(),
		"ship_size_modifiers_enabled": enable_ship_size_modifiers,
		"penetration_calculations_enabled": enable_penetration_calculations,
		"line_of_sight_checks_enabled": enable_line_of_sight_checks,
		"performance_stats": calculation_performance_stats.duplicate()
	}

## Get performance statistics
func get_calculation_performance_statistics() -> Dictionary:
	return calculation_performance_stats.duplicate()

## Cleanup old cache entries
func _cleanup_cache() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var keys_to_remove: Array[String] = []
	
	for key in calculation_cache.keys():
		var cached_data = calculation_cache[key]
		if current_time - cached_data["timestamp"] > cache_lifetime:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		calculation_cache.erase(key)

## Setup area effect calculator
func _setup_area_effect_calculator() -> void:
	calculation_cache.clear()
	last_cache_cleanup = 0.0
	
	# Reset performance stats
	calculation_performance_stats = {
		"total_calculations": 0,
		"targets_processed": 0,
		"effectiveness_determinations": 0,
		"line_of_sight_checks": 0,
		"calculation_time_ms": 0.0
	}

## Process frame updates
func _process(delta: float) -> void:
	# Periodic cache cleanup
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_cache_cleanup > cache_lifetime:
		last_cache_cleanup = current_time
		_cleanup_cache()