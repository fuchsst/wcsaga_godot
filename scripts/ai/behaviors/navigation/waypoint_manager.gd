class_name WCSWaypointManager
extends Node

## Comprehensive waypoint management system for AI navigation
## Handles waypoint creation, sequencing, arrival detection, and route management

signal waypoint_reached(waypoint: Vector3, waypoint_id: String)
signal route_completed(route_id: String)
signal route_progress_updated(route_id: String, progress: float)
signal waypoint_skipped(waypoint: Vector3, reason: String)

# Waypoint types and data structures
enum WaypointType {
	NAVIGATION,     # Standard navigation waypoint
	PATROL,         # Patrol route waypoint
	INTERCEPT,      # Intercept course waypoint  
	FORMATION,      # Formation position waypoint
	MISSION,        # Mission objective waypoint
	AUTOPILOT       # Player autopilot waypoint
}

enum RouteType {
	LINEAR,         # Sequential waypoint following
	CIRCULAR,       # Repeating circular route
	PATROL,         # Back-and-forth patrol
	INTERCEPT,      # Calculated intercept course
	FORMATION       # Formation movement route
}

# Waypoint data structure
class Waypoint:
	var id: String
	var position: Vector3
	var type: WaypointType
	var arrival_tolerance: float = 50.0
	var approach_speed: float = 1.0
	var hold_time: float = 0.0  # Time to hold at waypoint
	var metadata: Dictionary = {}
	
	func _init(waypoint_id: String, pos: Vector3, waypoint_type: WaypointType = WaypointType.NAVIGATION):
		id = waypoint_id
		position = pos
		type = waypoint_type

# Route data structure
class Route:
	var id: String
	var type: RouteType
	var waypoints: Array[Waypoint] = []
	var current_index: int = 0
	var is_active: bool = false
	var loop_count: int = 0
	var max_loops: int = -1  # -1 for infinite
	var created_time: float
	var completion_time: float = -1.0
	
	func _init(route_id: String, route_type: RouteType = RouteType.LINEAR):
		id = route_id
		type = route_type
		created_time = Time.get_time_dict_from_system()["unix"]

# Active route management
var active_routes: Dictionary = {}  # agent_id -> Route
var route_progress: Dictionary = {}  # route_id -> progress data
var waypoint_arrival_times: Dictionary = {}  # waypoint_id -> arrival time

# Route templates and patterns
var route_templates: Dictionary = {}  # template_name -> Route template
var patrol_patterns: Dictionary = {}  # pattern_name -> patrol configuration

# Performance tracking
var navigation_statistics: Dictionary = {}  # Performance metrics
var arrival_accuracy_history: Array[float] = []
var max_history_size: int = 100

func _ready() -> void:
	_initialize_route_templates()
	_initialize_patrol_patterns()

# Public interface for waypoint management

func create_waypoint(waypoint_id: String, position: Vector3, type: WaypointType = WaypointType.NAVIGATION) -> Waypoint:
	"""Create a new waypoint with specified properties"""
	var waypoint: Waypoint = Waypoint.new(waypoint_id, position, type)
	
	# Set default properties based on type
	match type:
		WaypointType.PATROL:
			waypoint.arrival_tolerance = 75.0
			waypoint.hold_time = 1.0
		WaypointType.INTERCEPT:
			waypoint.arrival_tolerance = 100.0
			waypoint.approach_speed = 1.2
		WaypointType.FORMATION:
			waypoint.arrival_tolerance = 30.0
			waypoint.approach_speed = 0.8
		WaypointType.MISSION:
			waypoint.arrival_tolerance = 25.0
			waypoint.hold_time = 2.0
		WaypointType.AUTOPILOT:
			waypoint.arrival_tolerance = 50.0
	
	return waypoint

func create_route(route_id: String, waypoints: Array[Vector3], type: RouteType = RouteType.LINEAR) -> Route:
	"""Create a new route from a list of waypoint positions"""
	var route: Route = Route.new(route_id, type)
	
	for i in range(waypoints.size()):
		var waypoint_id: String = route_id + "_wp_" + str(i)
		var waypoint: Waypoint = create_waypoint(waypoint_id, waypoints[i])
		route.waypoints.append(waypoint)
	
	return route

func create_route_from_waypoints(route_id: String, waypoints: Array[Waypoint], type: RouteType = RouteType.LINEAR) -> Route:
	"""Create a new route from existing waypoint objects"""
	var route: Route = Route.new(route_id, type)
	route.waypoints = waypoints.duplicate()
	return route

func assign_route_to_agent(agent_id: String, route: Route) -> bool:
	"""Assign a route to an AI agent"""
	if not route or route.waypoints.is_empty():
		push_warning("WCSWaypointManager: Cannot assign empty route to agent " + agent_id)
		return false
	
	# Store route for agent
	active_routes[agent_id] = route
	route.is_active = true
	route.current_index = 0
	
	# Initialize progress tracking
	route_progress[route.id] = {
		"agent_id": agent_id,
		"start_time": Time.get_time_dict_from_system()["unix"],
		"waypoints_reached": 0,
		"distance_traveled": 0.0,
		"current_waypoint": route.waypoints[0] if not route.waypoints.is_empty() else null
	}
	
	return true

func get_current_waypoint(agent_id: String) -> Waypoint:
	"""Get current target waypoint for an agent"""
	var route: Route = active_routes.get(agent_id, null)
	if not route or route.waypoints.is_empty():
		return null
	
	if route.current_index >= route.waypoints.size():
		return null
	
	return route.waypoints[route.current_index]

func get_next_waypoint(agent_id: String) -> Waypoint:
	"""Get next waypoint after current for lookahead"""
	var route: Route = active_routes.get(agent_id, null)
	if not route or route.waypoints.is_empty():
		return null
	
	var next_index: int = _calculate_next_waypoint_index(route)
	if next_index < 0 or next_index >= route.waypoints.size():
		return null
	
	return route.waypoints[next_index]

func check_waypoint_arrival(agent_id: String, agent_position: Vector3) -> bool:
	"""Check if agent has arrived at current waypoint"""
	var waypoint: Waypoint = get_current_waypoint(agent_id)
	if not waypoint:
		return false
	
	var distance: float = agent_position.distance_to(waypoint.position)
	var arrived: bool = distance <= waypoint.arrival_tolerance
	
	if arrived:
		_handle_waypoint_arrival(agent_id, waypoint, agent_position)
	
	return arrived

func advance_to_next_waypoint(agent_id: String) -> bool:
	"""Advance agent to next waypoint in route"""
	var route: Route = active_routes.get(agent_id, null)
	if not route:
		return false
	
	var next_index: int = _calculate_next_waypoint_index(route)
	
	if next_index < 0:
		# Route completed
		_handle_route_completion(agent_id, route)
		return false
	
	route.current_index = next_index
	_update_route_progress(route.id)
	
	return true

func skip_current_waypoint(agent_id: String, reason: String = "manual_skip") -> bool:
	"""Skip current waypoint and advance to next"""
	var waypoint: Waypoint = get_current_waypoint(agent_id)
	if not waypoint:
		return false
	
	waypoint_skipped.emit(waypoint.position, reason)
	return advance_to_next_waypoint(agent_id)

func get_route_progress(agent_id: String) -> Dictionary:
	"""Get detailed progress information for agent's route"""
	var route: Route = active_routes.get(agent_id, null)
	if not route:
		return {}
	
	var progress_data: Dictionary = route_progress.get(route.id, {})
	var total_waypoints: int = route.waypoints.size()
	var completed_waypoints: int = route.current_index
	
	var result: Dictionary = {
		"route_id": route.id,
		"route_type": RouteType.keys()[route.type],
		"total_waypoints": total_waypoints,
		"completed_waypoints": completed_waypoints,
		"progress_percentage": float(completed_waypoints) / float(total_waypoints) if total_waypoints > 0 else 0.0,
		"current_waypoint_index": route.current_index,
		"loop_count": route.loop_count,
		"is_completed": route.completion_time > 0,
		"elapsed_time": Time.get_time_dict_from_system()["unix"] - progress_data.get("start_time", 0.0)
	}
	
	# Add current waypoint info
	var current_wp: Waypoint = get_current_waypoint(agent_id)
	if current_wp:
		result["current_waypoint"] = {
			"id": current_wp.id,
			"position": current_wp.position,
			"type": WaypointType.keys()[current_wp.type],
			"arrival_tolerance": current_wp.arrival_tolerance
		}
	
	return result

func get_remaining_waypoints(agent_id: String) -> Array[Waypoint]:
	"""Get all remaining waypoints in agent's route"""
	var route: Route = active_routes.get(agent_id, null)
	if not route or route.waypoints.is_empty():
		return []
	
	var remaining: Array[Waypoint] = []
	for i in range(route.current_index, route.waypoints.size()):
		remaining.append(route.waypoints[i])
	
	return remaining

func get_remaining_path(agent_id: String) -> Array[Vector3]:
	"""Get remaining waypoint positions as path"""
	var remaining_waypoints: Array[Waypoint] = get_remaining_waypoints(agent_id)
	var path: Array[Vector3] = []
	
	for waypoint in remaining_waypoints:
		path.append(waypoint.position)
	
	return path

# Route templates and patterns

func create_patrol_route(route_id: String, start_pos: Vector3, end_pos: Vector3, waypoint_count: int = 2) -> Route:
	"""Create a patrol route between two points"""
	var route: Route = Route.new(route_id, RouteType.PATROL)
	
	if waypoint_count == 2:
		# Simple back-and-forth patrol
		var wp1: Waypoint = create_waypoint(route_id + "_start", start_pos, WaypointType.PATROL)
		var wp2: Waypoint = create_waypoint(route_id + "_end", end_pos, WaypointType.PATROL)
		route.waypoints = [wp1, wp2]
	else:
		# Multi-point patrol with intermediate waypoints
		for i in range(waypoint_count):
			var progress: float = float(i) / float(waypoint_count - 1)
			var position: Vector3 = start_pos.lerp(end_pos, progress)
			var waypoint: Waypoint = create_waypoint(route_id + "_wp_" + str(i), position, WaypointType.PATROL)
			route.waypoints.append(waypoint)
	
	return route

func create_circular_route(route_id: String, center: Vector3, radius: float, waypoint_count: int = 8) -> Route:
	"""Create a circular patrol route"""
	var route: Route = Route.new(route_id, RouteType.CIRCULAR)
	
	for i in range(waypoint_count):
		var angle: float = (float(i) / float(waypoint_count)) * PI * 2.0
		var offset: Vector3 = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var position: Vector3 = center + offset
		
		var waypoint: Waypoint = create_waypoint(route_id + "_circle_" + str(i), position, WaypointType.PATROL)
		route.waypoints.append(waypoint)
	
	return route

func create_intercept_route(route_id: String, interceptor_pos: Vector3, target_pos: Vector3, target_velocity: Vector3, lead_time: float = 2.0) -> Route:
	"""Create intercept course to moving target"""
	var route: Route = Route.new(route_id, RouteType.INTERCEPT)
	
	# Calculate intercept position
	var intercept_pos: Vector3 = target_pos + target_velocity * lead_time
	
	# Create waypoints for smooth intercept
	var midpoint: Vector3 = interceptor_pos.lerp(intercept_pos, 0.5)
	
	var wp1: Waypoint = create_waypoint(route_id + "_approach", midpoint, WaypointType.INTERCEPT)
	var wp2: Waypoint = create_waypoint(route_id + "_intercept", intercept_pos, WaypointType.INTERCEPT)
	
	route.waypoints = [wp1, wp2]
	return route

func create_formation_route(route_id: String, leader_route: Array[Vector3], formation_offset: Vector3) -> Route:
	"""Create formation route following leader with offset"""
	var route: Route = Route.new(route_id, RouteType.FORMATION)
	
	for i in range(leader_route.size()):
		var formation_pos: Vector3 = leader_route[i] + formation_offset
		var waypoint: Waypoint = create_waypoint(route_id + "_form_" + str(i), formation_pos, WaypointType.FORMATION)
		route.waypoints.append(waypoint)
	
	return route

# Route modification and management

func insert_waypoint(agent_id: String, waypoint: Waypoint, index: int = -1) -> bool:
	"""Insert waypoint into agent's current route"""
	var route: Route = active_routes.get(agent_id, null)
	if not route:
		return false
	
	if index < 0 or index > route.waypoints.size():
		index = route.current_index + 1  # Insert after current waypoint
	
	route.waypoints.insert(index, waypoint)
	
	# Adjust current index if needed
	if index <= route.current_index:
		route.current_index += 1
	
	return true

func remove_waypoint(agent_id: String, waypoint_id: String) -> bool:
	"""Remove waypoint from agent's route"""
	var route: Route = active_routes.get(agent_id, null)
	if not route:
		return false
	
	for i in range(route.waypoints.size()):
		if route.waypoints[i].id == waypoint_id:
			route.waypoints.remove_at(i)
			
			# Adjust current index if needed
			if i < route.current_index:
				route.current_index -= 1
			elif i == route.current_index and route.current_index >= route.waypoints.size():
				route.current_index = max(0, route.waypoints.size() - 1)
			
			return true
	
	return false

func modify_waypoint(agent_id: String, waypoint_id: String, new_position: Vector3) -> bool:
	"""Modify waypoint position in agent's route"""
	var route: Route = active_routes.get(agent_id, null)
	if not route:
		return false
	
	for waypoint in route.waypoints:
		if waypoint.id == waypoint_id:
			waypoint.position = new_position
			return true
	
	return false

func clear_route(agent_id: String) -> void:
	"""Clear agent's current route"""
	if active_routes.has(agent_id):
		var route: Route = active_routes[agent_id]
		route.is_active = false
		active_routes.erase(agent_id)
		route_progress.erase(route.id)

# Private implementation methods

func _handle_waypoint_arrival(agent_id: String, waypoint: Waypoint, agent_position: Vector3) -> void:
	"""Handle agent arrival at waypoint"""
	var arrival_time: float = Time.get_time_dict_from_system()["unix"]
	var arrival_accuracy: float = agent_position.distance_to(waypoint.position)
	
	# Store arrival data
	waypoint_arrival_times[waypoint.id] = arrival_time
	arrival_accuracy_history.append(arrival_accuracy)
	if arrival_accuracy_history.size() > max_history_size:
		arrival_accuracy_history.pop_front()
	
	# Update route progress
	var route: Route = active_routes.get(agent_id, null)
	if route:
		var progress_data: Dictionary = route_progress.get(route.id, {})
		progress_data["waypoints_reached"] = progress_data.get("waypoints_reached", 0) + 1
		progress_data["last_arrival_time"] = arrival_time
		progress_data["last_arrival_accuracy"] = arrival_accuracy
	
	# Emit arrival signal
	waypoint_reached.emit(waypoint.position, waypoint.id)
	
	# Auto-advance to next waypoint
	advance_to_next_waypoint(agent_id)

func _handle_route_completion(agent_id: String, route: Route) -> void:
	"""Handle route completion"""
	route.completion_time = Time.get_time_dict_from_system()["unix"]
	
	# Handle different route types
	match route.type:
		RouteType.CIRCULAR:
			if route.max_loops < 0 or route.loop_count < route.max_loops:
				# Restart circular route
				route.current_index = 0
				route.loop_count += 1
				return
		
		RouteType.PATROL:
			if route.max_loops < 0 or route.loop_count < route.max_loops:
				# Reverse patrol direction
				route.waypoints.reverse()
				route.current_index = 0
				route.loop_count += 1
				return
	
	# Route truly completed
	route.is_active = false
	route_completed.emit(route.id)

func _calculate_next_waypoint_index(route: Route) -> int:
	"""Calculate next waypoint index based on route type"""
	match route.type:
		RouteType.LINEAR, RouteType.INTERCEPT, RouteType.FORMATION:
			var next_index: int = route.current_index + 1
			return next_index if next_index < route.waypoints.size() else -1
		
		RouteType.CIRCULAR:
			return (route.current_index + 1) % route.waypoints.size()
		
		RouteType.PATROL:
			var next_index: int = route.current_index + 1
			return next_index if next_index < route.waypoints.size() else -1
	
	return -1

func _update_route_progress(route_id: String) -> void:
	"""Update route progress tracking"""
	var progress_data: Dictionary = route_progress.get(route_id, {})
	if progress_data.is_empty():
		return
	
	var agent_id: String = progress_data.get("agent_id", "")
	var route: Route = active_routes.get(agent_id, null)
	if not route:
		return
	
	var total_waypoints: int = route.waypoints.size()
	var completed_waypoints: int = route.current_index
	var progress: float = float(completed_waypoints) / float(total_waypoints) if total_waypoints > 0 else 0.0
	
	route_progress_updated.emit(route_id, progress)

func _initialize_route_templates() -> void:
	"""Initialize common route templates"""
	# Could be loaded from configuration files
	pass

func _initialize_patrol_patterns() -> void:
	"""Initialize patrol pattern definitions"""
	# Could be loaded from configuration files
	pass

# Statistics and monitoring

func get_navigation_statistics() -> Dictionary:
	"""Get navigation performance statistics"""
	var avg_arrival_accuracy: float = 0.0
	if not arrival_accuracy_history.is_empty():
		avg_arrival_accuracy = arrival_accuracy_history.reduce(func(sum, val): return sum + val, 0.0) / arrival_accuracy_history.size()
	
	return {
		"active_routes": active_routes.size(),
		"total_waypoints_reached": waypoint_arrival_times.size(),
		"average_arrival_accuracy": avg_arrival_accuracy,
		"route_completion_rate": 0.0  # Could calculate based on completed vs started routes
	}