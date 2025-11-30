class_name NebulaGenerator
extends RefCounted

func generate(assets: Resource, output_dir: String, source_root: String) -> bool:
	DirAccess.make_dir_recursive_absolute(output_dir)

	# Process background bitmaps
	for bitmap_name in assets.backgrounds.keys():
		var source = _find_source_asset(source_root, bitmap_name, [".pcx", ".dds", ".png", ".tga"])
		if not source.is_empty():
			_convert_asset(source, output_dir, "texture")
			var texture_path = output_dir.path_join(source.get_file().get_basename() + ".png")
			# Use PlaceholderTexture2D to create a reference to the file
			# This ensures ResourceSaver writes ExtResource("path") even if the file isn't imported yet
			var texture = PlaceholderTexture2D.new()
			# Ensure path is res://
			var res_path = texture_path
			if not res_path.begins_with("res://"):
				# Assuming running from project root, relative paths are res://
				# Strip ./ if present
				res_path = res_path.replace("./", "")
				# If it doesn't start with res://, prepend it
				if not res_path.begins_with("res://"):
					res_path = "res://" + res_path.lstrip("/")

			texture.resource_path = res_path
			assets.backgrounds[bitmap_name] = texture
		else:
			print("Source not found for: " + bitmap_name)

	# Process poof bitmaps
	for poof_name in assets.poofs.keys():
		var source = _find_source_asset(source_root, poof_name, [".pcx", ".dds", ".png", ".tga"])
		if not source.is_empty():
			_convert_asset(source, output_dir, "texture")
			var texture_path = output_dir.path_join(source.get_file().get_basename() + ".png")

			var texture = PlaceholderTexture2D.new()
			var res_path = texture_path
			if not res_path.begins_with("res://"):
				res_path = res_path.replace("./", "")
				if not res_path.begins_with("res://"):
					res_path = "res://" + res_path.lstrip("/")

			texture.resource_path = res_path
			assets.poofs[poof_name] = texture
		else:
			print("Source not found for: " + poof_name)

	var save_path = output_dir.path_join("nebula.tres")
	var err = ResourceSaver.save(assets, save_path)
	if err != OK:
		print("Failed to save resource: " + save_path)
		return false

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

	var args = ["run", "python", "-m", "converter", "convert", global_source, global_target, "--type", type]

	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
