# MissionRunner - Per-Mission Runtime Manager
# Executes mission events, goals, and coordinates AI spawning
# Created by MissionManager when a mission starts

class_name MissionRunner
extends Node

# === REFERENCES ===
var mission: Resource = null  ## MissionManifest
var event_bt_players: Dictionary = {}  ## event_name -> BTPlayer
var goal_bt_players: Dictionary = {}  ## goal_name -> BTPlayer
var arrival_checkers: Dictionary = {}  ## object_name -> BTPlayer for arrival cues
var blackboard: Blackboard = null  ## Shared mission blackboard

# === STATE ===
var mission_time: float = 0.0
var is_running: bool = false


func _get_mission_manager() -> Node:
	"""Get MissionManager autoload safely"""
	return (
		Engine.get_singleton("MissionManager") if Engine.has_singleton("MissionManager") else null
	)


func _ready() -> void:
	blackboard = Blackboard.new()
	_populate_blackboard()


func _process(delta: float) -> void:
	if not is_running:
		return

	mission_time += delta
	blackboard.set_var("mission_time", mission_time)

	# Check pending arrivals
	_check_pending_arrivals()


# === PUBLIC API ===


func initialize(mission_manifest: Resource) -> void:
	"""Initialize runner with mission data"""
	mission = mission_manifest
	_setup_event_runners()
	_setup_goal_runners()
	_setup_arrival_checkers()


func start() -> void:
	"""Begin mission execution"""
	is_running = true
	mission_time = 0.0

	# Start all event BTPlayers
	for event_name in event_bt_players.keys():
		var player = event_bt_players[event_name]
		if player:
			player.update_enabled = true


func pause() -> void:
	"""Pause mission execution"""
	is_running = false

	for event_name in event_bt_players.keys():
		var player = event_bt_players[event_name]
		if player:
			player.update_enabled = false


func stop() -> void:
	"""Stop mission execution"""
	is_running = false

	# Clean up BTPlayers
	for event_name in event_bt_players.keys():
		var player = event_bt_players[event_name]
		if player and is_instance_valid(player):
			player.queue_free()
	event_bt_players.clear()

	for goal_name in goal_bt_players.keys():
		var player = goal_bt_players[goal_name]
		if player and is_instance_valid(player):
			player.queue_free()
	goal_bt_players.clear()

	for obj_name in arrival_checkers.keys():
		var player = arrival_checkers[obj_name]
		if player and is_instance_valid(player):
			player.queue_free()
	arrival_checkers.clear()


# === PRIVATE HELPERS ===


func _populate_blackboard() -> void:
	"""Initialize mission blackboard with context"""
	if not blackboard:
		return

	blackboard.set_var("mission_time", 0.0)
	var mm = _get_mission_manager()
	blackboard.set_var("mission_manager", mm)

	# Mission metadata
	if mission:
		blackboard.set_var(
			"mission_title", mission.mission_title if "mission_title" in mission else ""
		)


func _setup_event_runners() -> void:
	"""Create BTPlayers for each mission event"""
	if not mission or not "events" in mission:
		return

	for event in mission.events:
		if event.behavior_tree:
			var player = BTPlayer.new()
			player.name = "Event_" + event.event_name
			player.behavior_tree = event.behavior_tree
			player.blackboard = blackboard
			player.update_enabled = false  # Start disabled until mission starts
			add_child(player)

			event_bt_players[event.event_name] = player


func _setup_goal_runners() -> void:
	"""Create BTPlayers for each mission goal"""
	if not mission or not "goals" in mission:
		return

	for goal in mission.goals:
		if "behavior_tree" in goal and goal.behavior_tree:
			var player = BTPlayer.new()
			player.name = "Goal_" + goal.goal_name
			player.behavior_tree = goal.behavior_tree
			player.blackboard = blackboard
			player.update_enabled = false
			add_child(player)

			goal_bt_players[goal.goal_name] = player


func _setup_arrival_checkers() -> void:
	"""Create BTPlayers for arrival cue evaluation"""
	if not mission or not "objects" in mission:
		return

	var mm = _get_mission_manager()
	for obj in mission.objects:
		# Skip if already spawned or no cue
		if mm and mm.is_entity_arrived(obj.object_name):
			continue

		if "arrival_cue_bt" in obj and obj.arrival_cue_bt:
			var player = BTPlayer.new()
			player.name = "Arrival_" + obj.object_name
			player.behavior_tree = obj.arrival_cue_bt
			player.blackboard = blackboard
			player.update_enabled = true
			add_child(player)

			arrival_checkers[obj.object_name] = player


func _check_pending_arrivals() -> void:
	"""Check if any pending arrivals should spawn"""
	var mm = _get_mission_manager()
	if not mission or not mm:
		return

	var to_remove: Array[String] = []

	for obj_name in arrival_checkers.keys():
		var player = arrival_checkers[obj_name] as BTPlayer
		if not player or not is_instance_valid(player):
			to_remove.append(obj_name)
			continue

		# Check if the BT returned SUCCESS (condition met)
		# BTPlayer.last_status gives us the result of the last tick
		if player.get_last_status() == BTTask.SUCCESS:
			# Find the mission object and spawn it
			for obj in mission.objects:
				if obj.object_name == obj_name:
					mm.spawn_entity(obj)
					break

			player.queue_free()
			to_remove.append(obj_name)

	for obj_name in to_remove:
		arrival_checkers.erase(obj_name)
