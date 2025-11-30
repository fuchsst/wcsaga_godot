class_name WCSShipParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const ShipStats = preload("res://scripts/resources/ships/ship_stats.gd")

## Parser for ships.tbl files.
## Converts ship data into ShipStats resources.


func _parse_content() -> Variant:
	var ships: Array[ShipStats] = []

	_current_line_index = 0

	while _has_more_lines():
		var line = _get_next_line()

		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue

		if line.begins_with("$Name:"):
			var ship = _parse_ship(line)
			ships.append(ship)

	return ships


func _parse_ship(first_line: String) -> ShipStats:
	var ship = ShipStats.new()
	ship.ship_class = _extract_string_value(first_line, "$Name:")
	ship.display_name = ship.ship_class  # Default

	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("#"):
			break

		_get_next_line()  # Consume

		if line.begins_with("$Short name:"):
			ship.ship_short_name = _extract_string_value(line, "$Short name:")
		elif line.begins_with("$Species:"):
			ship.species_mnemonic = _extract_string_value(line, "$Species:")
		elif line.begins_with("+Type:"):
			var type_str = _extract_string_value(line, "+Type:").to_lower()
			if "fighter" in type_str:
				ship.ship_role = 0
			elif "bomber" in type_str:
				ship.ship_role = 1
			elif (
				"cruiser" in type_str
				or "corvette" in type_str
				or "destroyer" in type_str
				or "capital" in type_str
			):
				ship.ship_role = 2
			elif "transport" in type_str or "freighter" in type_str:
				ship.ship_role = 3
		elif line.begins_with("+Maneuverability:"):
			# Parse maneuverability
			pass
		elif line.begins_with("+Armor:"):
			# Parse armor
			pass
		elif line.begins_with("+Tech Description:"):
			ship.tech_description = _parse_multiline_text()
		elif line.begins_with("+Description:"):
			ship.description = _parse_multiline_text()
		elif line.begins_with("$POF file:"):
			ship.model_file = _extract_string_value(line, "$POF file:")
		elif line.begins_with("$Detail distance:"):
			# Parse detail distances
			pass
		elif line.begins_with("$Density:"):
			ship.density = _extract_float_value(line, "$Density:")
		elif line.begins_with("$Score:"):
			ship.score_value = _extract_int_value(line, "$Score:")
		elif line.begins_with("$Max Velocity:"):
			ship.max_velocity = _parse_vector3(line.substr(14))
		elif line.begins_with("$Rotation time:"):
			ship.rotation_time = _parse_vector3(line.substr(15))

	return ship


func _parse_multiline_text() -> String:
	var text = ""
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$end_multi_text"):
			_get_next_line()  # Consume end marker
			break
		text += _get_next_line() + "\n"
	return text.strip_edges()
