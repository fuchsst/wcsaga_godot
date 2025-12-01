class_name Ship
extends GameEntity

# Ship Entity
# Handles physics-based flight, input processing, and system integration

# Physics properties
@export_group("Physics")
@export var max_speed: float = 100.0
@export var acceleration: float = 50.0
@export var rotation_speed: Vector3 = Vector3(1.0, 1.0, 1.0) # Pitch, Yaw, Roll
@export var drag_coefficient: float = 0.98

# IFF team
@export var iff_team: String = "Friendly"

# System integration
var ship_instance: ShipInstance = null

func _ready() -> void:
	super._ready()
	gravity_scale = 0.0 # Space has no gravity
	linear_damp = 0.0 # We handle drag manually
	angular_damp = 1.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if InputManager == null:
		return
		
	_handle_movement(delta)

func _handle_movement(delta: float) -> void:
	# Get input from InputManager
	var thrust = InputManager.get_thrust_input()
	var yaw = InputManager.get_yaw_input()
	var pitch = InputManager.get_pitch_input()
	var roll = InputManager.get_roll_input()
	
	# Apply forces (Local space)
	var forward_dir = - global_transform.basis.z
	var right_dir = global_transform.basis.x
	var up_dir = global_transform.basis.y
	
	# Linear movement (Thrust)
	if thrust != 0:
		apply_central_force(forward_dir * thrust * acceleration)
	
	# Drag (Space friction)
	var velocity_magnitude = linear_velocity.length()
	if velocity_magnitude > 0:
		var drag_force = - linear_velocity.normalized() * (velocity_magnitude * velocity_magnitude) * (1.0 - drag_coefficient) * delta
		# Clamp drag to not reverse movement
		# Simplified linear drag for now
		linear_velocity *= drag_coefficient
		
	# Angular movement (Rotation)
	# Using torque for physics-based rotation
	var torque = Vector3.ZERO
	torque += right_dir * pitch * rotation_speed.x
	torque += up_dir * yaw * rotation_speed.y
	torque += forward_dir * roll * rotation_speed.z
	
	apply_torque(torque)
