extends RigidBody3D

## Mock ship script for collision response testing

var shield_strength: Array[float] = [100.0, 100.0, 100.0, 100.0]
var max_shield_strength: Array[float] = [100.0, 100.0, 100.0, 100.0]
var current_health: float = 500.0
var max_health: float = 500.0

func get_object_type() -> int:
	return get_meta("object_type", 1)

func get_shield_quadrant(hit_position: Vector3) -> int:
	var local_pos = to_local(hit_position)
	if local_pos.z > 0:
		return 0 if local_pos.x > 0 else 1
	else:
		return 2 if local_pos.x > 0 else 3

func get_shield_strength(quadrant: int) -> float:
	if quadrant >= 0 and quadrant < shield_strength.size():
		return shield_strength[quadrant]
	return 0.0

func get_max_shield_strength(quadrant: int) -> float:
	if quadrant >= 0 and quadrant < max_shield_strength.size():
		return max_shield_strength[quadrant]
	return 100.0

func apply_shield_damage(damage: float, quadrant: int):
	if quadrant >= 0 and quadrant < shield_strength.size():
		shield_strength[quadrant] = maxf(0.0, shield_strength[quadrant] - damage)

func apply_hull_damage(damage: float):
	current_health = maxf(0.0, current_health - damage)

func apply_collision_damage(damage: float):
	apply_hull_damage(damage)