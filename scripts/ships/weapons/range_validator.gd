class_name RangeValidator
extends Node

## Range and line-of-sight validation system with sensor integration
## Handles sensor range limits, obstacle detection, and stealth mechanics
## Implementation of SHIP-006 AC5: Range and line-of-sight validation

# Constants
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

# Sensor detection ranges (in meters)
const BASE_SENSOR_RANGE: float = 8000.0
const EXTENDED_SENSOR_RANGE: float = 15000.0  # With AWACS support
const CLOSE_RANGE_DETECTION: float = 500.0    # Always detectable within this range
const STEALTH_DETECTION_RANGE: float = 200.0  # Stealth ships detectable within this range

# Detection probabilities for stealth ships
const STEALTH_DETECTION_BASE: float = 0.1      # 10% base detection chance
const STEALTH_DETECTION_CLOSE: float = 1.0     # 100% detection at close range
const STEALTH_DETECTION_ACTIVE: float = 0.3    # 30% when stealth ship is active (firing/moving fast)

# Signals for validation events
signal target_in_range(target: Node3D, range: float, sensor_quality: float)
signal target_out_of_range(target: Node3D, range: float)
signal line_of_sight_clear(target: Node3D)
signal line_of_sight_blocked(target: Node3D, obstruction: Node3D)
signal stealth_target_detected(target: Node3D, detection_chance: float)
signal sensor_interference_detected(interference_level: float)

# Ship and sensor references
var parent_ship: BaseShip
var sensor_range: float = BASE_SENSOR_RANGE
var sensor_quality: float = 1.0  # 0.0 to 1.0 sensor efficiency

# AWACS and extended sensor support
var awacs_ships: Array[BaseShip] = []
var extended_sensor_active: bool = false
var extended_sensor_range: float = 0.0

# Environment effects
var nebula_interference: float = 0.0  # 0.0 to 1.0 interference level
var jamming_interference: float = 0.0  # Electronic warfare interference
var total_interference: float = 0.0

# Stealth detection tracking
var stealth_detection_cache: Dictionary = {}  # target -> detection_data
var detection_cache_duration: float = 1.0  # Cache detection results for 1 second

# Line of sight cache
var los_cache: Dictionary = {}  # target -> {clear: bool, time: float}
var los_cache_duration: float = 0.5  # Cache LOS results for 0.5 seconds

func _init() -> void:
	set_process(true)

func _ready() -> void:
	# Initialize interference levels
	_update_total_interference()

func _process(delta: float) -> void:
	if not parent_ship:
		return
	
	# Update AWACS sensor support
	_update_awacs_support()
	
	# Update environment interference
	_update_environment_interference()
	
	# Clean up old cache entries
	_cleanup_cache_entries()

## Initialize range validator
func initialize_range_validator(ship: BaseShip) -> bool:
	"""Initialize range validator with ship reference.
	
	Args:
		ship: Parent ship reference
		
	Returns:
		true if initialization successful
	"""
	if not ship:
		push_error("RangeValidator: Cannot initialize without valid ship")
		return false
	
	parent_ship = ship
	
	# Initialize sensor range based on ship class
	if ship.ship_class and ship.ship_class.has_method("get_sensor_range"):
		sensor_range = ship.ship_class.get_sensor_range()
	
	return true

## Validate target range and detectability (SHIP-006 AC5)
func validate_target(target: Node3D) -> Dictionary:
	"""Validate target range, line of sight, and detectability.
	
	Args:
		target: Target to validate
		
	Returns:
		Dictionary containing validation results
	"""
	var result: Dictionary = {
		"valid": false,
		"in_range": false,
		"line_of_sight": false,
		"detectable": false,
		"range": 0.0,
		"sensor_quality": 0.0,
		"stealth_detected": false,
		"detection_chance": 0.0,
		"interference_level": total_interference,
		"reason": ""
	}
	
	if not target or not parent_ship:
		result["reason"] = "Invalid target or ship reference"
		return result
	
	# Calculate range
	var range: float = parent_ship.global_position.distance_to(target.global_position)
	result["range"] = range
	
	# Check range limits
	var effective_range: float = _get_effective_sensor_range()
	result["in_range"] = range <= effective_range
	
	if not result["in_range"]:
		result["reason"] = "Target out of sensor range"
		target_out_of_range.emit(target, range)
		return result
	
	# Check line of sight
	result["line_of_sight"] = _check_line_of_sight(target)
	if not result["line_of_sight"]:
		result["reason"] = "Line of sight blocked"
		return result
	
	# Check stealth detection
	var stealth_result: Dictionary = _check_stealth_detection(target, range)
	result["detectable"] = stealth_result["detectable"]
	result["stealth_detected"] = stealth_result["stealth_detected"]
	result["detection_chance"] = stealth_result["detection_chance"]
	
	if not result["detectable"]:
		result["reason"] = "Stealth target not detected"
		return result
	
	# Calculate sensor quality
	result["sensor_quality"] = _calculate_sensor_quality(range)
	
	result["valid"] = true
	target_in_range.emit(target, range, result["sensor_quality"])
	
	return result

## Check line of sight to target (SHIP-006 AC5)
func _check_line_of_sight(target: Node3D) -> bool:
	"""Check if there's clear line of sight to target."""
	if not target or not parent_ship:
		return false
	
	var target_id: int = target.get_instance_id()
	var current_time: float = Time.get_ticks_msec() * 0.001
	
	# Check cache first
	if target_id in los_cache:
		var cache_entry: Dictionary = los_cache[target_id]
		if (current_time - cache_entry["time"]) < los_cache_duration:
			return cache_entry["clear"]
	
	# Perform raycast check
	var space_state := parent_ship.physics_body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		parent_ship.global_position,
		target.global_position,
		(1 << CollisionLayers.Layer.ASTEROIDS) | (1 << CollisionLayers.Layer.INSTALLATIONS) | (1 << CollisionLayers.Layer.DEBRIS)
	)
	
	var result := space_state.intersect_ray(query)
	var clear: bool = result.is_empty()
	
	# Cache result
	los_cache[target_id] = {
		"clear": clear,
		"time": current_time
	}
	
	# Emit appropriate signal
	if clear:
		line_of_sight_clear.emit(target)
	else:
		var obstruction: Node3D = result.get("collider", null)
		line_of_sight_blocked.emit(target, obstruction)
	
	return clear

## Check stealth detection (SHIP-006 AC5)
func _check_stealth_detection(target: Node3D, range: float) -> Dictionary:
	"""Check if stealth target can be detected."""
	var result: Dictionary = {
		"detectable": true,
		"stealth_detected": false,
		"detection_chance": 1.0
	}
	
	# Check if target is a stealth ship
	if not target is BaseShip:
		return result  # Non-ships are always detectable
	
	var target_ship := target as BaseShip
	if not target_ship.has_method("is_stealthed") or not target_ship.is_stealthed():
		return result  # Non-stealth ships are always detectable
	
	# Target is stealthed - check detection
	result["stealth_detected"] = true
	
	var target_id: int = target.get_instance_id()
	var current_time: float = Time.get_ticks_msec() * 0.001
	
	# Check cache first
	if target_id in stealth_detection_cache:
		var cache_entry: Dictionary = stealth_detection_cache[target_id]
		if (current_time - cache_entry["time"]) < detection_cache_duration:
			result["detectable"] = cache_entry["detected"]
			result["detection_chance"] = cache_entry["chance"]
			return result
	
	# Calculate detection chance
	var detection_chance: float = _calculate_stealth_detection_chance(target_ship, range)
	result["detection_chance"] = detection_chance
	
	# Roll for detection
	var detected: bool = randf() < detection_chance
	result["detectable"] = detected
	
	# Cache result
	stealth_detection_cache[target_id] = {
		"detected": detected,
		"chance": detection_chance,
		"time": current_time
	}
	
	if detected:
		stealth_target_detected.emit(target, detection_chance)
	
	return result

## Calculate stealth detection chance
func _calculate_stealth_detection_chance(stealth_ship: BaseShip, range: float) -> float:
	"""Calculate probability of detecting stealth ship."""
	var base_chance: float = STEALTH_DETECTION_BASE
	
	# Range-based detection
	if range <= STEALTH_DETECTION_RANGE:
		# Close range - high detection chance
		var range_factor: float = 1.0 - (range / STEALTH_DETECTION_RANGE)
		base_chance = STEALTH_DETECTION_BASE + (STEALTH_DETECTION_CLOSE - STEALTH_DETECTION_BASE) * range_factor
	
	# Activity-based detection (if ship is active)
	if _is_stealth_ship_active(stealth_ship):
		base_chance = max(base_chance, STEALTH_DETECTION_ACTIVE)
	
	# Sensor quality modifier
	base_chance *= sensor_quality
	
	# Interference penalty
	base_chance *= (1.0 - total_interference * 0.5)  # Up to 50% penalty
	
	# AWACS bonus
	if extended_sensor_active:
		base_chance *= 1.5  # 50% bonus with AWACS
	
	return min(base_chance, 1.0)

## Check if stealth ship is currently active
func _is_stealth_ship_active(stealth_ship: BaseShip) -> bool:
	"""Check if stealth ship is performing detectable activities."""
	if not stealth_ship:
		return false
	
	# Check if ship is firing weapons
	if stealth_ship.has_method("is_firing_weapons") and stealth_ship.is_firing_weapons():
		return true
	
	# Check if ship is moving fast
	if stealth_ship.physics_body and stealth_ship.physics_body.linear_velocity.length() > 50.0:
		return true
	
	# Check if afterburner is active
	if stealth_ship.is_afterburner_active:
		return true
	
	return false

## Get effective sensor range
func _get_effective_sensor_range() -> float:
	"""Get effective sensor range considering all factors."""
	var base_range: float = sensor_range
	
	# AWACS extension
	if extended_sensor_active:
		base_range = max(base_range, extended_sensor_range)
	
	# Sensor quality modifier
	base_range *= sensor_quality
	
	# Interference penalty
	base_range *= (1.0 - total_interference * 0.3)  # Up to 30% range reduction
	
	return max(base_range, CLOSE_RANGE_DETECTION)  # Always detect at close range

## Calculate sensor quality based on range
func _calculate_sensor_quality(range: float) -> float:
	"""Calculate sensor quality degradation with range."""
	var effective_range: float = _get_effective_sensor_range()
	
	if range <= effective_range * 0.5:
		return 1.0  # Perfect quality at close range
	
	# Linear degradation from 50% to 100% range
	var range_factor: float = (range - effective_range * 0.5) / (effective_range * 0.5)
	var quality: float = 1.0 - range_factor * 0.5  # Degrade to 50% quality at max range
	
	# Apply interference
	quality *= (1.0 - total_interference * 0.3)
	
	return max(quality, 0.1)  # Minimum 10% quality

## Update AWACS sensor support
func _update_awacs_support() -> void:
	"""Update extended sensor range from nearby AWACS ships."""
	awacs_ships.clear()
	extended_sensor_active = false
	extended_sensor_range = 0.0
	
	if not parent_ship:
		return
	
	# Find nearby friendly AWACS ships
	var space_state := parent_ship.physics_body.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	
	var sphere := SphereShape3D.new()
	sphere.radius = EXTENDED_SENSOR_RANGE
	query.shape = sphere
	query.transform = Transform3D(Basis(), parent_ship.global_position)
	query.collision_mask = (1 << CollisionLayers.Layer.SHIPS)
	
	var results := space_state.intersect_shape(query)
	
	for result in results:
		var collider := result["collider"] as Node3D
		if not collider:
			continue
		
		var ship := _get_ship_from_collider(collider)
		if _is_awacs_ship(ship) and ship.team == parent_ship.team:
			awacs_ships.append(ship)
			extended_sensor_active = true
			extended_sensor_range = max(extended_sensor_range, EXTENDED_SENSOR_RANGE)

## Get ship from physics collider
func _get_ship_from_collider(collider: Node3D) -> BaseShip:
	"""Extract ship from physics collider."""
	var current_node: Node = collider
	while current_node:
		if current_node is BaseShip:
			return current_node as BaseShip
		current_node = current_node.get_parent()
	return null

## Check if ship is AWACS type
func _is_awacs_ship(ship: BaseShip) -> bool:
	"""Check if ship provides AWACS sensor support."""
	if not ship or not ship.ship_class:
		return false
	
	# Check for AWACS ship class or special sensor subsystem
	if ship.ship_class.has_method("has_awacs_capability"):
		return ship.ship_class.has_awacs_capability()
	
	# Check for advanced sensor subsystems
	if ship.subsystem_manager:
		return ship.subsystem_manager.has_functional_subsystem("Advanced Sensors")
	
	return false

## Update environment interference
func _update_environment_interference() -> void:
	"""Update interference from environment and electronic warfare."""
	# Check for nebula interference
	nebula_interference = _check_nebula_interference()
	
	# Check for electronic jamming
	jamming_interference = _check_jamming_interference()
	
	# Update total interference
	_update_total_interference()

## Check nebula interference
func _check_nebula_interference() -> float:
	"""Check for nebula interference effects."""
	if not parent_ship:
		return 0.0
	
	# This would integrate with environment system
	# For now, return 0.0 (no nebula)
	return 0.0

## Check electronic jamming interference
func _check_jamming_interference() -> float:
	"""Check for electronic warfare jamming."""
	if not parent_ship:
		return 0.0
	
	# This would check for nearby jamming ships
	# For now, return 0.0 (no jamming)
	return 0.0

## Update total interference level
func _update_total_interference() -> void:
	"""Update total interference from all sources."""
	total_interference = min(nebula_interference + jamming_interference, 1.0)
	
	if total_interference > 0.1:  # Significant interference
		sensor_interference_detected.emit(total_interference)

## Clean up cache entries
func _cleanup_cache_entries() -> void:
	"""Remove old cache entries to prevent memory buildup."""
	var current_time: float = Time.get_ticks_msec() * 0.001
	
	# Clean stealth detection cache
	var stealth_keys_to_remove: Array = []
	for target_id in stealth_detection_cache:
		var cache_entry: Dictionary = stealth_detection_cache[target_id]
		if (current_time - cache_entry["time"]) > detection_cache_duration * 2.0:
			stealth_keys_to_remove.append(target_id)
	
	for key in stealth_keys_to_remove:
		stealth_detection_cache.erase(key)
	
	# Clean line of sight cache
	var los_keys_to_remove: Array = []
	for target_id in los_cache:
		var cache_entry: Dictionary = los_cache[target_id]
		if (current_time - cache_entry["time"]) > los_cache_duration * 2.0:
			los_keys_to_remove.append(target_id)
	
	for key in los_keys_to_remove:
		los_cache.erase(key)

## Set sensor parameters
func set_sensor_parameters(range: float, quality: float) -> void:
	"""Set sensor range and quality parameters.
	
	Args:
		range: Sensor detection range in meters
		quality: Sensor quality factor (0.0 to 1.0)
	"""
	sensor_range = range
	sensor_quality = clamp(quality, 0.0, 1.0)

## Clear all caches
func clear_caches() -> void:
	"""Clear all cached detection and line-of-sight data."""
	stealth_detection_cache.clear()
	los_cache.clear()

## Get range validation status
func get_validation_status() -> Dictionary:
	"""Get comprehensive range validation status."""
	return {
		"sensor_range": _get_effective_sensor_range(),
		"sensor_quality": sensor_quality,
		"awacs_active": extended_sensor_active,
		"awacs_count": awacs_ships.size(),
		"interference_level": total_interference,
		"nebula_interference": nebula_interference,
		"jamming_interference": jamming_interference,
		"cache_entries": {
			"stealth_detection": stealth_detection_cache.size(),
			"line_of_sight": los_cache.size()
		}
	}

## Debug information
func debug_info() -> String:
	"""Get debug information string."""
	var info: String = "RangeValidator: "
	info += "Range:%.0fm " % _get_effective_sensor_range()
	info += "Quality:%.1f " % sensor_quality
	if extended_sensor_active:
		info += "AWACS:%d " % awacs_ships.size()
	if total_interference > 0.0:
		info += "Interference:%.1f%% " % (total_interference * 100.0)
	return info