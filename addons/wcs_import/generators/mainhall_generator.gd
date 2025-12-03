class_name MainhallGenerator
extends RefCounted


func generate(mainhall: Resource, output_dir: String, source_root: String) -> bool:
	DirAccess.make_dir_recursive_absolute(output_dir)

	# 1. Background Bitmap
	if not mainhall.bitmap.is_empty():
		var source = _find_source_asset(source_root, mainhall.bitmap, [".pcx", ".dds", ".png"])
		if not source.is_empty():
			_convert_asset(source, output_dir, "texture")
			# Update resource path? MainhallResource uses String for bitmap currently?
			# Parser extracts string. We should probably update it to be a path or load it.
			# But MainhallResource definition might be simple.
			# Let's assume we just ensure the asset exists in the output dir.
		else:
			print("Warning: Mainhall bitmap not found: " + mainhall.bitmap)

	# 2. Music
	if not mainhall.music.is_empty():
		var source = _find_source_asset(source_root, mainhall.music, [".wav", ".ogg"])
		if not source.is_empty():
			_convert_asset(source, output_dir, "audio")
		else:
			print("Warning: Mainhall music not found: " + mainhall.music)

	# 3. Door Icons
	for door in mainhall.doors:
		if not door.icon.is_empty():
			var source = _find_source_asset(
				source_root, door.icon, [".pcx", ".dds", ".png", ".ani"]
			)
			if not source.is_empty():
				var type = "texture"
				if source.ends_with(".ani"):
					type = "animation"
				_convert_asset(source, output_dir, type)
			else:
				print("Warning: Mainhall door icon not found: " + door.icon)

	# Save Resource
	var save_path = output_dir.path_join("mainhall.tres")
	var err = ResourceSaver.save(mainhall, save_path)
	if err != OK:
		print("Failed to save mainhall resource: " + save_path)
		return false

	print("Saved mainhall: " + save_path)
	return true


func _find_source_asset(root_path: String, filename: String, extensions: Array = []) -> String:
	var found = _find_file_recursive(root_path, filename)
	if found.is_empty() and not extensions.is_empty():
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

	var args = [
		"run", "--directory", "..", "python", "-m", "converter", global_source, global_target, "--type", type
	]

	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
