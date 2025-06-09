class_name SwarmWeaponSystem
extends Node

## SHIP-014 AC3: Swarm Weapon System
## Launches coordinated missile groups with spiral flight patterns, target tracking, and sequential firing timing
## Manages swarm missile coordination with authentic WCS spiral mathematics and targeting behavior

# EPIC-002 Asset Core Integration
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")
const ProjectileTypes = preload("res://addons/wcs_asset_core/constants/projectile_types.gd")

# Signals
signal swarm_launched(swarm_id: String, missile_count: int, target: Node)
signal swarm_missile_fired(swarm_id: String, missile_index: int, missile: Node)
signal swarm_formation_complete(swarm_id: String, missiles_active: int)
signal swarm_target_acquired(swarm_id: String, target: Node, lock_strength: float)
signal swarm_missile_impact(missile: Node, target: Node, damage: float)

# Swarm tracking
var active_swarms: Dictionary = {}  # swarm_id -> swarm_data
var swarm_missiles: Dictionary = {}  # missile -> swarm_data
var swarm_targeting_data: Dictionary = {}  # swarm_id -> targeting_info

# Swarm weapon configurations
var swarm_weapon_configs: Dictionary = {
	WeaponTypes.Type.SWARM_MISSILE: {
		"missiles_per_swarm": 4,
		"launch_interval": 0.15,  # 150ms between missiles
		"spiral_radius": 8.0,
		"spiral_frequency": 2.0,  # 2 full spirals per second
		"spiral_duration": 3.0,   # 3 seconds of spiral flight
		"approach_speed": 120.0,
		"tracking_speed": 90.0,
		"damage_per_missile": 45.0,
		"energy_cost_per_missile": 8.0,
		"max_turn_rate": 180.0  # degrees per second
	},
	WeaponTypes.Type.HEAVY_SWARM: {
		"missiles_per_swarm": 6,
		"launch_interval": 0.12,
		"spiral_radius": 12.0,
		"spiral_frequency": 1.5,
		"spiral_duration": 4.0,
		"approach_speed": 100.0,
		"tracking_speed": 80.0,
		"damage_per_missile": 65.0,
		"energy_cost_per_missile": 12.0,
		"max_turn_rate": 150.0
	},
	WeaponTypes.Type.LIGHT_SWARM: {
		"missiles_per_swarm": 3,
		"launch_interval": 0.2,
		"spiral_radius": 6.0,
		"spiral_frequency": 2.5,
		"spiral_duration": 2.5,
		"approach_speed": 140.0,
		"tracking_speed": 110.0,
		"damage_per_missile": 30.0,
		"energy_cost_per_missile": 5.0,
		"max_turn_rate": 210.0
	}
}

# Spiral pattern definitions (WCS-authentic)
var spiral_patterns: Array[Dictionary] = [
	{"type": "vertical", "axis": Vector3.UP, "direction": 1},
	{"type": "horizontal", "axis": Vector3.RIGHT, "direction": 1},
	{"type": "diagonal_1", "axis": Vector3(1, 1, 0).normalized(), "direction": 1},
	{"type": "diagonal_2", "axis": Vector3(1, -1, 0).normalized(), "direction": -1}
]

# Configuration
@export var enable_swarm_debugging: bool = false
@export var enable_spiral_flight: bool = true
@export var enable_target_tracking: bool = true
@export var enable_formation_coordination: bool = true
@export var max_simultaneous_swarms: int = 8
@export var max_missiles_per_frame: int = 2

# System references
var special_weapon_manager: Node = null
var ship_owner: Node = null
var targeting_system: Node = null
var missile_factory: Node = null

# Performance tracking
var swarm_performance_stats: Dictionary = {
	"total_swarms_launched": 0,
	"total_missiles_fired": 0,
	"missiles_hit_target": 0,
	"active_swarms": 0,
	"active_missiles": 0,
	"spiral_calculations_per_second": 0
}

# Update timers
var swarm_update_interval: float = 0.02  # 50 FPS for smooth spiral motion
var swarm_update_timer: float = 0.0
var launch_sequence_timer: float = 0.0

func _ready() -> void:
	_setup_swarm_weapon_system()

## Initialize swarm weapon system
func initialize_swarm_system(owner_ship: Node) -> void:
	ship_owner = owner_ship
	
	# Get system references
	if owner_ship.has_method("get_targeting_system"):
		targeting_system = owner_ship.get_targeting_system()
	
	if owner_ship.has_method("get_missile_factory"):
		missile_factory = owner_ship.get_missile_factory()
	
	if enable_swarm_debugging:
		print("SwarmWeaponSystem: Initialized for ship %s" % ship_owner.name)

## Launch swarm missile system
func launch_swarm_missiles(firing_data: Dictionary) -> String:
	var weapon_type = firing_data.get("weapon_type", WeaponTypes.Type.SWARM_MISSILE)
	var source_position = firing_data.get("source_position", Vector3.ZERO)
	var target = firing_data.get("target", null)
	var firing_ship = firing_data.get("firing_ship", ship_owner)
	var turret_node = firing_data.get("turret_node", null)
	var intensity_modifier = firing_data.get("intensity_modifier", 1.0)
	
	# Validate weapon type
	if not swarm_weapon_configs.has(weapon_type):
		push_error("SwarmWeaponSystem: Invalid swarm weapon type %d" % weapon_type)
		return ""
	
	# Check limits
	if active_swarms.size() >= max_simultaneous_swarms:
		if enable_swarm_debugging:
			print("SwarmWeaponSystem: Maximum swarm limit reached")
		return ""
	
	# Generate unique swarm ID
	var swarm_id = "swarm_%d_%d" % [weapon_type, Time.get_ticks_msec()]
	
	# Create swarm data
	var config = swarm_weapon_configs[weapon_type]
	var swarm_data = _create_swarm_data(swarm_id, weapon_type, source_position, target, firing_ship, turret_node, config, intensity_modifier)
	active_swarms[swarm_id] = swarm_data
	
	# Start launch sequence
	_start_swarm_launch_sequence(swarm_id, swarm_data)
	
	# Update performance stats
	swarm_performance_stats["total_swarms_launched"] += 1
	swarm_performance_stats["active_swarms"] = active_swarms.size()
	
	swarm_launched.emit(swarm_id, config["missiles_per_swarm"], target)
	
	if enable_swarm_debugging:
		print("SwarmWeaponSystem: Launched swarm %s with %d missiles targeting %s" % [
			swarm_id, config["missiles_per_swarm"], target.name if target else "area"
		])
	
	return swarm_id

## Start sequential missile launch sequence
func _start_swarm_launch_sequence(swarm_id: String, swarm_data: Dictionary) -> void:
	swarm_data["launch_sequence_active"] = true
	swarm_data["next_missile_index"] = 0
	swarm_data["next_launch_time"] = Time.get_ticks_msec() / 1000.0
	
	# Launch first missile immediately
	_launch_next_swarm_missile(swarm_id, swarm_data)

## Launch next missile in swarm sequence
func _launch_next_swarm_missile(swarm_id: String, swarm_data: Dictionary) -> void:
	var config = swarm_data["config"]
	var missile_index = swarm_data["next_missile_index"]
	var missiles_per_swarm = config["missiles_per_swarm"]
	
	if missile_index >= missiles_per_swarm:
		# All missiles launched
		swarm_data["launch_sequence_active"] = false
		swarm_formation_complete.emit(swarm_id, missiles_per_swarm)
		
		if enable_swarm_debugging:
			print("SwarmWeaponSystem: Swarm %s launch sequence complete" % swarm_id)
		return
	
	# Create missile
	var missile = _create_swarm_missile(swarm_id, swarm_data, missile_index)
	if missile:
		# Track missile
		swarm_missiles[missile] = swarm_data
		swarm_data["missiles"].append(missile)
		
		# Setup spiral pattern for this missile
		_setup_missile_spiral_pattern(missile, missile_index, swarm_data)
		
		# Update performance stats
		swarm_performance_stats["total_missiles_fired"] += 1
		swarm_performance_stats["active_missiles"] = _count_active_missiles()
		
		swarm_missile_fired.emit(swarm_id, missile_index, missile)
		
		if enable_swarm_debugging:
			print("SwarmWeaponSystem: Launched missile %d of swarm %s" % [missile_index + 1, swarm_id])
	
	# Schedule next missile
	swarm_data["next_missile_index"] += 1
	swarm_data["next_launch_time"] += config["launch_interval"]

## Create swarm missile
func _create_swarm_missile(swarm_id: String, swarm_data: Dictionary, missile_index: int) -> Node:
	var config = swarm_data["config"]
	var source_position = swarm_data["source_position"]
	var target = swarm_data["target"]
	
	# Create missile data
	var missile_data = {
		"missile_type": ProjectileTypes.Type.SWARM_MISSILE,
		"source_position": source_position,
		"target": target,
		"damage": config["damage_per_missile"],
		"speed": config["approach_speed"],
		"tracking_speed": config["tracking_speed"],
		"max_turn_rate": config["max_turn_rate"],
		"firing_ship": swarm_data["firing_ship"],
		"swarm_id": swarm_id,
		"missile_index": missile_index
	}
	
	# Create missile through factory or fallback method
	var missile: Node = null
	if missile_factory and missile_factory.has_method("create_missile"):
		missile = missile_factory.create_missile(missile_data)
	else:
		missile = _create_fallback_missile(missile_data)
	
	return missile

## Create fallback missile when factory unavailable
func _create_fallback_missile(missile_data: Dictionary) -> Node:
	# Create basic missile node structure
	var missile = RigidBody3D.new()
	missile.name = "SwarmMissile_%d" % missile_data["missile_index"]
	missile.set_script(preload("res://scripts/weapons/projectiles/swarm_missile.gd"))
	
	# Add to scene
	get_tree().current_scene.add_child(missile)
	missile.global_position = missile_data["source_position"]
	
	# Initialize missile
	if missile.has_method("initialize_missile"):
		missile.initialize_missile(missile_data)
	
	return missile

## Setup spiral pattern for missile
func _setup_missile_spiral_pattern(missile: Node, missile_index: int, swarm_data: Dictionary) -> void:
	if not enable_spiral_flight:
		return
	
	var config = swarm_data["config"]
	var pattern = spiral_patterns[missile_index % spiral_patterns.size()]
	
	var spiral_data = {
		"pattern_type": pattern["type"],
		"spiral_axis": pattern["axis"],
		"spiral_direction": pattern["direction"],
		"spiral_radius": config["spiral_radius"],
		"spiral_frequency": config["spiral_frequency"],
		"spiral_duration": config["spiral_duration"],
		"start_time": Time.get_ticks_msec() / 1000.0,
		"center_trajectory": Vector3.ZERO  # Will be calculated each frame
	}
	
	# Store spiral data in missile
	if missile.has_method("set_spiral_pattern"):
		missile.set_spiral_pattern(spiral_data)
	else:
		missile.set_meta("spiral_data", spiral_data)

## Update swarm missile flight patterns
func _update_swarm_missiles() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var calculations_this_frame = 0
	
	for missile in swarm_missiles.keys():
		if not is_instance_valid(missile):
			_remove_missile_from_tracking(missile)
			continue
		
		var swarm_data = swarm_missiles[missile]
		
		# Update spiral flight if active
		if enable_spiral_flight:
			_update_missile_spiral_flight(missile, swarm_data, current_time)
			calculations_this_frame += 1
		
		# Update target tracking
		if enable_target_tracking:
			_update_missile_target_tracking(missile, swarm_data, current_time)
		
		# Check for impact or expiration
		_check_missile_status(missile, swarm_data)
	
	# Update performance stats
	swarm_performance_stats["spiral_calculations_per_second"] = calculations_this_frame / swarm_update_interval

## Update missile spiral flight pattern
func _update_missile_spiral_flight(missile: Node, swarm_data: Dictionary, current_time: float) -> void:
	var spiral_data = missile.get_meta("spiral_data", {})
	if spiral_data.is_empty():
		return
	
	var spiral_time = current_time - spiral_data["start_time"]
	
	# Check if spiral phase is complete
	if spiral_time >= spiral_data["spiral_duration"]:
		# Transition to direct approach
		_transition_missile_to_direct_approach(missile, swarm_data)
		return
	
	# Calculate spiral position
	var spiral_position = _calculate_spiral_position(missile, spiral_data, spiral_time)
	
	# Apply spiral movement
	if missile.has_method("set_target_position"):
		missile.set_target_position(spiral_position)
	elif missile.has_method("apply_force"):
		var direction = (spiral_position - missile.global_position).normalized()
		var config = swarm_data["config"]
		var force = direction * config["approach_speed"] * missile.mass
		missile.apply_force(force)

## Calculate spiral position using WCS mathematics
func _calculate_spiral_position(missile: Node, spiral_data: Dictionary, spiral_time: float) -> Vector3:
	var target = swarm_missiles[missile]["target"]
	var source_position = swarm_missiles[missile]["source_position"]
	
	# Base trajectory toward target
	var target_position = target.global_position if target and is_instance_valid(target) else source_position + Vector3.FORWARD * 500.0
	var base_direction = (target_position - source_position).normalized()
	var progress = spiral_time / spiral_data["spiral_duration"]
	var center_point = source_position + base_direction * progress * 300.0  # 300 unit range
	
	# Spiral mathematics (WCS-authentic trigonometric calculations)
	var spiral_frequency = spiral_data["spiral_frequency"]
	var spiral_radius = spiral_data["spiral_radius"]
	var spiral_direction = spiral_data["spiral_direction"]
	var spiral_axis = spiral_data["spiral_axis"]
	
	# Calculate spiral angle
	var spiral_angle = spiral_time * spiral_frequency * 2.0 * PI * spiral_direction
	
	# Create perpendicular vectors for spiral plane
	var spiral_perpendicular_1 = base_direction.cross(spiral_axis).normalized()
	var spiral_perpendicular_2 = base_direction.cross(spiral_perpendicular_1).normalized()
	
	# Calculate spiral offset
	var spiral_offset = (
		spiral_perpendicular_1 * cos(spiral_angle) * spiral_radius +
		spiral_perpendicular_2 * sin(spiral_angle) * spiral_radius
	)
	
	return center_point + spiral_offset

## Transition missile from spiral to direct approach
func _transition_missile_to_direct_approach(missile: Node, swarm_data: Dictionary) -> void:
	# Remove spiral data
	if missile.has_meta("spiral_data"):
		missile.remove_meta("spiral_data")
	
	# Set direct targeting mode
	if missile.has_method("set_flight_mode"):
		missile.set_flight_mode("direct_approach")
	
	var config = swarm_data["config"]
	if missile.has_method("set_tracking_speed"):
		missile.set_tracking_speed(config["tracking_speed"])

## Update missile target tracking
func _update_missile_target_tracking(missile: Node, swarm_data: Dictionary, current_time: float) -> void:
	var target = swarm_data["target"]
	if not target or not is_instance_valid(target):
		return
	
	# Check if missile has tracking capability
	if not missile.has_method("update_target_tracking"):
		return
	
	# Calculate lead vector for moving targets
	var target_velocity = Vector3.ZERO
	if target.has_method("get_linear_velocity"):
		target_velocity = target.get_linear_velocity()
	
	var missile_velocity = Vector3.ZERO
	if missile.has_method("get_linear_velocity"):
		missile_velocity = missile.get_linear_velocity()
	
	var relative_position = target.global_position - missile.global_position
	var closing_speed = missile_velocity.length()
	var time_to_intercept = relative_position.length() / max(closing_speed, 1.0)
	var lead_position = target.global_position + target_velocity * time_to_intercept
	
	# Update missile tracking
	missile.update_target_tracking(lead_position, target_velocity)

## Check missile status for impact or expiration
func _check_missile_status(missile: Node, swarm_data: Dictionary) -> void:
	# Check if missile has hit target
	if missile.has_method("has_impacted") and missile.has_impacted():
		var target = missile.get_meta("impact_target", null)
		var damage = swarm_data["config"]["damage_per_missile"]
		
		if target:
			swarm_missile_impact.emit(missile, target, damage)
			swarm_performance_stats["missiles_hit_target"] += 1
		
		_remove_missile_from_tracking(missile)
		return
	
	# Check for expiration (missiles shouldn't live forever)
	var creation_time = missile.get_meta("creation_time", Time.get_ticks_msec() / 1000.0)
	var current_time = Time.get_ticks_msec() / 1000.0
	var max_lifetime = 30.0  # 30 seconds maximum
	
	if current_time - creation_time > max_lifetime:
		_remove_missile_from_tracking(missile)
		if is_instance_valid(missile):
			missile.queue_free()

## Remove missile from tracking
func _remove_missile_from_tracking(missile: Node) -> void:
	if swarm_missiles.has(missile):
		var swarm_data = swarm_missiles[missile]
		var missiles_array = swarm_data["missiles"]
		var index = missiles_array.find(missile)
		
		if index >= 0:
			missiles_array.remove_at(index)
		
		swarm_missiles.erase(missile)
		swarm_performance_stats["active_missiles"] = _count_active_missiles()

## Process launch sequences
func _process_launch_sequences() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for swarm_id in active_swarms.keys():
		var swarm_data = active_swarms[swarm_id]
		
		if not swarm_data["launch_sequence_active"]:
			continue
		
		# Check if it's time for next missile
		if current_time >= swarm_data["next_launch_time"]:
			_launch_next_swarm_missile(swarm_id, swarm_data)

## Create swarm data structure
func _create_swarm_data(swarm_id: String, weapon_type: int, source_position: Vector3, target: Node, firing_ship: Node, turret_node: Node, config: Dictionary, intensity_modifier: float) -> Dictionary:
	return {
		"swarm_id": swarm_id,
		"weapon_type": weapon_type,
		"source_position": source_position,
		"target": target,
		"firing_ship": firing_ship,
		"turret_node": turret_node,
		"config": config.duplicate(),
		"intensity_modifier": intensity_modifier,
		"creation_time": Time.get_ticks_msec() / 1000.0,
		"launch_sequence_active": false,
		"next_missile_index": 0,
		"next_launch_time": 0.0,
		"missiles": []  # Array of active missiles in this swarm
	}

## Count active missiles across all swarms
func _count_active_missiles() -> int:
	var count = 0
	for swarm_data in active_swarms.values():
		count += swarm_data["missiles"].size()
	return count

## Clean up completed swarms
func _cleanup_completed_swarms() -> void:
	var swarms_to_remove: Array[String] = []
	
	for swarm_id in active_swarms.keys():
		var swarm_data = active_swarms[swarm_id]
		
		# Remove swarms with no active missiles and completed launch sequence
		if swarm_data["missiles"].is_empty() and not swarm_data["launch_sequence_active"]:
			swarms_to_remove.append(swarm_id)
	
	# Remove completed swarms
	for swarm_id in swarms_to_remove:
		active_swarms.erase(swarm_id)
		
		if enable_swarm_debugging:
			print("SwarmWeaponSystem: Cleaned up completed swarm %s" % swarm_id)
	
	swarm_performance_stats["active_swarms"] = active_swarms.size()

## Get swarm system status
func get_swarm_system_status() -> Dictionary:
	return {
		"active_swarms": active_swarms.size(),
		"active_missiles": _count_active_missiles(),
		"spiral_flight_enabled": enable_spiral_flight,
		"target_tracking_enabled": enable_target_tracking,
		"formation_coordination_enabled": enable_formation_coordination,
		"performance_stats": swarm_performance_stats.duplicate()
	}

## Get performance statistics
func get_swarm_performance_statistics() -> Dictionary:
	return swarm_performance_stats.duplicate()

## Get swarm data for specific swarm
func get_swarm_data(swarm_id: String) -> Dictionary:
	return active_swarms.get(swarm_id, {})

## Check if swarm is still active
func is_swarm_active(swarm_id: String) -> bool:
	return active_swarms.has(swarm_id)

## Get missiles in swarm
func get_swarm_missiles(swarm_id: String) -> Array:
	var swarm_data = active_swarms.get(swarm_id, {})
	return swarm_data.get("missiles", [])

## Setup swarm weapon system
func _setup_swarm_weapon_system() -> void:
	active_swarms.clear()
	swarm_missiles.clear()
	swarm_targeting_data.clear()
	
	swarm_update_timer = 0.0
	launch_sequence_timer = 0.0
	
	# Reset performance stats
	swarm_performance_stats = {
		"total_swarms_launched": 0,
		"total_missiles_fired": 0,
		"missiles_hit_target": 0,
		"active_swarms": 0,
		"active_missiles": 0,
		"spiral_calculations_per_second": 0
	}

## Process frame updates
func _process(delta: float) -> void:
	# Update swarm missiles
	swarm_update_timer += delta
	if swarm_update_timer >= swarm_update_interval:
		swarm_update_timer = 0.0
		_update_swarm_missiles()
	
	# Process launch sequences
	_process_launch_sequences()
	
	# Cleanup completed swarms (less frequently)
	launch_sequence_timer += delta
	if launch_sequence_timer >= 1.0:  # Every second
		launch_sequence_timer = 0.0
		_cleanup_completed_swarms()