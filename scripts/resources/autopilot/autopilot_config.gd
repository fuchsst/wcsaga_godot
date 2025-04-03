# scripts/resources/autopilot/autopilot_config.gd
extends Resource
class_name AutopilotConfig

## Stores configuration settings for the Autopilot system.
## Corresponds to data parsed from autopilot.tbl.

# --- Exports ---

@export var link_distance: float = 500.0 # NavLinkDistance

@export var use_cutscene_bars: bool = true # UseCutsceneBars flag
@export var no_autopilot_interrupt: bool = false # No_Autopilot_Interrupt flag (maps to Cmdline_autopilot_interruptable == 0)

# --- Messages ---
# Corresponds to NavMessage struct and msg_tags array

@export_group("Messages")
@export_multiline var msg_fail_no_selection: String = "No navigation point selected."
@export var snd_fail_no_selection: String = "" # Path to sound file or ""/"none"

@export_group("Messages")
@export_multiline var msg_fail_gliding: String = "Cannot engage autopilot while gliding."
@export var snd_fail_gliding: String = ""

@export_group("Messages")
@export_multiline var msg_fail_too_close: String = "Too close to destination to engage autopilot."
@export var snd_fail_too_close: String = ""

@export_group("Messages")
@export_multiline var msg_fail_hostiles: String = "Cannot engage autopilot with hostiles nearby."
@export var snd_fail_hostiles: String = ""

@export_group("Messages")
@export_multiline var msg_misc_linked: String = "Ship linked for autopilot."
@export var snd_misc_linked: String = ""

@export_group("Messages")
@export_multiline var msg_fail_hazard: String = "Cannot engage autopilot near navigational hazard."
@export var snd_fail_hazard: String = ""

# --- Constants for Message IDs (matching C++ enum order) ---
enum MessageID {
	FAIL_NO_SELECTION,   # NP_MSG_FAIL_NOSEL
	FAIL_GLIDING,        # NP_MSG_FAIL_GLIDING
	FAIL_TOO_CLOSE,      # NP_MSG_FAIL_TOCLOSE
	FAIL_HOSTILES,       # NP_MSG_FAIL_HOSTILES
	MISC_LINKED,         # NP_MSG_MISC_LINKED
	FAIL_HAZARD,         # NP_MSG_FAIL_HAZARD
	NUM_MESSAGES         # NP_NUM_MESSAGES
}

# --- Methods ---

func get_message(msg_id: MessageID) -> String:
	match msg_id:
		MessageID.FAIL_NO_SELECTION: return msg_fail_no_selection
		MessageID.FAIL_GLIDING: return msg_fail_gliding
		MessageID.FAIL_TOO_CLOSE: return msg_fail_too_close
		MessageID.FAIL_HOSTILES: return msg_fail_hostiles
		MessageID.MISC_LINKED: return msg_misc_linked
		MessageID.FAIL_HAZARD: return msg_fail_hazard
	return "Unknown Autopilot Message ID"

func get_sound(msg_id: MessageID) -> String:
	match msg_id:
		MessageID.FAIL_NO_SELECTION: return snd_fail_no_selection
		MessageID.FAIL_GLIDING: return snd_fail_gliding
		MessageID.FAIL_TOO_CLOSE: return snd_fail_too_close
		MessageID.FAIL_HOSTILES: return snd_fail_hostiles
		MessageID.MISC_LINKED: return snd_misc_linked
		MessageID.FAIL_HAZARD: return snd_fail_hazard
	return ""
