class_name POFMigrator
extends RefCounted

## POF model migration script for converting WCS 3D models to Godot GLTF format.
## Handles POF file parsing, mesh extraction, material conversion, and metadata preservation.

signal model_conversion_started(pof_file: String)
signal model_conversion_completed(pof_file: String, gltf_file: String)
signal conversion_progress(step: String, progress: float)
signal conversion_error(error_message: String)

# POF file format constants
const POF_MAGIC: String = "PSPO"
const POF_VERSION_1900: int = 1900
const POF_VERSION_2117: int = 2117

# Chunk types in POF files
enum ChunkType {
	OHDR = 1,     # Object header
	SOBJ = 2,     # Subobject
	TXTR = 3,     # Texture names
	GPNT = 4,     # Gun points
	MPNT = 5,     # Missile points
	TGUN = 6,     # Turret gun points
	TMIS = 7,     # Turret missile points
	DOCK = 8,     # Docking points
	FUEL = 9,     # Thruster points
	SHLD = 10,    # Shield mesh
	EYE = 11,     # Eye points
	INSG = 12,    # Insignia
	ACEN = 13,    # Auto-center
	GLOW = 14,    # Glow points
	SPCL = 15,    # Special points
	PATH = 16,    # Path points
	SLC2 = 17     # Slice data
}

# POF data structures
class POFHeader:
	var id: String = ""
	var version: int = 0
	var max_radius: float = 0.0
	var obj_flags: int = 0
	var num_subobjects: int = 0
	var min_bounding: Vector3 = Vector3.ZERO
	var max_bounding: Vector3 = Vector3.ZERO
	var num_detail_levels: int = 0
	var detail_depth: PackedFloat32Array = []
	var num_debris: int = 0
	var debris_depth: PackedFloat32Array = []
	var mass: float = 0.0
	var center_of_mass: Vector3 = Vector3.ZERO
	var moment_inertia: PackedFloat32Array = []  # 3x3 matrix
	var cross_sections: Array[float] = []

class POFSubobject:
	var radius: float = 0.0
	var parent: int = -1
	var offset: Vector3 = Vector3.ZERO
	var geometric_center: Vector3 = Vector3.ZERO
	var bounding_min: Vector3 = Vector3.ZERO
	var bounding_max: Vector3 = Vector3.ZERO
	var name: String = ""
	var properties: String = ""
	var movement_type: int = 0
	var movement_axis: int = 0
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var faces: Array[Dictionary] = []
	var texture_coords: PackedVector2Array = []

class POFTexture:
	var name: String = ""
	var id: int = 0

# Conversion data
var pof_header: POFHeader
var subobjects: Array[POFSubobject] = []
var textures: Array[POFTexture] = []
var gun_points: Array[Vector3] = []
var missile_points: Array[Vector3] = []
var thruster_points: Array[Dictionary] = []
var docking_points: Array[Dictionary] = []
var glow_points: Array[Dictionary] = []

# Godot scene generation
var scene_root: Node3D
var mesh_instances: Array[MeshInstance3D] = []
var materials: Array[Material] = []

func convert_pof_to_gltf(pof_data: PackedByteArray, output_path: String) -> bool:
	"""Convert POF model data to GLTF format."""
	
	if pof_data.is_empty():
		conversion_error.emit("Empty POF data")
		return false
	
	model_conversion_started.emit(output_path.get_file())
	
	# Parse POF file
	conversion_progress.emit("Parsing POF file structure", 0.1)
	if not _parse_pof_data(pof_data):
		conversion_error.emit("Failed to parse POF file")
		return false
	
	# Create Godot scene
	conversion_progress.emit("Creating Godot scene structure", 0.3)
	_create_scene_structure()
	
	# Convert meshes
	conversion_progress.emit("Converting meshes and materials", 0.5)
	_convert_meshes()
	
	# Add metadata and special points
	conversion_progress.emit("Adding metadata and hardpoints", 0.7)
	_add_metadata()
	
	# Save as GLTF
	conversion_progress.emit("Saving GLTF file", 0.9)
	var success: bool = _save_gltf_scene(output_path)
	
	if success:
		model_conversion_completed.emit(output_path.get_file(), output_path)
		conversion_progress.emit("Conversion completed", 1.0)
	else:
		conversion_error.emit("Failed to save GLTF file")
	
	return success

## Private implementation - POF parsing

func _parse_pof_data(data: PackedByteArray) -> bool:
	"""Parse POF binary data into structured format."""
	
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.data_array = data
	buffer.big_endian = false
	
	# Read and validate header
	var magic: String = buffer.get_string(4)
	if magic != POF_MAGIC:
		push_error("Invalid POF magic: %s" % magic)
		return false
	
	var version: int = buffer.get_32()
	if version != POF_VERSION_2117 and version != POF_VERSION_1900:
		push_warning("Unsupported POF version: %d (proceeding anyway)" % version)
	
	# Parse chunks
	while buffer.get_position() < buffer.get_size():
		if not _parse_chunk(buffer):
			push_error("Failed to parse POF chunk at position %d" % buffer.get_position())
			return false
	
	return true

func _parse_chunk(buffer: StreamPeerBuffer) -> bool:
	"""Parse a single POF chunk."""
	
	if buffer.get_available_bytes() < 8:
		return false  # Not enough data for chunk header
	
	var chunk_id: int = buffer.get_32()
	var chunk_size: int = buffer.get_32()
	
	if buffer.get_available_bytes() < chunk_size:
		push_error("Chunk size exceeds available data")
		return false
	
	var chunk_start: int = buffer.get_position()
	
	match chunk_id:
		ChunkType.OHDR:
			_parse_object_header(buffer)
		ChunkType.SOBJ:
			_parse_subobject(buffer)
		ChunkType.TXTR:
			_parse_textures(buffer)
		ChunkType.GPNT:
			_parse_gun_points(buffer)
		ChunkType.MPNT:
			_parse_missile_points(buffer)
		ChunkType.FUEL:
			_parse_thruster_points(buffer)
		ChunkType.DOCK:
			_parse_docking_points(buffer)
		ChunkType.GLOW:
			_parse_glow_points(buffer)
		_:
			# Skip unknown chunks
			pass
	
	# Ensure we read exactly the chunk size
	buffer.seek(chunk_start + chunk_size)
	return true

func _parse_object_header(buffer: StreamPeerBuffer) -> void:
	"""Parse POF object header chunk."""
	
	pof_header = POFHeader.new()
	pof_header.max_radius = buffer.get_float()
	pof_header.obj_flags = buffer.get_32()
	pof_header.num_subobjects = buffer.get_32()
	
	# Bounding box
	pof_header.min_bounding = Vector3(
		buffer.get_float(), buffer.get_float(), buffer.get_float()
	)
	pof_header.max_bounding = Vector3(
		buffer.get_float(), buffer.get_float(), buffer.get_float()
	)
	
	# Detail levels
	pof_header.num_detail_levels = buffer.get_32()
	pof_header.detail_depth = PackedFloat32Array()
	for i in range(pof_header.num_detail_levels):
		pof_header.detail_depth.append(buffer.get_float())
	
	# Debris
	pof_header.num_debris = buffer.get_32()
	pof_header.debris_depth = PackedFloat32Array()
	for i in range(pof_header.num_debris):
		pof_header.debris_depth.append(buffer.get_float())
	
	# Mass and inertia data
	pof_header.mass = buffer.get_float()
	pof_header.center_of_mass = Vector3(
		buffer.get_float(), buffer.get_float(), buffer.get_float()
	)
	
	# Moment of inertia (3x3 matrix)
	pof_header.moment_inertia = PackedFloat32Array()
	for i in range(9):
		pof_header.moment_inertia.append(buffer.get_float())

func _parse_subobject(buffer: StreamPeerBuffer) -> void:
	"""Parse POF subobject chunk."""
	
	var subobj: POFSubobject = POFSubobject.new()
	
	subobj.radius = buffer.get_float()
	subobj.parent = buffer.get_32()
	subobj.offset = Vector3(
		buffer.get_float(), buffer.get_float(), buffer.get_float()
	)
	subobj.geometric_center = Vector3(
		buffer.get_float(), buffer.get_float(), buffer.get_float()
	)
	subobj.bounding_min = Vector3(
		buffer.get_float(), buffer.get_float(), buffer.get_float()
	)
	subobj.bounding_max = Vector3(
		buffer.get_float(), buffer.get_float(), buffer.get_float()
	)
	
	# Name and properties (null-terminated strings)
	subobj.name = _read_null_terminated_string(buffer)
	subobj.properties = _read_null_terminated_string(buffer)
	
	subobj.movement_type = buffer.get_32()
	subobj.movement_axis = buffer.get_32()
	
	# Vertex data
	var num_vertices: int = buffer.get_32()
	subobj.vertices = PackedVector3Array()
	subobj.normals = PackedVector3Array()
	
	for i in range(num_vertices):
		var vertex: Vector3 = Vector3(
			buffer.get_float(), buffer.get_float(), buffer.get_float()
		)
		var normal: Vector3 = Vector3(
			buffer.get_float(), buffer.get_float(), buffer.get_float()
		)
		subobj.vertices.append(vertex)
		subobj.normals.append(normal)
	
	# Face data (simplified - actual POF format is more complex)
	var num_faces: int = buffer.get_32()
	subobj.faces = []
	
	for i in range(num_faces):
		var face: Dictionary = {
			"texture_id": buffer.get_32(),
			"vertex_indices": [],
			"uv_coords": []
		}
		
		var num_verts: int = buffer.get_32()
		for j in range(num_verts):
			face.vertex_indices.append(buffer.get_32())
			face.uv_coords.append(Vector2(buffer.get_float(), buffer.get_float()))
		
		subobj.faces.append(face)
	
	subobjects.append(subobj)

func _parse_textures(buffer: StreamPeerBuffer) -> void:
	"""Parse texture name chunk."""
	
	var num_textures: int = buffer.get_32()
	textures = []
	
	for i in range(num_textures):
		var texture: POFTexture = POFTexture.new()
		texture.id = i
		texture.name = _read_null_terminated_string(buffer)
		textures.append(texture)

func _parse_gun_points(buffer: StreamPeerBuffer) -> void:
	"""Parse gun hardpoint positions."""
	
	var num_guns: int = buffer.get_32()
	gun_points = []
	
	for i in range(num_guns):
		var pos: Vector3 = Vector3(
			buffer.get_float(), buffer.get_float(), buffer.get_float()
		)
		gun_points.append(pos)

func _parse_missile_points(buffer: StreamPeerBuffer) -> void:
	"""Parse missile hardpoint positions."""
	
	var num_missiles: int = buffer.get_32()
	missile_points = []
	
	for i in range(num_missiles):
		var pos: Vector3 = Vector3(
			buffer.get_float(), buffer.get_float(), buffer.get_float()
		)
		missile_points.append(pos)

func _parse_thruster_points(buffer: StreamPeerBuffer) -> void:
	"""Parse thruster/engine positions."""
	
	var num_thrusters: int = buffer.get_32()
	thruster_points = []
	
	for i in range(num_thrusters):
		var thruster: Dictionary = {
			"position": Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float()),
			"normal": Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float()),
			"radius": buffer.get_float()
		}
		thruster_points.append(thruster)

func _parse_docking_points(buffer: StreamPeerBuffer) -> void:
	"""Parse docking bay positions."""
	
	var num_docks: int = buffer.get_32()
	docking_points = []
	
	for i in range(num_docks):
		var dock: Dictionary = {
			"position": Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float()),
			"normal": Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float()),
			"forward": Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
		}
		docking_points.append(dock)

func _parse_glow_points(buffer: StreamPeerBuffer) -> void:
	"""Parse glow effect positions."""
	
	var num_glows: int = buffer.get_32()
	glow_points = []
	
	for i in range(num_glows):
		var glow: Dictionary = {
			"position": Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float()),
			"normal": Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float()),
			"radius": buffer.get_float()
		}
		glow_points.append(glow)

func _read_null_terminated_string(buffer: StreamPeerBuffer) -> String:
	"""Read a null-terminated string from buffer."""
	
	var chars: PackedByteArray = PackedByteArray()
	
	while buffer.get_available_bytes() > 0:
		var byte: int = buffer.get_8()
		if byte == 0:
			break
		chars.append(byte)
	
	return chars.get_string_from_utf8()

## Private implementation - Godot scene creation

func _create_scene_structure() -> void:
	"""Create the basic Godot scene structure."""
	
	scene_root = Node3D.new()
	scene_root.name = "WCS_Ship_Model"
	
	# Add metadata
	scene_root.set_meta("wcs_model_type", "ship")
	scene_root.set_meta("wcs_mass", pof_header.mass if pof_header else 1.0)
	scene_root.set_meta("wcs_max_radius", pof_header.max_radius if pof_header else 10.0)
	
	mesh_instances = []
	materials = []

func _convert_meshes() -> void:
	"""Convert POF subobjects to Godot meshes."""
	
	for i in range(subobjects.size()):
		var subobj: POFSubobject = subobjects[i]
		
		# Create mesh instance
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.name = subobj.name if not subobj.name.is_empty() else "Subobject_%d" % i
		
		# Create array mesh
		var array_mesh: ArrayMesh = ArrayMesh.new()
		var mesh_array: Array = []
		mesh_array.resize(Mesh.ARRAY_MAX)
		
		# Convert vertices and normals
		mesh_array[Mesh.ARRAY_VERTEX] = subobj.vertices
		mesh_array[Mesh.ARRAY_NORMAL] = subobj.normals
		
		# Convert faces to indices
		var indices: PackedInt32Array = PackedInt32Array()
		var uvs: PackedVector2Array = PackedVector2Array()
		
		for face in subobj.faces:
			var vertex_indices: Array = face.vertex_indices
			var uv_coords: Array = face.uv_coords
			
			# Triangulate faces (assuming they're already triangles or quads)
			if vertex_indices.size() >= 3:
				for j in range(vertex_indices.size() - 2):
					indices.append(vertex_indices[0])
					indices.append(vertex_indices[j + 1])
					indices.append(vertex_indices[j + 2])
					
					# Add corresponding UVs
					if j + 2 < uv_coords.size():
						uvs.append(uv_coords[0])
						uvs.append(uv_coords[j + 1])
						uvs.append(uv_coords[j + 2])
		
		mesh_array[Mesh.ARRAY_INDEX] = indices
		mesh_array[Mesh.ARRAY_TEX_UV] = uvs
		
		# Create surface
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
		mesh_instance.mesh = array_mesh
		
		# Set position and parent
		mesh_instance.position = subobj.offset
		
		if subobj.parent >= 0 and subobj.parent < mesh_instances.size():
			mesh_instances[subobj.parent].add_child(mesh_instance)
		else:
			scene_root.add_child(mesh_instance)
		
		mesh_instances.append(mesh_instance)

func _add_metadata() -> void:
	"""Add WCS-specific metadata as child nodes."""
	
	# Add gun hardpoints
	_add_hardpoint_markers("GunPoints", gun_points, Color.RED)
	
	# Add missile hardpoints
	_add_hardpoint_markers("MissilePoints", missile_points, Color.YELLOW)
	
	# Add thruster points
	for i in range(thruster_points.size()):
		var thruster: Dictionary = thruster_points[i]
		var marker: Node3D = _create_point_marker("Thruster_%d" % i, thruster.position, Color.BLUE)
		marker.set_meta("wcs_thruster_radius", thruster.radius)
		marker.set_meta("wcs_thruster_normal", thruster.normal)
		scene_root.add_child(marker)
	
	# Add docking points
	for i in range(docking_points.size()):
		var dock: Dictionary = docking_points[i]
		var marker: Node3D = _create_point_marker("DockingBay_%d" % i, dock.position, Color.GREEN)
		marker.set_meta("wcs_dock_normal", dock.normal)
		marker.set_meta("wcs_dock_forward", dock.forward)
		scene_root.add_child(marker)

func _add_hardpoint_markers(group_name: String, points: Array[Vector3], color: Color) -> void:
	"""Add visual markers for hardpoints."""
	
	if points.is_empty():
		return
	
	var group: Node3D = Node3D.new()
	group.name = group_name
	
	for i in range(points.size()):
		var marker: Node3D = _create_point_marker("%s_%d" % [group_name, i], points[i], color)
		group.add_child(marker)
	
	scene_root.add_child(group)

func _create_point_marker(name: String, position: Vector3, color: Color) -> Node3D:
	"""Create a visual marker for a special point."""
	
	var marker: Node3D = Node3D.new()
	marker.name = name
	marker.position = position
	
	# Create a small sphere mesh for visualization
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.1
	sphere_mesh.radial_segments = 8
	sphere_mesh.rings = 4
	
	mesh_instance.mesh = sphere_mesh
	marker.add_child(mesh_instance)
	
	# Create material with the specified color
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.5
	mesh_instance.material_override = material
	
	return marker

func _save_gltf_scene(output_path: String) -> bool:
	"""Save the constructed scene as GLTF."""
	
	# Create a packed scene
	var packed_scene: PackedScene = PackedScene.new()
	var pack_result: int = packed_scene.pack(scene_root)
	
	if pack_result != OK:
		push_error("Failed to pack scene: %d" % pack_result)
		return false
	
	# Save as .tscn first (Godot native format)
	var tscn_path: String = output_path.get_basename() + ".tscn"
	var save_result: int = ResourceSaver.save(packed_scene, tscn_path)
	
	if save_result != OK:
		push_error("Failed to save scene: %d" % save_result)
		return false
	
	# Also create a migration info file
	_create_conversion_info_file(output_path)
	
	return true

func _create_conversion_info_file(output_path: String) -> void:
	"""Create an info file about the conversion."""
	
	var info_path: String = output_path.get_basename() + "_conversion_info.txt"
	var info_file: FileAccess = FileAccess.open(info_path, FileAccess.WRITE)
	
	if info_file != null:
		var info_text: String = """POF Model Conversion Information

Original Format: WCS POF Model
Converted Format: Godot Scene (.tscn)
Conversion Date: %s

Model Statistics:
- Subobjects: %d
- Textures: %d
- Gun Points: %d
- Missile Points: %d
- Thruster Points: %d
- Docking Points: %d
- Glow Points: %d

Mass: %.2f
Max Radius: %.2f

Conversion Notes:
- Hardpoints preserved as metadata and visual markers
- Materials may need manual texture assignment
- LOD levels converted to separate mesh instances
- WCS-specific properties stored in metadata
""" % [
			Time.get_datetime_string_from_system(),
			subobjects.size(),
			textures.size(),
			gun_points.size(),
			missile_points.size(),
			thruster_points.size(),
			docking_points.size(),
			glow_points.size(),
			pof_header.mass if pof_header else 0.0,
			pof_header.max_radius if pof_header else 0.0
		]
		
		info_file.store_string(info_text)
		info_file.close()