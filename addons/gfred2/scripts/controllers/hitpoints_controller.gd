@tool
class_name HitpointsController
extends Control

## Hitpoints controller for GFRED2-009 Advanced Ship Configuration.
## Scene-based UI controller for configuring ship hitpoint properties.
## Scene: addons/gfred2/scenes/dialogs/ship_editor/hitpoints_panel.tscn

signal hitpoint_config_updated(property_name: String, new_value: Variant)

# Current hitpoint configuration
var current_hitpoint_config: HitpointConfig = null

# Scene node references
@onready var hull_strength_spin: SpinBox = $VBoxContainer/HullStrengthSpin
@onready var shield_strength_spin: SpinBox = $VBoxContainer/ShieldStrengthSpin
@onready var shield_recharge_spin: SpinBox = $VBoxContainer/ShieldRechargeSpin
@onready var shield_regen_check: CheckBox = $VBoxContainer/ShieldRegenCheck

func _ready() -> void:
	name = "HitpointsController"
	_setup_ui()

func _setup_ui() -> void:
	if hull_strength_spin:
		hull_strength_spin.min_value = 1.0
		hull_strength_spin.max_value = 99999.0
		hull_strength_spin.value_changed.connect(_on_hull_strength_changed)
	
	if shield_strength_spin:
		shield_strength_spin.min_value = 0.0
		shield_strength_spin.max_value = 99999.0
		shield_strength_spin.value_changed.connect(_on_shield_strength_changed)
	
	if shield_recharge_spin:
		shield_recharge_spin.min_value = 0.0
		shield_recharge_spin.max_value = 10.0
		shield_recharge_spin.step = 0.1
		shield_recharge_spin.value_changed.connect(_on_shield_recharge_changed)
	
	if shield_regen_check:
		shield_regen_check.toggled.connect(_on_shield_regen_toggled)

func update_with_hitpoint_config(config: HitpointConfig) -> void:
	if not config:
		return
	
	current_hitpoint_config = config
	
	if hull_strength_spin:
		hull_strength_spin.value = config.hull_strength
	if shield_strength_spin:
		shield_strength_spin.value = config.shield_strength
	if shield_recharge_spin:
		shield_recharge_spin.value = config.shield_recharge_rate
	if shield_regen_check:
		shield_regen_check.button_pressed = config.shield_regeneration

func _on_hull_strength_changed(value: float) -> void:
	if current_hitpoint_config:
		current_hitpoint_config.hull_strength = value
		hitpoint_config_updated.emit("hull_strength", value)

func _on_shield_strength_changed(value: float) -> void:
	if current_hitpoint_config:
		current_hitpoint_config.shield_strength = value
		hitpoint_config_updated.emit("shield_strength", value)

func _on_shield_recharge_changed(value: float) -> void:
	if current_hitpoint_config:
		current_hitpoint_config.shield_recharge_rate = value
		hitpoint_config_updated.emit("shield_recharge_rate", value)

func _on_shield_regen_toggled(enabled: bool) -> void:
	if current_hitpoint_config:
		current_hitpoint_config.shield_regeneration = enabled
		hitpoint_config_updated.emit("shield_regeneration", enabled)

func get_current_hitpoint_config() -> HitpointConfig:
	return current_hitpoint_config