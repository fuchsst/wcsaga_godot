class_name ShipGenerator
extends RefCounted

const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")


func generate(ships: Array, output_dir: String, source_root: String) -> bool:
	print("Processing " + str(ships.size()) + " ships...")

	for res in ships:
		# Determine output path using PathResolver
		var pof_file = res.model_file
		if pof_file.is_empty():
			pof_file = res.ship_class + ".pof" # Fallback
			res.model_file = pof_file

		var path_info = WCSPathResolver.determine_output_path(pof_file)
		var category = path_info[0]
		var subcategory = path_info[1]

		var filename = _normalize_filename(res.ship_class)

		# Create per-ship subfolder
		var ship_dir = output_dir.path_join(category).path_join(subcategory).path_join(filename)
		DirAccess.make_dir_recursive_absolute(ship_dir)

		# Convert POF Model
		var pof_source = _find_source_asset(source_root, pof_file)
		if not pof_source.is_empty():
			# Pass --textures flag for models
			if _convert_asset(pof_source, ship_dir, "model"):
				# Update resource to point to converted GLB (keep original basename)
				res.model_file = pof_source.get_file().get_basename() + ".gltf"
				
				# Generate and Load ShipModelData
				var basename = pof_source.get_file().get_basename()
				var json_access_path = ship_dir.path_join(basename + "_data.json")
				var model_data_path = ship_dir.path_join(basename + "_model.tres")
				
				# If JSON exists (new pipeline), generate TRES
				# We use a dynamic script load or assume ModelDataGenerator is available
				var md_generator = load("res://addons/wcs_import/generators/model_data_generator.gd").new()
				if FileAccess.file_exists(json_access_path):
					var generated_data = md_generator.generate(json_access_path)
					if generated_data:
						res.model_data = generated_data
						print("Generated & Linked ShipModelData: " + model_data_path)
					else:
						print("Failed to generate ShipModelData from: " + json_access_path)
				elif FileAccess.file_exists(model_data_path):
					# Fallback to existing TRES (old pipeline or manual)
					var model_data = load(model_data_path)
					if model_data:
						res.model_data = model_data
						print("Linked existing ShipModelData: " + model_data_path)
					else:
						print("Failed to load existing ShipModelData: " + model_data_path)
				else:
					print("Warning: No model data (json or tres) found for " + basename)
				
				# Cleanup JSON file
				if FileAccess.file_exists(json_access_path):
					DirAccess.remove_absolute(json_access_path)
					print("Cleaned up intermediate JSON: " + json_access_path)
			else:
				print("Failed to convert POF: " + pof_source)
		else:
			print("Warning: Could not find POF source for " + pof_file)

		# Save Resource
		var save_path = ship_dir.path_join(filename + ".tres")
		var err = ResourceSaver.save(res, save_path)
		if err != OK:
			print("Failed to save resource: " + save_path)
		else:
			print("Saved: " + save_path + " (Model: " + res.model_file + ")")

	return true


func _normalize_filename(name: String) -> String:
	var n = name.to_lower()
	n = n.replace(" ", "_")
	n = n.replace("-", "_")
	n = n.replace("#", "_")
	n = n.replace("/", "_")
	n = n.replace("\\", "_")
	return n


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


func _convert_asset(
	source_path: String, target_dir: String, type: String, extra_args: Array = []
) -> bool:
	var global_source = ProjectSettings.globalize_path(source_path)
	var global_target = ProjectSettings.globalize_path(target_dir)

	var args = [
		"run", "--directory", "..", "python", "-m", "converter", global_source, global_target, "--type", type
	]
	args.append_array(extra_args)

	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
