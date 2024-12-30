@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

# Ship properties
var ship_name := ""
var ship_class := -1
var team := 0
var alt_name := ""
var callsign := ""
var cargo := ""

# Ship flags
var flags := {
	# Combat flags
	"protect_ship": false,
	"beam_protect_ship": false,
	"escort": false,
	"invulnerable": false,
	"targetable_as_bomb": false,
	"guardian": false,
	"vaporize": false,
	"stealth": false,
	"friendly_stealth_invisible": false,
	
	# Sensor flags
	"hidden_from_sensors": false,
	"primitive_sensors": false,
	"toggle_subsystem_scanning": false,
	"scannable": false,
	
	# Drive/movement flags
	"no_subspace_drive": false,
	"affected_by_gravity": false,
	"no_bank": false,
	
	# Mission flags
	"destroy_before_mission": false,
	"ignore_count": false,
	"no_arrival_music": false,
	"no_arrival_warp": false,
	"no_departure_warp": false,
	"no_arrival_log": false,
	"no_departure_log": false,
	"red_alert_carry": false,
	
	# AI flags
	"no_dynamic": false,
	"kamikaze": false,
	"disable_messages": false,
	
	# Status flags
	"locked": false,
	"set_class_dynamically": false,
	"no_death_scream": false,
	"always_death_scream": false,
	"hide_ship_name": false,
	"hide_log_entries": false,
	"is_harmless": false
}

# Combat settings
var escort_priority := 0
var kamikaze_damage := 0
var guardian_threshold := 0
var respawn_priority := 0

# Special damage settings
var special_exp_index := -1
var special_hitpoints := {}
var special_shield_settings := {}

# Path restrictions
var arrival_path_mask := 0
var departure_path_mask := 0

# Textures
var ship_textures := {}

# Ship status
var initial_hull := 100.0
var initial_shields := 100.0
var initial_velocity := 33.0
var initial_orientation := Vector3.ZERO

# Arrival/Departure
var arrival_location := 0  # Near ship, In front of ship, etc
var arrival_target := ""
var arrival_distance := 1000
var arrival_delay := 0
var departure_location := 0
var departure_target := ""
var departure_delay := 0

# UI Controls
@onready var name_edit: LineEdit = get_content_container().get_node("TabContainer/Properties/BasicGrid/NameEdit")
@onready var class_option: OptionButton = get_content_container().get_node("TabContainer/Properties/BasicGrid/ClassOption")
@onready var team_option: OptionButton = get_content_container().get_node("TabContainer/Properties/BasicGrid/TeamOption")
@onready var alt_name_edit: LineEdit = get_content_container().get_node("TabContainer/Properties/BasicGrid/AltNameEdit")
@onready var callsign_edit: LineEdit = get_content_container().get_node("TabContainer/Properties/BasicGrid/CallsignEdit")
@onready var cargo_edit: LineEdit = get_content_container().get_node("TabContainer/Properties/BasicGrid/CargoEdit")

# Status controls
@onready var hull_spin: SpinBox = get_content_container().get_node("TabContainer/Status/StatusGrid/HullSpin")
@onready var shields_spin: SpinBox = get_content_container().get_node("TabContainer/Status/StatusGrid/ShieldsSpin")
@onready var velocity_spin: SpinBox = get_content_container().get_node("TabContainer/Status/StatusGrid/VelocitySpin")
@onready var orientation_edits := [
	get_content_container().get_node("TabContainer/Status/StatusGrid/OrientationContainer/PitchSpin"),
	get_content_container().get_node("TabContainer/Status/StatusGrid/OrientationContainer/BankSpin"),
	get_content_container().get_node("TabContainer/Status/StatusGrid/OrientationContainer/HeadingSpin")
]

# Arrival/Departure controls
@onready var arrival_location_option: OptionButton = get_content_container().get_node("TabContainer/Arrival/ArrivalSection/ArrivalGrid/ArrivalLocationOption")
@onready var arrival_target_edit: LineEdit = get_content_container().get_node("TabContainer/Arrival/ArrivalSection/ArrivalGrid/ArrivalTargetEdit")
@onready var arrival_distance_spin: SpinBox = get_content_container().get_node("TabContainer/Arrival/ArrivalSection/ArrivalGrid/ArrivalDistanceSpin")
@onready var arrival_delay_spin: SpinBox = get_content_container().get_node("TabContainer/Arrival/ArrivalSection/ArrivalGrid/ArrivalDelaySpin")
@onready var departure_location_option: OptionButton = get_content_container().get_node("TabContainer/Arrival/DepartureSection/DepartureGrid/DepartureLocationOption")
@onready var departure_target_edit: LineEdit = get_content_container().get_node("TabContainer/Arrival/DepartureSection/DepartureGrid/DepartureTargetEdit")
@onready var departure_delay_spin: SpinBox = get_content_container().get_node("TabContainer/Arrival/DepartureSection/DepartureGrid/DepartureDelaySpin")
@onready var arrival_restrict_button: Button = get_content_container().get_node("TabContainer/Arrival/ArrivalSection/ArrivalRestrictButton")
@onready var departure_restrict_button: Button = get_content_container().get_node("TabContainer/Arrival/DepartureSection/DepartureRestrictButton")

# Combat settings controls
@onready var escort_priority_spin: SpinBox = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/EscortPriorityContainer/EscortPrioritySpin")
@onready var kamikaze_damage_spin: SpinBox = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/AI/KamikazeDamageContainer/KamikazeDamageSpin")
@onready var guardian_threshold_spin: SpinBox = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/GuardianThresholdContainer/GuardianThresholdSpin")

# Special buttons
@onready var textures_button: Button = get_content_container().get_node("TabContainer/Properties/ButtonBox/TexturesButton")
@onready var damage_button: Button = get_content_container().get_node("TabContainer/Properties/ButtonBox/DamageButton")
@onready var hitpoints_button: Button = get_content_container().get_node("TabContainer/Properties/ButtonBox/HitpointsButton")

# Flag checkboxes dictionary
var flag_checks := {}

# Multi-edit support
var multi_edit := false
var tristate_values := {}

const ARRIVE_FROM_DOCK_BAY := 1
const DEPART_AT_DOCK_BAY := 1

func _ready():
	super._ready()
	
	# Initialize flag checkboxes dictionary
	_setup_flag_checks()
	
	# Connect signals
	_connect_signals()
	
	# Set initial state
	_update_ui()

func _setup_flag_checks():
	# Combat flags
	flag_checks["protect_ship"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/ProtectShipCheck")
	flag_checks["beam_protect_ship"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/BeamProtectShipCheck")
	flag_checks["escort"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/EscortCheck")
	flag_checks["invulnerable"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/InvulnerableCheck")
	flag_checks["targetable_as_bomb"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/TargetableAsBombCheck")
	flag_checks["guardian"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/GuardianCheck")
	flag_checks["vaporize"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/VaporizeCheck")
	flag_checks["stealth"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/StealthCheck")
	flag_checks["friendly_stealth_invisible"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Combat/FriendlyStealthInvisibleCheck")
	
	# Sensor flags
	flag_checks["hidden_from_sensors"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Sensors/HiddenFromSensorsCheck")
	flag_checks["primitive_sensors"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Sensors/PrimitiveSensorsCheck")
	flag_checks["toggle_subsystem_scanning"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Sensors/ToggleSubsystemScanningCheck")
	flag_checks["scannable"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Sensors/ScannableCheck")
	
	# Drive flags
	flag_checks["no_subspace_drive"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Drive/NoSubspaceDriveCheck")
	flag_checks["affected_by_gravity"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Drive/AffectedByGravityCheck")
	flag_checks["no_bank"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Drive/NoBankCheck")
	
	# Mission flags
	flag_checks["destroy_before_mission"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Mission/DestroyBeforeMissionCheck")
	flag_checks["ignore_count"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Mission/IgnoreCountCheck")
	flag_checks["no_arrival_music"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Mission/NoArrivalMusicCheck")
	flag_checks["no_arrival_warp"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Mission/NoArrivalWarpCheck")
	flag_checks["no_departure_warp"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Mission/NoDepartureWarpCheck")
	flag_checks["no_arrival_log"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Mission/NoArrivalLogCheck")
	flag_checks["no_departure_log"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Mission/NoDepartureLogCheck")
	flag_checks["red_alert_carry"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Mission/RedAlertCarryCheck")
	
	# AI flags
	flag_checks["no_dynamic"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/AI/NoDynamicCheck")
	flag_checks["kamikaze"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/AI/KamikazeCheck")
	flag_checks["disable_messages"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/AI/DisableMessagesCheck")
	
	# Status flags
	flag_checks["locked"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Status/LockedCheck")
	flag_checks["set_class_dynamically"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Status/SetClassDynamicallyCheck")
	flag_checks["no_death_scream"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Status/NoDeathScreamCheck")
	flag_checks["always_death_scream"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Status/AlwaysDeathScreamCheck")
	flag_checks["hide_ship_name"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Status/HideShipNameCheck")
	flag_checks["hide_log_entries"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Status/HideLogEntriesCheck")
	flag_checks["is_harmless"] = get_content_container().get_node("TabContainer/Properties/FlagsNotebook/Status/IsHarmlessCheck")

func _connect_signals():
	# Basic properties
	name_edit.text_submitted.connect(_on_name_changed)
	class_option.item_selected.connect(_on_class_selected)
	team_option.item_selected.connect(_on_team_selected)
	alt_name_edit.text_submitted.connect(_on_alt_name_changed)
	callsign_edit.text_submitted.connect(_on_callsign_changed)
	cargo_edit.text_submitted.connect(_on_cargo_changed)
	
	# Status values
	hull_spin.value_changed.connect(_on_hull_changed)
	shields_spin.value_changed.connect(_on_shields_changed)
	velocity_spin.value_changed.connect(_on_velocity_changed)
	
	for i in range(3):
		orientation_edits[i].value_changed.connect(_on_orientation_changed.bind(["P", "B", "H"][i]))
	
	# Arrival/Departure
	arrival_location_option.item_selected.connect(_on_arrival_location_selected)
	arrival_target_edit.text_submitted.connect(_on_arrival_target_changed)
	arrival_distance_spin.value_changed.connect(_on_arrival_distance_changed)
	arrival_delay_spin.value_changed.connect(_on_arrival_delay_changed)
	departure_location_option.item_selected.connect(_on_departure_location_selected)
	departure_target_edit.text_submitted.connect(_on_departure_target_changed)
	departure_delay_spin.value_changed.connect(_on_departure_delay_changed)
	
	# Combat settings
	escort_priority_spin.value_changed.connect(_on_escort_priority_changed)
	kamikaze_damage_spin.value_changed.connect(_on_kamikaze_damage_changed)
	guardian_threshold_spin.value_changed.connect(_on_guardian_threshold_changed)
	
	# Special buttons
	textures_button.pressed.connect(_on_textures_pressed)
	damage_button.pressed.connect(_on_special_damage_pressed)
	hitpoints_button.pressed.connect(_on_special_hitpoints_pressed)
	arrival_restrict_button.pressed.connect(_on_restrict_arrival_paths)
	departure_restrict_button.pressed.connect(_on_restrict_departure_paths)
	
	# Connect flag checkboxes
	for flag in flags:
		if flag_checks.has(flag):
			flag_checks[flag].toggled.connect(_on_flag_toggled.bind(flag))

func _update_ui():
	if multi_edit:
		# Clear text fields that can vary between ships
		name_edit.text = ""
		alt_name_edit.text = ""
		callsign_edit.text = ""
		cargo_edit.text = ""
		
		# Update checkboxes to show mixed state
		for flag in flags:
			if flag_checks.has(flag):
				if tristate_values.has(flag):
					match tristate_values[flag]:
						0: # All false
							flag_checks[flag].button_pressed = false
							flag_checks[flag].set_modulate(Color(1, 1, 1, 1))
						1: # All true
							flag_checks[flag].button_pressed = true
							flag_checks[flag].set_modulate(Color(1, 1, 1, 1))
						2: # Mixed
							flag_checks[flag].button_pressed = false
							flag_checks[flag].set_modulate(Color(1, 1, 1, 0.5))
	else:
		# Normal single-edit mode
		name_edit.text = ship_name
		alt_name_edit.text = alt_name
		callsign_edit.text = callsign
		cargo_edit.text = cargo
		
		for flag in flags:
			if flag_checks.has(flag):
				flag_checks[flag].button_pressed = flags[flag]
				flag_checks[flag].set_modulate(Color(1, 1, 1, 1))
	
	# Update combat settings
	if flags["escort"]:
		escort_priority_spin.value = escort_priority
		escort_priority_spin.editable = true
	else:
		escort_priority_spin.editable = false
		
	if flags["kamikaze"]:
		kamikaze_damage_spin.value = kamikaze_damage
		kamikaze_damage_spin.editable = true
	else:
		kamikaze_damage_spin.editable = false
		
	if flags["guardian"]:
		guardian_threshold_spin.value = guardian_threshold
		guardian_threshold_spin.editable = true
	else:
		guardian_threshold_spin.editable = false
	
	# Update status values
	hull_spin.value = initial_hull
	shields_spin.value = initial_shields
	velocity_spin.value = initial_velocity
	
	for i in range(3):
		orientation_edits[i].value = initial_orientation[i]
	
	# Update arrival/departure
	arrival_target_edit.text = arrival_target
	arrival_distance_spin.value = arrival_distance
	arrival_delay_spin.value = arrival_delay
	departure_target_edit.text = departure_target
	departure_delay_spin.value = departure_delay
	
	# Update path restriction buttons
	arrival_restrict_button.visible = (arrival_location == ARRIVE_FROM_DOCK_BAY)
	departure_restrict_button.visible = (departure_location == DEPART_AT_DOCK_BAY)

func set_multi_edit(enabled: bool):
	multi_edit = enabled
	
	# Reset tristate tracking
	tristate_values.clear()
	
	# Disable name editing in multi-edit
	name_edit.editable = !multi_edit
	
	# Update UI for multi-edit mode
	_update_ui()

func set_tristate_value(flag: String, value: int):
	tristate_values[flag] = value
	_update_ui()

# Signal handlers
func _on_name_changed(new_text: String):
	ship_name = new_text

func _on_class_selected(index: int):
	ship_class = index

func _on_team_selected(index: int):
	team = index

func _on_alt_name_changed(new_text: String):
	alt_name = new_text

func _on_callsign_changed(new_text: String):
	callsign = new_text

func _on_cargo_changed(new_text: String):
	cargo = new_text

func _on_flag_toggled(pressed: bool, flag: String):
	flags[flag] = pressed
	
	# Handle flag dependencies
	match flag:
		"escort":
			escort_priority_spin.editable = pressed
		"kamikaze":
			kamikaze_damage_spin.editable = pressed
		"guardian":
			guardian_threshold_spin.editable = pressed
		"no_death_scream":
			if pressed:
				flags["always_death_scream"] = false
				flag_checks["always_death_scream"].button_pressed = false
				flag_checks["always_death_scream"].disabled = true
			else:
				flag_checks["always_death_scream"].disabled = false
		"always_death_scream":
			if pressed:
				flags["no_death_scream"] = false
				flag_checks["no_death_scream"].button_pressed = false
				flag_checks["no_death_scream"].disabled = true
			else:
				flag_checks["no_death_scream"].disabled = false

func _on_escort_priority_changed(value: float):
	escort_priority = int(value)

func _on_kamikaze_damage_changed(value: float):
	kamikaze_damage = int(value)

func _on_guardian_threshold_changed(value: float):
	guardian_threshold = int(value)

func _on_hull_changed(value: float):
	initial_hull = value

func _on_shields_changed(value: float):
	initial_shields = value

func _on_velocity_changed(value: float):
	initial_velocity = value

func _on_orientation_changed(value: float, axis: String):
	match axis:
		"P": initial_orientation.x = value
		"B": initial_orientation.y = value 
		"H": initial_orientation.z = value

func _on_arrival_location_selected(index: int):
	arrival_location = index
	arrival_restrict_button.visible = (index == ARRIVE_FROM_DOCK_BAY)
	arrival_target_edit.editable = (index != ARRIVE_FROM_DOCK_BAY)

func _on_arrival_target_changed(new_text: String):
	arrival_target = new_text

func _on_arrival_distance_changed(value: float):
	arrival_distance = int(value)

func _on_arrival_delay_changed(value: float):
	arrival_delay = int(value)

func _on_departure_location_selected(index: int):
	departure_location = index
	departure_restrict_button.visible = (index == DEPART_AT_DOCK_BAY)
	departure_target_edit.editable = (index != DEPART_AT_DOCK_BAY)

func _on_departure_target_changed(new_text: String):
	departure_target = new_text

func _on_departure_delay_changed(value: float):
	departure_delay = int(value)

func _on_textures_pressed():
	var dialog = preload("res://addons/gfred2/dialogs/ship_textures_editor.gd").new()
	dialog.ship_textures = ship_textures.duplicate()
	dialog.confirmed.connect(_on_textures_confirmed.bind(dialog))
	add_child(dialog)
	dialog.show_dialog()

func _on_textures_confirmed(dialog):
	ship_textures = dialog.ship_textures.duplicate()
	dialog.queue_free()

func _on_special_damage_pressed():
	var dialog = preload("res://addons/gfred2/dialogs/ship_special_damage_editor.gd").new()
	dialog.special_exp_index = special_exp_index
	dialog.confirmed.connect(_on_special_damage_confirmed.bind(dialog))
	add_child(dialog)
	dialog.show_dialog()

func _on_special_damage_confirmed(dialog):
	special_exp_index = dialog.special_exp_index
	dialog.queue_free()

func _on_special_hitpoints_pressed():
	var dialog = preload("res://addons/gfred2/dialogs/ship_special_hitpoints_editor.gd").new()
	dialog.special_hitpoints = special_hitpoints.duplicate()
	dialog.special_shield_settings = special_shield_settings.duplicate()
	dialog.confirmed.connect(_on_special_hitpoints_confirmed.bind(dialog))
	add_child(dialog)
	dialog.show_dialog()

func _on_special_hitpoints_confirmed(dialog):
	special_hitpoints = dialog.special_hitpoints.duplicate()
	special_shield_settings = dialog.special_shield_settings.duplicate()
	dialog.queue_free()

func _on_restrict_arrival_paths():
	var dialog = preload("res://addons/gfred2/dialogs/restrict_paths_dialog.gd").new()
	dialog.is_arrival = true
	dialog.path_mask = arrival_path_mask
	dialog.ship_class = ship_class
	dialog.confirmed.connect(_on_arrival_paths_confirmed.bind(dialog))
	add_child(dialog)
	dialog.show_dialog()

func _on_arrival_paths_confirmed(dialog):
	arrival_path_mask = dialog.path_mask
	dialog.queue_free()

func _on_restrict_departure_paths():
	var dialog = preload("res://addons/gfred2/dialogs/restrict_paths_dialog.gd").new()
	dialog.is_arrival = false
	dialog.path_mask = departure_path_mask
	dialog.ship_class = ship_class
	dialog.confirmed.connect(_on_departure_paths_confirmed.bind(dialog))
	add_child(dialog)
	dialog.show_dialog()

func _on_departure_paths_confirmed(dialog):
	departure_path_mask = dialog.path_mask
	dialog.queue_free()
