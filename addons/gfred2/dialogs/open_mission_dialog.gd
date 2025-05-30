@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

signal mission_selected(mission_data: MissionData)

const MissionConverter = preload("res://addons/wcs_converter/conversion/mission_converter.gd")

var file_list: ItemList
var preview: TextEdit
var open_button: Button

var missions: Array[MissionData] = []
var mission_converter: MissionConverter

func _ready():
	super._ready()
	
	# Initialize EPIC-003 mission converter
	mission_converter = MissionConverter.new()
	
	# Get node references
	file_list = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/FileList
	preview = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/Preview
	open_button = $MarginContainer/VBoxContainer/ButtonContainer/OpenButton
	
	# Connect signals
	file_list.item_selected.connect(_on_file_selected)
	open_button.pressed.connect(_on_ok_pressed)
	$MarginContainer/VBoxContainer/ButtonContainer/CancelButton.pressed.connect(_on_cancel_pressed)

func show_dialog(minsize: Vector2 = Vector2(800, 500)):
	# Clear previous state
	file_list.clear()
	preview.text = ""
	open_button.disabled = true
	missions.clear()
	
	# Load available missions using EPIC-003 MissionConverter
	var dir: DirAccess = DirAccess.open("res://assets/hermes_core")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".fs2") or file_name.ends_with(".fc2"):
				var file_path: String = "res://assets/hermes_core/" + file_name
				var info_result: Dictionary = mission_converter.get_mission_file_info(file_path)
				
				if info_result.get("success", false):
					# Create MissionData from EPIC-003 converter info
					var mission: MissionData = _create_mission_data_from_info(info_result, file_path)
					missions.append(mission)
					file_list.add_item(info_result.get("mission_name", "Unknown Mission"))
				else:
					# Log error but continue processing other missions
					push_warning("Failed to load mission info for %s: %s" % [file_name, info_result.get("error", "Unknown error")])
			
			file_name = dir.get_next()
		dir.list_dir_end()
	
	super.show_dialog(minsize)

func _on_file_selected(index: int):
	if index >= 0 and index < missions.size():
		var mission: MissionData = missions[index]
		
		# Update preview with detailed mission information
		var preview_text: String = ""
		preview_text += "Title: " + (mission.title if mission.title else "Unknown") + "\n"
		preview_text += "Designer: " + (mission.designer if mission.designer else "Unknown") + "\n"
		preview_text += "File: " + mission.get_meta("source_file_path", "Unknown").get_file() + "\n"
		preview_text += "Type: " + _get_mission_type_string(mission.mission_type) + "\n"
		
		# Add statistics from EPIC-003 converter analysis
		preview_text += "\nMission Statistics:\n"
		preview_text += "Ships: " + str(mission.stats.get("num_ships", 0)) + "\n"
		preview_text += "Wings: " + str(mission.stats.get("num_wings", 0)) + "\n" 
		preview_text += "Waypoints: " + str(mission.get_meta("waypoint_count", 0)) + "\n"
		preview_text += "Events: " + str(mission.stats.get("num_events", 0)) + "\n"
		preview_text += "Goals: " + str(mission.stats.get("num_goals", 0)) + "\n"
		preview_text += "File Size: " + str(mission.get_meta("file_size", 0)) + " bytes\n"
		
		# Add mission flags if any are set
		var flags: Array[String] = []
		if mission.red_alert: flags.append("Red Alert")
		if mission.scramble: flags.append("Scramble")
		if mission.is_training: flags.append("Training")
		if mission.all_teams_at_war: flags.append("All Teams at War")
		if flags.size() > 0:
			preview_text += "Flags: " + ", ".join(flags) + "\n"
		
		if mission.description and not mission.description.is_empty():
			preview_text += "\nDescription:\n" + mission.description
		
		preview.text = preview_text
		open_button.disabled = false

func _on_ok_pressed():
	var selected = file_list.get_selected_items()
	if selected.size() > 0:
		mission_selected.emit(missions[selected[0]])
	super._on_ok_pressed()

func _on_cancel_pressed():
	super._on_cancel_pressed()

func _create_mission_data_from_info(info: Dictionary, file_path: String) -> MissionData:
	"""Create MissionData object from EPIC-003 converter mission info"""
	var mission: MissionData = MissionData.new()
	
	# Set basic mission properties from converter info
	mission.title = info.get("mission_name", "Unknown")
	mission.designer = info.get("author", "Unknown")
	mission.description = info.get("description", "")
	
	# Store file path for reference (will add this property to MissionData)
	mission.set_meta("source_file_path", file_path)
	
	# Set statistics from converter analysis using correct property names
	mission.stats["num_ships"] = info.get("ship_count", 0)
	mission.stats["num_wings"] = info.get("wing_count", 0)
	mission.stats["num_events"] = info.get("event_count", 0)
	mission.stats["num_goals"] = info.get("goal_count", 0)
	
	# Store additional converter information
	mission.set_meta("waypoint_count", info.get("waypoint_count", 0))
	mission.set_meta("file_size", info.get("file_size", 0))
	
	return mission

func _get_mission_type_string(mission_type: MissionData.MissionType) -> String:
	"""Convert mission type enum to display string"""
	match mission_type:
		MissionData.MissionType.SINGLE_PLAYER:
			return "Single Player"
		MissionData.MissionType.MULTI_PLAYER:
			return "Multi Player"
		MissionData.MissionType.TRAINING:
			return "Training"
		MissionData.MissionType.COOPERATIVE:
			return "Cooperative"
		MissionData.MissionType.TEAM_VS_TEAM:
			return "Team vs Team"
		MissionData.MissionType.DOGFIGHT:
			return "Dogfight"
		_:
			return "Unknown"
