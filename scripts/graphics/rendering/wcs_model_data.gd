class_name WCSModelData
extends BaseAssetData

## Model definition for WCS-Godot conversion containing converted GLB model data
## Works with EPIC-003 conversion tools to load converted POF→GLB models

@export var model_name: String
@export var ship_class: String
@export var model_type: String = "ship"
@export var glb_model_path: String

# LOD system
@export var lod_distances: Array[float] = [100.0, 500.0, 1500.0, 5000.0]
@export var lod_meshes: Array[Mesh] = []
@export var use_automatic_lod: bool = true

# Material assignments
@export var material_mappings: Dictionary = {}
@export var subsystem_materials: Dictionary = {}

# Physics and collision
@export var collision_shapes: Array[Shape3D] = []
@export var physics_enabled: bool = false
@export var collision_layers: int = 1
@export var collision_mask: int = 1

# Model metadata  
@export var model_scale: float = 1.0
@export var model_center_offset: Vector3 = Vector3.ZERO
@export var estimated_size: float = 10.0
@export var triangle_count: int = 0

# Subsystem data for damage visualization
@export var subsystem_locations: Dictionary = {}
@export var hardpoint_locations: Dictionary = {}
@export var engine_positions: Array[Vector3] = []

func _init() -> void:
	resource_name = "WCSModelData"

func is_valid() -> bool:
	var errors: Array[String] = get_validation_errors()
	return errors.is_empty()

func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	
	if model_name.is_empty():
		errors.append("Model name cannot be empty")
	
	if glb_model_path.is_empty():
		errors.append("GLB model path must be specified")
	
	if not FileAccess.file_exists(glb_model_path):
		errors.append("GLB model file not found: " + glb_model_path)
	
	if model_scale <= 0.0:
		errors.append("Model scale must be positive")
	
	if lod_distances.size() > 0:
		for i in range(1, lod_distances.size()):
			if lod_distances[i] <= lod_distances[i-1]:
				errors.append("LOD distances must be in ascending order")
	
	return errors

func get_lod_meshes() -> Array[Mesh]:
	if use_automatic_lod and lod_meshes.is_empty():
		# Generate automatic LOD meshes from main mesh
		return _generate_automatic_lod_meshes()
	
	return lod_meshes

func _generate_automatic_lod_meshes() -> Array[Mesh]:
	# Load the main GLB model and extract meshes for LOD generation
	var glb_scene: PackedScene = load(glb_model_path)
	if not glb_scene:
		return []
	
	var scene_instance: Node3D = glb_scene.instantiate()
	var meshes: Array[Mesh] = []
	
	# Find all meshes in the model
	_collect_meshes_recursive(scene_instance, meshes)
	
	scene_instance.queue_free()
	
	# TODO: Implement actual LOD mesh generation
	# For now, return the original meshes
	return meshes

func _collect_meshes_recursive(node: Node3D, meshes: Array[Mesh]) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			meshes.append(mesh_instance.mesh)
	
	for child in node.get_children():
		if child is Node3D:
			_collect_meshes_recursive(child as Node3D, meshes)

func get_material_mappings() -> Dictionary:
	return material_mappings

func get_collision_shapes() -> Array[Shape3D]:
	return collision_shapes

func get_subsystem_locations() -> Dictionary:
	return subsystem_locations

func get_hardpoint_locations() -> Dictionary:
	return hardpoint_locations

func get_engine_positions() -> Array[Vector3]:
	return engine_positions

func set_lod_distances(distances: Array[float]) -> void:
	lod_distances = distances.duplicate()

func add_material_mapping(mesh_name: String, material_path: String) -> void:
	material_mappings[mesh_name] = material_path

func add_collision_shape(shape: Shape3D) -> void:
	collision_shapes.append(shape)

func add_subsystem_location(subsystem_name: String, location: Vector3) -> void:
	subsystem_locations[subsystem_name] = location

func add_hardpoint_location(hardpoint_name: String, location: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	hardpoint_locations[hardpoint_name] = {
		"position": location,
		"rotation": rotation
	}

func add_engine_position(position: Vector3) -> void:
	engine_positions.append(position)

func get_model_bounds() -> AABB:
	# Load and calculate model bounds
	var glb_scene: PackedScene = load(glb_model_path)
	if not glb_scene:
		return AABB(Vector3.ZERO, Vector3.ONE * estimated_size)
	
	var scene_instance: Node3D = glb_scene.instantiate()
	var bounds: AABB = _calculate_model_bounds(scene_instance)
	scene_instance.queue_free()
	
	return bounds

func _calculate_model_bounds(node: Node3D) -> AABB:
	var combined_aabb: AABB = AABB()
	var found_mesh: bool = false
	
	_accumulate_bounds_recursive(node, combined_aabb, found_mesh)
	
	if not found_mesh:
		# Return default bounds if no meshes found
		combined_aabb = AABB(-Vector3.ONE * estimated_size * 0.5, Vector3.ONE * estimated_size)
	
	return combined_aabb

func _accumulate_bounds_recursive(node: Node3D, combined_aabb: AABB, found_mesh: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			var mesh_aabb: AABB = mesh_instance.get_aabb()
			mesh_aabb = node.transform * mesh_aabb
			
			if not found_mesh:
				combined_aabb = mesh_aabb
				found_mesh = true
			else:
				combined_aabb = combined_aabb.merge(mesh_aabb)
	
	for child in node.get_children():
		if child is Node3D:
			_accumulate_bounds_recursive(child as Node3D, combined_aabb, found_mesh)

func estimate_triangle_count() -> int:
	if triangle_count > 0:
		return triangle_count
	
	# Calculate triangle count from meshes
	var meshes: Array[Mesh] = get_lod_meshes()
	var total_triangles: int = 0
	
	for mesh in meshes:
		if mesh is ArrayMesh:
			var array_mesh: ArrayMesh = mesh as ArrayMesh
			for surface_idx in range(array_mesh.get_surface_count()):
				var arrays: Array = array_mesh.surface_get_arrays(surface_idx)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				total_triangles += indices.size() / 3
	
	triangle_count = total_triangles
	return triangle_count

func set_ship_class_data(ship_class_name: String):
	ship_class = ship_class_name
	model_name = ship_class_name + "_model"

func create_for_ship_class(ship_class_name: String, glb_path: String) -> WCSModelData:
	var model_data: WCSModelData = WCSModelData.new()
	model_data.ship_class = ship_class_name
	model_data.model_name = ship_class_name + "_model"
	model_data.glb_model_path = glb_path
	model_data.model_type = "ship"
	
	return model_data
