class_name SpeciesGenerator
extends RefCounted

const SpeciesManifest = preload("res://scripts/resources/species/species_manifest.gd")
const SpeciesData = preload("res://scripts/resources/species/species_data.gd")


func generate_defs(manifest: SpeciesManifest, output_dir: String, source_root: String) -> bool:
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	var saved_count = 0
	for species in manifest.species_list:
		# Convert assets to the same directory
		_convert_species_assets(species, source_root, output_dir)
		
		# For species_defs, we just save the resource data
		# We might need to convert assets if they are referenced here, but user instruction
		# emphasized "one tres per species_name" for species_defs.
		# If assets are present, we should probably convert them too, but maybe to a common location?
		# Or maybe species_defs doesn't have assets.
		# Let's assume we just save the data for now.
		var filename = species.species_name.to_lower().replace(" ", "_") + ".tres"
		var save_path = output_dir.path_join(filename)
		var err = ResourceSaver.save(species, save_path)
		if err != OK:
			print("Failed to save species def: " + save_path)
		else:
			print("Saved species def: " + save_path)
			saved_count += 1

	return saved_count == manifest.species_list.size()


func generate_species_assets(manifest: SpeciesManifest, output_dir: String, source_root: String) -> bool:
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	for species in manifest.species_list:
		var raw_name = species.species_name
		var folder_name = raw_name.to_lower().replace(" ", "_")
		
		# Handle Category: Name format (e.g. Ace: Bloodmist -> ace/bloodmist)
		if ":" in raw_name:
			var parts = raw_name.split(":", true, 1)
			var category = parts[0].strip_edges().to_lower().replace(" ", "_")
			var name = parts[1].strip_edges().to_lower().replace(" ", "_")
			folder_name = category.path_join(name)
			
		var species_dir = output_dir.path_join(folder_name)
		if not DirAccess.dir_exists_absolute(species_dir):
			DirAccess.make_dir_recursive_absolute(species_dir)
			
		_convert_species_assets(species, source_root, species_dir)
		
		# Save the resource as a sibling to the folder (or just in the category folder)
		# e.g. .../fiction/ace/bloodmist.tres
		var save_path = output_dir.path_join(folder_name + ".tres")
		ResourceSaver.save(species, save_path)
		print("Saved species data to: " + save_path)
		print("Saved species assets to: " + species_dir)

	return true


func _convert_species_assets(species: Resource, source_root: String, output_dir: String) -> void:
	# Helper to convert and load
	var convert_and_load = func(filename_prop: String, resource_prop: String, type: String):
		if not species.has_meta(filename_prop):
			return

		var filename = species.get_meta(filename_prop)
		if not filename.is_empty():
			if filename.begins_with("empty"):
				species.set(resource_prop, load("res://assets/shared/empty.tres"))
				return

			var exts = [".pcx", ".dds", ".png", ".tga"]
			if type == "animation":
				exts = [".ani", ".eff"]

			var source_file = _find_source_asset(source_root, filename, exts)
			if not source_file.is_empty():
				var target_dir_for_asset = output_dir
				
				# If asset is a Command Briefing animation, use the shared location
				if source_file.contains("/hermes_cbanims/"):
					# We assume cli_runner runs generic animation processing first for these files
					# Target: campaigns/hermes/animations/command_briefings
					# We need to construct the absolute path to the shared folder
					# output_dir is .../assets/species_defs
					# We want .../campaigns/hermes/animations/command_briefings
					# HACK: Assume standard project structure relative to output_dir or just use absolute path logic
					# output_dir should be absolute or res://
					# Let's try to construct it relative to the project root if possible, or just hardcode the expected path
					# Since we don't have easy access to project root here without assumptions, let's use the fact that
					# output_dir usually ends with "assets/species_defs"
					# Better: Use "res://campaigns/hermes/animations/command_briefings" and globalize it if needed
					# But _convert_asset expects a target directory to write to (if it needs to convert).
					# If cli_runner ran first, the file exists there.
					# If we pass the shared dir to _convert_asset, it will overwrite/update it there.
					# This is fine and ensures it exists.
					target_dir_for_asset = "res://campaigns/hermes/animations/command_briefings"
					target_dir_for_asset = ProjectSettings.globalize_path(target_dir_for_asset)
					
					if not DirAccess.dir_exists_absolute(target_dir_for_asset):
						DirAccess.make_dir_recursive_absolute(target_dir_for_asset)

				_convert_asset(source_file, target_dir_for_asset, type)

				# Determine converted filename
				var converted_filename = source_file.get_file().get_basename()
				if type == "texture":
					converted_filename += ".png"
				elif type == "animation":
					converted_filename += ".tres" # SpriteFrames

				var converted_path = target_dir_for_asset.path_join(converted_filename)
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
	convert_and_load.call(
		"thruster_secondary_normal_filename", "thruster_secondary_normal", "animation"
	)
	convert_and_load.call(
		"thruster_secondary_afterburn_filename", "thruster_secondary_afterburn", "animation"
	)
	convert_and_load.call(
		"thruster_tertiary_normal_filename", "thruster_tertiary_normal", "animation"
	)
	convert_and_load.call(
		"thruster_tertiary_afterburn_filename", "thruster_tertiary_afterburn", "animation"
	)

	convert_and_load.call("glow_normal_filename", "glow_normal", "texture")
	convert_and_load.call("glow_afterburn_filename", "glow_afterburn", "texture")
	convert_and_load.call("debris_texture_filename", "debris_texture", "texture")
	convert_and_load.call("shield_hit_anim_filename", "shield_hit_anim", "animation")
	convert_and_load.call("fiction_anim_filename", "fiction_anim", "animation")


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
