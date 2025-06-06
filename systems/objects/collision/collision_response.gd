class_name CollisionResponse
extends Node

## Collision response and physics impulse system for WCS-Godot conversion.
## Handles collision reactions, damage application, physics impulses, and effect triggering
## based on WCS collision response mechanics for realistic space combat physics.
##
## Key Features:
## - Physics impulse calculation and application for realistic collision responses
## - Damage application to shields, hull, and subsystems based on WCS mechanics
## - Effect and audio triggering for visual and auditory collision feedback
## - Special collision handling for different object type combinations
## - Performance optimization to handle multiple simultaneous collisions

signal collision_damage_applied(target: Node3D, damage: float, damage_type: String)
signal collision_effect_triggered(position: Vector3, normal: Vector3, effect_type: String, intensity: float)
signal collision_physics_applied(object: Node3D, impulse: Vector3, angular_impulse: Vector3)
signal shield_quadrant_hit(ship: Node3D, quadrant: int, damage: float)
signal subsystem_damaged(ship: Node3D, subsystem: String, damage: float)

# Core collision system components
const DamageCalculator = preload("res://systems/objects/collision/damage_calculator.gd")
const CollisionDetector = preload("res://systems/objects/collision/collision_detector.gd")

# EPIC-001 Foundation classes
const WCSObject = preload("res://scripts/core/wcs_object.gd")
const CustomPhysicsBody = preload("res://scripts/core/custom_physics_body.gd")

# EPIC-002 Asset Core Integration - MANDATORY
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Configuration parameters (WCS-based values)
@export var collision_response_enabled: bool = true
@export var physics_impulse_scale: float = 1.0  # Scale factor for physics forces
@export var damage_application_enabled: bool = true
@export var effect_triggering_enabled: bool = true
@export var max_impulse_magnitude: float = 10000.0  # Maximum physics impulse
@export var restitution_coefficient: float = 0.3  # Collision bounce factor
@export var friction_coefficient: float = 0.7  # Collision friction

# Response timing configuration (WCS collision timing)
@export var response_delay_ms: int = 0  # Immediate response
@export var effect_delay_ms: int = 16   # 1-frame delay for effects (60 FPS)
@export var damage_delay_ms: int = 0    # Immediate damage application

# Performance tracking
var responses_processed_this_frame: int = 0
var max_responses_per_frame: int = 20  # Performance limit

# Component references
var damage_calculator: DamageCalculator
var collision_detector: CollisionDetector

# Effect integration (will be enhanced for EPIC-008)
var graphics_manager: Node = null  # EPIC-008 integration point
var audio_manager: Node = null     # Audio system integration

func _ready() -> void:
	_initialize_collision_response()
	_setup_component_references()
	_connect_collision_signals()

## Initialize the collision response system.
func _initialize_collision_response() -> void:
	# Create damage calculator
	damage_calculator = DamageCalculator.new()
	
	# Set up performance tracking
	responses_processed_this_frame = 0
	
	# Try to connect to graphics and audio managers (EPIC-008 integration)
	_setup_effect_managers()

## Set up references to required components.
func _setup_component_references() -> void:
	# Get collision detector from parent or scene
	collision_detector = get_parent() as CollisionDetector
	if not collision_detector:
		collision_detector = get_tree().get_first_node_in_group("collision_detector")
	
	if not collision_detector:
		push_warning("CollisionResponse: No CollisionDetector found - some features may not work")

## Connect to collision detection signals.
func _connect_collision_signals() -> void:
	if collision_detector:
		collision_detector.collision_pair_detected.connect(_on_collision_pair_detected)

## Set up graphics and audio managers for effect integration.
func _setup_effect_managers() -> void:
	# EPIC-008 Graphics Manager integration
	graphics_manager = get_tree().get_first_node_in_group("graphics_manager")
	if not graphics_manager:
		graphics_manager = get_node_or_null("/root/GraphicsManager")
	
	# Audio Manager integration
	audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if not audio_manager:
		audio_manager = get_node_or_null("/root/AudioManager")

## Handle collision pair detection and trigger response.
func _on_collision_pair_detected(object_a: Node3D, object_b: Node3D, collision_info: Dictionary) -> void:
	if not collision_response_enabled:
		return
	
	# Performance limit check
	if responses_processed_this_frame >= max_responses_per_frame:
		push_warning("CollisionResponse: Max responses per frame reached, deferring collision")
		call_deferred("_process_collision_response", object_a, object_b, collision_info)
		return
	
	_process_collision_response(object_a, object_b, collision_info)
	responses_processed_this_frame += 1

## Process complete collision response including damage, physics, and effects.
func _process_collision_response(object_a: Node3D, object_b: Node3D, collision_info: Dictionary) -> void:
	# Validate collision objects
	if not _validate_collision_response(object_a, object_b, collision_info):
		return
	
	# Calculate collision damage
	var damage_info: Dictionary = damage_calculator.calculate_collision_damage(object_a, object_b, collision_info)
	
	# Apply physics response
	if physics_impulse_scale > 0.0:
		_apply_physics_response(object_a, object_b, collision_info, damage_info)
	
	# Apply damage to objects
	if damage_application_enabled:
		_apply_collision_damage(object_a, object_b, damage_info)
	
	# Trigger visual and audio effects
	if effect_triggering_enabled:
		_trigger_collision_effects(collision_info, damage_info)

## Apply physics impulses for realistic collision response.
## Based on WCS ship_apply_whack and collision physics
func _apply_physics_response(object_a: Node3D, object_b: Node3D, collision_info: Dictionary, damage_info: Dictionary) -> void:
	var collision_point: Vector3 = collision_info.get("position", Vector3.ZERO)
	var collision_normal: Vector3 = collision_info.get("normal", Vector3.UP)
	
	# Calculate collision impulse based on momentum conservation
	var impulse_a: Vector3 = _calculate_collision_impulse(object_a, object_b, collision_normal, true)
	var impulse_b: Vector3 = _calculate_collision_impulse(object_b, object_a, collision_normal, false)
	
	# Apply linear impulses
	_apply_linear_impulse(object_a, impulse_a)
	_apply_linear_impulse(object_b, impulse_b)
	
	# Calculate and apply angular impulses (torque from collision)
	var angular_impulse_a: Vector3 = _calculate_angular_impulse(object_a, collision_point, impulse_a)
	var angular_impulse_b: Vector3 = _calculate_angular_impulse(object_b, collision_point, impulse_b)
	
	_apply_angular_impulse(object_a, angular_impulse_a)
	_apply_angular_impulse(object_b, angular_impulse_b)
	
	# Emit physics application signals
	collision_physics_applied.emit(object_a, impulse_a, angular_impulse_a)
	collision_physics_applied.emit(object_b, impulse_b, angular_impulse_b)

## Calculate collision impulse for an object.
func _calculate_collision_impulse(target_obj: Node3D, other_obj: Node3D, collision_normal: Vector3, is_primary: bool) -> Vector3:
	# Get object velocities
	var target_velocity: Vector3 = _get_object_velocity(target_obj)
	var other_velocity: Vector3 = _get_object_velocity(other_obj)
	var relative_velocity: Vector3 = target_velocity - other_velocity
	
	# Get object masses
	var target_mass: float = _get_object_mass(target_obj)
	var other_mass: float = _get_object_mass(other_obj)
	
	# Calculate collision impulse using coefficient of restitution
	var velocity_along_normal: float = relative_velocity.dot(collision_normal)
	
	# Objects separating - no collision response needed
	if velocity_along_normal > 0:
		return Vector3.ZERO
	
	# Calculate impulse magnitude
	var impulse_magnitude: float = -(1.0 + restitution_coefficient) * velocity_along_normal
	impulse_magnitude /= (1.0 / target_mass + 1.0 / other_mass)
	
	# Scale by physics impulse setting
	impulse_magnitude *= physics_impulse_scale
	
	# Apply direction (primary object gets positive impulse)
	var impulse_direction: Vector3 = collision_normal if is_primary else -collision_normal
	var impulse: Vector3 = impulse_direction * impulse_magnitude
	
	# Clamp to maximum impulse
	if impulse.length() > max_impulse_magnitude:
		impulse = impulse.normalized() * max_impulse_magnitude
	
	return impulse

## Calculate angular impulse (torque) from collision.
func _calculate_angular_impulse(obj: Node3D, collision_point: Vector3, linear_impulse: Vector3) -> Vector3:
	# Vector from object center to collision point
	var radius_vector: Vector3 = collision_point - obj.global_position
	
	# Calculate torque: τ = r × F
	var angular_impulse: Vector3 = radius_vector.cross(linear_impulse)
	
	# Scale down angular impulse to prevent excessive spinning
	angular_impulse *= 0.5
	
	return angular_impulse

## Apply linear impulse to an object.
func _apply_linear_impulse(obj: Node3D, impulse: Vector3) -> void:
	if impulse.length() < 0.001:  # Skip negligible impulses
		return
	
	if obj is RigidBody3D:
		var rigid_body = obj as RigidBody3D
		rigid_body.apply_central_impulse(impulse)
	elif obj.has_method("apply_impulse"):
		obj.apply_impulse(impulse)
	elif obj.has_method("add_velocity"):
		# Convert impulse to velocity change
		var mass: float = _get_object_mass(obj)
		var velocity_change: Vector3 = impulse / mass
		obj.add_velocity(velocity_change)

## Apply angular impulse to an object.
func _apply_angular_impulse(obj: Node3D, angular_impulse: Vector3) -> void:
	if angular_impulse.length() < 0.001:  # Skip negligible impulses
		return
	
	if obj is RigidBody3D:
		var rigid_body = obj as RigidBody3D
		rigid_body.apply_torque_impulse(angular_impulse)
	elif obj.has_method("apply_torque_impulse"):
		obj.apply_torque_impulse(angular_impulse)
	elif obj.has_method("add_angular_velocity"):
		# Convert impulse to angular velocity change (simplified)
		var angular_velocity_change: Vector3 = angular_impulse * 0.01  # Simplified inertia calculation
		obj.add_angular_velocity(angular_velocity_change)

## Apply collision damage to objects based on calculated damage.
## Based on WCS ship_apply_local_damage and weapon hit systems
func _apply_collision_damage(object_a: Node3D, object_b: Node3D, damage_info: Dictionary) -> void:
	var damage_type: String = damage_info.get("damage_type", "collision")
	
	match damage_type:
		"weapon":
			_apply_weapon_damage(object_a, object_b, damage_info)
		"collision":
			_apply_mutual_collision_damage(object_a, object_b, damage_info)
		"asteroid_collision":
			_apply_asteroid_collision_damage(object_a, object_b, damage_info)
		_:
			_apply_generic_damage(object_a, object_b, damage_info)

## Apply weapon damage to target ship.
func _apply_weapon_damage(weapon_obj: Node3D, ship_obj: Node3D, damage_info: Dictionary) -> void:
	var shield_damage: float = damage_info.get("shield_damage", 0.0)
	var hull_damage: float = damage_info.get("hull_damage", 0.0)
	var subsystem_damage: float = damage_info.get("subsystem_damage", 0.0)
	var quadrant: int = damage_info.get("quadrant_hit", -1)
	
	# Apply shield damage
	if shield_damage > 0.0 and quadrant >= 0:
		if ship_obj.has_method("apply_shield_damage"):
			ship_obj.apply_shield_damage(shield_damage, quadrant)
		shield_quadrant_hit.emit(ship_obj, quadrant, shield_damage)
	
	# Apply hull damage
	if hull_damage > 0.0:
		if ship_obj.has_method("apply_hull_damage"):
			ship_obj.apply_hull_damage(hull_damage)
		collision_damage_applied.emit(ship_obj, hull_damage, "hull")
	
	# Apply subsystem damage
	if subsystem_damage > 0.0:
		if ship_obj.has_method("apply_subsystem_damage"):
			var subsystem_name: String = damage_info.get("subsystem_hit", "unknown")
			ship_obj.apply_subsystem_damage(subsystem_damage, subsystem_name)
			subsystem_damaged.emit(ship_obj, subsystem_name, subsystem_damage)
	
	# Destroy weapon (most weapons are destroyed on impact)
	if weapon_obj.has_method("destroy_weapon"):
		weapon_obj.destroy_weapon()
	elif weapon_obj.has_method("queue_free"):
		weapon_obj.queue_free()

## Apply mutual damage for ship-ship collisions.
func _apply_mutual_collision_damage(ship_a: Node3D, ship_b: Node3D, damage_info: Dictionary) -> void:
	var damage_a: float = damage_info.get("ship_a_damage", 0.0)
	var damage_b: float = damage_info.get("ship_b_damage", 0.0)
	
	# Apply damage to both ships
	if damage_a > 0.0:
		if ship_a.has_method("apply_collision_damage"):
			ship_a.apply_collision_damage(damage_a)
		collision_damage_applied.emit(ship_a, damage_a, "collision")
	
	if damage_b > 0.0:
		if ship_b.has_method("apply_collision_damage"):
			ship_b.apply_collision_damage(damage_b)
		collision_damage_applied.emit(ship_b, damage_b, "collision")

## Apply damage for ship-asteroid collisions.
func _apply_asteroid_collision_damage(ship_obj: Node3D, asteroid_obj: Node3D, damage_info: Dictionary) -> void:
	var ship_damage: float = damage_info.get("ship_damage", 0.0)
	var asteroid_damage: float = damage_info.get("asteroid_damage", 0.0)
	
	# Apply damage to ship
	if ship_damage > 0.0:
		if ship_obj.has_method("apply_collision_damage"):
			ship_obj.apply_collision_damage(ship_damage)
		collision_damage_applied.emit(ship_obj, ship_damage, "asteroid")
	
	# Apply damage to asteroid (may cause breakup)
	if asteroid_damage > 0.0:
		if asteroid_obj.has_method("apply_collision_damage"):
			asteroid_obj.apply_collision_damage(asteroid_damage)
		collision_damage_applied.emit(asteroid_obj, asteroid_damage, "collision")

## Apply generic damage for other collision types.
func _apply_generic_damage(object_a: Node3D, object_b: Node3D, damage_info: Dictionary) -> void:
	var damage_a: float = damage_info.get("object_a_damage", 0.0)
	var damage_b: float = damage_info.get("object_b_damage", 0.0)
	
	if damage_a > 0.0 and object_a.has_method("apply_damage"):
		object_a.apply_damage(damage_a)
		collision_damage_applied.emit(object_a, damage_a, "generic")
	
	if damage_b > 0.0 and object_b.has_method("apply_damage"):
		object_b.apply_damage(damage_b)
		collision_damage_applied.emit(object_b, damage_b, "generic")

## Trigger visual and audio effects for collision.
## Integration point for EPIC-008 graphics system
func _trigger_collision_effects(collision_info: Dictionary, damage_info: Dictionary) -> void:
	var position: Vector3 = collision_info.get("position", Vector3.ZERO)
	var normal: Vector3 = collision_info.get("normal", Vector3.UP)
	var damage: float = damage_info.get("primary_damage", 0.0)
	var damage_type: String = damage_info.get("damage_type", "collision")
	
	# Determine effect intensity based on damage
	var intensity: float = _calculate_effect_intensity(damage)
	
	# Determine effect type based on collision and damage type
	var effect_type: String = _determine_effect_type(damage_type, damage)
	
	# Trigger visual effects through graphics manager (EPIC-008)
	if graphics_manager and graphics_manager.has_method("create_collision_effect"):
		graphics_manager.create_collision_effect(position, normal, effect_type, intensity)
	
	# Trigger audio effects
	if audio_manager and audio_manager.has_method("play_collision_sound"):
		audio_manager.play_collision_sound(effect_type, position, intensity)
	
	# Emit effect signal for other systems to respond
	collision_effect_triggered.emit(position, normal, effect_type, intensity)

## Calculate effect intensity based on damage amount.
func _calculate_effect_intensity(damage: float) -> float:
	# Normalize damage to 0-1 intensity scale
	var max_damage_for_effects: float = 1000.0
	return clampf(damage / max_damage_for_effects, 0.1, 1.0)

## Determine effect type based on damage type and amount.
func _determine_effect_type(damage_type: String, damage: float) -> String:
	match damage_type:
		"weapon":
			if damage > 500.0:
				return "weapon_hit_heavy"
			elif damage > 100.0:
				return "weapon_hit_medium"
			else:
				return "weapon_hit_light"
		"collision":
			if damage > 1000.0:
				return "collision_heavy"
			elif damage > 300.0:
				return "collision_medium"
			else:
				return "collision_light"
		"asteroid":
			return "asteroid_impact"
		_:
			return "generic_impact"

## Get object velocity for physics calculations.
func _get_object_velocity(obj: Node3D) -> Vector3:
	if obj is RigidBody3D:
		return (obj as RigidBody3D).linear_velocity
	elif obj.has_method("get_velocity"):
		return obj.get_velocity()
	else:
		return Vector3.ZERO

## Get object mass for physics calculations.
func _get_object_mass(obj: Node3D) -> float:
	if obj is RigidBody3D:
		return (obj as RigidBody3D).mass
	elif obj.has_method("get_mass"):
		return obj.get_mass()
	else:
		return 100.0  # Default mass

## Validate collision response inputs.
func _validate_collision_response(object_a: Node3D, object_b: Node3D, collision_info: Dictionary) -> bool:
	if not object_a or not object_b:
		return false
	
	if not is_instance_valid(object_a) or not is_instance_valid(object_b):
		return false
	
	if object_a == object_b:
		return false
	
	if not collision_info.has("position") or not collision_info.has("normal"):
		push_warning("CollisionResponse: Invalid collision_info - missing position or normal")
		return false
	
	return true

## Reset per-frame performance counters.
func _process(_delta: float) -> void:
	responses_processed_this_frame = 0

## Get collision response statistics for monitoring.
func get_collision_response_statistics() -> Dictionary:
	return {
		"responses_this_frame": responses_processed_this_frame,
		"max_responses_per_frame": max_responses_per_frame,
		"physics_impulse_scale": physics_impulse_scale,
		"damage_application_enabled": damage_application_enabled,
		"effect_triggering_enabled": effect_triggering_enabled,
		"graphics_manager_connected": graphics_manager != null,
		"audio_manager_connected": audio_manager != null
	}