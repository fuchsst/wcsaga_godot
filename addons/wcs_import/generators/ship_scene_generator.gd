class_name ShipSceneGenerator
extends RefCounted

const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")

func generate(res: Resource, output_dir: String, source_root: String) -> bool:
	print("Generating Scene for " + res.ship_class)
	
	# 1. Determine Output Path - must match ship_generator.gd logic
	var pof_file = res.model_file
	if pof_file.is_empty():
		push_warning("No model_file on resource for ship: " + res.ship_class)
		return false
		
	var path_info = WCSPathResolver.determine_output_path(pof_file)
	var category = path_info[0]
	var subcategory = path_info[1]
	
	# Use POF basename for folder name (matching ship_generator.gd)
	var pof_basename = pof_file.get_basename().to_lower()
	var folder_name = _extract_ship_name_from_pof(pof_basename)
	var ship_dir = output_dir.path_join(category).path_join(subcategory).path_join(folder_name)
	
	DirAccess.make_dir_recursive_absolute(ship_dir)
	
	# 2. Prepare Paths
	var base_scene_path = "res://scenes/entities/ship/ship_base.tscn"
	var resource_path = ship_dir.path_join(folder_name + ".tres")
	
	# Model path logic - the GLTF is in the same folder with its original basename
	var model_path = ship_dir.path_join(res.model_file)
	
	# If model specifically at resource path doesn't exist, try variants
	if not FileAccess.file_exists(model_path):
		var gltf_p = ship_dir.path_join(pof_basename + ".gltf")
		var glb_p = ship_dir.path_join(pof_basename + ".glb")
		if FileAccess.file_exists(gltf_p):
			model_path = gltf_p
		elif FileAccess.file_exists(glb_p):
			model_path = glb_p
		else:
			# If still not found, leave model_path pointing to expected location
			pass

	# 3. Generate Text Content
	var tscn_content = _generate_ship_scene_text(
		folder_name,
		res,
		base_scene_path,
		resource_path,
		model_path
	)
	
	# 4. Write Scene File
	var scene_path = ship_dir.path_join(folder_name + ".tscn")
	var file = FileAccess.open(scene_path, FileAccess.WRITE)
	if file:
		file.store_string(tscn_content)
		file.close()
		print("Saved Scene (Text): " + scene_path)
		return true
	else:
		print("Error writing scene file: " + scene_path)
		return false

func _generate_ship_scene_text(
	ship_name: String,
	stats: Resource,
	base_scene_path: String,
	resource_path: String,
	model_path: String
) -> String:
	var lines: Array[String] = []
	
	# External Resources Registry
	var ext_resources = [] # Array of {path, type, id}
	
	# Helper to find or add resource
	var get_ext_id = func(path, type):
		for res in ext_resources:
			if res.path == path:
				return res.id
		var new_id = "%d_%s" % [ext_resources.size() + 1, type.to_lower().substr(0, 3)]
		ext_resources.append({"path": path, "type": type, "id": new_id})
		return new_id

	# 1. Base Scene
	var base_id = get_ext_id.call(base_scene_path, "PackedScene")
	
	# 2. Stats Resource
	var res_stats_path = _to_res_path(resource_path)
	var stats_id = get_ext_id.call(res_stats_path, "Resource")
	
	# 3. Model
	var has_model = not model_path.is_empty() and FileAccess.file_exists(model_path)
	var model_id = ""
	if has_model:
		var res_model_path = _to_res_path(model_path)
		model_id = get_ext_id.call(res_model_path, "PackedScene")

	# Header
	# Approximate load steps. Godot is forgiving, but let's try to be close.
	# Ext resources count + 1 subresource + 1 (for main node?)
	var load_steps = ext_resources.size() + 2
	lines.append('[gd_scene load_steps=%d format=3]' % load_steps)
	lines.append("")
	
	# Write External Resources
	for r in ext_resources:
		lines.append('[ext_resource type="%s" path="%s" id="%s"]' % [r.type, r.path, r.id])
	lines.append("")
	
	# Sub Resource: Collision Shape
	# Approximation logic from previous generator
	var box_size = Vector3(10, 5, 15)
	if stats.ship_length_meters > 0:
		var length = stats.ship_length_meters
		var width = length * 0.5
		var height = length * 0.3
		box_size = Vector3(width, height, length)
		
	lines.append('[sub_resource type="BoxShape3D" id="BoxShape3D_gen"]')
	lines.append('size = Vector3(%.4f, %.4f, %.4f)' % [box_size.x, box_size.y, box_size.z])
	lines.append("")
	
	# Root Node
	lines.append('[node name="%s" instance=ExtResource("%s")]' % [ship_name, base_id])
	lines.append('stats = ExtResource("%s")' % stats_id)
	lines.append('ship_name = "%s"' % (stats.display_name if not stats.display_name.is_empty() else stats.ship_class))
	lines.append("")
	
	# CollisionShape3D override
	lines.append('[node name="CollisionShape3D" parent="." index="0"]')
	lines.append('shape = SubResource("BoxShape3D_gen")')
	lines.append("")
	
	# Model Container
	lines.append('[node name="ModelContainer" parent="." index="1"]')
	lines.append("")
	
	if has_model:
		lines.append('[node name="Model" parent="ModelContainer" index="0" instance=ExtResource("%s")]' % model_id)
		# Rotate -90 degrees on X-axis so ship faces forward (-Z) instead of up (+Y)
		lines.append('rotation_degrees = Vector3(-90, 0, 0)')
		lines.append("")
	
	# Generate derived nodes from ModelData
	if stats.model_data:
		_append_model_data_nodes(lines, stats.model_data)
		
	return "\n".join(lines)

func _append_model_data_nodes(lines: Array, data: Resource):
	# Hardpoints container exists in base scene at index ? 
	# Safest to reference parent="Hardpoints"
	# Guns
	if not data.guns.is_empty():
		lines.append('[node name="Guns" type="Node3D" parent="Hardpoints" index="0"]')
		lines.append("")
		for bank in data.guns:
			var bank_name = "Bank_" + _clean_name(bank.name)
			lines.append('[node name="%s" type="Node3D" parent="Hardpoints/Guns"]' % bank_name)
			lines.append("")
			for i in bank.points.size():
				var pt = bank.points[i]
				lines.append('[node name="Point_%d" type="Marker3D" parent="Hardpoints/Guns/%s"]' % [i, bank_name])
				lines.append('position = Vector3(%.4f, %.4f, %.4f)' % [pt.x, pt.y, pt.z])
				lines.append("")

	# Missiles
	if not data.missiles.is_empty():
		lines.append('[node name="Missiles" type="Node3D" parent="Hardpoints" index="1"]')
		lines.append("")
		for bank in data.missiles:
			var bank_name = "Bank_" + _clean_name(bank.name)
			lines.append('[node name="%s" type="Node3D" parent="Hardpoints/Missiles"]' % bank_name)
			lines.append("")
			for i in bank.points.size():
				var pt = bank.points[i]
				lines.append('[node name="Point_%d" type="Marker3D" parent="Hardpoints/Missiles/%s"]' % [i, bank_name])
				lines.append('position = Vector3(%.4f, %.4f, %.4f)' % [pt.x, pt.y, pt.z])
				lines.append("")

	# Turrets
	if not data.turrets.is_empty():
		lines.append('[node name="Turrets" type="Node3D" parent="Hardpoints" index="2"]')
		lines.append("")
		for turret in data.turrets:
			var t_name = _clean_name(turret.name)
			lines.append('[node name="%s" type="Node3D" parent="Hardpoints/Turrets"]' % t_name)
			# Do we have turret base position? Usually define fire points.
			lines.append("")
			for i in turret.fire_points.size():
				var pt = turret.fire_points[i]
				lines.append('[node name="FirePoint_%d" type="Marker3D" parent="Hardpoints/Turrets/%s"]' % [i, t_name])
				lines.append('position = Vector3(%.4f, %.4f, %.4f)' % [pt.x, pt.y, pt.z])
				lines.append("")

	# Eyes
	if not data.eyes.is_empty():
		lines.append('[node name="Eyes" type="Node3D" parent="Hardpoints" index="3"]')
		lines.append("")
		for i in data.eyes.size():
			var eye = data.eyes[i]
			lines.append('[node name="Eye_%d" type="Marker3D" parent="Hardpoints/Eyes"]' % i)
			lines.append('position = Vector3(%.4f, %.4f, %.4f)' % [eye.position.x, eye.position.y, eye.position.z])
			# Rotation from normal could be complex in text, skipping for now or assume forward
			lines.append("")

	# Visuals (New node not in base, so we add it to root)
	# parent="."
	if not data.thrusters.is_empty():
		lines.append('[node name="Visuals" type="Node3D" parent="."]')
		lines.append("")
		lines.append('[node name="Thrusters" type="Node3D" parent="Visuals"]')
		lines.append("")
		for i in data.thrusters.size():
			var t = data.thrusters[i]
			lines.append('[node name="Thruster_%d" type="Marker3D" parent="Visuals/Thrusters"]' % i)
			lines.append('position = Vector3(%.4f, %.4f, %.4f)' % [t.position.x, t.position.y, t.position.z])
			lines.append("")

func _to_res_path(abs_path: String) -> String:
	var project_root = ProjectSettings.globalize_path("res://")
	if abs_path.begins_with(project_root):
		return abs_path.replace(project_root, "res://")
	var idx = abs_path.find("/target/")
	if idx != -1:
		return "res://" + abs_path.substr(idx + 8)
	return abs_path

func _normalize_filename(name: String) -> String:
	var n = name.to_lower()
	n = n.replace(" ", "_")
	n = n.replace("-", "_")
	n = n.replace("#", "_")
	return n


func _extract_ship_name_from_pof(pof_basename: String) -> String:
	# Strip common prefixes like "tcf_", "tcb_", "tcs_", "kif_", "kib_", "kim_", etc.
	# E.g., "tcf_hellcat_v" -> "hellcat_v", "kif_dralthi_mk_iv" -> "dralthi_mk_iv"
	var prefixes = ["tcf_", "tcb_", "tcs_", "kif_", "kib_", "kic_", "kis_", "kim_", "kb_", "tcc_"]
	var name = pof_basename
	for prefix in prefixes:
		if name.begins_with(prefix):
			name = name.substr(prefix.length())
			break
	return name

func _clean_name(name: String) -> String:
	return name.replace(" ", "_").replace("-", "_").replace(".", "")
