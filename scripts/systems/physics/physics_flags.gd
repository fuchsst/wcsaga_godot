## PhysicsFlags - Physics State Flags Enum
## Replicates WCS C++ PF_* flags for physics state management
## Used as bitmask for efficient state checking

class_name PhysicsFlags
extends RefCounted

## Physics behavior flags - matches C++ physics.h PF_* constants
enum Flag {
	NONE = 0,
	ACCELERATES = 1 << 1,  ## Ship uses acceleration ramping
	USE_VEL = 1 << 2,  ## Use raw velocity, skip simulation
	AFTERBURNER_ON = 1 << 3,  ## Afterburner currently engaged
	SLIDE_ENABLED = 1 << 4,  ## Allow Descent-style sliding
	REDUCED_DAMP = 1 << 5,  ## Reduced damping (after hit/shockwave)
	IN_SHOCKWAVE = 1 << 6,  ## Recently hit by shockwave
	DEAD_DAMP = 1 << 7,  ## Dead ship damping (all axes equal)
	AFTERBURNER_WAIT = 1 << 8,  ## Afterburner cooldown active
	CONST_VEL = 1 << 9,  ## Constant velocity (weapons optimization)
	WARP_IN = 1 << 10,  ## Ship is warping in
	SPECIAL_WARP_IN = 1 << 11,  ## Special warp in physics
	WARP_OUT = 1 << 12,  ## Ship is warping out
	SPECIAL_WARP_OUT = 1 << 13,  ## Special warp out physics
	BOOSTER_ON = 1 << 14,  ## Booster engaged (docking etc.)
	GLIDING = 1 << 15,  ## Newtonian glide mode active
}


## Helper to check if a flag is set in a bitmask
static func has_flag(flags: int, flag: Flag) -> bool:
	return (flags & flag) != 0


## Helper to set a flag
static func set_flag(flags: int, flag: Flag) -> int:
	return flags | flag


## Helper to clear a flag
static func clear_flag(flags: int, flag: Flag) -> int:
	return flags & ~flag


## Helper to toggle a flag
static func toggle_flag(flags: int, flag: Flag) -> int:
	return flags ^ flag


## Get human-readable flag names for debugging
static func get_active_flag_names(flags: int) -> Array[String]:
	var names: Array[String] = []
	if flags & Flag.ACCELERATES:
		names.append("ACCELERATES")
	if flags & Flag.USE_VEL:
		names.append("USE_VEL")
	if flags & Flag.AFTERBURNER_ON:
		names.append("AFTERBURNER_ON")
	if flags & Flag.SLIDE_ENABLED:
		names.append("SLIDE_ENABLED")
	if flags & Flag.REDUCED_DAMP:
		names.append("REDUCED_DAMP")
	if flags & Flag.IN_SHOCKWAVE:
		names.append("IN_SHOCKWAVE")
	if flags & Flag.DEAD_DAMP:
		names.append("DEAD_DAMP")
	if flags & Flag.CONST_VEL:
		names.append("CONST_VEL")
	if flags & Flag.WARP_IN:
		names.append("WARP_IN")
	if flags & Flag.WARP_OUT:
		names.append("WARP_OUT")
	if flags & Flag.BOOSTER_ON:
		names.append("BOOSTER_ON")
	if flags & Flag.GLIDING:
		names.append("GLIDING")
	return names
