class_name WCSMessageParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const PersonaResource = preload("res://scripts/resources/persona/persona_resource.gd")


func _parse_content() -> Variant:
	var personas: Dictionary = {}  # Key: Persona Name, Value: PersonaResource
	var current_section = ""
	var current_persona: PersonaResource = null

	# Temporary variables for message parsing
	var current_msg_name = ""
	var current_msg_text = ""
	var current_msg_avi = ""
	var current_msg_wave = ""
	var current_msg_persona = ""

	_current_line_index = 0

	while _has_more_lines():
		var line = _get_next_line()

		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue

		if line.begins_with("#"):
			current_section = line
			continue

		if current_section == "#Personas":
			if line.begins_with("$Persona:"):
				var p_name = _extract_string_value(line, "$Persona:")
				current_persona = PersonaResource.new()
				current_persona.persona_name = p_name
				personas[p_name] = current_persona
			elif line.begins_with("$Type:"):
				if current_persona:
					current_persona.type = _extract_string_value(line, "$Type:")
			elif line.begins_with("+"):
				if current_persona:
					if line.strip_edges() == "+autoassign":
						current_persona.auto_assign = true
					else:
						# Assuming +Species format like +Kilrathi
						var species = line.trim_prefix("+").strip_edges()
						current_persona.species = species

		elif current_section == "#Messages":
			if line.begins_with("$Name:"):
				# Commit previous message if exists
				if not current_msg_name.is_empty():
					_commit_message(
						personas,
						current_msg_name,
						current_msg_text,
						current_msg_avi,
						current_msg_wave,
						current_msg_persona
					)

				# Reset for new message
				current_msg_name = _extract_string_value(line, "$Name:")
				current_msg_text = ""
				current_msg_avi = ""
				current_msg_wave = ""
				current_msg_persona = ""

			elif line.begins_with("$Message:") or line.begins_with("$MessageNew:"):
				var prefix = "$Message:"
				if line.begins_with("$MessageNew:"):
					prefix = "$MessageNew:"
				var raw_msg = _extract_string_value(line, prefix)
				current_msg_text = _clean_xstr(raw_msg)

			elif line.begins_with("$Team:"):
				# Ignore team for now, but consume it
				pass

			elif line.begins_with("+Avi Name:"):
				current_msg_avi = _extract_string_value(line, "+Avi Name:")

			elif line.begins_with("+Wave Name:"):
				current_msg_wave = _extract_string_value(line, "+Wave Name:")

			elif line.begins_with("+Persona:"):
				current_msg_persona = _extract_string_value(line, "+Persona:")

	# Commit final message
	if not current_msg_name.is_empty():
		_commit_message(
			personas,
			current_msg_name,
			current_msg_text,
			current_msg_avi,
			current_msg_wave,
			current_msg_persona
		)

	return personas.values()


func _commit_message(
	personas: Dictionary,
	msg_name: String,
	text: String,
	avi: String,
	wave: String,
	persona_name: String
) -> void:
	if persona_name.is_empty():
		return  # Orphaned message?

	if personas.has(persona_name):
		var p = personas[persona_name]
		p.add_message(msg_name, text, avi, wave)
	else:
		# Persona not found? Maybe create it or warn?
		# TBL might define personas implicitly? Usually not.
		pass


func _clean_xstr(raw: String) -> String:
	# Format: XSTR("text", -1)
	if raw.begins_with("XSTR("):
		var comma_pos = raw.rfind(",")
		if comma_pos != -1:
			var text = raw.substr(5, comma_pos - 5)
			# Remove quotes
			if text.begins_with('"') and text.ends_with('"'):
				text = text.substr(1, text.length() - 2)
			return text
	return raw.replace('"', "")  # Fallback
