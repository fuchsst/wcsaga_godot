class_name MissionResourceCoordinator
extends RefCounted

## Mission Resource Coordinator
## Manages resource loading and cleanup during mission flow transitions,
## leveraging existing WCSAssetLoader and resource management systems

const MissionContext = preload("res://scripts/core/game_flow/mission_context/mission_context.gd")

signal resource_loading_progress(progress: float, current_resource: String)
signal resource_cleanup_completed(mission_id: String)

## Resource loading result structure
class ResourceLoadResult:
	var success: bool = false
	var loaded_resources: Array[String] = []
	var failed_resources: Array[String] = []
	var total_loaded: int = 0
	var loading_time_ms: int = 0
	var start_time: int = 0
	
	func _init() -> void:
		start_time = Time.get_ticks_msec()

## Prepare mission resources with progress reporting
func prepare_mission_resources(mission_context: MissionContext) -> ResourceLoadResult:
	var result = ResourceLoadResult.new()
	var resources_to_load: Array[String] = []
	
	print("MissionResourceCoordinator: Preparing resources for mission: ", mission_context.mission_id)
	
	# Collect required resources
	resources_to_load.append_array(_get_mission_specific_resources(mission_context))
	resources_to_load.append_array(_get_ship_resources(mission_context))
	resources_to_load.append_array(_get_briefing_resources(mission_context))
	
	print("Total resources to load: ", resources_to_load.size())
	
	# Load resources with progress reporting
	var loaded_count = 0
	for i in range(resources_to_load.size()):
		var resource_path = resources_to_load[i]
		var load_result = _load_resource_with_validation(resource_path)
		
		if load_result.success:
			result.loaded_resources.append(resource_path)
			mission_context.add_loaded_resource(resource_path)
			loaded_count += 1
		else:
			result.failed_resources.append(resource_path)
			push_warning("Failed to load mission resource: %s - %s" % [resource_path, load_result.error_message])
		
		# Report progress
		var progress = float(i + 1) / float(resources_to_load.size())
		resource_loading_progress.emit(progress, resource_path)
		
		# Allow frame processing to prevent blocking
		await get_tree().process_frame if Engine.is_editor_hint() == false
	
	result.success = result.failed_resources.size() == 0
	result.total_loaded = loaded_count
	result.loading_time_ms = Time.get_ticks_msec() - result.start_time
	
	print("Resource loading completed: %d/%d successful (%.1f%% success rate)" % [
		result.loaded_resources.size(),
		resources_to_load.size(),
		float(result.loaded_resources.size()) / float(resources_to_load.size()) * 100.0
	])
	
	return result

## Clean up mission resources after completion
func cleanup_mission_resources(mission_context: MissionContext) -> void:
	print("MissionResourceCoordinator: Cleaning up resources for mission: ", mission_context.mission_id)
	
	# Get resources that were loaded for this mission
	var resources_to_unload = mission_context.loaded_resources
	
	# Unload mission-specific resources
	for resource_path in resources_to_unload:
		_unload_resource_safely(resource_path)
	
	# Clean up temporary mission data
	_cleanup_temporary_data(mission_context)
	
	# Clear loaded resources list
	mission_context.loaded_resources.clear()
	
	resource_cleanup_completed.emit(mission_context.mission_id)
	print("Resource cleanup completed for mission: ", mission_context.mission_id)

## Prepare specific briefing resources
func prepare_briefing_resources(mission_context: MissionContext) -> ResourceLoadResult:
	var result = ResourceLoadResult.new()
	var briefing_resources = _get_briefing_resources(mission_context)
	
	print("Loading briefing resources: ", briefing_resources.size(), " items")
	
	for resource_path in briefing_resources:
		var load_result = _load_resource_with_validation(resource_path)
		if load_result.success:
			result.loaded_resources.append(resource_path)
			mission_context.add_loaded_resource(resource_path)
		else:
			result.failed_resources.append(resource_path)
			push_warning("Failed to load briefing resource: %s" % resource_path)
	
	result.success = result.failed_resources.size() == 0
	result.total_loaded = result.loaded_resources.size()
	result.loading_time_ms = Time.get_ticks_msec() - result.start_time
	
	return result

## Private resource collection methods
func _get_mission_specific_resources(mission_context: MissionContext) -> Array[String]:
	var resources: Array[String] = []
	var mission_data = mission_context.mission_data
	
	if not mission_data:
		return resources
	
	# Mission file itself (already loaded, but include for completeness)
	if mission_data.resource_path and not mission_data.resource_path.is_empty():
		resources.append(mission_data.resource_path)
	
	# Environment resources
	if not mission_data.skybox_model.is_empty():
		resources.append("models/skyboxes/" + mission_data.skybox_model)
	
	if not mission_data.loading_screen_640.is_empty():
		resources.append("textures/loading/" + mission_data.loading_screen_640)
	
	if not mission_data.loading_screen_1024.is_empty():
		resources.append("textures/loading/" + mission_data.loading_screen_1024)
	
	# Music resources
	if not mission_data.event_music_name.is_empty():
		resources.append("audio/music/" + mission_data.event_music_name)
	
	if not mission_data.briefing_music_name.is_empty():
		resources.append("audio/music/" + mission_data.briefing_music_name)
	
	# Ship and wing specific resources from mission data
	for ship_resource in mission_data.ships:
		if ship_resource.has_method("get_required_resources"):
			resources.append_array(ship_resource.get_required_resources())
	
	print("Mission-specific resources: ", resources.size())
	return resources

func _get_ship_resources(mission_context: MissionContext) -> Array[String]:
	var resources: Array[String] = []
	
	# Selected ship resources
	if mission_context.selected_ship:
		var ship = mission_context.selected_ship
		
		# Ship model and textures
		if not ship.model_path.is_empty():
			resources.append(ship.model_path)
		
		# Ship textures
		for texture_path in ship.texture_paths:
			if not texture_path.is_empty():
				resources.append(texture_path)
		
		# Weapon resources from selected loadout
		if not mission_context.selected_loadout.is_empty():
			resources.append_array(_get_loadout_weapon_resources(mission_context.selected_loadout))
	
	print("Ship resources: ", resources.size())
	return resources

func _get_briefing_resources(mission_context: MissionContext) -> Array[String]:
	var resources: Array[String] = []
	
	var briefing = mission_context.get_mission_briefing()
	if not briefing:
		return resources
	
	# Briefing background images
	if briefing.has_method("get_background_images"):
		resources.append_array(briefing.get_background_images())
	
	# Briefing audio files
	if briefing.has_method("get_audio_files"):
		resources.append_array(briefing.get_audio_files())
	
	# Command briefing resources
	if mission_context.mission_data and not mission_context.mission_data.command_briefings.is_empty():
		var cmd_briefing = mission_context.mission_data.command_briefings[0]
		if cmd_briefing.has_method("get_required_resources"):
			resources.append_array(cmd_briefing.get_required_resources())
	
	print("Briefing resources: ", resources.size())
	return resources

func _get_loadout_weapon_resources(loadout: Dictionary) -> Array[String]:
	var resources: Array[String] = []
	
	# Primary weapons
	if loadout.has("primary_weapons"):
		for weapon_name in loadout.primary_weapons:
			if not weapon_name.is_empty():
				resources.append("weapons/primary/" + weapon_name + ".tres")
	
	# Secondary weapons
	if loadout.has("secondary_weapons"):
		for weapon_name in loadout.secondary_weapons:
			if not weapon_name.is_empty():
				resources.append("weapons/secondary/" + weapon_name + ".tres")
	
	return resources

## Resource loading with validation
func _load_resource_with_validation(resource_path: String) -> Dictionary:
	var result = {
		"success": false,
		"error_message": "",
		"resource": null
	}
	
	# Check if resource exists
	if not ResourceLoader.exists(resource_path):
		result.error_message = "Resource not found: " + resource_path
		return result
	
	# Attempt to load resource
	var loaded_resource = WCSAssetLoader.load_asset(resource_path)
	if loaded_resource:
		result.success = true
		result.resource = loaded_resource
	else:
		result.error_message = "Failed to load resource: " + resource_path
	
	return result

## Safe resource unloading
func _unload_resource_safely(resource_path: String) -> void:
	# Use existing resource management system for unloading
	if ResourceLoader.has_cached(resource_path):
		# Let Godot's resource management handle unloading
		# Don't force unload as other systems might still be using the resource
		pass
	
	print("Resource marked for cleanup: ", resource_path)

## Clean up temporary mission data
func _cleanup_temporary_data(mission_context: MissionContext) -> void:
	# Clear mission-specific temporary data
	mission_context.mission_variables.clear()
	mission_context.resource_loading_progress = 0.0
	
	# Additional cleanup can be added here as needed
	print("Temporary mission data cleaned up")

## Get the tree reference for async operations
func get_tree() -> SceneTree:
	if Engine.is_editor_hint():
		return EditorInterface.get_editor_main_screen().get_tree()
	else:
		return Engine.get_main_loop() as SceneTree