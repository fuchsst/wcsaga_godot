extends Node

## Mock debris object for GC testing

var object_type: int = 5  # Debris type
var creation_time: float
var has_expire_flag_value: bool = true

func _init() -> void:
	creation_time = Time.get_time_dict_from_system()["unix"] - 35.0  # Old debris

func get_object_type() -> int:
	return object_type

func get_creation_time() -> float:
	return creation_time

func has_expire_flag() -> bool:
	return has_expire_flag_value

func is_marked_for_destruction() -> bool:
	return has_expire_flag_value

func cleanup() -> void:
	queue_free()