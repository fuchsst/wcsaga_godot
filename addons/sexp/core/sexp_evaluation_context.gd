class_name SexpEvaluationContext
extends RefCounted

## SEXP Evaluation Context
##
## Manages variable state, object references, and mission context during
## SEXP expression evaluation. Provides isolated evaluation environments
## with proper scoping and state management.

signal variable_set(name: String, value: Variant)
signal variable_accessed(name: String, value: Variant)
signal object_referenced(object_id: String, object_ref: Variant)
signal context_error(error_message: String)

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Variable storage with type information
var variables: Dictionary = {}              # String -> SexpResult
var variable_types: Dictionary = {}         # String -> SexpResult.Type
var variable_metadata: Dictionary = {}      # String -> Dictionary (creation time, access count, etc.)

## Object reference management
var object_references: Dictionary = {}      # String -> Object reference
var object_metadata: Dictionary = {}        # String -> Dictionary (type, creation time, etc.)

## Context hierarchy for scoping
var parent_context: SexpEvaluationContext = null
var child_contexts: Array[SexpEvaluationContext] = []

## Context identification
var context_id: String = ""
var context_type: String = "general"       # general, mission, event, condition, action
var creation_time: int = 0
var last_access_time: int = 0

## Performance tracking
var variable_access_count: int = 0
var object_access_count: int = 0
var total_evaluations: int = 0

## Context state
var is_read_only: bool = false
var is_locked: bool = false
var max_variables: int = 1000
var max_objects: int = 500

## Initialize context
func _init(id: String = "", type: String = "general") -> void:
	context_id = id if not id.is_empty() else _generate_context_id()
	context_type = type
	creation_time = Time.get_ticks_msec()
	last_access_time = creation_time

## Generate unique context ID
func _generate_context_id() -> String:
	return "ctx_%d_%s" % [Time.get_ticks_msec(), str(randi()).substr(0, 4)]

## Variable management

## Set variable value
func set_variable(name: String, value: SexpResult) -> bool:
	if is_read_only or is_locked:
		context_error.emit("Cannot set variable '%s': context is read-only" % name)
		return false
	
	if variables.size() >= max_variables and name not in variables:
		context_error.emit("Cannot set variable '%s': maximum variable limit reached" % name)
		return false
	
	if not _is_valid_variable_name(name):
		context_error.emit("Invalid variable name: '%s'" % name)
		return false
	
	# Store variable with metadata
	variables[name] = value
	variable_types[name] = value.result_type
	variable_metadata[name] = {
		"creation_time": Time.get_ticks_msec(),
		"access_count": 0,
		"last_access": Time.get_ticks_msec(),
		"type_history": [value.result_type]
	}
	
	last_access_time = Time.get_ticks_msec()
	variable_set.emit(name, value.value)
	return true

## Get variable value
func get_variable(name: String) -> SexpResult:
	last_access_time = Time.get_ticks_msec()
	variable_access_count += 1
	
	# Check local variables first
	if name in variables:
		var result: SexpResult = variables[name]
		_update_variable_access(name)
		variable_accessed.emit(name, result.value)
		return result
	
	# Check parent context if available
	if parent_context != null:
		var parent_result: SexpResult = parent_context.get_variable(name)
		if not parent_result.is_error():
			return parent_result
	
	# Variable not found
	return SexpResult.create_contextual_error(
		"Variable '%s' not found" % name,
		"In context '%s'" % context_id,
		-1, -1, -1,
		"Define variable with (set-variable) or check spelling",
		SexpResult.ErrorType.UNDEFINED_VARIABLE
	)

## Check if variable exists
func has_variable(name: String) -> bool:
	if name in variables:
		return true
	
	if parent_context != null:
		return parent_context.has_variable(name)
	
	return false

## Remove variable
func remove_variable(name: String) -> bool:
	if is_read_only or is_locked:
		return false
	
	if name in variables:
		variables.erase(name)
		variable_types.erase(name)
		variable_metadata.erase(name)
		return true
	
	return false

## Get all variable names
func get_variable_names() -> Array[String]:
	var names: Array[String] = variables.keys()
	
	if parent_context != null:
		var parent_names: Array[String] = parent_context.get_variable_names()
		for parent_name in parent_names:
			if parent_name not in names:
				names.append(parent_name)
	
	return names

## Get variable metadata
func get_variable_metadata(name: String) -> Dictionary:
	if name in variable_metadata:
		return variable_metadata[name].duplicate()
	return {}

## Update variable access statistics
func _update_variable_access(name: String) -> void:
	if name in variable_metadata:
		variable_metadata[name]["access_count"] += 1
		variable_metadata[name]["last_access"] = Time.get_ticks_msec()

## Validate variable name
func _is_valid_variable_name(name: String) -> bool:
	if name.is_empty() or name.length() > 64:
		return false
	
	# Variable names should be valid identifiers
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z_][a-zA-Z0-9_-]*$")
	return regex.search(name) != null

## Object reference management

## Set object reference
func set_object_reference(object_id: String, object_ref: Variant) -> bool:
	if is_read_only or is_locked:
		context_error.emit("Cannot set object reference '%s': context is read-only" % object_id)
		return false
	
	if object_references.size() >= max_objects and object_id not in object_references:
		context_error.emit("Cannot set object reference '%s': maximum object limit reached" % object_id)
		return false
	
	# Store object reference with metadata
	object_references[object_id] = object_ref
	object_metadata[object_id] = {
		"creation_time": Time.get_ticks_msec(),
		"access_count": 0,
		"last_access": Time.get_ticks_msec(),
		"object_type": _get_object_type_name(object_ref),
		"is_valid": object_ref != null
	}
	
	last_access_time = Time.get_ticks_msec()
	object_referenced.emit(object_id, object_ref)
	return true

## Get object reference
func get_object_reference(object_id: String) -> SexpResult:
	last_access_time = Time.get_ticks_msec()
	object_access_count += 1
	
	# Check local object references first
	if object_id in object_references:
		var object_ref: Variant = object_references[object_id]
		_update_object_access(object_id)
		
		# Validate object is still valid
		if object_ref == null or (object_ref is Object and not is_instance_valid(object_ref)):
			object_metadata[object_id]["is_valid"] = false
			return SexpResult.create_contextual_error(
				"Object reference '%s' is no longer valid" % object_id,
				"In context '%s'" % context_id,
				-1, -1, -1,
				"Check if object still exists or update reference",
				SexpResult.ErrorType.OBJECT_NOT_FOUND
			)
		
		return SexpResult.create_object(object_ref)
	
	# Check parent context if available
	if parent_context != null:
		var parent_result: SexpResult = parent_context.get_object_reference(object_id)
		if not parent_result.is_error():
			return parent_result
	
	# Object not found
	return SexpResult.create_contextual_error(
		"Object reference '%s' not found" % object_id,
		"In context '%s'" % context_id,
		-1, -1, -1,
		"Register object with (set-object-reference) or check object ID",
		SexpResult.ErrorType.OBJECT_NOT_FOUND
	)

## Check if object reference exists
func has_object_reference(object_id: String) -> bool:
	if object_id in object_references:
		return true
	
	if parent_context != null:
		return parent_context.has_object_reference(object_id)
	
	return false

## Remove object reference
func remove_object_reference(object_id: String) -> bool:
	if is_read_only or is_locked:
		return false
	
	if object_id in object_references:
		object_references.erase(object_id)
		object_metadata.erase(object_id)
		return true
	
	return false

## Get all object IDs
func get_object_ids() -> Array[String]:
	var ids: Array[String] = object_references.keys()
	
	if parent_context != null:
		var parent_ids: Array[String] = parent_context.get_object_ids()
		for parent_id in parent_ids:
			if parent_id not in ids:
				ids.append(parent_id)
	
	return ids

## Get object metadata
func get_object_metadata(object_id: String) -> Dictionary:
	if object_id in object_metadata:
		return object_metadata[object_id].duplicate()
	return {}

## Update object access statistics
func _update_object_access(object_id: String) -> void:
	if object_id in object_metadata:
		object_metadata[object_id]["access_count"] += 1
		object_metadata[object_id]["last_access"] = Time.get_ticks_msec()

## Get object type name for metadata
func _get_object_type_name(object_ref: Variant) -> String:
	if object_ref == null:
		return "null"
	elif object_ref is Object:
		return object_ref.get_class()
	else:
		return type_string(typeof(object_ref))

## Context hierarchy management

## Create child context
func create_child_context(child_id: String = "", child_type: String = "general") -> SexpEvaluationContext:
	var child: SexpEvaluationContext = SexpEvaluationContext.new(child_id, child_type)
	child.parent_context = self
	child_contexts.append(child)
	return child

## Remove child context
func remove_child_context(child: SexpEvaluationContext) -> bool:
	var index: int = child_contexts.find(child)
	if index >= 0:
		child_contexts[index].parent_context = null
		child_contexts.remove_at(index)
		return true
	return false

## Get parent context
func get_parent_context() -> SexpEvaluationContext:
	return parent_context

## Get child contexts
func get_child_contexts() -> Array[SexpEvaluationContext]:
	return child_contexts.duplicate()

## Find context by ID in hierarchy
func find_context(search_id: String) -> SexpEvaluationContext:
	if context_id == search_id:
		return self
	
	# Search children
	for child in child_contexts:
		var found: SexpEvaluationContext = child.find_context(search_id)
		if found != null:
			return found
	
	# Search parent hierarchy
	if parent_context != null:
		return parent_context.find_context(search_id)
	
	return null

## Context state management

## Lock context (prevent modifications)
func lock_context() -> void:
	is_locked = true

## Unlock context
func unlock_context() -> void:
	is_locked = false

## Set read-only mode
func set_read_only(read_only: bool) -> void:
	is_read_only = read_only

## Clear all variables and objects
func clear_all() -> bool:
	if is_read_only or is_locked:
		return false
	
	variables.clear()
	variable_types.clear()
	variable_metadata.clear()
	object_references.clear()
	object_metadata.clear()
	
	variable_access_count = 0
	object_access_count = 0
	total_evaluations = 0
	
	return true

## Validate all object references
func validate_object_references() -> Array[String]:
	var invalid_objects: Array[String] = []
	
	for object_id in object_references:
		var object_ref: Variant = object_references[object_id]
		if object_ref == null or (object_ref is Object and not is_instance_valid(object_ref)):
			invalid_objects.append(object_id)
			object_metadata[object_id]["is_valid"] = false
	
	return invalid_objects

## Context serialization

## Export context to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"context_id": context_id,
		"context_type": context_type,
		"creation_time": creation_time,
		"last_access_time": last_access_time,
		"variables": {},
		"variable_metadata": variable_metadata.duplicate(),
		"object_metadata": object_metadata.duplicate(),
		"statistics": {
			"variable_access_count": variable_access_count,
			"object_access_count": object_access_count,
			"total_evaluations": total_evaluations
		},
		"state": {
			"is_read_only": is_read_only,
			"is_locked": is_locked
		}
	}
	
	# Export variables (convert SexpResult to serializable format)
	for var_name in variables:
		var result: SexpResult = variables[var_name]
		data["variables"][var_name] = {
			"type": result.result_type,
			"value": result.value
		}
	
	# Note: Object references are not serialized as they may not be valid after reload
	
	return data

## Import context from dictionary
static func from_dict(data: Dictionary) -> SexpEvaluationContext:
	var context: SexpEvaluationContext = SexpEvaluationContext.new(
		data.get("context_id", ""),
		data.get("context_type", "general")
	)
	
	context.creation_time = data.get("creation_time", Time.get_ticks_msec())
	context.last_access_time = data.get("last_access_time", Time.get_ticks_msec())
	
	# Import variables
	var variables_data: Dictionary = data.get("variables", {})
	for var_name in variables_data:
		var var_data: Dictionary = variables_data[var_name]
		var result: SexpResult
		
		match var_data["type"]:
			SexpResult.Type.NUMBER:
				result = SexpResult.create_number(var_data["value"])
			SexpResult.Type.STRING:
				result = SexpResult.create_string(var_data["value"])
			SexpResult.Type.BOOLEAN:
				result = SexpResult.create_boolean(var_data["value"])
			SexpResult.Type.VOID:
				result = SexpResult.create_void()
			_:
				continue  # Skip unknown types
		
		context.set_variable(var_name, result)
	
	# Import metadata
	context.variable_metadata = data.get("variable_metadata", {})
	context.object_metadata = data.get("object_metadata", {})
	
	# Import statistics
	var stats: Dictionary = data.get("statistics", {})
	context.variable_access_count = stats.get("variable_access_count", 0)
	context.object_access_count = stats.get("object_access_count", 0)
	context.total_evaluations = stats.get("total_evaluations", 0)
	
	# Import state
	var state: Dictionary = data.get("state", {})
	context.is_read_only = state.get("is_read_only", false)
	context.is_locked = state.get("is_locked", false)
	
	return context

## Get context statistics
func get_statistics() -> Dictionary:
	return {
		"context_id": context_id,
		"context_type": context_type,
		"creation_time": creation_time,
		"last_access_time": last_access_time,
		"age_ms": Time.get_ticks_msec() - creation_time,
		"variable_count": variables.size(),
		"object_count": object_references.size(),
		"variable_access_count": variable_access_count,
		"object_access_count": object_access_count,
		"total_evaluations": total_evaluations,
		"child_context_count": child_contexts.size(),
		"has_parent": parent_context != null,
		"state": {
			"is_read_only": is_read_only,
			"is_locked": is_locked
		}
	}

## Get context summary for debugging
func get_debug_summary() -> String:
	var summary: String = "EvaluationContext '%s' (%s):\n" % [context_id, context_type]
	summary += "  Variables: %d (accessed %d times)\n" % [variables.size(), variable_access_count]
	summary += "  Objects: %d (accessed %d times)\n" % [object_references.size(), object_access_count]
	summary += "  Age: %d ms\n" % (Time.get_ticks_msec() - creation_time)
	summary += "  State: %s%s\n" % ["Read-only " if is_read_only else "", "Locked" if is_locked else "Active"]
	
	if child_contexts.size() > 0:
		summary += "  Child contexts: %d\n" % child_contexts.size()
	
	if parent_context != null:
		summary += "  Parent: %s\n" % parent_context.context_id
	
	return summary

## Convert to string representation
func _to_string() -> String:
	return "SexpEvaluationContext('%s', %d vars, %d objs)" % [context_id, variables.size(), object_references.size()]