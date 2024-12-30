@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

var special_hitpoints_enabled := false
var special_shield_enabled := false
var hitpoints := 100
var shield_strength := 100
var shield_regen := 1.0

@onready var enable_hitpoints_check: CheckBox = get_content_container().get_node("EnableContainer/EnableSpecialHitpointsCheck")
@onready var enable_shield_check: CheckBox = get_content_container().get_node("EnableContainer/EnableSpecialShieldCheck")
@onready var hitpoints_spin: SpinBox = get_content_container().get_node("HitpointsContainer/HitpointsSpin")
@onready var shields_spin: SpinBox = get_content_container().get_node("ShieldsContainer/ShieldsSpin")
@onready var shield_regen_spin: SpinBox = get_content_container().get_node("ShieldsContainer/ShieldRegenSpin")

func _ready():
	super._ready()
	title = "Special Hitpoints"
	
	# Connect signals
	enable_hitpoints_check.toggled.connect(_on_hitpoints_toggled)
	enable_shield_check.toggled.connect(_on_shield_toggled)
	hitpoints_spin.value_changed.connect(_on_hitpoints_changed)
	shields_spin.value_changed.connect(_on_shields_changed)
	shield_regen_spin.value_changed.connect(_on_shield_regen_changed)
	
	# Set initial values
	enable_hitpoints_check.button_pressed = special_hitpoints_enabled
	enable_shield_check.button_pressed = special_shield_enabled
	hitpoints_spin.value = hitpoints
	shields_spin.value = shield_strength
	shield_regen_spin.value = shield_regen
	
	# Update UI state
	_update_ui()

func _update_ui():
	hitpoints_spin.editable = enable_hitpoints_check.button_pressed
	shields_spin.editable = enable_shield_check.button_pressed
	shield_regen_spin.editable = enable_shield_check.button_pressed

func _on_hitpoints_toggled(pressed: bool):
	special_hitpoints_enabled = pressed
	_update_ui()

func _on_shield_toggled(pressed: bool):
	special_shield_enabled = pressed
	_update_ui()

func _on_hitpoints_changed(value: float):
	hitpoints = int(value)

func _on_shields_changed(value: float):
	shield_strength = int(value)

func _on_shield_regen_changed(value: float):
	shield_regen = value
