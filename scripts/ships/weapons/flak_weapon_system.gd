class_name FlakWeaponSystem
extends Node

## SHIP-014 AC2: Flak Weapon System
## Provides area denial with predetermined detonation ranges, aim jitter calculations, and defensive barrier coverage
## Manages flak weapon firing with authentic WCS detonation timing and area coverage mechanics

# EPIC-002 Asset Core Integration
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")
const ProjectileTypes = preload("res://addons/wcs_asset_core/constants/projectile_types.gd")

# Signals
signal flak_weapon_fired(flak_id: String, source_position: Vector3, target_area: Vector3)
signal flak_detonated(flak_id: String, detonation_point: Vector3, coverage_radius: float)
signal flak_barrier_created(barrier_id: String, center: Vector3, coverage_area: float)
signal target_intercepted(target: Node, flak_id: String, damage_dealt: float)

# Flak projectile tracking
var active_flak_projectiles: Dictionary = {}  # flak_id -> projectile_data
var flak_barriers: Dictionary = {}  # barrier_id -> barrier_data
var aim_jitter_data: Dictionary = {}  # weapon_mount -> jitter_data

# Flak weapon configurations
var flak_weapon_configs: Dictionary = {
	WeaponTypes.Type.FLAK_CANNON: {
		"projectile_speed": 300.0,
		"detonation_range": 150.0,
		"coverage_radius": 60.0,
		"base_damage": 80.0,
		"fragments_count": 12,
		"minimum_safety_range": 10.0,
		"aim_jitter_base": 0.05,  # 5% base jitter
		"barrier_duration": 8.0,
		"energy_cost": 20.0
	},
	WeaponTypes.Type.FLAK_BURST: {
		"projectile_speed": 250.0,
		"detonation_range": 120.0,
		"coverage_radius": 45.0,
		"base_damage": 60.0,
		"fragments_count": 8,
		"minimum_safety_range": 8.0,
		"aim_jitter_base": 0.08,  # 8% base jitter
		"barrier_duration": 6.0,
		"energy_cost": 15.0
	},
	WeaponTypes.Type.FLAK_AAA: {  # Anti-Aircraft Artillery
		"projectile_speed": 400.0,
		"detonation_range": 200.0,
		"coverage_radius": 80.0,
		"base_damage": 120.0,
		"fragments_count": 16,
		"minimum_safety_range": 15.0,
		"aim_jitter_base": 0.03,  # 3% base jitter
		"barrier_duration": 10.0,
		"energy_cost": 30.0
	}
}

# Configuration
@export var enable_flak_debugging: bool = false
@export var enable_aim_jitter: bool = true
@export var enable_defensive_barriers: bool = true
@export var enable_muzzle_flash_limiting: bool = true
@export var max_simultaneous_flak: int = 25
@export var max_muzzle_flashes_per_frame: int = 8

# System references
var special_weapon_manager: Node = null
var ship_owner: Node = null
var visual_effects_manager: Node = null
var collision_manager: Node = null

# Performance tracking
var flak_performance_stats: Dictionary = {
	"total_flak_fired": 0,
	"total_detonations": 0,
	"targets_intercepted": 0,
	"active_flak_count": 0,
	"active_barriers": 0,
	"muzzle_flashes_limited": 0
}

# Update timers
var projectile_update_interval: float = 0.05  # 50ms updates for projectiles
var projectile_update_timer: float = 0.0
var barrier_update_interval: float = 0.1  # 100ms updates for barriers
var barrier_update_timer: float = 0.0

func _ready() -> void:
	_setup_flak_weapon_system()

## Initialize flak weapon system
func initialize_flak_system(owner_ship: Node) -> void:
	ship_owner = owner_ship
	
	# Get system references
	if owner_ship.has_method("get_visual_effects_manager"):
		visual_effects_manager = owner_ship.get_visual_effects_manager()
	
	if owner_ship.has_method("get_collision_manager"):
		collision_manager = owner_ship.get_collision_manager()
	
	if enable_flak_debugging:
		print("FlakWeaponSystem: Initialized for ship %s" % ship_owner.name)

## Fire flak weapon
func fire_flak_weapon(firing_data: Dictionary) -> String:
	var weapon_type = firing_data.get("weapon_type", WeaponTypes.Type.FLAK_CANNON)
	var source_position = firing_data.get("source_position", Vector3.ZERO)
	var target_position = firing_data.get("target_position", Vector3.ZERO)
	var firing_ship = firing_data.get("firing_ship", ship_owner)
	var weapon_mount = firing_data.get("weapon_mount", null)
	var weapon_health = firing_data.get("weapon_health", 1.0)
	
	# Validate weapon type
	if not flak_weapon_configs.has(weapon_type):
		push_error("FlakWeaponSystem: Invalid flak weapon type %d" % weapon_type)
		return ""
	
	# Check limits
	if active_flak_projectiles.size() >= max_simultaneous_flak:
		if enable_flak_debugging:
			print("FlakWeaponSystem: Maximum flak projectiles limit reached")
		return ""
	
	# Calculate aim jitter
	var jittered_target = _apply_aim_jitter(target_position, weapon_mount, weapon_health)
	
	# Calculate detonation point
	var config = flak_weapon_configs[weapon_type]
	var detonation_point = _calculate_detonation_point(source_position, jittered_target, config)
	
	# Generate unique flak ID
	var flak_id = "flak_%d_%d" % [weapon_type, Time.get_ticks_msec()]
	
	# Create flak projectile
	var projectile_data = _create_flak_projectile_data(flak_id, weapon_type, source_position, detonation_point, firing_ship, config)
	active_flak_projectiles[flak_id] = projectile_data
	
	# Create muzzle flash (with limiting)
	if enable_muzzle_flash_limiting:
		_create_limited_muzzle_flash(source_position, weapon_type)
	
	# Update performance stats
	flak_performance_stats["total_flak_fired"] += 1
	flak_performance_stats["active_flak_count"] = active_flak_projectiles.size()
	
	flak_weapon_fired.emit(flak_id, source_position, jittered_target)
	
	if enable_flak_debugging:
		print("FlakWeaponSystem: Fired flak %s from %s to %s (detonation at %s)" % [
			flak_id, source_position, jittered_target, detonation_point
		])
	
	return flak_id

## Apply aim jitter based on weapon health and subsystem damage
func _apply_aim_jitter(target_position: Vector3, weapon_mount: Node, weapon_health: float) -> Vector3:
	if not enable_aim_jitter:
		return target_position
	
	# Calculate jitter amount
	var jitter_data = _get_or_create_jitter_data(weapon_mount)
	var base_jitter = jitter_data.get("base_jitter", 0.05)
	
	# Health degradation increases jitter
	var health_factor = 1.0 - weapon_health  # 0.0 = healthy, 1.0 = destroyed
	var total_jitter = base_jitter * (1.0 + health_factor * 2.0)  # Up to 3x jitter when damaged
	
	# Apply random jitter in cone around target
	var jitter_distance = target_position.length() * total_jitter
	var jitter_offset = Vector3(
		randf_range(-jitter_distance, jitter_distance),
		randf_range(-jitter_distance, jitter_distance),
		randf_range(-jitter_distance, jitter_distance)
	)
	
	return target_position + jitter_offset

## Calculate predetermined detonation point
func _calculate_detonation_point(source: Vector3, target: Vector3, config: Dictionary) -> Vector3:
	var direction = (target - source).normalized()
	var distance_to_target = source.distance_to(target)
	var detonation_range = config["detonation_range"]
	var minimum_safety_range = config["minimum_safety_range"]
	
	# Ensure minimum safety distance
	var travel_distance = max(minimum_safety_range, min(distance_to_target, detonation_range))
	
	return source + direction * travel_distance

## Create flak detonation at specified point
func detonate_flak(flak_id: String) -> void:
	if not active_flak_projectiles.has(flak_id):
		return
	
	var projectile_data = active_flak_projectiles[flak_id]
	var detonation_point = projectile_data["detonation_point"]
	var config = projectile_data["config"]
	var coverage_radius = config["coverage_radius"]
	
	# Create fragments and damage area
	_create_flak_detonation_effects(flak_id, detonation_point, config)
	
	# Find and damage targets in area
	var targets_hit = _apply_area_damage(detonation_point, coverage_radius, projectile_data)
	
	# Create defensive barrier if enabled
	if enable_defensive_barriers:
		_create_defensive_barrier(flak_id, detonation_point, config)
	
	# Remove projectile from tracking
	active_flak_projectiles.erase(flak_id)
	
	# Update performance stats
	flak_performance_stats["total_detonations"] += 1
	flak_performance_stats["targets_intercepted"] += targets_hit
	flak_performance_stats["active_flak_count"] = active_flak_projectiles.size()
	
	flak_detonated.emit(flak_id, detonation_point, coverage_radius)
	
	if enable_flak_debugging:
		print("FlakWeaponSystem: Flak %s detonated at %s, hit %d targets" % [
			flak_id, detonation_point, targets_hit
		])

## Create defensive barrier from flak detonation
func _create_defensive_barrier(flak_id: String, center: Vector3, config: Dictionary) -> void:
	var barrier_id = "barrier_%s" % flak_id
	var coverage_area = config["coverage_radius"] * 1.5  # Barriers slightly larger than damage area
	var duration = config["barrier_duration"]
	
	var barrier_data = {
		"barrier_id": barrier_id,
		"center": center,
		"coverage_area": coverage_area,
		"creation_time": Time.get_ticks_msec() / 1000.0,
		"end_time": (Time.get_ticks_msec() / 1000.0) + duration,
		"active": true,
		"fragment_density": config["fragments_count"] / coverage_area
	}
	
	flak_barriers[barrier_id] = barrier_data
	flak_performance_stats["active_barriers"] = flak_barriers.size()
	
	flak_barrier_created.emit(barrier_id, center, coverage_area)
	
	if enable_flak_debugging:
		print("FlakWeaponSystem: Created defensive barrier %s at %s" % [barrier_id, center])

## Apply area damage from flak detonation
func _apply_area_damage(detonation_point: Vector3, radius: float, projectile_data: Dictionary) -> int:
	var config = projectile_data["config"]
	var base_damage = config["base_damage"]
	var fragments_count = config["fragments_count"]
	var firing_team = projectile_data.get("firing_team", TeamTypes.Type.UNKNOWN)
	
	var targets_hit = 0
	var nearby_targets = _find_targets_in_area(detonation_point, radius)
	
	for target in nearby_targets:
		# Skip friendly fire
		if _is_friendly_fire(firing_team, target):
			continue
		
		# Calculate damage based on distance and fragment density
		var distance = detonation_point.distance_to(target.global_position)
		var damage_multiplier = _calculate_flak_damage_multiplier(distance, radius)
		var fragments_hitting = max(1, int(fragments_count * damage_multiplier))
		var total_damage = base_damage * damage_multiplier
		
		# Apply damage
		if _apply_flak_damage_to_target(target, total_damage, fragments_hitting, detonation_point):
			targets_hit += 1
			target_intercepted.emit(target, projectile_data["flak_id"], total_damage)
	
	return targets_hit

## Calculate damage multiplier based on distance from detonation
func _calculate_flak_damage_multiplier(distance: float, max_radius: float) -> float:
	if distance >= max_radius:
		return 0.0
	
	# Flak has relatively uniform damage within burst radius
	# Unlike EMP, fragments provide more consistent coverage
	var falloff_factor = 1.0 - (distance / max_radius) * 0.7  # 30% falloff at edge
	return max(0.1, falloff_factor)  # Minimum 10% damage at edge

## Apply flak damage to target
func _apply_flak_damage_to_target(target: Node, damage: float, fragments: int, source_position: Vector3) -> bool:
	var damage_data = {
		"damage_amount": damage,
		"damage_type": DamageTypes.Type.KINETIC,  # Flak is kinetic fragmentation damage
		"source_position": source_position,
		"fragment_count": fragments,
		"is_flak_damage": true,
		"damage_time": Time.get_ticks_msec() / 1000.0
	}
	
	# Apply damage using available method
	if target.has_method("apply_damage"):
		return target.apply_damage(damage_data)
	elif target.has_method("apply_hull_damage"):
		return target.apply_hull_damage(damage)
	
	return false

## Find targets in area for flak damage
func _find_targets_in_area(center: Vector3, radius: float) -> Array:
	var targets_in_area: Array = []
	
	# Use physics server for efficient area query
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Create sphere shape for query
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = radius
	query.shape = sphere_shape
	query.transform.origin = center
	query.collision_mask = 0b111  # Ships, missiles, and asteroids
	
	# Perform query
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var collider = result["collider"]
		
		# Check if it's a valid target
		if _is_valid_flak_target(collider):
			targets_in_area.append(collider)
	
	return targets_in_area

## Check if object is valid flak target
func _is_valid_flak_target(target: Node) -> bool:
	# Ships are primary targets
	if target.has_method("get_ship_controller") or target.has_method("is_ship"):
		return true
	
	# Missiles and projectiles are also targets
	if target.has_method("is_missile") or target.has_method("is_projectile"):
		return true
	
	# Asteroids and debris can be targeted
	if target.has_method("is_asteroid") or target.has_method("is_debris"):
		return true
	
	return false

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

## Create flak detonation visual effects
func _create_flak_detonation_effects(flak_id: String, detonation_point: Vector3, config: Dictionary) -> void:
	if not visual_effects_manager:
		return
	
	var effect_data = {
		"effect_type": "flak_detonation",
		"location": detonation_point,
		"coverage_radius": config["coverage_radius"],
		"fragments_count": config["fragments_count"],
		"intensity": config["base_damage"] / 100.0  # Normalize for effect intensity
	}
	
	if visual_effects_manager.has_method("create_flak_burst_effect"):
		visual_effects_manager.create_flak_burst_effect(effect_data)

## Create limited muzzle flash effects
func _create_limited_muzzle_flash(source_position: Vector3, weapon_type: int) -> void:
	# Track muzzle flashes this frame
	var frame_flashes = get_meta("frame_muzzle_flashes", 0)
	
	if frame_flashes >= max_muzzle_flashes_per_frame:
		flak_performance_stats["muzzle_flashes_limited"] += 1
		return
	
	set_meta("frame_muzzle_flashes", frame_flashes + 1)
	
	if visual_effects_manager and visual_effects_manager.has_method("create_muzzle_flash"):
		var effect_data = {
			"effect_type": "flak_muzzle_flash",
			"location": source_position,
			"weapon_type": weapon_type
		}
		visual_effects_manager.create_muzzle_flash(effect_data)

## Get or create aim jitter data for weapon mount
func _get_or_create_jitter_data(weapon_mount: Node) -> Dictionary:
	if not weapon_mount:
		return {"base_jitter": 0.05}
	
	if not aim_jitter_data.has(weapon_mount):
		aim_jitter_data[weapon_mount] = {
			"base_jitter": 0.05,
			"subsystem_health": 1.0,
			"last_jitter_calculation": 0.0
		}
	
	return aim_jitter_data[weapon_mount]

## Create flak projectile data
func _create_flak_projectile_data(flak_id: String, weapon_type: int, source_position: Vector3, detonation_point: Vector3, firing_ship: Node, config: Dictionary) -> Dictionary:
	return {
		"flak_id": flak_id,
		"weapon_type": weapon_type,
		"source_position": source_position,
		"detonation_point": detonation_point,
		"firing_ship": firing_ship,
		"firing_team": _get_target_team(firing_ship),
		"config": config.duplicate(),
		"creation_time": Time.get_ticks_msec() / 1000.0,
		"travel_distance": source_position.distance_to(detonation_point),
		"current_position": source_position
	}

## Process flak projectile updates
func _process_flak_projectiles() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var flak_ids_to_detonate: Array[String] = []
	
	for flak_id in active_flak_projectiles.keys():
		var projectile_data = active_flak_projectiles[flak_id]
		var config = projectile_data["config"]
		var travel_time = current_time - projectile_data["creation_time"]
		var expected_travel_time = projectile_data["travel_distance"] / config["projectile_speed"]
		
		# Update projectile position
		var progress = min(1.0, travel_time / expected_travel_time)
		projectile_data["current_position"] = projectile_data["source_position"].lerp(
			projectile_data["detonation_point"], progress
		)
		
		# Check if it's time to detonate
		if travel_time >= expected_travel_time:
			flak_ids_to_detonate.append(flak_id)
	
	# Detonate projectiles that have reached their destination
	for flak_id in flak_ids_to_detonate:
		detonate_flak(flak_id)

## Process defensive barrier updates
func _process_defensive_barriers() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var barriers_to_remove: Array[String] = []
	
	for barrier_id in flak_barriers.keys():
		var barrier_data = flak_barriers[barrier_id]
		
		if current_time >= barrier_data["end_time"]:
			barriers_to_remove.append(barrier_id)
	
	# Remove expired barriers
	for barrier_id in barriers_to_remove:
		_remove_defensive_barrier(barrier_id)

## Remove defensive barrier
func _remove_defensive_barrier(barrier_id: String) -> void:
	if not flak_barriers.has(barrier_id):
		return
	
	flak_barriers.erase(barrier_id)
	flak_performance_stats["active_barriers"] = flak_barriers.size()
	
	if enable_flak_debugging:
		print("FlakWeaponSystem: Removed expired barrier %s" % barrier_id)

## Get flak system status
func get_flak_system_status() -> Dictionary:
	return {
		"active_projectiles": active_flak_projectiles.size(),
		"active_barriers": flak_barriers.size(),
		"aim_jitter_enabled": enable_aim_jitter,
		"defensive_barriers_enabled": enable_defensive_barriers,
		"performance_stats": flak_performance_stats.duplicate()
	}

## Get performance statistics
func get_flak_performance_statistics() -> Dictionary:
	return flak_performance_stats.duplicate()

## Check if area is covered by flak barrier
func is_area_covered_by_flak(position: Vector3, radius: float = 0.0) -> bool:
	for barrier_data in flak_barriers.values():
		var distance = position.distance_to(barrier_data["center"])
		var coverage = barrier_data["coverage_area"] + radius
		
		if distance <= coverage:
			return true
	
	return false

## Get flak coverage density at position
func get_flak_coverage_density(position: Vector3) -> float:
	var total_density = 0.0
	
	for barrier_data in flak_barriers.values():
		var distance = position.distance_to(barrier_data["center"])
		var max_range = barrier_data["coverage_area"]
		
		if distance <= max_range:
			var coverage_factor = 1.0 - (distance / max_range)
			total_density += barrier_data["fragment_density"] * coverage_factor
	
	return total_density

## Setup flak weapon system
func _setup_flak_weapon_system() -> void:
	active_flak_projectiles.clear()
	flak_barriers.clear()
	aim_jitter_data.clear()
	
	projectile_update_timer = 0.0
	barrier_update_timer = 0.0
	
	# Reset frame-based tracking
	if has_meta("frame_muzzle_flashes"):
		remove_meta("frame_muzzle_flashes")
	
	# Reset performance stats
	flak_performance_stats = {
		"total_flak_fired": 0,
		"total_detonations": 0,
		"targets_intercepted": 0,
		"active_flak_count": 0,
		"active_barriers": 0,
		"muzzle_flashes_limited": 0
	}

## Process frame updates
func _process(delta: float) -> void:
	# Reset frame-based counters
	if has_meta("frame_muzzle_flashes"):
		set_meta("frame_muzzle_flashes", 0)
	
	# Update projectiles
	projectile_update_timer += delta
	if projectile_update_timer >= projectile_update_interval:
		projectile_update_timer = 0.0
		_process_flak_projectiles()
	
	# Update barriers
	barrier_update_timer += delta
	if barrier_update_timer >= barrier_update_interval:
		barrier_update_timer = 0.0
		_process_defensive_barriers()