extends RefCounted

const WeaponExplosionResource = preload("res://scripts/resources/effects/weapon_expl_resource.gd")

func generate(resource: WeaponExplosionResource, output_dir: String) -> bool:
	var filename = resource.name
	if filename.is_empty():
		filename = "unknown_weapon_expl"
		
	var target_dir = output_dir.path_join("explosions")
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
		
	# Resolve LOD paths
	# Assuming sequences are already converted to .tres in the same directory
	# or handled by AssetPathResolver to be in assets/effects/explosions/
	# The base name is resource.name.
	# LODs are name, name_1, name_2, etc.
	
	resource.lod_paths.clear()
	
	# LOD 0
	# Frames are now in a subdirectory with the same name as the resource
	var base_lod_path = "res://assets/effects/explosions/" + resource.name.to_lower() + "/" + resource.name.to_lower() + ".tres"
	resource.lod_paths.append(base_lod_path)
	
	# LOD 1+
	for i in range(1, resource.lod_count):
		var lod_name = resource.name + "_" + str(i)
		# Assuming LODs are also sequences in their own subdirectories
		var lod_path = "res://assets/effects/explosions/" + lod_name.to_lower() + "/" + lod_name.to_lower() + ".tres"
		resource.lod_paths.append(lod_path)
		
	# 1. Save Resource (.tres)
	var tres_path = target_dir.path_join(filename + ".tres")
	var err = ResourceSaver.save(resource, tres_path)
	if err != OK:
		push_error("Failed to save weapon expl resource: " + tres_path)
		return false
		
	# 2. Generate Scene (.tscn)
	var res_path = tres_path
	var project_root = ProjectSettings.globalize_path("res://")
	if tres_path.begins_with(project_root):
		res_path = tres_path.replace(project_root, "res://")
	elif tres_path.find("/target/") != -1:
		var idx = tres_path.find("/target/")
		res_path = "res://" + tres_path.substr(idx + 8)
		
	var uid = _get_uid(tres_path)
	var uid_str = ""
	if not uid.is_empty():
		uid_str = ' uid="' + uid + '"'
		
	var tscn_content = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/entities/effects/weapon_explosion.gd" id="1_script"]
[ext_resource type="Resource"%s path="%s" id="2_resource"]

[node name="%s" type="Node3D"]
script = ExtResource("1_script")
resource = ExtResource("2_resource")
""" % [uid_str, res_path, filename]
		
	var tscn_path = target_dir.path_join(filename + ".tscn")
	var file = FileAccess.open(tscn_path, FileAccess.WRITE)
	if file:
		file.store_string(tscn_content)
		file.close()
	else:
		push_error("Failed to write TSCN: " + tscn_path)
		return false
		
	return true

func _get_uid(path: String) -> String:
	var uid = ResourceLoader.get_resource_uid(path)
	if uid != -1:
		return ResourceUID.id_to_text(uid)
	return ""
