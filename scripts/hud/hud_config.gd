extends Resource
class_name HUDConfig

# HUD gauge flags for showing/hiding elements
@export var show_flags := 0
@export var show_flags2 := 0

# HUD gauge flags for popup behavior
@export var popup_flags := 0
@export var popup_flags2 := 0

# Number of message window lines
@export var num_msg_window_lines := 4

# Radar range flags
@export var rp_flags := 0
@export var rp_dist := 0

# Observer mode flag
@export var is_observer := false

# Main HUD color
@export var main_color := 0

# Individual gauge colors
@export var gauge_colors: Array[Color]

func _init():
	# Initialize default colors for all gauges
	gauge_colors.resize(39) # NUM_HUD_GAUGES
	for i in range(gauge_colors.size()):
		gauge_colors[i] = Color(0, 1, 0, 0.5) # Default green with 0.5 alpha

# Default flags for regular HUD
const DEFAULT_FLAGS = (
	(1 << HUDGauge.GaugeType.LEAD_INDICATOR) |
	(1 << HUDGauge.GaugeType.ORIENTATION_TEE) |
	(1 << HUDGauge.GaugeType.HOSTILE_TRIANGLE) |
	(1 << HUDGauge.GaugeType.TARGET_TRIANGLE) |
	(1 << HUDGauge.GaugeType.MISSION_TIME) |
	(1 << HUDGauge.GaugeType.RETICLE_CIRCLE) |
	(1 << HUDGauge.GaugeType.THROTTLE_GAUGE) |
	(1 << HUDGauge.GaugeType.RADAR) |
	(1 << HUDGauge.GaugeType.TARGET_MONITOR) |
	(1 << HUDGauge.GaugeType.CENTER_RETICLE) |
	(1 << HUDGauge.GaugeType.TARGET_MONITOR_EXTRA_DATA) |
	(1 << HUDGauge.GaugeType.TARGET_SHIELD_ICON) |
	(1 << HUDGauge.GaugeType.PLAYER_SHIELD_ICON) |
	(1 << HUDGauge.GaugeType.ETS_GAUGE) |
	(1 << HUDGauge.GaugeType.AUTO_TARGET) |
	(1 << HUDGauge.GaugeType.AUTO_SPEED) |
	(1 << HUDGauge.GaugeType.WEAPONS_GAUGE) |
	(1 << HUDGauge.GaugeType.ESCORT_VIEW) |
	(1 << HUDGauge.GaugeType.DIRECTIVES_VIEW) |
	(1 << HUDGauge.GaugeType.THREAT_GAUGE) |
	(1 << HUDGauge.GaugeType.AFTERBURNER_ENERGY) |
	(1 << HUDGauge.GaugeType.WEAPONS_ENERGY) |
	(1 << HUDGauge.GaugeType.WEAPON_LINKING_GAUGE) |
	(1 << HUDGauge.GaugeType.TARGET_MINI_ICON) |
	(1 << HUDGauge.GaugeType.OFFSCREEN_INDICATOR) |
	(1 << HUDGauge.GaugeType.TALKING_HEAD) |
	(1 << HUDGauge.GaugeType.DAMAGE_GAUGE) |
	(1 << HUDGauge.GaugeType.MESSAGE_LINES) |
	(1 << HUDGauge.GaugeType.MISSILE_WARNING_ARROW) |
	(1 << HUDGauge.GaugeType.CMEASURE_GAUGE) |
	(1 << HUDGauge.GaugeType.OBJECTIVES_NOTIFY_GAUGE) |
	(1 << HUDGauge.GaugeType.WINGMEN_STATUS)
)

const DEFAULT_FLAGS2 = (
	(1 << (HUDGauge.GaugeType.OFFSCREEN_RANGE - 32)) |
	(1 << (HUDGauge.GaugeType.KILLS_GAUGE - 32)) |
	(1 << (HUDGauge.GaugeType.ATTACKING_TARGET_COUNT - 32)) |
	(1 << (HUDGauge.GaugeType.SUPPORT_GAUGE - 32)) |
	(1 << (HUDGauge.GaugeType.LAG_GAUGE - 32))
)

# Default flags for observer HUD
const OBSERVER_FLAGS = (
	(1 << HUDGauge.GaugeType.CENTER_RETICLE) |
	(1 << HUDGauge.GaugeType.OFFSCREEN_INDICATOR) |
	(1 << HUDGauge.GaugeType.MESSAGE_LINES) |
	(1 << HUDGauge.GaugeType.HOSTILE_TRIANGLE) |
	(1 << HUDGauge.GaugeType.TARGET_TRIANGLE) |
	(1 << HUDGauge.GaugeType.TARGET_MINI_ICON) |
	(1 << HUDGauge.GaugeType.TARGET_MONITOR)
)

const OBSERVER_FLAGS2 = (
	(1 << (HUDGauge.GaugeType.OFFSCREEN_RANGE - 32))
)

func reset_to_defaults():
	show_flags = DEFAULT_FLAGS
	show_flags2 = DEFAULT_FLAGS2
	popup_flags = 0
	popup_flags2 = 0
	num_msg_window_lines = 4
	rp_flags = 0
	rp_dist = 0
	is_observer = false
	main_color = 0
	
	# Reset all gauge colors to default
	for i in range(gauge_colors.size()):
		gauge_colors[i] = Color(0, 1, 0, 0.5)

func set_observer_mode():
	show_flags = OBSERVER_FLAGS
	show_flags2 = OBSERVER_FLAGS2
	popup_flags = 0
	popup_flags2 = 0
	is_observer = true

func is_gauge_visible(gauge_index: int) -> bool:
	if gauge_index < 32:
		return (show_flags & (1 << gauge_index)) != 0
	else:
		return (show_flags2 & (1 << (gauge_index - 32))) != 0

func set_gauge_visible(gauge_index: int, visible: bool):
	if gauge_index < 32:
		if visible:
			show_flags |= (1 << gauge_index)
		else:
			show_flags &= ~(1 << gauge_index)
	else:
		if visible:
			show_flags2 |= (1 << (gauge_index - 32))
		else:
			show_flags2 &= ~(1 << (gauge_index - 32))

func is_gauge_popup(gauge_index: int) -> bool:
	if gauge_index < 32:
		return (popup_flags & (1 << gauge_index)) != 0
	else:
		return (popup_flags2 & (1 << (gauge_index - 32))) != 0

func set_gauge_popup(gauge_index: int, popup: bool):
	if gauge_index < 32:
		if popup:
			popup_flags |= (1 << gauge_index)
		else:
			popup_flags &= ~(1 << gauge_index)
	else:
		if popup:
			popup_flags2 |= (1 << (gauge_index - 32))
		else:
			popup_flags2 &= ~(1 << (gauge_index - 32))
