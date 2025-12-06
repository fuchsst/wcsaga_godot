class_name WeaponGenerator
extends RefCounted

const WeaponSceneGenerator = preload("res://addons/wcs_import/generators/weapon_scene_generator.gd")
const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")


func generate(weapons: Array, output_dir: String, source_root: String) -> bool:
	print("Processing " + str(weapons.size()) + " weapons...")

	var scene_generator = WeaponSceneGenerator.new()

	# Use base output dir (assets/weapons) as root for generator
	# The generator handles subdirectories (category/weapon_name)
	# Use base output dir (assets/weapons) as root for generator
	# The generator handles subdirectories (category/weapon_name)
	var weapons_root = output_dir

	for res in weapons:
		# 1. Determine specific output directory for this weapon
		# e.g. target/assets/weapons/<category>/<faction>/<weapon_slug>/
		var category_dir = res.category.to_lower().replace(" ", "_")
		var faction_dir = res.manufacturer_species.to_lower().replace(" ", "_")
		var weapon_slug = res.id.to_lower().replace(" ", "_")

		var weapon_dir = weapons_root.path_join(category_dir).path_join(faction_dir).path_join(
			weapon_slug
		)
		DirAccess.make_dir_recursive_absolute(weapon_dir)

		# 2. Convert POF Model
		if not res.projectile_model.is_empty() and res.projectile_model != "none":
			var pof_source = _find_source_asset(source_root, res.projectile_model)
			if pof_source.is_empty():
				push_error("Error: Could not find POF source for " + res.projectile_model)
				return false
			
			if not _convert_asset(pof_source, weapon_dir, "model"):
				push_error("Error: Failed to convert POF model: " + pof_source)
				return false

			# Update resource to point to converted GLB (keep original basename)
			res.projectile_model = pof_source.get_file().get_basename() + ".gltf"

			# Attempt to generate ModelData for the weapon model if available
			if not res.projectile_model.is_empty() and res.projectile_model.ends_with(".gltf"):
				var basename = res.projectile_model.get_basename()
				var json_access_path = weapon_dir.path_join(basename + "_data.json")
				
				if FileAccess.file_exists(json_access_path):
					var md_generator = load("res://addons/wcs_import/generators/model_data_generator.gd").new()
					var generated_data = md_generator.generate(json_access_path)
					if generated_data:
						print("Generated ModelData for weapon: " + basename)
					else:
						# If model data generation fails, is it critical? Maybe not, but let's error for consistency if expected
						# Actually ModelData is optional enrichment. Let's warn but maybe not fail hard unless needed.
						# But purely purely "fail early if referenced resource not available": The JSON was available.
						# Let's print error.
						push_error("Error: Failed to generate ModelData for weapon: " + basename)
						return false

		# 3. Convert/Copy Textures and Icons
		if not res.display_icon.is_empty():
			if res.display_icon.begins_with("empty"):
				res.display_icon = "res://assets/shared/empty.tres"
			else:
				var icon_source = _find_source_asset(
					source_root, res.display_icon, [".pcx", ".dds", ".png"]
				)
				if icon_source.is_empty():
					push_error("Error: Could not find icon source: " + res.display_icon)
					# Some icons are truly optional or shared? But usually if referenced it should exist.
					return false
				
				if not _convert_asset(icon_source, weapon_dir, "texture"):
					push_error("Error: Failed to convert icon: " + icon_source)
					return false

				res.display_icon = icon_source.get_file().get_basename() + ".png" # Assuming conversion to PNG

		if not res._laser_bitmap_source.is_empty():
			if not res._laser_bitmap_source.begins_with("empty"):
				var laser_source = _find_source_asset(
					source_root, res._laser_bitmap_source, [".pcx", ".dds", ".png"]
				)
				if laser_source.is_empty():
					push_error("Error: Could not find laser bitmap source: " + res._laser_bitmap_source)
					return false
				
				if not _convert_asset(laser_source, weapon_dir, "texture"):
					push_error("Error: Failed to convert laser bitmap: " + laser_source)
					return false
					
				var tex_path = weapon_dir.path_join(laser_source.get_file().get_basename() + ".png")
				if not FileAccess.file_exists(tex_path):
					push_error("Error: Converted laser bitmap not found: " + tex_path)
					return false
					
				var loaded_tex = load(tex_path)
				if loaded_tex:
					res.laser_bitmap = loaded_tex
				else:
					push_error("Error: Failed to load laser bitmap: " + tex_path)
					return false

		if not res._laser_glow_source.is_empty():
			if not res._laser_glow_source.begins_with("empty"):
				var glow_source = _find_source_asset(
					source_root, res._laser_glow_source, [".pcx", ".dds", ".png"]
				)
				if glow_source.is_empty():
					push_error("Error: Could not find laser glow source: " + res._laser_glow_source)
					return false
				
				if not _convert_asset(glow_source, weapon_dir, "texture"):
					push_error("Error: Failed to convert laser glow: " + glow_source)
					return false

				var tex_path = weapon_dir.path_join(glow_source.get_file().get_basename() + ".png")
				if not FileAccess.file_exists(tex_path):
					push_error("Error: Converted laser glow not found: " + tex_path)
					return false
					
				var loaded_tex = load(tex_path)
				if loaded_tex:
					res.laser_glow = loaded_tex
				else:
					push_error("Error: Failed to load laser glow: " + tex_path)
					return false

		if not res.tech_animation.is_empty():
			if res.tech_animation.begins_with("empty"):
				res.tech_animation = "res://assets/shared/empty.tres"
			else:
				var anim_source = _find_source_asset(source_root, res.tech_animation, [".ani", ".eff"])
				if anim_source.is_empty():
					push_error("Error: Could not find tech animation source: " + res.tech_animation)
					return false
				
				if not _convert_asset(anim_source, weapon_dir, "ui"):
					push_error("Error: Failed to convert tech animation: " + anim_source)
					return false

		# 4. Resolve Impact Explosion
		if not res.impact_explosion.is_empty():
			# This references another resource. We assume it exists or will exist.
			# But if we want to fail early, we should check availability.
			# However, explosions might be generated in a different pass.
			# The logic here just constructs a path.
			var expl_name = res.impact_explosion.get_basename()
			var expl_path = "res://assets/effects/explosions/" + expl_name + ".tscn"
			# We can check if it exists or if we expect it to exist later.
			# Given we are generating weapons, explosions might be generated before or after.
			# Strict dependency management would require order or checking.
			# If we just leave the path, it's a weak reference.
			# But if the file definitely doesn't exist at runtime, it's a problem.
			# For now, let's keep the path setting logic but maybe add a check?
			# res.impact_explosion = expl_path
			# Let's assume explosions are handled separately and we just link.
			res.impact_explosion = expl_path

		# 5. Generate Scene and Resource
		scene_generator.generate_scene(res, weapons_root)

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
