class_name AnimationGenerator
extends RefCounted

func generate(input_path: String, output_dir: String, source_root: String) -> bool:
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	var filename = input_path.get_file()
	var source_file = _find_source_asset(source_root, filename)

	if source_file.is_empty():
		# Try with extensions if input path doesn't have one or if not found
		var base = filename.get_basename()
		source_file = _find_source_asset(source_root, base, [".eff", ".ani"])

	if not source_file.is_empty():
		# Convert asset
		if _convert_asset(source_file, output_dir, "animation"):
			print("Converted animation: " + source_file)
			return true
		else:
			push_error("Error: Failed to convert animation: " + source_file)
			return false
	else:
		push_error("Error: Could not find source for animation: " + input_path)
		return false


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

	# uv run python -m converter convert input output --type type
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
