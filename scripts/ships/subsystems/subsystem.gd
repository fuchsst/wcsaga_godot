class_name Subsystem
extends Node

## Active subsystem instance for ship subsystem management
## Represents runtime state and behavior of a ship subsystem
## Integrates with WCS-authentic damage modeling and performance effects

# Required references
const SubsystemDefinition = preload("res://addons/wcs_asset_core/resources/ship/subsystem_definition.gd")
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Signals for subsystem state changes (SHIP-002 AC7)
signal subsystem_damaged(subsystem: Subsystem, damage_amount: float)
signal subsystem_destroyed(subsystem: Subsystem)
signal subsystem_repaired(subsystem: Subsystem, repair_amount: float)
signal performance_changed(subsystem: Subsystem, new_performance: float)
signal target_acquired(subsystem: Subsystem, target: Node3D)  # For turrets
signal target_lost(subsystem: Subsystem)  # For turrets

# Core subsystem state (SHIP-002 AC1)
@export var subsystem_definition: SubsystemDefinition
@export var current_hits: float = 100.0
@export var max_hits: float = 100.0
@export var is_functional: bool = true
@export var is_repairing: bool = false

# Performance tracking (SHIP-002 AC2, AC3)
var performance_modifier: float = 1.0
var damage_state: SubsystemTypes.DamageState = SubsystemTypes.DamageState.UNDAMAGED
var last_damage_time: float = 0.0
var repair_rate: float = 2.0  # Hits per second repair rate

# Ship reference
var parent_ship: BaseShip
var subsystem_manager: SubsystemManager

# Turret-specific state (SHIP-002 AC5)
var turret_target: Node3D
var turret_current_facing: Vector3 = Vector3.FORWARD
var turret_locked_on: bool = false
var turret_last_fire_time: float = 0.0
var turret_accuracy_bonus: float = 0.0

# Proximity damage tracking (SHIP-002 AC4)
var damage_accumulator: float = 0.0
var last_frame_processed: int = 0

# Node references
var model_subobject: Node3D  # Reference to 3D model subobject

func _init() -> void:
	set_physics_process(false)  # Enable only when needed
	set_process(false)

func _ready() -> void:
	if subsystem_definition:
		_initialize_from_definition()

## Initialize subsystem from definition (SHIP-002 AC1)
func initialize_subsystem(definition: SubsystemDefinition, ship: BaseShip, manager: SubsystemManager) -> bool:
	"""Initialize subsystem with definition and ship references.
	
	Args:
		definition: Subsystem definition resource
		ship: Parent ship reference
		manager: Subsystem manager reference
		
	Returns:
		true if initialization successful
	"""
	if not definition or not definition.is_valid():
		push_error("Subsystem: Invalid subsystem definition")
		return false
	
	subsystem_definition = definition
	parent_ship = ship
	subsystem_manager = manager
	
	_initialize_from_definition()
	_setup_subsystem_processing()
	
	return true

## Initialize properties from subsystem definition
func _initialize_from_definition() -> void:
	"""Configure subsystem properties from definition."""
	if not subsystem_definition:
		return
	
	# Set basic properties
	name = subsystem_definition.get_display_name()
	max_hits = subsystem_definition.max_hits
	current_hits = max_hits
	is_functional = true
	
	# Initialize performance
	_update_performance_modifier()
	_update_damage_state()
	
	# Initialize repair rate based on type
	repair_rate = _calculate_base_repair_rate()

## Setup frame processing based on subsystem type
func _setup_subsystem_processing() -> void:
	"""Enable appropriate processing for subsystem type."""
	if not subsystem_definition:
		return
	
	# Turrets need frame processing for targeting
	if subsystem_definition.is_turret():
		set_process(true)
		turret_current_facing = Vector3.FORWARD
		
	# Repairable subsystems need physics process
	if subsystem_definition.subsystem_type != SubsystemTypes.Type.NONE:
		set_physics_process(true)

## Frame processing for turret AI and repair systems
func _process(delta: float) -> void:
	if not is_functional or not subsystem_definition:
		return
	
	# Process turret AI (SHIP-002 AC5)
	if subsystem_definition.is_turret():
		_process_turret_ai(delta)

## Physics processing for repair and state management
func _physics_process(delta: float) -> void:
	if not subsystem_definition:
		return
	
	# Process subsystem repair (SHIP-002 AC6)
	if is_repairing and current_hits < max_hits:
		_process_repair(delta)
	
	# Update performance effects
	_update_performance_effects()

## Process turret AI behavior (SHIP-002 AC5)
func _process_turret_ai(delta: float) -> void:
	"""Process turret targeting and firing behavior."""
	if not parent_ship or not is_functional:
		return
	
	# Acquire or update target
	_update_turret_target(delta)
	
	# Track target if available
	if turret_target and is_instance_valid(turret_target):
		_track_turret_target(delta)
	else:
		_lose_turret_target()

## Update turret target acquisition (SHIP-002 AC5)
func _update_turret_target(delta: float) -> void:
	"""Update turret target selection with multi-criteria prioritization."""
	var current_time: float = Time.get_ticks_msec() * 0.001
	
	# Check for target updates periodically
	if current_time - turret_last_fire_time < 0.5:  # Update every 0.5 seconds
		return
	
	# Find potential targets in range
	var potential_targets: Array[Node3D] = _find_potential_targets()
	if potential_targets.is_empty():
		_lose_turret_target()
		return
	
	# Select best target using WCS-style prioritization
	var best_target: Node3D = _select_best_turret_target(potential_targets)
	
	if best_target != turret_target:
		if turret_target:
			target_lost.emit(self)
		
		turret_target = best_target
		turret_locked_on = false
		turret_accuracy_bonus = 0.0
		
		if turret_target:
			target_acquired.emit(self, turret_target)

## Find potential targets for turret
func _find_potential_targets() -> Array[Node3D]:
	"""Find all potential targets within turret range and FOV."""
	var targets: Array[Node3D] = []
	
	if not parent_ship or not parent_ship.physics_body:
		return targets
	
	# Get all ships in physics space
	var space_state := parent_ship.physics_body.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	
	# Create sphere query for range detection
	var sphere := SphereShape3D.new()
	sphere.radius = subsystem_definition.turret_range
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = (1 << CollisionLayers.Layer.SHIPS)  # Only ships
	
	var results := space_state.intersect_shape(query)
	
	for result in results:
		var collider := result["collider"] as RigidBody3D
		if not collider:
			continue
		
		var target_ship := collider.get_parent() as BaseShip
		if not target_ship or target_ship == parent_ship:
			continue
		
		# Check team alignment (don't target friendlies)
		if target_ship.team == parent_ship.team:
			continue
		
		# Check FOV constraint
		if _is_target_in_fov(target_ship):
			targets.append(target_ship)
	
	return targets

## Select best target using WCS prioritization
func _select_best_turret_target(targets: Array[Node3D]) -> Node3D:
	"""Select best target using multi-criteria WCS-style prioritization."""
	if targets.is_empty():
		return null
	
	var best_target: Node3D = null
	var best_score: float = -1.0
	
	for target in targets:
		var score: float = _calculate_target_priority_score(target)
		if score > best_score:
			best_score = score
			best_target = target
	
	return best_target

## Calculate target priority score
func _calculate_target_priority_score(target: Node3D) -> float:
	"""Calculate priority score for target selection."""
	var score: float = 0.0
	
	if not target or not parent_ship:
		return score
	
	var distance: float = global_position.distance_to(target.global_position)
	
	# Closer targets get higher score (inverse distance)
	score += (subsystem_definition.turret_range - distance) / subsystem_definition.turret_range * 40.0
	
	# Target type prioritization (if we can determine ship type)
	var target_ship := target as BaseShip
	if target_ship and target_ship.ship_class:
		match target_ship.ship_class.ship_type:
			ShipTypes.Type.FIGHTER:
				score += 30.0  # High priority
			ShipTypes.Type.BOMBER:
				score += 35.0  # Highest priority
			ShipTypes.Type.TRANSPORT:
				score += 20.0  # Medium priority
			ShipTypes.Type.CRUISER:
				score += 15.0  # Lower priority
			_:
				score += 10.0  # Default priority
	
	# Health-based prioritization (weaker targets preferred)
	if target_ship:
		var health_percent: float = (target_ship.current_hull_strength / target_ship.max_hull_strength) * 100.0
		score += (100.0 - health_percent) * 0.2  # Up to 20 points for damaged targets
	
	# Angle to target (prefer targets in front)
	var to_target: Vector3 = (target.global_position - global_position).normalized()
	var facing_dot: float = turret_current_facing.dot(to_target)
	score += facing_dot * 10.0  # Up to 10 points for targets in current facing
	
	return score

## Check if target is within turret FOV
func _is_target_in_fov(target: Node3D) -> bool:
	"""Check if target is within turret field of view."""
	if not target:
		return false
	
	var to_target: Vector3 = (target.global_position - global_position).normalized()
	var turret_forward: Vector3 = turret_current_facing.normalized()
	
	var angle: float = acos(turret_forward.dot(to_target))
	var fov_radians: float = deg_to_rad(subsystem_definition.turret_fov * 0.5)
	
	return angle <= fov_radians

## Track current turret target
func _track_turret_target(delta: float) -> void:
	"""Update turret facing to track current target."""
	if not turret_target or not is_instance_valid(turret_target):
		return
	
	var to_target: Vector3 = (turret_target.global_position - global_position).normalized()
	var turn_rate_rad: float = deg_to_rad(subsystem_definition.turret_turn_rate)
	
	# Smoothly rotate turret toward target
	var angle_to_target: float = turret_current_facing.angle_to(to_target)
	var max_turn: float = turn_rate_rad * delta
	
	if angle_to_target <= max_turn:
		# Can reach target this frame
		turret_current_facing = to_target
		turret_locked_on = true
		turret_accuracy_bonus = min(turret_accuracy_bonus + delta * 2.0, 1.0)  # Build accuracy over time
	else:
		# Turn toward target
		var cross: Vector3 = turret_current_facing.cross(to_target)
		var rotation_axis: Vector3 = cross.normalized()
		turret_current_facing = turret_current_facing.rotated(rotation_axis, max_turn)
		turret_locked_on = false
		turret_accuracy_bonus = max(turret_accuracy_bonus - delta, 0.0)  # Lose accuracy when turning

## Lose current turret target
func _lose_turret_target() -> void:
	"""Clear current turret target and reset state."""
	if turret_target:
		target_lost.emit(self)
	
	turret_target = null
	turret_locked_on = false
	turret_accuracy_bonus = 0.0

## Process subsystem repair (SHIP-002 AC6)
func _process_repair(delta: float) -> void:
	"""Process subsystem repair over time."""
	if current_hits >= max_hits:
		is_repairing = false
		return
	
	var repair_amount: float = repair_rate * delta
	var old_hits: float = current_hits
	
	current_hits = min(current_hits + repair_amount, max_hits)
	var actual_repair: float = current_hits - old_hits
	
	if actual_repair > 0.0:
		subsystem_repaired.emit(self, actual_repair)
		_update_performance_modifier()
		_update_damage_state()
		
		# Check if fully repaired
		if current_hits >= max_hits:
			is_repairing = false
			is_functional = true

## Calculate base repair rate based on subsystem type
func _calculate_base_repair_rate() -> float:
	"""Calculate base repair rate for this subsystem type."""
	if not subsystem_definition:
		return 2.0
	
	# Base repair rate modified by priority and type
	var base_rate: float = 2.0
	var priority_modifier: float = subsystem_definition.get_repair_priority() / 10.0
	
	match subsystem_definition.subsystem_type:
		SubsystemTypes.Type.ENGINE:
			return base_rate * 1.5 * priority_modifier  # Engines repair faster
		SubsystemTypes.Type.WEAPONS:
			return base_rate * 1.2 * priority_modifier  # Weapons repair moderately fast
		SubsystemTypes.Type.RADAR, SubsystemTypes.Type.SENSORS:
			return base_rate * 0.8 * priority_modifier  # Electronics repair slowly
		SubsystemTypes.Type.COMMUNICATION:
			return base_rate * 0.6 * priority_modifier  # Communication repairs slowest
		_:
			return base_rate * priority_modifier

## Apply damage to subsystem (SHIP-002 AC4)
func apply_damage(damage_amount: float, impact_position: Vector3 = Vector3.ZERO) -> float:
	"""Apply damage to subsystem with proximity calculations.
	
	Args:
		damage_amount: Base damage amount
		impact_position: World position of impact for proximity calculation
		
	Returns:
		Actual damage applied after calculations
	"""
	if damage_amount <= 0.0 or not is_functional:
		return 0.0
	
	# Calculate proximity modifier (SHIP-002 AC4)
	var proximity_modifier: float = _calculate_proximity_damage_modifier(impact_position)
	
	# Apply vulnerability modifier
	var vulnerability: float = subsystem_definition.get_vulnerability_modifier()
	var actual_damage: float = damage_amount * proximity_modifier * vulnerability
	
	# Apply damage
	var old_hits: float = current_hits
	current_hits = max(0.0, current_hits - actual_damage)
	var damage_applied: float = old_hits - current_hits
	
	last_damage_time = Time.get_ticks_msec() * 0.001
	
	# Update state
	_update_performance_modifier()
	_update_damage_state()
	
	# Check for destruction
	if current_hits <= 0.0 and is_functional:
		_trigger_subsystem_destruction()
	
	# Emit damage signal
	if damage_applied > 0.0:
		subsystem_damaged.emit(self, damage_applied)
	
	return damage_applied

## Calculate proximity-based damage modifier (SHIP-002 AC4)
func _calculate_proximity_damage_modifier(impact_position: Vector3) -> float:
	"""Calculate damage modifier based on proximity to impact point."""
	if impact_position == Vector3.ZERO:
		return 1.0  # Default damage if no position provided
	
	var distance: float = global_position.distance_to(impact_position)
	var radius: float = subsystem_definition.radius
	
	# Full damage within subsystem radius
	if distance <= radius:
		return 1.0
	
	# Reduced damage based on distance beyond radius
	var max_distance: float = radius * 3.0  # Damage drops to zero at 3x radius
	if distance >= max_distance:
		return 0.0
	
	# Linear falloff from radius to max_distance
	var falloff: float = (max_distance - distance) / (max_distance - radius)
	return max(0.0, falloff)

## Trigger subsystem destruction
func _trigger_subsystem_destruction() -> void:
	"""Handle subsystem destruction sequence."""
	is_functional = false
	current_hits = 0.0
	performance_modifier = 0.0
	damage_state = SubsystemTypes.DamageState.DESTROYED
	
	# Stop repair if in progress
	is_repairing = false
	
	# Clear turret target if applicable
	if subsystem_definition.is_turret():
		_lose_turret_target()
	
	# Emit destruction signal
	subsystem_destroyed.emit(self)
	
	# Trigger dependent subsystem failures
	_trigger_dependent_failures()

## Trigger failures in dependent subsystems
func _trigger_dependent_failures() -> void:
	"""Trigger failures in subsystems that depend on this one."""
	if not subsystem_manager or subsystem_definition.dependent_subsystems.is_empty():
		return
	
	for dependent_name in subsystem_definition.dependent_subsystems:
		var dependent: Subsystem = subsystem_manager.get_subsystem_by_name(dependent_name)
		if dependent and dependent.is_functional:
			# Apply cascading failure damage
			dependent.apply_damage(dependent.max_hits * 0.5)  # 50% damage to dependents

## Update performance modifier based on current health (SHIP-002 AC3)
func _update_performance_modifier() -> void:
	"""Update performance modifier using WCS-authentic curves."""
	var health_percent: float = get_health_percentage()
	var old_performance: float = performance_modifier
	
	performance_modifier = subsystem_definition.get_performance_modifier(health_percent)
	
	# Emit signal if performance changed significantly
	if abs(performance_modifier - old_performance) > 0.01:
		performance_changed.emit(self, performance_modifier)

## Update damage state
func _update_damage_state() -> void:
	"""Update damage state based on current health."""
	damage_state = subsystem_definition.get_damage_state(get_health_percentage())

## Update performance effects on ship
func _update_performance_effects() -> void:
	"""Apply performance effects to parent ship systems."""
	if not parent_ship or not subsystem_definition:
		return
	
	# Apply effects based on subsystem type (SHIP-002 AC2)
	match subsystem_definition.subsystem_type:
		SubsystemTypes.Type.ENGINE:
			parent_ship.engine_performance = performance_modifier
		SubsystemTypes.Type.WEAPONS:
			parent_ship.weapon_performance = performance_modifier
		SubsystemTypes.Type.RADAR, SubsystemTypes.Type.SENSORS:
			parent_ship.shield_performance = performance_modifier  # Sensors affect shield efficiency

## Start repair process (SHIP-002 AC6)
func start_repair() -> bool:
	"""Start repair process for this subsystem.
	
	Returns:
		true if repair started successfully
	"""
	if current_hits >= max_hits:
		return false  # Already at full health
	
	if not is_functional and current_hits <= 0.0:
		return false  # Cannot repair completely destroyed subsystems without replacement
	
	is_repairing = true
	return true

## Stop repair process
func stop_repair() -> void:
	"""Stop current repair process."""
	is_repairing = false

## Get current health percentage
func get_health_percentage() -> float:
	"""Get current health as percentage (0-100)."""
	if max_hits <= 0.0:
		return 0.0
	return (current_hits / max_hits) * 100.0

## Get subsystem status information
func get_status_info() -> Dictionary:
	"""Get comprehensive subsystem status information."""
	return {
		"name": subsystem_definition.get_display_name() if subsystem_definition else "Unknown",
		"type": SubsystemTypes.get_type_name(subsystem_definition.subsystem_type) if subsystem_definition else "Unknown",
		"health_percent": get_health_percentage(),
		"current_hits": current_hits,
		"max_hits": max_hits,
		"performance_modifier": performance_modifier,
		"damage_state": SubsystemTypes.get_damage_state_name(damage_state),
		"is_functional": is_functional,
		"is_repairing": is_repairing,
		"is_critical": subsystem_definition.is_critical if subsystem_definition else false,
		"turret_info": _get_turret_status() if subsystem_definition and subsystem_definition.is_turret() else {}
	}

## Get turret-specific status information
func _get_turret_status() -> Dictionary:
	"""Get turret-specific status information."""
	return {
		"has_target": turret_target != null,
		"locked_on": turret_locked_on,
		"accuracy_bonus": turret_accuracy_bonus,
		"facing_direction": turret_current_facing,
		"target_name": turret_target.name if turret_target else ""
	}

## Debug information string
func debug_info() -> String:
	var info: String = "[%s: %.1f%% (%.1f/%.1f) Perf:%.2f]" % [
		name, get_health_percentage(), current_hits, max_hits, performance_modifier
	]
	
	if subsystem_definition and subsystem_definition.is_turret() and turret_target:
		info += " Target:%s" % turret_target.name
	
	return info