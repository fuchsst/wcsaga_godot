class_name CommandBriefingParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses the Command Briefing section (#Command Briefing)
## Handles command briefing stages with text, audio, and animation

const CommandBriefingStage = preload("res://scripts/resources/missions/command_briefing_stage.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Command Briefing consists of multiple stages
	# It starts with $Stage Text: usually
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_get_next_line()
			continue
		
		# Each stage starts with $Stage Text:
		if line.begins_with("$Stage Text:"):
			_parse_stage(manifest)
		else:
			_get_next_line() # Skip unexpected lines
	
	return _base_parser._current_line_index


func _parse_stage(manifest: Resource):
	var stage = CommandBriefingStage.new()
	
	# Parse stage properties until we hit the next $Stage Text: or section
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next stage or section
		if line.begins_with("$Stage Text:") and stage.text != "": # Only break if we already parsed text for this stage
			break
		if line.begins_with("#"):
			break
			
		_get_next_line() # Consume line
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		if line.begins_with("$Stage Text:"):
			stage.text = _clean_xstr(_extract_multiline_until(["$end_multi_text"]))
		
		elif line.begins_with("$Ani Filename:"):
			stage.ani_filename = _extract_string_value(line, "$Ani Filename:")
			# Try to load as video stream first
			stage.anim_stream = _load_video_stream(stage.ani_filename)
			# If not found as video, it might be a sprite animation (TODO: handle .eff conversion)
		
		elif line.begins_with("$Wave Filename:") or line.begins_with("+Wave Name:"):
			var prefix = "$Wave Filename:" if line.begins_with("$Wave Filename:") else "+Wave Name:"
			stage.wave_filename = _extract_string_value(line, prefix)
			stage.audio_stream = _load_audio_stream(stage.wave_filename, "briefing_voice")
			
	manifest.command_briefing.append(stage)
