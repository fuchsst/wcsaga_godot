class_name ShipStateManager
extends Node

## Ship state management system implementing WCS ship flag system and state validation
## Handles all ship lifecycle states, team management, and state persistence (SHIP-004)

# EPIC-002 Asset Core Integration
const ShipStateTypes = preload("res://addons/wcs_asset_core/constants/ship_state_types.gd")
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")

# Ship state management signals
signal state_changed(old_state: int, new_state: int)
signal flag_changed(flag_name: String, enabled: bool)
signal team_changed(old_team: int, new_team: int)
signal arrival_stage_changed(stage: int)
signal combat_state_changed(combat_state: int)

# WCS Mission-Persistent Ship Flags (bits 0-7) - saved in mission files
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

# WCS Runtime Ship Flags (bits 8-31) - runtime state only
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

# WCS Ship States (ship lifecycle)
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

# WCS Combat States
enum CombatState {
	NORMAL = 0,                # Normal operation
	DEATH_ROLL = 1,            # Ship is in death roll
	PRE_EXPLOSION = 2,         # About to explode
	EXPLODING = 3,             # Currently exploding
	CLEANUP = 4                # Post-explosion cleanup
}

# Ship state data
var ship_reference: BaseShip
var current_state: int = ShipState.NOT_YET_PRESENT
var previous_state: int = ShipState.NOT_YET_PRESENT
var combat_state: int = CombatState.NORMAL
var arrival_stage: int = 0
var departure_stage: int = 0

# Mission-persistent flags (bits 0-7) 
var mission_flags: int = 0
# Runtime flags (bits 8-31)
var runtime_flags: int = 0

# Team and IFF management
var team: int = TeamTypes.Team.FRIENDLY
var previous_team: int = TeamTypes.Team.FRIENDLY
var observed_team_color: int = TeamTypes.Team.FRIENDLY  # What other ships observe
var iff_code: String = ""  # Mission-specific IFF identifier

# Lifecycle timing
var state_transition_time: float = 0.0
var arrival_started_time: float = 0.0
var departure_started_time: float = 0.0
var destruction_started_time: float = 0.0

# Combat tracking
var damage_accumulation: float = 0.0
var last_damage_time: float = 0.0
var death_timer: float = 0.0
var explosion_timer: float = 0.0

# Mission integration
var mission_arrival_cue: String = ""
var mission_departure_cue: String = ""
var arrival_location: Vector3 = Vector3.ZERO
var departure_location: Vector3 = Vector3.ZERO

# State validation and constraints
var state_transition_rules: Dictionary = {}
var flag_dependency_rules: Dictionary = {}

## Initialize state manager for specific ship
func initialize_state_manager(ship: BaseShip) -> void:
	"""Initialize state manager for specific ship.
	
	Args:
		ship: BaseShip instance to manage
	"""
	ship_reference = ship
	_initialize_state_system()
	_setup_transition_rules()
	_setup_flag_dependencies()

## Initialize ship state management system (SHIP-004 AC1)
func _initialize_state_system() -> void:
	"""Initialize WCS-authentic state management with proper validation."""
	# Set default state
	current_state = ShipState.NOT_YET_PRESENT
	previous_state = ShipState.NOT_YET_PRESENT
	combat_state = CombatState.NORMAL
	
	# Initialize team assignment
	team = TeamTypes.Team.FRIENDLY
	previous_team = team
	observed_team_color = team
	
	# Clear all flags
	mission_flags = 0
	runtime_flags = 0
	
	# Initialize timing
	state_transition_time = Time.get_ticks_msec() * 0.001

## Setup state transition validation rules (SHIP-004 AC3)
func _setup_transition_rules() -> void:
	"""Define valid state transitions based on WCS behavior."""
	state_transition_rules = {
		ShipState.NOT_YET_PRESENT: [ShipState.ARRIVING_STAGE_1, ShipState.ACTIVE],
		ShipState.ARRIVING_STAGE_1: [ShipState.ARRIVING_STAGE_2, ShipState.DESTROYED],
		ShipState.ARRIVING_STAGE_2: [ShipState.ACTIVE, ShipState.DESTROYED],
		ShipState.ACTIVE: [ShipState.DEPARTING_STAGE_1, ShipState.DESTROYED],
		ShipState.DEPARTING_STAGE_1: [ShipState.DEPARTING_STAGE_2, ShipState.DESTROYED],
		ShipState.DEPARTING_STAGE_2: [ShipState.EXITED, ShipState.DESTROYED],
		ShipState.EXITED: [],  # Terminal state (unless respawning)
		ShipState.DESTROYED: []  # Terminal state
	}

## Setup flag dependency rules (SHIP-004 AC1)
func _setup_flag_dependencies() -> void:
	"""Define flag dependencies and mutual exclusions."""
	flag_dependency_rules = {
		# Departure flags are mutually exclusive
		"DEPART_WARP": ["DEPART_DOCKBAY"],
		"DEPART_DOCKBAY": ["DEPART_WARP"],
		
		# Combat states
		"DYING": ["DISABLED", "EXPLODED"],
		"EXPLODED": ["DYING"],
		
		# Weapon lockout dependencies
		"PRIMARIES_LOCKED": [],
		"SECONDARIES_LOCKED": [],
		"AFTERBURNERS_LOCKED": [],
		
		# Stealth combinations
		"STEALTH": ["HIDDEN_FROM_SENSORS"],
		"FRIENDLY_STEALTH_INVIS": ["STEALTH"]
	}

# ============================================================================
# STATE MANAGEMENT API (SHIP-004 AC1, AC3)
# ============================================================================

## Set ship state with validation (SHIP-004 AC3)
func set_ship_state(new_state: int) -> bool:
	"""Set ship state with transition validation.
	
	Args:
		new_state: Target ship state from ShipState enum
		
	Returns:
		true if state transition was valid and applied
	"""
	if not _is_valid_state_transition(current_state, new_state):
		push_warning("ShipStateManager: Invalid state transition %d -> %d for ship %s" % [
			current_state, new_state, ship_reference.ship_name if ship_reference else "Unknown"
		])
		return false
	
	# Store previous state
	previous_state = current_state
	current_state = new_state
	state_transition_time = Time.get_ticks_msec() * 0.001
	
	# Update arrival/departure stage tracking
	_update_stage_tracking(new_state)
	
	# Handle state-specific initialization
	_handle_state_entry(new_state)
	
	# Emit state change signal
	state_changed.emit(previous_state, current_state)
	
	return true

## Get current ship state
func get_ship_state() -> int:
	"""Get current ship state."""
	return current_state

## Check if state transition is valid
func _is_valid_state_transition(from_state: int, to_state: int) -> bool:
	"""Validate state transition according to WCS rules."""
	if not state_transition_rules.has(from_state):
		return false
	
	var valid_transitions: Array = state_transition_rules[from_state]
	return to_state in valid_transitions

## Update stage tracking for arrival/departure sequences
func _update_stage_tracking(new_state: int) -> void:
	"""Update stage tracking for multi-stage sequences."""
	match new_state:
		ShipState.ARRIVING_STAGE_1:
			arrival_stage = 1
			arrival_started_time = state_transition_time
			arrival_stage_changed.emit(arrival_stage)
		ShipState.ARRIVING_STAGE_2:
			arrival_stage = 2
			arrival_stage_changed.emit(arrival_stage)
		ShipState.ACTIVE:
			arrival_stage = 0
			if previous_state in [ShipState.ARRIVING_STAGE_1, ShipState.ARRIVING_STAGE_2]:
				arrival_stage_changed.emit(0)
		ShipState.DEPARTING_STAGE_1:
			departure_stage = 1
			departure_started_time = state_transition_time
		ShipState.DEPARTING_STAGE_2:
			departure_stage = 2
		ShipState.EXITED:
			departure_stage = 0

## Handle state entry initialization
func _handle_state_entry(new_state: int) -> void:
	"""Handle initialization when entering specific states."""
	match new_state:
		ShipState.ARRIVING_STAGE_1:
			# Start arrival effects and music
			if not has_runtime_flag(RuntimeFlags.NO_ARRIVAL_MUSIC):
				_trigger_arrival_music()
			_trigger_arrival_effects()
		
		ShipState.ACTIVE:
			# Ship becomes fully operational
			if ship_reference:
				ship_reference.is_disabled = false
		
		ShipState.DEPARTING_STAGE_1:
			# Start departure effects and music
			if not has_runtime_flag(RuntimeFlags.NO_DEPARTURE_MUSIC):
				_trigger_departure_music()
			_trigger_departure_effects()
		
		ShipState.DESTROYED:
			# Handle destruction sequence
			destruction_started_time = state_transition_time
			set_combat_state(CombatState.DEATH_ROLL)
			_trigger_destruction_sequence()

# ============================================================================
# FLAG MANAGEMENT API (SHIP-004 AC1)
# ============================================================================

## Set mission-persistent flag (SHIP-004 AC1)
func set_mission_flag(flag: int, enabled: bool) -> bool:
	"""Set mission-persistent flag with validation.
	
	Args:
		flag: Flag from MissionFlags enum
		enabled: true to set, false to clear
		
	Returns:
		true if flag was set successfully
	"""
	if flag < 0 or flag > 7:
		push_error("ShipStateManager: Invalid mission flag %d" % flag)
		return false
	
	var old_value: bool = has_mission_flag(flag)
	
	if enabled:
		mission_flags |= (1 << flag)
	else:
		mission_flags &= ~(1 << flag)
	
	if old_value != enabled:
		var flag_name: String = MissionFlags.keys()[flag]
		flag_changed.emit(flag_name, enabled)
	
	return true

## Set runtime flag (SHIP-004 AC1)
func set_runtime_flag(flag: int, enabled: bool) -> bool:
	"""Set runtime flag with validation and dependency checking.
	
	Args:
		flag: Flag from RuntimeFlags enum
		enabled: true to set, false to clear
		
	Returns:
		true if flag was set successfully
	"""
	if flag < 8 or flag > 31:
		push_error("ShipStateManager: Invalid runtime flag %d" % flag)
		return false
	
	var old_value: bool = has_runtime_flag(flag)
	
	# Check flag dependencies before setting
	if enabled and not _validate_flag_dependencies(flag):
		return false
	
	if enabled:
		runtime_flags |= (1 << flag)
	else:
		runtime_flags &= ~(1 << flag)
	
	# Handle flag-specific side effects
	_handle_flag_side_effects(flag, enabled)
	
	if old_value != enabled:
		var flag_name: String = RuntimeFlags.keys()[flag - 8]
		flag_changed.emit(flag_name, enabled)
	
	return true

## Check if mission flag is set
func has_mission_flag(flag: int) -> bool:
	"""Check if mission-persistent flag is set."""
	if flag < 0 or flag > 7:
		return false
	return (mission_flags & (1 << flag)) != 0

## Check if runtime flag is set
func has_runtime_flag(flag: int) -> bool:
	"""Check if runtime flag is set."""
	if flag < 8 or flag > 31:
		return false
	return (runtime_flags & (1 << flag)) != 0

## Validate flag dependencies
func _validate_flag_dependencies(flag: int) -> bool:
	"""Validate flag dependencies and mutual exclusions."""
	var flag_name: String = RuntimeFlags.keys()[flag - 8] if flag >= 8 else MissionFlags.keys()[flag]
	
	if not flag_dependency_rules.has(flag_name):
		return true
	
	var conflicting_flags: Array = flag_dependency_rules[flag_name]
	
	# Check for conflicting flags
	for conflict_flag_name: String in conflicting_flags:
		var conflict_flag_value: int = RuntimeFlags.get(conflict_flag_name, -1)
		if conflict_flag_value >= 8 and has_runtime_flag(conflict_flag_value):
			return false
	
	return true

## Handle flag-specific side effects
func _handle_flag_side_effects(flag: int, enabled: bool) -> void:
	"""Handle side effects when flags are set or cleared."""
	match flag:
		RuntimeFlags.DYING:
			if enabled and ship_reference:
				ship_reference.is_dying = true
				set_combat_state(CombatState.DEATH_ROLL)
		
		RuntimeFlags.DISABLED:
			if ship_reference:
				ship_reference.is_disabled = enabled
		
		RuntimeFlags.SHIP_INVULNERABLE:
			# TODO: Set invulnerability in damage system
			pass
		
		RuntimeFlags.STEALTH:
			if enabled:
				set_runtime_flag(RuntimeFlags.HIDDEN_FROM_SENSORS, true)
		
		RuntimeFlags.AFTERBURNERS_LOCKED:
			if enabled and ship_reference:
				ship_reference.set_afterburner_active(false)

# ============================================================================
# COMBAT STATE MANAGEMENT (SHIP-004 AC4)
# ============================================================================

## Set combat state (SHIP-004 AC4)
func set_combat_state(new_combat_state: int) -> bool:
	"""Set combat state with validation.
	
	Args:
		new_combat_state: Combat state from CombatState enum
		
	Returns:
		true if combat state was set successfully
	"""
	if new_combat_state < 0 or new_combat_state >= CombatState.size():
		return false
	
	var old_combat_state: int = combat_state
	combat_state = new_combat_state
	
	# Handle combat state-specific behavior
	_handle_combat_state_entry(new_combat_state)
	
	if old_combat_state != new_combat_state:
		combat_state_changed.emit(new_combat_state)
	
	return true

## Get current combat state
func get_combat_state() -> int:
	"""Get current combat state."""
	return combat_state

## Handle combat state entry
func _handle_combat_state_entry(new_combat_state: int) -> void:
	"""Handle combat state entry initialization."""
	match new_combat_state:
		CombatState.DEATH_ROLL:
			death_timer = 3.0  # 3 seconds of death roll
			set_runtime_flag(RuntimeFlags.DYING, true)
		
		CombatState.PRE_EXPLOSION:
			explosion_timer = 1.0  # 1 second before explosion
		
		CombatState.EXPLODING:
			_trigger_ship_explosion()
		
		CombatState.CLEANUP:
			_begin_cleanup_sequence()

## Process combat state timing
func process_combat_state(delta: float) -> void:
	"""Process combat state timing and transitions."""
	match combat_state:
		CombatState.DEATH_ROLL:
			death_timer -= delta
			if death_timer <= 0.0:
				set_combat_state(CombatState.PRE_EXPLOSION)
		
		CombatState.PRE_EXPLOSION:
			explosion_timer -= delta
			if explosion_timer <= 0.0:
				set_combat_state(CombatState.EXPLODING)

## Apply damage accumulation (SHIP-004 AC4)
func accumulate_damage(damage: float, damage_position: Vector3 = Vector3.ZERO) -> void:
	"""Accumulate damage for combat state tracking.
	
	Args:
		damage: Amount of damage applied
		damage_position: World position where damage occurred
	"""
	damage_accumulation += damage
	last_damage_time = Time.get_ticks_msec() * 0.001

# ============================================================================
# TEAM AND IFF MANAGEMENT (SHIP-004 AC5)
# ============================================================================

## Set ship team (SHIP-004 AC5)
func set_team(new_team: int) -> bool:
	"""Set ship team with validation.
	
	Args:
		new_team: Team from TeamTypes.Team enum
		
	Returns:
		true if team was set successfully
	"""
	if not TeamTypes.is_valid_team(new_team):
		push_error("ShipStateManager: Invalid team %d" % new_team)
		return false
	
	var old_team: int = team
	previous_team = team
	team = new_team
	observed_team_color = new_team  # Default to same as actual team
	
	# Update ship reference
	if ship_reference:
		ship_reference.team = new_team
	
	if old_team != new_team:
		team_changed.emit(old_team, new_team)
	
	return true

## Get current team
func get_team() -> int:
	"""Get current ship team."""
	return team

## Set observed team color (for stealth/deception)
func set_observed_team_color(observed_team: int) -> bool:
	"""Set team color that other ships observe.
	
	Args:
		observed_team: Team color others observe
		
	Returns:
		true if observed team was set successfully
	"""
	if not TeamTypes.is_valid_team(observed_team):
		return false
	
	observed_team_color = observed_team
	return true

## Get observed team color
func get_observed_team_color() -> int:
	"""Get team color that other ships observe."""
	return observed_team_color

## Check team relationship (SHIP-004 AC5)
func get_team_relationship(other_team: int) -> int:
	"""Get relationship between this ship's team and another team.
	
	Args:
		other_team: Team to check relationship with
		
	Returns:
		TeamTypes.Relationship value
	"""
	return TeamTypes.get_team_relationship(observed_team_color, other_team)

## Check if hostile to team
func is_hostile_to_team(other_team: int) -> bool:
	"""Check if this ship is hostile to another team."""
	var relationship: int = get_team_relationship(other_team)
	return relationship == TeamTypes.Relationship.HOSTILE

## Check if friendly to team
func is_friendly_to_team(other_team: int) -> bool:
	"""Check if this ship is friendly to another team."""
	var relationship: int = get_team_relationship(other_team)
	return relationship == TeamTypes.Relationship.FRIENDLY

# ============================================================================
# LIFECYCLE EVENT PROCESSING (SHIP-004 AC2)
# ============================================================================

## Begin ship arrival sequence (SHIP-004 AC2)
func begin_arrival_sequence(arrival_position: Vector3 = Vector3.ZERO, cue_name: String = "") -> bool:
	"""Begin ship arrival sequence with effects.
	
	Args:
		arrival_position: World position for arrival
		cue_name: Mission cue name for arrival
		
	Returns:
		true if arrival sequence started successfully
	"""
	if current_state != ShipState.NOT_YET_PRESENT:
		return false
	
	arrival_location = arrival_position
	mission_arrival_cue = cue_name
	
	return set_ship_state(ShipState.ARRIVING_STAGE_1)

## Complete arrival sequence (SHIP-004 AC2)
func complete_arrival_sequence() -> bool:
	"""Complete arrival sequence and activate ship."""
	if current_state == ShipState.ARRIVING_STAGE_1:
		return set_ship_state(ShipState.ARRIVING_STAGE_2)
	elif current_state == ShipState.ARRIVING_STAGE_2:
		return set_ship_state(ShipState.ACTIVE)
	return false

## Begin ship departure sequence (SHIP-004 AC2)
func begin_departure_sequence(departure_position: Vector3 = Vector3.ZERO, cue_name: String = "", via_warp: bool = true) -> bool:
	"""Begin ship departure sequence.
	
	Args:
		departure_position: World position for departure
		cue_name: Mission cue name for departure
		via_warp: true for warp departure, false for docking bay
		
	Returns:
		true if departure sequence started successfully
	"""
	if current_state != ShipState.ACTIVE:
		return false
	
	departure_location = departure_position
	mission_departure_cue = cue_name
	
	# Set departure method flag
	if via_warp:
		set_runtime_flag(RuntimeFlags.DEPART_WARP, true)
	else:
		set_runtime_flag(RuntimeFlags.DEPART_DOCKBAY, true)
	
	return set_ship_state(ShipState.DEPARTING_STAGE_1)

## Complete departure sequence (SHIP-004 AC2)
func complete_departure_sequence() -> bool:
	"""Complete departure sequence and remove ship."""
	if current_state == ShipState.DEPARTING_STAGE_1:
		return set_ship_state(ShipState.DEPARTING_STAGE_2)
	elif current_state == ShipState.DEPARTING_STAGE_2:
		return set_ship_state(ShipState.EXITED)
	return false

## Trigger destruction sequence (SHIP-004 AC2)
func trigger_destruction_sequence() -> bool:
	"""Trigger ship destruction sequence."""
	return set_ship_state(ShipState.DESTROYED)

# ============================================================================
# MISSION INTEGRATION (SHIP-004 AC6)
# ============================================================================

## Get ship data for mission save
func get_mission_save_data() -> Dictionary:
	"""Get ship data for mission save files.
	
	Returns:
		Dictionary containing mission-persistent ship data
	"""
	return {
		"ship_name": ship_reference.ship_name if ship_reference else "",
		"mission_flags": mission_flags,
		"team": team,
		"current_state": current_state,
		"hull_strength": ship_reference.current_hull_strength if ship_reference else 0.0,
		"shield_strength": ship_reference.current_shield_strength if ship_reference else 0.0,
		"weapon_energy": ship_reference.current_weapon_energy if ship_reference else 0.0,
		"afterburner_fuel": ship_reference.current_afterburner_fuel if ship_reference else 0.0,
		"iff_code": iff_code,
		"mission_arrival_cue": mission_arrival_cue,
		"mission_departure_cue": mission_departure_cue,
		"damage_accumulation": damage_accumulation
	}

## Load ship data from mission save
func load_mission_save_data(save_data: Dictionary) -> bool:
	"""Load ship data from mission save files.
	
	Args:
		save_data: Dictionary containing saved ship data
		
	Returns:
		true if data was loaded successfully
	"""
	if not save_data:
		return false
	
	# Load mission-persistent data
	mission_flags = save_data.get("mission_flags", 0)
	var saved_team: int = save_data.get("team", TeamTypes.Team.FRIENDLY)
	set_team(saved_team)
	
	# Load state (with validation)
	var saved_state: int = save_data.get("current_state", ShipState.NOT_YET_PRESENT)
	current_state = saved_state  # Direct assignment to bypass transition validation on load
	
	# Load ship properties
	if ship_reference:
		ship_reference.current_hull_strength = save_data.get("hull_strength", ship_reference.max_hull_strength)
		ship_reference.current_shield_strength = save_data.get("shield_strength", ship_reference.max_shield_strength)
		ship_reference.current_weapon_energy = save_data.get("weapon_energy", ship_reference.max_weapon_energy)
		ship_reference.current_afterburner_fuel = save_data.get("afterburner_fuel", ship_reference.afterburner_fuel_capacity)
	
	# Load mission data
	iff_code = save_data.get("iff_code", "")
	mission_arrival_cue = save_data.get("mission_arrival_cue", "")
	mission_departure_cue = save_data.get("mission_departure_cue", "")
	damage_accumulation = save_data.get("damage_accumulation", 0.0)
	
	return true

# ============================================================================
# EFFECT AND EVENT TRIGGERS
# ============================================================================

## Trigger arrival music
func _trigger_arrival_music() -> void:
	"""Trigger arrival music based on ship type and team."""
	# TODO: Integrate with audio system
	pass

## Trigger arrival effects
func _trigger_arrival_effects() -> void:
	"""Trigger arrival visual effects."""
	# TODO: Integrate with effects system for warp-in effects
	pass

## Trigger departure music
func _trigger_departure_music() -> void:
	"""Trigger departure music."""
	# TODO: Integrate with audio system
	pass

## Trigger departure effects
func _trigger_departure_effects() -> void:
	"""Trigger departure visual effects."""
	# TODO: Integrate with effects system for warp-out effects
	pass

## Trigger destruction sequence
func _trigger_destruction_sequence() -> void:
	"""Trigger ship destruction sequence with effects."""
	set_runtime_flag(RuntimeFlags.DYING, true)
	
	# TODO: Integrate with effects system for explosions
	if has_runtime_flag(RuntimeFlags.VAPORIZE):
		# Instant vaporization
		set_combat_state(CombatState.EXPLODING)
	else:
		# Normal death roll sequence
		set_combat_state(CombatState.DEATH_ROLL)

## Trigger ship explosion
func _trigger_ship_explosion() -> void:
	"""Trigger ship explosion effects."""
	set_runtime_flag(RuntimeFlags.EXPLODED, true)
	
	# TODO: Integrate with effects system for explosion effects
	# TODO: Play death scream if not disabled
	
	# Move to cleanup after explosion
	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.wait_time = 2.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): set_combat_state(CombatState.CLEANUP))
	if ship_reference:
		ship_reference.add_child(cleanup_timer)
		cleanup_timer.start()

## Begin cleanup sequence
func _begin_cleanup_sequence() -> void:
	"""Begin post-destruction cleanup."""
	# TODO: Handle debris creation, cleanup timers, etc.
	pass

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Get comprehensive state information
func get_state_info() -> Dictionary:
	"""Get comprehensive ship state information for debugging."""
	return {
		"ship_name": ship_reference.ship_name if ship_reference else "Unknown",
		"current_state": ShipState.keys()[current_state],
		"previous_state": ShipState.keys()[previous_state],
		"combat_state": CombatState.keys()[combat_state],
		"team": TeamTypes.get_team_name(team),
		"observed_team": TeamTypes.get_team_name(observed_team_color),
		"arrival_stage": arrival_stage,
		"departure_stage": departure_stage,
		"mission_flags": mission_flags,
		"runtime_flags": runtime_flags,
		"damage_accumulation": damage_accumulation,
		"state_transition_time": state_transition_time,
		"iff_code": iff_code
	}

## Get debug information string
func debug_info() -> String:
	"""Get debug information string."""
	var state_name: String = ShipState.keys()[current_state]
	var team_name: String = TeamTypes.get_team_name(team)
	var flags_str: String = ""
	
	# Add active flags
	for i in range(32):
		var flag_active: bool = false
		var flag_name: String = ""
		
		if i < 8 and has_mission_flag(i):
			flag_active = true
			flag_name = MissionFlags.keys()[i]
		elif i >= 8 and has_runtime_flag(i):
			flag_active = true
			flag_name = RuntimeFlags.keys()[i - 8]
		
		if flag_active:
			if flags_str != "":
				flags_str += ","
			flags_str += flag_name
	
	return "[State:%s Team:%s Flags:%s]" % [state_name, team_name, flags_str if flags_str != "" else "none"]