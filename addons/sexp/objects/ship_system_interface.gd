class_name ShipSystemInterface
extends RefCounted

## Interface between SEXP ship functions and Godot ship/object systems
##
## Provides centralized access to ship status, modification, and reference management
## following WCS patterns for ship identification and manipulation.
## 
## Integrates with WCS Asset Core addon for ship data definitions and follows
## EPIC-002 asset structure patterns for consistent ship reference management.

signal ship_destroyed(ship_name: String, ship_node: Node)
signal ship_departed(ship_name: String, ship_node: Node)
signal ship_subsystem_destroyed(ship_name: String, subsystem_name: String)
signal cache_invalidation_required(dependency: String)

# Import WCS Asset Core types for proper integration
const ShipData = preload("res://addons/wcs_asset_core/structures/ship_data.gd")
const BaseAssetData = preload("res://addons/wcs_asset_core/structures/base_asset_data.gd")
const ObjectReferenceSystem = preload("res://addons/sexp/objects/object_reference_system.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Object reference system for reliable ship tracking
var _object_ref_system: ObjectReferenceSystem

## Ship state tracking
var _ship_destroyed: Dictionary = {}    ## Track destroyed ships
var _ship_departed: Dictionary = {}     ## Track departed ships
var _ship_subsystem_status: Dictionary = {}  ## Track subsystem status

## Ship lookup and reference management
static var _instance: ShipSystemInterface = null

static func get_instance() -> ShipSystemInterface:
	if _instance == null:
		_instance = ShipSystemInterface.new()
	return _instance

func _init():
	if _instance == null:
		_instance = self
	_object_ref_system = ObjectReferenceSystem.get_instance()
	
	# Connect to object reference system signals
	_object_ref_system.object_reference_invalidated.connect(_on_object_invalidated)
	_object_ref_system.object_reference_updated.connect(_on_object_updated)

## Ship identification and lookup functions

func ship_name_lookup(ship_name: String, include_players: bool = false) -> Node:
	"""
	Find ship node by name following WCS lookup patterns
	Returns ship node or null if not found
	"""
	if ship_name.is_empty():
		return null
	
	# Use object reference system for reliable ship lookup
	var ship_node = _object_ref_system.find_object_by_name(ship_name, ObjectReferenceSystem.ReferenceType.SHIP)
	
	# Filter player ships if not included
	if ship_node != null and not include_players and _is_player_ship(ship_node):
		return null
	
	# Fallback to scene tree search if not found in reference system
	if ship_node == null:
		ship_node = _find_ship_in_scene(ship_name, include_players)
		
		# Register found ship in reference system for future lookups
		if ship_node != null:
			register_ship(ship_name, ship_node)
	
	return ship_node

func _find_ship_in_scene(ship_name: String, include_players: bool) -> Node:
	"""Search scene tree for ship with matching name"""
	# Try to find ship manager or mission manager first
	var ship_manager = _get_ship_manager()
	if ship_manager != null:
		return _find_ship_in_manager(ship_manager, ship_name, include_players)
	
	# Fallback: search entire scene tree
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return null
	
	return _recursive_ship_search(scene_tree.current_scene, ship_name, include_players)

func _find_ship_in_manager(manager: Node, ship_name: String, include_players: bool) -> Node:
	"""Search for ship in a ship manager node"""
	for child in manager.get_children():
		if _is_ship_node(child, ship_name, include_players):
			return child
	return null

func _recursive_ship_search(node: Node, ship_name: String, include_players: bool) -> Node:
	"""Recursively search scene tree for ship"""
	if _is_ship_node(node, ship_name, include_players):
		return node
	
	for child in node.get_children():
		var result = _recursive_ship_search(child, ship_name, include_players)
		if result != null:
			return result
	
	return null

func _is_ship_node(node: Node, ship_name: String, include_players: bool) -> bool:
	"""Check if node is a ship with matching name"""
	# Check for ship class or group membership
	if not (node.has_method("get_ship_name") or node.is_in_group("ships")):
		return false
	
	# Get ship name
	var node_ship_name: String = ""
	if node.has_method("get_ship_name"):
		node_ship_name = node.get_ship_name()
	else:
		node_ship_name = node.name
	
	# Case-insensitive comparison following WCS pattern
	if node_ship_name.to_lower() != ship_name.to_lower():
		return false
	
	# Check player flag if needed
	if not include_players and _is_player_ship(node):
		return false
	
	return true

func _is_player_ship(ship_node: Node) -> bool:
	"""Check if ship is a player-controlled ship"""
	if ship_node.has_method("is_player_ship"):
		return ship_node.is_player_ship()
	elif ship_node.is_in_group("player_ships"):
		return true
	elif ship_node.has_meta("is_player"):
		return ship_node.get_meta("is_player")
	return false

## Ship status query functions

func get_ship_hull_percentage(ship_name: String) -> int:
	"""
	Get ship hull health as percentage (0-100)
	Returns SEXP_NAN if ship not found, SEXP_NAN_FOREVER if destroyed/departed
	"""
	# Check if ship is destroyed or departed
	if _ship_destroyed.has(ship_name):
		return SexpResult.SEXP_NAN_FOREVER
	if _ship_departed.has(ship_name):
		return SexpResult.SEXP_NAN_FOREVER
	
	var ship_node = ship_name_lookup(ship_name, true)
	if ship_node == null:
		return SexpResult.SEXP_NAN
	
	# Get hull health
	var hull_pct: float = 1.0
	if ship_node.has_method("get_hull_percentage"):
		hull_pct = ship_node.get_hull_percentage()
	elif ship_node.has_method("get_health_percentage"):
		hull_pct = ship_node.get_health_percentage()
	elif ship_node.has_property("health") and ship_node.has_property("max_health"):
		var health = ship_node.get("health") as float
		var max_health = ship_node.get("max_health") as float
		if max_health > 0.0:
			hull_pct = health / max_health
	
	return int((hull_pct * 100.0) + 0.5)  # Round to nearest integer

func get_ship_shield_percentage(ship_name: String) -> int:
	"""
	Get ship shield health as percentage (0-100)
	Returns 0 if ship has no shields, SEXP_NAN if not found, SEXP_NAN_FOREVER if destroyed
	"""
	# Check if ship is destroyed or departed
	if _ship_destroyed.has(ship_name):
		return SexpResult.SEXP_NAN_FOREVER
	if _ship_departed.has(ship_name):
		return SexpResult.SEXP_NAN_FOREVER
	
	var ship_node = ship_name_lookup(ship_name, true)
	if ship_node == null:
		return SexpResult.SEXP_NAN
	
	# Get shield health
	var shield_pct: float = 0.0
	if ship_node.has_method("get_shield_percentage"):
		shield_pct = ship_node.get_shield_percentage()
	elif ship_node.has_property("shields") and ship_node.has_property("max_shields"):
		var shields = ship_node.get("shields") as float
		var max_shields = ship_node.get("max_shields") as float
		if max_shields > 0.0:
			shield_pct = shields / max_shields
		else:
			return 0  # Ship has no shields
	else:
		return 0  # Ship has no shield system
	
	return int((shield_pct * 100.0) + 0.5)  # Round to nearest integer

func get_ship_distance(ship_name1: String, ship_name2: String) -> float:
	"""
	Get distance between two ships
	Returns SEXP_NAN if either ship not found, SEXP_NAN_FOREVER if either destroyed
	"""
	# Check if either ship is destroyed or departed
	if _ship_destroyed.has(ship_name1) or _ship_departed.has(ship_name1):
		return SexpResult.SEXP_NAN_FOREVER
	if _ship_destroyed.has(ship_name2) or _ship_departed.has(ship_name2):
		return SexpResult.SEXP_NAN_FOREVER
	
	var ship1 = ship_name_lookup(ship_name1, true)
	var ship2 = ship_name_lookup(ship_name2, true)
	
	if ship1 == null or ship2 == null:
		return SexpResult.SEXP_NAN
	
	# Get positions
	var pos1 = _get_ship_position(ship1)
	var pos2 = _get_ship_position(ship2)
	
	return pos1.distance_to(pos2)

func get_ship_position(ship_name: String) -> Vector3:
	"""
	Get ship world position
	Returns Vector3.ZERO if ship not found or destroyed
	"""
	# Check if ship is destroyed or departed
	if _ship_destroyed.has(ship_name) or _ship_departed.has(ship_name):
		return Vector3.ZERO
	
	var ship_node = ship_name_lookup(ship_name, true)
	if ship_node == null:
		return Vector3.ZERO
	
	return _get_ship_position(ship_node)

func _get_ship_position(ship_node: Node) -> Vector3:
	"""Get position from ship node"""
	if ship_node is Node3D:
		return ship_node.global_position
	elif ship_node.has_method("get_position"):
		return ship_node.get_position()
	elif ship_node.has_property("position"):
		return ship_node.get("position")
	return Vector3.ZERO

func get_ship_velocity(ship_name: String) -> Vector3:
	"""
	Get ship velocity vector
	Returns Vector3.ZERO if ship not found or destroyed
	"""
	# Check if ship is destroyed or departed
	if _ship_destroyed.has(ship_name) or _ship_departed.has(ship_name):
		return Vector3.ZERO
	
	var ship_node = ship_name_lookup(ship_name, true)
	if ship_node == null:
		return Vector3.ZERO
	
	return _get_ship_velocity(ship_node)

func _get_ship_velocity(ship_node: Node) -> Vector3:
	"""Get velocity from ship node"""
	if ship_node.has_method("get_velocity"):
		return ship_node.get_velocity()
	elif ship_node is RigidBody3D:
		return ship_node.linear_velocity
	elif ship_node is CharacterBody3D:
		return ship_node.velocity
	elif ship_node.has_property("velocity"):
		return ship_node.get("velocity")
	return Vector3.ZERO

func get_ship_speed(ship_name: String) -> float:
	"""
	Get ship current speed (velocity magnitude)
	Returns 0.0 if ship not found or destroyed
	"""
	var velocity = get_ship_velocity(ship_name)
	return velocity.length()

## Subsystem status functions

func get_ship_subsystem_health(ship_name: String, subsystem_name: String) -> int:
	"""
	Get specific subsystem health percentage (0-100)
	Returns SEXP_NAN if ship or subsystem not found
	"""
	# Check if ship is destroyed or departed
	if _ship_destroyed.has(ship_name) or _ship_departed.has(ship_name):
		return SexpResult.SEXP_NAN_FOREVER
	
	var ship_node = ship_name_lookup(ship_name, true)
	if ship_node == null:
		return SexpResult.SEXP_NAN
	
	# Get subsystem health
	var subsystem_pct: float = 0.0
	if ship_node.has_method("get_subsystem_health"):
		subsystem_pct = ship_node.get_subsystem_health(subsystem_name)
	elif ship_node.has_method("get_subsystem"):
		var subsystem = ship_node.get_subsystem(subsystem_name)
		if subsystem != null and subsystem.has_method("get_health_percentage"):
			subsystem_pct = subsystem.get_health_percentage()
	else:
		# Try to find subsystem as child node
		var subsystem_node = _find_subsystem_node(ship_node, subsystem_name)
		if subsystem_node != null:
			subsystem_pct = _get_subsystem_health_percentage(subsystem_node)
	
	if subsystem_pct < 0.0:
		return SexpResult.SEXP_NAN  # Subsystem not found
	
	return int((subsystem_pct * 100.0) + 0.5)

func _find_subsystem_node(ship_node: Node, subsystem_name: String) -> Node:
	"""Find subsystem node by name"""
	for child in ship_node.get_children():
		if child.name.to_lower() == subsystem_name.to_lower():
			return child
		# Check for subsystem groups
		if child.is_in_group("subsystems") and child.has_method("get_subsystem_name"):
			if child.get_subsystem_name().to_lower() == subsystem_name.to_lower():
				return child
	return null

func _get_subsystem_health_percentage(subsystem_node: Node) -> float:
	"""Get health percentage from subsystem node"""
	if subsystem_node.has_method("get_health_percentage"):
		return subsystem_node.get_health_percentage()
	elif subsystem_node.has_property("health") and subsystem_node.has_property("max_health"):
		var health = subsystem_node.get("health") as float
		var max_health = subsystem_node.get("max_health") as float
		if max_health > 0.0:
			return health / max_health
	return -1.0  # Not found or invalid

## Ship registration and lifecycle tracking

func register_ship(ship_name: String, ship_node: Node, metadata: Dictionary = {}) -> bool:
	"""
	Register ship in the object reference system
	Args:
		ship_name: Name to register ship under
		ship_node: Ship node to register
		metadata: Additional metadata (team, wing, etc.)
	Returns:
		true if registration succeeded
	"""
	return _object_ref_system.register_object(ship_name, ObjectReferenceSystem.ReferenceType.SHIP, ship_node, metadata)

func register_ship_destroyed(ship_name: String, ship_node: Node = null):
	"""Register ship as destroyed"""
	_object_ref_system.mark_object_destroyed(ship_name)
	ship_destroyed.emit(ship_name, ship_node)

func register_ship_departed(ship_name: String, ship_node: Node = null):
	"""Register ship as departed"""
	_object_ref_system.mark_object_departed(ship_name)
	ship_departed.emit(ship_name, ship_node)

func is_ship_destroyed(ship_name: String) -> bool:
	"""Check if ship is registered as destroyed"""
	return _object_ref_system.is_object_destroyed(ship_name)

func is_ship_departed(ship_name: String) -> bool:
	"""Check if ship is registered as departed"""
	return _object_ref_system.is_object_departed(ship_name)

func is_ship_exited(ship_name: String) -> bool:
	"""Check if ship has exited (destroyed or departed)"""
	return _object_ref_system.is_object_exited(ship_name)

func clear_ship_lifecycle_data():
	"""Clear all ship lifecycle tracking data"""
	# This is now handled by the object reference system cleanup
	_object_ref_system.cleanup_invalid_references()

## Object reference system signal handlers

func _on_object_invalidated(reference_id: String, reference_type: ObjectReferenceSystem.ReferenceType):
	"""Handle object reference invalidation"""
	if reference_type == ObjectReferenceSystem.ReferenceType.SHIP:
		# Could emit additional ship-specific signals here
		pass

func _on_object_updated(reference_id: String, old_node: Node, new_node: Node):
	"""Handle object reference updates"""
	# Could handle ship state transitions here
	pass

## Utility functions

func _get_ship_manager() -> Node:
	"""Get ship manager node from scene"""
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return null
	
	# Try common ship manager names
	var manager_names = ["ShipManager", "ship_manager", "MissionManager", "mission_manager"]
	for name in manager_names:
		var manager = scene_tree.get_first_node_in_group(name)
		if manager != null:
			return manager
	
	return null

func get_system_statistics() -> Dictionary:
	"""Get system performance and usage statistics"""
	return _object_ref_system.get_system_statistics()

func cleanup_system():
	"""Perform system maintenance and cleanup"""
	_object_ref_system.cleanup_invalid_references()

## Wing and team management functions

func register_wing(wing_name: String, ship_names: Array[String]) -> bool:
	"""
	Register a wing with its member ships
	Args:
		wing_name: Name of the wing
		ship_names: Array of ship names in the wing
	Returns:
		true if registration succeeded
	"""
	for ship_name in ship_names:
		var ship_node = ship_name_lookup(ship_name, true)
		if ship_node:
			var metadata = {"wing_name": wing_name}
			_object_ref_system.register_object(ship_name, ObjectReferenceSystem.ReferenceType.SHIP, ship_node, metadata)
	
	return true

func register_team_ship(ship_name: String, team_id: int) -> bool:
	"""
	Register a ship as part of a team
	Args:
		ship_name: Name of the ship
		team_id: Team identifier
	Returns:
		true if registration succeeded
	"""
	var ship_node = ship_name_lookup(ship_name, true)
	if ship_node:
		var metadata = {"team_id": team_id}
		return _object_ref_system.register_object(ship_name, ObjectReferenceSystem.ReferenceType.SHIP, ship_node, metadata)
	
	return false

func get_wing_ships(wing_name: String) -> Array[Node]:
	"""Get all ships in a wing"""
	return _object_ref_system.get_wing_members(wing_name)

func get_team_ships(team_id: int) -> Array[Node]:
	"""Get all ships on a team"""
	return _object_ref_system.get_team_members(team_id)