class_name PlayerParser
extends BaseSectionParser

## Parses the Players section (#Players)
## Handles starting ship, ship choices, and weaponry pool

const PlayerData = preload("res://scripts/resources/missions/player_data.gd")
const ShipChoice = preload("res://scripts/resources/missions/ship_choice.gd")
const WeaponryPoolItem = preload("res://scripts/resources/missions/weaponry_pool_item.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Continue until we hit the next section
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		_get_next_line() # Consume line
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		# Parse fields
		_parse_player_field(line, manifest)
	
	return _base_parser._current_line_index


func _parse_player_field(line: String, manifest: Resource):
	if line.begins_with("$Starting Shipname:"):
		manifest.players.starting_ship = _extract_string_value(line, "$Starting Shipname:")
	
	elif line.begins_with("$Ship Choices:"):
		# Ship choices are in a parenthesized list (possibly multi-line)
		manifest.players.ship_choices = _parse_ship_choices()
	
	elif line.begins_with("+Weaponry Pool:"):
		# Weaponry pool is in a parenthesized list with "name count" pairs
		manifest.players.weaponry_pool = _parse_weaponry_pool()


## Parse ship choices list
func _parse_ship_choices() -> Array[ShipChoice]:
	var result: Array[ShipChoice] = []
	
	# Read until we find the closing parenthesis
	var in_list = false
	while _has_more_lines():
		var line = _peek_next_line()
		
		if "(" in line:
			in_list = true
			_get_next_line()
			continue
		
		if ")" in line:
			_get_next_line()
			break
		
		if not in_list:
			_get_next_line()
			continue
		
		_get_next_line()
		var ship_name = line.strip_edges()
		
		# Remove quotes if present
		if ship_name.begins_with("\"") and ship_name.ends_with("\""):
			ship_name = ship_name.substr(1, ship_name.length() - 2)
		
		if not ship_name.is_empty():
			var choice = ShipChoice.new()
			choice.ship_class = ship_name
			result.append(choice)
	
	return result


## Parse weaponry pool: ( "weapon name" count ... )
func _parse_weaponry_pool() -> Array[WeaponryPoolItem]:
	var result: Array[WeaponryPoolItem] = []
	
	# Read until we find the closing parenthesis
	var in_list = false
	var current_weapon = ""
	
	while _has_more_lines():
		var line = _peek_next_line()
		
		if "(" in line:
			in_list = true
			_get_next_line()
			continue
		
		if ")" in line:
			_get_next_line()
			break
		
		if not in_list:
			_get_next_line()
			continue
		
		_get_next_line()
		var parts = line.strip_edges().split("\t", false) # Split by tab
		if parts.size() < 2:
			parts = line.strip_edges().split(" ", false) # Fallback to space
		
		if parts.size() >= 2:
			var weapon_name = parts[0].strip_edges()
			# Remove quotes
			if weapon_name.begins_with("\""):
				weapon_name = weapon_name.trim_prefix("\"").trim_suffix("\"")
			
			var count_str = parts[parts.size() - 1].strip_edges()
			var count = count_str.to_int()
			
			if not weapon_name.is_empty() and count > 0:
				var item = WeaponryPoolItem.new()
				item.weapon_class = weapon_name
				item.count = count
				result.append(item)
	
	return result
