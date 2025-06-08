extends GdUnitTestSuite

## Comprehensive test suite for AI Behavior Tree Infrastructure (AI-003)
## Tests all behavior tree components including actions, conditions, manager, and debugging

# Test subjects
var behavior_tree_manager: BehaviorTreeManager
var ai_debugger: AIDebugger
var test_agent: WCSAIAgent
var mock_ship_controller: Node

# Test data
var test_behavior_trees: Dictionary = {}
var test_templates: Array[String] = []

func before_test() -> void:
	# Create test instances
	behavior_tree_manager = BehaviorTreeManager.new()
	ai_debugger = AIDebugger.new()
	test_agent = WCSAIAgent.new()
	mock_ship_controller = Node.new()
	
	# Set up test agent
	test_agent.name = "TestAgent"
	test_agent.add_child(mock_ship_controller)
	
	# Add to scene tree for testing
	add_child(behavior_tree_manager)
	add_child(ai_debugger)
	add_child(test_agent)
	
	# Initialize test data
	test_templates = ["fighter_combat", "fighter_escort", "capital_combat"]

func after_test() -> void:
	# Clean up test instances
	if is_instance_valid(behavior_tree_manager):
		behavior_tree_manager.queue_free()
	if is_instance_valid(ai_debugger):
		ai_debugger.queue_free()
	if is_instance_valid(test_agent):
		test_agent.queue_free()
	if is_instance_valid(mock_ship_controller):
		mock_ship_controller.queue_free()

# BehaviorTreeManager Tests
func test_behavior_tree_manager_initialization() -> void:
	assert_not_null(behavior_tree_manager, "BehaviorTreeManager should be created")
	assert_true(behavior_tree_manager.has_method("register_behavior_template"), "Should have register_behavior_template method")
	assert_true(behavior_tree_manager.has_method("assign_behavior_tree"), "Should have assign_behavior_tree method")

func test_behavior_template_registration() -> void:
	var test_tree: BehaviorTree = BehaviorTree.new()
	test_tree.resource_name = "TestTemplate"
	
	var metadata: Dictionary = {
		"ship_classes": ["fighter"],
		"behavior_type": "test",
		"performance_priority": "high"
	}
	
	var result: bool = behavior_tree_manager.register_behavior_template("test_template", test_tree, metadata)
	
	assert_true(result, "Template registration should succeed")
	
	var available_templates: Array = behavior_tree_manager.get_available_templates()
	assert_true("test_template" in available_templates, "Template should be in available templates")
	
	var retrieved_metadata: Dictionary = behavior_tree_manager.get_template_metadata("test_template")
	assert_eq(retrieved_metadata["behavior_type"], "test", "Metadata should be stored correctly")

func test_behavior_tree_assignment() -> void:
	# Register a test template first
	var test_tree: BehaviorTree = BehaviorTree.new()
	test_tree.resource_name = "AssignmentTest"
	behavior_tree_manager.register_behavior_template("assignment_test", test_tree)
	
	# Assign tree to agent
	var assigned_tree: BehaviorTree = behavior_tree_manager.assign_behavior_tree(test_agent, "assignment_test")
	
	assert_not_null(assigned_tree, "Should return assigned behavior tree")
	assert_eq(assigned_tree.resource_name, "AssignmentTest", "Should assign correct tree")
	
	# Verify agent has the tree
	var agent_tree: BehaviorTree = behavior_tree_manager.get_behavior_tree_for_agent(test_agent)
	assert_not_null(agent_tree, "Agent should have assigned tree")

func test_behavior_tree_pooling() -> void:
	# Register template
	var test_tree: BehaviorTree = BehaviorTree.new()
	behavior_tree_manager.register_behavior_template("pooling_test", test_tree)
	
	# Assign tree
	var tree1: BehaviorTree = behavior_tree_manager.assign_behavior_tree(test_agent, "pooling_test")
	assert_not_null(tree1, "First assignment should succeed")
	
	# Release tree
	var release_result: bool = behavior_tree_manager.release_behavior_tree(test_agent)
	assert_true(release_result, "Tree release should succeed")
	
	# Verify agent no longer has tree
	var agent_tree: BehaviorTree = behavior_tree_manager.get_behavior_tree_for_agent(test_agent)
	assert_null(agent_tree, "Agent should not have tree after release")

func test_templates_for_ship_class() -> void:
	# Register templates with different ship classes
	var fighter_tree: BehaviorTree = BehaviorTree.new()
	behavior_tree_manager.register_behavior_template("fighter_specific", fighter_tree, {"ship_classes": ["fighter"]})
	
	var universal_tree: BehaviorTree = BehaviorTree.new()
	behavior_tree_manager.register_behavior_template("universal", universal_tree, {"ship_classes": ["all"]})
	
	var fighter_templates: Array = behavior_tree_manager.get_templates_for_ship_class("fighter")
	assert_true("fighter_specific" in fighter_templates, "Should include fighter-specific template")
	assert_true("universal" in fighter_templates, "Should include universal template")
	
	var capital_templates: Array = behavior_tree_manager.get_templates_for_ship_class("capital")
	assert_false("fighter_specific" in capital_templates, "Should not include fighter-specific template")
	assert_true("universal" in capital_templates, "Should include universal template")

# WCS Behavior Tree Action Tests
func test_move_to_action() -> void:
	var move_action: MoveToAction = MoveToAction.new()
	move_action.ai_agent = test_agent
	move_action.ship_controller = mock_ship_controller
	
	# Test target position setting
	var target_pos: Vector3 = Vector3(100, 0, 200)
	move_action.set_target_position_direct(target_pos)
	assert_eq(move_action.target_position, target_pos, "Target position should be set correctly")
	
	# Test distance calculation (requires mock implementation)
	var distance: float = move_action.get_distance_to_target()
	assert_ge(distance, 0.0, "Distance should be non-negative")

func test_attack_target_action() -> void:
	var attack_action: AttackTargetAction = AttackTargetAction.new()
	attack_action.ai_agent = test_agent
	attack_action.ship_controller = mock_ship_controller
	
	# Test weapon parameters
	attack_action.set_weapon_parameters(1500.0, 750.0, 0.85)
	assert_eq(attack_action.weapon_range, 1500.0, "Weapon range should be set")
	assert_eq(attack_action.optimal_attack_distance, 750.0, "Optimal distance should be set")
	assert_eq(attack_action.min_firing_angle, 0.85, "Firing angle should be set")

func test_follow_leader_action() -> void:
	var follow_action: FollowLeaderAction = FollowLeaderAction.new()
	follow_action.ai_agent = test_agent
	follow_action.ship_controller = mock_ship_controller
	
	# Test formation parameters
	var offset: Vector3 = Vector3(75, 10, -100)
	follow_action.set_formation_parameters(offset, 300.0, 0.8)
	assert_eq(follow_action.formation_offset, offset, "Formation offset should be set")
	assert_eq(follow_action.max_distance_from_leader, 300.0, "Max distance should be set")
	assert_eq(follow_action.formation_tightness, 0.8, "Formation tightness should be set")

# WCS Behavior Tree Condition Tests
func test_has_target_condition() -> void:
	var has_target_condition: HasTargetCondition = HasTargetCondition.new()
	has_target_condition.ai_agent = test_agent
	
	# Test without target (should fail)
	var result: bool = has_target_condition.evaluate_wcs_condition(0.016)
	assert_false(result, "Should return false when no target")
	
	# Mock target setting would require agent modification
	# This tests the condition logic structure

func test_in_formation_condition() -> void:
	var formation_condition: InFormationCondition = InFormationCondition.new()
	formation_condition.ai_agent = test_agent
	
	# Test formation tolerances
	formation_condition.set_formation_tolerances(25.0, 150.0, 0.9)
	assert_eq(formation_condition.max_distance_from_position, 25.0, "Position tolerance should be set")
	assert_eq(formation_condition.max_distance_from_leader, 150.0, "Leader tolerance should be set")
	assert_eq(formation_condition.orientation_tolerance, 0.9, "Orientation tolerance should be set")

func test_threat_detected_condition() -> void:
	var threat_condition: ThreatDetectedCondition = ThreatDetectedCondition.new()
	threat_condition.ai_agent = test_agent
	
	# Test threat detection parameters
	threat_condition.detection_range = 1800.0
	threat_condition.threat_threshold = 0.4
	threat_condition.immediate_threat_range = 400.0
	
	assert_eq(threat_condition.detection_range, 1800.0, "Detection range should be set")
	assert_eq(threat_condition.threat_threshold, 0.4, "Threat threshold should be set")
	assert_eq(threat_condition.immediate_threat_range, 400.0, "Immediate threat range should be set")
	
	# Test threat data structures
	var threats: Array = threat_condition.get_detected_threats()
	assert_not_null(threats, "Should return threat array")
	
	var highest_threat: Dictionary = threat_condition.get_highest_threat()
	assert_not_null(highest_threat, "Should return highest threat dictionary")

# AI Debugger Tests
func test_ai_debugger_initialization() -> void:
	assert_not_null(ai_debugger, "AIDebugger should be created")
	assert_true(ai_debugger.has_method("register_agent"), "Should have register_agent method")
	assert_true(ai_debugger.has_method("get_agent_debug_info"), "Should have get_agent_debug_info method")

func test_agent_registration() -> void:
	ai_debugger.register_agent(test_agent)
	
	var monitored_agents: Array = ai_debugger.get_all_monitored_agents()
	assert_true(test_agent in monitored_agents, "Agent should be in monitored list")
	
	var debug_info: Dictionary = ai_debugger.get_agent_debug_info(test_agent)
	assert_not_null(debug_info, "Should return debug info for registered agent")

func test_agent_unregistration() -> void:
	ai_debugger.register_agent(test_agent)
	ai_debugger.unregister_agent(test_agent)
	
	var monitored_agents: Array = ai_debugger.get_all_monitored_agents()
	assert_false(test_agent in monitored_agents, "Agent should not be in monitored list after unregistration")

func test_performance_monitoring() -> void:
	ai_debugger.enable_performance_monitoring = true
	ai_debugger.register_agent(test_agent)
	
	# Simulate some time passing
	await get_tree().process_frame
	await get_tree().process_frame
	
	var performance_history: Array = ai_debugger.get_performance_history(test_agent)
	assert_not_null(performance_history, "Should return performance history")

# Integration Tests
func test_full_behavior_tree_workflow() -> void:
	"""Test complete workflow from template registration to agent execution"""
	
	# 1. Register template
	var test_tree: BehaviorTree = BehaviorTree.new()
	test_tree.resource_name = "IntegrationTest"
	var registration_success: bool = behavior_tree_manager.register_behavior_template("integration_test", test_tree)
	assert_true(registration_success, "Template registration should succeed")
	
	# 2. Assign to agent
	var assigned_tree: BehaviorTree = behavior_tree_manager.assign_behavior_tree(test_agent, "integration_test")
	assert_not_null(assigned_tree, "Tree assignment should succeed")
	
	# 3. Register for debugging
	ai_debugger.register_agent(test_agent)
	var monitored_agents: Array = ai_debugger.get_all_monitored_agents()
	assert_true(test_agent in monitored_agents, "Agent should be monitored")
	
	# 4. Get debug info
	var debug_info: Dictionary = ai_debugger.get_agent_debug_info(test_agent)
	assert_str_contains(debug_info.get("current_behavior", ""), "IntegrationTest", "Debug info should show correct behavior")
	
	# 5. Release tree
	var release_success: bool = behavior_tree_manager.release_behavior_tree(test_agent)
	assert_true(release_success, "Tree release should succeed")

func test_sexp_integration() -> void:
	"""Test SEXP system integration with behavior tree manager"""
	
	var sexp_manager = Engine.get_singleton("SexpManager")
	if not sexp_manager:
		skip_test("SEXP system not available - skipping SEXP integration test")
		return
	
	# Register a template
	var test_tree: BehaviorTree = BehaviorTree.new()
	behavior_tree_manager.register_behavior_template("sexp_test", test_tree)
	
	# Assign to agent
	behavior_tree_manager.assign_behavior_tree(test_agent, "sexp_test")
	
	# Test SEXP function registration (if available)
	if sexp_manager.has_method("get_registered_functions"):
		var functions: Array = sexp_manager.get_registered_functions()
		var ai_functions: Array = functions.filter(func(f): return f.begins_with("ai-"))
		assert_gt(ai_functions.size(), 0, "Should have AI-related SEXP functions registered")

# Performance Tests
func test_behavior_tree_performance() -> void:
	"""Test behavior tree system performance under load"""
	
	var num_agents: int = 10
	var agents: Array = []  # Array[WCSAIAgent] - avoiding circular type issues
	
	# Create multiple agents
	for i in num_agents:
		var agent: WCSAIAgent = WCSAIAgent.new()
		agent.name = "PerformanceTestAgent_%d" % i
		add_child(agent)
		agents.append(agent)
	
	# Register template
	var test_tree: BehaviorTree = BehaviorTree.new()
	behavior_tree_manager.register_behavior_template("performance_test", test_tree)
	
	# Measure assignment time
	var start_time: int = Time.get_ticks_usec()
	
	for agent in agents:
		behavior_tree_manager.assign_behavior_tree(agent, "performance_test")
	
	var assignment_time: float = (Time.get_ticks_usec() - start_time) / 1000.0  # Convert to milliseconds
	
	assert_lt(assignment_time, 50.0, "Mass assignment should complete within 50ms")
	
	# Verify all assignments
	for agent in agents:
		var assigned_tree: BehaviorTree = behavior_tree_manager.get_behavior_tree_for_agent(agent)
		assert_not_null(assigned_tree, "Each agent should have assigned tree")
	
	# Clean up
	for agent in agents:
		behavior_tree_manager.release_behavior_tree(agent)
		agent.queue_free()

func test_memory_usage() -> void:
	"""Test memory usage and cleanup"""
	
	# Register template
	var test_tree: BehaviorTree = BehaviorTree.new()
	behavior_tree_manager.register_behavior_template("memory_test", test_tree)
	
	# Assign and release multiple times
	for i in 20:
		var assigned_tree: BehaviorTree = behavior_tree_manager.assign_behavior_tree(test_agent, "memory_test")
		assert_not_null(assigned_tree, "Assignment %d should succeed" % i)
		
		var release_success: bool = behavior_tree_manager.release_behavior_tree(test_agent)
		assert_true(release_success, "Release %d should succeed" % i)
	
	# Verify no memory leaks (tree should be pooled/reused)
	var final_tree: BehaviorTree = behavior_tree_manager.assign_behavior_tree(test_agent, "memory_test")
	assert_not_null(final_tree, "Final assignment should still work")

# Error Handling Tests
func test_invalid_template_assignment() -> void:
	"""Test error handling for invalid template assignment"""
	
	var result: BehaviorTree = behavior_tree_manager.assign_behavior_tree(test_agent, "nonexistent_template")
	assert_null(result, "Should return null for nonexistent template")

func test_null_agent_handling() -> void:
	"""Test error handling for null agent"""
	
	var test_tree: BehaviorTree = BehaviorTree.new()
	behavior_tree_manager.register_behavior_template("null_test", test_tree)
	
	var result: BehaviorTree = behavior_tree_manager.assign_behavior_tree(null, "null_test")
	assert_null(result, "Should return null for null agent")

func test_invalid_template_registration() -> void:
	"""Test error handling for invalid template registration"""
	
	var result1: bool = behavior_tree_manager.register_behavior_template("", BehaviorTree.new())
	assert_false(result1, "Should fail with empty template name")
	
	var result2: bool = behavior_tree_manager.register_behavior_template("valid_name", null)
	assert_false(result2, "Should fail with null behavior tree")

# Signal Tests
func test_behavior_tree_signals() -> void:
	"""Test behavior tree manager signals"""
	
	var template_loaded_signal_received: bool = false
	var tree_assigned_signal_received: bool = false
	
	behavior_tree_manager.behavior_tree_loaded.connect(func(template_name: String, tree: BehaviorTree):
		template_loaded_signal_received = true
	)
	
	behavior_tree_manager.behavior_tree_assigned.connect(func(agent: WCSAIAgent, tree: BehaviorTree):
		tree_assigned_signal_received = true
	)
	
	# Register template and assign
	var test_tree: BehaviorTree = BehaviorTree.new()
	behavior_tree_manager.register_behavior_template("signal_test", test_tree)
	behavior_tree_manager.assign_behavior_tree(test_agent, "signal_test")
	
	# Wait for signals
	await get_tree().process_frame
	
	assert_true(template_loaded_signal_received, "Should receive template loaded signal")
	assert_true(tree_assigned_signal_received, "Should receive tree assigned signal")

func test_ai_debugger_signals() -> void:
	"""Test AI debugger signals"""
	
	var debug_info_updated_received: bool = false
	
	ai_debugger.debug_info_updated.connect(func(agent: WCSAIAgent, debug_data: Dictionary):
		debug_info_updated_received = true
	)
	
	ai_debugger.register_agent(test_agent)
	
	# Wait for debug update
	await get_tree().create_timer(0.2).timeout
	
	assert_true(debug_info_updated_received, "Should receive debug info updated signal")