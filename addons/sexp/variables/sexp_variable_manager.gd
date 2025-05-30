class_name SexpVariableManager
extends RefCounted

## Variable Manager for SEXP expressions with scope management and persistence
##
## Manages variables across three scopes:
## - Local: Mission-specific variables (not persistent)
## - Campaign: Persistent across missions within a campaign
## - Global: Persistent across all campaigns and sessions
##
## Provides type-safe variable storage, change notifications, and compatibility
## with WCS variable semantics.

signal variable_changed(scope: VariableScope, name: String, old_value: SexpResult, new_value: SexpResult)
signal variable_added(scope: VariableScope, name: String, value: SexpResult)
signal variable_removed(scope: VariableScope, name: String)
signal scope_cleared(scope: VariableScope)

enum VariableScope {
	LOCAL = 0,    ## Mission-specific variables (cleared on mission end)
	CAMPAIGN = 1, ## Campaign-persistent variables
	GLOBAL = 2    ## Global persistent variables
}

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpVariable = preload("res://addons/sexp/variables/sexp_variable.gd")

## Variable storage for each scope
var _local_variables: Dictionary = {}      ## String -> SexpVariable
var _campaign_variables: Dictionary = {}   ## String -> SexpVariable  
var _global_variables: Dictionary = {}     ## String -> SexpVariable

## Performance optimization - variable access cache
var _variable_cache: Dictionary = {}       ## String -> {scope: VariableScope, variable: SexpVariable}
var _cache_enabled: bool = true
var _cache_max_size: int = 500

## Statistics tracking
var _access_stats: Dictionary = {
	"gets": 0,
	"sets": 0,
	"cache_hits": 0,
	"cache_misses": 0
}

## Persistence configuration
var _campaign_save_path: String = ""
var _global_save_path: String = ""
var _auto_save_enabled: bool = true

func _init(campaign_save_path: String = "user://campaign_variables.save", global_save_path: String = "user://global_variables.save"):
	_campaign_save_path = campaign_save_path
	_global_save_path = global_save_path
	
	# Load persistent variables on initialization
	_load_campaign_variables()
	_load_global_variables()

## Core variable operations

func set_variable(scope: VariableScope, name: String, value: SexpResult) -> bool:
	## Set a variable with the given scope, name, and value
	## Returns true if successful, false otherwise
	
	if name.is_empty():
		push_error("Variable name cannot be empty")
		return false
	
	if value == null:
		push_error("Variable value cannot be null")
		return false
	
	var variable_dict: Dictionary = _get_scope_dictionary(scope)
	var old_variable: SexpVariable = variable_dict.get(name, null)
	var old_value: SexpResult = old_variable.value if old_variable != null else null
	
	# Create new variable
	var new_variable: SexpVariable = SexpVariable.new()
	new_variable.name = name
	new_variable.value = value
	new_variable.scope = scope
	new_variable.created_time = Time.get_unix_time_from_system()
	new_variable.modified_time = new_variable.created_time
	
	if old_variable != null:
		new_variable.created_time = old_variable.created_time
	
	# Store variable
	variable_dict[name] = new_variable
	
	# Update cache
	if _cache_enabled:
		_update_cache(name, scope, new_variable)
	
	# Emit signals
	if old_variable != null:
		variable_changed.emit(scope, name, old_value, value)
	else:
		variable_added.emit(scope, name, value)
	
	# Auto-save if enabled
	if _auto_save_enabled and scope != VariableScope.LOCAL:
		_auto_save_scope(scope)
	
	_access_stats.sets += 1
	return true

func get_variable(scope: VariableScope, name: String) -> SexpResult:
	## Get a variable value by scope and name
	## Returns the variable value, or ERROR result if not found
	
	if name.is_empty():
		return SexpResult.create_error("Variable name cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
	
	_access_stats.gets += 1
	
	# Check cache first
	if _cache_enabled:
		var cache_key: String = "%s_%s" % [scope, name]
		if _variable_cache.has(cache_key):
			var cached: Dictionary = _variable_cache[cache_key]
			if cached.scope == scope:
				_access_stats.cache_hits += 1
				var variable: SexpVariable = cached.variable
				variable.last_accessed = Time.get_unix_time_from_system()
				variable.access_count += 1
				return variable.value
	
	_access_stats.cache_misses += 1
	
	# Search in scope
	var variable_dict: Dictionary = _get_scope_dictionary(scope)
	var variable: SexpVariable = variable_dict.get(name, null)
	
	if variable != null:
		variable.last_accessed = Time.get_unix_time_from_system()
		variable.access_count += 1
		
		# Update cache
		if _cache_enabled:
			_update_cache(name, scope, variable)
		
		return variable.value
	
	return SexpResult.create_error("Variable '%s' not found in scope %s" % [name, _scope_to_string(scope)], SexpResult.ErrorType.VARIABLE_NOT_FOUND)

func has_variable(scope: VariableScope, name: String) -> bool:
	## Check if a variable exists in the given scope
	
	if name.is_empty():
		return false
	
	var variable_dict: Dictionary = _get_scope_dictionary(scope)
	return variable_dict.has(name)

func remove_variable(scope: VariableScope, name: String) -> bool:
	## Remove a variable from the given scope
	## Returns true if variable was removed, false if not found
	
	if name.is_empty():
		return false
	
	var variable_dict: Dictionary = _get_scope_dictionary(scope)
	if not variable_dict.has(name):
		return false
	
	variable_dict.erase(name)
	
	# Remove from cache
	if _cache_enabled:
		var cache_key: String = "%s_%s" % [scope, name]
		_variable_cache.erase(cache_key)
	
	# Emit signal
	variable_removed.emit(scope, name)
	
	# Auto-save if enabled
	if _auto_save_enabled and scope != VariableScope.LOCAL:
		_auto_save_scope(scope)
	
	return true

func clear_scope(scope: VariableScope) -> void:
	## Clear all variables in the given scope
	
	var variable_dict: Dictionary = _get_scope_dictionary(scope)
	var variable_names: Array = variable_dict.keys()
	variable_dict.clear()
	
	# Clear cache entries for this scope
	if _cache_enabled:
		for name in variable_names:
			var cache_key: String = "%s_%s" % [scope, name]
			_variable_cache.erase(cache_key)
	
	scope_cleared.emit(scope)
	
	# Auto-save if enabled
	if _auto_save_enabled and scope != VariableScope.LOCAL:
		_auto_save_scope(scope)

## Variable search and listing

func find_variable(name: String) -> Dictionary:
	## Find a variable by name across all scopes
	## Returns {found: bool, scope: VariableScope, variable: SexpVariable}
	
	# Search order: Local -> Campaign -> Global
	var scopes: Array[VariableScope] = [VariableScope.LOCAL, VariableScope.CAMPAIGN, VariableScope.GLOBAL]
	
	for scope in scopes:
		if has_variable(scope, name):
			var variable_dict: Dictionary = _get_scope_dictionary(scope)
			return {
				"found": true,
				"scope": scope,
				"variable": variable_dict[name]
			}
	
	return {"found": false, "scope": VariableScope.LOCAL, "variable": null}

func get_all_variables(scope: VariableScope) -> Dictionary:
	## Get all variables in a scope as Dictionary[String, SexpVariable]
	return _get_scope_dictionary(scope).duplicate()

func get_variable_names(scope: VariableScope) -> Array[String]:
	## Get list of all variable names in the given scope
	var names: Array[String] = []
	var variable_dict: Dictionary = _get_scope_dictionary(scope)
	for name in variable_dict.keys():
		names.append(name)
	return names

func get_variable_count(scope: VariableScope) -> int:
	## Get the number of variables in the given scope
	return _get_scope_dictionary(scope).size()

## Type conversion and validation (WCS compatibility)

func convert_value_to_type(value: SexpResult, target_type: SexpResult.ResultType) -> SexpResult:
	## Convert a value to the target type using WCS semantics
	
	if value == null:
		return SexpResult.create_error("Cannot convert null value", SexpResult.ErrorType.TYPE_MISMATCH)
	
	if value.is_error():
		return value
	
	if value.result_type == target_type:
		return value  # Already correct type
	
	match target_type:
		SexpResult.ResultType.NUMBER:
			return _convert_to_number(value)
		SexpResult.ResultType.STRING:
			return _convert_to_string(value)
		SexpResult.ResultType.BOOLEAN:
			return _convert_to_boolean(value)
		SexpResult.ResultType.OBJECT_REFERENCE:
			return SexpResult.create_error("Cannot convert to object reference", SexpResult.ErrorType.TYPE_MISMATCH)
		_:
			return SexpResult.create_error("Unsupported target type", SexpResult.ErrorType.TYPE_MISMATCH)

## Persistence operations

func save_campaign_variables() -> bool:
	## Save campaign variables to persistent storage
	return _save_variables_to_file(_campaign_variables, _campaign_save_path)

func save_global_variables() -> bool:
	## Save global variables to persistent storage
	return _save_variables_to_file(_global_variables, _global_save_path)

func load_campaign_variables() -> bool:
	## Load campaign variables from persistent storage
	return _load_variables_from_file(_campaign_save_path, VariableScope.CAMPAIGN)

func load_global_variables() -> bool:
	## Load global variables from persistent storage
	return _load_variables_from_file(_global_save_path, VariableScope.GLOBAL)

func set_campaign_save_path(path: String) -> void:
	## Set the save path for campaign variables
	_campaign_save_path = path

func set_global_save_path(path: String) -> void:
	## Set the save path for global variables
	_global_save_path = path

## Performance and configuration

func enable_cache(enabled: bool) -> void:
	## Enable or disable variable access caching
	_cache_enabled = enabled
	if not enabled:
		_variable_cache.clear()

func set_cache_size(max_size: int) -> void:
	## Set maximum cache size (LRU eviction when exceeded)
	_cache_max_size = max_size
	_trim_cache()

func get_access_statistics() -> Dictionary:
	## Get variable access statistics
	var cache_hit_rate: float = 0.0
	var total_cache_ops: int = _access_stats.cache_hits + _access_stats.cache_misses
	if total_cache_ops > 0:
		cache_hit_rate = float(_access_stats.cache_hits) / float(total_cache_ops) * 100.0
	
	return {
		"total_gets": _access_stats.gets,
		"total_sets": _access_stats.sets,
		"cache_hits": _access_stats.cache_hits,
		"cache_misses": _access_stats.cache_misses,
		"cache_hit_rate": cache_hit_rate,
		"cache_size": _variable_cache.size(),
		"local_variables": _local_variables.size(),
		"campaign_variables": _campaign_variables.size(),
		"global_variables": _global_variables.size()
	}

func reset_statistics() -> void:
	## Reset access statistics
	_access_stats = {
		"gets": 0,
		"sets": 0,
		"cache_hits": 0,
		"cache_misses": 0
	}

## Private helper methods

func _get_scope_dictionary(scope: VariableScope) -> Dictionary:
	## Get the dictionary for the given scope
	match scope:
		VariableScope.LOCAL:
			return _local_variables
		VariableScope.CAMPAIGN:
			return _campaign_variables
		VariableScope.GLOBAL:
			return _global_variables
		_:
			push_error("Invalid variable scope: %s" % scope)
			return {}

func _scope_to_string(scope: VariableScope) -> String:
	## Convert scope enum to string
	match scope:
		VariableScope.LOCAL:
			return "local"
		VariableScope.CAMPAIGN:
			return "campaign"
		VariableScope.GLOBAL:
			return "global"
		_:
			return "unknown"

func _update_cache(name: String, scope: VariableScope, variable: SexpVariable) -> void:
	## Update variable cache with LRU management
	if not _cache_enabled:
		return
	
	var cache_key: String = "%s_%s" % [scope, name]
	_variable_cache[cache_key] = {
		"scope": scope,
		"variable": variable,
		"access_time": Time.get_unix_time_from_system()
	}
	
	# Trim cache if needed
	_trim_cache()

func _trim_cache() -> void:
	## Trim cache to maximum size using LRU eviction
	if _variable_cache.size() <= _cache_max_size:
		return
	
	# Sort by access time and remove oldest entries
	var cache_items: Array = []
	for key in _variable_cache.keys():
		var item: Dictionary = _variable_cache[key]
		cache_items.append({"key": key, "access_time": item.access_time})
	
	cache_items.sort_custom(func(a, b): return a.access_time < b.access_time)
	
	# Remove oldest entries
	var items_to_remove: int = _variable_cache.size() - _cache_max_size
	for i in range(items_to_remove):
		_variable_cache.erase(cache_items[i].key)

func _auto_save_scope(scope: VariableScope) -> void:
	## Auto-save a scope if auto-save is enabled
	if not _auto_save_enabled:
		return
	
	match scope:
		VariableScope.CAMPAIGN:
			save_campaign_variables()
		VariableScope.GLOBAL:
			save_global_variables()

func _save_variables_to_file(variables: Dictionary, file_path: String) -> bool:
	## Save variables dictionary to file
	if file_path.is_empty():
		return false
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % file_path)
		return false
	
	var save_data: Dictionary = {}
	for name in variables.keys():
		var variable: SexpVariable = variables[name]
		save_data[name] = variable.serialize()
	
	var json_string: String = JSON.stringify(save_data)
	file.store_var(json_string)
	file.close()
	
	return true

func _load_variables_from_file(file_path: String, scope: VariableScope) -> bool:
	## Load variables from file into the given scope
	if file_path.is_empty() or not FileAccess.file_exists(file_path):
		return false
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file for reading: %s" % file_path)
		return false
	
	var json_string: String = file.get_var()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse JSON from file: %s" % file_path)
		return false
	
	var save_data: Dictionary = json.data
	var variable_dict: Dictionary = _get_scope_dictionary(scope)
	
	for name in save_data.keys():
		var variable_data: Dictionary = save_data[name]
		var variable: SexpVariable = SexpVariable.new()
		if variable.deserialize(variable_data):
			variable.scope = scope  # Ensure correct scope
			variable_dict[name] = variable
	
	return true

func _load_campaign_variables() -> void:
	## Load campaign variables on initialization
	_load_variables_from_file(_campaign_save_path, VariableScope.CAMPAIGN)

func _load_global_variables() -> void:
	## Load global variables on initialization
	_load_variables_from_file(_global_save_path, VariableScope.GLOBAL)

## Type conversion helpers (WCS compatibility)

func _convert_to_number(value: SexpResult) -> SexpResult:
	## Convert value to number using WCS semantics
	match value.result_type:
		SexpResult.ResultType.NUMBER:
			return value
		SexpResult.ResultType.STRING:
			var str_val: String = value.get_string_value()
			var num_val: float = str_val.to_float()
			# WCS uses atoi() equivalent - only parse until first non-digit
			if str_val.is_empty():
				num_val = 0.0
			return SexpResult.create_number(num_val)
		SexpResult.ResultType.BOOLEAN:
			return SexpResult.create_number(1.0 if value.get_boolean_value() else 0.0)
		_:
			return SexpResult.create_error("Cannot convert to number", SexpResult.ErrorType.TYPE_MISMATCH)

func _convert_to_string(value: SexpResult) -> SexpResult:
	## Convert value to string
	match value.result_type:
		SexpResult.ResultType.STRING:
			return value
		SexpResult.ResultType.NUMBER:
			var num: float = value.get_number_value()
			return SexpResult.create_string(str(num))
		SexpResult.ResultType.BOOLEAN:
			return SexpResult.create_string("true" if value.get_boolean_value() else "false")
		SexpResult.ResultType.OBJECT_REFERENCE:
			var obj = value.get_object_reference()
			return SexpResult.create_string(str(obj) if obj != null else "null")
		_:
			return SexpResult.create_error("Cannot convert to string", SexpResult.ErrorType.TYPE_MISMATCH)

func _convert_to_boolean(value: SexpResult) -> SexpResult:
	## Convert value to boolean using WCS semantics
	match value.result_type:
		SexpResult.ResultType.BOOLEAN:
			return value
		SexpResult.ResultType.NUMBER:
			return SexpResult.create_boolean(value.get_number_value() != 0.0)
		SexpResult.ResultType.STRING:
			var str_val: String = value.get_string_value()
			return SexpResult.create_boolean(not str_val.is_empty() and str_val.to_float() != 0.0)
		_:
			return SexpResult.create_error("Cannot convert to boolean", SexpResult.ErrorType.TYPE_MISMATCH)