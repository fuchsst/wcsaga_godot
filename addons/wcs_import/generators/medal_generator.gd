class_name MedalGenerator
extends RefCounted

const MedalResource = preload("res://scripts/resources/campaigns/medal_resource.gd")
const MedalManifest = preload("res://scripts/resources/campaigns/medal_manifest.gd")


func generate(manifest: MedalManifest, output_root: String, source_root: String) -> bool:
	# Target: target/campaigns/hermes/medals/
	var output_dir = output_root
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	print("Processing " + str(manifest.medals.size()) + " medals...")

	# Process each medal
	for medal in manifest.medals:
		if medal == null:
			continue

		var medal_name = medal.name.to_lower().replace(" ", "_")
		var medal_output_path = output_dir.path_join(medal_name + ".tres")

		if medal._bitmap_filename != "":
			var bitmap_name = medal._bitmap_filename
			var source_path = _find_source_asset(source_root, bitmap_name, [".pcx", ".dds", ".png"])

			if source_path != "":
				# Convert to PNG
				_convert_asset(source_path, output_dir, "texture")

				var target_filename = source_path.get_file().get_basename() + ".png"
				var target_path = output_dir.path_join(target_filename)

				# Load Texture (Embedded ImageTexture)
				var image = Image.load_from_file(target_path)
				if image:
					var texture = ImageTexture.create_from_image(image)
					medal.bitmap = texture
				else:
					print("Failed to load image: " + target_path)
			else:
				print("Could not find bitmap: " + bitmap_name)

		# Save individual medal resource
		var error = ResourceSaver.save(medal, medal_output_path)
		if error != OK:
			print("Failed to save medal: " + medal_output_path)
		else:
			print("Saved medal: " + medal_output_path)

	print("Medal processing complete.")
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
