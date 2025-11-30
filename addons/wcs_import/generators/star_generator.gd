class_name StarGenerator
extends RefCounted

const WCSSunData = preload("res://scripts/resources/environment/stars/sun_data.gd")
const WCSSunFlare = preload("res://scripts/resources/environment/stars/sun_flare.gd")


func generate(result: Dictionary, output_dir: String, source_root: String) -> bool:
	var success = true

	# Output directories based on user request:
	# images -> target/assets/environment/stars/ (which is output_dir passed in)
	# suns -> target/assets/environment/suns/
	# debris -> target/assets/environment/debris/

	var stars_dir = output_dir # target/assets/environment/stars
	var suns_dir = output_dir.get_base_dir().path_join("suns") # target/assets/environment/suns
	var debris_dir = output_dir.get_base_dir().path_join("debris") # target/assets/environment/debris
	var debris_neb_dir = output_dir.get_base_dir().path_join("debris_neb") # target/assets/environment/debris_neb

	DirAccess.make_dir_recursive_absolute(stars_dir)
	DirAccess.make_dir_recursive_absolute(suns_dir)
	DirAccess.make_dir_recursive_absolute(debris_dir)
	DirAccess.make_dir_recursive_absolute(debris_neb_dir)

	# Process Bitmaps (Convert to PNG in stars_dir)
	for star in result.get("bitmaps", []):
		# star is WCSStarBitmapData, has filename
		var tex_filename = star.filename
		if not tex_filename.is_empty():
			var source_file = _find_source_asset(
				source_root, tex_filename, [".pcx", ".dds", ".png", ".tga"]
			)
			if not source_file.is_empty():
				_convert_asset(source_file, stars_dir, "texture")

				var png_filename = source_file.get_file().get_basename() + ".png"
				var png_path = stars_dir.path_join(png_filename)

				# Ensure path is res://
				var res_path = _to_target_res_path(png_path)

				var tex = PlaceholderTexture2D.new()
				tex.resource_path = res_path
				
				# StarBitmapData doesn't have texture property and isn't saved as resource
				# star.texture = tex
			else:
				print("Warning: Could not find source for star bitmap: " + tex_filename)

	# Process Suns
	for sun_dict in result.get("suns", []):
		var sun_res = WCSSunData.new()
		sun_res.sun_name = sun_dict.get("sun_name", "")
		sun_res.color = sun_dict.get("color", Color.WHITE)
		sun_res.scale = sun_dict.get("scale", 1.0)

		# Handle sunglow texture
		var sunglow_name = sun_dict.get("sunglow_filename", "")
		if not sunglow_name.is_empty():
			var source_file = _find_source_asset(
				source_root, sunglow_name, [".pcx", ".dds", ".png", ".tga"]
			)
			if not source_file.is_empty():
				_convert_asset(source_file, stars_dir, "texture") # Save texture to stars dir? Or suns dir? User said images go to stars/
				# Load the converted texture using PlaceholderTexture2D to ensure path is saved
				var png_filename = source_file.get_file().get_basename() + ".png"
				var png_path = stars_dir.path_join(png_filename)

				# Ensure path is res://
				var res_path = _to_target_res_path(png_path)

				var tex = PlaceholderTexture2D.new()
				tex.resource_path = res_path
				sun_res.sunglow = tex
			else:
				print("Warning: Could not find source for sunglow: " + sunglow_name)

		# Handle flares
		for flare_dict in sun_dict.get("flares", []):
			var flare_res = WCSSunFlare.new()
			flare_res.position = flare_dict.get("position", 0.0)
			flare_res.scale = flare_dict.get("scale", 1.0)

			var flare_tex_name = flare_dict.get("texture_filename", "")
			if not flare_tex_name.is_empty():
				var source_file = _find_source_asset(
					source_root, flare_tex_name, [".pcx", ".dds", ".png", ".tga"]
				)
				if not source_file.is_empty():
					_convert_asset(source_file, stars_dir, "texture") # Save texture to stars dir
					var png_filename = source_file.get_file().get_basename() + ".png"
					var png_path = stars_dir.path_join(png_filename)

					# Ensure path is res://
					var res_path = _to_target_res_path(png_path)

					var tex = PlaceholderTexture2D.new()
					tex.resource_path = res_path
					flare_res.texture = tex
				else:
					print("Warning: Could not find source for flare: " + flare_tex_name)

			sun_res.flares.append(flare_res)

		var filename = sun_res.sun_name.to_lower().replace(" ", "_") + ".tres"
		var save_path = suns_dir.path_join(filename)
		if ResourceSaver.save(sun_res, save_path) != OK:
			print("Failed to save sun: " + save_path)
			success = false

	# Process Debris
	# Directories created at top of function

	for debris in result.get("debris", []):
		# debris is WCSDebrisData, has filename and is_nebula_debris
		var tex_filename = debris.filename
		var target_dir = debris_dir
		if debris.is_nebula_debris:
			target_dir = debris_neb_dir

		if not tex_filename.is_empty():
			var source_file = _find_source_asset(
				source_root, tex_filename, [".pcx", ".dds", ".png", ".tga", ".ani", ".eff"]
			)
			if not source_file.is_empty():
				var ext = source_file.get_extension().to_lower()
				if ext == "ani" or ext == "eff":
					# Convert animation (creates spritesheet PNG and SpriteFrames TRES)
					_convert_asset(source_file, target_dir, "animation")
					print("Converted " + ext.to_upper() + " to spritesheet: " + tex_filename)
				else:
					# Standard texture conversion
					_convert_asset(source_file, target_dir, "texture")
			else:
				print("Warning: Could not find source for debris: " + tex_filename)

	return success


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
		"run", "python", "-m", "converter", "convert", global_source, global_target, "--type", type
	]

	var output = []
	var exit_code = OS.execute("uv", args, output, true)

	if exit_code != 0:
		print("Conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false

	return true


func _to_target_res_path(path: String) -> String:
	var abs_path = ProjectSettings.globalize_path(path).replace("\\", "/")
	var assets_idx = abs_path.find("/assets/")
	if assets_idx != -1:
		return "res://" + abs_path.substr(assets_idx + 1)
	
	# Fallback
	return ProjectSettings.localize_path(path)
