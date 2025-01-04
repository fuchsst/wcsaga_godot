@tool
extends Node2D
class_name HUDGauge

# Gauge types matching original implementation
enum GaugeType {
	EMPTY = 0,
	LEAD_INDICATOR = 1,
	ORIENTATION_TEE = 2,
	HOSTILE_TRIANGLE = 3,
	TARGET_TRIANGLE = 4,
	MISSION_TIME = 5,
	RETICLE_CIRCLE = 6,
	THROTTLE_GAUGE = 7,
	RADAR = 8,
	TARGET_MONITOR = 9,
	CENTER_RETICLE = 10,
	TARGET_MONITOR_EXTRA_DATA = 11,
	TARGET_SHIELD_ICON = 12,
	PLAYER_SHIELD_ICON = 13,
	ETS_GAUGE = 14,
	AUTO_TARGET = 15,
	AUTO_SPEED = 16,
	WEAPONS_GAUGE = 17,
	ESCORT_VIEW = 18,
	DIRECTIVES_VIEW = 19,
	THREAT_GAUGE = 20,
	AFTERBURNER_ENERGY = 21,
	WEAPONS_ENERGY = 22,
	WEAPON_LINKING_GAUGE = 23,
	TARGET_MINI_ICON = 24,
	OFFSCREEN_INDICATOR = 25,
	TALKING_HEAD = 26,
	DAMAGE_GAUGE = 27,
	MESSAGE_LINES = 28,
	MISSILE_WARNING_ARROW = 29,
	CMEASURE_GAUGE = 30,
	OBJECTIVES_NOTIFY_GAUGE = 31,
	WINGMEN_STATUS = 32,
	OFFSCREEN_RANGE = 33,
	KILLS_GAUGE = 34,
	ATTACKING_TARGET_COUNT = 35,
	TEXT_FLASH = 36,
	MESSAGE_BOX = 37,
	SUPPORT_GAUGE = 38,
	LAG_GAUGE = 39
}

# Gauge state
@export var gauge_id: GaugeType = GaugeType.EMPTY
@export var is_visible := true
@export var is_popup := false
@export var base_alpha := 0.8
@export var bright_alpha := 1.0
@export var dim_alpha := 0.5

# Internal state
var popup_duration := 0.0
var popup_start_time := 0.0
var flash_duration := 0.0
var flash_interval := 0.0
var flash_next_time := 0.0
var is_flashing := false
var is_bright := false

# Colors
@export var base_color := Color(0, 1, 0, 0.8) # Default green
var bright_color := Color(0, 1, 0, 1.0)
var dim_color := Color(0, 1, 0, 0.5)

# Constants
const FLASH_DURATION := 5.0
const FLASH_INTERVAL := 0.2
const POPUP_DEFAULT_DURATION := 4.0

func _init() -> void:
	# Enable processing in editor for preview
	set_process(true)
	if Engine.is_editor_hint():
		process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	# Initialize gauge state
	reset()
	queue_redraw()

func reset() -> void:
	is_visible = true
	is_popup = false
	popup_duration = 0.0
	popup_start_time = 0.0
	flash_duration = 0.0
	flash_interval = 0.0
	flash_next_time = 0.0
	is_flashing = false
	is_bright = false
	queue_redraw()

func set_color(color: Color) -> void:
	base_color = color
	bright_color = Color(color.r, color.g, color.b, bright_alpha)
	dim_color = Color(color.r, color.g, color.b, dim_alpha)
	queue_redraw()

func set_alpha_levels(normal: float, bright: float, dim: float) -> void:
	base_alpha = normal
	bright_alpha = bright
	dim_alpha = dim
	# Update colors with new alpha
	set_color(base_color)

func start_flash(duration: float = FLASH_DURATION, interval: float = FLASH_INTERVAL) -> void:
	flash_duration = duration
	flash_interval = interval
	flash_next_time = Time.get_ticks_msec() + (interval * 1000)
	is_flashing = true
	queue_redraw()

func stop_flash() -> void:
	is_flashing = false
	is_bright = false
	queue_redraw()

func start_popup(duration: float = POPUP_DEFAULT_DURATION) -> void:
	if is_popup:
		popup_duration = duration
		popup_start_time = Time.get_ticks_msec()
		is_visible = true
		queue_redraw()

func is_popup_active() -> bool:
	if !is_popup:
		return false
	if popup_duration > 0:
		var current_time = Time.get_ticks_msec()
		return (current_time - popup_start_time) < (popup_duration * 1000)
	return false

func update_flash(delta: float) -> void:
	if !is_flashing:
		return
		
	var current_time = Time.get_ticks_msec()
	
	# Check flash duration
	if flash_duration > 0:
		if current_time > (popup_start_time + (flash_duration * 1000)):
			stop_flash()
			return
			
	# Update flash state
	if current_time > flash_next_time:
		is_bright = !is_bright
		flash_next_time = current_time + (flash_interval * 1000)
		queue_redraw()

func get_current_color() -> Color:
	if is_flashing:
		return bright_color if is_bright else dim_color
	return base_color

func can_draw() -> bool:
	if !is_visible:
		return false
	if is_popup && !is_popup_active():
		return false
	return true

func _process(delta: float) -> void:
	update_flash(delta)
	
	# Force redraw in editor for preview
	if Engine.is_editor_hint():
		queue_redraw()

# Virtual method to be overridden by gauge implementations
func update_from_game_state() -> void:
	pass

# Editor preview - draw gauge name and bounds
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw bounding box
		var rect = Rect2(Vector2.ZERO, Vector2(100, 100))
		draw_rect(rect, Color(1, 1, 1, 0.2), false)
		
		# Draw gauge name
		if gauge_id != GaugeType.EMPTY:
			var text = _get_gauge_name(gauge_id)
			var font = ThemeDB.fallback_font
			var font_size = ThemeDB.fallback_font_size
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, Vector2(5, text_size.y + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

# Get gauge name for display
func _get_gauge_name(id: int) -> String:
	match id:
		GaugeType.LEAD_INDICATOR: return "Lead Indicator"
		GaugeType.ORIENTATION_TEE: return "Target Orientation"
		GaugeType.HOSTILE_TRIANGLE: return "Closest Attacking Hostile"
		GaugeType.TARGET_TRIANGLE: return "Current Target Direction"
		GaugeType.MISSION_TIME: return "Mission Time"
		GaugeType.RETICLE_CIRCLE: return "Reticle"
		GaugeType.THROTTLE_GAUGE: return "Throttle"
		GaugeType.RADAR: return "Radar"
		GaugeType.TARGET_MONITOR: return "Target Monitor"
		GaugeType.CENTER_RETICLE: return "Center of Reticle"
		GaugeType.TARGET_MONITOR_EXTRA_DATA: return "Extra Target Info"
		GaugeType.TARGET_SHIELD_ICON: return "Target Shield"
		GaugeType.PLAYER_SHIELD_ICON: return "Player Shield"
		GaugeType.ETS_GAUGE: return "Power Management"
		GaugeType.AUTO_TARGET: return "Auto-target Icon"
		GaugeType.AUTO_SPEED: return "Auto-speed-match Icon"
		GaugeType.WEAPONS_GAUGE: return "Weapons Display"
		GaugeType.ESCORT_VIEW: return "Monitoring View"
		GaugeType.DIRECTIVES_VIEW: return "Directives View"
		GaugeType.THREAT_GAUGE: return "Threat Gauge"
		GaugeType.AFTERBURNER_ENERGY: return "Afterburner Energy"
		GaugeType.WEAPONS_ENERGY: return "Weapons Energy"
		GaugeType.WEAPON_LINKING_GAUGE: return "Weapon Linking"
		GaugeType.TARGET_MINI_ICON: return "Target Hull/Shield Icon"
		GaugeType.OFFSCREEN_INDICATOR: return "Offscreen Indicator"
		GaugeType.TALKING_HEAD: return "Comm Video"
		GaugeType.DAMAGE_GAUGE: return "Damage Display"
		GaugeType.MESSAGE_LINES: return "Message Output"
		GaugeType.MISSILE_WARNING_ARROW: return "Locked Missile Direction"
		GaugeType.CMEASURE_GAUGE: return "Countermeasures"
		GaugeType.OBJECTIVES_NOTIFY_GAUGE: return "Objective Notify"
		GaugeType.WINGMEN_STATUS: return "Wingmen Status"
		GaugeType.OFFSCREEN_RANGE: return "Offscreen Range"
		GaugeType.KILLS_GAUGE: return "Kills Gauge"
		GaugeType.ATTACKING_TARGET_COUNT: return "Attacking Target Count"
		GaugeType.TEXT_FLASH: return "Warning Flash"
		GaugeType.MESSAGE_BOX: return "Message Box"
		GaugeType.SUPPORT_GAUGE: return "Support Gauge"
		GaugeType.LAG_GAUGE: return "Lag Gauge"
		_: return "Unknown Gauge"

# Check if this gauge type can be set to popup mode
static func can_popup(gauge: GaugeType) -> bool:
	match gauge:
		GaugeType.WEAPONS_GAUGE, GaugeType.ESCORT_VIEW, GaugeType.DIRECTIVES_VIEW, GaugeType.THREAT_GAUGE, GaugeType.DAMAGE_GAUGE, GaugeType.KILLS_GAUGE, GaugeType.SUPPORT_GAUGE, GaugeType.LAG_GAUGE:
			return true
		_:
			return false
