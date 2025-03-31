# scripts/ai/behaviors/chase_target.gd
# LimboAI BTAction: Calculates movement and rotation towards the current target.
# Reads target information from the blackboard and sets desired movement/rotation.
# NOTE: This is a simplified chase action. The full C++ ai_chase logic involves
# complex submodes (attack, evade, get behind, etc.) which should be handled
# by the overall Behavior Tree structure using conditions and other actions
# in conjunction with this basic chase movement.
class_name ChaseTarget
extends BTAction

# Optional export variables for customization
@export var arrival_distance: float = 50.0 # Distance at which to potentially stop chasing (or switch behavior)
@export var speed_multiplier: float = 1.0 # Multiplier for ship's max speed

func _tick() -> Status:
	# Agent is the node running the BTPlayer (likely the AIController or the Ship itself)
	# We need access to the ship node for its position and potentially max speed.
	# Assuming the agent (AIController) has a reference to the ship.
	var controller = agent as AIController
	if not controller or not is_instance_valid(controller.ship):
		printerr("ChaseTarget: Agent is not a valid AIController or ship reference is invalid.")
		return FAILURE

	var ship_node = controller.ship as Node3D # Cast to Node3D for transform access

	# Read target ID from blackboard
	var target_id = blackboard.get_var("target_id", -1)
	if target_id == -1:
		# No target, clear movement and fail
		blackboard.set_var("desired_movement", Vector3.ZERO)
		blackboard.set_var("desired_rotation", Vector3.ZERO)
		return FAILURE

	# Get target node instance
	var target_node = instance_from_id(target_id)
	if not is_instance_valid(target_node) or not target_node is Node3D:
		# Target node is invalid, clear movement and fail
		blackboard.set_var("desired_movement", Vector3.ZERO)
		blackboard.set_var("desired_rotation", Vector3.ZERO)
		blackboard.set_var("target_id", -1) # Clear invalid target ID
		return FAILURE

	# Calculate direction and distance to target
	var target_pos = target_node.global_position
	var current_pos = ship_node.global_position
	var direction = (target_pos - current_pos)
	var distance = direction.length()

	# Check if we've reached the arrival distance (optional behavior)
	# A separate condition node (like IsTargetInRange) might be better for checking arrival.
	# if distance <= arrival_distance:
	#	 blackboard.set_var("desired_movement", Vector3.ZERO)
	#	 return SUCCESS # Or RUNNING if chase should continue even when close

	direction = direction.normalized()

	# Set desired rotation (direction vector)
	# The AIController/Ship script will interpret this to apply torque/rotation.
	blackboard.set_var("desired_rotation", direction)

	# Set desired movement (direction scaled by speed)
	# Assumes ship script has a way to get its max speed.
	var max_speed = 100.0 # Default placeholder
	if ship_node.has_method("get_max_speed"):
		max_speed = ship_node.get_max_speed()

	# Simple approach: always move at max speed towards target
	# More complex logic could adjust speed based on distance, profile, etc.
	# Assuming desired_movement is a world-space velocity vector
	var desired_velocity = direction * max_speed * speed_multiplier
	blackboard.set_var("desired_movement", desired_velocity) # AIController/Ship interprets this

	# This action typically keeps running as long as there's a target to chase.
	# The overall BT structure will decide when to stop chasing (e.g., target lost, new goal).
	return RUNNING
