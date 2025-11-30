class_name PersonaGenerator
extends RefCounted

const PersonaResource = preload("res://scripts/resources/persona/persona_resource.gd")

# Asset paths
# We use globalized paths for source to ensure we can find them outside the project if needed, 
# but here they are in the project source_assets folder.
const SOURCE_SOUNDS_DIR = "res://../source_assets/wcs_hermes_campaign/hermes_sounds"
const SOURCE_MOVIES_DIR = "res://../source_assets/wcs_hermes_campaign/hermes_movies" # Assumption

func generate_persona(persona: PersonaResource, output_root: String) -> void:
	# Target: target/campaigns/hermes/persona/<PersonaName>/
	var persona_slug = persona.persona_name
	var target_dir = output_root.path_join("campaigns/hermes/persona").path_join(persona_slug)
	
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
		
	# Process messages and assets
	for msg_name in persona.messages:
		var msg = persona.messages[msg_name]
		
		# Handle Audio (Wave)
		if not msg.wave_filename.is_empty():
			var wave_source = _find_asset(msg.wave_filename, [SOURCE_SOUNDS_DIR])
			if wave_source:
				# Convert to OGG for runtime loading
				var target_ogg_filename = msg.wave_filename.get_basename() + ".ogg"
				var target_ogg_path = target_dir.path_join(target_ogg_filename)
				
				# Convert if needed
				var converted = false
				if not FileAccess.file_exists(target_ogg_path):
					converted = _convert_to_ogg(wave_source, target_ogg_path)
				else:
					converted = true
					
				if converted:
					# Load OGG stream using res:// path
					# Ensure target_ogg_path is a valid res:// path
					var res_path = target_ogg_path
					if not res_path.begins_with("res://"):
						# Assuming target_ogg_path is relative to project root if not absolute
						# If it starts with "./", strip it
						if res_path.begins_with("./"):
							res_path = "res://" + res_path.substr(2)
						elif not res_path.begins_with("/"):
							res_path = "res://" + res_path
							
					var stream = AudioStreamOggVorbis.load_from_file(res_path)
					if stream:
						# Set resource_path to force ExtResource usage
						stream.resource_path = res_path
						msg.wave_stream = stream
					else:
						print("Warning: Failed to load OGG stream: " + res_path)
				else:
					print("Warning: Failed to convert wave to OGG: " + msg.wave_filename)
			else:
				print("Warning: Could not find wave file: " + msg.wave_filename)

		# Handle Video (AVI)
		if not msg.avi_filename.is_empty():
			# AVI files are often in data/movies or similar.
			var avi_source = _find_asset(msg.avi_filename, [SOURCE_MOVIES_DIR, "res://../source_assets/data/movies"])
			if avi_source:
				# Convert to OGV (Theora) for Godot
				var target_ogv_filename = msg.avi_filename.get_basename() + ".ogv"
				var target_ogv_path = target_dir.path_join(target_ogv_filename)
				
				# Convert if needed
				var converted = false
				if not FileAccess.file_exists(target_ogv_path):
					converted = _convert_to_ogv(avi_source, target_ogv_path)
				else:
					converted = true
					
				if converted:
					var stream = VideoStreamTheora.new()
					
					# Ensure target_ogv_path is a valid res:// path
					var res_path = target_ogv_path
					if not res_path.begins_with("res://"):
						if res_path.begins_with("./"):
							res_path = "res://" + res_path.substr(2)
						elif not res_path.begins_with("/"):
							res_path = "res://" + res_path
							
					stream.set_file(res_path)
					
					# Set resource path for ExtResource
					stream.resource_path = res_path
						
					msg.avi_stream = stream
						
					msg.avi_stream = stream
				else:
					print("Warning: Failed to convert AVI to OGV: " + msg.avi_filename)
			else:
				print("Warning: Could not find avi file: " + msg.avi_filename)
			
	# Save Resource
	var resource_path = target_dir.path_join(persona_slug + ".tres")
	ResourceSaver.save(persona, resource_path)
	print("Saved persona: " + resource_path)

func _find_asset(filename: String, search_dirs: Array) -> String:
	# Remove extension to search for variations? Or assume exact match?
	# TBL usually has exact filename (e.g. assassin_01.wav).
	for dir in search_dirs:
		# Try exact match
		var path = dir.path_join(filename)
		if FileAccess.file_exists(path):
			return path
			
		# Try recursive search if not found directly?
		# For now, simple search.
		
		# Also check for case sensitivity issues
		var found = _find_file_case_insensitive(dir, filename)
		if not found.is_empty():
			return dir.path_join(found)
			
	return ""

func _find_file_case_insensitive(dir_path: String, filename: String) -> String:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.to_lower() == filename.to_lower():
					return file_name
			file_name = dir.get_next()
	return ""

func _copy_file(source: String, target: String) -> void:
	var dir = DirAccess.open("res://")
	if dir:
		dir.copy(source, target)

func _convert_to_ogg(source_path: String, target_path: String) -> bool:
	var global_source = ProjectSettings.globalize_path(source_path)
	var global_target = ProjectSettings.globalize_path(target_path)
	
	# ffmpeg -i input.wav -c:a libvorbis -q:a 4 output.ogg
	# -y to overwrite
	var args = ["-i", global_source, "-c:a", "libvorbis", "-q:a", "4", "-y", global_target]
	
	print("Converting audio: " + global_source + " -> " + global_target)
	var output = []
	var exit_code = OS.execute("ffmpeg", args, output, true)
	
	if exit_code != 0:
		print("FFmpeg failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false
		
	return true

func _convert_to_ogv(source_path: String, target_path: String) -> bool:
	var global_source = ProjectSettings.globalize_path(source_path)
	var global_target = ProjectSettings.globalize_path(target_path)
	
	# ffmpeg -i input.avi -c:v libtheora -q:v 7 -c:a libvorbis -q:a 4 output.ogv
	# -y to overwrite
	var args = ["-i", global_source, "-c:v", "libtheora", "-q:v", "7", "-c:a", "libvorbis", "-q:a", "4", "-y", global_target]
	
	print("Converting video: " + global_source + " -> " + global_target)
	var output = []
	var exit_code = OS.execute("ffmpeg", args, output, true)
	
	if exit_code != 0:
		print("FFmpeg failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false
		
	return true
