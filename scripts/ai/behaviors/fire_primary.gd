# scripts/ai/behaviors/fire_primary.gd
# BTAction: Sets the flag to fire primary weapons.
# Writes "fire_primary" = true to the blackboard.
class_name BTActionFirePrimary extends BTAction

# Called once when the action is executed.
func _tick() -> Status:
	# Set the fire_primary flag on the blackboard.
	# The AIController will read this and trigger the ship's weapon system.
	blackboard.set_var("fire_primary", true)

	# This action completes immediately.
	return SUCCESS
