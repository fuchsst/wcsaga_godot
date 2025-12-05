class_name CampaignGenerator
extends RefCounted

const CampaignParser = preload("res://addons/wcs_import/parsers/campaign_parser.gd")
const CampaignManifest = preload("res://scripts/resources/campaigns/campaign_manifest.gd")


func process_campaign(source_path: String, output_dir: String) -> bool:
	if not FileAccess.file_exists(source_path):
		push_error("Campaign file not found: " + source_path)
		return false

	var parser = CampaignParser.new()
	var manifest = parser.parse(source_path)

	if manifest == null:
		push_error("Failed to parse campaign: " + source_path)
		return false

	# Ensure output directory exists (target/campaigns/<name>/)
	# Determine campaign name from manifest or filename
	var campaign_name = "hermes" # Default or derived from path
	if "hermes" in source_path.to_lower():
		campaign_name = "hermes"
	# else: derive from manifest.campaign_name sanitized? using filename is safer for folder struct

	# Use the provided output directory (which should be correct from CLI runner)
	var campaign_output_dir = output_dir
	var filename = source_path.get_file().get_basename() + ".tres"

	var abs_output_dir = ProjectSettings.globalize_path(campaign_output_dir)
	if not DirAccess.dir_exists_absolute(abs_output_dir):
		var err = DirAccess.make_dir_recursive_absolute(abs_output_dir)
		if err != OK:
			push_error("Failed to create campaign directory: " + abs_output_dir)
			return false

	var output_path = campaign_output_dir.path_join(filename)

	var err = ResourceSaver.save(manifest, output_path)
	if err != OK:
		push_error("Failed to save campaign resource to: " + output_path)
		return false

	print("Successfully generated campaign: " + output_path)
	return true
