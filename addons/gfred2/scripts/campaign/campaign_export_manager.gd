@tool
class_name CampaignExportManager
extends RefCounted

## Campaign export manager for GFRED2-008 Campaign Editor Integration.
## Handles exporting campaign data to WCS format using EPIC-003 conversion tools.

signal export_started()
signal export_progress_updated(progress: float, status: String)
signal export_completed(success: bool, output_path: String)
signal export_error(error_message: String)

# Export configuration
var campaign_data: CampaignData = null
var export_format: ExportFormat = ExportFormat.WCS_CAMPAIGN
var output_directory: String = ""
var include_mission_files: bool = true
var validate_before_export: bool = true

enum ExportFormat {
	WCS_CAMPAIGN,    # Original WCS .fc2 campaign format
	GODOT_RESOURCE,  # Godot .tres resource format
	JSON_DATA,       # JSON data format for external tools
	XML_CAMPAIGN     # XML format for compatibility
}

# Export status
var is_exporting: bool = false
var export_progress: float = 0.0
var export_status: String = ""

## Initializes the export manager with campaign data
func setup_campaign_export(target_campaign: CampaignData) -> void:
	campaign_data = target_campaign
	if not campaign_data:
		print("CampaignExportManager: No campaign data provided")
		return
	
	print("CampaignExportManager: Initialized for campaign: %s" % campaign_data.campaign_name)

## Exports campaign to specified format
func export_campaign(format: ExportFormat, output_path: String) -> Error:
	if not campaign_data:
		export_error.emit("No campaign data to export")
		return ERR_INVALID_DATA
	
	if is_exporting:
		export_error.emit("Export already in progress")
		return ERR_BUSY
	
	export_format = format
	output_directory = output_path.get_base_dir()
	
	# Validate campaign before export if requested
	if validate_before_export:
		var validation_errors: Array[String] = campaign_data.validate_campaign()
		if not validation_errors.is_empty():
			export_error.emit("Campaign validation failed: %s" % str(validation_errors))
			return ERR_INVALID_DATA
	
	is_exporting = true
	export_progress = 0.0
	export_started.emit()
	
	var result: Error = OK
	
	match format:
		ExportFormat.WCS_CAMPAIGN:
			result = _export_to_wcs_format(output_path)
		ExportFormat.GODOT_RESOURCE:
			result = _export_to_godot_resource(output_path)
		ExportFormat.JSON_DATA:
			result = _export_to_json_format(output_path)
		ExportFormat.XML_CAMPAIGN:
			result = _export_to_xml_format(output_path)
		_:
			result = ERR_INVALID_PARAMETER
			export_error.emit("Unsupported export format")
	
	is_exporting = false
	
	if result == OK:
		export_completed.emit(true, output_path)
		print("CampaignExportManager: Export completed successfully: %s" % output_path)
	else:
		export_completed.emit(false, "")
		print("CampaignExportManager: Export failed with error: %s" % error_string(result))
	
	return result

## Exports campaign to WCS .fc2 format
func _export_to_wcs_format(output_path: String) -> Error:
	_update_export_progress(0.1, "Preparing WCS campaign export...")
	
	# Create WCS campaign file structure
	var campaign_content: String = _generate_wcs_campaign_content()
	
	_update_export_progress(0.5, "Writing campaign file...")
	
	# Write campaign file
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		export_error.emit("Failed to create campaign file: %s" % output_path)
		return ERR_FILE_CANT_WRITE
	
	file.store_string(campaign_content)
	file.close()
	
	_update_export_progress(0.8, "Exporting mission files...")
	
	# Export associated mission files if requested
	if include_mission_files:
		var mission_export_result: Error = _export_mission_files()
		if mission_export_result != OK:
			return mission_export_result
	
	_update_export_progress(1.0, "WCS campaign export completed")
	return OK

## Generates WCS campaign file content
func _generate_wcs_campaign_content() -> String:
	var content: String = ""
	
	# WCS Campaign file header
	content += "$Name: %s\n" % campaign_data.campaign_name
	content += "$Type: Single\n"  # Assuming single-player campaign
	
	if not campaign_data.campaign_description.is_empty():
		content += "$Desc: %s\n" % campaign_data.campaign_description
	
	content += "\n"
	
	# Campaign missions
	content += "$Num Missions: %d\n" % campaign_data.missions.size()
	content += "\n"
	
	for i in range(campaign_data.missions.size()):
		var mission: CampaignMissionData = campaign_data.missions[i]
		content += _generate_wcs_mission_entry(mission, i)
		content += "\n"
	
	# Campaign branches and logic
	content += _generate_wcs_campaign_logic()
	
	# Campaign variables
	if not campaign_data.campaign_variables.is_empty():
		content += _generate_wcs_campaign_variables()
	
	return content

## Generates WCS mission entry
func _generate_wcs_mission_entry(mission: CampaignMissionData, index: int) -> String:
	var entry: String = ""
	
	entry += "$Mission: %s\n" % mission.mission_filename
	entry += "+Name: %s\n" % mission.mission_name
	
	if not mission.mission_description.is_empty():
		entry += "+Description: %s\n" % mission.mission_description
	
	entry += "+Pos: %d %d\n" % [int(mission.position.x), int(mission.position.y)]
	
	# Mission flags
	if mission.is_required:
		entry += "+Flags: REQUIRED\n"
	
	# Mission prerequisites
	if not mission.prerequisite_missions.is_empty():
		entry += "+Prerequisites: ( "
		for prereq_id in mission.prerequisite_missions:
			var prereq_mission: CampaignMissionData = campaign_data.get_mission(prereq_id)
			if prereq_mission:
				var prereq_index: int = campaign_data.missions.find(prereq_mission)
				entry += "%d " % prereq_index
		entry += ")\n"
	
	# Mission branches
	for branch in mission.mission_branches:
		entry += _generate_wcs_mission_branch(branch)
	
	# Mission briefing/debriefing
	if not mission.mission_briefing_text.is_empty():
		entry += "+Brief: %s\n" % mission.mission_briefing_text
	
	if not mission.mission_debriefing_text.is_empty():
		entry += "+Debrief: %s\n" % mission.mission_debriefing_text
	
	return entry

## Generates WCS mission branch entry
func _generate_wcs_mission_branch(branch: CampaignMissionDataBranch) -> String:
	var branch_entry: String = ""
	
	match branch.branch_type:
		CampaignMissionDataBranch.BranchType.SUCCESS:
			branch_entry += "+Success: "
		CampaignMissionDataBranch.BranchType.FAILURE:
			branch_entry += "+Failure: "
		CampaignMissionDataBranch.BranchType.CONDITION:
			branch_entry += "+Formula: %s\n+Success: " % branch.branch_condition
	
	# Find target mission index
	if not branch.target_mission_id.is_empty():
		var target_mission: CampaignMissionData = campaign_data.get_mission(branch.target_mission_id)
		if target_mission:
			var target_index: int = campaign_data.missions.find(target_mission)
			branch_entry += "%d\n" % target_index
		else:
			branch_entry += "END\n"
	else:
		branch_entry += "END\n"
	
	return branch_entry

## Generates WCS campaign logic section
func _generate_wcs_campaign_logic() -> String:
	var logic: String = ""
	
	# TODO: Generate complex campaign logic based on mission branches
	# This would involve converting mission prerequisites and branches
	# to WCS campaign formula expressions
	
	return logic

## Generates WCS campaign variables section
func _generate_wcs_campaign_variables() -> String:
	var variables: String = ""
	
	variables += "$Variables:\n"
	
	for variable in campaign_data.campaign_variables:
		variables += "+Variable: %s\n" % variable.variable_name
		variables += "+InitialValue: %s\n" % variable.initial_value
		variables += "+Type: "
		
		match variable.variable_type:
			CampaignVariable.VariableType.INTEGER:
				variables += "Integer\n"
			CampaignVariable.VariableType.FLOAT:
				variables += "Float\n"
			CampaignVariable.VariableType.BOOLEAN:
				variables += "Boolean\n"
			CampaignVariable.VariableType.STRING:
				variables += "String\n"
		
		if variable.is_persistent:
			variables += "+Persistent: true\n"
		
		variables += "\n"
	
	return variables

## Exports associated mission files
func _export_mission_files() -> Error:
	var missions_dir: String = output_directory + "/missions/"
	
	# Create missions directory
	if not DirAccess.dir_exists_absolute(missions_dir):
		var dir: DirAccess = DirAccess.open(output_directory)
		if not dir:
			export_error.emit("Failed to access output directory")
			return ERR_FILE_CANT_OPEN
		
		var create_result: Error = dir.make_dir("missions")
		if create_result != OK:
			export_error.emit("Failed to create missions directory")
			return create_result
	
	# Export each mission file
	for i in range(campaign_data.missions.size()):
		var mission: CampaignMissionData = campaign_data.missions[i]
		var progress: float = 0.8 + (0.2 * float(i) / float(campaign_data.missions.size()))
		_update_export_progress(progress, "Exporting mission: %s" % mission.mission_name)
		
		# TODO: Convert mission from Godot format to WCS .fs2 format
		# This would integrate with EPIC-003 conversion tools
		var mission_export_result: Error = _export_single_mission(mission, missions_dir)
		if mission_export_result != OK:
			export_error.emit("Failed to export mission: %s" % mission.mission_name)
			return mission_export_result
	
	return OK

## Exports a single mission file
func _export_single_mission(mission: CampaignMissionData, missions_dir: String) -> Error:
	# TODO: Implement mission file export using EPIC-003 conversion tools
	# This would involve:
	# 1. Loading the Godot mission data
	# 2. Converting to WCS .fs2 format
	# 3. Writing the converted file
	
	var mission_path: String = missions_dir + "/" + mission.mission_filename
	
	# Placeholder: create empty mission file
	var file: FileAccess = FileAccess.open(mission_path, FileAccess.WRITE)
	if not file:
		return ERR_FILE_CANT_WRITE
	
	file.store_string("; Mission file placeholder for %s\n" % mission.mission_name)
	file.close()
	
	print("CampaignExportManager: Mission file exported (placeholder): %s" % mission_path)
	return OK

## Exports campaign to Godot resource format
func _export_to_godot_resource(output_path: String) -> Error:
	_update_export_progress(0.5, "Saving Godot resource...")
	
	var result: Error = ResourceSaver.save(campaign_data, output_path)
	
	if result == OK:
		_update_export_progress(1.0, "Godot resource export completed")
	else:
		export_error.emit("Failed to save Godot resource: %s" % error_string(result))
	
	return result

## Exports campaign to JSON format
func _export_to_json_format(output_path: String) -> Error:
	_update_export_progress(0.3, "Converting to JSON...")
	
	var json_data: Dictionary = _convert_campaign_to_json()
	
	_update_export_progress(0.7, "Writing JSON file...")
	
	var json_string: String = JSON.stringify(json_data, "\t")
	
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		export_error.emit("Failed to create JSON file: %s" % output_path)
		return ERR_FILE_CANT_WRITE
	
	file.store_string(json_string)
	file.close()
	
	_update_export_progress(1.0, "JSON export completed")
	return OK

## Converts campaign data to JSON dictionary
func _convert_campaign_to_json() -> Dictionary:
	var json_data: Dictionary = {}
	
	# Campaign metadata
	json_data["campaign"] = {
		"name": campaign_data.campaign_name,
		"description": campaign_data.campaign_description,
		"author": campaign_data.campaign_author,
		"version": campaign_data.campaign_version,
		"created_date": campaign_data.campaign_created_date,
		"modified_date": campaign_data.campaign_modified_date,
		"starting_mission_id": campaign_data.starting_mission_id,
		"flags": campaign_data.campaign_flags
	}
	
	# Missions
	json_data["missions"] = []
	for mission in campaign_data.missions:
		var mission_data: Dictionary = {
			"id": mission.mission_id,
			"name": mission.mission_name,
			"filename": mission.mission_filename,
			"description": mission.mission_description,
			"author": mission.mission_author,
			"position": {"x": mission.position.x, "y": mission.position.y},
			"prerequisites": mission.prerequisite_missions,
			"is_required": mission.is_required,
			"difficulty_level": mission.difficulty_level,
			"briefing_text": mission.mission_briefing_text,
			"debriefing_text": mission.mission_debriefing_text,
			"flags": mission.mission_flags
		}
		
		# Mission branches
		mission_data["branches"] = []
		for branch in mission.mission_branches:
			var branch_data: Dictionary = {
				"type": _branch_type_to_string(branch.branch_type),
				"target_mission_id": branch.target_mission_id,
				"condition": branch.branch_condition,
				"description": branch.branch_description,
				"enabled": branch.is_enabled
			}
			mission_data["branches"].append(branch_data)
		
		json_data["missions"].append(mission_data)
	
	# Campaign variables
	json_data["variables"] = []
	for variable in campaign_data.campaign_variables:
		var variable_data: Dictionary = {
			"name": variable.variable_name,
			"type": _variable_type_to_string(variable.variable_type),
			"initial_value": variable.initial_value,
			"description": variable.description,
			"persistent": variable.is_persistent
		}
		json_data["variables"].append(variable_data)
	
	return json_data

## Converts branch type enum to string
func _branch_type_to_string(type: CampaignMissionDataBranch.BranchType) -> String:
	match type:
		CampaignMissionDataBranch.BranchType.SUCCESS:
			return "success"
		CampaignMissionDataBranch.BranchType.FAILURE:
			return "failure"
		CampaignMissionDataBranch.BranchType.CONDITION:
			return "condition"
	return "unknown"

## Converts variable type enum to string
func _variable_type_to_string(type: CampaignVariable.VariableType) -> String:
	match type:
		CampaignVariable.VariableType.INTEGER:
			return "integer"
		CampaignVariable.VariableType.FLOAT:
			return "float"
		CampaignVariable.VariableType.BOOLEAN:
			return "boolean"
		CampaignVariable.VariableType.STRING:
			return "string"
	return "unknown"

## Exports campaign to XML format
func _export_to_xml_format(output_path: String) -> Error:
	_update_export_progress(0.3, "Generating XML...")
	
	var xml_content: String = _generate_xml_content()
	
	_update_export_progress(0.7, "Writing XML file...")
	
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		export_error.emit("Failed to create XML file: %s" % output_path)
		return ERR_FILE_CANT_WRITE
	
	file.store_string(xml_content)
	file.close()
	
	_update_export_progress(1.0, "XML export completed")
	return OK

## Generates XML content for campaign
func _generate_xml_content() -> String:
	var xml: String = ""
	
	xml += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	xml += "<campaign>\n"
	
	# Campaign metadata
	xml += "\t<metadata>\n"
	xml += "\t\t<name>%s</name>\n" % _xml_escape(campaign_data.campaign_name)
	xml += "\t\t<description>%s</description>\n" % _xml_escape(campaign_data.campaign_description)
	xml += "\t\t<author>%s</author>\n" % _xml_escape(campaign_data.campaign_author)
	xml += "\t\t<version>%s</version>\n" % campaign_data.campaign_version
	xml += "\t\t<created>%s</created>\n" % campaign_data.campaign_created_date
	xml += "\t\t<modified>%s</modified>\n" % campaign_data.campaign_modified_date
	xml += "\t\t<starting_mission>%s</starting_mission>\n" % campaign_data.starting_mission_id
	xml += "\t</metadata>\n"
	
	# Missions
	xml += "\t<missions>\n"
	for mission in campaign_data.missions:
		xml += "\t\t<mission id=\"%s\">\n" % mission.mission_id
		xml += "\t\t\t<name>%s</name>\n" % _xml_escape(mission.mission_name)
		xml += "\t\t\t<filename>%s</filename>\n" % mission.mission_filename
		xml += "\t\t\t<description>%s</description>\n" % _xml_escape(mission.mission_description)
		xml += "\t\t\t<position x=\"%f\" y=\"%f\"/>\n" % [mission.position.x, mission.position.y]
		xml += "\t\t\t<required>%s</required>\n" % str(mission.is_required).to_lower()
		xml += "\t\t\t<difficulty>%d</difficulty>\n" % mission.difficulty_level
		
		# Prerequisites
		if not mission.prerequisite_missions.is_empty():
			xml += "\t\t\t<prerequisites>\n"
			for prereq_id in mission.prerequisite_missions:
				xml += "\t\t\t\t<prerequisite>%s</prerequisite>\n" % prereq_id
			xml += "\t\t\t</prerequisites>\n"
		
		# Branches
		if not mission.mission_branches.is_empty():
			xml += "\t\t\t<branches>\n"
			for branch in mission.mission_branches:
				xml += "\t\t\t\t<branch type=\"%s\" target=\"%s\">\n" % [_branch_type_to_string(branch.branch_type), branch.target_mission_id]
				if not branch.branch_condition.is_empty():
					xml += "\t\t\t\t\t<condition>%s</condition>\n" % _xml_escape(branch.branch_condition)
				xml += "\t\t\t\t</branch>\n"
			xml += "\t\t\t</branches>\n"
		
		xml += "\t\t</mission>\n"
	
	xml += "\t</missions>\n"
	
	# Variables
	if not campaign_data.campaign_variables.is_empty():
		xml += "\t<variables>\n"
		for variable in campaign_data.campaign_variables:
			xml += "\t\t<variable name=\"%s\" type=\"%s\" persistent=\"%s\">\n" % [
				variable.variable_name,
				_variable_type_to_string(variable.variable_type),
				str(variable.is_persistent).to_lower()
			]
			xml += "\t\t\t<initial_value>%s</initial_value>\n" % _xml_escape(variable.initial_value)
			xml += "\t\t\t<description>%s</description>\n" % _xml_escape(variable.description)
			xml += "\t\t</variable>\n"
		xml += "\t</variables>\n"
	
	xml += "</campaign>\n"
	
	return xml

## Escapes XML special characters
func _xml_escape(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;")

## Updates export progress
func _update_export_progress(progress: float, status: String) -> void:
	export_progress = progress
	export_status = status
	export_progress_updated.emit(progress, status)

## Public API

## Gets supported export formats
func get_supported_formats() -> Array[ExportFormat]:
	return [
		ExportFormat.WCS_CAMPAIGN,
		ExportFormat.GODOT_RESOURCE,
		ExportFormat.JSON_DATA,
		ExportFormat.XML_CAMPAIGN
	]

## Gets format name for display
func get_format_name(format: ExportFormat) -> String:
	match format:
		ExportFormat.WCS_CAMPAIGN:
			return "WCS Campaign (.fc2)"
		ExportFormat.GODOT_RESOURCE:
			return "Godot Resource (.tres)"
		ExportFormat.JSON_DATA:
			return "JSON Data (.json)"
		ExportFormat.XML_CAMPAIGN:
			return "XML Campaign (.xml)"
	return "Unknown"

## Gets format file extension
func get_format_extension(format: ExportFormat) -> String:
	match format:
		ExportFormat.WCS_CAMPAIGN:
			return "fc2"
		ExportFormat.GODOT_RESOURCE:
			return "tres"
		ExportFormat.JSON_DATA:
			return "json"
		ExportFormat.XML_CAMPAIGN:
			return "xml"
	return "dat"

## Checks if currently exporting
func is_export_in_progress() -> bool:
	return is_exporting

## Gets current export progress
func get_export_progress() -> float:
	return export_progress

## Gets current export status
func get_export_status() -> String:
	return export_status

## Cancels current export operation
func cancel_export() -> void:
	if is_exporting:
		is_exporting = false
		export_error.emit("Export cancelled by user")
		print("CampaignExportManager: Export cancelled")

## Sets export options
func set_export_options(include_missions: bool, validate_first: bool) -> void:
	include_mission_files = include_missions
	validate_before_export = validate_first