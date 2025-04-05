# migration_tools/gdscript_converters/fs2_parsers/fiction_parser.gd
extends BaseFS2Parser # Changed from RefCounted
class_name FictionParser

# --- Dependencies ---
# None specific needed for basic parsing

# --- Parser State ---
# Inherited: _lines, _current_line_num

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the parsed fiction data ('file', 'font')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var fiction_data: Dictionary = {
		"file": "",
		"font": ""
	}

	print("Parsing #Fiction Viewer section...")

	# Required $File:
	var file_str = _parse_required_token("$File:")
	if file_str == null: return { "data": null, "next_line": _current_line_num } # Error handled in helper
	if file_str and file_str.to_lower() != "none":
		# Assuming fiction files remain .txt but are moved
		fiction_data["file"] = "res://assets/fiction/" + file_str.get_file() # Keep extension
	else:
		fiction_data["file"] = ""

	# Optional $Font:
	var font_str = _parse_optional_token("$Font:")
	if font_str != null and font_str.to_lower() != "none":
		# Assuming fonts are converted to .ttf or .otf
		# We need to determine the final extension. Let's assume .ttf for now.
		fiction_data["font"] = "res://assets/fonts/" + font_str.get_basename() + ".ttf"
	else:
		fiction_data["font"] = ""

	# Skip any remaining lines until the next section
	_skip_to_next_section_or_token("#") # Skip until next section marker

	print("Finished parsing #Fiction Viewer section.")
	return { "data": fiction_data, "next_line": _current_line_num }
