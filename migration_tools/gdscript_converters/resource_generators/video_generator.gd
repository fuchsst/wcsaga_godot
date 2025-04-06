@tool # Allows running from editor/command line
extends EditorScript

# Generates/Updates a CutsceneMap resource (.tres) mapping cutscene IDs
# to their converted video file paths (.webm).

# --- Configuration ---
const CONVERTED_VIDEO_DIR = "res://assets/cutscenes"
# TODO: Define path to converted cutscenes.tbl data (e.g., JSON or TRES)
const CUTSCENE_TABLE_DATA_PATH = "res://resources/game_data/cutscenes_table_data.tres" # Placeholder

const OUTPUT_CUTSCENE_MAP_RES = "res://resources/game_data/cutscene_map.tres"

# Preload necessary resource scripts/classes
# Assuming a simple Dictionary resource for mapping for now.
# If a custom CutsceneMap resource script exists, preload it:
# const CutsceneMap = preload("res://scripts/resources/game_data/cutscene_map.gd")

var force_overwrite: bool = false # Might not be needed if we're updating

# --- Main Execution ---
func _run():
	print("Updating Video Map Resource...")
	var args = OS.get_cmdline_args()
	# if "--force" in args:
	#	force_overwrite = true
	#	print("  Force overwrite enabled.")

	var success = true
	var processed_count = 0
	var error_count = 0

	# 1. Load converted cutscenes.tbl data
	# TODO: Implement loading logic based on actual converted format
	var cutscene_table_data = _load_cutscene_table_data(CUTSCENE_TABLE_DATA_PATH)
	if cutscene_table_data == null:
		printerr(f"Error: Could not load cutscene table data from {CUTSCENE_TABLE_DATA_PATH}")
		return
	print(f"    Loaded {cutscene_table_data.size()} cutscene definitions from table data.")

	# 2. Load or create the CutsceneMap resource
	var cutscene_map_res: Dictionary = {} # Use a plain Dictionary for now
	if ResourceLoader.exists(OUTPUT_CUTSCENE_MAP_RES):
		var loaded_res = load(OUTPUT_CUTSCENE_MAP_RES)
		# Check if it's a Dictionary or a custom Resource containing one
		if loaded_res is Dictionary:
			cutscene_map_res = loaded_res
		# Example if using a custom resource:
		# elif loaded_res is CutsceneMap:
		#     if loaded_res.mapping == null: loaded_res.mapping = {}
		#     cutscene_map_res = loaded_res.mapping
		else:
			printerr(f"Warning: Existing resource at {OUTPUT_CUTSCENE_MAP_RES} is not a Dictionary. Creating new.")
	# else: # If using custom resource
		# cutscene_map_res = CutsceneMap.new()
		# cutscene_map_res.mapping = {}


	# 3. Iterate through table data and update map
	for cutscene_id_name in cutscene_table_data:
		var entry_data: Dictionary = cutscene_table_data[cutscene_id_name]
		var filename = entry_data.get("filename", "") # Assuming table data has filename key

		if filename.is_empty():
			printerr(f"Warning: Empty filename for cutscene ID '{cutscene_id_name}'. Skipping.")
			continue

		# Find the corresponding video file in assets
		var video_path = _find_video_file(filename, [CONVERTED_VIDEO_DIR])
		if video_path.is_empty():
			printerr(f"Error: Video file '{filename}' not found for cutscene '{cutscene_id_name}' in {CONVERTED_VIDEO_DIR}")
			error_count += 1
			continue

		# Add/Update entry in the map
		cutscene_map_res[cutscene_id_name] = video_path
		processed_count += 1

	# 4. Save the updated resource
	# If using a plain Dictionary, wrap it in a Resource for saving
	var resource_to_save = Resource.new()
	resource_to_save.set_script(preload("res://scripts/resources/game_data/cutscene_map.gd")) # Assign the script
	resource_to_save.mapping = cutscene_map_res # Set the dictionary data

	# Example if using a custom resource:
	# var resource_to_save = cutscene_map_res # If cutscene_map_res is already the custom resource instance

	var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	DirAccess.make_dir_recursive_absolute(OUTPUT_CUTSCENE_MAP_RES.get_base_dir())
	var save_result = ResourceSaver.save(resource_to_save, OUTPUT_CUTSCENE_MAP_RES, save_flags)
	if save_result != OK:
		printerr(f"Error saving Cutscene Map resource '{OUTPUT_CUTSCENE_MAP_RES}': {save_result}")
		success = false
	else:
		print(f"  Finished updating Cutscene Map. Processed: {processed_count}, Errors: {error_count}.")

	if not success:
		printerr("Video Map update finished with errors.")


func _load_cutscene_table_data(path: String) -> Dictionary:
	# Placeholder: Load data from the converted cutscenes.tbl
	# This should return a dictionary like:
	# { "IntroMovie": {"filename": "intro.webm", ...}, ... }
	printerr(f"Warning: Cutscene table data loading from {path} is not implemented. Returning empty data.")
	# Example structure:
	# var data = {
	# 	"IntroMovie": {"filename": "intro.webm"},
	# 	"Mission1Brief": {"filename": "m01brief.webm"}
	# }
	# return data
	return {}


func _find_video_file(base_filename: String, search_dirs: Array[String]) -> String:
	"""Searches for the video file (likely .webm) in the specified asset directories."""
	var base_name = base_filename.get_basename().get_slice(".", 0) # Remove extension
	var target_filename = base_name + ".webm" # Assume target is WebM

	for search_dir in search_dirs:
		var full_path = search_dir.path_join(target_filename)
		if FileAccess.file_exists(full_path):
			return full_path

	return "" # Not found
