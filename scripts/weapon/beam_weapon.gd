extends WeaponInstance
class_name BeamWeapon

# Beam specific properties from WeaponData
var beam_info: Dictionary = {} # Parsed from WeaponData.tres -> beam_info dictionary
var beam_type: int = GlobalConstants.BEAM_TYPE_A
var beam_life: float = 1.0
var beam_warmup_time_ms: int = 0 # ms
var beam_warmdown_time_ms: int = 0 # ms
var beam_muzzle_radius: float = 1.0
var beam_shots: int = 1
var beam_range: float = 1000.0
var beam_damage_threshold: float = 1.0 # Attenuation factor
var beam_width: float = 1.0

# Runtime state
var is_firing: bool = false
var current_target_node: Node3D = null # Renamed from current_target to avoid conflict
var warmup_timer: float = 0.0
var warmdown_timer: float = 0.0
var fire_timer: float = 0.0
var damage_timer: float = 0.0
const BEAM_DAMAGE_INTERVAL = 0.17 # How often to apply damage (seconds)

@onready var ray_cast: RayCast3D = $RayCast3D # Assuming a RayCast3D child node for hit detection
var beam_visual_node: Node3D = null # Placeholder for the visual effect node

# TODO: Add nodes for beam visuals (e.g., MeshInstance3D with custom shader or ImmediateMesh)
# Need a way to dynamically update the visual based on hit point.

func _ready():
	super._ready() # Call base class ready
	# Ensure necessary child nodes exist
	if not has_node("RayCast3D"):
		ray_cast = RayCast3D.new()
		ray_cast.name = "RayCast3D"
		add_child(ray_cast)
		print("BeamWeapon: Added missing RayCast3D node.")
	else:
		ray_cast = get_node("RayCast3D")

	# Load beam properties from weapon_data
	if weapon_data and weapon_data.has("beam_info"):
		beam_info = weapon_data.beam_info
		beam_type = beam_info.get("type", GlobalConstants.BEAM_TYPE_A) # Use get() with default
		beam_life = beam_info.get("life", 1.0)
		beam_warmup_time_ms = beam_info.get("warmup", 0)
		beam_warmdown_time_ms = beam_info.get("warmdown", 0)
		beam_muzzle_radius = beam_info.get("muzzle_radius", 1.0)
		beam_shots = beam_info.get("shots", 1) # TODO: Implement multi-shot logic if needed
		beam_range = beam_info.get("range", 1000.0)
		beam_damage_threshold = beam_info.get("damage_threshold", 1.0)
		beam_width = beam_info.get("width", 1.0) # Use beam_width from weapon_data if available
		ray_cast.target_position = Vector3(0, 0, -beam_range) # Set raycast length
		ray_cast.collision_mask = GlobalConstants.COLLISION_MASK_BEAM # Set appropriate collision mask
		ray_cast.collide_with_areas = true # Beams might hit shields (Area3D)
		ray_cast.collide_with_bodies = true
		# TODO: Load particle/glow/section info if available in beam_info
	else:
		printerr("BeamWeapon: Missing or invalid beam_info in WeaponData!")
		# Set default range even if info is missing
		ray_cast.target_position = Vector3(0, 0, -1000.0) # Default range if info missing


func _physics_process(delta):
	# Base class cooldown handling
	if not is_ready and cooldown_timer <= 0.0:
		is_ready = true
		emit_signal("ready_to_fire")
	elif cooldown_timer > 0.0:
		cooldown_timer -= delta

	# Update beam position/direction based on hardpoint
	if is_instance_valid(hardpoint_node):
		global_transform = hardpoint_node.global_transform
	else:
		printerr("BeamWeapon: Invalid hardpoint_node!")
		stop_firing() # Stop if hardpoint is gone
		return

	# --- Beam State Machine ---
	if is_firing:
		fire_timer -= delta
		damage_timer -= delta

		if fire_timer <= 0:
			stop_firing()
			return

		# Perform raycast
		ray_cast.force_raycast_update()

		var hit_point = global_position + global_transform.basis.z * -beam_range # Default end point
		var hit_something = false
		var hit_collider = null

		if ray_cast.is_colliding():
			hit_collider = ray_cast.get_collider()
			# Ensure we don't hit the owner ship immediately after firing
			if hit_collider != owner_ship or time_since_creation > 0.1:
				hit_point = ray_cast.get_collision_point()
				var hit_normal = ray_cast.get_collision_normal()
				hit_something = true

				# Apply damage periodically
				if damage_timer <= 0 and is_instance_valid(hit_collider):
					apply_beam_damage(hit_collider, hit_point, hit_normal)
					damage_timer = BEAM_DAMAGE_INTERVAL # Reset damage timer
			else:
				# Hit owner ship too soon, ignore collision for now
				hit_collider = null # Prevent damage application

		# Update beam visual effect
		_update_beam_visual(global_position, hit_point)

		# TODO: Handle beam energy consumption via WeaponSystem (per tick)
		# if is_instance_valid(weapon_system) and weapon_data:
		#	var energy_cost_per_second = weapon_data.energy_consumed / weapon_data.fire_wait # Estimate cost per second
		#	weapon_system.ship_base.weapon_energy -= energy_cost_per_second * delta
		#	if weapon_system.ship_base.weapon_energy < 0: weapon_system.ship_base.weapon_energy = 0
		#	weapon_system.emit_signal("energy_updated")

	elif warmup_timer > 0:
		warmup_timer -= delta
		# TODO: Update warmup visual/audio effects based on warmup_timer progress
		_update_warmup_visual(warmup_timer / (float(beam_warmup_time_ms) / 1000.0))
		if warmup_timer <= 0:
			start_beam_fire()
			# TODO: Play beam firing sound loop (SND_BEAM_LOOP)

	elif warmdown_timer > 0:
		warmdown_timer -= delta
		# TODO: Update warmdown visual/audio effects based on warmdown_timer progress
		_update_warmdown_visual(warmdown_timer / (float(beam_warmdown_time_ms) / 1000.0))
		if warmdown_timer <= 0:
			# Beam cycle finished
			_finish_beam_cycle()

	# Update time since creation for arming checks
	time_since_creation += delta


# Override base fire method
func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	if not is_ready: # Check base class cooldown/readiness
		#print("Beam not ready (cooldown)")
		return false

	if is_firing or warmup_timer > 0 or warmdown_timer > 0:
		#print("Beam already in firing cycle")
		return false # Already in a firing cycle

	# TODO: Check energy via WeaponSystem
	# if weapon_system and weapon_system.ship_base.weapon_energy < weapon_data.energy_consumed:
	#     print("Beam out of energy")
	#     return false

	current_target_node = target # Store target if needed for specific beam types
	# is_active = true # Use is_ready, is_firing, warmup/warmdown timers instead
	time_since_creation = 0.0 # Reset arming timer

	if beam_warmup_time_ms > 0:
		warmup_timer = float(beam_warmup_time_ms) / 1000.0
		# TODO: Start warmup visual/audio effects (SND_BEAM_WARMUP)
		print("Beam warming up...")
	else:
		start_beam_fire()
		# TODO: Play beam firing sound loop (SND_BEAM_LOOP)

	# Consume energy/ammo immediately? Or per tick during firing? FS2 likely consumes per tick/shot.
	# weapon_system.consume_ammo(bank_index, 1) # Placeholder

	# Set base class cooldown (even though beam has its own cycle)
	is_ready = false
	cooldown_timer = weapon_data.fire_wait if weapon_data else 1.0 # Use fire_wait as minimum time between beam activations

	emit_signal("fired", null, global_position, -global_transform.basis.z) # Emit base signal
	return true

func start_beam_fire():
	is_firing = true
	warmup_timer = 0.0 # Ensure warmup is finished
	fire_timer = beam_life
	damage_timer = 0 # Apply damage immediately on first frame
	# TODO: Start beam visual effect
	# TODO: Play beam firing sound loop (SND_BEAM_LOOP)
	print("Beam firing!")

func stop_firing():
	if not is_firing: return # Already stopping or stopped

	is_firing = false
	fire_timer = 0.0
	# TODO: Stop beam visual effect (or transition to warmdown)
	_stop_beam_visual()
	# TODO: Stop beam firing sound loop

	if beam_warmdown_time_ms > 0:
		warmdown_timer = float(beam_warmdown_time_ms) / 1000.0
		# TODO: Start warmdown visual/audio effects (SND_BEAM_WARMDOWN)
		print("Beam warming down...")
	else:
		# No warmdown, finish immediately and start cooldown
		_finish_beam_cycle()
		print("Beam finished (no warmdown)")

func _finish_beam_cycle():
	warmdown_timer = 0.0
	is_ready = false # Set cooldown based on fire_wait
	cooldown_timer = weapon_data.fire_wait if weapon_data else 1.0
	# TODO: Stop beam visual effect completely
	_stop_beam_visual()
	# TODO: Stop beam firing sound loop

func apply_beam_damage(collider: Node, hit_point: Vector3, hit_normal: Vector3):
	if not weapon_data: return

	# Calculate damage based on beam type, distance, attenuation etc.
	var damage_per_tick = weapon_data.damage * BEAM_DAMAGE_INTERVAL
	var attenuation = 1.0

	# Apply attenuation if threshold is set and distance is beyond threshold
	# beam_damage_threshold is a percentage (0.0 to 1.0) of the beam_range where damage starts to fall off.
	if beam_damage_threshold > 0.0 and beam_damage_threshold < 1.0:
		var hit_distance = global_position.distance_to(hit_point)
		var attenuation_start_dist = beam_range * beam_damage_threshold
		if hit_distance > attenuation_start_dist and beam_range > attenuation_start_dist: # Avoid division by zero
			# Linear falloff from full damage at attenuation_start_dist to zero damage at beam_range
			attenuation = 1.0 - (hit_distance - attenuation_start_dist) / (beam_range - attenuation_start_dist)
			attenuation = clamp(attenuation, 0.0, 1.0) # Ensure attenuation is between 0 and 1

	damage_per_tick *= attenuation

	# Check if collider is a valid target (ship, asteroid, etc.)
	if collider is ShipBase:
		var damage_system = collider.get_node_or_null("DamageSystem")
		if damage_system:
			var killer_id = owner_ship.get_instance_id() if is_instance_valid(owner_ship) else -1
			# TODO: Determine hit subsystem based on hit_point relative to collider's model
			var hit_subsystem_node = null # Placeholder
			damage_system.apply_local_damage(hit_point, damage_per_tick, killer_id, weapon_data.damage_type_idx, hit_subsystem_node)
			# TODO: Trigger impact effects (visual/audio) at hit_point (SND_BEAM_HIT_*)
			# EffectManager.create_beam_impact(hit_point, hit_normal)
			print("Beam hit ship: ", collider.name)
		else:
			printerr("Beam hit ShipBase without DamageSystem: ", collider.name)
	elif collider.has_method("take_damage"): # Check for asteroids, debris etc.
		# Assuming a simple take_damage(amount) method for now
		collider.take_damage(damage_per_tick)
		# TODO: Trigger generic impact effect
		print("Beam hit other object: ", collider.name)
	# else: Hit something that doesn't take damage (e.g., station part?)

# Override base class _is_armed as beams are typically always "armed"
func _is_armed() -> bool:
	return true

# Override base class _expire as beams don't expire based on lifetime_timer
func _expire():
	# Beams stop based on fire_timer or external factors, not lifetime.
	# If stop_firing wasn't called, ensure cleanup.
	if is_firing or warmup_timer > 0 or warmdown_timer > 0:
		print("Beam forcefully expired/cleaned up.")
		is_firing = false
		warmup_timer = 0.0
		warmdown_timer = 0.0
		# TODO: Ensure visuals/sounds are stopped
		_stop_beam_visual()
	# Beams don't queue_free themselves, they are managed by the WeaponSystem/Ship
	pass

# --- Visual Effect Stubs ---
func _update_beam_visual(start_pos: Vector3, end_pos: Vector3):
	# TODO: Implement logic to update the beam visual (e.g., scale/orient a MeshInstance)
	# This needs a reference to the actual visual node (beam_visual_node)
	pass

func _update_warmup_visual(progress: float):
	# TODO: Implement visual feedback for warmup (e.g., change color/intensity)
	pass

func _update_warmdown_visual(progress: float):
	# TODO: Implement visual feedback for warmdown (e.g., fade out)
	pass

func _stop_beam_visual():
	# TODO: Hide or stop the beam visual effect node
	if is_instance_valid(beam_visual_node):
		beam_visual_node.visible = false
	pass
