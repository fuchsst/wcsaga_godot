class_name RankGenerator
extends RefCounted

const RankResource = preload("res://scripts/resources/campaigns/rank_resource.gd")
const RankManifest = preload("res://scripts/resources/campaigns/rank_manifest.gd")

# Asset paths
const SOURCE_INTERFACE_DIR = "res://../source_assets/wcs_hermes_campaign/hermes_interface"

func generate_ranks(manifest: RankManifest, output_root: String) -> bool:
	# Target: target/campaigns/hermes/ranks/
	var target_dir = output_root.path_join("campaigns/hermes/ranks")
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	
	print("Processing " + str(manifest.ranks.size()) + " ranks...")
	
	# Process each rank
	for rank in manifest.ranks:
		if rank == null:
			continue
			
		var rank_name = rank.name.to_lower().replace(" ", "_")
		var rank_output_path = target_dir.path_join(rank_name + ".tres")
		
		# 1. Handle Bitmap
		if rank._bitmap_filename != "":
			var bitmap_name = rank._bitmap_filename
			# Try to find the file in source assets
			# Assuming bitmaps are in hermes_interface or hermes_core
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
				var target_path = target_dir.path_join(target_filename)
				
				var converted = _convert_to_png(source_path, target_path)
				
				if converted:
					# Load Texture (Embedded ImageTexture)
					var image = Image.load_from_file(target_path)
					if image:
						var texture = ImageTexture.create_from_image(image)
						rank.bitmap = texture
					else:
						print("Failed to load image: " + target_path)
			else:
				print("Could not find bitmap: " + bitmap_name)

		# 2. Handle Promotion Voice
		if rank._promotion_voice_base != "":
			var voice_name = rank._promotion_voice_base
			# Try to find the file in source assets
			var source_path = ""
			var found = false
			
			# Check common locations for sounds
			var search_paths = [
				ProjectSettings.globalize_path("res://").path_join("../source_assets/wcs_hermes_campaign/hermes_core/sounds"),
				ProjectSettings.globalize_path("res://").path_join("../source_assets/wcs_hermes_campaign/hermes_core")
			]
			
			# Try .wav and .ogg
			var voice_variations = [voice_name + ".wav", voice_name + ".ogg"]
			
			for v in voice_variations:
				source_path = _find_asset(v, search_paths)
				if source_path != "":
					found = true
					break
			
			if found:
				# Convert to OGG
				var target_filename = voice_name + ".ogg"
				var target_path = target_dir.path_join(target_filename)
				
				var converted = _convert_to_ogg(source_path, target_path)
				
				if converted:
					# Try to load audio
					var file = FileAccess.open(target_path, FileAccess.READ)
					if file:
						var stream = AudioStreamOggVorbis.load_from_buffer(file.get_buffer(file.get_length()))
						rank.promotion_voice = stream
					else:
						print("Failed to load audio: " + target_path)
			else:
				print("Could not find voice: " + voice_name)

		# Save individual rank resource
		var error = ResourceSaver.save(rank, rank_output_path)
		if error != OK:
			print("Failed to save rank: " + rank_output_path)
		else:
			print("Saved rank: " + rank_output_path)
			
	print("Rank processing complete.")
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

func _convert_to_ogg(source_path: String, target_path: String) -> bool:
	var global_source = ProjectSettings.globalize_path(source_path)
	var global_target = ProjectSettings.globalize_path(target_path)
	
	# Determine path to converter script
	var project_root = ProjectSettings.globalize_path("res://").get_base_dir() # target
	var repo_root = project_root.get_base_dir() # wcsaga_godot_converter
	var converter_script = repo_root.path_join("converter/convert_audio.py")
	
	# uv run python converter/convert_audio.py input output
	var args = ["run", "python", converter_script, global_source, global_target]
	
	print("Converting audio (Python): " + global_source + " -> " + global_target)
	var output = []
	var exit_code = OS.execute("uv", args, output, true)
	
	if exit_code != 0:
		print("Python audio conversion failed with code " + str(exit_code))
		print("Output: " + str(output))
		return false
		
	return true
