class_name ModelCollisionGenerator
extends Node

## Collision shape generation system for BaseSpaceObject 3D models
## Generates collision shapes from EPIC-003 converted POF model mesh data
## Integrates with EPIC-009 collision system and BaseSpaceObject physics

# EPIC-002 Asset Core Integration
const ModelMetadata = preload("res://addons/wcs_asset_core/resources/object/model_metadata.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

# Collision Generation Signals (AC4)
signal collision_shape_generated(space_object: BaseSpaceObject, collision_shape: CollisionShape3D)
signal collision_generation_failed(space_object: BaseSpaceObject, error_message: String)
signal collision_shape_optimized(space_object: BaseSpaceObject, vertices_reduced: int)

# Collision shape types based on object requirements
enum CollisionShapeType {
	TRIMESH,        # Exact mesh collision (high accuracy, high cost)
	CONVEX_HULL,    # Convex approximation (good accuracy, medium cost)
	SPHERE,         # Simple sphere (low accuracy, low cost)
	CAPSULE,        # Capsule shape for elongated objects
	BOX,            # Bounding box approximation
	COMPOUND        # Multiple shapes for complex objects
}

# Performance settings for different object types
var _collision_type_config: Dictionary = {
	ObjectTypes.Type.SHIP: CollisionShapeType.CONVEX_HULL,
	ObjectTypes.Type.FIGHTER: CollisionShapeType.CONVEX_HULL,
	ObjectTypes.Type.CAPITAL: CollisionShapeType.TRIMESH,
	ObjectTypes.Type.WEAPON: CollisionShapeType.SPHERE,
	ObjectTypes.Type.DEBRIS: CollisionShapeType.CONVEX_HULL,
	ObjectTypes.Type.ASTEROID: CollisionShapeType.TRIMESH,
	ObjectTypes.Type.CARGO: CollisionShapeType.BOX,
	ObjectTypes.Type.WAYPOINT: CollisionShapeType.SPHERE
}

# Performance tracking
var _generation_times: Array[float] = []

func _ready() -> void:
	name = "ModelCollisionGenerator"

## Generate collision shape from 3D mesh data for BaseSpaceObject (AC4)
func generate_collision_shape_from_mesh(space_object: BaseSpaceObject, model_mesh: Mesh) -> bool:
	if not space_object or not model_mesh:
		push_error("ModelCollisionGenerator: Invalid parameters")
		return false
	
	if not space_object.collision_shape or not space_object.physics_body:
		push_error("ModelCollisionGenerator: BaseSpaceObject missing collision components")
		return false
	
	var start_time: int = Time.get_ticks_msec()
	
	# Determine collision shape type based on object type
	var object_type: int = space_object.get_meta("object_type_enum", ObjectTypes.Type.NONE)
	var shape_type: CollisionShapeType = _collision_type_config.get(object_type, CollisionShapeType.CONVEX_HULL)
	
	# Generate appropriate collision shape
	var collision_shape: Shape3D = null
	match shape_type:
		CollisionShapeType.TRIMESH:
			collision_shape = _generate_trimesh_collision(model_mesh)
		CollisionShapeType.CONVEX_HULL:
			collision_shape = _generate_convex_hull_collision(model_mesh)
		CollisionShapeType.SPHERE:
			collision_shape = _generate_sphere_collision(model_mesh)
		CollisionShapeType.CAPSULE:
			collision_shape = _generate_capsule_collision(model_mesh)
		CollisionShapeType.BOX:
			collision_shape = _generate_box_collision(model_mesh)
		CollisionShapeType.COMPOUND:
			collision_shape = _generate_compound_collision(space_object, model_mesh)
	
	if not collision_shape:
		var error_msg: String = "Failed to generate collision shape for %s" % space_object.name
		push_error("ModelCollisionGenerator: " + error_msg)
		collision_generation_failed.emit(space_object, error_msg)
		return false
	
	# Apply collision shape to space object
	space_object.collision_shape.shape = collision_shape
	
	# Set appropriate collision layers from EPIC-002 asset core
	_configure_collision_layers(space_object, object_type)
	
	# Track performance
	var generation_time: float = (Time.get_ticks_msec() - start_time) / 1000.0
	_generation_times.append(generation_time)
	if _generation_times.size() > 100:
		_generation_times.pop_front()
	
	collision_shape_generated.emit(space_object, space_object.collision_shape)
	return true

## Generate trimesh collision (exact mesh shape) for high-accuracy requirements
func _generate_trimesh_collision(model_mesh: Mesh) -> ConcavePolygonShape3D:
	var array_mesh: ArrayMesh = model_mesh as ArrayMesh
	if not array_mesh:
		push_error("ModelCollisionGenerator: Model is not ArrayMesh, cannot generate trimesh")
		return null
	
	# Create trimesh collision shape from mesh surfaces
	var trimesh_shape: ConcavePolygonShape3D = array_mesh.create_trimesh_shape()
	if not trimesh_shape:
		push_error("ModelCollisionGenerator: Failed to create trimesh collision shape")
		return null
	
	return trimesh_shape

## Generate convex hull collision (convex approximation) for balanced accuracy/performance
func _generate_convex_hull_collision(model_mesh: Mesh) -> ConvexPolygonShape3D:
	var array_mesh: ArrayMesh = model_mesh as ArrayMesh
	if not array_mesh:
		return null
	
	# Create convex hull collision shape
	var convex_shape: ConvexPolygonShape3D = array_mesh.create_convex_shape()
	if not convex_shape:
		push_error("ModelCollisionGenerator: Failed to create convex hull collision shape")
		return null
	
	# Optimize convex hull if it has too many vertices
	_optimize_convex_shape(convex_shape)
	
	return convex_shape

## Generate sphere collision (simple sphere) for low-cost collision
func _generate_sphere_collision(model_mesh: Mesh) -> SphereShape3D:
	var aabb: AABB = model_mesh.get_aabb()
	var radius: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z)) * 0.5
	
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = radius
	
	return sphere_shape

## Generate capsule collision for elongated objects
func _generate_capsule_collision(model_mesh: Mesh) -> CapsuleShape3D:
	var aabb: AABB = model_mesh.get_aabb()
	var size: Vector3 = aabb.size
	
	# Use the longest axis as the capsule height
	var height: float = max(size.x, max(size.y, size.z))
	var radius: float = min(size.x, min(size.y, size.z)) * 0.4  # Slightly smaller than half width
	
	var capsule_shape: CapsuleShape3D = CapsuleShape3D.new()
	capsule_shape.height = height
	capsule_shape.radius = radius
	
	return capsule_shape

## Generate box collision (bounding box approximation)
func _generate_box_collision(model_mesh: Mesh) -> BoxShape3D:
	var aabb: AABB = model_mesh.get_aabb()
	
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = aabb.size
	
	return box_shape

## Generate compound collision shape for complex objects with subsystems
func _generate_compound_collision(space_object: BaseSpaceObject, model_mesh: Mesh) -> Shape3D:
	# For now, fallback to convex hull
	# TODO: Implement compound collision based on ModelMetadata subsystem data
	return _generate_convex_hull_collision(model_mesh)

## Configure collision layers and masks based on object type (EPIC-002 integration)
func _configure_collision_layers(space_object: BaseSpaceObject, object_type: int) -> void:
	if not space_object.physics_body:
		return
	
	var physics_body: RigidBody3D = space_object.physics_body
	
	# Set collision layer and mask based on object type using EPIC-002 constants
	match object_type:
		ObjectTypes.Type.SHIP, ObjectTypes.Type.FIGHTER, ObjectTypes.Type.CAPITAL:
			physics_body.collision_layer = CollisionLayers.SHIPS
			physics_body.collision_mask = CollisionLayers.SHIPS | CollisionLayers.WEAPONS | CollisionLayers.OBSTACLES
		
		ObjectTypes.Type.WEAPON:
			physics_body.collision_layer = CollisionLayers.WEAPONS
			physics_body.collision_mask = CollisionLayers.SHIPS | CollisionLayers.OBSTACLES
		
		ObjectTypes.Type.DEBRIS:
			physics_body.collision_layer = CollisionLayers.DEBRIS
			physics_body.collision_mask = CollisionLayers.SHIPS | CollisionLayers.OBSTACLES
		
		ObjectTypes.Type.ASTEROID:
			physics_body.collision_layer = CollisionLayers.OBSTACLES
			physics_body.collision_mask = CollisionLayers.SHIPS | CollisionLayers.WEAPONS
		
		ObjectTypes.Type.CARGO:
			physics_body.collision_layer = CollisionLayers.CARGO
			physics_body.collision_mask = CollisionLayers.SHIPS
		
		ObjectTypes.Type.WAYPOINT:
			physics_body.collision_layer = CollisionLayers.TRIGGERS
			physics_body.collision_mask = CollisionLayers.SHIPS
		
		_:
			# Default collision configuration
			physics_body.collision_layer = 1
			physics_body.collision_mask = 1

## Optimize convex shape by reducing vertex count if needed
func _optimize_convex_shape(convex_shape: ConvexPolygonShape3D) -> void:
	var points: PackedVector3Array = convex_shape.points
	var initial_count: int = points.size()
	
	# If too many vertices, apply simplification
	if points.size() > 100:  # Threshold for optimization
		# TODO: Implement vertex reduction algorithm
		# For now, just log the optimization opportunity
		var vertices_to_reduce: int = points.size() - 100
		push_warning("ModelCollisionGenerator: Convex shape has %d vertices, could optimize by reducing %d" % [points.size(), vertices_to_reduce])
		collision_shape_optimized.emit(null, vertices_to_reduce)

## Generate collision shape from ModelMetadata subsystem data
func generate_subsystem_collision_shapes(space_object: BaseSpaceObject, metadata: ModelMetadata) -> Array[CollisionShape3D]:
	var subsystem_shapes: Array[CollisionShape3D] = []
	
	# Generate collision shapes for weapon hardpoints
	for gun_bank in metadata.gun_banks:
		for point in gun_bank.points:
			var hardpoint_shape: CollisionShape3D = CollisionShape3D.new()
			hardpoint_shape.shape = SphereShape3D.new()
			(hardpoint_shape.shape as SphereShape3D).radius = max(0.5, point.radius)
			hardpoint_shape.position = point.position
			subsystem_shapes.append(hardpoint_shape)
	
	# Generate collision shapes for docking points
	for dock_point in metadata.docking_points:
		for point in dock_point.points:
			var dock_shape: CollisionShape3D = CollisionShape3D.new()
			dock_shape.shape = BoxShape3D.new()
			(dock_shape.shape as BoxShape3D).size = Vector3(2.0, 2.0, 1.0)
			dock_shape.position = point.position
			subsystem_shapes.append(dock_shape)
	
	return subsystem_shapes

## Configure collision shape type for specific object type
func configure_collision_type(object_type: int, shape_type: CollisionShapeType) -> void:
	_collision_type_config[object_type] = shape_type

## Get collision generation performance statistics
func get_performance_stats() -> Dictionary:
	var avg_time: float = 0.0
	var max_time: float = 0.0
	
	if _generation_times.size() > 0:
		for time in _generation_times:
			avg_time += time
			max_time = max(max_time, time)
		avg_time /= _generation_times.size()
	
	return {
		"average_generation_time_ms": avg_time * 1000,
		"max_generation_time_ms": max_time * 1000,
		"total_generations": _generation_times.size()
	}

## Clear performance history
func clear_performance_history() -> void:
	_generation_times.clear()

## Validate collision shape quality
func validate_collision_shape(space_object: BaseSpaceObject) -> Dictionary:
	if not space_object.collision_shape or not space_object.collision_shape.shape:
		return {"valid": false, "error": "No collision shape assigned"}
	
	var shape: Shape3D = space_object.collision_shape.shape
	var validation_result: Dictionary = {"valid": true, "warnings": []}
	
	# Check for degenerate shapes
	if shape is SphereShape3D:
		var sphere: SphereShape3D = shape as SphereShape3D
		if sphere.radius <= 0.0:
			validation_result["valid"] = false
			validation_result["error"] = "Sphere collision shape has invalid radius"
	
	elif shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
			validation_result["valid"] = false
			validation_result["error"] = "Box collision shape has invalid size"
	
	elif shape is ConvexPolygonShape3D:
		var convex: ConvexPolygonShape3D = shape as ConvexPolygonShape3D
		if convex.points.size() < 4:
			validation_result["valid"] = false
			validation_result["error"] = "Convex collision shape has insufficient vertices"
		elif convex.points.size() > 200:
			validation_result["warnings"].append("Convex collision shape has many vertices, may impact performance")
	
	return validation_result