extends GdUnitTestSuite

## Simplified Test Suite for AI Mission Integration (AI-015)
##
## Tests core AI-015 functionality without complex dependencies.
## Focuses on SEXP integration, goal management, and mission reporting.

# Test AI behavior functions class
var ai_behavior_functions_class

func before_test() -> void:
	# Load the AI behavior functions class
	ai_behavior_functions_class = preload("res://addons/sexp/functions/ai/ai_behavior_functions.gd")

func after_test() -> void:
	pass

## Test SEXP AI Function Classes
func test_set_ai_goal_function_creation() -> void:
	var set_goal_func = ai_behavior_functions_class.SetAIGoalFunction.new()
	
	assert_that(set_goal_func.function_name).is_equal("ai-set-goal")
	assert_that(set_goal_func.function_category).is_equal("ai")
	assert_that(set_goal_func.minimum_args).is_equal(2)
	assert_that(set_goal_func.maximum_args).is_equal(4)

func test_change_ai_behavior_function_creation() -> void:
	var change_behavior_func = ai_behavior_functions_class.ChangeAIBehaviorFunction.new()
	
	assert_that(change_behavior_func.function_name).is_equal("ai-change-behavior")
	assert_that(change_behavior_func.function_category).is_equal("ai")
	assert_that(change_behavior_func.minimum_args).is_equal(2)
	assert_that(change_behavior_func.maximum_args).is_equal(3)

func test_set_formation_function_creation() -> void:
	var set_formation_func = ai_behavior_functions_class.SetFormationFunction.new()
	
	assert_that(set_formation_func.function_name).is_equal("ai-set-formation")
	assert_that(set_formation_func.function_category).is_equal("ai")
	assert_that(set_formation_func.minimum_args).is_equal(3)
	assert_that(set_formation_func.maximum_args).is_equal(4)

func test_get_ai_status_function_creation() -> void:
	var get_status_func = ai_behavior_functions_class.GetAIStatusFunction.new()
	
	assert_that(get_status_func.function_name).is_equal("ai-get-status")
	assert_that(get_status_func.function_category).is_equal("ai")
	assert_that(get_status_func.is_pure_function).is_true()

func test_set_ai_enabled_function_creation() -> void:
	var set_enabled_func = ai_behavior_functions_class.SetAIEnabledFunction.new()
	
	assert_that(set_enabled_func.function_name).is_equal("ai-set-enabled")
	assert_that(set_enabled_func.function_category).is_equal("ai")
	assert_that(set_enabled_func.minimum_args).is_equal(2)
	assert_that(set_enabled_func.maximum_args).is_equal(2)

## Test Mission Event Handler
func test_mission_event_handler_creation() -> void:
	var event_handler_class = preload("res://scripts/ai/mission/mission_ai_event_handler.gd")
	var event_handler = event_handler_class.new()
	
	assert_that(event_handler).is_not_null()
	assert_that(event_handler.mission_context).is_not_null()
	assert_that(event_handler.ai_response_templates).is_not_null()

func test_event_categorization() -> void:
	var event_handler_class = preload("res://scripts/ai/mission/mission_ai_event_handler.gd")
	var event_handler = event_handler_class.new()
	
	# Test event categorization
	var phase_event = event_handler._categorize_event("phase_engagement")
	assert_that(phase_event).is_equal(event_handler.EventTriggerType.MISSION_PHASE_CHANGE)
	
	var ship_event = event_handler._categorize_event("ship_damage_critical")
	assert_that(ship_event).is_equal(event_handler.EventTriggerType.SHIP_EVENT)
	
	var combat_event = event_handler._categorize_event("combat_engagement_start")
	assert_that(combat_event).is_equal(event_handler.EventTriggerType.COMBAT_EVENT)

## Test Context Awareness System
func test_context_awareness_system_creation() -> void:
	var context_class = preload("res://scripts/ai/mission/ai_context_awareness_system.gd")
	var context_system = context_class.new()
	
	assert_that(context_system).is_not_null()
	assert_that(context_system.mission_contexts).is_not_null()
	assert_that(context_system.narrative_state).is_not_null()
	assert_that(context_system.environmental_context).is_not_null()

func test_context_type_enum() -> void:
	var context_class = preload("res://scripts/ai/mission/ai_context_awareness_system.gd")
	var context_system = context_class.new()
	
	# Test that context types are properly defined
	assert_that(context_system.ContextType.MISSION_PHASE).is_equal(0)
	assert_that(context_system.ContextType.OBJECTIVE_STATUS).is_equal(1)
	assert_that(context_system.ContextType.NARRATIVE_STATE).is_equal(2)
	assert_that(context_system.ContextType.ENVIRONMENTAL).is_equal(3)

func test_mission_phase_context_structure() -> void:
	var context_class = preload("res://scripts/ai/mission/ai_context_awareness_system.gd")
	var context_system = context_class.new()
	context_system._initialize_contexts()
	
	var phase_context = context_system.mission_contexts[context_system.ContextType.MISSION_PHASE]
	assert_that(phase_context.has("current_phase")).is_true()
	assert_that(phase_context.has("phase_objectives")).is_true()
	assert_that(phase_context.has("phase_constraints")).is_true()

## Test AI Goal System
func test_ai_goal_system_creation() -> void:
	var goal_class = preload("res://scripts/ai/goals/ai_goal_system.gd")
	var goal_system = goal_class.new()
	
	assert_that(goal_system).is_not_null()
	assert_that(goal_system.active_goals).is_not_null()
	assert_that(goal_system.goal_history).is_not_null()
	assert_that(goal_system.goal_execution_queue).is_not_null()

func test_ai_goal_types() -> void:
	var goal_class = preload("res://scripts/ai/goals/ai_goal_system.gd")
	var goal_system = goal_class.new()
	
	# Test goal type enum values
	assert_that(goal_system.GoalType.ATTACK_TARGET).is_equal(0)
	assert_that(goal_system.GoalType.DEFEND_TARGET).is_equal(1)
	assert_that(goal_system.GoalType.ESCORT_TARGET).is_equal(2)
	assert_that(goal_system.GoalType.PATROL_AREA).is_equal(3)

func test_ai_goal_priority_levels() -> void:
	var goal_class = preload("res://scripts/ai/goals/ai_goal_system.gd")
	var goal_system = goal_class.new()
	
	# Test priority levels
	assert_that(goal_system.GoalPriority.EMERGENCY).is_equal(5)
	assert_that(goal_system.GoalPriority.CRITICAL).is_equal(4)
	assert_that(goal_system.GoalPriority.HIGH).is_equal(3)
	assert_that(goal_system.GoalPriority.NORMAL).is_equal(2)
	assert_that(goal_system.GoalPriority.LOW).is_equal(1)

func test_ai_goal_creation() -> void:
	var goal_class = preload("res://scripts/ai/goals/ai_goal_system.gd")
	var ai_goal = goal_class.AIGoal.new("test_goal", 0, "TestTarget", 2)  # ATTACK_TARGET, NORMAL priority
	
	assert_that(ai_goal.goal_id).is_equal("test_goal")
	assert_that(ai_goal.goal_type).is_equal(0)  # ATTACK_TARGET
	assert_that(ai_goal.target_name).is_equal("TestTarget")
	assert_that(ai_goal.priority).is_equal(2)  # NORMAL

func test_goal_type_parsing() -> void:
	var goal_class = preload("res://scripts/ai/goals/ai_goal_system.gd")
	var goal_system = goal_class.new()
	
	# Test goal type parsing
	assert_that(goal_system._parse_goal_type("attack")).is_equal(goal_system.GoalType.ATTACK_TARGET)
	assert_that(goal_system._parse_goal_type("defend")).is_equal(goal_system.GoalType.DEFEND_TARGET)
	assert_that(goal_system._parse_goal_type("escort")).is_equal(goal_system.GoalType.ESCORT_TARGET)
	assert_that(goal_system._parse_goal_type("patrol")).is_equal(goal_system.GoalType.PATROL_AREA)

func test_priority_conversion() -> void:
	var goal_class = preload("res://scripts/ai/goals/ai_goal_system.gd")
	var goal_system = goal_class.new()
	
	# Test priority conversion
	assert_that(goal_system._convert_priority(5.0)).is_equal(goal_system.GoalPriority.EMERGENCY)
	assert_that(goal_system._convert_priority(4.0)).is_equal(goal_system.GoalPriority.CRITICAL)
	assert_that(goal_system._convert_priority(3.0)).is_equal(goal_system.GoalPriority.HIGH)
	assert_that(goal_system._convert_priority(2.0)).is_equal(goal_system.GoalPriority.NORMAL)
	assert_that(goal_system._convert_priority(1.0)).is_equal(goal_system.GoalPriority.LOW)

## Test Mission Behavior Nodes
func test_mission_behavior_nodes_creation() -> void:
	var mission_nodes_class = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var mission_nodes = mission_nodes_class.new()
	
	assert_that(mission_nodes).is_not_null()

func test_mission_context_adaptation_action_creation() -> void:
	var mission_nodes_class = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var adaptation_action = mission_nodes_class.MissionContextAdaptationAction.new()
	
	assert_that(adaptation_action).is_not_null()
	assert_that(adaptation_action.adaptation_sensitivity).is_equal(1.0)
	assert_that(adaptation_action.context_update_frequency).is_equal(2.0)

func test_escort_mission_action_creation() -> void:
	var mission_nodes_class = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var escort_action = mission_nodes_class.EscortMissionAction.new()
	
	assert_that(escort_action).is_not_null()
	assert_that(escort_action.escort_distance).is_equal(200.0)
	assert_that(escort_action.protection_radius).is_equal(500.0)
	assert_that(escort_action.max_escort_distance).is_equal(1000.0)

func test_defensive_operation_action_creation() -> void:
	var mission_nodes_class = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var defensive_action = mission_nodes_class.DefensiveOperationAction.new()
	
	assert_that(defensive_action).is_not_null()
	assert_that(defensive_action.defense_radius).is_equal(800.0)
	assert_that(defensive_action.patrol_radius).is_equal(400.0)
	assert_that(defensive_action.threat_engagement_range).is_equal(1200.0)

func test_scripted_sequence_action_creation() -> void:
	var mission_nodes_class = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var sequence_action = mission_nodes_class.ScriptedSequenceAction.new()
	
	assert_that(sequence_action).is_not_null()
	assert_that(sequence_action.sequence_timeout).is_equal(60.0)
	assert_that(sequence_action.allow_interruption).is_false()

func test_narrative_event_condition_creation() -> void:
	var mission_nodes_class = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd")
	var narrative_condition = mission_nodes_class.NarrativeEventCondition.new()
	
	assert_that(narrative_condition).is_not_null()
	assert_that(narrative_condition.min_tension_level).is_equal(0.0)

## Test Mission Reporter
func test_mission_reporter_creation() -> void:
	var reporter_class = preload("res://scripts/ai/mission/ai_mission_reporter.gd")
	var reporter = reporter_class.new()
	
	assert_that(reporter).is_not_null()
	assert_that(reporter.agent_status_registry).is_not_null()
	assert_that(reporter.objective_progress_registry).is_not_null()
	assert_that(reporter.formation_status_registry).is_not_null()

func test_report_category_enum() -> void:
	var reporter_class = preload("res://scripts/ai/mission/ai_mission_reporter.gd")
	var reporter = reporter_class.new()
	
	# Test report categories
	assert_that(reporter.ReportCategory.STATUS_REPORT).is_equal(0)
	assert_that(reporter.ReportCategory.OBJECTIVE_PROGRESS).is_equal(1)
	assert_that(reporter.ReportCategory.GOAL_COMPLETION).is_equal(2)
	assert_that(reporter.ReportCategory.FORMATION_UPDATE).is_equal(3)

func test_report_priority_enum() -> void:
	var reporter_class = preload("res://scripts/ai/mission/ai_mission_reporter.gd")
	var reporter = reporter_class.new()
	
	# Test report priorities
	assert_that(reporter.ReportPriority.EMERGENCY).is_equal(5)
	assert_that(reporter.ReportPriority.HIGH).is_equal(4)
	assert_that(reporter.ReportPriority.NORMAL).is_equal(3)
	assert_that(reporter.ReportPriority.LOW).is_equal(2)
	assert_that(reporter.ReportPriority.DEBUG).is_equal(1)

func test_report_generation() -> void:
	var reporter_class = preload("res://scripts/ai/mission/ai_mission_reporter.gd")
	var reporter = reporter_class.new()
	reporter._initialize_reporting_system()
	
	# Test report generation
	var report = reporter._create_base_report(reporter.ReportCategory.STATUS_REPORT, reporter.ReportPriority.NORMAL)
	
	assert_that(report.has("id")).is_true()
	assert_that(report.has("category")).is_true()
	assert_that(report.has("priority")).is_true()
	assert_that(report.has("timestamp")).is_true()
	assert_that(report["category"]).is_equal(reporter.ReportCategory.STATUS_REPORT)
	assert_that(report["priority"]).is_equal(reporter.ReportPriority.NORMAL)

## Test Configuration and Settings
func test_ai_behavior_function_metadata() -> void:
	var set_goal_func = ai_behavior_functions_class.SetAIGoalFunction.new()
	
	assert_that(set_goal_func.function_signature).contains("ai-set-goal")
	assert_that(set_goal_func.function_signature).contains("ship_name")
	assert_that(set_goal_func.function_signature).contains("goal_type")
	assert_that(set_goal_func.is_pure_function).is_false()  # AI functions have side effects
	assert_that(set_goal_func.is_cacheable).is_false()      # AI functions shouldn't be cached

func test_mission_reporting_configuration() -> void:
	var reporter_class = preload("res://scripts/ai/mission/ai_mission_reporter.gd")
	var reporter = reporter_class.new()
	
	# Test default configuration
	assert_that(reporter.reporting_enabled).is_true()
	assert_that(reporter.report_frequency).is_equal(2.0)
	assert_that(reporter.max_report_history).is_equal(100)
	assert_that(reporter.filter_by_priority).is_equal(reporter.ReportPriority.LOW)
	
	# Test configuration changes
	reporter.set_reporting_enabled(false)
	assert_that(reporter.reporting_enabled).is_false()
	
	reporter.set_report_frequency(5.0)
	assert_that(reporter.report_frequency).is_equal(5.0)

## Test System Integration Points
func test_sexp_function_registration() -> void:
	# Test that all AI functions can be registered
	var functions_to_register = [
		ai_behavior_functions_class.SetAIGoalFunction.new(),
		ai_behavior_functions_class.ChangeAIBehaviorFunction.new(),
		ai_behavior_functions_class.SetFormationFunction.new(),
		ai_behavior_functions_class.SetTargetPriorityFunction.new(),
		ai_behavior_functions_class.SetAIEnabledFunction.new(),
		ai_behavior_functions_class.GetAIStatusFunction.new()
	]
	
	for func in functions_to_register:
		assert_that(func.function_name).is_not_empty()
		assert_that(func.function_category).is_equal("ai")
		assert_that(func.minimum_args).is_greater_equal(1)

func test_mission_context_data_structure() -> void:
	var context_class = preload("res://scripts/ai/mission/ai_context_awareness_system.gd")
	var context_system = context_class.new()
	context_system._initialize_contexts()
	
	# Test mission context structure
	var mission_context = context_system.mission_contexts[context_system.ContextType.MISSION_PHASE]
	assert_that(mission_context["current_phase"]).is_equal("briefing")
	assert_that(mission_context["phase_objectives"]).is_equal([])
	assert_that(mission_context["phase_constraints"]).is_equal({})

func test_ai_goal_to_dictionary_serialization() -> void:
	var goal_class = preload("res://scripts/ai/goals/ai_goal_system.gd")
	var ai_goal = goal_class.AIGoal.new("test_goal", 0, "TestTarget", 2)
	
	var goal_dict = ai_goal.to_dictionary()
	
	assert_that(goal_dict.has("goal_id")).is_true()
	assert_that(goal_dict.has("goal_type")).is_true()
	assert_that(goal_dict.has("target_name")).is_true()
	assert_that(goal_dict.has("priority")).is_true()
	assert_that(goal_dict.has("status")).is_true()
	assert_that(goal_dict["goal_id"]).is_equal("test_goal")
	assert_that(goal_dict["target_name"]).is_equal("TestTarget")

## Test Utility Functions
func test_formation_type_parsing() -> void:
	# Test formation type parsing from AI behavior functions
	var formation_type_diamond = ai_behavior_functions_class._parse_formation_type("diamond")
	var formation_type_vic = ai_behavior_functions_class._parse_formation_type("vic")
	var formation_type_column = ai_behavior_functions_class._parse_formation_type("column")
	
	assert_that(formation_type_diamond).is_equal(0)  # DIAMOND
	assert_that(formation_type_vic).is_equal(1)      # VIC
	assert_that(formation_type_column).is_equal(3)   # COLUMN

func test_behavior_change_application() -> void:
	# Test behavior change logic
	var mock_agent = Node.new()
	mock_agent.aggression_level = 0.5
	mock_agent.accuracy_modifier = 1.0
	mock_agent.evasion_skill = 1.0
	mock_agent.formation_precision = 1.0
	
	# Test aggressive behavior change
	var success = ai_behavior_functions_class._apply_behavior_change(mock_agent, "aggressive", 0.8)
	assert_that(success).is_true()
	assert_that(mock_agent.aggression_level).is_equal(0.8)
	
	# Test defensive behavior change
	success = ai_behavior_functions_class._apply_behavior_change(mock_agent, "defensive", 0.8)
	assert_that(success).is_true()
	assert_that(mock_agent.aggression_level).is_equal(0.2)  # 1.0 - 0.8
	
	mock_agent.queue_free()

## Test Error Handling
func test_invalid_goal_type_parsing() -> void:
	var goal_class = preload("res://scripts/ai/goals/ai_goal_system.gd")
	var goal_system = goal_class.new()
	
	# Test invalid goal type defaults to PATROL_AREA
	var invalid_goal_type = goal_system._parse_goal_type("invalid_goal_type")
	assert_that(invalid_goal_type).is_equal(goal_system.GoalType.PATROL_AREA)

func test_invalid_behavior_change() -> void:
	var mock_agent = Node.new()
	mock_agent.aggression_level = 0.5
	
	# Test invalid behavior change returns false
	var success = ai_behavior_functions_class._apply_behavior_change(mock_agent, "invalid_behavior", 0.8)
	assert_that(success).is_false()
	assert_that(mock_agent.aggression_level).is_equal(0.5)  # Unchanged
	
	mock_agent.queue_free()

func test_mission_reporter_priority_filtering() -> void:
	var reporter_class = preload("res://scripts/ai/mission/ai_mission_reporter.gd")
	var reporter = reporter_class.new()
	reporter._initialize_reporting_system()
	
	# Set high priority filter
	reporter.set_priority_filter(reporter.ReportPriority.HIGH)
	
	# Test that low priority reports are filtered
	var initial_count = reporter.report_history.size()
	reporter.report_ai_status("TestAgent", {"health": 1.0}, reporter.ReportPriority.LOW)
	assert_that(reporter.report_history.size()).is_equal(initial_count)  # Should not increase
	
	# Test that high priority reports are not filtered
	reporter.report_ai_status("TestAgent", {"health": 1.0}, reporter.ReportPriority.HIGH)
	assert_that(reporter.report_history.size()).is_equal(initial_count + 1)  # Should increase

## Summary Test - Verify All Core Components
func test_ai_mission_integration_system_completeness() -> void:
	# Verify all main components can be instantiated
	var ai_functions = ai_behavior_functions_class.new()
	var event_handler = preload("res://scripts/ai/mission/mission_ai_event_handler.gd").new()
	var context_system = preload("res://scripts/ai/mission/ai_context_awareness_system.gd").new()
	var goal_system = preload("res://scripts/ai/goals/ai_goal_system.gd").new()
	var mission_nodes = preload("res://scripts/ai/behaviors/mission/mission_behavior_nodes.gd").new()
	var reporter = preload("res://scripts/ai/mission/ai_mission_reporter.gd").new()
	
	# Verify all components are valid
	assert_that(ai_functions).is_not_null()
	assert_that(event_handler).is_not_null()
	assert_that(context_system).is_not_null()
	assert_that(goal_system).is_not_null()
	assert_that(mission_nodes).is_not_null()
	assert_that(reporter).is_not_null()
	
	# Cleanup
	event_handler.queue_free()
	context_system.queue_free()
	goal_system.queue_free()
	reporter.queue_free()