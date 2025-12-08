class_name PersonaGenerator
extends RefCounted

const PersonaResource = preload("res://scripts/resources/persona/persona_resource.gd")

# Asset paths
# We use globalized paths for source to ensure we can find them outside the project if needed,
# but here they are in the project source_assets folder.
const SOURCE_SOUNDS_DIR = "res://../source_assets/wcs_hermes_campaign/hermes_sounds"
const SOURCE_MOVIES_DIR = "res://../source_assets/wcs_hermes_campaign/hermes_movies" # Assumption


func generate(persona: PersonaResource, output_root: String, source_root: String) -> void:
	# Target: target/campaigns/hermes/persona/<PersonaName>/
	var persona_slug = persona.persona_name
	var target_dir = output_root.path_join(persona_slug)

	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)

	# Process messages and assets
	for msg_name in persona.messages:
		var msg = persona.messages[msg_name]

		# Handle Audio (Wave)
		if not msg.wave_filename.is_empty():
			# Search in source_root/hermes_sounds (or similar)
			# We can use _find_asset with source_root
			var wave_source = _find_asset(
				msg.wave_filename, [source_root.path_join("hermes_sounds"), source_root]
			)
			if wave_source:
				# Convert to OGG
				var target_ogg_filename = msg.wave_filename.get_basename() + ".ogg"
				var target_ogg_path = target_dir.path_join(target_ogg_filename)

				var converted = _convert_asset(wave_source, target_ogg_path, "audio")

				if converted:
					# Load OGG stream using res:// path
					var res_path = target_ogg_path
					if not res_path.begins_with("res://"):
						res_path = ProjectSettings.localize_path(res_path)

					if FileAccess.file_exists(res_path):
						var stream = AudioStreamOggVorbis.load_from_file(res_path)
						if stream:
							stream.resource_path = res_path
							msg.wave_stream = stream
						else:
							print("Warning: Failed to load OGG stream: " + res_path)
					else:
						print("Warning: Converted file not found: " + res_path)
				else:
					print("Warning: Failed to convert wave to OGG: " + msg.wave_filename)
			else:
				print("Warning: Could not find wave file: " + msg.wave_filename)

		# Handle Video (AVI)
		if not msg.avi_filename.is_empty():
			var avi_source = _find_asset(
				msg.avi_filename,
				[
					source_root.path_join("hermes_movies"),
					source_root.path_join("../data/movies"),
					source_root
				]
			)
			if avi_source:
				# Convert to OGV
				var target_ogv_filename = msg.avi_filename.get_basename() + ".ogv"
				var target_ogv_path = target_dir.path_join(target_ogv_filename)

				var converted = _convert_asset(avi_source, target_ogv_path, "video")

				if converted:
					var stream = VideoStreamTheora.new()
					var res_path = target_ogv_path
					if not res_path.begins_with("res://"):
						res_path = ProjectSettings.localize_path(res_path)

					if FileAccess.file_exists(res_path):
						stream.set_file(res_path)
						stream.resource_path = res_path
						msg.avi_stream = stream
					else:
						print("Warning: Converted file not found: " + res_path)
				else:
					print("Warning: Failed to convert AVI to OGV: " + msg.avi_filename)
			else:
				print("Warning: Could not find avi file: " + msg.avi_filename)

	# Save Resource
	var resource_path = target_dir.path_join(persona_slug + ".tres")
	ResourceSaver.save(persona, resource_path)
	print("Saved persona: " + resource_path)


func _find_asset(filename: String, search_dirs: Array) -> String:
	for dir in search_dirs:
		var path = dir.path_join(filename)
		if FileAccess.file_exists(path):
			return path
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


func _convert_asset(source_path: String, target_path: String, type: String) -> bool:
	var global_source = ProjectSettings.globalize_path(source_path)
	var global_target = ProjectSettings.globalize_path(target_path)

	# uv run python -m converter convert input output --type type
	var args = [
		"run", "--directory", "..", "python", "-m", "converter", global_source, global_target, "--type", type
	]

	print("Converting " + type + ": " + global_source + " -> " + global_target)
	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
