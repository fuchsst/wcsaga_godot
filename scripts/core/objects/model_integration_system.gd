class_name ModelIntegrationSystem
extends Node

## Enhanced 3D model loading and integration system for BaseSpaceObject
## Integrates with EPIC-008 Graphics Rendering Engine and EPIC-002 wcs_asset_core
## Provides model loading, LOD management, collision shape generation, and subsystem integration

# EPIC-002 Asset Core Integration (AC2 - MANDATORY)
const ModelMetadata = preload("res://addons/wcs_asset_core/resources/object/model_metadata.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# Model Integration Signals (AC7)
signal model_loaded(space_object: BaseSpaceObject, model_resource: Mesh)
signal model_load_failed(space_object: BaseSpaceObject, error_message: String)
signal lod_level_changed(space_object: BaseSpaceObject, old_level: int, new_level: int)
signal collision_shape_generated(space_object: BaseSpaceObject, collision_shape: CollisionShape3D)
signal subsystem_damage_state_changed(space_object: BaseSpaceObject, subsystem_name: String, damage_state: float)

# Performance metrics tracking
var _load_time_start: int = 0
var _load_performance_history: Array[float] = []
var _lod_switch_performance_history: Array[float] = []

# EPIC-008 Graphics Integration references (will be initialized at runtime)
var graphics_engine: Node = null
var texture_manager: Node = null
var lod_manager: Node = null
var performance_monitor: Node = null

# Cache for loaded models to prevent duplicate loading
var _model_cache: Dictionary = {}
var _metadata_cache: Dictionary = {}

func _ready() -> void:
	name = "ModelIntegrationSystem"
	_initialize_graphics_integration()

## Initialize EPIC-008 Graphics Rendering Engine integration (AC1)
func _initialize_graphics_integration() -> void:
	# Connect to EPIC-008 Graphics Rendering Engine
	graphics_engine = get_node_or_null("/root/GraphicsRenderingEngine")
	if graphics_engine == null:
		push_warning("ModelIntegrationSystem: Graphics Rendering Engine not found")
		return
	
	# Access graphics subsystems through the engine
	texture_manager = graphics_engine.get("texture_streamer")
	lod_manager = graphics_engine.get("model_renderer") 
	performance_monitor = graphics_engine.get("performance_monitor")
	
	print("ModelIntegrationSystem: Successfully integrated with EPIC-008 Graphics Rendering Engine")

## Load 3D model for BaseSpaceObject with EPIC-008 integration (AC1, AC5)
func load_model_for_object(space_object: BaseSpaceObject, model_path: String) -> bool:
	if not space_object or model_path.is_empty():
		push_error("ModelIntegrationSystem: Invalid parameters for model loading")
		return false
	
	_load_time_start = Time.get_ticks_msec()
	
	# Check cache first for performance
	if _model_cache.has(model_path):
		var cached_model: Mesh = _model_cache[model_path]
		return _apply_model_to_object(space_object, cached_model, model_path)
	
	# Load model resource (POF models converted to Godot Mesh via EPIC-003 wcs_converter addon)
	# The EPIC-003 conversion pipeline converts POF files to .tres Mesh resources with LOD support
	var model_resource: Mesh = load(model_path) as Mesh
	if model_resource == null:
		var error_msg: String = "Failed to load model resource at path: %s" % model_path
		push_error("ModelIntegrationSystem: " + error_msg)
		model_load_failed.emit(space_object, error_msg)
		return false
	
	# Cache the loaded model
	_model_cache[model_path] = model_resource
	
	return _apply_model_to_object(space_object, model_resource, model_path)

## Apply loaded model to BaseSpaceObject with performance tracking (AC6)
func _apply_model_to_object(space_object: BaseSpaceObject, model_resource: Mesh, model_path: String) -> bool:
	# Ensure space object has mesh instance component
	if not space_object.mesh_instance:
		push_error("ModelIntegrationSystem: BaseSpaceObject missing mesh_instance component")
		return false
	
	# Apply model to mesh instance
	space_object.mesh_instance.mesh = model_resource
	
	# Load and apply model metadata extracted from POF during EPIC-003 conversion (AC2)
	# POF subsystems, weapon banks, docking points converted to ModelMetadata resources
	var metadata_path: String = model_path.get_basename() + "_metadata.tres"
	var model_metadata: ModelMetadata = _load_model_metadata(metadata_path)
	if model_metadata:
		_apply_model_metadata(space_object, model_metadata)
	
	# Generate collision shapes from mesh data (AC4)
	if not _generate_collision_shape_from_mesh(space_object, model_resource):
		push_warning("ModelIntegrationSystem: Failed to generate collision shape for %s" % model_path)
	
	# Track loading performance (AC6)
	var load_time: float = (Time.get_ticks_msec() - _load_time_start) / 1000.0
	_load_performance_history.append(load_time)
	if _load_performance_history.size() > 100:
		_load_performance_history.pop_front()
	
	# Validate performance target: Model loading under 5ms (AC6)
	if load_time > 0.005:  # 5ms
		push_warning("ModelIntegrationSystem: Model loading exceeded 5ms target: %.3fms for %s" % [load_time * 1000, model_path])
	
	model_loaded.emit(space_object, model_resource)
	return true

## Load model metadata resource with caching (AC2)
func _load_model_metadata(metadata_path: String) -> ModelMetadata:
	# Check cache first
	if _metadata_cache.has(metadata_path):
		return _metadata_cache[metadata_path]
	
	# Check if metadata file exists
	if not FileAccess.file_exists(metadata_path):
		return null
	
	# Load metadata resource
	var metadata: ModelMetadata = load(metadata_path) as ModelMetadata
	if metadata:
		_metadata_cache[metadata_path] = metadata
	
	return metadata

## Apply model metadata to space object for weapon banks, docking points, etc.
func _apply_model_metadata(space_object: BaseSpaceObject, metadata: ModelMetadata) -> void:
	# Store metadata reference for subsystem integration
	space_object.set_meta("model_metadata", metadata)
	
	# Apply weapon bank positions for combat system integration
	if metadata.gun_banks.size() > 0 or metadata.missile_banks.size() > 0:
		_setup_weapon_hardpoints(space_object, metadata)
	
	# Apply docking points for docking system integration
	if metadata.docking_points.size() > 0:
		_setup_docking_points(space_object, metadata)
	
	# Apply thruster banks for movement system integration
	if metadata.thruster_banks.size() > 0:
		_setup_thruster_effects(space_object, metadata)

## Setup weapon hardpoints from model metadata
func _setup_weapon_hardpoints(space_object: BaseSpaceObject, metadata: ModelMetadata) -> void:
	# Create weapon hardpoint markers for combat system
	for i in range(metadata.gun_banks.size()):
		var gun_bank: ModelMetadata.WeaponBank = metadata.gun_banks[i]
		for j in range(gun_bank.points.size()):
			var point: ModelMetadata.PointDefinition = gun_bank.points[j]
			var hardpoint: Marker3D = Marker3D.new()
			hardpoint.name = "GunHardpoint_%d_%d" % [i, j]
			hardpoint.position = point.position
			hardpoint.look_at(hardpoint.position + point.normal, Vector3.UP)
			space_object.add_child(hardpoint)
	
	for i in range(metadata.missile_banks.size()):
		var missile_bank: ModelMetadata.WeaponBank = metadata.missile_banks[i]
		for j in range(missile_bank.points.size()):
			var point: ModelMetadata.PointDefinition = missile_bank.points[j]
			var hardpoint: Marker3D = Marker3D.new()
			hardpoint.name = "MissileHardpoint_%d_%d" % [i, j]
			hardpoint.position = point.position
			hardpoint.look_at(hardpoint.position + point.normal, Vector3.UP)
			space_object.add_child(hardpoint)

## Setup docking points from model metadata
func _setup_docking_points(space_object: BaseSpaceObject, metadata: ModelMetadata) -> void:
	for i in range(metadata.docking_points.size()):
		var dock_point: ModelMetadata.DockPoint = metadata.docking_points[i]
		var dock_marker: Marker3D = Marker3D.new()
		dock_marker.name = "DockPoint_%s" % dock_point.name
		if dock_point.points.size() > 0:
			dock_marker.position = dock_point.points[0].position
			if dock_point.points.size() > 1:
				dock_marker.look_at(dock_marker.position + dock_point.points[0].normal, Vector3.UP)
		space_object.add_child(dock_marker)

## Setup thruster effects from model metadata
func _setup_thruster_effects(space_object: BaseSpaceObject, metadata: ModelMetadata) -> void:
	for i in range(metadata.thruster_banks.size()):
		var thruster_bank: ModelMetadata.ThrusterBank = metadata.thruster_banks[i]
		for j in range(thruster_bank.points.size()):
			var point: ModelMetadata.PointDefinition = thruster_bank.points[j]
			var thruster_effect: Marker3D = Marker3D.new()
			thruster_effect.name = "ThrusterEffect_%d_%d" % [i, j]
			thruster_effect.position = point.position
			thruster_effect.look_at(thruster_effect.position - point.normal, Vector3.UP)  # Opposite direction
			space_object.add_child(thruster_effect)

## Generate collision shape from 3D mesh data (AC4)
func _generate_collision_shape_from_mesh(space_object: BaseSpaceObject, model_resource: Mesh) -> bool:
	if not space_object.collision_shape or not space_object.physics_body:
		push_error("ModelIntegrationSystem: BaseSpaceObject missing collision components")
		return false
	
	# Generate trimesh collision shape from mesh
	var collision_mesh: ArrayMesh = model_resource as ArrayMesh
	if not collision_mesh:
		push_warning("ModelIntegrationSystem: Model is not ArrayMesh, cannot generate collision shape")
		return false
	
	# Create trimesh collision shape
	var trimesh_shape: ConcavePolygonShape3D = collision_mesh.create_trimesh_shape()
	if not trimesh_shape:
		push_error("ModelIntegrationSystem: Failed to create trimesh collision shape")
		return false
	
	# Apply collision shape to space object
	space_object.collision_shape.shape = trimesh_shape
	
	collision_shape_generated.emit(space_object, space_object.collision_shape)
	return true

## Set LOD level with EPIC-008 integration and performance tracking (AC3)
func set_lod_level(space_object: BaseSpaceObject, new_lod_level: int) -> bool:
	if not space_object or not space_object.mesh_instance:
		return false
	
	var lod_switch_start: int = Time.get_ticks_msec()
	var current_lod: int = space_object.get_meta("current_lod_level", 0)
	
	if current_lod == new_lod_level:
		return true  # No change needed
	
	# Get model metadata for LOD information
	var metadata: ModelMetadata = space_object.get_meta("model_metadata", null)
	if not metadata or new_lod_level >= metadata.detail_level_paths.size():
		return false
	
	# Load LOD model (converted from POF detail levels by EPIC-003 conversion)
	# detail_level_paths contain paths to converted Mesh resources for each LOD level
	var lod_model_path: String = metadata.detail_level_paths[new_lod_level]
	var lod_model: Mesh = load(lod_model_path) as Mesh
	if not lod_model:
		push_error("ModelIntegrationSystem: Failed to load LOD level %d model: %s" % [new_lod_level, lod_model_path])
		return false
	
	# Apply LOD model
	space_object.mesh_instance.mesh = lod_model
	space_object.set_meta("current_lod_level", new_lod_level)
	
	# Track LOD switching performance (AC3)
	var switch_time: float = (Time.get_ticks_msec() - lod_switch_start) / 1000.0
	_lod_switch_performance_history.append(switch_time)
	if _lod_switch_performance_history.size() > 100:
		_lod_switch_performance_history.pop_front()
	
	# Validate performance target: LOD switching under 0.1ms (AC3)
	if switch_time > 0.0001:  # 0.1ms
		push_warning("ModelIntegrationSystem: LOD switch exceeded 0.1ms target: %.3fms" % [switch_time * 1000])
	
	# Notify EPIC-008 LOD manager if available
	if lod_manager and lod_manager.has_method("notify_lod_change"):
		lod_manager.notify_lod_change(space_object, new_lod_level)
	
	lod_level_changed.emit(space_object, current_lod, new_lod_level)
	return true

## Automatic LOD selection based on distance and importance (AC3)
func update_automatic_lod(space_object: BaseSpaceObject, camera_position: Vector3) -> void:
	if not space_object or not space_object.mesh_instance:
		return
	
	var distance: float = space_object.global_position.distance_to(camera_position)
	var metadata: ModelMetadata = space_object.get_meta("model_metadata", null)
	
	if not metadata or metadata.detail_level_paths.size() <= 1:
		return  # No LOD levels available
	
	# Calculate appropriate LOD level based on distance
	var new_lod_level: int = 0
	
	# LOD thresholds (can be made configurable)
	var lod_distances: Array[float] = [50.0, 150.0, 400.0, 1000.0, 2500.0, 5000.0, 10000.0]
	
	for i in range(min(lod_distances.size(), metadata.detail_level_paths.size() - 1)):
		if distance > lod_distances[i]:
			new_lod_level = i + 1
	
	# Cap at maximum available LOD level
	new_lod_level = min(new_lod_level, metadata.detail_level_paths.size() - 1)
	
	# Apply LOD change
	set_lod_level(space_object, new_lod_level)

## Change model dynamically for EPIC-004 SEXP integration (AC8)
func change_model_dynamically(space_object: BaseSpaceObject, new_model_path: String, preserve_state: bool = true) -> bool:
	if not space_object or new_model_path.is_empty():
		return false
	
	# Store current state if requested
	var saved_metadata: Dictionary = {}
	if preserve_state:
		saved_metadata = {
			"position": space_object.global_position,
			"rotation": space_object.global_rotation,
			"current_lod": space_object.get_meta("current_lod_level", 0),
			"health": space_object.get("current_health", 100.0)
		}
	
	# Load new model
	var success: bool = load_model_for_object(space_object, new_model_path)
	
	# Restore state if requested and loading succeeded
	if success and preserve_state:
		space_object.global_position = saved_metadata.get("position", space_object.global_position)
		space_object.global_rotation = saved_metadata.get("rotation", space_object.global_rotation)
		space_object.set_meta("current_lod_level", saved_metadata.get("current_lod", 0))
		if space_object.has_method("set_health"):
			space_object.set_health(saved_metadata.get("health", 100.0))
	
	return success

## Apply damage state to model subsystems (AC7)
func apply_subsystem_damage_state(space_object: BaseSpaceObject, subsystem_name: String, damage_percentage: float) -> void:
	if not space_object:
		return
	
	# Find subsystem node by name
	var subsystem_node: Node3D = space_object.find_child(subsystem_name, false, false) as Node3D
	if not subsystem_node:
		return
	
	# Apply visual damage effects based on damage percentage
	if damage_percentage >= 0.75:  # 75% damaged - heavy damage
		_apply_heavy_damage_effects(subsystem_node)
	elif damage_percentage >= 0.5:  # 50% damaged - moderate damage
		_apply_moderate_damage_effects(subsystem_node)
	elif damage_percentage >= 0.25:  # 25% damaged - light damage
		_apply_light_damage_effects(subsystem_node)
	else:  # Less than 25% - no visible damage
		_clear_damage_effects(subsystem_node)
	
	subsystem_damage_state_changed.emit(space_object, subsystem_name, damage_percentage)

## Apply heavy damage visual effects to subsystem
func _apply_heavy_damage_effects(subsystem_node: Node3D) -> void:
	# Reduce visibility and add damage particles
	subsystem_node.modulate = Color(0.6, 0.4, 0.4, 0.8)  # Darkened, reddish tint
	
	# Add damage particle effect if not already present
	if not subsystem_node.find_child("DamageEffect", false, false):
		var damage_particles: GPUParticles3D = GPUParticles3D.new()
		damage_particles.name = "DamageEffect"
		damage_particles.emitting = true
		damage_particles.amount = 50
		subsystem_node.add_child(damage_particles)

## Apply moderate damage visual effects to subsystem
func _apply_moderate_damage_effects(subsystem_node: Node3D) -> void:
	subsystem_node.modulate = Color(0.8, 0.7, 0.7, 0.9)  # Slightly darkened

## Apply light damage visual effects to subsystem
func _apply_light_damage_effects(subsystem_node: Node3D) -> void:
	subsystem_node.modulate = Color(0.9, 0.85, 0.85, 0.95)  # Very slightly darkened

## Clear damage visual effects from subsystem
func _clear_damage_effects(subsystem_node: Node3D) -> void:
	subsystem_node.modulate = Color.WHITE  # Restore normal appearance
	
	# Remove damage particle effects
	var damage_effect: Node = subsystem_node.find_child("DamageEffect", false, false)
	if damage_effect:
		damage_effect.queue_free()

## Get performance metrics for monitoring (AC6)
func get_performance_metrics() -> Dictionary:
	var avg_load_time: float = 0.0
	var avg_lod_switch_time: float = 0.0
	
	if _load_performance_history.size() > 0:
		for time in _load_performance_history:
			avg_load_time += time
		avg_load_time /= _load_performance_history.size()
	
	if _lod_switch_performance_history.size() > 0:
		for time in _lod_switch_performance_history:
			avg_lod_switch_time += time
		avg_lod_switch_time /= _lod_switch_performance_history.size()
	
	return {
		"average_load_time_ms": avg_load_time * 1000,
		"average_lod_switch_time_ms": avg_lod_switch_time * 1000,
		"load_time_samples": _load_performance_history.size(),
		"lod_switch_samples": _lod_switch_performance_history.size(),
		"model_cache_size": _model_cache.size(),
		"metadata_cache_size": _metadata_cache.size()
	}

## Clear performance history for fresh measurements
func clear_performance_history() -> void:
	_load_performance_history.clear()
	_lod_switch_performance_history.clear()

## Clear model and metadata caches to free memory
func clear_caches() -> void:
	_model_cache.clear()
	_metadata_cache.clear()