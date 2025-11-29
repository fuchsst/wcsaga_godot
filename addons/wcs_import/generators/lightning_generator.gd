class_name LightningGenerator
extends RefCounted

## Generates Lightning Resources from parsed TBL data
## Handles saving resources to correct subfolders (bolts/storms).

const LightningResource = preload("res://scripts/resources/effects/lightning/lightning_resource.gd")

func generate(resource: LightningResource, output_dir: String) -> bool:
	var subfolder = "bolts"
	if resource.type == LightningResource.LightningType.STORM:
		subfolder = "storms"
		
	var target_dir = output_dir.path_join(subfolder)
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
		
	var filename = resource.name
	if filename.is_empty():
		filename = "unknown_lightning"
		
	# 1. Save Resource (.tres)
	var tres_path = target_dir.path_join(filename + ".tres")
	var err = ResourceSaver.save(resource, tres_path)
	if err != OK:
		push_error("Failed to save lightning resource: " + tres_path)
		return false
		
	# 2. Generate Scene (.tscn)
	# We manually construct the TSCN content to ensure correct references without loading
	
	# Calculate res:// path for the resource
	var res_path = tres_path
	var project_root = ProjectSettings.globalize_path("res://")
	if tres_path.begins_with(project_root):
		res_path = tres_path.replace(project_root, "res://")
	elif tres_path.find("/target/") != -1:
		var idx = tres_path.find("/target/")
		res_path = "res://" + tres_path.substr(idx + 8)
		
	# Get UID if possible (optional, but good for references)
	var uid_str = ""
	# We can't easily get the UID of the just-saved resource without re-scanning or reading the file
	# For simplicity, we'll omit UID for now or try to read it
	var uid = _get_uid(tres_path)
	if not uid.is_empty():
		uid_str = ' uid="uid://' + uid + '"'

	var tscn_content = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/entities/effects/lightning.gd" id="1_script"]
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
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		# Read first few lines to find uid
		for i in range(5):
			var line = file.get_line()
			var regex = RegEx.new()
			regex.compile('uid="uid://([^"]+)"')
			var result = regex.search(line)
			if result:
				return result.get_string(1)
	return ""
