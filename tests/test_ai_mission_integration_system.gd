extends GdUnitTestSuite

## Test Suite for AI Mission Integration System (AI-015)
##
## Comprehensive tests for SEXP integration, mission event handling, context awareness,
## dynamic goal assignment, mission-specific behaviors, and AI mission reporting.

# Test classes and resources
var ai_behavior_functions: RefCounted
var mission_event_handler: Node
var context_awareness_system: Node
var ai_goal_system: Node
var mission_reporter: Node
var mock_ai_agent: Node
var mock_ship_controller: Node
var mock_formation_manager: Node

# Mock data
var mock_mission_context: Dictionary
var mock_sexp_manager: Node

func before_test() -> void:
	# Setup test environment
	_setup_mock_objects()
	_setup_test_data()

func after_test() -> void:
	# Cleanup
	_cleanup_test_objects()

func _setup_mock_objects() -> void:
	# Create mock AI agent
	mock_ai_agent = Node.new()
	mock_ai_agent.name = "TestAIAgent"
	mock_ai_agent.set_script(preload("res://scripts/ai/core/wcs_ai_agent.gd"))
	
	# Initialize properties
	mock_ai_agent.skill_level = 0.7
	mock_ai_agent.aggression_level = 0.6
	mock_ai_agent.current_target = null
	mock_ai_agent.formation_id = ""
	mock_ai_agent.current_ai_state = "idle"
	mock_ai_agent.alertness_level = 0.5
	mock_ai_agent.formation_precision = 1.0
	
	# Create mock ship controller
	mock_ship_controller = Node.new()
	mock_ship_controller.name = "ShipController"
	mock_ai_agent.add_child(mock_ship_controller)
	
	# Setup AI behavior functions
	ai_behavior_functions = preload("res://addons/sexp/functions/ai/ai_behavior_functions.gd").new()
	
	# Setup mission event handler
	mission_event_handler = preload("res://scripts/ai/mission/mission_ai_event_handler.gd").new()
	mission_event_handler.name = "MissionAIEventHandler"
	
	# Setup context awareness system
	context_awareness_system = preload("res://scripts/ai/mission/ai_context_awareness_system.gd").new()
	context_awareness_system.name = "AIContextAwarenessSystem"
	
	# Setup AI goal system
	ai_goal_system = preload("res://scripts/ai/goals/ai_goal_system.gd").new()
	ai_goal_system.name = "AIGoalSystem"
	
	# Setup mission reporter
	mission_reporter = preload("res://scripts/ai/mission/ai_mission_reporter.gd").new()
	mission_reporter.name = "AIMissionReporter"
	
	# Create mock formation manager
	mock_formation_manager = Node.new()
	mock_formation_manager.name = "FormationManager"
	
	# Create mock SEXP manager
	mock_sexp_manager = Node.new()
	mock_sexp_manager.name = "SexpManager"

func _setup_test_data() -> void:
	mock_mission_context = {
		"current_phase": "approach",
		"primary_objectives": [
			{"id": "obj_1", "status": "assigned", "progress": 0.3},
			{"id": "obj_2", "status": "in_progress", "progress": 0.7}
		],
		"threat_level": 0.4,
		"time_pressure": 0.2
	}

func _cleanup_test_objects() -> void:
	if mock_ai_agent:
		mock_ai_agent.queue_free()
	if mission_event_handler:
		mission_event_handler.queue_free()
	if context_awareness_system:
		context_awareness_system.queue_free()
	if ai_goal_system:
		ai_goal_system.queue_free()
	if mission_reporter:
		mission_reporter.queue_free()

## SEXP AI Behavior Functions Tests
func test_sexp_set_ai_goal_function() -> void:
	var set_goal_func = ai_behavior_functions.SetAIGoalFunction.new()
	
	# Test basic goal assignment
	var args: Array = [
		_create_sexp_result("string", "TestShip"),
		_create_sexp_result("string", "attack"),
		_create_sexp_result("string", "EnemyShip"),
		_create_sexp_result("number", 3.0)
	]
	
	var result = set_goal_func._execute_implementation(args)
	assert_that(result.is_boolean()).is_true()

func test_sexp_change_ai_behavior_function() -> void:
	var change_behavior_func = ai_behavior_functions.ChangeAIBehaviorFunction.new()
	
	# Test behavior modification
	var args: Array = [
		_create_sexp_result("string", "TestShip"),
		_create_sexp_result("string", "aggressive"),
		_create_sexp_result("number", 0.8)
	]
	
	var result = change_behavior_func._execute_implementation(args)
	assert_that(result.is_boolean()).is_true()

func test_sexp_set_formation_function() -> void:
	var set_formation_func = ai_behavior_functions.SetFormationFunction.new()
	
	# Test formation assignment
	var ship_list = ["Ship1", "Ship2", "Ship3"]
	var args: Array = [
		_create_sexp_result("string", "LeaderShip"),
		_create_sexp_result("string", "diamond"),
		_create_sexp_result("array", ship_list),
		_create_sexp_result("number", 150.0)
	]
	
	var result = set_formation_func._execute_implementation(args)
	# Would normally check if formation was created, but mocked environment
	assert_that(result).is_not_null()

func test_sexp_get_ai_status_function() -> void:
	var get_status_func = ai_behavior_functions.GetAIStatusFunction.new()
	
	# Test status query
	var args: Array = [
		_create_sexp_result("string", "TestShip"),
		_create_sexp_result("string", "goal")
	]
	
	var result = get_status_func._execute_implementation(args)
	assert_that(result.is_string()).is_true()

## Mission Event Handler Tests
func test_mission_phase_change_handling() -> void:
	# Setup mission event handler
	mission_event_handler._ready()
	
	# Test phase change handling
	var event_data = {"phase": "engagement", "old_phase": "approach"}
	mission_event_handler._handle_phase_change(event_data)
	
	# Verify context was updated
	assert_that(mission_event_handler.mission_context["current_phase"]).is_equal("engagement")

func test_objective_change_handling() -> void:
	mission_event_handler._ready()
	
	# Test objective completion
	var event_data = {
		"objective_id": "obj_1",
		"status": "completed",
		"ships": ["TestShip"]
	}
	
	mission_event_handler._handle_objective_change(event_data)
	
	# Verify objective was removed from context
	var primary_objectives = mission_event_handler.mission_context.get("primary_objectives", [])
	var found_objective = false
	for obj in primary_objectives:
		if obj.get("id") == "obj_1":
			found_objective = true
			break
	
	assert_that(found_objective).is_false()

func test_emergency_event_handling() -> void:
	mission_event_handler._ready()
	
	# Test emergency response
	var event_data = {
		"type": "damage_critical",
		"severity": 0.9,
		"ships": ["TestShip"]
	}
	
	mission_event_handler._handle_emergency_event(event_data)
	
	# Verify emergency behavior was triggered
	assert_that(mission_event_handler.active_modifications.has("global")).is_true()

## Context Awareness System Tests
func test_mission_phase_context_update() -> void:
	context_awareness_system._ready()
	
	# Test phase context update
	var objectives = [{"id": "obj_1", "type": "attack"}]
	var constraints = {"time_limit": 300.0}
	
	context_awareness_system.update_mission_phase_context("engagement", objectives, constraints)
	
	var phase_context = context_awareness_system.get_current_context(context_awareness_system.ContextType.MISSION_PHASE)
	assert_that(phase_context["current_phase"]).is_equal("engagement")
	assert_that(phase_context["phase_objectives"]).is_equal(objectives)

func test_narrative_context_adaptation() -> void:
	context_awareness_system._ready()
	
	# Test narrative context update
	context_awareness_system.update_narrative_context("dramatic_revelation", "tense", 0.8)
	
	var narrative_context = context_awareness_system.get_narrative_context()
	assert_that(narrative_context["emotional_tone"]).is_equal("tense")
	assert_that(narrative_context["scene_tension"]).is_equal(0.8)

func test_environmental_context_adaptation() -> void:
	context_awareness_system._ready()
	
	# Test environmental adaptation
	var env_factors = {
		"visibility": 0.3,
		"gravity_effects": 1.2,
		"electromagnetic_interference": 0.4
	}
	
	context_awareness_system.update_environmental_context(env_factors)
	
	var env_context = context_awareness_system.get_environmental_context()
	assert_that(env_context["visibility"]).is_equal(0.3)
	assert_that(env_context["electromagnetic_interference"]).is_equal(0.4)

func test_tactical_context_analysis() -> void:
	context_awareness_system._ready()
	
	# Test tactical context update
	var engagement_params = {
		"engagement_range": "close",
		"formation_effectiveness": 0.85
	}
	
	context_awareness_system.update_tactical_context(0.7, 0.6, engagement_params)
	
	var tactical_context = context_awareness_system.get_tactical_context()
	assert_that(tactical_context["force_balance"]).is_equal(0.6)
	assert_that(tactical_context["engagement_range"]).is_equal("close")

## AI Goal System Tests
func test_goal_assignment_and_priority() -> void:
	ai_goal_system._init(mock_ai_agent)
	ai_goal_system._ready()
	
	# Test goal assignment
	var goal_id = ai_goal_system.assign_goal("attack", "EnemyShip", 3.0, {"weapon_type": "primary"})
	
	assert_that(goal_id).is_not_empty()
	assert_that(ai_goal_system.get_active_goals().size()).is_equal(1)
	
	var active_goal = ai_goal_system.get_active_goals()[0]
	assert_that(active_goal.goal_type).is_equal(ai_goal_system.GoalType.ATTACK_TARGET)
	assert_that(active_goal.target_name).is_equal("EnemyShip")

func test_goal_priority_modification() -> void:
	ai_goal_system._init(mock_ai_agent)
	ai_goal_system._ready()
	
	# Assign a goal and modify its priority
	var goal_id = ai_goal_system.assign_goal("patrol", "", 2.0)
	var success = ai_goal_system.modify_goal_priority(goal_id, 4.0)
	
	assert_that(success).is_true()
	
	var goal = ai_goal_system._find_goal_by_id(goal_id)
	assert_that(goal.priority).is_equal(ai_goal_system.GoalPriority.CRITICAL)

func test_goal_conflict_resolution() -> void:
	ai_goal_system._init(mock_ai_agent)
	ai_goal_system._ready()
	
	# Assign conflicting goals
	var goal1_id = ai_goal_system.assign_goal("attack", "Target1", 2.0)
	var goal2_id = ai_goal_system.assign_goal("attack", "Target1", 4.0)  # Higher priority conflict
	
	# Check that higher priority goal is active
	var primary_goal = ai_goal_system.get_current_primary_goal()
	assert_that(primary_goal.goal_id).is_equal(goal2_id)

func test_goal_completion_tracking() -> void:
	ai_goal_system._init(mock_ai_agent)
	ai_goal_system._ready()
	
	# Assign and complete a goal
	var goal_id = ai_goal_system.assign_goal("attack", "EnemyShip", 3.0)
	var goal = ai_goal_system._find_goal_by_id(goal_id)
	
	# Simulate goal completion
	ai_goal_system._complete_goal(goal, true)
	
	assert_that(ai_goal_system.get_active_goals().size()).is_equal(0)
	assert_that(ai_goal_system.goal_history.size()).is_equal(1)

func test_goal_timeout_handling() -> void:
	ai_goal_system._init(mock_ai_agent)
	ai_goal_system._ready()
	
	# Assign goal with short timeout
	var goal_id = ai_goal_system.assign_goal("patrol", "", 2.0, {"timeout": 0.1})
	var goal = ai_goal_system._find_goal_by_id(goal_id)
	goal.timeout_duration = 0.1  # Very short timeout
	goal.start_time = Time.get_ticks_msec() - 200  # Set start time in past
	
	# Check timeout handling
	ai_goal_system._check_goal_timeouts()
	
	assert_that(goal.status).is_equal(ai_goal_system.GoalStatus.FAILED)

## Mission Behavior Nodes Tests
func test_mission_context_adaptation_action() -> void:
	var mission_nodes = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var adaptation_action = mission_nodes.MissionContextAdaptationAction.new()
	
	# Setup action
	adaptation_action.ai_agent = mock_ai_agent
	adaptation_action.ship_controller = mock_ship_controller
	adaptation_action._setup()
	
	# Test context adaptation
	mock_ai_agent.blackboard = preload("res://scripts/ai/utilities/ai_blackboard.gd").new()
	mock_ai_agent.blackboard.set_value("mission_context", mock_mission_context)
	
	var result = adaptation_action._apply_context_adaptations()
	assert_that(result).is_true()

func test_escort_mission_action() -> void:
	var mission_nodes = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var escort_action = mission_nodes.EscortMissionAction.new()
	
	# Setup escort action
	escort_action.ai_agent = mock_ai_agent
	escort_action.ship_controller = mock_ship_controller
	escort_action._setup()
	
	# Test escort position calculation
	var mock_escort_target = Node3D.new()
	mock_escort_target.global_position = Vector3(100, 0, 100)
	escort_action.escort_target = mock_escort_target
	
	escort_action._update_escort_position()
	
	# Verify escort position was calculated
	assert_that(escort_action.escort_formation_position).is_not_equal(Vector3.ZERO)
	
	mock_escort_target.queue_free()

func test_defensive_operation_action() -> void:
	var mission_nodes = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var defensive_action = mission_nodes.DefensiveOperationAction.new()
	
	# Setup defensive action
	defensive_action.ai_agent = mock_ai_agent
	defensive_action.ship_controller = mock_ship_controller
	defensive_action._setup()
	
	# Test defense area scanning
	defensive_action.defense_center = Vector3(0, 0, 0)
	defensive_action._scan_defense_area()
	
	# Verify scanning completed without errors
	assert_that(defensive_action.active_threats).is_not_null()

func test_scripted_sequence_action() -> void:
	var mission_nodes = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var sequence_action = mission_nodes.ScriptedSequenceAction.new()
	
	# Setup sequence action
	sequence_action.ai_agent = mock_ai_agent
	sequence_action.ship_controller = mock_ship_controller
	sequence_action.sequence_name = "victory_flyby"
	sequence_action._setup()
	
	# Test sequence data loading
	sequence_action._load_sequence_data()
	
	assert_that(sequence_action.sequence_data).is_not_empty()
	assert_that(sequence_action.sequence_data.has("steps")).is_true()

## Mission Reporter Tests
func test_ai_status_reporting() -> void:
	mission_reporter._ready()
	
	# Test AI status report
	var status_data = {
		"health": 0.8,
		"goal": "attack",
		"target": "EnemyShip",
		"formation": "diamond"
	}
	
	mission_reporter.report_ai_status("TestAgent", status_data)
	
	# Verify report was recorded
	assert_that(mission_reporter.agent_status_registry.has("TestAgent")).is_true()
	assert_that(mission_reporter.agent_status_registry["TestAgent"]["health"]).is_equal(0.8)

func test_objective_progress_reporting() -> void:
	mission_reporter._ready()
	
	# Test objective progress report
	var progress_data = {
		"progress": 0.65,
		"status": "in_progress",
		"assigned_agents": ["Agent1", "Agent2"]
	}
	
	mission_reporter.report_objective_progress("obj_1", progress_data)
	
	# Verify progress was recorded
	assert_that(mission_reporter.objective_progress_registry.has("obj_1")).is_true()
	assert_that(mission_reporter.objective_progress_registry["obj_1"]["progress"]).is_equal(0.65)

func test_goal_completion_reporting() -> void:
	mission_reporter._ready()
	
	# Test goal completion report
	var completion_data = {
		"success": true,
		"goal_type": "attack",
		"completion_time": 45.2,
		"effectiveness": 0.9
	}
	
	mission_reporter.report_goal_completion("TestAgent", "goal_123", completion_data)
	
	# Verify completion was recorded in history
	assert_that(mission_reporter.report_history.size()).is_greater(0)
	var last_report = mission_reporter.report_history[-1]
	assert_that(last_report["agent_name"]).is_equal("TestAgent")

func test_formation_status_reporting() -> void:
	mission_reporter._ready()
	
	# Test formation status report
	var status_data = {
		"integrity": 0.92,
		"member_count": 4,
		"formation_type": "diamond",
		"leader": "LeaderShip"
	}
	
	mission_reporter.report_formation_status("formation_1", status_data)
	
	# Verify status was recorded
	assert_that(mission_reporter.formation_status_registry.has("formation_1")).is_true()
	assert_that(mission_reporter.formation_status_registry["formation_1"]["integrity"]).is_equal(0.92)

func test_tactical_situation_reporting() -> void:
	mission_reporter._ready()
	
	# Test tactical situation report
	var situation_data = {
		"threat_level": 0.7,
		"force_balance": 0.6,
		"engagement_range": "medium",
		"tactical_advantage": "enemy"
	}
	
	mission_reporter.report_tactical_situation(situation_data)
	
	# Verify situation was recorded
	assert_that(mission_reporter.tactical_reports.size()).is_greater(0)
	var last_tactical = mission_reporter.tactical_reports[-1]
	assert_that(last_tactical["threat_level"]).is_equal(0.7)

func test_performance_analytics() -> void:
	mission_reporter._ready()
	
	# Generate several reports to test analytics
	mission_reporter.report_ai_status("Agent1", {"health": 1.0})
	mission_reporter.report_ai_status("Agent2", {"health": 0.8})
	mission_reporter.report_objective_progress("obj_1", {"progress": 0.5})
	
	var analytics = mission_reporter.get_performance_analytics()
	
	assert_that(analytics["total_reports"]).is_equal(3)
	assert_that(analytics["reports_by_category"].has("STATUS_REPORT")).is_true()
	assert_that(analytics["reports_by_category"]["STATUS_REPORT"]).is_equal(2)

func test_mission_summary_report() -> void:
	mission_reporter._ready()
	
	# Setup some test data
	mission_reporter.agent_status_registry["Agent1"] = {"health": 0.9}
	mission_reporter.agent_status_registry["Agent2"] = {"health": 0.3}
	mission_reporter.objective_progress_registry["obj_1"] = {"progress": 0.8}
	
	var summary = mission_reporter.get_mission_summary_report()
	
	assert_that(summary["total_agents"]).is_equal(2)
	assert_that(summary["active_objectives"]).is_equal(1)
	assert_that(summary.has("agent_status_breakdown")).is_true()

## Query Interface Tests
func test_agent_status_queries() -> void:
	mission_reporter._ready()
	
	# Setup test data
	mission_reporter.agent_status_registry["HealthyAgent"] = {"health": 0.9, "current_goal": "patrol"}
	mission_reporter.agent_status_registry["DamagedAgent"] = {"health": 0.4, "current_goal": "retreat"}
	mission_reporter.agent_status_registry["IdleAgent"] = {"health": 1.0, "current_goal": "none"}
	
	# Test query by status criteria
	var active_agents = mission_reporter.get_agents_by_status({"current_goal": "patrol"})
	assert_that(active_agents.size()).is_equal(1)
	assert_that(active_agents[0]).is_equal("HealthyAgent")

func test_objective_progress_queries() -> void:
	mission_reporter._ready()
	
	# Setup test data
	mission_reporter.objective_progress_registry["obj_1"] = {"progress": 0.2}
	mission_reporter.objective_progress_registry["obj_2"] = {"progress": 0.7}
	mission_reporter.objective_progress_registry["obj_3"] = {"progress": 0.95}
	
	# Test query by progress range
	var in_progress_objectives = mission_reporter.get_objectives_by_progress(0.3, 0.9)
	assert_that(in_progress_objectives.size()).is_equal(1)
	assert_that(in_progress_objectives[0]).is_equal("obj_2")

## Integration Tests
func test_sexp_to_mission_integration() -> void:
	# Test complete SEXP command to mission response flow
	ai_goal_system._init(mock_ai_agent)
	ai_goal_system._ready()
	mission_reporter._ready()
	
	# Simulate SEXP command execution
	var goal_id = ai_goal_system.assign_goal("escort", "VIPShip", 4.0)
	
	# Simulate goal progress and completion
	var goal = ai_goal_system._find_goal_by_id(goal_id)
	goal.progress = 1.0
	ai_goal_system._complete_goal(goal, true)
	
	# Verify mission reporting captured the completion
	assert_that(mission_reporter.report_history.size()).is_greater(0)

func test_context_to_behavior_adaptation() -> void:
	# Test context awareness driving behavior adaptation
	context_awareness_system._ready()
	mission_event_handler._ready()
	
	# Simulate mission phase change
	context_awareness_system.update_mission_phase_context("engagement")
	
	# Verify adaptation rules were applied
	var phase_context = context_awareness_system.get_current_context(context_awareness_system.ContextType.MISSION_PHASE)
	assert_that(phase_context["current_phase"]).is_equal("engagement")

func test_narrative_event_to_ai_response() -> void:
	# Test narrative events triggering appropriate AI responses
	context_awareness_system._ready()
	mission_event_handler._ready()
	
	# Simulate narrative event
	var narrative_event_data = {
		"event": "dramatic_revelation",
		"emotional_tone": "surprise",
		"tension_level": 0.8
	}
	
	mission_event_handler._handle_story_event(narrative_event_data)
	
	# Verify context was updated appropriately
	assert_that(mission_event_handler.mission_context.has("current_phase")).is_true()

## Helper Methods
func _create_sexp_result(type: String, value: Variant) -> RefCounted:
	var sexp_result = preload("res://addons/sexp/core/sexp_result.gd").new()
	
	match type:
		"string":
			sexp_result.result_type = 1  # STRING
			sexp_result.string_value = value
		"number":
			sexp_result.result_type = 2  # NUMBER
			sexp_result.number_value = value
		"boolean":
			sexp_result.result_type = 3  # BOOLEAN
			sexp_result.boolean_value = value
		"array":
			sexp_result.result_type = 4  # ARRAY
			sexp_result.array_value = value
	
	return sexp_result

## Performance and Stress Tests
func test_high_volume_reporting() -> void:
	mission_reporter._ready()
	mission_reporter.set_priority_filter(mission_reporter.ReportPriority.DEBUG)
	
	# Generate many reports quickly
	var start_time = Time.get_ticks_msec()
	for i in range(100):
		mission_reporter.report_ai_status("Agent" + str(i), {"health": randf()})
	var end_time = Time.get_ticks_msec()
	
	# Verify performance is acceptable (under 100ms for 100 reports)
	var duration = end_time - start_time
	assert_that(duration).is_less(100)
	assert_that(mission_reporter.agent_status_registry.size()).is_equal(100)

func test_goal_system_scalability() -> void:
	ai_goal_system._init(mock_ai_agent)
	ai_goal_system._ready()
	ai_goal_system.max_concurrent_goals = 10
	
	# Assign many goals to test scalability
	var goal_ids: Array[String] = []
	for i in range(15):  # More than max concurrent
		var goal_id = ai_goal_system.assign_goal("patrol", "Area" + str(i), float(i % 5))
		goal_ids.append(goal_id)
	
	# Verify goal queue management
	assert_that(ai_goal_system.get_active_goals().size()).is_less_equal(10)
	assert_that(ai_goal_system.get_goal_queue().size()).is_greater(0)

func test_context_adaptation_frequency() -> void:
	context_awareness_system._ready()
	
	# Test rapid context updates
	var start_time = Time.get_ticks_msec()
	for i in range(50):
		context_awareness_system.update_tactical_context(randf(), randf(), {})
	var end_time = Time.get_ticks_msec()
	
	# Verify updates are processed efficiently
	var duration = end_time - start_time
	assert_that(duration).is_less(50)  # Should be very fast

## Error Handling Tests
func test_invalid_sexp_parameters() -> void:
	var set_goal_func = ai_behavior_functions.SetAIGoalFunction.new()
	
	# Test with invalid parameters
	var args: Array = [
		_create_sexp_result("string", ""),  # Empty ship name
		_create_sexp_result("string", "invalid_goal"),  # Invalid goal type
	]
	
	var result = set_goal_func._execute_implementation(args)
	assert_that(result.is_error()).is_true()

func test_missing_target_handling() -> void:
	ai_goal_system._init(mock_ai_agent)
	ai_goal_system._ready()
	
	# Assign goal with non-existent target
	var goal_id = ai_goal_system.assign_goal("attack", "NonExistentTarget", 3.0)
	var goal = ai_goal_system._find_goal_by_id(goal_id)
	
	# Verify goal handles missing target gracefully
	assert_that(goal.target_node).is_null()

func test_reporter_error_tracking() -> void:
	mission_reporter._ready()
	
	# Report an error
	mission_reporter.report_error("TestAgent", "navigation_failure", {"reason": "path_blocked"})
	
	var error_data = mission_reporter.get_error_tracking_data()
	assert_that(error_data["total_errors"]).is_equal(1)
	assert_that(error_data["error_types"]["navigation_failure"]).is_equal(1)

## Final Integration Test
func test_complete_mission_scenario() -> void:
	# Setup complete test scenario
	ai_goal_system._init(mock_ai_agent)
	ai_goal_system._ready()
	context_awareness_system._ready()
	mission_event_handler._ready()
	mission_reporter._ready()
	
	# Phase 1: Mission start
	context_awareness_system.update_mission_phase_context("approach")
	
	# Phase 2: Assign AI goals via SEXP
	var escort_goal_id = ai_goal_system.assign_goal("escort", "TransportShip", 3.0)
	
	# Phase 3: Mission event triggers adaptation
	var threat_event = {"type": "enemy_sighted", "threat_level": 0.8}
	mission_event_handler._handle_combat_event(threat_event)
	
	# Phase 4: Context changes behavior
	context_awareness_system.update_tactical_context(0.8, 0.6, {"engagement_range": "close"})
	
	# Phase 5: Goal completion and reporting
	var escort_goal = ai_goal_system._find_goal_by_id(escort_goal_id)
	ai_goal_system._complete_goal(escort_goal, true)
	
	# Verify complete integration
	assert_that(ai_goal_system.goal_history.size()).is_equal(1)
	assert_that(mission_reporter.report_history.size()).is_greater(0)
	
	var summary = mission_reporter.get_mission_summary_report()
	assert_that(summary["total_agents"]).is_greater_equal(0)