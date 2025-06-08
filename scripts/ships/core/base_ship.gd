class_name BaseShip
extends BaseSpaceObject

## Enhanced ship controller providing authentic WCS ship behavior and combat mechanics
## Implements core ship properties, ETS power management, and subsystem coordination
## Foundation for all ship types in the WCS-Godot conversion (SHIP-001)

# EPIC-002 Asset Core Integration
const ShipTypes = preload("res://addons/wcs_asset_core/constants/ship_types.gd")
const ShipClass = preload("res://addons/wcs_asset_core/resources/ship/ship_class.gd")
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")
const SubsystemManager = preload("res://scripts/ships/subsystems/subsystem_manager.gd")

# SHIP-004 Lifecycle and State Management
const ShipLifecycleController = preload("res://scripts/ships/core/ship_lifecycle_controller.gd")
const ShipStateManager = preload("res://scripts/ships/core/ship_state_manager.gd")
const ShipTeamManager = preload("res://scripts/ships/core/ship_team_manager.gd")

# SHIP-005 Weapon Management and Firing System
const WeaponManager = preload("res://scripts/ships/weapons/weapon_manager.gd")
const WeaponBankType = preload("res://addons/wcs_asset_core/constants/weapon_bank_types.gd")
const WeaponBase = preload("res://scripts/object/weapon_base.gd")

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

# SHIP-005 Weapon system signals
signal weapon_fired(bank_type: WeaponBankType.Type, weapon_name: String, projectiles: Array[WeaponBase])
signal weapon_target_acquired(target: Node3D, target_subsystem: Node)
signal weapon_target_lost()
signal ammunition_depleted(bank_type: WeaponBankType.Type, bank_index: int)

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

# Current maximum velocity affected by performance and ETS
var current_max_speed: float = 50.0

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

# Subsystem management (SHIP-002 - integrated)
var subsystem_manager: SubsystemManager

# Lifecycle and state management (SHIP-004 - integrated)
var lifecycle_controller: ShipLifecycleController
var state_manager: ShipStateManager

# Weapon management system (SHIP-005 - integrated)
var weapon_manager: WeaponManager

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
	current_max_speed = max_velocity  # Initialize current max speed
	_initialize_ship_physics()
	_setup_ship_signals()
	_initialize_ets_system()
	_initialize_subsystem_manager()
	_initialize_lifecycle_management()
	_initialize_weapon_manager()
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
	
	# Initialize subsystems (SHIP-002 - integrated)
	if subsystem_manager:
		subsystem_manager.create_subsystems_from_ship_class(ship_class)
	
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

## Initialize subsystem manager (SHIP-002)
func _initialize_subsystem_manager() -> void:
	"""Create and initialize the subsystem manager."""
	subsystem_manager = SubsystemManager.new()
	add_child(subsystem_manager)
	
	if not subsystem_manager.initialize_manager(self):
		push_error("BaseShip: Failed to initialize subsystem manager")
		return
	
	# Connect subsystem manager signals
	subsystem_manager.subsystem_performance_changed.connect(_on_subsystem_performance_changed)
	subsystem_manager.critical_subsystem_destroyed.connect(_on_critical_subsystem_destroyed)

## Initialize lifecycle management system (SHIP-004)
func _initialize_lifecycle_management() -> void:
	"""Create and initialize the lifecycle management system."""
	# Create lifecycle controller
	lifecycle_controller = ShipLifecycleController.new()
	add_child(lifecycle_controller)
	
	if not lifecycle_controller.initialize_controller(self):
		push_error("BaseShip: Failed to initialize lifecycle controller")
		return
	
	# Get state manager reference (created by lifecycle controller)
	state_manager = lifecycle_controller.state_manager
	
	# Connect lifecycle signals
	lifecycle_controller.ship_activated.connect(_on_ship_activated)
	lifecycle_controller.ship_destroyed.connect(_on_ship_lifecycle_destroyed)

## Initialize weapon management system (SHIP-005)
func _initialize_weapon_manager() -> void:
	"""Create and initialize the weapon management system."""
	weapon_manager = WeaponManager.new()
	add_child(weapon_manager)
	
	# Initialize after ship class is set
	if ship_class:
		weapon_manager.initialize_weapon_manager(self)
		
		# Connect weapon manager signals
		weapon_manager.weapon_fired.connect(_on_weapon_fired)
		weapon_manager.target_acquired.connect(_on_weapon_target_acquired)
		weapon_manager.target_lost.connect(_on_weapon_target_lost)
		weapon_manager.ammunition_depleted.connect(_on_ammunition_depleted)

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
	# Forward collision to subsystem manager for damage allocation (SHIP-002 AC4)
	if subsystem_manager and collision_info.has("impact_position"):
		var impact_pos: Vector3 = collision_info.get("impact_position", global_position)
		# Calculate damage based on collision (placeholder for now)
		var collision_damage: float = 25.0  # Base collision damage
		subsystem_manager.allocate_damage_to_subsystems(collision_damage, impact_pos)

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

## Handle subsystem performance changes (SHIP-002)
func _on_subsystem_performance_changed(subsystem_name: String, performance: float) -> void:
	"""Handle subsystem performance changes."""
	# Emit subsystem damage signal for external systems
	var damage_percent: float = (1.0 - performance) * 100.0
	subsystem_damaged.emit(subsystem_name, damage_percent)

## Handle critical subsystem destruction (SHIP-002)
func _on_critical_subsystem_destroyed(subsystem_name: String) -> void:
	"""Handle critical subsystem destruction."""
	# Check if ship should be disabled due to critical failures
	if subsystem_manager:
		if subsystem_manager.has_critical_subsystem_failure():
			is_disabled = true
			ship_disabled.emit()

## Handle ship activation from lifecycle controller (SHIP-004)
func _on_ship_activated(activated_ship: BaseShip) -> void:
	"""Handle ship activation completion."""
	if activated_ship == self:
		is_disabled = false
		ship_enabled.emit()

## Handle ship destruction from lifecycle controller (SHIP-004)
func _on_ship_lifecycle_destroyed(destroyed_ship: BaseShip) -> void:
	"""Handle ship destruction from lifecycle controller."""
	if destroyed_ship == self:
		# Lifecycle controller handles the destruction sequence
		# BaseShip just needs to update its state
		is_dying = true

## Handle ship arrival completion (SHIP-004)
func _on_ship_arrival_completed(arrived_ship: BaseShip) -> void:
	"""Handle ship arrival sequence completion."""
	if arrived_ship == self:
		# Ship is now fully active and operational
		pass

## Handle ship departure start (SHIP-004)
func _on_ship_departure_started(departing_ship: BaseShip, stage: int) -> void:
	"""Handle ship departure sequence start."""
	if departing_ship == self:
		# Begin shutdown of non-essential systems
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
	
	# Add subsystem information (SHIP-002)
	if subsystem_manager:
		var subsystem_info: String = " " + subsystem_manager.debug_info()
		return base_info + " " + ship_info + subsystem_info
	
	return base_info + " " + ship_info

# ============================================================================
# SUBSYSTEM API METHODS (SHIP-002)
# ============================================================================

## Apply damage to specific subsystem
func apply_subsystem_damage(subsystem_name: String, damage: float, impact_position: Vector3 = Vector3.ZERO) -> float:
	"""Apply damage to a specific subsystem.
	
	Args:
		subsystem_name: Name of subsystem to damage
		damage: Amount of damage to apply
		impact_position: World position of impact for proximity calculation
		
	Returns:
		Actual damage applied
	"""
	if not subsystem_manager:
		return 0.0
	
	var subsystem: Subsystem = subsystem_manager.get_subsystem_by_name(subsystem_name)
	if not subsystem:
		return 0.0
	
	return subsystem.apply_damage(damage, impact_position)

## Get subsystem health percentage
func get_subsystem_health(subsystem_name: String) -> float:
	"""Get health percentage of named subsystem (0-100)."""
	if not subsystem_manager:
		return 0.0
	
	return subsystem_manager.get_subsystem_health(subsystem_name)

## Check if subsystem is functional
func is_subsystem_functional(subsystem_name: String) -> bool:
	"""Check if named subsystem is functional."""
	if not subsystem_manager:
		return false
	
	return subsystem_manager.is_subsystem_functional(subsystem_name)

## Queue subsystem for repair
func repair_subsystem(subsystem_name: String) -> bool:
	"""Queue named subsystem for repair.
	
	Args:
		subsystem_name: Name of subsystem to repair
		
	Returns:
		true if successfully queued for repair
	"""
	if not subsystem_manager:
		return false
	
	var subsystem: Subsystem = subsystem_manager.get_subsystem_by_name(subsystem_name)
	if not subsystem:
		return false
	
	return subsystem_manager.queue_subsystem_repair(subsystem)

## Get overall performance by category
func get_subsystem_performance(category: String) -> float:
	"""Get overall subsystem performance for category (engine, weapon, shield, sensor)."""
	if not subsystem_manager:
		return 1.0
	
	return subsystem_manager.get_overall_performance(category)

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
		"dying": is_dying,
		"subsystem_status": subsystem_manager.get_subsystem_status() if subsystem_manager else {}
	}


# ============================================================================
# LIFECYCLE AND STATE MANAGEMENT API (SHIP-004)
# ============================================================================

## Begin ship arrival sequence (SHIP-004 AC2)
func begin_arrival(arrival_position: Vector3 = Vector3.ZERO, arrival_cue: String = "") -> bool:
	"""Begin ship arrival sequence with warp effects.
	
	Args:
		arrival_position: World position for arrival
		arrival_cue: Mission cue name for arrival event
		
	Returns:
		true if arrival sequence started successfully
	"""
	if not lifecycle_controller:
		push_error("BaseShip: Lifecycle controller not initialized")
		return false
	
	return lifecycle_controller.begin_ship_arrival(arrival_position, arrival_cue)

## Begin ship departure sequence (SHIP-004 AC2)
func begin_departure(departure_position: Vector3 = Vector3.ZERO, departure_cue: String = "", via_warp: bool = true) -> bool:
	"""Begin ship departure sequence.
	
	Args:
		departure_position: World position for departure
		departure_cue: Mission cue name for departure event
		via_warp: true for warp departure, false for docking bay
		
	Returns:
		true if departure sequence started successfully
	"""
	if not lifecycle_controller:
		push_error("BaseShip: Lifecycle controller not initialized")
		return false
	
	return lifecycle_controller.begin_ship_departure(departure_position, departure_cue, via_warp)

## Get current ship state (SHIP-004 AC1)
func get_ship_state() -> int:
	"""Get current ship lifecycle state.
	
	Returns:
		ShipStateManager.ShipState value
	"""
	if not state_manager:
		return 0  # NOT_YET_PRESENT
	
	return state_manager.get_ship_state()

## Set ship state with validation (SHIP-004 AC3)
func set_ship_state(new_state: int) -> bool:
	"""Set ship state with validation.
	
	Args:
		new_state: Target ship state
		
	Returns:
		true if state transition was valid and applied
	"""
	if not state_manager:
		push_error("BaseShip: State manager not initialized")
		return false
	
	return state_manager.set_ship_state(new_state)

## Set ship team assignment (SHIP-004 AC5)
func set_ship_team(new_team: int) -> bool:
	"""Set ship team assignment.
	
	Args:
		new_team: New team assignment
		
	Returns:
		true if team was set successfully
	"""
	if not state_manager:
		push_error("BaseShip: State manager not initialized")
		return false
	
	# Update both state manager and ship property
	if state_manager.set_team(new_team):
		team = new_team
		return true
	
	return false

## Get ship team relationship with another ship (SHIP-004 AC5)
func get_relationship_with_ship(other_ship: BaseShip) -> int:
	"""Get relationship with another ship.
	
	Args:
		other_ship: Ship to check relationship with
		
	Returns:
		TeamTypes.Relationship value
	"""
	if not state_manager or not other_ship or not other_ship.state_manager:
		return 1  # HOSTILE (safe default)
	
	return state_manager.get_team_relationship(other_ship.get_ship_team())

## Check if hostile to another ship (SHIP-004 AC5)
func is_hostile_to_ship(other_ship: BaseShip) -> bool:
	"""Check if this ship is hostile to another ship."""
	var relationship: int = get_relationship_with_ship(other_ship)
	return relationship == 1  # TeamTypes.Relationship.HOSTILE

## Set mission flag (SHIP-004 AC1)
func set_mission_flag(flag: int, enabled: bool) -> bool:
	"""Set mission-persistent flag.
	
	Args:
		flag: Flag from ShipStateManager.MissionFlags enum
		enabled: true to set, false to clear
		
	Returns:
		true if flag was set successfully
	"""
	if not state_manager:
		return false
	
	return state_manager.set_mission_flag(flag, enabled)

## Set runtime flag (SHIP-004 AC1)
func set_runtime_flag(flag: int, enabled: bool) -> bool:
	"""Set runtime flag.
	
	Args:
		flag: Flag from ShipStateManager.RuntimeFlags enum
		enabled: true to set, false to clear
		
	Returns:
		true if flag was set successfully
	"""
	if not state_manager:
		return false
	
	return state_manager.set_runtime_flag(flag, enabled)

## Check if mission flag is set (SHIP-004 AC1)
func has_mission_flag(flag: int) -> bool:
	"""Check if mission-persistent flag is set."""
	if not state_manager:
		return false
	
	return state_manager.has_mission_flag(flag)

## Check if runtime flag is set (SHIP-004 AC1)
func has_runtime_flag(flag: int) -> bool:
	"""Check if runtime flag is set."""
	if not state_manager:
		return false
	
	return state_manager.has_runtime_flag(flag)

## Get save data for mission persistence (SHIP-004 AC7)
func get_mission_save_data() -> Dictionary:
	"""Get ship data for mission save files.
	
	Returns:
		Dictionary containing all persistent ship data
	"""
	var save_data: Dictionary = {
		"ship_name": ship_name,
		"ship_class_path": ship_class.resource_path if ship_class else "",
		"position": global_position,
		"rotation": global_rotation,
		"hull_strength": current_hull_strength,
		"shield_strength": current_shield_strength,
		"weapon_energy": current_weapon_energy,
		"afterburner_fuel": current_afterburner_fuel,
		"ets_allocation": [shield_recharge_rate, weapon_recharge_rate, engine_power_rate]
	}
	
	# Include state manager data
	if state_manager:
		save_data["state_data"] = state_manager.get_mission_save_data()
	
	# Include lifecycle controller data
	if lifecycle_controller:
		save_data["lifecycle_data"] = lifecycle_controller.get_save_data()
	
	# Include subsystem data
	if subsystem_manager:
		save_data["subsystem_data"] = subsystem_manager.get_save_data()
	
	return save_data

# ============================================================================
# WEAPON MANAGEMENT API (SHIP-005)
# ============================================================================

## Fire primary weapons (SHIP-005 AC2)
func fire_primary_weapons() -> bool:
	"""Fire selected primary weapon banks.
	
	Returns:
		true if weapons fired successfully
	"""
	if not weapon_manager:
		return false
	
	return weapon_manager.fire_primary_weapons()

## Fire secondary weapons (SHIP-005 AC4)
func fire_secondary_weapons() -> bool:
	"""Fire selected secondary weapon banks.
	
	Returns:
		true if weapons fired successfully
	"""
	if not weapon_manager:
		return false
	
	return weapon_manager.fire_secondary_weapons()

## Set weapon target (SHIP-005 AC6)
func set_weapon_target(target: Node3D, target_subsystem: Node = null) -> void:
	"""Set target for weapon systems.
	
	Args:
		target: Target node to engage
		target_subsystem: Optional specific subsystem to target
	"""
	if weapon_manager:
		weapon_manager.set_weapon_target(target, target_subsystem)

## Select weapon bank (SHIP-005 AC5)
func select_weapon_bank(bank_type: WeaponBankType.Type, bank_index: int) -> bool:
	"""Select specific weapon bank.
	
	Args:
		bank_type: Type of weapon bank (PRIMARY, SECONDARY)
		bank_index: Index of bank to select
		
	Returns:
		true if selection successful
	"""
	if not weapon_manager:
		return false
	
	return weapon_manager.select_weapon_bank(bank_type, bank_index)

## Cycle weapon selection (SHIP-005 AC5)
func cycle_weapon_selection(bank_type: WeaponBankType.Type, forward: bool = true) -> bool:
	"""Cycle through available weapons.
	
	Args:
		bank_type: Type of weapon bank to cycle
		forward: true for next weapon, false for previous
		
	Returns:
		true if cycling successful
	"""
	if not weapon_manager:
		return false
	
	return weapon_manager.cycle_weapon_selection(bank_type, forward)

## Set weapon linking mode (SHIP-005 AC5)
func set_weapon_linking_mode(bank_type: WeaponBankType.Type, linked: bool) -> void:
	"""Set weapon linking mode for bank type.
	
	Args:
		bank_type: Type of weapon bank to modify
		linked: true to link weapons of same type, false for single bank
	"""
	if weapon_manager:
		weapon_manager.set_weapon_linking_mode(bank_type, linked)

## Get weapon status (SHIP-005 AC1)
func get_weapon_status() -> Dictionary:
	"""Get comprehensive weapon system status.
	
	Returns:
		Dictionary containing weapon system information
	"""
	if not weapon_manager:
		return {}
	
	return weapon_manager.get_weapon_status()

## Enable/disable weapon systems (SHIP-005 AC7)
func set_weapons_enabled(enabled: bool) -> void:
	"""Enable or disable weapon systems.
	
	Args:
		enabled: true to enable weapons, false to disable
	"""
	if weapon_manager:
		weapon_manager.set_weapons_enabled(enabled)

## Consume weapon energy (SHIP-005 AC3)
func consume_weapon_energy(amount: float) -> bool:
	"""Consume weapon energy for firing.
	
	Args:
		amount: Amount of energy to consume
		
	Returns:
		true if energy was available and consumed
	"""
	if current_weapon_energy >= amount:
		current_weapon_energy -= amount
		current_weapon_energy = max(0.0, current_weapon_energy)
		return true
	return false

## Add weapon energy (SHIP-005 AC3)
func add_weapon_energy(amount: float) -> void:
	"""Add weapon energy from regeneration.
	
	Args:
		amount: Amount of energy to add
	"""
	current_weapon_energy = min(current_weapon_energy + amount, max_weapon_energy)

## Get weapon energy allocation from ETS (SHIP-005 AC3)
func get_weapon_energy_allocation() -> float:
	"""Get current weapon energy allocation from ETS.
	
	Returns:
		Weapon energy allocation percentage (0.0 to 1.0)
	"""
	return weapon_recharge_rate

# ============================================================================
# WEAPON SYSTEM SIGNAL HANDLERS (SHIP-005)
# ============================================================================

## Handle weapon fired signal
func _on_weapon_fired(bank_type: WeaponBankType.Type, weapon_name: String, projectiles: Array[WeaponBase]) -> void:
	"""Handle weapon firing event."""
	weapon_fired.emit(bank_type, weapon_name, projectiles)

## Handle weapon target acquired signal
func _on_weapon_target_acquired(target: Node3D, target_subsystem: Node) -> void:
	"""Handle weapon target acquisition."""
	weapon_target_acquired.emit(target, target_subsystem)

## Handle weapon target lost signal
func _on_weapon_target_lost() -> void:
	"""Handle weapon target loss."""
	weapon_target_lost.emit()

## Handle ammunition depleted signal
func _on_ammunition_depleted(bank_type: WeaponBankType.Type, bank_index: int) -> void:
	"""Handle ammunition depletion."""
	ammunition_depleted.emit(bank_type, bank_index)

## Load save data from mission persistence (SHIP-004 AC7)
func load_mission_save_data(save_data: Dictionary) -> bool:
	"""Load ship data from mission save files.
	
	Args:
		save_data: Dictionary containing saved ship data
		
	Returns:
		true if data was loaded successfully
	"""
	if not save_data:
		return false
	
	# Load basic ship properties
	ship_name = save_data.get("ship_name", ship_name)
	global_position = save_data.get("position", global_position)
	global_rotation = save_data.get("rotation", global_rotation)
	current_hull_strength = save_data.get("hull_strength", current_hull_strength)
	current_shield_strength = save_data.get("shield_strength", current_shield_strength)
	current_weapon_energy = save_data.get("weapon_energy", current_weapon_energy)
	current_afterburner_fuel = save_data.get("afterburner_fuel", current_afterburner_fuel)
	
	# Load ETS allocation
	var ets_allocation: Array = save_data.get("ets_allocation", [0.333, 0.333, 0.333])
	if ets_allocation.size() >= 3:
		set_ets_allocation(ets_allocation[0], ets_allocation[1], ets_allocation[2])
	
	# Load state manager data
	if state_manager and save_data.has("state_data"):
		state_manager.load_mission_save_data(save_data["state_data"])
	
	# Load lifecycle controller data
	if lifecycle_controller and save_data.has("lifecycle_data"):
		lifecycle_controller.load_save_data(save_data["lifecycle_data"])
	
	# Load subsystem data
	if subsystem_manager and save_data.has("subsystem_data"):
		subsystem_manager.load_save_data(save_data["subsystem_data"])
	
	return true
