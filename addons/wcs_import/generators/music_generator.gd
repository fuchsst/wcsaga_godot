class_name MusicGenerator
extends RefCounted

const SoundtrackResource = preload("res://scripts/resources/soundtrack/soundtrack_resource.gd")
const MenuMusicResource = preload("res://scripts/resources/soundtrack/menu_music_resource.gd")

func generate(parsed_data: Dictionary, output_dir: String, source_root: String) -> bool:
	var soundtracks = parsed_data.get("soundtracks", [])
	var menu_music = parsed_data.get("menu_music")

	var save_dir = output_dir
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	var saved_count = 0
	for item in soundtracks:
		# Convert assets for this soundtrack
		_convert_soundtrack_assets(item, source_root, save_dir)

		var item_name = item.name
		if item_name.is_empty():
			item_name = "unknown_" + str(saved_count)

		var filename = item_name.to_lower().replace(" ", "_").replace(".", "_") + ".tres"
		var save_path = save_dir.path_join(filename)

		var err = ResourceSaver.save(item, save_path)
		if err != OK:
			print("Failed to save resource: " + save_path)
		else:
			# print("Saved: " + save_path)
			saved_count += 1

	if menu_music:
		_convert_menu_music_assets(menu_music, source_root, save_dir)
		var menu_path = save_dir.path_join("menu_music.tres")
		var err = ResourceSaver.save(menu_music, menu_path)
		if err != OK:
			print("Failed to save menu music: " + menu_path)
		else:
			print("Saved: " + menu_path)

	print("Saved " + str(saved_count) + " soundtracks and menu music.")
	return true

func _convert_soundtrack_assets(res: Resource, source_root: String, output_dir: String) -> void:
	# Iterate over properties ending in _filename
	var props = res.get_property_list()
	for prop in props:
		if prop.name.ends_with("_filename"):
			var filename = res.get(prop.name)
			if not filename.is_empty():
				var source_file = _find_source_asset(source_root, filename, [".wav", ".ogg"])
				if not source_file.is_empty():
					_convert_asset(source_file, output_dir, "audio")

					var converted_filename = source_file.get_file().get_basename() + ".ogg"
					var converted_path = output_dir.path_join(converted_filename)

					var res_path = converted_path
					if not res_path.begins_with("res://"):
						res_path = ProjectSettings.localize_path(res_path)

					if FileAccess.file_exists(res_path):
						# Determine target property name (remove _filename)
						var target_prop = prop.name.substr(0, prop.name.length() - 9)
						res.set(target_prop, load(res_path))
					else:
						print("Warning: Converted file not found: " + res_path)
				else:
					print("Warning: Could not find source for music: " + filename)

func _convert_menu_music_assets(res: Resource, source_root: String, output_dir: String) -> void:
	var props = res.get_property_list()
	for prop in props:
		if prop.name.ends_with("_filename"):
			var filename = res.get(prop.name)
			if not filename.is_empty():
				var source_file = _find_source_asset(source_root, filename, [".wav", ".ogg"])
				if not source_file.is_empty():
					_convert_asset(source_file, output_dir, "audio")

					var converted_filename = source_file.get_file().get_basename() + ".ogg"
					var converted_path = output_dir.path_join(converted_filename)

					var res_path = converted_path
					if not res_path.begins_with("res://"):
						res_path = ProjectSettings.localize_path(res_path)

					if FileAccess.file_exists(res_path):
						var target_prop = prop.name.substr(0, prop.name.length() - 9)
						res.set(target_prop, load(res_path))
					else:
						print("Warning: Converted file not found: " + res_path)
				else:
					print("Warning: Could not find source for menu music: " + filename)

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
