class_name AIBlackboard
extends RefCounted

## Simple blackboard implementation for AI behavior trees
## Stores and retrieves key-value pairs for AI decision making

var data: Dictionary = {}
var history: Array[Dictionary] = []
var max_history_size: int = 100

func set_value(key: String, value: Variant) -> void:
	## Sets a value in the blackboard
	var old_value: Variant = data.get(key)
	data[key] = value
	
	# Store in history for debugging
	if old_value != value:
		_add_to_history(key, old_value, value)

func get_value(key: String, default_value: Variant = null) -> Variant:
	## Gets a value from the blackboard with optional default
	return data.get(key, default_value)

func has_value(key: String) -> bool:
	## Checks if a key exists in the blackboard
	return data.has(key)

func erase_value(key: String) -> void:
	## Removes a value from the blackboard
	if data.has(key):
		var old_value: Variant = data[key]
		data.erase(key)
		_add_to_history(key, old_value, null)

func clear_all() -> void:
	## Clears all values from the blackboard
	data.clear()
	history.clear()

func get_all_keys() -> Array[String]:
	## Returns all keys in the blackboard
	var keys: Array[String] = []
	for key in data.keys():
		keys.append(key)
	return keys

func get_all_values() -> Dictionary:
	## Returns a copy of all blackboard data
	return data.duplicate()

func merge_values(other_data: Dictionary) -> void:
	## Merges data from another dictionary
	for key in other_data.keys():
		set_value(key, other_data[key])

func get_history() -> Array[Dictionary]:
	## Returns the value change history
	return history.duplicate()

func _add_to_history(key: String, old_value: Variant, new_value: Variant) -> void:
	## Adds a change to the history
	var change: Dictionary = {
		"key": key,
		"old_value": old_value,
		"new_value": new_value,
		"timestamp": Time.get_time_from_start()
	}
	
	history.append(change)
	
	# Limit history size
	if history.size() > max_history_size:
		history.remove_at(0)

func get_debug_info() -> Dictionary:
	## Returns debug information about the blackboard
	return {
		"key_count": data.size(),
		"keys": get_all_keys(),
		"history_size": history.size(),
		"recent_changes": history.slice(-5) if history.size() > 5 else history
	}