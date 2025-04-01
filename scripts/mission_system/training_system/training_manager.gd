# scripts/mission_system/training_system/training_manager.gd
# Singleton or helper node responsible for managing training mission logic.
# Handles training directives, messages, and failure conditions.
# Corresponds to missiontraining.cpp logic.
class_name TrainingManager
extends Node

# --- Dependencies ---
# Access MissionManager, MessageManager, HUDManager via singletons or references

# --- Constants ---
const MAX_TRAINING_MESSAGE_QUEUE = 40 # From missiontraining.cpp

# --- State ---
var training_failure: bool = false
var training_message_queue: Array[Dictionary] = [] # Stores queued training messages
# Keys: message_data, timestamp, length, special_message_text

# --- Nodes ---
# Reference to the HUD directives gauge (set externally or found)
var hud_directives_gauge = null # Example: %HUDDirectivesGauge

func _ready() -> void:
	print("TrainingManager initialized.")
	# TODO: Get reference to hud_directives_gauge

func _physics_process(delta: float) -> void:
	if training_failure:
		return

	# Check objectives (update HUD directives display)
	_check_objectives()

	# Check and display queued training messages
	_check_message_queue()


# --- Public API ---

func mission_init() -> void:
	print("TrainingManager: Initializing for new training mission.")
	training_failure = false
	training_message_queue.clear()
	# TODO: Reset HUD directives gauge


func mission_shutdown() -> void:
	print("TrainingManager: Shutting down training mission state.")
	# TODO: Stop any playing training messages/sounds
	training_message_queue.clear()


func fail_training() -> void:
	if not training_failure:
		print("TrainingManager: Training mission failed!")
		training_failure = true
		# TODO: Display failure message (via MessageManager?)
		# TODO: Potentially end the mission (call MissionManager?)


func queue_training_message(message_name: String, timestamp_ms: int, length_ms: int = -1) -> void:
	if training_message_queue.size() >= MAX_TRAINING_MESSAGE_QUEUE:
		printerr("TrainingManager: Training message queue full.")
		return

	# TODO: Find MessageData resource by message_name
	var message_data: MessageData = null # Placeholder
	# message_data = MessageManager.find_message_data(message_name) # Assuming method exists

	if message_data == null and message_name != "none":
		printerr("TrainingManager: Could not find message data for: ", message_name)
		return

	var queue_entry: Dictionary = {}
	queue_entry["message_data"] = message_data # Can be null if message_name is "none"
	queue_entry["timestamp"] = timestamp_ms
	queue_entry["length"] = length_ms
	queue_entry["special_message_text"] = "" # Placeholder for potential SEXP replacement

	# TODO: Perform SEXP variable replacement on message text if needed
	# var text_to_check = message_data.message_text if message_data else ""
	# if SexpVariableManager.text_has_variables(text_to_check):
	#	 queue_entry["special_message_text"] = SexpVariableManager.replace_variables(text_to_check)

	training_message_queue.append(queue_entry)
	# Training queue doesn't seem to be sorted by priority in original code


# --- Internal Logic ---

func _check_objectives() -> void:
	# Corresponds to training_check_objectives()
	# This function updates the HUD directives gauge based on the status
	# of mission events marked as objectives.

	if not is_instance_valid(hud_directives_gauge):
		# Try to find it if not set
		if Engine.has_singleton("HUDManager"):
			hud_directives_gauge = HUDManager.get_directives_gauge() # Assuming method exists
		if not is_instance_valid(hud_directives_gauge):
			# Still not found, can't update
			# printerr("TrainingManager: HUD Directives Gauge node not found.")
			return

	# TODO: Get current mission events from MissionManager
	var mission_events: Array[MissionEventData] = []
	if Engine.has_singleton("MissionManager") and MissionManager.current_mission_data:
		mission_events = MissionManager.current_mission_data.events

	var directive_lines: Array[Dictionary] = [] # Store lines to display {text: String, status: int, key_text: String}

	for event_data in mission_events:
		# Check if this event should be displayed as a directive
		if event_data.objective_text.is_empty():
			continue

		# Check if event is currently active or recently completed/failed
		var status = _get_event_display_status(event_data)
		if status != GlobalConstants.EVENT_UNBORN: # Assuming enum defined
			var line_entry = {
				"text": event_data.objective_text,
				"status": status,
				"key_text": event_data.objective_key_text,
				"born_on_date": event_data.born_on_date # For sorting
			}
			# TODO: Handle event count display "[%d]" if event_data.count > 0
			directive_lines.append(line_entry)

	# TODO: Sort directive_lines based on born_on_date (similar to sort_training_objectives)
	# TODO: Handle scrolling/display limits (show only top N directives)
	# TODO: Pass the sorted/filtered directive_lines to the hud_directives_gauge node for rendering
	# hud_directives_gauge.update_directives(directive_lines) # Assuming method exists


func _get_event_display_status(event_data: MissionEventData) -> int:
	# Simplified version of mission_get_event_status, focused on display state
	if event_data.flags & GlobalConstants.MEF_DIRECTIVE_SPECIAL:
		# Handle special directive logic if needed
		pass

	if event_data.flags & GlobalConstants.MEF_CURRENT: # Assuming flag defined
		if event_data.result:
			# Check if recently satisfied
			var time_since_satisfied = (GameManager.get_mission_time() if Engine.has_singleton("GameManager") else 0.0) - event_data.satisfied_time
			if time_since_satisfied < 5.0: # Example: Show as satisfied for 5 seconds
				return GlobalConstants.EVENT_SATISFIED
			else:
				return GlobalConstants.EVENT_UNBORN # Don't display old satisfied directives? Check FS2 behavior.
		elif event_data.formula_sexp == null: # Condition evaluated to known false
			# Check if recently failed
			var time_since_failed = (GameManager.get_mission_time() if Engine.has_singleton("GameManager") else 0.0) - event_data.satisfied_time # satisfied_time used for failure time too?
			if time_since_failed < 7.0: # Example: Show as failed for 7 seconds
				return GlobalConstants.EVENT_FAILED
			else:
				return GlobalConstants.EVENT_UNBORN # Don't display old failed directives?
		else:
			return GlobalConstants.EVENT_CURRENT # Still active and not resolved
	else:
		return GlobalConstants.EVENT_UNBORN # Not yet active


func _check_message_queue() -> void:
	# Corresponds to message_training_queue_check()
	var current_time_ms = Time.get_ticks_msec()
	var i = 0
	while i < training_message_queue.size():
		var entry = training_message_queue[i]
		if current_time_ms >= entry["timestamp"]:
			# Time to display this message
			_display_training_message(entry)
			training_message_queue.remove_at(i)
			# Don't increment i, as the next element shifted into the current index
		else:
			i += 1


func _display_training_message(entry: Dictionary) -> void:
	# Corresponds to message_training_setup() and parts of message_training_display()
	var message_data: MessageData = entry["message_data"]
	var length_ms: int = entry["length"]
	var special_text: String = entry["special_message_text"]

	if message_data == null: # Handle "none" message to stop current message
		# TODO: Stop current training voice/text display
		print("TrainingManager: Stopping current training message.")
		return

	var final_text = special_text if not special_text.is_empty() else message_data.message_text

	# TODO: Translate tokens in final_text (key bindings, etc.)
	# final_text = _translate_training_tokens(final_text)

	# TODO: Add message to HUD scrollback (call HUDManager)
	# HUDManager.add_to_scrollback(final_text, HUD_SOURCE_TRAINING) # Assuming source enum

	# TODO: Display message in dedicated training message area (if different from scrollback)
	# - Process bold tags <b></b>
	# - Handle text wipe effect
	# - Play voice associated with message_data (call SoundManager or MessageManager?)
	# - Set timer to hide message after voice or calculated duration

	print("TrainingManager: Displaying training message: ", final_text)


# func _translate_training_tokens(text: String) -> String:
	# TODO: Implement token replacement logic similar to message_translate_tokens
	# - Find $key$ and #token# patterns
	# - Call input system to get bound key names for $key$
	# - Call helper for #token# (e.g., #wp# for waypoint number)
	# return translated_text
