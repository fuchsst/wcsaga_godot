# scripts/weapon/projectiles/missile_projectile.gd
extends ProjectileBase
class_name MissileProjectile

# Missile-specific properties
# var time_since_creation: float = 0.0 # Moved to base class

# Homing state
var is_homing_active: bool = false
var free_flight_timer: float = 0.0 # Use this instead of checking time_since_creation directly


func _ready():
	super._ready()
	if weapon_data:
		free_flight_timer = weapon_data.free_flight_time


func _physics_process(delta):
	# time_since_creation += delta # Handled in base class
	super._physics_process(delta) # Handles lifetime


func _homing_logic(delta):
	# Based on weapon_home()
	if not weapon_data or not (weapon_data.flags & GlobalConstants.WIF_HOMING):
		return # Not a homing missile

	# Check if free flight time has passed
	if not is_homing_active:
		if free_flight_timer > 0.0:
			free_flight_timer -= delta
			# Maintain current velocity during free flight
			linear_velocity = -global_transform.basis.z * current_speed
			return
		else:
			is_homing_active = true
			# TODO: If heat seeker without initial target, acquire one now?
			# if weapon_data.homing_type == GlobalConstants.WIF_HOMING_HEAT and not is_instance_valid(target_node):
			#     _find_new_heat_target() # Needs implementation

	# --- Countermeasure Check ---
	# TODO: Implement countermeasure check logic here.
	# - Find nearby active countermeasures.
	# - Check effectiveness (cm_aspect_effectiveness, cm_heat_effectiveness) vs seeker strength.
	# - If distracted, temporarily set target_node to the countermeasure.
	# - Need to handle ignoring specific countermeasures (cmeasure_ignore_objnum)
	# - Need to handle chasing specific countermeasures (cmeasure_chase_objnum)
	# Example placeholder:
	# var distracted_by_cm = _check_countermeasures()
	# if distracted_by_cm:
	#     target_node = distracted_by_cm # Temporarily target the countermeasure
	# else:
	#     # Ensure we are targeting the original intended target if not distracted
	#     if not is_instance_valid(target_node) or target_node.is_queued_for_deletion():
	#          # Reacquire original target if possible (using target_signature?)
	#          # target_node = ObjectManager.get_object_by_signature(target_signature) # Placeholder
	#          pass


	# --- Target Validation ---
	var target_is_valid = is_instance_valid(target_node) and not target_node.is_queued_for_deletion()
	if target_is_valid:
		# Check signature for locked missiles (if signature tracking is implemented)
		# if weapon_data.flags & GlobalConstants.WIF_LOCKED_HOMING:
		#     if target_node.get_instance_id() != target_signature: # Instance ID is unreliable
		#         target_is_valid = false

		# Check if target is dying/destroyed
		if target_node is ShipBase and target_node.is_dying:
			target_is_valid = false

		# TODO: Check if target is hidden/stealth if applicable
		# if target_node is ShipBase and target_node.flags2 & GlobalConstants.SF2_STEALTH:
		#     # Check if detectable by this missile/parent ship
		#     pass

	if not target_is_valid:
		# Target lost or destroyed
		target_node = null
		target_subsystem = null
		target_signature = 0
		is_homing_active = false # Stop active homing

		# TODO: Implement re-targeting for heat seekers?
		# if weapon_data.homing_type == GlobalConstants.WIF_HOMING_HEAT:
		#     _find_new_heat_target()

		# For now, continue straight
		linear_velocity = -global_transform.basis.z * current_speed
		return

	# --- Calculate Target Position ---
	var target_pos: Vector3
	if target_subsystem and is_instance_valid(target_subsystem) and not (weapon_data.flags2 & GlobalConstants.WIF2_NON_SUBSYS_HOMING):
		# TODO: Get world position of the subsystem accurately
		target_pos = target_subsystem.global_position # Placeholder
	else:
		# Target center of mass or a specific homing point if defined
		# TODO: Implement logic for ai_big_pick_attack_point if target is large
		target_pos = target_node.global_position

	# --- Lead Targeting (Simplified) ---
	# Based on weapon_home() logic involving time_to_target
	var dist_to_target = global_position.distance_to(target_pos)
	var time_to_target = 0.0
	if current_speed > 0.01:
		time_to_target = dist_to_target / current_speed

	var lead_target_pos = target_pos
	# Check if target has linear_velocity property (common for RigidBody3D/CharacterBody3D)
	# Use get_meta for safety, or check if target inherits from a base class with velocity
	var target_velocity = Vector3.ZERO
	if target_node.has_method("get_linear_velocity"): # More reliable check
		target_velocity = target_node.get_linear_velocity()
	elif target_node.has_meta("linear_velocity"):
		target_velocity = target_node.get_meta("linear_velocity", Vector3.ZERO)

	if target_velocity.length_squared() > 0.01 and time_to_target > 0.1:
		var lead_time = time_to_target
		var lead_scale = 1.0 # Default for aspect/javelin

		# Apply lead scaling based on homing type and weapon data
		if weapon_data.flags2 & GlobalConstants.WIF2_VARIABLE_LEAD_HOMING:
			lead_scale = weapon_data.target_lead_scaler
		elif weapon_data.flags & GlobalConstants.WIF_HOMING_HEAT:
			lead_scale = 0.0 # Default heat seekers don't lead unless target_lead_scaler is set

		# Clamp lead time (similar to FS2)
		if weapon_data.flags & GlobalConstants.WIF_LOCKED_HOMING:
			lead_time = min(lead_time, 2.0)
		elif weapon_data.flags & GlobalConstants.WIF_HOMING_HEAT:
			lead_time = min(lead_time, 6.0) * 0.33 # FS2 heat seeker lead time adjustment

		lead_target_pos = target_pos + target_velocity * lead_time * lead_scale

	# --- Calculate Steering ---
	var current_dir = -global_transform.basis.z.normalized()
	var desired_dir = (lead_target_pos - global_position).normalized()

	# Limit turn rate using slerp for smoother rotation
	# weapon_data.turn_time seems to be time to turn 180 deg in FS2? Convert to rad/sec
	# Assuming turn_time is radians per second for now, needs verification.
	var max_turn_rad_per_sec = weapon_data.turn_time
	var max_angle_change = max_turn_rad_per_sec * delta

	var target_quat = Quat(Basis().looking_at(desired_dir)) # More direct way to get target orientation
	var current_quat = Quat(global_transform.basis)
	var angle_diff = current_quat.angle_to(target_quat)

	var rotation_ratio = 1.0
	if angle_diff > 0.001:
		rotation_ratio = min(1.0, max_angle_change / angle_diff)

	var final_quat = current_quat.slerp(target_quat, rotation_ratio)
	global_transform.basis = Basis(final_quat)

	# --- Speed Adjustment ---
	# Adjust speed based on angle to target (FS2 logic)
	var dot_to_target = current_dir.dot(desired_dir)
	if dot_to_target < 0.90:
		# Non-linear slowdown: speed = dot^2 * max_speed, but ensure minimum speed
		current_speed = max(0.2 * weapon_data.max_speed, dot_to_target * abs(dot_to_target) * weapon_data.max_speed)
		# Ensure minimum speed during turn (FS2 logic seemed to be ~75% of max)
		current_speed = max(current_speed, weapon_data.max_speed * 0.75)
	else:
		# Accelerate back to max speed if facing target
		current_speed = weapon_data.max_speed

	# Apply final velocity
	linear_velocity = -global_transform.basis.z * current_speed

	# --- Life Left Penalty (FS2 logic) ---
	if not (weapon_data.flags2 & GlobalConstants.WIF2_NO_LIFE_LOST_IF_MISSED):
		# Ensure weapon_data.fov is treated as cosine of half-angle as per C++ comments
		var fov_cosine = weapon_data.fov
		# Check if outside FOV cone (dot product is cosine of angle between vectors)
		if fov_cosine < 0.999 and dot_to_target < fov_cosine: # Avoid penalty if FOV is very wide or target is centered
			lifetime_timer -= delta * (fov_cosine - dot_to_target) # Reduce lifetime faster if off-target (scale penalty by how far off)


func _apply_impact(hit_object: Node, hit_position: Vector3, hit_normal: Vector3):
	# Override impact logic for missile-specific effects
	# print("Missile projectile impact!")
	super._apply_impact(hit_object, hit_position, hit_normal)
	# Add missile-specific explosion, shockwave, etc.


func _expire():
	# Override for missile-specific expiration (e.g., different fizzle effect)
	# print("Missile projectile expired")
	super._expire()
