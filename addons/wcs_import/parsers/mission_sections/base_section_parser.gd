class_name BaseSectionParser
extends RefCounted

## Base class for mission section parsers
## Provides common utilities for parsing FS2 mission sections

var _base_parser: RefCounted # Reference to WCSBaseParser for utility functions
var _mission_dir: String = "" # Mission directory for asset placement (set by MissionParser)


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


## Helper: Extract multiline string
func _extract_multiline_string(first_line: String, prefix: String) -> String:
	if _base_parser.has_method("_extract_multiline_string"):
		return _base_parser.call("_extract_multiline_string", first_line, prefix)
	return _base_parser.call("_extract_string_value", first_line, prefix) # Fallback


## Helper: Extract SEXP formula
func _extract_sexp_formula(line: String, prefix: String) -> String:
	if _base_parser.has_method("_extract_sexp_formula"):
		return _base_parser.call("_extract_sexp_formula", line, prefix)
	return ""


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


# Static cache for file lookups to avoid repeated recursive directory walking
static var _dir_file_cache: Dictionary = {}

## Helper: Get all files in directory recursively (cached)
static func _get_files_in_dir_recursive(root_dir: String) -> Dictionary:
	if _dir_file_cache.has(root_dir):
		return _dir_file_cache[root_dir]
	
	var files = {}
	var dir = DirAccess.open(root_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					var sub_files = _get_files_in_dir_recursive(root_dir.path_join(file_name))
					files.merge(sub_files)
			else:
				# Store lower case filename -> full path
				files[file_name.to_lower()] = root_dir.path_join(file_name)
			file_name = dir.get_next()
	
	_dir_file_cache[root_dir] = files
	return files


## Helper: Find file in directories (recursive)
func _find_resource_path(filename: String, search_dirs: Array[String]) -> String:
	var lower_name = filename.to_lower()
	
	for dir in search_dirs:
		var cache = _get_files_in_dir_recursive(dir)
		if cache.has(lower_name):
			return cache[lower_name]
			
	return ""


## Load ship resource with strict validation
func _load_ship_resource(ship_class_name: String) -> Resource:
	if ship_class_name.is_empty():
		return null
	
	# Clean up the name
	var clean_name = ship_class_name.split(";")[0].strip_edges()
	var target_filename = clean_name.replace(" ", "_").replace("-", "_").to_lower() + ".tres"
	
	var search_dirs: Array[String] = [
		"res://assets/ships/"
	]
	
	var path = _find_resource_path(target_filename, search_dirs)
	if not path.is_empty():
		return ResourceLoader.load(path)
	
	# Fallback: try exact name match if snake_case failed
	path = _find_resource_path(clean_name.to_lower() + ".tres", search_dirs)
	if not path.is_empty():
		return ResourceLoader.load(path)
	
	# FAIL EARLY - No fallback!
	push_warning("WARNING: Ship resource not found: '" + clean_name + "' (Searched in assets/ships/ and campaigns/hermes/ships/)")
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
func _load_audio_stream(filename: String, context: String = "sound") -> AudioStream:
	if filename.is_empty() or filename == "none" or filename == "none.wav":
		return null # No audio is valid
	
	var base = filename.get_basename()
	var extensions = [".ogg", ".wav", ".mp3"]
	
	# Determine target directory based on context using WCSPathResolver
	var target_dir = WCSPathResolver.determine_mission_asset_path(filename, context, _mission_dir)
	
	# First try resolving from source map if available
	var source_path = WCSPathResolver.resolve_source_path(filename)
	if not source_path.is_empty():
		# Check if we need to copy it
		var target_path = target_dir.path_join(filename)
		
		# Use absolute path to verify physical existence (bypass Godot cache)
		var abs_target_path = ProjectSettings.globalize_path(target_path)
		
		if not FileAccess.file_exists(abs_target_path):
			var abs_source = source_path
			
			if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target_dir)):
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
				
			var err = DirAccess.copy_absolute(abs_source, abs_target_path)
			if err != OK:
				push_error("Failed to copy audio: " + str(err))
			else:
				# Clear cache so _find_resource_path can see the new file
				_dir_file_cache.clear()
	
	# Search order: target_dir, then campaign soundtrack, then assets/sounds
	var search_dirs: Array[String] = [
		target_dir,
		"res://campaigns/hermes/soundtrack/",
		"res://assets/sounds/"
	]
	
	for ext in extensions:
		var target_filename = base + ext
		var path = _find_resource_path(target_filename, search_dirs)
		if not path.is_empty():
			# Try to load the resource (works if already imported)
			var resource = ResourceLoader.load(path) as AudioStream
			if resource:
				return resource
			
			# If not imported yet, copy .ogg to target directory
			# Godot will import it when project is opened in editor
			if FileAccess.file_exists(path) and path.ends_with(".ogg"):
				# Copy .ogg file to target directory (mission folder)
				var ogg_target_path = target_dir.path_join(target_filename)
				var abs_ogg_target = ProjectSettings.globalize_path(ogg_target_path)
				
				if not FileAccess.file_exists(abs_ogg_target):
					var abs_source = ProjectSettings.globalize_path(path)
					# Ensure target directory exists
					if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target_dir)):
						DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
					
					var err = DirAccess.copy_absolute(abs_source, abs_ogg_target)
					if err != OK:
						push_warning("Failed to copy .ogg file: " + abs_source + " to " + abs_ogg_target)
						continue
					# Clear cache after copying
					_dir_file_cache.clear()
					
					# TRIGGER IMPORT: Force Godot to recognize the new file
					# In headless mode, we need to ensure the importer runs
					# We can try to append the .import extension to check if it exists, or just load it
					# Using ResourceLoader with CACHE_MODE_IGNORE might force a re-check
					var _temp = ResourceLoader.load(ogg_target_path, "", ResourceLoader.CACHE_MODE_IGNORE)
				
				# Try to load from the new location
				# This will create an ExtResource reference when saving
				var resource_from_target = ResourceLoader.load(ogg_target_path) as AudioStream
				if resource_from_target:
					return resource_from_target
				else:
					# If standard load fails, try one more time with cache ignore
					resource_from_target = ResourceLoader.load(ogg_target_path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
					if resource_from_target:
						return resource_from_target
						
					# File copied but not imported yet - this is expected in headless mode if auto-import doesn't trigger
					# However, we need to return the path so it can be referenced
					# We can return a placeholder or just the path string if the caller supports it?
					# The caller expects AudioStream.
					# If we return null, the field is empty.
					# We really need that import to happen.
					push_warning("Audio file copied but import failed (headless mode limitation?): " + ogg_target_path)
					return null
	
	# FAIL EARLY - No fallback!
	push_warning("WARNING: Audio resource not found: '" + filename + "' (Searched in campaigns/hermes/soundtrack/ and assets/sounds/)")
	return null


## Load video stream with strict validation  
func _load_video_stream(filename: String, context: String = "cutscene") -> VideoStream:
	if filename.is_empty() or filename == "none":
		return null
	
	var base = filename.get_basename()
	var extensions = [".ogv", ".ogg"] # OGV is Theora video
	
	# Determine target directory based on context using WCSPathResolver
	var target_dir = WCSPathResolver.determine_mission_asset_path(filename, context, _mission_dir)
	
	# First try resolving from source map
	var source_path = WCSPathResolver.resolve_source_path(filename)
	if not source_path.is_empty():
		# Check if we need to copy it
		var target_path = target_dir.path_join(filename)
		
		# Use absolute path to verify physical existence
		var abs_target_path = ProjectSettings.globalize_path(target_path)
		
		if not FileAccess.file_exists(abs_target_path):
			var abs_source = source_path
			
			if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target_dir)):
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
				
			var err = DirAccess.copy_absolute(abs_source, abs_target_path)
			if err != OK:
				push_error("Failed to copy video: " + str(err))
			else:
				_dir_file_cache.clear()

	# Videos are in campaign cutscenes folder
	var search_dirs = [target_dir, "res://campaigns/hermes/cutscenes/"]
	
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


## Helper: Parse quoted list: ( "item1" "item2" )
func _parse_quoted_list(line: String, prefix: String) -> Array[String]:
	var result: Array[String] = []
	var list_part = line.substr(prefix.length()).strip_edges()
	
	# Remove parentheses
	list_part = list_part.trim_prefix("(").trim_suffix(")").strip_edges()
	
	# Parse quoted items
	var in_quote = false
	var current_item = ""
	
	for i in range(list_part.length()):
		var c = list_part[i]
		if c == '"':
			if in_quote:
				# End of quoted string
				if not current_item.is_empty():
					result.append(current_item)
					current_item = ""
				in_quote = false
			else:
				# Start of quoted string
				in_quote = true
		elif in_quote:
			current_item += c
	
	return result


## Helper: Extract multiline text until one of the terminators is found
func _extract_multiline_until(terminators: Array[String]) -> String:
	var text = ""
	while _has_more_lines():
		var line = _peek_next_line()
		
		var found_terminator = false
		for term in terminators:
			if line.begins_with(term) or line.begins_with("#"):
				found_terminator = true
				break
		
		if found_terminator:
			break
			
		text += _get_next_line() + "\n"
	
	return text.strip_edges()


## Helper: Clean XSTR wrappers
func _clean_xstr(text: String) -> String:
	var s = text.strip_edges()
	
	if s.begins_with("XSTR"):
		var first_quote = s.find("\"")
		var last_quote = s.rfind("\",")
		if last_quote == -1:
			last_quote = s.rfind("\"")
		
		if first_quote != -1 and last_quote > first_quote:
			var second_quote = s.find("\"", first_quote + 1)
			if second_quote != -1:
				return s.substr(first_quote + 1, second_quote - first_quote - 1)
	
	if s.begins_with("\"") and s.ends_with("\""):
		s = s.substr(1, s.length() - 2)
	
	return s


## Map arrival location string to enum
func _map_arrival_location(name: String) -> MissionEnums.ArrivalLocation:
	var lower = name.to_lower()
	if lower == "hyperspace":
		return MissionEnums.ArrivalLocation.HYPERSPACE
	elif lower.begins_with("near ship"):
		return MissionEnums.ArrivalLocation.NEAR_SHIP
	elif lower.begins_with("in front of ship"):
		return MissionEnums.ArrivalLocation.IN_FRONT_OF_SHIP
	elif lower.begins_with("docking bay"):
		return MissionEnums.ArrivalLocation.DOCKING_BAY
	return MissionEnums.ArrivalLocation.HYPERSPACE


## Map departure location string to enum
func _map_departure_location(name: String) -> MissionEnums.DepartureLocation:
	var lower = name.to_lower()
	if lower == "hyperspace":
		return MissionEnums.DepartureLocation.HYPERSPACE
	elif lower.begins_with("docking bay"):
		return MissionEnums.DepartureLocation.DOCKING_BAY
	return MissionEnums.DepartureLocation.HYPERSPACE


## Map team string to enum
func _map_team(name: String) -> MissionEnums.Team:
	match name.to_lower():
		"friendly": return MissionEnums.Team.FRIENDLY
		"hostile": return MissionEnums.Team.HOSTILE
		"neutral": return MissionEnums.Team.NEUTRAL
		"unknown": return MissionEnums.Team.UNKNOWN
		"traitor": return MissionEnums.Team.TRAITOR
		_: return MissionEnums.Team.UNKNOWN
