class_name SexpFunctionRegistry
extends RefCounted

## Function Registry for SEXP Function Management
##
## Manages registration, lookup, and discovery of SEXP function implementations.
## Provides efficient name-to-implementation mapping with metadata support
## and dynamic loading capabilities for the complete WCS operator set.

signal function_registered(function_name: String, function_impl: BaseSexpFunction)
signal function_unregistered(function_name: String)
signal category_added(category_name: String)

const BaseSexpFunction = preload("res://addons/sexp/functions/base_sexp_function.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Core registration data
var function_implementations: Dictionary = {}  # String -> BaseSexpFunction
var function_categories: Dictionary = {}       # String -> Array[String]
var function_aliases: Dictionary = {}          # String -> String (alias -> real_name)
var function_metadata: Dictionary = {}         # String -> Dictionary

## Performance optimization
var lookup_cache: Dictionary = {}              # Recently accessed functions
var category_cache: Dictionary = {}            # Category lookups
var search_index: Dictionary = {}              # For fuzzy function search

## Registry statistics
var total_registrations: int = 0
var total_lookups: int = 0
var cache_hits: int = 0
var cache_misses: int = 0

## Dynamic loading support
var plugin_directories: Array[String] = []
var auto_discovery_enabled: bool = true
var loaded_plugins: Dictionary = {}

## Registry configuration
var max_cache_size: int = 100
var enable_fuzzy_search: bool = true
var case_sensitive_lookup: bool = false

## Initialize registry
func _init():
	_setup_core_categories()
	_initialize_search_index()

## Setup core function categories
func _setup_core_categories() -> void:
	var core_categories: Array[String] = [
		"arithmetic", "comparison", "logical", "control", "type",
		"string", "variable", "mission", "ship", "object",
		"conditional", "math", "time", "debug", "user"
	]
	
	for category in core_categories:
		function_categories[category] = []

## Initialize search index for function discovery
func _initialize_search_index() -> void:
	search_index = {
		"by_name": {},
		"by_category": {},
		"by_description": {},
		"by_signature": {}
	}

## Register a function implementation
func register_function(function_impl: BaseSexpFunction, aliases: Array[String] = []) -> bool:
	if function_impl == null:
		push_error("SexpFunctionRegistry: Cannot register null function")
		return false
	
	var function_name: String = function_impl.function_name
	if function_name.is_empty():
		push_error("SexpFunctionRegistry: Function name cannot be empty")
		return false
	
	# Normalize function name
	var normalized_name: String = _normalize_name(function_name)
	
	# Check for existing registration
	if normalized_name in function_implementations:
		push_warning("SexpFunctionRegistry: Overwriting existing function '%s'" % function_name)
	
	# Register the function
	function_implementations[normalized_name] = function_impl
	total_registrations += 1
	
	# Register in category
	var category: String = function_impl.function_category
	if category not in function_categories:
		function_categories[category] = []
		category_added.emit(category)
	
	if function_name not in function_categories[category]:
		function_categories[category].append(function_name)
	
	# Register aliases
	for alias in aliases:
		var normalized_alias: String = _normalize_name(alias)
		function_aliases[normalized_alias] = normalized_name
	
	# Store metadata
	function_metadata[normalized_name] = function_impl.get_signature_info()
	
	# Update search index
	_update_search_index(function_impl)
	
	# Clear caches
	_clear_caches()
	
	function_registered.emit(function_name, function_impl)
	print("SexpFunctionRegistry: Registered function '%s' in category '%s'" % [function_name, category])
	
	return true

## Unregister a function
func unregister_function(function_name: String) -> bool:
	var normalized_name: String = _normalize_name(function_name)
	
	if normalized_name not in function_implementations:
		push_warning("SexpFunctionRegistry: Function '%s' not found for unregistration" % function_name)
		return false
	
	var function_impl: BaseSexpFunction = function_implementations[normalized_name]
	var category: String = function_impl.function_category
	
	# Remove from implementations
	function_implementations.erase(normalized_name)
	
	# Remove from category
	if category in function_categories:
		var category_list: Array = function_categories[category]
		var index: int = category_list.find(function_name)
		if index >= 0:
			category_list.remove_at(index)
	
	# Remove aliases
	var aliases_to_remove: Array[String] = []
	for alias in function_aliases:
		if function_aliases[alias] == normalized_name:
			aliases_to_remove.append(alias)
	
	for alias in aliases_to_remove:
		function_aliases.erase(alias)
	
	# Remove metadata
	function_metadata.erase(normalized_name)
	
	# Update search index
	_remove_from_search_index(function_impl)
	
	# Clear caches
	_clear_caches()
	
	function_unregistered.emit(function_name)
	return true

## Get function implementation by name
func get_function(function_name: String) -> BaseSexpFunction:
	var normalized_name: String = _normalize_name(function_name)
	total_lookups += 1
	
	# Check cache first
	if normalized_name in lookup_cache:
		cache_hits += 1
		return lookup_cache[normalized_name]
	
	cache_misses += 1
	var function_impl: BaseSexpFunction = null
	
	# Direct lookup
	if normalized_name in function_implementations:
		function_impl = function_implementations[normalized_name]
	# Check aliases
	elif normalized_name in function_aliases:
		var real_name: String = function_aliases[normalized_name]
		if real_name in function_implementations:
			function_impl = function_implementations[real_name]
	
	# Cache the result (even if null)
	if lookup_cache.size() >= max_cache_size:
		_trim_cache()
	lookup_cache[normalized_name] = function_impl
	
	return function_impl

## Check if function exists
func has_function(function_name: String) -> bool:
	return get_function(function_name) != null

## Get all function names
func get_all_function_names() -> Array[String]:
	var names: Array[String] = []
	for name in function_implementations.keys():
		var function_impl: BaseSexpFunction = function_implementations[name]
		names.append(function_impl.function_name)
	return names

## Get functions in category
func get_functions_in_category(category: String) -> Array[String]:
	if category in category_cache:
		return category_cache[category].duplicate()
	
	var functions: Array[String] = []
	if category in function_categories:
		functions = function_categories[category].duplicate()
	
	# Cache result
	category_cache[category] = functions
	return functions

## Get all categories
func get_all_categories() -> Array[String]:
	return function_categories.keys()

## Get function metadata
func get_function_metadata(function_name: String) -> Dictionary:
	var normalized_name: String = _normalize_name(function_name)
	if normalized_name in function_metadata:
		return function_metadata[normalized_name].duplicate()
	return {}

## Search functions by name pattern
func search_functions(query: String, max_results: int = 10) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var normalized_query: String = _normalize_name(query)
	
	# Exact matches first
	for name in function_implementations.keys():
		var function_impl: BaseSexpFunction = function_implementations[name]
		var original_name: String = function_impl.function_name
		
		if _normalize_name(original_name) == normalized_query:
			results.append(_create_search_result(function_impl, 1.0, "exact"))
			continue
	
	# Prefix matches
	for name in function_implementations.keys():
		var function_impl: BaseSexpFunction = function_implementations[name]
		var original_name: String = function_impl.function_name
		
		if _normalize_name(original_name).begins_with(normalized_query):
			results.append(_create_search_result(function_impl, 0.8, "prefix"))
	
	# Substring matches
	if enable_fuzzy_search:
		for name in function_implementations.keys():
			var function_impl: BaseSexpFunction = function_implementations[name]
			var original_name: String = function_impl.function_name
			
			if _normalize_name(original_name).contains(normalized_query):
				results.append(_create_search_result(function_impl, 0.6, "substring"))
	
	# Sort by relevance score
	results.sort_custom(func(a, b): return a.score > b.score)
	
	# Limit results
	if results.size() > max_results:
		results = results.slice(0, max_results)
	
	return results

## Get function suggestions for typos
func get_function_suggestions(function_name: String, max_suggestions: int = 5) -> Array[String]:
	var suggestions: Array[String] = []
	var normalized_name: String = _normalize_name(function_name)
	
	# Simple Levenshtein distance-based suggestions
	var all_names: Array[String] = get_all_function_names()
	var scored_suggestions: Array[Dictionary] = []
	
	for name in all_names:
		var distance: int = _levenshtein_distance(normalized_name, _normalize_name(name))
		if distance <= 3 and distance > 0:  # Similar but not exact
			scored_suggestions.append({"name": name, "distance": distance})
	
	# Sort by distance (closer is better)
	scored_suggestions.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Extract names
	for suggestion in scored_suggestions:
		suggestions.append(suggestion.name)
		if suggestions.size() >= max_suggestions:
			break
	
	return suggestions

## Register functions from directory (dynamic loading)
func register_functions_from_directory(directory_path: String) -> int:
	var registered_count: int = 0
	
	if not DirAccess.dir_exists_absolute(directory_path):
		push_warning("SexpFunctionRegistry: Directory not found: %s" % directory_path)
		return 0
	
	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null:
		push_error("SexpFunctionRegistry: Failed to open directory: %s" % directory_path)
		return 0
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while not file_name.is_empty():
		if file_name.ends_with(".gd") and not file_name.begins_with("."):
			var script_path: String = directory_path.path_join(file_name)
			if _try_load_function_from_script(script_path):
				registered_count += 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("SexpFunctionRegistry: Loaded %d functions from %s" % [registered_count, directory_path])
	return registered_count

## Add plugin directory for auto-discovery
func add_plugin_directory(directory_path: String) -> void:
	if directory_path not in plugin_directories:
		plugin_directories.append(directory_path)
		if auto_discovery_enabled:
			register_functions_from_directory(directory_path)

## Enable/disable auto-discovery
func set_auto_discovery(enabled: bool) -> void:
	auto_discovery_enabled = enabled
	if enabled:
		for directory in plugin_directories:
			register_functions_from_directory(directory)

## Get registry statistics
func get_statistics() -> Dictionary:
	var stats: Dictionary = {
		"total_functions": function_implementations.size(),
		"total_categories": function_categories.size(),
		"total_aliases": function_aliases.size(),
		"total_registrations": total_registrations,
		"total_lookups": total_lookups,
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"cache_hit_rate": float(cache_hits) / max(1, total_lookups),
		"cache_size": lookup_cache.size(),
		"plugin_directories": plugin_directories.size(),
		"loaded_plugins": loaded_plugins.size()
	}
	
	# Category breakdown
	stats["category_breakdown"] = {}
	for category in function_categories:
		stats["category_breakdown"][category] = function_categories[category].size()
	
	return stats

## Clear all caches
func _clear_caches() -> void:
	lookup_cache.clear()
	category_cache.clear()

## Trim cache to max size
func _trim_cache() -> void:
	# Simple LRU-style trimming - remove half the cache
	var keys_to_remove: Array = lookup_cache.keys().slice(0, lookup_cache.size() / 2)
	for key in keys_to_remove:
		lookup_cache.erase(key)

## Normalize function name for consistent lookup
func _normalize_name(name: String) -> String:
	if case_sensitive_lookup:
		return name
	return name.to_lower()

## Update search index when function is added
func _update_search_index(function_impl: BaseSexpFunction) -> void:
	var name: String = function_impl.function_name
	var category: String = function_impl.function_category
	var description: String = function_impl.function_description
	
	# Index by name
	search_index["by_name"][_normalize_name(name)] = name
	
	# Index by category
	if category not in search_index["by_category"]:
		search_index["by_category"][category] = []
	search_index["by_category"][category].append(name)
	
	# Index by description keywords
	var keywords: Array[String] = description.split(" ")
	for keyword in keywords:
		keyword = keyword.to_lower().strip_edges()
		if keyword.length() > 2:  # Skip short words
			if keyword not in search_index["by_description"]:
				search_index["by_description"][keyword] = []
			search_index["by_description"][keyword].append(name)

## Remove function from search index
func _remove_from_search_index(function_impl: BaseSexpFunction) -> void:
	var name: String = function_impl.function_name
	var category: String = function_impl.function_category
	
	# Remove from name index
	search_index["by_name"].erase(_normalize_name(name))
	
	# Remove from category index
	if category in search_index["by_category"]:
		var category_list: Array = search_index["by_category"][category]
		var index: int = category_list.find(name)
		if index >= 0:
			category_list.remove_at(index)

## Create search result entry
func _create_search_result(function_impl: BaseSexpFunction, score: float, match_type: String) -> Dictionary:
	return {
		"name": function_impl.function_name,
		"category": function_impl.function_category,
		"description": function_impl.function_description,
		"score": score,
		"match_type": match_type,
		"signature": function_impl.function_signature
	}

## Try to load function from script file
func _try_load_function_from_script(script_path: String) -> bool:
	try:
		var script: Script = load(script_path)
		if script == null:
			return false
		
		# Check if script extends BaseSexpFunction
		var instance: Object = script.new()
		if not (instance is BaseSexpFunction):
			instance.free()
			return false
		
		var function_impl: BaseSexpFunction = instance as BaseSexpFunction
		var success: bool = register_function(function_impl)
		
		if success:
			loaded_plugins[script_path] = function_impl.function_name
		
		return success
		
	except error:
		push_warning("SexpFunctionRegistry: Failed to load function from %s: %s" % [script_path, error])
		return false

## Calculate Levenshtein distance for function suggestions
func _levenshtein_distance(s1: String, s2: String) -> int:
	var len1: int = s1.length()
	var len2: int = s2.length()
	
	if len1 == 0:
		return len2
	if len2 == 0:
		return len1
	
	var matrix: Array = []
	for i in range(len1 + 1):
		matrix.append([])
		for j in range(len2 + 1):
			matrix[i].append(0)
	
	# Initialize first row and column
	for i in range(len1 + 1):
		matrix[i][0] = i
	for j in range(len2 + 1):
		matrix[0][j] = j
	
	# Fill the matrix
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost: int = 0 if s1[i - 1] == s2[j - 1] else 1
			matrix[i][j] = min(
				matrix[i - 1][j] + 1,      # deletion
				min(
					matrix[i][j - 1] + 1,  # insertion
					matrix[i - 1][j - 1] + cost  # substitution
				)
			)
	
	return matrix[len1][len2]

## String representation for debugging
func _to_string() -> String:
	return "SexpFunctionRegistry(functions=%d, categories=%d, lookups=%d)" % [
		function_implementations.size(),
		function_categories.size(),
		total_lookups
	]