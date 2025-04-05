@tool
extends EditorScript
# Converts iff_defs.tbl into a Godot resource (e.g., iff_defs.tres)

# Define the structure for the output resource (can be inline or separate script)
class_name IffDefsData
extends Resource
@export var iff_names: Array[String] = []
# TODO: Add other relevant IFF data if needed (relationships, colors?)

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/iff_defs.tbl" # Adjust if needed
const OUTPUT_RES_PATH = "res://resources/game_data/iff_defs.tres"

# --- Main Execution ---
func _run():
	print("Converting iff_defs.tbl...")

	var file = FileAccess.open(INPUT_TBL_PATH, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {INPUT_TBL_PATH}")
		return

	var iff_data = IffDefsData.new()

	# --- Parsing Logic ---
	# Skip header lines (usually start with ';')
	while true:
		var line = file.get_line().strip_edges()
		if line.is_empty(): continue
		if not line.begins_with(";"): break # First non-comment line

	# TODO: Implement actual parsing based on iff_defs.tbl format.
	# Assuming a simple format for now: one IFF name per relevant line.
	# Example placeholder logic:
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue

		# Assuming the first word on the line is the IFF name
		var parts = line.split(" ", false, 1) # Split only once
		if parts.size() > 0:
			var iff_name = parts[0]
			# Basic validation/cleanup
			if iff_name.length() > 0 and not iff_name.begins_with("$"): # Avoid table keys
				iff_data.iff_names.append(iff_name)
				print(f"  Found IFF: {iff_name}")
		else:
			print(f"Skipping malformed line: {line}")


	file.close()

	# --- Save Resource ---
	var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	var save_result = ResourceSaver.save(iff_data, OUTPUT_RES_PATH, save_flags)

	if save_result != OK:
		printerr(f"Error saving resource '{OUTPUT_RES_PATH}': {save_result}")
	else:
		print(f"Successfully converted iff_defs.tbl to {OUTPUT_RES_PATH}")
