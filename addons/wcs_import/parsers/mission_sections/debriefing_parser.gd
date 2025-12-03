class_name DebriefingParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses the Debriefing section (#Debriefing_info)
## Handles debriefing stages, formulas, and recommendations

const DebriefingStage = preload("res://scripts/resources/missions/debriefing_stage.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Debriefing section starts with $Num stages:
	# Then stages follow
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.strip_edges().begins_with("#"):
			break
		
		_get_next_line() # Consume line
		
		if line.begins_with("$Num stages:"):
			# We don't strictly need this count
			pass
			
		if line.begins_with("$Formula:"):
			# Start of a stage
			_parse_stage(line, manifest)
			
	return _base_parser._current_line_index


func _parse_stage(first_line: String, manifest: Resource):
	var stage = DebriefingStage.new()
	stage.formula = _extract_sexp_formula(first_line, "$Formula:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next stage or section
		if line.begins_with("$Formula:") or line.begins_with("#"):
			break
			
		_get_next_line() # Consume
		
		if line.begins_with("$Text:"):
			stage.text = _clean_xstr(_extract_multiline_until(["$end_multi_text"]))
			
		elif line.begins_with("$Voice:"):
			stage.voice_file = _extract_string_value(line, "$Voice:")
			stage.voice_audio = _load_audio_stream(stage.voice_file, "debriefing_voice")
			
		elif line.begins_with("$Recommendation text:"):
			var next_peek = _peek_next_line()
			if next_peek.strip_edges().begins_with("XSTR") or next_peek.strip_edges().begins_with("\""):
				stage.recommendation_text = _clean_xstr(_extract_multiline_until(["$end_multi_text"]))
			else:
				# Sometimes it might be single line? Usually multiline in FS2.
				# Let's assume multiline structure if $end_multi_text is found later
				stage.recommendation_text = _clean_xstr(_extract_multiline_until(["$end_multi_text"]))

	manifest.debriefing.append(stage)
