@tool
class_name BasicPropertiesController
extends Control

## Basic ship properties controller for GFRED2-009 Advanced Ship Configuration.
## Scene-based UI controller for editing fundamental ship properties.
## Scene: addons/gfred2/scenes/dialogs/ship_editor/basic_properties_panel.tscn

signal properties_updated(property_name: String, new_value: Variant)
signal ship_class_changed(new_class: String, old_class: String)
signal validation_status_changed(is_valid: bool, errors: Array[String])

# Current configuration
var current_config: ShipConfigurationData = null
var asset_registry: RegistryManager = null

# Scene node references (populated by .tscn file)
@onready var ship_name_edit: LineEdit = $VBoxContainer/BasicInfo/ShipNameEdit
@onready var ship_class_option: OptionButton = $VBoxContainer/BasicInfo/ShipClassOption
@onready var alt_class_option: OptionButton = $VBoxContainer/BasicInfo/AltClassOption
@onready var team_spin: SpinBox = $VBoxContainer/BasicInfo/TeamSpin
@onready var hotkey_spin: SpinBox = $VBoxContainer/BasicInfo/HotkeySpin
@onready var persona_spin: SpinBox = $VBoxContainer/BasicInfo/PersonaSpin

@onready var cargo_edit: LineEdit = $VBoxContainer/MissionInfo/CargoEdit
@onready var alt_name_edit: LineEdit = $VBoxContainer/MissionInfo/AltNameEdit
@onready var callsign_edit: LineEdit = $VBoxContainer/MissionInfo/CallsignEdit

@onready var position_x_spin: SpinBox = $VBoxContainer/Transform/Position/XSpin
@onready var position_y_spin: SpinBox = $VBoxContainer/Transform/Position/YSpin
@onready var position_z_spin: SpinBox = $VBoxContainer/Transform/Position/ZSpin

@onready var orientation_x_spin: SpinBox = $VBoxContainer/Transform/Orientation/XSpin
@onready var orientation_y_spin: SpinBox = $VBoxContainer/Transform/Orientation/YSpin
@onready var orientation_z_spin: SpinBox = $VBoxContainer/Transform/Orientation/ZSpin

@onready var hull_spin: SpinBox = $VBoxContainer/Status/InitialHullSpin
@onready var shields_spin: SpinBox = $VBoxContainer/Status/InitialShieldsSpin

@onready var velocity_x_spin: SpinBox = $VBoxContainer/Status/Velocity/XSpin
@onready var velocity_y_spin: SpinBox = $VBoxContainer/Status/Velocity/YSpin
@onready var velocity_z_spin: SpinBox = $VBoxContainer/Status/Velocity/ZSpin

# Validation state
var is_valid: bool = true
var validation_errors: Array[String] = []

func _ready() -> void:
	name = "BasicPropertiesController"
	
	# Initialize asset system integration
	asset_registry = WCSAssetRegistry
	
	# Setup ship class options
	_populate_ship_class_options()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Setup initial validation
	_validate_properties()
	
	print("BasicPropertiesController: Controller initialized")

## Updates the panel with ship configuration data
func update_with_configuration(config: ShipConfigurationData) -> void:
	if not config:
		return
	
	current_config = config
	
	# Update basic info
	ship_name_edit.text = config.ship_name
	_set_ship_class_selection(config.ship_class)
	_set_alt_class_selection(config.alt_class)
	team_spin.value = config.team
	hotkey_spin.value = config.hotkey
	persona_spin.value = config.persona
	
	# Update mission info
	cargo_edit.text = config.cargo
	alt_name_edit.text = config.alt_name
	callsign_edit.text = config.callsign
	
	# Update transform
	position_x_spin.value = config.position.x
	position_y_spin.value = config.position.y
	position_z_spin.value = config.position.z
	
	orientation_x_spin.value = config.orientation.x
	orientation_y_spin.value = config.orientation.y
	orientation_z_spin.value = config.orientation.z
	
	# Update status
	hull_spin.value = config.initial_hull
	shields_spin.value = config.initial_shields
	
	velocity_x_spin.value = config.initial_velocity.x
	velocity_y_spin.value = config.initial_velocity.y
	velocity_z_spin.value = config.initial_velocity.z
	
	# Validate after update
	_validate_properties()

## Populates ship class option buttons with available ship classes
func _populate_ship_class_options() -> void:
	if not asset_registry:
		return
	
	# Get available ship classes from asset system
	var ship_paths: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
	var ship_classes: Array[String] = []
	
	for ship_path in ship_paths:
		var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
		if ship_data and not ship_classes.has(ship_data.ship_class):
			ship_classes.append(ship_data.ship_class)
	
	# Sort ship classes alphabetically
	ship_classes.sort()
	
	# Clear and populate ship class options
	ship_class_option.clear()
	ship_class_option.add_item("(None)", 0)
	
	for i in range(ship_classes.size()):
		ship_class_option.add_item(ship_classes[i], i + 1)
	
	# Populate alt class options (same list)
	alt_class_option.clear()
	alt_class_option.add_item("(None)", 0)
	
	for i in range(ship_classes.size()):
		alt_class_option.add_item(ship_classes[i], i + 1)

## Sets ship class selection in option button
func _set_ship_class_selection(ship_class: String) -> void:
	for i in range(ship_class_option.get_item_count()):
		if ship_class_option.get_item_text(i) == ship_class:
			ship_class_option.selected = i
			return
	
	# Default to None if not found
	ship_class_option.selected = 0

## Sets alt class selection in option button
func _set_alt_class_selection(alt_class: String) -> void:
	for i in range(alt_class_option.get_item_count()):
		if alt_class_option.get_item_text(i) == alt_class:
			alt_class_option.selected = i
			return
	
	# Default to None if not found
	alt_class_option.selected = 0

## Connects all UI signal handlers
func _connect_ui_signals() -> void:
	# Basic info signals
	ship_name_edit.text_changed.connect(_on_ship_name_changed)
	ship_class_option.item_selected.connect(_on_ship_class_selected)
	alt_class_option.item_selected.connect(_on_alt_class_selected)
	team_spin.value_changed.connect(_on_team_changed)
	hotkey_spin.value_changed.connect(_on_hotkey_changed)
	persona_spin.value_changed.connect(_on_persona_changed)
	
	# Mission info signals
	cargo_edit.text_changed.connect(_on_cargo_changed)
	alt_name_edit.text_changed.connect(_on_alt_name_changed)
	callsign_edit.text_changed.connect(_on_callsign_changed)
	
	# Transform signals
	position_x_spin.value_changed.connect(_on_position_x_changed)
	position_y_spin.value_changed.connect(_on_position_y_changed)
	position_z_spin.value_changed.connect(_on_position_z_changed)
	
	orientation_x_spin.value_changed.connect(_on_orientation_x_changed)
	orientation_y_spin.value_changed.connect(_on_orientation_y_changed)
	orientation_z_spin.value_changed.connect(_on_orientation_z_changed)
	
	# Status signals
	hull_spin.value_changed.connect(_on_hull_changed)
	shields_spin.value_changed.connect(_on_shields_changed)
	
	velocity_x_spin.value_changed.connect(_on_velocity_x_changed)
	velocity_y_spin.value_changed.connect(_on_velocity_y_changed)
	velocity_z_spin.value_changed.connect(_on_velocity_z_changed)

## Validates current property values
func _validate_properties() -> void:
	validation_errors.clear()
	
	if not current_config:
		validation_errors.append("No configuration loaded")
		is_valid = false
		validation_status_changed.emit(is_valid, validation_errors)
		return
	
	# Validate ship name
	if current_config.ship_name.is_empty():
		validation_errors.append("Ship name cannot be empty")
	elif current_config.ship_name.length() > 32:
		validation_errors.append("Ship name cannot exceed 32 characters")
	
	# Validate ship class
	if current_config.ship_class.is_empty():
		validation_errors.append("Ship class must be selected")
	
	# Validate team
	if current_config.team < 0 or current_config.team > 99:
		validation_errors.append("Team must be between 0 and 99")
	
	# Validate hotkey
	if current_config.hotkey < -1 or current_config.hotkey > 9:
		validation_errors.append("Hotkey must be between -1 (none) and 9")
	
	# Validate persona
	if current_config.persona < -1 or current_config.persona > 9:
		validation_errors.append("Persona must be between -1 (none) and 9")
	
	# Validate initial values
	if current_config.initial_hull < 0.0:
		validation_errors.append("Initial hull strength cannot be negative")
	
	if current_config.initial_shields < 0.0:
		validation_errors.append("Initial shield strength cannot be negative")
	
	# Validate cargo name
	if current_config.cargo.length() > 64:
		validation_errors.append("Cargo name cannot exceed 64 characters")
	
	# Validate alt name
	if current_config.alt_name.length() > 32:
		validation_errors.append("Alternative name cannot exceed 32 characters")
	
	# Validate callsign
	if current_config.callsign.length() > 16:
		validation_errors.append("Callsign cannot exceed 16 characters")
	
	is_valid = validation_errors.is_empty()
	validation_status_changed.emit(is_valid, validation_errors)

## Updates configuration property and emits signal
func _update_property(property_name: String, new_value: Variant) -> void:
	if not current_config:
		return
	
	current_config.set_property(property_name, new_value)
	properties_updated.emit(property_name, new_value)
	
	# Revalidate after property change
	_validate_properties()

## Signal handlers

func _on_ship_name_changed(new_text: String) -> void:
	_update_property("ship_name", new_text)

func _on_ship_class_selected(index: int) -> void:
	var old_class: String = current_config.ship_class if current_config else ""
	var new_class: String = ship_class_option.get_item_text(index) if index > 0 else ""
	
	_update_property("ship_class", new_class)
	
	if old_class != new_class:
		ship_class_changed.emit(new_class, old_class)
		print("BasicPropertiesController: Ship class changed from '%s' to '%s'" % [old_class, new_class])

func _on_alt_class_selected(index: int) -> void:
	var new_alt_class: String = alt_class_option.get_item_text(index) if index > 0 else ""
	_update_property("alt_class", new_alt_class)

func _on_team_changed(new_value: float) -> void:
	_update_property("team", int(new_value))

func _on_hotkey_changed(new_value: float) -> void:
	_update_property("hotkey", int(new_value))

func _on_persona_changed(new_value: float) -> void:
	_update_property("persona", int(new_value))

func _on_cargo_changed(new_text: String) -> void:
	_update_property("cargo", new_text)

func _on_alt_name_changed(new_text: String) -> void:
	_update_property("alt_name", new_text)

func _on_callsign_changed(new_text: String) -> void:
	_update_property("callsign", new_text)

func _on_position_x_changed(new_value: float) -> void:
	if current_config:
		current_config.position.x = new_value
		_update_property("position", current_config.position)

func _on_position_y_changed(new_value: float) -> void:
	if current_config:
		current_config.position.y = new_value
		_update_property("position", current_config.position)

func _on_position_z_changed(new_value: float) -> void:
	if current_config:
		current_config.position.z = new_value
		_update_property("position", current_config.position)

func _on_orientation_x_changed(new_value: float) -> void:
	if current_config:
		current_config.orientation.x = new_value
		_update_property("orientation", current_config.orientation)

func _on_orientation_y_changed(new_value: float) -> void:
	if current_config:
		current_config.orientation.y = new_value
		_update_property("orientation", current_config.orientation)

func _on_orientation_z_changed(new_value: float) -> void:
	if current_config:
		current_config.orientation.z = new_value
		_update_property("orientation", current_config.orientation)

func _on_hull_changed(new_value: float) -> void:
	_update_property("initial_hull", new_value)

func _on_shields_changed(new_value: float) -> void:
	_update_property("initial_shields", new_value)

func _on_velocity_x_changed(new_value: float) -> void:
	if current_config:
		current_config.initial_velocity.x = new_value
		_update_property("initial_velocity", current_config.initial_velocity)

func _on_velocity_y_changed(new_value: float) -> void:
	if current_config:
		current_config.initial_velocity.y = new_value
		_update_property("initial_velocity", current_config.initial_velocity)

func _on_velocity_z_changed(new_value: float) -> void:
	if current_config:
		current_config.initial_velocity.z = new_value
		_update_property("initial_velocity", current_config.initial_velocity)

## Public API

## Gets current configuration
func get_current_configuration() -> ShipConfigurationData:
	return current_config

## Checks if properties are valid
func is_properties_valid() -> bool:
	return is_valid

## Gets validation errors
func get_validation_errors() -> Array[String]:
	return validation_errors.duplicate()

## Resets properties to default values
func reset_to_defaults() -> void:
	if not current_config:
		return
	
	# Reset basic properties
	current_config.ship_name = ""
	current_config.ship_class = ""
	current_config.alt_class = ""
	current_config.team = 0
	current_config.hotkey = -1
	current_config.persona = -1
	current_config.cargo = ""
	current_config.alt_name = ""
	current_config.callsign = ""
	current_config.position = Vector3.ZERO
	current_config.orientation = Vector3.ZERO
	current_config.initial_hull = 100.0
	current_config.initial_shields = 100.0
	current_config.initial_velocity = Vector3.ZERO
	
	# Update UI to reflect changes
	update_with_configuration(current_config)
	
	print("BasicPropertiesController: Properties reset to defaults")