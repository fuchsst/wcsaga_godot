class_name ObjectValidator
extends Node

## Object validation system for detecting state corruption, invalid configurations,
## and system consistency issues in the WCS-Godot object framework.
## Provides comprehensive validation rules based on WCS object system requirements.

# EPIC-002 Asset Core Integration
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

signal validation_started()
signal validation_completed(results: Dictionary)
signal critical_error_detected(object: BaseSpaceObject, error_type: String, details: Dictionary)
signal warning_detected(object: BaseSpaceObject, warning_type: String, details: Dictionary)

# Validation configuration
@export var auto_validation_enabled: bool = true
@export var validation_interval: float = 5.0  # Auto-validation every 5 seconds
@export var critical_validation_enabled: bool = true
@export var performance_validation_enabled: bool = true
@export var strict_validation_mode: bool = false  # More rigorous validation

# Validation rules configuration
@export var max_velocity_threshold: float = 2000.0  # Maximum allowed velocity
@export var max_angular_velocity_threshold: float = 50.0  # Maximum angular velocity
@export var min_mass_threshold: float = 0.1  # Minimum object mass
@export var max_mass_threshold: float = 100000.0  # Maximum object mass
@export var max_children_warning: int = 50  # Child count warning threshold
@export var memory_usage_warning_mb: float = 10.0  # Per-object memory warning

# Validation statistics
var total_validations_performed: int = 0
var total_errors_found: int = 0
var total_warnings_found: int = 0
var validation_performance_ms: Array[float] = []

# Validation timer
var validation_timer: float = 0.0

# System references
var object_manager: ObjectManager
var physics_manager: PhysicsManager

func _ready() -> void:
	_find_system_references()
	set_process(auto_validation_enabled)
	print("ObjectValidator: Object validation system initialized")

func _process(delta: float) -> void:
	"""Perform automatic validation at intervals."""
	if not auto_validation_enabled:
		return
	
	validation_timer += delta
	if validation_timer >= validation_interval:
		perform_automatic_validation()
		validation_timer = 0.0

## Public Validation API (AC2)

func validate_object(object: BaseSpaceObject) -> Dictionary:
	"""Perform comprehensive validation of a single object.
	
	Args:
		object: BaseSpaceObject to validate
		
	Returns:
		Dictionary containing validation results and detected issues
	"""
	if not is_instance_valid(object):
		return _create_error_result("invalid_object", null, {"message": "Object reference is invalid"})
	
	var start_time: float = Time.get_time_dict_from_system()["second"]
	var results: Dictionary = _create_validation_results(object.name)
	
	# Perform different validation categories
	_validate_object_references(object, results)
	_validate_object_state(object, results)
	_validate_object_physics(object, results)
	_validate_object_collision(object, results)
	_validate_object_hierarchy(object, results)
	_validate_object_performance(object, results)
	_validate_object_consistency(object, results)
	
	# Record performance
	var end_time: float = Time.get_time_dict_from_system()["second"]
	var validation_time: float = (end_time - start_time) * 1000.0  # Convert to milliseconds
	results.validation_time_ms = validation_time
	
	_record_validation_performance(validation_time)
	_process_validation_results(object, results)
	
	return results

func validate_object_collection(objects: Array[BaseSpaceObject]) -> Dictionary:
	"""Validate a collection of objects and check inter-object relationships.
	
	Args:
		objects: Array of BaseSpaceObject instances to validate
		
	Returns:
		Dictionary containing collection validation results
	"""
	validation_started.emit()
	
	var collection_results: Dictionary = {
		"timestamp": Time.get_time_dict_from_system(),
		"total_objects": objects.size(),
		"individual_results": [],
		"collection_errors": [],
		"collection_warnings": [],
		"relationships": {},
		"summary": {}
	}
	
	# Validate individual objects
	for object in objects:
		if is_instance_valid(object):
			var individual_result: Dictionary = validate_object(object)
			collection_results.individual_results.append(individual_result)
	
	# Validate inter-object relationships
	_validate_object_relationships(objects, collection_results)
	_validate_id_uniqueness(objects, collection_results)
	_validate_parent_child_consistency(objects, collection_results)
	
	# Generate summary
	_generate_collection_summary(collection_results)
	
	validation_completed.emit(collection_results)
	total_validations_performed += 1
	
	return collection_results

func check_object_state_corruption(object: BaseSpaceObject) -> Dictionary:
	"""Check for state corruption in an object.
	
	Args:
		object: BaseSpaceObject to check for corruption
		
	Returns:
		Dictionary containing corruption detection results
	"""
	var corruption_results: Dictionary = {
		"object_name": object.name if object else "unknown",
		"has_corruption": false,
		"corruption_types": [],
		"corruption_details": []
	}
	
	if not is_instance_valid(object):
		corruption_results.has_corruption = true
		corruption_results.corruption_types.append("invalid_reference")
		corruption_results.corruption_details.append({"type": "invalid_reference", "message": "Object reference is invalid"})
		return corruption_results
	
	# Check for NaN values in transforms
	if _has_nan_in_transform(object):
		corruption_results.has_corruption = true
		corruption_results.corruption_types.append("nan_transform")
		corruption_results.corruption_details.append({
			"type": "nan_transform",
			"position": object.global_position,
			"rotation": object.global_rotation
		})
	
	# Check for physics corruption
	if object is RigidBody3D:
		var physics_corruption: Dictionary = _check_physics_corruption(object as RigidBody3D)
		if physics_corruption.has_corruption:
			corruption_results.has_corruption = true
			corruption_results.corruption_types.append_array(physics_corruption.corruption_types)
			corruption_results.corruption_details.append_array(physics_corruption.corruption_details)
	
	# Check for node hierarchy corruption
	var hierarchy_corruption: Dictionary = _check_hierarchy_corruption(object)
	if hierarchy_corruption.has_corruption:
		corruption_results.has_corruption = true
		corruption_results.corruption_types.append_array(hierarchy_corruption.corruption_types)
		corruption_results.corruption_details.append_array(hierarchy_corruption.corruption_details)
	
	return corruption_results

func check_system_consistency() -> Dictionary:
	"""Check overall system consistency across all managers.
	
	Returns:
		Dictionary containing system consistency validation results
	"""
	var consistency_results: Dictionary = {
		"timestamp": Time.get_time_dict_from_system(),
		"systems_checked": [],
		"consistency_errors": [],
		"consistency_warnings": [],
		"overall_status": "unknown"
	}
	
	# Check ObjectManager consistency
	if object_manager:
		_validate_object_manager_consistency(consistency_results)
	
	# Check PhysicsManager consistency
	if physics_manager:
		_validate_physics_manager_consistency(consistency_results)
	
	# Determine overall status
	if consistency_results.consistency_errors.size() > 0:
		consistency_results.overall_status = "critical"
	elif consistency_results.consistency_warnings.size() > 0:
		consistency_results.overall_status = "warning"
	else:
		consistency_results.overall_status = "healthy"
	
	return consistency_results

func get_validation_statistics() -> Dictionary:
	"""Get comprehensive validation system statistics.
	
	Returns:
		Dictionary containing validation system performance metrics
	"""
	var average_validation_time: float = 0.0
	if validation_performance_ms.size() > 0:
		var total: float = 0.0
		for time in validation_performance_ms:
			total += time
		average_validation_time = total / validation_performance_ms.size()
	
	return {
		"total_validations": total_validations_performed,
		"total_errors": total_errors_found,
		"total_warnings": total_warnings_found,
		"average_validation_time_ms": average_validation_time,
		"auto_validation_enabled": auto_validation_enabled,
		"validation_interval": validation_interval,
		"performance_history_count": validation_performance_ms.size()
	}

func perform_automatic_validation() -> void:
	"""Perform automatic validation of all registered objects."""
	if not object_manager:
		return
	
	var registered_objects: Array[BaseSpaceObject] = []
	
	# Get objects from ObjectManager (assuming it has a method to get all objects)
	if object_manager.has_method("get_all_space_objects"):
		registered_objects = object_manager.get_all_space_objects()
	
	if registered_objects.size() > 0:
		validate_object_collection(registered_objects)
		print("ObjectValidator: Automatic validation completed - %d objects checked" % registered_objects.size())

# Private validation implementation

func _create_validation_results(object_name: String) -> Dictionary:
	"""Create a new validation results dictionary."""
	return {
		"object_name": object_name,
		"timestamp": Time.get_time_dict_from_system(),
		"errors": [],
		"warnings": [],
		"performance_issues": [],
		"validation_time_ms": 0.0,
		"status": "unknown"
	}

func _create_error_result(error_type: String, object: BaseSpaceObject, details: Dictionary) -> Dictionary:
	"""Create an error validation result."""
	var result: Dictionary = _create_validation_results(object.name if object else "unknown")
	result.errors.append({
		"type": error_type,
		"details": details,
		"timestamp": Time.get_time_dict_from_system()
	})
	result.status = "error"
	return result

func _validate_object_references(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object references and required components."""
	# Check for required methods
	var required_methods: Array[String] = ["get_object_type", "_ready"]
	for method in required_methods:
		if not object.has_method(method):
			_add_error(results, "missing_method", {"method": method})
	
	# Check for required properties
	if not object.has_method("get_object_id") and not object.get("object_id"):
		_add_warning(results, "missing_object_id", {"message": "Object lacks unique ID"})

func _validate_object_state(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object state consistency."""
	# Check position validity
	if _has_nan_in_vector(object.global_position):
		_add_error(results, "invalid_position", {"position": object.global_position})
	
	# Check scale validity
	if object.scale.x <= 0 or object.scale.y <= 0 or object.scale.z <= 0:
		_add_error(results, "invalid_scale", {"scale": object.scale})
	
	# Check if object is queued for deletion
	if object.is_queued_for_deletion():
		_add_warning(results, "queued_for_deletion", {"message": "Object is queued for deletion"})

func _validate_object_physics(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object physics state."""
	if not (object is RigidBody3D or object is CharacterBody3D):
		return  # Skip non-physics objects
	
	if object is RigidBody3D:
		var body: RigidBody3D = object as RigidBody3D
		
		# Check velocity limits
		if body.linear_velocity.length() > max_velocity_threshold:
			_add_warning(results, "excessive_velocity", {
				"velocity": body.linear_velocity.length(),
				"threshold": max_velocity_threshold
			})
		
		# Check angular velocity limits
		if body.angular_velocity.length() > max_angular_velocity_threshold:
			_add_warning(results, "excessive_angular_velocity", {
				"angular_velocity": body.angular_velocity.length(),
				"threshold": max_angular_velocity_threshold
			})
		
		# Check mass validity
		if body.mass < min_mass_threshold or body.mass > max_mass_threshold:
			_add_warning(results, "invalid_mass", {
				"mass": body.mass,
				"min_threshold": min_mass_threshold,
				"max_threshold": max_mass_threshold
			})
		
		# Check for NaN values in physics
		if _has_nan_in_vector(body.linear_velocity) or _has_nan_in_vector(body.angular_velocity):
			_add_error(results, "nan_physics_values", {
				"linear_velocity": body.linear_velocity,
				"angular_velocity": body.angular_velocity
			})

func _validate_object_collision(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object collision configuration."""
	if not (object is CollisionObject3D):
		return  # Skip non-collision objects
	
	var collision_obj: CollisionObject3D = object as CollisionObject3D
	
	# Check for collision shapes
	var shape_owners: Array[int] = collision_obj.get_shape_owners()
	if shape_owners.size() == 0:
		_add_warning(results, "no_collision_shapes", {"message": "Object has no collision shapes"})
	
	# Validate collision layers
	if collision_obj.collision_layer == 0 and collision_obj.collision_mask == 0:
		_add_warning(results, "no_collision_layers", {
			"message": "Object has no collision layers or mask set"
		})

func _validate_object_hierarchy(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object node hierarchy."""
	# Check child count
	var child_count: int = object.get_child_count()
	if child_count > max_children_warning:
		_add_warning(results, "excessive_children", {
			"child_count": child_count,
			"threshold": max_children_warning
		})
	
	# Check for orphaned objects
	if not object.get_parent() and object != get_tree().root:
		_add_warning(results, "orphaned_object", {"message": "Object has no parent"})
	
	# Check for circular references in hierarchy
	if _has_circular_reference(object):
		_add_error(results, "circular_reference", {"message": "Circular reference detected in hierarchy"})

func _validate_object_performance(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object performance characteristics."""
	if not performance_validation_enabled:
		return
	
	# Estimate memory usage (simplified)
	var estimated_memory: float = _estimate_object_memory_usage(object)
	if estimated_memory > memory_usage_warning_mb:
		_add_warning(results, "high_memory_usage", {
			"estimated_mb": estimated_memory,
			"threshold_mb": memory_usage_warning_mb
		})
	
	# Check process mode
	if object.process_mode == Node.PROCESS_MODE_ALWAYS:
		_add_warning(results, "always_process_mode", {
			"message": "Object uses PROCESS_MODE_ALWAYS which may impact performance"
		})

func _validate_object_consistency(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Validate object internal consistency."""
	# Check object type consistency
	if object.has_method("get_object_type"):
		var object_type: int = object.get_object_type()
		if not ObjectTypes.is_valid_type(object_type):
			_add_error(results, "invalid_object_type", {
				"object_type": object_type,
				"message": "Object type is not valid"
			})

func _validate_object_relationships(objects: Array[BaseSpaceObject], results: Dictionary) -> void:
	"""Validate relationships between objects."""
	var parent_child_map: Dictionary = {}
	
	for object in objects:
		if not is_instance_valid(object):
			continue
		
		var parent: Node = object.get_parent()
		if parent and parent is BaseSpaceObject:
			var parent_obj: BaseSpaceObject = parent as BaseSpaceObject
			if parent_obj not in parent_child_map:
				parent_child_map[parent_obj] = []
			parent_child_map[parent_obj].append(object)
	
	results.relationships = parent_child_map

func _validate_id_uniqueness(objects: Array[BaseSpaceObject], results: Dictionary) -> void:
	"""Validate that object IDs are unique."""
	var id_map: Dictionary = {}
	
	for object in objects:
		if not is_instance_valid(object):
			continue
		
		var object_id: int = -1
		if object.has_method("get_object_id"):
			object_id = object.get_object_id()
		elif object.get("object_id") != null:
			object_id = object.get("object_id")
		
		if object_id >= 0:
			if object_id in id_map:
				_add_collection_error(results, "duplicate_object_id", {
					"object_id": object_id,
					"objects": [id_map[object_id].name, object.name]
				})
			else:
				id_map[object_id] = object

func _validate_parent_child_consistency(objects: Array[BaseSpaceObject], results: Dictionary) -> void:
	"""Validate parent-child relationship consistency."""
	for object in objects:
		if not is_instance_valid(object):
			continue
		
		var parent: Node = object.get_parent()
		if parent and parent is BaseSpaceObject:
			var parent_obj: BaseSpaceObject = parent as BaseSpaceObject
			if parent_obj not in objects:
				_add_collection_warning(results, "parent_not_in_collection", {
					"child": object.name,
					"parent": parent_obj.name
				})

func _has_nan_in_transform(object: BaseSpaceObject) -> bool:
	"""Check if object has NaN values in its transform."""
	return _has_nan_in_vector(object.global_position) or _has_nan_in_vector(object.global_rotation)

func _has_nan_in_vector(vector: Vector3) -> bool:
	"""Check if a Vector3 contains NaN values."""
	return is_nan(vector.x) or is_nan(vector.y) or is_nan(vector.z)

func _check_physics_corruption(body: RigidBody3D) -> Dictionary:
	"""Check for physics-related corruption."""
	var corruption_result: Dictionary = {
		"has_corruption": false,
		"corruption_types": [],
		"corruption_details": []
	}
	
	# Check for infinite values
	if is_inf(body.mass) or body.mass <= 0:
		corruption_result.has_corruption = true
		corruption_result.corruption_types.append("invalid_mass")
		corruption_result.corruption_details.append({"type": "invalid_mass", "mass": body.mass})
	
	# Check for extreme velocities that might indicate corruption
	if body.linear_velocity.length() > 10000.0:  # Extreme velocity threshold
		corruption_result.has_corruption = true
		corruption_result.corruption_types.append("extreme_velocity")
		corruption_result.corruption_details.append({
			"type": "extreme_velocity",
			"velocity": body.linear_velocity.length()
		})
	
	return corruption_result

func _check_hierarchy_corruption(object: BaseSpaceObject) -> Dictionary:
	"""Check for node hierarchy corruption."""
	var corruption_result: Dictionary = {
		"has_corruption": false,
		"corruption_types": [],
		"corruption_details": []
	}
	
	# Check for excessive depth
	var depth: int = _calculate_node_depth(object)
	if depth > 20:  # Arbitrary deep hierarchy threshold
		corruption_result.has_corruption = true
		corruption_result.corruption_types.append("excessive_depth")
		corruption_result.corruption_details.append({"type": "excessive_depth", "depth": depth})
	
	return corruption_result

func _has_circular_reference(object: BaseSpaceObject) -> bool:
	"""Check for circular references in the node hierarchy."""
	var visited: Array[Node] = []
	var current: Node = object
	
	while current:
		if current in visited:
			return true
		visited.append(current)
		current = current.get_parent()
	
	return false

func _calculate_node_depth(object: BaseSpaceObject) -> int:
	"""Calculate the depth of a node in the scene tree."""
	var depth: int = 0
	var current: Node = object
	
	while current and current.get_parent():
		depth += 1
		current = current.get_parent()
	
	return depth

func _estimate_object_memory_usage(object: BaseSpaceObject) -> float:
	"""Estimate memory usage of an object in MB (simplified)."""
	# This is a simplified estimation
	var base_size: float = 0.1  # Base object size in MB
	var child_count_factor: float = object.get_child_count() * 0.01
	
	# Add size for physics bodies
	if object is RigidBody3D:
		base_size += 0.05
	
	# Add size for collision shapes
	if object is CollisionObject3D:
		var collision_obj: CollisionObject3D = object as CollisionObject3D
		base_size += collision_obj.get_shape_owners().size() * 0.02
	
	return base_size + child_count_factor

func _validate_object_manager_consistency(results: Dictionary) -> void:
	"""Validate ObjectManager consistency."""
	results.systems_checked.append("ObjectManager")
	
	# Check if ObjectManager exists and is functional
	if not object_manager.has_method("get_object_count"):
		_add_consistency_error(results, "object_manager_missing_methods", {
			"message": "ObjectManager missing required methods"
		})

func _validate_physics_manager_consistency(results: Dictionary) -> void:
	"""Validate PhysicsManager consistency."""
	results.systems_checked.append("PhysicsManager")
	
	# Check if PhysicsManager exists and is functional
	if not physics_manager.has_method("get_physics_object_count"):
		_add_consistency_error(results, "physics_manager_missing_methods", {
			"message": "PhysicsManager missing required methods"
		})

func _add_error(results: Dictionary, error_type: String, details: Dictionary) -> void:
	"""Add an error to validation results."""
	results.errors.append({
		"type": error_type,
		"details": details,
		"timestamp": Time.get_time_dict_from_system()
	})
	total_errors_found += 1

func _add_warning(results: Dictionary, warning_type: String, details: Dictionary) -> void:
	"""Add a warning to validation results."""
	results.warnings.append({
		"type": warning_type,
		"details": details,
		"timestamp": Time.get_time_dict_from_system()
	})
	total_warnings_found += 1

func _add_collection_error(results: Dictionary, error_type: String, details: Dictionary) -> void:
	"""Add an error to collection validation results."""
	results.collection_errors.append({
		"type": error_type,
		"details": details,
		"timestamp": Time.get_time_dict_from_system()
	})

func _add_collection_warning(results: Dictionary, warning_type: String, details: Dictionary) -> void:
	"""Add a warning to collection validation results."""
	results.collection_warnings.append({
		"type": warning_type,
		"details": details,
		"timestamp": Time.get_time_dict_from_system()
	})

func _add_consistency_error(results: Dictionary, error_type: String, details: Dictionary) -> void:
	"""Add a consistency error to results."""
	results.consistency_errors.append({
		"type": error_type,
		"details": details,
		"timestamp": Time.get_time_dict_from_system()
	})

func _generate_collection_summary(results: Dictionary) -> void:
	"""Generate summary statistics for collection validation."""
	var total_errors: int = 0
	var total_warnings: int = 0
	
	for individual_result in results.individual_results:
		total_errors += individual_result.errors.size()
		total_warnings += individual_result.warnings.size()
	
	total_errors += results.collection_errors.size()
	total_warnings += results.collection_warnings.size()
	
	results.summary = {
		"total_errors": total_errors,
		"total_warnings": total_warnings,
		"objects_with_errors": 0,
		"objects_with_warnings": 0,
		"overall_status": "healthy"
	}
	
	# Count objects with issues
	for individual_result in results.individual_results:
		if individual_result.errors.size() > 0:
			results.summary.objects_with_errors += 1
		if individual_result.warnings.size() > 0:
			results.summary.objects_with_warnings += 1
	
	# Determine overall status
	if total_errors > 0:
		results.summary.overall_status = "critical"
	elif total_warnings > 0:
		results.summary.overall_status = "warning"

func _process_validation_results(object: BaseSpaceObject, results: Dictionary) -> void:
	"""Process validation results and emit appropriate signals."""
	# Determine status
	if results.errors.size() > 0:
		results.status = "error"
	elif results.warnings.size() > 0:
		results.status = "warning"
	else:
		results.status = "healthy"
	
	# Emit signals for errors and warnings
	for error in results.errors:
		critical_error_detected.emit(object, error.type, error.details)
	
	for warning in results.warnings:
		warning_detected.emit(object, warning.type, warning.details)

func _record_validation_performance(validation_time_ms: float) -> void:
	"""Record validation performance for statistics."""
	validation_performance_ms.append(validation_time_ms)
	
	# Keep only the last 100 samples
	if validation_performance_ms.size() > 100:
		validation_performance_ms.pop_front()

func _find_system_references() -> void:
	"""Find references to system components."""
	object_manager = get_node_or_null("/root/ObjectManager")
	physics_manager = get_node_or_null("/root/PhysicsManager")
	
	if not object_manager:
		push_warning("ObjectValidator: ObjectManager not found")
	if not physics_manager:
		push_warning("ObjectValidator: PhysicsManager not found")