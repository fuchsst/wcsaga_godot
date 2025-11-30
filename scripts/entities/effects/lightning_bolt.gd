extends Node3D

class_name LightningBolt

# References
var mesh_instance: MeshInstance3D
var glow_mesh_instance: MeshInstance3D
var immediate_mesh: ImmediateMesh
var glow_immediate_mesh: ImmediateMesh

# Data
var start_pos: Vector3
var end_pos: Vector3
var resource: LightningResource
var lifetime: float = 0.0
var current_time: float = 0.0
var width: float = 1.0

# State
var is_active: bool = false
var segments: Array[Vector3] = []


func _ready():
	# Create MeshInstance for the main bolt
	mesh_instance = MeshInstance3D.new()
	immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)

	# Create MeshInstance for the glow
	glow_mesh_instance = MeshInstance3D.new()
	glow_immediate_mesh = ImmediateMesh.new()
	glow_mesh_instance.mesh = glow_immediate_mesh
	glow_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow_mesh_instance)


func setup(p_start: Vector3, p_end: Vector3, p_resource: LightningResource):
	start_pos = p_start
	end_pos = p_end
	resource = p_resource
	lifetime = resource.b_lifetime
	current_time = 0.0
	is_active = true

	# Calculate width based on distance and poly pct
	var dist = start_pos.distance_to(end_pos)
	width = dist * resource.b_poly_pct

	# Setup materials
	_setup_materials()

	# Initial generation
	_generate_segments()
	_update_mesh()


func _setup_materials():
	# Main texture
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true

	if resource.b_texture:
		# Load texture from expected path
		# Assuming textures are in the same folder or resolvable
		# For now, we might need to rely on the generator to pass the texture path or load it here
		# But LightningResource stores the string name.
		# We need a way to resolve "lightning" to "res://assets/effects/lightning/bolts/lightning.png"
		# For this implementation, we will assume standard path or use a placeholder if not found
		var tex_path = "res://assets/effects/lightning/bolts/" + resource.b_texture + ".png"
		if ResourceLoader.exists(tex_path):
			mat.albedo_texture = load(tex_path)

	mesh_instance.material_override = mat

	# Glow texture
	var glow_mat = StandardMaterial3D.new()
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ADD
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.vertex_color_use_as_albedo = true

	if resource.b_glow:
		var glow_path = "res://assets/effects/lightning/bolts/" + resource.b_glow + ".png"
		if ResourceLoader.exists(glow_path):
			glow_mat.albedo_texture = load(glow_path)

	glow_mesh_instance.material_override = glow_mat


func _process(delta):
	if not is_active:
		return

	current_time += delta
	if current_time >= lifetime:
		queue_free()
		return

	# Jitter
	# In FS2, they jitter every frame or so.
	# We can regenerate segments or just offset them.
	# Regenerating is expensive but accurate to the "midpoint displacement" style.
	# Let's try regenerating every frame for that chaotic look.
	_generate_segments()
	_update_mesh()

	# Fade out
	var alpha = 1.0 - (current_time / lifetime)
	var mat = mesh_instance.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color.a = alpha
	var glow_mat = glow_mesh_instance.material_override as StandardMaterial3D
	if glow_mat:
		glow_mat.albedo_color.a = alpha


func _generate_segments():
	segments.clear()
	segments.append(start_pos)
	segments.append(end_pos)

	# Recursive subdivision
	# We'll do a fixed number of iterations or based on distance
	var iterations = 4  # Adjust based on detail needed

	for i in range(iterations):
		var new_segments: Array[Vector3] = []
		for j in range(segments.size() - 1):
			var p1 = segments[j]
			var p2 = segments[j + 1]
			var mid = (p1 + p2) * 0.5

			# Displace
			var dist = p1.distance_to(p2)
			var displacement = dist * resource.b_scale * 0.5  # Scale factor

			# Random direction perpendicular to the segment would be ideal,
			# but random vector is easier and usually sufficient for lightning
			var offset = (
				Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
				* displacement
				* randf_range(0.0, 1.0)
			)  # b_rand influence?

			mid += offset

			new_segments.append(p1)
			new_segments.append(mid)

		new_segments.append(segments[segments.size() - 1])
		segments = new_segments


func _update_mesh():
	# Update Main Bolt
	immediate_mesh.clear_surfaces()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var camera = get_viewport().get_camera_3d()
	var cam_pos = camera.global_position if camera else Vector3.ZERO

	for i in range(segments.size()):
		var p = segments[i]
		var next_p = segments[i + 1] if i < segments.size() - 1 else p

		# Calculate ribbon width vector (billboarded)
		var dir = (next_p - p).normalized()
		if i == segments.size() - 1:
			dir = (p - segments[i - 1]).normalized()

		var to_cam = (cam_pos - p).normalized()
		var right = dir.cross(to_cam).normalized() * width * 0.5

		var uv_y = float(i) / float(segments.size() - 1)

		immediate_mesh.surface_set_uv(Vector2(0, uv_y))
		immediate_mesh.surface_add_vertex(p - right)

		immediate_mesh.surface_set_uv(Vector2(1, uv_y))
		immediate_mesh.surface_add_vertex(p + right)

	immediate_mesh.surface_end()

	# Update Glow (Wider)
	glow_immediate_mesh.clear_surfaces()
	glow_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var glow_width = width * resource.b_add  # b_add seems to be a multiplier or addition
	if glow_width <= width:
		glow_width = width * 2.0

	for i in range(segments.size()):
		var p = segments[i]
		var next_p = segments[i + 1] if i < segments.size() - 1 else p

		var dir = (next_p - p).normalized()
		if i == segments.size() - 1:
			dir = (p - segments[i - 1]).normalized()

		var to_cam = (cam_pos - p).normalized()
		var right = dir.cross(to_cam).normalized() * glow_width * 0.5

		var uv_y = float(i) / float(segments.size() - 1)

		glow_immediate_mesh.surface_set_uv(Vector2(0, uv_y))
		glow_immediate_mesh.surface_add_vertex(p - right)

		glow_immediate_mesh.surface_set_uv(Vector2(1, uv_y))
		glow_immediate_mesh.surface_add_vertex(p + right)

	glow_immediate_mesh.surface_end()
