@tool
extends Node

# Factory script to generate Behavior Tree resources
# Run via: godot --headless --path target target/scenes/tools/bt_generator.tscn

const BTFlyToPosition = preload("res://scripts/ai/behavior_tree/tasks/bt_fly_to_position.gd")
const BTChaseTarget = preload("res://scripts/ai/behavior_tree/tasks/bt_chase_target.gd")
const BTFireWeapons = preload("res://scripts/ai/behavior_tree/tasks/bt_fire_weapons.gd")
const BTEvade = preload("res://scripts/ai/behavior_tree/tasks/bt_evade.gd")

# Mission Tasks
const BTCheckArrived = preload("res://scripts/ai/tasks/mission/bt_check_arrived.gd")
const BTCheckGoal = preload("res://scripts/ai/tasks/mission/bt_check_goal.gd")
const BTCheckEvent = preload("res://scripts/ai/tasks/mission/bt_check_event.gd")
const BTTriggerEvent = preload("res://scripts/ai/tasks/mission/bt_trigger_event.gd")
const BTSetGoalStatus = preload("res://scripts/ai/tasks/mission/bt_set_goal_status.gd")

func _ready():
    print("Generating Behavior Trees...")
    _generate_combat_fighter()
    _generate_patrol()
    _generate_guard()
    
    # Mission Sub-trees
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
    
    # Root: Selector (Priority)
    var bt_root = BTSelector.new()
    bt.root_task = bt_root
    
    # Branch 1: Evade if under fire (Sequence)
    # TODO: Need CheckUnderFire condition
    # For now placeholder
    
    # Branch 2: Attack Target (Sequence)
    var attack_seq = BTSequence.new()
    bt_root.add_child(attack_seq)
    
    # 2.1 Check/Acquire Target
    # Placeholder: Assuming target is already set in blackboard "target"
    
    # 2.2 Parallel: Fly + Fire
    var combat_parallel = BTParallel.new()
    attack_seq.add_child(combat_parallel)
    
    # 2.2.1 Chase
    var chase = BTChaseTarget.new()
    chase.target_var = "target"
    combat_parallel.add_child(chase)
    
    # 2.2.2 Fire
    var fire = BTFireWeapons.new()
    fire.target_var = "target"
    combat_parallel.add_child(fire)
    
    # Save
    var path = "res://resources/behaviour_trees/combat/combat_fighter.tres"
    DirAccess.make_dir_recursive_absolute("res://resources/behaviour_trees/combat")
    ResourceSaver.save(bt, path)
    print("Saved " + path)

func _generate_patrol():
    print("Creating patrol.tres...")
    var bt = BehaviorTree.new()
    
    # Root: Sequence
    var bt_root = BTSequence.new()
    bt.root_task = bt_root
    
    # 1. Fly to Waypoint (Placeholder logic)
    var fly = BTFlyToPosition.new()
    fly.target_pos_var = "waypoint"
    bt_root.add_child(fly)
    
    # 2. Wait
    var wait = BTWait.new()
    wait.duration = 2.0
    bt_root.add_child(wait)
    
    var path = "res://resources/behaviour_trees/combat/patrol.tres"
    ResourceSaver.save(bt, path)
    print("Saved " + path)

func _generate_guard():
    print("Creating guard.tres...")
    var bt = BehaviorTree.new()
    var bt_root = BTSelector.new()
    bt.root_task = bt_root
    
    # 1. Attack threat (Reuse combat logic?)
    # For now just simple Chase
    var chase = BTChaseTarget.new()
    bt_root.add_child(chase)
    
    # 2. Return to guard post
    var fly = BTFlyToPosition.new()
    fly.target_pos_var = "guard_pos"
    bt_root.add_child(fly)
    
    var path = "res://resources/behaviour_trees/combat/guard.tres"
    ResourceSaver.save(bt, path)
    print("Saved " + path)
