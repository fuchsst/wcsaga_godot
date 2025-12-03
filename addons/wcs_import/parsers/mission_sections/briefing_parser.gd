class_name BriefingParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses the Briefing section (#Briefing)
## Handles briefing stages, icons, and voice

const BriefingStage = preload("res://scripts/resources/missions/briefing_stage.gd")
const BriefingIcon = preload("res://scripts/resources/missions/briefing_icon.gd")
const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Briefing section starts with $start_briefing
	# Then $num_stages: X
	# Then stages follow
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		_get_next_line() # Consume line
		
		if line.begins_with("$start_briefing"):
			continue
			
		if line.begins_with("$num_stages:"):
			var num = _extract_int_value(line, "$num_stages:")
			# We don't strictly need this count as we parse sequentially
			pass
			
		if line.begins_with("$end_briefing"):
			break
			
		if line.begins_with("$Formula:"):
			# Start of a stage
			_parse_stage(line, manifest)
			
	return _base_parser._current_line_index


func _parse_stage(first_line: String, manifest: Resource):
	var stage = BriefingStage.new()
	stage.formula = _extract_sexp_formula(first_line, "$Formula:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next stage or end of briefing
		if line.begins_with("$Formula:") or line.begins_with("$end_briefing") or line.begins_with("#"):
			break
			
		_get_next_line() # Consume
		
		if line.begins_with("$Text:"):
			stage.text = _clean_xstr(_extract_multiline_until(["$end_multi_text"]))
			
		elif line.begins_with("$Voice:"):
			stage.voice_file = _extract_string_value(line, "$Voice:")
			stage.voice_stream = _load_audio_stream(stage.voice_file, "briefing_voice")
			
		elif line.begins_with("$Camera pos:"):
			stage.camera_pos = _parse_vector3(line.substr("$Camera pos:".length()))
			
		elif line.begins_with("$Camera orient:"):
			# Orientation is a matrix, usually 3 lines following? 
			# Or sometimes just one line? In FS2 it's usually a matrix.
			# Let's check the file content. 
			# Usually:
			# $Camera orient:
			#  x, y, z
			#  x, y, z
			#  x, y, z
			var row1 = _parse_vector3(_get_next_line())
			var row2 = _parse_vector3(_get_next_line())
			var row3 = _parse_vector3(_get_next_line())
			stage.camera_orient = Basis(row1, row2, row3)
			
		elif line.begins_with("$Icon:"):
			_parse_icon(line, stage)


func _parse_icon(first_line: String, stage: BriefingStage):
	var icon = BriefingIcon.new()
	# Format: $Icon: type, x, y, z, id
	# Wait, let's check the file format.
	# Usually: $Icon: type
	# $Pos: x, y, z
	# $Label: text
	# $Team: team
	
	# Actually, looking at FS2 docs/files:
	# $Icon: type
	# $Pos: ...
	# $Label: ...
	# $Team: ...
	
	icon.icon_type = _extract_string_value(first_line, "$Icon:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next icon or end of stage properties
		if line.begins_with("$Icon:") or line.begins_with("$Formula:") or line.begins_with("$end_briefing") or line.begins_with("$Text:") or line.begins_with("$Voice:") or line.begins_with("$Camera"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Pos:"):
			icon.position = _parse_vector3(line.substr("$Pos:".length()))
		elif line.begins_with("$Label:"):
			icon.label = _clean_xstr(_extract_string_value(line, "$Label:"))
		elif line.begins_with("$Team:"):
			icon.team = _extract_string_value(line, "$Team:")
		elif line.begins_with("$ID:"):
			icon.icon_id = _extract_int_value(line, "$ID:")
			
	stage.icons.append(icon)
