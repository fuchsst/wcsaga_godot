# MissionManager - Central Mission Lifecycle Controller
# Autoload singleton for managing mission loading, spawning, and state
# Coordinates with GameStateMachine for mission flow
# Access via MissionManager autoload name (registered in project.godot)

extends Node

# === SIGNALS ===
signal mission_loaded(manifest: MissionManifest)
signal mission_started
signal mission_ended(success: bool)
signal mission_failed(reason: String)
signal entity_spawned(entity: Node, mission_object: MissionObject)
signal entity_destroyed(entity: Node, mission_object: MissionObject)
signal goal_updated(goal: MissionGoal, new_status: int)
signal event_triggered(event: MissionEvent)

# === CONSTANTS ===
# Preloads removed to avoid shadowing global class_names
# const MissionManifest = preload("res://scripts/resources/missions/mission_manifest.gd")
# const MissionObject = preload("res://scripts/resources/missions/mission_object.gd")
# const MissionGoal = preload("res://scripts/resources/missions/mission_goal.gd")
# const MissionEvent = preload("res://scripts/resources/missions/mission_event.gd")
# const MissionWing = preload("res://scripts/resources/missions/mission_wing.gd")

# === STATE ===
## Currently loaded mission manifest
var current_mission: MissionManifest = null

## Mission runtime state
var mission_time: float = 0.0
var mission_active: bool = false

## Entity registry: object_name -> spawned Node
var entity_registry: Dictionary = {}

## Wing registry: wing_name -> Array[Node]
var wing_registry: Dictionary = {}

## Mission variables (from SEXP set-variable)
var mission_variables: Dictionary = {}

## Goal status tracking: goal_name -> status (0=incomplete, 1=complete, 2=failed)
var goal_status: Dictionary = {}

## Event tracking: event_name -> times_fired
var event_fire_count: Dictionary = {}

## Logic Execution
var bt_player: BTPlayer = null

# === LIFECYCLE ===


func _ready() -> void:
	add_to_group("mission_manager")
	
	# Setup logic player
	bt_player = BTPlayer.new()
	bt_player.name = "MissionLogicPlayer"
	bt_player.active = false
	add_child(bt_player)


func _process(delta: float) -> void:
	if mission_active:
		mission_time += delta


# === PUBLIC API ===


func load_mission(mission_path: String) -> bool:
	"""Load a mission manifest from path"""
	var manifest = load(mission_path) as MissionManifest
	if not manifest:
		push_error("MissionManager: Failed to load mission from: " + mission_path)
		return false

	current_mission = manifest
	_reset_mission_state()
	
	# Load logic tree if present
	if current_mission.mission_logic:
		bt_player.behavior_tree = current_mission.mission_logic
		bt_player.agent = self # Manager is the agent
	else:
		bt_player.behavior_tree = null

	mission_loaded.emit(manifest)
	print("MissionManager: Loaded mission - " + manifest.mission_title)
	return true


func start_mission() -> void:
	"""Start the loaded mission - spawn initial entities"""
	if not current_mission:
		push_error("MissionManager: No mission loaded")
		return

	mission_active = true
	mission_time = 0.0

	# Spawn ships that arrive at mission start
	_spawn_initial_entities()

	# Initialize goals
	_initialize_goals()

	# Initialize mission variables
	_initialize_variables()
	
	# Start Logic
	if bt_player.behavior_tree:
		bt_player.active = true
		print("MissionManager: Started Mission Logic Tree")
	else:
		print("MissionManager: No logic tree for this mission")

	mission_started.emit()
	print("MissionManager: Mission started - " + current_mission.mission_title)


func end_mission(success: bool) -> void:
	"""End the current mission"""
	mission_active = false
	if bt_player:
		bt_player.active = false
	mission_ended.emit(success)
	print("MissionManager: Mission ended - Success: " + str(success))


func unload_mission() -> void:
	"""Unload current mission and clean up"""
	mission_active = false
	if bt_player:
		bt_player.active = false
		bt_player.behavior_tree = null

	# Despawn all entities
	for entity_name in entity_registry.keys():
		var entity = entity_registry[entity_name]
		if is_instance_valid(entity):
			entity.queue_free()

	entity_registry.clear()
	wing_registry.clear()
	goal_status.clear()
	event_fire_count.clear()
	mission_variables.clear()
	current_mission = null


# === ENTITY MANAGEMENT ===


func get_entity(object_name: String) -> Node:
	"""Get spawned entity by mission object name"""
	return entity_registry.get(object_name, null)


func get_wing_entities(wing_name: String) -> Array:
	"""Get all spawned entities in a wing"""
	return wing_registry.get(wing_name, [])


func is_entity_destroyed(object_name: String) -> bool:
	"""Check if entity was destroyed (existed but no longer valid)"""
	if not entity_registry.has(object_name):
		return false # Never spawned
	var entity = entity_registry[object_name]
	return (
		not is_instance_valid(entity) or (entity.has_method("is_alive") and not entity.is_alive())
	)


func is_entity_arrived(object_name: String) -> bool:
	"""Check if entity has arrived (spawned)"""
	return entity_registry.has(object_name) and is_instance_valid(entity_registry[object_name])


func spawn_entity(mission_object: MissionObject) -> Node:
	"""Spawn a single entity from mission object data"""
	if not mission_object.ship:
		push_warning(
			"MissionManager: MissionObject has no ship reference: " + mission_object.object_name
		)
		return null

	# Find the ship scene to instantiate
	var ship_scene_path = _find_ship_scene(mission_object.ship)
	if ship_scene_path.is_empty():
		push_error(
			"MissionManager: Could not find scene for ship: " + mission_object.ship.ship_class
		)
		return null

	var ship_scene = load(ship_scene_path)
	if not ship_scene:
		push_error("MissionManager: Failed to load ship scene: " + ship_scene_path)
		return null

	var entity = ship_scene.instantiate()

	# Configure entity from mission object
	entity.name = mission_object.object_name
	entity.global_position = mission_object.position
	entity.global_transform.basis = mission_object.orientation

	if entity.has_method("set") and "ship_name" in entity:
		entity.ship_name = (
			mission_object.callsign
			if not mission_object.callsign.is_empty()
			else mission_object.object_name
		)

	if "team" in entity:
		entity.team = mission_object.team

	if "stats" in entity and mission_object.ship:
		entity.stats = mission_object.ship

	# Apply initial hull/shields
	if mission_object.initial_hull < 100 and entity.has_method("set") and "current_hull" in entity:
		var max_hull: float = float(mission_object.ship.hull_hitpoints) if mission_object.ship else 100.0
		entity.current_hull = max_hull * mission_object.initial_hull / 100.0

	# Add to scene tree
	get_tree().current_scene.add_child(entity)

	# Register
	entity_registry[mission_object.object_name] = entity

	# Connect destruction signal if available
	if entity.has_signal("ship_destroyed"):
		entity.ship_destroyed.connect(_on_entity_destroyed.bind(mission_object))

	entity_spawned.emit(entity, mission_object)
	return entity


# === GOAL MANAGEMENT ===


func set_goal_status(goal_name: String, status: int) -> void:
	"""Update goal status: 0=incomplete, 1=complete, 2=failed"""
	goal_status[goal_name] = status

	# Find the goal resource
	if current_mission:
		for goal in current_mission.goals:
			if goal.goal_name == goal_name:
				goal_updated.emit(goal, status)
				break

	_check_mission_end_conditions()


func get_goal_status(goal_name: String) -> int:
	"""Get goal status by name"""
	return goal_status.get(goal_name, 0)


# === VARIABLE MANAGEMENT ===


func set_variable(var_name: String, value: Variant) -> void:
	"""Set mission variable value"""
	mission_variables[var_name] = value


func get_variable(var_name: String, default: Variant = null) -> Variant:
	"""Get mission variable value"""
	return mission_variables.get(var_name, default)


# === EVENT MANAGEMENT ===


func record_event_fired(event_name: String) -> void:
	"""Record that an event has fired"""
	event_fire_count[event_name] = event_fire_count.get(event_name, 0) + 1


func get_event_fire_count(event_name: String) -> int:
	"""Get number of times an event has fired"""
	return event_fire_count.get(event_name, 0)


# === PRIVATE HELPERS ===


func _reset_mission_state() -> void:
	entity_registry.clear()
	wing_registry.clear()
	goal_status.clear()
	event_fire_count.clear()
	mission_variables.clear()
	mission_time = 0.0


func _spawn_initial_entities() -> void:
	"""Spawn entities that arrive at mission start"""
	if not current_mission:
		return

	for obj in current_mission.objects:
		# Check if arrival cue is "true" or has no condition (immediate spawn)
		var should_spawn = (
			obj.arrival_cue.is_empty() or obj.arrival_cue == "( true )" or obj.arrival_cue == "true"
		)
		if should_spawn:
			spawn_entity(obj)


func _initialize_goals() -> void:
	"""Initialize goal tracking"""
	if not current_mission:
		return

	for goal in current_mission.goals:
		goal_status[goal.goal_name] = 0 # Incomplete


func _initialize_variables() -> void:
	"""Initialize mission variables from manifest"""
	if not current_mission:
		return

	for sexp_var in current_mission.sexp_variables:
		mission_variables[sexp_var.var_name] = sexp_var.value


func _find_ship_scene(ship_stats: Resource) -> String:
	"""Find the .tscn scene file for a ship"""
	if not ship_stats or not "ship_class" in ship_stats:
		return ""

	var ship_class = ship_stats.ship_class.to_lower().replace(" ", "_")

	# Check common locations
	var search_paths = [
		# Try generator structure (Type/Race/Class)
		"res://assets/ships/fighter/terran/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/bomber/terran/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/capital/terran/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/fighter/kilrathi/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/bomber/kilrathi/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/capital/kilrathi/" + ship_class + "/" + ship_class + ".tscn",
		
		# Try legacy structure (Race/Type/Class)
		"res://assets/ships/terran/fighter/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/terran/bomber/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/terran/capital/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/kilrathi/fighter/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/kilrathi/bomber/" + ship_class + "/" + ship_class + ".tscn",
		"res://assets/ships/kilrathi/capital/" + ship_class + "/" + ship_class + ".tscn",
	]

	for path in search_paths:
		if ResourceLoader.exists(path):
			return path

	return "res://scenes/entities/ship/ship_base.tscn"


func _on_entity_destroyed(entity: Node, mission_object: MissionObject) -> void:
	"""Handle entity destruction"""
	entity_destroyed.emit(entity, mission_object)


func _check_mission_end_conditions() -> void:
	"""Check if mission should end based on goal status"""
	if not current_mission or not mission_active:
		return

	var all_primary_complete = true
	var any_primary_failed = false

	for goal in current_mission.goals:
		if goal.goal_type == 0: # Primary goal
			var status = goal_status.get(goal.goal_name, 0)
			if status == 0:
				all_primary_complete = false
			elif status == 2:
				any_primary_failed = true

	if any_primary_failed:
		end_mission(false)
	elif all_primary_complete:
		end_mission(true)
