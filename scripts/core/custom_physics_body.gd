class_name CustomPhysicsBody
extends Node3D

## Custom physics body for WCS-specific physics simulation
## Provides interface between WCS objects and the physics manager

signal physics_updated()

# Physics properties
@export var mass: float = 1.0
@export var drag_coefficient: float = 0.01
@export var collision_radius: float = 1.0
@export var collision_layer: int = 1
@export var collision_mask: int = 1

# State
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var thrust_vector: Vector3 = Vector3.ZERO
var applied_forces: Array[Vector3] = []

# Configuration
var physics_enabled: bool = true
var collision_enabled: bool = true

# Associated objects
var wcs_object: WCSObject
var collision_shape: Shape3D

func _ready() -> void:
	# Initialize default collision shape
	if not collision_shape:
		var sphere_shape: SphereShape3D = SphereShape3D.new()
		sphere_shape.radius = collision_radius
		collision_shape = sphere_shape

# Physics property getters/setters

func get_mass() -> float:
	return mass

func set_mass(new_mass: float) -> void:
	mass = maxf(0.001, new_mass)  # Prevent zero mass

func get_velocity() -> Vector3:
	return velocity

func set_velocity(new_velocity: Vector3) -> void:
	velocity = new_velocity

func get_angular_velocity() -> Vector3:
	return angular_velocity

func set_angular_velocity(new_angular_velocity: Vector3) -> void:
	angular_velocity = new_angular_velocity

func get_drag_coefficient() -> float:
	return drag_coefficient

func get_thrust_vector() -> Vector3:
	return thrust_vector

func set_thrust_vector(new_thrust: Vector3) -> void:
	thrust_vector = new_thrust

# Collision properties

func get_collision_radius() -> float:
	return collision_radius

func get_collision_layer() -> int:
	return collision_layer

func get_collision_mask() -> int:
	return collision_mask

func get_collision_shape() -> Shape3D:
	return collision_shape

func set_collision_shape(shape: Shape3D) -> void:
	collision_shape = shape

# Physics control

func is_physics_enabled() -> bool:
	return physics_enabled

func set_physics_enabled(enabled: bool) -> void:
	physics_enabled = enabled

func is_collision_enabled() -> bool:
	return collision_enabled

func set_collision_enabled(enabled: bool) -> void:
	collision_enabled = enabled

# Force application

func apply_force(force: Vector3) -> void:
	applied_forces.append(force)

func apply_impulse(impulse: Vector3) -> void:
	velocity += impulse / mass

func apply_torque(torque: Vector3) -> void:
	# Apply rotational force
	angular_velocity += torque / mass

# Physics integration

func integrate_physics(delta: float) -> void:
	# Apply accumulated forces
	for force in applied_forces:
		velocity += (force / mass) * delta
	
	# Clear applied forces
	applied_forces.clear()
	
	# Update position and rotation
	position += velocity * delta
	rotation += angular_velocity * delta
	
	physics_updated.emit()

# Object association

func get_wcs_object() -> WCSObject:
	return wcs_object

func set_wcs_object(obj: WCSObject) -> void:
	wcs_object = obj

# Debug helpers

func get_debug_name() -> String:
	if wcs_object:
		return wcs_object.debug_info()
	else:
		return "CustomPhysicsBody[%s]" % name
