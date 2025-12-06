class_name MissileWeapon
extends BaseWeapon

# Local State
var current_turn_rate: float = 0.0
var time_since_launch: float = 0.0
var swarm_index: int = 0
var noise_seed: Vector2 = Vector2.ZERO

func _initialize_from_data() -> void:
	super._initialize_from_data()
	if weapon_data:
		current_turn_rate = weapon_data.turn_time # Actually TBL has turn_time in seconds? No, check weapon_data.gd.
		# weapon_data.turn_time is "Turn Time" in seconds (time to turn 360? or time to reach max turn? No, usually it's turn rate deg/sec or time to turn)
		# FS2 wiki says "Turn Time: The time in seconds it takes for the missile to complete a 360 degree turn."
		# So Turn Rate (deg/s) = 360 / Turn Time
		pass
	noise_seed = Vector2(randf() * 100.0, randf() * 100.0)

func _handle_movement(step: Vector3) -> void:
	time_since_launch += 0.016 # Approx delta
	
	if target and is_instance_valid(target) and weapon_data.is_homing():
		_apply_guidance(get_physics_process_delta_time())
		
	# Move forward with new orientation
	var new_step = - global_transform.basis.z * velocity.length() * get_physics_process_delta_time()
	
	# Still use raycast for safety
	var params = PhysicsRayQueryParameters3D.create(global_position, global_position + new_step)
	params.collide_with_bodies = true
	params.exclude = [fired_by.get_rid()] if fired_by else []
	
	var result = get_world_3d().direct_space_state.intersect_ray(params)
	if result:
		global_position = result.position
		_detonate(result.collider)
	else:
		global_position += new_step

func _apply_guidance(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return
		
	# 1. Aspect/Heat Checks
	if weapon_data.homing_type == WeaponData.HomingType.HEAT_SEEKING:
		# Check FOV
		var to_target = global_position.direction_to(target.global_position)
		var forward = - global_transform.basis.z
		var angle = rad_to_deg(forward.angle_to(to_target))
		if angle > (weapon_data.fov / 2.0):
			# Lost lock / outside FOV - stop homing or reduce turn rate?
			# In FS2, heat seekers lose lock if target leaves cone
			return

	# 2. Swarm Logic
	if weapon_data.swarm_count > 0:
		_apply_swarm_movement(delta)
		return
		
	# 3. Corkscrew Logic
	if "CORKSCREW" in weapon_data.flags: # Assuming flags check
		_apply_corkscrew_movement(delta)
		return

	# 4. Standard Homing (Proportional Navigation or Pursuit)
	if not weapon_data.turn_time > 0:
		return
		
	var turn_rate_deg = 360.0 / weapon_data.turn_time
	var max_turn = deg_to_rad(turn_rate_deg) * delta
	
	var target_dir = global_position.direction_to(target.global_position)
	var current_dir = - global_transform.basis.z
	
	# Determine rotation needed
	var new_dir = current_dir
	var angle_diff = current_dir.angle_to(target_dir)
	
	if angle_diff > 0.001:
		var t = clamp(max_turn / angle_diff, 0.0, 1.0)
		new_dir = current_dir.slerp(target_dir, t).normalized()
	
	# Apply
	look_at(global_position + new_dir, Vector3.UP) # Note: Be careful with Up vector locking
	
	# Maintain velocity magnitude
	velocity = - global_transform.basis.z * weapon_data.velocity_mps # Re-align velocity to new heading

func _apply_swarm_movement(delta: float) -> void:
	# Swarm behavior: Random spiral that converges
	# Use swarm_index to offset phase
	var guidance_factor = clamp(time_since_launch / 2.0, 0.0, 1.0) # Full guidance after 2 seconds?
	
	# Basic sine wave offset on local axes
	# We want to move towards target but spiral
	var target_dir = global_position.direction_to(target.global_position)
	
	# Create orthonormal basis from target_dir
	var up = Vector3.UP if abs(target_dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right = target_dir.cross(up).normalized()
	up = right.cross(target_dir).normalized()
	
	# Swarm noise
	var freq = 3.0
	var amp = 5.0 * (1.0 - guidance_factor) # Decay amplitude as we get closer/older?
	
	var time_offset = float(swarm_index) * (PI / 2.0)
	var x_off = sin(time_since_launch * freq + time_offset) * amp
	var y_off = cos(time_since_launch * freq + time_offset) * amp
	
	# Ideal position is simply moving towards target?
	# Implementation: Modify velocity direction directly
	
	var desired_dir = (target_dir + (right * x_off * 0.1) + (up * y_off * 0.1)).normalized()
	
	# Turn towards desired
	var turn_rate_deg = 360.0 # Swarms are agile
	var max_turn = deg_to_rad(turn_rate_deg) * delta
	
	var current_dir = - global_transform.basis.z
	var new_dir = current_dir
	var angle_diff = current_dir.angle_to(desired_dir)
	
	if angle_diff > 0.001:
		var t = clamp(max_turn / angle_diff, 0.0, 1.0)
		new_dir = current_dir.slerp(desired_dir, t).normalized()
		
	look_at(global_position + new_dir, Vector3.UP)
	velocity = new_dir * velocity.length()

func _apply_corkscrew_movement(delta: float) -> void:
	# Corkscrew: Rotate velocity vector around the forward axis
	var freq = 4.0 # Radians per second
	var radius = 2.0 # Meters radius of corkscrew
	
	# Current Basis
	var forward = - global_transform.basis.z
	var right = global_transform.basis.x
	var up = global_transform.basis.y
	
	# Rotate an offset around forward
	var angle = time_since_launch * freq
	var offset_dir = (right * cos(angle) + up * sin(angle)).normalized()
	
	# We want the missile to physically move in a spiral
	# So we adjust the velocity direction to point 'in' towards the spiral center if we are out, 
	# and 'tangent' to move forward?
	# Simpler: The physical model is the spiral center, the visual model spins? 
	# No, POF collisions happen on the mesh. The mesh moves.
	
	# Let's adjust velocity to be: Forward + Rotating Tangent
	# No, that makes it fly in a circle away from origin.
	
	# Correct way: GUIDANCE moves the "Center" of the corkscrew.
	# The missile oscillates around that center.
	
	# 1. Calculate ideal "Center" position
	# We don't track center explicitly.
	# Let's just add a rotating velocity component perpendicular to forward.
	
	# If we add a rotating component, we spiral out?
	# Unless we are correcting back.
	
	# Standard Homming controls the "Center".
	# We superimpose corkscrew.
	
	# For now, let's just make it look cool by adding a local offset to position for rendering/collision?
	# Bad for physics step.
	
	# Implementation: 
	# Move normally (Guidance) -> resulting "Center" position and "Center" velocity.
	# Add Corkscrew Offset to Global Position?
	# But collision detection uses global_position.
	
	# Let's simple apply a rotational velocity bias.
	# To circle a point, Velocity must be perpendicular to Radius.
	# Radius vector rotates. Velocity is Tangent.
	
	# Tangent direction:
	var tangent_dir = (right * -sin(angle) + up * cos(angle)).normalized()
	
	# Add tangent velocity to forward velocity
	# V = V_forward + V_tangent
	# V_tangent speed = radius * freq ??
	# Circumference = 2*pi*r. Freq (rad/s). Speed = r * w.
	
	var tan_speed = radius * freq
	
	# Base movement is forward
	var base_velocity = forward * weapon_data.velocity_mps
	
	# Resulting velocity
	velocity = base_velocity + (tangent_dir * tan_speed)
	
	# Look at? 
	look_at(global_position + velocity, Vector3.UP)
