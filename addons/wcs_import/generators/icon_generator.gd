class_name IconGenerator
extends RefCounted

func generate(icons: Array, output_dir: String, source_root: String) -> bool:
	print("Processing " + str(icons.size()) + " icons...")

	var save_dir = output_dir
	DirAccess.make_dir_recursive_absolute(save_dir)
	DirAccess.make_dir_recursive_absolute(save_dir)

	var saved_count = 0
	for icon in icons:
		# Use name as filename if filename is empty (common in icons.tbl)
		var search_filename = icon.filename
		if search_filename.is_empty():
			search_filename = icon.name

		# Convert image if present
		if not search_filename.is_empty():
			var source_file = _find_source_asset(source_root, search_filename, [".pcx", ".dds", ".png", ".ani"])
			if not source_file.is_empty():
				var type = "texture"
				if source_file.ends_with(".ani"):
					type = "animation"

				_convert_asset(source_file, save_dir, type)
				saved_count += 1
			else:
				print("Warning: Could not find source image for icon: " + search_filename)

	print("Converted assets for " + str(saved_count) + "/" + str(icons.size()) + " icons.")
	return true

func _resolve_output_path(base_output_dir: String, subpath: String) -> String:
	# If subpath starts with "assets/" and base_output_dir ends with "assets", strip it
	if subpath.begins_with("assets/") and base_output_dir.ends_with("assets"):
		return base_output_dir.path_join(subpath.substr(7))
	return base_output_dir.path_join(subpath)

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

	var args = ["run", "python", "-m", "converter", "convert", global_source, global_target, "--type", type]

	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
