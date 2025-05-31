@tool
class_name ShipFlagsController
extends Control

## Ship flags controller for GFRED2-009 Advanced Ship Configuration.
## Scene-based UI controller for managing ship behavior flags.
## Scene: addons/gfred2/scenes/dialogs/ship_editor/ship_flags_panel.tscn

signal flag_config_updated(flag_name: String, enabled: bool)
signal flags_preset_applied(preset_name: String)

# Current flag configuration
var current_flag_config: ShipFlagConfig = null

# Scene node references (populated by .tscn file)
@onready var flags_grid: GridContainer = $VBoxContainer/FlagsGrid

# Flag checkboxes (populated dynamically)
var flag_checkboxes: Dictionary = {}

# Flag presets for different ship types
var flag_presets: Dictionary = {
	"Fighter": {
		"protect_ship": false,
		"escort": false,
		"invulnerable": false,
		"stealth": false,
		"no_dynamic": false
	},
	"Bomber": {
		"protect_ship": false,
		"beam_protect_ship": true,
		"escort": false,
		"invulnerable": false,
		"no_dynamic": false
	},
	"Capital Ship": {
		"protect_ship": true,
		"guardian": true,
		"no_dynamic": true,
		"invulnerable": false,
		"no_arrival_warp": false
	},
	"Transport": {
		"protect_ship": false,
		"escort": false,
		"no_dynamic": true,
		"ignore_count": true,
		"scannable": true
	}
}

func _ready() -> void:
	name = "ShipFlagsController"
	
	# Create flag checkboxes
	_create_flag_checkboxes()
	
	print("ShipFlagsController: Controller initialized")

## Updates the panel with flag configuration
func update_with_flag_config(flag_config: ShipFlagConfig) -> void:
	if not flag_config:
		return
	
	current_flag_config = flag_config
	
	# Update all flag checkboxes
	for flag_name in flag_checkboxes:
		var checkbox: CheckBox = flag_checkboxes[flag_name]
		var flag_value: bool = flag_config.get(flag_name)
		checkbox.button_pressed = flag_value

## Creates flag checkboxes dynamically
func _create_flag_checkboxes() -> void:
	if not flags_grid:
		return
	
	# Define all ship flags with descriptions
	var ship_flags: Array[Dictionary] = [
		{"name": "protect_ship", "label": "Protect Ship", "tooltip": "Ship is protected from player attacks"},
		{"name": "beam_protect_ship", "label": "Beam Protect Ship", "tooltip": "Ship is protected from beam weapons"},
		{"name": "escort", "label": "Escort", "tooltip": "Ship will escort other ships"},
		{"name": "invulnerable", "label": "Invulnerable", "tooltip": "Ship cannot be destroyed"},
		{"name": "guardian", "label": "Guardian", "tooltip": "Ship is a guardian vessel"},
		{"name": "vaporize", "label": "Vaporize", "tooltip": "Ship vaporizes when destroyed"},
		{"name": "stealth", "label": "Stealth", "tooltip": "Ship is stealthed"},
		{"name": "hidden_from_sensors", "label": "Hidden from Sensors", "tooltip": "Ship is hidden from sensors"},
		{"name": "scannable", "label": "Scannable", "tooltip": "Ship can be scanned for cargo"},
		{"name": "kamikaze", "label": "Kamikaze", "tooltip": "Ship will perform kamikaze attacks"},
		{"name": "no_dynamic", "label": "No Dynamic", "tooltip": "Ship will not dynamically appear"},
		{"name": "red_alert_carry", "label": "Red Alert Carry", "tooltip": "Ship carries red alert status"},
		{"name": "no_arrival_music", "label": "No Arrival Music", "tooltip": "No music plays on ship arrival"},
		{"name": "no_arrival_warp", "label": "No Arrival Warp", "tooltip": "Ship arrives without warp effect"},
		{"name": "no_departure_warp", "label": "No Departure Warp", "tooltip": "Ship departs without warp effect"},
		{"name": "locked", "label": "Locked", "tooltip": "Ship loadout is locked"},
		{"name": "ignore_count", "label": "Ignore Count", "tooltip": "Ship is not counted for mission objectives"}
	]
	
	# Create checkboxes for each flag
	for flag_info in ship_flags:
		var checkbox: CheckBox = CheckBox.new()
		checkbox.text = flag_info["label"]
		checkbox.tooltip_text = flag_info["tooltip"]
		checkbox.toggled.connect(_on_flag_toggled.bind(flag_info["name"]))
		
		flags_grid.add_child(checkbox)
		flag_checkboxes[flag_info["name"]] = checkbox

## Signal handlers
func _on_flag_toggled(flag_name: String, enabled: bool) -> void:
	if not current_flag_config:
		return
	
	current_flag_config.set(flag_name, enabled)
	flag_config_updated.emit(flag_name, enabled)

## Public API
func get_current_flag_config() -> ShipFlagConfig:
	return current_flag_config

func apply_flag_preset(preset_name: String) -> void:
	if not current_flag_config or not flag_presets.has(preset_name):
		return
	
	var preset: Dictionary = flag_presets[preset_name]
	for flag_name in preset:
		current_flag_config.set(flag_name, preset[flag_name])
		if flag_checkboxes.has(flag_name):
			flag_checkboxes[flag_name].button_pressed = preset[flag_name]
	
	flags_preset_applied.emit(preset_name)