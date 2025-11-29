class_name WCSCutsceneParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const CutsceneResource = preload("res://scripts/resources/cutscenes/cutscene_resource.gd")
const CutsceneManifest = preload("res://scripts/resources/cutscenes/cutscene_manifest.gd")

func _parse_content() -> Variant:
	var manifest = CutsceneManifest.new()
	var current_cutscene: CutsceneResource = null
	
	# We need to know where to copy the video files.
	# The CLI runner passes output_dir, but the parser doesn't know it directly unless we pass it.
	# However, we can assume a standard path relative to the project or use the WCSPathResolver if available.
	# But wait, the parser is running inside Godot. It can use ProjectSettings or relative paths.
	# The user said: "mentioned $Filename ogg movie in the tbl are copied to target/campaign/cutscenes/"
	# I'll assume the input file is in the source directory, and the video files are next to it.
	
	# We need the source directory of the TBL file to find the video files.
	# base_parser.gd stores `_file_path`.
	var source_dir = _file_path.get_base_dir()
	
	# Target directory for videos: res://campaigns/hermes/cutscenes/ (assuming standard structure)
	# Or we can use the output directory passed to CLI runner? 
	# The CLI runner doesn't pass output dir to parse().
	# But we can copy the file here if we know where to put it.
	# Let's assume we put it in `res://campaigns/hermes/cutscenes/` for now.
	# Ideally, the parser shouldn't do file IO (copying), but the user request implies the converter (which includes the parser logic) should do it.
	# Since I'm in GDScript, I can use DirAccess.
	
	var target_video_dir = "res://campaigns/hermes/cutscenes/"
	DirAccess.make_dir_recursive_absolute(target_video_dir)
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Filename:"):
			current_cutscene = CutsceneResource.new()
			var filename = _extract_string_value(line, "$Filename:")
			current_cutscene.filename = filename
			
			# Handle video file
			var source_video_path = source_dir.path_join(filename)
			
			# If not found in TBL directory, check sibling directories
			if not FileAccess.file_exists(source_video_path):
				var parent_dir = source_dir.get_base_dir()
				var candidates = [
					parent_dir.path_join("hermes_movies").path_join(filename),
					parent_dir.path_join("hermes_movies_prologue").path_join(filename),
					parent_dir.path_join("movies").path_join(filename),
					parent_dir.path_join("data/movies").path_join(filename)
				]
				for candidate in candidates:
					if FileAccess.file_exists(candidate):
						source_video_path = candidate
						break
			
			if FileAccess.file_exists(source_video_path):
				# Rename to .ogv for Godot compatibility if it's .ogg
				var target_filename = filename
				if filename.ends_with(".ogg"):
					target_filename = filename.get_basename() + ".ogv"
				
				var target_video_path = target_video_dir.path_join(target_filename)
				
				# Copy file
				var err = DirAccess.copy_absolute(source_video_path, target_video_path)
				if err == OK:
					# Create VideoStreamTheora
					var video_stream = VideoStreamTheora.new()
					video_stream.file = target_video_path
					current_cutscene.video_stream = video_stream
				else:
					print("Error copying video file: " + source_video_path)
			else:
				print("Warning: Video file not found: " + source_video_path)
			
			# Add to manifest using filename without extension as key
			var key = filename.get_basename()
			manifest.cutscenes[key] = current_cutscene
			
		elif current_cutscene:
			if line.begins_with("$Name:"):
				current_cutscene.name = _extract_string_value(line, "$Name:")
			elif line.begins_with("$Description:"):
				# Handle multiline description
				var desc = ""
				# Check if there's text on the same line
				var same_line_desc = _extract_string_value(line, "$Description:")
				if not same_line_desc.is_empty():
					desc = same_line_desc
				
				# Read following lines until $end_multi_text or next field
				while _has_more_lines():
					var next_line = _peek_next_line()
					if next_line.begins_with("$"):
						if next_line == "$end_multi_text":
							_get_next_line() # Consume
							break
						# If it's another field, stop (unless it's part of description?)
						# Usually description ends with $end_multi_text
						if not next_line.begins_with("XSTR"):
							break
					
					var desc_line = _get_next_line()
					
					# Handle XSTR
					if desc_line.contains("XSTR"):
						# Extract text from XSTR("Text", -1)
						var start = desc_line.find('"')
						var end = desc_line.rfind('"')
						if start != -1 and end != -1 and end > start:
							desc_line = desc_line.substr(start + 1, end - start - 1)
					
					if not desc.is_empty():
						desc += "\n"
					desc += desc_line
				
				current_cutscene.description = desc
				
	return manifest
