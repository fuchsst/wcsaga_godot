class_name ObjectSerialization
extends RefCounted

## Comprehensive object serialization and persistence system for BaseSpaceObject
## Handles save/load operations with validation, versioning, and relationship management
## Integrates with SaveGameManager for save game compatibility

# Asset core integration for typing and validation
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ValidationResult = preload("res://addons/wcs_asset_core/structures/validation_result.gd")

# Serialization versioning and compatibility
const SERIALIZATION_VERSION: int = 1
const MIN_SUPPORTED_VERSION: int = 1
const MAX_SUPPORTED_VERSION: int = 1

# Performance targets (OBJ-004 AC requirements)
const SERIALIZATION_TARGET_MS: float = 2.0  # Under 2ms per object
const DESERIALIZATION_TARGET_MS: float = 5.0  # Under 5ms per object

# Object state categories for incremental saves
enum StateCategory {
	CRITICAL,      # Position, health, core properties
	PHYSICS,       # Velocity, acceleration, forces 
	RELATIONSHIPS, # Object references and connections
	METADATA,      # Non-critical data, custom properties
	VISUAL         # Visual state, effects, animations
}

# Serialization options and control
static var incremental_saves_enabled: bool = true
static var relationship_serialization_enabled: bool = true
static var validation_enabled: bool = true
static var compression_enabled: bool = false

# Object relationship tracking for proper restoration
static var _object_relationships: Dictionary = {}
static var _serialization_cache: Dictionary = {}
static var _performance_stats: Dictionary = {}

## Serialize BaseSpaceObject to dictionary format (AC1: Capture all essential state)
static func serialize_space_object(space_object: BaseSpaceObject, options: Dictionary = {}) -> Dictionary:
	if not space_object:
		push_error("ObjectSerialization: Cannot serialize null space object")
		return {}
	
	var start_time: int = Time.get_ticks_msec()
	var serialized_data: Dictionary = {}
	
	# Core serialization version and metadata
	serialized_data["serialization_version"] = SERIALIZATION_VERSION
	serialized_data["serialized_timestamp"] = Time.get_unix_time_from_system()
	serialized_data["object_class"] = space_object.get_script().resource_path if space_object.get_script() else ""
	
	# Critical state (always serialized) - AC1
	serialized_data["critical"] = _serialize_critical_state(space_object)
	
	# Physics state (always serialized) - AC1  
	serialized_data["physics"] = _serialize_physics_state(space_object)
	
	# Object relationships (AC2: Handle relationships and references)
	if relationship_serialization_enabled and options.get("include_relationships", true):
		serialized_data["relationships"] = _serialize_object_relationships(space_object)
	
	# Metadata and custom properties
	serialized_data["metadata"] = _serialize_metadata_state(space_object)
	
	# Visual state (optional for performance)
	if options.get("include_visual_state", false):
		serialized_data["visual"] = _serialize_visual_state(space_object)
	
	# Incremental save support (AC4: Only changed objects)
	if incremental_saves_enabled:
		serialized_data["state_hash"] = _calculate_object_state_hash(space_object)
		serialized_data["last_modified"] = space_object.get("last_modified_time") if "last_modified_time" in space_object else 0
	
	# Performance tracking
	var duration: float = float(Time.get_ticks_msec() - start_time)
	_update_serialization_performance(duration)
	
	if duration > SERIALIZATION_TARGET_MS:
		push_warning("ObjectSerialization: Slow serialization %.2fms (target: %.2fms)" % [duration, SERIALIZATION_TARGET_MS])
	
	return serialized_data

## Deserialize dictionary to BaseSpaceObject (AC3: Recreate with identical state)
static func deserialize_space_object(serialized_data: Dictionary, parent_node: Node = null) -> BaseSpaceObject:
	if serialized_data.is_empty():
		push_error("ObjectSerialization: Cannot deserialize empty data")
		return null
	
	var start_time: int = Time.get_ticks_msec()
	
	# Version compatibility check (AC5: Version compatibility)
	if not _validate_serialization_version(serialized_data):
		return null
	
	# Data integrity validation (AC5: Data integrity)
	if validation_enabled:
		var validation_result: ValidationResult = _validate_serialized_data(serialized_data)
		if not validation_result.is_valid:
			push_error("ObjectSerialization: Data validation failed: %s" % str(validation_result.errors))
			return null
	
	# Create object instance
	var space_object: BaseSpaceObject = _create_space_object_instance(serialized_data)
	if not space_object:
		push_error("ObjectSerialization: Failed to create space object instance")
		return null
	
	# Restore critical state
	if serialized_data.has("critical"):
		_restore_critical_state(space_object, serialized_data["critical"])
	
	# Restore physics state
	if serialized_data.has("physics"):
		_restore_physics_state(space_object, serialized_data["physics"])
	
	# Restore metadata
	if serialized_data.has("metadata"):
		_restore_metadata_state(space_object, serialized_data["metadata"])
	
	# Restore visual state if present
	if serialized_data.has("visual"):
		_restore_visual_state(space_object, serialized_data["visual"])
	
	# Add to scene tree if parent provided (AC3: Scene tree integration)
	if parent_node:
		parent_node.add_child(space_object)
		space_object._ready()  # Ensure proper initialization
	
	# Restore object relationships (deferred to avoid circular dependencies)
	if serialized_data.has("relationships"):
		_defer_relationship_restoration(space_object, serialized_data["relationships"])
	
	# Performance tracking
	var duration: float = float(Time.get_ticks_msec() - start_time)
	_update_deserialization_performance(duration)
	
	if duration > DESERIALIZATION_TARGET_MS:
		push_warning("ObjectSerialization: Slow deserialization %.2fms (target: %.2fms)" % [duration, DESERIALIZATION_TARGET_MS])
	
	return space_object

## Serialize multiple objects with relationship preservation (AC2: Object relationships)
static func serialize_object_collection(objects: Array[BaseSpaceObject], options: Dictionary = {}) -> Dictionary:
	var collection_data: Dictionary = {
		"serialization_version": SERIALIZATION_VERSION,
		"collection_timestamp": Time.get_unix_time_from_system(),
		"object_count": objects.size(),
		"objects": [],
		"relationships": {}
	}
	
	# Clear relationship tracking
	_object_relationships.clear()
	
	# Serialize individual objects
	for i in range(objects.size()):
		var obj: BaseSpaceObject = objects[i]
		if obj:
			var obj_data: Dictionary = serialize_space_object(obj, options)
			obj_data["collection_index"] = i
			obj_data["object_id"] = obj.get_object_id()
			collection_data["objects"].append(obj_data)
	
	# Serialize collection-level relationships
	collection_data["relationships"] = _object_relationships.duplicate(true)
	
	return collection_data

## Deserialize multiple objects with relationship restoration (AC2: Object relationships)
static func deserialize_object_collection(collection_data: Dictionary, parent_node: Node = null) -> Array[BaseSpaceObject]:
	var objects: Array[BaseSpaceObject] = []
	
	if not collection_data.has("objects"):
		push_error("ObjectSerialization: Collection data missing objects array")
		return objects
	
	var objects_data: Array = collection_data["objects"]
	objects.resize(objects_data.size())
	
	# First pass: Create all objects
	for i in range(objects_data.size()):
		var obj_data: Dictionary = objects_data[i]
		var space_object: BaseSpaceObject = deserialize_space_object(obj_data, parent_node)
		if space_object:
			objects[i] = space_object
		else:
			push_warning("ObjectSerialization: Failed to deserialize object at index %d" % i)
	
	# Second pass: Restore relationships
	if collection_data.has("relationships"):
		_restore_collection_relationships(objects, collection_data["relationships"])
	
	return objects

## Check if object state has changed for incremental saves (AC4: Incremental saves)
static func has_object_changed(space_object: BaseSpaceObject, last_state_hash: String) -> bool:
	if not incremental_saves_enabled:
		return true  # Always serialize if incremental saves disabled
	
	var current_hash: String = _calculate_object_state_hash(space_object)
	return current_hash != last_state_hash

## Get objects that have changed since last save (AC4: Incremental saves)
static func get_changed_objects(objects: Array[BaseSpaceObject], last_save_data: Dictionary) -> Array[BaseSpaceObject]:
	var changed_objects: Array[BaseSpaceObject] = []
	
	if not incremental_saves_enabled or last_save_data.is_empty():
		return objects  # Return all objects if no incremental support
	
	var last_hashes: Dictionary = last_save_data.get("state_hashes", {})
	
	for obj in objects:
		if obj:
			var obj_id: String = str(obj.get_object_id())
			var last_hash: String = last_hashes.get(obj_id, "")
			
			if has_object_changed(obj, last_hash):
				changed_objects.append(obj)
	
	return changed_objects

## Validate serialized data integrity (AC5: Data integrity validation)
static func validate_serialized_data(serialized_data: Dictionary) -> ValidationResult:
	return _validate_serialized_data(serialized_data)

## Get serialization performance statistics
static func get_performance_statistics() -> Dictionary:
	return _performance_stats.duplicate(true)

## Reset performance statistics
static func reset_performance_statistics() -> void:
	_performance_stats = {
		"serialization": {
			"total_operations": 0,
			"total_time_ms": 0.0,
			"average_time_ms": 0.0,
			"min_time_ms": 999999.0,
			"max_time_ms": 0.0
		},
		"deserialization": {
			"total_operations": 0,
			"total_time_ms": 0.0,
			"average_time_ms": 0.0,
			"min_time_ms": 999999.0,
			"max_time_ms": 0.0
		}
	}

## Configure serialization options
static func configure_serialization(config: Dictionary) -> void:
	incremental_saves_enabled = config.get("incremental_saves", incremental_saves_enabled)
	relationship_serialization_enabled = config.get("relationships", relationship_serialization_enabled)
	validation_enabled = config.get("validation", validation_enabled)
	compression_enabled = config.get("compression", compression_enabled)

# --- Internal Helper Functions ---

## Serialize critical object state (position, health, type, etc.)
static func _serialize_critical_state(space_object: BaseSpaceObject) -> Dictionary:
	var critical_data: Dictionary = {}
	
	# Basic object properties from WCSObject
	critical_data["object_id"] = space_object.get_object_id()
	critical_data["object_type"] = space_object.get_object_type()
	critical_data["object_type_enum"] = space_object.object_type_enum
	critical_data["is_initialized"] = space_object.is_initialized
	critical_data["update_frequency"] = space_object.get_update_frequency()
	
	# Transform and spatial properties
	critical_data["global_position"] = var_to_str(space_object.global_position)
	critical_data["global_rotation"] = var_to_str(space_object.global_rotation)
	critical_data["global_scale"] = var_to_str(space_object.global_scale)
	
	# Space object specific properties
	if space_object.has_method("get_max_health"):
		critical_data["max_health"] = space_object.max_health if "max_health" in space_object else 100.0
		critical_data["current_health"] = space_object.current_health if "current_health" in space_object else critical_data["max_health"]
	
	critical_data["space_physics_enabled"] = space_object.space_physics_enabled
	critical_data["collision_detection_enabled"] = space_object.collision_detection_enabled
	critical_data["is_active"] = space_object.is_active
	critical_data["destruction_pending"] = space_object.destruction_pending
	
	# Asset integration data
	critical_data["collision_layer_bits"] = space_object.collision_layer_bits
	critical_data["collision_mask_bits"] = space_object.collision_mask_bits
	
	return critical_data

## Serialize physics state (velocity, forces, etc.)
static func _serialize_physics_state(space_object: BaseSpaceObject) -> Dictionary:
	var physics_data: Dictionary = {}
	
	# Physics state vectors
	physics_data["linear_velocity"] = var_to_str(space_object.linear_velocity)
	physics_data["angular_velocity"] = var_to_str(space_object.angular_velocity)
	
	# Applied forces and torques
	var forces_array: Array[String] = []
	for force in space_object.applied_forces:
		forces_array.append(var_to_str(force))
	physics_data["applied_forces"] = forces_array
	
	var torques_array: Array[String] = []
	for torque in space_object.applied_torques:
		torques_array.append(var_to_str(torque))
	physics_data["applied_torques"] = torques_array
	
	# Physics profile data (if available)
	if space_object.physics_profile:
		physics_data["has_physics_profile"] = true
		# Store physics profile as resource path for efficiency
		var profile_path: String = space_object.physics_profile.resource_path
		if not profile_path.is_empty():
			physics_data["physics_profile_path"] = profile_path
		else:
			# If no path, serialize profile data directly
			physics_data["physics_profile_data"] = _serialize_physics_profile(space_object.physics_profile)
	else:
		physics_data["has_physics_profile"] = false
	
	# RigidBody3D physics state (if available)
	if space_object.physics_body:
		physics_data["physics_body"] = _serialize_rigid_body_state(space_object.physics_body)
	
	return physics_data

## Serialize object relationships and references (AC2)
static func _serialize_object_relationships(space_object: BaseSpaceObject) -> Dictionary:
	var relationships: Dictionary = {}
	var obj_id: String = str(space_object.get_object_id())
	
	# Track object relationships for collection serialization
	if not _object_relationships.has(obj_id):
		_object_relationships[obj_id] = {}
	
	# Serialize connected objects (if any signal connections exist)
	var connected_objects: Array[String] = []
	# This would need specific implementation based on actual signal connections
	relationships["connected_objects"] = connected_objects
	
	# Parent-child relationships in scene tree
	var parent_info: Dictionary = {}
	if space_object.get_parent():
		var parent: Node = space_object.get_parent()
		if parent is BaseSpaceObject:
			parent_info["parent_object_id"] = parent.get_object_id()
			parent_info["parent_type"] = parent.get_object_type()
	relationships["parent_info"] = parent_info
	
	# Child relationships
	var children_info: Array[Dictionary] = []
	for child in space_object.get_children():
		if child is BaseSpaceObject:
			var child_info: Dictionary = {
				"child_object_id": child.get_object_id(),
				"child_type": child.get_object_type(),
				"child_index": child.get_index()
			}
			children_info.append(child_info)
	relationships["children_info"] = children_info
	
	# Store in global relationship tracking
	_object_relationships[obj_id] = relationships
	
	return relationships

## Serialize metadata and custom properties
static func _serialize_metadata_state(space_object: BaseSpaceObject) -> Dictionary:
	var metadata: Dictionary = {}
	
	# WCSObjectData if available
	if space_object.object_data:
		var data: WCSObjectData = space_object.object_data
		metadata["object_data"] = {
			"object_type": data.object_type,
			"mass": data.mass,
			"health": data.health,
			"position": var_to_str(data.position),
			"rotation": var_to_str(data.rotation),
			"velocity": var_to_str(data.velocity),
			"angular_velocity": var_to_str(data.angular_velocity),
			"custom_properties": data.custom_properties.duplicate(true),
			"ship_class": data.ship_class,
			"team": data.team,
			"arrival_condition": data.arrival_condition,
			"departure_condition": data.departure_condition,
			"ai_goals": data.ai_goals.duplicate(),
			"cargo": data.cargo
		}
	
	# Custom metadata properties
	if space_object.has_method("get_custom_metadata"):
		metadata["custom_metadata"] = space_object.get_custom_metadata()
	
	return metadata

## Serialize visual state (optional for performance)
static func _serialize_visual_state(space_object: BaseSpaceObject) -> Dictionary:
	var visual_data: Dictionary = {}
	
	# Visibility state
	visual_data["visible"] = space_object.visible
	visual_data["modulate"] = var_to_str(space_object.modulate)
	
	# Mesh and visual component states
	if space_object.mesh_instance:
		visual_data["mesh_instance"] = {
			"visible": space_object.mesh_instance.visible,
			"cast_shadow": space_object.mesh_instance.cast_shadow,
			"material_override_path": space_object.mesh_instance.material_override.resource_path if space_object.mesh_instance.material_override else ""
		}
	
	# Audio source state
	if space_object.audio_source:
		visual_data["audio_source"] = {
			"playing": space_object.audio_source.playing,
			"volume_db": space_object.audio_source.volume_db,
			"stream_path": space_object.audio_source.stream.resource_path if space_object.audio_source.stream else ""
		}
	
	return visual_data

## Calculate object state hash for incremental saves
static func _calculate_object_state_hash(space_object: BaseSpaceObject) -> String:
	var hash_data: String = ""
	
	# Include critical state in hash
	hash_data += str(space_object.global_position)
	hash_data += str(space_object.global_rotation)
	hash_data += str(space_object.linear_velocity)
	hash_data += str(space_object.angular_velocity)
	hash_data += str(space_object.is_active)
	
	if "current_health" in space_object:
		hash_data += str(space_object.current_health)
	
	# Generate hash
	return hash_data.sha256_text()

## Validate serialization version compatibility
static func _validate_serialization_version(serialized_data: Dictionary) -> bool:
	if not serialized_data.has("serialization_version"):
		push_error("ObjectSerialization: Missing serialization version")
		return false
	
	var version: int = serialized_data["serialization_version"]
	if version < MIN_SUPPORTED_VERSION or version > MAX_SUPPORTED_VERSION:
		push_error("ObjectSerialization: Unsupported serialization version %d (supported: %d-%d)" % [version, MIN_SUPPORTED_VERSION, MAX_SUPPORTED_VERSION])
		return false
	
	return true

## Validate serialized data structure and integrity
static func _validate_serialized_data(serialized_data: Dictionary) -> ValidationResult:
	var result: ValidationResult = ValidationResult.new("", "Object Serialization")
	
	# Check required fields
	var required_fields: Array[String] = ["serialization_version", "critical"]
	for field in required_fields:
		if not serialized_data.has(field):
			result.add_error("Missing required field: %s" % field)
	
	# Validate critical state
	if serialized_data.has("critical"):
		var critical: Dictionary = serialized_data["critical"]
		if not critical.has("object_id"):
			result.add_error("Critical state missing object_id")
		if not critical.has("object_type"):
			result.add_error("Critical state missing object_type")
		if not critical.has("global_position"):
			result.add_error("Critical state missing global_position")
	
	# Validate physics state if present
	if serialized_data.has("physics"):
		var physics: Dictionary = serialized_data["physics"]
		if not physics.has("linear_velocity"):
			result.add_warning("Physics state missing linear_velocity")
		if not physics.has("angular_velocity"):
			result.add_warning("Physics state missing angular_velocity")
	
	return result

## Create space object instance from serialized data
static func _create_space_object_instance(serialized_data: Dictionary) -> BaseSpaceObject:
	var space_object: BaseSpaceObject = null
	
	# Determine object creation method
	if serialized_data.has("object_class") and not serialized_data["object_class"].is_empty():
		# Try to create from class path
		var script_path: String = serialized_data["object_class"]
		var script: Script = load(script_path)
		if script:
			space_object = script.new()
	
	# Fallback to default BaseSpaceObject
	if not space_object:
		space_object = BaseSpaceObject.new()
	
	return space_object

## Restore critical state to space object
static func _restore_critical_state(space_object: BaseSpaceObject, critical_data: Dictionary) -> void:
	# Basic object properties
	if critical_data.has("object_id"):
		space_object.set_object_id(critical_data["object_id"])
	
	if critical_data.has("object_type"):
		space_object.set_object_type(critical_data["object_type"])
	
	if critical_data.has("object_type_enum"):
		space_object.object_type_enum = critical_data["object_type_enum"]
	
	if critical_data.has("update_frequency"):
		space_object.set_update_frequency(critical_data["update_frequency"])
	
	# Transform properties
	if critical_data.has("global_position"):
		space_object.global_position = str_to_var(critical_data["global_position"])
	
	if critical_data.has("global_rotation"):
		space_object.global_rotation = str_to_var(critical_data["global_rotation"])
	
	if critical_data.has("global_scale"):
		var scale_value: Vector3 = str_to_var(critical_data["global_scale"])
		space_object.scale = scale_value
	
	# Health properties
	if critical_data.has("max_health") and "max_health" in space_object:
		space_object.max_health = critical_data["max_health"]
	
	if critical_data.has("current_health") and "current_health" in space_object:
		space_object.current_health = critical_data["current_health"]
	
	# Space object specific properties
	if critical_data.has("space_physics_enabled"):
		space_object.space_physics_enabled = critical_data["space_physics_enabled"]
	
	if critical_data.has("collision_detection_enabled"):
		space_object.collision_detection_enabled = critical_data["collision_detection_enabled"]
	
	if critical_data.has("is_active"):
		space_object.is_active = critical_data["is_active"]
	
	if critical_data.has("destruction_pending"):
		space_object.destruction_pending = critical_data["destruction_pending"]
	
	# Asset integration
	if critical_data.has("collision_layer_bits"):
		space_object.collision_layer_bits = critical_data["collision_layer_bits"]
	
	if critical_data.has("collision_mask_bits"):
		space_object.collision_mask_bits = critical_data["collision_mask_bits"]
	
	# Mark as initialized
	if critical_data.has("is_initialized"):
		space_object.is_initialized = critical_data["is_initialized"]

## Restore physics state to space object
static func _restore_physics_state(space_object: BaseSpaceObject, physics_data: Dictionary) -> void:
	# Velocity vectors
	if physics_data.has("linear_velocity"):
		space_object.linear_velocity = str_to_var(physics_data["linear_velocity"])
	
	if physics_data.has("angular_velocity"):
		space_object.angular_velocity = str_to_var(physics_data["angular_velocity"])
	
	# Applied forces
	if physics_data.has("applied_forces"):
		space_object.applied_forces.clear()
		var forces_array: Array = physics_data["applied_forces"]
		for force_str in forces_array:
			space_object.applied_forces.append(str_to_var(force_str))
	
	# Applied torques
	if physics_data.has("applied_torques"):
		space_object.applied_torques.clear()
		var torques_array: Array = physics_data["applied_torques"]
		for torque_str in torques_array:
			space_object.applied_torques.append(str_to_var(torque_str))
	
	# Physics profile restoration
	if physics_data.has("has_physics_profile") and physics_data["has_physics_profile"]:
		if physics_data.has("physics_profile_path"):
			# Load from resource path
			var profile_path: String = physics_data["physics_profile_path"]
			space_object.physics_profile = load(profile_path)
		elif physics_data.has("physics_profile_data"):
			# Restore from serialized data
			space_object.physics_profile = _deserialize_physics_profile(physics_data["physics_profile_data"])
	
	# RigidBody3D state restoration (deferred until after _ready)
	if physics_data.has("physics_body"):
		space_object.call_deferred("_restore_rigid_body_state", physics_data["physics_body"])

## Restore metadata state to space object
static func _restore_metadata_state(space_object: BaseSpaceObject, metadata: Dictionary) -> void:
	# WCSObjectData restoration
	if metadata.has("object_data"):
		var data_dict: Dictionary = metadata["object_data"]
		var object_data: WCSObjectData = WCSObjectData.new()
		
		object_data.object_type = data_dict.get("object_type", "")
		object_data.mass = data_dict.get("mass", 1.0)
		object_data.health = data_dict.get("health", 100.0)
		object_data.position = str_to_var(data_dict.get("position", "Vector3(0, 0, 0)"))
		object_data.rotation = str_to_var(data_dict.get("rotation", "Vector3(0, 0, 0)"))
		object_data.velocity = str_to_var(data_dict.get("velocity", "Vector3(0, 0, 0)"))
		object_data.angular_velocity = str_to_var(data_dict.get("angular_velocity", "Vector3(0, 0, 0)"))
		object_data.custom_properties = data_dict.get("custom_properties", {})
		object_data.ship_class = data_dict.get("ship_class", "")
		object_data.team = data_dict.get("team", "Friendly")
		object_data.arrival_condition = data_dict.get("arrival_condition", "(true)")
		object_data.departure_condition = data_dict.get("departure_condition", "(false)")
		object_data.ai_goals = data_dict.get("ai_goals", [])
		object_data.cargo = data_dict.get("cargo", "Nothing")
		
		space_object.object_data = object_data
	
	# Custom metadata restoration
	if metadata.has("custom_metadata") and space_object.has_method("set_custom_metadata"):
		space_object.set_custom_metadata(metadata["custom_metadata"])

## Restore visual state to space object
static func _restore_visual_state(space_object: BaseSpaceObject, visual_data: Dictionary) -> void:
	# Basic visibility
	if visual_data.has("visible"):
		space_object.visible = visual_data["visible"]
	
	if visual_data.has("modulate"):
		space_object.modulate = str_to_var(visual_data["modulate"])
	
	# Mesh instance state
	if visual_data.has("mesh_instance") and space_object.mesh_instance:
		var mesh_data: Dictionary = visual_data["mesh_instance"]
		space_object.mesh_instance.visible = mesh_data.get("visible", true)
		space_object.mesh_instance.cast_shadow = mesh_data.get("cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		
		var material_path: String = mesh_data.get("material_override_path", "")
		if not material_path.is_empty() and ResourceLoader.exists(material_path):
			space_object.mesh_instance.material_override = load(material_path)
	
	# Audio source state
	if visual_data.has("audio_source") and space_object.audio_source:
		var audio_data: Dictionary = visual_data["audio_source"]
		space_object.audio_source.volume_db = audio_data.get("volume_db", 0.0)
		
		var stream_path: String = audio_data.get("stream_path", "")
		if not stream_path.is_empty() and ResourceLoader.exists(stream_path):
			space_object.audio_source.stream = load(stream_path)
			
		if audio_data.get("playing", false):
			space_object.audio_source.play()

## Defer relationship restoration to avoid circular dependencies
static func _defer_relationship_restoration(space_object: BaseSpaceObject, relationships: Dictionary) -> void:
	# This would be implemented to restore object relationships after all objects are created
	# For now, store the relationship data for later processing
	var obj_id: String = str(space_object.get_object_id())
	_object_relationships[obj_id] = relationships

## Restore relationships for entire object collection
static func _restore_collection_relationships(objects: Array[BaseSpaceObject], relationships: Dictionary) -> void:
	# Implementation would restore parent-child relationships and signal connections
	# This is a complex operation that requires careful ordering to avoid issues
	pass

## Serialize physics profile to dictionary
static func _serialize_physics_profile(profile: PhysicsProfile) -> Dictionary:
	if not profile:
		return {}
	
	# This would serialize the physics profile properties
	# For now, return empty dictionary as fallback
	return {}

## Deserialize physics profile from dictionary
static func _deserialize_physics_profile(profile_data: Dictionary) -> PhysicsProfile:
	if profile_data.is_empty():
		return null
	
	# This would recreate a physics profile from the dictionary
	# For now, return null as fallback
	return null

## Serialize RigidBody3D state
static func _serialize_rigid_body_state(rigid_body: RigidBody3D) -> Dictionary:
	if not rigid_body:
		return {}
	
	return {
		"linear_velocity": var_to_str(rigid_body.linear_velocity),
		"angular_velocity": var_to_str(rigid_body.angular_velocity),
		"gravity_scale": rigid_body.gravity_scale,
		"linear_damp": rigid_body.linear_damp,
		"angular_damp": rigid_body.angular_damp,
		"collision_layer": rigid_body.collision_layer,
		"collision_mask": rigid_body.collision_mask,
		"freeze_mode": rigid_body.freeze_mode,
		"continuous_cd": rigid_body.continuous_cd,
		"max_contacts_reported": rigid_body.max_contacts_reported
	}

## Performance tracking for serialization operations
static func _update_serialization_performance(duration_ms: float) -> void:
	if not _performance_stats.has("serialization"):
		reset_performance_statistics()
	
	var stats: Dictionary = _performance_stats["serialization"]
	stats["total_operations"] += 1
	stats["total_time_ms"] += duration_ms
	stats["average_time_ms"] = stats["total_time_ms"] / stats["total_operations"]
	stats["min_time_ms"] = min(stats["min_time_ms"], duration_ms)
	stats["max_time_ms"] = max(stats["max_time_ms"], duration_ms)

## Performance tracking for deserialization operations
static func _update_deserialization_performance(duration_ms: float) -> void:
	if not _performance_stats.has("deserialization"):
		reset_performance_statistics()
	
	var stats: Dictionary = _performance_stats["deserialization"]
	stats["total_operations"] += 1
	stats["total_time_ms"] += duration_ms
	stats["average_time_ms"] = stats["total_time_ms"] / stats["total_operations"]
	stats["min_time_ms"] = min(stats["min_time_ms"], duration_ms)
	stats["max_time_ms"] = max(stats["max_time_ms"], duration_ms)

# Static initialization
static func _static_init() -> void:
	reset_performance_statistics()