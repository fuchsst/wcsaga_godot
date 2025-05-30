# scripts/mission_system/mission_loader.gd
# Helper class responsible for loading MissionData resources.
# This might be a simple utility class or integrated into MissionManager.
class_name MissionLoader
extends RefCounted # Use RefCounted for a utility class

const MissionData = preload("res://addons/wcs_asset_core/resources/mission/mission_data.gd")

# Loads a MissionData resource from the specified path.
# Returns the loaded MissionData resource or null on failure.
static func load_mission(mission_resource_path: String) -> MissionData:
	if not mission_resource_path.begins_with("res://"):
		# Assume it's a relative path within the missions folder if not absolute
		mission_resource_path = "res://resources/missions/" + mission_resource_path
		# Ensure correct extension
		if not mission_resource_path.ends_with(".tres"):
			mission_resource_path = mission_resource_path.get_basename() + ".tres"

	print("MissionLoader: Attempting to load mission: ", mission_resource_path)

	if not ResourceLoader.exists(mission_resource_path):
		printerr("MissionLoader: Mission resource file not found at path: ", mission_resource_path)
		return null

	var loaded_res = ResourceLoader.load(mission_resource_path)

	if loaded_res is MissionData:
		print("MissionLoader: Successfully loaded MissionData.")
		return loaded_res as MissionData
	else:
		printerr("MissionLoader: Loaded resource is not of type MissionData at path: ", mission_resource_path)
		if loaded_res:
			printerr("Loaded resource type: ", typeof(loaded_res))
		return null

# TODO: Add functions for asynchronous loading if needed for large missions.
# static func load_mission_async(mission_resource_path: String):
#	 ResourceLoader.load_threaded_request(mission_resource_path)
#	 # Need to handle the result later using load_threaded_get()
