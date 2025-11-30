class_name RankGenerator
extends RefCounted

const RankResource = preload("res://scripts/resources/campaigns/rank_resource.gd")
const RankManifest = preload("res://scripts/resources/campaigns/rank_manifest.gd")

func generate_ranks(manifest: RankManifest, output_root: String, source_root: String) -> bool:
	# Target: target/campaigns/hermes/ranks/
	var target_dir = output_root
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
			var source_path = _find_source_asset(source_root, bitmap_name, [".pcx", ".dds", ".png"])
			
			if source_path != "":
				# Convert to PNG
				_convert_asset(source_path, target_dir, "texture")
				
				var target_filename = source_path.get_file().get_basename() + ".png"
				var target_path = target_dir.path_join(target_filename)
				
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
			var source_path = _find_source_asset(source_root, voice_name, [".wav", ".ogg"])
			
			if source_path != "":
				# Convert to OGG
				_convert_asset(source_path, target_dir, "audio")
				
				var target_filename = source_path.get_file().get_basename() + ".ogg"
				var target_path = target_dir.path_join(target_filename)
				
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
