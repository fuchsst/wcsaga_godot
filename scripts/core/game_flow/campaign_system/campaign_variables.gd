class_name CampaignVariables
extends RefCounted

## Enhanced campaign variable management system that leverages existing CampaignState.
## Provides comprehensive variable management with type validation, access control,
## change tracking, and SEXP integration for complex campaign logic.

const VariableChange = preload("res://scripts/core/game_flow/campaign_system/variable_change.gd")

signal variable_changed(name: String, new_value: Variant, old_value: Variant, scope: VariableScope)
signal variable_deleted(name: String, scope: VariableScope)
signal variables_imported(count: int)

# Variable storage and metadata
var _variables: Dictionary = {}
var _variable_metadata: Dictionary = {}
var _change_history: Array = []
var _campaign_state: CampaignState = null

enum VariableScope {
	GLOBAL,      ## Persists across all campaigns
	CAMPAIGN,    ## Persists within current campaign
	MISSION,     ## Valid only for current mission
	SESSION      ## Valid only for current session
}

enum VariableType {
	INTEGER,
	FLOAT,
	BOOLEAN,
	STRING,
	ARRAY,
	DICTIONARY
}

# Static instance for global access
static var instance: CampaignVariables = null

func _init(campaign_state: CampaignState = null) -> void:
	_campaign_state = campaign_state
	if instance == null:
		instance = self

## Set a campaign variable with type validation and access control
func set_variable(name: String, value: Variant, scope: VariableScope = VariableScope.CAMPAIGN) -> bool:
	# Validate variable name
	if not _is_valid_variable_name(name):
		push_error("Invalid variable name: %s" % name)
		return false
	
	# Check write permissions
	if not _can_write_variable(name):
		push_error("Variable is write-protected: %s" % name)
		return false
	
	# Validate and convert value
	var validated_value: Variant = _validate_and_convert_value(name, value)
	if validated_value == null and value != null:
		push_error("Invalid value type for variable %s: %s" % [name, typeof(value)])
		return false
	
	# Store previous value for change tracking
	var previous_value: Variant = _variables.get(name, null)
	
	# Set the variable
	_variables[name] = validated_value
	_update_variable_metadata(name, scope, typeof(validated_value))
	
	# Update CampaignState if available
	if _campaign_state != null:
		match scope:
			VariableScope.CAMPAIGN, VariableScope.GLOBAL:
				_campaign_state.set_variable(name, validated_value, true)
			VariableScope.MISSION:
				_campaign_state.set_variable(name, validated_value, false)
			_:
				# Session variables only in memory
				pass
	
	# Record change
	_record_variable_change(name, previous_value, validated_value, scope)
	
	# Emit change signal
	variable_changed.emit(name, validated_value, previous_value, scope)
	
	return true

## Get a variable value with optional default
func get_variable(name: String, default_value: Variant = null) -> Variant:
	# Check read permissions
	if not _can_read_variable(name):
		push_warning("Variable access denied: %s" % name)
		return default_value
	
	# Check local storage first
	if name in _variables:
		return _variables[name]
	
	# Fall back to CampaignState if available
	if _campaign_state != null:
		var value: Variant = _campaign_state.get_variable(name, null)
		if value != null:
			return value
	
	return default_value

## Get variable as integer with validation
func get_int(name: String, default_value: int = 0) -> int:
	var value: Variant = get_variable(name, default_value)
	if typeof(value) == TYPE_INT:
		return value
	elif typeof(value) == TYPE_FLOAT:
		return int(value)
	elif typeof(value) == TYPE_STRING:
		if value.is_valid_int():
			return int(value)
	return default_value

## Get variable as float with validation
func get_float(name: String, default_value: float = 0.0) -> float:
	var value: Variant = get_variable(name, default_value)
	if typeof(value) == TYPE_FLOAT:
		return value
	elif typeof(value) == TYPE_INT:
		return float(value)
	elif typeof(value) == TYPE_STRING:
		if value.is_valid_float():
			return float(value)
	return default_value

## Get variable as boolean with validation
func get_bool(name: String, default_value: bool = false) -> bool:
	var value: Variant = get_variable(name, default_value)
	if typeof(value) == TYPE_BOOL:
		return value
	elif typeof(value) == TYPE_INT:
		return value != 0
	elif typeof(value) == TYPE_STRING:
		return value.to_lower() in ["true", "1", "yes", "on"]
	return default_value

## Get variable as string with validation
func get_string(name: String, default_value: String = "") -> String:
	var value: Variant = get_variable(name, default_value)
	if value != null:
		return str(value)
	return default_value

## Check if variable exists
func has_variable(name: String) -> bool:
	if name in _variables:
		return true
	if _campaign_state != null:
		return _campaign_state.get_variable(name, null) != null
	return false

## Get variable type information
func get_variable_type(name: String) -> VariableType:
	if not has_variable(name):
		return -1
	
	var metadata: Dictionary = _variable_metadata.get(name, {})
	return metadata.get("type", VariableType.STRING)

## Get variable scope information
func get_variable_scope(name: String) -> VariableScope:
	if not has_variable(name):
		return -1
	
	var metadata: Dictionary = _variable_metadata.get(name, {})
	return metadata.get("scope", VariableScope.CAMPAIGN)

## Increment numeric variable
func increment_variable(name: String, amount: float = 1.0) -> bool:
	var current_value: Variant = get_variable(name, 0)
	if typeof(current_value) == TYPE_INT:
		return set_variable(name, int(current_value) + int(amount))
	elif typeof(current_value) == TYPE_FLOAT:
		return set_variable(name, float(current_value) + amount)
	else:
		push_error("Cannot increment non-numeric variable: %s" % name)
		return false

## Append value to array variable
func append_to_array(name: String, value: Variant) -> bool:
	var current_array: Variant = get_variable(name, [])
	if typeof(current_array) != TYPE_ARRAY:
		push_error("Variable is not an array: %s" % name)
		return false
	
	current_array.append(value)
	return set_variable(name, current_array)

## Delete a variable
func delete_variable(name: String) -> bool:
	if not has_variable(name):
		return false
	
	if not _can_write_variable(name):
		push_error("Cannot delete write-protected variable: %s" % name)
		return false
	
	var scope: VariableScope = get_variable_scope(name)
	
	# Remove from local storage
	_variables.erase(name)
	_variable_metadata.erase(name)
	
	# Remove from CampaignState if needed
	if _campaign_state != null and scope != VariableScope.SESSION:
		# CampaignState doesn't have delete method, so we set to null
		_campaign_state.set_variable(name, null, scope != VariableScope.MISSION)
	
	variable_deleted.emit(name, scope)
	return true

## Clear variables by scope
func clear_variables_by_scope(scope: VariableScope) -> int:
	var cleared_count: int = 0
	var variables_to_clear: Array[String] = []
	
	# Find variables to clear
	for var_name: String in _variables.keys():
		if get_variable_scope(var_name) == scope:
			variables_to_clear.append(var_name)
	
	# Clear them
	for var_name: String in variables_to_clear:
		if delete_variable(var_name):
			cleared_count += 1
	
	# Clear mission variables in CampaignState if needed
	if scope == VariableScope.MISSION and _campaign_state != null:
		_campaign_state.clear_mission_variables()
	
	return cleared_count

## Get all variable names
func get_variable_names() -> Array[String]:
	var names: Array[String] = []
	names.append_array(_variables.keys())
	
	# Add CampaignState variables if available
	if _campaign_state != null:
		for var_name: String in _campaign_state.persistent_variables.keys():
			if var_name not in names:
				names.append(var_name)
		for var_name: String in _campaign_state.mission_variables.keys():
			if var_name not in names:
				names.append(var_name)
	
	return names

## Export variables to dictionary for serialization
func export_variables_to_dict() -> Dictionary:
	return {
		"variables": _variables,
		"metadata": _variable_metadata,
		"change_history": _serialize_change_history()
	}

## Import variables from dictionary
func import_variables_from_dict(data: Dictionary) -> bool:
	if not data.has("variables") or not data.has("metadata"):
		push_error("Invalid variable data format")
		return false
	
	_variables = data["variables"]
	_variable_metadata = data["metadata"]
	
	if data.has("change_history"):
		_change_history = _deserialize_change_history(data["change_history"])
	
	variables_imported.emit(_variables.size())
	return true

# --- Private Helper Methods ---

## Validate variable name format
func _is_valid_variable_name(name: String) -> bool:
	# Check basic naming rules
	if name.length() == 0 or name.length() > 64:
		return false
	
	# Check for valid characters (alphanumeric, underscore, dash)
	var regex: RegEx = RegEx.new()
	regex.compile("^[a-zA-Z][a-zA-Z0-9_-]*$")
	return regex.search(name) != null

## Validate and convert variable value
func _validate_and_convert_value(name: String, value: Variant) -> Variant:
	# Check if variable already exists and has a type constraint
	if name in _variable_metadata:
		var expected_type: VariableType = _variable_metadata[name].get("type", VariableType.STRING)
		return _convert_to_expected_type(value, expected_type)
	
	# New variable - accept as-is but validate
	if typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING, TYPE_ARRAY, TYPE_DICTIONARY]:
		return value
	
	# Try to convert to string as fallback
	return str(value)

## Convert value to expected type
func _convert_to_expected_type(value: Variant, expected_type: VariableType) -> Variant:
	match expected_type:
		VariableType.INTEGER:
			if typeof(value) == TYPE_INT:
				return value
			elif typeof(value) == TYPE_FLOAT:
				return int(value)
			elif typeof(value) == TYPE_STRING and value.is_valid_int():
				return int(value)
			elif typeof(value) == TYPE_BOOL:
				return 1 if value else 0
		
		VariableType.FLOAT:
			if typeof(value) == TYPE_FLOAT:
				return value
			elif typeof(value) == TYPE_INT:
				return float(value)
			elif typeof(value) == TYPE_STRING and value.is_valid_float():
				return float(value)
		
		VariableType.BOOLEAN:
			if typeof(value) == TYPE_BOOL:
				return value
			elif typeof(value) == TYPE_INT:
				return value != 0
			elif typeof(value) == TYPE_STRING:
				return value.to_lower() in ["true", "1", "yes", "on"]
		
		VariableType.STRING:
			return str(value)
		
		VariableType.ARRAY:
			if typeof(value) == TYPE_ARRAY:
				return value
			else:
				return [value]  # Wrap in array
		
		VariableType.DICTIONARY:
			if typeof(value) == TYPE_DICTIONARY:
				return value
			else:
				return {"value": value}  # Wrap in dictionary
	
	return null

## Update variable metadata
func _update_variable_metadata(name: String, scope: VariableScope, value_type: int) -> void:
	if name not in _variable_metadata:
		_variable_metadata[name] = {}
	
	var metadata: Dictionary = _variable_metadata[name]
	metadata["scope"] = scope
	metadata["type"] = _godot_type_to_variable_type(value_type)
	metadata["created_time"] = Time.get_unix_time_from_system()
	metadata["modified_time"] = Time.get_unix_time_from_system()
	metadata["access_count"] = metadata.get("access_count", 0) + 1

## Convert Godot type to VariableType enum
func _godot_type_to_variable_type(godot_type: int) -> VariableType:
	match godot_type:
		TYPE_INT:
			return VariableType.INTEGER
		TYPE_FLOAT:
			return VariableType.FLOAT
		TYPE_BOOL:
			return VariableType.BOOLEAN
		TYPE_STRING:
			return VariableType.STRING
		TYPE_ARRAY:
			return VariableType.ARRAY
		TYPE_DICTIONARY:
			return VariableType.DICTIONARY
		_:
			return VariableType.STRING

## Check read permissions
func _can_read_variable(name: String) -> bool:
	# Always allow reading (restriction would be on UI level)
	return true

## Check write permissions
func _can_write_variable(name: String) -> bool:
	# Check write permissions
	var metadata: Dictionary = _variable_metadata.get(name, {})
	var write_protected: bool = metadata.get("write_protected", false)
	
	# System variables are write-protected
	if name.begins_with("_system_"):
		return false
	
	return not write_protected

## Record variable change for history
func _record_variable_change(name: String, old_value: Variant, new_value: Variant, scope: VariableScope) -> void:
	var change = VariableChange.new()
	change.variable_name = name
	change.old_value = old_value
	change.new_value = new_value
	change.change_time = Time.get_unix_time_from_system()
	change.scope = scope
	change.source = _get_change_source()
	
	_change_history.append(change)
	
	# Limit history size
	if _change_history.size() > 1000:
		_change_history.pop_front()

## Get source of variable change
func _get_change_source() -> String:
	# Try to determine what caused the change
	var stack: Array = get_stack()
	if stack.size() > 2:
		var caller: Dictionary = stack[2]
		return "%s:%d" % [caller.get("source", "unknown"), caller.get("line", 0)]
	return "unknown"

## Serialize change history for saving
func _serialize_change_history() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for change in _change_history:
		serialized.append({
			"variable_name": change.variable_name,
			"old_value": change.old_value,
			"new_value": change.new_value,
			"change_time": change.change_time,
			"scope": change.scope,
			"source": change.source
		})
	return serialized

## Deserialize change history from loaded data
func _deserialize_change_history(data: Array) -> Array:
	var changes: Array = []
	for item: Dictionary in data:
		var change = VariableChange.new()
		change.variable_name = item.get("variable_name", "")
		change.old_value = item.get("old_value", null)
		change.new_value = item.get("new_value", null)
		change.change_time = item.get("change_time", 0)
		change.scope = item.get("scope", VariableScope.CAMPAIGN)
		change.source = item.get("source", "unknown")
		changes.append(change)
	return changes

## Static access methods for global usage
static func set_global_variable(name: String, value: Variant, scope: VariableScope = VariableScope.CAMPAIGN) -> bool:
	if instance != null:
		return instance.set_variable(name, value, scope)
	push_error("CampaignVariables instance not initialized")
	return false

static func get_global_variable(name: String, default_value: Variant = null) -> Variant:
	if instance != null:
		return instance.get_variable(name, default_value)
	push_warning("CampaignVariables instance not initialized")
	return default_value

static func has_global_variable(name: String) -> bool:
	if instance != null:
		return instance.has_variable(name)
	return false