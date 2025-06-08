class_name CollisionDamageSystem
extends Node

## Collision damage system handling impact-based damage from debris, ramming, and environmental hazards
## Manages WCS-authentic collision mechanics with momentum transfer and realistic damage calculation (SHIP-009 AC7)

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Collision damage signals (SHIP-009 AC7)
signal collision_damage_applied(damage_amount: float, collision_object: Node, impact_velocity: Vector3)
signal ramming_damage_applied(ramming_ship: BaseShip, target_ship: BaseShip, damage_amount: float)
signal debris_impact_detected(debris_object: Node, impact_velocity: Vector3, damage_amount: float)
signal environmental_damage_applied(hazard_type: String, damage_amount: float)

# Ship integration
var ship: BaseShip
var damage_manager: Node
var physics_body: RigidBody3D

# Collision damage configuration (SHIP-009 AC7)
var collision_damage_enabled: bool = true
var ramming_damage_enabled: bool = true
var debris_damage_enabled: bool = true
var environmental_damage_enabled: bool = true

# Damage calculation parameters
var base_collision_damage_multiplier: float = 0.5  # Base damage per unit of momentum
var ramming_damage_multiplier: float = 1.5  # Extra damage for ship-to-ship ramming
var debris_damage_multiplier: float = 0.3  # Debris impact damage multiplier
var minimum_damage_velocity: float = 10.0  # Minimum velocity for damage
var maximum_damage_velocity: float = 200.0  # Velocity where damage caps out

# Collision immunity and cooldowns
var collision_cooldown_duration: float = 0.5  # Seconds between collision damage applications
var last_collision_time: Dictionary = {}  # Track collision times by object
var collision_immunity_objects: Array[Node] = []  # Objects immune to collision damage

# Ship mass and armor factors
var ship_mass_factor: float = 1.0
var ship_armor_factor: float = 1.0
var ship_structural_integrity: float = 1.0

# Environmental hazard definitions
var environmental_hazards: Dictionary = {
	"asteroid": {"damage_multiplier": 0.8, "penetration": 0.6},
	"explosion": {"damage_multiplier": 2.0, "penetration": 0.9},
	"energy_field": {"damage_multiplier": 0.4, "penetration": 0.3},
	"debris_field": {"damage_multiplier": 0.6, "penetration": 0.4}
}

func _ready() -> void:
	name = "CollisionDamageSystem"

## Initialize collision damage system for specific ship (SHIP-009 AC7)
func initialize_collision_system(parent_ship: BaseShip) -> bool:
	"""Initialize collision damage system for specific ship.
	
	Args:
		parent_ship: Ship to handle collision damage for
		
	Returns:
		true if initialization successful
	"""
	if not parent_ship:
		push_error("CollisionDamageSystem: Cannot initialize with null ship")
		return false
	
	ship = parent_ship
	damage_manager = ship.get_node_or_null("DamageManager")
	physics_body = ship.physics_body
	
	# Configure collision parameters based on ship properties
	_configure_collision_parameters()
	
	# Connect to physics collision signals
	_connect_collision_signals()
	
	return true

## Configure collision damage parameters based on ship properties (SHIP-009 AC7)
func _configure_collision_parameters() -> void:
	"""Configure collision damage parameters based on ship class and properties."""
	if not ship or not ship.ship_class:
		return
	
	# Set mass factor based on ship mass
	ship_mass_factor = ship.mass / 1000.0  # Base mass of 1000
	ship_mass_factor = clamp(ship_mass_factor, 0.1, 10.0)
	
	# Set armor factor based on ship armor (if available)
	if damage_manager and damage_manager.has_method("get_armor_effectiveness"):
		ship_armor_factor = damage_manager.get_armor_effectiveness()
	else:
		# Estimate based on ship type
		match ship.ship_class.ship_type:
			ShipTypes.Type.FIGHTER:
				ship_armor_factor = 0.7
			ShipTypes.Type.BOMBER:
				ship_armor_factor = 0.9
			ShipTypes.Type.CRUISER:
				ship_armor_factor = 1.3
			ShipTypes.Type.CAPITAL:
				ship_armor_factor = 2.0
			_:
				ship_armor_factor = 1.0
	
	# Set structural integrity based on current hull condition
	ship_structural_integrity = ship.current_hull_strength / ship.max_hull_strength

## Connect to physics collision signals
func _connect_collision_signals() -> void:
	"""Connect to physics body collision signals."""
	if not physics_body:
		return
	
	# Connect to collision signals
	physics_body.body_entered.connect(_on_collision_detected)
	
	# Connect to ship collision signal if available
	if ship.has_signal("collision_detected"):
		ship.collision_detected.connect(_on_ship_collision_detected)

# ============================================================================
# COLLISION DAMAGE PROCESSING API (SHIP-009 AC7)
# ============================================================================

## Process collision damage from physics collision (SHIP-009 AC7)
func process_collision_damage(collision_object: Node, collision_info: Dictionary) -> float:
	"""Process collision damage from physics collision event.
	
	Args:
		collision_object: Object that collided with ship
		collision_info: Collision information including velocity, position, etc.
		
	Returns:
		Amount of damage applied
	"""
	if not collision_damage_enabled:
		return 0.0
	
	# Check collision cooldown
	if not _check_collision_cooldown(collision_object):
		return 0.0
	
	# Get collision parameters
	var impact_velocity: Vector3 = collision_info.get("relative_velocity", Vector3.ZERO)
	var impact_position: Vector3 = collision_info.get("impact_position", ship.global_position)
	var impact_normal: Vector3 = collision_info.get("impact_normal", Vector3.UP)
	
	# Calculate collision damage based on object type
	var damage_amount: float = 0.0
	
	if collision_object is BaseShip:
		damage_amount = _calculate_ramming_damage(collision_object as BaseShip, impact_velocity, impact_position)
	elif _is_debris_object(collision_object):
		damage_amount = _calculate_debris_damage(collision_object, impact_velocity, impact_position)
	elif _is_environmental_hazard(collision_object):
		damage_amount = _calculate_environmental_damage(collision_object, impact_velocity, impact_position)
	else:
		damage_amount = _calculate_generic_collision_damage(collision_object, impact_velocity, impact_position)
	
	# Apply damage if significant
	if damage_amount > 1.0:
		_apply_collision_damage(damage_amount, impact_position, impact_velocity, collision_object)
	
	return damage_amount

## Calculate ramming damage between ships (SHIP-009 AC7)
func _calculate_ramming_damage(other_ship: BaseShip, impact_velocity: Vector3, impact_position: Vector3) -> float:
	"""Calculate damage from ship-to-ship ramming collision."""
	if not ramming_damage_enabled:
		return 0.0
	
	var velocity_magnitude: float = impact_velocity.length()
	
	# Check minimum velocity threshold
	if velocity_magnitude < minimum_damage_velocity:
		return 0.0
	
	# Calculate base momentum damage
	var ship_momentum: float = ship.mass * velocity_magnitude
	var other_momentum: float = other_ship.mass * velocity_magnitude
	var total_momentum: float = ship_momentum + other_momentum
	
	# Calculate damage based on momentum transfer
	var base_damage: float = total_momentum * ramming_damage_multiplier * base_collision_damage_multiplier
	
	# Apply velocity scaling (diminishing returns at high velocity)
	var velocity_factor: float = _calculate_velocity_damage_factor(velocity_magnitude)
	base_damage *= velocity_factor
	
	# Apply mass differential (heavier ships cause more damage)
	var mass_ratio: float = other_ship.mass / ship.mass
	var mass_factor: float = 0.5 + (mass_ratio * 0.5)  # 50% base + 50% from mass ratio
	base_damage *= mass_factor
	
	# Apply armor resistance
	var armor_factor: float = 1.0 / ship_armor_factor
	base_damage *= armor_factor
	
	# Apply angle of impact (head-on collisions cause more damage)
	var angle_factor: float = _calculate_impact_angle_factor(impact_velocity, impact_position)
	base_damage *= angle_factor
	
	# Apply structural integrity modifier (damaged ships take more collision damage)
	var integrity_factor: float = 2.0 - ship_structural_integrity  # 1.0 at full health, 2.0 at 0 health
	base_damage *= integrity_factor
	
	return base_damage

## Calculate debris impact damage (SHIP-009 AC7)
func _calculate_debris_damage(debris_object: Node, impact_velocity: Vector3, impact_position: Vector3) -> float:
	"""Calculate damage from debris impact."""
	if not debris_damage_enabled:
		return 0.0
	
	var velocity_magnitude: float = impact_velocity.length()
	
	# Check minimum velocity threshold
	if velocity_magnitude < minimum_damage_velocity * 0.5:  # Lower threshold for debris
		return 0.0
	
	# Get debris mass (estimate if not available)
	var debris_mass: float = 100.0  # Default debris mass
	if debris_object.has_method("get_mass"):
		debris_mass = debris_object.get_mass()
	elif debris_object is RigidBody3D:
		debris_mass = (debris_object as RigidBody3D).mass
	
	# Calculate debris momentum
	var debris_momentum: float = debris_mass * velocity_magnitude
	
	# Calculate base damage
	var base_damage: float = debris_momentum * debris_damage_multiplier * base_collision_damage_multiplier
	
	# Apply velocity scaling
	var velocity_factor: float = _calculate_velocity_damage_factor(velocity_magnitude)
	base_damage *= velocity_factor
	
	# Apply armor resistance (debris is less effective against armor)
	var armor_factor: float = 1.0 / (ship_armor_factor * 1.5)  # 50% more armor effectiveness
	base_damage *= armor_factor
	
	# Random factor for debris variability
	var randomness: float = randf_range(0.7, 1.3)
	base_damage *= randomness
	
	return base_damage

## Calculate environmental hazard damage (SHIP-009 AC7)
func _calculate_environmental_damage(hazard_object: Node, impact_velocity: Vector3, impact_position: Vector3) -> float:
	"""Calculate damage from environmental hazards."""
	if not environmental_damage_enabled:
		return 0.0
	
	# Determine hazard type
	var hazard_type: String = _determine_hazard_type(hazard_object)
	
	if not environmental_hazards.has(hazard_type):
		return _calculate_generic_collision_damage(hazard_object, impact_velocity, impact_position)
	
	var hazard_config: Dictionary = environmental_hazards[hazard_type]
	var velocity_magnitude: float = impact_velocity.length()
	
	# Base damage calculation
	var base_damage: float = velocity_magnitude * hazard_config.damage_multiplier * base_collision_damage_multiplier
	
	# Apply armor penetration
	var penetration: float = hazard_config.penetration
	var armor_effectiveness: float = ship_armor_factor * (1.0 - penetration)
	armor_effectiveness = max(0.1, armor_effectiveness)  # Minimum 10% armor effectiveness
	
	var armor_factor: float = 1.0 / armor_effectiveness
	base_damage *= armor_factor
	
	# Special handling for specific hazard types
	match hazard_type:
		"explosion":
			# Explosions ignore velocity and deal fixed damage based on proximity
			var explosion_damage: float = 50.0  # Base explosion damage
			base_damage = explosion_damage * hazard_config.damage_multiplier
		
		"energy_field":
			# Energy fields deal continuous low damage
			base_damage *= 0.1  # Per-frame damage, so reduce significantly
		
		"asteroid":
			# Asteroids deal damage based on size and velocity
			var size_factor: float = _estimate_object_size(hazard_object)
			base_damage *= size_factor
	
	return base_damage

## Calculate generic collision damage (SHIP-009 AC7)
func _calculate_generic_collision_damage(collision_object: Node, impact_velocity: Vector3, impact_position: Vector3) -> float:
	"""Calculate damage from generic collision object."""
	var velocity_magnitude: float = impact_velocity.length()
	
	# Check minimum velocity threshold
	if velocity_magnitude < minimum_damage_velocity:
		return 0.0
	
	# Estimate object mass
	var object_mass: float = _estimate_object_mass(collision_object)
	
	# Calculate momentum
	var momentum: float = object_mass * velocity_magnitude
	
	# Calculate base damage
	var base_damage: float = momentum * base_collision_damage_multiplier
	
	# Apply velocity scaling
	var velocity_factor: float = _calculate_velocity_damage_factor(velocity_magnitude)
	base_damage *= velocity_factor
	
	# Apply armor resistance
	var armor_factor: float = 1.0 / ship_armor_factor
	base_damage *= armor_factor
	
	return base_damage

## Calculate velocity damage factor with diminishing returns (SHIP-009 AC7)
func _calculate_velocity_damage_factor(velocity_magnitude: float) -> float:
	"""Calculate damage scaling factor based on velocity with diminishing returns."""
	# Normalize velocity to 0-1 range
	var normalized_velocity: float = clamp(velocity_magnitude / maximum_damage_velocity, 0.0, 1.0)
	
	# Apply square root scaling for diminishing returns
	var velocity_factor: float = sqrt(normalized_velocity)
	
	# Ensure minimum factor
	return max(0.1, velocity_factor)

## Calculate impact angle damage factor (SHIP-009 AC7)
func _calculate_impact_angle_factor(impact_velocity: Vector3, impact_position: Vector3) -> float:
	"""Calculate damage modifier based on impact angle."""
	if impact_velocity.length() < 0.1:
		return 1.0
	
	# Calculate ship forward direction
	var ship_forward: Vector3 = -ship.global_transform.basis.z
	
	# Calculate impact direction
	var impact_direction: Vector3 = impact_velocity.normalized()
	
	# Calculate angle between impact and ship forward (0 = head-on, 90 = side impact)
	var dot_product: float = impact_direction.dot(ship_forward)
	var impact_angle: float = acos(clamp(abs(dot_product), 0.0, 1.0))
	
	# Head-on impacts (0-30 degrees) cause more damage
	# Side impacts (60-90 degrees) cause less damage
	var angle_degrees: float = impact_angle * 180.0 / PI
	
	if angle_degrees <= 30.0:
		return 1.5  # 50% more damage for head-on
	elif angle_degrees <= 60.0:
		return 1.0  # Normal damage for angled impact
	else:
		return 0.7  # 30% less damage for side impact

# ============================================================================
# COLLISION OBJECT CLASSIFICATION (SHIP-009 AC7)
# ============================================================================

## Check if object is debris
func _is_debris_object(object: Node) -> bool:
	"""Check if collision object is debris."""
	if object.has_method("get_object_type"):
		return object.get_object_type() == ObjectTypes.Type.DEBRIS
	
	# Check by name or group
	if object.name.to_lower().contains("debris"):
		return true
	
	if object.is_in_group("debris"):
		return true
	
	return false

## Check if object is environmental hazard
func _is_environmental_hazard(object: Node) -> bool:
	"""Check if collision object is an environmental hazard."""
	var hazard_type: String = _determine_hazard_type(object)
	return environmental_hazards.has(hazard_type)

## Determine environmental hazard type
func _determine_hazard_type(object: Node) -> String:
	"""Determine the type of environmental hazard."""
	var object_name: String = object.name.to_lower()
	
	if object_name.contains("asteroid"):
		return "asteroid"
	elif object_name.contains("explosion"):
		return "explosion"
	elif object_name.contains("energy") or object_name.contains("field"):
		return "energy_field"
	elif object_name.contains("debris"):
		return "debris_field"
	
	# Check groups
	for hazard_type in environmental_hazards.keys():
		if object.is_in_group(hazard_type):
			return hazard_type
	
	return ""

## Estimate object mass for damage calculation
func _estimate_object_mass(object: Node) -> float:
	"""Estimate mass of collision object."""
	if object.has_method("get_mass"):
		return object.get_mass()
	
	if object is RigidBody3D:
		return (object as RigidBody3D).mass
	
	# Estimate based on object type and size
	var size_factor: float = _estimate_object_size(object)
	
	if _is_debris_object(object):
		return 50.0 * size_factor  # Debris mass range
	elif object is BaseShip:
		return 1000.0 * size_factor  # Ship mass range
	else:
		return 200.0 * size_factor  # Generic object mass

## Estimate object size factor
func _estimate_object_size(object: Node) -> float:
	"""Estimate relative size of object for damage scaling."""
	# Try to get bounds from collision shape or mesh
	if object is CollisionObject3D:
		var collision_object: CollisionObject3D = object as CollisionObject3D
		var shape: CollisionShape3D = collision_object.get_child(0) as CollisionShape3D
		
		if shape and shape.shape:
			if shape.shape is BoxShape3D:
				var box: BoxShape3D = shape.shape as BoxShape3D
				var volume: float = box.size.x * box.size.y * box.size.z
				return clamp(volume / 8.0, 0.1, 5.0)  # Normalize to reasonable range
			elif shape.shape is SphereShape3D:
				var sphere: SphereShape3D = shape.shape as SphereShape3D
				var volume: float = (4.0/3.0) * PI * pow(sphere.radius, 3)
				return clamp(volume / 4.0, 0.1, 5.0)
	
	# Fallback: estimate from node scale
	if object is Node3D:
		var node_3d: Node3D = object as Node3D
		var scale_factor: float = (node_3d.scale.x + node_3d.scale.y + node_3d.scale.z) / 3.0
		return clamp(scale_factor, 0.1, 5.0)
	
	return 1.0  # Default size factor

# ============================================================================
# COLLISION COOLDOWN AND IMMUNITY (SHIP-009 AC7)
# ============================================================================

## Check collision cooldown for object
func _check_collision_cooldown(collision_object: Node) -> bool:
	"""Check if collision damage can be applied (not on cooldown)."""
	var object_id: int = collision_object.get_instance_id()
	var current_time: float = Time.get_ticks_msec() * 0.001
	
	if last_collision_time.has(object_id):
		var last_time: float = last_collision_time[object_id]
		if current_time - last_time < collision_cooldown_duration:
			return false
	
	# Update collision time
	last_collision_time[object_id] = current_time
	return true

## Add object to collision immunity list
func add_collision_immunity(object: Node, duration: float = 5.0) -> void:
	"""Add object to collision immunity list temporarily."""
	if object in collision_immunity_objects:
		return
	
	collision_immunity_objects.append(object)
	
	# Remove immunity after duration
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): _remove_collision_immunity(object))
	add_child(timer)
	timer.start()

## Remove object from collision immunity list
func _remove_collision_immunity(object: Node) -> void:
	"""Remove object from collision immunity list."""
	if object in collision_immunity_objects:
		collision_immunity_objects.erase(object)

## Check if object is immune to collision damage
func _is_collision_immune(object: Node) -> bool:
	"""Check if object is immune to collision damage."""
	return object in collision_immunity_objects

# ============================================================================
# DAMAGE APPLICATION (SHIP-009 AC7)
# ============================================================================

## Apply collision damage to ship (SHIP-009 AC7)
func _apply_collision_damage(damage_amount: float, impact_position: Vector3, impact_velocity: Vector3, collision_object: Node) -> void:
	"""Apply calculated collision damage to ship."""
	if damage_amount <= 0.0:
		return
	
	# Check collision immunity
	if _is_collision_immune(collision_object):
		return
	
	# Apply damage through damage manager
	if damage_manager:
		damage_manager.apply_hull_damage(damage_amount, impact_position, DamageTypes.Type.KINETIC, "collision")
	else:
		# Fallback: apply damage directly to ship
		ship.apply_hull_damage(damage_amount)
	
	# Emit collision damage signal
	collision_damage_applied.emit(damage_amount, collision_object, impact_velocity)
	
	# Emit specific signals based on collision type
	if collision_object is BaseShip:
		ramming_damage_applied.emit(ship, collision_object as BaseShip, damage_amount)
	elif _is_debris_object(collision_object):
		debris_impact_detected.emit(collision_object, impact_velocity, damage_amount)
	elif _is_environmental_hazard(collision_object):
		var hazard_type: String = _determine_hazard_type(collision_object)
		environmental_damage_applied.emit(hazard_type, damage_amount)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Handle physics body collision detection
func _on_collision_detected(other_body: Node) -> void:
	"""Handle collision detected from physics body."""
	if not other_body or not collision_damage_enabled:
		return
	
	# Get collision information from physics
	var collision_info: Dictionary = _get_collision_info(other_body)
	
	# Process collision damage
	process_collision_damage(other_body, collision_info)

## Handle ship collision detected signal
func _on_ship_collision_detected(other_object: Node, collision_info: Dictionary) -> void:
	"""Handle collision detected from ship collision signal."""
	if not other_object or not collision_damage_enabled:
		return
	
	# Process collision damage
	process_collision_damage(other_object, collision_info)

## Get collision information from physics system
func _get_collision_info(other_body: Node) -> Dictionary:
	"""Get collision information from physics system."""
	var collision_info: Dictionary = {}
	
	# Get relative velocity
	if other_body is RigidBody3D and physics_body:
		var other_physics: RigidBody3D = other_body as RigidBody3D
		collision_info["relative_velocity"] = physics_body.linear_velocity - other_physics.linear_velocity
	else:
		collision_info["relative_velocity"] = physics_body.linear_velocity if physics_body else Vector3.ZERO
	
	# Estimate impact position (center point between objects)
	if other_body is Node3D:
		var other_node: Node3D = other_body as Node3D
		collision_info["impact_position"] = (ship.global_position + other_node.global_position) * 0.5
	else:
		collision_info["impact_position"] = ship.global_position
	
	# Default impact normal (towards ship)
	collision_info["impact_normal"] = Vector3.UP
	
	return collision_info

# ============================================================================
# CONFIGURATION AND CONTROL
# ============================================================================

## Enable/disable collision damage
func set_collision_damage_enabled(enabled: bool) -> void:
	"""Enable or disable collision damage processing."""
	collision_damage_enabled = enabled

## Enable/disable ramming damage
func set_ramming_damage_enabled(enabled: bool) -> void:
	"""Enable or disable ship-to-ship ramming damage."""
	ramming_damage_enabled = enabled

## Enable/disable debris damage
func set_debris_damage_enabled(enabled: bool) -> void:
	"""Enable or disable debris impact damage."""
	debris_damage_enabled = enabled

## Enable/disable environmental damage
func set_environmental_damage_enabled(enabled: bool) -> void:
	"""Enable or disable environmental hazard damage."""
	environmental_damage_enabled = enabled

## Set collision damage multiplier
func set_collision_damage_multiplier(multiplier: float) -> void:
	"""Set global collision damage multiplier."""
	base_collision_damage_multiplier = max(0.0, multiplier)

## Set minimum damage velocity
func set_minimum_damage_velocity(velocity: float) -> void:
	"""Set minimum velocity required for collision damage."""
	minimum_damage_velocity = max(0.0, velocity)

# ============================================================================
# SAVE/LOAD AND PERSISTENCE (SHIP-009 AC6)
# ============================================================================

## Get collision save data for persistence
func get_collision_save_data() -> Dictionary:
	"""Get collision damage system save data for persistence."""
	return {
		"collision_damage_enabled": collision_damage_enabled,
		"ramming_damage_enabled": ramming_damage_enabled,
		"debris_damage_enabled": debris_damage_enabled,
		"environmental_damage_enabled": environmental_damage_enabled,
		"base_collision_damage_multiplier": base_collision_damage_multiplier,
		"minimum_damage_velocity": minimum_damage_velocity,
		"maximum_damage_velocity": maximum_damage_velocity,
		"collision_cooldown_duration": collision_cooldown_duration,
		"ship_mass_factor": ship_mass_factor,
		"ship_armor_factor": ship_armor_factor,
		"ship_structural_integrity": ship_structural_integrity
	}

## Load collision save data from persistence
func load_collision_save_data(save_data: Dictionary) -> bool:
	"""Load collision damage system save data from persistence."""
	if not save_data:
		return false
	
	# Load configuration
	collision_damage_enabled = save_data.get("collision_damage_enabled", collision_damage_enabled)
	ramming_damage_enabled = save_data.get("ramming_damage_enabled", ramming_damage_enabled)
	debris_damage_enabled = save_data.get("debris_damage_enabled", debris_damage_enabled)
	environmental_damage_enabled = save_data.get("environmental_damage_enabled", environmental_damage_enabled)
	base_collision_damage_multiplier = save_data.get("base_collision_damage_multiplier", base_collision_damage_multiplier)
	minimum_damage_velocity = save_data.get("minimum_damage_velocity", minimum_damage_velocity)
	maximum_damage_velocity = save_data.get("maximum_damage_velocity", maximum_damage_velocity)
	collision_cooldown_duration = save_data.get("collision_cooldown_duration", collision_cooldown_duration)
	ship_mass_factor = save_data.get("ship_mass_factor", ship_mass_factor)
	ship_armor_factor = save_data.get("ship_armor_factor", ship_armor_factor)
	ship_structural_integrity = save_data.get("ship_structural_integrity", ship_structural_integrity)
	
	return true

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Get collision damage status information
func get_collision_status() -> Dictionary:
	"""Get comprehensive collision damage status for debugging."""
	return {
		"collision_damage_enabled": collision_damage_enabled,
		"ramming_damage_enabled": ramming_damage_enabled,
		"debris_damage_enabled": debris_damage_enabled,
		"environmental_damage_enabled": environmental_damage_enabled,
		"base_damage_multiplier": base_collision_damage_multiplier,
		"minimum_damage_velocity": minimum_damage_velocity,
		"ship_mass_factor": ship_mass_factor,
		"ship_armor_factor": ship_armor_factor,
		"ship_structural_integrity": ship_structural_integrity,
		"collision_immunity_objects": collision_immunity_objects.size(),
		"collision_cooldowns_active": last_collision_time.size()
	}

## Get debug information string
func debug_info() -> String:
	"""Get debug information string."""
	return "[Collision Enabled:%s Multiplier:%.1f MinVel:%.1f Immune:%d]" % [
		"Y" if collision_damage_enabled else "N",
		base_collision_damage_multiplier,
		minimum_damage_velocity,
		collision_immunity_objects.size()
	]