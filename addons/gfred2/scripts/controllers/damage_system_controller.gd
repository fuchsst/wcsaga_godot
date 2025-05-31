@tool
class_name DamageSystemController
extends Control

## Damage system controller for GFRED2-009 Advanced Ship Configuration.
## Scene-based UI controller for configuring ship damage properties.
## Scene: addons/gfred2/scenes/dialogs/ship_editor/damage_system_panel.tscn

signal damage_config_updated(property_name: String, new_value: Variant)

# Current damage configuration
var current_damage_config: DamageSystemConfig = null

# Scene node references
@onready var damage_multiplier_spin: SpinBox = $VBoxContainer/DamageMultiplierSpin
@onready var explosion_index_spin: SpinBox = $VBoxContainer/ExplosionIndexSpin
@onready var subsystem_tree: Tree = $VBoxContainer/SubsystemTree

func _ready() -> void:
	name = "DamageSystemController"
	_setup_ui()

func _setup_ui() -> void:
	if damage_multiplier_spin:
		damage_multiplier_spin.min_value = 0.0
		damage_multiplier_spin.max_value = 10.0
		damage_multiplier_spin.step = 0.1
		damage_multiplier_spin.value_changed.connect(_on_damage_multiplier_changed)
	
	if explosion_index_spin:
		explosion_index_spin.min_value = -1
		explosion_index_spin.max_value = 100
		explosion_index_spin.value_changed.connect(_on_explosion_index_changed)

func update_with_damage_config(config: DamageSystemConfig) -> void:
	if not config:
		return
	
	current_damage_config = config
	
	if damage_multiplier_spin:
		damage_multiplier_spin.value = config.damage_multiplier
	if explosion_index_spin:
		explosion_index_spin.value = config.special_explosion_index

func _on_damage_multiplier_changed(value: float) -> void:
	if current_damage_config:
		current_damage_config.damage_multiplier = value
		damage_config_updated.emit("damage_multiplier", value)

func _on_explosion_index_changed(value: float) -> void:
	if current_damage_config:
		current_damage_config.special_explosion_index = int(value)
		damage_config_updated.emit("special_explosion_index", int(value))

func get_current_damage_config() -> DamageSystemConfig:
	return current_damage_config