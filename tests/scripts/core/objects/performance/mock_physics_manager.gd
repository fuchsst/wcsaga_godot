extends Node

## Mock PhysicsManager for performance testing

signal physics_step_completed(delta: float)

var physics_body_count: int = 40
var space_physics_body_count: int = 25
var performance_stats: Dictionary = {
	"physics_bodies": 40,
	"space_physics_bodies": 25,
	"collision_pairs": 150,
	"physics_time_ms": 1.5
}

func get_physics_body_count() -> int:
	return physics_body_count

func get_space_physics_body_count() -> int:
	return space_physics_body_count

func get_performance_stats() -> Dictionary:
	return performance_stats

func simulate_physics_step() -> void:
	"""Simulate a physics step for testing."""
	var delta: float = 0.016667  # 60 FPS
	physics_step_completed.emit(delta)