class_name MissileWeapon
extends BaseWeapon

# Local State
var time_since_launch: float = 0.0
var swarm_index: int = 0

# Swarm State
var swarm_change_timer: float = 0.0
var swarm_target_offset: Vector3 = Vector3.ZERO
var swarm_path_index: int = 0
const SWARM_CHANGE_INTERVAL: float = 0.4 # 400ms

# Corkscrew State
var corkscrew_angle: float = 0.0

func _initialize_from_data() -> void:
	super._initialize_from_data()
	if weapon_data:
		# Initialize swarm index if part of a volley (logic handled by launcher usually)
		swarm_index = randi() % 4
		
		# Validate config presence
		if weapon_data.flags & WeaponData.WeaponFlags.CORKSCREW and not weapon_data.corkscrew_config:
			push_warning("Weapon " + weapon_data.id + " has CORKSCREW flag but no config!")
		

func _handle_movement(step: Vector3) -> void:
	var delta = get_physics_process_delta_time()
	time_since_launch += delta
	
	# Determine guidance
	if target and is_instance_valid(target) and weapon_data.is_homing():
		_apply_guidance(delta)
	elif weapon_data.flags & WeaponData.WeaponFlags.CORKSCREW:
		# Corkscrew even without lock? Usually requires a target "center" line
		# If no target, corkscrew around forward line?
		_apply_corkscrew_no_target(delta)

	# 5. Apply Corkscrew Offset (Visual only? No, real position)
	# Corkscrew modifies implicit position relative to path. 
	# Actually, legacy corkscrew modifies velocity vector to spiral.
	
	# Apply final movement using updated velocity
	global_position += velocity * delta
	
	# Rotate to face velocity (bank handled separately if at all)
	if velocity.length_squared() > 0.001:
		look_at(global_position + velocity, Vector3.UP)
		
	# Skip the rest of the commented out logic block
	# since we handled movement and rotation above
	return
	
	# Below is cleaning up old comments...
	
	# We should completely override movement logic here.
	
	# Calculate step based on current velocity
	var current_step = velocity * delta
	
	var params = PhysicsRayQueryParameters3D.create(global_position, global_position + current_step)
	params.collide_with_bodies = true
	params.exclude = [fired_by.get_rid()] if fired_by else []
	
	var result = get_world_3d().direct_space_state.intersect_ray(params)
	if result:
		global_position = result.position
		_detonate(result.collider)
	else:
		global_position += current_step
		
	# Rotate mesh if needed (e.g. for corkscrew visual spin)
	pass

func _apply_guidance(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return

	# 1. Swarm Logic
	if weapon_data.flags & WeaponData.WeaponFlags.SWARM:
		_apply_swarm_guidance(delta)
		return

	# 2. Corkscrew Logic
	if weapon_data.flags & WeaponData.WeaponFlags.CORKSCREW:
		_apply_corkscrew_guidance(delta)
		return
		
	# 3. Standard Homing
	_apply_standard_homing(delta)

func _apply_swarm_guidance(delta: float) -> void:
	# Update Swarm Target Offset
	swarm_change_timer -= delta
	if swarm_change_timer <= 0:
		swarm_change_timer = SWARM_CHANGE_INTERVAL + randf_range(-0.1, 0.1)
		_update_swarm_offset()
		
	# Ideal target is actual target + offset
	var current_target_pos = target.global_position + swarm_target_offset
	
	# Steer towards it
	_steer_towards(current_target_pos, delta)

func _update_swarm_offset() -> void:
	# Legacy swarm logic picks a random path perpendicular to view
	# For now, simplistic random offset in cone
	var dist = global_position.distance_to(target.global_position)
	if dist < 300.0: # Stop swarming close up
		swarm_target_offset = Vector3.ZERO
		return
		
	var offset_mag = 20.0 # Meters? SWARM_DIST_OFFSET was 2.0? Seems small.
	# Converting C++ define: #define SWARM_DIST_OFFSET 2.0
	# Wait, legacy code calculates radius = tan(angle) * dist. 
	# Radius shrinks as we get closer? No, angle is constant?
	# "tan(swarmp->angle_offset) * target_dist"
	
	var spread_angle = deg_to_rad(5.0) # 5 degrees spread?
	var radius = tan(spread_angle) * dist
	
	# Random point on circle of radius
	var random_angle = randf() * TAU
	# Create basis perpendicular to target line
	var forward = global_position.direction_to(target.global_position)
	var right = forward.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	var up = right.cross(forward).normalized()
	
	swarm_target_offset = (right * cos(random_angle) + up * sin(random_angle)) * radius

func _apply_corkscrew_guidance(delta: float) -> void:
	var config = weapon_data.corkscrew_config
	if not config: return
	
	# Corkscrew logic: Missile moves along the homing line but spirals around it.
	# We simulated this by having a "Virtual" position that homes normally, 
	# and the real missile orbits it.
	# Since we don't have a virtual object, we calculate the "Ideal Homing Velocity" 
	# and add a "Tangential Velocity".
	
	# 1. Ideal Homing Direction (Forward for the spiral center)
	var target_dir = global_position.direction_to(target.global_position)
	
	# Use standard homing turn rate for the Center Line
	# (We cheat slightly by just using current forward as the center line approximation if not turning fast enough)
	# Proper way: turn the "forward" vector towards target.
	
	# Let's assume current velocity is roughly correct for the spiral center's direction
	# but we need to steer the center line.
	
	# This uses specific config values: radius, twist_rate
	var twist_rate = deg_to_rad(config.twist_rate) # rad/s
	var radius = config.radius
	
	corkscrew_angle += twist_rate * delta
	
	# Axis of spiral is direction to target (approx)
	var axis = target_dir
	
	# Orthonormal basis
	var right = axis.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	var up = right.cross(axis).normalized()
	
	# Tangential direction of spin
	# At angle theta, pos is (r*cos, r*sin). Tangent is (-r*sin, r*cos).
	var tangent = (right * -sin(corkscrew_angle) + up * cos(corkscrew_angle)).normalized()
	
	# Tangential Speed = radius * twist_rate
	var tan_speed = radius * twist_rate
	var tangent_vel = tangent * tan_speed
	
	# Forward Velocity (Closing speed)
	var forward_vel = axis * weapon_data.muzzle_velocity_mps
	
	# Resultant
	velocity = forward_vel + tangent_vel
	
	# Orientation
	look_at(global_position + velocity, up)

func _apply_corkscrew_no_target(delta: float) -> void:
	# Same as above but axis is just current forward
	var config = weapon_data.corkscrew_config
	if not config: return
	
	var twist_rate = deg_to_rad(config.twist_rate)
	var radius = config.radius
	corkscrew_angle += twist_rate * delta
	
	var axis = - global_transform.basis.z # Current forward? No, this changes as we rotate.
	# If we blindly trust basis.z, we spiral into a circle.
	# We need a stable "intended direction" when dumb-firing.
	# Store launch direction?
	pass # TODO: Implement dumbfire corkscrew buffer

func _apply_standard_homing(delta: float) -> void:
	if weapon_data.turn_time <= 0: return
	
	_steer_towards(target.global_position, delta)

func _steer_towards(target_pos: Vector3, delta: float) -> void:
	var target_dir = global_position.direction_to(target_pos)
	var current_dir = - global_transform.basis.z
	
	var turn_rate_deg = 360.0 / weapon_data.turn_time
	var max_turn = deg_to_rad(turn_rate_deg) * delta
	
	var angle_diff = current_dir.angle_to(target_dir)
	if angle_diff > 0.001:
		var t = clamp(max_turn / angle_diff, 0.0, 1.0)
		var new_dir = current_dir.slerp(target_dir, t).normalized()
		
		look_at(global_position + new_dir, Vector3.UP)
		velocity = new_dir * weapon_data.muzzle_velocity_mps
