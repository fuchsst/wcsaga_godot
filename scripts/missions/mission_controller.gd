class_name MissionController
extends Node3D

## Generic Mission Controller - EPIC-003 DM-007 Implementation
##
## Data-driven mission controller that loads mission configuration from
## Godot Resources and manages mission flow, objectives, and events.
## Follows EPIC-001/002 resource-based architecture principles.

signal mission_started()
signal mission_completed()
signal mission_failed()
signal objective_completed(objective_name: String)
signal objective_failed(objective_name: String)
signal event_triggered(event_name: String)

@export var mission_resource_path: String = ""
@export var auto_start_mission: bool = true
@export var debug_mode: bool = false

# Mission Data
var mission_data: MissionData
var ship_instances: Array[ShipInstanceData] = []
var wing_data: Array[WingInstanceData] = []
var mission_events: Array[MissionEventData] = []
var waypoint_lists: Array[WaypointListData] = []

# Mission State
var mission_time: float = 0.0
var mission_started: bool = false
var mission_completed: bool = false
var mission_result: String = ""

# Runtime Data
var active_ships: Dictionary = {}  # ship_name -> Node3D
var active_wings: Dictionary = {}  # wing_name -> Array[Node3D]
var objective_states: Dictionary = {}  # objective_name -> Dictionary
var event_states: Dictionary = {}  # event_name -> MissionEventData

# Container References
@onready var ships_container: Node3D = $Ships
@onready var wings_container: Node3D = $Wings
@onready var waypoints_container: Node3D = $Waypoints

func _ready() -> void:
	if mission_resource_path.is_empty():
		push_error("Mission resource path not set")
		return
	
	_load_mission_data()
	_setup_mission_containers()
	_initialize_mission_state()
	
	if auto_start_mission:
		call_deferred("start_mission")

func _load_mission_data() -> void:
	"""Load mission data from resource file."""
	mission_data = load(mission_resource_path) as MissionData
	if not mission_data:
		push_error("Failed to load mission data: " + mission_resource_path)
		return
	
	# Load sub-resources directly from mission data arrays
	ship_instances = mission_data.ships
	wing_data = mission_data.wings
	mission_events = mission_data.events
	waypoint_lists = mission_data.waypoint_lists
	
	if debug_mode:
		print("Loaded mission: ", mission_data.mission_title)
		print("Ships: ", ship_instances.size())
		print("Wings: ", wing_data.size())
		print("Events: ", mission_events.size())
		print("Waypoints: ", waypoint_lists.size())

func _setup_mission_containers() -> void:
	"""Initialize container nodes."""
	if not ships_container:
		ships_container = Node3D.new()
		ships_container.name = "Ships"
		add_child(ships_container)
	
	if not wings_container:
		wings_container = Node3D.new()
		wings_container.name = "Wings"
		add_child(wings_container)
	
	if not waypoints_container:
		waypoints_container = Node3D.new()
		waypoints_container.name = "Waypoints"
		add_child(waypoints_container)

func _initialize_mission_state() -> void:
	"""Initialize mission state from data."""
	# Initialize objectives from goals array
	for goal in mission_data.goals:
		var goal_data = goal as MissionObjectiveData
		if goal_data:
			objective_states[goal_data.goal_name] = {
				"type": "primary",  # Default to primary, would need proper type detection
				"name": goal_data.goal_name,
				"message": goal_data.goal_text,
				"completed": false,
				"failed": false
			}
	
	# Initialize events
	for event in mission_events:
		event_states[event.event_name] = event
		event.reset()  # Reset to initial state

func start_mission() -> void:
	"""Start the mission."""
	if mission_started:
		return
	
	mission_started = true
	mission_time = 0.0
	
	# Spawn ships
	_spawn_ships()
	
	# Setup wings
	_setup_wings()
	
	# Create waypoints
	_create_waypoints()
	
	# Start mission processing
	set_process(true)
	
	mission_started.emit()
	
	if debug_mode:
		print("Mission started: ", mission_data.mission_title)

func _process(delta: float) -> void:
	if not mission_started or mission_completed:
		return
	
	mission_time += delta
	
	# Process mission events
	_process_mission_events(delta)
	
	# Check objectives
	_check_objectives()
	
	# Update mission state
	_update_mission_state()

func _spawn_ships() -> void:
	"""Spawn all ships from ship instances."""
	for ship_data in ship_instances:
		var ship_node = _create_ship_node(ship_data)
		if ship_node:
			ships_container.add_child(ship_node)
			active_ships[ship_data.ship_name] = ship_node
			
			# Connect ship signals
			_connect_ship_signals(ship_node, ship_data)

func _create_ship_node(ship_data: ShipInstanceData) -> Node3D:
	"""Create ship node from ship instance data."""
	# Load ship model if available
	var ship_node: Node3D
	
	if ResourceLoader.exists(ship_data.model_resource):
		var model_scene = load(ship_data.model_resource)
		if model_scene is PackedScene:
			ship_node = model_scene.instantiate()
		else:
			# If it's a GLB file, create a basic node structure
			ship_node = Node3D.new()
			# TODO: Add model loading for GLB files
	else:
		# Create placeholder ship
		ship_node = _create_placeholder_ship(ship_data)
	
	# Set name and transform
	ship_node.name = ship_data.ship_name
	ship_node.transform = ship_data.get_spawn_transform()
	
	# Set metadata
	ship_node.set_meta("ship_class", ship_data.ship_class)
	ship_node.set_meta("team", ship_data.team)
	ship_node.set_meta("ai_class", ship_data.ai_class)
	ship_node.set_meta("current_hull", ship_data.initial_hull)
	ship_node.set_meta("current_shields", ship_data.initial_shields)
	ship_node.set_meta("cargo", ship_data.cargo)
	ship_node.set_meta("initial_velocity", ship_data.initial_velocity)
	ship_node.set_meta("destroyed", false)
	ship_node.set_meta("departed", false)
	ship_node.set_meta("arrived", true)
	
	# Add to team group
	ship_node.add_to_group("ships")
	ship_node.add_to_group(ship_data.team.to_lower())
	
	return ship_node

func _create_placeholder_ship(ship_data: ShipInstanceData) -> Node3D:
	"""Create a placeholder ship for testing."""
	var ship_node = Node3D.new()
	
	# Add visual placeholder
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2, 1, 4)  # Ship-like proportions
	mesh_instance.mesh = box_mesh
	
	# Add material with team color
	var material = StandardMaterial3D.new()
	material.albedo_color = ship_data.get_team_color()
	mesh_instance.material_override = material
	
	ship_node.add_child(mesh_instance)
	
	return ship_node

func _connect_ship_signals(ship_node: Node3D, ship_data: ShipInstanceData) -> void:
	"""Connect ship signals if available."""
	# Connect common ship signals
	if ship_node.has_signal("destroyed"):
		ship_node.destroyed.connect(_on_ship_destroyed.bind(ship_node))
	if ship_node.has_signal("damaged"):
		ship_node.damaged.connect(_on_ship_damaged.bind(ship_node))
	if ship_node.has_signal("departed"):
		ship_node.departed.connect(_on_ship_departed.bind(ship_node))

func _setup_wings() -> void:
	"""Setup wing formations."""
	for wing in wing_data:
		var wing_ships: Array[Node3D] = []
		
		# Find ships belonging to this wing
		for ship_name in wing.ship_names:
			if ship_name in active_ships:
				var ship_node = active_ships[ship_name]
				ship_node.set_meta("wing", wing.wing_name)
				wing_ships.append(ship_node)
		
		active_wings[wing.wing_name] = wing_ships
		
		if debug_mode:
			print("Setup wing: ", wing.wing_name, " with ", wing_ships.size(), " ships")

func _create_waypoints() -> void:
	"""Create waypoint markers."""
	for waypoint_list in waypoint_lists:
		var list_container = Node3D.new()
		list_container.name = waypoint_list.list_name
		waypoints_container.add_child(list_container)
		
		for i in range(waypoint_list.waypoint_count):
			var waypoint_node = Marker3D.new()
			waypoint_node.name = waypoint_list.get_waypoint_name(i)
			waypoint_node.position = waypoint_list.get_waypoint_position(i)
			waypoint_node.add_to_group("waypoints")
			waypoint_node.add_to_group("list_" + waypoint_list.list_name)
			
			list_container.add_child(waypoint_node)

func _process_mission_events(delta: float) -> void:
	"""Process all mission events."""
	for event_name in event_states.keys():
		var event_data = event_states[event_name] as MissionEventData
		
		if event_data.can_trigger(mission_time):
			# Check event conditions
			if _evaluate_event_conditions(event_data):
				_trigger_event(event_data)

func _evaluate_event_conditions(event_data: MissionEventData) -> bool:
	"""Evaluate event trigger conditions."""
	# For now, implement basic condition checking
	# In full implementation, would parse and evaluate the conditions
	
	for condition in event_data.trigger_conditions:
		if not _evaluate_condition_string(condition):
			return false
	
	return true

func _evaluate_condition_string(condition: String) -> bool:
	"""Evaluate a single condition string."""
	# Simplified condition evaluation
	# In full implementation, would have proper expression parser
	
	if condition.contains("time_elapsed"):
		var time_match = condition.get_slice(">=", 1).strip_edges()
		if time_match.is_valid_float():
			return mission_time >= time_match.to_float()
	
	if condition.contains("is_ship_destroyed"):
		var ship_name = _extract_ship_name_from_condition(condition)
		return is_ship_destroyed(ship_name)
	
	if condition.contains("distance_between"):
		# Would implement distance checking
		return false
	
	# Default to false for unknown conditions
	return false

func _extract_ship_name_from_condition(condition: String) -> String:
	"""Extract ship name from condition string."""
	var start = condition.find('"') + 1
	var end = condition.find('"', start)
	if start > 0 and end > start:
		return condition.substr(start, end - start)
	return ""

func _trigger_event(event_data: MissionEventData) -> void:
	"""Trigger a mission event."""
	event_data.trigger_event(mission_time)
	
	# Execute event actions
	for action in event_data.actions:
		_execute_action(action)
	
	event_triggered.emit(event_data.event_name)
	
	if debug_mode:
		print("Event triggered: ", event_data.event_name)

func _execute_action(action: String) -> void:
	"""Execute an event action."""
	# Simplified action execution
	if action.contains("send_message"):
		var message = _extract_message_from_action(action)
		_show_message(message)
	
	elif action.contains("end_mission"):
		_end_mission_success()
	
	elif action.contains("warp_in_ship"):
		var ship_name = _extract_ship_name_from_action(action)
		_warp_in_ship(ship_name)
	
	elif action.contains("warp_out_ship"):
		var ship_name = _extract_ship_name_from_action(action)
		_warp_out_ship(ship_name)

func _extract_message_from_action(action: String) -> String:
	"""Extract message from action string."""
	# Would implement proper parsing
	return "Mission message"

func _extract_ship_name_from_action(action: String) -> String:
	"""Extract ship name from action string."""
	# Would implement proper parsing
	return ""

func _check_objectives() -> void:
	"""Check objective completion status."""
	for objective_name in objective_states.keys():
		var objective = objective_states[objective_name]
		
		if not objective.completed and not objective.failed:
			if _evaluate_objective_condition(objective):
				_complete_objective(objective_name)

func _evaluate_objective_condition(objective: Dictionary) -> bool:
	"""Evaluate objective completion condition."""
	# Simplified objective checking
	# In full implementation, would evaluate goal formulas
	
	# Example: Check if all enemy ships are destroyed
	var enemy_ships = get_tree().get_nodes_in_group("hostile")
	var living_enemies = 0
	for ship in enemy_ships:
		if not ship.get_meta("destroyed", false):
			living_enemies += 1
	
	# Simple "destroy all enemies" objective
	if objective.type == "primary" and living_enemies == 0:
		return true
	
	return false

func _complete_objective(objective_name: String) -> void:
	"""Mark objective as completed."""
	if objective_name in objective_states:
		objective_states[objective_name].completed = true
		objective_completed.emit(objective_name)
		
		if debug_mode:
			print("Objective completed: ", objective_name)
		
		_check_mission_completion()

func _fail_objective(objective_name: String) -> void:
	"""Mark objective as failed."""
	if objective_name in objective_states:
		objective_states[objective_name].failed = true
		objective_failed.emit(objective_name)
		
		if debug_mode:
			print("Objective failed: ", objective_name)
		
		_check_mission_failure()

func _check_mission_completion() -> void:
	"""Check if mission should be completed."""
	# Check if all primary objectives are complete
	var primary_complete = true
	for objective in objective_states.values():
		if objective.type == "primary" and not objective.completed:
			primary_complete = false
			break
	
	if primary_complete:
		_end_mission_success()

func _check_mission_failure() -> void:
	"""Check if mission should fail."""
	# Check if any primary objective failed
	for objective in objective_states.values():
		if objective.type == "primary" and objective.failed:
			_end_mission_failure()
			return

func _end_mission_success() -> void:
	"""End mission successfully."""
	if mission_completed:
		return
	
	mission_completed = true
	mission_result = "success"
	set_process(false)
	
	mission_completed.emit()
	
	if debug_mode:
		print("Mission completed successfully!")

func _end_mission_failure() -> void:
	"""End mission with failure."""
	if mission_completed:
		return
	
	mission_completed = true
	mission_result = "failure"
	set_process(false)
	
	mission_failed.emit()
	
	if debug_mode:
		print("Mission failed!")

func _update_mission_state() -> void:
	"""Update ongoing mission state."""
	# Update ship states, check for departures, etc.
	pass

# Ship Event Handlers
func _on_ship_destroyed(ship: Node3D) -> void:
	"""Handle ship destruction."""
	ship.set_meta("destroyed", true)
	ship.hide()  # Or play destruction animation
	
	if debug_mode:
		print("Ship destroyed: ", ship.name)
	
	# Update wing status
	var wing_name = ship.get_meta("wing", "")
	if wing_name != "":
		_update_wing_status(wing_name)

func _on_ship_damaged(ship: Node3D, damage: float) -> void:
	"""Handle ship damage."""
	var current_hull = ship.get_meta("current_hull", 100.0)
	current_hull = max(0.0, current_hull - damage)
	ship.set_meta("current_hull", current_hull)
	
	if current_hull <= 0.0:
		_on_ship_destroyed(ship)

func _on_ship_departed(ship: Node3D) -> void:
	"""Handle ship departure."""
	ship.set_meta("departed", true)
	ship.hide()
	
	if debug_mode:
		print("Ship departed: ", ship.name)

func _update_wing_status(wing_name: String) -> void:
	"""Update wing status when ship status changes."""
	if wing_name in active_wings:
		var wing_ships = active_wings[wing_name]
		var active_count = 0
		
		for ship in wing_ships:
			if not ship.get_meta("destroyed", false) and not ship.get_meta("departed", false):
				active_count += 1
		
		if active_count == 0:
			if debug_mode:
				print("Wing eliminated: ", wing_name)

# Utility Functions
func get_ship_by_name(ship_name: String) -> Node3D:
	"""Get ship node by name."""
	return active_ships.get(ship_name, null)

func get_wing_ships(wing_name: String) -> Array[Node3D]:
	"""Get all ships in a wing."""
	return active_wings.get(wing_name, [])

func is_ship_destroyed(ship_name: String) -> bool:
	"""Check if ship is destroyed."""
	var ship = get_ship_by_name(ship_name)
	return ship == null or ship.get_meta("destroyed", false)

func is_ship_departed(ship_name: String) -> bool:
	"""Check if ship has departed."""
	var ship = get_ship_by_name(ship_name)
	return ship == null or ship.get_meta("departed", false)

func get_mission_time() -> float:
	"""Get current mission time."""
	return mission_time

func is_mission_active() -> bool:
	"""Check if mission is currently active."""
	return mission_started and not mission_completed

func get_mission_summary() -> Dictionary:
	"""Get mission status summary."""
	return {
		"name": mission_data.mission_title if mission_data else "Unknown",
		"time": mission_time,
		"started": mission_started,
		"completed": mission_completed,
		"result": mission_result,
		"objectives_completed": _count_completed_objectives(),
		"total_objectives": objective_states.size(),
		"active_ships": active_ships.size(),
		"active_wings": active_wings.size()
	}

func _count_completed_objectives() -> int:
	"""Count completed objectives."""
	var count = 0
	for objective in objective_states.values():
		if objective.completed:
			count += 1
	return count

# Action Functions
func _show_message(message: String) -> void:
	"""Show in-game message."""
	print("MESSAGE: ", message)
	# In full implementation, would show in HUD

func _warp_in_ship(ship_name: String) -> void:
	"""Warp in a ship."""
	var ship = get_ship_by_name(ship_name)
	if ship:
		ship.set_meta("arrived", true)
		ship.show()
		print("Ship warped in: ", ship_name)

func _warp_out_ship(ship_name: String) -> void:
	"""Warp out a ship."""
	var ship = get_ship_by_name(ship_name)
	if ship:
		ship.set_meta("departed", true)
		ship.hide()
		print("Ship warped out: ", ship_name)

# Debug Functions
func debug_print_mission_state() -> void:
	"""Print current mission state for debugging."""
	if not debug_mode:
		return
	
	print("=== Mission State ===")
	print("Time: ", mission_time)
	print("Active Ships: ", active_ships.size())
	print("Active Wings: ", active_wings.size())
	print("Objectives: ", objective_states.size())
	print("Events: ", event_states.size())
	print("===================")