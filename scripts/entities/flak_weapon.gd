class_name FlakWeapon
extends "res://scripts/entities/weapon.gd"

# Flak weapon entity
# Detonates near target or at max range

var target_pos: Vector3 = Vector3.ZERO
var detonation_range: float = 100.0
var current_dist: float = 0.0


func initialize(
	data: WCSWeaponData,
	source: Node3D,
	start_pos: Vector3,
	start_rot: Quaternion,
	initial_velocity: Vector3
) -> void:
	super.initialize(data, source, start_pos, start_rot, initial_velocity)

	if weapon_data.flak_config:
		detonation_range = weapon_data.flak_config.target_range
		if weapon_data.flak_config.range_variance > 0:
			detonation_range += randf_range(
				-weapon_data.flak_config.range_variance, weapon_data.flak_config.range_variance
			)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Check for proximity detonation
	# This is a simplified check; ideally we'd check distance to target if we had one locked
	# Or raycast forward to see if we're close to anything

	# For now, just detonate at max range/lifetime if no target
	# But Flak usually detonates NEAR a target.
	# If we have a target (from shooter?), we can check distance.

	pass


func _on_body_entered(body: Node3D) -> void:
	# Direct hit also triggers detonation
	_detonate(body.global_position)
	super._on_body_entered(body)


func expire() -> void:
	_detonate(global_position)
	super.expire()


func _detonate(pos: Vector3) -> void:
	# Spawn explosion effect
	if not weapon_data.flak_config:
		return

	# Apply area damage
	var radius = weapon_data.flak_config.explosion_radius

	# Find all bodies in radius
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform3D(Basis(), pos)

	var results = space_state.intersect_shape(query)

	for result in results:
		var collider = result.collider
		if collider == shooter:
			continue

		if collider.has_method("take_damage"):
			var dist = pos.distance_to(collider.global_position)
			var damage_factor = 1.0
			if weapon_data.flak_config.damage_falloff:
				damage_factor = 1.0 - clamp(dist / radius, 0.0, 1.0)

			var damage_info = {
				"total_damage": weapon_data.explosion_damage * damage_factor,
				"damage_type": "flak",
				"point": pos
			}
			collider.take_damage(damage_info)
