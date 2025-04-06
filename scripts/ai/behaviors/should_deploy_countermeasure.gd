# scripts/ai/behaviors/should_deploy_countermeasure.gd
# BTCondition: Checks if the AI should deploy a countermeasure based on
# missile lock, cooldown timer, and AI profile chance.
# Reads "is_missile_locked" from blackboard.
# Reads "cmeasure_cooldown_timer" and "cmeasure_fire_chance" from AIController.
class_name BTConditionShouldDeployCountermeasure extends BTCondition

func _tick() -> Status:
	var controller = agent as AIController
	if not controller:
		printerr("ShouldDeployCountermeasure: Agent is not a valid AIController.")
		return FAILURE

	# 1. Check if a missile is locked
	var is_locked = blackboard.get_var("is_missile_locked", false)
	if not is_locked:
		return FAILURE # No missile lock, no need to deploy

	# 2. Check cooldown timer
	if controller.cmeasure_cooldown_timer > 0.0:
		return FAILURE # Still on cooldown

	# 3. Check fire chance based on AI profile
	var fire_chance = controller.cmeasure_fire_chance # Get from controller's runtime skill params
	if randf() > fire_chance:
		# Random chance failed, set a short cooldown before next check?
		# Original code sets stamp based on fire_chance, let's mimic that roughly
		controller.cmeasure_cooldown_timer = AIConst.CMEASURE_WAIT * 0.001 * (1.0 + (1.0 - fire_chance) * 2.0) # Scale cooldown based on failure chance
		return FAILURE

	# All checks passed, AI should deploy
	return SUCCESS
