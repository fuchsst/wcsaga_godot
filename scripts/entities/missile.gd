class_name Missile
extends Weapon

# Missile entity with homing capabilities

var target: Node3D
var turn_rate: float = 0.0 # Degrees per second
var homing_delay: float = 0.0 # Time before homing starts
var current_homing_time: float = 0.0

func _ready():
	super._ready()
	if weapon_data:
		turn_rate = weapon_data.max_turn_rate_dps
		homing_delay = weapon_data.free_flight_time

func _process(delta: float):
	if target and is_instance_valid(target) and weapon_data.is_homing():
		current_homing_time += delta
		if current_homing_time > homing_delay:
			_update_homing(delta)
			
	super._process(delta)

func _update_homing(delta: float):
	var direction_to_target = (target.global_position - global_position).normalized()
	var current_direction = velocity.normalized()
	
	# Calculate rotation towards target
	# Simple interpolation for now
	var new_direction = current_direction.move_toward(direction_to_target, deg_to_rad(turn_rate) * delta).normalized()
	velocity = new_direction * velocity.length()
	
	# Rotate visual
	look_at(global_position + velocity, Vector3.UP)

func set_target(new_target: Node3D):
	target = new_target
