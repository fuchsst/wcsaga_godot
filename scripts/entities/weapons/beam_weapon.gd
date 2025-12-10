## Beam Weapon - Complete Implementation
## Continuous-fire weapon that casts a ray/beam at targets
## Based on base_weapon.gd and missile_weapon.gd patterns

class_name BeamWeapon
extends Node3D

# Signals (gdlint requires signals before constants)
signal beam_started
signal beam_stopped
signal beam_hit(target: Node3D, position: Vector3)

# Dependencies
const WCSWeaponData = preload("res://scripts/resources/weapons/weapon_data.gd")

# Configuration
@export var weapon_data: WCSWeaponData

# State
var fired_by: Node3D
var is_firing: bool = false
var is_warming_up: bool = false
var is_cooling_down: bool = false
var warmup_progress: float = 0.0
var cooldown_progress: float = 0.0
var fire_duration: float = 0.0
var team: int = 0

# Beam Geometry
var beam_mesh: MeshInstance3D
var beam_material: StandardMaterial3D
var current_hit_point: Vector3 = Vector3.ZERO
var current_hit_object: Node3D = null
var current_beam_length: float = 0.0

# Lighting
var tube_lights: Array = []  # Array[OmniLight3D]
var environment_manager: Node = null

# Audio
var audio_player: AudioStreamPlayer3D

# ==============================================================================
# LIFECYCLE
# ==============================================================================


func _ready() -> void:
	set_process(false)  # Only process when firing

	if weapon_data:
		_setup_visuals()
		_setup_audio()
	else:
		push_warning("BeamWeapon initialized without WeaponData!")

	# Find environment manager for lighting
	environment_manager = get_tree().get_first_node_in_group("environment_managers")
	if not environment_manager:
		# Try autoload
		if Engine.has_singleton("EnvironmentManager"):
			environment_manager = Engine.get_singleton("EnvironmentManager")


func setup(shooter: Node3D, turret_node: Node3D = null) -> void:
	fired_by = shooter

	if "team" in shooter:
		team = shooter.team

	# Attach to turret or mount point
	if turret_node:
		if get_parent():
			get_parent().remove_child(self)
		turret_node.add_child(self)
		transform = Transform3D.IDENTITY


# ==============================================================================
# FIRING CONTROL
# ==============================================================================


func fire() -> void:
	if is_firing or is_warming_up or is_cooling_down:
		return

	# Check energy availability
	if fired_by and fired_by.has_method("consume_weapon_energy"):
		if not fired_by.consume_weapon_energy(weapon_data.energy_consumed * 0.1):
			return  # Not enough energy for initial trigger

	# Start warmup if weapon has warmup time
	var warmup_time := _get_warmup_time()
	if warmup_time > 0.0:
		is_warming_up = true
		warmup_progress = 0.0
		visible = true
		set_process(true)
		_start_warmup_effects()
	else:
		_start_firing()


func stop_fire() -> void:
	if not is_firing and not is_warming_up:
		return

	if is_warming_up:
		# Cancel warmup
		is_warming_up = false
		warmup_progress = 0.0
		set_process(false)
		visible = false
		return

	if is_firing:
		# Start cooldown
		is_firing = false
		is_cooling_down = true
		cooldown_progress = 0.0
		_stop_firing_effects()


func _start_firing() -> void:
	is_warming_up = false
	is_firing = true
	fire_duration = 0.0
	visible = true
	set_process(true)

	_create_tube_lighting()
	_start_beam_audio()

	beam_started.emit()


func _stop_firing() -> void:
	is_firing = false
	is_cooling_down = false
	visible = false
	set_process(false)

	_cleanup_tube_lighting()
	_stop_beam_audio()

	beam_stopped.emit()


# ==============================================================================
# PROCESS
# ==============================================================================


func _process(delta: float) -> void:
	if is_warming_up:
		_process_warmup(delta)
	elif is_firing:
		_process_firing(delta)
	elif is_cooling_down:
		_process_cooldown(delta)


func _process_warmup(delta: float) -> void:
	var warmup_time := _get_warmup_time()
	warmup_progress += delta

	# Update warmup visual (beam grows in intensity/size)
	var progress_ratio := clampf(warmup_progress / warmup_time, 0.0, 1.0)
	_update_warmup_visual(progress_ratio)

	if warmup_progress >= warmup_time:
		_start_firing()


func _process_firing(delta: float) -> void:
	fire_duration += delta

	# Energy consumption
	if fired_by and fired_by.has_method("consume_weapon_energy"):
		var energy_per_second: float = weapon_data.energy_per_shot if weapon_data else 1.0
		if not fired_by.consume_weapon_energy(energy_per_second * delta):
			stop_fire()  # Out of energy
			return

	# Check max fire duration
	var max_duration := _get_max_fire_duration()
	if max_duration > 0.0 and fire_duration >= max_duration:
		stop_fire()
		return

	# Perform beam raycast
	_perform_beam_raycast()

	# Update visuals
	_update_beam_visual()

	# Apply continuous damage
	if current_hit_object and is_instance_valid(current_hit_object):
		_apply_continuous_damage(current_hit_object, delta)

	# Update tube lighting positions
	_update_tube_lighting()


func _process_cooldown(delta: float) -> void:
	var cooldown_time := _get_cooldown_time()
	cooldown_progress += delta

	# Update cooldown visual (beam fades)
	var progress_ratio := clampf(cooldown_progress / cooldown_time, 0.0, 1.0)
	_update_cooldown_visual(1.0 - progress_ratio)

	if cooldown_progress >= cooldown_time:
		_stop_firing()


# ==============================================================================
# BEAM MECHANICS
# ==============================================================================


func _perform_beam_raycast() -> void:
	var max_len := weapon_data.weapon_range_meters if weapon_data else 1000.0
	var cast_to := Vector3(0, 0, -max_len)

	# Perform raycast
	var space_state := get_world_3d().direct_space_state
	var from := global_position
	var to := global_transform * cast_to

	var query := PhysicsRayQueryParameters3D.create(from, to)
	if fired_by:
		query.exclude = [fired_by.get_rid()]

	# Setup collision mask for beam
	if CollisionManager:
		query.collision_mask = CollisionManager.get_collision_mask("beam", "")

	var result := space_state.intersect_ray(query)

	if result:
		current_hit_point = result.position
		current_hit_object = result.collider
		current_beam_length = global_position.distance_to(current_hit_point)
		beam_hit.emit(current_hit_object, current_hit_point)
	else:
		current_hit_point = to
		current_hit_object = null
		current_beam_length = max_len


func _apply_continuous_damage(target: Node3D, delta: float) -> void:
	if not weapon_data:
		return

	# Calculate DPS-based damage
	var damage_per_second: float = (
		weapon_data.base_damage_energy if weapon_data.base_damage_energy > 0 else 10.0
	)
	var damage_this_frame: float = damage_per_second * delta

	# Apply damage
	if target.has_method("take_damage"):
		var damage_info := {
			"damage": damage_this_frame,
			"damage_type": weapon_data.damage_type if weapon_data.damage_type else "beam",
			"impact_point": current_hit_point,
			"impact_normal": (global_position - current_hit_point).normalized(),
			"continuous": true
		}

		# Add subsystem targeting if specified
		if weapon_data.flags & WeaponData.WeaponFlags.PUNCTURE:
			damage_info["puncture"] = true

		target.take_damage(damage_info, fired_by)


# ==============================================================================
# VISUALS
# ==============================================================================


func _setup_visuals() -> void:
	# Create beam mesh (elongated quad or cylinder)
	beam_mesh = MeshInstance3D.new()
	beam_mesh.name = "BeamMesh"

	# Use cylinder mesh for beam
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = (
		weapon_data.laser_head_radius if weapon_data and weapon_data.laser_head_radius > 0 else 0.1
	)
	cylinder.bottom_radius = cylinder.top_radius
	cylinder.height = 1.0  # Will be scaled by beam length
	beam_mesh.mesh = cylinder

	# Setup material
	beam_material = StandardMaterial3D.new()
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = (
		weapon_data.laser_color if weapon_data and weapon_data.laser_color else Color.RED
	)

	# Add glow
	beam_material.emission_enabled = true
	beam_material.emission = beam_material.albedo_color
	beam_material.emission_energy_multiplier = 3.0

	beam_mesh.material_override = beam_material
	beam_mesh.visible = false

	add_child(beam_mesh)


func _update_beam_visual() -> void:
	if not beam_mesh:
		return

	# Scale and position the beam mesh
	var half_length := current_beam_length * 0.5
	beam_mesh.scale = Vector3(1, current_beam_length, 1)
	beam_mesh.position = Vector3(0, 0, -half_length)
	beam_mesh.rotation_degrees = Vector3(90, 0, 0)  # Align with Z axis
	beam_mesh.visible = true


func _update_warmup_visual(progress: float) -> void:
	if not beam_mesh or not beam_material:
		return

	beam_mesh.visible = true
	beam_material.albedo_color.a = progress * 0.5
	beam_material.emission_energy_multiplier = 1.0 + progress * 2.0

	# Scale beam during warmup
	var preview_length := (
		(weapon_data.weapon_range_meters if weapon_data else 100.0) * progress * 0.3
	)
	beam_mesh.scale = Vector3(progress, preview_length, progress)
	beam_mesh.position = Vector3(0, 0, -preview_length * 0.5)


func _update_cooldown_visual(intensity: float) -> void:
	if not beam_mesh or not beam_material:
		return

	beam_material.albedo_color.a = intensity
	beam_material.emission_energy_multiplier = intensity * 3.0


func _start_warmup_effects() -> void:
	# Placeholder for particle effects during warmup
	pass


func _stop_firing_effects() -> void:
	# Placeholder for effects when beam stops
	pass


# ==============================================================================
# LIGHTING
# ==============================================================================


func _create_tube_lighting() -> void:
	if not environment_manager or not environment_manager.has_method("add_tube_light"):
		return

	var color := weapon_data.laser_color if weapon_data and weapon_data.laser_color else Color.RED
	var energy := 2.0
	var radius := 10.0

	tube_lights = environment_manager.add_tube_light(
		global_position,
		(
			current_hit_point
			if current_hit_point != Vector3.ZERO
			else global_position + Vector3(0, 0, -100)
		),
		color,
		energy,
		radius,
		null,  # affected_object
		true  # apply_wcs_factor
	)


func _update_tube_lighting() -> void:
	if tube_lights.is_empty():
		return

	# Update light positions based on beam start/end
	if tube_lights.size() >= 1:
		tube_lights[0].global_position = global_position

	if tube_lights.size() >= 2:
		tube_lights[1].global_position = current_hit_point

	if tube_lights.size() >= 3:
		tube_lights[2].global_position = (global_position + current_hit_point) * 0.5


func _cleanup_tube_lighting() -> void:
	if not environment_manager:
		return

	for light in tube_lights:
		if is_instance_valid(light) and environment_manager.has_method("remove_point_light"):
			environment_manager.remove_point_light(light)

	tube_lights.clear()


# ==============================================================================
# AUDIO
# ==============================================================================


func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "BeamAudio"
	audio_player.bus = "SFX"
	audio_player.unit_size = 20.0
	audio_player.max_distance = 500.0
	add_child(audio_player)


func _start_beam_audio() -> void:
	if not audio_player:
		return

	# Load beam sound from weapon data if available
	if weapon_data and weapon_data.fire_sound:
		audio_player.stream = (
			weapon_data.fire_sound if weapon_data.fire_sound is AudioStream else null
		)
		if audio_player.stream:
			audio_player.play()


func _stop_beam_audio() -> void:
	if audio_player and audio_player.playing:
		audio_player.stop()


# ==============================================================================
# HELPER METHODS
# ==============================================================================


func _get_warmup_time() -> float:
	# BeamWeaponInfo in legacy has warmup_snd which implies warmup time
	# For now use a default based on weapon type
	return 0.25 if weapon_data else 0.0


func _get_cooldown_time() -> float:
	return 0.15 if weapon_data else 0.0


func _get_max_fire_duration() -> float:
	# Legacy beams often had limited fire duration
	return weapon_data.lifetime if weapon_data and weapon_data.lifetime > 0 else 5.0


func get_beam_range() -> float:
	return weapon_data.weapon_range_meters if weapon_data else 1000.0


func is_beam_active() -> bool:
	return is_firing
