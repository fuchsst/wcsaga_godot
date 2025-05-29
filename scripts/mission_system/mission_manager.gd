# scripts/mission_system/mission_manager.gd
# Singleton (Autoload) responsible for managing mission lifecycle, state, objects, events, goals.
# Corresponds to parts of missionparse.cpp, missiongoals.cpp, etc.
class_name MissionManager
extends Node

# --- Dependencies ---
const MissionData = preload("res://scripts/resources/mission_data.gd")
const ShipInstanceData = preload("res://scripts/resources/ship_instance_data.gd")
const WingInstanceData = preload("res://scripts/resources/wing_instance_data.gd")
const MissionObjectiveData = preload("res://scripts/resources/mission_objective_data.gd")
const MissionEventData = preload("res://scripts/resources/mission_event_data.gd")
# Preload other necessary resources/scripts
# const SEXPSystem = preload("res://scripts/scripting/sexp/sexp_system.gd") # Assuming singleton access via name
# const ObjectManager = preload("res://scripts/core_systems/object_manager.gd") # Assuming singleton access via name
# const GameManager = preload("res://scripts/core_systems/game_manager.gd") # Assuming singleton access via name
const MissionLoader = preload("mission_loader.gd")
const SpawnManager = preload("spawn_manager.gd") # Assuming helper node/script
const ArrivalDepartureSystem = preload("arrival_departure.gd") # Assuming helper node/script
const WCSConstants = preload("res://scripts/core/foundation/wcs_constants.gd")

# --- Signals ---
signal mission_started(mission_name: String, campaign_name: String) # Emitted when mission logic starts
signal mission_ended(mission_name: String, campaign_name: String)
signal objective_updated(objective_resource: MissionObjectiveData)
signal event_triggered(event_resource: MissionEventData)
signal reinforcement_available(reinforcement_name: String)

# --- State ---
var current_mission_data: MissionData = null
var mission_is_active: bool = false
var mission_start_time: float = 0.0

# Runtime tracking (consider if these should live here or in dedicated managers)
var active_ships: Dictionary = {} # signature -> ShipBase node
var active_wings: Dictionary = {} # wing_name -> Array[ShipBase node] ? Or Wing runtime data?
# TODO: Need robust way to track runtime status of goals/events if not modifying resources directly
var mission_goals_runtime: Array[MissionObjectiveData] = [] # Cloned resources with runtime status
var mission_events_runtime: Array[MissionEventData] = [] # Cloned resources with runtime status

# --- Helper Nodes/Systems (Optional - could be child nodes or separate singletons) ---
var spawn_manager: SpawnManager
var arrival_departure_system: ArrivalDepartureSystem

# --- Godot Lifecycle ---
func _ready() -> void:
	print("MissionManager initialized.")
	# Instantiate helper nodes if they are children (assuming they are added in the editor)
	spawn_manager = get_node_or_null("SpawnManager") as SpawnManager
	arrival_departure_system = get_node_or_null("ArrivalDepartureSystem") as ArrivalDepartureSystem
	if not is_instance_valid(spawn_manager):
		printerr("MissionManager: SpawnManager node not found! Creating dynamically.")
		# Optionally create dynamically:
		spawn_manager = SpawnManager.new()
		spawn_manager.name = "SpawnManager" # Assign name for clarity
		add_child(spawn_manager)
	if not is_instance_valid(arrival_departure_system):
		printerr("MissionManager: ArrivalDepartureSystem node not found! Creating dynamically.")
		# Optionally create dynamically:
		arrival_departure_system = ArrivalDepartureSystem.new()
		arrival_departure_system.name = "ArrivalDepartureSystem" # Assign name
		add_child(arrival_departure_system)

	# Pass references if needed
	if is_instance_valid(spawn_manager):
		spawn_manager.mission_manager = self
	if is_instance_valid(arrival_departure_system):
		arrival_departure_system.set_managers(self, spawn_manager)


func _physics_process(delta: float) -> void:
	if not mission_is_active:
		return

	# --- Core Mission Loop ---
	# 1. Evaluate Arrivals/Departures
	_check_arrivals(delta)
	_check_departures(delta)

	# 2. Evaluate Mission Events
	_evaluate_events(delta)

	# 3. Evaluate Mission Goals
	_evaluate_goals(delta)

	# 4. Check Mission End Conditions? (Or handle via events/goals)


# --- Public API ---

func load_mission(mission_resource_path: String) -> bool:
	print("MissionManager: Loading mission from path: ", mission_resource_path)
	if mission_is_active:
		end_mission() # End previous mission if any

	var loaded_data = load(mission_resource_path)
	if not loaded_data is MissionData:
		printerr("MissionManager: Failed to load mission data or incorrect type at path: ", mission_resource_path)
		current_mission_data = null
		return false

	current_mission_data = loaded_data as MissionData
	print("MissionManager: Successfully loaded mission '%s'" % current_mission_data.mission_name)

	# TODO: Initialize mission state based on current_mission_data
	# - Reset runtime goal/event status
	# - Clear active ship/wing lists
	# - Set up initial SEXP variables (call SexpVariableManager)
	# - Handle initial docking (call DockingManager or similar)
	# - Reset runtime goal/event status by cloning
	mission_goals_runtime = []
	for goal_res in current_mission_data.goals:
		var runtime_goal = goal_res.duplicate() as MissionObjectiveData
		if runtime_goal:
			runtime_goal.satisfied = GlobalConstants.GOAL_INCOMPLETE # Reset status
			mission_goals_runtime.append(runtime_goal)
		else:
			printerr("MissionManager: Failed to duplicate MissionObjectiveData: ", goal_res.name)
	mission_events_runtime = []
	for event_res in current_mission_data.events:
		var runtime_event = event_res.duplicate() as MissionEventData
		if runtime_event:
			# Reset runtime fields
			runtime_event.result = false
			runtime_event.flags = 0
			runtime_event.count = 0
			runtime_event.satisfied_time = 0.0
			runtime_event.born_on_date = 0
			runtime_event.timestamp = -1
			mission_events_runtime.append(runtime_event)
		else:
			printerr("MissionManager: Failed to duplicate MissionEventData: ", event_res.name)

	# - Clear active ship/wing lists
	active_ships.clear()
	active_wings.clear()

	# - Set up initial SEXP variables (call SexpVariableManager)
	if Engine.has_singleton("SexpVariableManager"):
		Engine.get_singleton("SexpVariableManager").clear_mission_variables()
		for var_data in current_mission_data.variables:
			# Need to parse initial_value based on type_flags
			var value = SexpVariableManager.parse_initial_value(var_data.initial_value, var_data.type_flags) # Assuming method exists
			Engine.get_singleton("SexpVariableManager").set_variable(var_data.variable_name, value, var_data.type_flags)
	else:
		push_warning("MissionManager: SexpVariableManager not found.")


	# - Handle initial docking (call DockingManager or similar)
	# TODO: Implement initial docking logic - needs DockingManager

	# - Prepare arrival list (call ArrivalDepartureSystem)
	# TODO: Pass necessary info (ships/wings not yet arrived) to ArrivalDepartureSystem
	# if is_instance_valid(arrival_departure_system):
	#	 arrival_departure_system.prepare_arrivals(current_mission_data) # Example

	# - Spawn initial objects (call SpawnManager)
	if is_instance_valid(spawn_manager):
		var pending_arrivals = [] # Store ships/wings not spawning immediately

		# Spawn initial ships
		for ship_instance_data_res in current_mission_data.ships:
			# Clone the resource to avoid modifying the original mission data
			var ship_instance_data = ship_instance_data_res.duplicate() as ShipInstanceData
			if not ship_instance_data: continue

			var should_spawn_now = false
			var is_reinforcement = (ship_instance_data.flags & GlobalConstants.P_SF_REINFORCEMENT) != 0

			# Evaluate arrival cue immediately if possible (basic check for always true/false)
			var cue_result = true # Default to true if no cue
			if ship_instance_data.arrival_cue_sexp != null:
				if Engine.has_singleton("SEXPSystem"):
					var context = {} # Build context if needed
					# Check for simple true/false first
					if SEXPSystem.is_known_true(ship_instance_data.arrival_cue_sexp):
						cue_result = true
					elif SEXPSystem.is_known_false(ship_instance_data.arrival_cue_sexp):
						cue_result = false
					else:
						# Complex cue, let ArrivalDepartureSystem handle it later
						cue_result = false # Assume false for now if complex
				else:
					push_warning("MissionManager: SEXPSystem not found for arrival cue check.")
					cue_result = false # Cannot evaluate

			if cue_result and ship_instance_data.arrival_delay_seconds <= 0 and not is_reinforcement:
				should_spawn_now = true

			if should_spawn_now:
				var spawned_ship = spawn_manager.spawn_ship(ship_instance_data)
				# TODO: Add spawned_ship to active_ships dictionary?
			else:
				pending_arrivals.append(ship_instance_data) # Add to pending list for ArrivalDepartureSystem

		# Spawn initial wing waves
		for wing_instance_data_res in current_mission_data.wings:
			var wing_instance_data = wing_instance_data_res.duplicate() as WingInstanceData
			if not wing_instance_data: continue

			var should_spawn_now = false
			var is_reinforcement = (wing_instance_data.flags & GlobalConstants.WF_REINFORCEMENT) != 0 # Assuming flag defined

			var cue_result = true
			if wing_instance_data.arrival_cue_sexp != null:
				if Engine.has_singleton("SEXPSystem"):
					var context = {}
					if SEXPSystem.is_known_true(wing_instance_data.arrival_cue_sexp):
						cue_result = true
					elif SEXPSystem.is_known_false(wing_instance_data.arrival_cue_sexp):
						cue_result = false
					else:
						cue_result = false
				else:
					push_warning("MissionManager: SEXPSystem not found for arrival cue check.")
					cue_result = false

			if cue_result and wing_instance_data.arrival_delay_seconds <= 0 and not is_reinforcement:
				should_spawn_now = true

			if should_spawn_now:
				# Spawn the first wave immediately
				var spawned_wing_ships = spawn_manager.spawn_wing_wave(wing_instance_data, 1, wing_instance_data.ship_names.size())
				# TODO: Add spawned ships to active lists?
			else:
				pending_arrivals.append(wing_instance_data) # Add wing to pending list

		# Pass pending arrivals to the arrival system
		if is_instance_valid(arrival_departure_system):
			arrival_departure_system.set_pending_arrivals(pending_arrivals) # Assuming method exists
	else:
		printerr("MissionManager: SpawnManager not valid during mission load.")


	return true


func start_mission() -> void:
	if current_mission_data == null:
		printerr("MissionManager: Cannot start mission, no mission data loaded.")
		return
	if mission_is_active:
		printerr("MissionManager: Mission already active.")
		return

	print("MissionManager: Starting mission '%s'" % current_mission_data.mission_name)
	mission_is_active = true
	mission_start_time = Time.get_ticks_msec() / 1000.0 # Or use GameManager time?

	# TODO: Perform any immediate start actions (after initial spawns)
	# - Play starting music (call MusicManager)
	# - Display starting messages (call MessageManager)

	# - Trigger MISSIONSTART hooks (call ScriptSystem)
	if Engine.has_singleton("ScriptSystem"):
		var context = {"mission_name": current_mission_data.mission_name, "campaign_name": ""} # TODO: Get campaign name
		# Ensure ScriptSystem is ready before calling
		await get_tree().process_frame # Wait a frame if ScriptSystem might not be ready
		if Engine.has_singleton("ScriptSystem"): # Check again after waiting
			ScriptSystem.get_script_state().run_condition(GlobalConstants.HookActionType.MISSIONSTART, context)
		else:
			push_warning("MissionManager: ScriptSystem not found after waiting frame.")

	emit_signal("mission_started", current_mission_data.mission_name, "") # TODO: Get campaign name


func end_mission() -> void:
	if not mission_is_active:
		return

	print("MissionManager: Ending mission '%s'" % current_mission_data.mission_name)
	var mission_name = current_mission_data.mission_name if current_mission_data else "Unknown"

	# TODO: Perform mission cleanup
	# - Destroy/remove mission objects (call ObjectManager.clear_mission_objects()?)
	if Engine.has_singleton("ObjectManager"):
		ObjectManager.clear_all_objects() # Maybe too broad? Need specific cleanup.
	# - Stop mission-specific sounds/music (call SoundManager/MusicManager)
	# - Clear runtime state (goals, events, active lists)
	if is_instance_valid(mission_goal_manager): mission_goal_manager.clear_runtime_goals()
	if is_instance_valid(mission_event_manager): mission_event_manager.clear_runtime_events()
	mission_goals_runtime.clear() # Clear local reference if kept
	mission_events_runtime.clear() # Clear local reference if kept
	active_ships.clear()
	active_wings.clear()

	# - Trigger MISSIONEND hooks (call ScriptSystem)
	if Engine.has_singleton("ScriptSystem"):
		var context = {"mission_name": mission_name, "campaign_name": ""} # TODO: Get campaign name
		ScriptSystem.get_script_state().run_condition(GlobalConstants.HookActionType.MISSIONEND, context)

	mission_is_active = false
	current_mission_data = null # Release reference to the loaded data

	emit_signal("mission_ended", mission_name, "") # TODO: Get campaign name


# --- Internal Logic ---

func _check_arrivals(delta: float) -> void:
	# TODO: Implement logic to check arrival cues (SEXP) and delays
	# - Iterate through ships/wings in MissionData not yet arrived (handled by ArrivalDepartureSystem)
	# - Evaluate arrival_cue_sexp using SEXPSystem (handled by ArrivalDepartureSystem)
	# - If true and delay expired, trigger spawn via SpawnManager (handled by ArrivalDepartureSystem)
	# - Handle reinforcements (check availability, trigger spawn, send messages)
	if is_instance_valid(arrival_departure_system):
		arrival_departure_system.update_arrivals_departures(delta) # Delegate checks
	# TODO: Handle reinforcement availability signals/checks here?
	pass


func _check_departures(delta: float) -> void:
	# TODO: Implement logic to check departure cues (SEXP) and delays
	# - Iterate through active ships/wings (handled by ArrivalDepartureSystem)
	# - Evaluate departure_cue_sexp using SEXPSystem (handled by ArrivalDepartureSystem)
	# - If true and delay expired, trigger departure sequence (AI warp out, despawn) (handled by ArrivalDepartureSystem)
	# ArrivalDepartureSystem handles the checks, MissionManager might react to departure signals if needed.
	pass


func _evaluate_events(delta: float) -> void:
	if current_mission_data == null or mission_events_runtime.is_empty(): return

	for i in range(mission_events_runtime.size()):
		var event: MissionEventData = mission_events_runtime[i] # Use the runtime copy

		# Skip already completed/failed events or those on cooldown
		if event.formula_sexp == null: # Event has already run its course or was invalid (check runtime copy)
			continue
		if event.timestamp != -1 and Time.get_ticks_msec() < event.timestamp:
			continue

		# TODO: Evaluate event.formula_sexp using SEXPSystem
		var context = {} # Build context for SEXP evaluation
		var result = false # Placeholder
		if Engine.has_singleton("SEXPSystem"):
			result = SEXPSystem.evaluate_expression(event.formula_sexp, context)
		else:
			push_warning("MissionManager: SEXPSystem not found for event evaluation.")


		var old_result = event.result # Check runtime value
		event.result = result # Update runtime value

		if result and not old_result: # Event just became true
			event.satisfied_time = GameManager.get_mission_time() if Engine.has_singleton("GameManager") else 0.0 # Use GameManager time
			event.born_on_date = Time.get_ticks_msec() if event.born_on_date == 0 else event.born_on_date # Set born date if not already set
			# TODO: Play directive sound? (SoundManager.play_sound(...))
			# TODO: Add score? (ScoringManager.add_mission_score(...))
			emit_signal("event_triggered", event) # Emit with the runtime event object
			print("MissionManager: Event '%s' triggered." % (event.name if not event.name.is_empty() else str(i)))

			# Handle repeat/trigger counts (modify runtime event)
			if event.flags & GlobalConstants.MEF_USING_TRIGGER_COUNT: # Assuming flag defined
				if event.trigger_count > 0:
					event.trigger_count -= 1
					if event.trigger_count == 0:
						# Mark as done by clearing the formula reference in the runtime copy
						event.formula_sexp = null
						event.timestamp = -1
					else:
						# Reset timestamp if interval exists
						if event.interval_seconds >= 0:
							event.timestamp = Time.get_ticks_msec() + event.interval_seconds * 1000
						else:
							# If no interval, needs immediate re-evaluation unless condition stays true
							event.timestamp = -1
			elif event.repeat_count > 0:
				event.repeat_count -= 1
				if event.repeat_count == 0:
					event.formula_sexp = null # Mark as done
					event.timestamp = -1
				else:
					# Reset timestamp if interval exists
					if event.interval_seconds >= 0:
						event.timestamp = Time.get_ticks_msec() + event.interval_seconds * 1000
					else:
						event.timestamp = -1
			elif event.repeat_count == -1: # Infinite repeat
				# Reset timestamp if interval exists
				if event.interval_seconds >= 0:
					event.timestamp = Time.get_ticks_msec() + event.interval_seconds * 1000
				else:
					# If no interval, needs immediate re-evaluation unless condition stays true
					event.timestamp = -1

		elif not result and old_result: # Event just became false
			# Reset timestamp if it was interval-based and repeating infinitely
			# Only reset if the interval was actually set previously
			if event.repeat_count == -1 and event.interval_seconds >= 0 and event.timestamp != -1:
				event.timestamp = Time.get_ticks_msec() + event.interval_seconds * 1000
			elif event.timestamp != -1: # If not infinite repeat, ensure timestamp is cleared unless interval pending
				# Clear timestamp only if there's no interval to wait for
				if event.interval_seconds < 0:
					event.timestamp = -1


func _evaluate_goals(delta: float) -> void:
	if current_mission_data == null or mission_goals_runtime.is_empty(): return

	for i in range(mission_goals_runtime.size()):
		var goal: MissionObjectiveData = mission_goals_runtime[i] # Use the runtime copy

		# Skip already completed/failed goals or invalid ones
		if goal.satisfied != GlobalConstants.GOAL_INCOMPLETE:
			continue
		if goal.type & GlobalConstants.INVALID_GOAL: # Check invalid flag
			continue
		if goal.formula_sexp == null:
			continue

		# TODO: Evaluate goal.formula_sexp using SEXPSystem
		var context = {} # Build context for SEXP evaluation
		var result = false # Placeholder
		var is_known_false = false # Placeholder
		if Engine.has_singleton("SEXPSystem"):
			result = SEXPSystem.evaluate_expression(goal.formula_sexp, context)
			is_known_false = SEXPSystem.is_known_false(goal.formula_sexp) # Check if formula is definitively false
		else:
			push_warning("MissionManager: SEXPSystem not found for goal evaluation.")


		if is_known_false:
			_set_goal_status(goal, GlobalConstants.GOAL_FAILED) # Use runtime goal object
		elif result:
			_set_goal_status(goal, GlobalConstants.GOAL_COMPLETE) # Use runtime goal object


func _set_goal_status(goal: MissionObjectiveData, new_status: int):
	# Modifies the RUNTIME goal object
	if goal.satisfied == new_status:
		return # No change

	goal.satisfied = new_status
	emit_signal("objective_updated", goal) # Emit with the runtime goal object
	print("MissionManager: Goal '%s' status changed to %d" % [goal.name, new_status])

	# TODO: Add to mission log (call MissionLogManager)
	if Engine.has_singleton("MissionLogManager"):
		var log_type = GlobalConstants.LOG_GOAL_SATISFIED if new_status == GlobalConstants.GOAL_COMPLETE else GlobalConstants.LOG_GOAL_FAILED
		MissionLogManager.add_entry(log_type, goal.name, "", mission_goals_runtime.find(goal)) # Pass index

	# TODO: Play success/fail music/sound (call MusicManager/SoundManager)
	# TODO: Add score if completed (call ScoringManager)
	if new_status == GlobalConstants.GOAL_COMPLETE and Engine.has_singleton("ScoringManager"):
		# Need access to player data to add score
		# ScoringManager.add_mission_score(player_data_ref, goal.score) # Example
		pass

# --- Helper Functions ---
# TODO: Add helpers for finding active ships/wings, getting runtime data, etc.
