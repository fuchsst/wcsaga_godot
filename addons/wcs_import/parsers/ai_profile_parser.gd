class_name WCSAIProfileParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

## Parser for ai_profiles.tbl files.
## Converts AI profile data into AIProfileResource resources.
## The TBL format has multi-value fields where each flag has 5 values
## (one for each difficulty: Very Easy, Easy, Medium, Hard, Insane).

const AIProfileResource = preload("res://scripts/resources/gameplay/ai_profile_resource.gd")

const DIFFICULTY_LEVELS = ["1_very_easy", "2_easy", "3_medium", "4_hard", "5_insane"]

func _parse_content() -> Variant:
	# Create 5 profile resources, one for each difficulty level
	var profiles: Array[AIProfileResource] = []
	for level in DIFFICULTY_LEVELS:
		var profile = AIProfileResource.new()
		profile.difficulty_level = level
		profile.profile_name = level
		profiles.append(profile)
	
	_current_line_index = 0
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		# Skip header and profile name info
		if line.begins_with("#AI Profiles") or line.begins_with("$Default Profile:") or line.begins_with("$Profile Name:"):
			continue
			
		# Parse flag lines
		if line.begins_with("$"):
			_parse_multi_value_flag(profiles, line)
	
	# Return only if we successfully parsed something
	if profiles.size() > 0:
		return profiles
	return []

func _parse_multi_value_flag(profiles: Array[AIProfileResource], line: String) -> void:
	# Format can be either:
	# 1. Multi-value: $Flag Name: value1, value2, value3, value4, value5
	# 2. Single-value: $Flag Name: YES or NO
	# Split on first colon
	var colon_idx = line.find(":")
	if colon_idx == -1:
		return
	
	var flag_name = line.substr(1, colon_idx - 1).strip_edges() # Remove leading $
	var values_str = line.substr(colon_idx + 1).strip_edges()
	
	# Check if this is a multi-value line (contains commas)
	if values_str.contains(","):
		# Multi-value format (one value per difficulty level)
		var value_parts = values_str.split(",")
		if value_parts.size() != 5:
			push_warning("Expected 5 values for flag '" + flag_name + "', got " + str(value_parts.size()))
			return
		
		# Convert flag name to property name
		var property_name = _flag_name_to_property(flag_name)
		
		# Assign each value to its corresponding difficulty profile
		for i in range(min(5, value_parts.size())):
			var value_str = value_parts[i].strip_edges()
			_set_property_value(profiles[i], property_name, value_str, flag_name, i == 0)
	else:
		# Single-value format (applies to ALL difficulty levels)
		var property_name = _flag_name_to_property(flag_name)
		
		# Apply the same value to all 5 profiles
		for i in range(5):
			_set_property_value(profiles[i], property_name, values_str, flag_name, i == 0)

func _set_property_value(profile: AIProfileResource, property_name: String, value_str: String, flag_name: String, log_warning: bool) -> void:
	# Determine value type and set property
	if value_str.to_upper() == "YES" or value_str.to_upper() == "NO":
		# Boolean flag
		var bool_val = (value_str.to_upper() == "YES")
		if property_name in profile:
			profile.set(property_name, bool_val)
		elif log_warning:
			push_warning("Unknown boolean flag: " + flag_name + " (property: " + property_name + ")")
	elif value_str.is_valid_float():
		# Numeric value - try to set if property exists
		var float_val = value_str.to_float()
		if property_name in profile:
			# Check if the property is a bool or float
			var current_val = profile.get(property_name)
			if typeof(current_val) == TYPE_BOOL:
				# Convert number to bool (0 = false, non-zero = true)
				profile.set(property_name, float_val != 0.0)
			else:
				profile.set(property_name, float_val)
		elif log_warning:
			# This might be a numeric setting we haven't added to the resource
			push_warning("Unknown numeric flag: " + flag_name + " (property: " + property_name + ")")

func _flag_name_to_property(flag_name: String) -> String:
	# Convert flag names like "Player Use AI" to "player_use_ai"
	var result = flag_name.to_lower()
	result = result.replace(" ", "_")
	result = result.replace("-", "_")
	result = result.replace("(", "")
	result = result.replace(")", "")
	result = result.replace(".", "")
	result = result.replace("'", "")
	
	# Handle multiple underscores
	while result.contains("__"):
		result = result.replace("__", "_")
	
	return result
