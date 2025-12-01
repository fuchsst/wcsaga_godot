class_name WCSMissionParser
extends WCSBaseParser

## Parser for Freespace 2 mission files (.fs2).
## Converts mission data into MissionManifest resources.

const MissionObject = preload("res://scripts/resources/missions/mission_object.gd")
const MissionWing = preload("res://scripts/resources/missions/mission_wing.gd")
const MissionEvent = preload("res://scripts/resources/missions/mission_event.gd")
const MissionMessage = preload("res://scripts/resources/missions/mission_message.gd")
const SupportShipInfo = preload("res://scripts/resources/missions/support_ship_info.gd")
const MissionCutscene = preload("res://scripts/resources/missions/mission_cutscene.gd")
const TextureReplacement = preload("res://scripts/resources/missions/texture_replacement.gd")
const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")
# MissionEnums is a class_name, so we can use it directly
const MissionManifest = preload("res://scripts/resources/missions/mission_manifest.gd")
const CommandBriefingStage = preload("res://scripts/resources/missions/command_briefing_stage.gd")
const BriefingStage = preload("res://scripts/resources/missions/briefing_stage.gd")
const DebriefingStage = preload("res://scripts/resources/missions/debriefing_stage.gd")
const BackgroundSet = preload("res://scripts/resources/missions/background_set.gd")
const MissionNebulaData = preload("res://scripts/resources/missions/mission_nebula_data.gd")
const AsteroidField = preload("res://scripts/resources/missions/asteroid_field.gd")
const SunData = preload("res://scripts/resources/missions/sun_data.gd")
const StarBitmapData = preload("res://scripts/resources/environment/stars/star_bitmap_data.gd")
const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")
const SexpVariable = preload("res://scripts/resources/missions/sexp_variable.gd")
const ShipStats = preload("res://scripts/resources/ships/ship_stats.gd")
const AIClassResource = preload("res://scripts/resources/ai_classes/ai_class_resource.gd")

# Section Parsers
const MissionInfoParser = preload("res://addons/wcs_import/parsers/mission_sections/mission_info_parser.gd")
const ObjectParser = preload("res://addons/wcs_import/parsers/mission_sections/object_parser.gd")
const PlayerParser = preload("res://addons/wcs_import/parsers/mission_sections/player_parser.gd")

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
			# Handle inline comments like "#Objects ;! 58 total"
			if ";" in current_section:
				current_section = current_section.split(";")[0].strip_edges()
			continue

		match current_section:
			"Mission Info":
				# Delegate to MissionInfoParser
				var parser = MissionInfoParser.new(self)
				_current_line_index = parser.parse_section(_current_line_index, manifest) - 1
			"Sexp_variables":
				if line.begins_with("$Variables:"):
					_parse_sexp_variables(manifest)
			"Fiction Viewer":
				if line.begins_with("$File:"):
					manifest.fiction_viewer_file = _extract_string_value(line, "$File:")
			"Command Briefing":
				if line.begins_with("$Stage Text:"):
					_parse_command_briefing_stage(manifest)
			"Briefing":
				if line.begins_with("$start_briefing"):
					_parse_briefing(manifest)
			"Debriefing_info":
				if line.begins_with("$Num stages:"):
					_parse_debriefing(manifest)
			"Players":
				# Delegate to PlayerParser
				var parser = PlayerParser.new(self)
				_current_line_index = parser.parse_section(_current_line_index, manifest) - 1
			"Objects":
				# Delegate to ObjectParser
				var parser = ObjectParser.new(self)
				_current_line_index = parser.parse_section(_current_line_index, manifest) - 1
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
				if line.begins_with("$Filename:") or line.begins_with("$Briefing Cutscene:"):
					_parse_cutscene(manifest)
			"Callsigns":
				if line.begins_with("$Callsign:"):
					manifest.callsigns.append(_extract_string_value(line, "$Callsign:"))
			"Background bitmaps":
				if line.begins_with("$Name:"):
					_parse_background_bitmap(line, manifest)
				elif line.begins_with("$Sun:"):
					_parse_sun(line, manifest)
				elif line.begins_with("+Nebula:"):
					_parse_nebula(line, manifest)
			"Asteroid Fields":
				if line.begins_with("$Density:"):
					_parse_asteroid_field(line, manifest)
				if line.begins_with("$Event Music:"):
					manifest.music = _load_audio_stream(_extract_string_value(line, "$Event Music:"))
				elif line.begins_with("$Briefing Music:"):
					manifest.briefing_music = _load_audio_stream(_extract_string_value(line, "$Briefing Music:"))
				elif line.begins_with("$Debriefing Music:"):
					manifest.debriefing_music = _load_audio_stream(_extract_string_value(line, "$Debriefing Music:"))

	return manifest


func _get_current_line() -> String:
	if _current_line_index > 0 and _current_line_index <= _lines.size():
		return _lines[_current_line_index - 1]
	return ""

# Helper to clean FS2 strings (remove XSTR, comments, quotes)
func _clean_fs2_string(raw: String) -> String:
	var s = raw.strip_edges()
	
	# Comments are now handled by BaseParser globally, but just in case
	var comment_idx = s.find(";")
	if comment_idx != -1:
		s = s.substr(0, comment_idx).strip_edges()
		
	# Handle XSTR("Value", ID)
	if s.begins_with("XSTR"):
		var first_quote = s.find("\"")
		var last_quote = s.rfind("\"")
		var comma = s.rfind(",")
		if comma != -1 and first_quote != -1:
			var second_quote = s.find("\"", first_quote + 1)
			if second_quote != -1:
				s = s.substr(first_quote + 1, second_quote - first_quote - 1)
				return s
	
	# Remove surrounding quotes if present
	if s.begins_with("\"") and s.ends_with("\""):
		s = s.substr(1, s.length() - 2)
		
	return s

func _load_ship_resource(ship_class_name: String) -> Resource:
	var path = "res://campaigns/hermes/ships/" + ship_class_name + ".tres"
	if FileAccess.file_exists(path):
		return ResourceLoader.load(path)
	
	push_error("Ship resource not found: " + ship_class_name + " at " + path)
	return null

func _load_audio_stream(filename: String) -> AudioStream:
	if filename == "" or filename == "none": return null
	var base = filename.get_basename()
	var paths = [
		"res://assets/music/" + filename,
		"res://assets/voice/" + filename,
		"res://assets/music/" + base + ".ogg",
		"res://assets/voice/" + base + ".ogg",
		"res://assets/music/" + base + ".wav",
		"res://assets/voice/" + base + ".wav"
	]
	
	for p in paths:
		if FileAccess.file_exists(p):
			return ResourceLoader.load(p) as AudioStream
			
	push_error("Audio resource not found: " + filename)
	return null

func _load_video_stream(filename: String) -> VideoStream:
	if filename == "" or filename == "none": return null
	var base = filename.get_basename()
	var paths = [
		"res://assets/movies/" + filename,
		"res://assets/movies/" + base + ".ogv"
	]
	for p in paths:
		if FileAccess.file_exists(p):
			return ResourceLoader.load(p) as VideoStream
			
	push_error("Video resource not found: " + filename)
	return null

func _load_model_resource(filename: String) -> Resource:
	var base = filename.get_basename()
	var paths = [
		"res://assets/models/" + filename,
		"res://assets/models/" + base + ".glb",
		"res://assets/models/" + base + ".gltf",
		"res://assets/models/" + base + ".tscn"
	]
	for p in paths:
		if FileAccess.file_exists(p):
			return ResourceLoader.load(p)
			
	push_error("Model resource not found: " + filename)
	return null

func _load_sky_resource(filename: String) -> Sky:
	var path = "res://assets/environment/skies/" + filename + ".tres"
	if FileAccess.file_exists(path):
		return ResourceLoader.load(path) as Sky
		
	push_error("Sky resource not found: " + filename)
	return null

func _load_bitmap_resource(filename: String) -> Texture2D:
	var base = filename.get_basename()
	var paths = [
		"res://assets/images/" + filename,
		"res://assets/images/" + base + ".png",
		"res://assets/images/" + base + ".jpg"
	]
	for p in paths:
		if FileAccess.file_exists(p):
			return ResourceLoader.load(p) as Texture2D
			
	push_error("Bitmap resource not found: " + filename)
	return null

func _load_animation_resource(filename: String) -> SpriteFrames:
	var base = filename.get_basename()
	var path = "res://assets/animations/" + base + ".tres"
	if FileAccess.file_exists(path):
		return ResourceLoader.load(path) as SpriteFrames
		
	push_error("Animation resource not found: " + filename)
	return null

func _load_persona(persona_name: String) -> Resource:
	var path = "res://campaigns/hermes/personas/" + persona_name + ".tres" # Assuming path
	if FileAccess.file_exists(path):
		return ResourceLoader.load(path)
	push_error("Persona resource not found: " + persona_name)
	return null

func _extract_string_value(line: String, prefix: String) -> String:
	var val = line.substr(prefix.length()).strip_edges()
	return _clean_fs2_string(val)

# ... (Parsing functions updated to use _clean_fs2_string and new types)


func _parse_object(first_line: String, manifest: MissionManifest):
	pass

func _parse_message(first_line: String, manifest: MissionManifest):
	var msg = MissionMessage.new()
	msg.message_name = _extract_string_value(first_line, "$Name:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
		_get_next_line()
		
		if line.begins_with("$Team:"):
			msg.team = _map_team(_extract_string_value(line, "$Team:"))
		elif line.begins_with("$Persona:"):
			var p_name = _extract_string_value(line, "$Persona:")
			msg.persona = _load_persona(p_name)
			# Assuming message_name corresponds to key in persona
			msg.message_key = msg.message_name
		elif line.begins_with("$Message New:"): # Or whatever the tag is for message content if not using persona
			pass

	manifest.messages.append(msg)

func _parse_event(first_line: String, manifest: MissionManifest):
	var event = MissionEvent.new()
	event.formula = _extract_string_value(first_line, "$Formula:")
	# Handle multi-line formula
	while _has_more_lines():
		var next_peek = _peek_next_line()
		if next_peek.begins_with("$") or next_peek.begins_with("+"):
			break
		event.formula += " " + _get_next_line().strip_edges()

	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Formula:") or line.begins_with("#"):
			break
		_get_next_line()

		if line.begins_with("+Name:"):
			event.event_name = _extract_string_value(line, "+Name:")
		elif line.begins_with("+Repeat Count:"):
			event.repeat_count = _extract_int_value(line, "+Repeat Count:")
		elif line.begins_with("+Interval:"):
			event.interval = _extract_int_value(line, "+Interval:")
		elif line.begins_with("+Chain Delay:"):
			event.chain_delay = _extract_int_value(line, "+Chain Delay:")
		elif line.begins_with("+Objective:"):
			event.objective = _extract_string_value(line, "+Objective:")

	manifest.events.append(event)


func _parse_cutscene(manifest: MissionManifest):
	var cutscene = MissionCutscene.new()
	while _has_more_lines():
		var line = _peek_next_line()
		if not (line.begins_with("$Filename:") or line.begins_with("$Name:") or line.begins_with("$Formula:")):
			break
			
		_get_next_line()
		
		if line.begins_with("$Filename:"):
			cutscene.filename = _extract_string_value(line, "$Filename:")
			cutscene.video_stream = _load_video_stream(cutscene.filename)
		elif line.begins_with("$Name:"):
			cutscene.name = _extract_string_value(line, "$Name:")
		elif line.begins_with("$Formula:"):
			cutscene.formula = _extract_string_value(line, "$Formula:")
			
	manifest.cutscenes.append(cutscene)


func _parse_command_briefing_stage(manifest: MissionManifest):
	var stage = CommandBriefingStage.new()
	while _has_more_lines():
		var line = _peek_next_line()
		if not (line.begins_with("$Text:") or line.begins_with("$Ani Filename:") or line.begins_with("+Wave Filename:")):
			break
			
		_get_next_line()
		
		if line.begins_with("$Text:"):
			stage.text = _extract_string_value(line, "$Text:")
			# Handle multi-line text
			while _has_more_lines() and not (_peek_next_line().begins_with("$") or _peek_next_line().begins_with("+")):
				stage.text += "\n" + _get_next_line()
		
		if line.begins_with("$Ani Filename:"):
			stage.ani_filename = _extract_string_value(line, "$Ani Filename:")
			stage.anim_stream = _load_video_stream(stage.ani_filename)
		elif line.begins_with("+Wave Filename:"):
			stage.wave_filename = _extract_string_value(line, "+Wave Filename:")
			stage.audio_stream = _load_audio_stream(stage.wave_filename)
			
	manifest.command_briefing.append(stage)


func _parse_briefing(manifest: MissionManifest):
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("#") or line.begins_with("$end_briefing"):
			if line.begins_with("$end_briefing"): _get_next_line()
			break
			
		_get_next_line()
		
		if line.begins_with("$start_stage"):
			_parse_briefing_stage(manifest)


func _parse_briefing_stage(manifest: MissionManifest):
	var stage = BriefingStage.new()
	while _has_more_lines():
		var line = _peek_next_line()
		if not (line.begins_with("$Formula:") or line.begins_with("$Text:") or line.begins_with("$Icon:") or line.begins_with("$Voice:")):
			break
			
		_get_next_line()
		
		if line.begins_with("$Formula:"):
			stage.formula = _extract_string_value(line, "$Formula:")
		elif line.begins_with("$Text:"):
			stage.text = _extract_string_value(line, "$Text:")
			while _has_more_lines() and not (_peek_next_line().begins_with("$") or _peek_next_line().begins_with("+")):
				stage.text += "\n" + _get_next_line()
		elif line.begins_with("$Icon:"):
			_parse_briefing_icon(stage)
		elif line.begins_with("$Voice:"):
			stage.voice_file = _extract_string_value(line, "$Voice:")
			stage.voice_stream = _load_audio_stream(stage.voice_file)
			
	manifest.briefing.append(stage)


func _parse_briefing_icon(stage: BriefingStage):
	# ... (implementation of icon parsing)
	pass


func _parse_debriefing(manifest: MissionManifest):
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("#"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Formula:"):
			var stage = DebriefingStage.new()
			stage.formula = _extract_string_value(line, "$Formula:")
			_parse_debriefing_stage(stage)
			manifest.debriefing.append(stage)


func _parse_debriefing_stage(stage: DebriefingStage):
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Formula:") or line.begins_with("#"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Multi text"):
			stage.text = _extract_multiline_text()
		elif line.begins_with("$Voice:"):
			stage.voice_file = _extract_string_value(line, "$Voice:")
		elif line.begins_with("$Recommendation text:"):
			stage.recommendation_text = _extract_multiline_text()


func _extract_multiline_text() -> String:
	var text = ""
	while _has_more_lines():
		var line = _get_next_line()
		if line.begins_with("$end_multi_text"):
			break
		text += line + "\n"
	return text.strip_edges()


func _parse_background_bitmap(first_line: String, manifest: MissionManifest):
	var bmp = StarBitmapData.new()
	bmp.filename = _extract_string_value(first_line, "$Name:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("$Sun:") or line.begins_with("+Nebula:") or line.begins_with("#"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Location:"):
			bmp.angles = _parse_vector3(line.substr(10))
	
	_ensure_background_set(manifest)
	manifest.backgrounds.backgrounds[0].bitmaps.append(bmp)


func _parse_sun(first_line: String, manifest: MissionManifest):
	var sun = SunData.new()
	sun.filename = _extract_string_value(first_line, "$Sun:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("$Sun:") or line.begins_with("+Nebula:") or line.begins_with("#"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Location:"):
			sun.angles = _parse_vector3(line.substr(10))
		elif line.begins_with("$Scale:"):
			sun.scale = _extract_float_value(line, "$Scale:")
			
	_ensure_background_set(manifest)
	manifest.backgrounds.backgrounds[0].suns.append(sun)


func _ensure_background_set(manifest: MissionManifest):
	if manifest.backgrounds.backgrounds.is_empty():
		manifest.backgrounds.backgrounds.append(BackgroundSet.new())


func _parse_nebula(first_line: String, manifest: MissionManifest):
	var neb = MissionNebulaData.new()
	neb.nebula_name = _extract_string_value(first_line, "+Nebula:")
	manifest.backgrounds.nebula = neb


func _parse_asteroid_field(first_line: String, manifest: MissionManifest):
	var field = AsteroidField.new()
	field.density = _extract_int_value(first_line, "$Density:")
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Density:") or line.begins_with("#"):
			break
			
		_get_next_line()
		
		if line.begins_with("$Location:"):
			field.position = _parse_vector3(line.substr(10))
		elif line.begins_with("$Volume:"):
			field.volume = _parse_vector3(line.substr(9))
		elif line.begins_with("$Average Speed:"):
			field.average_speed = _extract_float_value(line, "$Average Speed:")
			
	manifest.asteroid_fields.append(field)


func _parse_sexp_variables(manifest: MissionManifest):
	pass


func _split_fs2_list_line(line: String) -> Array[String]:
	return []


func _consume_block():
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$") or line.begins_with("#"):
			break
		_get_next_line()


func _map_team(name: String) -> MissionEnums.Team:
	match name.to_lower():
		"friendly": return MissionEnums.Team.FRIENDLY
		"hostile": return MissionEnums.Team.HOSTILE
		"neutral": return MissionEnums.Team.NEUTRAL
		"unknown": return MissionEnums.Team.UNKNOWN
		"traitor": return MissionEnums.Team.TRAITOR
		_: return MissionEnums.Team.UNKNOWN

func _map_ai_behavior(name: String) -> MissionEnums.AIBehavior:
	match name.to_lower():
		"none": return MissionEnums.AIBehavior.NONE
		"chase": return MissionEnums.AIBehavior.CHASE
		"evade": return MissionEnums.AIBehavior.EVADE
		"get behind": return MissionEnums.AIBehavior.GET_BEHIND
		"stay near": return MissionEnums.AIBehavior.STAY_NEAR
		"still": return MissionEnums.AIBehavior.STILL
		"guard": return MissionEnums.AIBehavior.GUARD
		"avoid": return MissionEnums.AIBehavior.AVOID
		"waypoints": return MissionEnums.AIBehavior.WAYPOINTS
		"dock": return MissionEnums.AIBehavior.DOCK
		_: return MissionEnums.AIBehavior.NONE

func _map_arrival_location(name: String) -> MissionEnums.ArrivalLocation:
	if name.to_lower() == "hyperspace":
		return MissionEnums.ArrivalLocation.HYPERSPACE
	elif name.to_lower().begins_with("near ship"):
		return MissionEnums.ArrivalLocation.NEAR_SHIP
	elif name.to_lower().begins_with("in front of ship"):
		return MissionEnums.ArrivalLocation.IN_FRONT_OF_SHIP
	elif name.to_lower().begins_with("docking bay"):
		return MissionEnums.ArrivalLocation.DOCKING_BAY
	return MissionEnums.ArrivalLocation.HYPERSPACE

func _map_departure_location(name: String) -> MissionEnums.DepartureLocation:
	if name.to_lower() == "hyperspace":
		return MissionEnums.DepartureLocation.HYPERSPACE
	elif name.to_lower().begins_with("docking bay"):
		return MissionEnums.DepartureLocation.DOCKING_BAY
	return MissionEnums.DepartureLocation.HYPERSPACE


func _parse_texture_replacement(obj: MissionObject):
	var rep = TextureReplacement.new()
	while _has_more_lines():
		var line = _peek_next_line()
		if not (line.begins_with("+Old Texture:") or line.begins_with("+New Texture:") or line.begins_with("+New Texture ID:")):
			break
			
		_get_next_line()
		
		if line.begins_with("+Old Texture:"):
			rep.old_texture = _extract_string_value(line, "+Old Texture:")
		elif line.begins_with("+New Texture:"):
			rep.new_texture = _extract_string_value(line, "+New Texture:")
			rep.new_texture_stream = _load_asset(rep.new_texture)
		elif line.begins_with("+New Texture ID:"):
			rep.new_texture_id = _extract_int_value(line, "+New Texture ID:")
			
	obj.texture_replacements.append(rep)


func _load_asset(filename: String) -> Resource:
	if filename.is_empty():
		return null
		
	var path_info = WCSPathResolver.determine_asset_output_path(filename)
	var path = "res://assets/" + path_info[0] + "/" + path_info[1] + "/" + filename
	
	# Try to find the file with different extensions if not found
	if not FileAccess.file_exists(path):
		# Simple fuzzy match for extension
		var base_dir = path.get_base_dir()
		var base_name = filename.get_basename()
		var dir = DirAccess.open(base_dir)
		if dir:
			dir.list_dir_begin()
			var file = dir.get_next()
			while file != "":
				if file.get_basename() == base_name:
					path = base_dir.path_join(file)
					break
				file = dir.get_next()
	
	if ResourceLoader.exists(path):
		return load(path)
	
	# push_warning("Asset not found: " + filename + " at " + path)
	return null


func _load_ai_class_resource(ai_class_name: String) -> Resource:
	# Clean up name
	var clean_name = ai_class_name.strip_edges()
	# Try to find in ai_classes directory
	# We search recursively because structure might be nested by difficulty or category
	return _find_resource_in_dir("res://campaigns/hermes/ai_classes", clean_name + ".tres")

func _map_orders_accepted(mask: int) -> Array[MissionEnums.OrdersAccepted]:
	var result: Array[MissionEnums.OrdersAccepted] = []
	if mask & (1 << 0): result.append(MissionEnums.OrdersAccepted.ATTACK_TARGET)
	if mask & (1 << 1): result.append(MissionEnums.OrdersAccepted.DISABLE_TARGET)
	if mask & (1 << 2): result.append(MissionEnums.OrdersAccepted.DISARM_TARGET)
	if mask & (1 << 3): result.append(MissionEnums.OrdersAccepted.PROTECT_TARGET)
	if mask & (1 << 4): result.append(MissionEnums.OrdersAccepted.IGNORE_TARGET)
	if mask & (1 << 5): result.append(MissionEnums.OrdersAccepted.FORMATION)
	if mask & (1 << 6): result.append(MissionEnums.OrdersAccepted.COVER_ME)
	if mask & (1 << 7): result.append(MissionEnums.OrdersAccepted.ENGAGE_ENEMY)
	if mask & (1 << 8): result.append(MissionEnums.OrdersAccepted.CAPTURE_TARGET)
	if mask & (1 << 9): result.append(MissionEnums.OrdersAccepted.REARM_REPAIR_ME)
	if mask & (1 << 10): result.append(MissionEnums.OrdersAccepted.ABORT_REARM_REPAIR)
	if mask & (1 << 11): result.append(MissionEnums.OrdersAccepted.STAY_NEAR_ME)
	if mask & (1 << 12): result.append(MissionEnums.OrdersAccepted.STAY_NEAR_TARGET)
	if mask & (1 << 13): result.append(MissionEnums.OrdersAccepted.KEEP_SAFE_DIST)
	if mask & (1 << 14): result.append(MissionEnums.OrdersAccepted.DEPART)
	if mask & (1 << 15): result.append(MissionEnums.OrdersAccepted.DISABLE_SUBSYSTEM)
	return result

func _map_game_type_flags(mask: int) -> Array[MissionEnums.GameTypeFlags]:
	var result: Array[MissionEnums.GameTypeFlags] = []
	if mask & (1 << 0): result.append(MissionEnums.GameTypeFlags.SINGLE)
	if mask & (1 << 1): result.append(MissionEnums.GameTypeFlags.MULTI)
	if mask & (1 << 2): result.append(MissionEnums.GameTypeFlags.TRAINING)
	if mask & (1 << 3): result.append(MissionEnums.GameTypeFlags.MULTI_COOP)
	if mask & (1 << 4): result.append(MissionEnums.GameTypeFlags.MULTI_TEAMS)
	if mask & (1 << 5): result.append(MissionEnums.GameTypeFlags.MULTI_DOGFIGHT)
	return result

func _map_mission_flags(mask: int) -> Array[MissionEnums.MissionFlags]:
	var result: Array[MissionEnums.MissionFlags] = []
	if mask & (1 << 0): result.append(MissionEnums.MissionFlags.SUBSPACE)
	if mask & (1 << 1): result.append(MissionEnums.MissionFlags.NO_PROMOTION)
	if mask & (1 << 2): result.append(MissionEnums.MissionFlags.FULLNEB)
	if mask & (1 << 3): result.append(MissionEnums.MissionFlags.NO_BUILTIN_MSGS)
	if mask & (1 << 4): result.append(MissionEnums.MissionFlags.NO_TRAITOR)
	if mask & (1 << 5): result.append(MissionEnums.MissionFlags.TOGGLE_SHIP_TRAILS)
	if mask & (1 << 6): result.append(MissionEnums.MissionFlags.SUPPORT_REPAIRS_HULL)
	if mask & (1 << 7): result.append(MissionEnums.MissionFlags.BEAM_FREE_ALL_BY_DEFAULT)
	if mask & (1 << 10): result.append(MissionEnums.MissionFlags.NO_BRIEFING)
	if mask & (1 << 11): result.append(MissionEnums.MissionFlags.TOGGLE_DEBRIEFING)
	if mask & (1 << 13): result.append(MissionEnums.MissionFlags.ALLOW_DOCK_TREES)
	if mask & (1 << 14): result.append(MissionEnums.MissionFlags.MISSION_2D)
	if mask & (1 << 16): result.append(MissionEnums.MissionFlags.RED_ALERT)
	if mask & (1 << 17): result.append(MissionEnums.MissionFlags.SCRAMBLE)
	if mask & (1 << 18): result.append(MissionEnums.MissionFlags.NO_BUILTIN_COMMAND)
	if mask & (1 << 19): result.append(MissionEnums.MissionFlags.PLAYER_START_AI)
	if mask & (1 << 20): result.append(MissionEnums.MissionFlags.ALL_ATTACK)
	if mask & (1 << 21): result.append(MissionEnums.MissionFlags.USE_AP_CINEMATICS)
	if mask & (1 << 22): result.append(MissionEnums.MissionFlags.DEACTIVATE_AP)
	return result

func _map_skybox_flags(mask: int) -> Array[MissionEnums.SkyboxFlags]:
	var result: Array[MissionEnums.SkyboxFlags] = []
	if mask & (1 << 0): result.append(MissionEnums.SkyboxFlags.SHOW_OUTLINE)
	if mask & (1 << 1): result.append(MissionEnums.SkyboxFlags.SHOW_PIVOTS)
	if mask & (1 << 2): result.append(MissionEnums.SkyboxFlags.SHOW_PATHS)
	if mask & (1 << 3): result.append(MissionEnums.SkyboxFlags.SHOW_RADIUS)
	if mask & (1 << 4): result.append(MissionEnums.SkyboxFlags.SHOW_SHIELDS)
	if mask & (1 << 5): result.append(MissionEnums.SkyboxFlags.SHOW_THRUSTERS)
	if mask & (1 << 6): result.append(MissionEnums.SkyboxFlags.LOCK_DETAIL)
	if mask & (1 << 7): result.append(MissionEnums.SkyboxFlags.NO_POLYS)
	if mask & (1 << 8): result.append(MissionEnums.SkyboxFlags.NO_LIGHTING)
	if mask & (1 << 9): result.append(MissionEnums.SkyboxFlags.NO_TEXTURING)
	if mask & (1 << 10): result.append(MissionEnums.SkyboxFlags.NO_CORRECT)
	if mask & (1 << 11): result.append(MissionEnums.SkyboxFlags.NO_SMOOTHING)
	if mask & (1 << 12): result.append(MissionEnums.SkyboxFlags.IS_ASTEROID)
	if mask & (1 << 13): result.append(MissionEnums.SkyboxFlags.IS_MISSILE)
	if mask & (1 << 14): result.append(MissionEnums.SkyboxFlags.SHOW_OUTLINE_PRESET)
	if mask & (1 << 15): result.append(MissionEnums.SkyboxFlags.SHOW_INVISIBLE_FACES)
	if mask & (1 << 16): result.append(MissionEnums.SkyboxFlags.AUTOCENTER)
	if mask & (1 << 17): result.append(MissionEnums.SkyboxFlags.BAY_PATHS)
	if mask & (1 << 18): result.append(MissionEnums.SkyboxFlags.ALL_XPARENT)
	if mask & (1 << 19): result.append(MissionEnums.SkyboxFlags.NO_ZBUFFER)
	if mask & (1 << 20): result.append(MissionEnums.SkyboxFlags.NO_CULL)
	if mask & (1 << 21): result.append(MissionEnums.SkyboxFlags.FORCE_TEXTURE)
	if mask & (1 << 22): result.append(MissionEnums.SkyboxFlags.FORCE_LOWER_DETAIL)
	if mask & (1 << 23): result.append(MissionEnums.SkyboxFlags.EDGE_ALPHA)
	if mask & (1 << 24): result.append(MissionEnums.SkyboxFlags.CENTER_ALPHA)
	if mask & (1 << 25): result.append(MissionEnums.SkyboxFlags.NO_FOGGING)
	if mask & (1 << 26): result.append(MissionEnums.SkyboxFlags.SHOW_OUTLINE_HTL)
	return result

func _find_persona_message(message_name: String, persona_name: String) -> Resource:
	# This requires finding the Persona resource first.
	# We don't have a direct link to all personas here.
	# But we can try to load the persona resource by name if we follow a convention.
	# Persona resources are likely in `res://assets/personas/` or similar?
	# User pointed to `target/scripts/resources/persona/persona_resource.gd`.
	# We need to find where instances are.
	# Let's assume `res://assets/personas/<persona_name>.tres`
	var persona_res = _load_asset(persona_name + ".tres")
	if persona_res and persona_res.has_method("get") and persona_res.get("messages") is Dictionary:
		var messages = persona_res.messages
		if messages.has(message_name):
			return messages[message_name]
	return null


func _strip_xstr(text: String) -> String:
	if text.begins_with("XSTR(\""):
		var end_quote = text.rfind("\",")
		if end_quote != -1:
			return text.substr(6, end_quote - 6)
		# Handle case where it might just be XSTR("text", -1)
		end_quote = text.rfind("\"")
		if end_quote > 6:
			return text.substr(6, end_quote - 6)
	return text.replace("\"", "")


func _find_resource_in_dir(dir_path: String, filename: String) -> Resource:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					var res = _find_resource_in_dir(dir_path + "/" + file_name, filename)
					if res: return res
			elif file_name == filename:
				return load(dir_path + "/" + file_name)
			file_name = dir.get_next()
	return null


func _map_ship_flag(name: String) -> MissionEnums.ShipFlags:
	match name:
		"cargo-known": return MissionEnums.ShipFlags.CARGO_KNOWN
		"ignore-count": return MissionEnums.ShipFlags.IGNORE_COUNT
		"protect-ship": return MissionEnums.ShipFlags.PROTECT_SHIP
		"reinforcement": return MissionEnums.ShipFlags.REINFORCEMENT
		"no-shields": return MissionEnums.ShipFlags.NO_SHIELDS
		"escort": return MissionEnums.ShipFlags.ESCORT
		"player-start": return MissionEnums.ShipFlags.PLAYER_START
		"no-arrival-music": return MissionEnums.ShipFlags.NO_ARRIVAL_MUSIC
		"no-arrival-warp": return MissionEnums.ShipFlags.NO_ARRIVAL_WARP
		"no-departure-warp": return MissionEnums.ShipFlags.NO_DEPARTURE_WARP
		"locked": return MissionEnums.ShipFlags.LOCKED
		"invulnerable": return MissionEnums.ShipFlags.INVULNERABLE
		"hidden-from-sensors": return MissionEnums.ShipFlags.HIDDEN_FROM_SENSORS
		"scannable": return MissionEnums.ShipFlags.SCANNABLE
		"kamikaze": return MissionEnums.ShipFlags.KAMIKAZE
		"no-dynamic": return MissionEnums.ShipFlags.NO_DYNAMIC
		"red-alert-carry": return MissionEnums.ShipFlags.RED_ALERT_CARRY
		"beam-protect-ship": return MissionEnums.ShipFlags.BEAM_PROTECT_SHIP
		"guardian": return MissionEnums.ShipFlags.GUARDIAN
		"special-warp": return MissionEnums.ShipFlags.SPECIAL_WARP
		"vaporize": return MissionEnums.ShipFlags.VAPORIZE
		"stealth": return MissionEnums.ShipFlags.STEALTH
		"friendly-stealth-invisible": return MissionEnums.ShipFlags.FRIENDLY_STEALTH_INVISIBLE
		"don't-collide-invisible": return MissionEnums.ShipFlags.DONT_COLLIDE_INVISIBLE
		_: return MissionEnums.ShipFlags.UNKNOWN

func _map_ship_flag2(name: String) -> MissionEnums.ShipFlags2:
	match name:
		"primitive-sensors": return MissionEnums.ShipFlags2.PRIMITIVE_SENSORS
		"no-subspace-drive": return MissionEnums.ShipFlags2.NO_SUBSPACE_DRIVE
		"nav-carry-status": return MissionEnums.ShipFlags2.NAV_CARRY_STATUS
		"affected-by-gravity": return MissionEnums.ShipFlags2.AFFECTED_BY_GRAVITY
		"toggle-subsystem-scanning": return MissionEnums.ShipFlags2.TOGGLE_SUBSYSTEM_SCANNING
		"targetable-as-bomb": return MissionEnums.ShipFlags2.TARGETABLE_AS_BOMB
		"no-builtin-messages": return MissionEnums.ShipFlags2.NO_BUILTIN_MESSAGES
		"primaries-locked": return MissionEnums.ShipFlags2.PRIMARIES_LOCKED
		"secondaries-locked": return MissionEnums.ShipFlags2.SECONDARIES_LOCKED
		"no-death-scream": return MissionEnums.ShipFlags2.NO_DEATH_SCREAM
		"always-death-scream": return MissionEnums.ShipFlags2.ALWAYS_DEATH_SCREAM
		"nav-needslink": return MissionEnums.ShipFlags2.NAV_NEEDSLINK
		"hide-ship-name": return MissionEnums.ShipFlags2.HIDE_SHIP_NAME
		"set-class-dynamically": return MissionEnums.ShipFlags2.SET_CLASS_DYNAMICALLY
		"lock-all-turrets": return MissionEnums.ShipFlags2.LOCK_ALL_TURRETS
		"afterburners-locked": return MissionEnums.ShipFlags2.AFTERBURNERS_LOCKED
		"force-shields-on": return MissionEnums.ShipFlags2.FORCE_SHIELDS_ON
		"hide-log-entries": return MissionEnums.ShipFlags2.HIDE_LOG_ENTRIES
		"no-arrival-log": return MissionEnums.ShipFlags2.NO_ARRIVAL_LOG
		"no-departure-log": return MissionEnums.ShipFlags2.NO_DEPARTURE_LOG
		"is_harmless": return MissionEnums.ShipFlags2.IS_HARMLESS
		_: return MissionEnums.ShipFlags2.UNKNOWN
