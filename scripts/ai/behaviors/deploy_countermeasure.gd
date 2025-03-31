# scripts/ai/behaviors/deploy_countermeasure.gd
# BTAction: Sets the flag to deploy a countermeasure.
# Writes "deploy_countermeasure" = true to the blackboard.
class_name BTActionDeployCountermeasure extends BTAction

# Called once when the action is executed.
func _tick() -> Status:
	# Set the deploy_countermeasure flag on the blackboard.
	# The AIController will read this and trigger the ship's countermeasure system.
	blackboard.set_var("deploy_countermeasure", true)

	# This action completes immediately.
	# Note: The ship/AIController should handle cooldowns (CMEASURE_WAIT)
	# and success/failure logic for countermeasures.
	return SUCCESS
