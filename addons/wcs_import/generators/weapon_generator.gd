class_name WeaponGenerator
extends RefCounted

const WeaponSceneGenerator = preload("res://addons/wcs_import/generators/weapon_scene_generator.gd")
const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")
const SoundManifest = preload("res://scripts/resources/sounds/sound_manifest.gd")

# Sound lookup cache: index -> AudioStream
var _sound_lookup: Dictionary = {}


func generate(weapons: Array, output_dir: String, source_root: String) -> bool:
	print("Processing " + str(weapons.size()) + " weapons...")
	print("DEBUG: Received output_dir: ", output_dir)

	# Load sound manifest for audio resolution
	_load_sound_manifest()

	var scene_generator = WeaponSceneGenerator.new()

	# Convert output_dir to absolute path if needed
	# Output_dir comes from wcs_importer and should be the final target directory
	# (e.g., /home/.../target/assets/weapons or res://assets/weapons)
	var global_output_dir = output_dir
	if output_dir.begins_with("res://"):
		# Convert res:// path to absolute filesystem path
		global_output_dir = ProjectSettings.globalize_path(output_dir)
	elif not output_dir.begins_with("/"):
		# Relative path - resolve relative to the Godot project root (res://)
		var godot_project_root = ProjectSettings.globalize_path("res://")
		if godot_project_root.ends_with("/"):
			godot_project_root = godot_project_root.left(-1)
		global_output_dir = godot_project_root.path_join(output_dir).simplify_path()
	print("DEBUG: Globalized output_dir: ", global_output_dir)

	# Use base output dir (assets/weapons) as root for generator
	# The generator handles subdirectories (category/weapon_name)
	var weapons_root = global_output_dir
	print("DEBUG: Using weapons_root: ", weapons_root)

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
			var pof_source = WCSPathResolver.resolve_source_path(res.projectile_model)
			if pof_source.is_empty():
				# Try manual search as fallback
				pof_source = _find_source_asset(source_root, res.projectile_model)
			if pof_source.is_empty():
				push_error("Error: Could not find POF source for " + res.projectile_model)
				return false

			if not _convert_asset(pof_source, weapon_dir, "model"):
				push_error("Error: Failed to convert POF model: " + pof_source)
				return false

			# Update resource to point to converted model (keep original basename)
			res.projectile_model = pof_source.get_file().get_basename() + ".gltf"

			# Cleanup any intermediate JSON files from POF conversion
			# ModelDataGenerator creates ShipModelData which is not applicable to weapons
			var basename = res.projectile_model.get_basename()
			var json_access_path = weapon_dir.path_join(basename + "_data.json")
			if FileAccess.file_exists(json_access_path):
				DirAccess.remove_absolute(json_access_path)
				print("Cleaned up intermediate JSON for weapon model: " + basename)

		# 3. Convert/Copy Textures and Icons
		if not res.display_icon.is_empty():
			if res.display_icon.begins_with("empty"):
				res.display_icon = "res://assets/shared/empty.tres"
			else:
				# First try to find icon using path resolver
				var icon_source = WCSPathResolver.resolve_source_path(res.display_icon)

				# If not found, try searching in hermes_interface specifically
				if icon_source.is_empty():
					var hermes_interface_dir = source_root.path_join("hermes_interface")
					icon_source = _find_source_asset(
						hermes_interface_dir, res.display_icon, [".eff", ".dds", ".pcx", ".png"]
					)

				# If still not found, try general search
				if icon_source.is_empty():
					icon_source = _find_source_asset(
						source_root, res.display_icon, [".pcx", ".dds", ".png"]
					)

				if icon_source.is_empty():
					push_warning("Warning: Could not find icon source: " + res.display_icon)
					res.display_icon = ""
				else:
					# Determine conversion type based on file extension
					var ext = icon_source.get_extension().to_lower()
					var conversion_type = "texture"
					if ext == "eff":
						conversion_type = "animation"

					if not _convert_asset(icon_source, weapon_dir, conversion_type):
						push_warning("Warning: Failed to convert icon: " + icon_source)
						res.display_icon = ""
					else:
						# Set appropriate output filename
						if conversion_type == "animation":
							res.display_icon = (
								icon_source.get_file().get_basename() + "_spriteframes.tres"
							)
						else:
							res.display_icon = icon_source.get_file().get_basename() + ".png"

		if not res._laser_bitmap_source.is_empty():
			if not res._laser_bitmap_source.begins_with("empty"):
				var laser_source = WCSPathResolver.resolve_source_path(res._laser_bitmap_source)
				if laser_source.is_empty():
					# Try manual search as fallback
					laser_source = _find_source_asset(
						source_root, res._laser_bitmap_source, [".pcx", ".dds", ".png"]
					)
				if laser_source.is_empty():
					push_warning(
						"Warning: Could not find laser bitmap source: " + res._laser_bitmap_source
					)
				else:
					if not _convert_asset(laser_source, weapon_dir, "texture"):
						push_warning("Warning: Failed to convert laser bitmap: " + laser_source)
					else:
						var tex_path = weapon_dir.path_join(
							laser_source.get_file().get_basename() + ".png"
						)
						print("DEBUG: Checking for texture at: ", tex_path)
						# weapon_dir is an absolute path, so tex_path is also absolute
						var file_exists = FileAccess.file_exists(tex_path)
						print("DEBUG: File exists (absolute)? ", file_exists)
						if not file_exists:
							push_warning("Warning: Converted laser bitmap not found: " + tex_path)
						else:
							# Load using the absolute path
							var loaded_tex = load(tex_path)
							if loaded_tex:
								res.laser_bitmap = loaded_tex
							else:
								push_warning("Warning: Failed to load laser bitmap: " + tex_path)

		if not res._laser_glow_source.is_empty():
			if not res._laser_glow_source.begins_with("empty"):
				var glow_source = _find_source_asset(
					source_root, res._laser_glow_source, [".pcx", ".dds", ".png"]
				)
				if glow_source.is_empty():
					push_warning(
						"Warning: Could not find laser glow source: " + res._laser_glow_source
					)
				else:
					if not _convert_asset(glow_source, weapon_dir, "texture"):
						push_warning("Warning: Failed to convert laser glow: " + glow_source)
					else:
						var tex_path = weapon_dir.path_join(
							glow_source.get_file().get_basename() + ".png"
						)
						if not FileAccess.file_exists(tex_path):
							push_warning("Warning: Converted laser glow not found: " + tex_path)
						else:
							var loaded_tex = load(tex_path)
							if loaded_tex:
								res.laser_glow = loaded_tex
							else:
								push_warning("Warning: Failed to load laser glow: " + tex_path)

		if not res.tech_animation.is_empty():
			if res.tech_animation.begins_with("empty"):
				res.tech_animation = "res://assets/shared/empty.tres"
			else:
				var anim_source = _find_source_asset(
					source_root, res.tech_animation, [".ani", ".eff"]
				)
				if anim_source.is_empty():
					push_warning(
						"Warning: Could not find tech animation source: " + res.tech_animation
					)
					res.tech_animation = ""
				elif not _convert_asset(anim_source, weapon_dir, "ui"):
					push_warning("Warning: Failed to convert tech animation: " + anim_source)
					res.tech_animation = ""

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

		# 5. Resolve sounds from manifest
		_resolve_weapon_sounds(res)

		# 6. Generate Scene and Resource
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
		"run",
		"--directory",
		"..",
		"python",
		"-m",
		"converter",
		global_source,
		global_target,
		"--type",
		type
	]

	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true


# ==============================================================================
# SOUND RESOLUTION
# ==============================================================================


func _load_sound_manifest() -> void:
	"""Load sound manifest and build index -> AudioStream lookup table."""
	_sound_lookup.clear()

	var manifest_path = "res://assets/sounds/sounds.tres"
	if not ResourceLoader.exists(manifest_path):
		push_warning(
			(
				"Sound manifest not found at: "
				+ manifest_path
				+ ". Weapon sounds will not be resolved."
			)
		)
		return

	var manifest = load(manifest_path)
	if not manifest:
		push_warning("Failed to load sound manifest. Weapon sounds will not be resolved.")
		return

	# Build lookup from signature (index) to audio_stream
	if manifest.audio_configs:
		for config in manifest.audio_configs:
			if config.signature >= 0 and config.audio_stream:
				_sound_lookup[config.signature] = config.audio_stream

	print("Loaded sound manifest with " + str(_sound_lookup.size()) + " sound entries.")


func _get_sound_by_index(sound_index: int) -> AudioStream:
	"""Look up an AudioStream by its sound index from sounds.tbl."""
	if sound_index < 0:
		return null
	if _sound_lookup.has(sound_index):
		return _sound_lookup[sound_index]
	return null


func _resolve_weapon_sounds(weapon_res: Resource) -> void:
	"""Resolve sound indices to AudioStream resources."""
	# Fire sound (launch_sound_index)
	if weapon_res.launch_sound_index >= 0:
		var stream = _get_sound_by_index(weapon_res.launch_sound_index)
		if stream:
			weapon_res.fire_sound = stream
		else:
			push_warning(
				(
					"Could not resolve fire sound index "
					+ str(weapon_res.launch_sound_index)
					+ " for weapon "
					+ weapon_res.id
				)
			)

	# Impact sound
	if weapon_res.impact_sound_index >= 0:
		var stream = _get_sound_by_index(weapon_res.impact_sound_index)
		if stream:
			weapon_res.impact_sound = stream
		else:
			push_warning(
				(
					"Could not resolve impact sound index "
					+ str(weapon_res.impact_sound_index)
					+ " for weapon "
					+ weapon_res.id
				)
			)

	# Flyby sound
	if weapon_res.flyby_sound_index >= 0:
		var stream = _get_sound_by_index(weapon_res.flyby_sound_index)
		if stream:
			weapon_res.flyby_sound = stream
		else:
			push_warning(
				(
					"Could not resolve flyby sound index "
					+ str(weapon_res.flyby_sound_index)
					+ " for weapon "
					+ weapon_res.id
				)
			)
