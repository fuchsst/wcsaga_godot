class_name CampaignData
extends Resource

## WCS campaign data resource containing mission structure and metadata.
## Represents a complete campaign with missions, progression logic, and story elements.
## Compatible with WCS FC2 campaign file format and SEXP integration.

@export var name: String = ""
@export var description: String = ""
@export var filename: String = ""
@export var type: CampaignDataManager.CampaignType = CampaignDataManager.CampaignType.SINGLE_PLAYER

# GFRED2 editor compatibility properties
@export var campaign_name: String = ""
@export var campaign_description: String = ""
@export var campaign_author: String = ""
@export var campaign_version: String = "1.0"
@export var campaign_created_date: String = ""
@export var campaign_modified_date: String = ""
@export var campaign_variables: Array[SexpVariableData] = []
@export var starting_mission_id: String = ""
@export var campaign_flags: Array[String] = []

# GFRED2 editor signals
signal campaign_data_changed()
signal mission_added(mission: CampaignMissionData)
signal mission_removed(mission_id: String)
signal variable_added(variable: SexpVariableData)
signal variable_removed(variable_name: String)

# Campaign structure
@export var missions: Array[CampaignMissionData] = []
@export var num_missions: int = 0
@export var num_players: int = 1

# Campaign flow
@export var intro_cutscene: String = ""
@export var end_cutscene: String = ""
@export var loop_enabled: bool = false
@export var loop_mission_index: int = -1
@export var loop_reentry_index: int = -1

# Available assets
@export var allowed_ships: Array[String] = []
@export var allowed_weapons: Array[String] = []

# Campaign flags and settings
@export var custom_tech_database: bool = false
@export var reset_rank: bool = false
@export var main_hall: String = "default"

# Campaign progression metadata
@export var created_date: String = ""
@export var version: String = "1.0"
@export var author: String = ""

func _init() -> void:
	"""Initialize campaign data resource."""
	resource_name = "CampaignData"
	# GFRED2 compatibility initialization
	if campaign_created_date.is_empty():
		campaign_created_date = Time.get_datetime_string_from_system()

func get_mission_count() -> int:
	"""Get total number of missions in campaign."""
	return missions.size()

func get_mission_by_index(index: int) -> CampaignMissionData:
	"""Get mission by index."""
	if index < 0 or index >= missions.size():
		return null
	return missions[index]

func get_mission_by_filename(mission_filename: String) -> CampaignMissionData:
	"""Get mission by filename."""
	for mission in missions:
		if mission.filename == mission_filename:
			return mission
	return null

func add_mission(mission: CampaignMissionData) -> void:
	"""Add mission to campaign."""
	mission.index = missions.size()
	missions.append(mission)
	num_missions = missions.size()
	# GFRED2 compatibility
	campaign_data_changed.emit()
	mission_added.emit(mission)

func is_multiplayer_campaign() -> bool:
	"""Check if campaign is multiplayer."""
	return type != CampaignDataManager.CampaignType.SINGLE_PLAYER

func get_campaign_info() -> Dictionary:
	"""Get campaign information summary."""
	return {
		"name": name,
		"description": description,
		"filename": filename,
		"type": CampaignDataManager.CampaignType.keys()[type],
		"mission_count": get_mission_count(),
		"is_multiplayer": is_multiplayer_campaign(),
		"author": author,
		"version": version
	}

## GFRED2 Editor Compatibility Methods

## Removes a mission from the campaign
func remove_mission(mission_id: String) -> void:
	for i in range(missions.size()):
		var mission = missions[i]
		if (mission.mission_id == mission_id) or (mission.name == mission_id):
			# Remove dependencies that reference this mission
			_remove_mission_dependencies(mission_id)
			missions.remove_at(i)
			num_missions = missions.size()
			campaign_data_changed.emit()
			mission_removed.emit(mission_id)
			break

## Gets a mission by ID (GFRED2 compatibility)
func get_mission(mission_id: String) -> CampaignMissionData:
	for mission in missions:
		if (mission.mission_id == mission_id) or (mission.name == mission_id):
			return mission
	return null

## Gets mission by index (GFRED2 compatibility)  
func get_mission_at_index(index: int) -> CampaignMissionData:
	if index >= 0 and index < missions.size():
		return missions[index]
	return null

## Removes dependencies that reference a mission
func _remove_mission_dependencies(mission_id: String) -> void:
	for mission in missions:
		mission.prerequisite_missions.erase(mission_id)
		for branch in mission.mission_branches:
			if branch.target_mission_id == mission_id:
				branch.target_mission_id = ""

## Adds a campaign variable
func add_campaign_variable(variable: SexpVariableData) -> void:
	campaign_variables.append(variable)
	campaign_data_changed.emit()
	variable_added.emit(variable)

## Removes a campaign variable
func remove_campaign_variable(variable_name: String) -> void:
	for i in range(campaign_variables.size()):
		if campaign_variables[i].name == variable_name:
			campaign_variables.remove_at(i)
			campaign_data_changed.emit()
			variable_removed.emit(variable_name)
			break

## Gets a campaign variable by name
func get_campaign_variable(variable_name: String) -> SexpVariableData:
	for variable in campaign_variables:
		if variable.name == variable_name:
			return variable
	return null

## Updates campaign modification date
func update_modification_date() -> void:
	campaign_modified_date = Time.get_datetime_string_from_system()
	campaign_data_changed.emit()

## Duplicates campaign data
func duplicate_campaign() -> CampaignData:
	var duplicate: CampaignData = CampaignData.new()
	# Copy core properties
	duplicate.name = name + " (Copy)"
	duplicate.description = description
	duplicate.filename = filename
	duplicate.type = type
	duplicate.num_players = num_players
	duplicate.intro_cutscene = intro_cutscene
	duplicate.end_cutscene = end_cutscene
	duplicate.loop_enabled = loop_enabled
	duplicate.loop_mission_index = loop_mission_index
	duplicate.loop_reentry_index = loop_reentry_index
	duplicate.allowed_ships = allowed_ships.duplicate()
	duplicate.allowed_weapons = allowed_weapons.duplicate()
	duplicate.custom_tech_database = custom_tech_database
	duplicate.reset_rank = reset_rank
	duplicate.main_hall = main_hall
	duplicate.created_date = created_date
	duplicate.version = version
	duplicate.author = author
	
	# Copy GFRED2 properties
	duplicate.campaign_name = campaign_name + " (Copy)"
	duplicate.campaign_description = campaign_description
	duplicate.campaign_author = campaign_author
	duplicate.campaign_version = campaign_version
	duplicate.campaign_created_date = Time.get_datetime_string_from_system()
	duplicate.starting_mission_id = starting_mission_id
	duplicate.campaign_flags = campaign_flags.duplicate()
	
	# Copy missions
	for mission in missions:
		duplicate.missions.append(mission.duplicate_mission())
	
	# Copy variables
	for variable in campaign_variables:
		var dup_var: SexpVariableData = SexpVariableData.new()
		dup_var.name = variable.name
		dup_var.value = variable.value
		dup_var.type = variable.type
		duplicate.campaign_variables.append(dup_var)
	
	duplicate.num_missions = duplicate.missions.size()
	return duplicate

# Additional resource classes are defined in separate files
# to avoid multiple class_name declarations in a single file