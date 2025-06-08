extends Node

## Mock BaseSpaceObject for performance testing

var space_object_type: int = 2  # Space object type
var creation_time: float
var memory_footprint: int = 1024 * 200  # 200KB

func _init() -> void:
	creation_time = Time.get_time_dict_from_system()["unix"]

func get_space_object_type() -> int:
	return space_object_type

func get_creation_time() -> float:
	return creation_time

func get_memory_footprint() -> int:
	return memory_footprint

func is_marked_for_destruction() -> bool:
	return false

func cleanup() -> void:
	queue_free()