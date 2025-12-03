class_name EnvironmentParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses Environment-related sections:
## #Background bitmaps, #Asteroid Fields, #Nebula

const BackgroundData = preload("res://scripts/resources/missions/background_data.gd")
const SunData = preload("res://scripts/resources/missions/sun_data.gd")
const BackgroundSet = preload("res://scripts/resources/missions/background_set.gd")
const AsteroidField = preload("res://scripts/resources/missions/asteroid_field.gd")
const MissionNebulaData = preload("res://scripts/resources/missions/mission_nebula_data.gd")
const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# This parser handles multiple sections, but parse_section is called for one specific section
	# We need to determine which section we are in based on the first line or context
	# Actually, MissionParser delegates based on section header.
	# So we might need different entry points or just check the current line.
	# However, MissionParser calls parse_section for a specific block.
	# Let's see what the current line is.
	var line = _get_current_line()
	if line.begins_with("#Background bitmaps"):
		_parse_background_bitmaps(manifest)
	elif line.begins_with("#Asteroid Fields"):
		_parse_asteroid_fields(manifest)
	elif line.begins_with("#Nebula"):
		_parse_nebula(manifest)
	elif line.begins_with("#Music"):
		_parse_music(manifest)
		
	return _base_parser._current_line_index


func _parse_background_bitmaps(manifest: Resource):
	var bg = manifest.backgrounds
	
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.strip_edges().begins_with("#") and not line.strip_edges().begins_with("#Background bitmaps"):
			break
			
		_get_next_line() # Consume
		
		if line.begins_with("$Num stars:"):
			# Not used in Godot usually, but we can store it if needed
			pass
			
		elif line.begins_with("$Ambient light level:"):
			# FS2 ambient light is an int, maybe color?
			pass
			
		elif line.begins_with("$Sun:"):
			_parse_sun(line, bg)
			
		elif line.begins_with("$Starbitmap:"):
			_parse_starbitmap(line, bg)
			
		elif line.begins_with("+Nebula:"):
			# Background nebula bitmap
			pass


func _parse_sun(first_line: String, bg: BackgroundData):
	var sun = SunData.new()
	sun.sun_type = _extract_string_value(first_line, "$Sun:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$") or line.begins_with("#") or line.begins_with("+Nebula:"): # Break on next item
			break
			
		_get_next_line()
		
		if line.begins_with("+Angles:"):
			sun.angles = _parse_vector3(line.substr("+Angles:".length()))
		elif line.begins_with("+Scale:"):
			sun.scale = _extract_float_value(line, "+Scale:")
			
	bg.suns.append(sun)


func _parse_starbitmap(first_line: String, bg: BackgroundData):
	var set = BackgroundSet.new()
	set.bitmap_name = _extract_string_value(first_line, "$Starbitmap:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$") or line.begins_with("#") or line.begins_with("+Nebula:"):
			break
			
		_get_next_line()
		
		if line.begins_with("+Angles:"):
			set.angles = _parse_vector3(line.substr("+Angles:".length()))
		elif line.begins_with("+ScaleX:"):
			set.scale_x = _extract_float_value(line, "+ScaleX:")
		elif line.begins_with("+ScaleY:"):
			set.scale_y = _extract_float_value(line, "+ScaleY:")
		elif line.begins_with("+DivX:"):
			set.div_x = _extract_int_value(line, "+DivX:")
		elif line.begins_with("+DivY:"):
			set.div_y = _extract_int_value(line, "+DivY:")
			
	bg.background_sets.append(set)


func _parse_asteroid_fields(manifest: Resource):
	# Parse asteroid fields
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("#") and not line.begins_with("#Asteroid Fields"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Density:"):
			_parse_single_asteroid_field(line, manifest)


func _parse_single_asteroid_field(first_line: String, manifest: Resource):
	var field = AsteroidField.new()
	field.density = _extract_int_value(first_line, "$Density:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Density:") or line.begins_with("#"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Location:"):
			field.location = _parse_vector3(line.substr("$Location:".length()))
		elif line.begins_with("$Speed:"):
			field.speed = _extract_float_value(line, "$Speed:")
		elif line.begins_with("$Radius:"):
			field.radius = _extract_float_value(line, "$Radius:")
		elif line.begins_with("$Inner Radius:"):
			field.inner_radius = _extract_float_value(line, "$Inner Radius:")
			
	manifest.asteroid_fields.append(field)


func _parse_nebula(manifest: Resource):
	# Parse full nebula section
	var neb = manifest.backgrounds.nebula
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("#") and not line.begins_with("#Nebula"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Nebula:"):
			neb.nebula_filename = _extract_string_value(line, "$Nebula:")
		# Add other nebula fields as needed


func _parse_music(manifest: Resource):
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("#") and not line.begins_with("#Music"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Event Music:"):
			manifest.music = _load_audio_stream(_extract_string_value(line, "$Event Music:"))
		elif line.begins_with("$Briefing Music:"):
			manifest.briefing_music = _load_audio_stream(_extract_string_value(line, "$Briefing Music:"))
		elif line.begins_with("$Debriefing Music:"):
			manifest.debriefing_music = _load_audio_stream(_extract_string_value(line, "$Debriefing Music:"))
