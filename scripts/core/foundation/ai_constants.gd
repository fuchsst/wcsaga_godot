class_name AIConstants
extends RefCounted

## AI Constants from WCS ai.h
## Placeholder implementation for compilation

# AI Goal types
enum GoalMode {
	CHASE = 0,
	DOCK = 1,
	WAYPOINTS = 2,
	WAYPOINTS_ONCE = 3,
	WARP = 4,
	ATTACK_SHIP = 5,
	ATTACK_WING = 6,
	GUARD = 7,
	DISABLE_SHIP = 8,
	DISARM_SHIP = 9,
	ATTACK_SUBSYS = 10,
	GUARD_WING = 11,
	EVADE_SHIP = 12,
	STAY_RELATIVE = 13,
	KEEP_SAFE_DISTANCE = 14,
	REARM_REPAIR = 15,
	STAY_STILL = 16,
	PLAY_DEAD = 17,
	BAY_EMERGE = 18,
	BAY_DEPART = 19,
	SENTRY = 20,
	IGNORE = 21,
	IGNORE_NEW = 22,
	FORM_ON_WING = 23,
	UNDOCK = 24,
	FLY_TO_SHIP = 25
}

# AI Behavior types
enum AIBehavior {
	DEFAULT = 0,
	CHASE = 1,
	EVADE = 2,
	GET_BEHIND = 3,
	STAY_NEAR = 4,
	STILL = 5,
	GUARD = 6,
	AVOID = 7,
	WAYPOINTS = 8,
	DOCK = 9,
	NONE = 10,
	BIGSHIP = 11,
	PATH = 12,
	SAFE = 13,
	EMP = 14,
	TURRET_NORMAL = 15,
	TURRET_FREE_LOOK = 16,
	TURRET_TAGGED_ONLY = 17,
	TURRET_TAGGED_CLEAR = 18
}