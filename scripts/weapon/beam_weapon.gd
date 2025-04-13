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

# Visual Effect Setup
@export var beam_visual_scene: PackedScene = preload("res://scenes/effects/beam_effect.tscn")
var beam_visual_node: Node3D = null # Instantiated visual effect node
var beam_material: ShaderMaterial = null # Reference to the shader material
var _beam_loop_sound_player: AudioStreamPlayer3D = null # Node instance for the looping sound

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
	if weapon_data and weapon_data.beam_info: # Check beam_info directly
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

	# Instantiate and setup visual effect node
	if beam_visual_scene:
		beam_visual_node = beam_visual_scene.instantiate()
		add_child(beam_visual_node)
		# Find the MeshInstance3D and get its material
		# Assume the material is on the MeshInstance3D itself or its surface 0
		var mesh_instance = beam_visual_node.find_child("BeamMesh", true, false) as MeshInstance3D
		if mesh_instance:
			var mat = mesh_instance.get_active_material(0)
			if mat is ShaderMaterial:
				beam_material = mat.duplicate() # Duplicate to avoid modifying shared resource
				mesh_instance.set_surface_override_material(0, beam_material) # Apply the duplicated material
			else:
				printerr("BeamWeapon: BeamMesh material is not a ShaderMaterial!")
		else:
			printerr("BeamWeapon: Could not find 'BeamMesh' node in beam_visual_scene!")

		if is_instance_valid(beam_visual_node):
			beam_visual_node.visible = false # Start hidden
	else:
		printerr("BeamWeapon: beam_visual_scene not set!")

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

		# Handle beam energy consumption via WeaponSystem (per tick)
		if is_instance_valid(weapon_system) and weapon_data:
			# Calculate energy cost per second (assuming energy_consumed is per shot/activation)
			# If beam_life is the duration, cost per second is energy_consumed / beam_life
			var energy_cost_per_second = weapon_data.energy_consumed / beam_life if beam_life > 0 else weapon_data.energy_consumed
			var energy_consumed_this_frame = energy_cost_per_second * delta
			if not weapon_system.consume_energy(energy_consumed_this_frame):
				print("BeamWeapon: Out of energy!")
				stop_firing() # Stop firing if out of energy
				return

	elif warmup_timer > 0:
		warmup_timer -= delta
		# Update warmup visual effects based on warmup_timer progress
		_update_warmup_visual(1.0 - (warmup_timer / (float(beam_warmup_time_ms) / 1000.0))) # Progress 0 to 1
		if warmup_timer <= 0:
			start_beam_fire()

	elif warmdown_timer > 0:
		warmdown_timer -= delta
		# Update warmdown visual effects based on warmdown_timer progress
		_update_warmdown_visual(warmdown_timer / (float(beam_warmdown_time_ms) / 1000.0)) # Progress 1 to 0
		if warmdown_timer <= 0:
			# Beam cycle finished
			_finish_beam_cycle()

	# Update time since creation for arming checks (handled by base class?)
	# time_since_creation += delta # Assuming base class handles this if needed


# Override base fire method
func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	if not is_ready: # Check base class cooldown/readiness
		#print("Beam not ready (cooldown)")
		return false

	if is_firing or warmup_timer > 0 or warmdown_timer > 0:
		#print("Beam already in firing cycle")
		return false # Already in a firing cycle

	# Check energy via WeaponSystem
	if not weapon_system or not weapon_system.has_enough_energy(weapon_data.energy_consumed):
		print("BeamWeapon: Out of energy to start firing.")
		# TODO: Play out of ammo sound?
		return false

	current_target_node = target # Store target if needed for specific beam types
	# time_since_creation = 0.0 # Reset arming timer (Handled by base class?)

	if beam_warmup_time_ms > 0:
		warmup_timer = float(beam_warmup_time_ms) / 1000.0
		# Start warmup visual/audio effects
		_play_sound(weapon_data.b_info.get("warmup_sound", -1))
		_update_warmup_visual(0.0) # Start visual at 0 progress
		print("Beam warming up...")
	else:
		# No warmup, start firing immediately
		start_beam_fire()

	# Consume initial energy cost? Or only per tick? Assume per tick for now.
	# weapon_system.consume_energy(weapon_data.energy_consumed) # Consume initial cost if applicable

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
	# Start beam visual effect
	_update_beam_visual(global_position, global_position + global_transform.basis.z * -beam_range) # Initial visual update
	# Play beam firing sound loop
	_play_sound_loop(weapon_data.b_info.get("loop_sound", -1))
	print("Beam firing!")

func stop_firing():
	if not is_firing: return # Already stopping or stopped

	is_firing = false
	fire_timer = 0.0
	# Stop beam firing sound loop
	_stop_sound_loop()

	if beam_warmdown_time_ms > 0:
		warmdown_timer = float(beam_warmdown_time_ms) / 1000.0
		# Start warmdown visual/audio effects
		_play_sound(weapon_data.b_info.get("warmdown_sound", -1))
		_update_warmdown_visual(1.0) # Start visual at full progress (1.0)
		print("Beam warming down...")
	else:
		# No warmdown, finish immediately and start cooldown
		_finish_beam_cycle()
		print("Beam finished (no warmdown)")

func _finish_beam_cycle():
	warmdown_timer = 0.0
	is_ready = false # Set cooldown based on fire_wait
	cooldown_timer = weapon_data.fire_wait if weapon_data else 1.0
	# Stop beam visual effect completely
	_stop_beam_visual()
	# Ensure loop sound is stopped if it wasn't already
	_stop_sound_loop()

func apply_beam_damage(collider: Node, hit_point: Vector3, hit_normal: Vector3):
	if not weapon_data: return

	# Calculate damage based on beam type, distance, attenuation etc.
	var damage_per_tick = weapon_data.damage * BEAM_DAMAGE_INTERVAL
	var attenuation = 1.0

	# Apply attenuation based on distance and damage_threshold
	var hit_distance = global_position.distance_to(hit_point)
	if beam_damage_threshold > 0.0 and beam_damage_threshold < 1.0:
		var attenuation_start_dist = beam_range * beam_damage_threshold
		if hit_distance > attenuation_start_dist and beam_range > attenuation_start_dist: # Avoid division by zero
			# Linear falloff from full damage at attenuation_start_dist to zero damage at beam_range
			attenuation = 1.0 - (hit_distance - attenuation_start_dist) / (beam_range - attenuation_start_dist)
			attenuation = clamp(attenuation, 0.0, 1.0) # Ensure attenuation is between 0 and 1
	damage_per_tick *= attenuation

	# --- IFF Check ---
	var can_damage = true
	if is_instance_valid(owner_ship) and owner_ship.has_method("get_team"):
		var owner_team = owner_ship.get_team()
		var target_team = -1
		if collider.has_method("get_team"):
			target_team = collider.get_team()

		if owner_team != -1 and target_team != -1:
			if Engine.has_singleton("IFFManager"):
				if not IFFManager.iff_can_attack(owner_team, target_team):
					# TODO: Check training exceptions?
					can_damage = false
			else:
				printerr("BeamWeapon: IFFManager not found for damage check.")

	if not can_damage:
		# Play friendly hit sound/effect? For now, just don't apply damage.
		return

	# --- Apply Damage ---
	var owner_id = owner_ship.get_instance_id() if is_instance_valid(owner_ship) else -1
	if collider is ShipBase:
		var damage_system = collider.get_node_or_null("DamageSystem")
		if damage_system:
			# TODO: Determine hit subsystem based on hit_point relative to collider's model
			var hit_subsystem_node = null # Placeholder
			damage_system.apply_local_damage(hit_point, damage_per_tick, owner_id, weapon_data.damage_type_idx, hit_subsystem_node)
			# Trigger impact effects (visual/audio) at hit_point
			_play_sound(weapon_data.impact_snd, hit_point) # Play impact sound at hit location
			if Engine.has_singleton("EffectManager"):
				EffectManager.create_beam_impact(hit_point, hit_normal)
			# print("Beam hit ship: ", collider.name)
		else:
			printerr("Beam hit ShipBase without DamageSystem: ", collider.name)
	elif collider.has_method("take_damage"): # Check for asteroids, debris etc.
		# Assuming a simple take_damage(amount) method for now
		collider.take_damage(damage_per_tick)
		# Trigger generic impact effect
		_play_sound(weapon_data.impact_snd, hit_point)
		if Engine.has_singleton("EffectManager"):
			EffectManager.create_beam_impact(hit_point, hit_normal) # Use beam impact for now
		# print("Beam hit other object: ", collider.name)
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
	if is_instance_valid(beam_visual_node) and beam_material:
		# Update shader uniforms
		beam_material.set_shader_parameter("start_point", start_pos)
		beam_material.set_shader_parameter("end_point", end_pos)
		beam_material.set_shader_parameter("beam_width", beam_width)
		beam_material.set_shader_parameter("intensity", 1.0) # Full intensity while firing
		# TODO: Set texture scroll speed? beam_color?
		# beam_material.set_shader_parameter("texture_scroll_speed", ...)
		# beam_material.set_shader_parameter("beam_color", ...)
		beam_visual_node.visible = true
	elif is_instance_valid(beam_visual_node):
		beam_visual_node.visible = true # Ensure visible even if material setup failed

func _update_warmup_visual(progress: float):
	# Progress goes from 0.0 to 1.0 during warmup
	if is_instance_valid(beam_visual_node) and beam_material:
		beam_material.set_shader_parameter("intensity", progress)
		# Update start/end points even during warmup to keep it positioned
		var end_point = global_position + global_transform.basis.z * -beam_range
		beam_material.set_shader_parameter("start_point", global_position)
		beam_material.set_shader_parameter("end_point", end_point) # Aim straight ahead during warmup
		beam_material.set_shader_parameter("beam_width", beam_width)
		beam_visual_node.visible = true # Show during warmup
	elif is_instance_valid(beam_visual_node):
		beam_visual_node.visible = true

func _update_warmdown_visual(progress: float):
	# Progress goes from 1.0 down to 0.0 during warmdown
	if is_instance_valid(beam_visual_node) and beam_material:
		beam_material.set_shader_parameter("intensity", progress)
		# Keep updating position during warmdown
		var end_point = global_position + global_transform.basis.z * -beam_range # Aim straight
		beam_material.set_shader_parameter("start_point", global_position)
		beam_material.set_shader_parameter("end_point", end_point)
		beam_material.set_shader_parameter("beam_width", beam_width)
		beam_visual_node.visible = true # Keep visible during warmdown
	elif is_instance_valid(beam_visual_node):
		beam_visual_node.visible = true

func _stop_beam_visual():
	if is_instance_valid(beam_visual_node):
		beam_visual_node.visible = false
		if beam_material:
			beam_material.set_shader_parameter("intensity", 0.0) # Ensure intensity is zero

# --- Sound Helpers ---
func _play_sound(sound_sig: int, pos: Vector3 = Vector3.ZERO):
	if sound_sig < 0: return
	if Engine.has_singleton("SoundManager") and Engine.has_singleton("GameSounds"):
		var sound_entry = GameSounds.get_sound_entry_by_sig(sound_sig)
		if sound_entry:
			var play_pos = pos if pos != Vector3.ZERO else global_position
			SoundManager.play_sound_3d(sound_entry.id_name, play_pos)
		else:
			printerr("BeamWeapon: Sound entry not found for signature %d" % sound_sig)
	elif Engine.has_singleton("SoundManager"):
		printerr("BeamWeapon: GameSounds singleton not found.")
		else:
			printerr("BeamWeapon: SoundManager not found.")

func _play_sound_loop(sound_sig: int):
	if sound_sig < 0: return
	# Stop existing loop first
	_stop_sound_loop()

	if Engine.has_singleton("SoundManager") and Engine.has_singleton("GameSounds"):
		var sound_entry = GameSounds.get_sound_entry_by_sig(sound_sig)
		if sound_entry:
			# Assume play_sound_3d returns the player node instance
			var player_node = SoundManager.play_sound_3d(sound_entry.id_name, global_position)
			if player_node is AudioStreamPlayer3D:
				_beam_loop_sound_player = player_node
				# Ensure the stream is set to loop
				if is_instance_valid(_beam_loop_sound_player.stream):
					_beam_loop_sound_player.stream.loop = true
				else:
					printerr("BeamWeapon: Sound stream invalid for looping sound %d" % sound_sig)
					_beam_loop_sound_player = null # Clear invalid player reference
			elif player_node != null: # It returned something, but not the expected type
				printerr("BeamWeapon: SoundManager.play_sound_3d did not return an AudioStreamPlayer3D for looping sound %d" % sound_sig)
			# else: play_sound_3d returned null or -1, error already printed by SoundManager
		else:
			printerr("BeamWeapon: Sound entry not found for loop signature %d" % sound_sig)
	elif Engine.has_singleton("SoundManager"):
		printerr("BeamWeapon: GameSounds singleton not found.")
	else:
		printerr("BeamWeapon: SoundManager not found.")

func _stop_sound_loop():
	if is_instance_valid(_beam_loop_sound_player):
		_beam_loop_sound_player.stop()
		# Optionally return the player to the SoundManager pool if it manages pooling
		# SoundManager.return_player_to_pool(_beam_loop_sound_player)
	_beam_loop_sound_player = null
