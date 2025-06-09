class_name RadarSpatialManager
extends RefCounted

## HUD-009 Component 2: Radar Spatial Management System
## Handles 3D-to-2D coordinate transformation, spatial calculations, and radar geometry
## Provides accurate spatial representation for the 3D radar display

# Coordinate transformation parameters
var radar_center: Vector2
var radar_radius: float
var current_scale: float
var display_size: Vector2

# 3D projection settings
var elevation_scale: float = 0.5  # How much to compress vertical distances
var perspective_angle: float = 0.0  # Viewing angle for 3D perspective
var radar_orientation: Quaternion = Quaternion.IDENTITY

# Range and scale management
var radar_range: float = 10000.0
var range_rings: Array[float] = []
var range_ring_count: int = 5

# Spatial calculation cache
var transform_cache: Dictionary = {}
var cache_ttl: float = 0.1  # Cache time-to-live in seconds
var last_cache_clear: float = 0.0

# Performance optimization
var transform_precision: float = 1.0  # Scale for precision vs performance
var use_lod: bool = true
var lod_distance_threshold: float = 5000.0

func _init():
	_initialize_spatial_manager()

func _initialize_spatial_manager() -> void:
	print("RadarSpatialManager: Initializing spatial management system...")
	
	# Set default parameters
	display_size = Vector2(300, 300)
	radar_center = display_size * 0.5
	radar_radius = min(display_size.x, display_size.y) * 0.4
	current_scale = 1.0
	
	# Initialize range rings
	_calculate_range_rings()
	
	print("RadarSpatialManager: Spatial management system initialized")

## Setup radar display parameters
func setup_radar_display(size: Vector2, range: float) -> void:
	display_size = size
	radar_center = display_size * 0.5
	radar_radius = min(display_size.x, display_size.y) * 0.4
	radar_range = range
	
	_calculate_current_scale()
	_calculate_range_rings()

## Update spatial data for current frame
func update_spatial_data(player_pos: Vector3, player_orient: Quaternion, range: float) -> void:
	radar_range = range
	radar_orientation = player_orient
	
	_calculate_current_scale()
	_clear_transform_cache_if_needed()

## Transform world coordinates to radar display coordinates
func world_to_radar_coordinates(world_pos: Vector3, player_pos: Vector3, player_orient: Quaternion) -> Vector2:
	# Check cache first
	var cache_key = _generate_cache_key(world_pos, player_pos, player_orient)
	if transform_cache.has(cache_key):
		var cached_data = transform_cache[cache_key]
		if Time.get_ticks_usec() / 1000000.0 - cached_data.timestamp < cache_ttl:
			return cached_data.position
	
	# Calculate relative position
	var relative_pos = world_pos - player_pos
	
	# Rotate to player's reference frame (inverse rotation)
	var inverse_rotation = player_orient.inverse()
	var rotated_pos = inverse_rotation * relative_pos
	
	# Apply 3D-to-2D projection
	var radar_pos = _project_3d_to_2d(rotated_pos)
	
	# Apply scale and center transformation
	var scaled_pos = radar_pos * current_scale
	var final_pos = radar_center + scaled_pos
	
	# Clamp to radar display bounds
	final_pos = _clamp_to_radar_bounds(final_pos)
	
	# Cache the result
	transform_cache[cache_key] = {
		"position": final_pos,
		"timestamp": Time.get_ticks_usec() / 1000000.0
	}
	
	return final_pos

## Project 3D coordinates to 2D radar display
func _project_3d_to_2d(pos_3d: Vector3) -> Vector2:
	# Use perspective projection for more natural 3D representation
	var distance = pos_3d.length()
	
	# Apply LOD-based precision
	var precision = transform_precision
	if use_lod and distance > lod_distance_threshold:
		precision *= 0.5  # Reduce precision for distant objects
	
	# Basic orthographic projection with slight perspective effect
	var x = pos_3d.x
	var z = pos_3d.z
	
	# Add subtle perspective distortion based on distance
	var perspective_factor = 1.0 + (distance * 0.00001)  # Very subtle effect
	x /= perspective_factor
	z /= perspective_factor
	
	# Apply elevation compression
	var y_offset = pos_3d.y * elevation_scale
	
	# Create 2D position (X-Z plane, with Y affecting the display slightly)
	var pos_2d = Vector2(x, z)
	
	# Apply distance-based scaling
	if distance > 0:
		pos_2d = pos_2d.normalized() * min(distance, radar_range)
	
	return pos_2d

## Calculate elevation indicator for objects above/below player
func calculate_elevation_indicator(world_pos: Vector3, player_pos: Vector3) -> float:
	var relative_pos = world_pos - player_pos
	var distance_horizontal = Vector2(relative_pos.x, relative_pos.z).length()
	
	if distance_horizontal < 0.1:
		return 0.0  # Directly above/below
	
	# Calculate elevation angle in degrees
	var elevation_angle = rad_to_deg(atan2(relative_pos.y, distance_horizontal))
	
	# Normalize to -1.0 (below) to 1.0 (above)
	return clamp(elevation_angle / 90.0, -1.0, 1.0)

## Get distance from player to world position
func get_distance_to_player(world_pos: Vector3, player_pos: Vector3) -> float:
	return player_pos.distance_to(world_pos)

## Check if position is within radar range
func is_within_radar_range(distance: float) -> bool:
	return distance <= radar_range

## Set radar range and recalculate scale
func set_radar_range(new_range: float) -> void:
	radar_range = new_range
	_calculate_current_scale()
	_calculate_range_rings()

## Get range rings for display
func get_range_rings() -> Array[Dictionary]:
	var rings: Array[Dictionary] = []
	
	for i in range(range_ring_count):
		var ring_range = range_rings[i]
		var ring_radius = (ring_range / radar_range) * radar_radius
		
		rings.append({
			"center": radar_center,
			"radius": ring_radius,
			"range": ring_range,
			"visible": ring_radius > 10.0  # Only show rings with reasonable size
		})
	
	return rings

## Get radar display bounds
func get_radar_bounds() -> Rect2:
	var top_left = radar_center - Vector2(radar_radius, radar_radius)
	var size = Vector2(radar_radius * 2, radar_radius * 2)
	return Rect2(top_left, size)

## Check if radar position is within display bounds
func is_within_display_bounds(radar_pos: Vector2) -> bool:
	var bounds = get_radar_bounds()
	return bounds.has_point(radar_pos)

## Get relative bearing to world position
func get_bearing_to_position(world_pos: Vector3, player_pos: Vector3, player_orient: Quaternion) -> float:
	var relative_pos = world_pos - player_pos
	var rotated_pos = player_orient.inverse() * relative_pos
	
	# Calculate bearing in degrees (0 = forward, 90 = right, etc.)
	var bearing = rad_to_deg(atan2(rotated_pos.x, rotated_pos.z))
	
	# Normalize to 0-360 degrees
	if bearing < 0:
		bearing += 360
	
	return bearing

## Get radar display center point
func get_radar_center() -> Vector2:
	return radar_center

## Get radar display radius
func get_radar_radius() -> float:
	return radar_radius

## Get current scale factor
func get_current_scale() -> float:
	return current_scale

## Private methods

func _calculate_current_scale() -> void:
	# Calculate scale to fit radar range within display radius
	if radar_range > 0:
		current_scale = radar_radius / radar_range
	else:
		current_scale = 1.0

func _calculate_range_rings() -> void:
	range_rings.clear()
	
	if radar_range <= 0:
		return
	
	# Create evenly spaced range rings
	for i in range(1, range_ring_count + 1):
		var ring_range = (radar_range * i) / range_ring_count
		range_rings.append(ring_range)

func _clamp_to_radar_bounds(pos: Vector2) -> Vector2:
	# Clamp position to stay within radar display circle
	var offset_from_center = pos - radar_center
	var distance_from_center = offset_from_center.length()
	
	if distance_from_center > radar_radius:
		# Project to edge of radar circle
		var direction = offset_from_center.normalized()
		return radar_center + direction * radar_radius
	
	return pos

func _generate_cache_key(world_pos: Vector3, player_pos: Vector3, player_orient: Quaternion) -> String:
	# Generate cache key with reduced precision for better cache hits
	var precision = 10.0  # Round to nearest 10 units
	
	var rounded_world = Vector3(
		round(world_pos.x / precision) * precision,
		round(world_pos.y / precision) * precision,
		round(world_pos.z / precision) * precision
	)
	
	var rounded_player = Vector3(
		round(player_pos.x / precision) * precision,
		round(player_pos.y / precision) * precision,
		round(player_pos.z / precision) * precision
	)
	
	# Simplified orientation cache key
	var orient_key = "%d_%d_%d" % [
		int(player_orient.x * 100),
		int(player_orient.y * 100),
		int(player_orient.z * 100)
	]
	
	return "%s_%s_%s" % [str(rounded_world), str(rounded_player), orient_key]

func _clear_transform_cache_if_needed() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	if current_time - last_cache_clear > cache_ttl * 10:  # Clear cache every second
		transform_cache.clear()
		last_cache_clear = current_time

## Coordinate conversion utilities

## Convert screen position to world direction
func screen_to_world_direction(screen_pos: Vector2, player_orient: Quaternion) -> Vector3:
	# Convert screen position to radar-relative position
	var radar_offset = screen_pos - radar_center
	
	# Convert to world-relative direction
	var world_direction_2d = radar_offset / current_scale
	var world_direction_3d = Vector3(world_direction_2d.x, 0, world_direction_2d.y)
	
	# Rotate by player orientation
	return player_orient * world_direction_3d

## Get world position from radar coordinates
func radar_to_world_position(radar_pos: Vector2, player_pos: Vector3, player_orient: Quaternion, distance: float) -> Vector3:
	var direction = screen_to_world_direction(radar_pos, player_orient)
	return player_pos + direction.normalized() * distance

## Advanced spatial calculations

## Calculate intercept point for moving target
func calculate_intercept_point(target_pos: Vector3, target_vel: Vector3, interceptor_pos: Vector3, interceptor_speed: float) -> Vector3:
	var relative_pos = target_pos - interceptor_pos
	var relative_vel = target_vel
	
	# Solve quadratic equation for intercept time
	var a = relative_vel.dot(relative_vel) - interceptor_speed * interceptor_speed
	var b = 2.0 * relative_pos.dot(relative_vel)
	var c = relative_pos.dot(relative_pos)
	
	var discriminant = b * b - 4 * a * c
	
	if discriminant < 0 or abs(a) < 0.001:
		# No solution or degenerate case
		return target_pos
	
	var t1 = (-b - sqrt(discriminant)) / (2 * a)
	var t2 = (-b + sqrt(discriminant)) / (2 * a)
	
	# Choose the positive, smaller solution
	var t = t1 if t1 > 0 else t2
	if t <= 0:
		return target_pos  # No valid intercept
	
	return target_pos + target_vel * t

## Calculate formation center for multiple targets
func calculate_formation_center(positions: Array[Vector3]) -> Vector3:
	if positions.is_empty():
		return Vector3.ZERO
	
	var center = Vector3.ZERO
	for pos in positions:
		center += pos
	
	return center / positions.size()

## Get spatial relationship between two objects
func get_spatial_relationship(pos1: Vector3, pos2: Vector3, reference_pos: Vector3) -> Dictionary:
	var dist1 = reference_pos.distance_to(pos1)
	var dist2 = reference_pos.distance_to(pos2)
	var separation = pos1.distance_to(pos2)
	
	var vec1 = (pos1 - reference_pos).normalized()
	var vec2 = (pos2 - reference_pos).normalized()
	var angle = rad_to_deg(acos(vec1.dot(vec2)))
	
	return {
		"distance_1": dist1,
		"distance_2": dist2,
		"separation": separation,
		"angular_separation": angle,
		"relative_bearing": angle
	}

## Debug and utility methods

## Get debug information
func get_debug_info() -> Dictionary:
	return {
		"radar_center": radar_center,
		"radar_radius": radar_radius,
		"current_scale": current_scale,
		"radar_range": radar_range,
		"display_size": display_size,
		"elevation_scale": elevation_scale,
		"cache_size": transform_cache.size(),
		"range_rings": range_rings.size(),
		"transform_precision": transform_precision
	}

## Set elevation scale factor
func set_elevation_scale(scale: float) -> void:
	elevation_scale = clamp(scale, 0.1, 2.0)

## Set transform precision
func set_transform_precision(precision: float) -> void:
	transform_precision = clamp(precision, 0.1, 2.0)

## Enable/disable LOD
func set_lod_enabled(enabled: bool) -> void:
	use_lod = enabled

## Set LOD distance threshold
func set_lod_threshold(threshold: float) -> void:
	lod_distance_threshold = max(1000.0, threshold)
