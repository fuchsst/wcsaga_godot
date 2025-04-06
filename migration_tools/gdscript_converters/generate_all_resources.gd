@tool # Allows running from editor/command line
extends EditorScript

# Orchestrates the generation of various Godot resources from converted assets/metadata.

# Preload the individual generator scripts
const SpriteFramesGenerator = preload("res://migration_tools/gdscript_converters/resource_generators/spriteframes_generator.gd")
const ModelGenerator = preload("res://migration_tools/gdscript_converters/resource_generators/model_generator.gd")
const AudioGenerator = preload("res://migration_tools/gdscript_converters/resource_generators/audio_generator.gd")
const VideoGenerator = preload("res://migration_tools/gdscript_converters/resource_generators/video_generator.gd")
# TODO: Add preloads for other generators if created (e.g., TBL converters if they generate .tres directly)

var force_overwrite: bool = false

# --- Main Execution ---
func _run():
	print("=============================================")
	print("Starting Godot Resource Generation Pipeline")
	print("=============================================")
	var start_time = Time.get_ticks_msec()

	var args = OS.get_cmdline_args()
	if "--force" in args:
		force_overwrite = true
		print("Force overwrite enabled for all generators.")

	# --- Run Generators ---
	# Note: Order might matter if one generator depends on the output of another,
	# but in this case, they seem relatively independent based on output locations.

	# 1. SpriteFrames Generator
	var sprite_gen = SpriteFramesGenerator.new()
	sprite_gen.force_overwrite = force_overwrite # Pass force flag
	sprite_gen._run() # Call its run function
	sprite_gen.free() # Clean up instance

	# 2. Model Generator (Scenes + Metadata)
	var model_gen = ModelGenerator.new()
	model_gen.force_overwrite = force_overwrite
	model_gen._run()
	model_gen.free()

	# 3. Audio Generator (GameSounds, MusicTracks)
	var audio_gen = AudioGenerator.new()
	audio_gen.force_overwrite = force_overwrite
	audio_gen._run()
	audio_gen.free()

	# 4. Video Generator (Cutscene Map)
	var video_gen = VideoGenerator.new()
	video_gen.force_overwrite = force_overwrite
	video_gen._run()
	video_gen.free()

	# TODO: Add calls to other generators if needed

	var end_time = Time.get_ticks_msec()
	var duration = (end_time - start_time) / 1000.0
	print("=============================================")
	print(f"Godot Resource Generation Pipeline Finished in {duration:.2f} seconds.")
	print("=============================================")

	# Optional: Quit after running if executed from command line
	# get_tree().quit(0) # Use with caution
