extends Node

## Mock WCSObject for performance testing

var object_type: int = 1  # Generic object type
var creation_time: float
var memory_footprint: int = 1024 * 100  # 100KB

func _init() -> void:
	creation_time = Time.get_time_dict_from_system()["unix"]

func get_object_type() -> int:
	return object_type

func get_creation_time() -> float:
	return creation_time

func get_memory_footprint() -> int:
	return memory_footprint

func is_marked_for_destruction() -> bool:
	return false

func cleanup() -> void:
	queue_free()