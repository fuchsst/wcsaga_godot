# scripts/globals/ai_constants.gd
# Defines constants and enums used by the AI system.
class_name AIConstants
extends RefCounted # Use RefCounted or Node depending on how it's accessed (likely RefCounted for constants)

# --- AI Modes (AIM_*) ---
# High-level behavioral state of the AI.
enum AIMode {
	NONE = 9,
	CHASE = 0,
	EVADE = 1,
	GET_BEHIND = 2,
	STAY_NEAR = 3,
	STILL = 4,
	GUARD = 5,
	AVOID = 6,
	WAYPOINTS = 7,
	DOCK = 8,
	BIGSHIP = 10, # Handles capital ship specific logic (approach, circle, parallel)
	PATH = 11, # Following model paths
	BE_REARMED = 12,
	SAFETY = 13, # Retreat to safe spot
	EVADE_WEAPON = 14,
	STRAFE = 15, # Fighter attacking big ship
	PLAY_DEAD = 16,
	BAY_EMERGE = 17,
	BAY_DEPART = 18,
	SENTRYGUN = 19, # Stationary turret logic?
	WARP_OUT = 20,
	FLY_TO_SHIP = 21
}

# --- AI Submodes ---
# More specific behaviors within a primary mode.

# Chase Submodes (SM_*)
enum ChaseSubmode {
	CONTINUOUS_TURN = 1,
	ATTACK = 2,
	EVADE_SQUIGGLE = 3,
	EVADE_BRAKE = 4,
	EVADE = 5,
	SUPER_ATTACK = 6,
	AVOID = 7, # Avoid collision during chase
	GET_BEHIND = 8,
	GET_AWAY = 9,
	EVADE_WEAPON = 10,
	FLY_AWAY = 11,
	ATTACK_FOREVER = 12,
	# Combined from AIS_*
	GLIDE_ATTACK = 13, # AIS_CHASE_GLIDEATTACK
	CIRCLE_STRAFE = 14 # AIS_CHASE_CIRCLESTRAFE
}

# Strafe Submodes (AIS_STRAFE_*)
enum StrafeSubmode {
	ATTACK = 201,
	AVOID = 202,
	RETREAT1 = 203,
	RETREAT2 = 204,
	POSITION = 205,
	GLIDE_ATTACK = 206
}

# Stealth Find Submodes (SM_SF_*)
enum StealthFindSubmode {
	AHEAD = 0,
	BEHIND = 1,
	BAIL = 2
}

# Stealth Sweep Submodes (SM_SS_*)
enum StealthSweepSubmode {
	SET_GOAL = -1,
	BOX0 = 0,
	LR = 1, # Lower Right
	UL = 2, # Upper Left
	BOX1 = 3,
	UR = 4, # Upper Right
	LL = 5, # Lower Left
	BOX2 = 6,
	DONE = 7
}

# Guard Submodes (AIS_GUARD_*)
enum GuardSubmode {
	STATIC = 101, # Guard static position relative to target
	PATROL = 102, # Patrol around the guarded object
	ATTACK = 103 # Attack threats to the guarded object
}

# Docking Submodes (AIS_DOCK_*, AIS_UNDOCK_*)
enum DockSubmode {
	# Docking
	DOCK_0_UNUSED = 21, # Original AIS_DOCK_0
	DOCK_1_APPROACH_PATH = 22, # AIS_DOCK_1
	DOCK_2_ORIENT_FINAL = 23, # AIS_DOCK_2
	DOCK_3_FINAL_MANEUVER = 24, # AIS_DOCK_3
	DOCK_4_STAY_REPAIRING = 26, # AIS_DOCK_4
	DOCK_4A_STAY_NORMAL = 27, # AIS_DOCK_4A
	# Undocking
	UNDOCK_0_START_PATH = 30, # AIS_UNDOCK_0
	UNDOCK_1_MOVE_AWAY = 31, # AIS_UNDOCK_1
	UNDOCK_2_CONTINUE_PATH = 32, # AIS_UNDOCK_2
	UNDOCK_3_FINAL_SEPARATION = 33, # AIS_UNDOCK_3
	UNDOCK_4_COMPLETE = 34 # AIS_UNDOCK_4
}

# Safety Submodes (AISS_*)
enum SafetySubmode {
	PICK_SPOT = 41, # AISS_1
	GOTO_SPOT = 42, # AISS_2
	CIRCLE_SPOT = 43 # AISS_3
}

# Warp Out Submodes (AIS_WARP_*)
enum WarpOutSubmode {
	CHECK_CLEAR = 300, # AIS_WARP_1
	WAIT_CLEAR = 301, # AIS_WARP_2
	ACCELERATE = 302, # AIS_WARP_3
	INITIATE_EFFECT = 303, # AIS_WARP_4
	WARPING = 304 # AIS_WARP_5
}

# --- AI Flags (AIF_*) ---
# Bitmask controlling runtime state and fine-grained behaviors.
const AIF_FORMATION_WING = 1 << 0       # Ship is flying in wing formation
const AIF_AWAITING_REPAIR = 1 << 1      # Ship is waiting for repair
const AIF_BEING_REPAIRED = 1 << 2       # Ship is currently being repaired
const AIF_REPAIRING = 1 << 3            # Ship is repairing another ship
const AIF_SEEK_LOCK = 1 << 4            # Ship is trying to get missile lock
const AIF_FORMATION_OBJECT = 1 << 5     # Ship is flying in formation with object
const AIF_TEMPORARY_IGNORE = 1 << 6     # Temporarily ignore target (until ignore_expire_timestamp)
const AIF_USE_EXIT_PATH = 1 << 7        # Ship is using exit path (from dock bay)
const AIF_USE_STATIC_PATH = 1 << 8      # Ship is using a static path (not dynamically recreated)
const AIF_TARGET_COLLISION = 1 << 9     # Ship is avoiding collision with target (specific logic in strafe)
const AIF_UNLOAD_SECONDARIES = 1 << 10  # Ship should fire secondaries rapidly (usually when preferred)
const AIF_ON_SUBSYS_PATH = 1 << 11      # Ship is on path to subsystem
const AIF_AVOID_SHOCKWAVE_SHIP = 1 << 12 # Ship is avoiding shockwave from ship explosion
const AIF_AVOID_SHOCKWAVE_WEAPON = 1 << 13 # Ship is avoiding shockwave from weapon impact
const AIF_AVOID_SHOCKWAVE_STARTED = 1 << 14 # Ship has started avoiding shockwave (prevents re-triggering immediately)
const AIF_ATTACK_SLOWLY = 1 << 15       # Ship should attack slowly (used after getting away)
const AIF_REPAIR_OBSTRUCTED = 1 << 16   # Repair is obstructed (used by support ship)
const AIF_KAMIKAZE = 1 << 17            # Ship is in kamikaze mode
const AIF_NO_DYNAMIC = 1 << 18          # Ship doesn't use dynamic goals (e.g., attacking threats when guarding)
const AIF_AVOIDING_SMALL_SHIP = 1 << 19 # Ship is avoiding small ship (player collision avoidance)
const AIF_AVOIDING_BIG_SHIP = 1 << 20   # Ship is avoiding big ship (collision avoidance)
const AIF_BIG_SHIP_COLLIDE_RECOVER_1 = 1 << 21 # Big ship collision recovery phase 1
const AIF_BIG_SHIP_COLLIDE_RECOVER_2 = 1 << 22 # Big ship collision recovery phase 2
const AIF_STEALTH_PURSUIT = 1 << 23     # Ship is pursuing stealth target
const AIF_UNLOAD_PRIMARIES = 1 << 24    # Ship should fire primary weapons rapidly (not commonly used)
const AIF_TRYING_UNSUCCESSFULLY_TO_WARP = 1 << 25 # Ship failed to warp due to obstruction/damage
const AIF_CLOSING_DISTANCE_WITH_AB = 1 << 26 # Ship is using afterburner specifically to close distance (e.g., stay near, formation)

# Combined flags for convenience
const AIF_AVOID_SHOCKWAVE = AIF_AVOID_SHOCKWAVE_SHIP | AIF_AVOID_SHOCKWAVE_WEAPON
const AIF_FORMATION = AIF_FORMATION_WING | AIF_FORMATION_OBJECT

# --- Path Following Directions (PD_*) ---
enum PathDirection {
	FORWARD = 1,
	BACKWARD = -1
}

# --- Waypoint Path Flags (WPF_*) ---
enum WaypointFlags {
	REPEAT = 1 << 0,
	BACKTRACK = 1 << 1
}

# --- Goal Achievable States ---
# Internal constants used by AIGoalManager._is_goal_achievable
enum GoalAchievableState {
	ACHIEVABLE = 1,
	NOT_ACHIEVABLE = 2,
	NOT_KNOWN = 3,
	SATISFIED = 4
}

# --- Subsystem Types (for targeting preferences, etc.) ---
# These might need to align with enums defined elsewhere (e.g., in ShipSubsystem)
enum SubsystemType {
	NONE = 0,
	ENGINE = 1,
	TURRET = 2,
	RADAR = 3,
	NAVIGATION = 4,
	COMMUNICATION = 5,
	WEAPONS = 6,
	SENSORS = 7
	# Add others as needed
}
