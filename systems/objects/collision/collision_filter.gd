class_name CollisionFilter
extends Node

## Collision filtering system for WCS-Godot conversion that prevents unnecessary collision checks.
## Implements WCS-style collision filtering including parent-child rejection, collision groups,
## and performance optimization through intelligent pair filtering.
##
## Key Features:
## - Parent-child collision rejection to prevent inappropriate collisions
## - Collision group filtering for organized collision management  
## - Object type-based filtering to reduce collision pair creation
## - Performance optimization through early rejection of impossible collisions

signal collision_filtered(object_a: Node3D, object_b: Node3D, filter_reason: String)
signal filter_rule_applied(rule_name: String, objects_filtered: int)

# EPIC-002 Asset Core Integration
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

# Collision filtering configuration
@export var enable_parent_child_filtering: bool = true
@export var enable_collision_group_filtering: bool = true
@export var enable_distance_filtering: bool = true
@export var enable_type_filtering: bool = true
@export var max_collision_distance: float = 10000.0  # Maximum distance for collision consideration

# Collision group management (WCS-inspired)
var collision_groups: Dictionary = {}  # group_id -> Array[Node3D] objects in group
var object_collision_groups: Dictionary = {}  # object_id -> group_id

# Object relationship tracking
var parent_child_relationships: Dictionary = {}  # child_id -> parent_id
var object_signatures: Dictionary = {}  # object_id -> signature for parent tracking

# Type-based collision rules
var collision_type_matrix: Dictionary = {}

# Performance tracking
var filters_applied_this_frame: int = 0
var filter_statistics: Dictionary = {
	"parent_child_filtered": 0,
	"collision_group_filtered": 0, 
	"distance_filtered": 0,
	"type_filtered": 0,
	"total_filtered": 0
}

func _ready() -> void:
	_initialize_collision_type_matrix()
	print("CollisionFilter: Initialized with WCS-style collision filtering")

func _initialize_collision_type_matrix() -> void:
	"""Initialize the collision type matrix defining which object types can collide."""
	collision_type_matrix = {
		# Ships can collide with everything except themselves (handled separately)
		ObjectTypes.Type.SHIP: [
			ObjectTypes.Type.WEAPON,
			ObjectTypes.Type.DEBRIS, 
			ObjectTypes.Type.ASTEROID,
			ObjectTypes.Type.BEAM,
			ObjectTypes.Type.EFFECT
		],
		
		# Weapons collide with ships, debris, and asteroids
		ObjectTypes.Type.WEAPON: [
			ObjectTypes.Type.SHIP,
			ObjectTypes.Type.DEBRIS,
			ObjectTypes.Type.ASTEROID
		],
		
		# Debris collides with ships and weapons
		ObjectTypes.Type.DEBRIS: [
			ObjectTypes.Type.SHIP,
			ObjectTypes.Type.WEAPON,
			ObjectTypes.Type.DEBRIS  # Debris can collide with other debris
		],
		
		# Asteroids collide with ships and weapons
		ObjectTypes.Type.ASTEROID: [
			ObjectTypes.Type.SHIP,
			ObjectTypes.Type.WEAPON
		],
		
		# Beams only collide with ships
		ObjectTypes.Type.BEAM: [
			ObjectTypes.Type.SHIP
		],
		
		# Effects generally don't collide
		ObjectTypes.Type.EFFECT: [],
		
		# Countermeasures collide with weapons (for interception)
		ObjectTypes.Type.COUNTERMEASURE: [
			ObjectTypes.Type.WEAPON
		]
	}

## Main collision filtering function (AC3)
func should_create_collision_pair(object_a: Node3D, object_b: Node3D) -> bool:
	"""Determine if a collision pair should be created between two objects.
	
	Args:
		object_a: First object to check
		object_b: Second object to check
		
	Returns:
		true if collision pair should be created, false if filtered out
	"""
	filters_applied_this_frame = 0
	
	# Basic validation
	if not is_instance_valid(object_a) or not is_instance_valid(object_b):
		_record_filter_applied("invalid_objects")
		return false
	
	if object_a == object_b:
		_record_filter_applied("same_object")
		return false
	
	# Parent-child relationship filtering (AC3)
	if enable_parent_child_filtering:
		if _is_parent_child_relationship(object_a, object_b):
			collision_filtered.emit(object_a, object_b, "parent_child_relationship")
			_record_filter_applied("parent_child")
			return false
	
	# Collision group filtering (AC3)
	if enable_collision_group_filtering:
		if _objects_in_same_collision_group(object_a, object_b):
			collision_filtered.emit(object_a, object_b, "same_collision_group")
			_record_filter_applied("collision_group")
			return false
	
	# Object type filtering (AC3)
	if enable_type_filtering:
		if not _types_can_collide(object_a, object_b):
			collision_filtered.emit(object_a, object_b, "incompatible_types")
			_record_filter_applied("type_filtered")
			return false
	
	# Distance-based filtering (AC3)
	if enable_distance_filtering:
		if not _objects_within_collision_distance(object_a, object_b):
			collision_filtered.emit(object_a, object_b, "distance_too_far")
			_record_filter_applied("distance_filtered")
			return false
	
	# Collision layer/mask filtering (AC3)
	if not _collision_layers_compatible(object_a, object_b):
		collision_filtered.emit(object_a, object_b, "incompatible_collision_layers")
		_record_filter_applied("layer_mask_filtered")
		return false
	
	return true

## Parent-child relationship filtering (WCS-inspired)
func _is_parent_child_relationship(object_a: Node3D, object_b: Node3D) -> bool:
	"""Check if objects have parent-child relationship that should prevent collision.
	
	Implements WCS reject_obj_pair_on_parent logic.
	"""
	var id_a: int = object_a.get_instance_id()
	var id_b: int = object_b.get_instance_id()
	
	# Check direct parent-child relationships
	if id_a in parent_child_relationships and parent_child_relationships[id_a] == id_b:
		return true
	if id_b in parent_child_relationships and parent_child_relationships[id_b] == id_a:
		return true
	
	# Check WCS-style signature-based relationships
	var sig_a: int = object_signatures.get(id_a, -1)
	var sig_b: int = object_signatures.get(id_b, -1)
	
	if sig_a != -1 and sig_b != -1:
		if sig_a == sig_b:
			return true  # Same signature = parent-child relationship
	
	# Special case: Ship-debris relationships (WCS logic)
	var type_a: ObjectTypes.Type = _get_object_type(object_a)
	var type_b: ObjectTypes.Type = _get_object_type(object_b)
	
	if type_a == ObjectTypes.Type.SHIP and type_b == ObjectTypes.Type.DEBRIS:
		# Check if debris was created by this ship
		if _debris_created_by_ship(object_b, object_a):
			return false  # Allow ship-debris collision for its own debris
	
	if type_b == ObjectTypes.Type.SHIP and type_a == ObjectTypes.Type.DEBRIS:
		# Check if debris was created by this ship
		if _debris_created_by_ship(object_a, object_b):
			return false  # Allow ship-debris collision for its own debris
	
	return false

func _debris_created_by_ship(debris: Node3D, ship: Node3D) -> bool:
	"""Check if debris was created by a specific ship."""
	if debris.has_method("get_parent_signature") and ship.has_method("get_signature"):
		return debris.get_parent_signature() == ship.get_signature()
	
	return false

## Collision group filtering (WCS-inspired)
func _objects_in_same_collision_group(object_a: Node3D, object_b: Node3D) -> bool:
	"""Check if objects are in the same collision group and should not collide.
	
	Implements WCS reject_due_collision_groups logic.
	"""
	var id_a: int = object_a.get_instance_id()
	var id_b: int = object_b.get_instance_id()
	
	var group_a: int = object_collision_groups.get(id_a, 0)
	var group_b: int = object_collision_groups.get(id_b, 0)
	
	# Objects with collision group 0 can collide with anything
	if group_a == 0 or group_b == 0:
		return false
	
	# Check if groups overlap (WCS bitwise AND logic)
	return (group_a & group_b) != 0

## Object type compatibility checking
func _types_can_collide(object_a: Node3D, object_b: Node3D) -> bool:
	"""Check if object types are compatible for collision detection."""
	var type_a: ObjectTypes.Type = _get_object_type(object_a)
	var type_b: ObjectTypes.Type = _get_object_type(object_b)
	
	# Check collision matrix
	var allowed_types_a: Array = collision_type_matrix.get(type_a, [])
	var allowed_types_b: Array = collision_type_matrix.get(type_b, [])
	
	# Types can collide if either type allows collision with the other
	return type_b in allowed_types_a or type_a in allowed_types_b

func _get_object_type(obj: Node3D) -> ObjectTypes.Type:
	"""Get object type for collision filtering."""
	if obj.has_method("get_object_type"):
		return obj.get_object_type()
	
	# Fallback to name-based detection
	var name_lower: String = obj.name.to_lower()
	if "ship" in name_lower:
		return ObjectTypes.Type.SHIP
	elif "weapon" in name_lower:
		return ObjectTypes.Type.WEAPON
	elif "debris" in name_lower:
		return ObjectTypes.Type.DEBRIS
	elif "asteroid" in name_lower:
		return ObjectTypes.Type.ASTEROID
	elif "beam" in name_lower:
		return ObjectTypes.Type.BEAM
	elif "effect" in name_lower:
		return ObjectTypes.Type.EFFECT
	
	return ObjectTypes.Type.SHIP  # Default fallback

## Distance-based filtering
func _objects_within_collision_distance(object_a: Node3D, object_b: Node3D) -> bool:
	"""Check if objects are within collision distance threshold."""
	var distance: float = object_a.global_position.distance_to(object_b.global_position)
	return distance <= max_collision_distance

## Collision layer/mask filtering (Godot-specific)
func _collision_layers_compatible(object_a: Node3D, object_b: Node3D) -> bool:
	"""Check if objects' collision layers and masks are compatible."""
	var layer_a: int = _get_object_collision_layer(object_a)
	var mask_a: int = _get_object_collision_mask(object_a)
	var layer_b: int = _get_object_collision_layer(object_b)
	var mask_b: int = _get_object_collision_mask(object_b)
	
	# Objects can collide if layer A is in mask B OR layer B is in mask A
	return (layer_a & mask_b) != 0 or (layer_b & mask_a) != 0

func _get_object_collision_layer(obj: Node3D) -> int:
	"""Get collision layer from object."""
	if obj.has_method("get_collision_layer"):
		return obj.get_collision_layer()
	
	return 1  # Default layer

func _get_object_collision_mask(obj: Node3D) -> int:
	"""Get collision mask from object."""
	if obj.has_method("get_collision_mask"):
		return obj.get_collision_mask()
	
	return 1  # Default mask

## Collision group management functions
func set_object_collision_group(obj: Node3D, group_id: int) -> void:
	"""Set collision group for an object.
	
	Args:
		obj: Object to assign to collision group
		group_id: Collision group ID (0 = no group restrictions)
	"""
	var object_id: int = obj.get_instance_id()
	
	# Remove from previous group
	if object_id in object_collision_groups:
		var old_group: int = object_collision_groups[object_id]
		if old_group in collision_groups:
			collision_groups[old_group].erase(obj)
	
	# Add to new group
	object_collision_groups[object_id] = group_id
	
	if group_id != 0:
		if not group_id in collision_groups:
			collision_groups[group_id] = []
		collision_groups[group_id].append(obj)
	
	print("CollisionFilter: Set object %s to collision group %d" % [obj.name, group_id])

func get_object_collision_group(obj: Node3D) -> int:
	"""Get collision group for an object.
	
	Args:
		obj: Object to query
		
	Returns:
		Collision group ID (0 = no group restrictions)
	"""
	var object_id: int = obj.get_instance_id()
	return object_collision_groups.get(object_id, 0)

func remove_object_from_collision_groups(obj: Node3D) -> void:
	"""Remove object from all collision groups.
	
	Args:
		obj: Object to remove from groups
	"""
	var object_id: int = obj.get_instance_id()
	
	if object_id in object_collision_groups:
		var group_id: int = object_collision_groups[object_id]
		if group_id in collision_groups:
			collision_groups[group_id].erase(obj)
		object_collision_groups.erase(object_id)
	
	print("CollisionFilter: Removed object %s from collision groups" % obj.name)

## Parent-child relationship management
func set_parent_child_relationship(child: Node3D, parent: Node3D) -> void:
	"""Set parent-child relationship for collision filtering.
	
	Args:
		child: Child object
		parent: Parent object
	"""
	var child_id: int = child.get_instance_id()
	var parent_id: int = parent.get_instance_id()
	
	parent_child_relationships[child_id] = parent_id
	
	# Set signatures for WCS-style tracking
	if parent.has_method("get_signature"):
		object_signatures[child_id] = parent.get_signature()
	
	print("CollisionFilter: Set parent-child relationship: %s -> %s" % [child.name, parent.name])

func remove_parent_child_relationship(child: Node3D) -> void:
	"""Remove parent-child relationship for an object.
	
	Args:
		child: Child object to remove relationship for
	"""
	var child_id: int = child.get_instance_id()
	
	parent_child_relationships.erase(child_id)
	object_signatures.erase(child_id)
	
	print("CollisionFilter: Removed parent-child relationship for %s" % child.name)

## Collision type matrix management
func add_collision_type_rule(type_a: ObjectTypes.Type, type_b: ObjectTypes.Type) -> void:
	"""Add collision rule allowing two object types to collide.
	
	Args:
		type_a: First object type
		type_b: Second object type
	"""
	if not type_a in collision_type_matrix:
		collision_type_matrix[type_a] = []
	if not type_b in collision_type_matrix:
		collision_type_matrix[type_b] = []
	
	if not type_b in collision_type_matrix[type_a]:
		collision_type_matrix[type_a].append(type_b)
	if not type_a in collision_type_matrix[type_b]:
		collision_type_matrix[type_b].append(type_a)
	
	print("CollisionFilter: Added collision rule: %s <-> %s" % [type_a, type_b])

func remove_collision_type_rule(type_a: ObjectTypes.Type, type_b: ObjectTypes.Type) -> void:
	"""Remove collision rule between two object types.
	
	Args:
		type_a: First object type
		type_b: Second object type
	"""
	if type_a in collision_type_matrix:
		collision_type_matrix[type_a].erase(type_b)
	if type_b in collision_type_matrix:
		collision_type_matrix[type_b].erase(type_a)
	
	print("CollisionFilter: Removed collision rule: %s <-> %s" % [type_a, type_b])

## Performance and statistics
func _record_filter_applied(filter_type: String) -> void:
	"""Record that a filter was applied for statistics tracking."""
	filters_applied_this_frame += 1
	filter_statistics.total_filtered += 1
	
	match filter_type:
		"parent_child":
			filter_statistics.parent_child_filtered += 1
		"collision_group":
			filter_statistics.collision_group_filtered += 1
		"distance_filtered":
			filter_statistics.distance_filtered += 1
		"type_filtered":
			filter_statistics.type_filtered += 1
	
	filter_rule_applied.emit(filter_type, 1)

func get_filter_statistics() -> Dictionary:
	"""Get collision filtering statistics.
	
	Returns:
		Dictionary containing filter performance data
	"""
	return filter_statistics.duplicate()

func reset_filter_statistics() -> void:
	"""Reset filtering statistics."""
	filter_statistics = {
		"parent_child_filtered": 0,
		"collision_group_filtered": 0,
		"distance_filtered": 0,
		"type_filtered": 0,
		"total_filtered": 0
	}
	
	print("CollisionFilter: Filter statistics reset")

## Configuration functions
func set_max_collision_distance(distance: float) -> void:
	"""Set maximum distance for collision consideration.
	
	Args:
		distance: Maximum collision distance in world units
	"""
	max_collision_distance = distance
	print("CollisionFilter: Maximum collision distance set to %.1f" % distance)

func set_parent_child_filtering_enabled(enabled: bool) -> void:
	"""Enable or disable parent-child collision filtering.
	
	Args:
		enabled: true to enable parent-child filtering
	"""
	enable_parent_child_filtering = enabled
	print("CollisionFilter: Parent-child filtering %s" % ("enabled" if enabled else "disabled"))

func set_collision_group_filtering_enabled(enabled: bool) -> void:
	"""Enable or disable collision group filtering.
	
	Args:
		enabled: true to enable collision group filtering
	"""
	enable_collision_group_filtering = enabled
	print("CollisionFilter: Collision group filtering %s" % ("enabled" if enabled else "disabled"))

func set_type_filtering_enabled(enabled: bool) -> void:
	"""Enable or disable object type filtering.
	
	Args:
		enabled: true to enable type filtering
	"""
	enable_type_filtering = enabled
	print("CollisionFilter: Type filtering %s" % ("enabled" if enabled else "disabled"))

func set_distance_filtering_enabled(enabled: bool) -> void:
	"""Enable or disable distance-based filtering.
	
	Args:
		enabled: true to enable distance filtering
	"""
	enable_distance_filtering = enabled
	print("CollisionFilter: Distance filtering %s" % ("enabled" if enabled else "disabled"))