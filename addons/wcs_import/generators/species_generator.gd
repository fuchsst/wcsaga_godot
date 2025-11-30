class_name SpeciesGenerator
extends RefCounted

const SpeciesManifest = preload("res://scripts/resources/species/species_manifest.gd")
const SpeciesData = preload("res://scripts/resources/species/species_data.gd")

func generate(manifest: SpeciesManifest, output_dir: String, source_root: String) -> bool:
	var save_dir = output_dir
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	for species in manifest.species_list:
		_convert_species_assets(species, source_root, save_dir)

	var save_path = save_dir.path_join("species_defs.tres")
	var err = ResourceSaver.save(manifest, save_path)
	if err != OK:
		print("Failed to save species manifest: " + save_path)
		return false

	print("Saved species manifest: " + save_path)
	return true

func _convert_species_assets(species: Resource, source_root: String, output_dir: String) -> void:
	# Helper to convert and load
	var convert_and_load = func(filename_prop: String, resource_prop: String, type: String):
		if not species.has_meta(filename_prop):
			return
			
		var filename = species.get_meta(filename_prop)
		if not filename.is_empty():
			var exts = [".pcx", ".dds", ".png", ".tga"]
			if type == "animation": exts = [".ani", ".eff"]

			var source_file = _find_source_asset(source_root, filename, exts)
			if not source_file.is_empty():
				_convert_asset(source_file, output_dir, type)

				# Determine converted filename
				var converted_filename = source_file.get_file().get_basename()
				if type == "texture": converted_filename += ".png"
				elif type == "animation": converted_filename += ".tres" # SpriteFrames

				var converted_path = output_dir.path_join(converted_filename)
				var res_path = converted_path
				if not res_path.begins_with("res://"):
					res_path = ProjectSettings.localize_path(res_path)

				if FileAccess.file_exists(res_path):
					species.set(resource_prop, load(res_path))
				else:
					print("Warning: Converted file not found: " + res_path)
			else:
				print("Warning: Could not find source for species asset: " + filename)

	convert_and_load.call("thruster_normal_filename", "thruster_normal", "animation")
	convert_and_load.call("thruster_afterburn_filename", "thruster_afterburn", "animation")
	convert_and_load.call("thruster_secondary_normal_filename", "thruster_secondary_normal", "animation")
	convert_and_load.call("thruster_secondary_afterburn_filename", "thruster_secondary_afterburn", "animation")
	convert_and_load.call("thruster_tertiary_normal_filename", "thruster_tertiary_normal", "animation")
	convert_and_load.call("thruster_tertiary_afterburn_filename", "thruster_tertiary_afterburn", "animation")

	convert_and_load.call("glow_normal_filename", "glow_normal", "texture")
	convert_and_load.call("glow_afterburn_filename", "glow_afterburn", "texture")
	convert_and_load.call("debris_texture_filename", "debris_texture", "texture")
	convert_and_load.call("shield_hit_anim_filename", "shield_hit_anim", "animation")

func _find_source_asset(root_path: String, filename: String, extensions: Array = []) -> String:
	# 1. Try exact match in known directories (recursive search is expensive)
	# For now, we do a recursive search because we don't have the file map here.
	# To optimize, we could pass the file map, but for now let's implement a recursive finder
	# or rely on a known structure.
	# Actually, let's implement a simple recursive finder with caching if needed,
	# or just walk the directory.
	# To keep it simple and consistent with other generators, we'll search recursively.
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
	var args = ["run", "python", "-m", "converter", "convert", global_source, global_target, "--type", type]

	# print("Converting " + type + ": " + global_source + " -> " + global_target)
	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true
