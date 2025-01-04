@tool
extends Node2D
class_name HUDGauge

# Gauge types/IDs matching original implementation
enum {
	LEAD_INDICATOR,
	ORIENTATION_TEE, 
	HOSTILE_TRIANGLE,
	TARGET_TRIANGLE,
	MISSION_TIME,
	RETICLE_CIRCLE,
	THROTTLE_GAUGE,
	RADAR,
	TARGET_MONITOR,
	CENTER_RETICLE,
	TARGET_MONITOR_EXTRA_DATA,
	TARGET_SHIELD_ICON,
	PLAYER_SHIELD_ICON,
	ETS_GAUGE,
	AUTO_TARGET,
	AUTO_SPEED,
	WEAPONS_GAUGE,
	ESCORT_VIEW,
	DIRECTIVES_VIEW,
	THREAT_GAUGE,
	AFTERBURNER_ENERGY,
	WEAPONS_ENERGY,
	WEAPON_LINKING_GAUGE,
	TARGET_MINI_ICON,
	OFFSCREEN_INDICATOR,
	TALKING_HEAD,
	DAMAGE_GAUGE,
	MESSAGE_LINES,
	MISSILE_WARNING_ARROW,
	CMEASURE_GAUGE,
	OBJECTIVES_NOTIFY_GAUGE,
	WINGMEN_STATUS,
	OFFSCREEN_RANGE,
	KILLS_GAUGE,
	ATTACKING_TARGET_COUNT,
	TEXT_FLASH,
	MESSAGE_BOX,
	SUPPORT_GAUGE,
	LAG_GAUGE
}

# Gauge names for display/config
static var GAUGE_NAMES = {
	LEAD_INDICATOR: "Lead Indicator",
	ORIENTATION_TEE: "Target Orientation",
	HOSTILE_TRIANGLE: "Closest Attacking Hostile",
	TARGET_TRIANGLE: "Current Target Direction",
	MISSION_TIME: "Mission Time",
	RETICLE_CIRCLE: "Reticle",
	THROTTLE_GAUGE: "Throttle",
	RADAR: "Radar",
	TARGET_MONITOR: "Target Monitor",
	CENTER_RETICLE: "Center of Reticle",
	TARGET_MONITOR_EXTRA_DATA: "Extra Target Info",
	TARGET_SHIELD_ICON: "Target Shield",
	PLAYER_SHIELD_ICON: "Player Shield",
	ETS_GAUGE: "Power Management",
	AUTO_TARGET: "Auto-target Icon",
	AUTO_SPEED: "Auto-speed-match Icon",
	WEAPONS_GAUGE: "Weapons Display",
	ESCORT_VIEW: "Monitoring View",
	DIRECTIVES_VIEW: "Directives View",
	THREAT_GAUGE: "Threat Gauge",
	AFTERBURNER_ENERGY: "Afterburner Energy",
	WEAPONS_ENERGY: "Weapons Energy",
	WEAPON_LINKING_GAUGE: "Weapon Linking",
	TARGET_MINI_ICON: "Target Hull/Shield Icon",
	OFFSCREEN_INDICATOR: "Offscreen Indicator",
	TALKING_HEAD: "Comm Video",
	DAMAGE_GAUGE: "Damage Display",
	MESSAGE_LINES: "Message Output",
	MISSILE_WARNING_ARROW: "Locked Missile Direction",
	CMEASURE_GAUGE: "Countermeasures",
	OBJECTIVES_NOTIFY_GAUGE: "Objective Notify",
	WINGMEN_STATUS: "Wingmen Status",
	OFFSCREEN_RANGE: "Offscreen Range",
	KILLS_GAUGE: "Kills Gauge",
	ATTACKING_TARGET_COUNT: "Attacking Target Count",
	TEXT_FLASH: "Warning Flash",
	MESSAGE_BOX: "Message Box",
	SUPPORT_GAUGE: "Support Gauge",
	LAG_GAUGE: "Lag Gauge"
}

# Gauge state
@export var gauge_id: int = -1
@export var is_visible: bool = true
@export var is_popup: bool = false
@export var base_alpha: float = 0.8
@export var bright_alpha: float = 1.0
@export var dim_alpha: float = 0.5

# Internal state
var popup_duration: float = 0.0
var popup_start_time: float = 0.0
var flash_duration: float = 0.0
var flash_interval: float = 0.0
var flash_next_time: float = 0.0
var is_flashing: bool = false
var is_bright: bool = false

# Colors
@export var base_color: Color = Color(0, 1, 0, 0.8) # Default green
var bright_color: Color = Color(0, 1, 0, 1.0)
var dim_color: Color = Color(0, 1, 0, 0.5)

# Constants
const FLASH_DURATION: float = 5.0
const FLASH_INTERVAL: float = 0.2
const POPUP_DEFAULT_DURATION: float = 4.0

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

# Get whether this gauge type can be set to popup mode
static func can_popup(gauge: int) -> bool:
	match gauge:
		WEAPONS_GAUGE, ESCORT_VIEW, DIRECTIVES_VIEW, THREAT_GAUGE, DAMAGE_GAUGE, KILLS_GAUGE, SUPPORT_GAUGE, LAG_GAUGE:
			return true
		_:
			return false

# Editor preview - draw gauge name and bounds
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw bounding box
		var rect = Rect2(Vector2.ZERO, Vector2(100, 100))
		draw_rect(rect, Color(1, 1, 1, 0.2), false)
		
		# Draw gauge name
		if gauge_id >= 0 && GAUGE_NAMES.has(gauge_id):
			var font = ThemeDB.fallback_font
			var font_size = ThemeDB.fallback_font_size
			var text = GAUGE_NAMES[gauge_id]
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, Vector2(5, text_size.y + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
