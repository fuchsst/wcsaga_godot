class_name WCSMissionParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

## Parser for Freespace 2 mission files (.fs2).
## Converts mission data into MissionManifest resources.

const MissionObject = preload("res://scripts/resources/missions/mission_object.gd")
const MissionWing = preload("res://scripts/resources/missions/mission_wing.gd")
const MissionEvent = preload("res://scripts/resources/missions/mission_event.gd")
const MissionMessage = preload("res://scripts/resources/missions/mission_message.gd")
const MissionManifest = preload("res://scripts/resources/missions/mission_manifest.gd")
const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")

func _parse_content() -> Variant:
	var manifest = MissionManifest.new()
	
	_current_line_index = 0
	var current_section = ""
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
			
		if line.begins_with("#"):
			current_section = line.lstrip("#").strip_edges()
			continue
			
		match current_section:
			"Mission Info":
				_parse_mission_info_line(line, manifest)
			"Objects":
				if line.begins_with("$Name:"):
					_parse_object(line, manifest)
			"Wings":
				if line.begins_with("$Name:"):
					_parse_wing(line, manifest)
			"Events":
				if line.begins_with("$Formula:"):
					_parse_event(line, manifest)
			"Messages":
				if line.begins_with("$Name:"):
					_parse_message(line, manifest)
			"Cutscenes":
				if line.begins_with("$Filename:"):
					_parse_cutscene(line, manifest)
			
	return manifest

# ... (existing methods)

func _parse_cutscene(first_line: String, manifest: MissionManifest):
	var filename = _extract_string_value(first_line, "$Filename:")
	var video_stream = VideoStreamTheora.new()
	# Determine path using PathResolver
	var path_info = WCSPathResolver.determine_asset_output_path(filename)
	var path = "res://assets/" + path_info[0] + "/" + path_info[1] + "/" + filename
	video_stream.file = path
	
	manifest.cutscenes.append(video_stream)
	
	# Consume rest of block if any (usually just one line for cutscenes in some formats, but let's check)
	# FS2 cutscenes might have more properties.
	# For now, assuming simple filename line or block.
	# If it's a block, I should consume it.
	if not _peek_next_line().begins_with("$Filename:") and not _peek_next_line().begins_with("#"):
		_consume_block()

func _parse_mission_info_line(line: String, manifest: MissionManifest):
	if line.begins_with("$Version:"):
		manifest.metadata["version"] = _extract_float_value(line, "$Version:")
	elif line.begins_with("$Name:"):
		manifest.mission_name = _extract_string_value(line, "$Name:")
	elif line.begins_with("$Author:"):
		manifest.metadata["author"] = _extract_string_value(line, "$Author:")
	elif line.begins_with("$Created:"):
		manifest.metadata["created"] = _extract_string_value(line, "$Created:")
	elif line.begins_with("$Modified:"):
		manifest.metadata["modified"] = _extract_string_value(line, "$Modified:")
	elif line.begins_with("$Notes:"):
		manifest.metadata["notes"] = _extract_string_value(line, "$Notes:")
	elif line.begins_with("$Mission Desc:"):
		manifest.metadata["description"] = _extract_string_value(line, "$Mission Desc:")
	elif line.begins_with("+Type:"):
		manifest.metadata["type"] = _extract_int_value(line, "+Type:")
	elif line.begins_with("+Flags:"):
		manifest.metadata["flags"] = _extract_int_value(line, "+Flags:")

func _parse_object(first_line: String, manifest: MissionManifest):
	var obj = MissionObject.new()
	obj.object_name = _extract_string_value(first_line, "$Name:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
			
		_get_next_line() # Consume
		
		if line.begins_with("$Class:"):
			obj.ship_class = _extract_string_value(line, "$Class:")
		elif line.begins_with("$Team:"):
			obj.team_name = _extract_string_value(line, "$Team:")
		elif line.begins_with("$Location:"):
			obj.position = _parse_vector3(line.substr(10))
		elif line.begins_with("$Orientation:"):
			# Orientation parsing to be implemented
			pass
		elif line.begins_with("$Flags:"):
			# Flags parsing
			pass
			
	manifest.objects.append(obj)

func _parse_wing(first_line: String, manifest: MissionManifest):
	var wing = MissionWing.new()
	wing.wing_name = _extract_string_value(first_line, "$Name:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
			
		_get_next_line() # Consume
		
		if line.begins_with("$Waves:"):
			wing.wave_count = _extract_int_value(line, "$Waves:")
		elif line.begins_with("$Wave Threshold:"):
			wing.wave_threshold = _extract_int_value(line, "$Wave Threshold:")
		elif line.begins_with("$Special Ship:"):
			wing.ship_class = _extract_string_value(line, "$Special Ship:")
			
	manifest.wings.append(wing)

func _parse_event(first_line: String, manifest: MissionManifest):
	var event = MissionEvent.new()
	# event.formula = _extract_string_value(first_line, "$Formula:") 
	# Assuming MissionEvent has a formula property, checking file...
	# It likely has name, repeat_count, interval, etc.
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Formula:") or line.begins_with("#"):
			break
			
		_get_next_line() # Consume
		
		if line.begins_with("+Name:"):
			event.event_name = _extract_string_value(line, "+Name:")
		elif line.begins_with("+Repeat Count:"):
			event.repeat_count = _extract_int_value(line, "+Repeat Count:")
		elif line.begins_with("+Interval:"):
			event.interval = _extract_int_value(line, "+Interval:")
			
	manifest.events.append(event)

func _parse_message(first_line: String, manifest: MissionManifest):
	var msg = MissionMessage.new()
	msg.message_name = _extract_string_value(first_line, "$Name:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
			
		_get_next_line() # Consume
		
		if line.begins_with("$Message:"):
			msg.message_text = _extract_string_value(line, "$Message:")
		elif line.begins_with("$Persona:"):
			msg.persona_name = _extract_string_value(line, "$Persona:")
		elif line.begins_with("$AVI Name:"):
			msg.avi_filename = _extract_string_value(line, "$AVI Name:")
		elif line.begins_with("$Wave Name:"):
			msg.wave_filename = _extract_string_value(line, "$Wave Name:")
			
	manifest.messages.append(msg)

func _consume_block():
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$") or line.begins_with("#"):
			break
		_get_next_line()
