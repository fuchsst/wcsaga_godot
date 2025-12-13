@tool
extends Node

# Factory script to generate Behavior Tree resources
# Run via: godot --headless --path target target/scenes/tools/bt_generator.tscn

# Original basic tasks
const BTFlyToPosition = preload("res://scripts/ai/behavior_tree/tasks/bt_fly_to_position.gd")
const BTChaseTarget = preload("res://scripts/ai/behavior_tree/tasks/bt_chase_target.gd")
const BTFireWeapons = preload("res://scripts/ai/behavior_tree/tasks/bt_fire_weapons.gd")
const BTEvade = preload("res://scripts/ai/behavior_tree/tasks/bt_evade.gd")

# Enhanced combat tasks
const BTSelectTarget = preload("res://scripts/ai/behavior_tree/tasks/combat/bt_select_target.gd")
const BTAttackRun = preload("res://scripts/ai/behavior_tree/tasks/combat/bt_attack_run.gd")
const BTEvadeManeuver = preload("res://scripts/ai/behavior_tree/tasks/combat/bt_evade_maneuver.gd")
const BTCircleStrafe = preload("res://scripts/ai/behavior_tree/tasks/combat/bt_circle_strafe.gd")
const BTSentryGun = preload("res://scripts/ai/behavior_tree/tasks/combat/bt_sentry_gun.gd")
const BTBigShipAttack = preload(
	"res://scripts/ai/behavior_tree/tasks/combat/bt_big_ship_attack.gd")

# Guard tasks
const BTGuardPatrol = preload(
	"res://scripts/ai/behavior_tree/tasks/guard/bt_guard_patrol.gd")
const BTCheckGuardThreat = preload(
	"res://scripts/ai/behavior_tree/tasks/guard/bt_check_guard_threat.gd")

# Formation tasks
const BTFlyFormation = preload("res://scripts/ai/behavior_tree/tasks/formation/bt_fly_formation.gd")

# Navigation tasks
const BTFollowPath = preload("res://scripts/ai/behavior_tree/tasks/navigation/bt_follow_path.gd")
const BTWarpOut = preload("res://scripts/ai/behavior_tree/tasks/navigation/bt_warp_out.gd")
const BTStayStill = preload("res://scripts/ai/behavior_tree/tasks/navigation/bt_stay_still.gd")
const BTPlayDead = preload("res://scripts/ai/behavior_tree/tasks/navigation/bt_play_dead.gd")

# Docking tasks
const BTDockApproach = preload("res://scripts/ai/behavior_tree/tasks/docking/bt_dock_approach.gd")
const BTUndock = preload("res://scripts/ai/behavior_tree/tasks/docking/bt_undock.gd")
const BTBayEmerge = preload("res://scripts/ai/behavior_tree/tasks/docking/bt_bay_emerge.gd")
const BTBayDepart = preload("res://scripts/ai/behavior_tree/tasks/docking/bt_bay_depart.gd")
const BTRearm = preload("res://scripts/ai/behavior_tree/tasks/docking/bt_rearm.gd")

# Mission tasks
const BTCheckArrived = preload("res://scripts/ai/tasks/mission/bt_check_arrived.gd")
const BTCheckGoal = preload("res://scripts/ai/tasks/mission/bt_check_goal.gd")
const BTCheckEvent = preload("res://scripts/ai/tasks/mission/bt_check_event.gd")
const BTTriggerEvent = preload("res://scripts/ai/tasks/mission/bt_trigger_event.gd")
const BTSetGoalStatus = preload("res://scripts/ai/tasks/mission/bt_set_goal_status.gd")

func _ready():
	print("Generating Behavior Trees...")

	# Enhanced combat trees
	_generate_combat_fighter()
	_generate_bomber_attack()
	_generate_guard_escort()
	_generate_patrol_waypoints()
	_generate_formation_wing()

	# Mission sub-trees
	_generate_arrival_handler()
	_generate_goal_check()
	_generate_event_trigger()

	get_tree().quit()


func _generate_arrival_handler():
	print("Creating arrival_handler.tres...")
	var bt = BehaviorTree.new()
	var bt_root = BTSequence.new()
	bt.root_task = bt_root

	# Check if entity arrived (name from blackboard)
	var check = BTCheckArrived.new()
	check.object_name_var = "arrival_object"
	bt_root.add_child(check)

	# Trigger event
	var trig = BTTriggerEvent.new()
	trig.event_name_var = "arrival_event"
	bt_root.add_child(trig)

	var path = "res://resources/behaviour_trees/mission/arrival_handler.tres"
	DirAccess.make_dir_recursive_absolute("res://resources/behaviour_trees/mission")
	ResourceSaver.save(bt, path)
	print("Saved " + path)


func _generate_goal_check():
	print("Creating goal_check.tres...")
	var bt = BehaviorTree.new()
	var bt_root = BTSequence.new()
	bt.root_task = bt_root

	# Check goal
	var check = BTCheckGoal.new()
	check.goal_name_var = "goal_to_check"
	check.status_check = 1 # Complete
	bt_root.add_child(check)

	# Trigger event
	var trig = BTTriggerEvent.new()
	trig.event_name_var = "success_event"
	bt_root.add_child(trig)

	var path = "res://resources/behaviour_trees/mission/goal_check.tres"
	ResourceSaver.save(bt, path)
	print("Saved " + path)


func _generate_event_trigger():
	print("Creating event_trigger.tres...")
	var bt = BehaviorTree.new()

	var trig = BTTriggerEvent.new()
	trig.event_name_var = "event_to_trigger"
	bt.root_task = trig

	var path = "res://resources/behaviour_trees/mission/event_trigger.tres"
	ResourceSaver.save(bt, path)
	print("Saved " + path)


func _generate_combat_fighter():
	print("Creating combat_fighter.tres...")
	var bt = BehaviorTree.new()

	# Root: Selector (priority-based fallback)
	var bt_root = BTSelector.new()
	bt.root_task = bt_root

	# Branch 1: Evade if low health (Sequence)
	var evade_seq = BTSequence.new()
	bt_root.add_child(evade_seq)

	var check_health = BTCheckVar.new()
	check_health.variable = "hull_percent"
	check_health.check_type = 2 # LESS_THAN
	check_health.value_type = 0 # Float
	check_health.value = 0.25
	evade_seq.add_child(check_health)

	var evade = BTEvadeManeuver.new()
	evade.pattern = 2 # FLY_AWAY
	evade.evade_duration = 3.0
	evade_seq.add_child(evade)

	# Branch 2: Attack if has target (Sequence)
	var attack_seq = BTSequence.new()
	bt_root.add_child(attack_seq)

	var has_target = BTCheckVar.new()
	has_target.variable = "target_valid"
	has_target.check_type = 0 # EQUAL
	has_target.value_type = 1 # Bool
	has_target.value = true
	attack_seq.add_child(has_target)

	# Parallel: Attack run + Fire
	var combat_parallel = BTParallel.new()
	combat_parallel.num_successes_required = 1
	combat_parallel.num_failures_required = 2
	attack_seq.add_child(combat_parallel)

	var attack = BTAttackRun.new()
	attack.attack_mode = 0 # DIRECT
	attack.fire_range = 800.0
	combat_parallel.add_child(attack)

	var fire = BTFireWeapons.new()
	fire.target_var = "target"
	combat_parallel.add_child(fire)

	# Branch 3: Acquire target
	var select = BTSelectTarget.new()
	select.max_range = 2500.0
	bt_root.add_child(select)

	# Save
	DirAccess.make_dir_recursive_absolute("res://resources/behaviour_trees/combat")
	var path = "res://resources/behaviour_trees/combat/combat_fighter.tres"
	ResourceSaver.save(bt, path)
	print("Saved " + path)

func _generate_bomber_attack():
	print("Creating bomber_attack.tres...")
	var bt = BehaviorTree.new()

	# Root: Selector
	var bt_root = BTSelector.new()
	bt.root_task = bt_root

	# Branch 1: Strafe big ship if target is capital
	var strafe_seq = BTSequence.new()
	bt_root.add_child(strafe_seq)

	var has_target = BTCheckVar.new()
	has_target.variable = "target_valid"
	has_target.check_type = 0 # EQUAL
	has_target.value_type = 1 # Bool
	has_target.value = true
	strafe_seq.add_child(has_target)

	var circle = BTCircleStrafe.new()
	circle.circle_radius = 400.0
	circle.fire_while_strafing = true
	strafe_seq.add_child(circle)

	# Branch 2: Attack run
	var attack = BTAttackRun.new()
	attack.attack_mode = 3 # STRAFE
	attack.fire_range = 1000.0
	bt_root.add_child(attack)

	# Branch 3: Select target
	var select = BTSelectTarget.new()
	select.max_range = 3500.0
	bt_root.add_child(select)

	# Save
	var path = "res://resources/behaviour_trees/combat/bomber_attack.tres"
	ResourceSaver.save(bt, path)
	print("Saved " + path)


func _generate_guard_escort():
	print("Creating guard_escort.tres...")
	var bt = BehaviorTree.new()

	# Root: Selector
	var bt_root = BTSelector.new()
	bt.root_task = bt_root

	# Branch 1: Attack threat if detected (Sequence)
	var attack_seq = BTSequence.new()
	bt_root.add_child(attack_seq)

	var check_threat = BTCheckGuardThreat.new()
	check_threat.detection_range = 2000.0
	check_threat.guard_target_var = "guard_target"
	attack_seq.add_child(check_threat)

	# Attack the threat
	var attack = BTAttackRun.new()
	attack.attack_mode = 0 # DIRECT
	attack.attack_duration = 8.0
	attack_seq.add_child(attack)

	# Branch 2: Patrol around guard target
	var patrol = BTGuardPatrol.new()
	patrol.patrol_radius = 500.0
	patrol.waypoint_dwell_time = 3.0
	bt_root.add_child(patrol)

	# Save
	var path = "res://resources/behaviour_trees/combat/guard_escort.tres"
	ResourceSaver.save(bt, path)
	print("Saved " + path)


func _generate_patrol_waypoints():
	print("Creating patrol_waypoints.tres...")
	var bt = BehaviorTree.new()

	# Root: Selector
	var bt_root = BTSelector.new()
	bt.root_task = bt_root

	# Branch 1: Attack if threat nearby
	var attack_seq = BTSequence.new()
	bt_root.add_child(attack_seq)

	var has_target = BTCheckVar.new()
	has_target.variable = "target_valid"
	has_target.check_type = 0
	has_target.value_type = 1
	has_target.value = true
	attack_seq.add_child(has_target)

	var attack = BTAttackRun.new()
	attack.attack_mode = 0
	attack.attack_duration = 5.0
	attack_seq.add_child(attack)

	# Branch 2: Fly waypoints
	var fly = BTFlyToPosition.new()
	fly.target_pos_var = "waypoint"
	bt_root.add_child(fly)

	# Save
	var path = "res://resources/behaviour_trees/combat/patrol_waypoints.tres"
	ResourceSaver.save(bt, path)
	print("Saved " + path)


func _generate_formation_wing():
	print("Creating formation_wing.tres...")
	var bt = BehaviorTree.new()

	# Root: Selector
	var bt_root = BTSelector.new()
	bt.root_task = bt_root

	# Branch 1: Break formation if under attack
	var break_seq = BTSequence.new()
	bt_root.add_child(break_seq)

	var under_attack = BTCheckVar.new()
	under_attack.variable = "under_attack"
	under_attack.check_type = 0
	under_attack.value_type = 1
	under_attack.value = true
	break_seq.add_child(under_attack)

	var evade = BTEvadeManeuver.new()
	evade.pattern = 0 # SQUIGGLE
	evade.evade_duration = 2.0
	break_seq.add_child(evade)

	# Branch 2: Follow formation
	var formation = BTFlyFormation.new()
	formation.formation_slot = 1
	formation.formation_type = 0 # VIC
	formation.spacing = 50.0
	bt_root.add_child(formation)

	# Save
	var path = "res://resources/behaviour_trees/combat/formation_wing.tres"
	ResourceSaver.save(bt, path)
	print("Saved " + path)
