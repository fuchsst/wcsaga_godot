class_name MedalGenerator
extends RefCounted

const MedalResource = preload("res://scripts/resources/campaigns/medal_resource.gd")
const MedalManifest = preload("res://scripts/resources/campaigns/medal_manifest.gd")

# Asset paths
const SOURCE_INTERFACE_DIR = "res://../source_assets/wcs_hermes_campaign/hermes_interface"

func generate_medals(manifest: MedalManifest, output_root: String) -> bool:
	# Target: target/campaigns/hermes/medals/
	var output_dir = output_root.path_join("campaigns/hermes/medals")
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
			# Try to find the file in source assets
			var source_path = ""
			var found = false
			
			# Check common locations
			var search_paths = [
				ProjectSettings.globalize_path("res://").path_join("../source_assets/wcs_hermes_campaign/hermes_interface"),
				ProjectSettings.globalize_path("res://").path_join("../source_assets/wcs_hermes_campaign/hermes_core")
			]
			
			source_path = _find_asset(bitmap_name, search_paths)
			if source_path != "":
				found = true
			
			if found:
				# Convert to PNG
				var target_filename = bitmap_name.get_basename() + ".png"
				var target_path = output_dir.path_join(target_filename)
				
				var converted = _convert_to_png(source_path, target_path)
				
				if converted:
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

func _find_asset(filename: String, search_dirs: Array) -> String:
	var variations = [filename]
	
	# Add extension swaps
	var ext = filename.get_extension().to_lower()
	if ext == "pcx":
		variations.append(filename.replace(".pcx", ".dds"))
	elif ext == "dds":
		variations.append(filename.replace(".dds", ".pcx"))
		
	# Add prefix variations
	var prefixes = ["2_", "1_"]
	var current_variations = variations.duplicate()
	for v in current_variations:
		for prefix in prefixes:
			variations.append(prefix + v)
			
	for dir in search_dirs:
		for v in variations:
			var path = dir.path_join(v)
			if FileAccess.file_exists(path):
				return path
			# Case insensitive check
			var found = _find_file_case_insensitive(dir, v)
			if not found.is_empty():
				return dir.path_join(found)
	return ""

func _find_file_case_insensitive(dir_path: String, filename: String) -> String:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.to_lower() == filename.to_lower():
					return file_name
			file_name = dir.get_next()
	return ""

func _convert_to_png(source_path: String, target_path: String) -> bool:
	var global_source = ProjectSettings.globalize_path(source_path)
	var global_target = ProjectSettings.globalize_path(target_path)
	
	# Determine path to converter script
	var project_root = ProjectSettings.globalize_path("res://").get_base_dir() # target
	var repo_root = project_root.get_base_dir() # wcsaga_godot_converter
	var converter_script = repo_root.path_join("converter/convert_image.py")
	
	# uv run python converter/convert_image.py input output
	var args = ["run", "python", converter_script, global_source, global_target]
	
	print("Converting image (Python): " + global_source + " -> " + global_target)
	var output = []
	var exit_code = OS.execute("uv", args, output, true)
	
	if exit_code != 0:
		print("Python conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false
		
	return true
