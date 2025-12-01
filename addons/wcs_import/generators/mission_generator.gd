class_name MissionGenerator
extends RefCounted

const MissionParser = preload("res://addons/wcs_import/parsers/mission_parser.gd")
const MissionManifest = preload("res://scripts/resources/missions/mission_manifest.gd")

func process_mission(source_path: String, output_dir: String) -> bool:
	if not FileAccess.file_exists(source_path):
		push_error("Mission file not found: " + source_path)
		return false

	var parser = MissionParser.new()
	var manifest = parser.parse(source_path)
	
	if manifest == null:
		push_error("Failed to parse mission: " + source_path)
		return false

	# Ensure output directory exists
	if not DirAccess.dir_exists_absolute(output_dir):
		var err = DirAccess.make_dir_recursive_absolute(output_dir)
		if err != OK:
			push_error("Failed to create output directory: " + output_dir)
			return false

	# Determine output filename
	var filename = source_path.get_file().get_basename() + ".tres"
	# Force output to target/campaigns/hermes/missions/
	var mission_output_dir = "res://campaigns/hermes/missions/"
	# Ensure directory exists (using DirAccess with absolute path)
	var abs_output_dir = ProjectSettings.globalize_path(mission_output_dir)
	if not DirAccess.dir_exists_absolute(abs_output_dir):
		DirAccess.make_dir_recursive_absolute(abs_output_dir)
		
	var output_path = mission_output_dir.path_join(filename)

	# Set source file metadata
	manifest.source_file = source_path
	manifest.mission_id = source_path.get_file().get_basename()

	# Save resource
	var err = ResourceSaver.save(manifest, output_path)
	if err != OK:
		push_error("Failed to save mission resource to: " + output_path)
		return false

	print("Successfully generated mission: " + output_path)
	return true
