# scripts/resources/ai_goal.gd
# Defines the structure for an AI goal, corresponding to the ai_goal struct in ai.h.
class_name AIGoal
extends Resource

# Preload constants for easy access
const AIConst = preload("res://scripts/globals/ai_constants.gd")

# Goal Type (Source) - Mirrored from AIG_TYPE_*
enum GoalSource {
	EVENT_SHIP = 1,
	EVENT_WING = 2,
	PLAYER_SHIP = 3,
	PLAYER_WING = 4,
	DYNAMIC = 5 # Generated by AI itself (e.g., attacking threat)
}

# Goal Flags - Mirrored from AIGF_*
enum GoalFlags {
	NONE = 0,
	DOCKER_INDEX_VALID = 1 << 0,
	DOCKEE_INDEX_VALID = 1 << 1,
	ON_HOLD = 1 << 2,
	SUBSYS_NEEDS_FIXUP = 1 << 3, # Needs subsystem name resolved to index/node
	OVERRIDE = 1 << 4, # Goal overrides lower priority dynamic goals
	PURGE = 1 << 5, # Mark for removal
	GOALS_PURGED = 1 << 6, # Internal flag after purging dependent goals
	DOCK_SOUND_PLAYED = 1 << 7
}

# Goal Mode (Action) - Mirrored from AI_GOAL_*
# Using an enum for clarity. Values match the original bitflags for potential compatibility.
enum GoalMode {
	NONE = 0,
	CHASE = 1 << 1,
	DOCK = 1 << 2,
	WAYPOINTS = 1 << 3,
	WAYPOINTS_ONCE = 1 << 4,
	WARP = 1 << 5,
	DESTROY_SUBSYSTEM = 1 << 6,
	FORM_ON_WING = 1 << 7,
	UNDOCK = 1 << 8,
	CHASE_WING = 1 << 9,
	GUARD = 1 << 10,
	DISABLE_SHIP = 1 << 11,
	DISARM_SHIP = 1 << 12,
	CHASE_ANY = 1 << 13,
	IGNORE = 1 << 14,
	GUARD_WING = 1 << 15,
	EVADE_SHIP = 1 << 16,
	STAY_NEAR_SHIP = 1 << 17,
	KEEP_SAFE_DISTANCE = 1 << 18,
	REARM_REPAIR = 1 << 19,
	STAY_STILL = 1 << 20,
	PLAY_DEAD = 1 << 21,
	CHASE_WEAPON = 1 << 22,
	FLY_TO_SHIP = 1 << 23,
	IGNORE_NEW = 1 << 24 # Newer temporary ignore
}

# --- Goal Properties ---
@export var signature: int = -1 # Unique identifier assigned on creation
@export var ai_mode: GoalMode = GoalMode.NONE # Primary goal mode (AI_GOAL_*)
@export var ai_submode: int = 0 # Submode for the goal (e.g., specific dock stage)
@export var source: GoalSource = GoalSource.EVENT_SHIP # Type of goal (event, player, dynamic)
@export_flags("Docker Valid", "Dockee Valid", "On Hold", "Subsys Fixup", "Override", "Purge", "Goals Purged", "Dock Sound Played") var flags: int = 0
@export var creation_time: float = 0.0 # Time.get_ticks_msec() / 1000.0 when created
@export var priority: int = 0 # Priority (0-200, higher takes precedence)

# Target Info (Context depends on ai_mode)
# Stores the *name* of the target (ship, wing, waypoint list) as parsed from mission file.
# Runtime systems will resolve this name to an actual object/path reference.
@export var target_name: String = ""
# Original C++ used ship_name_index for optimization, less critical here.
# var ship_name_index: int = -1

# Waypoint Goal Info
# Covered by target_name for WAYPOINTS* modes.
# Original C++ used wp_index for the list index, we can resolve from target_name.
# var wp_index: int = -1

# Weapon Goal Info
@export var weapon_target_signature: int = -1 # If ai_mode is CHASE_WEAPON

# Docking Goal Info
@export var docker_point_name: String = "" # Name of the docking point on the *acting* ship
@export var dockee_point_name: String = "" # Name of the docking point on the *target* ship
# Resolved indices will be stored at runtime, not exported in the resource.
var docker_point_index: int = -1
var dockee_point_index: int = -1

# Subsystem Goal Info
@export var subsystem_name: String = "" # Name of the target subsystem
# Resolved index/node reference stored at runtime.
var subsystem_target_index: int = -1
var subsystem_node: Node = null # Runtime reference

# Runtime state (not exported, managed by AIGoalManager/AIController)
var is_active: bool = false
var is_completed: bool = false # Added for potential use
var is_failed: bool = false # Added for potential use

func _init():
	# Assign a default invalid signature. A unique one will be assigned by AIGoalManager.
	signature = -1
	# Record creation time for potential priority tie-breaking or debugging.
	creation_time = Time.get_ticks_msec() / 1000.0

func is_valid() -> bool:
	# A goal is considered valid if it has a defined mode other than NONE.
	return ai_mode != GoalMode.NONE

func set_flag(flag_enum: GoalFlags, value: bool):
	# Helper to set or clear a specific flag using the GoalFlags enum.
	if value:
		flags |= flag_enum
	else:
		flags &= ~flag_enum

func has_flag(flag_enum: GoalFlags) -> bool:
	# Helper to check if a specific flag is set using the GoalFlags enum.
	return (flags & flag_enum) != 0

# --- Convenience Getters ---
# These help interpret the target_name based on the goal mode.

func get_target_ship_name() -> String:
	# Returns target_name if the mode implies a ship target.
	match ai_mode:
		GoalMode.CHASE, GoalMode.DOCK, GoalMode.DESTROY_SUBSYSTEM, \
		GoalMode.FORM_ON_WING, GoalMode.UNDOCK, GoalMode.GUARD, \
		GoalMode.DISABLE_SHIP, GoalMode.DISARM_SHIP, GoalMode.IGNORE, \
		GoalMode.IGNORE_NEW, GoalMode.EVADE_SHIP, GoalMode.STAY_NEAR_SHIP, \
		GoalMode.REARM_REPAIR, GoalMode.STAY_STILL, \
		GoalMode.FLY_TO_SHIP:
			return target_name
		_:
			return ""

func get_target_wing_name() -> String:
	# Returns target_name if the mode implies a wing target.
	match ai_mode:
		GoalMode.CHASE_WING, GoalMode.GUARD_WING:
			return target_name
		_:
			return ""

func get_target_waypoint_list_name() -> String:
	# Returns target_name if the mode implies a waypoint list target.
	match ai_mode:
		GoalMode.WAYPOINTS, GoalMode.WAYPOINTS_ONCE:
			return target_name
		_:
			return ""
