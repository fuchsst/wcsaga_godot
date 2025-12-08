@tool
class_name ShipEntity
extends WCSPhysicsBody

# === SIGNALS ===
signal ship_destroyed(ship: ShipEntity, killer: Node)
signal damage_received(ship: ShipEntity, damage_result: DamageResult)
signal shield_hit(ship: ShipEntity, quadrant: int, damage: float)
signal subsystem_damaged(ship: ShipEntity, subsystem_name: String, new_health_percent: float)
signal weapon_fired(ship: ShipEntity, weapon_slot: int, weapon_scene: PackedScene)
signal afterburner_state_changed(enabled: bool)

# === CONFIGURATION ===
@export var stats: ShipStats:
	set(value):
		stats = value
		if is_inside_tree():
			_initialize_from_stats()

@export var team: int = 0 ## IFF team index
@export var ship_name: String = "" ## Instance name (e.g., "Alpha 1")

# === STATE ===
## Hull and shields
var current_hull: float = 100.0
var current_shields: Array[float] = [100.0, 100.0, 100.0, 100.0] ## Front, Left, Right, Rear
var shield_quadrant_count: int = 4

## Energy systems
var weapon_energy: float = 100.0
var afterburner_fuel: float = 100.0
var is_afterburner_active: bool = false

## Subsystem health (0.0 = destroyed, 1.0 = full health)
var subsystem_health: Dictionary = {}

## Combat state
var is_destroyed: bool = false
var last_attacker: Node = null
var damage_feedback: Array[DamageResult] = []

# === SYSTEMS ===
const ShipWeaponSystemScript = preload("res://scripts/entities/ship/weapon_system.gd")
var weapon_system: Node # Type hint issues with cyclic preloads, safer to use Node or weak ref

# === COMPONENTS ===
var model_node: Node3D
var collision_shape: CollisionShape3D

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	super._ready()
	add_to_group("ships")
	add_to_group("game_entities")

	# Initialize weapon system
	weapon_system = ShipWeaponSystemScript.new()
	weapon_system.name = "WeaponSystem"
	add_child(weapon_system)
	
	# Forward weapon fired signal
	weapon_system.weapon_fired.connect(func(_idx, secondary):
		# TODO: We need the actual projectile scene or weapon type to emit with signal
		# For now emitting null scene as placeholder
		weapon_fired.emit(self, 1 if secondary else 0, null)
	)

	if stats:
		_initialize_from_stats()
		weapon_system.setup(self)
	else:
		push_warning("ShipEntity initialized without ShipStats!")


func _initialize_from_stats() -> void:
	if not stats:
		return

	# Initialize hull and shields
	current_hull = stats.hull_hitpoints
	_initialize_shields()

	# Initialize energy
	weapon_energy = stats.max_weapon_energy
	afterburner_fuel = stats.max_afterburner_fuel

	# Initialize subsystems
	_initialize_subsystems()

	# Generate physics data from ship stats if not already set
	if not physics_data:
		physics_data = _create_physics_data_from_stats()


func _initialize_shields() -> void:
	if stats.shield_strength > 0:
		var per_quadrant = stats.shield_strength / float(shield_quadrant_count)
		current_shields.clear()
		for i in range(shield_quadrant_count):
			current_shields.append(per_quadrant)
	else:
		current_shields = [0.0, 0.0, 0.0, 0.0]


func _initialize_subsystems() -> void:
	subsystem_health.clear()

	# Add engine subsystems
	for engine in stats.engine_subsystems:
		subsystem_health[engine.subsystem_name] = 1.0

	# Add weapon subsystems
	for weapon_sub in stats.weapon_subsystems:
		subsystem_health[weapon_sub.subsystem_name] = 1.0

	# Add shield subsystems
	for shield_sub in stats.shield_subsystems:
		subsystem_health[shield_sub.subsystem_name] = 1.0


func _create_physics_data_from_stats() -> ShipPhysicsData:
	"""Create ShipPhysicsData from ShipStats movement properties"""
	var data = ShipPhysicsData.new()

	# Mass from ship mass
	data.mass = stats.ship_mass_tons if stats.ship_mass_tons > 0 else 10.0

	# Velocity limits
	data.max_velocity = stats.max_velocity
	data.max_rear_velocity = (
		stats.rear_velocity if stats.rear_velocity > 0 else stats.max_velocity.z * 0.3
	)
	data.afterburner_max_velocity = stats.afterburner_velocity

	# Calculate rotational velocity from rotation time (time for 360° rotation)
	# rot_vel = 2*PI / rotation_time
	data.max_rotational_velocity = Vector3(
		TAU / max(stats.rotation_time.x, 0.1),
		TAU / max(stats.rotation_time.y, 0.1),
		TAU / max(stats.rotation_time.z, 0.1)
	)

	# Damping
	data.rotational_damping = stats.rotational_dampening if stats.rotational_dampening > 0 else 0.1
	data.side_slip_time_const = stats.movement_dampening if stats.movement_dampening > 0 else 0.05

	# Acceleration - convert from fraction to time constant
	# In WCS: accel_factor is fraction per frame, we need time constant
	data.forward_accel_time_const = 1.0 / max(stats.forward_acceleration, 0.1) * 0.1
	data.forward_decel_time_const = 1.0 / max(stats.forward_deceleration, 0.1) * 0.1

	# Slide/strafe
	if stats.slide_acceleration > 0:
		data.slide_accel_time_const = 1.0 / stats.slide_acceleration * 0.1
		data.slide_decel_time_const = (
			1.0 / max(stats.slide_deceleration, stats.slide_acceleration) * 0.1
		)

	# Glide mode
	if stats.glide_enabled:
		data.glide_cap = stats.max_velocity.z * 1.1 # Slightly above max normal velocity
		data.glide_accel_mult = 0.5

	return data


# ==============================================================================
# PHYSICS PROCESS
# ==============================================================================


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return

	# Call parent physics (WCSPhysicsBody handles all movement)
	super._physics_process(delta)

	# Update ship-specific systems
	_update_energy_systems(delta)
	_update_shield_regeneration(delta)


func _update_energy_systems(delta: float) -> void:
	if not stats:
		return

	# Weapon energy regeneration
	if weapon_energy < stats.max_weapon_energy:
		var regen = stats.max_weapon_energy * stats.weapon_energy_regen_rate * delta
		weapon_energy = min(weapon_energy + regen, stats.max_weapon_energy)

	# Afterburner fuel consumption/regeneration
	if is_afterburner_active:
		afterburner_fuel -= stats.afterburner_burn_rate * delta
		if afterburner_fuel <= 0:
			afterburner_fuel = 0
			set_afterburner_enabled(false)
	elif afterburner_fuel < stats.max_afterburner_fuel and stats.afterburner_fuel_regen_rate > 0:
		afterburner_fuel = min(
			afterburner_fuel + stats.afterburner_fuel_regen_rate * delta, stats.max_afterburner_fuel
		)


func _update_shield_regeneration(delta: float) -> void:
	if not stats or stats.shield_strength <= 0:
		return

	# Check if shield subsystems are functional
	var shield_efficiency = _get_subsystem_efficiency("shields")
	if shield_efficiency <= 0:
		return

	var max_per_quadrant = stats.shield_strength / float(shield_quadrant_count)
	var regen_amount = stats.shield_strength * stats.shield_regen_rate * delta * shield_efficiency

	# Regenerate each quadrant
	for i in range(current_shields.size()):
		if current_shields[i] < max_per_quadrant:
			current_shields[i] = min(
				current_shields[i] + regen_amount / shield_quadrant_count, max_per_quadrant
			)


# ==============================================================================
# DAMAGE SYSTEM
# ==============================================================================


func take_damage(damage_info: Variant, attacker: Node = null) -> void:
	"""Handle incoming damage - accepts Dictionary or DamageResult"""
	if is_destroyed:
		return

	var result: DamageResult
	if damage_info is DamageResult:
		result = damage_info
	else:
		result = _create_damage_result_from_dict(damage_info, attacker)

	result.attacker = attacker
	last_attacker = attacker

	_apply_damage(result)


func apply_damage_result(result: DamageResult) -> void:
	"""Apply damage using full DamageResult"""
	if is_destroyed:
		return

	last_attacker = result.attacker
	_apply_damage(result)


func _create_damage_result_from_dict(info: Dictionary, attacker: Node = null) -> DamageResult:
	var result = DamageResult.new()
	result.attacker = attacker
	result.original_damage = info.get("total_damage", info.get("hull_damage", 0.0))
	result.shield_absorbed = info.get("shield_damage", 0.0)
	result.actual_damage = info.get("hull_damage", result.original_damage)
	result.damage_type = info.get("damage_type", "generic")
	return result


func _apply_damage(result: DamageResult) -> void:
	# Determine shield quadrant from impact direction
	var quadrant = _get_shield_quadrant(result.impact_point)

	# Apply shield damage first
	var remaining_damage = result.original_damage
	if current_shields[quadrant] > 0:
		var shield_damage = min(remaining_damage, current_shields[quadrant])
		current_shields[quadrant] -= shield_damage
		remaining_damage -= shield_damage
		result.shield_absorbed = shield_damage
		result.is_shield_hit = true
		shield_hit.emit(self, quadrant, shield_damage)

	# Apply hull damage
	if remaining_damage > 0:
		result.actual_damage = remaining_damage
		result.final_hull_damage = remaining_damage
		current_hull -= remaining_damage

	# Store for feedback
	damage_feedback.append(result)
	if damage_feedback.size() > 10:
		damage_feedback.pop_front()

	damage_received.emit(self, result)

	# Check for subsystem damage based on impact location
	_check_subsystem_damage(result)

	# Apply physics whack from weapon hit
	if physics_data and result.impact_point != Vector3.ZERO:
		var impulse = (
			result.actual_damage * 0.1 * (global_position - result.impact_point).normalized()
		)
		apply_whack(impulse, result.impact_point)

	# Check destruction
	if current_hull <= 0:
		result.mark_killing_blow()
		_on_destroyed()


func _get_shield_quadrant(impact_point: Vector3) -> int:
	if impact_point == Vector3.ZERO:
		return 0 # Default to front

	# Convert to local coordinates
	var local_point = to_local(impact_point)

	# Determine quadrant based on direction
	var angle = atan2(local_point.x, -local_point.z)

	if angle >= -PI / 4 and angle < PI / 4:
		return 0 # Front
	elif angle >= PI / 4 and angle < 3 * PI / 4:
		return 2 # Right
	elif angle >= -3 * PI / 4 and angle < -PI / 4:
		return 1 # Left
	else:
		return 3 # Rear


func _check_subsystem_damage(result: DamageResult) -> void:
	# Simple subsystem damage - reduce health based on damage percentage
	if result.actual_damage <= 0:
		return

	var damage_percent = result.actual_damage / max(stats.hull_hitpoints, 1.0) * 0.1

	# Randomly damage a subsystem based on impact
	var subsystem_names = subsystem_health.keys()
	if subsystem_names.size() > 0:
		var target_sub = subsystem_names[randi() % subsystem_names.size()]
		var old_health = subsystem_health[target_sub]
		subsystem_health[target_sub] = max(0.0, old_health - damage_percent)

		if subsystem_health[target_sub] != old_health:
			subsystem_damaged.emit(self, target_sub, subsystem_health[target_sub])


func _get_subsystem_efficiency(subsystem_type: String) -> float:
	"""Get average efficiency of subsystems of a given type"""
	var total = 0.0
	var count = 0

	for sub_name in subsystem_health.keys():
		if sub_name.to_lower().contains(subsystem_type.to_lower()):
			total += subsystem_health[sub_name]
			count += 1

	return total / max(count, 1)


func _on_destroyed() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	ship_destroyed.emit(self, last_attacker)

	# Spawn explosion effect
	_spawn_destruction_effects()

	# Remove after short delay
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(queue_free)


func _spawn_destruction_effects() -> void:
	# TODO: Instantiate explosion scene based on stats.explosion_effect
	pass


# ==============================================================================
# CONTROL API
# ==============================================================================


func set_throttle(percent: float) -> void:
	"""Set forward throttle (-1.0 to 1.0, negative for reverse)"""
	control_input["forward"] = clampf(percent, -1.0, 1.0)


func set_afterburner_enabled(enabled: bool) -> void:
	if enabled and afterburner_fuel <= 0:
		return

	is_afterburner_active = enabled
	set_afterburner(enabled) # Call parent WCSPhysicsBody method
	afterburner_state_changed.emit(enabled)


func fire_weapon(slot: int) -> void:
	"""Fire weapon from specified slot - Legacy/AI hook"""
	if slot == 0: # Primary
		weapon_system.set_trigger(true)
		# Auto-release for single shot logic if needed, but for now assume held
	elif slot == 1: # Secondary
		weapon_system.set_secondary_trigger(true)

func stop_firing_weapon(slot: int) -> void:
	if slot == 0:
		weapon_system.set_trigger(false)
	elif slot == 1:
		weapon_system.set_secondary_trigger(false)

func cycle_primary_weapon() -> void:
	weapon_system.cycle_primary()

func cycle_secondary_weapon() -> void:
	weapon_system.cycle_secondary()

func consume_weapon_energy(amount: float) -> bool:
	if weapon_energy >= amount:
		weapon_energy -= amount
		return true
	return false


# ==============================================================================
# QUERIES
# ==============================================================================


func get_hull_percent() -> float:
	if not stats or stats.hull_hitpoints <= 0:
		return 0.0
	return current_hull / stats.hull_hitpoints


func get_shield_percent(quadrant: int = -1) -> float:
	if not stats or stats.shield_strength <= 0:
		return 0.0

	var max_per_quadrant = stats.shield_strength / float(shield_quadrant_count)

	if quadrant >= 0 and quadrant < current_shields.size():
		return current_shields[quadrant] / max_per_quadrant

	# Return average
	var total = 0.0
	for shield in current_shields:
		total += shield
	return total / stats.shield_strength


func get_weapon_energy_percent() -> float:
	if not stats or stats.max_weapon_energy <= 0:
		return 0.0
	return weapon_energy / stats.max_weapon_energy


func get_afterburner_fuel_percent() -> float:
	if not stats or stats.max_afterburner_fuel <= 0:
		return 0.0
	return afterburner_fuel / stats.max_afterburner_fuel


func is_alive() -> bool:
	return not is_destroyed and current_hull > 0


func get_iff_name() -> String:
	if IFFManager:
		var iff = IFFManager.get_iff_by_index(team)
		if iff:
			return iff.iff_name
	return "Unknown"
