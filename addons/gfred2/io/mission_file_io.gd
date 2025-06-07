@tool
class_name MissionFileIO
extends RefCounted

## Godot Resource I/O for MissionData
##
## Provides a high-level interface for loading and saving MissionData resources.
## This class operates on Godot's native resource formats (.tres, .res) and
## does NOT handle the parsing of legacy .fs2 files. The conversion of .fs2
## files to MissionData resources is the responsibility of the WCS
## conversion tools (EPIC-003).

## Loads a MissionData resource from a given path.
##
## @param file_path: The path to the .tres or .res file.
## @return MissionData resource on success, null on failure.
static func load_mission_resource(file_path: String) -> MissionData:
	if not ResourceLoader.exists(file_path, "MissionData"):
		push_error("Mission resource file not found or not of type MissionData: %s" % file_path)
		return null
	
	var mission_resource: MissionData = ResourceLoader.load(file_path, "MissionData", ResourceLoader.CACHE_MODE_REUSE)
	if not mission_resource:
		push_error("Failed to load MissionData resource from: %s" % file_path)
		return null
		
	return mission_resource

## Saves a MissionData resource to a given path.
##
## @param mission_data: The MissionData resource to save.
## @param file_path: The path to save the .tres or .res file.
## @return OK on success, or an error code on failure.
static func save_mission_resource(mission_data: MissionData, file_path: String) -> Error:
	if not mission_data:
		push_error("Cannot save a null MissionData resource.")
		return ERR_INVALID_DATA
		
	# Ensure the path has the correct extension
	var final_path := file_path
	if not final_path.ends_with(".tres") and not final_path.ends_with(".res"):
		final_path += ".tres"
		
	var err := ResourceSaver.save(mission_data, final_path)
	if err != OK:
		push_error("Failed to save MissionData resource to: %s (Error %d)" % [final_path, err])
		
	return err

## Creates a backup of an existing mission resource file.
##
## @param file_path: The path to the resource file to back up.
## @return OK on success, or an error code on failure.
static func backup_mission_resource(file_path: String) -> Error:
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND
		
	var backup_path := file_path.get_basename() + ".bak"
	var dir_access := DirAccess.open(file_path.get_base_dir())
	if not dir_access:
		return ERR_CANT_OPEN
		
	var err := dir_access.copy(file_path, backup_path)
	if err != OK:
		push_error("Failed to create backup for mission resource: %s (Error %d)" % [file_path, err])
		
	return err
