# scripts/resources/object/model_metadata.gd
# Stores metadata extracted from original POF models, not covered by ShipData/WeaponData.
# Corresponds to parts of polymodel, bsp_info, model_subsystem structs.
extends Resource
class_name ModelMetadata

## --- Nested Classes for Point/Bank Definitions ---

# Generic point definition (used for thrusters, glow points)
# Corresponds roughly to glow_point struct
class PointDefinition extends Resource:
	@export var position: Vector3 = Vector3.ZERO # pnt
	@export var normal: Vector3 = Vector3.FORWARD # norm
	@export var radius: float = 0.0 # radius

# Weapon bank definition
# Corresponds to w_bank struct
class WeaponBank extends Resource:
	@export var points: Array[PointDefinition] = [] # Array of PointDefinition (pnt, norm, radius)

# Docking point definition
# Corresponds to dock_bay struct
class DockPoint extends Resource:
	@export var name: String = "" # name (from $name property)
	@export var type_flags: int = 0 # type_flags (DOCK_TYPE_*)
	@export var spline_paths: Array[NodePath] = [] # NodePaths to Path3D nodes (splines array maps to path indices)
	# points array holds the dock positions/normals (pnt[], norm[])
	# num_slots is implicitly points.size()
	@export var points: Array[PointDefinition] = [] # Usually 2 points (position/normal)

# Thruster bank definition
# Corresponds to thruster_bank struct
class ThrusterBank extends Resource:
	# Properties like $engine_subsystem are handled by linking via ShipData/SubsystemDefinition
	# @export var properties: Dictionary = {}
	# num_points is implicitly points.size()
	@export var points: Array[PointDefinition] = [] # Array of PointDefinition for thruster glows/particles

# Glow point bank definition
# Corresponds to glow_point_bank struct
class GlowPointBank extends Resource:
	@export var disp_time: int = 0 # disp_time
	@export var on_time: int = 0 # on_time
	@export var off_time: int = 0 # off_time
	@export var submodel_parent_path: NodePath = NodePath("") # Path to parent submodel Node3D (submodel_parent)
	@export var lod: int = 0 # LOD level this bank applies to (LOD)
	@export var type: int = 0 # Glow type (e.g., simple glow, beam) (type)
	@export var glow_texture_path: String = "" # Path to glow texture resource (glow_bitmap)
	@export var glow_nebula_texture_path: String = "" # Path to nebula glow texture resource (glow_neb_bitmap)
	# num_points is implicitly points.size()
	@export var points: Array[PointDefinition] = [] # Array of PointDefinition (points)

# AI/Scripting Path definition
# Corresponds to model_path struct
class ModelPath extends Resource:
	@export var name: String = "" # name
	@export var parent_name: String = "" # parent_name
	# parent_submodel index is resolved at load time if needed
	# nverts is implicitly path_node.curve.point_count
	# verts array (pos, radius, nturrets, turret_ids) is represented by the Path3D node and potentially metadata
	@export var path_node: NodePath = NodePath("") # NodePath to the Path3D node in the scene

# Cross-section definition
# Corresponds to cross_section struct
class CrossSection extends Resource:
	@export var z: float = 0.0 # z
	@export var radius: float = 0.0 # radius

# Insignia face definition (part of insignia struct)
class InsigniaFace extends Resource:
	# faces[face_idx][0..2]
	@export var vertex_indices: Array[int] = [] # Indices into the insignia's vertex array
	# u[face_idx][0..2], v[face_idx][0..2]
	@export var uvs: Array[Vector2] = [] # UV coordinates corresponding to vertex_indices

# Insignia definition
# Corresponds to insignia struct
class Insignia extends Resource:
	@export var detail_level: int = 0 # detail_level
	# num_faces is implicitly faces.size()
	# num_verts is implicitly vertices.size()
	@export var vertices: Array[Vector3] = [] # Local vertices for the insignia decal (vecs)
	@export var offset: Vector3 = Vector3.ZERO # Offset relative to the submodel it's attached to (offset)
	# norm array is calculated if needed, not stored directly
	@export var faces: Array[InsigniaFace] = [] # Array of InsigniaFace resources

# Viewpoint definition
# Corresponds to eye struct
class ViewPoint extends Resource:
	# parent index resolved at load time if needed
	@export var parent_submodel_path: NodePath = NodePath("") # Path to parent submodel Node3D (parent)
	@export var position: Vector3 = Vector3.ZERO # pnt
	@export var normal: Vector3 = Vector3.FORWARD # norm


## --- ModelMetadata Properties (Corresponds to polymodel struct) ---

# File Info
@export var pof_filename: String = "" # filename
@export var version: int = 0 # version

# Flags (PM_FLAG_*)
@export var flags: int = 0 # flags

# Detail Levels (References to other scene/model files)
# detail[] array holds indices, detail_depth[] is calculated at runtime if needed
# n_detail_levels is implicitly detail_level_paths.size()
@export var detail_level_paths: Array[String] = []

# Bounding Box (Might be redundant if using Godot's AABB, but useful for reference)
@export var mins: Vector3 = Vector3.ZERO # mins
@export var maxs: Vector3 = Vector3.ZERO # maxs
@export var radius: float = 0.0 # rad (Overall model radius)
@export var core_radius: float = 0.0 # core_radius
@export var autocenter: Vector3 = Vector3.ZERO # autocenter (If PM_FLAG_AUTOCEN is set)

# Points and Banks (Arrays of the nested classes defined above)
# n_guns is implicitly gun_banks.size()
@export var gun_banks: Array[WeaponBank] = [] # gun_banks
# n_missiles is implicitly missile_banks.size()
@export var missile_banks: Array[WeaponBank] = [] # missile_banks
# n_docks is implicitly docking_points.size()
@export var docking_points: Array[DockPoint] = [] # docking_bays
# n_thrusters is implicitly thruster_banks.size()
@export var thruster_banks: Array[ThrusterBank] = [] # thrusters
# n_glow_point_banks is implicitly glow_point_banks.size()
@export var glow_point_banks: Array[GlowPointBank] = [] # glow_point_banks

# Shield Mesh (Reference to the Mesh resource)
# shield_info struct (nverts, ntris, verts, tris) represented by the Mesh resource
@export var shield_mesh: Mesh = null
# shield_collision_tree_data might be needed for faster shield collision checks if Godot's collision isn't sufficient
# @export var shield_collision_tree_data: PackedByteArray = PackedByteArray() # shield_collision_tree, sldc_size

# Paths (Array of ModelPath resources)
# n_paths is implicitly paths.size()
@export var paths: Array[ModelPath] = [] # paths

# Viewpoints (Array of ViewPoint resources)
# n_view_positions is implicitly viewpoints.size()
@export var viewpoints: Array[ViewPoint] = [] # view_positions

# Cross Sections (Array of CrossSection resources)
# num_xc is implicitly cross_sections.size()
@export var cross_sections: Array[CrossSection] = [] # xc

# Insignias (Array of Insignia resources)
# num_ins is implicitly insignias.size()
@export var insignias: Array[Insignia] = [] # ins

# Note: Subsystem definitions (model_subsystem) are now part of ShipData.
# Note: Physics properties (mass, center_of_mass, moment_of_inertia) are part of ShipData or handled by RigidBody3D.
# Note: Texture references (texture_map) are handled by Materials in the Godot scene.
# Note: Debris objects (debris_objects, num_debris_objects) are handled in ShipData.
# Note: Lighting info (lights, num_lights) is handled by Godot's lighting system.
# Note: Octants (octants) are handled by Godot's spatial partitioning.
