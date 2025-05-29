# scripts/mission_system/mission_event_manager.gd
# Manages the evaluation and state of mission events during gameplay.
class_name MissionEventManager
extends Node

# --- Dependencies ---
const MissionEventData = preload("res://scripts/resources/mission/mission_event_data.gd")
const WCSConstants = preload("res://scripts/core/foundation/wcs_constants.gd")
# Access GameManager, ScoringManager, SEXPSystem via singletons

# --- State ---
var mission_events_runtime: Array[MissionEventData] = [] # Holds the runtime copies of events

# --- Signals ---
signal event_triggered(event_resource: MissionEventData)

func _ready() -> void:
	print("MissionEventManager initialized.")

# Called by MissionManager during mission load
func set_runtime_events(runtime_events: Array[MissionEventData]) -> void:
	mission_events_runtime = runtime_events

# Called by MissionManager in _physics_process
func evaluate_events(delta: float) -> void:
	if mission_events_runtime.is_empty(): return

	for i in range(mission_events_runtime.size()):
		var event: MissionEventData = mission_events_runtime[i] # Use the runtime copy

		# Skip already completed/failed events or those on cooldown
		if event.formula_sexp == null: # Event has already run its course or was invalid (check runtime copy)
			continue
		if event.timestamp != -1 and Time.get_ticks_msec() < event.timestamp:
			continue

		# Evaluate event.formula_sexp using SEXPSystem
		var context = {} # Build context for SEXP evaluation
		var result = false # Placeholder
		if Engine.has_singleton("SEXPSystem"):
			result = SEXPSystem.evaluate_expression(event.formula_sexp, context)
		else:
			push_warning("MissionEventManager: SEXPSystem not found for event evaluation.")


		var old_result = event.result # Check runtime value
		event.result = result # Update runtime value

		if result and not old_result: # Event just became true
			event.satisfied_time = GameManager.get_mission_time() if Engine.has_singleton("GameManager") else 0.0 # Use GameManager time
			event.born_on_date = Time.get_ticks_msec() if event.born_on_date == 0 else event.born_on_date # Set born date if not already set

			# TODO: Play directive sound? (SoundManager.play_sound(...))
			# TODO: Add score? (ScoringManager.add_mission_score(...))
			emit_signal("event_triggered", event) # Emit with the runtime event object
			print("MissionEventManager: Event '%s' triggered." % (event.name if not event.name.is_empty() else str(i)))

			# Handle repeat/trigger counts (modify runtime event)
			# Assuming MEF_USING_TRIGGER_COUNT is defined in GlobalConstants
			if event.flags & GlobalConstants.MEF_USING_TRIGGER_COUNT:
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

func clear_runtime_events() -> void:
	mission_events_runtime.clear()
