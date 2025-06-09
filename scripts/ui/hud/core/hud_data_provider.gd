class_name HUDDataProvider
extends Node

## EPIC-012 HUD-001: HUD Data Provider System
## Centralized data collection and distribution system for HUD elements
## Provides real-time access to ship systems, game state, and mission information with optimization

signal data_updated(data_type: String, data: Dictionary)
signal data_source_changed(source_name: String, available: bool)
signal data_source_error(source: String, error: String)
signal cache_invalidated(data_type: String)

# Data source references
var ship_manager: Node
var object_manager: Node
var mission_manager: Node
var input_manager: Node
var game_state_manager: Node

# Data caching system
var cached_data: Dictionary = {}
var cache_timestamps: Dictionary = {}
var cache_ttl: Dictionary = {}  # Time-to-live for each data type

# Update intervals for different data types (in seconds)
var update_intervals: Dictionary = {
	"ship_status": 0.016,      # 60 FPS - critical flight data
	"targeting_data": 0.016,   # 60 FPS - combat information
	"weapon_status": 0.033,    # 30 FPS - weapon information
	"radar_contacts": 0.066,   # 15 FPS - radar updates
	"mission_info": 0.5,       # 2 FPS - mission objectives
	"system_status": 0.1,      # 10 FPS - general system info
	"communication": 0.2,      # 5 FPS - messages and comm
	"navigation": 0.033        # 30 FPS - navigation data
}

# Data collection state
var data_sources_available: Dictionary = {}
var last_update_times: Dictionary = {}
var update_timers: Dictionary = {}
var data_subscribers: Dictionary = {}  # data_type -> Array[HUDElementBase]

# Performance tracking
var data_collection_time_ms: float = 0.0
var total_queries_per_frame: int = 0
var max_queries_per_frame: int = 100

func _ready() -> void:
	_initialize_data_provider()

## Initialize data provider system
func _initialize_data_provider() -> void:
	print("HUDDataProvider: Initializing data collection system...")
	
	# Find and connect to data sources
	_connect_to_data_sources()
	
	# Initialize cache system
	_initialize_cache_system()
	
	# Setup update timers
	_setup_update_timers()
	
	# Start data collection
	set_process(true)
	
	print("HUDDataProvider: Data provider initialization complete")

## Connect to available data sources in the game
func _connect_to_data_sources() -> void:
	# Find ship manager for ship status data
	ship_manager = _find_manager("BaseShip")  # Look for ship instances
	_register_data_source("ship_manager", ship_manager != null)
	
	# Find object manager for radar and targeting data
	object_manager = _find_manager("ObjectManager")
	_register_data_source("object_manager", object_manager != null)
	
	# Find mission manager for mission information
	mission_manager = _find_manager("MissionManager")
	_register_data_source("mission_manager", mission_manager != null)
	
	# Find input manager for control information
	input_manager = _find_manager("InputManager")
	_register_data_source("input_manager", input_manager != null)
	
	# Find game state manager
	game_state_manager = _find_manager("GameStateManager")
	_register_data_source("game_state_manager", game_state_manager != null)

## Find manager by class name or node name
func _find_manager(manager_name: String) -> Node:
	# Check autoloads first
	for child in get_tree().root.get_children():
		if child.name == manager_name or (child.get_script() and child.get_script().get_global_name() == manager_name):
			return child
	
	# Search scene tree recursively
	return _recursive_find_manager(get_tree().root, manager_name)

func _recursive_find_manager(node: Node, target_name: String) -> Node:
	if node.name == target_name or (node.get_script() and node.get_script().get_global_name() == target_name):
		return node
	
	for child in node.get_children():
		var result = _recursive_find_manager(child, target_name)
		if result:
			return result
	
	return null

## Register data source availability
func _register_data_source(source_name: String, available: bool) -> void:
	data_sources_available[source_name] = available
	data_source_changed.emit(source_name, available)
	
	if available:
		print("HUDDataProvider: Connected to %s" % source_name)
	else:
		print("HUDDataProvider: %s not available" % source_name)

## Initialize cache system with TTL values
func _initialize_cache_system() -> void:
	# Set cache TTL for different data types
	cache_ttl = {
		"ship_status": 0.1,      # 100ms cache for ship data
		"targeting_data": 0.05,  # 50ms cache for targeting
		"weapon_status": 0.2,    # 200ms cache for weapons
		"radar_contacts": 1.0,   # 1s cache for radar
		"mission_info": 5.0,     # 5s cache for mission data
		"system_status": 1.0,    # 1s cache for system info
		"communication": 2.0,    # 2s cache for messages
		"navigation": 0.2        # 200ms cache for navigation
	}
	
	# Initialize cache structures
	for data_type in update_intervals.keys():
		cached_data[data_type] = {}
		cache_timestamps[data_type] = 0.0
		last_update_times[data_type] = 0.0

## Setup update timers for data collection
func _setup_update_timers() -> void:
	for data_type in update_intervals.keys():
		var timer = Timer.new()
		timer.wait_time = update_intervals[data_type]
		timer.timeout.connect(_on_update_timer_timeout.bind(data_type))
		timer.autostart = true
		add_child(timer)
		update_timers[data_type] = timer

## Main data collection processing
func _process(delta: float) -> void:
	total_queries_per_frame = 0
	var start_time = Time.get_ticks_usec()
	
	# Collect critical real-time data
	_update_critical_data()
	
	# Track performance
	var end_time = Time.get_ticks_usec()
	data_collection_time_ms = (end_time - start_time) / 1000.0

## Update critical real-time data every frame
func _update_critical_data() -> void:
	# Always update ship status and targeting data for responsive HUD
	_collect_ship_status_data()
	_collect_targeting_data()

## Handle timer-based data updates
func _on_update_timer_timeout(data_type: String) -> void:
	if total_queries_per_frame >= max_queries_per_frame:
		return  # Skip update to maintain performance
	
	match data_type:
		"weapon_status":
			_collect_weapon_status_data()
		"radar_contacts":
			_collect_radar_contacts_data()
		"mission_info":
			_collect_mission_info_data()
		"system_status":
			_collect_system_status_data()
		"communication":
			_collect_communication_data()
		"navigation":
			_collect_navigation_data()

## Data collection methods for different types

## Collect ship status data
func _collect_ship_status_data() -> void:
	if not _is_cache_valid("ship_status"):
		var data = _gather_ship_status()
		_update_cache("ship_status", data)
		total_queries_per_frame += 1

func _gather_ship_status() -> Dictionary:
	var data: Dictionary = {}
	
	# Get player ship data
	var player_ship = _get_player_ship()
	if player_ship:
		data = {
			"hull_percentage": player_ship.get_hull_percentage(),
			"shield_percentage": player_ship.get_shield_percentage(),
			"current_speed": player_ship.get_current_speed(),
			"max_speed": player_ship.get_max_speed(),
			"afterburner_fuel": player_ship.get_afterburner_fuel_percentage(),
			"energy_levels": player_ship.get_energy_levels(),
			"ship_flags": player_ship.get_ship_flags(),
			"subsystem_status": player_ship.get_subsystem_status(),
			"position": player_ship.global_position,
			"velocity": player_ship.get_velocity()
		}
	else:
		# Provide default/error data
		data = _get_default_ship_data()
	
	return data

## Collect targeting data
func _collect_targeting_data() -> void:
	if not _is_cache_valid("targeting_data"):
		var data = _gather_targeting_data()
		_update_cache("targeting_data", data)
		total_queries_per_frame += 1

func _gather_targeting_data() -> Dictionary:
	var data: Dictionary = {}
	
	var player_ship = _get_player_ship()
	if player_ship and player_ship.has_method("get_target"):
		var target = player_ship.get_target()
		if target:
			data = {
				"has_target": true,
				"target_name": target.get_ship_name() if target.has_method("get_ship_name") else "Unknown",
				"target_hull": target.get_hull_percentage() if target.has_method("get_hull_percentage") else 0.0,
				"target_shield": target.get_shield_percentage() if target.has_method("get_shield_percentage") else 0.0,
				"target_distance": player_ship.global_position.distance_to(target.global_position),
				"target_position": target.global_position,
				"target_velocity": target.get_velocity() if target.has_method("get_velocity") else Vector3.ZERO,
				"target_type": target.get_ship_type() if target.has_method("get_ship_type") else "unknown",
				"is_hostile": target.is_hostile_to(player_ship) if target.has_method("is_hostile_to") else false
			}
		else:
			data = {"has_target": false}
	else:
		data = {"has_target": false}
	
	return data

## Collect weapon status data
func _collect_weapon_status_data() -> void:
	var data = _gather_weapon_status()
	_update_cache("weapon_status", data)

func _gather_weapon_status() -> Dictionary:
	var data: Dictionary = {}
	
	var player_ship = _get_player_ship()
	if player_ship and player_ship.has_method("get_weapon_status"):
		data = player_ship.get_weapon_status()
	else:
		data = {
			"primary_weapons": [],
			"secondary_weapons": [],
			"weapon_energy": 100.0,
			"selected_primary": 0,
			"selected_secondary": 0
		}
	
	return data

## Collect radar contacts data
func _collect_radar_contacts_data() -> void:
	var data = _gather_radar_contacts()
	_update_cache("radar_contacts", data)

func _gather_radar_contacts() -> Dictionary:
	var data: Dictionary = {"contacts": []}
	
	if object_manager and object_manager.has_method("get_all_objects"):
		var objects = object_manager.get_all_objects()
		var contacts: Array[Dictionary] = []
		
		for obj in objects:
			if obj.has_method("is_radar_visible") and obj.is_radar_visible():
				contacts.append({
					"name": obj.get_name() if obj.has_method("get_name") else "Unknown",
					"position": obj.global_position,
					"type": obj.get_object_type() if obj.has_method("get_object_type") else "unknown",
					"is_hostile": obj.is_hostile() if obj.has_method("is_hostile") else false,
					"distance": obj.global_position.distance_to(_get_player_position())
				})
		
		data["contacts"] = contacts
	
	return data

## Collect mission information data
func _collect_mission_info_data() -> void:
	var data = _gather_mission_info()
	_update_cache("mission_info", data)

func _gather_mission_info() -> Dictionary:
	var data: Dictionary = {}
	
	if mission_manager:
		if mission_manager.has_method("get_mission_time"):
			data["mission_time"] = mission_manager.get_mission_time()
		if mission_manager.has_method("get_objectives"):
			data["objectives"] = mission_manager.get_objectives()
		if mission_manager.has_method("get_mission_status"):
			data["status"] = mission_manager.get_mission_status()
	
	return data

## Collect system status data
func _collect_system_status_data() -> void:
	var data = _gather_system_status()
	_update_cache("system_status", data)

func _gather_system_status() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"memory_usage": OS.get_static_memory_usage(),
		"performance_time_ms": data_collection_time_ms
	}

## Collect communication data
func _collect_communication_data() -> void:
	var data = _gather_communication_data()
	_update_cache("communication", data)

func _gather_communication_data() -> Dictionary:
	var data: Dictionary = {"messages": [], "active_comm": false}
	
	# This would integrate with message system when available
	return data

## Collect navigation data
func _collect_navigation_data() -> void:
	var data = _gather_navigation_data()
	_update_cache("navigation", data)

func _gather_navigation_data() -> Dictionary:
	var data: Dictionary = {}
	
	var player_ship = _get_player_ship()
	if player_ship:
		data = {
			"heading": player_ship.get_heading() if player_ship.has_method("get_heading") else 0.0,
			"altitude": player_ship.global_position.y,
			"waypoints": [],  # Would get from navigation system
			"autopilot_active": false  # Would get from autopilot system
		}
	
	return data

## Cache management

## Check if cached data is still valid
func _is_cache_valid(data_type: String) -> bool:
	if not cached_data.has(data_type):
		return false
	
	var current_time = Time.get_ticks_usec() / 1000000.0
	var cache_age = current_time - cache_timestamps.get(data_type, 0.0)
	var ttl = cache_ttl.get(data_type, 1.0)
	
	return cache_age < ttl

## Update cache with new data
func _update_cache(data_type: String, data: Dictionary) -> void:
	cached_data[data_type] = data
	cache_timestamps[data_type] = Time.get_ticks_usec() / 1000000.0
	last_update_times[data_type] = cache_timestamps[data_type]
	
	# Emit data update signal
	data_updated.emit(data_type, data)

## Invalidate cache for data type
func invalidate_cache(data_type: String) -> void:
	if cached_data.has(data_type):
		cached_data[data_type] = {}
		cache_timestamps[data_type] = 0.0
		cache_invalidated.emit(data_type)

## Public API for HUD elements

## Get cached data for specific type
func get_data(data_type: String) -> Dictionary:
	return cached_data.get(data_type, {})

## Get real-time ship status (always current)
func get_ship_status() -> Dictionary:
	_collect_ship_status_data()
	return get_data("ship_status")

## Get real-time targeting data (always current)
func get_targeting_data() -> Dictionary:
	_collect_targeting_data()
	return get_data("targeting_data")

## Get weapon status
func get_weapon_status() -> Dictionary:
	return get_data("weapon_status")

## Get radar contacts
func get_radar_contacts() -> Array[Dictionary]:
	var data = get_data("radar_contacts")
	return data.get("contacts", [])

## Get mission information
func get_mission_info() -> Dictionary:
	return get_data("mission_info")

## Get system status
func get_system_status() -> Dictionary:
	return get_data("system_status")

## Helper methods

## Get player ship reference
func _get_player_ship() -> Node:
	# Try to find player ship in various ways
	if ship_manager:
		if ship_manager.has_method("get_player_ship"):
			return ship_manager.get_player_ship()
	
	# Look for player ship in scene tree
	var player_ships = get_tree().get_nodes_in_group("player_ships")
	if not player_ships.is_empty():
		return player_ships[0]
	
	return null

## Get player position
func _get_player_position() -> Vector3:
	var player_ship = _get_player_ship()
	return player_ship.global_position if player_ship else Vector3.ZERO

## Get default ship data for when no ship is available
func _get_default_ship_data() -> Dictionary:
	return {
		"hull_percentage": 100.0,
		"shield_percentage": 100.0,
		"current_speed": 0.0,
		"max_speed": 100.0,
		"afterburner_fuel": 100.0,
		"energy_levels": {"shields": 0.33, "weapons": 0.33, "engines": 0.33},
		"ship_flags": 0,
		"subsystem_status": {},
		"position": Vector3.ZERO,
		"velocity": Vector3.ZERO
	}

## Get data provider statistics
func get_statistics() -> Dictionary:
	return {
		"data_sources_available": data_sources_available,
		"cached_data_types": cached_data.keys(),
		"data_collection_time_ms": data_collection_time_ms,
		"queries_per_frame": total_queries_per_frame,
		"cache_hit_rates": _calculate_cache_hit_rates(),
		"update_intervals": update_intervals
	}

## Calculate cache hit rates
func _calculate_cache_hit_rates() -> Dictionary:
	var hit_rates: Dictionary = {}
	# Implementation would track cache hits vs misses
	return hit_rates

## Error handling
func _on_data_collection_error(source: String, error: String) -> void:
	data_source_error.emit(source, error)
	push_warning("HUDDataProvider: Error collecting data from %s: %s" % [source, error])