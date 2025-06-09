class_name ShipLODManager
extends Node

## SHIP-016 AC2: LOD (Level of Detail) Manager with distance-based quality scaling
## Scales ship complexity, effect quality, and update frequency based on distance and screen importance
## Implements multi-tier LOD system for optimal performance during large battles

signal lod_level_changed(object: Node3D, old_level: int, new_level: int)
signal quality_scaling_applied(category: String, objects_affected: int, quality_level: int)
signal distance_threshold_changed(tier: int, old_distance: float, new_distance: float)

# LOD configuration
@export var enable_lod_system: bool = true
@export var update_frequency: float = 0.2  # How often to recalculate LOD (5 times per second)
@export var distance_calculation_method: DistanceMethod = DistanceMethod.CAMERA_DISTANCE
@export var screen_importance_factor: float = 1.0  # Weight of screen space importance
@export var player_ship_lod_boost: float = 2.0  # Multiplier for player ship importance

# LOD levels and thresholds
enum LODLevel {
	MAXIMUM = 0,     # Full detail, all features enabled
	HIGH = 1,        # High detail, minor optimizations
	MEDIUM = 2,      # Balanced detail and performance
	LOW = 3,         # Reduced detail, significant optimizations
	MINIMAL = 4      # Minimum detail, maximum performance
}

enum DistanceMethod {
	CAMERA_DISTANCE,    # Distance from active camera
	PLAYER_DISTANCE,    # Distance from player ship
	SCREEN_SPACE        # Based on screen space occupied
}

# Distance thresholds for each LOD level (in units)
var lod_distance_thresholds: Array[float] = [
	50.0,   # MAXIMUM to HIGH
	150.0,  # HIGH to MEDIUM  
	400.0,  # MEDIUM to LOW
	1000.0  # LOW to MINIMAL
]

# Screen space thresholds (percentage of screen)
var screen_space_thresholds: Array[float] = [
	10.0,   # MAXIMUM (>10% of screen)
	5.0,    # HIGH (5-10% of screen)
	2.0,    # MEDIUM (2-5% of screen)
	0.5     # LOW (0.5-2% of screen)
]

# Camera and player references
var active_camera: Camera3D = null
var player_ship: Node3D = null
var camera_position: Vector3 = Vector3.ZERO

# LOD management
var lod_objects: Dictionary = {}  # Node -> LODObjectData
var update_timer: float = 0.0
var last_camera_position: Vector3 = Vector3.ZERO
var camera_moved_threshold: float = 10.0  # Only update if camera moved significantly

# Performance tracking
var total_objects_managed: int = 0
var objects_by_lod_level: Dictionary = {
	LODLevel.MAXIMUM: 0,
	LODLevel.HIGH: 0,
	LODLevel.MEDIUM: 0,
	LODLevel.LOW: 0,
	LODLevel.MINIMAL: 0
}

# LOD object data structure
class LODObjectData:
	var node: Node3D
	var current_lod_level: LODLevel = LODLevel.MAXIMUM
	var last_distance: float = 0.0
	var last_screen_space: float = 100.0
	var importance_multiplier: float = 1.0
	var lod_components: Dictionary = {}  # Component name -> LODComponent
	var update_skip_counter: int = 0
	var force_high_lod: bool = false  # For important objects like player ship

# LOD component interface
class LODComponent:
	var component_name: String
	var node: Node
	var lod_settings: Dictionary = {}
	
	func apply_lod_level(level: LODLevel) -> void:
		# Override in subclasses
		pass

func _ready() -> void:
	set_process(enable_lod_system)
	_initialize_lod_system()
	print("LODManager: Distance-based quality scaling system initialized")

## Initialize the LOD management system
func _initialize_lod_system() -> void:
	# Find active camera
	_update_camera_reference()
	
	# Find player ship
	_update_player_ship_reference()
	
	# Initialize object tracking
	total_objects_managed = 0
	lod_objects.clear()

func _process(delta: float) -> void:
	if not enable_lod_system:
		return
	
	update_timer += delta
	
	# Update at specified frequency or when camera moves significantly
	var camera_moved: bool = _check_camera_movement()
	
	if update_timer >= update_frequency or camera_moved:
		_update_lod_system()
		update_timer = 0.0
		last_camera_position = camera_position

## Update the entire LOD system
func _update_lod_system() -> void:
	_update_camera_reference()
	_update_player_ship_reference()
	
	if not active_camera:
		return
	
	camera_position = active_camera.global_position
	
	# Update LOD for all registered objects
	for node in lod_objects.keys():
		if not is_instance_valid(node):
			lod_objects.erase(node)
			continue
		
		var lod_data: LODObjectData = lod_objects[node]
		_update_object_lod(lod_data)
	
	# Update performance statistics
	_update_lod_statistics()

## Update LOD level for a specific object
func _update_object_lod(lod_data: LODObjectData) -> void:
	if not is_instance_valid(lod_data.node):
		return
	
	var node: Node3D = lod_data.node
	var old_lod_level: LODLevel = lod_data.current_lod_level
	
	# Skip update based on current LOD level (lower detail objects updated less frequently)
	lod_data.update_skip_counter += 1
	var skip_threshold: int = _get_update_skip_threshold(old_lod_level)
	if lod_data.update_skip_counter < skip_threshold and not lod_data.force_high_lod:
		return
	lod_data.update_skip_counter = 0
	
	# Calculate distance and importance
	var distance: float = _calculate_object_distance(node)
	var screen_space: float = _calculate_screen_space_percentage(node, distance)
	var importance: float = _calculate_object_importance(node, distance, screen_space)
	
	# Determine new LOD level
	var new_lod_level: LODLevel = _determine_lod_level(distance, screen_space, importance, lod_data.force_high_lod)
	
	# Apply LOD changes if level changed
	if new_lod_level != old_lod_level:
		_apply_lod_level_to_object(lod_data, new_lod_level)
		lod_level_changed.emit(node, old_lod_level, new_lod_level)
	
	# Update stored data
	lod_data.current_lod_level = new_lod_level
	lod_data.last_distance = distance
	lod_data.last_screen_space = screen_space

## Calculate distance to object based on selected method
func _calculate_object_distance(node: Node3D) -> float:
	match distance_calculation_method:
		DistanceMethod.CAMERA_DISTANCE:
			return camera_position.distance_to(node.global_position)
		DistanceMethod.PLAYER_DISTANCE:
			if player_ship:
				return player_ship.global_position.distance_to(node.global_position)
			else:
				return camera_position.distance_to(node.global_position)
		DistanceMethod.SCREEN_SPACE:
			return camera_position.distance_to(node.global_position)
	
	return 0.0

## Calculate screen space percentage occupied by object
func _calculate_screen_space_percentage(node: Node3D, distance: float) -> float:
	if not active_camera or distance <= 0.0:
		return 0.0
	
	# Estimate object size (could be improved with actual bounds)
	var estimated_size: float = 10.0  # Default object size
	
	# Get object bounds if available
	if node.has_method("get_aabb"):
		var aabb: AABB = node.get_aabb()
		estimated_size = aabb.size.length()
	elif node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			var aabb: AABB = mesh_instance.mesh.get_aabb()
			estimated_size = aabb.size.length()
	
	# Project to screen space
	var angular_size: float = estimated_size / distance
	var screen_percentage: float = (angular_size / active_camera.fov) * 100.0
	
	return min(100.0, screen_percentage)

## Calculate object importance for LOD prioritization
func _calculate_object_importance(node: Node3D, distance: float, screen_space: float) -> float:
	var importance: float = 1.0
	
	# Screen space importance
	importance *= (screen_space * screen_importance_factor)
	
	# Player ship gets priority
	if node == player_ship:
		importance *= player_ship_lod_boost
	
	# Ship objects are more important than effects
	if node.has_method("get_ship_class"):
		importance *= 1.5
	
	# Combat-active objects are more important
	if node.has_method("is_in_combat") and node.is_in_combat():
		importance *= 1.3
	
	# Distance-based importance falloff
	importance *= 1.0 / (1.0 + distance * 0.001)
	
	return importance

## Determine LOD level based on distance, screen space, and importance
func _determine_lod_level(distance: float, screen_space: float, importance: float, force_high: bool) -> LODLevel:
	if force_high:
		return LODLevel.MAXIMUM
	
	# Adjust thresholds based on importance
	var adjusted_distance_thresholds: Array[float] = []
	var adjusted_screen_thresholds: Array[float] = []
	
	for i in range(lod_distance_thresholds.size()):
		adjusted_distance_thresholds.append(lod_distance_thresholds[i] * importance)
		adjusted_screen_thresholds.append(screen_space_thresholds[i] / importance)
	
	# Primary decision based on distance
	var distance_lod: LODLevel = LODLevel.MINIMAL
	for i in range(adjusted_distance_thresholds.size()):
		if distance <= adjusted_distance_thresholds[i]:
			distance_lod = i as LODLevel
			break
	
	# Secondary decision based on screen space
	var screen_lod: LODLevel = LODLevel.MINIMAL
	for i in range(adjusted_screen_thresholds.size()):
		if screen_space >= adjusted_screen_thresholds[i]:
			screen_lod = i as LODLevel
			break
	
	# Take the higher quality LOD of the two
	return min(distance_lod, screen_lod) as LODLevel

## Apply LOD level to object and all its components
func _apply_lod_level_to_object(lod_data: LODObjectData, lod_level: LODLevel) -> void:
	var node: Node3D = lod_data.node
	
	# Apply to all registered components
	for component_name in lod_data.lod_components.keys():
		var component: LODComponent = lod_data.lod_components[component_name]
		component.apply_lod_level(lod_level)
	
	# Apply built-in LOD optimizations
	_apply_builtin_lod_optimizations(node, lod_level)

## Apply built-in LOD optimizations for common object types
func _apply_builtin_lod_optimizations(node: Node3D, lod_level: LODLevel) -> void:
	# Mesh LOD for MeshInstance3D nodes
	if node is MeshInstance3D:
		_apply_mesh_lod(node as MeshInstance3D, lod_level)
	
	# Particle LOD for GPUParticles3D nodes
	if node is GPUParticles3D:
		_apply_particle_lod(node as GPUParticles3D, lod_level)
	
	# Audio LOD for AudioStreamPlayer3D nodes
	var audio_players: Array[Node] = node.find_children("*", "AudioStreamPlayer3D")
	for audio_player in audio_players:
		_apply_audio_lod(audio_player as AudioStreamPlayer3D, lod_level)
	
	# Ship-specific LOD optimizations
	if node.has_method("set_update_frequency"):
		var update_frequency: float = _get_update_frequency_for_lod(lod_level)
		node.set_update_frequency(update_frequency)

## Apply mesh LOD optimizations
func _apply_mesh_lod(mesh_instance: MeshInstance3D, lod_level: LODLevel) -> void:
	# Adjust material quality
	match lod_level:
		LODLevel.MAXIMUM:
			mesh_instance.material_override = null  # Use full materials
		LODLevel.HIGH:
			# Slightly reduced material quality
			pass
		LODLevel.MEDIUM:
			# Use simplified materials
			pass
		LODLevel.LOW:
			# Use basic materials
			pass
		LODLevel.MINIMAL:
			# Use minimal materials or hide completely at extreme distance
			mesh_instance.visible = mesh_instance.global_position.distance_to(camera_position) < 2000.0

## Apply particle LOD optimizations
func _apply_particle_lod(particles: GPUParticles3D, lod_level: LODLevel) -> void:
	var original_amount: int = particles.get("original_amount")
	if original_amount == 0:
		original_amount = particles.amount
		particles.set("original_amount", original_amount)
	
	match lod_level:
		LODLevel.MAXIMUM:
			particles.amount = original_amount
			particles.emitting = true
		LODLevel.HIGH:
			particles.amount = int(original_amount * 0.8)
			particles.emitting = true
		LODLevel.MEDIUM:
			particles.amount = int(original_amount * 0.5)
			particles.emitting = true
		LODLevel.LOW:
			particles.amount = int(original_amount * 0.3)
			particles.emitting = true
		LODLevel.MINIMAL:
			particles.emitting = false

## Apply audio LOD optimizations
func _apply_audio_lod(audio: AudioStreamPlayer3D, lod_level: LODLevel) -> void:
	match lod_level:
		LODLevel.MAXIMUM:
			audio.max_distance = 1000.0
		LODLevel.HIGH:
			audio.max_distance = 800.0
		LODLevel.MEDIUM:
			audio.max_distance = 500.0
		LODLevel.LOW:
			audio.max_distance = 300.0
		LODLevel.MINIMAL:
			audio.max_distance = 100.0

## Get update frequency multiplier for LOD level
func _get_update_frequency_for_lod(lod_level: LODLevel) -> float:
	match lod_level:
		LODLevel.MAXIMUM:
			return 1.0
		LODLevel.HIGH:
			return 0.8
		LODLevel.MEDIUM:
			return 0.5
		LODLevel.LOW:
			return 0.25
		LODLevel.MINIMAL:
			return 0.1
	return 1.0

## Get update skip threshold for LOD level
func _get_update_skip_threshold(lod_level: LODLevel) -> int:
	match lod_level:
		LODLevel.MAXIMUM:
			return 1  # Update every frame
		LODLevel.HIGH:
			return 2  # Update every 2 frames
		LODLevel.MEDIUM:
			return 4  # Update every 4 frames
		LODLevel.LOW:
			return 8  # Update every 8 frames
		LODLevel.MINIMAL:
			return 16  # Update every 16 frames
	return 1

## Check if camera has moved significantly
func _check_camera_movement() -> bool:
	if not active_camera:
		return false
	
	var current_pos: Vector3 = active_camera.global_position
	var distance_moved: float = current_pos.distance_to(last_camera_position)
	
	return distance_moved > camera_moved_threshold

## Update camera reference
func _update_camera_reference() -> void:
	if not active_camera:
		var viewport: Viewport = get_viewport()
		if viewport:
			active_camera = viewport.get_camera_3d()

## Update player ship reference
func _update_player_ship_reference() -> void:
	if not player_ship:
		# Try to find player ship through game state
		var game_state = get_node_or_null("/root/GameStateManager")
		if game_state and game_state.has_method("get_player_ship"):
			player_ship = game_state.get_player_ship()

## Update LOD statistics
func _update_lod_statistics() -> void:
	# Reset counters
	for level in objects_by_lod_level.keys():
		objects_by_lod_level[level] = 0
	
	# Count objects by LOD level
	for lod_data in lod_objects.values():
		if is_instance_valid(lod_data.node):
			objects_by_lod_level[lod_data.current_lod_level] += 1
	
	total_objects_managed = lod_objects.size()

# Public API

## Register object for LOD management
func register_lod_object(node: Node3D, importance_multiplier: float = 1.0, force_high_lod: bool = false) -> bool:
	if not node or lod_objects.has(node):
		return false
	
	var lod_data: LODObjectData = LODObjectData.new()
	lod_data.node = node
	lod_data.importance_multiplier = importance_multiplier
	lod_data.force_high_lod = force_high_lod
	
	lod_objects[node] = lod_data
	
	print("LODManager: Registered object %s for LOD management" % node.name)
	return true

## Unregister object from LOD management
func unregister_lod_object(node: Node3D) -> bool:
	if not lod_objects.has(node):
		return false
	
	lod_objects.erase(node)
	print("LODManager: Unregistered object %s from LOD management" % node.name)
	return true

## Register LOD component for an object
func register_lod_component(node: Node3D, component: LODComponent) -> bool:
	if not lod_objects.has(node):
		return false
	
	var lod_data: LODObjectData = lod_objects[node]
	lod_data.lod_components[component.component_name] = component
	
	return true

## Set LOD distance thresholds
func set_lod_distance_thresholds(thresholds: Array[float]) -> void:
	if thresholds.size() >= 4:
		var old_thresholds: Array[float] = lod_distance_thresholds.duplicate()
		lod_distance_thresholds = thresholds
		
		for i in range(min(4, thresholds.size())):
			distance_threshold_changed.emit(i, old_thresholds[i], thresholds[i])
		
		print("LODManager: Updated distance thresholds: %s" % str(thresholds))

## Set screen space thresholds
func set_screen_space_thresholds(thresholds: Array[float]) -> void:
	if thresholds.size() >= 4:
		screen_space_thresholds = thresholds
		print("LODManager: Updated screen space thresholds: %s" % str(thresholds))

## Force LOD level for specific object
func force_lod_level(node: Node3D, lod_level: LODLevel) -> bool:
	if not lod_objects.has(node):
		return false
	
	var lod_data: LODObjectData = lod_objects[node]
	var old_level: LODLevel = lod_data.current_lod_level
	
	_apply_lod_level_to_object(lod_data, lod_level)
	lod_data.current_lod_level = lod_level
	
	lod_level_changed.emit(node, old_level, lod_level)
	return true

## Get current LOD level for object
func get_object_lod_level(node: Node3D) -> LODLevel:
	if lod_objects.has(node):
		return lod_objects[node].current_lod_level
	return LODLevel.MAXIMUM

## Get LOD system statistics
func get_lod_statistics() -> Dictionary:
	return {
		"total_objects_managed": total_objects_managed,
		"objects_by_lod_level": objects_by_lod_level.duplicate(),
		"distance_thresholds": lod_distance_thresholds.duplicate(),
		"screen_space_thresholds": screen_space_thresholds.duplicate(),
		"update_frequency": update_frequency,
		"camera_position": camera_position,
		"player_ship_position": player_ship.global_position if player_ship else Vector3.ZERO,
		"lod_system_enabled": enable_lod_system
	}

## Enable/disable LOD system
func set_lod_system_enabled(enabled: bool) -> void:
	enable_lod_system = enabled
	set_process(enabled)
	
	if not enabled:
		# Reset all objects to maximum LOD
		for lod_data in lod_objects.values():
			_apply_lod_level_to_object(lod_data, LODLevel.MAXIMUM)
			lod_data.current_lod_level = LODLevel.MAXIMUM
	
	print("LODManager: LOD system %s" % ("enabled" if enabled else "disabled"))

## Set LOD update frequency
func set_update_frequency(frequency: float) -> void:
	update_frequency = max(0.05, frequency)  # Minimum 20Hz
	print("LODManager: Update frequency set to %.2f Hz" % (1.0 / update_frequency))