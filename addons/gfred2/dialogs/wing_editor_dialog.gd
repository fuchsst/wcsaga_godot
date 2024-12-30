@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

# Wing data
var wing_data: MissionObject

# UI Controls
@onready var name_edit: LineEdit = get_content_container().get_node("GridContainer/NameEdit")
@onready var special_ship_option: OptionButton = get_content_container().get_node("GridContainer/SpecialShipOption")
@onready var waves_spin: SpinBox = get_content_container().get_node("GridContainer/WavesSpin")
@onready var threshold_spin: SpinBox = get_content_container().get_node("GridContainer/ThresholdSpin")
@onready var arrival_location: OptionButton = get_content_container().get_node("GridContainer/ArrivalLocation")
@onready var departure_location: OptionButton = get_content_container().get_node("GridContainer/DepartureLocation")
@onready var arrival_delay: SpinBox = get_content_container().get_node("GridContainer/ArrivalDelay")
@onready var departure_delay: SpinBox = get_content_container().get_node("GridContainer/DepartureDelay")
@onready var arrival_target: OptionButton = get_content_container().get_node("GridContainer/ArrivalTarget")
@onready var departure_target: OptionButton = get_content_container().get_node("GridContainer/DepartureTarget")
@onready var arrival_distance: SpinBox = get_content_container().get_node("GridContainer/ArrivalDistance")
@onready var reinforcement_check: CheckBox = get_content_container().get_node("FlagsContainer/ReinforcementCheck")
@onready var ignore_count_check: CheckBox = get_content_container().get_node("FlagsContainer/IgnoreCountCheck")
@onready var no_arrival_music_check: CheckBox = get_content_container().get_node("FlagsContainer/NoArrivalMusicCheck")
@onready var no_arrival_warp_check: CheckBox = get_content_container().get_node("FlagsContainer/NoArrivalWarpCheck")
@onready var no_departure_warp_check: CheckBox = get_content_container().get_node("FlagsContainer/NoDepartureWarpCheck")
@onready var no_arrival_log_check: CheckBox = get_content_container().get_node("FlagsContainer/NoArrivalLogCheck")
@onready var no_departure_log_check: CheckBox = get_content_container().get_node("FlagsContainer/NoDepartureLogCheck")
@onready var no_dynamic_check: CheckBox = get_content_container().get_node("FlagsContainer/NoDynamicCheck")
@onready var arrival_tree: Tree = get_content_container().get_node("TreeContainer/ArrivalContainer/ArrivalTree")
@onready var departure_tree: Tree = get_content_container().get_node("TreeContainer/DepartureContainer/DepartureTree")

func _ready():
	super._ready()
	
	# Initialize location options
	_populate_location_options(arrival_location)
	_populate_location_options(departure_location)

func _populate_location_options(option_button: OptionButton):
	option_button.add_item("Hyperspace", MissionObject.LocationType.HYPERSPACE)
	option_button.add_item("Docking Bay", MissionObject.LocationType.DOCKING_BAY) 
	option_button.add_item("In Front of Ship", MissionObject.LocationType.IN_FRONT_OF_SHIP)
	option_button.add_item("At Location", MissionObject.LocationType.AT_LOCATION)

func show_dialog_for_wing(wing: MissionObject):
	wing_data = wing
	
	# Populate fields
	name_edit.text = wing.name
	
	# Populate special ship dropdown with wing members
	special_ship_option.clear()
	for i in range(wing.children.size()):
		var ship = wing.children[i]
		special_ship_option.add_item(ship.name, i)
	special_ship_option.selected = wing.special_ship_index
	
	waves_spin.value = wing.num_waves
	threshold_spin.value = wing.threshold
	threshold_spin.max_value = wing.children.size() - 1
	
	arrival_location.selected = wing.arrival_location
	departure_location.selected = wing.departure_location
	
	arrival_delay.value = wing.arrival_delay
	departure_delay.value = wing.departure_delay
	
	arrival_distance.value = wing.arrival_distance
	
	# Set flags
	reinforcement_check.button_pressed = wing.reinforcement
	ignore_count_check.button_pressed = wing.ignore_count
	no_arrival_music_check.button_pressed = wing.no_arrival_music
	no_arrival_warp_check.button_pressed = wing.no_arrival_warp
	no_departure_warp_check.button_pressed = wing.no_departure_warp
	no_arrival_log_check.button_pressed = wing.no_arrival_log
	no_departure_log_check.button_pressed = wing.no_departure_log
	no_dynamic_check.button_pressed = wing.no_dynamic
	
	# TODO: Populate arrival/departure trees with SEXP data
	
	show_dialog(Vector2(800, 600))

func _on_ok_pressed():
	# Update wing data
	wing_data.name = name_edit.text
	wing_data.special_ship_index = special_ship_option.selected
	wing_data.num_waves = int(waves_spin.value)
	wing_data.threshold = int(threshold_spin.value)
	
	wing_data.arrival_location = arrival_location.selected
	wing_data.departure_location = departure_location.selected
	
	wing_data.arrival_delay = int(arrival_delay.value)
	wing_data.departure_delay = int(departure_delay.value)
	
	wing_data.arrival_distance = int(arrival_distance.value)
	
	# Update flags
	wing_data.reinforcement = reinforcement_check.button_pressed
	wing_data.ignore_count = ignore_count_check.button_pressed
	wing_data.no_arrival_music = no_arrival_music_check.button_pressed
	wing_data.no_arrival_warp = no_arrival_warp_check.button_pressed
	wing_data.no_departure_warp = no_departure_warp_check.button_pressed
	wing_data.no_arrival_log = no_arrival_log_check.button_pressed
	wing_data.no_departure_log = no_departure_log_check.button_pressed
	wing_data.no_dynamic = no_dynamic_check.button_pressed
	
	# TODO: Save SEXP tree data
	
	super._on_ok_pressed()
