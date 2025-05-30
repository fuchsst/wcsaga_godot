class_name SexpHelpSystem
extends RefCounted

## SEXP Help System
##
## Provides comprehensive help and documentation access for SEXP functions.
## Supports runtime documentation generation, interactive help, search,
## and integration with development tools.

signal help_requested(function_name: String, help_type: String)
signal search_performed(query: String, results_count: int)

const SexpFunctionRegistry = preload("res://addons/sexp/functions/sexp_function_registry.gd")
const SexpFunctionMetadata = preload("res://addons/sexp/functions/sexp_function_metadata.gd")
const BaseSexpFunction = preload("res://addons/sexp/functions/base_sexp_function.gd")

## Help system configuration
var registry: SexpFunctionRegistry = null
var default_help_format: String = "text"
var enable_syntax_highlighting: bool = true
var show_performance_info: bool = false
var show_wcs_compatibility: bool = true
var max_search_results: int = 20

## Documentation cache
var help_cache: Dictionary = {}  # function_name -> formatted_help
var metadata_cache: Dictionary = {}  # function_name -> metadata
var search_cache: Dictionary = {}  # query -> results

## Interactive help state
var current_context: String = ""
var help_history: Array[String] = []
var bookmark_functions: Array[String] = []

## Documentation templates
var help_templates: Dictionary = {}

## Initialize help system
func _init(function_registry: SexpFunctionRegistry = null):
	if function_registry != null:
		registry = function_registry
	_setup_help_templates()

## Setup default help templates
func _setup_help_templates() -> void:
	help_templates = {
		"quick": _get_quick_help_template(),
		"detailed": _get_detailed_help_template(),
		"examples": _get_examples_template(),
		"signature": _get_signature_template(),
		"errors": _get_errors_template()
	}

## Get function help
func get_function_help(function_name: String, format: String = "", help_type: String = "detailed") -> String:
	if registry == null:
		return "Help system not initialized with function registry"
	
	var use_format: String = format if not format.is_empty() else default_help_format
	var cache_key: String = "%s_%s_%s" % [function_name, use_format, help_type]
	
	# Check cache first
	if cache_key in help_cache:
		help_requested.emit(function_name, help_type)
		return help_cache[cache_key]
	
	# Get function implementation
	var function_impl: BaseSexpFunction = registry.get_function(function_name)
	if function_impl == null:
		var suggestions: Array[String] = registry.get_function_suggestions(function_name, 3)
		var suggestion_text: String = ""
		if not suggestions.is_empty():
			suggestion_text = "\n\nDid you mean: %s?" % ", ".join(suggestions)
		
		return "Function '%s' not found.%s\n\nUse 'help functions' to see all available functions." % [function_name, suggestion_text]
	
	# Generate help based on type
	var help_text: String = ""
	match help_type.to_lower():
		"quick":
			help_text = _generate_quick_help(function_impl, use_format)
		"detailed":
			help_text = _generate_detailed_help(function_impl, use_format)
		"examples":
			help_text = _generate_examples_help(function_impl, use_format)
		"signature":
			help_text = _generate_signature_help(function_impl, use_format)
		"errors":
			help_text = _generate_errors_help(function_impl, use_format)
		"metadata":
			help_text = _generate_metadata_help(function_impl, use_format)
		_:
			help_text = _generate_detailed_help(function_impl, use_format)
	
	# Cache the result
	help_cache[cache_key] = help_text
	
	# Update history
	if function_name not in help_history:
		help_history.append(function_name)
	if help_history.size() > 50:  # Keep last 50 entries
		help_history = help_history.slice(-50)
	
	help_requested.emit(function_name, help_type)
	return help_text

## Search functions by query
func search_functions(query: String, search_type: String = "all") -> Array[Dictionary]:
	if registry == null:
		return []
	
	var cache_key: String = "%s_%s" % [query, search_type]
	
	# Check cache first
	if cache_key in search_cache:
		search_performed.emit(query, search_cache[cache_key].size())
		return search_cache[cache_key]
	
	var results: Array[Dictionary] = []
	
	match search_type.to_lower():
		"name":
			results = _search_by_name(query)
		"category":
			results = _search_by_category(query)
		"description":
			results = _search_by_description(query)
		"examples":
			results = _search_by_examples(query)
		"all":
			results = _search_comprehensive(query)
		_:
			results = _search_comprehensive(query)
	
	# Limit results
	if results.size() > max_search_results:
		results = results.slice(0, max_search_results)
	
	# Cache results
	search_cache[cache_key] = results
	
	search_performed.emit(query, results.size())
	return results

## Get list of all functions with basic info
func get_function_list(category: String = "", format: String = "text") -> String:
	if registry == null:
		return "Registry not available"
	
	var functions: Array[String] = []
	
	if category.is_empty():
		functions = registry.get_all_function_names()
	else:
		functions = registry.get_functions_in_category(category)
	
	functions.sort()
	
	var output: String = ""
	
	match format.to_lower():
		"text":
			output = _format_function_list_text(functions, category)
		"markdown":
			output = _format_function_list_markdown(functions, category)
		"json":
			output = _format_function_list_json(functions, category)
		_:
			output = _format_function_list_text(functions, category)
	
	return output

## Get category overview
func get_category_overview(format: String = "text") -> String:
	if registry == null:
		return "Registry not available"
	
	var categories: Array[String] = registry.get_all_categories()
	categories.sort()
	
	var output: String = ""
	
	match format.to_lower():
		"text":
			output = _format_category_overview_text(categories)
		"markdown":
			output = _format_category_overview_markdown(categories)
		_:
			output = _format_category_overview_text(categories)
	
	return output

## Get function usage examples
func get_function_examples(function_name: String, format: String = "text") -> String:
	return get_function_help(function_name, format, "examples")

## Get function signature
func get_function_signature(function_name: String, format: String = "text") -> String:
	return get_function_help(function_name, format, "signature")

## Add bookmark
func add_bookmark(function_name: String) -> bool:
	if function_name not in bookmark_functions:
		bookmark_functions.append(function_name)
		return true
	return false

## Remove bookmark
func remove_bookmark(function_name: String) -> bool:
	var index: int = bookmark_functions.find(function_name)
	if index >= 0:
		bookmark_functions.remove_at(index)
		return true
	return false

## Get bookmarked functions
func get_bookmarks(format: String = "text") -> String:
	if bookmark_functions.is_empty():
		return "No bookmarked functions"
	
	match format.to_lower():
		"text":
			return "Bookmarked Functions:\n" + "\n".join(bookmark_functions)
		"list":
			return bookmark_functions
		_:
			return "\n".join(bookmark_functions)

## Get help history
func get_help_history(limit: int = 10) -> Array[String]:
	var history_limit: int = min(limit, help_history.size())
	return help_history.slice(-history_limit)

## Clear caches
func clear_cache() -> void:
	help_cache.clear()
	metadata_cache.clear()
	search_cache.clear()

## Generate quick help
func _generate_quick_help(function_impl: BaseSexpFunction, format: String) -> String:
	var help: String = ""
	
	match format.to_lower():
		"text":
			help += "%s (%s)\n" % [function_impl.function_name, function_impl.function_category]
			help += "%s\n" % function_impl.function_description
			if not function_impl.function_signature.is_empty():
				help += "Usage: %s" % function_impl.function_signature
		"markdown":
			help += "## %s\n" % function_impl.function_name
			help += "**Category:** %s  \n" % function_impl.function_category
			help += "%s\n" % function_impl.function_description
		_:
			help = function_impl.get_help_text()
	
	return help

## Generate detailed help
func _generate_detailed_help(function_impl: BaseSexpFunction, format: String) -> String:
	# Try to get metadata for more detailed information
	var metadata: SexpFunctionMetadata = _get_function_metadata(function_impl)
	
	if metadata != null:
		return metadata.generate_help_text(format)
	else:
		# Fall back to basic help from function
		return function_impl.get_help_text()

## Generate examples help
func _generate_examples_help(function_impl: BaseSexpFunction, format: String) -> String:
	var examples: Array[String] = function_impl.get_usage_examples()
	
	if examples.is_empty():
		return "No examples available for function '%s'" % function_impl.function_name
	
	var help: String = ""
	
	match format.to_lower():
		"text":
			help += "Examples for %s:\n" % function_impl.function_name
			for i in range(examples.size()):
				help += "  %d. %s\n" % [i + 1, examples[i]]
		"markdown":
			help += "# Examples: %s\n\n" % function_impl.function_name
			for example in examples:
				help += "```lisp\n%s\n```\n\n" % example
		_:
			help = "\n".join(examples)
	
	return help

## Generate signature help
func _generate_signature_help(function_impl: BaseSexpFunction, format: String) -> String:
	var signature_info: Dictionary = function_impl.get_signature_info()
	
	var help: String = ""
	
	match format.to_lower():
		"text":
			help += "Function: %s\n" % signature_info["name"]
			help += "Category: %s\n" % signature_info["category"]
			if not signature_info["signature"].is_empty():
				help += "Signature: %s\n" % signature_info["signature"]
			help += "Arguments: %d to %d\n" % [signature_info["min_args"], signature_info["max_args"]]
		"markdown":
			help += "## %s\n\n" % signature_info["name"]
			help += "**Category:** %s  \n" % signature_info["category"]
			if not signature_info["signature"].is_empty():
				help += "**Signature:** `%s`  \n" % signature_info["signature"]
		_:
			help = str(signature_info)
	
	return help

## Generate errors help
func _generate_errors_help(function_impl: BaseSexpFunction, format: String) -> String:
	var help: String = "Error Information for %s:\n\n" % function_impl.function_name
	
	# Get performance stats to show error information
	var stats: Dictionary = function_impl.get_performance_stats()
	
	help += "Error count: %d\n" % stats["error_count"]
	help += "Error rate: %.2f%%\n" % (stats["error_rate"] * 100)
	
	if not stats["last_error"].is_empty():
		help += "Last error: %s\n" % stats["last_error"]
	
	help += "\nCommon error conditions:\n"
	help += "• Invalid argument count\n"
	help += "• Type mismatches\n"
	help += "• Out of range values\n"
	
	return help

## Generate metadata help
func _generate_metadata_help(function_impl: BaseSexpFunction, format: String) -> String:
	var stats: Dictionary = function_impl.get_performance_stats()
	var signature: Dictionary = function_impl.get_signature_info()
	
	var help: String = ""
	
	match format.to_lower():
		"json":
			var metadata: Dictionary = {
				"function_info": signature,
				"performance_stats": stats
			}
			help = JSON.stringify(metadata, "\t")
		_:
			help += "Metadata for %s:\n\n" % function_impl.function_name
			help += "Performance Statistics:\n"
			help += "  Calls: %d\n" % stats["call_count"]
			help += "  Average time: %.3f ms\n" % stats["average_time_ms"]
			help += "  Total time: %.3f ms\n" % stats["total_time_ms"]
			help += "  Error rate: %.2f%%\n" % (stats["error_rate"] * 100)
			
			help += "\nFunction Properties:\n"
			help += "  Pure: %s\n" % signature["is_pure"]
			help += "  Cacheable: %s\n" % signature["is_cacheable"]
	
	return help

## Search by function name
func _search_by_name(query: String) -> Array[Dictionary]:
	return registry.search_functions(query, max_search_results)

## Search by category
func _search_by_category(query: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var categories: Array[String] = registry.get_all_categories()
	
	for category in categories:
		if category.to_lower().contains(query.to_lower()):
			var functions: Array[String] = registry.get_functions_in_category(category)
			for func_name in functions:
				var function_impl: BaseSexpFunction = registry.get_function(func_name)
				if function_impl != null:
					results.append({
						"name": func_name,
						"category": category,
						"description": function_impl.function_description,
						"score": 0.8,
						"match_type": "category"
					})
	
	return results

## Search by description
func _search_by_description(query: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var all_functions: Array[String] = registry.get_all_function_names()
	var query_lower: String = query.to_lower()
	
	for func_name in all_functions:
		var function_impl: BaseSexpFunction = registry.get_function(func_name)
		if function_impl != null and function_impl.function_description.to_lower().contains(query_lower):
			results.append({
				"name": func_name,
				"category": function_impl.function_category,
				"description": function_impl.function_description,
				"score": 0.7,
				"match_type": "description"
			})
	
	return results

## Search by examples
func _search_by_examples(query: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var all_functions: Array[String] = registry.get_all_function_names()
	var query_lower: String = query.to_lower()
	
	for func_name in all_functions:
		var function_impl: BaseSexpFunction = registry.get_function(func_name)
		if function_impl != null:
			var examples: Array[String] = function_impl.get_usage_examples()
			for example in examples:
				if example.to_lower().contains(query_lower):
					results.append({
						"name": func_name,
						"category": function_impl.function_category,
						"description": function_impl.function_description,
						"score": 0.6,
						"match_type": "example"
					})
					break
	
	return results

## Comprehensive search
func _search_comprehensive(query: String) -> Array[Dictionary]:
	var all_results: Array[Dictionary] = []
	
	# Search by name (highest priority)
	var name_results: Array[Dictionary] = _search_by_name(query)
	all_results.append_array(name_results)
	
	# Search by category
	var category_results: Array[Dictionary] = _search_by_category(query)
	all_results.append_array(category_results)
	
	# Search by description
	var desc_results: Array[Dictionary] = _search_by_description(query)
	all_results.append_array(desc_results)
	
	# Remove duplicates and sort by score
	var unique_results: Dictionary = {}
	for result in all_results:
		var key: String = result["name"]
		if key not in unique_results or result["score"] > unique_results[key]["score"]:
			unique_results[key] = result
	
	var final_results: Array[Dictionary] = unique_results.values()
	final_results.sort_custom(func(a, b): return a.score > b.score)
	
	return final_results

## Format function list as text
func _format_function_list_text(functions: Array[String], category: String) -> String:
	var title: String = "All Functions" if category.is_empty() else "Functions in '%s'" % category
	var output: String = "%s (%d functions):\n\n" % [title, functions.size()]
	
	for func_name in functions:
		var function_impl: BaseSexpFunction = registry.get_function(func_name)
		if function_impl != null:
			output += "• %s - %s\n" % [func_name, function_impl.function_description]
		else:
			output += "• %s\n" % func_name
	
	return output

## Format function list as markdown
func _format_function_list_markdown(functions: Array[String], category: String) -> String:
	var title: String = "All Functions" if category.is_empty() else "Functions in '%s'" % category
	var output: String = "# %s\n\n" % title
	
	for func_name in functions:
		var function_impl: BaseSexpFunction = registry.get_function(func_name)
		if function_impl != null:
			output += "- **%s** - %s\n" % [func_name, function_impl.function_description]
		else:
			output += "- **%s**\n" % func_name
	
	return output

## Format function list as JSON
func _format_function_list_json(functions: Array[String], category: String) -> String:
	var function_list: Array[Dictionary] = []
	
	for func_name in functions:
		var function_impl: BaseSexpFunction = registry.get_function(func_name)
		if function_impl != null:
			function_list.append({
				"name": func_name,
				"category": function_impl.function_category,
				"description": function_impl.function_description
			})
		else:
			function_list.append({"name": func_name})
	
	return JSON.stringify({"category": category, "functions": function_list}, "\t")

## Format category overview as text
func _format_category_overview_text(categories: Array[String]) -> String:
	var output: String = "Function Categories:\n\n"
	
	for category in categories:
		var functions: Array[String] = registry.get_functions_in_category(category)
		output += "• %s (%d functions)\n" % [category, functions.size()]
	
	return output

## Format category overview as markdown
func _format_category_overview_markdown(categories: Array[String]) -> String:
	var output: String = "# Function Categories\n\n"
	
	for category in categories:
		var functions: Array[String] = registry.get_functions_in_category(category)
		output += "- **%s** (%d functions)\n" % [category, functions.size()]
	
	return output

## Get function metadata (placeholder for future metadata integration)
func _get_function_metadata(function_impl: BaseSexpFunction) -> SexpFunctionMetadata:
	# This would integrate with a metadata registry in a full implementation
	return null

## Get help templates
func _get_quick_help_template() -> String:
	return "{name} ({category})\n{description}"

func _get_detailed_help_template() -> String:
	return "{name}\n{category}\n{description}\n{signature}\n{arguments}\n{examples}"

func _get_examples_template() -> String:
	return "Examples for {name}:\n{examples}"

func _get_signature_template() -> String:
	return "{name}: {signature}"

func _get_errors_template() -> String:
	return "Error information for {name}:\n{error_conditions}"

## String representation for debugging
func _to_string() -> String:
	return "SexpHelpSystem(registry=%s, cache_size=%d, history=%d)" % [
		"available" if registry != null else "none",
		help_cache.size(),
		help_history.size()
	]