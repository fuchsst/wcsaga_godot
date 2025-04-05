# migration_tools/gdscript_converters/fs2_parsers/briefing_parser.gd
extends BaseFS2Parser
class_name BriefingParser

# --- Dependencies ---
const BriefingData = preload("res://scripts/resources/mission/briefing_data.gd")
const BriefingStageData = preload("res://scripts/resources/mission/briefing_stage_data.gd")
const BriefingIconData = preload("res://scripts/resources/mission/briefing_icon_data.gd")
const BriefingLineData = preload("res://scripts/resources/mission/briefing_line_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const SexpParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/sexp_parser.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num
var _sexp_parser = SexpParserFS2.new()

# --- Main Parse Function ---
# Parses a single #Briefing section from the lines array starting at start_line_index.
# Returns a Dictionary: { "data": BriefingData, "next_line": int }
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index

	var briefing_data = BriefingData.new()

	if not _parse_required_token("$start_briefing"):
		printerr("BriefingParser: Expected $start_briefing")
		return { "data": null, "next_line": _current_line_num }

	var num_stages_str = _parse_required_token("$num_stages:")
	if num_stages_str == null:
		printerr("BriefingParser: Expected $num_stages:")
		return { "data": null, "next_line": _current_line_num }
	var num_stages = num_stages_str.to_int()

	print(f"Parsing {num_stages} briefing stages...")

	for stage_idx in range(num_stages):
		if not _parse_required_token("$start_stage"):
			printerr(f"BriefingParser: Expected $start_stage for stage {stage_idx}")
			break # Stop parsing stages if format is wrong

		var stage_data = BriefingStageData.new()

		# Parse multi-line text
		if not _parse_required_token("$multi_text"):
			printerr(f"BriefingParser: Expected $multi_text for stage {stage_idx}")
			break
		stage_data.text = _parse_multitext()

		# Parse voice filename
		var voice_str = _parse_required_token("$voice:")
		if voice_str == null:
			printerr(f"BriefingParser: Expected $voice: for stage {stage_idx}")
			break
		if voice_str.to_lower() != "none":
			# Prepend path and assume .ogg format
			stage_data.voice_path = "res://assets/voices/" + voice_str.get_basename() + ".ogg"
		else:
			stage_data.voice_path = "" # Store empty string for "none"

		# Parse camera position
		var cam_pos_str = _parse_required_token("$camera_pos:")
		if cam_pos_str == null:
			printerr(f"BriefingParser: Expected $camera_pos: for stage {stage_idx}")
			break
		stage_data.camera_pos = _parse_vector(cam_pos_str)

		# Parse camera orientation
		var cam_orient_str = _parse_required_token("$camera_orient:")
		if cam_orient_str == null:
			printerr(f"BriefingParser: Expected $camera_orient: for stage {stage_idx}")
			break
		stage_data.camera_orient = _parse_basis(cam_orient_str)

		# Parse camera time
		var cam_time_str = _parse_required_token("$camera_time:")
		if cam_time_str == null:
			printerr(f"BriefingParser: Expected $camera_time: for stage {stage_idx}")
			break
		stage_data.camera_time_ms = cam_time_str.to_int()

		# Parse optional lines
		var num_lines_str = _parse_optional_token("$num_lines:")
		if num_lines_str != null:
			var num_lines = num_lines_str.to_int()
			for line_idx in range(num_lines):
				var line_data = BriefingLineData.new()
				var start_str = _parse_required_token("$line_start:")
				var end_str = _parse_required_token("$line_end:")
				if start_str == null or end_str == null:
					printerr(f"BriefingParser: Error parsing line {line_idx} for stage {stage_idx}")
					break # Stop parsing lines for this stage
				line_data.start_icon_index = start_str.to_int()
				line_data.end_icon_index = end_str.to_int()
				stage_data.lines.append(line_data)

		# Parse number of icons
		var num_icons_str = _parse_required_token("$num_icons:")
		if num_icons_str == null:
			printerr(f"BriefingParser: Expected $num_icons: for stage {stage_idx}")
			break
		var num_icons = num_icons_str.to_int()

		# Parse optional flags
		var flags_str = _parse_optional_token("$flags:")
		if flags_str != null:
			stage_data.flags = flags_str.to_int()

		# Parse optional formula
		# Check if the *next* line starts with $formula: without consuming it yet
		var next_line_peek = _peek_line()
		if next_line_peek != null and next_line_peek.begins_with("$formula:"):
			_read_line() # Consume the $formula: line itself
			# Call the SEXP parser starting from the *current* line number
			# (which is the line *after* $formula:)
			var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
			if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
				stage_data.formula_sexp = sexp_result["sexp_node"]
				# Update the main line counter based on how many lines the SEXP parser consumed
				_current_line_num = sexp_result["next_line"]
				print(f"Parsed SEXP formula for stage {stage_idx}, next line is {_current_line_num}")
			else:
				printerr(f"BriefingParser: Failed to parse SEXP formula for stage {stage_idx}")
				# If SEXP parsing fails, we might be stuck. It's safer to stop parsing this stage.
				# Alternatively, try to find $end_stage, but that's risky.
				# For now, let's assume the SEXP must parse correctly if present.
				# If the SEXP parser returns null, it means an error occurred, and
				# _current_line_num might point to the problematic line or EOF.
				# We might need more robust error handling here later.
				pass # Continue parsing stage, but formula will be null
		else:
			# No $formula: token found, assign default (true)
			# stage_data.formula_sexp = SexpNode.new() # Or load a pre-defined 'true' node
			# stage_data.formula_sexp.op_code = SexpNode.SexpOperator.OP_TRUE
			# stage_data.formula_sexp.node_type = SexpNode.SexpNodeType.ATOM
			# stage_data.formula_sexp.atom_subtype = SexpNode.SexpAtomSubtype.OPERATOR
			# stage_data.formula_sexp.text = "true"
			# print(f"No SEXP formula found for stage {stage_idx}, defaulting.")
			pass # Default is null in the resource definition

		# Parse icons
		for icon_idx in range(num_icons):
			if not _parse_required_token("$start_icon"):
				printerr(f"BriefingParser: Expected $start_icon for icon {icon_idx} in stage {stage_idx}")
				break # Stop parsing icons for this stage

			var icon_data = BriefingIconData.new()

			var type_str = _parse_required_token("$type:")
			if type_str != null: icon_data.type = type_str.to_int()

			var team_str = _parse_required_token("$team:")
			if team_str != null: icon_data.team = GlobalConstants.lookup_iff_index(team_str) # Use GlobalConstants lookup

			var class_str = _parse_required_token("$class:")
			if class_str != null: icon_data.ship_class_name = class_str # Store name, index resolved later

			var pos_str = _parse_required_token("$pos:")
			if pos_str != null: icon_data.position = _parse_vector(pos_str)

			var label_str = _parse_optional_token("$label:")
			if label_str != null: icon_data.label = label_str

			# +id: is optional but important
			var id_str = _parse_optional_token("+id:")
			if id_str != null: icon_data.id = id_str.to_int()

			var hlight_str = _parse_required_token("$hlight:")
			if hlight_str != null and hlight_str.to_int() > 0:
				icon_data.flags |= GlobalConstants.BI_HIGHLIGHT

			# +mirror: is optional
			var mirror_str = _parse_optional_token("+mirror:")
			if mirror_str != null and mirror_str.to_int() > 0:
				icon_data.flags |= GlobalConstants.BI_MIRROR_ICON

			# Icon multi-text (currently ignored in Godot resource)
			if not _parse_required_token("$multi_text"):
				printerr(f"BriefingParser: Expected $multi_text for icon {icon_idx} in stage {stage_idx}")
				break
			_parse_multitext() # Consume the text

			if not _parse_required_token("$end_icon"):
				printerr(f"BriefingParser: Expected $end_icon for icon {icon_idx} in stage {stage_idx}")
				break

			stage_data.icons.append(icon_data)

		if not _parse_required_token("$end_stage"):
			printerr(f"BriefingParser: Expected $end_stage for stage {stage_idx}")
			break

		briefing_data.stages.append(stage_data)

	_parse_optional_token("$end_briefing") # Consume end tag if present

	print(f"Finished parsing briefing section. Consumed lines up to {_current_line_num}")
	return { "data": briefing_data, "next_line": _current_line_num }
