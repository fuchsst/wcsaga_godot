class_name FormationMoveAction
extends WCSBTAction

## Behavior tree action for coordinated formation movement
## Handles movement of entire formations while maintaining formation integrity

@export var movement_speed_factor: float = 1.0
@export var coordination_delay: float = 0.5  # Delay for formation coordination
@export var formation_break_distance: float = 300.0  # Distance at which formation breaks
@export var enable_formation_rerouting: bool = true  # Allow formation path adjustment

var formation_manager: FormationManager
var target_destination: Vector3
var formation_id: String = ""
var movement_start_time: float = 0.0
var is_formation_leader: bool = false
var coordination_complete: bool = false

func _ready() -> void:
	super._ready()
	# Find formation manager
	formation_manager = get_node("/root/AIManager/FormationManager") as FormationManager
	if not formation_manager:
		formation_manager = get_tree().get_first_node_in_group("formation_managers") as FormationManager

func execute_wcs_action(delta: float) -> int:
	if not ai_agent or not ai_agent.ship_controller:
		return BTTask.FAILURE
	
	# Get formation information
	var ship: Node3D = ai_agent.ship_controller.get_physics_body()
	if not ship or not formation_manager:
		return BTTask.FAILURE
	
	formation_id = formation_manager.get_ship_formation_id(ship)
	if formation_id.is_empty():
		return BTTask.FAILURE  # Not in formation
	
	var formation: FormationManager.Formation = formation_manager.get_formation(formation_id)
	if not formation:
		return BTTask.FAILURE
	
	# Check if we're the formation leader
	is_formation_leader = (ship == formation.leader)
	
	# Get target destination from blackboard
	target_destination = ai_agent.blackboard.get_value("formation_destination", Vector3.ZERO)
	if target_destination == Vector3.ZERO:
		return BTTask.FAILURE  # No destination set
	
	# Execute formation movement based on role
	if is_formation_leader:
		return _execute_leader_movement(delta, formation)
	else:
		return _execute_member_movement(delta, formation)

func _execute_leader_movement(delta: float, formation: FormationManager.Formation) -> int:
	## Formation leader coordinates the movement of the entire formation
	
	var ship_pos: Vector3 = ai_agent.ship_controller.get_ship_position()
	var distance_to_destination: float = ship_pos.distance_to(target_destination)
	
	# Check if movement is just starting
	if movement_start_time == 0.0:
		movement_start_time = Time.get_time_from_start()
		_initiate_formation_movement(formation)
	
	# Wait for coordination delay before starting movement
	if Time.get_time_from_start() - movement_start_time < coordination_delay:
		_signal_formation_preparation()
		return BTTask.RUNNING
	
	coordination_complete = true
	
	# Check formation integrity before movement
	var formation_integrity: float = formation.get_formation_integrity()
	if formation_integrity < 0.6:  # Formation is too loose
		_signal_formation_tighten()
		return BTTask.RUNNING
	
	# Execute leader movement
	if distance_to_destination > 50.0:
		_move_formation_to_destination(delta, formation)
		_monitor_formation_during_movement(formation)
		return BTTask.RUNNING
	else:
		# Arrived at destination
		_complete_formation_movement(formation)
		return BTTask.SUCCESS

func _execute_member_movement(delta: float, formation: FormationManager.Formation) -> int:
	## Formation member follows leader and maintains formation
	
	var ship_pos: Vector3 = ai_agent.ship_controller.get_ship_position()
	var leader_pos: Vector3 = formation.leader.global_position
	var distance_to_leader: float = ship_pos.distance_to(leader_pos)
	
	# Check if formation is breaking up
	if distance_to_leader > formation_break_distance:
		_handle_formation_break()
		return BTTask.FAILURE
	
	# Wait for leader coordination signal
	var leader_ready: bool = ai_agent.blackboard.get_value("formation_movement_ready", false)
	if not leader_ready and not coordination_complete:
		_maintain_formation_position()
		return BTTask.RUNNING
	
	# Follow formation movement
	var formation_position: Vector3 = formation_manager.get_ship_formation_position(ai_agent.ship_controller.get_physics_body())
	var distance_to_formation_pos: float = ship_pos.distance_to(formation_position)
	
	if distance_to_formation_pos > 100.0:
		# Too far from formation position during movement
		_catch_up_to_formation(formation_position)
		return BTTask.RUNNING
	else:
		# In formation, follow leader
		_follow_formation_movement(delta, formation)
		
		# Check if destination reached
		var distance_to_destination: float = ship_pos.distance_to(target_destination)
		if distance_to_destination <= 100.0:
			return BTTask.SUCCESS
		else:
			return BTTask.RUNNING

func _initiate_formation_movement(formation: FormationManager.Formation) -> void:
	## Leader initiates formation movement coordination
	
	# Signal all formation members to prepare for movement
	ai_agent.blackboard.set_value("formation_movement_ready", false)
	ai_agent.blackboard.set_value("formation_destination", target_destination)
	
	# Calculate formation route if rerouting is enabled
	if enable_formation_rerouting:
		_calculate_formation_route(formation)
	
	# Store movement parameters
	ai_agent.blackboard.set_value("formation_movement_start_time", movement_start_time)
	ai_agent.blackboard.set_value("formation_movement_speed", movement_speed_factor)

func _signal_formation_preparation() -> void:
	## Signals formation members to prepare for coordinated movement
	ai_agent.blackboard.set_value("formation_preparing_movement", true)

func _signal_formation_tighten() -> void:
	## Signals formation members to tighten up before movement
	ai_agent.blackboard.set_value("formation_tighten_up", true)

func _move_formation_to_destination(delta: float, formation: FormationManager.Formation) -> void:
	## Moves the formation leader toward destination
	
	# Set leader movement
	set_ship_target_position(target_destination)
	
	# Adjust speed based on formation integrity
	var integrity: float = formation.get_formation_integrity()
	var speed_adjustment: float = lerp(0.6, 1.0, integrity)
	var final_speed: float = movement_speed_factor * speed_adjustment * get_skill_modifier()
	
	if ai_agent.ship_controller.has_method("set_throttle"):
		ai_agent.ship_controller.set_throttle(final_speed)
	
	# Signal movement to formation
	ai_agent.blackboard.set_value("formation_movement_ready", true)
	ai_agent.blackboard.set_value("formation_leader_speed", final_speed)

func _monitor_formation_during_movement(formation: FormationManager.Formation) -> void:
	## Monitors formation integrity during movement
	
	var integrity: float = formation.get_formation_integrity()
	ai_agent.blackboard.set_value("formation_integrity", integrity)
	
	# Slow down if formation is struggling
	if integrity < 0.5:
		ai_agent.blackboard.set_value("formation_slow_down", true)
	else:
		ai_agent.blackboard.set_value("formation_slow_down", false)

func _complete_formation_movement(formation: FormationManager.Formation) -> void:
	## Completes formation movement and resets state
	
	movement_start_time = 0.0
	coordination_complete = false
	
	# Clear movement blackboard values
	ai_agent.blackboard.erase_value("formation_movement_ready")
	ai_agent.blackboard.erase_value("formation_preparing_movement")
	ai_agent.blackboard.erase_value("formation_tighten_up")
	ai_agent.blackboard.erase_value("formation_slow_down")
	
	# Signal completion
	ai_agent.blackboard.set_value("formation_movement_complete", true)

func _maintain_formation_position() -> void:
	## Maintains current formation position while waiting for movement
	var ship: Node3D = ai_agent.ship_controller.get_physics_body()
	var formation_position: Vector3 = formation_manager.get_ship_formation_position(ship)
	set_ship_target_position(formation_position)

func _catch_up_to_formation(formation_position: Vector3) -> void:
	## Catches up to formation when fallen behind during movement
	set_ship_target_position(formation_position)
	
	# Increase speed to catch up
	var catch_up_speed: float = movement_speed_factor * 1.3
	if ai_agent.ship_controller.has_method("set_throttle"):
		ai_agent.ship_controller.set_throttle(catch_up_speed)

func _follow_formation_movement(delta: float, formation: FormationManager.Formation) -> void:
	## Follows formation movement while maintaining position
	
	var ship: Node3D = ai_agent.ship_controller.get_physics_body()
	var formation_position: Vector3 = formation_manager.get_ship_formation_position(ship)
	set_ship_target_position(formation_position)
	
	# Match leader's speed with formation adjustments
	var leader_speed: float = ai_agent.blackboard.get_value("formation_leader_speed", movement_speed_factor)
	var slow_down: bool = ai_agent.blackboard.get_value("formation_slow_down", false)
	
	var member_speed: float = leader_speed
	if slow_down:
		member_speed *= 0.8
	
	# Apply skill modifier
	member_speed *= get_skill_modifier()
	
	if ai_agent.ship_controller.has_method("set_throttle"):
		ai_agent.ship_controller.set_throttle(member_speed)

func _handle_formation_break() -> void:
	## Handles formation breakup during movement
	ai_agent.blackboard.set_value("formation_broken", true)
	
	# Attempt to rejoin formation or continue to destination independently
	if target_destination != Vector3.ZERO:
		set_ship_target_position(target_destination)

func _calculate_formation_route(formation: FormationManager.Formation) -> void:
	## Calculates optimal route for formation movement
	
	# Get formation bounds
	var formation_bounds: AABB = _get_formation_bounds(formation)
	
	# Check for obstacles in formation path
	var obstacles: Array = _detect_formation_obstacles(formation_bounds)
	
	if obstacles.size() > 0:
		# Calculate alternative route
		var alternative_route: Array[Vector3] = _calculate_alternative_route(obstacles)
		ai_agent.blackboard.set_value("formation_waypoints", alternative_route)

func _get_formation_bounds(formation: FormationManager.Formation) -> AABB:
	## Calculates the bounding box of the formation
	
	var min_pos: Vector3 = formation.leader.global_position
	var max_pos: Vector3 = formation.leader.global_position
	
	for member in formation.members:
		if is_instance_valid(member):
			var pos: Vector3 = member.global_position
			min_pos = Vector3(min(min_pos.x, pos.x), min(min_pos.y, pos.y), min(min_pos.z, pos.z))
			max_pos = Vector3(max(max_pos.x, pos.x), max(max_pos.y, pos.y), max(max_pos.z, pos.z))
	
	return AABB(min_pos, max_pos - min_pos)

func _detect_formation_obstacles(formation_bounds: AABB) -> Array:
	## Detects obstacles that might interfere with formation movement
	
	var obstacles: Array = []
	var space_state: PhysicsDirectSpaceState3D = ai_agent.get_world_3d().direct_space_state
	
	if space_state:
		# Use formation bounds to detect large obstacles
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = formation_bounds.size * 1.2  # Add safety margin
		query.shape = box_shape
		query.transform = Transform3D(Basis.IDENTITY, formation_bounds.get_center())
		query.collision_mask = 15  # All collision layers
		
		var results: Array[Dictionary] = space_state.intersect_shape(query)
		for result in results:
			if result.has("collider"):
				obstacles.append(result["collider"])
	
	return obstacles

func _calculate_alternative_route(obstacles: Array) -> Array[Vector3]:
	## Calculates alternative route around obstacles
	
	var waypoints: Array[Vector3] = []
	var start_pos: Vector3 = ai_agent.ship_controller.get_ship_position()
	
	# Simple obstacle avoidance - generate waypoints around obstacles
	for obstacle in obstacles:
		if is_instance_valid(obstacle):
			var obstacle_pos: Vector3 = obstacle.global_position
			var avoidance_offset: Vector3 = (start_pos - obstacle_pos).normalized() * 200.0
			waypoints.append(obstacle_pos + avoidance_offset)
	
	# Add final destination
	waypoints.append(target_destination)
	return waypoints

func set_formation_destination(destination: Vector3) -> void:
	## Sets the destination for formation movement
	target_destination = destination
	ai_agent.blackboard.set_value("formation_destination", destination)

func get_formation_movement_status() -> Dictionary:
	## Returns detailed formation movement status
	return {
		"is_leader": is_formation_leader,
		"destination": target_destination,
		"coordination_complete": coordination_complete,
		"movement_start_time": movement_start_time,
		"formation_id": formation_id,
		"distance_to_destination": ai_agent.ship_controller.get_ship_position().distance_to(target_destination)
	}

func cancel_formation_movement() -> void:
	## Cancels ongoing formation movement
	movement_start_time = 0.0
	coordination_complete = false
	target_destination = Vector3.ZERO
	
	# Clear all movement-related blackboard values
	ai_agent.blackboard.erase_value("formation_destination")
	ai_agent.blackboard.erase_value("formation_movement_ready")
	ai_agent.blackboard.erase_value("formation_preparing_movement")
	ai_agent.blackboard.erase_value("formation_tighten_up")
	ai_agent.blackboard.erase_value("formation_slow_down")
	ai_agent.blackboard.erase_value("formation_movement_complete")