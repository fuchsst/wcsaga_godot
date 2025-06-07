extends GdUnitTestSuite

## Unit tests for AI Integration and Setup (AI-001)
## Tests LimboAI integration, custom node classes, and basic functionality

var test_scene: Node3D
var test_ship: CharacterBody3D
var ai_agent: WCSAIAgent
var ai_manager: Node

func before_test() -> void:
	# Load test scene
	test_scene = preload("res://scenes/tests/ai_integration_test.tscn").instantiate()
	add_child(test_scene)
	
	# Get components
	test_ship = test_scene.get_node("TestShip")
	ai_agent = test_ship.get_node("WCSAIAgent")
	
	# Create AI manager instance
	ai_manager = preload("res://scripts/ai/core/ai_manager.gd").new()
	add_child(ai_manager)

func after_test() -> void:
	if test_scene:
		test_scene.queue_free()
	if ai_manager:
		ai_manager.queue_free()

func test_limboai_integration() -> void:
	# Test that WCSAIAgent is properly set up (will extend LimboAI when available)
	assert_that(ai_agent).is_not_null()
	assert_that(ai_agent is Node).is_true()
	assert_that(ai_agent.get_script().get_path()).contains("wcs_ai_agent")

func test_ai_agent_initialization() -> void:
	# Test AI agent proper initialization
	assert_that(ai_agent.skill_level).is_equal(0.5)
	assert_that(ai_agent.aggression_level).is_equal(0.5)
	assert_that(ai_agent.current_target).is_null()
	assert_that(ai_agent.formation_leader).is_null()
	assert_that(ai_agent.formation_position).is_equal(-1)

func test_ai_agent_ship_controller_integration() -> void:
	# Test integration with ship controller
	var ship_controller: Node = ai_agent.get_ship_controller()
	assert_that(ship_controller).is_not_null()
	assert_that(ship_controller).is_same(test_ship)

func test_ai_manager_registration() -> void:
	# Test AI manager agent registration
	var initial_count: int = ai_manager.get_active_agent_count()
	
	ai_manager.register_ai_agent(ai_agent)
	assert_that(ai_manager.get_active_agent_count()).is_equal(initial_count + 1)
	
	ai_manager.unregister_ai_agent(ai_agent)
	assert_that(ai_manager.get_active_agent_count()).is_equal(initial_count)

func test_performance_monitor_creation() -> void:
	# Test that performance monitor is created
	assert_that(ai_agent.performance_monitor).is_not_null()
	
	# Test performance recording
	ai_agent.performance_monitor.record_ai_frame_time(1000)  # 1ms
	var stats: Dictionary = ai_agent.performance_monitor.get_stats()
	assert_that(stats.has("frame_time_ms")).is_true()

func test_wcs_bt_action_base_class() -> void:
	# Test WCSBTAction base class functionality
	var action: WCSBTAction = preload("res://scripts/ai/behaviors/actions/move_to_action.gd").new()
	
	# Set up mock agent
	action.agent = ai_agent
	action._setup()
	
	assert_that(action.ai_agent).is_same(ai_agent)
	assert_that(action.ship_controller).is_not_null()

func test_wcs_bt_condition_base_class() -> void:
	# Test WCSBTCondition base class functionality
	var condition: WCSBTCondition = preload("res://scripts/ai/behaviors/conditions/has_target_condition.gd").new()
	
	# Set up mock agent
	condition.agent = ai_agent
	condition._setup()
	
	assert_that(condition.ai_agent).is_same(ai_agent)
	assert_that(condition.ship_controller).is_not_null()

func test_has_target_condition() -> void:
	# Test HasTargetCondition functionality
	var condition: HasTargetCondition = preload("res://scripts/ai/behaviors/conditions/has_target_condition.gd").new()
	condition.agent = ai_agent
	condition._setup()
	
	# No target initially
	var result: bool = condition.evaluate_wcs_condition(0.0)
	assert_that(result).is_false()
	
	# Set a target
	var target: Node3D = Node3D.new()
	test_scene.add_child(target)
	ai_agent.set_current_target(target)
	
	result = condition.evaluate_wcs_condition(0.0)
	assert_that(result).is_true()
	
	target.queue_free()

func test_move_to_action() -> void:
	# Test MoveToAction functionality
	var action: MoveToAction = preload("res://scripts/ai/behaviors/actions/move_to_action.gd").new()
	action.agent = ai_agent
	action._setup()
	
	# Set target position
	action.set_target_position_direct(Vector3(100, 0, 100))
	
	# Execute action
	var result: int = action.execute_wcs_action(0.016)
	
	# Should be running since we're not at target yet (2 = RUNNING)
	assert_that(result).is_equal(2)

func test_ai_agent_signals() -> void:
	# Test AI agent signal emissions
	var signal_monitor: SignalMonitor = monitor_signals(ai_agent)
	
	# Test target acquisition signal
	var target: Node3D = Node3D.new()
	test_scene.add_child(target)
	
	ai_agent.set_current_target(target)
	
	assert_signal(signal_monitor).emit_signal("target_acquired").with_parameters(target)
	
	# Test target loss signal
	ai_agent.set_current_target(null)
	assert_signal(signal_monitor).emit_signal("target_lost").with_parameters(target)
	
	target.queue_free()

func test_ai_state_management() -> void:
	# Test AI state changes
	var signal_monitor: SignalMonitor = monitor_signals(ai_agent)
	
	assert_that(ai_agent.get_ai_state()).is_equal("idle")
	
	ai_agent.set_ai_state("combat")
	
	assert_that(ai_agent.get_ai_state()).is_equal("combat")
	assert_signal(signal_monitor).emit_signal("ai_state_changed").with_parameters("idle", "combat")

func test_formation_status() -> void:
	# Test formation status management
	var leader: WCSAIAgent = WCSAIAgent.new()
	test_scene.add_child(leader)
	
	assert_that(ai_agent.is_formation_leader()).is_true()
	
	ai_agent.set_formation_leader(leader, 1)
	
	var status: Dictionary = ai_agent.get_formation_status()
	assert_that(status["is_in_formation"]).is_true()
	assert_that(status["formation_leader"]).is_same(leader)
	assert_that(status["formation_position"]).is_equal(1)
	
	assert_that(ai_agent.is_formation_leader()).is_false()
	
	leader.queue_free()

func test_skill_and_aggression_levels() -> void:
	# Test skill and aggression level management
	ai_agent.set_skill_level(1.5)
	assert_that(ai_agent.get_skill_level()).is_equal(1.5)
	
	# Test clamping
	ai_agent.set_skill_level(3.0)
	assert_that(ai_agent.get_skill_level()).is_equal(2.0)
	
	ai_agent.set_skill_level(-1.0)
	assert_that(ai_agent.get_skill_level()).is_equal(0.0)
	
	ai_agent.set_aggression_level(1.2)
	assert_that(ai_agent.get_aggression_level()).is_equal(1.2)

func test_debug_info() -> void:
	# Test debug information gathering
	var debug_info: Dictionary = ai_agent.get_debug_info()
	
	assert_that(debug_info.has("ai_state")).is_true()
	assert_that(debug_info.has("current_target")).is_true()
	assert_that(debug_info.has("formation_status")).is_true()
	assert_that(debug_info.has("skill_level")).is_true()
	assert_that(debug_info.has("aggression_level")).is_true()
	assert_that(debug_info.has("threat_level")).is_true()
	assert_that(debug_info.has("behavior_tree")).is_true()

## Integration test with Godot project
func test_godot_project_integration() -> void:
	# Verify that the scene loads without errors
	assert_that(test_scene).is_not_null()
	assert_that(test_ship).is_not_null()
	assert_that(ai_agent).is_not_null()
	
	# Verify scene hierarchy
	assert_that(ai_agent.get_parent()).is_same(test_ship)
	assert_that(test_ship.get_parent()).is_same(test_scene)

## Performance test
func test_ai_performance() -> void:
	# Test that AI processing stays within reasonable bounds
	var start_time: int = Time.get_ticks_usec()
	
	# Simulate AI processing
	for i in range(100):
		ai_agent.update_ai_decision(0.016)
	
	var total_time: float = (Time.get_ticks_usec() - start_time) / 1000.0
	
	# Should complete 100 AI updates in less than 50ms
	assert_that(total_time).is_less(50.0)