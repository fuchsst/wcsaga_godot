class_name WCSModelRenderer
extends Node

## 3D Model Rendering system using converted GLB models and Godot's native rendering pipeline
## Handles model loading, LOD management, and material assignment with WCS integration

signal model_loaded(model_path: String, model_data: WCSModelData)
signal model_loading_failed(model_path: String, error: String)
signal model_instance_created(instance_id: String, model_node: Node3D)
signal model_instance_destroyed(instance_id: String)
signal lod_changed(instance_id: String, new_lod_level: int)
signal performance_warning(metric_name: String, current_value: float, threshold: float)

enum LODLevel {
	HIGH_DETAIL = 0,    # 0-100m: Full detail model
	MEDIUM_DETAIL = 1,  # 100-500m: Reduced detail  
	LOW_DETAIL = 2,     # 500m+: Minimal detail
	IMPOSTOR = 3        # Very far: Billboard/impostor
}

# Model management
var model_cache: Dictionary = {}
var model_instances: Dictionary = {}
var model_pools: Dictionary = {}
var instance_counter: int = 0

# Performance settings
var max_draw_calls: int = 2000
var max_vertices_per_frame: int = 500000
var lod_bias: float = 1.0
var quality_level: int = 2

# Performance monitoring
var current_draw_calls: int = 0
var current_vertices: int = 0
var performance_stats: Dictionary = {}

# Integration systems
var material_system: WCSMaterialSystem
var texture_streamer: WCSTextureStreamer

func _ready() -> void:
	name = "WCSModelRenderer"
	_initialize_model_system()
	_setup_performance_monitoring()
	print("WCSModelRenderer: Initialized with Godot native 3D pipeline")

func _initialize_model_system() -> void:
	# Initialize model pools for common ship types
	_create_model_pools()
	
	# Set up LOD configuration
	_configure_lod_system()

func _create_model_pools() -> void:
	# Pre-create pools for frequently used ship types
	var common_ship_types: Array[String] = [
		"fighter_light",
		"fighter_medium", 
		"fighter_heavy",
		"bomber_light",
		"bomber_heavy",
		"freighter",
		"transport"
	]
	
	for ship_type in common_ship_types:
		model_pools[ship_type] = WCSModelPool.new(ship_type, 10)
		add_child(model_pools[ship_type])

func _configure_lod_system() -> void:
	# Configure Godot's LOD system for space environments
	var lod_settings: Dictionary = {
		LODLevel.HIGH_DETAIL: {"distance": 100.0, "bias": 1.0},
		LODLevel.MEDIUM_DETAIL: {"distance": 500.0, "bias": 0.6},
		LODLevel.LOW_DETAIL: {"distance": 1500.0, "bias": 0.3},
		LODLevel.IMPOSTOR: {"distance": 5000.0, "bias": 0.1}
	}
	
	# Apply LOD bias based on quality level
	match quality_level:
		0, 1:  # Low quality
			lod_bias = 0.5
		2:     # Medium quality  
			lod_bias = 1.0
		3, 4:  # High/Ultra quality
			lod_bias = 2.0

func load_model_data(model_path: String) -> WCSModelData:
	# Check cache first
	if model_path in model_cache:
		return model_cache[model_path]
	
	# Try to load as Resource directly first (for testing/development)
	var model_data: WCSModelData = load(model_path) as WCSModelData
	
	# If not found, try through WCS asset system
	if not model_data and WCSAssetLoader:
		model_data = WCSAssetLoader.load_asset(model_path) as WCSModelData
	
	if not model_data:
		model_loading_failed.emit(model_path, "Failed to load ModelData from asset system")
		return null
	
	# Validate model data
	if not model_data.is_valid():
		model_loading_failed.emit(model_path, "ModelData validation failed")
		return null
	
	# Cache the model data
	model_cache[model_path] = model_data
	model_loaded.emit(model_path, model_data)
	
	return model_data

func create_model_instance(model_path: String, properties: Dictionary = {}) -> String:
	var model_data: WCSModelData = load_model_data(model_path)
	if not model_data:
		return ""
	
	# Generate instance ID
	instance_counter += 1
	var instance_id: String = "model_instance_%d_%s" % [instance_counter, model_data.model_name]
	
	# Create 3D model node using Godot's native systems
	var model_node: Node3D = _create_model_node(model_data, properties)
	if not model_node:
		return ""
	
	# Configure LOD and optimization
	_setup_model_lod(model_node, model_data)
	_setup_model_materials(model_node, model_data)
	_setup_model_physics(model_node, model_data, properties)
	
	# Track instance
	model_instances[instance_id] = {
		"node": model_node,
		"model_data": model_data,
		"properties": properties,
		"created_time": Time.get_ticks_msec(),
		"lod_level": LODLevel.HIGH_DETAIL
	}
	
	model_instance_created.emit(instance_id, model_node)
	return instance_id

func _create_model_node(model_data: WCSModelData, properties: Dictionary) -> Node3D:
	# Load the converted GLB model
	var glb_scene: PackedScene = load(model_data.glb_model_path)
	if not glb_scene:
		push_error("Failed to load GLB model: " + model_data.glb_model_path)
		return null
	
	# Instantiate the model
	var model_node: Node3D = glb_scene.instantiate()
	model_node.name = model_data.model_name
	
	# Apply initial transformations
	var scale_factor: float = properties.get("scale", 1.0)
	model_node.scale = Vector3.ONE * scale_factor
	
	return model_node

func _setup_model_lod(model_node: Node3D, model_data: WCSModelData) -> void:
	# Use Godot's native LOD system
	var lod_meshes: Array = model_data.get_lod_meshes()
	
	if lod_meshes.size() > 1:
		# Find MeshInstance3D nodes and set up LOD
		_configure_mesh_lod(model_node, lod_meshes)

func _configure_mesh_lod(node: Node3D, lod_meshes: Array) -> void:
	# Recursively configure LOD for all MeshInstance3D nodes
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		
		# Configure LOD distances based on model size
		var model_size: float = _estimate_model_size(mesh_instance)
		
		# Set LOD bias and distances
		mesh_instance.lod_bias = lod_bias
		
		# Use Godot's automatic LOD system
		mesh_instance.visibility_range_begin = 0.0
		mesh_instance.visibility_range_end = model_size * 50.0  # Hide at 50x model size
		mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	
	# Recursively configure children
	for child in node.get_children():
		if child is Node3D:
			_configure_mesh_lod(child as Node3D, lod_meshes)

func _setup_model_materials(model_node: Node3D, model_data: WCSModelData) -> void:
	# Apply materials through the material system
	if not material_system:
		return
	
	var material_mappings: Dictionary = model_data.get_material_mappings()
	_apply_materials_recursive(model_node, material_mappings)

func _apply_materials_recursive(node: Node3D, material_mappings: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var node_name: String = mesh_instance.name
		
		# Find material mapping for this mesh
		if node_name in material_mappings:
			var material_path: String = material_mappings[node_name]
			var material: StandardMaterial3D = null
			
			# Try material system if available
			if material_system and material_system.has_method("get_material"):
				material = material_system.get_material(material_path)
			
			# Fallback to direct loading
			if not material:
				material = load(material_path) as StandardMaterial3D
			
			if material:
				mesh_instance.material_override = material
	
	# Recursively apply to children
	for child in node.get_children():
		if child is Node3D:
			_apply_materials_recursive(child as Node3D, material_mappings)

func _setup_model_physics(model_node: Node3D, model_data: WCSModelData, properties: Dictionary) -> void:
	# Add collision shapes if specified
	var use_physics: bool = properties.get("physics_enabled", false)
	if not use_physics:
		return
	
	# Add collision body
	var collision_body: StaticBody3D = StaticBody3D.new()
	collision_body.name = "CollisionBody"
	model_node.add_child(collision_body)
	
	# Add collision shapes from model data
	var collision_shapes: Array = model_data.get_collision_shapes()
	for shape_data in collision_shapes:
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		collision_shape.shape = shape_data
		collision_body.add_child(collision_shape)

func destroy_model_instance(instance_id: String) -> void:
	if instance_id not in model_instances:
		return
	
	var instance_data: Dictionary = model_instances[instance_id]
	var model_node: Node3D = instance_data.node
	
	# Remove from scene and free
	if model_node.get_parent():
		model_node.get_parent().remove_child(model_node)
	model_node.queue_free()
	
	# Remove from tracking
	model_instances.erase(instance_id)
	model_instance_destroyed.emit(instance_id)

func get_model_instance(instance_id: String) -> Node3D:
	if instance_id in model_instances:
		return model_instances[instance_id].node
	return null

func update_model_lod(instance_id: String, camera_position: Vector3) -> void:
	if instance_id not in model_instances:
		return
	
	var instance_data: Dictionary = model_instances[instance_id]
	var model_node: Node3D = instance_data.node
	var current_lod: LODLevel = instance_data.lod_level
	
	# Calculate distance to camera
	var distance: float = camera_position.distance_to(model_node.global_position)
	
	# Determine appropriate LOD level
	var new_lod: LODLevel = _calculate_lod_level(distance, model_node)
	
	if new_lod != current_lod:
		_apply_lod_level(model_node, new_lod)
		instance_data.lod_level = new_lod
		lod_changed.emit(instance_id, new_lod)

func _calculate_lod_level(distance: float, model_node: Node3D) -> LODLevel:
	# Calculate model size factor
	var model_size: float = _estimate_model_size(model_node)
	var size_adjusted_distance: float = distance / (model_size * lod_bias)
	
	# Determine LOD based on adjusted distance
	if size_adjusted_distance < 100.0:
		return LODLevel.HIGH_DETAIL
	elif size_adjusted_distance < 500.0:
		return LODLevel.MEDIUM_DETAIL
	elif size_adjusted_distance < 1500.0:
		return LODLevel.LOW_DETAIL
	else:
		return LODLevel.IMPOSTOR

func _apply_lod_level(model_node: Node3D, lod_level: LODLevel) -> void:
	# Godot handles LOD automatically, but we can adjust visibility
	match lod_level:
		LODLevel.IMPOSTOR:
			# Hide very detailed components for far distances
			_set_detail_visibility(model_node, false)
		_:
			# Show normal detail
			_set_detail_visibility(model_node, true)

func _set_detail_visibility(node: Node3D, visible: bool) -> void:
	# Hide/show detail components like antennas, small weapons, etc.
	for child in node.get_children():
		if child.name.contains("detail") or child.name.contains("antenna") or child.name.contains("small"):
			child.visible = visible
		
		if child is Node3D:
			_set_detail_visibility(child as Node3D, visible)

func _estimate_model_size(node: Node3D) -> float:
	var aabb: AABB = AABB()
	var found_mesh: bool = false
	
	# Calculate combined AABB for all meshes
	_calculate_node_aabb(node, aabb, found_mesh)
	
	if found_mesh:
		return aabb.size.length()
	
	return 10.0  # Default size

func _calculate_node_aabb(node: Node3D, aabb: AABB, found_mesh: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			var mesh_aabb: AABB = mesh_instance.get_aabb()
			if not found_mesh:
				aabb = mesh_aabb
				found_mesh = true
			else:
				aabb = aabb.merge(mesh_aabb)
	
	# Recursively process children
	for child in node.get_children():
		if child is Node3D:
			_calculate_node_aabb(child as Node3D, aabb, found_mesh)

func set_quality_level(quality: int) -> void:
	quality_level = clamp(quality, 0, 4)
	
	# Adjust LOD bias based on quality
	match quality_level:
		0:  # Very low
			lod_bias = 0.25
			max_draw_calls = 1000
			max_vertices_per_frame = 250000
		1:  # Low
			lod_bias = 0.5
			max_draw_calls = 1500
			max_vertices_per_frame = 350000
		2:  # Medium
			lod_bias = 1.0
			max_draw_calls = 2000
			max_vertices_per_frame = 500000
		3:  # High
			lod_bias = 1.5
			max_draw_calls = 2500
			max_vertices_per_frame = 750000
		4:  # Ultra
			lod_bias = 2.0
			max_draw_calls = 3000
			max_vertices_per_frame = 1000000
	
	# Update all existing instances
	for instance_id in model_instances:
		var instance_data: Dictionary = model_instances[instance_id]
		var model_node: Node3D = instance_data.node
		_update_node_lod_bias(model_node)
	
	print("WCSModelRenderer: Quality set to level %d (LOD bias: %.2f)" % [quality_level, lod_bias])

func _update_node_lod_bias(node: Node3D) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		mesh_instance.lod_bias = lod_bias
	
	for child in node.get_children():
		if child is Node3D:
			_update_node_lod_bias(child as Node3D)

func _setup_performance_monitoring() -> void:
	# Monitor performance every second
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_performance_stats)
	add_child(timer)

func _update_performance_stats() -> void:
	# Get rendering statistics from Godot
	var render_info: Dictionary = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TYPE_VISIBLE)
	
	current_draw_calls = render_info.get("draw_calls", 0)
	current_vertices = render_info.get("vertices", 0)
	
	performance_stats = {
		"draw_calls": current_draw_calls,
		"vertices": current_vertices,
		"model_instances": model_instances.size(),
		"cached_models": model_cache.size(),
		"quality_level": quality_level,
		"lod_bias": lod_bias
	}
	
	# Check performance thresholds
	if current_draw_calls > max_draw_calls:
		performance_warning.emit("draw_calls", current_draw_calls, max_draw_calls)
	
	if current_vertices > max_vertices_per_frame:
		performance_warning.emit("vertices", current_vertices, max_vertices_per_frame)

func get_performance_statistics() -> Dictionary:
	return performance_stats.duplicate()

func get_model_statistics() -> Dictionary:
	var instance_stats: Dictionary = {}
	var lod_distribution: Dictionary = {
		LODLevel.HIGH_DETAIL: 0,
		LODLevel.MEDIUM_DETAIL: 0,
		LODLevel.LOW_DETAIL: 0,
		LODLevel.IMPOSTOR: 0
	}
	
	for instance_id in model_instances:
		var instance_data: Dictionary = model_instances[instance_id]
		var model_data: WCSModelData = instance_data.model_data
		var lod_level: LODLevel = instance_data.lod_level
		
		# Count by model type
		var model_name: String = model_data.model_name
		instance_stats[model_name] = instance_stats.get(model_name, 0) + 1
		
		# Count by LOD level
		lod_distribution[lod_level] += 1
	
	return {
		"total_instances": model_instances.size(),
		"cached_models": model_cache.size(),
		"instance_by_model": instance_stats,
		"lod_distribution": lod_distribution,
		"performance": performance_stats
	}

func preload_ship_models(ship_classes: Array[String]) -> void:
	# Preload common ship models for smooth gameplay
	for ship_class in ship_classes:
		var model_path: String = "ships/%s/%s_model.tres" % [ship_class, ship_class]
		load_model_data(model_path)

func clear_model_cache() -> void:
	# Clear cached models to free memory
	model_cache.clear()
	print("WCSModelRenderer: Model cache cleared")

func clear_all_instances() -> void:
	# Destroy all active model instances
	var instance_ids: Array[String] = []
	for instance_id in model_instances:
		instance_ids.append(instance_id)
	
	for instance_id in instance_ids:
		destroy_model_instance(instance_id)

func create_ship_model_instance(ship_class: String, position: Vector3, 
								rotation: Vector3 = Vector3.ZERO, 
								scale: float = 1.0) -> String:
	var model_path: String = "ships/%s/%s_model.tres" % [ship_class, ship_class]
	var properties: Dictionary = {
		"scale": scale,
		"physics_enabled": true,
		"ship_class": ship_class
	}
	
	var instance_id: String = create_model_instance(model_path, properties)
	if not instance_id.is_empty():
		var model_node: Node3D = get_model_instance(instance_id)
		if model_node:
			model_node.global_position = position
			model_node.rotation_degrees = rotation
	
	return instance_id

func update_damage_visualization(instance_id: String, damage_level: float, 
								damage_locations: Array[Vector3] = []) -> void:
	if instance_id not in model_instances:
		return
	
	var instance_data: Dictionary = model_instances[instance_id]
	var model_node: Node3D = instance_data.node
	
	# Apply damage materials and effects
	_apply_damage_materials(model_node, damage_level)
	
	# Add damage effects at specific locations
	for damage_pos in damage_locations:
		_create_damage_effect(model_node, damage_pos, damage_level)

func _apply_damage_materials(model_node: Node3D, damage_level: float) -> void:
	# Apply damage visualization through material system
	if not material_system:
		return
	
	# TODO: Implement damage material switching
	# This would involve creating damaged material variants
	# and applying them based on damage level

func _create_damage_effect(model_node: Node3D, damage_position: Vector3, damage_level: float) -> void:
	# Create localized damage effects (sparks, smoke, etc.)
	# This would integrate with the effects system
	pass

func _exit_tree() -> void:
	clear_all_instances()