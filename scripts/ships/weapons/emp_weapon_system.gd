class_name EMPWeaponSystem
extends Node

## SHIP-014 AC1: EMP Weapon System
## Creates electromagnetic pulse effects with range-based intensity, system disruption, and visual interference
## Manages EMP weapon firing, effect duration, and ship system impact with WCS-authentic mechanics

# EPIC-002 Asset Core Integration
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")
const ShipSizes = preload("res://addons/wcs_asset_core/constants/ship_sizes.gd")

# Signals
signal emp_weapon_fired(emp_id: String, location: Vector3, intensity: float)
signal emp_effect_applied(target: Node, intensity: float, duration: float)
signal emp_effect_expired(target: Node, emp_id: String)
signal ship_system_disrupted(target: Node, system: String, disruption_level: float)

# EMP effect tracking
var active_emp_effects: Dictionary = {}  # emp_id -> emp_data
var affected_ships: Dictionary = {}  # ship -> emp_effects_array
var system_disruptions: Dictionary = {}  # ship -> system_disruption_data

# EMP configuration
@export var enable_emp_debugging: bool = false
@export var enable_visual_effects: bool = true
@export var enable_hud_disruption: bool = true
@export var enable_ai_disruption: bool = true
@export var max_simultaneous_emp_effects: int = 10

# EMP weapon specifications
var emp_weapon_configs: Dictionary = {
	WeaponTypes.Type.EMP_BOMB: {
		"effect_duration": 15.0,
		"inner_radius": 50.0,
		"outer_radius": 200.0,
		"base_intensity": 1.0,
		"energy_cost": 25.0,
		"disruption_types": ["targeting", "engines", "weapons", "hud", "ai"]
	},
	WeaponTypes.Type.EMP_MISSILE: {
		"effect_duration": 12.0,
		"inner_radius": 30.0,
		"outer_radius": 150.0,
		"base_intensity": 0.8,
		"energy_cost": 15.0,
		"disruption_types": ["targeting", "hud", "weapons"]
	},
	WeaponTypes.Type.EMP_CANNON: {
		"effect_duration": 8.0,
		"inner_radius": 20.0,
		"outer_radius": 100.0,
		"base_intensity": 0.6,
		"energy_cost": 10.0,
		"disruption_types": ["targeting", "hud"]
	}
}

# Ship resistance by size
var emp_resistance_by_size: Dictionary = {
	ShipSizes.Size.FIGHTER: 0.0,      # No resistance - fully affected
	ShipSizes.Size.BOMBER: 0.1,       # 10% resistance
	ShipSizes.Size.CORVETTE: 0.3,     # 30% resistance
	ShipSizes.Size.FRIGATE: 0.5,      # 50% resistance
	ShipSizes.Size.DESTROYER: 0.7,    # 70% resistance
	ShipSizes.Size.CRUISER: 0.8,      # 80% resistance
	ShipSizes.Size.BATTLESHIP: 0.9,   # 90% resistance
	ShipSizes.Size.CAPITAL: 0.95      # 95% resistance - turrets only
}

# System references
var special_weapon_manager: Node = null
var ship_owner: Node = null
var visual_effects_manager: Node = null
var hud_system: Node = null

# Performance tracking
var emp_performance_stats: Dictionary = {
	"total_emp_fired": 0,
	"total_ships_affected": 0,
	"active_emp_count": 0,
	"system_disruptions_applied": 0
}

# Update timer
var effect_update_timer: float = 0.0
var effect_update_interval: float = 0.1  # Update every 100ms

func _ready() -> void:
	_setup_emp_weapon_system()

## Initialize EMP weapon system
func initialize_emp_system(owner_ship: Node) -> void:
	ship_owner = owner_ship
	
	# Get system references
	if owner_ship.has_method("get_visual_effects_manager"):
		visual_effects_manager = owner_ship.get_visual_effects_manager()
	
	if owner_ship.has_method("get_hud_system"):
		hud_system = owner_ship.get_hud_system()
	
	if enable_emp_debugging:
		print("EMPWeaponSystem: Initialized for ship %s" % ship_owner.name)

## Fire EMP weapon
func fire_emp_weapon(firing_data: Dictionary) -> String:
	var weapon_type = firing_data.get("weapon_type", WeaponTypes.Type.EMP_BOMB)
	var target_location = firing_data.get("target_location", Vector3.ZERO)
	var firing_ship = firing_data.get("firing_ship", ship_owner)
	var intensity_modifier = firing_data.get("intensity_modifier", 1.0)
	
	# Validate weapon type
	if not emp_weapon_configs.has(weapon_type):
		push_error("EMPWeaponSystem: Invalid EMP weapon type %d" % weapon_type)
		return ""
	
	# Check limits
	if active_emp_effects.size() >= max_simultaneous_emp_effects:
		if enable_emp_debugging:
			print("EMPWeaponSystem: Maximum EMP effects limit reached")
		return ""
	
	# Generate unique EMP ID
	var emp_id = "emp_%d_%d" % [weapon_type, Time.get_ticks_msec()]
	
	# Create EMP effect
	var emp_data = _create_emp_effect_data(emp_id, weapon_type, target_location, firing_ship, intensity_modifier)
	active_emp_effects[emp_id] = emp_data
	
	# Apply EMP effects to nearby ships
	_apply_emp_effects(emp_id, emp_data)
	
	# Create visual and audio effects
	if enable_visual_effects:
		_create_emp_visual_effects(emp_data)
	
	# Update performance stats
	emp_performance_stats["total_emp_fired"] += 1
	emp_performance_stats["active_emp_count"] = active_emp_effects.size()
	
	emp_weapon_fired.emit(emp_id, target_location, emp_data["base_intensity"])
	
	if enable_emp_debugging:
		print("EMPWeaponSystem: Fired EMP %s at %s with intensity %.2f" % [
			emp_id, target_location, emp_data["base_intensity"]
		])
	
	return emp_id

## Apply EMP effects to ships in range
func _apply_emp_effects(emp_id: String, emp_data: Dictionary) -> void:
	var affected_count = 0
	var target_location = emp_data["target_location"]
	var inner_radius = emp_data["inner_radius"]
	var outer_radius = emp_data["outer_radius"]
	var base_intensity = emp_data["base_intensity"]
	var firing_team = emp_data.get("firing_team", TeamTypes.Type.UNKNOWN)
	
	# Find all ships in range
	var nearby_ships = _find_ships_in_range(target_location, outer_radius)
	
	for ship in nearby_ships:
		var distance = target_location.distance_to(ship.global_position)
		
		# Skip friendly fire if protection enabled
		if _is_friendly_fire(firing_team, ship):
			continue
		
		# Calculate intensity based on distance
		var intensity = _calculate_emp_intensity(distance, inner_radius, outer_radius, base_intensity)
		
		# Apply ship size resistance
		var ship_size = _get_ship_size(ship)
		var resistance = emp_resistance_by_size.get(ship_size, 0.0)
		intensity *= (1.0 - resistance)
		
		# Skip if intensity too low to matter
		if intensity < 0.1:
			continue
		
		# Apply EMP effects to ship
		_apply_emp_to_ship(emp_id, ship, intensity, emp_data)
		affected_count += 1
	
	# Update performance stats
	emp_performance_stats["total_ships_affected"] += affected_count
	
	if enable_emp_debugging:
		print("EMPWeaponSystem: EMP %s affected %d ships" % [emp_id, affected_count])

## Apply EMP effects to specific ship
func _apply_emp_to_ship(emp_id: String, ship: Node, intensity: float, emp_data: Dictionary) -> void:
	var duration = emp_data["effect_duration"] * intensity  # Duration scales with intensity
	var disruption_types = emp_data["disruption_types"]
	
	# Track ship as affected
	if not affected_ships.has(ship):
		affected_ships[ship] = []
	
	var ship_effect_data = {
		"emp_id": emp_id,
		"ship": ship,
		"intensity": intensity,
		"duration": duration,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"end_time": (Time.get_ticks_msec() / 1000.0) + duration,
		"disruption_types": disruption_types
	}
	
	affected_ships[ship].append(ship_effect_data)
	
	# Apply system disruptions
	for disruption_type in disruption_types:
		_apply_system_disruption(ship, disruption_type, intensity, duration)
	
	# Apply visual effects to ship
	if enable_visual_effects:
		_apply_ship_emp_visual_effects(ship, intensity, duration)
	
	emp_effect_applied.emit(ship, intensity, duration)
	
	if enable_emp_debugging:
		print("EMPWeaponSystem: Applied EMP to %s - intensity %.2f, duration %.1fs" % [
			ship.name, intensity, duration
		])

## Apply system disruption to ship
func _apply_system_disruption(ship: Node, disruption_type: String, intensity: float, duration: float) -> void:
	if not system_disruptions.has(ship):
		system_disruptions[ship] = {}
	
	var ship_disruptions = system_disruptions[ship]
	var disruption_level = _calculate_disruption_level(disruption_type, intensity)
	
	# Create or update disruption data
	ship_disruptions[disruption_type] = {
		"disruption_level": disruption_level,
		"end_time": (Time.get_ticks_msec() / 1000.0) + duration,
		"original_intensity": intensity
	}
	
	# Apply specific disruption effects
	match disruption_type:
		"targeting":
			_disrupt_targeting_system(ship, disruption_level)
		"engines":
			_disrupt_engine_system(ship, disruption_level)
		"weapons":
			_disrupt_weapon_system(ship, disruption_level)
		"hud":
			_disrupt_hud_system(ship, disruption_level)
		"ai":
			_disrupt_ai_system(ship, disruption_level)
	
	ship_system_disrupted.emit(ship, disruption_type, disruption_level)
	emp_performance_stats["system_disruptions_applied"] += 1

## Calculate EMP intensity based on distance
func _calculate_emp_intensity(distance: float, inner_radius: float, outer_radius: float, base_intensity: float) -> float:
	if distance <= inner_radius:
		return base_intensity  # Full intensity within inner radius
	
	if distance >= outer_radius:
		return 0.0  # No effect beyond outer radius
	
	# Linear falloff between inner and outer radius
	var falloff_distance = distance - inner_radius
	var falloff_range = outer_radius - inner_radius
	var falloff_factor = 1.0 - (falloff_distance / falloff_range)
	
	return base_intensity * falloff_factor

## Calculate disruption level for system type
func _calculate_disruption_level(disruption_type: String, intensity: float) -> float:
	# Different systems have different susceptibility to EMP
	var system_susceptibility = {
		"targeting": 1.0,    # Most susceptible
		"hud": 0.9,         # Very susceptible
		"weapons": 0.8,     # Moderately susceptible
		"ai": 0.7,          # Less susceptible
		"engines": 0.6      # Least susceptible (physical systems)
	}
	
	var susceptibility = system_susceptibility.get(disruption_type, 1.0)
	return intensity * susceptibility

## Disrupt targeting system
func _disrupt_targeting_system(ship: Node, disruption_level: float) -> void:
	if ship.has_method("apply_targeting_disruption"):
		ship.apply_targeting_disruption(disruption_level)
	elif ship.has_method("get_targeting_system"):
		var targeting_system = ship.get_targeting_system()
		if targeting_system and targeting_system.has_method("apply_emp_disruption"):
			targeting_system.apply_emp_disruption(disruption_level)

## Disrupt engine system
func _disrupt_engine_system(ship: Node, disruption_level: float) -> void:
	if ship.has_method("apply_engine_disruption"):
		ship.apply_engine_disruption(disruption_level)
	elif ship.has_method("get_subsystem_manager"):
		var subsystem_manager = ship.get_subsystem_manager()
		if subsystem_manager and subsystem_manager.has_method("apply_emp_disruption"):
			subsystem_manager.apply_emp_disruption("Engine", disruption_level)

## Disrupt weapon system
func _disrupt_weapon_system(ship: Node, disruption_level: float) -> void:
	if ship.has_method("apply_weapon_disruption"):
		ship.apply_weapon_disruption(disruption_level)
	elif ship.has_method("get_weapon_manager"):
		var weapon_manager = ship.get_weapon_manager()
		if weapon_manager and weapon_manager.has_method("apply_emp_disruption"):
			weapon_manager.apply_emp_disruption(disruption_level)

## Disrupt HUD system
func _disrupt_hud_system(ship: Node, disruption_level: float) -> void:
	if not enable_hud_disruption:
		return
	
	if ship.has_method("apply_hud_disruption"):
		ship.apply_hud_disruption(disruption_level)
	elif ship == ship_owner and hud_system:
		if hud_system.has_method("apply_emp_disruption"):
			hud_system.apply_emp_disruption(disruption_level)

## Disrupt AI system
func _disrupt_ai_system(ship: Node, disruption_level: float) -> void:
	if not enable_ai_disruption:
		return
	
	if ship.has_method("apply_ai_disruption"):
		ship.apply_ai_disruption(disruption_level)
	elif ship.has_method("get_ai_controller"):
		var ai_controller = ship.get_ai_controller()
		if ai_controller and ai_controller.has_method("apply_emp_disruption"):
			ai_controller.apply_emp_disruption(disruption_level)

## Find ships in range of EMP effect
func _find_ships_in_range(center: Vector3, radius: float) -> Array:
	var ships_in_range: Array = []
	
	# Use physics server for efficient range query
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Create sphere shape for query
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = radius
	query.shape = sphere_shape
	query.transform.origin = center
	query.collision_mask = 0b1  # Ship collision layer
	
	# Perform query
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var collider = result["collider"]
		
		# Check if it's a ship
		if collider.has_method("get_ship_controller") or collider.has_method("is_ship"):
			var ship = collider
			if collider.has_method("get_ship_controller"):
				ship = collider.get_ship_controller()
			
			if ship and not ships_in_range.has(ship):
				ships_in_range.append(ship)
	
	return ships_in_range

## Check if effect would be friendly fire
func _is_friendly_fire(firing_team: int, target_ship: Node) -> bool:
	var target_team = _get_ship_team(target_ship)
	
	# No friendly fire on same team
	if firing_team == target_team and firing_team != TeamTypes.Type.UNKNOWN:
		return true
	
	# Additional friendly fire checks
	if firing_team == TeamTypes.Type.FRIENDLY and target_team == TeamTypes.Type.FRIENDLY:
		return true
	
	return false

## Get ship size for resistance calculation
func _get_ship_size(ship: Node) -> int:
	if ship.has_method("get_ship_size"):
		return ship.get_ship_size()
	elif ship.has_method("get_ship_class"):
		var ship_class = ship.get_ship_class()
		if ship_class and ship_class.has_method("get", "ship_size"):
			return ship_class.ship_size
	
	# Default to fighter size
	return ShipSizes.Size.FIGHTER

## Get ship team
func _get_ship_team(ship: Node) -> int:
	if ship.has_method("get_team"):
		return ship.get_team()
	elif ship.has_property("team"):
		return ship.team
	elif ship.has_property("ship_team"):
		return ship.ship_team
	
	return TeamTypes.Type.UNKNOWN

## Create EMP effect data structure
func _create_emp_effect_data(emp_id: String, weapon_type: int, target_location: Vector3, firing_ship: Node, intensity_modifier: float) -> Dictionary:
	var config = emp_weapon_configs[weapon_type]
	
	return {
		"emp_id": emp_id,
		"weapon_type": weapon_type,
		"target_location": target_location,
		"firing_ship": firing_ship,
		"firing_team": _get_ship_team(firing_ship),
		"base_intensity": config["base_intensity"] * intensity_modifier,
		"effect_duration": config["effect_duration"],
		"inner_radius": config["inner_radius"],
		"outer_radius": config["outer_radius"],
		"energy_cost": config["energy_cost"],
		"disruption_types": config["disruption_types"].duplicate(),
		"creation_time": Time.get_ticks_msec() / 1000.0,
		"ships_affected": []
	}

## Create EMP visual effects
func _create_emp_visual_effects(emp_data: Dictionary) -> void:
	if not visual_effects_manager:
		return
	
	var effect_data = {
		"effect_type": "emp_detonation",
		"location": emp_data["target_location"],
		"intensity": emp_data["base_intensity"],
		"inner_radius": emp_data["inner_radius"],
		"outer_radius": emp_data["outer_radius"],
		"duration": emp_data["effect_duration"]
	}
	
	if visual_effects_manager.has_method("create_emp_effect"):
		visual_effects_manager.create_emp_effect(effect_data)

## Apply visual effects to affected ship
func _apply_ship_emp_visual_effects(ship: Node, intensity: float, duration: float) -> void:
	if not visual_effects_manager:
		return
	
	var effect_data = {
		"effect_type": "ship_emp_disruption",
		"target_ship": ship,
		"intensity": intensity,
		"duration": duration
	}
	
	if visual_effects_manager.has_method("create_ship_emp_effect"):
		visual_effects_manager.create_ship_emp_effect(effect_data)

## Process EMP effect updates
func _process_emp_effects() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Update active EMP effects
	var emp_ids_to_remove: Array[String] = []
	for emp_id in active_emp_effects.keys():
		var emp_data = active_emp_effects[emp_id]
		var creation_time = emp_data["creation_time"]
		var duration = emp_data["effect_duration"]
		
		if current_time >= (creation_time + duration):
			emp_ids_to_remove.append(emp_id)
	
	# Remove expired EMP effects
	for emp_id in emp_ids_to_remove:
		_remove_emp_effect(emp_id)
	
	# Update ship effects
	_update_ship_effects(current_time)
	
	# Update system disruptions
	_update_system_disruptions(current_time)

## Remove expired EMP effect
func _remove_emp_effect(emp_id: String) -> void:
	if not active_emp_effects.has(emp_id):
		return
	
	active_emp_effects.erase(emp_id)
	emp_performance_stats["active_emp_count"] = active_emp_effects.size()
	
	if enable_emp_debugging:
		print("EMPWeaponSystem: Removed expired EMP effect %s" % emp_id)

## Update ship effects
func _update_ship_effects(current_time: float) -> void:
	var ships_to_remove: Array = []
	
	for ship in affected_ships.keys():
		var ship_effects = affected_ships[ship]
		var effects_to_remove: Array = []
		
		# Check each effect on this ship
		for i in range(ship_effects.size()):
			var effect_data = ship_effects[i]
			
			if current_time >= effect_data["end_time"]:
				effects_to_remove.append(i)
				emp_effect_expired.emit(ship, effect_data["emp_id"])
		
		# Remove expired effects (in reverse order to maintain indices)
		effects_to_remove.reverse()
		for index in effects_to_remove:
			ship_effects.remove_at(index)
		
		# If no effects remain, remove ship from tracking
		if ship_effects.is_empty():
			ships_to_remove.append(ship)
	
	# Remove ships with no active effects
	for ship in ships_to_remove:
		affected_ships.erase(ship)

## Update system disruptions
func _update_system_disruptions(current_time: float) -> void:
	var ships_to_clean: Array = []
	
	for ship in system_disruptions.keys():
		var ship_disruptions = system_disruptions[ship]
		var systems_to_remove: Array[String] = []
		
		# Check each system disruption
		for system_type in ship_disruptions.keys():
			var disruption_data = ship_disruptions[system_type]
			
			if current_time >= disruption_data["end_time"]:
				systems_to_remove.append(system_type)
				_remove_system_disruption(ship, system_type)
		
		# Remove expired disruptions
		for system_type in systems_to_remove:
			ship_disruptions.erase(system_type)
		
		# If no disruptions remain, mark for cleanup
		if ship_disruptions.is_empty():
			ships_to_clean.append(ship)
	
	# Clean up ships with no disruptions
	for ship in ships_to_clean:
		system_disruptions.erase(ship)

## Remove system disruption
func _remove_system_disruption(ship: Node, system_type: String) -> void:
	# Restore system to normal operation
	match system_type:
		"targeting":
			if ship.has_method("remove_targeting_disruption"):
				ship.remove_targeting_disruption()
		"engines":
			if ship.has_method("remove_engine_disruption"):
				ship.remove_engine_disruption()
		"weapons":
			if ship.has_method("remove_weapon_disruption"):
				ship.remove_weapon_disruption()
		"hud":
			if ship.has_method("remove_hud_disruption"):
				ship.remove_hud_disruption()
		"ai":
			if ship.has_method("remove_ai_disruption"):
				ship.remove_ai_disruption()

## Get EMP system status
func get_emp_system_status() -> Dictionary:
	return {
		"active_emp_effects": active_emp_effects.size(),
		"affected_ships": affected_ships.size(),
		"total_disruptions": _count_total_disruptions(),
		"performance_stats": emp_performance_stats.duplicate()
	}

## Get performance statistics
func get_emp_performance_statistics() -> Dictionary:
	return emp_performance_stats.duplicate()

## Count total active disruptions
func _count_total_disruptions() -> int:
	var total = 0
	for ship in system_disruptions.keys():
		total += system_disruptions[ship].size()
	return total

## Setup EMP weapon system
func _setup_emp_weapon_system() -> void:
	active_emp_effects.clear()
	affected_ships.clear()
	system_disruptions.clear()
	
	effect_update_timer = 0.0
	
	# Reset performance stats
	emp_performance_stats = {
		"total_emp_fired": 0,
		"total_ships_affected": 0,
		"active_emp_count": 0,
		"system_disruptions_applied": 0
	}

## Check if ship is currently affected by EMP
func is_ship_affected_by_emp(ship: Node) -> bool:
	return affected_ships.has(ship) and not affected_ships[ship].is_empty()

## Get EMP intensity affecting ship
func get_ship_emp_intensity(ship: Node) -> float:
	if not affected_ships.has(ship):
		return 0.0
	
	var max_intensity = 0.0
	for effect_data in affected_ships[ship]:
		max_intensity = max(max_intensity, effect_data["intensity"])
	
	return max_intensity

## Get system disruption level
func get_system_disruption_level(ship: Node, system_type: String) -> float:
	if not system_disruptions.has(ship):
		return 0.0
	
	var ship_disruptions = system_disruptions[ship]
	if not ship_disruptions.has(system_type):
		return 0.0
	
	return ship_disruptions[system_type]["disruption_level"]

## Process frame updates
func _process(delta: float) -> void:
	effect_update_timer += delta
	
	# Update EMP effects at regular intervals
	if effect_update_timer >= effect_update_interval:
		effect_update_timer = 0.0
		_process_emp_effects()