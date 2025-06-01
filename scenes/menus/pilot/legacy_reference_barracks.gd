extends Node2D

# Sound indices from original code
const HOTSPOT_ON_SOUND = 36
const HOTSPOT_OFF_SOUND = 37

# Pilot data class
class PilotData:
	var callsign: String
	var image_filename: String
	var squad_filename: String
	var stats: Dictionary
	
	func _init():
		callsign = ""
		image_filename = ""
		squad_filename = ""
		stats = {
			"primary_shots": 0,
			"primary_hits": 0,
			"secondary_shots": 0,
			"secondary_hits": 0,
			"kills": 0,
			"missions": 0,
			"flight_time": 0
		}

var current_pilot: PilotData = null
var pilots: Array[PilotData] = []
var selected_pilot_index: int = 0
var pilot_image_index: int = 0
var squad_image_index: int = 0

func _ready() -> void:
	# Connect button signals
	$Buttons/CreatePilot.pressed.connect(_on_create_pilot)
	$Buttons/DeletePilot.pressed.connect(_on_delete_pilot)
	$Buttons/ClonePilot.pressed.connect(_on_clone_pilot)
	$Buttons/PrevPilotImage.pressed.connect(_on_prev_pilot_image)
	$Buttons/NextPilotImage.pressed.connect(_on_next_pilot_image)
	$Buttons/PrevSquadImage.pressed.connect(_on_prev_squad_image)
	$Buttons/NextSquadImage.pressed.connect(_on_next_squad_image)
	$Buttons/Accept.pressed.connect(_on_accept)
	$Buttons/Back.pressed.connect(_on_back)
	
	# Connect hover signals for tooltips
	_connect_button_hover($Buttons/CreatePilot, "Create New Pilot")
	_connect_button_hover($Buttons/DeletePilot, "Delete Selected Pilot")
	_connect_button_hover($Buttons/ClonePilot, "Clone Selected Pilot")
	_connect_button_hover($Buttons/PrevPilotImage, "Previous Pilot Image")
	_connect_button_hover($Buttons/NextPilotImage, "Next Pilot Image")
	_connect_button_hover($Buttons/PrevSquadImage, "Previous Squad Image")
	_connect_button_hover($Buttons/NextSquadImage, "Next Squad Image")
	_connect_button_hover($Buttons/Accept, "Accept Selection")
	_connect_button_hover($Buttons/Back, "Return to Main Hall")
	
	# Load pilot data
	_load_pilots()
	_update_displays()

func _connect_button_hover(button: Button, tooltip: String) -> void:
	button.mouse_entered.connect(_on_button_hover.bind(tooltip))
	button.mouse_exited.connect(_on_button_unhover)

func _play_sound(sound_index: int) -> void:
	print("Playing sound:", sound_index)  # TODO: Implement actual sound system

func _on_button_hover(tooltip: String) -> void:
	_play_sound(HOTSPOT_ON_SOUND)
	$TooltipLabel.text = tooltip

func _on_button_unhover() -> void:
	_play_sound(HOTSPOT_OFF_SOUND)
	$TooltipLabel.text = ""

func _load_pilots() -> void:
	# TODO: Load actual pilot files
	var test_pilot = PilotData.new()
	test_pilot.callsign = "TEST PILOT"
	test_pilot.stats.primary_shots = 100
	test_pilot.stats.primary_hits = 75
	test_pilot.stats.kills = 25
	pilots.append(test_pilot)
	current_pilot = test_pilot

func _update_displays() -> void:
	if current_pilot == null:
		return
		
	# Update pilot list
	var pilot_list = $PilotList/ScrollContainer/VBoxContainer
	for child in pilot_list.get_children():
		child.queue_free()
	
	for pilot in pilots:
		var label = Label.new()
		label.text = pilot.callsign
		label.add_theme_color_override("font_color", Color(0.678, 0.847, 0.901))
		pilot_list.add_child(label)
	
	# Update stats
	var stats_list = $PilotStats/ScrollContainer/VBoxContainer
	for child in stats_list.get_children():
		if child.name != "StatsLabel":
			child.queue_free()
	
	var stats = [
		["Primary Shots:", str(current_pilot.stats.primary_shots)],
		["Primary Hits:", str(current_pilot.stats.primary_hits)],
		["Kill Count:", str(current_pilot.stats.kills)],
		["Missions:", str(current_pilot.stats.missions)],
		["Flight Time:", str(current_pilot.stats.flight_time) + " minutes"]
	]
	
	for stat in stats:
		var label = Label.new()
		label.text = stat[0] + " " + stat[1]
		label.add_theme_color_override("font_color", Color(0.678, 0.847, 0.901))
		stats_list.add_child(label)
	
	# Update image counts
	$PilotImage/ImageCount.text = str(pilot_image_index + 1) + " of 1"  # TODO: Actual image count
	$SquadImage/ImageCount.text = str(squad_image_index + 1) + " of 1"  # TODO: Actual image count

func _on_create_pilot() -> void:
	print("Creating new pilot")  # TODO: Implement pilot creation

func _on_delete_pilot() -> void:
	print("Deleting pilot")  # TODO: Implement pilot deletion

func _on_clone_pilot() -> void:
	print("Cloning pilot")  # TODO: Implement pilot cloning

func _on_prev_pilot_image() -> void:
	pilot_image_index = max(0, pilot_image_index - 1)
	_update_displays()

func _on_next_pilot_image() -> void:
	pilot_image_index += 1  # TODO: Add max check
	_update_displays()

func _on_prev_squad_image() -> void:
	squad_image_index = max(0, squad_image_index - 1)
	_update_displays()

func _on_next_squad_image() -> void:
	squad_image_index += 1  # TODO: Add max check
	_update_displays()

func _on_accept() -> void:
	if current_pilot != null:
		# TODO: Save pilot data
		SceneManager.change_scene("main_hall",
			SceneManager.create_options(1.0, "fade"),
			SceneManager.create_options(1.0, "fade"),
			SceneManager.create_general_options(Color.BLACK))

func _on_back() -> void:
	SceneManager.change_scene("main_hall",
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_general_options(Color.BLACK))
