# migration_tools/gdscript_converters/fs2_parsers/persona_parser.gd
extends BaseParser
class_name PersonaParser

const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

# Mapping from FS2 persona type strings to our flag constants
const PERSONA_TYPE_MAP = {
	"wingman": GlobalConstants.PersonaFlags.PERSONA_FLAG_WINGMAN,
	"support": GlobalConstants.PersonaFlags.PERSONA_FLAG_SUPPORT,
	"large": GlobalConstants.PersonaFlags.PERSONA_FLAG_LARGE,
	"command": GlobalConstants.PersonaFlags.PERSONA_FLAG_COMMAND,
	# Add other potential types if they exist in FS2 source
}

func parse(lines: PackedStringArray, start_index: int) -> Dictionary:
	var current_line_num = start_index
	var personas_data: Array[Dictionary] = []

	while current_line_num < lines.size():
		var line = lines[current_line_num].strip_edges()

		# Stop condition: Reached next section or end of file
		if line.begins_with("#") or line.is_empty() and _is_eof_or_next_section(lines, current_line_num + 1):
			break

		# Skip comments and empty lines
		if line.is_empty() or line.begins_with(";"):
			current_line_num += 1
			continue

		# Check for $Persona: tag
		if line.begins_with("$Persona:"):
			var persona_dict = {
				"name": "",
				"type_flags": 0,
				"species_name": "", # Store name for now, resolve index later if needed
				"auto_assign": false
			}
			persona_dict["name"] = _stuff_string_after_tag(line, "$Persona:")
			current_line_num += 1

			# Parse attributes within the current persona block
			while current_line_num < lines.size():
				line = lines[current_line_num].strip_edges()

				# Stop if we hit the next persona or section
				if line.begins_with("$Persona:") or line.begins_with("#"):
					break

				if line.begins_with("$Type:"):
					var type_str = _stuff_string_after_tag(line, "$Type:").to_lower()
					if PERSONA_TYPE_MAP.has(type_str):
						persona_dict["type_flags"] = PERSONA_TYPE_MAP[type_str]
					else:
						printerr(f"Warning: Unknown persona type '{type_str}' for persona '{persona_dict['name']}' at line {current_line_num + 1}")
					current_line_num += 1
				elif line.begins_with("+autoassign"):
					persona_dict["auto_assign"] = true
					current_line_num += 1
				elif line.begins_with("+") and line.ends_with(":"): # Check for species tag like "+Terran:"
					# Extract species name (remove '+' and ':')
					var species_name = line.trim_prefix("+").trim_suffix(":")
					persona_dict["species_name"] = species_name
					# TODO: Optionally validate against a known species list here
					# We store the name; runtime or a later step can resolve to index
					current_line_num += 1
				else:
					# Unknown or irrelevant line within persona block, skip
					# Check if it's empty or a comment before potentially warning
					if not line.is_empty() and not line.begins_with(";"):
						# Optionally print a warning for unexpected lines within a persona block
						# print(f"Debug: Skipping line in persona block: '{line}' at {current_line_num + 1}")
						pass
					current_line_num += 1
					continue # Continue inner loop

			# Add the parsed persona to our list
			personas_data.append(persona_dict)
			# The outer loop will handle advancing past the next $Persona or #

		else:
			# Unexpected line, might indicate end of section or error
			# Let the outer loop handle section breaks
			# print(f"Debug: Unexpected line, breaking persona parse: '{line}' at {current_line_num + 1}")
			break

	return {"data": personas_data, "next_line": current_line_num}

func _is_eof_or_next_section(lines: PackedStringArray, index: int) -> bool:
	"""Checks if the next non-empty/comment line is EOF or a new section."""
	while index < lines.size():
		var line = lines[index].strip_edges()
		if not line.is_empty() and not line.begins_with(";"):
			return line.begins_with("#")
		index += 1
	return true # Reached end of file
