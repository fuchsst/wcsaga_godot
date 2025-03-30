# scripts/ai/behaviors/approach_target.gd
# BTAction: Steers the agent towards the target position.
# Reads "target_position" from the blackboard.
# Writes "desired_movement" and "desired_rotation" to the blackboard.
class_name BTActionApproachTarget extends BTAction

# Optional: Distance at which the action returns SUCCESS.
@export var arrival_distance: float = 50.0
# Optional: Speed multiplier (adjusts how fast to approach).
@export var speed_multiplier: float = 1.0

# Called every frame while the action is running.
func _tick() -> Status:
	# Agent is the Node executing the behavior tree (e.g., the ShipBase node).
	if agent == null:
		printerr("BTActionApproachTarget: Agent is null!")
		return FAILURE
	
	# Ensure the agent is a Node3D to access global_position
	if not agent is Node3D:
		printerr("BTActionApproachTarget: Agent must be a Node3D!")
		return FAILURE

	# Get target position from blackboard. Default to agent's position if not set.
	var target_pos = blackboard.get_var("target_position", agent.global_position)
	var current_pos = agent.global_position

	var distance_to_target = current_pos.distance_to(target_pos)

	# Check if we have arrived.
	if distance_to_target <= arrival_distance:
		# Stop movement by setting desired velocity to zero.
		blackboard.set_var("desired_movement", Vector3.ZERO)
		blackboard.set_var("desired_rotation", Vector3.ZERO) # Stop rotation input too
		return SUCCESS

	# Calculate direction towards the target.
	var direction = (target_pos - current_pos).normalized()

	# Set desired movement and rotation on the blackboard.
	# The AIController's _execute_actions_from_blackboard will read these.
	# Assuming "desired_movement" is an input vector (like Input.get_vector)
	# and "desired_rotation" is the direction to face.
	# The ship's script needs to interpret these correctly.
	# For simplicity, setting forward movement and facing direction.
	# Note: desired_movement is local space (forward = -Z), desired_rotation is world space direction.
	blackboard.set_var("desired_movement", Vector3(0, 0, -1.0 * speed_multiplier)) # Move forward (local Z)
	blackboard.set_var("desired_rotation", direction) # Face the target direction (world space)

	# Action is still running.
	return RUNNING
