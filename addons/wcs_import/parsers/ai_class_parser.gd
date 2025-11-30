class_name WCSAIClassParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

## Parser for ai.tbl files.
## Converts AI class data into AIClassResource resources.
## The TBL format has multi-value parameters where each line has 5 values
## (one for each difficulty: Trainee, Rookie, Hotshot, Ace, Insane).
## Each AI class (e.g., "Coward", "Ace") becomes 5 separate resources.

const AIClassResource = preload("res://scripts/resources/ai_classes/ai_class_resource.gd")

const DIFFICULTY_LEVELS = ["1_very_easy", "2_easy", "3_medium", "4_hard", "5_insane"]


func _parse_content() -> Variant:
	var all_classes: Array[AIClassResource] = []

	_current_line_index = 0

	while _has_more_lines():
		var line = _get_next_line()

		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue

		# Skip header
		if line.begins_with("#AI Classes"):
			continue

		# Start of a new AI class
		if line.begins_with("$Name:"):
			var class_resources = _parse_ai_class(line)
			all_classes.append_array(class_resources)

	return all_classes


func _parse_ai_class(first_line: String) -> Array[AIClassResource]:
	# Create 5 resources for this AI class (one per difficulty level)
	var class_resources: Array[AIClassResource] = []

	# Extract class name
	var ai_class_name = _extract_string_value(first_line, "$Name:").strip_edges()

	# Create 5 difficulty instances
	for difficulty in DIFFICULTY_LEVELS:
		var ai_class = AIClassResource.new()
		ai_class.ai_class_name = ai_class_name
		ai_class.difficulty_level = difficulty
		class_resources.append(ai_class)

	# Parse all parameters for this class
	while _has_more_lines():
		var line = _peek_next_line()

		# Stop at next class or end
		if line.begins_with("$Name:") or line.begins_with("#End"):
			break

		_get_next_line()  # Consume

		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue

		# Parse parameter line
		if line.begins_with("$"):
			_parse_multi_value_parameter(class_resources, line)

	return class_resources


func _parse_multi_value_parameter(class_resources: Array[AIClassResource], line: String) -> void:
	# Format can be either:
	# 1. Multi-value: $Parameter: value1, value2, value3, value4, value5
	# 2. Single-value: $Parameter: YES or NO
	var colon_idx = line.find(":")
	if colon_idx == -1:
		return

	var param_name = line.substr(1, colon_idx - 1).strip_edges()  # Remove leading $
	var values_str = line.substr(colon_idx + 1).strip_edges()

	# Check if this is a multi-value line (contains commas)
	if values_str.contains(","):
		# Multi-value format (one value per difficulty level)
		var value_parts = values_str.split(",")
		if value_parts.size() != 5:
			push_warning(
				(
					"Expected 5 values for parameter '"
					+ param_name
					+ "', got "
					+ str(value_parts.size())
				)
			)
			return

		# Convert parameter name to property name
		var property_name = _param_name_to_property(param_name)

		# Assign each value to its corresponding difficulty instance
		for i in range(min(5, value_parts.size())):
			var value_str = value_parts[i].strip_edges()
			_set_property_value(class_resources[i], property_name, value_str, param_name, i == 0)
	else:
		# Single-value format (applies to ALL difficulty levels)
		var property_name = _param_name_to_property(param_name)

		# Apply the same value to all 5 instances
		for i in range(5):
			_set_property_value(class_resources[i], property_name, values_str, param_name, i == 0)


func _set_property_value(
	ai_class: AIClassResource,
	property_name: String,
	value_str: String,
	param_name: String,
	log_warning: bool
) -> void:
	# Determine value type and set property
	if value_str.to_upper() == "YES" or value_str.to_upper() == "NO":
		# Boolean parameter
		var bool_val = value_str.to_upper() == "YES"
		if property_name in ai_class:
			ai_class.set(property_name, bool_val)
		elif log_warning:
			push_warning(
				"Unknown boolean parameter: " + param_name + " (property: " + property_name + ")"
			)
	elif value_str.is_valid_float():
		# Numeric value
		var float_val = value_str.to_float()
		if property_name in ai_class:
			# Check if the property is a bool or float
			var current_val = ai_class.get(property_name)
			if typeof(current_val) == TYPE_BOOL:
				# Convert number to bool (0 = false, non-zero = true)
				ai_class.set(property_name, float_val != 0.0)
			else:
				ai_class.set(property_name, float_val)
		elif log_warning:
			# This might be a parameter we haven't added to the resource
			push_warning(
				"Unknown numeric parameter: " + param_name + " (property: " + property_name + ")"
			)


func _param_name_to_property(param_name: String) -> String:
	# Convert parameter names like "AI Shield Manage Delay" to "ai_shield_manage_delay"
	var result = param_name.to_lower()
	result = result.replace(" ", "_")
	result = result.replace("-", "_")
	result = result.replace("(", "")
	result = result.replace(")", "")
	result = result.replace(".", "")
	result = result.replace("'", "")
	result = result.replace("#", "")

	# Handle multiple underscores
	while result.contains("__"):
		result = result.replace("__", "_")

	return result
