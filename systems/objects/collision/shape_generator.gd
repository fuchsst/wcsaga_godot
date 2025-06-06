class_name ShapeGenerator
extends Node

## Dynamic collision shape generation system for WCS-Godot conversion.
## Creates optimized collision shapes for space objects with caching and multiple shape types.
## Supports sphere, box, and mesh-based collision shapes with performance optimization.
##
## Key Features:
## - Dynamic collision shape generation for various space object types
## - Multi-level shape complexity (simple shapes for broad phase, complex for narrow phase)
## - Collision shape caching for performance optimization
## - Integration with WCS model data and Godot's collision system

signal shape_generated(object: Node3D, shape_type: String, generation_time_ms: float)
signal shape_cached(object: Node3D, cache_key: String)
signal shape_cache_hit(object: Node3D, cache_key: String)

# EPIC-002 Asset Core Integration
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Shape type enumeration
enum ShapeType {
	SPHERE,      # Simple sphere collision
	BOX,         # Bounding box collision  
	CAPSULE,     # Capsule collision for elongated objects
	CONVEX_HULL, # Convex hull from mesh
	TRIMESH,     # Exact mesh collision (expensive)
	COMPOUND     # Multiple shapes combined
}

# Configuration
@export var shape_caching_enabled: bool = true  # AC5: Collision shape caching
@export var auto_generate_shapes: bool = true
@export var default_shape_type: ShapeType = ShapeType.SPHERE
@export var max_cache_size: int = 1000
@export var shape_generation_budget_ms: float = 0.1  # AC2: <0.1ms generation time

# Shape cache for performance optimization (AC5)
var shape_cache: Dictionary = {}  # cache_key -> CollisionShape3D
var cache_access_times: Dictionary = {}  # cache_key -> last_access_timestamp
var shape_generation_stats: Dictionary = {
	"shapes_generated": 0,
	"shapes_cached": 0,
	"cache_hits": 0,
	"generation_time_total_ms": 0.0
}

# Shape complexity levels for multi-level collision (AC4)
var complexity_levels: Dictionary = {
	ShapeType.SPHERE: 1,      # Simplest - broad phase
	ShapeType.BOX: 2,         # Simple - broad phase
	ShapeType.CAPSULE: 3,     # Medium - narrow phase
	ShapeType.CONVEX_HULL: 4, # Complex - narrow phase
	ShapeType.TRIMESH: 5,     # Most complex - detailed collision
	ShapeType.COMPOUND: 6     # Most complex - multiple shapes
}

# Default shape parameters for different object types
var object_shape_defaults: Dictionary = {
	ObjectTypes.Type.SHIP: {
		"primary_shape": ShapeType.CONVEX_HULL,
		"broad_phase_shape": ShapeType.SPHERE,
		"narrow_phase_shape": ShapeType.CONVEX_HULL
	},
	ObjectTypes.Type.WEAPON: {
		"primary_shape": ShapeType.CAPSULE,
		"broad_phase_shape": ShapeType.SPHERE,
		"narrow_phase_shape": ShapeType.CAPSULE
	},
	ObjectTypes.Type.DEBRIS: {
		"primary_shape": ShapeType.BOX,
		"broad_phase_shape": ShapeType.SPHERE,
		"narrow_phase_shape": ShapeType.BOX
	},
	ObjectTypes.Type.ASTEROID: {
		"primary_shape": ShapeType.CONVEX_HULL,
		"broad_phase_shape": ShapeType.SPHERE,
		"narrow_phase_shape": ShapeType.CONVEX_HULL
	},
	ObjectTypes.Type.BEAM: {
		"primary_shape": ShapeType.CAPSULE,
		"broad_phase_shape": ShapeType.SPHERE,
		"narrow_phase_shape": ShapeType.CAPSULE
	}
}

func _ready() -> void:
	print("ShapeGenerator: Initialized with dynamic collision shape generation")

## Main shape generation function (AC2)
func generate_collision_shape(object: Node3D, shape_type: ShapeType = ShapeType.SPHERE, use_cache: bool = true) -> CollisionShape3D:
	"""Generate collision shape for a space object with caching optimization.
	
	Args:
		object: Node3D object to generate collision shape for
		shape_type: Type of collision shape to generate
		use_cache: Whether to use shape caching for performance
		
	Returns:
		CollisionShape3D node with generated shape
	"""
	var generation_start_time: float = Time.get_ticks_usec() / 1000.0
	
	# Check cache first (AC5)
	if use_cache and shape_caching_enabled:
		var cache_key: String = _generate_cache_key(object, shape_type)
		var cached_shape: CollisionShape3D = _get_cached_shape(cache_key)
		
		if cached_shape:
			shape_cache_hit.emit(object, cache_key)
			shape_generation_stats.cache_hits += 1
			return cached_shape.duplicate()
	
	# Generate new shape
	var collision_shape: CollisionShape3D = _generate_shape_by_type(object, shape_type)
	
	# Cache the generated shape (AC5)
	if use_cache and shape_caching_enabled and collision_shape:
		var cache_key: String = _generate_cache_key(object, shape_type)
		_cache_shape(cache_key, collision_shape)
	
	# Track performance
	var generation_end_time: float = Time.get_ticks_usec() / 1000.0
	var generation_time_ms: float = generation_end_time - generation_start_time
	
	shape_generation_stats.shapes_generated += 1
	shape_generation_stats.generation_time_total_ms += generation_time_ms
	
	shape_generated.emit(object, ShapeType.keys()[shape_type], generation_time_ms)
	
	# Check performance budget (AC2)
	if generation_time_ms > shape_generation_budget_ms:
		push_warning("ShapeGenerator: Shape generation exceeded budget: %.3fms" % generation_time_ms)
	
	return collision_shape

## Multi-level shape generation for broad/narrow phase collision (AC4)
func generate_multi_level_shapes(object: Node3D) -> Dictionary:
	"""Generate multiple collision shapes for multi-level collision detection.
	
	Args:
		object: Node3D object to generate shapes for
		
	Returns:
		Dictionary containing broad_phase and narrow_phase collision shapes
	"""
	var object_type: ObjectTypes.Type = _get_object_type(object)
	var shape_config: Dictionary = object_shape_defaults.get(object_type, object_shape_defaults[ObjectTypes.Type.SHIP])
	
	var shapes: Dictionary = {}
	
	# Generate broad phase shape (simple, fast)
	var broad_phase_type: ShapeType = shape_config.get("broad_phase_shape", ShapeType.SPHERE)
	shapes.broad_phase = generate_collision_shape(object, broad_phase_type)
	
	# Generate narrow phase shape (detailed, accurate)
	var narrow_phase_type: ShapeType = shape_config.get("narrow_phase_shape", ShapeType.CONVEX_HULL)
	shapes.narrow_phase = generate_collision_shape(object, narrow_phase_type)
	
	# Generate primary shape (balanced)
	var primary_type: ShapeType = shape_config.get("primary_shape", ShapeType.SPHERE)
	shapes.primary = generate_collision_shape(object, primary_type)
	
	return shapes

## Shape generation by type (AC2)
func _generate_shape_by_type(object: Node3D, shape_type: ShapeType) -> CollisionShape3D:
	"""Generate collision shape based on specified type."""
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	
	match shape_type:
		ShapeType.SPHERE:
			collision_shape.shape = _generate_sphere_shape(object)
		ShapeType.BOX:
			collision_shape.shape = _generate_box_shape(object)
		ShapeType.CAPSULE:
			collision_shape.shape = _generate_capsule_shape(object)
		ShapeType.CONVEX_HULL:
			collision_shape.shape = _generate_convex_hull_shape(object)
		ShapeType.TRIMESH:
			collision_shape.shape = _generate_trimesh_shape(object)
		ShapeType.COMPOUND:
			collision_shape.shape = _generate_compound_shape(object)
		_:
			push_warning("ShapeGenerator: Unknown shape type, defaulting to sphere")
			collision_shape.shape = _generate_sphere_shape(object)
	
	return collision_shape

## Individual shape generation functions
func _generate_sphere_shape(object: Node3D) -> SphereShape3D:
	"""Generate sphere collision shape from object bounds."""
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	
	# Calculate radius from object bounds
	var aabb: AABB = _get_object_aabb(object)
	var radius: float = aabb.size.length() * 0.5
	
	if radius <= 0.0:
		radius = 1.0  # Default radius
	
	sphere_shape.radius = radius
	return sphere_shape

func _generate_box_shape(object: Node3D) -> BoxShape3D:
	"""Generate box collision shape from object bounds."""
	var box_shape: BoxShape3D = BoxShape3D.new()
	
	# Calculate size from object bounds
	var aabb: AABB = _get_object_aabb(object)
	var size: Vector3 = aabb.size
	
	if size.length() <= 0.0:
		size = Vector3.ONE  # Default size
	
	box_shape.size = size
	return box_shape

func _generate_capsule_shape(object: Node3D) -> CapsuleShape3D:
	"""Generate capsule collision shape, ideal for elongated objects like weapons."""
	var capsule_shape: CapsuleShape3D = CapsuleShape3D.new()
	
	# Calculate dimensions from object bounds
	var aabb: AABB = _get_object_aabb(object)
	var size: Vector3 = aabb.size
	
	# Use the longest axis for height, average of others for radius
	var max_axis: float = maxf(maxf(size.x, size.y), size.z)
	var min_axes: float = (size.x + size.y + size.z - max_axis) * 0.5
	
	capsule_shape.height = max_axis
	capsule_shape.radius = min_axes * 0.5
	
	# Minimum values
	if capsule_shape.height <= 0.0:
		capsule_shape.height = 2.0
	if capsule_shape.radius <= 0.0:
		capsule_shape.radius = 0.5
	
	return capsule_shape

func _generate_convex_hull_shape(object: Node3D) -> ConvexPolygonShape3D:
	"""Generate convex hull collision shape from mesh data."""
	var convex_shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	
	# Get mesh from object
	var mesh: Mesh = _get_object_mesh(object)
	
	if mesh:
		# Generate convex hull from mesh
		var vertices: PackedVector3Array = _extract_mesh_vertices(mesh)
		if vertices.size() > 0:
			convex_shape.points = vertices
		else:
			# Fallback to simple box vertices
			convex_shape.points = _generate_box_vertices(object)
	else:
		# Fallback to simple box vertices
		convex_shape.points = _generate_box_vertices(object)
	
	return convex_shape

func _generate_trimesh_shape(object: Node3D) -> ConcavePolygonShape3D:
	"""Generate exact mesh collision shape (expensive, use sparingly)."""
	var trimesh_shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	
	# Get mesh from object
	var mesh: Mesh = _get_object_mesh(object)
	
	if mesh:
		# Create exact mesh collision
		trimesh_shape.set_faces(_extract_mesh_faces(mesh))
	else:
		# Fallback to box faces
		trimesh_shape.set_faces(_generate_box_faces(object))
	
	return trimesh_shape

func _generate_compound_shape(object: Node3D) -> CompoundShape3D:
	"""Generate compound collision shape with multiple sub-shapes."""
	var compound_shape: CompoundShape3D = CompoundShape3D.new()
	
	# For now, create a simple compound with sphere + box
	# This could be enhanced to analyze mesh and create multiple shapes
	
	# Add main sphere shape
	var sphere: SphereShape3D = _generate_sphere_shape(object)
	compound_shape.add_child_shape(Transform3D.IDENTITY, sphere)
	
	# Add smaller box shape
	var box: BoxShape3D = _generate_box_shape(object)
	var box_transform: Transform3D = Transform3D.IDENTITY
	box_transform = box_transform.scaled(Vector3(0.8, 0.8, 0.8))  # Slightly smaller
	compound_shape.add_child_shape(box_transform, box)
	
	return compound_shape

## Utility functions for shape generation
func _get_object_aabb(object: Node3D) -> AABB:
	"""Get axis-aligned bounding box from object."""
	# Try to get AABB from visual instance
	if object.has_method("get_aabb"):
		return object.get_aabb()
	
	# Try to get from MeshInstance3D child
	for child in object.get_children():
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			if mesh_instance.mesh:
				return mesh_instance.get_aabb()
	
	# Try to get from existing collision shape
	for child in object.get_children():
		if child is CollisionShape3D:
			var collision_shape: CollisionShape3D = child as CollisionShape3D
			if collision_shape.shape:
				return collision_shape.shape.get_debug_mesh().get_aabb()
	
	# Default fallback
	return AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))

func _get_object_mesh(object: Node3D) -> Mesh:
	"""Extract mesh from object for collision shape generation."""
	# Try to get mesh from MeshInstance3D child
	for child in object.get_children():
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			return mesh_instance.mesh
	
	# Try to get mesh from the object itself if it's a MeshInstance3D
	if object is MeshInstance3D:
		var mesh_instance: MeshInstance3D = object as MeshInstance3D
		return mesh_instance.mesh
	
	return null

func _extract_mesh_vertices(mesh: Mesh) -> PackedVector3Array:
	"""Extract vertices from mesh for convex hull generation."""
	var vertices: PackedVector3Array = PackedVector3Array()
	
	if mesh.get_surface_count() > 0:
		var surface_array: Array = mesh.surface_get_arrays(0)
		if surface_array.size() > Mesh.ARRAY_VERTEX:
			var vertex_array = surface_array[Mesh.ARRAY_VERTEX]
			if vertex_array is PackedVector3Array:
				vertices = vertex_array
	
	return vertices

func _extract_mesh_faces(mesh: Mesh) -> PackedVector3Array:
	"""Extract face data from mesh for trimesh collision."""
	var faces: PackedVector3Array = PackedVector3Array()
	
	if mesh.get_surface_count() > 0:
		var surface_array: Array = mesh.surface_get_arrays(0)
		if surface_array.size() > Mesh.ARRAY_VERTEX:
			var vertex_array = surface_array[Mesh.ARRAY_VERTEX]
			var index_array = surface_array[Mesh.ARRAY_INDEX] if surface_array.size() > Mesh.ARRAY_INDEX else null
			
			if vertex_array is PackedVector3Array:
				if index_array is PackedInt32Array:
					# Use indices to create faces
					for i in range(0, index_array.size(), 3):
						if i + 2 < index_array.size():
							faces.append(vertex_array[index_array[i]])
							faces.append(vertex_array[index_array[i + 1]])
							faces.append(vertex_array[index_array[i + 2]])
				else:
					# Use vertices directly
					for i in range(0, vertex_array.size(), 3):
						if i + 2 < vertex_array.size():
							faces.append(vertex_array[i])
							faces.append(vertex_array[i + 1])
							faces.append(vertex_array[i + 2])
	
	return faces

func _generate_box_vertices(object: Node3D) -> PackedVector3Array:
	"""Generate box vertices for fallback convex hull."""
	var aabb: AABB = _get_object_aabb(object)
	var vertices: PackedVector3Array = PackedVector3Array()
	
	var min_pos: Vector3 = aabb.position
	var max_pos: Vector3 = aabb.position + aabb.size
	
	# 8 vertices of box
	vertices.append(Vector3(min_pos.x, min_pos.y, min_pos.z))
	vertices.append(Vector3(max_pos.x, min_pos.y, min_pos.z))
	vertices.append(Vector3(max_pos.x, max_pos.y, min_pos.z))
	vertices.append(Vector3(min_pos.x, max_pos.y, min_pos.z))
	vertices.append(Vector3(min_pos.x, min_pos.y, max_pos.z))
	vertices.append(Vector3(max_pos.x, min_pos.y, max_pos.z))
	vertices.append(Vector3(max_pos.x, max_pos.y, max_pos.z))
	vertices.append(Vector3(min_pos.x, max_pos.y, max_pos.z))
	
	return vertices

func _generate_box_faces(object: Node3D) -> PackedVector3Array:
	"""Generate box faces for fallback trimesh."""
	var vertices: PackedVector3Array = _generate_box_vertices(object)
	var faces: PackedVector3Array = PackedVector3Array()
	
	# Define box faces using vertex indices
	var face_indices: Array[int] = [
		0, 1, 2,  0, 2, 3,  # Bottom face
		4, 6, 5,  4, 7, 6,  # Top face
		0, 4, 1,  1, 4, 5,  # Front face
		2, 6, 3,  3, 6, 7,  # Back face
		0, 3, 4,  3, 7, 4,  # Left face
		1, 5, 2,  2, 5, 6   # Right face
	]
	
	for i in face_indices:
		faces.append(vertices[i])
	
	return faces

func _get_object_type(obj: Node3D) -> ObjectTypes.Type:
	"""Get object type for shape generation defaults."""
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
	
	return ObjectTypes.Type.SHIP  # Default fallback

## Shape caching functions (AC5)
func _generate_cache_key(object: Node3D, shape_type: ShapeType) -> String:
	"""Generate cache key for collision shape."""
	var object_name: String = object.name
	var shape_type_name: String = ShapeType.keys()[shape_type]
	
	# Include object bounds in cache key for accuracy
	var aabb: AABB = _get_object_aabb(object)
	var bounds_hash: int = hash(str(aabb.position) + str(aabb.size))
	
	return "%s_%s_%d" % [object_name, shape_type_name, bounds_hash]

func _get_cached_shape(cache_key: String) -> CollisionShape3D:
	"""Get collision shape from cache."""
	if cache_key in shape_cache:
		cache_access_times[cache_key] = Time.get_ticks_msec()
		return shape_cache[cache_key]
	
	return null

func _cache_shape(cache_key: String, collision_shape: CollisionShape3D) -> void:
	"""Cache collision shape for future use."""
	# Check cache size limit
	if shape_cache.size() >= max_cache_size:
		_cleanup_old_cache_entries()
	
	shape_cache[cache_key] = collision_shape
	cache_access_times[cache_key] = Time.get_ticks_msec()
	
	shape_generation_stats.shapes_cached += 1
	shape_cached.emit(collision_shape.get_parent() if collision_shape.get_parent() else Node3D.new(), cache_key)

func _cleanup_old_cache_entries() -> void:
	"""Remove old cache entries to make room for new ones."""
	var current_time: int = Time.get_ticks_msec()
	var entries_to_remove: Array[String] = []
	
	# Find oldest entries
	for cache_key in cache_access_times:
		var age_ms: int = current_time - cache_access_times[cache_key]
		if age_ms > 60000:  # Remove entries older than 1 minute
			entries_to_remove.append(cache_key)
	
	# Remove old entries
	for cache_key in entries_to_remove:
		shape_cache.erase(cache_key)
		cache_access_times.erase(cache_key)
	
	print("ShapeGenerator: Cleaned up %d old cache entries" % entries_to_remove.size())

## Public API functions
func get_optimal_shape_type_for_object(object: Node3D) -> ShapeType:
	"""Get optimal collision shape type for an object based on its properties.
	
	Args:
		object: Node3D object to analyze
		
	Returns:
		Recommended ShapeType for the object
	"""
	var object_type: ObjectTypes.Type = _get_object_type(object)
	var shape_config: Dictionary = object_shape_defaults.get(object_type, object_shape_defaults[ObjectTypes.Type.SHIP])
	
	return shape_config.get("primary_shape", ShapeType.SPHERE)

func generate_shape_for_object_type(object: Node3D, object_type: ObjectTypes.Type) -> CollisionShape3D:
	"""Generate collision shape optimized for specific object type.
	
	Args:
		object: Node3D object to generate shape for
		object_type: ObjectTypes.Type to optimize for
		
	Returns:
		CollisionShape3D optimized for the object type
	"""
	var shape_config: Dictionary = object_shape_defaults.get(object_type, object_shape_defaults[ObjectTypes.Type.SHIP])
	var shape_type: ShapeType = shape_config.get("primary_shape", ShapeType.SPHERE)
	
	return generate_collision_shape(object, shape_type)

func clear_shape_cache() -> void:
	"""Clear all cached collision shapes."""
	shape_cache.clear()
	cache_access_times.clear()
	print("ShapeGenerator: Shape cache cleared")

func get_shape_generation_statistics() -> Dictionary:
	"""Get collision shape generation statistics.
	
	Returns:
		Dictionary containing shape generation performance data
	"""
	var stats: Dictionary = shape_generation_stats.duplicate()
	stats.cache_size = shape_cache.size()
	stats.average_generation_time_ms = 0.0
	
	if stats.shapes_generated > 0:
		stats.average_generation_time_ms = stats.generation_time_total_ms / stats.shapes_generated
	
	return stats

func set_shape_caching_enabled(enabled: bool) -> void:
	"""Enable or disable shape caching.
	
	Args:
		enabled: true to enable shape caching, false to disable
	"""
	shape_caching_enabled = enabled
	print("ShapeGenerator: Shape caching %s" % ("enabled" if enabled else "disabled"))

func set_shape_generation_budget_ms(budget_ms: float) -> void:
	"""Set shape generation performance budget.
	
	Args:
		budget_ms: Maximum time in milliseconds for shape generation
	"""
	shape_generation_budget_ms = budget_ms
	print("ShapeGenerator: Shape generation budget set to %.3fms" % budget_ms)