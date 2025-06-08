class_name SexpVariable
extends Resource

## SEXP Variable Resource for type-safe variable storage with metadata
##
## Represents a single variable in the SEXP system with complete metadata
## tracking, type safety, and persistence support. Each variable stores
## its value, scope, creation/modification times, and access statistics.

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Variable identification and scope
@export var name: String = ""
@export var scope: SexpVariableManager.VariableScope = SexpVariableManager.VariableScope.LOCAL

## Variable value (core data)
var value: SexpResult = null

## Metadata tracking
@export var created_time: float = 0.0
@export var modified_time: float = 0.0
@export var last_accessed: float = 0.0
@export var access_count: int = 0

## Type constraints and validation
@export var type_locked: bool = false
@export var allowed_types: Array[SexpResult.Type] = []
@export var read_only: bool = false

## Description and documentation
@export var description: String = ""
@export var source_mission: String = ""  ## Mission that created this variable
@export var source_function: String = "" ## SEXP function that created this variable

## Validation and constraints
@export var min_value: float = -INF
@export var max_value: float = INF
@export var allowed_string_values: Array[String] = []  ## For enum-like string variables

func _init():
	created_time = Time.get_unix_time_from_system()
	modified_time = created_time
	last_accessed = created_time

## Core variable operations

func set_value(new_value: SexpResult, validate: bool = true) -> bool:
	## Set the variable value with optional validation
	## Returns true if successful, false if validation fails or read-only
	
	if read_only:
		push_error("Cannot modify read-only variable: %s" % name)
		return false
	
	if new_value == null:
		push_error("Cannot set null value for variable: %s" % name)
		return false
	
	if validate and not _validate_value(new_value):
		return false
	
	# Type locking check
	if type_locked and value != null:
		if value.result_type != new_value.result_type:
			push_error("Cannot change type of type-locked variable %s from %s to %s" % [
				name, 
				SexpResult.Type.keys()[value.result_type],
				SexpResult.Type.keys()[new_value.result_type]
			])
			return false
	
	value = new_value
	modified_time = Time.get_unix_time_from_system()
	last_accessed = modified_time
	
	return true

func get_value() -> SexpResult:
	## Get the variable value and update access tracking
	last_accessed = Time.get_unix_time_from_system()
	access_count += 1
	return value

func get_value_safe() -> SexpResult:
	## Get the variable value without updating access tracking
	return value

## Type management and validation

func lock_type() -> void:
	## Lock the variable to its current type
	type_locked = true

func unlock_type() -> void:
	## Unlock the variable type (allow type changes)
	type_locked = false

func set_allowed_types(types: Array[SexpResult.Type]) -> void:
	## Set the allowed types for this variable
	allowed_types = types.duplicate()

func add_allowed_type(type: SexpResult.Type) -> void:
	## Add an allowed type
	if not allowed_types.has(type):
		allowed_types.append(type)

func remove_allowed_type(type: SexpResult.Type) -> void:
	## Remove an allowed type
	allowed_types.erase(type)

func is_type_allowed(type: SexpResult.Type) -> bool:
	## Check if a type is allowed for this variable
	return allowed_types.is_empty() or allowed_types.has(type)

## Value constraints

func set_number_range(min_val: float, max_val: float) -> void:
	## Set numerical range constraints
	min_value = min_val
	max_value = max_val

func set_allowed_string_values(values: Array[String]) -> void:
	## Set allowed string values (enum-like constraint)
	allowed_string_values = values.duplicate()

func add_allowed_string_value(value_str: String) -> void:
	## Add an allowed string value
	if not allowed_string_values.has(value_str):
		allowed_string_values.append(value_str)

func clear_constraints() -> void:
	## Clear all value constraints
	min_value = -INF
	max_value = INF
	allowed_string_values.clear()
	allowed_types.clear()

## Metadata and information

func set_read_only(readonly: bool) -> void:
	## Set read-only status
	read_only = readonly

func set_description(desc: String) -> void:
	## Set variable description
	description = desc

func set_source_info(mission: String, function: String) -> void:
	## Set source information for debugging
	source_mission = mission
	source_function = function

func get_age_seconds() -> float:
	## Get variable age in seconds
	return Time.get_unix_time_from_system() - created_time

func get_time_since_modified() -> float:
	## Get seconds since last modification
	return Time.get_unix_time_from_system() - modified_time

func get_time_since_accessed() -> float:
	## Get seconds since last access
	return Time.get_unix_time_from_system() - last_accessed

## Type checking and conversion

func is_number() -> bool:
	## Check if variable contains a number
	return value != null and value.is_number()

func is_string() -> bool:
	## Check if variable contains a string
	return value != null and value.is_string()

func is_boolean() -> bool:
	## Check if variable contains a boolean
	return value != null and value.is_boolean()

func is_object_reference() -> bool:
	## Check if variable contains an object reference
	return value != null and value.is_object_reference()

func is_error() -> bool:
	## Check if variable contains an error
	return value != null and value.is_error()

func is_void() -> bool:
	## Check if variable contains void
	return value != null and value.is_void()

func get_type_string() -> String:
	## Get the variable type as a string
	if value == null:
		return "null"
	return SexpResult.Type.keys()[value.result_type].to_lower()

## Conversion with validation

func convert_to_number() -> SexpResult:
	## Convert variable value to number
	if value == null:
		return SexpResult.create_error("Cannot convert null value to number", SexpResult.ErrorType.TYPE_MISMATCH)
	
	return _convert_value_to_number(value)

func convert_to_string() -> SexpResult:
	## Convert variable value to string
	if value == null:
		return SexpResult.create_error("Cannot convert null value to string", SexpResult.ErrorType.TYPE_MISMATCH)
	
	return _convert_value_to_string(value)

func convert_to_boolean() -> SexpResult:
	## Convert variable value to boolean
	if value == null:
		return SexpResult.create_error("Cannot convert null value to boolean", SexpResult.ErrorType.TYPE_MISMATCH)
	
	return _convert_value_to_boolean(value)

## Persistence and serialization

func serialize() -> Dictionary:
	## Serialize variable to dictionary for persistence
	var data: Dictionary = {
		"name": name,
		"scope": scope,
		"created_time": created_time,
		"modified_time": modified_time,
		"last_accessed": last_accessed,
		"access_count": access_count,
		"type_locked": type_locked,
		"read_only": read_only,
		"description": description,
		"source_mission": source_mission,
		"source_function": source_function,
		"min_value": min_value,
		"max_value": max_value,
		"allowed_string_values": allowed_string_values,
		"allowed_types": _serialize_types(allowed_types)
	}
	
	# Serialize value
	if value != null:
		data["value"] = _serialize_sexp_result(value)
	else:
		data["value"] = null
	
	return data

func deserialize(data: Dictionary) -> bool:
	## Deserialize variable from dictionary
	## Returns true if successful, false if data is invalid
	
	if not data.has("name") or not data.has("scope"):
		push_error("Invalid variable data: missing required fields")
		return false
	
	name = data.get("name", "")
	scope = data.get("scope", SexpVariableManager.VariableScope.LOCAL)
	created_time = data.get("created_time", 0.0)
	modified_time = data.get("modified_time", 0.0)
	last_accessed = data.get("last_accessed", 0.0)
	access_count = data.get("access_count", 0)
	type_locked = data.get("type_locked", false)
	read_only = data.get("read_only", false)
	description = data.get("description", "")
	source_mission = data.get("source_mission", "")
	source_function = data.get("source_function", "")
	min_value = data.get("min_value", -INF)
	max_value = data.get("max_value", INF)
	allowed_string_values = data.get("allowed_string_values", [])
	
	# Deserialize allowed types
	var serialized_types: Array = data.get("allowed_types", [])
	allowed_types = _deserialize_types(serialized_types)
	
	# Deserialize value
	var value_data = data.get("value", null)
	if value_data != null:
		value = _deserialize_sexp_result(value_data)
		if value == null:
			push_error("Failed to deserialize variable value for: %s" % name)
			return false
	else:
		value = null
	
	return true

## Information and debugging

func get_info() -> Dictionary:
	## Get comprehensive variable information
	return {
		"name": name,
		"scope": _scope_to_string(scope),
		"type": get_type_string(),
		"value": _value_to_string(),
		"type_locked": type_locked,
		"read_only": read_only,
		"description": description,
		"source_mission": source_mission,
		"source_function": source_function,
		"created_time": created_time,
		"modified_time": modified_time,
		"last_accessed": last_accessed,
		"access_count": access_count,
		"age_seconds": get_age_seconds(),
		"time_since_modified": get_time_since_modified(),
		"time_since_accessed": get_time_since_accessed(),
		"constraints": _get_constraints_info()
	}

func print_info() -> void:
	## Print variable information to console
	var info: Dictionary = get_info()
	print("Variable: %s" % info.name)
	print("  Scope: %s" % info.scope)
	print("  Type: %s" % info.type)
	print("  Value: %s" % info.value)
	print("  Type Locked: %s" % info.type_locked)
	print("  Read Only: %s" % info.read_only)
	print("  Description: %s" % info.description)
	print("  Access Count: %s" % info.access_count)
	print("  Age: %.2f seconds" % info.age_seconds)

## Private helper methods

func _validate_value(new_value: SexpResult) -> bool:
	## Validate value against constraints
	if new_value == null:
		return false
	
	if new_value.is_error():
		return true  # Allow error values
	
	# Check allowed types
	if not is_type_allowed(new_value.result_type):
		push_error("Type %s not allowed for variable %s" % [
			SexpResult.Type.keys()[new_value.result_type],
			name
		])
		return false
	
	# Type-specific validation
	match new_value.result_type:
		SexpResult.Type.NUMBER:
			return _validate_number_value(new_value.get_number_value())
		SexpResult.Type.STRING:
			return _validate_string_value(new_value.get_string_value())
		_:
			return true  # Other types have no additional constraints

func _validate_number_value(num: float) -> bool:
	## Validate numerical value against range constraints
	if num < min_value or num > max_value:
		push_error("Number value %.2f out of range [%.2f, %.2f] for variable %s" % [
			num, min_value, max_value, name
		])
		return false
	return true

func _validate_string_value(str_val: String) -> bool:
	## Validate string value against allowed values
	if allowed_string_values.is_empty():
		return true
	
	if not allowed_string_values.has(str_val):
		push_error("String value '%s' not in allowed values %s for variable %s" % [
			str_val, allowed_string_values, name
		])
		return false
	return true

func _scope_to_string(var_scope: SexpVariableManager.VariableScope) -> String:
	## Convert scope to string
	match var_scope:
		SexpVariableManager.VariableScope.LOCAL:
			return "local"
		SexpVariableManager.VariableScope.CAMPAIGN:
			return "campaign"
		SexpVariableManager.VariableScope.GLOBAL:
			return "global"
		_:
			return "unknown"

func _value_to_string() -> String:
	## Convert value to string representation
	if value == null:
		return "null"
	if value.is_error():
		return "ERROR: %s" % value.get_error_message()
	
	match value.result_type:
		SexpResult.Type.NUMBER:
			return str(value.get_number_value())
		SexpResult.Type.STRING:
			return "\"%s\"" % value.get_string_value()
		SexpResult.Type.BOOLEAN:
			return "true" if value.get_boolean_value() else "false"
		SexpResult.Type.OBJECT_REFERENCE:
			var obj = value.get_object_reference()
			return "[Object:%s]" % str(obj) if obj != null else "[Object:null]"
		SexpResult.Type.VOID:
			return "void"
		_:
			return "unknown"

func _get_constraints_info() -> Dictionary:
	## Get information about variable constraints
	return {
		"allowed_types": _types_to_strings(allowed_types),
		"number_range": [min_value, max_value] if min_value != -INF or max_value != INF else null,
		"allowed_string_values": allowed_string_values if not allowed_string_values.is_empty() else null
	}

func _types_to_strings(types: Array[SexpResult.Type]) -> Array[String]:
	## Convert type array to string array
	var type_strings: Array[String] = []
	for type in types:
		type_strings.append(SexpResult.Type.keys()[type].to_lower())
	return type_strings

## Serialization helpers

func _serialize_types(types: Array[SexpResult.Type]) -> Array[int]:
	## Serialize types array to integers
	var serialized: Array[int] = []
	for type in types:
		serialized.append(int(type))
	return serialized

func _deserialize_types(serialized: Array) -> Array[SexpResult.Type]:
	## Deserialize types array from integers
	var types: Array[SexpResult.Type] = []
	for type_int in serialized:
		if type_int >= 0 and type_int < SexpResult.Type.size():
			types.append(type_int as SexpResult.Type)
	return types

func _serialize_sexp_result(result: SexpResult) -> Dictionary:
	## Serialize SexpResult to dictionary
	if result == null:
		return {"type": "null"}
	
	var data: Dictionary = {
		"type": int(result.result_type)
	}
	
	match result.result_type:
		SexpResult.Type.NUMBER:
			data["value"] = result.get_number_value()
		SexpResult.Type.STRING:
			data["value"] = result.get_string_value()
		SexpResult.Type.BOOLEAN:
			data["value"] = result.get_boolean_value()
		SexpResult.Type.ERROR:
			data["message"] = result.get_error_message()
			data["error_type"] = int(result.error_type)
		SexpResult.Type.VOID:
			pass  # No additional data
		SexpResult.Type.OBJECT_REFERENCE:
			# Object references cannot be serialized
			data["type"] = int(SexpResult.Type.ERROR)
			data["message"] = "Object reference cannot be serialized"
			data["error_type"] = int(SexpResult.ErrorType.SERIALIZATION_ERROR)
	
	return data

func _deserialize_sexp_result(data: Dictionary) -> SexpResult:
	## Deserialize SexpResult from dictionary
	if not data.has("type"):
		return null
	
	var type_val = data["type"]
	if type_val == "null":
		return null
	
	var result_type: SexpResult.Type = int(type_val) as SexpResult.Type
	
	match result_type:
		SexpResult.Type.NUMBER:
			return SexpResult.create_number(data.get("value", 0.0))
		SexpResult.Type.STRING:
			return SexpResult.create_string(data.get("value", ""))
		SexpResult.Type.BOOLEAN:
			return SexpResult.create_boolean(data.get("value", false))
		SexpResult.Type.ERROR:
			var error_type: SexpResult.ErrorType = data.get("error_type", 0) as SexpResult.ErrorType
			return SexpResult.create_error(data.get("message", "Unknown error"), error_type)
		SexpResult.Type.VOID:
			return SexpResult.create_void()
		_:
			return SexpResult.create_error("Unknown result type in deserialization", SexpResult.ErrorType.SERIALIZATION_ERROR)

## Type conversion helpers (WCS compatibility)

func _convert_value_to_number(val: SexpResult) -> SexpResult:
	## Convert value to number using WCS semantics
	match val.result_type:
		SexpResult.Type.NUMBER:
			return val
		SexpResult.Type.STRING:
			var str_val: String = val.get_string_value()
			var num_val: float = str_val.to_float()
			return SexpResult.create_number(num_val)
		SexpResult.Type.BOOLEAN:
			return SexpResult.create_number(1.0 if val.get_boolean_value() else 0.0)
		_:
			return SexpResult.create_error("Cannot convert to number", SexpResult.ErrorType.TYPE_MISMATCH)

func _convert_value_to_string(val: SexpResult) -> SexpResult:
	## Convert value to string
	match val.result_type:
		SexpResult.Type.STRING:
			return val
		SexpResult.Type.NUMBER:
			return SexpResult.create_string(str(val.get_number_value()))
		SexpResult.Type.BOOLEAN:
			return SexpResult.create_string("true" if val.get_boolean_value() else "false")
		SexpResult.Type.OBJECT_REFERENCE:
			var obj = val.get_object_reference()
			return SexpResult.create_string(str(obj) if obj != null else "null")
		_:
			return SexpResult.create_error("Cannot convert to string", SexpResult.ErrorType.TYPE_MISMATCH)

func _convert_value_to_boolean(val: SexpResult) -> SexpResult:
	## Convert value to boolean using WCS semantics
	match val.result_type:
		SexpResult.Type.BOOLEAN:
			return val
		SexpResult.Type.NUMBER:
			return SexpResult.create_boolean(val.get_number_value() != 0.0)
		SexpResult.Type.STRING:
			var str_val: String = val.get_string_value()
			return SexpResult.create_boolean(not str_val.is_empty() and str_val.to_float() != 0.0)
		_:
			return SexpResult.create_error("Cannot convert to boolean", SexpResult.ErrorType.TYPE_MISMATCH)
