class_name BaseSectionParser
extends RefCounted

## Base class for mission section parsers
## Provides common utilities for parsing FS2 mission sections

var _base_parser: RefCounted # Reference to WCSBaseParser for utility functions


func _init(base_parser: RefCounted):
	_base_parser = base_parser


## Parse a section and update the manifest
## Returns the new line index after parsing
func parse_section(start_index: int, manifest: Resource) -> int:
	push_error("parse_section must be implemented by subclass")
	return start_index


## Helper: Check if we have more lines to parse
func _has_more_lines() -> bool:
	return _base_parser._has_more_lines()


## Helper: Get next line and advance index
func _get_next_line() -> String:
	return _base_parser._get_next_line()


## Helper: Peek at next line without advancing
func _peek_next_line() -> String:
	return _base_parser._peek_next_line()


## Helper: Get current line without advancing
func _get_current_line() -> String:
	return _base_parser._get_current_line()


## Helper: Extract string value after prefix
func _extract_string_value(line: String, prefix: String) -> String:
	return _base_parser._extract_string_value(line, prefix)


## Helper: Extract int value after prefix
func _extract_int_value(line: String, prefix: String) -> int:
	return _base_parser._extract_int_value(line, prefix)


## Helper: Extract float value after prefix
func _extract_float_value(line: String, prefix: String) -> float:
	return _base_parser._extract_float_value(line, prefix)


## Helper: Extract boolean value
func _extract_boolean_value(line: String, prefix: String) -> bool:
	return _base_parser._extract_boolean_value(line, prefix)


## Helper: Parse Vector3 from string
func _parse_vector3(text: String) -> Vector3:
	return _base_parser._parse_vector3(text)


## Helper: Parse list of values (comma or space separated)
func _extract_list_value(line: String) -> Array[String]:
	var result: Array[String] = []
	var value_part = line.substr(line.find(":") + 1).strip_edges()
	
	# Handle parentheses list format
	if value_part.begins_with("("):
		value_part = value_part.trim_prefix("(").trim_suffix(")").strip_edges()
	
	# Split by commas or spaces
	var items = value_part.split(",") if "," in value_part else value_part.split(" ")
	for item in items:
		var cleaned = item.strip_edges()
		if not cleaned.is_empty():
			result.append(cleaned)
	
	return result


## Skip to next section (when current section ends)
func _skip_to_next_section():
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("#"):
			break
		_get_next_line()


## Load ship resource with strict validation
func _load_ship_resource(ship_class_name: String) -> Resource:
	if ship_class_name.is_empty():
		push_error("Ship class name is empty")
		return null
	
	# Clean up the name
	var clean_name = ship_class_name.split(";")[0].strip_edges()
	
	# Try to find in ships directory
	var path = "res://assets/ships/" + clean_name.to_lower() + ".tres"
	if FileAccess.file_exists(path):
		return ResourceLoader.load(path)
	
	# Try campaigns/hermes/ships
	path = "res://campaigns/hermes/ships/" + clean_name + ".tres"
	if FileAccess.file_exists(path):
		return ResourceLoader.load(path)
	
	# FAIL EARLY - No fallback!
	push_error("FATAL: Ship resource not found: '" + clean_name + "' (Expected at res://assets/ships/ or res://campaigns/hermes/ships/)")
	return null


## Load AI class resource with strict validation
func _load_ai_class_resource(ai_class_name: String) -> Resource:
	if ai_class_name.is_empty():
		return null # AI class is optional
	
	var clean_name = ai_class_name.strip_edges()
	var path = "res://campaigns/hermes/ai_classes/" + clean_name + ".tres"
	
	if FileAccess.file_exists(path):
		return ResourceLoader.load(path)
	
	# FAIL EARLY - No fallback!
	push_error("FATAL: AI class resource not found: '" + clean_name + "' at " + path)
	return null


## Load audio stream with strict validation
func _load_audio_stream(filename: String) -> AudioStream:
	if filename.is_empty() or filename == "none" or filename == "none.wav":
		return null # No audio is valid
	
	var base = filename.get_basename()
	var extensions = [".ogg", ".wav", ".mp3"]
	
	# Search order: campaign soundtrack, then assets/sounds
	var search_dirs = [
		"res://campaigns/hermes/soundtrack/",
		"res://assets/sounds/"
	]
	
	for dir in search_dirs:
		for ext in extensions:
			var path = dir + base + ext
			if FileAccess.file_exists(path):
				var resource = ResourceLoader.load(path) as AudioStream
				if resource:
					return resource
	
	# FAIL EARLY - No fallback!
	push_error("FATAL: Audio resource not found: '" + filename + "' (Searched in campaigns/hermes/soundtrack/ and assets/sounds/)")
	return null


## Load video stream with strict validation  
func _load_video_stream(filename: String) -> VideoStream:
	if filename.is_empty() or filename == "none":
		return null
	
	var base = filename.get_basename()
	var extensions = [".ogv", ".ogg"] # OGV is Theora video
	
	# Videos are in campaign cutscenes folder
	var search_dirs = ["res://campaigns/hermes/cutscenes/"]
	
	for dir in search_dirs:
		for ext in extensions:
			var path = dir + base + ext
			if FileAccess.file_exists(path):
				var resource = ResourceLoader.load(path) as VideoStream
				if resource:
					return resource
	
	# FAIL EARLY - No fallback!
	push_error("FATAL: Video resource not found: '" + filename + "' (Searched in campaigns/hermes/cutscenes/)")
	return null


## Load texture with strict validation
func _load_texture(filename: String) -> Texture2D:
	if filename.is_empty():
		return null
	
	var base = filename.get_basename()
	var extensions = [".png", ".jpg", ".webp"]
	
	# Textures could be in various places depending on type
	var search_dirs = [
		"res://assets/environment/",
		"res://assets/effects/",
		"res://campaigns/hermes/ui/",
		"res://assets/ships/"
	]
	
	for dir in search_dirs:
		for ext in extensions:
			var path = dir + base + ext
			if FileAccess.file_exists(path):
				var resource = ResourceLoader.load(path) as Texture2D
				if resource:
					return resource
	
	# FAIL EARLY - No fallback!
	push_error("FATAL: Texture resource not found: '" + filename + "' (Searched in assets/environment/, assets/effects/, campaigns/hermes/ui/, assets/ships/)")
	return null
