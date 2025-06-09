class_name BeamCollisionDetector
extends Node

## SHIP-013 AC3: Beam Collision Detection
## Handles both precision line collision and area sphereline collision based on beam width thresholds
## Provides efficient collision detection for continuous beam weapons

# EPIC-002 Asset Core Integration
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

# Signals
signal beam_collision_detected(beam_id: String, collision_data: Dictionary)
signal collision_detection_completed(beam_id: String, collision_count: int)
signal collision_method_changed(beam_id: String, old_method: String, new_method: String)

# Collision detection methods
enum CollisionMethod {
	PRECISION_LINE = 0,      # Ray casting for thin beams
	AREA_SPHERELINE = 1,     # Shape intersection for wide beams
	HYBRID = 2               # Combination based on distance and width
}

# Collision detection configuration
var collision_method_configs: Dictionary = {
	CollisionMethod.PRECISION_LINE: {
		"name": "Precision Line",
		"max_width_threshold": 2.0,
		"performance_cost": 1.0,
		"accuracy": "high"
	},
	CollisionMethod.AREA_SPHERELINE: {
		"name": "Area Sphereline",
		"min_width_threshold": 3.0,
		"performance_cost": 2.5,
		"accuracy": "medium"
	},
	CollisionMethod.HYBRID: {
		"name": "Hybrid",
		"switch_distance": 100.0,
		"performance_cost": 1.5,
		"accuracy": "adaptive"
	}
}

# Active beam collision tracking
var active_beam_collisions: Dictionary = {}  # beam_id -> collision_data
var collision_detection_cache: Dictionary = {}  # beam_id -> cached_results
var collision_performance_stats: Dictionary = {}

# Collision detection settings
@export var enable_collision_caching: bool = true
@export var cache_validity_time: float = 0.05  # 50ms cache validity
@export var max_collision_distance: float = 3000.0
@export var collision_layer_mask: int = 0
@export var enable_collision_debugging: bool = false

# Performance optimization
@export var max_ray_casts_per_frame: int = 50
@export var collision_batch_size: int = 10
@export var enable_distance_culling: bool = true
@export var distance_culling_threshold: float = 2000.0

# Width thresholds for collision method selection
@export var precision_line_max_width: float = 2.0
@export var area_sphereline_min_width: float = 3.0
@export var hybrid_switch_distance: float = 100.0

# Collision detection state
var collision_queries_this_frame: int = 0
var frame_start_time: float = 0.0

# System references
var space_state: PhysicsDirectSpaceState3D = null
var collision_exclusions: Array[RID] = []

func _ready() -> void:
	_setup_collision_detector()
	_initialize_collision_layers()

## Initialize beam collision detector
func initialize_collision_detector() -> void:
	space_state = get_viewport().get_world_3d().direct_space_state
	
	if enable_collision_debugging:
		print("BeamCollisionDetector: Initialized with space state")

## Detect collisions for beam weapon
func detect_beam_collisions(beam_id: String, beam_data: Dictionary) -> Array[Dictionary]:
	var config = beam_data.get("config", {})
	var beam_width = config.get("width", 2.0)
	var beam_range = config.get("range", 1000.0)
	var source_position = beam_data.get("source_position", Vector3.ZERO)
	var beam_direction = beam_data.get("current_direction", Vector3.FORWARD)
	
	# Check cache first
	if enable_collision_caching and _has_valid_cache(beam_id):
		return _get_cached_collisions(beam_id)
	
	# Determine collision detection method
	var collision_method = _determine_collision_method(beam_width, beam_range, source_position)
	
	# Perform collision detection
	var collisions: Array[Dictionary] = []
	
	match collision_method:
		CollisionMethod.PRECISION_LINE:
			collisions = _detect_precision_line_collisions(beam_id, beam_data)
		
		CollisionMethod.AREA_SPHERELINE:
			collisions = _detect_area_sphereline_collisions(beam_id, beam_data)
		
		CollisionMethod.HYBRID:
			collisions = _detect_hybrid_collisions(beam_id, beam_data)
	
	# Cache results
	if enable_collision_caching:
		_cache_collision_results(beam_id, collisions)
	
	# Update performance statistics
	_update_collision_performance_stats(beam_id, collision_method, collisions.size())
	
	# Emit signals
	for collision in collisions:
		beam_collision_detected.emit(beam_id, collision)
	
	collision_detection_completed.emit(beam_id, collisions.size())
	
	if enable_collision_debugging:
		print("BeamCollisionDetector: Detected %d collisions for beam %s using %s" % [
			collisions.size(), beam_id, collision_method_configs[collision_method]["name"]
		])
	
	return collisions

## Detect precision line collisions (for thin beams)
func _detect_precision_line_collisions(beam_id: String, beam_data: Dictionary) -> Array[Dictionary]:
	var config = beam_data.get("config", {})
	var source_position = beam_data.get("source_position", Vector3.ZERO)
	var beam_direction = beam_data.get("current_direction", Vector3.FORWARD)
	var beam_range = config.get("range", 1000.0)
	
	var end_position = source_position + (beam_direction * beam_range)
	var collisions: Array[Dictionary] = []
	
	if not space_state:
		return collisions
	
	# Create ray query
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = source_position
	ray_query.to = end_position
	ray_query.collision_mask = collision_layer_mask
	ray_query.exclude = collision_exclusions
	
	# Perform ray cast
	var result = space_state.intersect_ray(ray_query)
	
	if result.size() > 0:
		var collision_data = {
			"target": result.get("collider", null),
			"collision_point": result.get("position", Vector3.ZERO),
			"collision_normal": result.get("normal", Vector3.UP),
			"collision_distance": source_position.distance_to(result.get("position", Vector3.ZERO)),
			"collision_method": "precision_line",
			"beam_id": beam_id,
			"detection_time": Time.get_ticks_msec() / 1000.0
		}
		collisions.append(collision_data)
	
	collision_queries_this_frame += 1
	return collisions

## Detect area sphereline collisions (for wide beams)
func _detect_area_sphereline_collisions(beam_id: String, beam_data: Dictionary) -> Array[Dictionary]:
	var config = beam_data.get("config", {})
	var source_position = beam_data.get("source_position", Vector3.ZERO)
	var beam_direction = beam_data.get("current_direction", Vector3.FORWARD)
	var beam_range = config.get("range", 1000.0)
	var beam_width = config.get("width", 4.0)
	
	var collisions: Array[Dictionary] = []
	
	if not space_state:
		return collisions
	
	# Create cylinder shape for beam volume
	var cylinder_shape = CylinderShape3D.new()
	cylinder_shape.top_radius = beam_width / 2.0
	cylinder_shape.bottom_radius = beam_width / 2.0
	cylinder_shape.height = beam_range
	
	# Position cylinder along beam direction
	var cylinder_center = source_position + (beam_direction * beam_range / 2.0)
	var cylinder_transform = Transform3D()
	cylinder_transform.origin = cylinder_center
	
	# Align cylinder with beam direction
	if beam_direction != Vector3.UP:
		var rotation_axis = Vector3.UP.cross(beam_direction).normalized()
		var rotation_angle = Vector3.UP.angle_to(beam_direction)
		if rotation_axis != Vector3.ZERO:
			cylinder_transform.basis = Basis(rotation_axis, rotation_angle)
	
	# Create shape query
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = cylinder_shape
	shape_query.transform = cylinder_transform
	shape_query.collision_mask = collision_layer_mask
	shape_query.exclude = collision_exclusions
	
	# Perform shape intersection
	var results = space_state.intersect_shape(shape_query)
	
	for result in results:
		var target = result.get("collider", null)
		if target:
			# Calculate approximate collision point
			var target_position = target.global_position if target.has_method("get_global_position") else Vector3.ZERO
			var collision_point = _calculate_beam_collision_point(source_position, beam_direction, target_position)
			
			var collision_data = {
				"target": target,
				"collision_point": collision_point,
				"collision_normal": (collision_point - target_position).normalized(),
				"collision_distance": source_position.distance_to(collision_point),
				"collision_method": "area_sphereline",
				"beam_id": beam_id,
				"detection_time": Time.get_ticks_msec() / 1000.0
			}
			collisions.append(collision_data)
	
	collision_queries_this_frame += 1
	return collisions

## Detect hybrid collisions (adaptive method)
func _detect_hybrid_collisions(beam_id: String, beam_data: Dictionary) -> Array[Dictionary]:
	var config = beam_data.get("config", {})
	var source_position = beam_data.get("source_position", Vector3.ZERO)
	var beam_range = config.get("range", 1000.0)
	var beam_width = config.get("width", 2.0)
	
	# Use precision line for close targets, area sphereline for distant ones
	if beam_range < hybrid_switch_distance:
		return _detect_precision_line_collisions(beam_id, beam_data)
	else:
		# For long-range beams, use area detection to ensure hits
		return _detect_area_sphereline_collisions(beam_id, beam_data)

## Determine optimal collision detection method
func _determine_collision_method(beam_width: float, beam_range: float, source_position: Vector3) -> CollisionMethod:
	# Width-based selection
	if beam_width <= precision_line_max_width:
		return CollisionMethod.PRECISION_LINE
	elif beam_width >= area_sphereline_min_width:
		return CollisionMethod.AREA_SPHERELINE
	else:
		# Use hybrid for beams between thresholds
		return CollisionMethod.HYBRID

## Calculate beam collision point on target
func _calculate_beam_collision_point(beam_start: Vector3, beam_direction: Vector3, target_position: Vector3) -> Vector3:
	# Project target position onto beam line
	var beam_to_target = target_position - beam_start
	var projection_length = beam_to_target.dot(beam_direction)
	
	# Clamp to beam range
	projection_length = max(0.0, projection_length)
	
	return beam_start + (beam_direction * projection_length)

## Setup collision detector
func _setup_collision_detector() -> void:
	active_beam_collisions.clear()
	collision_detection_cache.clear()
	collision_performance_stats.clear()
	
	collision_queries_this_frame = 0
	frame_start_time = 0.0

## Initialize collision layers
func _initialize_collision_layers() -> void:
	# Set up collision mask for beam weapons
	collision_layer_mask = 0
	collision_layer_mask |= CollisionLayers.Layer.SHIPS
	collision_layer_mask |= CollisionLayers.Layer.ASTEROIDS
	collision_layer_mask |= CollisionLayers.Layer.DEBRIS
	collision_layer_mask |= CollisionLayers.Layer.CAPITAL_SHIPS
	
	if enable_collision_debugging:
		print("BeamCollisionDetector: Initialized collision mask: %d" % collision_layer_mask)

## Cache management
func _has_valid_cache(beam_id: String) -> bool:
	if not collision_detection_cache.has(beam_id):
		return false
	
	var cache_data = collision_detection_cache[beam_id]
	var current_time = Time.get_ticks_msec() / 1000.0
	var cache_time = cache_data.get("cache_time", 0.0)
	
	return (current_time - cache_time) < cache_validity_time

func _get_cached_collisions(beam_id: String) -> Array[Dictionary]:
	var cache_data = collision_detection_cache.get(beam_id, {})
	return cache_data.get("collisions", [])

func _cache_collision_results(beam_id: String, collisions: Array[Dictionary]) -> void:
	collision_detection_cache[beam_id] = {
		"collisions": collisions.duplicate(),
		"cache_time": Time.get_ticks_msec() / 1000.0
	}

## Performance tracking
func _update_collision_performance_stats(beam_id: String, method: CollisionMethod, collision_count: int) -> void:
	if not collision_performance_stats.has(beam_id):
		collision_performance_stats[beam_id] = {
			"total_detections": 0,
			"total_collisions": 0,
			"method_usage": {},
			"average_collisions": 0.0
		}
	
	var stats = collision_performance_stats[beam_id]
	stats["total_detections"] += 1
	stats["total_collisions"] += collision_count
	stats["average_collisions"] = float(stats["total_collisions"]) / float(stats["total_detections"])
	
	var method_name = collision_method_configs[method]["name"]
	if not stats["method_usage"].has(method_name):
		stats["method_usage"][method_name] = 0
	stats["method_usage"][method_name] += 1

## Add collision exclusion
func add_collision_exclusion(body: RigidBody3D) -> void:
	if body and body.get_rid() not in collision_exclusions:
		collision_exclusions.append(body.get_rid())

## Remove collision exclusion
func remove_collision_exclusion(body: RigidBody3D) -> void:
	if body:
		collision_exclusions.erase(body.get_rid())

## Clear all collision exclusions
func clear_collision_exclusions() -> void:
	collision_exclusions.clear()

## Get collision detection statistics
func get_collision_detection_statistics() -> Dictionary:
	return {
		"queries_this_frame": collision_queries_this_frame,
		"active_beam_count": active_beam_collisions.size(),
		"cache_hit_rate": _calculate_cache_hit_rate(),
		"performance_stats": collision_performance_stats.duplicate(),
		"collision_layer_mask": collision_layer_mask,
		"exclusions_count": collision_exclusions.size()
	}

## Calculate cache hit rate
func _calculate_cache_hit_rate() -> float:
	# This would track cache hits vs misses in a real implementation
	return 0.0

## Clean up old cache entries
func _cleanup_collision_cache() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var keys_to_remove: Array[String] = []
	
	for beam_id in collision_detection_cache.keys():
		var cache_data = collision_detection_cache[beam_id]
		var cache_time = cache_data.get("cache_time", 0.0)
		
		if (current_time - cache_time) > (cache_validity_time * 5):  # Keep cache 5x longer than validity
			keys_to_remove.append(beam_id)
	
	for key in keys_to_remove:
		collision_detection_cache.erase(key)

## Process frame updates
func _process(delta: float) -> void:
	# Reset frame collision query counter
	if frame_start_time == 0.0:
		frame_start_time = Time.get_ticks_msec() / 1000.0
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - frame_start_time >= 1.0:  # Every second
		frame_start_time = current_time
		collision_queries_this_frame = 0
		
		# Periodic cache cleanup
		_cleanup_collision_cache()