# migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd
# Utility functions for parsing common data types found in FreeSpace TBL files.
class_name TblParserUtils

# --- Basic Type Parsers ---

static func parse_int(value_str: String, default_val: int = 0) -> int:
	var clean_str = value_str.strip_edges()
	if clean_str.is_valid_int():
		return clean_str.to_int()
	else:
		printerr(f"Warning: Could not parse int from '{value_str}'. Using default {default_val}.")
		return default_val

static func parse_float(value_str: String, default_val: float = 0.0) -> float:
	var clean_str = value_str.strip_edges()
	if clean_str.is_valid_float():
		return clean_str.to_float()
	else:
		printerr(f"Warning: Could not parse float from '{value_str}'. Using default {default_val}.")
		return default_val

static func parse_bool(value_str: String, default_val: bool = false) -> bool:
	var lower_val = value_str.strip_edges().to_lower()
	if lower_val == "yes" or lower_val == "true" or lower_val == "1":
		return true
	elif lower_val == "no" or lower_val == "false" or lower_val == "0":
		return false
	else:
		printerr(f"Warning: Invalid boolean value '{value_str}'. Using default {default_val}.")
		return default_val

# --- Vector/Color Parsers ---

static func parse_vector(value_str: String, default_val: Vector3 = Vector3.ZERO) -> Vector3:
	var content = value_str.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false)
	if parts.size() == 3:
		var x = parse_float(parts[0], default_val.x)
		var y = parse_float(parts[1], default_val.y)
		var z = parse_float(parts[2], default_val.z)
		return Vector3(x, y, z)
	else:
		printerr(f"Error parsing Vector3: '{value_str}'. Using default {default_val}.")
		return default_val

static func parse_color(value_str: String, default_val: Color = Color.WHITE) -> Color:
	var parts = value_str.split() # Usually space-separated R G B
	if parts.size() == 3:
		var r = parse_int(parts[0], 255)
		var g = parse_int(parts[1], 255)
		var b = parse_int(parts[2], 255)
		if r < 0 or r > 255 or g < 0 or g > 255 or b < 0 or b > 255:
			printerr(f"Warning: Invalid color component in '{value_str}'. Clamping to 0-255.")
			r = clamp(r, 0, 255)
			g = clamp(g, 0, 255)
			b = clamp(b, 0, 255)
		return Color(r / 255.0, g / 255.0, b / 255.0)
	else:
		printerr(f"Error parsing Color (expected 3 components): '{value_str}'. Using default {default_val}.")
		return default_val

# --- List Parsers ---

static func parse_string_list(value_str: String) -> PackedStringArray:
	var result: PackedStringArray = []
	# Handle potential parentheses, split by space or comma, trim quotes
	var content = value_str.trim_prefix("(").trim_suffix(")").strip_edges()
	# Split by space first, then check for comma within parts if needed
	var parts = content.split(" ", false) # Don't allow empty parts from multiple spaces
	for part in parts:
		var clean_part = part.strip_edges().trim_prefix('"').trim_suffix('"')
		if not clean_part.is_empty():
			# Handle potential comma separation within parts if spaces aren't reliable
			if "," in clean_part:
				var comma_parts = clean_part.split(",", false)
				for cp in comma_parts:
					var final_part = cp.strip_edges().trim_prefix('"').trim_suffix('"')
					if not final_part.is_empty():
						result.append(final_part)
			else:
				result.append(clean_part)
	return result

static func parse_int_list(value_str: String) -> PackedInt32Array:
	var result: PackedInt32Array = []
	var content = value_str.trim_prefix("(").trim_suffix(")").strip_edges()
	if content.is_empty(): return result
	# Try splitting by comma first, then space as fallback
	var parts = content.split(",", false) if "," in content else content.split(" ", false)
	for part in parts:
		var clean_part = part.strip_edges()
		if clean_part.is_valid_int():
			result.append(clean_part.to_int())
		elif not clean_part.is_empty(): # Avoid error on empty strings from split
			printerr(f"Error parsing int list item: '{clean_part}' in '{value_str}'. Skipping.")
	return result

static func parse_float_list(value_str: String) -> PackedFloat32Array:
	var result: PackedFloat32Array = []
	var content = value_str.trim_prefix("(").trim_suffix(")").strip_edges()
	if content.is_empty(): return result
	# Try splitting by comma first, then space as fallback
	var parts = content.split(",", false) if "," in content else content.split(" ", false)
	for part in parts:
		var clean_part = part.strip_edges()
		if clean_part.is_valid_float():
			result.append(clean_part.to_float())
		elif not clean_part.is_empty():
			printerr(f"Error parsing float list item: '{clean_part}' in '{value_str}'. Skipping.")
	return result

# --- Flag Parser ---

static func parse_flags(value_str: String, flag_map: Dictionary) -> int:
	"""Parses a list of flag names (space or | separated) into a bitmask."""
	var bitmask = 0
	# Handle both space and pipe separators
	var flags_list = value_str.replace("|", " ").split(" ", false)
	for flag_str in flags_list:
		var clean_flag = flag_str.strip_edges().to_lower()
		if flag_map.has(clean_flag):
			bitmask |= flag_map[clean_flag]
		elif not clean_flag.is_empty():
			printerr(f"Warning: Unknown flag '{clean_flag}' found in value '{value_str}'.")
	return bitmask

# --- Name Lookup Helpers (Placeholders - Rely on GlobalConstants) ---
# These are better placed in GlobalConstants or specific managers after loading.

# static func lookup_weapon_index(weapon_name: String) -> int:
# 	# Placeholder - Call GlobalConstants.lookup_weapon_index(weapon_name)
# 	printerr("Warning: TblParserUtils.lookup_weapon_index is a placeholder.")
# 	return -1

# static func lookup_ship_index(ship_name: String) -> int:
# 	# Placeholder - Call GlobalConstants.lookup_ship_index(ship_name)
# 	printerr("Warning: TblParserUtils.lookup_ship_index is a placeholder.")
# 	return -1

# static func lookup_sound_index(sound_name: String) -> int:
# 	# Placeholder - Call GlobalConstants.lookup_sound_index(sound_name)
# 	printerr("Warning: TblParserUtils.lookup_sound_index is a placeholder.")
# 	return -1

# static func lookup_armor_index(armor_name: String) -> int:
# 	# Placeholder - Call GlobalConstants.lookup_armor_index(armor_name)
# 	printerr("Warning: TblParserUtils.lookup_armor_index is a placeholder.")
# 	return -1

# static func lookup_ai_class_index(class_name: String) -> int:
# 	# Placeholder - Call GlobalConstants.lookup_ai_class_index(class_name)
# 	printerr("Warning: TblParserUtils.lookup_ai_class_index is a placeholder.")
# 	return -1

# static func lookup_species_index(species_name: String) -> int:
# 	# Placeholder - Call GlobalConstants.lookup_species_index(species_name)
# 	printerr("Warning: TblParserUtils.lookup_species_index is a placeholder.")
# 	return -1
