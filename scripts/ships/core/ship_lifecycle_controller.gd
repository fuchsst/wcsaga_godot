class_name ShipLifecycleController
extends Node

## Ship lifecycle controller managing creation, activation, departure, and destruction events
## Handles arrival/departure sequences, combat events, and state transitions (SHIP-004)

# EPIC-002 Asset Core Integration
const ShipStateTypes = preload("res://addons/wcs_asset_core/constants/ship_state_types.gd")
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")

# Lifecycle management signals
signal ship_created(ship: BaseShip)
signal ship_activated(ship: BaseShip)
signal ship_arrival_started(ship: BaseShip, stage: int)
signal ship_arrival_completed(ship: BaseShip)
signal ship_departure_started(ship: BaseShip, stage: int)
signal ship_departure_completed(ship: BaseShip)
signal ship_destroyed(ship: BaseShip)
signal ship_cleanup_completed(ship: BaseShip)

# Lifecycle event types for mission system integration
enum LifecycleEvent {
	CREATION = 0,                  # Ship created
	ARRIVAL_STAGE_1 = 1,          # Arrival warp effect begins
	ARRIVAL_STAGE_2 = 2,          # Arrival warp effect ends
	ACTIVATION = 3,               # Ship becomes active
	DEPARTURE_STAGE_1 = 4,        # Departure warp effect begins
	DEPARTURE_STAGE_2 = 5,        # Departure warp effect ends
	EXIT = 6,                     # Ship exits mission
	DESTRUCTION = 7,              # Ship destroyed
	CLEANUP = 8                   # Post-destruction cleanup
}

# Ship reference and state manager
var ship: BaseShip
var state_manager: ShipStateManager

# Lifecycle timing and effects
var arrival_stage_duration: float = 2.5  # WCS arrival effect duration
var departure_stage_duration: float = 2.5  # WCS departure effect duration
var death_roll_duration: float = 3.0  # Death roll time
var explosion_cleanup_duration: float = 2.0  # Post-explosion cleanup

# Mission integration
var mission_system_connection: bool = false
var sexp_integration_enabled: bool = false

# Internal timers
var _arrival_timer: Timer
var _departure_timer: Timer
var _death_timer: Timer
var _cleanup_timer: Timer

func _init() -> void:
	"""Initialize lifecycle controller."""
	name = "ShipLifecycleController"
	_create_internal_timers()

func _ready() -> void:
	"""Setup lifecycle controller when added to scene tree."""
	_setup_mission_integration()
	_setup_sexp_integration()

## Initialize lifecycle controller for specific ship (SHIP-004 AC2)
func initialize_controller(target_ship: BaseShip) -> bool:
	"""Initialize lifecycle controller for specific ship.
	
	Args:
		target_ship: Ship to manage lifecycle for
		
	Returns:
		true if initialization successful
	"""
	if not target_ship:
		push_error("ShipLifecycleController: Cannot initialize with null ship")
		return false
	
	ship = target_ship
	
	# Create state manager for this ship
	state_manager = ShipStateManager.new()
	add_child(state_manager)
	state_manager.initialize_state_manager(ship)
	
	# Connect state manager signals
	_connect_state_manager_signals()
	
	# Connect ship signals
	_connect_ship_signals()
	
	# Register with mission system
	_register_with_mission_system()
	
	# Emit creation event
	_emit_lifecycle_event(LifecycleEvent.CREATION)
	ship_created.emit(ship)
	
	return true

## Create internal timers for lifecycle events
func _create_internal_timers() -> void:
	"""Create timers for managing lifecycle sequences."""
	# Arrival timer for multi-stage arrival
	_arrival_timer = Timer.new()
	_arrival_timer.name = "ArrivalTimer"
	_arrival_timer.one_shot = true
	_arrival_timer.timeout.connect(_on_arrival_timer_timeout)
	add_child(_arrival_timer)
	
	# Departure timer for multi-stage departure
	_departure_timer = Timer.new()
	_departure_timer.name = "DepartureTimer"
	_departure_timer.one_shot = true
	_departure_timer.timeout.connect(_on_departure_timer_timeout)
	add_child(_departure_timer)
	
	# Death timer for death roll sequence
	_death_timer = Timer.new()
	_death_timer.name = "DeathTimer"
	_death_timer.one_shot = true
	_death_timer.timeout.connect(_on_death_timer_timeout)
	add_child(_death_timer)
	
	# Cleanup timer for post-destruction cleanup
	_cleanup_timer = Timer.new()
	_cleanup_timer.name = "CleanupTimer"
	_cleanup_timer.one_shot = true
	_cleanup_timer.timeout.connect(_on_cleanup_timer_timeout)
	add_child(_cleanup_timer)

## Connect state manager signals
func _connect_state_manager_signals() -> void:
	"""Connect to state manager signals for lifecycle coordination."""
	if not state_manager:
		return
	
	state_manager.state_changed.connect(_on_ship_state_changed)
	state_manager.arrival_stage_changed.connect(_on_arrival_stage_changed)
	state_manager.combat_state_changed.connect(_on_combat_state_changed)
	state_manager.team_changed.connect(_on_team_changed)

## Connect ship signals
func _connect_ship_signals() -> void:
	"""Connect to ship signals for lifecycle events."""
	if not ship:
		return
	
	ship.ship_destroyed.connect(_on_ship_destroyed_signal)

## Setup mission system integration (SHIP-004 AC6)
func _setup_mission_integration() -> void:
	"""Setup integration with mission system for arrival/departure cues."""
	# Check if mission system is available
	if has_node("/root/MissionSystem"):
		mission_system_connection = true
		# TODO: Connect to mission system signals and cue handling
	else:
		mission_system_connection = false
		print("ShipLifecycleController: Mission system not available for lifecycle integration")

## Setup SEXP integration for mission scripting (SHIP-004 AC6)
func _setup_sexp_integration() -> void:
	"""Setup SEXP integration for mission scripting access."""
	# Check if SEXP addon is available
	if has_node("/root/SexpEngine"):
		sexp_integration_enabled = true
		_register_sexp_functions()
	else:
		sexp_integration_enabled = false
		print("ShipLifecycleController: SEXP engine not available for lifecycle integration")

## Register with mission system
func _register_with_mission_system() -> void:
	"""Register ship lifecycle events with mission system."""
	if not mission_system_connection or not ship:
		return
	
	# TODO: Register ship with mission system for event tracking
	# This will be implemented when mission system is fully integrated

## Register SEXP functions for mission scripting
func _register_sexp_functions() -> void:
	"""Register ship lifecycle functions with SEXP engine."""
	if not sexp_integration_enabled or not ship:
		return
	
	# TODO: Register lifecycle query functions with SEXP
	# Examples: (is-ship-arriving "ship_name"), (is-ship-departing "ship_name"), etc.

# ============================================================================
# LIFECYCLE EVENT API (SHIP-004 AC2)
# ============================================================================

## Begin ship arrival sequence (SHIP-004 AC2)
func begin_ship_arrival(arrival_position: Vector3 = Vector3.ZERO, arrival_cue: String = "") -> bool:
	"""Begin ship arrival sequence with multi-stage warp effects.
	
	Args:
		arrival_position: World position for ship arrival
		arrival_cue: Mission cue name for arrival event
		
	Returns:
		true if arrival sequence started successfully
	"""
	if not ship or not state_manager:
		return false
	
	# Position ship at arrival location
	if arrival_position != Vector3.ZERO:
		ship.global_position = arrival_position
	
	# Begin arrival in state manager
	if not state_manager.begin_arrival_sequence(arrival_position, arrival_cue):
		return false
	
	# Start arrival stage 1 timer
	_arrival_timer.wait_time = arrival_stage_duration
	_arrival_timer.start()
	
	# Emit arrival events
	_emit_lifecycle_event(LifecycleEvent.ARRIVAL_STAGE_1)
	ship_arrival_started.emit(ship, 1)
	
	# Start arrival effects
	_start_arrival_effects()
	
	return true

## Begin ship departure sequence (SHIP-004 AC2)
func begin_ship_departure(departure_position: Vector3 = Vector3.ZERO, departure_cue: String = "", via_warp: bool = true) -> bool:
	"""Begin ship departure sequence with effects.
	
	Args:
		departure_position: World position for departure
		departure_cue: Mission cue name for departure event
		via_warp: true for warp departure, false for docking bay
		
	Returns:
		true if departure sequence started successfully
	"""
	if not ship or not state_manager:
		return false
	
	# Begin departure in state manager
	if not state_manager.begin_departure_sequence(departure_position, departure_cue, via_warp):
		return false
	
	# Start departure stage 1 timer
	_departure_timer.wait_time = departure_stage_duration
	_departure_timer.start()
	
	# Emit departure events
	_emit_lifecycle_event(LifecycleEvent.DEPARTURE_STAGE_1)
	ship_departure_started.emit(ship, 1)
	
	# Start departure effects
	_start_departure_effects(via_warp)
	
	return true

## Activate ship (make fully operational) (SHIP-004 AC2)
func activate_ship() -> bool:
	"""Activate ship to make it fully operational.
	
	Returns:
		true if ship was activated successfully
	"""
	if not ship or not state_manager:
		return false
	
	# Set state to active
	if not state_manager.set_ship_state(ShipStateManager.ShipState.ACTIVE):
		return false
	
	# Emit activation events
	_emit_lifecycle_event(LifecycleEvent.ACTIVATION)
	ship_activated.emit(ship)
	
	return true

## Trigger ship destruction sequence (SHIP-004 AC2)
func trigger_ship_destruction(damage_source: String = "") -> bool:
	"""Trigger ship destruction sequence with death roll and explosion.
	
	Args:
		damage_source: Description of what caused destruction
		
	Returns:
		true if destruction sequence started
	"""
	if not ship or not state_manager:
		return false
	
	# Check if ship is already dying or destroyed
	if state_manager.get_ship_state() == ShipStateManager.ShipState.DESTROYED:
		return false
	
	# Trigger destruction in state manager
	if not state_manager.trigger_destruction_sequence():
		return false
	
	# Start death roll timer
	_death_timer.wait_time = death_roll_duration
	_death_timer.start()
	
	# Emit destruction events
	_emit_lifecycle_event(LifecycleEvent.DESTRUCTION)
	ship_destroyed.emit(ship)
	
	# Start destruction effects
	_start_destruction_effects()
	
	return true

# ============================================================================
# LIFECYCLE SEQUENCE PROCESSING
# ============================================================================

## Process arrival stage timeout
func _on_arrival_timer_timeout() -> void:
	"""Handle arrival stage timer timeout."""
	if not state_manager:
		return
	
	var current_state: int = state_manager.get_ship_state()
	
	if current_state == ShipStateManager.ShipState.ARRIVING_STAGE_1:
		# Move to stage 2
		state_manager.set_ship_state(ShipStateManager.ShipState.ARRIVING_STAGE_2)
		
		# Start stage 2 timer
		_arrival_timer.wait_time = arrival_stage_duration
		_arrival_timer.start()
		
		# Emit stage 2 events
		_emit_lifecycle_event(LifecycleEvent.ARRIVAL_STAGE_2)
		ship_arrival_started.emit(ship, 2)
		
	elif current_state == ShipStateManager.ShipState.ARRIVING_STAGE_2:
		# Complete arrival
		state_manager.complete_arrival_sequence()

## Process departure stage timeout
func _on_departure_timer_timeout() -> void:
	"""Handle departure stage timer timeout."""
	if not state_manager:
		return
	
	var current_state: int = state_manager.get_ship_state()
	
	if current_state == ShipStateManager.ShipState.DEPARTING_STAGE_1:
		# Move to stage 2
		state_manager.set_ship_state(ShipStateManager.ShipState.DEPARTING_STAGE_2)
		
		# Start stage 2 timer
		_departure_timer.wait_time = departure_stage_duration
		_departure_timer.start()
		
		# Emit stage 2 events
		_emit_lifecycle_event(LifecycleEvent.DEPARTURE_STAGE_2)
		ship_departure_started.emit(ship, 2)
		
	elif current_state == ShipStateManager.ShipState.DEPARTING_STAGE_2:
		# Complete departure
		state_manager.complete_departure_sequence()

## Process death timer timeout
func _on_death_timer_timeout() -> void:
	"""Handle death timer timeout - move to explosion."""
	if not state_manager:
		return
	
	# Move to explosion state
	state_manager.set_combat_state(ShipStateManager.CombatState.EXPLODING)
	
	# Start cleanup timer
	_cleanup_timer.wait_time = explosion_cleanup_duration
	_cleanup_timer.start()

## Process cleanup timer timeout
func _on_cleanup_timer_timeout() -> void:
	"""Handle cleanup timer timeout - complete destruction."""
	if not state_manager:
		return
	
	# Move to cleanup state
	state_manager.set_combat_state(ShipStateManager.CombatState.CLEANUP)
	
	# Emit cleanup event
	_emit_lifecycle_event(LifecycleEvent.CLEANUP)
	ship_cleanup_completed.emit(ship)
	
	# Begin final cleanup
	_begin_final_cleanup()

# ============================================================================
# STATE CHANGE HANDLERS
# ============================================================================

## Handle ship state changes
func _on_ship_state_changed(old_state: int, new_state: int) -> void:
	"""Handle ship state changes from state manager."""
	match new_state:
		ShipStateManager.ShipState.ACTIVE:
			if old_state in [ShipStateManager.ShipState.ARRIVING_STAGE_1, ShipStateManager.ShipState.ARRIVING_STAGE_2]:
				# Arrival completed
				_emit_lifecycle_event(LifecycleEvent.ACTIVATION)
				ship_arrival_completed.emit(ship)
				ship_activated.emit(ship)
		
		ShipStateManager.ShipState.EXITED:
			# Departure completed
			_emit_lifecycle_event(LifecycleEvent.EXIT)
			ship_departure_completed.emit(ship)

## Handle arrival stage changes
func _on_arrival_stage_changed(stage: int) -> void:
	"""Handle arrival stage changes."""
	# Stage changes are handled by timer events
	pass

## Handle combat state changes
func _on_combat_state_changed(combat_state: int) -> void:
	"""Handle combat state changes."""
	match combat_state:
		ShipStateManager.CombatState.EXPLODING:
			_trigger_ship_explosion()

## Handle team changes
func _on_team_changed(old_team: int, new_team: int) -> void:
	"""Handle team assignment changes."""
	# Update any team-dependent systems
	_update_team_dependent_systems(new_team)

## Handle ship destroyed signal
func _on_ship_destroyed_signal(destroyed_ship: BaseShip) -> void:
	"""Handle ship destroyed signal from BaseShip."""
	if destroyed_ship == ship:
		trigger_ship_destruction()

# ============================================================================
# EFFECT TRIGGERS AND COORDINATION
# ============================================================================

## Start arrival effects
func _start_arrival_effects() -> void:
	"""Start arrival visual and audio effects."""
	# TODO: Integrate with effects system for warp-in effects
	# TODO: Play arrival music if not disabled
	
	# Temporary: Just enable ship visibility
	if ship:
		ship.visible = true

## Start departure effects
func _start_departure_effects(via_warp: bool) -> void:
	"""Start departure visual and audio effects.
	
	Args:
		via_warp: true for warp effects, false for docking bay effects
	"""
	# TODO: Integrate with effects system for departure effects
	# Different effects for warp vs docking bay departure
	
	if via_warp:
		# Warp-out effects
		pass
	else:
		# Docking bay departure effects
		pass

## Start destruction effects
func _start_destruction_effects() -> void:
	"""Start destruction visual and audio effects."""
	# TODO: Integrate with effects system for destruction effects
	# TODO: Play death scream if not disabled by ship flags
	
	# Start death roll behavior
	if ship and ship.physics_body:
		# Apply death roll rotation
		ship.physics_body.apply_torque_impulse(Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)))

## Trigger ship explosion
func _trigger_ship_explosion() -> void:
	"""Trigger ship explosion effects and cleanup."""
	# TODO: Integrate with effects system for explosion effects
	# TODO: Create debris if not vaporizing
	
	# Disable ship systems
	if ship:
		ship.is_disabled = true
		ship.visible = false  # Hide ship after explosion

## Begin final cleanup
func _begin_final_cleanup() -> void:
	"""Begin final cleanup after destruction."""
	# Remove ship from active systems
	if ship:
		# TODO: Remove from AI systems, mission tracking, etc.
		
		# Optionally queue ship for removal
		# ship.queue_free()  # Will be handled by ship manager
		pass

# ============================================================================
# MISSION SYSTEM INTEGRATION (SHIP-004 AC6)
# ============================================================================

## Emit lifecycle event for mission system
func _emit_lifecycle_event(event_type: int) -> void:
	"""Emit lifecycle event for mission system integration.
	
	Args:
		event_type: LifecycleEvent type
	"""
	if not mission_system_connection or not ship:
		return
	
	# Create event data
	var event_data: Dictionary = {
		"ship_name": ship.ship_name,
		"ship_team": state_manager.get_team() if state_manager else 0,
		"event_type": event_type,
		"timestamp": Time.get_ticks_msec() * 0.001,
		"ship_state": state_manager.get_ship_state() if state_manager else 0
	}
	
	# TODO: Send event to mission system
	# Example: MissionSystem.record_ship_event(event_data)

## Update team-dependent systems
func _update_team_dependent_systems(new_team: int) -> void:
	"""Update systems that depend on team assignment.
	
	Args:
		new_team: New team assignment
	"""
	# TODO: Update AI targeting systems
	# TODO: Update HUD team indicators
	# TODO: Update mission objective tracking
	pass

# ============================================================================
# SAVE/LOAD INTEGRATION (SHIP-004 AC7)
# ============================================================================

## Get save data for persistence
func get_save_data() -> Dictionary:
	"""Get lifecycle controller save data for persistence.
	
	Returns:
		Dictionary containing save data
	"""
	var save_data: Dictionary = {
		"controller_active": true,
		"arrival_stage_duration": arrival_stage_duration,
		"departure_stage_duration": departure_stage_duration,
		"death_roll_duration": death_roll_duration,
		"explosion_cleanup_duration": explosion_cleanup_duration
	}
	
	# Include state manager save data
	if state_manager:
		save_data["state_manager_data"] = state_manager.get_mission_save_data()
	
	# Include timer states
	save_data["timer_states"] = {
		"arrival_timer_active": not _arrival_timer.is_stopped(),
		"arrival_timer_remaining": _arrival_timer.time_left if not _arrival_timer.is_stopped() else 0.0,
		"departure_timer_active": not _departure_timer.is_stopped(),
		"departure_timer_remaining": _departure_timer.time_left if not _departure_timer.is_stopped() else 0.0,
		"death_timer_active": not _death_timer.is_stopped(),
		"death_timer_remaining": _death_timer.time_left if not _death_timer.is_stopped() else 0.0,
		"cleanup_timer_active": not _cleanup_timer.is_stopped(),
		"cleanup_timer_remaining": _cleanup_timer.time_left if not _cleanup_timer.is_stopped() else 0.0
	}
	
	return save_data

## Load save data from persistence
func load_save_data(save_data: Dictionary) -> bool:
	"""Load lifecycle controller save data from persistence.
	
	Args:
		save_data: Dictionary containing saved data
		
	Returns:
		true if data loaded successfully
	"""
	if not save_data or not save_data.get("controller_active", false):
		return false
	
	# Load configuration
	arrival_stage_duration = save_data.get("arrival_stage_duration", 2.5)
	departure_stage_duration = save_data.get("departure_stage_duration", 2.5)
	death_roll_duration = save_data.get("death_roll_duration", 3.0)
	explosion_cleanup_duration = save_data.get("explosion_cleanup_duration", 2.0)
	
	# Load state manager data
	if state_manager and save_data.has("state_manager_data"):
		state_manager.load_mission_save_data(save_data["state_manager_data"])
	
	# Restore timer states
	if save_data.has("timer_states"):
		var timer_states: Dictionary = save_data["timer_states"]
		
		if timer_states.get("arrival_timer_active", false):
			_arrival_timer.wait_time = timer_states.get("arrival_timer_remaining", arrival_stage_duration)
			_arrival_timer.start()
		
		if timer_states.get("departure_timer_active", false):
			_departure_timer.wait_time = timer_states.get("departure_timer_remaining", departure_stage_duration)
			_departure_timer.start()
		
		if timer_states.get("death_timer_active", false):
			_death_timer.wait_time = timer_states.get("death_timer_remaining", death_roll_duration)
			_death_timer.start()
		
		if timer_states.get("cleanup_timer_active", false):
			_cleanup_timer.wait_time = timer_states.get("cleanup_timer_remaining", explosion_cleanup_duration)
			_cleanup_timer.start()
	
	return true

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Get lifecycle status information
func get_lifecycle_status() -> Dictionary:
	"""Get comprehensive lifecycle status for debugging."""
	var status: Dictionary = {
		"ship_name": ship.ship_name if ship else "None",
		"controller_active": ship != null,
		"mission_integration": mission_system_connection,
		"sexp_integration": sexp_integration_enabled,
		"arrival_timer_active": not _arrival_timer.is_stopped(),
		"departure_timer_active": not _departure_timer.is_stopped(),
		"death_timer_active": not _death_timer.is_stopped(),
		"cleanup_timer_active": not _cleanup_timer.is_stopped()
	}
	
	# Include state manager status
	if state_manager:
		status["state_info"] = state_manager.get_state_info()
	
	return status

## Get debug information string
func debug_info() -> String:
	"""Get debug information string."""
	var ship_name: String = ship.ship_name if ship else "None"
	var state_name: String = ""
	var active_timers: Array[String] = []
	
	if state_manager:
		var current_state: int = state_manager.get_ship_state()
		state_name = ShipStateManager.ShipState.keys()[current_state]
	
	if not _arrival_timer.is_stopped():
		active_timers.append("Arrival")
	if not _departure_timer.is_stopped():
		active_timers.append("Departure")
	if not _death_timer.is_stopped():
		active_timers.append("Death")
	if not _cleanup_timer.is_stopped():
		active_timers.append("Cleanup")
	
	var timers_str: String = ",".join(active_timers) if active_timers.size() > 0 else "none"
	
	return "[Lifecycle:%s State:%s Timers:%s]" % [ship_name, state_name, timers_str]