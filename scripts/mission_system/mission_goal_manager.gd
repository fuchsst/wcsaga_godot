# scripts/mission_system/mission_goal_manager.gd
# Manages the evaluation and state of mission goals during gameplay.
class_name MissionGoalManager
extends Node

# --- Dependencies ---
const MissionObjectiveData = preload("res://scripts/resources/mission/mission_objective_data.gd")
const WCSConstants = preload("res://scripts/core/foundation/wcs_constants.gd")
# Access MissionLogManager, ScoringManager, MusicManager, SoundManager, SEXPSystem via singletons

# --- State ---
var mission_goals_runtime: Array[MissionObjectiveData] = [] # Holds the runtime copies of goals

# --- Signals ---
signal objective_updated(objective_resource: MissionObjectiveData) # Emitted when status changes

func _ready() -> void:
	print("MissionGoalManager initialized.")

# Called by MissionManager during mission load
func set_runtime_goals(runtime_goals: Array[MissionObjectiveData]) -> void:
	mission_goals_runtime = runtime_goals

# Called by MissionManager in _physics_process
func evaluate_goals(delta: float) -> void:
	if mission_goals_runtime.is_empty(): return

	for i in range(mission_goals_runtime.size()):
		var goal: MissionObjectiveData = mission_goals_runtime[i] # Use the runtime copy

		# Skip already completed/failed goals or invalid ones
		if goal.satisfied != GlobalConstants.GOAL_INCOMPLETE:
			continue
		# Check invalid flag using bitwise AND
		if goal.type & GlobalConstants.INVALID_GOAL:
			continue
		if goal.formula_sexp == null:
			continue

		# Evaluate goal.formula_sexp using SEXPSystem
		var context = {} # Build context for SEXP evaluation
		var result = false # Placeholder
		var is_known_false = false # Placeholder
		if Engine.has_singleton("SEXPSystem"):
			result = SEXPSystem.evaluate_expression(goal.formula_sexp, context)
			is_known_false = SEXPSystem.is_known_false(goal.formula_sexp) # Check if formula is definitively false
		else:
			push_warning("MissionGoalManager: SEXPSystem not found for goal evaluation.")


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
	print("MissionGoalManager: Goal '%s' status changed to %d" % [goal.name, new_status])

	# Add to mission log (call MissionLogManager)
	if Engine.has_singleton("MissionLogManager"):
		var log_type = GlobalConstants.LOG_GOAL_SATISFIED if new_status == GlobalConstants.GOAL_COMPLETE else GlobalConstants.LOG_GOAL_FAILED
		# Find the index of the goal in the runtime array to pass to the log
		var goal_index = mission_goals_runtime.find(goal)
		MissionLogManager.add_entry(log_type, goal.name, "", goal_index) # Pass index
	else:
		push_warning("MissionGoalManager: MissionLogManager not found.")


	# Play success/fail music/sound (call MusicManager/SoundManager)
	# TODO: Implement music/sound calls based on goal type and status

	# Add score if completed (call ScoringManager)
	if new_status == GlobalConstants.GOAL_COMPLETE:
		if Engine.has_singleton("ScoringManager"):
			# Need access to player data to add score
			# ScoringManager.add_mission_score(player_data_ref, goal.score) # Example
			pass # Placeholder for score addition
		else:
			push_warning("MissionGoalManager: ScoringManager not found.")


func clear_runtime_goals() -> void:
	mission_goals_runtime.clear()

# --- Public Helper Functions ---

# Checks if all primary goals are complete, failed, or still incomplete
func evaluate_primary_goals_status() -> int:
	var primary_goals_status = GlobalConstants.PRIMARY_GOALS_COMPLETE # Assume complete initially
	var found_primary = false

	for goal in mission_goals_runtime:
		# Check if it's a primary goal (ignoring the INVALID_GOAL flag)
		if (goal.type & GlobalConstants.GOAL_TYPE_MASK) == GlobalConstants.PRIMARY_GOAL:
			found_primary = true
			if goal.satisfied == GlobalConstants.GOAL_INCOMPLETE:
				return GlobalConstants.PRIMARY_GOALS_INCOMPLETE # If any primary is incomplete, return immediately
			elif goal.satisfied == GlobalConstants.GOAL_FAILED:
				primary_goals_status = GlobalConstants.PRIMARY_GOALS_FAILED # Mark as failed, but continue checking others

	if not found_primary:
		# If no primary goals were found, consider it incomplete? Or complete? Check FS2 behavior.
		return GlobalConstants.PRIMARY_GOALS_INCOMPLETE # Defaulting to incomplete if none exist

	return primary_goals_status


# Checks if all primary and secondary goals are met (not failed or incomplete)
func mission_goals_met() -> bool:
	for goal in mission_goals_runtime:
		if goal.type & GlobalConstants.INVALID_GOAL:
			continue

		var goal_type = goal.type & GlobalConstants.GOAL_TYPE_MASK
		if goal_type == GlobalConstants.PRIMARY_GOAL or goal_type == GlobalConstants.SECONDARY_GOAL:
			if goal.satisfied != GlobalConstants.GOAL_COMPLETE:
				return false # Found an incomplete or failed primary/secondary goal

	return true # All primary/secondary goals are complete


# Fails all currently incomplete goals
func fail_incomplete_goals() -> void:
	for goal in mission_goals_runtime:
		if goal.satisfied == GlobalConstants.GOAL_INCOMPLETE:
			_set_goal_status(goal, GlobalConstants.GOAL_FAILED)


# Marks a specific goal as invalid (won't be evaluated)
func invalidate_goal(goal_name: String) -> void:
	for goal in mission_goals_runtime:
		if goal.name == goal_name:
			if not (goal.type & GlobalConstants.INVALID_GOAL):
				goal.type |= GlobalConstants.INVALID_GOAL
				emit_signal("objective_updated", goal) # Notify change
				# TODO: Send multiplayer update if needed
			return


# Marks a specific goal as valid (will be evaluated)
func validate_goal(goal_name: String) -> void:
	for goal in mission_goals_runtime:
		if goal.name == goal_name:
			if goal.type & GlobalConstants.INVALID_GOAL:
				goal.type &= ~GlobalConstants.INVALID_GOAL
				emit_signal("objective_updated", goal) # Notify change
				# TODO: Send multiplayer update if needed
			return
