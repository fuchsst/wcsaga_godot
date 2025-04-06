@tool # Allows running from editor/command line
extends EditorScript

# Generates SpriteFrames resources (.tres) from PNG spritesheets and JSON metadata.

# --- Configuration ---
const CONVERTED_ANIM_DIR = "res://assets/animations" # Input dir (output from Python converters)
const OUTPUT_ANIM_RES_DIR = "res://resources/animations" # Output dir for .tres files

# Preload necessary resource scripts/classes
const SpriteFrames = preload("SpriteFrames") # Built-in

var force_overwrite: bool = false

# --- Main Execution ---
func _run():
	print("Generating SpriteFrames resources...")
	var args = OS.get_cmdline_args()
	if "--force" in args:
		force_overwrite = true
		print("  Force overwrite enabled.")

	var processed_count = 0
	var skipped_count = 0
	var error_count = 0

	var dir = DirAccess.open(CONVERTED_ANIM_DIR)
	if not dir:
		printerr(f"Error: Could not open animation directory: {CONVERTED_ANIM_DIR}")
		return

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(OUTPUT_ANIM_RES_DIR)

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var json_path = CONVERTED_ANIM_DIR.path_join(file_name)
			var base_name = file_name.get_basename().replace(".json", "")
			var png_path = base_name + ".png" # Assumes PNG exists with same base name
			var png_full_path = CONVERTED_ANIM_DIR.path_join(png_path)

			if not FileAccess.file_exists(png_full_path):
				printerr(f"Error: Spritesheet PNG not found for JSON: {json_path} (Expected: {png_full_path})")
				error_count += 1
				file_name = dir.get_next()
				continue

			var output_res_path = OUTPUT_ANIM_RES_DIR.path_join(base_name + ".tres")

			if FileAccess.file_exists(output_res_path) and not force_overwrite:
				#print(f"Skipping existing SpriteFrames: {output_res_path}")
				skipped_count += 1
				file_name = dir.get_next()
				continue

			print(f"  Processing: {file_name}")

			# Read JSON
			var json_file = FileAccess.open(json_path, FileAccess.READ)
			if not json_file:
				printerr(f"Error: Could not open JSON file: {json_path}")
				error_count += 1
				file_name = dir.get_next()
				continue
			var json_string = json_file.get_as_text()
			json_file.close()
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result != OK:
				printerr(f"Error: Could not parse JSON file: {json_path} - {json.get_error_message()} at line {json.get_error_line()}")
				error_count += 1
				file_name = dir.get_next()
				continue
			var json_data: Dictionary = json.get_data()

			# Load Texture
			var texture: Texture2D = load(png_full_path)
			if not texture:
				printerr(f"Error: Could not load texture: {png_full_path}")
				error_count += 1
				file_name = dir.get_next()
				continue

			# Extract metadata
			var frames = json_data.get("frames", 0)
			var cols = json_data.get("columns", 1)
			# var rows = json_data.get("rows", 1) # Not strictly needed if we have frame count and cols
			var fw = json_data.get("frame_width", 0)
			var fh = json_data.get("frame_height", 0)
			var loops = json_data.get("loops", true)
			# var frame_delay = json_data.get("frame_delay", 1.0/30.0) # Used by player node

			if fw <= 0 or fh <= 0 or frames <= 0 or cols <= 0:
				printerr(f"Error: Invalid metadata in JSON (frames, cols, width, or height is zero or missing): {json_path}")
				error_count += 1
				file_name = dir.get_next()
				continue

			# Create SpriteFrames Resource
			var sprite_frames = SpriteFrames.new()
			sprite_frames.add_animation("default")
			sprite_frames.set_animation_loops("default", loops)
			# sprite_frames.set_animation_speed("default", 1.0 / frame_delay if frame_delay > 0 else 30.0) # Set FPS

			for i in range(frames):
				var col = i % cols
				var row = i / cols
				var region = Rect2(col * fw, row * fh, fw, fh)
				# Check if region is within texture bounds
				if region.end.x > texture.get_width() or region.end.y > texture.get_height():
					printerr(f"Error: Calculated frame region {region} exceeds texture bounds ({texture.get_width()}x{texture.get_height()}) for frame {i} in {json_path}")
					error_count += 1
					sprite_frames = null # Invalidate resource
					break # Stop processing this file
				sprite_frames.add_frame("default", texture, region)

			if sprite_frames == null: # Check if invalidated in the loop
				file_name = dir.get_next()
				continue

			# Save Resource
			var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
			var save_result = ResourceSaver.save(sprite_frames, output_res_path, save_flags)
			if save_result != OK:
				printerr(f"Error saving SpriteFrames resource '{output_res_path}': {save_result}")
				error_count += 1
			else:
				processed_count += 1
				#print(f"  Saved: {output_res_path}")

		file_name = dir.get_next()

	dir.list_dir_end()
	print(f"Finished generating SpriteFrames. Processed: {processed_count}, Skipped: {skipped_count}, Errors: {error_count}.")
