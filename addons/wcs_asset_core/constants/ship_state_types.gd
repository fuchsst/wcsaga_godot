class_name ShipStateTypes
extends RefCounted

## Ship state type constants for WCS-Godot conversion
## Defines ship lifecycle states, combat states, and flag types (SHIP-004)

# Ship lifecycle states (matching WCS ship state enum)
enum ShipState {
	NOT_YET_PRESENT = 0,       # Ship hasn't arrived yet
	ARRIVING_STAGE_1 = 1,      # First arrival stage (warp effect start)
	ARRIVING_STAGE_2 = 2,      # Second arrival stage (warp effect end)
	ACTIVE = 3,                # Ship is active in mission
	DEPARTING_STAGE_1 = 4,     # First departure stage (warp effect start)
	DEPARTING_STAGE_2 = 5,     # Second departure stage (warp effect end)
	EXITED = 6,                # Ship has left the mission
	DESTROYED = 7              # Ship is destroyed
}

# Ship combat states
enum CombatState {
	NORMAL = 0,                # Normal operation
	DEATH_ROLL = 1,            # Ship is in death roll
	PRE_EXPLOSION = 2,         # About to explode
	EXPLODING = 3,             # Currently exploding
	CLEANUP = 4                # Post-explosion cleanup
}

# Mission-persistent ship flags (bits 0-7) - saved in mission files
enum MissionFlags {
	CARGO_KNOWN = 0,           # Cargo scanning completed  
	IGNORE_HOMING = 1,         # Ignore homing weapons
	SUICIDED = 2,              # Ship committed suicide
	CARGO_REVEALED = 3,        # Cargo contents revealed
	FROM_PLAYER_WING = 4,      # Ship was in player wing
	RED_ALERT_STORE = 5,       # Ship stored for red alert
	ESCORT = 6,                # Ship is escort target
	REINFORCEMENT = 7          # Ship is reinforcement
}

# Runtime ship flags (bits 8-31) - runtime state only
enum RuntimeFlags {
	KILL_BEFORE_MISSION = 8,   # Kill ship before mission starts
	DYING = 9,                 # Ship is in death sequence
	DISABLED = 10,             # Ship is disabled
	DEPART_WARP = 11,          # Ship departing via warp
	DEPART_DOCKBAY = 12,       # Ship departing via docking bay
	EXPLODED = 13,             # Ship has exploded
	SHIP_LOCKED = 14,          # Ship position is locked
	SHIP_INVULNERABLE = 15,    # Ship cannot take damage
	HIDDEN_FROM_SENSORS = 16,  # Ship not visible on sensors
	STEALTH = 17,              # Ship using stealth
	FRIENDLY_STEALTH_INVIS = 18, # Invisible to friendly stealth
	DON_T_COLLIDE_INVIS = 19,  # Don't collide when invisible
	NO_ARRIVAL_MUSIC = 20,     # Don't play arrival music
	NO_DEPARTURE_MUSIC = 21,   # Don't play departure music
	NO_DYNAMIC = 22,           # No dynamic goals
	AFTERBURNERS_LOCKED = 23,  # Cannot use afterburners
	PRIMARIES_LOCKED = 24,     # Cannot fire primary weapons
	SECONDARIES_LOCKED = 25,   # Cannot fire secondary weapons
	NO_DEATH_SCREAM = 26,      # No death scream when destroyed
	ALWAYS_DEATH_SCREAM = 27,  # Always play death scream
	GUARDIAN = 28,             # Ship is mission-critical guardian
	VAPORIZE = 29,             # Ship vaporizes when destroyed
	WARP_BROKEN = 30,          # Ship's warp drive is broken
	WARP_NEVER = 31            # Ship can never warp
}

## Get ship state name
static func get_ship_state_name(state: int) -> String:
	"""Get human-readable name for ship state."""
	if state >= 0 and state < ShipState.size():
		return ShipState.keys()[state]
	return "UNKNOWN"

## Get combat state name
static func get_combat_state_name(combat_state: int) -> String:
	"""Get human-readable name for combat state."""
	if combat_state >= 0 and combat_state < CombatState.size():
		return CombatState.keys()[combat_state]
	return "UNKNOWN"

## Get mission flag name
static func get_mission_flag_name(flag: int) -> String:
	"""Get human-readable name for mission flag."""
	if flag >= 0 and flag < 8:
		return MissionFlags.keys()[flag]
	return "UNKNOWN"

## Get runtime flag name
static func get_runtime_flag_name(flag: int) -> String:
	"""Get human-readable name for runtime flag."""
	if flag >= 8 and flag < 32:
		return RuntimeFlags.keys()[flag - 8]
	return "UNKNOWN"

## Check if state transition is valid (basic rules)
static func is_valid_state_transition(from_state: int, to_state: int) -> bool:
	"""Check if state transition follows basic WCS rules."""
	# Same state is always valid
	if from_state == to_state:
		return true
	
	# Destruction is always possible
	if to_state == ShipState.DESTROYED:
		return true
	
	# Basic transition validation
	match from_state:
		ShipState.NOT_YET_PRESENT:
			return to_state in [ShipState.ARRIVING_STAGE_1, ShipState.ACTIVE]
		ShipState.ARRIVING_STAGE_1:
			return to_state in [ShipState.ARRIVING_STAGE_2, ShipState.DESTROYED]
		ShipState.ARRIVING_STAGE_2:
			return to_state in [ShipState.ACTIVE, ShipState.DESTROYED]
		ShipState.ACTIVE:
			return to_state in [ShipState.DEPARTING_STAGE_1, ShipState.DESTROYED]
		ShipState.DEPARTING_STAGE_1:
			return to_state in [ShipState.DEPARTING_STAGE_2, ShipState.DESTROYED]
		ShipState.DEPARTING_STAGE_2:
			return to_state in [ShipState.EXITED, ShipState.DESTROYED]
		_:
			return false

## Check if flag is mission-persistent
static func is_mission_flag(flag: int) -> bool:
	"""Check if flag is mission-persistent (saved in mission files)."""
	return flag >= 0 and flag <= 7

## Check if flag is runtime-only
static func is_runtime_flag(flag: int) -> bool:
	"""Check if flag is runtime-only (not saved in mission files)."""
	return flag >= 8 and flag <= 31

## Get all active flags from flag value
static func get_active_flags(flags: int, is_mission_flags: bool = true) -> Array[String]:
	"""Get array of active flag names from flag value.
	
	Args:
		flags: Flag value to decode
		is_mission_flags: true for mission flags, false for runtime flags
		
	Returns:
		Array of active flag names
	"""
	var active_flags: Array[String] = []
	var start_bit: int = 0 if is_mission_flags else 8
	var end_bit: int = 8 if is_mission_flags else 32
	
	for i in range(start_bit, end_bit):
		if (flags & (1 << i)) != 0:
			if is_mission_flags:
				active_flags.append(get_mission_flag_name(i))
			else:
				active_flags.append(get_runtime_flag_name(i))
	
	return active_flags