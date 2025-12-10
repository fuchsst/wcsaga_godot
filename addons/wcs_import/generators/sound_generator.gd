class_name SoundGenerator
extends RefCounted

const SoundManifest = preload("res://scripts/resources/sounds/sound_manifest.gd")
const AudioConfigResource = preload("res://scripts/resources/sounds/audio_config_resource.gd")


func generate(manifest: SoundManifest, output_dir: String, source_root: String) -> bool:
	var save_dir = output_dir
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	# Convert assets
	for config in manifest.audio_configs:
		if not _convert_audio_config(config, source_root, save_dir):
			return false

	for flyby in manifest.flyby_sounds:
		if not _convert_audio_config(flyby, source_root, save_dir):
			return false

	var save_path = save_dir.path_join("sounds.tres")
	var err = ResourceSaver.save(manifest, save_path)
	if err != OK:
		print("Failed to save sounds manifest: " + save_path)
		return false

	print("Saved sounds manifest to: " + save_path)
	return true


func _convert_audio_config(config: Resource, source_root: String, output_dir: String) -> bool:
	var filename = config.filename
	if filename.is_empty():
		return true

	var search_name = filename.get_basename()
	var source_file = _find_source_asset(source_root, search_name, [".wav", ".ogg"])

	if source_file.is_empty():
		push_warning("Warning: Could not find source for sound: " + filename)
		return true # Continue with other sounds

	if not _convert_asset(source_file, output_dir, "audio"):
		push_warning("Warning: Failed to convert sound asset: " + source_file)
		return true # Continue with other sounds

	var converted_filename = source_file.get_file().get_basename() + ".ogg"
	var converted_path = output_dir.path_join(converted_filename)

	var res_path = converted_path
	if not res_path.begins_with("res://"):
		res_path = ProjectSettings.localize_path(res_path)

	if not FileAccess.file_exists(converted_path):
		push_warning("Warning: Converted file not found: " + converted_path)
		return true

	# Store the path for lazy loading (headless mode can't load resources immediately)
	config.audio_path = res_path

	# Try to load immediately (will work in non-headless mode)
	var stream = load(res_path)
	if stream:
		config.audio_stream = stream
	# If load fails (headless mode), audio_path is still set for runtime loading

	return true


func _find_source_asset(root_path: String, filename: String, extensions: Array = []) -> String:
	var found = _find_file_recursive(root_path, filename)
	if found.is_empty() and not extensions.is_empty():
		# Try with extensions
		var basename = filename.get_basename()
		for ext in extensions:
			found = _find_file_recursive(root_path, basename + ext)
			if not found.is_empty():
				break
	return found


func _find_file_recursive(dir_path: String, filename: String) -> String:
	if not DirAccess.dir_exists_absolute(dir_path):
		return ""

	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					var sub_path = dir_path.path_join(file_name)
					var found = _find_file_recursive(sub_path, filename)
					if not found.is_empty():
						return found
			else:
				if file_name.to_lower() == filename.to_lower():
					return dir_path.path_join(file_name)
			file_name = dir.get_next()
	return ""


func _convert_asset(source_path: String, target_dir: String, type: String) -> bool:
	var global_source = ProjectSettings.globalize_path(source_path)
	var global_target = ProjectSettings.globalize_path(target_dir)

	# uv run python -m converter convert input output --type type
	var args = [
		"run", "--directory", "..", "python", "-m", "converter", global_source, global_target, "--type", type
	]

	# print("Converting " + type + ": " + global_source + " -> " + global_target)
	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
