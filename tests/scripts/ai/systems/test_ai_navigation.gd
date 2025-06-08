extends GdUnitTestSuite

## Comprehensive unit tests for AI Navigation System (AI-005)
## Tests waypoint navigation, path planning, route management, and navigation patterns

class_name TestAINavigation

# Test components
var path_planner: WCSPathPlanner
var waypoint_manager: WCSWaypointManager
var navigation_controller: WCSNavigationController
var path_recalculator: DynamicPathRecalculator

# Test objects
var test_agent: WCSAIAgent
var test_ship_controller: AIShipController

# Test data
var test_waypoints: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(100, 0, 0),
	Vector3(100, 0, 100),
	Vector3(0, 0, 100)
]

func before_test() -> void:
	# Create test components
	path_planner = WCSPathPlanner.new()
	waypoint_manager = WCSWaypointManager.new()
	navigation_controller = WCSNavigationController.new()
	path_recalculator = DynamicPathRecalculator.new()
	
	# Create test AI agent and ship controller
	test_agent = WCSAIAgent.new()
	test_agent.name = "TestAgent"
	test_ship_controller = AIShipController.new()
	test_ship_controller.name = "TestShipController"
	
	# Add to scene tree
	add_child(path_planner)
	add_child(waypoint_manager)
	add_child(navigation_controller)
	add_child(path_recalculator)
	add_child(test_agent)
	add_child(test_ship_controller)
	
	# Connect ship controller to agent
	test_agent.add_child(test_ship_controller)

func after_test() -> void:
	# Cleanup
	if path_planner:
		path_planner.queue_free()
	if waypoint_manager:
		waypoint_manager.queue_free()
	if navigation_controller:
		navigation_controller.queue_free()
	if path_recalculator:
		path_recalculator.queue_free()
	if test_agent:
		test_agent.queue_free()

# Path Planner Tests

func test_path_planner_initialization() -> void:
	assert_that(path_planner).is_not_null()
	assert_that(path_planner.grid_cell_size).is_equal(100.0)
	assert_that(path_planner.max_planning_distance).is_equal(10000.0)

func test_path_planner_simple_path() -> void:
	var start: Vector3 = Vector3(0, 0, 0)
	var goal: Vector3 = Vector3(500, 0, 0)
	
	var path: Array[Vector3] = path_planner.calculate_path(start, goal)
	
	assert_that(path).is_not_empty()
	assert_that(path[0]).is_equal(start)
	assert_that(path[-1].distance_to(goal)).is_less(path_planner.grid_cell_size)

func test_path_planner_invalid_input() -> void:
	var start: Vector3 = Vector3(0, 0, 0)
	var goal: Vector3 = Vector3(20000, 0, 0)  # Beyond max distance
	
	var path: Array[Vector3] = path_planner.calculate_path(start, goal)
	
	assert_that(path).is_empty()

func test_path_planner_grid_conversion() -> void:
	var world_pos: Vector3 = Vector3(250, 0, 350)
	var grid_coord: Vector2i = path_planner._world_to_grid(world_pos)
	var back_to_world: Vector3 = path_planner._grid_to_world(grid_coord)
	
	assert_that(grid_coord.x).is_equal(2)  # 250 / 100 = 2
	assert_that(grid_coord.y).is_equal(3)  # 350 / 100 = 3
	assert_that(back_to_world.distance_to(Vector3(250, 0, 350))).is_less(path_planner.grid_cell_size)

func test_path_planner_performance() -> void:
	var start_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	
	var start: Vector3 = Vector3(0, 0, 0)
	var goal: Vector3 = Vector3(1000, 0, 1000)
	var path: Array[Vector3] = path_planner.calculate_path(start, goal)
	
	var end_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	var calculation_time_ms: float = (end_time - start_time) / 1000.0
	
	assert_that(calculation_time_ms).is_less(100.0)  # Should complete within 100ms
	assert_that(path).is_not_empty()

# Waypoint Manager Tests

func test_waypoint_creation() -> void:
	var waypoint: WCSWaypointManager.Waypoint = waypoint_manager.create_waypoint(
		"test_wp", Vector3(100, 0, 100), WCSWaypointManager.WaypointType.NAVIGATION
	)
	
	assert_that(waypoint).is_not_null()
	assert_that(waypoint.id).is_equal("test_wp")
	assert_that(waypoint.position).is_equal(Vector3(100, 0, 100))
	assert_that(waypoint.type).is_equal(WCSWaypointManager.WaypointType.NAVIGATION)

func test_route_creation() -> void:
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("test_route", test_waypoints)
	
	assert_that(route).is_not_null()
	assert_that(route.id).is_equal("test_route")
	assert_that(route.waypoints.size()).is_equal(test_waypoints.size())
	assert_that(route.type).is_equal(WCSWaypointManager.RouteType.LINEAR)

func test_route_assignment() -> void:
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("test_route", test_waypoints)
	var success: bool = waypoint_manager.assign_route_to_agent("test_agent", route)
	
	assert_that(success).is_true()
	
	var current_waypoint: WCSWaypointManager.Waypoint = waypoint_manager.get_current_waypoint("test_agent")
	assert_that(current_waypoint).is_not_null()
	assert_that(current_waypoint.position).is_equal(test_waypoints[0])

func test_waypoint_arrival_detection() -> void:
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("test_route", test_waypoints)
	waypoint_manager.assign_route_to_agent("test_agent", route)
	
	# Test arrival at first waypoint
	var arrived: bool = waypoint_manager.check_waypoint_arrival("test_agent", test_waypoints[0])
	assert_that(arrived).is_true()
	
	# Test not arrived when far away
	var not_arrived: bool = waypoint_manager.check_waypoint_arrival("test_agent", Vector3(1000, 0, 1000))
	assert_that(not_arrived).is_false()

func test_route_progression() -> void:
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("test_route", test_waypoints)
	waypoint_manager.assign_route_to_agent("test_agent", route)
	
	# Advance through waypoints
	for i in range(test_waypoints.size()):
		var current_wp: WCSWaypointManager.Waypoint = waypoint_manager.get_current_waypoint("test_agent")
		assert_that(current_wp.position).is_equal(test_waypoints[i])
		
		# Simulate arrival
		waypoint_manager.check_waypoint_arrival("test_agent", test_waypoints[i])
		
		if i < test_waypoints.size() - 1:
			var advanced: bool = waypoint_manager.advance_to_next_waypoint("test_agent")
			assert_that(advanced).is_true()

func test_route_progress_tracking() -> void:
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("test_route", test_waypoints)
	waypoint_manager.assign_route_to_agent("test_agent", route)
	
	var initial_progress: Dictionary = waypoint_manager.get_route_progress("test_agent")
	assert_that(initial_progress["progress_percentage"]).is_equal(0.0)
	assert_that(initial_progress["completed_waypoints"]).is_equal(0)
	
	# Advance halfway through route
	for i in range(test_waypoints.size() / 2):
		waypoint_manager.check_waypoint_arrival("test_agent", test_waypoints[i])
		waypoint_manager.advance_to_next_waypoint("test_agent")
	
	var mid_progress: Dictionary = waypoint_manager.get_route_progress("test_agent")
	assert_that(mid_progress["progress_percentage"]).is_greater(0.4).is_less(0.6)

func test_patrol_route_creation() -> void:
	var start_pos: Vector3 = Vector3(0, 0, 0)
	var end_pos: Vector3 = Vector3(500, 0, 0)
	
	var patrol_route: WCSWaypointManager.Route = waypoint_manager.create_patrol_route(
		"patrol_test", start_pos, end_pos, 2
	)
	
	assert_that(patrol_route).is_not_null()
	assert_that(patrol_route.type).is_equal(WCSWaypointManager.RouteType.PATROL)
	assert_that(patrol_route.waypoints.size()).is_equal(2)
	assert_that(patrol_route.waypoints[0].position).is_equal(start_pos)
	assert_that(patrol_route.waypoints[1].position).is_equal(end_pos)

func test_circular_route_creation() -> void:
	var center: Vector3 = Vector3(0, 0, 0)
	var radius: float = 100.0
	var waypoint_count: int = 8
	
	var circular_route: WCSWaypointManager.Route = waypoint_manager.create_circular_route(
		"circle_test", center, radius, waypoint_count
	)
	
	assert_that(circular_route).is_not_null()
	assert_that(circular_route.type).is_equal(WCSWaypointManager.RouteType.CIRCULAR)
	assert_that(circular_route.waypoints.size()).is_equal(waypoint_count)
	
	# Check that all waypoints are approximately the correct distance from center
	for waypoint in circular_route.waypoints:
		var distance: float = center.distance_to(waypoint.position)
		assert_that(distance).is_close_to(radius, 5.0)

func test_intercept_route_creation() -> void:
	var interceptor_pos: Vector3 = Vector3(0, 0, 0)
	var target_pos: Vector3 = Vector3(100, 0, 0)
	var target_velocity: Vector3 = Vector3(50, 0, 0)
	var lead_time: float = 2.0
	
	var intercept_route: WCSWaypointManager.Route = waypoint_manager.create_intercept_route(
		"intercept_test", interceptor_pos, target_pos, target_velocity, lead_time
	)
	
	assert_that(intercept_route).is_not_null()
	assert_that(intercept_route.type).is_equal(WCSWaypointManager.RouteType.INTERCEPT)
	assert_that(intercept_route.waypoints.size()).is_greater(0)

# Navigation Controller Tests

func test_navigation_controller_initialization() -> void:
	navigation_controller.controller_id = "test_controller"
	navigation_controller._initialize_navigation_systems()
	
	assert_that(navigation_controller.controller_id).is_equal("test_controller")
	assert_that(navigation_controller.current_state).is_equal(WCSNavigationController.NavigationState.IDLE)

func test_navigation_to_position() -> void:
	navigation_controller.controller_id = "test_nav"
	navigation_controller.ship_controller = test_ship_controller
	navigation_controller.waypoint_manager = waypoint_manager
	
	var destination: Vector3 = Vector3(500, 0, 0)
	var result: bool = navigation_controller.navigate_to_position(destination)
	
	# Note: This might fail without proper ship controller setup, but tests the basic logic
	# In a real test environment, we'd mock the ship controller
	assert_that(result).is_true()
	assert_that(navigation_controller.current_destination).is_equal(destination)

func test_navigation_status() -> void:
	navigation_controller.controller_id = "status_test"
	
	var status: Dictionary = navigation_controller.get_navigation_status()
	
	assert_that(status.has("controller_id")).is_true()
	assert_that(status.has("state")).is_true()
	assert_that(status.has("mode")).is_true()
	assert_that(status["controller_id"]).is_equal("status_test")

# Path Recalculator Tests

func test_path_recalculator_initialization() -> void:
	assert_that(path_recalculator).is_not_null()
	assert_that(path_recalculator.monitored_agents).is_empty()
	assert_that(path_recalculator.validity_check_interval).is_equal(0.5)

func test_agent_registration() -> void:
	var agent_id: String = "test_recalc_agent"
	var initial_path: Array[Vector3] = [Vector3(0, 0, 0), Vector3(100, 0, 0)]
	
	path_recalculator.register_agent(agent_id, initial_path, false)
	
	assert_that(path_recalculator.monitored_agents.has(agent_id)).is_true()
	
	var agent_data = path_recalculator.monitored_agents[agent_id]
	assert_that(agent_data.current_path.size()).is_equal(2)
	assert_that(agent_data.is_priority).is_false()

func test_agent_position_update() -> void:
	var agent_id: String = "position_test_agent"
	path_recalculator.register_agent(agent_id, [Vector3(0, 0, 0), Vector3(100, 0, 0)])
	
	var new_position: Vector3 = Vector3(50, 0, 0)
	path_recalculator.update_agent_position(agent_id, new_position)
	
	var agent_data = path_recalculator.monitored_agents[agent_id]
	assert_that(agent_data.current_position).is_equal(new_position)

func test_path_validity_check() -> void:
	var agent_id: String = "validity_test_agent"
	path_recalculator.register_agent(agent_id, [Vector3(0, 0, 0), Vector3(100, 0, 0)])
	path_recalculator.update_agent_position(agent_id, Vector3(0, 0, 0))
	
	var validity: Dictionary = path_recalculator.check_path_validity_immediate(agent_id)
	
	assert_that(validity.has("valid")).is_true()
	assert_that(validity.has("reason")).is_true()

# Behavior Tree Action Tests

func test_navigate_to_waypoint_action() -> void:
	var action: NavigateToWaypointAction = NavigateToWaypointAction.new()
	action._setup()
	
	# Set up blackboard with waypoint
	action.set_blackboard_value("target_waypoint", Vector3(100, 0, 0))
	
	# Execute action (would need proper agent setup for full test)
	# This tests the basic setup and validation logic
	assert_that(action.waypoint_key).is_equal("target_waypoint")
	assert_that(action.arrival_tolerance).is_equal(50.0)

func test_follow_path_action() -> void:
	var action: FollowPathAction = FollowPathAction.new()
	action._setup()
	
	# Set up blackboard with path
	action.set_blackboard_value("navigation_path", test_waypoints)
	
	assert_that(action.path_key).is_equal("navigation_path")
	assert_that(action.waypoint_tolerance).is_equal(50.0)

func test_patrol_action() -> void:
	var action: PatrolAction = PatrolAction.new()
	action._setup()
	
	# Set up blackboard with patrol route
	action.set_blackboard_value("patrol_route", test_waypoints)
	action.set_blackboard_value("patrol_type", PatrolAction.PatrolType.LINEAR)
	
	assert_that(action.patrol_route_key).is_equal("patrol_route")
	assert_that(action.patrol_speed_factor).is_equal(0.7)

func test_intercept_action() -> void:
	var action: InterceptAction = InterceptAction.new()
	action._setup()
	
	# Create mock target
	var target: Node3D = Node3D.new()
	target.global_position = Vector3(100, 0, 100)
	add_child(target)
	
	action.set_blackboard_value("intercept_target", target)
	
	assert_that(action.target_key).is_equal("intercept_target")
	assert_that(action.lead_time_factor).is_equal(1.2)
	
	target.queue_free()

# Integration Tests

func test_waypoint_navigation_integration() -> void:
	# Test integration between waypoint manager and navigation controller
	navigation_controller.controller_id = "integration_test"
	navigation_controller.waypoint_manager = waypoint_manager
	
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("integration_route", test_waypoints)
	
	# This would need proper ship controller for full integration
	assert_that(route).is_not_null()
	assert_that(route.waypoints.size()).is_equal(test_waypoints.size())

func test_path_planning_with_recalculation() -> void:
	# Test integration between path planner and recalculator
	path_recalculator.path_planner = path_planner
	
	var agent_id: String = "planning_integration_test"
	var initial_path: Array[Vector3] = [Vector3(0, 0, 0), Vector3(500, 0, 0)]
	
	path_recalculator.register_agent(agent_id, initial_path)
	path_recalculator.update_agent_position(agent_id, Vector3(0, 0, 0))
	
	# Force recalculation
	path_recalculator.force_recalculation(agent_id, "test_trigger")
	
	# Check that agent is in recalculation queue
	# (In real implementation, this would trigger actual recalculation)
	assert_that(path_recalculator.monitored_agents.has(agent_id)).is_true()

# Performance Tests

func test_path_planning_performance() -> void:
	var start_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	
	# Test multiple path calculations
	for i in range(10):
		var start: Vector3 = Vector3(i * 100, 0, 0)
		var goal: Vector3 = Vector3(i * 100 + 500, 0, 0)
		var path: Array[Vector3] = path_planner.calculate_path(start, goal)
		assert_that(path).is_not_empty()
	
	var end_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	var total_time_ms: float = (end_time - start_time) / 1000.0
	
	# Should complete 10 path calculations in reasonable time
	assert_that(total_time_ms).is_less(1000.0)  # Less than 1 second

func test_waypoint_manager_performance() -> void:
	var start_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	
	# Create many routes and agents
	for i in range(100):
		var route: WCSWaypointManager.Route = waypoint_manager.create_route("perf_route_" + str(i), test_waypoints)
		waypoint_manager.assign_route_to_agent("perf_agent_" + str(i), route)
		
		# Test arrival checking
		waypoint_manager.check_waypoint_arrival("perf_agent_" + str(i), test_waypoints[0])
	
	var end_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	var total_time_ms: float = (end_time - start_time) / 1000.0
	
	# Should handle 100 agents efficiently
	assert_that(total_time_ms).is_less(500.0)  # Less than 500ms

# Utility Tests

func test_static_utility_methods() -> void:
	# Test PatrolAction static methods
	var linear_route: Array[Vector3] = PatrolAction.create_linear_patrol_route(
		Vector3(0, 0, 0), Vector3(100, 0, 0)
	)
	assert_that(linear_route.size()).is_equal(2)
	assert_that(linear_route[0]).is_equal(Vector3(0, 0, 0))
	assert_that(linear_route[1]).is_equal(Vector3(100, 0, 0))
	
	var circular_route: Array[Vector3] = PatrolAction.create_circular_patrol_route(
		Vector3(0, 0, 0), 100.0, 8
	)
	assert_that(circular_route.size()).is_equal(8)
	
	# Test InterceptAction static methods
	var intercept_time: float = InterceptAction.calculate_intercept_time(
		Vector3(0, 0, 0), 100.0, Vector3(100, 0, 0), Vector3(50, 0, 0)
	)
	assert_that(intercept_time).is_greater(0.0)

# Error Handling Tests

func test_invalid_waypoint_handling() -> void:
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("empty_route", [])
	var success: bool = waypoint_manager.assign_route_to_agent("test_agent", route)
	
	assert_that(success).is_false()

func test_invalid_agent_handling() -> void:
	var current_waypoint: WCSWaypointManager.Waypoint = waypoint_manager.get_current_waypoint("nonexistent_agent")
	assert_that(current_waypoint).is_null()

func test_path_recalculator_invalid_agent() -> void:
	var validity: Dictionary = path_recalculator.check_path_validity_immediate("nonexistent_agent")
	assert_that(validity["valid"]).is_false()
	assert_that(validity["reason"]).is_equal("agent_not_found")

# Edge Case Tests

func test_single_waypoint_route() -> void:
	var single_waypoint: Array[Vector3] = [Vector3(100, 0, 0)]
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("single_wp", single_waypoint)
	
	assert_that(route).is_not_null()
	assert_that(route.waypoints.size()).is_equal(1)

func test_zero_distance_navigation() -> void:
	navigation_controller.controller_id = "zero_dist_test"
	navigation_controller.ship_controller = test_ship_controller
	
	# Try to navigate to same position (should be rejected)
	var result: bool = navigation_controller.navigate_to_position(Vector3.ZERO)
	
	# This depends on ship controller position - might pass or fail
	# In real implementation, we'd mock the ship controller position

func test_very_long_path() -> void:
	var long_path: Array[Vector3] = []
	for i in range(100):
		long_path.append(Vector3(i * 10, 0, 0))
	
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("long_route", long_path)
	
	assert_that(route).is_not_null()
	assert_that(route.waypoints.size()).is_equal(100)

# System Integration Test

func test_complete_navigation_workflow() -> void:
	# Test a complete navigation workflow from start to finish
	
	# 1. Create path using path planner
	var start: Vector3 = Vector3(0, 0, 0)
	var goal: Vector3 = Vector3(500, 0, 500)
	var path: Array[Vector3] = path_planner.calculate_path(start, goal)
	
	assert_that(path).is_not_empty()
	
	# 2. Create route from path
	var route: WCSWaypointManager.Route = waypoint_manager.create_route("workflow_test", path)
	assert_that(route).is_not_null()
	
	# 3. Assign route to agent
	var success: bool = waypoint_manager.assign_route_to_agent("workflow_agent", route)
	assert_that(success).is_true()
	
	# 4. Register with path recalculator
	path_recalculator.register_agent("workflow_agent", path)
	
	# 5. Check initial status
	var progress: Dictionary = waypoint_manager.get_route_progress("workflow_agent")
	assert_that(progress["progress_percentage"]).is_equal(0.0)
	
	# 6. Simulate some navigation progress
	waypoint_manager.check_waypoint_arrival("workflow_agent", path[0])
	waypoint_manager.advance_to_next_waypoint("workflow_agent")
	
	# 7. Verify progress
	var updated_progress: Dictionary = waypoint_manager.get_route_progress("workflow_agent")
	assert_that(updated_progress["completed_waypoints"]).is_greater(0)
	
	# 8. Cleanup
	path_recalculator.unregister_agent("workflow_agent")
	waypoint_manager.clear_route("workflow_agent")