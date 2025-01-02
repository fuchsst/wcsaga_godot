extends Resource
class_name PilotData

# Core pilot data
@export var callsign: String
@export var image_filename: String = ""
@export var squad_name: String = ""
@export var squad_filename: String = ""
@export var short_callsign: String = "" # Used for HUD display
@export var short_callsign_width: int = 0

# Campaign info
@export var current_campaign: String = ""
@export var num_campaigns: int = 0
@export var campaign_progress: Dictionary = {}

# Tips/Help settings
@export var show_tips: bool = true
@export var auto_advance: bool = true
@export var tips_shown: Array[String] = []

# Flags (using enums for type safety)
enum PilotFlags {
	MATCH_TARGET = 1 << 0,
	MSG_MODE = 1 << 1,
	AUTO_TARGETING = 1 << 2,
	AUTO_MATCH_SPEED = 1 << 3,
	STRUCTURE_IN_USE = 1 << 4,
	PROMOTED = 1 << 5,
	IS_MULTI = 1 << 6,
	KILLED_BY_EXPLOSION = 1 << 12,
	HAS_PLAYED_PXO = 1 << 13,
	KILLED_BY_ENGINE_WASH = 1 << 15,
	KILLED_SELF_UNKNOWN = 1 << 16,
	KILLED_SELF_MISSILES = 1 << 17,
	KILLED_SELF_SHOCKWAVE = 1 << 18
}

@export var flags: int = PilotFlags.STRUCTURE_IN_USE | PilotFlags.AUTO_TARGETING
@export var save_flags: int = flags

# Stats
@export var stats: Dictionary = {
	"missions_flown": 0,
	"flight_time": 0.0,
	"last_flown": 0,
	"kill_count": 0,
	"kill_count_ok": 0, # Kills without excessive collateral damage
	"assists": 0,
	"friendly_hits": 0,
	"friendly_damage": 0.0,
	"friendly_last_hit_time": 0,
	"last_warning_message_time": 0,
	"distance_warning_count": 0,
	"distance_warning_time": 0,
	"praise_count": 0,
	"praise_delay_time": 0,
	"ask_help_count": 0,
	"scream_count": 0,
	"low_ammo_complaint_count": 0,
	"medals": [],
	"kills_by_ship": {},  # Dictionary of ship type to kill count
	"assists_by_ship": {}  # Dictionary of ship type to assist count
}

# Combat state
@export var last_ship_flown: String = ""
@export var killer_objtype: int = -1
@export var killer_species: int = -1
@export var killer_weapon_index: int = -1
@export var killer_parent_name: String = ""
@export var death_message: String = ""

# Settings
@export var auto_target: bool = true
@export var auto_speed_match: bool = false
@export var mouse_sensitivity: float = 1.0
@export var joystick_sensitivity: float = 1.0
@export var dead_zone: float = 0.1
@export var briefing_voice_enabled: bool = true
@export var main_hall_id: int = 0 # Which main hall scene to use

# HUD settings
@export var hud_show_flags: int = 0xFFFFFFFF # All HUD elements visible by default
@export var hud_show_flags2: int = 0xFFFFFFFF
@export var hud_popup_flags: int = 0
@export var hud_popup_flags2: int = 0
@export var hud_num_msg_window_lines: int = 4
@export var hud_rp_flags: int = 0
@export var hud_rp_dist: int = 0

# Control settings
@export var control_config: Dictionary = {}
@export var axis_config: Dictionary = {}

# Default control settings
const DEFAULT_CONTROL_CONFIG = {
	# Target controls
	"target_next": {"key": KEY_T, "joy": -1, "mod": 0},
	"target_prev": {"key": KEY_T, "joy": -1, "mod": KEY_SHIFT},
	"target_nearest_hostile": {"key": KEY_H, "joy": -1, "mod": 0},
	"target_prev_hostile": {"key": KEY_H, "joy": -1, "mod": KEY_SHIFT},
	"target_nearest_friendly": {"key": KEY_F, "joy": -1, "mod": 0},
	"target_prev_friendly": {"key": KEY_F, "joy": -1, "mod": KEY_SHIFT},
	"target_in_reticle": {"key": KEY_Y, "joy": -1, "mod": 0},
	"target_attacking_target": {"key": KEY_G, "joy": -1, "mod": 0},
	"target_last_sender": {"key": KEY_Y, "joy": -1, "mod": KEY_ALT},
	"clear_target": {"key": KEY_T, "joy": -1, "mod": KEY_ALT},
	"target_subsystem": {"key": KEY_V, "joy": -1, "mod": 0},
	"next_subsystem": {"key": KEY_S, "joy": -1, "mod": 0},
	"prev_subsystem": {"key": KEY_S, "joy": -1, "mod": KEY_SHIFT},
	"clear_subsystem": {"key": KEY_S, "joy": -1, "mod": KEY_ALT},
	
	# Ship controls
	"pitch_forward": {"key": KEY_KP_8, "joy": -1, "mod": 0},
	"pitch_back": {"key": KEY_KP_2, "joy": -1, "mod": 0},
	"yaw_left": {"key": KEY_KP_4, "joy": -1, "mod": 0},
	"yaw_right": {"key": KEY_KP_6, "joy": -1, "mod": 0},
	"roll_left": {"key": KEY_KP_7, "joy": -1, "mod": 0},
	"roll_right": {"key": KEY_KP_9, "joy": -1, "mod": 0},
	"throttle_up": {"key": KEY_A, "joy": -1, "mod": 0},
	"throttle_down": {"key": KEY_Z, "joy": -1, "mod": 0},
	"throttle_zero": {"key": KEY_BACKSPACE, "joy": -1, "mod": 0},
	"throttle_full": {"key": KEY_SLASH, "joy": -1, "mod": 0},
	"throttle_one_third": {"key": KEY_BRACKETLEFT, "joy": -1, "mod": 0},
	"throttle_two_thirds": {"key": KEY_BRACKETRIGHT, "joy": -1, "mod": 0},
	"throttle_plus_5": {"key": KEY_EQUAL, "joy": -1, "mod": 0},
	"throttle_minus_5": {"key": KEY_MINUS, "joy": -1, "mod": 0},
	"afterburner": {"key": KEY_TAB, "joy": -1, "mod": 0},
	"glide_when_pressed": {"key": -1, "joy": -1, "mod": 0},
	"toggle_glide": {"key": KEY_G, "joy": -1, "mod": KEY_ALT},
	
	# Weapon controls
	"fire_primary": {"key": KEY_CTRL, "joy": 0, "mod": 0},
	"fire_secondary": {"key": KEY_SPACE, "joy": 1, "mod": 0},
	"next_primary": {"key": KEY_PERIOD, "joy": -1, "mod": 0},
	"prev_primary": {"key": KEY_COMMA, "joy": -1, "mod": 0},
	"cycle_secondary": {"key": KEY_SLASH, "joy": -1, "mod": 0},
	"cycle_secondary_bank": {"key": KEY_SLASH, "joy": -1, "mod": KEY_SHIFT},
	"launch_countermeasure": {"key": KEY_X, "joy": -1, "mod": 0},
	
	# Computer controls
	"match_target_speed": {"key": KEY_M, "joy": -1, "mod": 0},
	"toggle_auto_match": {"key": KEY_M, "joy": -1, "mod": KEY_ALT},
	"view_chase": {"key": KEY_KP_MULTIPLY, "joy": -1, "mod": 0},
	"view_external": {"key": KEY_KP_PERIOD, "joy": -1, "mod": 0},
	"view_target": {"key": KEY_KP_DIVIDE, "joy": -1, "mod": 0},
	"view_dist_in": {"key": KEY_KP_ADD, "joy": -1, "mod": 0},
	"view_dist_out": {"key": KEY_KP_SUBTRACT, "joy": -1, "mod": 0},
	"view_center": {"key": KEY_KP_5, "joy": -1, "mod": 0},
	"comm_menu": {"key": KEY_C, "joy": -1, "mod": 0},
	"show_objectives": {"key": -1, "joy": -1, "mod": 0},
	"end_mission": {"key": KEY_J, "joy": -1, "mod": KEY_ALT}
}

const DEFAULT_AXIS_CONFIG = {
	"pitch": {"axis": JOY_AXIS_LEFT_Y, "invert": true},
	"yaw": {"axis": JOY_AXIS_LEFT_X, "invert": false}, 
	"roll": {"axis": JOY_AXIS_RIGHT_X, "invert": false},
	"throttle_abs": {"axis": -1, "invert": false},
	"throttle_rel": {"axis": -1, "invert": false}
}

# Campaign save data
@export var campaign_saves: Dictionary = {}

# Create a new pilot with default settings
static func create(p_callsign: String) -> PilotData:
	var pilot = PilotData.new()
	pilot.callsign = p_callsign
	pilot.short_callsign = p_callsign
	
	# Set default flags
	pilot.flags = PilotFlags.STRUCTURE_IN_USE | PilotFlags.AUTO_TARGETING
	pilot.save_flags = pilot.flags
	
	# Set default settings
	pilot.auto_target = true
	pilot.auto_advance = true
	pilot.show_tips = true
	pilot.briefing_voice_enabled = true
	
	# Initialize control config with defaults
	pilot.control_config = DEFAULT_CONTROL_CONFIG.duplicate(true)
	pilot.axis_config = DEFAULT_AXIS_CONFIG.duplicate(true)
	
	return pilot

# Clone an existing pilot
static func clone_from(source: PilotData, new_callsign: String) -> PilotData:
	var pilot = PilotData.new()
	pilot.callsign = new_callsign
	pilot.short_callsign = new_callsign
	pilot.image_filename = source.image_filename
	pilot.squad_name = source.squad_name 
	pilot.squad_filename = source.squad_filename
	pilot.flags = source.flags
	pilot.save_flags = source.save_flags
	
	# Copy settings but not campaign/stats
	pilot.auto_target = source.auto_target
	pilot.auto_speed_match = source.auto_speed_match
	pilot.mouse_sensitivity = source.mouse_sensitivity
	pilot.joystick_sensitivity = source.joystick_sensitivity
	pilot.dead_zone = source.dead_zone
	pilot.briefing_voice_enabled = source.briefing_voice_enabled
	pilot.show_tips = source.show_tips
	pilot.auto_advance = source.auto_advance
	pilot.hud_show_flags = source.hud_show_flags
	pilot.hud_show_flags2 = source.hud_show_flags2
	pilot.hud_popup_flags = source.hud_popup_flags
	pilot.hud_popup_flags2 = source.hud_popup_flags2
	pilot.hud_num_msg_window_lines = source.hud_num_msg_window_lines
	pilot.hud_rp_flags = source.hud_rp_flags
	pilot.hud_rp_dist = source.hud_rp_dist
	pilot.control_config = source.control_config.duplicate(true)
	pilot.axis_config = source.axis_config.duplicate(true)
	
	return pilot

# Update short callsign based on max width (used for HUD)
func update_short_callsign(max_width: int) -> void:
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	
	# Start with full callsign
	short_callsign = callsign
	short_callsign_width = font.get_string_size(short_callsign, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	# Truncate if needed
	while short_callsign_width > max_width and short_callsign.length() > 0:
		short_callsign = short_callsign.substr(0, short_callsign.length() - 1)
		short_callsign_width = font.get_string_size(short_callsign, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

# Save campaign progress
func save_campaign_state(campaign_name: String, data: Dictionary) -> void:
	campaign_saves[campaign_name] = data
	campaign_progress[campaign_name] = data.get("progress", 0)

# Load campaign progress
func load_campaign_state(campaign_name: String) -> Dictionary:
	return campaign_saves.get(campaign_name, {})

# Record a kill
func record_kill(ship_type: String, clean_kill: bool = true) -> void:
	stats.kill_count += 1
	if clean_kill:
		stats.kill_count_ok += 1
	
	if not stats.kills_by_ship.has(ship_type):
		stats.kills_by_ship[ship_type] = 0
	stats.kills_by_ship[ship_type] += 1

# Record an assist
func record_assist(ship_type: String) -> void:
	stats.assists += 1
	
	if not stats.assists_by_ship.has(ship_type):
		stats.assists_by_ship[ship_type] = 0
	stats.assists_by_ship[ship_type] += 1

# Record friendly fire
func record_friendly_hit(damage: float) -> void:
	stats.friendly_hits += 1
	stats.friendly_damage += damage
	stats.friendly_last_hit_time = Time.get_unix_time_from_system()
