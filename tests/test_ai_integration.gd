extends GdUnitTestSuite

## Unit tests for AI Integration and Setup (AI-001) and AI Framework (AI-002)
## Tests LimboAI integration, custom node classes, AI manager, ship controller, and personality system

var test_scene: Node3D
var test_ship: CharacterBody3D
var ai_agent: WCSAIAgent
var ai_manager: Node
var ship_controller: AIShipController
var ai_personality: AIPersonality

func before_test() -> void:
	# Load test scene
	test_scene = preload("res://scenes/tests/ai_integration_test.tscn").instantiate()
	add_child(test_scene)
	
	# Get components
	test_ship = test_scene.get_node("TestShip")
	ai_agent = test_ship.get_node("WCSAIAgent")
	ship_controller = ai_agent.get_node("AIShipController") if ai_agent else null
	
	# Create AI manager instance
	ai_manager = preload("res://scripts/ai/core/ai_manager.gd").new()
	add_child(ai_manager)
	
	# Create test personality
	ai_personality = preload("res://scripts/ai/core/ai_personality.gd").new()
	ai_personality.personality_name = "Test Pilot"

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

## AI-002 Framework Tests

func test_enhanced_ai_manager() -> void:
	# Test enhanced AI manager functionality
	assert_that(ai_manager).is_not_null()
	
	# Test system state management
	ai_manager.set_ai_system_enabled(false)
	assert_that(ai_manager.ai_system_enabled).is_false()
	
	ai_manager.set_ai_system_enabled(true)
	assert_that(ai_manager.ai_system_enabled).is_true()
	
	# Test performance statistics
	var stats: Dictionary = ai_manager.get_performance_stats()
	assert_that(stats.has("active_agents")).is_true()
	assert_that(stats.has("performance_budget_ms")).is_true()
	assert_that(stats.has("system_enabled")).is_true()

func test_ai_manager_team_tracking() -> void:
	# Register agent and test team tracking
	ai_manager.register_ai_agent(ai_agent)
	
	var team_agents: Array = ai_manager.get_agents_by_team(0)
	assert_that(team_agents.size()).is_greater_equal(1)
	
	var enemy_agents: Array = ai_manager.get_enemy_agents(0)
	assert_that(enemy_agents).is_not_null()
	
	ai_manager.unregister_ai_agent(ai_agent)

func test_ai_manager_state_tracking() -> void:
	# Test state-based agent tracking
	ai_manager.register_ai_agent(ai_agent)
	
	ai_agent.set_ai_state("combat")
	
	var combat_agents: Array = ai_manager.get_agents_by_state("combat")
	assert_that(combat_agents.size()).is_greater_equal(1)
	
	ai_manager.unregister_ai_agent(ai_agent)

func test_formation_management() -> void:
	# Test formation creation and management
	ai_manager.register_ai_agent(ai_agent)
	
	var formation_id: String = ai_manager.create_formation(ai_agent, "diamond")
	assert_that(formation_id).is_not_empty()
	
	var formation_info: Dictionary = ai_manager.get_formation_info(formation_id)
	assert_that(formation_info.has("leader")).is_true()
	assert_that(formation_info["leader"]).is_same(ai_agent)
	
	# Create a wingman
	var wingman: WCSAIAgent = WCSAIAgent.new()
	test_scene.add_child(wingman)
	
	var success: bool = ai_manager.add_agent_to_formation(formation_id, wingman, 1)
	assert_that(success).is_true()
	
	formation_info = ai_manager.get_formation_info(formation_id)
	assert_that(formation_info["member_count"]).is_equal(1)
	
	# Test formation disbanding
	success = ai_manager.disband_formation(formation_id)
	assert_that(success).is_true()
	
	wingman.queue_free()
	ai_manager.unregister_ai_agent(ai_agent)

func test_ai_lifecycle_management() -> void:
	# Test AI agent spawning
	var mock_ship: Node = Node.new()
	test_scene.add_child(mock_ship)
	
	var spawned_agent: WCSAIAgent = ai_manager.spawn_ai_agent(mock_ship, ai_personality)
	assert_that(spawned_agent).is_not_null()
	assert_that(spawned_agent.ai_personality).is_same(ai_personality)
	
	# Test lifecycle transitions
	ai_manager.activate_ai_agent(spawned_agent)
	assert_that(spawned_agent.get_ai_state()).is_equal("active")
	
	ai_manager.deactivate_ai_agent(spawned_agent)
	assert_that(spawned_agent.get_ai_state()).is_equal("deactivating")
	
	ai_manager.destroy_ai_agent(spawned_agent)
	assert_that(spawned_agent.get_ai_state()).is_equal("destroying")
	
	mock_ship.queue_free()

func test_ai_ship_controller() -> void:
	# Test AIShipController functionality
	if not ship_controller:
		# Create manually if not available from scene
		ship_controller = AIShipController.new()
		ai_agent.add_child(ship_controller)
	
	assert_that(ship_controller).is_not_null()
	assert_that(ship_controller is AIShipController).is_true()
	
	# Test movement commands
	ship_controller.set_movement_target(Vector3(100, 0, 100))
	assert_that(ship_controller.current_movement_target).is_equal(Vector3(100, 0, 100))
	
	# Test controller status
	var status: Dictionary = ship_controller.get_controller_status()
	assert_that(status.has("ai_enabled")).is_true()
	assert_that(status.has("current_target")).is_true()
	assert_that(status.has("movement_mode")).is_true()

func test_ai_ship_controller_weapon_systems() -> void:
	if not ship_controller:
		ship_controller = AIShipController.new()
		ai_agent.add_child(ship_controller)
	
	# Test weapon range queries
	var primary_range: float = ship_controller.get_weapon_range(AIShipController.WeaponSystem.PRIMARY)
	assert_that(primary_range).is_greater(0.0)
	
	# Test target facing
	var target: Node3D = Node3D.new()
	target.position = Vector3(100, 0, 0)
	test_scene.add_child(target)
	
	ship_controller.face_target(target)
	assert_that(ship_controller.current_facing_target).is_equal(target.global_position)
	
	target.queue_free()

func test_ai_ship_controller_evasive_maneuvers() -> void:
	if not ship_controller:
		ship_controller = AIShipController.new()
		ai_agent.add_child(ship_controller)
	
	var signal_monitor: SignalMonitor = monitor_signals(ship_controller)
	
	ship_controller.execute_evasive_maneuvers(Vector3.FORWARD, "barrel_roll")
	
	assert_that(ship_controller.is_executing_maneuver).is_true()
	assert_signal(signal_monitor).emit_signal("evasive_maneuvers_started").with_parameters("barrel_roll")

func test_ai_personality_system() -> void:
	# Test personality creation and application
	assert_that(ai_personality).is_not_null()
	assert_that(ai_personality.personality_name).is_equal("Test Pilot")
	
	# Test personality application
	ai_personality.apply_to_agent(ai_agent)
	
	# Test factory methods
	var rookie: AIPersonality = AIPersonality.create_rookie()
	assert_that(rookie.personality_name).is_equal("Rookie")
	assert_that(rookie.skill_multiplier).is_less(1.0)
	
	var veteran: AIPersonality = AIPersonality.create_veteran()
	assert_that(veteran.personality_name).is_equal("Veteran")
	assert_that(veteran.skill_multiplier).is_greater(1.0)
	
	var ace: AIPersonality = AIPersonality.create_ace()
	assert_that(ace.personality_name).is_equal("Ace")
	assert_that(ace.special_abilities.size()).is_greater(0)

func test_ai_personality_behavioral_traits() -> void:
	var aggressive: AIPersonality = AIPersonality.create_aggressive()
	
	# Test threat rating calculation
	var threat_rating: float = aggressive.calculate_threat_rating("fighters")
	assert_that(threat_rating).is_greater(0.0)
	
	# Test retreat decision
	var should_retreat: bool = aggressive.should_retreat(0.1, 1.0)  # Low health, high threat
	# Aggressive pilots should retreat less often
	assert_that(should_retreat).is_false()
	
	# Test combat range preference
	var combat_range: float = aggressive.get_preferred_combat_range()
	assert_that(combat_range).is_greater(0.0)

func test_ai_personality_behavior_profile() -> void:
	# Test behavior profile generation
	var profile: Dictionary = ai_personality.create_behavior_profile()
	
	assert_that(profile.has("personality_name")).is_true()
	assert_that(profile.has("skill_level")).is_true()
	assert_that(profile.has("accuracy")).is_true()
	assert_that(profile.has("target_priorities")).is_true()
	assert_that(profile.has("behavior_weights")).is_true()

func test_enhanced_performance_monitoring() -> void:
	# Test enhanced performance monitoring
	var monitor: AIPerformanceMonitor = ai_agent.performance_monitor as AIPerformanceMonitor
	if not monitor:
		monitor = AIPerformanceMonitor.new()
		ai_agent.add_child(monitor)
	
	assert_that(monitor).is_not_null()
	
	# Test budget management
	monitor.set_performance_level(AIPerformanceMonitor.PerformanceLevel.HIGH)
	var budget: float = monitor.get_current_budget_ms()
	assert_that(budget).is_equal(2.0)  # HIGH level = 2.0ms
	
	# Test budget utilization tracking
	monitor.record_ai_frame_time(1500)  # 1.5ms
	var utilization: float = monitor.get_budget_utilization()
	assert_that(utilization).is_greater(0.0)
	
	# Test budget compliance
	var is_compliant: bool = monitor.is_budget_compliant()
	assert_that(is_compliant).is_true()  # 1.5ms < 2.0ms budget

func test_performance_monitor_adaptive_budget() -> void:
	var monitor: AIPerformanceMonitor = AIPerformanceMonitor.new()
	test_scene.add_child(monitor)
	
	monitor.enable_adaptive_budget(true)
	monitor.set_performance_level(AIPerformanceMonitor.PerformanceLevel.NORMAL)
	
	# Simulate high performance usage
	for i in range(20):
		monitor.record_ai_frame_time(2000)  # 2ms (over 1ms budget)
	
	# Budget should auto-adjust
	var scaling_factor: float = monitor.budget_scaling_factor
	assert_that(scaling_factor).is_greater(1.0)
	
	monitor.queue_free()

func test_performance_monitor_alerts() -> void:
	var monitor: AIPerformanceMonitor = AIPerformanceMonitor.new()
	test_scene.add_child(monitor)
	
	monitor.record_ai_frame_time(20000)  # 20ms - way over budget
	
	var alerts: Array = monitor.get_performance_alerts()
	assert_that(alerts.size()).is_greater(0)
	
	var suggestions: Array = monitor.get_optimization_suggestions()
	assert_that(suggestions.size()).is_greater(0)
	
	monitor.queue_free()

func test_ai_agent_personality_integration() -> void:
	# Test personality integration with AI agent
	ai_agent.ai_personality = ai_personality
	ai_agent.apply_personality()
	
	# Test modifier methods that personality system uses
	ai_agent.set_accuracy_modifier(1.5)
	assert_that(ai_agent.get_accuracy_modifier()).is_equal(1.5)
	
	ai_agent.set_evasion_skill(1.2)
	assert_that(ai_agent.get_evasion_skill()).is_equal(1.2)
	
	ai_agent.set_formation_precision(0.8)
	assert_that(ai_agent.get_formation_precision()).is_equal(0.8)

func test_ai_agent_ship_controller_integration_enhanced() -> void:
	# Test enhanced ship controller integration
	if ship_controller:
		# Test movement commands through AI agent
		ai_agent.move_to_position(Vector3(200, 0, 200))
		assert_that(ship_controller.current_movement_target).is_equal(Vector3(200, 0, 200))
		
		# Test weapon firing
		var target: Node3D = Node3D.new()
		test_scene.add_child(target)
		ai_agent.set_current_target(target)
		
		# Test firing weapons (will return false without actual ship systems)
		var fired: bool = ai_agent.fire_weapons(AIShipController.WeaponSystem.PRIMARY)
		assert_that(fired).is_false()  # Expected since no real weapons
		
		target.queue_free()

func test_ai_manager_performance_tracking() -> void:
	# Test AI manager performance tracking
	ai_manager.register_ai_agent(ai_agent)
	
	# Simulate some performance data
	ai_agent.performance_monitor.record_ai_frame_time(1000)  # 1ms
	
	var manager_stats: Dictionary = ai_manager.get_performance_stats()
	assert_that(manager_stats.has("budget_utilization")).is_true()
	assert_that(manager_stats.has("total_execution_time_ms")).is_true()
	
	ai_manager.unregister_ai_agent(ai_agent)

## Integration Performance Test for AI-002
func test_ai_framework_performance() -> void:
	# Test complete AI framework performance
	var test_agents: Array[WCSAIAgent] = []
	
	# Create multiple AI agents
	for i in range(10):
		var mock_ship: Node = Node.new()
		test_scene.add_child(mock_ship)
		
		var agent: WCSAIAgent = ai_manager.spawn_ai_agent(mock_ship)
		test_agents.append(agent)
		ai_manager.activate_ai_agent(agent)
	
	var start_time: int = Time.get_ticks_usec()
	
	# Simulate AI processing for all agents
	for agent in test_agents:
		agent.update_ai_decision(0.016)
	
	var total_time: float = (Time.get_ticks_usec() - start_time) / 1000.0
	
	# 10 AI agents should process in less than 20ms
	assert_that(total_time).is_less(20.0)
	
	# Cleanup
	for agent in test_agents:
		ai_manager.destroy_ai_agent(agent)