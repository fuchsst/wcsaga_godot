class_name WCSAsteroidParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

## Parser for asteroid.tbl files.
## Returns an Array of Dictionaries containing asteroid definition data.

# Global impact explosion settings
var _global_impact_explosion_name: String = ""
var _global_impact_explosion_radius: float = 20.0


func _parse_content() -> Variant:
	var asteroids: Array[Dictionary] = []

	_current_line_index = 0
	var current_asteroid: Dictionary = {}

	while _has_more_lines():
		var line = _get_next_line()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue

		# Skip section headers
		if line.begins_with("#Asteroid Types") or line.begins_with("#End"):
			continue

		# Check for global settings (appear after #End)
		if line.begins_with("$Impact Explosion:"):
			_global_impact_explosion_name = _extract_string_value(line, "$Impact Explosion:")
			continue

		if line.begins_with("$Impact Explosion Radius:"):
			_global_impact_explosion_radius = _extract_float_value(
				line, "$Impact Explosion Radius:"
			)
			continue

		# Start of new asteroid definition
		if line.begins_with("$Name:"):
			# Save previous asteroid if exists
			if not current_asteroid.is_empty():
				_apply_global_settings(current_asteroid)
				asteroids.append(current_asteroid)

			# Create new asteroid data structure
			current_asteroid = {
				"asteroid_name": "",
				"resource_identifier": "",
				"pof_file_lod0": "",
				"pof_file_lod1": "",
				"pof_file_lod2": "",
				"lod_distances": [],
				"max_speed": 60.0,
				"hitpoints": 100.0,
				"explosion_inner_radius": 0.0,
				"explosion_outer_radius": 0.0,
				"explosion_damage": 0.0,
				"explosion_blast": 0.0,
				"impact_explosion_effect": "",
				"impact_explosion_radius": 20.0
			}

			var name = _extract_string_value(line, "$Name:")
			current_asteroid["asteroid_name"] = name
			current_asteroid["resource_identifier"] = _sanitize_name(name)
			continue

		# Parse asteroid properties
		if not current_asteroid.is_empty():
			_parse_asteroid_property(current_asteroid, line)

	# Don't forget the last asteroid
	if not current_asteroid.is_empty():
		_apply_global_settings(current_asteroid)
		asteroids.append(current_asteroid)

	return asteroids


func _parse_asteroid_property(asteroid: Dictionary, line: String) -> void:
	"""Parse a property line for an asteroid"""

	if line.begins_with("$POF file1:"):
		asteroid["pof_file_lod0"] = _extract_string_value(line, "$POF file1:")

	elif line.begins_with("$POF file2:"):
		asteroid["pof_file_lod1"] = _extract_string_value(line, "$POF file2:")

	elif line.begins_with("$POF file3:"):
		asteroid["pof_file_lod2"] = _extract_string_value(line, "$POF file3:")

	elif line.begins_with("$Detail distance:"):
		asteroid["lod_distances"] = _extract_tuple_values(line, "$Detail distance:")

	elif line.begins_with("$Max Speed:"):
		asteroid["max_speed"] = _extract_float_value(line, "$Max Speed:")

	elif line.begins_with("$Expl inner rad:"):
		asteroid["explosion_inner_radius"] = _extract_float_value(line, "$Expl inner rad:")

	elif line.begins_with("$Expl outer rad:"):
		asteroid["explosion_outer_radius"] = _extract_float_value(line, "$Expl outer rad:")

	elif line.begins_with("$Expl damage:"):
		asteroid["explosion_damage"] = _extract_float_value(line, "$Expl damage:")

	elif line.begins_with("$Expl blast:"):
		asteroid["explosion_blast"] = _extract_float_value(line, "$Expl blast:")

	elif line.begins_with("$Hitpoints:"):
		asteroid["hitpoints"] = _extract_float_value(line, "$Hitpoints:")


func _apply_global_settings(asteroid: Dictionary) -> void:
	"""Apply global impact explosion settings to asteroid"""
	if not _global_impact_explosion_name.is_empty():
		asteroid["impact_explosion_effect"] = _global_impact_explosion_name
	asteroid["impact_explosion_radius"] = _global_impact_explosion_radius


func _extract_string_value(line: String, prefix: String) -> String:
	"""Extract string value after prefix, removing comments"""
	var value = super._extract_string_value(line, prefix)

	# Remove inline comments
	var comment_idx = value.find(";")
	if comment_idx != -1:
		value = value.substr(0, comment_idx).strip_edges()

	return value


func _extract_float_value(line: String, prefix: String, alt_prefix: String = "") -> float:
	"""Extract float value after prefix"""
	return super._extract_float_value(line, prefix, alt_prefix)


func _extract_tuple_values(line: String, prefix: String) -> Array[float]:
	"""Extract tuple values like (0, 12000, 24000)"""
	var values: Array[float] = []
	var value_str = _extract_string_value(line, prefix)

	# Remove parentheses
	value_str = value_str.replace("(", "").replace(")", "")

	# Split by comma
	var parts = value_str.split(",")
	for part in parts:
		var cleaned = part.strip_edges()
		if cleaned.is_valid_float():
			values.append(cleaned.to_float())

	return values


func _sanitize_name(name: String) -> String:
	"""Convert asteroid name to valid resource identifier"""
	var result = name.to_lower()
	result = result.replace(" ", "_")
	result = result.replace("-", "_")
	result = result.replace("(", "")
	result = result.replace(")", "")

	# Handle multiple underscores
	while result.contains("__"):
		result = result.replace("__", "_")

	return result
