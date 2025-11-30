class_name BeamWeapon
extends Node3D

# Beam weapon entity (continuous ray/cylinder)

signal hit_target(target, damage_info)
signal expired

@export var weapon_data: WCSWeaponData
var shooter: Node3D
var is_firing: bool = false
var current_time: float = 0.0
var beam_raycast: RayCast3D
var beam_mesh: MeshInstance3D


func initialize(data: WCSWeaponData, source: Node3D) -> void:
	weapon_data = data
	shooter = source

	_setup_visuals()
	_setup_physics()


func _ready() -> void:
	set_physics_process(false)


func fire() -> void:
	is_firing = true
	current_time = 0.0
	visible = true
	set_physics_process(true)
	if beam_raycast:
		beam_raycast.enabled = true


func stop_fire() -> void:
	is_firing = false
	visible = false
	set_physics_process(false)
	if beam_raycast:
		beam_raycast.enabled = false
	expire()


func _physics_process(delta: float) -> void:
	if not is_firing:
		return

	current_time += delta
	if current_time > weapon_data.beam_config.beam_life:
		stop_fire()
		return

	# Update beam visual (pulsing, growing/shrinking)
	_update_beam_visuals(delta)

	# Check collision
	if beam_raycast.is_colliding():
		var collider = beam_raycast.get_collider()
		var point = beam_raycast.get_collision_point()
		_apply_continuous_damage(collider, point, delta)


func _setup_visuals() -> void:
	# Create beam mesh (cylinder)
	beam_mesh = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = weapon_data.beam_config.beam_width / 2.0
	mesh.bottom_radius = weapon_data.beam_config.beam_width / 2.0
	mesh.height = weapon_data.effective_range_meters
	beam_mesh.mesh = mesh

	# Rotate to point forward (-Z)
	beam_mesh.rotation_degrees.x = 90
	beam_mesh.position.z = -mesh.height / 2.0

	# Material
	var material = StandardMaterial3D.new()
	material.albedo_color = weapon_data.beam_config.beam_color
	material.emission_enabled = true
	material.emission = weapon_data.beam_config.beam_color
	material.emission_energy_multiplier = weapon_data.beam_config.beam_glow_factor
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mesh.material_override = material

	add_child(beam_mesh)


func _setup_physics() -> void:
	beam_raycast = RayCast3D.new()
	beam_raycast.target_position = Vector3(0, 0, -weapon_data.effective_range_meters)
	beam_raycast.enabled = false  # Enable only when firing
	add_child(beam_raycast)


func _update_beam_visuals(delta: float) -> void:
	# Handle warmup/warmdown width changes
	var life = weapon_data.beam_config.beam_life
	var warmup = weapon_data.beam_config.beam_warmup
	var warmdown = weapon_data.beam_config.beam_warmdown

	var width_scale = 1.0
	if current_time < warmup:
		width_scale = current_time / warmup
	elif current_time > (life - warmdown):
		width_scale = (life - current_time) / warmdown

	beam_mesh.scale.x = width_scale
	beam_mesh.scale.y = width_scale


func _apply_continuous_damage(target: Node3D, point: Vector3, delta: float) -> void:
	# Calculate damage per tick
	var dps = weapon_data.get_damage_per_second()
	var damage_this_tick = dps * delta

	# Create a temporary modified weapon data for this tick?
	# Or just manually calculate

	# For now, simplistic damage application
	if target.has_method("take_damage"):
		# We need to construct a damage info dict similar to WeaponData.calculate_damage...
		# But scaled by delta
		var damage_info = {"total_damage": damage_this_tick, "damage_type": "beam", "point": point}
		target.take_damage(damage_info)
		hit_target.emit(target, damage_info)


func expire() -> void:
	expired.emit()
	queue_free()
