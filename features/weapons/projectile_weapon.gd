class_name ProjectileWeapon
extends BaseWeapon

func _handle_movement(step: Vector3) -> void:
	# Raycast for high speed collision detection
	var params = PhysicsRayQueryParameters3D.create(global_position, global_position + step)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	# Exclude shooter
	if fired_by:
		params.exclude = [fired_by.get_rid()]
		
	var result = get_world_3d().direct_space_state.intersect_ray(params)
	
	if result:
		global_position = result.position
		_detonate(result.collider)
	else:
		global_position += step
