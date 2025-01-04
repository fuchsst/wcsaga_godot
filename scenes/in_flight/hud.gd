extends Node2D
class_name HUD

# HUD configuration resource
@export var hud_config: HUDConfig

# Current HUD state
var is_observer := false

func _ready() -> void:
	# Load HUD config
	if not hud_config:
		hud_config = load("user://hud_config.tres")
	if not hud_config:
		hud_config = load("res://resources/hud/default1.tres")
		
	# Apply config to all gauge nodes
	_apply_hud_config()

func _apply_hud_config() -> void:
	# Apply HUD configuration to all gauges
	for gauge in get_children():
		if gauge is HUDGauge:
			var gauge_id = gauge.gauge_id
			gauge.is_visible = hud_config.is_gauge_visible(gauge_id)
			gauge.is_popup = hud_config.is_gauge_popup(gauge_id)
			gauge.set_color(hud_config.gauge_colors[gauge_id])

func set_observer_mode(enabled: bool) -> void:
	# Toggle observer mode
	if enabled == is_observer:
		return
		
	is_observer = enabled
	if enabled:
		hud_config.set_observer_mode()
	else:
		hud_config.reset_to_defaults()
		
	_apply_hud_config()

func _process(_delta: float) -> void:
	# Update gauges that need per-frame updates
	if is_observer:
		return
		
	# Update gauges based on current game state
	for gauge in get_children():
		if gauge is HUDGauge and gauge.is_visible:
			gauge.update_from_game_state()
