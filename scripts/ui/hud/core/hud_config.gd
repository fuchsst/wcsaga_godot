class_name HUDConfig
extends HUDConfiguration

## Extended HUD Configuration with gauge flags and advanced settings
## Builds upon the base HUDConfiguration with WCS-specific gauge management

# HUD Gauge Visibility Flags (WCS compatibility)
const GAUGE_SPEED: int = 1 << 0
const GAUGE_WEAPONS: int = 1 << 1
const GAUGE_OBJECTIVES: int = 1 << 2
const GAUGE_TARGET_BOX: int = 1 << 3
const GAUGE_TARGET_SHIELD: int = 1 << 4
const GAUGE_PLAYER_SHIELD: int = 1 << 5
const GAUGE_AFTERBURNER: int = 1 << 6
const GAUGE_WEAPON_ENERGY: int = 1 << 7
const GAUGE_AUTO_SPEED: int = 1 << 8
const GAUGE_AUTO_TARGET: int = 1 << 9
const GAUGE_CMEASURE: int = 1 << 10
const GAUGE_TALKING_HEAD: int = 1 << 11
const GAUGE_DAMAGE: int = 1 << 12
const GAUGE_MESSAGE_LINES: int = 1 << 13
const GAUGE_RADAR: int = 1 << 14
const GAUGE_ESCORT: int = 1 << 15
const GAUGE_DIRECTIVES: int = 1 << 16
const GAUGE_THREAT: int = 1 << 17
const GAUGE_LEAD: int = 1 << 18
const GAUGE_LOCK: int = 1 << 19
const GAUGE_LEAD_SIGHT: int = 1 << 20
const GAUGE_ORIENTATION_TEE: int = 1 << 21
const GAUGE_SQUADMSG: int = 1 << 22
const GAUGE_LAG: int = 1 << 23
const GAUGE_MINI_TARGET_BOX: int = 1 << 24
const GAUGE_OFFSCREEN: int = 1 << 25
const GAUGE_BRACKETS: int = 1 << 26
const GAUGE_WEAPON_LINKING: int = 1 << 27
const GAUGE_THROTTLE: int = 1 << 28
const GAUGE_RADAR_INTEGRITY: int = 1 << 29
const GAUGE_COUNTERMEASURES: int = 1 << 30
const GAUGE_WINGMAN_STATUS: int = 1 << 31
const GAUGE_KILL_GAUGE: int = 1 << 32
const GAUGE_TEXT_WARNINGS: int = 1 << 33
const GAUGE_CENTER_RETICLE: int = 1 << 34
const GAUGE_NAVIGATION: int = 1 << 35
const GAUGE_MISSION_TIME: int = 1 << 36
const GAUGE_FLIGHT_PATH: int = 1 << 37
const GAUGE_WARHEAD_COUNT: int = 1 << 38
const GAUGE_SUPPORT_VIEW: int = 1 << 39

# Default visibility flags (essential elements)
const DEFAULT_FLAGS: int = (
	GAUGE_SPEED |
	GAUGE_WEAPONS |
	GAUGE_OBJECTIVES |
	GAUGE_TARGET_BOX |
	GAUGE_TARGET_SHIELD |
	GAUGE_PLAYER_SHIELD |
	GAUGE_AFTERBURNER |
	GAUGE_WEAPON_ENERGY |
	GAUGE_AUTO_SPEED |
	GAUGE_AUTO_TARGET |
	GAUGE_CMEASURE |
	GAUGE_TALKING_HEAD |
	GAUGE_DAMAGE |
	GAUGE_MESSAGE_LINES |
	GAUGE_RADAR |
	GAUGE_ESCORT |
	GAUGE_DIRECTIVES |
	GAUGE_THREAT |
	GAUGE_LEAD |
	GAUGE_LOCK |
	GAUGE_LEAD_SIGHT |
	GAUGE_ORIENTATION_TEE
)

# Observer mode flags (minimal for spectating)
const OBSERVER_FLAGS: int = (
	GAUGE_TARGET_BOX |
	GAUGE_TARGET_SHIELD |
	GAUGE_OBJECTIVES |
	GAUGE_MESSAGE_LINES |
	GAUGE_RADAR |
	GAUGE_ESCORT
)

# Extended HUD configuration
@export var gauge_visibility_flags: int = DEFAULT_FLAGS
@export var layout_preset: String = "standard"
@export var color_scheme: String = "green"
@export var element_positions: Dictionary = {}
@export var custom_colors: Dictionary = {}
@export var alpha_multiplier: float = 0.8

# Configuration metadata
@export var config_version: String = "1.0.0"
@export var last_saved: String = ""
@export var migration_history: Array[Dictionary] = []

func _init() -> void:
	super._init()
	_initialize_extended_settings()

## Initialize extended HUD settings
func _initialize_extended_settings() -> void:
	gauge_visibility_flags = DEFAULT_FLAGS
	layout_preset = "standard"
	color_scheme = "green"
	element_positions = {}
	custom_colors = {}
	alpha_multiplier = 0.8

## Check if specific gauge is visible
func is_gauge_visible(gauge_flag: int) -> bool:
	return (gauge_visibility_flags & gauge_flag) != 0

## Set gauge visibility
func set_gauge_visible(gauge_flag: int, visible: bool) -> void:
	if visible:
		gauge_visibility_flags |= gauge_flag
	else:
		gauge_visibility_flags &= ~gauge_flag

## Get visible gauge count
func get_visible_gauge_count() -> int:
	var count = 0
	var flags = gauge_visibility_flags
	while flags > 0:
		if (flags & 1) != 0:
			count += 1
		flags >>= 1
	return count

## Reset gauge visibility to defaults
func reset_gauge_visibility() -> void:
	gauge_visibility_flags = DEFAULT_FLAGS

## Enable minimal gauge set
func set_minimal_gauge_visibility() -> void:
	gauge_visibility_flags = (
		GAUGE_SPEED |
		GAUGE_TARGET_BOX |
		GAUGE_PLAYER_SHIELD |
		GAUGE_WEAPONS |
		GAUGE_RADAR
	)

## Enable observer mode gauges
func set_observer_gauge_visibility() -> void:
	gauge_visibility_flags = OBSERVER_FLAGS

## Get gauge visibility summary
func get_gauge_visibility_summary() -> Dictionary:
	return {
		"total_gauges": 40,
		"visible_gauges": get_visible_gauge_count(),
		"visibility_percentage": (float(get_visible_gauge_count()) / 40.0) * 100.0,
		"flags": gauge_visibility_flags,
		"preset_mode": _detect_preset_mode()
	}

## Detect current preset mode based on flags
func _detect_preset_mode() -> String:
	if gauge_visibility_flags == DEFAULT_FLAGS:
		return "default"
	elif gauge_visibility_flags == OBSERVER_FLAGS:
		return "observer"
	elif get_visible_gauge_count() <= 8:
		return "minimal"
	else:
		return "custom"

## Validate extended configuration
func validate_extended_configuration() -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Validate gauge flags
	if gauge_visibility_flags < 0:
		result.errors.append("Invalid gauge visibility flags")
		result.is_valid = false
	
	# Validate layout preset
	if layout_preset.is_empty():
		result.errors.append("Layout preset cannot be empty")
		result.is_valid = false
	
	# Validate color scheme
	if color_scheme.is_empty():
		result.errors.append("Color scheme cannot be empty")
		result.is_valid = false
	
	# Validate alpha multiplier
	if alpha_multiplier < 0.0 or alpha_multiplier > 1.0:
		result.warnings.append("Alpha multiplier should be between 0.0 and 1.0")
		alpha_multiplier = clampf(alpha_multiplier, 0.0, 1.0)
	
	# Validate element positions
	if element_positions is Dictionary:
		for element_id in element_positions:
			var pos_data = element_positions[element_id]
			if not (pos_data is Dictionary):
				result.warnings.append("Invalid position data for element: %s" % element_id)
	
	return result

## Export extended configuration
func export_extended_configuration() -> Dictionary:
	var base_config = export_configuration()
	base_config["extended"] = {
		"gauge_visibility_flags": gauge_visibility_flags,
		"layout_preset": layout_preset,
		"color_scheme": color_scheme,
		"element_positions": element_positions,
		"custom_colors": custom_colors,
		"alpha_multiplier": alpha_multiplier,
		"gauge_summary": get_gauge_visibility_summary(),
		"config_version": config_version
	}
	return base_config