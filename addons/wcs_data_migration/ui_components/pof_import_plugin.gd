@tool
extends EditorImportPlugin

## POF Model Import Plugin
## Implements DM-005 POF to Godot Mesh Conversion and DM-006 LOD and Material Processing

func _get_importer_name() -> String:
	return "wcs.pof_model"

func _get_visible_name() -> String:
	return "WCS POF Model"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["pof"])

func _get_save_extension() -> String:
	return "glb"

func _get_resource_type() -> String:
	return "PackedScene"

func _get_preset_count() -> int:
	return 3

func _get_preset_name(preset_index: int) -> String:
	match preset_index:
		0: return "Ship"
		1: return "Station"
		2: return "Debris"
		_: return "Unknown"

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	var base_options: Array[Dictionary] = [
		{
			"name": "import_scale",
			"default_value": 1.0,
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.01,100.0,0.01"
		},
		{
			"name": "generate_lods",
			"default_value": true,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Generate LOD variants for performance"
		},
		{
			"name": "generate_collision",
			"default_value": true,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Generate collision shapes"
		},
		{
			"name": "collision_type",
			"default_value": 1,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Convex Hull,Trimesh,Simplified"
		},
		{
			"name": "texture_directory",
			"default_value": "res://assets/textures/",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_DIR,
			"hint_string": "Directory containing textures"
		}
	]
	
	# Preset-specific options
	match preset_index:
		0: # Ship
			base_options.append({
				"name": "create_physics_body",
				"default_value": true,
				"type": TYPE_BOOL,
				"hint": PROPERTY_HINT_NONE,
				"hint_string": "Create RigidBody3D for ship physics"
			})
		1: # Station
			base_options.append({
				"name": "create_static_body",
				"default_value": true,
				"type": TYPE_BOOL,
				"hint": PROPERTY_HINT_NONE,
				"hint_string": "Create StaticBody3D for station"
			})
		2: # Debris
			base_options.append({
				"name": "create_debris_physics",
				"default_value": true,
				"type": TYPE_BOOL,
				"hint": PROPERTY_HINT_NONE,
				"hint_string": "Create physics for debris"
			})
	
	return base_options

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	if option_name == "collision_type":
		return options.get("generate_collision", false)
	return true

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> int:
	print("Importing POF model: %s" % source_file)
	
	# Get the Python converter directory
	var converter_dir: String = get_script().get_path().get_base_dir().path_join("..")
	var python_script: String = converter_dir.path_join("pof_parser/cli.py")
	var output_glb: String = save_path + ".glb"
	
	var args: PackedStringArray = PackedStringArray([
		python_script,
		"convert",
		source_file,
		"--output", output_glb,
		"--scale", str(options.get("import_scale", 1.0))
	])
	
	# Add texture directory if specified
	var texture_dir: String = options.get("texture_directory", "")
	if not texture_dir.is_empty():
		args.append_array(["--textures", texture_dir])
	
	# Add LOD generation if enabled
	if options.get("generate_lods", true):
		args.append("--generate-lods")
	
	# Add collision generation if enabled
	if options.get("generate_collision", true):
		args.append("--generate-collision")
		
		var collision_type: int = options.get("collision_type", 1)
		match collision_type:
			0: args.append_array(["--collision-type", "convex"])
			1: args.append_array(["--collision-type", "trimesh"])
			2: args.append_array(["--collision-type", "simplified"])
	
	# Execute Python POF converter
	var python_exe: String = _get_python_executable()
	var output: Array = []
	var result: int = OS.execute(python_exe, args, output, true)
	
	if result != 0:
		print_rich("[color=red]POF conversion failed: %s[/color]" % result)
		return FAILED
	
	# Check if GLB file was created
	if not FileAccess.file_exists(output_glb):
		print_rich("[color=red]GLB file not created: %s[/color]" % output_glb)
		return FAILED
	
	# Load the GLB and create a PackedScene
	var gltf_document: GLTFDocument = GLTFDocument.new()
	var gltf_state: GLTFState = GLTFState.new()
	
	var error: Error = gltf_document.append_from_file(output_glb, gltf_state)
	if error != OK:
		print_rich("[color=red]Failed to load GLB: %s[/color]" % error)
		return FAILED
	
	var scene: Node3D = gltf_document.generate_scene(gltf_state)
	if not scene:
		print_rich("[color=red]Failed to generate scene from GLB[/color]")
		return FAILED
	
	# Apply WCS-specific enhancements
	_apply_wcs_enhancements(scene, options)
	
	# Create PackedScene
	var packed_scene: PackedScene = PackedScene.new()
	packed_scene.pack(scene)
	
	# Save the scene
	var save_result: Error = ResourceSaver.save(packed_scene, "%s.%s" % [save_path, _get_save_extension()])
	
	if save_result == OK:
		print("POF model imported successfully: %s" % source_file)
		
		# Clean up temporary GLB file
		DirAccess.remove_absolute(output_glb)
		
		return OK
	else:
		print_rich("[color=red]Failed to save POF scene[/color]")
		return FAILED

func _apply_wcs_enhancements(scene: Node3D, options: Dictionary) -> void:
	## Apply WCS-specific enhancements to the imported scene
	
	# Set up metadata
	scene.set_meta("wcs_model_type", "pof")
	scene.set_meta("import_time", Time.get_unix_time_from_system())
	scene.set_meta("import_options", options)
	
	# Add WCS model metadata component if available
	var wcs_metadata_script: Script = load("res://addons/wcs_asset_core/structures/base_asset_data.gd")
	if wcs_metadata_script:
		var metadata_node: Node = Node.new()
		metadata_node.name = "WCSModelMetadata"
		metadata_node.set_script(wcs_metadata_script)
		scene.add_child(metadata_node)
	
	# Configure physics based on preset
	if options.get("create_physics_body", false):
		_add_physics_body(scene, "RigidBody3D")
	elif options.get("create_static_body", false):
		_add_physics_body(scene, "StaticBody3D")
	elif options.get("create_debris_physics", false):
		_add_physics_body(scene, "RigidBody3D")

func _add_physics_body(scene: Node3D, body_type: String) -> void:
	## Add physics body to the scene if collision shapes are present
	
	# Find mesh instances with collision shapes
	var mesh_instances: Array[MeshInstance3D] = []
	_find_mesh_instances(scene, mesh_instances)
	
	for mesh_instance in mesh_instances:
		var collision_shape: CollisionShape3D = mesh_instance.get_node_or_null("CollisionShape3D")
		if collision_shape:
			# Create physics body based on type string
			var physics_body: PhysicsBody3D
			if body_type == "RigidBody3D":
				physics_body = RigidBody3D.new()
			elif body_type == "StaticBody3D":
				physics_body = StaticBody3D.new()
			else:
				physics_body = RigidBody3D.new()  # Default fallback
			
			physics_body.name = mesh_instance.name + "_Physics"
			
			# Move collision shape to physics body
			mesh_instance.remove_child(collision_shape)
			physics_body.add_child(collision_shape)
			
			# Add physics body to scene
			scene.add_child(physics_body)

func _find_mesh_instances(node: Node, mesh_instances: Array[MeshInstance3D]) -> void:
	## Recursively find all MeshInstance3D nodes
	
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		_find_mesh_instances(child, mesh_instances)

func _get_python_executable() -> String:
	## Get the Python executable path for the conversion tools
	
	# Try to find Python executable
	var possible_paths: PackedStringArray = PackedStringArray([
		"/mnt/d/projects/wcsaga_godot_converter/target/venv/Scripts/python.exe",
		"/mnt/d/projects/wcsaga_godot_converter/target/venv/bin/python",
		"python",
		"python3"
	])
	
	for path in possible_paths:
		if FileAccess.file_exists(path) or _check_command_exists(path):
			return path
	
	# Fallback
	return "python"

func _check_command_exists(command: String) -> bool:
	## Check if a command exists in the system PATH
	var result: int = OS.execute("which", [command], [], true)
	return result == 0
