class_name ObjectReferenceSystem
extends RefCounted

## WCS-style object reference system for reliable ship/object identification
##
## Provides WCS-compatible object reference management following the patterns
## from the original object_ship_wing_point_team (OSWPT) system, enabling
## reliable object identification across mission state changes and supporting
## all WCS reference types including ships, wings, waypoints, and teams.
##
## Integrates with WCS Asset Core addon for consistent object data handling.

signal object_reference_invalidated(reference_id: String, reference_type: ReferenceType)
signal object_reference_updated(reference_id: String, old_node: Node, new_node: Node)

## Reference types following WCS OSWPT patterns
enum ReferenceType {
	SHIP,           # Individual ship
	WING,           # Ship wing/squadron
	WAYPOINT,       # Waypoint marker
	TEAM,           # All ships of a team
	EXITED,         # Destroyed/departed ships
	SUBSYSTEM,      # Ship subsystem
	UNKNOWN         # Invalid or unresolved reference
}

## Object reference structure following WCS patterns
class ObjectReference:
	extends RefCounted
	
	var reference_id: String
	var reference_type: ReferenceType
	var object_node: Node
	var team_id: int = -1
	var wing_name: String = ""
	var subsystem_name: String = ""
	var creation_time: float
	var last_access_time: float
	var is_valid: bool = true
	var metadata: Dictionary = {}
	
	func _init(id: String, type: ReferenceType, node: Node = null):
		reference_id = id
		reference_type = type
		object_node = node
		creation_time = Time.get_ticks_msec() * 0.001
		last_access_time = creation_time
	
	func update_access_time():
		last_access_time = Time.get_ticks_msec() * 0.001
	
	func invalidate():
		is_valid = false
		object_node = null
	
	func get_age() -> float:
		return Time.get_ticks_msec() * 0.001 - creation_time
	
	func get_idle_time() -> float:
		return Time.get_ticks_msec() * 0.001 - last_access_time

## Main reference system
var _object_references: Dictionary = {}  # reference_id -> ObjectReference
var _type_indices: Dictionary = {}       # ReferenceType -> Array[String]
var _wing_members: Dictionary = {}       # wing_name -> Array[String]
var _team_members: Dictionary = {}       # team_id -> Array[String]
var _subsystem_refs: Dictionary = {}     # ship_id -> Dictionary[subsystem_name -> String]
var _departed_objects: Dictionary = {}   # reference_id -> departure_time
var _destroyed_objects: Dictionary = {}  # reference_id -> destruction_time

## Performance and cache management
var _reference_cache: Dictionary = {}
var _cache_timeout: float = 1.0  # Cache timeout in seconds
var _max_cache_size: int = 1000
var _cleanup_interval: float = 30.0  # Cleanup every 30 seconds
var _last_cleanup: float = 0.0

## Singleton pattern
static var _instance: ObjectReferenceSystem = null

static func get_instance() -> ObjectReferenceSystem:
	if _instance == null:
		_instance = ObjectReferenceSystem.new()
	return _instance

func _init():
	if _instance == null:
		_instance = self
	_initialize_indices()

func _initialize_indices():
	"""Initialize type indices for efficient lookups"""
	for type in ReferenceType.values():
		_type_indices[type] = []

## Object registration and management

func register_object(reference_id: String, reference_type: ReferenceType, object_node: Node, metadata: Dictionary = {}) -> bool:
	"""
	Register an object in the reference system
	Args:
		reference_id: Unique identifier for the object
		reference_type: Type of object being registered
		object_node: Godot node representing the object
		metadata: Additional metadata (team, wing, etc.)
	Returns:
		true if registration succeeded
	"""
	if reference_id.is_empty() or object_node == null:
		return false
	
	# Create reference
	var ref = ObjectReference.new(reference_id, reference_type, object_node)
	ref.metadata = metadata.duplicate()
	
	# Extract team and wing information from metadata
	if metadata.has("team_id"):
		ref.team_id = metadata["team_id"]
		_add_to_team_index(ref.team_id, reference_id)
	
	if metadata.has("wing_name"):
		ref.wing_name = metadata["wing_name"]
		_add_to_wing_index(ref.wing_name, reference_id)
	
	if metadata.has("subsystem_name"):
		ref.subsystem_name = metadata["subsystem_name"]
		var ship_id = metadata.get("parent_ship_id", "")
		if not ship_id.is_empty():
			_add_to_subsystem_index(ship_id, ref.subsystem_name, reference_id)
	
	# Store reference
	_object_references[reference_id] = ref
	_add_to_type_index(reference_type, reference_id)
	
	# Clear cache for this object
	_invalidate_cache_for_object(reference_id)
	
	return true

func unregister_object(reference_id: String) -> bool:
	"""
	Remove object from reference system
	Args:
		reference_id: Object to remove
	Returns:
		true if removal succeeded
	"""
	if not _object_references.has(reference_id):
		return false
	
	var ref: ObjectReference = _object_references[reference_id]
	
	# Remove from indices
	_remove_from_type_index(ref.reference_type, reference_id)
	
	if ref.team_id >= 0:
		_remove_from_team_index(ref.team_id, reference_id)
	
	if not ref.wing_name.is_empty():
		_remove_from_wing_index(ref.wing_name, reference_id)
	
	if not ref.subsystem_name.is_empty():
		var ship_id = ref.metadata.get("parent_ship_id", "")
		if not ship_id.is_empty():
			_remove_from_subsystem_index(ship_id, ref.subsystem_name)
	
	# Remove main reference
	_object_references.erase(reference_id)
	
	# Clear cache
	_invalidate_cache_for_object(reference_id)
	
	# Emit invalidation signal
	object_reference_invalidated.emit(reference_id, ref.reference_type)
	
	return true

func update_object_node(reference_id: String, new_node: Node) -> bool:
	"""
	Update the node reference for an existing object
	Args:
		reference_id: Object to update
		new_node: New node reference
	Returns:
		true if update succeeded
	"""
	if not _object_references.has(reference_id) or new_node == null:
		return false
	
	var ref: ObjectReference = _object_references[reference_id]
	var old_node = ref.object_node
	
	ref.object_node = new_node
	ref.update_access_time()
	
	# Clear cache
	_invalidate_cache_for_object(reference_id)
	
	# Emit update signal
	object_reference_updated.emit(reference_id, old_node, new_node)
	
	return true

## Object lookup and retrieval

func get_object_reference(reference_id: String) -> ObjectReference:
	"""
	Get object reference by ID
	Args:
		reference_id: Object to find
	Returns:
		ObjectReference or null if not found
	"""
	if not _object_references.has(reference_id):
		return null
	
	var ref: ObjectReference = _object_references[reference_id]
	ref.update_access_time()
	
	# Validate node is still valid
	if ref.object_node != null and not is_instance_valid(ref.object_node):
		ref.invalidate()
		return null
	
	return ref

func get_object_node(reference_id: String) -> Node:
	"""
	Get object node by reference ID
	Args:
		reference_id: Object to find
	Returns:
		Node or null if not found or invalid
	"""
	var ref = get_object_reference(reference_id)
	return ref.object_node if ref and ref.is_valid else null

func find_object_by_name(object_name: String, object_type: ReferenceType = ReferenceType.UNKNOWN) -> Node:
	"""
	Find object by name, optionally filtered by type
	Args:
		object_name: Name to search for
		object_type: Optional type filter
	Returns:
		First matching node or null
	"""
	# Check cache first
	var cache_key = object_name + "_" + str(object_type)
	if _reference_cache.has(cache_key):
		var cache_entry = _reference_cache[cache_key]
		if Time.get_ticks_msec() * 0.001 - cache_entry.timestamp < _cache_timeout:
			var node = cache_entry.node
			if is_instance_valid(node):
				return node
			else:
				_reference_cache.erase(cache_key)
	
	# Search through references
	var search_types = [object_type] if object_type != ReferenceType.UNKNOWN else ReferenceType.values()
	
	for type in search_types:
		if not _type_indices.has(type):
			continue
		
		for ref_id in _type_indices[type]:
			var ref = get_object_reference(ref_id)
			if ref == null or not ref.is_valid:
				continue
			
			# Check various name fields
			if _object_matches_name(ref.object_node, object_name):
				# Cache the result
				_cache_reference_lookup(cache_key, ref.object_node)
				return ref.object_node
	
	return null

func get_objects_by_type(object_type: ReferenceType) -> Array[Node]:
	"""
	Get all objects of a specific type
	Args:
		object_type: Type to filter by
	Returns:
		Array of nodes matching the type
	"""
	var nodes: Array[Node] = []
	
	if not _type_indices.has(object_type):
		return nodes
	
	for ref_id in _type_indices[object_type]:
		var ref = get_object_reference(ref_id)
		if ref and ref.is_valid and ref.object_node:
			nodes.append(ref.object_node)
	
	return nodes

func get_wing_members(wing_name: String) -> Array[Node]:
	"""
	Get all ships in a wing
	Args:
		wing_name: Wing to get members for
	Returns:
		Array of ship nodes in the wing
	"""
	var members: Array[Node] = []
	
	if not _wing_members.has(wing_name):
		return members
	
	for ship_id in _wing_members[wing_name]:
		var node = get_object_node(ship_id)
		if node:
			members.append(node)
	
	return members

func get_team_members(team_id: int) -> Array[Node]:
	"""
	Get all ships on a team
	Args:
		team_id: Team to get members for
	Returns:
		Array of ship nodes on the team
	"""
	var members: Array[Node] = []
	
	if not _team_members.has(team_id):
		return members
	
	for ship_id in _team_members[team_id]:
		var node = get_object_node(ship_id)
		if node:
			members.append(node)
	
	return members

func get_ship_subsystems(ship_id: String) -> Dictionary:
	"""
	Get all subsystems for a ship
	Args:
		ship_id: Ship to get subsystems for
	Returns:
		Dictionary of subsystem_name -> Node
	"""
	var subsystems: Dictionary = {}
	
	if not _subsystem_refs.has(ship_id):
		return subsystems
	
	for subsystem_name in _subsystem_refs[ship_id]:
		var subsystem_id = _subsystem_refs[ship_id][subsystem_name]
		var node = get_object_node(subsystem_id)
		if node:
			subsystems[subsystem_name] = node
	
	return subsystems

## Object lifecycle management

func mark_object_destroyed(reference_id: String):
	"""Mark object as destroyed"""
	_destroyed_objects[reference_id] = Time.get_ticks_msec() * 0.001
	
	var ref = get_object_reference(reference_id)
	if ref:
		ref.reference_type = ReferenceType.EXITED
		ref.invalidate()

func mark_object_departed(reference_id: String):
	"""Mark object as departed"""
	_departed_objects[reference_id] = Time.get_ticks_msec() * 0.001
	
	var ref = get_object_reference(reference_id)
	if ref:
		ref.reference_type = ReferenceType.EXITED
		ref.invalidate()

func is_object_destroyed(reference_id: String) -> bool:
	"""Check if object is marked as destroyed"""
	return _destroyed_objects.has(reference_id)

func is_object_departed(reference_id: String) -> bool:
	"""Check if object is marked as departed"""
	return _departed_objects.has(reference_id)

func is_object_exited(reference_id: String) -> bool:
	"""Check if object has exited (destroyed or departed)"""
	return is_object_destroyed(reference_id) or is_object_departed(reference_id)

## Advanced query functions

func get_closest_object_to_position(position: Vector3, object_type: ReferenceType = ReferenceType.UNKNOWN, max_distance: float = -1.0) -> Node:
	"""
	Find closest object to a position
	Args:
		position: Position to search from
		object_type: Optional type filter
		max_distance: Maximum search distance (-1 for unlimited)
	Returns:
		Closest object node or null
	"""
	var closest_node: Node = null
	var closest_distance: float = INF
	
	var search_types = [object_type] if object_type != ReferenceType.UNKNOWN else [ReferenceType.SHIP, ReferenceType.WAYPOINT]
	
	for type in search_types:
		for node in get_objects_by_type(type):
			var node_pos = _get_object_position(node)
			var distance = position.distance_to(node_pos)
			
			if (max_distance < 0.0 or distance <= max_distance) and distance < closest_distance:
				closest_distance = distance
				closest_node = node
	
	return closest_node

func get_objects_in_range(center_position: Vector3, range_distance: float, object_type: ReferenceType = ReferenceType.UNKNOWN) -> Array[Node]:
	"""
	Get all objects within range of a position
	Args:
		center_position: Center position to search from
		range_distance: Search radius
		object_type: Optional type filter
	Returns:
		Array of objects within range
	"""
	var objects_in_range: Array[Node] = []
	
	var search_types = [object_type] if object_type != ReferenceType.UNKNOWN else [ReferenceType.SHIP, ReferenceType.WAYPOINT]
	
	for type in search_types:
		for node in get_objects_by_type(type):
			var node_pos = _get_object_position(node)
			var distance = center_position.distance_to(node_pos)
			
			if distance <= range_distance:
				objects_in_range.append(node)
	
	return objects_in_range

## System maintenance and optimization

func cleanup_invalid_references():
	"""Remove invalid references and perform maintenance"""
	var current_time = Time.get_ticks_msec() * 0.001
	
	if current_time - _last_cleanup < _cleanup_interval:
		return
	
	_last_cleanup = current_time
	
	# Clean up invalid references
	var invalid_refs: Array[String] = []
	
	for ref_id in _object_references:
		var ref: ObjectReference = _object_references[ref_id]
		
		# Check if node is still valid
		if ref.object_node != null and not is_instance_valid(ref.object_node):
			invalid_refs.append(ref_id)
		# Clean up old departed/destroyed references
		elif ref.get_idle_time() > 300.0 and ref.reference_type == ReferenceType.EXITED:
			invalid_refs.append(ref_id)
	
	# Remove invalid references
	for ref_id in invalid_refs:
		unregister_object(ref_id)
	
	# Clean up old cache entries
	_cleanup_cache()

func get_system_statistics() -> Dictionary:
	"""Get system performance and usage statistics"""
	return {
		"total_objects": _object_references.size(),
		"objects_by_type": _get_type_counts(),
		"cache_size": _reference_cache.size(),
		"wings": _wing_members.size(),
		"teams": _team_members.size(),
		"destroyed_objects": _destroyed_objects.size(),
		"departed_objects": _departed_objects.size(),
		"last_cleanup": _last_cleanup
	}

## Private helper functions

func _object_matches_name(node: Node, search_name: String) -> bool:
	"""Check if node matches search name"""
	if node.name.to_lower() == search_name.to_lower():
		return true
	
	# Check for ship-specific name methods
	if node.has_method("get_ship_name"):
		return node.get_ship_name().to_lower() == search_name.to_lower()
	elif node.has_method("get_object_name"):
		return node.get_object_name().to_lower() == search_name.to_lower()
	elif node.has_property("object_name"):
		return str(node.get("object_name")).to_lower() == search_name.to_lower()
	
	return false

func _get_object_position(node: Node) -> Vector3:
	"""Get position from any object node"""
	if node is Node3D:
		return node.global_position
	elif node.has_method("get_position"):
		return node.get_position()
	elif node.has_property("position"):
		return node.get("position")
	return Vector3.ZERO

func _add_to_type_index(object_type: ReferenceType, reference_id: String):
	"""Add reference to type index"""
	if not _type_indices.has(object_type):
		_type_indices[object_type] = []
	
	if not _type_indices[object_type].has(reference_id):
		_type_indices[object_type].append(reference_id)

func _remove_from_type_index(object_type: ReferenceType, reference_id: String):
	"""Remove reference from type index"""
	if _type_indices.has(object_type):
		_type_indices[object_type].erase(reference_id)

func _add_to_wing_index(wing_name: String, ship_id: String):
	"""Add ship to wing index"""
	if not _wing_members.has(wing_name):
		_wing_members[wing_name] = []
	
	if not _wing_members[wing_name].has(ship_id):
		_wing_members[wing_name].append(ship_id)

func _remove_from_wing_index(wing_name: String, ship_id: String):
	"""Remove ship from wing index"""
	if _wing_members.has(wing_name):
		_wing_members[wing_name].erase(ship_id)

func _add_to_team_index(team_id: int, ship_id: String):
	"""Add ship to team index"""
	if not _team_members.has(team_id):
		_team_members[team_id] = []
	
	if not _team_members[team_id].has(ship_id):
		_team_members[team_id].append(ship_id)

func _remove_from_team_index(team_id: int, ship_id: String):
	"""Remove ship from team index"""
	if _team_members.has(team_id):
		_team_members[team_id].erase(ship_id)

func _add_to_subsystem_index(ship_id: String, subsystem_name: String, subsystem_ref_id: String):
	"""Add subsystem to ship's subsystem index"""
	if not _subsystem_refs.has(ship_id):
		_subsystem_refs[ship_id] = {}
	
	_subsystem_refs[ship_id][subsystem_name] = subsystem_ref_id

func _remove_from_subsystem_index(ship_id: String, subsystem_name: String):
	"""Remove subsystem from ship's subsystem index"""
	if _subsystem_refs.has(ship_id):
		_subsystem_refs[ship_id].erase(subsystem_name)

func _cache_reference_lookup(cache_key: String, node: Node):
	"""Cache a reference lookup result"""
	if _reference_cache.size() >= _max_cache_size:
		_cleanup_cache()
	
	_reference_cache[cache_key] = {
		"node": node,
		"timestamp": Time.get_ticks_msec() * 0.001
	}

func _invalidate_cache_for_object(reference_id: String):
	"""Invalidate all cache entries for an object"""
	var keys_to_remove: Array[String] = []
	
	for key in _reference_cache:
		if key.begins_with(reference_id) or key.ends_with(reference_id):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_reference_cache.erase(key)

func _cleanup_cache():
	"""Remove old cache entries"""
	var current_time = Time.get_ticks_msec() * 0.001
	var keys_to_remove: Array[String] = []
	
	for key in _reference_cache:
		var entry = _reference_cache[key]
		if current_time - entry.timestamp > _cache_timeout:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_reference_cache.erase(key)

func _get_type_counts() -> Dictionary:
	"""Get count of objects by type"""
	var counts: Dictionary = {}
	
	for type in ReferenceType.values():
		var type_name = ReferenceType.keys()[type]
		counts[type_name] = _type_indices.get(type, []).size()
	
	return counts