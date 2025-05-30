class_name SexpFunctionMetadata
extends RefCounted

## SEXP Function Metadata System
##
## Manages comprehensive metadata for SEXP functions including documentation,
## signatures, usage examples, and performance characteristics. Supports
## runtime documentation generation and help system integration.

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Function metadata structure
var function_name: String = ""
var function_category: String = ""
var function_description: String = ""
var detailed_description: String = ""
var function_signature: String = ""

## Argument information
var arguments: Array[Dictionary] = []  # [{name, type, description, optional, default}]
var return_type: SexpResult.ResultType = SexpResult.ResultType.VOID
var return_description: String = ""

## Usage and examples
var usage_examples: Array[Dictionary] = []  # [{expression, description, result}]
var related_functions: Array[String] = []
var see_also: Array[String] = []

## Technical characteristics
var is_pure_function: bool = true
var is_deterministic: bool = true
var is_side_effect_free: bool = true
var is_thread_safe: bool = true
var complexity_rating: String = "O(1)"

## WCS compatibility
var wcs_equivalent: String = ""
var wcs_differences: String = ""
var wcs_reference_file: String = ""
var wcs_reference_line: int = -1

## Version and support information
var added_in_version: String = ""
var deprecated_in_version: String = ""
var deprecation_message: String = ""
var minimum_wcs_version: String = ""
var support_status: String = "stable"  # stable, experimental, deprecated

## Performance characteristics
var typical_execution_time: String = "< 1ms"
var memory_usage: String = "minimal"
var cache_behavior: String = "cacheable"
var performance_notes: String = ""

## Validation and constraints
var validation_rules: Array[String] = []
var constraint_descriptions: Array[String] = []
var error_conditions: Array[Dictionary] = []  # [{condition, error_type, message}]

## Tags and categorization
var tags: Array[String] = []
var difficulty_level: String = "beginner"  # beginner, intermediate, advanced
var use_frequency: String = "common"       # rare, uncommon, common, frequent

## Initialize metadata
func _init(name: String = ""):
	function_name = name

## Set basic function information
func set_basic_info(name: String, category: String, description: String, signature: String = "") -> void:
	function_name = name
	function_category = category
	function_description = description
	function_signature = signature

## Add argument information
func add_argument(name: String, type: SexpResult.ResultType, description: String, optional: bool = false, default_value: String = "") -> void:
	arguments.append({
		"name": name,
		"type": type,
		"description": description,
		"optional": optional,
		"default_value": default_value,
		"type_name": SexpResult.get_type_name(type)
	})

## Set return information
func set_return_info(type: SexpResult.ResultType, description: String = "") -> void:
	return_type = type
	return_description = description

## Add usage example
func add_example(expression: String, description: String, expected_result: String = "", notes: String = "") -> void:
	usage_examples.append({
		"expression": expression,
		"description": description,
		"expected_result": expected_result,
		"notes": notes
	})

## Add related function
func add_related_function(function_name: String) -> void:
	if function_name not in related_functions:
		related_functions.append(function_name)

## Add see also reference
func add_see_also(reference: String) -> void:
	if reference not in see_also:
		see_also.append(reference)

## Set technical characteristics
func set_technical_info(pure: bool = true, deterministic: bool = true, side_effect_free: bool = true, thread_safe: bool = true) -> void:
	is_pure_function = pure
	is_deterministic = deterministic
	is_side_effect_free = side_effect_free
	is_thread_safe = thread_safe

## Set WCS compatibility information
func set_wcs_info(equivalent: String = "", differences: String = "", reference_file: String = "", reference_line: int = -1) -> void:
	wcs_equivalent = equivalent
	wcs_differences = differences
	wcs_reference_file = reference_file
	wcs_reference_line = reference_line

## Set version information
func set_version_info(added: String = "", deprecated: String = "", deprecation_msg: String = "", min_wcs: String = "") -> void:
	added_in_version = added
	deprecated_in_version = deprecated
	deprecation_message = deprecation_msg
	minimum_wcs_version = min_wcs

## Set performance characteristics
func set_performance_info(execution_time: String = "< 1ms", memory: String = "minimal", cache: String = "cacheable", notes: String = "") -> void:
	typical_execution_time = execution_time
	memory_usage = memory
	cache_behavior = cache
	performance_notes = notes

## Add validation rule description
func add_validation_rule(rule_description: String) -> void:
	if rule_description not in validation_rules:
		validation_rules.append(rule_description)

## Add constraint description
func add_constraint(constraint_description: String) -> void:
	if constraint_description not in constraint_descriptions:
		constraint_descriptions.append(constraint_description)

## Add error condition
func add_error_condition(condition: String, error_type: String, message: String) -> void:
	error_conditions.append({
		"condition": condition,
		"error_type": error_type,
		"message": message
	})

## Add tag
func add_tag(tag: String) -> void:
	if tag not in tags:
		tags.append(tag)

## Set categorization
func set_categorization(difficulty: String = "beginner", frequency: String = "common") -> void:
	difficulty_level = difficulty
	use_frequency = frequency

## Generate comprehensive help text
func generate_help_text(format: String = "text") -> String:
	match format.to_lower():
		"text":
			return _generate_text_help()
		"markdown":
			return _generate_markdown_help()
		"html":
			return _generate_html_help()
		"json":
			return _generate_json_help()
		_:
			return _generate_text_help()

## Generate text format help
func _generate_text_help() -> String:
	var help: String = ""
	
	# Header
	help += "═══════════════════════════════════════════════════════════════\n"
	help += "  SEXP Function: %s\n" % function_name
	help += "═══════════════════════════════════════════════════════════════\n\n"
	
	# Basic information
	help += "Category: %s\n" % function_category
	help += "Description: %s\n" % function_description
	
	if not detailed_description.is_empty():
		help += "\nDetailed Description:\n%s\n" % detailed_description
	
	# Signature
	if not function_signature.is_empty():
		help += "\nSignature: %s\n" % function_signature
	
	# Arguments
	if not arguments.is_empty():
		help += "\nArguments:\n"
		for i in range(arguments.size()):
			var arg: Dictionary = arguments[i]
			var optional_marker: String = " (optional)" if arg["optional"] else ""
			var default_info: String = ""
			if arg["optional"] and not arg["default_value"].is_empty():
				default_info = " [default: %s]" % arg["default_value"]
			
			help += "  %d. %s (%s)%s%s\n     %s\n" % [
				i + 1,
				arg["name"],
				arg["type_name"],
				optional_marker,
				default_info,
				arg["description"]
			]
	
	# Return value
	if return_type != SexpResult.ResultType.VOID:
		help += "\nReturns: %s\n" % SexpResult.get_type_name(return_type)
		if not return_description.is_empty():
			help += "  %s\n" % return_description
	
	# Examples
	if not usage_examples.is_empty():
		help += "\nExamples:\n"
		for i in range(usage_examples.size()):
			var example: Dictionary = usage_examples[i]
			help += "  %d. %s\n" % [i + 1, example["expression"]]
			help += "     %s\n" % example["description"]
			if not example["expected_result"].is_empty():
				help += "     Result: %s\n" % example["expected_result"]
			if not example["notes"].is_empty():
				help += "     Note: %s\n" % example["notes"]
			help += "\n"
	
	# Technical information
	help += "\nTechnical Information:\n"
	help += "  Pure function: %s\n" % ("Yes" if is_pure_function else "No")
	help += "  Deterministic: %s\n" % ("Yes" if is_deterministic else "No")
	help += "  Side effects: %s\n" % ("None" if is_side_effect_free else "Has side effects")
	help += "  Thread safe: %s\n" % ("Yes" if is_thread_safe else "No")
	help += "  Complexity: %s\n" % complexity_rating
	help += "  Execution time: %s\n" % typical_execution_time
	help += "  Memory usage: %s\n" % memory_usage
	help += "  Cache behavior: %s\n" % cache_behavior
	
	# Performance notes
	if not performance_notes.is_empty():
		help += "\nPerformance Notes:\n%s\n" % performance_notes
	
	# Validation rules
	if not validation_rules.is_empty():
		help += "\nValidation Rules:\n"
		for rule in validation_rules:
			help += "  • %s\n" % rule
	
	# Constraints
	if not constraint_descriptions.is_empty():
		help += "\nConstraints:\n"
		for constraint in constraint_descriptions:
			help += "  • %s\n" % constraint
	
	# Error conditions
	if not error_conditions.is_empty():
		help += "\nError Conditions:\n"
		for error in error_conditions:
			help += "  • %s: %s (%s)\n" % [error["condition"], error["message"], error["error_type"]]
	
	# WCS compatibility
	if not wcs_equivalent.is_empty():
		help += "\nWCS Compatibility:\n"
		help += "  Equivalent: %s\n" % wcs_equivalent
		if not wcs_differences.is_empty():
			help += "  Differences: %s\n" % wcs_differences
		if not wcs_reference_file.is_empty():
			help += "  Reference: %s" % wcs_reference_file
			if wcs_reference_line > 0:
				help += ":%d" % wcs_reference_line
			help += "\n"
	
	# Version information
	if not added_in_version.is_empty() or not deprecated_in_version.is_empty():
		help += "\nVersion Information:\n"
		if not added_in_version.is_empty():
			help += "  Added in: %s\n" % added_in_version
		if not deprecated_in_version.is_empty():
			help += "  Deprecated in: %s\n" % deprecated_in_version
			if not deprecation_message.is_empty():
				help += "  Deprecation reason: %s\n" % deprecation_message
		if not minimum_wcs_version.is_empty():
			help += "  Minimum WCS version: %s\n" % minimum_wcs_version
		help += "  Support status: %s\n" % support_status
	
	# Related functions
	if not related_functions.is_empty():
		help += "\nRelated Functions:\n"
		for func in related_functions:
			help += "  • %s\n" % func
	
	# See also
	if not see_also.is_empty():
		help += "\nSee Also:\n"
		for ref in see_also:
			help += "  • %s\n" % ref
	
	# Tags and categorization
	if not tags.is_empty() or difficulty_level != "beginner" or use_frequency != "common":
		help += "\nCategorization:\n"
		help += "  Difficulty: %s\n" % difficulty_level
		help += "  Usage frequency: %s\n" % use_frequency
		if not tags.is_empty():
			help += "  Tags: %s\n" % ", ".join(tags)
	
	return help

## Generate markdown format help
func _generate_markdown_help() -> String:
	var help: String = ""
	
	# Header
	help += "# %s\n\n" % function_name
	help += "**Category:** %s  \n" % function_category
	help += "**Description:** %s\n\n" % function_description
	
	if not detailed_description.is_empty():
		help += "%s\n\n" % detailed_description
	
	# Signature
	if not function_signature.is_empty():
		help += "## Signature\n\n"
		help += "```lisp\n%s\n```\n\n" % function_signature
	
	# Arguments
	if not arguments.is_empty():
		help += "## Arguments\n\n"
		for arg in arguments:
			var optional_marker: String = " *(optional)*" if arg["optional"] else ""
			help += "- **%s** (`%s`)%s: %s\n" % [arg["name"], arg["type_name"], optional_marker, arg["description"]]
		help += "\n"
	
	# Return value
	if return_type != SexpResult.ResultType.VOID:
		help += "## Returns\n\n"
		help += "**Type:** `%s`  \n" % SexpResult.get_type_name(return_type)
		if not return_description.is_empty():
			help += "**Description:** %s\n\n" % return_description
	
	# Examples
	if not usage_examples.is_empty():
		help += "## Examples\n\n"
		for example in usage_examples:
			help += "```lisp\n%s\n```\n" % example["expression"]
			help += "%s\n" % example["description"]
			if not example["expected_result"].is_empty():
				help += "**Result:** `%s`\n" % example["expected_result"]
			help += "\n"
	
	return help

## Generate HTML format help
func _generate_html_help() -> String:
	var help: String = ""
	
	help += "<div class=\"sexp-function-help\">\n"
	help += "<h1>%s</h1>\n" % function_name
	help += "<p><strong>Category:</strong> %s</p>\n" % function_category
	help += "<p><strong>Description:</strong> %s</p>\n" % function_description
	
	if not usage_examples.is_empty():
		help += "<h2>Examples</h2>\n"
		help += "<ul>\n"
		for example in usage_examples:
			help += "<li><code>%s</code> - %s</li>\n" % [example["expression"], example["description"]]
		help += "</ul>\n"
	
	help += "</div>\n"
	
	return help

## Generate JSON format help
func _generate_json_help() -> String:
	var metadata_dict: Dictionary = to_dict()
	return JSON.stringify(metadata_dict, "\t")

## Convert metadata to dictionary
func to_dict() -> Dictionary:
	return {
		"function_name": function_name,
		"function_category": function_category,
		"function_description": function_description,
		"detailed_description": detailed_description,
		"function_signature": function_signature,
		"arguments": arguments,
		"return_type": SexpResult.get_type_name(return_type),
		"return_description": return_description,
		"usage_examples": usage_examples,
		"related_functions": related_functions,
		"see_also": see_also,
		"technical_characteristics": {
			"is_pure_function": is_pure_function,
			"is_deterministic": is_deterministic,
			"is_side_effect_free": is_side_effect_free,
			"is_thread_safe": is_thread_safe,
			"complexity_rating": complexity_rating
		},
		"wcs_compatibility": {
			"wcs_equivalent": wcs_equivalent,
			"wcs_differences": wcs_differences,
			"wcs_reference_file": wcs_reference_file,
			"wcs_reference_line": wcs_reference_line
		},
		"version_info": {
			"added_in_version": added_in_version,
			"deprecated_in_version": deprecated_in_version,
			"deprecation_message": deprecation_message,
			"minimum_wcs_version": minimum_wcs_version,
			"support_status": support_status
		},
		"performance": {
			"typical_execution_time": typical_execution_time,
			"memory_usage": memory_usage,
			"cache_behavior": cache_behavior,
			"performance_notes": performance_notes
		},
		"validation_rules": validation_rules,
		"constraint_descriptions": constraint_descriptions,
		"error_conditions": error_conditions,
		"categorization": {
			"tags": tags,
			"difficulty_level": difficulty_level,
			"use_frequency": use_frequency
		}
	}

## Create metadata from dictionary
static func from_dict(data: Dictionary) -> SexpFunctionMetadata:
	var metadata: SexpFunctionMetadata = SexpFunctionMetadata.new()
	
	# Basic information
	metadata.function_name = data.get("function_name", "")
	metadata.function_category = data.get("function_category", "")
	metadata.function_description = data.get("function_description", "")
	metadata.detailed_description = data.get("detailed_description", "")
	metadata.function_signature = data.get("function_signature", "")
	
	# Arguments and return
	metadata.arguments = data.get("arguments", [])
	metadata.return_description = data.get("return_description", "")
	
	# Usage and examples
	metadata.usage_examples = data.get("usage_examples", [])
	metadata.related_functions = data.get("related_functions", [])
	metadata.see_also = data.get("see_also", [])
	
	# Technical characteristics
	var tech: Dictionary = data.get("technical_characteristics", {})
	metadata.is_pure_function = tech.get("is_pure_function", true)
	metadata.is_deterministic = tech.get("is_deterministic", true)
	metadata.is_side_effect_free = tech.get("is_side_effect_free", true)
	metadata.is_thread_safe = tech.get("is_thread_safe", true)
	metadata.complexity_rating = tech.get("complexity_rating", "O(1)")
	
	# WCS compatibility
	var wcs: Dictionary = data.get("wcs_compatibility", {})
	metadata.wcs_equivalent = wcs.get("wcs_equivalent", "")
	metadata.wcs_differences = wcs.get("wcs_differences", "")
	metadata.wcs_reference_file = wcs.get("wcs_reference_file", "")
	metadata.wcs_reference_line = wcs.get("wcs_reference_line", -1)
	
	# Version information
	var version: Dictionary = data.get("version_info", {})
	metadata.added_in_version = version.get("added_in_version", "")
	metadata.deprecated_in_version = version.get("deprecated_in_version", "")
	metadata.deprecation_message = version.get("deprecation_message", "")
	metadata.minimum_wcs_version = version.get("minimum_wcs_version", "")
	metadata.support_status = version.get("support_status", "stable")
	
	# Performance
	var perf: Dictionary = data.get("performance", {})
	metadata.typical_execution_time = perf.get("typical_execution_time", "< 1ms")
	metadata.memory_usage = perf.get("memory_usage", "minimal")
	metadata.cache_behavior = perf.get("cache_behavior", "cacheable")
	metadata.performance_notes = perf.get("performance_notes", "")
	
	# Validation and constraints
	metadata.validation_rules = data.get("validation_rules", [])
	metadata.constraint_descriptions = data.get("constraint_descriptions", [])
	metadata.error_conditions = data.get("error_conditions", [])
	
	# Categorization
	var cat: Dictionary = data.get("categorization", {})
	metadata.tags = cat.get("tags", [])
	metadata.difficulty_level = cat.get("difficulty_level", "beginner")
	metadata.use_frequency = cat.get("use_frequency", "common")
	
	return metadata

## String representation for debugging
func _to_string() -> String:
	return "SexpFunctionMetadata(name='%s', category='%s', args=%d, examples=%d)" % [
		function_name,
		function_category,
		arguments.size(),
		usage_examples.size()
	]