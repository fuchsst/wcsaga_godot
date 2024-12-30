@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

var special_exp_enabled := false
var shock_enabled := false
var inner_rad := 100
var outer_rad := 200
var damage := 100
var blast := 50
var shock_speed := 10

@onready var enable_special_exp_check: CheckBox = get_content_container().get_node("EnableContainer/EnableSpecialExpCheck")
@onready var enable_shockwave_check: CheckBox = get_content_container().get_node("EnableContainer/EnableShockwaveCheck")
@onready var inner_rad_spin: SpinBox = get_content_container().get_node("ExplosionContainer/InnerRadSpin")
@onready var outer_rad_spin: SpinBox = get_content_container().get_node("ExplosionContainer/OuterRadSpin")
@onready var damage_spin: SpinBox = get_content_container().get_node("ExplosionContainer/DamageSpin")
@onready var blast_spin: SpinBox = get_content_container().get_node("ExplosionContainer/BlastSpin")
@onready var shock_speed_spin: SpinBox = get_content_container().get_node("ExplosionContainer/ShockSpeedSpin")

func _ready():
	super._ready()
	title = "Special Damage"
	
	# Connect signals
	enable_special_exp_check.toggled.connect(_on_special_exp_toggled)
	enable_shockwave_check.toggled.connect(_on_shockwave_toggled)
	inner_rad_spin.value_changed.connect(_on_inner_rad_changed)
	outer_rad_spin.value_changed.connect(_on_outer_rad_changed)
	damage_spin.value_changed.connect(_on_damage_changed)
	blast_spin.value_changed.connect(_on_blast_changed)
	shock_speed_spin.value_changed.connect(_on_shock_speed_changed)
	
	# Set initial values
	enable_special_exp_check.button_pressed = special_exp_enabled
	enable_shockwave_check.button_pressed = shock_enabled
	inner_rad_spin.value = inner_rad
	outer_rad_spin.value = outer_rad
	damage_spin.value = damage
	blast_spin.value = blast
	shock_speed_spin.value = shock_speed
	
	# Update UI state
	_update_ui()

func _update_ui():
	var enabled = enable_special_exp_check.button_pressed
	inner_rad_spin.editable = enabled
	outer_rad_spin.editable = enabled
	damage_spin.editable = enabled
	blast_spin.editable = enabled
	enable_shockwave_check.disabled = !enabled
	shock_speed_spin.editable = enabled && enable_shockwave_check.button_pressed

func _on_special_exp_toggled(pressed: bool):
	special_exp_enabled = pressed
	_update_ui()

func _on_shockwave_toggled(pressed: bool):
	shock_enabled = pressed
	_update_ui()

func _on_inner_rad_changed(value: float):
	inner_rad = int(value)
	if inner_rad >= outer_rad:
		outer_rad_spin.value = inner_rad + 1

func _on_outer_rad_changed(value: float):
	outer_rad = int(value)
	if outer_rad <= inner_rad:
		inner_rad_spin.value = outer_rad - 1

func _on_damage_changed(value: float):
	damage = int(value)

func _on_blast_changed(value: float):
	blast = int(value)

func _on_shock_speed_changed(value: float):
	shock_speed = int(value)
