class_name CampaignMigrator
extends RefCounted

## Campaign file migration tool for converting WCS .fc2 campaign files to Godot .tres resources
## Handles campaign progression, mission branching, and persistent state management

signal migration_progress(campaign_name: String, current: int, total: int)
signal migration_complete(campaign_name: String, success: bool, output_path: String)
signal migration_error(campaign_name: String, error: String)

# Migration settings
@export var output_directory: String = "res://migrated_assets/campaigns/"
@export var validate_mission_references: bool = true
@export var migrate_associated_missions: bool = true
@export var preserve_campaign_tree: bool = true

# Campaign parser state
var vp_manager: VPManager
var current_campaign: CampaignData
var parse_errors: Array[String] = []

func _init() -> void:
	pass

## Public API

func set_vp_manager(vp_mgr: VPManager) -> void:
	"""Set the VP manager for accessing campaign files."""
	vp_manager = vp_mgr

func migrate_campaign_file(campaign_path: String, output_path: String = "") -> bool:
	"""Migrate a single campaign file to Godot resource format."""
	
	if not vp_manager:
		_emit_error("", "VP Manager not set")
		return false
	
	if not vp_manager.has_file(campaign_path):
		_emit_error(campaign_path, "Campaign file not found: %s" % campaign_path)
		return false
	
	var campaign_name: String = campaign_path.get_file().get_basename()
	var actual_output: String = output_path
	
	if actual_output.is_empty():
		actual_output = output_directory + campaign_name + ".tres"
	
	print("CampaignMigrator: Starting migration of %s" % campaign_path)
	
	# Load and parse campaign file
	var file_data: PackedByteArray = vp_manager.get_file_data(campaign_path)
	var file_content: String = file_data.get_string_from_utf8()
	
	if file_content.is_empty():
		_emit_error(campaign_name, "Failed to read campaign file")
		return false
	
	# Parse campaign data
	current_campaign = CampaignData.new()
	parse_errors.clear()
	
	var success: bool = _parse_campaign_file(file_content, campaign_name)
	
	if not success or not parse_errors.is_empty():
		_emit_error(campaign_name, "Failed to parse campaign file. Errors: %s" % str(parse_errors))
		return false
	
	# Validate parsed data
	if validate_mission_references:
		_validate_campaign_integrity()
	
	# Migrate associated missions if requested
	if migrate_associated_missions:
		_migrate_campaign_missions()
	
	# Save campaign resource
	success = _save_campaign_resource(actual_output, campaign_name)
	
	if success:
		migration_complete.emit(campaign_name, true, actual_output)
		print("CampaignMigrator: Successfully migrated %s to %s" % [campaign_path, actual_output])
	else:
		migration_complete.emit(campaign_name, false, actual_output)
	
	return success

func migrate_all_campaigns() -> bool:
	"""Migrate all campaign files found in VP archives."""
	
	if not vp_manager:
		_emit_error("", "VP Manager not set")
		return false
	
	var campaign_files: Array[String] = _find_campaign_files()
	var total_campaigns: int = campaign_files.size()
	var successful: int = 0
	
	print("CampaignMigrator: Found %d campaign files to migrate" % total_campaigns)
	
	for i in range(campaign_files.size()):
		var campaign_file: String = campaign_files[i]
		migration_progress.emit("All Campaigns", i + 1, total_campaigns)
		
		if migrate_campaign_file(campaign_file):
			successful += 1
	
	print("CampaignMigrator: Migration complete. %d/%d campaigns successful" % [successful, total_campaigns])
	return successful == total_campaigns

## Private implementation - Campaign parsing

func _parse_campaign_file(content: String, campaign_name: String) -> bool:
	"""Parse FC2 campaign file format."""
	
	var lines: PackedStringArray = content.split("\n")
	var current_section: String = ""
	var line_index: int = 0
	
	current_campaign.campaign_filename = campaign_name
	
	while line_index < lines.size():
		var line: String = lines[line_index].strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";"):
			line_index += 1
			continue
		
		# Check for section headers
		if line.begins_with("#"):
			current_section = line.substr(1).to_lower()
			line_index += 1
			continue
		
		# Parse based on current section
		match current_section:
			"campaign info":
				line_index = _parse_campaign_info_section(lines, line_index)
			"mission":
				line_index = _parse_mission_section(lines, line_index)
			"end of campaign":
				break  # End of file
			_:
				# Skip unknown sections
				line_index += 1
	
	# Post-process campaign data
	_finalize_campaign_data()
	
	return true

func _parse_campaign_info_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse campaign info section."""
	var index: int = start_index
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			break  # Start of new section
		
		# Parse campaign properties
		if line.begins_with("$Name:"):
			current_campaign.campaign_name = line.substr(6).strip_edges()
		elif line.begins_with("$Type:"):
			current_campaign.campaign_type = line.substr(6).strip_edges().to_lower()
		elif line.begins_with("$Desc:"):
			current_campaign.description = line.substr(6).strip_edges()
		elif line.begins_with("$Briefing Cutscene:"):
			current_campaign.briefing_cutscene = line.substr(19).strip_edges()
		elif line.begins_with("$Mainhall:"):
			current_campaign.mainhall = line.substr(10).strip_edges()
		elif line.begins_with("$Num players:"):
			# This will be parsed per-mission, so we collect it here
			var num_players_str: String = line.substr(13).strip_edges()
			current_campaign.num_players = _parse_number_array(num_players_str)
		elif line.begins_with("$Flags:"):
			current_campaign.flags = _parse_flags_array(line.substr(7).strip_edges())
		elif line.begins_with("$Required String:"):
			current_campaign.required_string = line.substr(17).strip_edges()
		
		index += 1
	
	return index

func _parse_mission_section(lines: PackedStringArray, start_index: int) -> int:
	"""Parse mission section."""
	var index: int = start_index
	var mission_data: Dictionary = {}
	var mission_index: int = current_campaign.missions.size()
	
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		
		if line.is_empty():
			index += 1
			continue
		
		if line.begins_with("#"):
			# End of mission section, add mission to campaign
			if not mission_data.is_empty():
				current_campaign.missions.append(mission_data)
			break
		
		# Parse mission properties
		if line.begins_with("$Filename:"):
			mission_data["filename"] = line.substr(10).strip_edges()
		elif line.begins_with("$Name:"):
			mission_data["name"] = line.substr(6).strip_edges()
		elif line.begins_with("$Notes:"):
			mission_data["notes"] = line.substr(7).strip_edges()
		elif line.begins_with("$Main Hall:"):
			mission_data["main_hall"] = line.substr(11).strip_edges()
		elif line.begins_with("$Briefing Cutscene:"):
			mission_data["briefing_cutscene"] = line.substr(19).strip_edges()
		elif line.begins_with("$Formula:"):
			# Mission availability formula
			mission_data["formula"] = line.substr(9).strip_edges()
		elif line.begins_with("$Level:"):
			mission_data["level"] = int(line.substr(7).strip_edges())
		elif line.begins_with("$Position:"):
			mission_data["position"] = int(line.substr(10).strip_edges())
		elif line.begins_with("$Flags:"):
			mission_data["flags"] = _parse_flags_array(line.substr(7).strip_edges())
		elif line.begins_with("$Command Persona:"):
			mission_data["command_persona"] = line.substr(17).strip_edges()
		elif line.begins_with("$Command Sender:"):
			mission_data["command_sender"] = line.substr(16).strip_edges()
		elif line.begins_with("$Command Subject:"):
			mission_data["command_subject"] = line.substr(17).strip_edges()
		elif line.begins_with("$Command Message:"):
			mission_data["command_message"] = line.substr(17).strip_edges()
		elif line.begins_with("$Debrief Persona:"):
			mission_data["debrief_persona"] = line.substr(17).strip_edges()
		elif line.begins_with("$Debrief Success Text:"):
			mission_data["debrief_success_text"] = line.substr(22).strip_edges()
		elif line.begins_with("$Debrief Average Text:"):
			mission_data["debrief_average_text"] = line.substr(22).strip_edges()
		elif line.begins_with("$Debrief Fail Text:"):
			mission_data["debrief_fail_text"] = line.substr(19).strip_edges()
		elif line.begins_with("$Debrief Recommendation Text:"):
			mission_data["debrief_recommendation_text"] = line.substr(30).strip_edges()
		elif line.begins_with("$Red Alert Text:"):
			mission_data["red_alert_text"] = line.substr(16).strip_edges()
		elif line.begins_with("$Fiction Viewer:"):
			mission_data["fiction_viewer"] = line.substr(16).strip_edges()
		elif line.begins_with("$Loading Screen 640:"):
			mission_data["loading_screen_640"] = line.substr(20).strip_edges()
		elif line.begins_with("$Loading Screen 1024:"):
			mission_data["loading_screen_1024"] = line.substr(21).strip_edges()
		
		index += 1
	
	# Add final mission if exists
	if not mission_data.is_empty():
		current_campaign.missions.append(mission_data)
	
	return index

func _finalize_campaign_data() -> void:
	"""Finalize campaign data after parsing."""
	
	# Set mission counts
	current_campaign.total_missions = current_campaign.missions.size()
	
	# Build next mission array based on mission order
	current_campaign.next_mission.clear()
	for i in range(current_campaign.missions.size()):
		if i + 1 < current_campaign.missions.size():
			current_campaign.next_mission.append(i + 1)
		else:
			current_campaign.next_mission.append(-1)  # No next mission
	
	# Build branch info from mission formulas
	_build_branch_info()
	
	# Count required vs optional missions
	_count_mission_types()
	
	# Set up default starting equipment if not specified
	if current_campaign.starting_ships.is_empty():
		_set_default_starting_equipment()

func _build_branch_info() -> void:
	"""Build branch information from mission formulas."""
	current_campaign.branch_info.clear()
	
	for i in range(current_campaign.missions.size()):
		var mission: Dictionary = current_campaign.missions[i]
		var formula: String = mission.get("formula", "")
		
		if not formula.is_empty() and formula != "true":
			# This mission has a conditional formula, create branch info
			var branch: Dictionary = {
				"from_mission": i - 1 if i > 0 else 0,
				"to_mission": i,
				"condition": formula
			}
			current_campaign.branch_info.append(branch)

func _count_mission_types() -> void:
	"""Count required vs optional missions."""
	current_campaign.required_missions = 0
	current_campaign.optional_missions = 0
	
	for mission in current_campaign.missions:
		var flags: Array = mission.get("flags", [])
		
		if "optional" in flags:
			current_campaign.optional_missions += 1
		else:
			current_campaign.required_missions += 1

func _set_default_starting_equipment() -> void:
	"""Set default starting equipment for campaign."""
	
	# Default WCS starting ships
	current_campaign.starting_ships = [
		"GTF Hercules",
		"GTF Hercules Mk II",
		"GTF Ulysses",
		"GTF Apollo",
		"GTB Medusa",
		"GTB Ursa"
	]
	
	# Default WCS starting weapons
	current_campaign.starting_weapons = [
		"Subach HL-7",
		"Akheton SDG",
		"Prometheus R",
		"Tempest",
		"Harpoon",
		"Hornet",
		"Trebuchet"
	]

## Utility parsing functions

func _parse_number_array(numbers_str: String) -> Array[int]:
	"""Parse array of numbers from string."""
	var numbers: Array[int] = []
	var parts: PackedStringArray = numbers_str.split(",")
	
	for part in parts:
		var clean_part: String = part.strip_edges()
		if clean_part.is_valid_int():
			numbers.append(int(clean_part))
	
	return numbers

func _parse_flags_array(flags_str: String) -> Array[String]:
	"""Parse flags array from string."""
	var flags: Array[String] = []
	var parts: PackedStringArray = flags_str.split(",")
	
	for flag in parts:
		var clean_flag: String = flag.strip_edges()
		if not clean_flag.is_empty():
			flags.append(clean_flag)
	
	return flags

## Validation and migration support

func _validate_campaign_integrity() -> void:
	"""Validate campaign data integrity."""
	var issues: Array[String] = current_campaign.validate_campaign_integrity()
	
	for issue in issues:
		parse_errors.append(issue)
	
	# Additional validation for mission file references
	for i in range(current_campaign.missions.size()):
		var mission: Dictionary = current_campaign.missions[i]
		var filename: String = mission.get("filename", "")
		
		if filename.is_empty():
			parse_errors.append("Mission %d has no filename" % i)
			continue
		
		# Check if mission file exists in VP archives
		var mission_path: String = "data/missions/" + filename
		if not vp_manager.has_file(mission_path):
			# Try alternative path
			mission_path = "missions/" + filename
			if not vp_manager.has_file(mission_path):
				parse_errors.append("Mission file not found: %s" % filename)

func _migrate_campaign_missions() -> void:
	"""Migrate all missions referenced by the campaign."""
	
	print("CampaignMigrator: Migrating campaign missions...")
	
	var mission_migrator: MissionMigrator = MissionMigrator.new()
	mission_migrator.set_vp_manager(vp_manager)
	mission_migrator.output_directory = output_directory + "../missions/"
	
	var total_missions: int = current_campaign.missions.size()
	
	for i in range(current_campaign.missions.size()):
		var mission: Dictionary = current_campaign.missions[i]
		var filename: String = mission.get("filename", "")
		
		if filename.is_empty():
			continue
		
		migration_progress.emit(current_campaign.campaign_name, i + 1, total_missions)
		
		# Try to find mission file
		var mission_path: String = "data/missions/" + filename
		if not vp_manager.has_file(mission_path):
			mission_path = "missions/" + filename
		
		if vp_manager.has_file(mission_path):
			print("CampaignMigrator: Migrating mission %s" % filename)
			mission_migrator.migrate_mission_file(mission_path)
		else:
			print("CampaignMigrator: Warning - Mission file not found: %s" % filename)

func _save_campaign_resource(output_path: String, campaign_name: String) -> bool:
	"""Save campaign data as Godot resource."""
	
	# Ensure output directory exists
	var dir: DirAccess = DirAccess.open("res://")
	if not dir:
		_emit_error(campaign_name, "Cannot access resource directory")
		return false
	
	var output_dir: String = output_path.get_base_dir()
	if not dir.dir_exists(output_dir):
		dir.make_dir_recursive(output_dir)
	
	# Add migration metadata
	current_campaign.set_meta("migration_date", Time.get_datetime_string_from_system())
	current_campaign.set_meta("migrator_version", "1.0")
	current_campaign.set_meta("branch_count", current_campaign.branch_info.size())
	
	# Save the resource
	var error: Error = ResourceSaver.save(current_campaign, output_path)
	if error != OK:
		_emit_error(campaign_name, "Failed to save campaign resource: %s" % error_string(error))
		return false
	
	return true

func _find_campaign_files() -> Array[String]:
	"""Find all campaign files in VP archives."""
	var campaign_files: Array[String] = []
	
	# Common campaign file locations
	var search_patterns: Array[String] = [
		"data/campaigns/*.fc2",
		"campaigns/*.fc2"
	]
	
	for pattern in search_patterns:
		var files: Array[String] = vp_manager.find_files_by_pattern(pattern)
		campaign_files.append_array(files)
	
	return campaign_files

func _emit_error(campaign_name: String, error_message: String) -> void:
	"""Emit error signal and print error message."""
	print("CampaignMigrator Error [%s]: %s" % [campaign_name, error_message])
	migration_error.emit(campaign_name, error_message)