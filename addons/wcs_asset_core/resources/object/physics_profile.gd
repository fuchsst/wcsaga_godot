class_name PhysicsProfile
extends Resource

## WCS Physics Profile Resource
## Defines physics behavior patterns and properties for different object types
## Based on WCS physics system analysis and Godot RigidBody3D integration

## Physics integration mode with Godot
enum PhysicsMode {
	GODOT_RIGIDBODY = 0,    # Use Godot's RigidBody3D physics
	CUSTOM_PHYSICS = 1,     # Use custom WCS-style physics implementation
	HYBRID = 2,             # Combine Godot physics with WCS behavior
	KINEMATIC = 3,          # Use CharacterBody3D for precise control
	STATIC = 4              # Static physics body (no movement)
}

## Movement behavior types from WCS
enum MovementType {
	STANDARD = 0,           # Standard Newtonian physics
	AFTERBURNER = 1,        # Enhanced acceleration with afterburner
	GLIDING = 2,            # Reduced control, momentum-based
	BANKING = 3,            # Banking turns like atmospheric flight
	DESCENT_STYLE = 4,      # Descent-style 6DOF movement
	CAPITAL_SHIP = 5,       # Slow, massive ship movement
	WEAPON_PROJECTILE = 6,  # Fast, straight-line projectile
	MISSILE_HOMING = 7,     # Homing missile behavior
	BEAM_INSTANT = 8        # Instant beam weapon (no physics)
}

## Core physics properties
@export_group("Basic Physics")
@export var physics_mode: PhysicsMode = PhysicsMode.GODOT_RIGIDBODY
@export var movement_type: MovementType = MovementType.STANDARD
@export var use_gravity: bool = false
@export var gravity_scale: float = 0.0
@export var mass: float = 1.0
@export var center_of_mass: Vector3 = Vector3.ZERO

## Damping and resistance
@export_group("Damping")
@export var linear_damping: float = 0.1
@export var angular_damping: float = 0.1
@export var reduced_damping_factor: float = 0.5      # When PF_REDUCED_DAMP is active
@export var dead_damping_factor: float = 3.0         # When object is destroyed
@export var atmospheric_drag: float = 0.0            # Atmospheric effects

## Movement and acceleration
@export_group("Movement")
@export var max_velocity: float = 100.0
@export var max_angular_velocity: float = 5.0
@export var acceleration: float = 50.0
@export var angular_acceleration: float = 2.0
@export var afterburner_acceleration_multiplier: float = 2.0
@export var reverse_acceleration_factor: float = 0.5
@export var slide_factor: float = 0.8                # Descent-style sliding

## Collision properties
@export_group("Collision")
@export var collision_layer: int = 1
@export var collision_mask: int = 1
@export var collision_shape_complexity: int = 1      # From CollisionLayers.ShapeComplexity
@export var collision_radius: float = 1.0            # For sphere/capsule collision
@export var collision_height: float = 1.0            # For capsule collision
@export var collision_extents: Vector3 = Vector3.ONE # For box collision

## Shield physics (if applicable)
@export_group("Shields")
@export var has_shields: bool = false
@export var shield_sections: int = 4                 # WCS MAX_SHIELD_SECTIONS
@export var shield_collision_tolerance: float = 0.1
@export var shield_physics_mode: PhysicsMode = PhysicsMode.KINEMATIC

## Special physics flags from WCS
@export_group("Special Physics")
@export var can_accelerate: bool = true              # PF_ACCELERATES
@export var use_existing_velocity: bool = false     # PF_USE_VEL  
@export var afterburner_enabled: bool = false       # PF_AFTERBURNER_ON
@export var slide_enabled: bool = false             # PF_SLIDE_ENABLED
@export var gliding_enabled: bool = false           # PF_GLIDING
@export var constant_velocity: bool = false         # PF_CONST_VEL
@export var booster_enabled: bool = false           # PF_BOOSTER_ON

## Weapon-specific physics
@export_group("Weapon Physics")
@export var is_projectile: bool = false
@export var projectile_lifetime: float = 10.0       # Weapon lifetime in seconds
@export var projectile_speed: float = 300.0         # Initial projectile velocity
@export var homing_enabled: bool = false            # For homing missiles
@export var homing_turn_rate: float = 2.0           # Homing agility
@export var beam_weapon: bool = false               # Instant beam collision

## Performance and LOD
@export_group("Performance")
@export var update_frequency: int = 0               # From UpdateFrequencies.Frequency
@export var physics_lod_enabled: bool = true       # Use physics LOD system
@export var distance_scaling: bool = true          # Scale physics precision with distance
@export var sleep_threshold: float = 0.1           # Physics sleep velocity threshold

## Effect and particle physics
@export_group("Effects")
@export var particle_physics: bool = false         # Use particle physics
@export var debris_physics: bool = false           # Debris tumbling behavior
@export var explosion_physics: bool = false        # Explosion shockwave behavior
@export var trail_physics: bool = false            # Trail and contrail physics

## Advanced physics properties
@export_group("Advanced")
@export var moment_of_inertia: Vector3 = Vector3.ONE    # Rotational inertia
@export var newtonian_physics: bool = true              # Proper momentum conservation
@export var relativistic_effects: bool = false         # High-speed corrections
@export var magnetic_susceptibility: float = 0.0       # Magnetic field effects
@export var warp_physics: bool = false                  # Warp-in/warp-out effects

## Custom physics parameters
@export_group("Custom Parameters")
@export var custom_parameters: Dictionary = {}          # Additional custom physics data

## Static factory methods for common physics profiles

static func create_fighter_profile():
	"""Create a physics profile optimized for fighter craft.
	
	Returns:
		PhysicsProfile configured for fighter ships
	"""
	var profile = load("res://addons/wcs_asset_core/resources/object/physics_profile.gd").new()
	
	profile.physics_mode = PhysicsMode.HYBRID
	profile.movement_type = MovementType.STANDARD
	profile.mass = 15.0
	profile.linear_damping = 0.2
	profile.angular_damping = 0.3
	profile.max_velocity = 120.0
	profile.max_angular_velocity = 4.0
	profile.acceleration = 60.0
	profile.angular_acceleration = 3.0
	profile.afterburner_enabled = true
	profile.afterburner_acceleration_multiplier = 2.5
	profile.slide_enabled = true
	profile.has_shields = true
	profile.collision_shape_complexity = 4  # Hull complexity
	
	return profile

static func create_capital_profile():
	"""Create a physics profile optimized for capital ships.
	
	Returns:
		PhysicsProfile configured for capital ships
	"""
	var profile = load("res://addons/wcs_asset_core/resources/object/physics_profile.gd").new()
	
	profile.physics_mode = PhysicsMode.GODOT_RIGIDBODY
	profile.movement_type = MovementType.CAPITAL_SHIP
	profile.mass = 5000.0
	profile.linear_damping = 0.5
	profile.angular_damping = 0.8
	profile.max_velocity = 30.0
	profile.max_angular_velocity = 0.5
	profile.acceleration = 10.0
	profile.angular_acceleration = 0.3
	profile.afterburner_enabled = false
	profile.slide_enabled = false
	profile.has_shields = true
	profile.shield_sections = 4
	profile.collision_shape_complexity = 5  # Mesh complexity
	
	return profile

static func create_weapon_projectile_profile():
	"""Create a physics profile for weapon projectiles.
	
	Returns:
		PhysicsProfile configured for projectile weapons
	"""
	var profile = load("res://addons/wcs_asset_core/resources/object/physics_profile.gd").new()
	
	profile.physics_mode = PhysicsMode.KINEMATIC
	profile.movement_type = MovementType.WEAPON_PROJECTILE
	profile.mass = 0.1
	profile.linear_damping = 0.0
	profile.angular_damping = 0.0
	profile.max_velocity = 500.0
	profile.acceleration = 0.0  # Projectiles don't accelerate
	profile.constant_velocity = true
	profile.is_projectile = true
	profile.projectile_lifetime = 8.0
	profile.projectile_speed = 500.0
	profile.collision_shape_complexity = 2  # Capsule
	profile.physics_lod_enabled = true
	
	return profile

static func create_missile_profile():
	"""Create a physics profile for homing missiles.
	
	Returns:
		PhysicsProfile configured for homing missiles
	"""
	var profile = load("res://addons/wcs_asset_core/resources/object/physics_profile.gd").new()
	
	profile.physics_mode = PhysicsMode.HYBRID
	profile.movement_type = MovementType.MISSILE_HOMING
	profile.mass = 2.0
	profile.linear_damping = 0.05
	profile.angular_damping = 0.1
	profile.max_velocity = 200.0
	profile.max_angular_velocity = 3.0
	profile.acceleration = 80.0
	profile.angular_acceleration = 4.0
	profile.is_projectile = true
	profile.projectile_lifetime = 15.0
	profile.homing_enabled = true
	profile.homing_turn_rate = 3.0
	profile.collision_shape_complexity = 2  # Capsule
	
	return profile

static func create_debris_profile():
	"""Create a physics profile for debris objects.
	
	Returns:
		PhysicsProfile configured for space debris
	"""
	var profile = load("res://addons/wcs_asset_core/resources/object/physics_profile.gd").new()
	
	profile.physics_mode = PhysicsMode.GODOT_RIGIDBODY
	profile.movement_type = MovementType.STANDARD
	profile.mass = 5.0
	profile.linear_damping = 0.05
	profile.angular_damping = 0.1
	profile.max_velocity = 50.0
	profile.max_angular_velocity = 2.0
	profile.debris_physics = true
	profile.collision_shape_complexity = 3  # Box
	profile.physics_lod_enabled = true
	profile.sleep_threshold = 0.5
	
	return profile

static func create_beam_weapon_profile():
	"""Create a physics profile for beam weapons.
	
	Returns:
		PhysicsProfile configured for beam weapons
	"""
	var profile = load("res://addons/wcs_asset_core/resources/object/physics_profile.gd").new()
	
	profile.physics_mode = PhysicsMode.STATIC
	profile.movement_type = MovementType.BEAM_INSTANT
	profile.mass = 0.0
	profile.beam_weapon = true
	profile.collision_shape_complexity = 0  # Point collision
	profile.physics_lod_enabled = false  # Beams are always high priority
	
	return profile

static func create_effect_profile():
	"""Create a physics profile for visual effects.
	
	Returns:
		PhysicsProfile configured for effects and particles
	"""
	var profile = load("res://addons/wcs_asset_core/resources/object/physics_profile.gd").new()
	
	profile.physics_mode = PhysicsMode.KINEMATIC
	profile.movement_type = MovementType.STANDARD
	profile.mass = 0.1
	profile.linear_damping = 0.1
	profile.particle_physics = true
	profile.collision_shape_complexity = 0  # Point collision
	profile.physics_lod_enabled = true
	
	return profile

## Utility methods

func get_godot_rigidbody_mode() -> RigidBody3D.FreezeMode:
	"""Get appropriate Godot RigidBody3D mode for this profile.
	Note: Returns FreezeMode as BodyType is not available in current Godot version.
	
	Returns:
		RigidBody3D.FreezeMode enum value
	"""
	match physics_mode:
		PhysicsMode.STATIC:
			return RigidBody3D.FREEZE_MODE_KINEMATIC
		PhysicsMode.KINEMATIC:
			return RigidBody3D.FREEZE_MODE_KINEMATIC
		_:
			return RigidBody3D.FREEZE_MODE_KINEMATIC

func should_use_custom_physics() -> bool:
	"""Check if this profile requires custom physics implementation.
	
	Returns:
		true if custom physics should be used
	"""
	return physics_mode == PhysicsMode.CUSTOM_PHYSICS or physics_mode == PhysicsMode.HYBRID

func get_effective_damping() -> Vector2:
	"""Get effective linear and angular damping based on current state.
	
	Returns:
		Vector2 with x=linear_damping, y=angular_damping
	"""
	var effective_linear: float = linear_damping
	var effective_angular: float = angular_damping
	
	# Apply special damping modifiers (these would be set by the object manager)
	if custom_parameters.has("reduced_damping") and custom_parameters["reduced_damping"]:
		effective_linear *= reduced_damping_factor
		effective_angular *= reduced_damping_factor
	
	if custom_parameters.has("dead_damping") and custom_parameters["dead_damping"]:
		effective_linear *= dead_damping_factor
		effective_angular *= dead_damping_factor
	
	return Vector2(effective_linear, effective_angular)

func get_effective_acceleration() -> float:
	"""Get effective acceleration based on current state.
	
	Returns:
		Current effective acceleration value
	"""
	var effective_accel: float = acceleration
	
	if afterburner_enabled and custom_parameters.get("afterburner_active", false):
		effective_accel *= afterburner_acceleration_multiplier
	
	if custom_parameters.get("reverse_thrust", false):
		effective_accel *= reverse_acceleration_factor
	
	return effective_accel

func is_physics_enabled() -> bool:
	"""Check if physics simulation is enabled for this profile.
	
	Returns:
		true if physics is enabled
	"""
	return physics_mode != PhysicsMode.STATIC and not beam_weapon

func requires_collision_detection() -> bool:
	"""Check if this profile requires collision detection.
	
	Returns:
		true if collision detection is needed
	"""
	return collision_shape_complexity > 0 and not beam_weapon

func get_collision_shape_name() -> String:
	"""Get human-readable name for the collision shape complexity.
	
	Returns:
		String describing the collision shape
	"""
	const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
	return CollisionLayers.get_shape_complexity_name(collision_shape_complexity)

func copy_from(other: PhysicsProfile) -> void:
	"""Copy all properties from another physics profile.
	
	Args:
		other: PhysicsProfile to copy from
	"""
	if not other:
		return
	
	physics_mode = other.physics_mode
	movement_type = other.movement_type
	use_gravity = other.use_gravity
	gravity_scale = other.gravity_scale
	mass = other.mass
	center_of_mass = other.center_of_mass
	linear_damping = other.linear_damping
	angular_damping = other.angular_damping
	max_velocity = other.max_velocity
	max_angular_velocity = other.max_angular_velocity
	acceleration = other.acceleration
	angular_acceleration = other.angular_acceleration
	collision_layer = other.collision_layer
	collision_mask = other.collision_mask
	collision_shape_complexity = other.collision_shape_complexity
	has_shields = other.has_shields
	is_projectile = other.is_projectile
	projectile_lifetime = other.projectile_lifetime
	homing_enabled = other.homing_enabled
	beam_weapon = other.beam_weapon
	
	# Copy custom parameters
	custom_parameters = other.custom_parameters.duplicate()

func validate() -> bool:
	"""Validate that the physics profile has consistent values.
	
	Returns:
		true if profile is valid
	"""
	if mass < 0.0:
		return false
	
	if linear_damping < 0.0 or angular_damping < 0.0:
		return false
	
	if max_velocity <= 0.0 or max_angular_velocity <= 0.0:
		return false
	
	if is_projectile and projectile_lifetime <= 0.0:
		return false
	
	if homing_enabled and homing_turn_rate <= 0.0:
		return false
	
	return true

func get_description() -> String:
	"""Get a human-readable description of this physics profile.
	
	Returns:
		String description of the profile configuration
	"""
	var desc: String = "Physics Profile:\n"
	desc += "  Mode: %s\n" % PhysicsMode.keys()[physics_mode]
	desc += "  Type: %s\n" % MovementType.keys()[movement_type]
	desc += "  Mass: %.1f\n" % mass
	desc += "  Max Velocity: %.1f\n" % max_velocity
	desc += "  Acceleration: %.1f\n" % acceleration
	
	if afterburner_enabled:
		desc += "  Afterburner: %.1fx\n" % afterburner_acceleration_multiplier
	
	if has_shields:
		desc += "  Shields: %d sections\n" % shield_sections
	
	if is_projectile:
		desc += "  Projectile: %.1fs lifetime\n" % projectile_lifetime
	
	if homing_enabled:
		desc += "  Homing: %.1f turn rate\n" % homing_turn_rate
	
	return desc