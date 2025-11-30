class_name Missile
extends "res://scripts/entities/weapon.gd"

# Missile entity with homing capabilities

var target_node: Node3D
var homing_active: bool = false
var time_since_launch: float = 0.0

# Corkscrew/Swarm state
var swarm_index: int = 0
var swarm_total: int = 1
var virtual_position: Vector3 = Vector3.ZERO  # Center of the corkscrew path
var corkscrew_angle: float = 0.0
var current_corkscrew_radius: float = 0.0


func initialize(
	data: WCSWeaponData,
	source: Node3D,
	start_pos: Vector3,
	start_rot: Quaternion,
	initial_velocity: Vector3
) -> void:
	super.initialize(data, source, start_pos, start_rot, initial_velocity)
	virtual_position = start_pos

	if weapon_data.corkscrew_config:
		current_corkscrew_radius = weapon_data.corkscrew_config.radius
		# Randomize initial angle or base on index?
		# FS2 usually bases it on index for counter-rotation
		if weapon_data.corkscrew_config.counter_rotate and swarm_index % 2 == 1:
			corkscrew_angle = PI  # Start 180 deg off? Or just rotate opposite?
			# Actually counter-rotate means twist rate is negated.


func configure_swarm(index: int, total: int) -> void:
	swarm_index = index
	swarm_total = total


func _physics_process(delta: float) -> void:
	time_since_launch += delta

	if not homing_active and time_since_launch > weapon_data.free_flight_time:
		homing_active = true
		_acquire_target()

	if homing_active and is_instance_valid(target_node):
		_update_homing(delta)

	# Move virtual position (the center of the spiral)
	virtual_position += velocity * delta

	# Apply Corkscrew offset if active
	if weapon_data.corkscrew_config:
		_update_corkscrew(delta)
	else:
		global_position = virtual_position

	# Handle lifetime (from base class, but we need to call it manually or let base run?)
	# Base class does: global_position += velocity * delta.
	# We are overriding movement, so we shouldn't call super._physics_process for movement.
	# But we need lifetime logic.

	lifetime -= delta
	if lifetime <= 0:
		expire()


func _update_corkscrew(delta: float) -> void:
	var config = weapon_data.corkscrew_config

	# Update radius
	if config.shrink_rate > 0:
		current_corkscrew_radius -= config.shrink_rate * delta
		if current_corkscrew_radius < 0:
			current_corkscrew_radius = 0

	# Update angle
	var twist = deg_to_rad(config.twist_rate)
	if config.counter_rotate and swarm_index % 2 == 1:
		twist = -twist

	corkscrew_angle += twist * delta

	# Calculate offset
	# Basis vectors relative to velocity (forward)
	var forward = velocity.normalized()
	if forward == Vector3.ZERO:
		forward = -global_transform.basis.z

	var up = Vector3.UP
	if abs(forward.dot(Vector3.UP)) > 0.99:
		up = Vector3.RIGHT

	var right = forward.cross(up).normalized()
	up = right.cross(forward).normalized()

	var offset = (
		(right * cos(corkscrew_angle) + up * sin(corkscrew_angle)) * current_corkscrew_radius
	)

	global_position = virtual_position + offset

	# Optional: Rotate missile to face spiral direction?
	# If helix flag is set
	if config.helix:
		# Look at next position in spiral
		# Approximate by looking at current pos + velocity + tangential velocity
		pass


func _acquire_target() -> void:
	# If shooter has a target, use it
	if shooter and shooter.has_method("get_current_target"):
		target_node = shooter.get_current_target()

	# Otherwise, find nearest enemy in view cone (simplified)
	if not target_node and weapon_data.homing_type > 0:
		# TODO: Implement target selection logic
		pass


func _update_homing(delta: float) -> void:
	var target_pos = target_node.global_position
	var direction_to_target = (target_pos - virtual_position).normalized()  # Homing towards virtual center
	var current_forward = velocity.normalized()

	# Calculate rotation needed
	# Limit by max_turn_rate_dps
	var max_turn = deg_to_rad(weapon_data.max_turn_rate_dps) * delta

	# Simple interpolation for now (needs quaternion slerp for proper rotation)
	var new_forward = current_forward.move_toward(direction_to_target, max_turn).normalized()

	# Update velocity vector
	velocity = new_forward * weapon_data.muzzle_velocity_mps

	# Update rotation of the missile body to face velocity (unless helix overrides)
	if new_forward != Vector3.ZERO:
		look_at(global_position + new_forward, Vector3.UP)


func _setup_visuals() -> void:
	super._setup_visuals()

	# Add thruster trail
	if not weapon_data.projectile_trail_effect.is_empty():
		# TODO: Load trail effect
		pass
	else:
		# Default trail
		var trail = GPUParticles3D.new()
		# Configure particles...
		add_child(trail)
