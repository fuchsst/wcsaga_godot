class_name VariableChange
extends Resource

## Resource class for tracking campaign variable changes.
## Stores detailed information about variable modifications for debugging,
## analytics, and potential rollback functionality.

@export var variable_name: String = ""                    ## Name of the variable that changed
@export var old_value: Variant = null                     ## Previous value before change
@export var new_value: Variant = null                   ## New value after change
@export var change_time: int = 0                        ## Unix timestamp when change occurred
@export var scope: CampaignVariables.VariableScope = CampaignVariables.VariableScope.CAMPAIGN  ## Variable scope
@export var source: String = ""                         ## Source that caused the change (script, SEXP, etc.)

func _init() -> void:
	change_time = Time.get_unix_time_from_system()

## Get a human-readable description of the change
func get_change_description() -> String:
	var scope_name: String = _get_scope_name(scope)
	var old_str: String = str(old_value) if old_value != null else "null"
	var new_str: String = str(new_value) if new_value != null else "null"
	
	return "%s variable '%s' changed from '%s' to '%s' at %s" % [
		scope_name,
		variable_name,
		old_str,
		new_str,
		Time.get_datetime_string_from_unix_time(change_time)
	]

## Get formatted timestamp
func get_formatted_time() -> String:
	return Time.get_datetime_string_from_unix_time(change_time)

## Check if this was a significant change (type change or large value change)
func is_significant_change() -> bool:
	# Type change is always significant
	if typeof(old_value) != typeof(new_value):
		return true
	
	# For numeric values, check if change is substantial
	if typeof(new_value) in [TYPE_INT, TYPE_FLOAT]:
		var old_num: float = float(old_value) if old_value != null else 0.0
		var new_num: float = float(new_value) if new_value != null else 0.0
		var change_magnitude: float = abs(new_num - old_num)
		
		# Consider significant if change is more than 10% or absolute change > 100
		if old_num != 0.0:
			var change_percentage: float = change_magnitude / abs(old_num)
			return change_percentage > 0.1 or change_magnitude > 100.0
		else:
			return change_magnitude > 100.0
	
	# For strings, check length difference
	if typeof(new_value) == TYPE_STRING:
		var old_str: String = str(old_value) if old_value != null else ""
		var new_str: String = str(new_value)
		return abs(new_str.length() - old_str.length()) > 10
	
	# For arrays and dictionaries, consider size changes significant
	if typeof(new_value) == TYPE_ARRAY:
		var old_array: Array = old_value if old_value != null else []
		var new_array: Array = new_value
		return abs(new_array.size() - old_array.size()) > 0
	
	if typeof(new_value) == TYPE_DICTIONARY:
		var old_dict: Dictionary = old_value if old_value != null else {}
		var new_dict: Dictionary = new_value
		return abs(new_dict.size() - old_dict.size()) > 0
	
	# For booleans, any change is significant
	if typeof(new_value) == TYPE_BOOL:
		return old_value != new_value
	
	return false

## Export change data to dictionary
func export_to_dictionary() -> Dictionary:
	return {
		"variable_name": variable_name,
		"old_value": old_value,
		"new_value": new_value,
		"change_time": change_time,
		"scope": scope,
		"source": source,
		"description": get_change_description(),
		"is_significant": is_significant_change()
	}

## Get scope name as string
func _get_scope_name(variable_scope: CampaignVariables.VariableScope) -> String:
	match variable_scope:
		CampaignVariables.VariableScope.GLOBAL:
			return "Global"
		CampaignVariables.VariableScope.CAMPAIGN:
			return "Campaign"
		CampaignVariables.VariableScope.MISSION:
			return "Mission"
		CampaignVariables.VariableScope.SESSION:
			return "Session"
		_:
			return "Unknown"