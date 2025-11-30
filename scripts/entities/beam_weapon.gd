class_name BeamWeapon
extends Node3D

# Beam weapon entity
# Beams are different from projectiles; they are instantaneous (or near-instant) rays that persist

@export var weapon_data: WCSWeaponData
@export var fired_by: Node3D

var is_firing: bool = false
var duration: float = 0.0
var current_time: float = 0.0

# Visuals
var beam_mesh: MeshInstance3D

func _ready():
	if weapon_data:
		duration = weapon_data.beam_config.beam_life if weapon_data.beam_config else 1.0
		_setup_visuals()

func _process(delta: float):
	if is_firing:
		current_time += delta
		if current_time >= duration:
			stop_firing()
		else:
			_update_beam(delta)

func fire(from: Vector3, direction: Vector3):
	is_firing = true
	current_time = 0.0
	global_position = from
	look_at(from + direction, Vector3.UP)
	visible = true
	
	# Initial hit check
	_check_collision()

func stop_firing():
	is_firing = false
	visible = false
	queue_free()

func _update_beam(delta: float):
	# Update beam width/intensity based on warmup/warmdown
	pass

func _check_collision():
	var space_state = get_world_3d().direct_space_state
	var end_point = global_position - global_transform.basis.z * weapon_data.effective_range_meters
	var query = PhysicsRayQueryParameters3D.create(global_position, end_point)
	
	if fired_by:
		query.exclude = [fired_by.get_rid()]
		
	var result = space_state.intersect_ray(query)
	if result:
		_apply_damage(result.collider, result.position, delta_time_for_damage())

func delta_time_for_damage() -> float:
	# Beams apply damage over time, usually per frame
	return get_process_delta_time()

func _apply_damage(collider: Node3D, position: Vector3, dt: float):
	if collider.has_method("take_damage") and weapon_data:
		# Beam damage is usually per second, so scale by dt
		var damage_info = weapon_data.calculate_damage_against_target(
			"unknown",
			100.0,
			100.0,
			collider.to_local(position),
			0.0,
			0.0
		)
		# Scale damage
		damage_info["total_damage"] *= dt
		# ... scale other components ...
		
		collider.take_damage(damage_info)

func _setup_visuals():
	# Create cylinder or quad chain for beam
	pass
