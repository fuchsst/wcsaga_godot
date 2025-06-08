extends Node

## Mock weapon object for GC testing

var object_type: int = 3  # Weapon type
var creation_time: float
var is_perishable_value: bool = true

func _init() -> void:
	creation_time = Time.get_time_dict_from_system()["unix"] - 20.0  # Old weapon

func get_object_type() -> int:
	return object_type

func get_creation_time() -> float:
	return creation_time

func is_perishable() -> bool:
	return is_perishable_value

func is_marked_for_destruction() -> bool:
	return false

func cleanup() -> void:
	queue_free()