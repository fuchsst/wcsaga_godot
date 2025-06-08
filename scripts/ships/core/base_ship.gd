class_name BaseShip
extends BaseSpaceObject

## Enhanced ship controller providing authentic WCS ship behavior and combat mechanics
## Implements core ship properties, ETS power management, and subsystem coordination
## Foundation for all ship types in the WCS-Godot conversion (SHIP-001)

# EPIC-002 Asset Core Integration
const ShipTypes = preload("res://addons/wcs_asset_core/constants/ship_types.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const ShipClass = preload("res://addons/wcs_asset_core/resources/ship/ship_class.gd")
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Ship-specific signals (SHIP-001 AC7)
signal ship_destroyed(ship: BaseShip)
signal subsystem_damaged(subsystem_name: String, damage_percent: float)
signal shields_depleted()
signal shields_restored()
signal afterburner_activated()
signal afterburner_deactivated()
signal energy_transfer_changed(shields: float, weapons: float, engines: float)
signal ship_disabled()
signal ship_enabled()

# Core ship properties (SHIP-001 AC1)
@export var ship_class: ShipClass
@export var ship_name: String = ""
@export var team: int = 0  # FRIENDLY, HOSTILE, NEUTRAL, UNKNOWN
@export var max_hull_strength: float = 100.0
@export var current_hull_strength: float = 100.0
@export var max_shield_strength: float = 100.0
@export var current_shield_strength: float = 100.0

# Physics properties (SHIP-001 AC5)
@export var max_velocity: float = 50.0
@export var max_afterburner_velocity: float = 100.0
@export var acceleration: float = 25.0
@export var angular_acceleration: float = 180.0  # degrees per second squared
@export var mass: float = 1000.0
@export var moment_of_inertia: float = 2000.0

# Energy Transfer System (ETS) (SHIP-001 AC6)
@export var max_weapon_energy: float = 100.0
@export var current_weapon_energy: float = 100.0
@export var afterburner_fuel_capacity: float = 100.0
@export var current_afterburner_fuel: float = 100.0

# ETS allocation percentages (0.0 to 1.0)
var shield_recharge_rate: float = 0.333  # Default 1/3 allocation
var weapon_recharge_rate: float = 0.333  # Default 1/3 allocation  
var engine_power_rate: float = 0.333     # Default 1/3 allocation

# WCS Energy levels from hudets.cpp
const ENERGY_LEVELS: Array[float] = [
	0.0, 0.0833, 0.167, 0.25, 0.333, 0.417, 0.5,
	0.583, 0.667, 0.75, 0.833, 0.9167, 1.0
]

# ETS indices (matching WCS system)
var shield_recharge_index: int = 4  # Default to index 4 (0.333)
var weapon_recharge_index: int = 4  # Default to index 4 (0.333)
var engine_recharge_index: int = 4   # Default to index 4 (0.333)

# Ship state flags (SHIP-001 AC4)
var ship_flags: int = 0
var ship_flags2: int = 0
var is_dying: bool = false
var is_disabled: bool = false
var is_engines_on: bool = true
var is_afterburner_active: bool = false
var is_primary_linked: bool = false
var is_secondary_dual_fire: bool = false

# Subsystem references (SHIP-001 AC7)
var subsystems: Dictionary = {}
var subsystem_list: Array[Node] = []

# Performance tracking
var performance_modifier: float = 1.0  # Overall ship performance (affected by damage)
var engine_performance: float = 1.0    # Engine subsystem performance
var weapon_performance: float = 1.0    # Weapon subsystem performance
var shield_performance: float = 1.0    # Shield subsystem performance

# Frame processing
var last_frame_time: float = 0.0
var frame_delta: float = 0.0

func _init() -> void:
	super._init()
	# Initialize as ship type
	object_type_enum = ObjectTypes.Type.SHIP
	object_type = ObjectTypes.get_type_name(object_type_enum)

func _ready() -> void:
	super._ready()
	_initialize_ship_physics()
	_setup_ship_signals()
	_initialize_ets_system()
	_register_with_ship_manager()

## Initialize ship with configuration from ship class definition (SHIP-001 AC2)
func initialize_ship(ship_class_resource: ShipClass, ship_name_param: String = "") -> bool:
	"""Initialize ship from ship class definition with WCS-authentic properties.
	
	Args:
		ship_class_resource: Ship class configuration resource
		ship_name_param: Optional custom ship name
		
	Returns:
		true if initialization successful, false otherwise
	"""
	if not ship_class_resource:
		push_error("BaseShip: Cannot initialize without ship class")
		return false
	
	ship_class = ship_class_resource
	ship_name = ship_name_param if ship_name_param != "" else ship_class.class_name
	
	# Apply ship class properties (SHIP-001 AC1, AC2)
	max_hull_strength = ship_class.max_hull_strength
	current_hull_strength = max_hull_strength
	max_shield_strength = ship_class.max_shield_strength
	current_shield_strength = max_shield_strength
	
	# Apply physics properties (SHIP-001 AC5)
	max_velocity = ship_class.max_velocity
	max_afterburner_velocity = ship_class.max_afterburner_velocity
	acceleration = ship_class.acceleration
	angular_acceleration = ship_class.angular_acceleration
	mass = ship_class.mass
	moment_of_inertia = ship_class.moment_of_inertia
	
	# Apply energy properties (SHIP-001 AC6)
	max_weapon_energy = ship_class.max_weapon_energy
	current_weapon_energy = max_weapon_energy
	afterburner_fuel_capacity = ship_class.afterburner_fuel_capacity
	current_afterburner_fuel = afterburner_fuel_capacity
	
	# Configure physics body with ship properties
	_apply_ship_physics_configuration()
	
	# Initialize subsystems (SHIP-001 AC7)
	_initialize_ship_subsystems()
	
	return true

## Apply ship physics configuration to RigidBody3D (SHIP-001 AC5)
func _apply_ship_physics_configuration() -> void:
	"""Configure physics body with authentic WCS ship movement characteristics."""
	if not physics_body:
		return
	
	# Set mass and inertia
	physics_body.mass = mass
	# Note: Godot doesn't expose moment of inertia directly, but we can adjust via damping
	
	# Configure space physics (no gravity, custom damping)
	physics_body.gravity_scale = 0.0
	physics_body.linear_damp = 0.05  # Low damping for space flight
	physics_body.angular_damp = 0.1  # Slightly higher angular damping
	
	# Set collision configuration for ships
	collision_layer_bits = 1 << CollisionLayers.Layer.SHIPS  # Create layer bit for ships
	collision_mask_bits = (1 << CollisionLayers.Layer.SHIPS) | (1 << CollisionLayers.Layer.WEAPONS) | (1 << CollisionLayers.Layer.DEBRIS)  # Basic ship collision mask
	physics_body.collision_layer = collision_layer_bits
	physics_body.collision_mask = collision_mask_bits

## Initialize ship physics behavior (SHIP-001 AC5)
func _initialize_ship_physics() -> void:
	"""Setup ship-specific physics behavior and constraints."""
	if physics_body:
		# Connect to physics process for frame updates
		set_physics_process(true)
		
		# Set initial velocity limits
		_apply_velocity_constraints()

## Setup ship-specific signal connections (SHIP-001 AC7)
func _setup_ship_signals() -> void:
	"""Connect ship signals for subsystem communication and state management."""
	# Connect to base space object signals
	collision_detected.connect(_on_ship_collision_detected)
	object_destroyed.connect(_on_ship_object_destroyed)
	
	# Connect to ship-specific systems
	shields_depleted.connect(_on_shields_depleted)
	shields_restored.connect(_on_shields_restored)

## Initialize Energy Transfer System (SHIP-001 AC6)
func _initialize_ets_system() -> void:
	"""Initialize ETS with WCS-authentic energy management."""
	# Set default ETS allocation (equal distribution)
	set_ets_allocation(0.333, 0.333, 0.333)
	
	# Initialize energy reserves
	current_weapon_energy = max_weapon_energy
	current_afterburner_fuel = afterburner_fuel_capacity

## Initialize ship subsystems (SHIP-001 AC7)
func _initialize_ship_subsystems() -> void:
	"""Create and configure ship subsystems from ship class definition."""
	if not ship_class:
		return
	
	# This will be expanded in SHIP-002: Subsystem Management
	# For now, create placeholder subsystem tracking
	subsystems.clear()
	subsystem_list.clear()
	
	# Initialize performance tracking
	engine_performance = 1.0
	weapon_performance = 1.0
	shield_performance = 1.0
	_update_performance_modifier()

## Register with ship management systems
func _register_with_ship_manager() -> void:
	"""Register ship with global ship management systems."""
	# TODO: Register with ShipManager when implemented
	pass

## Physics process for frame-by-frame ship updates (SHIP-001 AC4)
func _physics_process(delta: float) -> void:
	"""Main ship processing loop with pre/post processing phases."""
	frame_delta = delta
	last_frame_time = Time.get_ticks_msec() * 0.001
	
	# Pre-processing phase
	_pre_process_ship_frame(delta)
	
	# Core ship processing
	_process_ship_frame(delta)
	
	# Post-processing phase
	_post_process_ship_frame(delta)

## Pre-processing phase for ship frame updates
func _pre_process_ship_frame(delta: float) -> void:
	"""Pre-processing phase: input validation, state checks."""
	# Update subsystem states (SHIP-001 AC7)
	_update_subsystem_states(delta)
	
	# Apply velocity constraints
	_apply_velocity_constraints()

## Core ship processing frame
func _process_ship_frame(delta: float) -> void:
	"""Core processing: ETS, energy management, physics."""
	# Process Energy Transfer System (SHIP-001 AC6)
	_process_ets_system(delta)
	
	# Update ship performance based on subsystem health (SHIP-001 AC7)
	_update_performance_effects()
	
	# Process afterburner system
	_process_afterburner_system(delta)

## Post-processing phase for ship frame updates
func _post_process_ship_frame(delta: float) -> void:
	"""Post-processing phase: cleanup, signal emission."""
	# Check for state changes and emit signals as needed
	_check_state_changes()

## Process Energy Transfer System each frame (SHIP-001 AC6)
func _process_ets_system(delta: float) -> void:
	"""Process ETS energy regeneration and power allocation."""
	# Shield regeneration
	if current_shield_strength < max_shield_strength and shield_performance > 0.0:
		var shield_regen_rate: float = shield_recharge_rate * shield_performance * delta * 20.0  # Base regen rate
		current_shield_strength = min(current_shield_strength + shield_regen_rate, max_shield_strength)
	
	# Weapon energy regeneration
	if current_weapon_energy < max_weapon_energy and weapon_performance > 0.0:
		var weapon_regen_rate: float = weapon_recharge_rate * weapon_performance * delta * 30.0  # Base regen rate
		current_weapon_energy = min(current_weapon_energy + weapon_regen_rate, max_weapon_energy)
	
	# Afterburner fuel regeneration (slower)
	if current_afterburner_fuel < afterburner_fuel_capacity and engine_performance > 0.0:
		var fuel_regen_rate: float = engine_power_rate * engine_performance * delta * 5.0  # Base regen rate
		current_afterburner_fuel = min(current_afterburner_fuel + fuel_regen_rate, afterburner_fuel_capacity)

## Update subsystem states and performance (SHIP-001 AC7)
func _update_subsystem_states(delta: float) -> void:
	"""Update subsystem health and performance effects."""
	# This will be expanded in SHIP-002
	# For now, maintain baseline performance
	if engine_performance <= 0.0:
		is_disabled = true
	else:
		is_disabled = false

## Update ship performance modifier based on subsystem health (SHIP-001 AC7)
func _update_performance_effects() -> void:
	"""Apply subsystem damage effects to ship performance."""
	# Calculate overall performance modifier
	_update_performance_modifier()
	
	# Apply engine performance to current max speed
	current_max_speed = max_velocity * engine_performance * engine_power_rate

## Update overall performance modifier
func _update_performance_modifier() -> void:
	"""Calculate overall ship performance based on subsystem health."""
	# Weighted average of subsystem performance
	performance_modifier = (engine_performance * 0.4 + weapon_performance * 0.3 + shield_performance * 0.3)
	performance_modifier = max(0.1, performance_modifier)  # Never go below 10% performance

## Process afterburner system (SHIP-001 AC5)
func _process_afterburner_system(delta: float) -> void:
	"""Handle afterburner fuel consumption and effects."""
	if is_afterburner_active:
		if current_afterburner_fuel > 0.0 and engine_performance > 0.5:
			# Consume afterburner fuel
			var fuel_consumption: float = delta * 25.0  # Base consumption rate
			current_afterburner_fuel = max(0.0, current_afterburner_fuel - fuel_consumption)
			
			# Deactivate if fuel depleted
			if current_afterburner_fuel <= 0.0:
				set_afterburner_active(false)
		else:
			# Deactivate if damaged or no fuel
			set_afterburner_active(false)

## Apply velocity constraints based on ship configuration (SHIP-001 AC5)
func _apply_velocity_constraints() -> void:
	"""Apply WCS-style velocity limiting and afterburner effects."""
	if not physics_body:
		return
	
	var current_velocity: Vector3 = physics_body.linear_velocity
	var max_speed: float = current_max_speed
	
	# Apply afterburner velocity boost
	if is_afterburner_active and current_afterburner_fuel > 0.0:
		max_speed = max_afterburner_velocity * engine_performance
	
	# Limit velocity to maximum speed
	if current_velocity.length() > max_speed:
		physics_body.linear_velocity = current_velocity.normalized() * max_speed

## Check for state changes and emit appropriate signals
func _check_state_changes() -> void:
	"""Check for ship state changes and emit signals."""
	# Check hull damage
	if current_hull_strength <= 0.0 and not is_dying:
		is_dying = true
		ship_destroyed.emit(self)
	
	# Check shield states
	if current_shield_strength <= 0.0 and not _shields_were_depleted:
		_shields_were_depleted = true
		shields_depleted.emit()
	elif current_shield_strength > 0.0 and _shields_were_depleted:
		_shields_were_depleted = false
		shields_restored.emit()

var _shields_were_depleted: bool = false

# ============================================================================
# PUBLIC API METHODS (SHIP-001 AC6, AC7)
# ============================================================================

## Set Energy Transfer System allocation (SHIP-001 AC6)
func set_ets_allocation(shields: float, weapons: float, engines: float) -> bool:
	"""Set ETS power allocation with WCS-authentic constraints.
	
	Args:
		shields: Shield power allocation (0.0 to 1.0)
		weapons: Weapon power allocation (0.0 to 1.0) 
		engines: Engine power allocation (0.0 to 1.0)
		
	Returns:
		true if allocation was applied successfully
	"""
	# Validate inputs
	if shields < 0.0 or shields > 1.0 or weapons < 0.0 or weapons > 1.0 or engines < 0.0 or engines > 1.0:
		return false
	
	# Total must equal 1.0 (100% allocation)
	var total: float = shields + weapons + engines
	if abs(total - 1.0) > 0.01:
		return false
	
	# Apply allocation
	shield_recharge_rate = shields
	weapon_recharge_rate = weapons
	engine_power_rate = engines
	
	# Update ETS indices for WCS compatibility
	shield_recharge_index = _get_energy_level_index(shields)
	weapon_recharge_index = _get_energy_level_index(weapons)
	engine_recharge_index = _get_energy_level_index(engines)
	
	# Update current max speed based on new engine allocation
	current_max_speed = max_velocity * engine_performance * engine_power_rate
	
	# Emit signal
	energy_transfer_changed.emit(shields, weapons, engines)
	
	return true

## Transfer energy using WCS-style ETS controls (SHIP-001 AC6)
func transfer_energy_to_shields() -> bool:
	"""Transfer energy from weapons to shields (WCS F5 key)."""
	if weapon_recharge_index > 0 and shield_recharge_index < ENERGY_LEVELS.size() - 1:
		weapon_recharge_index -= 1
		shield_recharge_index += 1
		_update_ets_from_indices()
		return true
	return false

func transfer_energy_to_weapons() -> bool:
	"""Transfer energy from shields to weapons (WCS F6 key)."""
	if shield_recharge_index > 0 and weapon_recharge_index < ENERGY_LEVELS.size() - 1:
		shield_recharge_index -= 1
		weapon_recharge_index += 1
		_update_ets_from_indices()
		return true
	return false

func transfer_energy_to_engines() -> bool:
	"""Transfer energy from weapons to engines (WCS F7 key)."""
	if weapon_recharge_index > 0 and engine_recharge_index < ENERGY_LEVELS.size() - 1:
		weapon_recharge_index -= 1
		engine_recharge_index += 1
		_update_ets_from_indices()
		return true
	return false

func balance_energy_systems() -> void:
	"""Reset ETS to balanced allocation (WCS F8 key)."""
	set_ets_allocation(0.333, 0.333, 0.333)

## Update ETS rates from WCS energy level indices
func _update_ets_from_indices() -> void:
	"""Update ETS allocation rates from current indices."""
	shield_recharge_rate = ENERGY_LEVELS[shield_recharge_index]
	weapon_recharge_rate = ENERGY_LEVELS[weapon_recharge_index]
	engine_power_rate = ENERGY_LEVELS[engine_recharge_index]
	
	# Update current max speed
	current_max_speed = max_velocity * engine_performance * engine_power_rate
	
	# Emit signal
	energy_transfer_changed.emit(shield_recharge_rate, weapon_recharge_rate, engine_power_rate)

## Get energy level index for allocation value
func _get_energy_level_index(allocation: float) -> int:
	"""Find closest energy level index for allocation value."""
	var closest_index: int = 0
	var closest_distance: float = abs(ENERGY_LEVELS[0] - allocation)
	
	for i in range(1, ENERGY_LEVELS.size()):
		var distance: float = abs(ENERGY_LEVELS[i] - allocation)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i
	
	return closest_index

## Set afterburner active state (SHIP-001 AC5)
func set_afterburner_active(active: bool) -> bool:
	"""Activate or deactivate afterburner system.
	
	Args:
		active: true to activate, false to deactivate
		
	Returns:
		true if state change was successful
	"""
	if active == is_afterburner_active:
		return true
	
	if active:
		# Check if we can activate afterburner
		if current_afterburner_fuel > 0.0 and engine_performance > 0.5 and not is_disabled:
			is_afterburner_active = true
			afterburner_activated.emit()
			return true
		else:
			return false
	else:
		# Deactivate afterburner
		is_afterburner_active = false
		afterburner_deactivated.emit()
		return true

## Apply damage to ship hull (SHIP-001 AC4)
func apply_hull_damage(damage: float) -> float:
	"""Apply damage to ship hull and return actual damage applied.
	
	Args:
		damage: Amount of damage to apply
		
	Returns:
		Actual damage applied after resistances
	"""
	var actual_damage: float = max(0.0, damage)
	current_hull_strength -= actual_damage
	current_hull_strength = max(0.0, current_hull_strength)
	
	# Check for ship destruction
	if current_hull_strength <= 0.0:
		_trigger_ship_destruction()
	
	return actual_damage

## Apply damage to ship shields (SHIP-001 AC4)
func apply_shield_damage(damage: float) -> float:
	"""Apply damage to ship shields and return actual damage applied.
	
	Args:
		damage: Amount of damage to apply
		
	Returns:
		Actual damage applied to shields
	"""
	if current_shield_strength <= 0.0:
		return 0.0
	
	var actual_damage: float = min(damage, current_shield_strength)
	current_shield_strength -= actual_damage
	current_shield_strength = max(0.0, current_shield_strength)
	
	return actual_damage

## Trigger ship destruction sequence (SHIP-001 AC3)
func _trigger_ship_destruction() -> void:
	"""Initiate ship destruction sequence."""
	if not is_dying:
		is_dying = true
		ship_destroyed.emit(self)
		
		# Start destruction sequence
		_begin_death_sequence()

## Begin death sequence (SHIP-001 AC3)
func _begin_death_sequence() -> void:
	"""Begin ship death and destruction sequence."""
	# This will be expanded with visual effects in later stories
	# For now, just disable the ship
	is_disabled = true
	
	# Deactivate physics
	if physics_body:
		physics_body.freeze = true

# ============================================================================
# SHIP CONTROL INTERFACES (SHIP-001 AC5, AC7)
# ============================================================================

## Apply thruster input for ship movement (SHIP-001 AC5)
func apply_ship_thrust(forward: float, side: float, vertical: float, afterburner: bool = false) -> bool:
	"""Apply thruster input with WCS-style ship physics.
	
	Args:
		forward: Forward thrust (0-1)
		side: Side thrust (-1 to 1) 
		vertical: Vertical thrust (-1 to 1)
		afterburner: Whether afterburner is active
		
	Returns:
		true if thrust was applied successfully
	"""
	if is_disabled or not physics_body:
		return false
	
	# Set afterburner state
	if afterburner != is_afterburner_active:
		set_afterburner_active(afterburner)
	
	# Calculate thrust force with performance modification
	var base_thrust: float = acceleration * mass * performance_modifier * engine_performance
	var thrust_vector: Vector3 = Vector3(-side, vertical, -forward) * base_thrust
	
	# Apply afterburner boost
	if is_afterburner_active:
		thrust_vector *= 1.5  # 50% thrust increase
	
	# Apply thrust through physics system
	return set_thruster_input(forward, side, vertical, is_afterburner_active)

## Get current ship status information (SHIP-001 AC4)
func get_ship_status() -> Dictionary:
	"""Get comprehensive ship status information.
	
	Returns:
		Dictionary containing all ship status data
	"""
	return {
		"ship_name": ship_name,
		"ship_class": ship_class.class_name if ship_class else "Unknown",
		"team": team,
		"hull_strength": current_hull_strength,
		"max_hull_strength": max_hull_strength,
		"hull_percent": (current_hull_strength / max_hull_strength) * 100.0,
		"shield_strength": current_shield_strength,
		"max_shield_strength": max_shield_strength,
		"shield_percent": (current_shield_strength / max_shield_strength) * 100.0,
		"weapon_energy": current_weapon_energy,
		"max_weapon_energy": max_weapon_energy,
		"weapon_energy_percent": (current_weapon_energy / max_weapon_energy) * 100.0,
		"afterburner_fuel": current_afterburner_fuel,
		"afterburner_fuel_capacity": afterburner_fuel_capacity,
		"afterburner_fuel_percent": (current_afterburner_fuel / afterburner_fuel_capacity) * 100.0,
		"ets_shields": shield_recharge_rate,
		"ets_weapons": weapon_recharge_rate,
		"ets_engines": engine_power_rate,
		"performance_modifier": performance_modifier,
		"engine_performance": engine_performance,
		"weapon_performance": weapon_performance,
		"shield_performance": shield_performance,
		"is_afterburner_active": is_afterburner_active,
		"is_disabled": is_disabled,
		"is_dying": is_dying,
		"current_max_speed": current_max_speed,
		"velocity": physics_body.linear_velocity if physics_body else Vector3.ZERO
	}

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Handle ship collision events
func _on_ship_collision_detected(other_object: BaseSpaceObject, collision_info: Dictionary) -> void:
	"""Handle collisions with other space objects."""
	# This will be expanded in damage system stories
	pass

## Handle ship destruction
func _on_ship_object_destroyed() -> void:
	"""Handle ship object destruction."""
	_trigger_ship_destruction()

## Handle shield depletion
func _on_shields_depleted() -> void:
	"""Handle shield depletion effects."""
	# Visual/audio effects will be added in later stories
	pass

## Handle shield restoration
func _on_shields_restored() -> void:
	"""Handle shield restoration effects.""" 
	# Visual/audio effects will be added in later stories
	pass

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Enhanced debug information for ships
func debug_info() -> String:
	var base_info: String = super.debug_info()
	var ship_info: String = "[Ship:%s Hull:%.0f/%.0f Shield:%.0f/%.0f ETS:(%.2f,%.2f,%.2f)]" % [
		ship_name, current_hull_strength, max_hull_strength,
		current_shield_strength, max_shield_strength,
		shield_recharge_rate, weapon_recharge_rate, engine_power_rate
	]
	return base_info + " " + ship_info

## Get ship performance information
func get_performance_info() -> Dictionary:
	"""Get detailed ship performance information for debugging."""
	return {
		"overall_performance": performance_modifier,
		"engine_performance": engine_performance,
		"weapon_performance": weapon_performance,
		"shield_performance": shield_performance,
		"current_max_speed": current_max_speed,
		"afterburner_active": is_afterburner_active,
		"disabled": is_disabled,
		"dying": is_dying
	}