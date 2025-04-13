# scripts/weapon/projectiles/missile_projectile.gd
extends ProjectileBase
class_name MissileProjectile

# Missile-specific properties
# var time_since_creation: float = 0.0 # Moved to base class

# Homing state
var is_homing_active: bool = false
var free_flight_timer: float = 0.0 # Use this instead of checking time_since_creation directly
var _cm_chase_signature: int = -1 # Signature of the countermeasure currently being chased (-1 if none)
var _cm_ignore_signatures: Dictionary = {} # { signature: expiry_timestamp }

# Corkscrew state (if applicable)
var is_corkscrewing: bool = false
var corkscrew_angle: float = 0.0
var corkscrew_radius: float = 0.0
var corkscrew_twist_rate: float = 0.0 # Radians per second
var corkscrew_direction: int = 1 # 1 for clockwise, -1 for counter-clockwise


func _ready():
	super._ready()
	if weapon_data:
		free_flight_timer = weapon_data.free_flight_time

		# Initialize corkscrew state if applicable
		if weapon_data.flags & GlobalConstants.WIF_CORKSCREW:
			is_corkscrewing = true
			corkscrew_radius = weapon_data.cs_radius
			# Convert twist (degrees/sec?) to radians/sec
			# Assuming cs_twist is degrees per second based on FS2 source context
			corkscrew_twist_rate = deg_to_rad(weapon_data.cs_twist)
			corkscrew_direction = -1 if weapon_data.cs_crotate else 1
			# Randomize starting angle for variation
			corkscrew_angle = randf() * TAU


func _physics_process(delta):
	# time_since_creation += delta # Handled in base class
	super._physics_process(delta) # Handles lifetime check

	# --- Corkscrew Movement (Applied after homing calculates velocity) ---
	if is_corkscrewing:
		# Update the corkscrew angle
		corkscrew_angle += corkscrew_twist_rate * corkscrew_direction * delta
		# Keep angle within 0 to TAU range (optional, but good practice)
		corkscrew_angle = fposmod(corkscrew_angle, TAU)

		# Calculate the offset in the missile's local XY plane
		var local_offset = Vector3(cos(corkscrew_angle), sin(corkscrew_angle), 0) * corkscrew_radius

		# Transform the local offset to world space based on current orientation
		# Note: We apply this *after* homing logic sets the velocity/orientation for the frame
		var world_offset = global_transform.basis * local_offset

		# The linear_velocity is already set by _homing_logic to move towards the target.
		# We adjust the *position* based on the corkscrew offset.
		# This assumes the RigidBody integration will handle the final position update.
		# If using CharacterBody, we'd adjust the final move_and_slide target.

		# For RigidBody, directly applying position changes can fight the physics engine.
		# A better approach might be to apply a perpendicular force or velocity change.
		# Let's try applying an additional velocity component perpendicular to the main velocity.

		# Get the current forward direction
		var forward_dir = -global_transform.basis.z.normalized()
		# Calculate the desired perpendicular velocity component based on the offset change
		# This is complex. Let's try a simpler position offset first, acknowledging potential physics issues.

		# --- Simpler Position Offset Approach (May conflict with RigidBody physics) ---
		# Calculate the ideal position *without* corkscrew based on current velocity
		# var ideal_next_pos = global_position + linear_velocity * delta
		# Calculate the final position *with* the corkscrew offset applied relative to the forward axis
		# var final_pos = ideal_next_pos + world_offset
		# This might not work well with RigidBody.

		# --- Refined Corkscrew Velocity Adjustment ---
		# Calculate the ideal position *without* corkscrew based on current velocity direction
		var ideal_center_path_next_pos = global_position + (-global_transform.basis.z * current_speed * delta)

		# Calculate the desired final position *with* the corkscrew offset applied relative to the forward axis
		# The offset is perpendicular to the *current* forward direction
		var desired_final_pos = ideal_center_path_next_pos + world_offset

		# Calculate the direction vector needed to reach the desired final position from the current position
		var desired_velocity_dir = (desired_final_pos - global_position).normalized()

		# Set the linear velocity to point in this adjusted direction, maintaining the calculated speed
		linear_velocity = desired_velocity_dir * current_speed

		# Note: This approach directly sets the velocity vector each frame to achieve the
		# corkscrew motion combined with homing. It avoids adding forces/impulses which
		# might be less predictable with the physics engine's integration.


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
	var original_target_node = target_node # Store original target before potential distraction
	var is_distracted_by_cm = false
	var current_time_ms = Time.get_ticks_msec()

	# Clean up expired ignore entries
	var expired_sigs = []
	for sig in _cm_ignore_signatures:
		if current_time_ms > _cm_ignore_signatures[sig]:
			expired_sigs.append(sig)
	for sig in expired_sigs:
		_cm_ignore_signatures.erase(sig)

	# Check if currently chasing a countermeasure
	if _cm_chase_signature != -1:
		var chased_cm_node = ObjectManager.get_object_by_signature(_cm_chase_signature)
		if is_instance_valid(chased_cm_node) and not chased_cm_node.is_queued_for_deletion():
			target_node = chased_cm_node # Continue chasing valid CM
			is_distracted_by_cm = true
		else:
			_cm_chase_signature = -1 # Chased CM is gone, stop chasing

	# If not currently distracted, check for new countermeasures
	if not is_distracted_by_cm and Engine.has_singleton("ObjectManager") and weapon_data.cm_effective_rad > 0:
		# Query for nearby countermeasures
		# TODO: Replace with spatial query for performance
		var nearby_objects = ObjectManager.get_all_weapons() # Placeholder
		var potential_cms: Array[Node] = []

		var check_radius_sq = weapon_data.cm_effective_rad * weapon_data.cm_effective_rad
		for obj in nearby_objects:
			if not is_instance_valid(obj) or obj == self: continue
			# Basic type check - assumes CMs are ProjectileBase with WIF_CMEASURE
			if obj is ProjectileBase and obj.weapon_data and (obj.weapon_data.flags & GlobalConstants.WIF_CMEASURE):
				if global_position.distance_squared_to(obj.global_position) < check_radius_sq:
					potential_cms.append(obj)

		# Sort potential CMs by distance
		potential_cms.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))

		for cm_node in potential_cms:
			var cm_sig = cm_node.get_signature()
			var cm_weapon_data = cm_node.weapon_data as WeaponData

			# Skip if recently ignored
			if _cm_ignore_signatures.has(cm_sig): continue

			# Calculate distraction chance
			var effectiveness = 0.0
			if weapon_data.flags & GlobalConstants.WIF_HOMING_ASPECT:
				effectiveness = cm_weapon_data.cm_aspect_effectiveness
			elif weapon_data.flags & GlobalConstants.WIF_HOMING_HEAT:
				effectiveness = cm_weapon_data.cm_heat_effectiveness
			# TODO: Javelin effectiveness?

			var chance = 0.0
			if weapon_data.seeker_strength > 0.01:
				chance = effectiveness / weapon_data.seeker_strength
			else:
				chance = 1.0 # Assume infinite chance if seeker strength is zero?

			if randf() < chance:
				# Distracted! Target this countermeasure
				target_node = cm_node
				target_subsystem = null # CMs don't have subsystems
				target_signature = cm_sig # Update target signature
				_cm_chase_signature = cm_sig
				is_distracted_by_cm = true
				# TODO: Alert player/AI? (cmeasure_maybe_alert_success)
				print("Missile distracted by countermeasure: ", cm_sig)
				break # Stop checking other countermeasures for this frame
			else:
				# Not distracted by this one, ignore it for a short time (e.g., 1 second)
				_cm_ignore_signatures[cm_sig] = current_time_ms + 1000
				# print("Missile ignored countermeasure: ", cm_sig)

	# If not distracted by CM, ensure we are targeting the original intended target
	if not is_distracted_by_cm:
		target_node = original_target_node
		# Re-validate original target if it became invalid while checking CMs
		if not is_instance_valid(target_node) or target_node.is_queued_for_deletion():
			target_node = ObjectManager.get_object_by_signature(target_signature) # Try to reacquire by signature
			if not is_instance_valid(target_node):
				target_signature = 0 # Clear signature if reacquisition failed


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

		# Target lost or destroyed
		target_node = null
		target_subsystem = null
		target_signature = 0
		is_homing_active = false # Stop active homing
		_cm_chase_signature = -1 # Stop chasing CM if target lost

		# Re-targeting logic for heat seekers
		if weapon_data.flags & GlobalConstants.WIF_HOMING_HEAT:
			_find_new_heat_target()
			# If _find_new_heat_target found something, is_homing_active will be true again
			if not is_homing_active:
				# Continue straight if no new target found
				linear_velocity = -global_transform.basis.z * current_speed
				return
		else:
			# Non-heat seekers just continue straight
			linear_velocity = -global_transform.basis.z * current_speed
			return

	# --- Calculate Target Position ---
	# (This section remains the same, but runs with the potentially updated target_node)
	var target_pos: Vector3
		return

	# --- Calculate Target Position ---
	var target_pos: Vector3
	if target_subsystem and is_instance_valid(target_subsystem) and not (weapon_data.flags2 & GlobalConstants.WIF2_NON_SUBSYS_HOMING):
		# Use the new helper function to get the accurate world position
		if target_subsystem.has_method("get_world_position"):
			target_pos = target_subsystem.get_world_position()
		else:
			# Fallback if method is missing (shouldn't happen if ShipSubsystem is updated)
			printerr("MissileProjectile: Target subsystem is missing get_world_position() method!")
			target_pos = target_subsystem.global_position # Fallback to node position
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

	# --- Aspect Lock / FOV Check & Life Left Penalty ---
	var aspect_score = 1.0 # Default to perfect aspect if not applicable
	if weapon_data.flags & GlobalConstants.WIF_HOMING_ASPECT:
		aspect_score = _get_aspect_score(target_node)

	# Use aspect score for aspect seekers, dot_to_target for others (like heat)
	var relevant_dot = aspect_score if (weapon_data.flags & GlobalConstants.WIF_HOMING_ASPECT) else dot_to_target

	# Ensure weapon_data.fov is treated as cosine of half-angle as per C++ comments
	var fov_cosine = weapon_data.fov

	# Check if outside FOV cone (dot product is cosine of angle between vectors)
	if relevant_dot < fov_cosine:
		# Target is outside the seeker's view cone (or aspect is too poor for aspect seekers)
		# Apply life penalty if enabled
		if not (weapon_data.flags2 & GlobalConstants.WIF2_NO_LIFE_LOST_IF_MISSED):
			if fov_cosine < 0.999: # Avoid penalty if FOV is very wide
				lifetime_timer -= delta * (fov_cosine - relevant_dot) # Reduce lifetime faster if off-target (scale penalty by how far off)

		# TODO: Should aspect seekers lose lock completely if aspect is too poor?
		# For now, we just apply the life penalty, mimicking the original logic's primary use of FOV.
		# If lock should be lost:
		# if weapon_data.flags & GlobalConstants.WIF_HOMING_ASPECT:
		#     print("Aspect lock lost!")
		#     is_homing_active = false
		#     target_node = null
		#     # Potentially trigger re-acquisition logic here if needed


func _apply_impact(hit_object: Node, hit_position: Vector3, hit_normal: Vector3):
	# Override impact logic for missile-specific effects
	# print("Missile projectile impact!")
	super._apply_impact(hit_object, hit_position, hit_normal)
	# Add missile-specific explosion, shockwave, etc.


func _expire():
	# Override for missile-specific expiration (e.g., different fizzle effect)
	# print("Missile projectile expired")
	super._expire()


# --- Helper Functions ---

func _get_aspect_score(p_target_node: Node3D) -> float:
	"""Calculates the aspect score (dot product with target's rear vector)."""
	if not is_instance_valid(p_target_node):
		return -1.0 # Invalid target

	# Missile's forward vector
	var missile_fvec = -global_transform.basis.z.normalized()

	# Target's backward vector
	var target_bvec = p_target_node.global_transform.basis.z.normalized() # Target's -Z is forward, so +Z is backward

	# Calculate dot product
	return missile_fvec.dot(target_bvec)


func _find_new_heat_target():
	"""Attempts to find a new target for a heat-seeking missile."""
	if not Engine.has_singleton("ObjectManager"):
		printerr("MissileProjectile: ObjectManager not found for heat target re-acquisition.")
		return

	var best_target: Node3D = null
	var min_dist_sq = INF

	# TODO: Use a more efficient spatial query
	var potential_targets = ObjectManager.get_all_ships() # Placeholder

	for potential_target in potential_targets:
		if not is_instance_valid(potential_target) or potential_target == owner_ship:
			continue

		# IFF Check
		var owner_team = owner_ship.get_team() if is_instance_valid(owner_ship) and owner_ship.has_method("get_team") else -1
		var target_team = potential_target.get_team() if potential_target.has_method("get_team") else -1
		if owner_team != -1 and target_team != -1:
			if Engine.has_singleton("IFFManager"):
				if not IFFManager.iff_can_attack(owner_team, target_team):
					continue # Skip friendlies
			else:
				printerr("MissileProjectile: IFFManager not found for heat target IFF check.")

		# TODO: Add heat signature check if implemented
		# TODO: Add FOV check? Original heat seekers might not have strict FOV for re-acquisition

		# Check distance
		var dist_sq = global_position.distance_squared_to(potential_target.global_position)
		if dist_sq < min_dist_sq:
			# TODO: Add visibility/sensor checks (stealth, nebula)
			min_dist_sq = dist_sq
			best_target = potential_target

	if is_instance_valid(best_target):
		print("Missile re-acquired heat target: ", best_target.name)
		target_node = best_target
		target_signature = best_target.get_instance_id() # Or persistent signature
		target_subsystem = null # Heat seekers usually target CoM
		is_homing_active = true # Resume homing
		# Reset ignore/chase state for countermeasures? Optional.
		# _cm_chase_signature = -1
		# _cm_ignore_signatures.clear()
