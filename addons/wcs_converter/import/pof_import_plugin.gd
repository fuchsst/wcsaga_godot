@tool
extends EditorImportPlugin

## POF Model Import Plugin
## Enables direct import of WCS .pof model files with real-time GLB conversion

const POFConverter = preload("res://addons/wcs_converter/conversion/pof_converter.gd")

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

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 0

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	match option_name:
		"texture_search_paths":
			return options.get("auto_find_textures", true)
		"collision_shape":
			return options.get("generate_collision", true)
		"lod_distance_1", "lod_distance_2", "lod_distance_3":
			return options.get("generate_lods", true)
		_:
			return true

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "auto_find_textures",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "texture_search_paths",
			"default_value": PackedStringArray(),
			"property_hint": PROPERTY_HINT_DIR,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "generate_collision", 
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "collision_shape",
			"default_value": 0,
			"property_hint": PROPERTY_HINT_ENUM,
			"hint_string": "Convex Hull,Trimesh,Simplified Hull",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "generate_lods",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "lod_distance_1",
			"default_value": 50.0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,1000.0,1.0",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "lod_distance_2",
			"default_value": 150.0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,1000.0,1.0",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "lod_distance_3",
			"default_value": 300.0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,1000.0,1.0",
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "optimize_meshes",
			"default_value": true,
			"property_hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		},
		{
			"name": "import_scale",
			"default_value": 1.0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.01,100.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT
		}
	]

func _get_preset_count() -> int:
	return 3

func _get_preset_name(preset_index: int) -> String:
	match preset_index:
		0:
			return "Default"
		1:
			return "High Quality (with LODs)"
		2:
			return "Performance Optimized"
		_:
			return "Unknown"

func _import(source_file: String, save_path: String, options: Dictionary,
			 platform_variants: Array[String], gen_files: Array[String]) -> Error:
	
	print("Importing POF model: ", source_file)
	
	# Initialize POF converter
	var converter: POFConverter = POFConverter.new()
	
	# Create progress dialog
	var progress_dialog: AcceptDialog = _create_progress_dialog()
	progress_dialog.popup_centered()
	
	# Convert POF to GLB
	var conversion_result: Dictionary = converter.convert_pof_to_glb(
		source_file,
		save_path + ".glb",
		options
	)
	
	progress_dialog.queue_free()
	
	if not conversion_result.get("success", false):
		push_error("Failed to convert POF model: " + conversion_result.get("error", "Unknown error"))
		return ERR_COMPILATION_FAILED
	
	# Load the generated GLB file
	var glb_path: String = save_path + ".glb"
	if not FileAccess.file_exists(glb_path):
		push_error("GLB file was not created: " + glb_path)
		return ERR_FILE_NOT_FOUND
	
	# Import GLB as PackedScene using Godot's built-in importer
	var scene: PackedScene = _load_glb_as_scene(glb_path)
	if scene == null:
		push_error("Failed to load GLB as scene")
		return ERR_COMPILATION_FAILED
	
	# Post-process the scene with WCS-specific enhancements
	var enhanced_scene: PackedScene = _enhance_wcs_scene(scene, conversion_result, options)
	
	# Save the final scene
	var save_result: Error = ResourceSaver.save(enhanced_scene, save_path + ".scn")
	if save_result != OK:
		push_error("Failed to save POF scene")
		return save_result
	
	# Generate .import file for the GLB
	_generate_glb_import_file(glb_path, options)
	
	# Add GLB to generated files list for cleanup
	gen_files.append(glb_path)
	
	print("POF model imported successfully: ", conversion_result.get("mesh_count", 0), " meshes, ", 
		  conversion_result.get("material_count", 0), " materials")
	
	return OK

func _create_progress_dialog() -> AcceptDialog:
	"""Create progress dialog for POF conversion"""
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Converting POF Model"
	dialog.set_flag(Window.FLAG_RESIZE_DISABLED, true)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label: Label = Label.new()
	label.text = "Converting WCS POF model to GLB format...\nParsing chunks and generating materials."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(350, 20)
	progress_bar.value = 50  # Indeterminate progress
	vbox.add_child(progress_bar)
	
	EditorInterface.get_base_control().add_child(dialog)
	return dialog

func _load_glb_as_scene(glb_path: String) -> PackedScene:
	"""Load GLB file as PackedScene using Godot's GLB importer"""
	
	# Use Godot's resource loader to import the GLB
	var scene: PackedScene = load(glb_path) as PackedScene
	if scene == null:
		push_warning("Direct GLB load failed, trying resource import...")
		
		# Try forcing reimport of GLB
		EditorInterface.get_resource_filesystem().update_file(glb_path)
		await EditorInterface.get_resource_filesystem().filesystem_changed
		
		scene = load(glb_path) as PackedScene
	
	return scene

func _enhance_wcs_scene(scene: PackedScene, conversion_result: Dictionary, options: Dictionary) -> PackedScene:
	"""Add WCS-specific enhancements to the imported scene"""
	
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		push_warning("Scene root is not a Node3D, skipping WCS enhancements")
		return scene
	
	# Add WCS metadata component
	var metadata_script: GDScript = preload("res://addons/wcs_converter/components/wcs_model_metadata.gd")
	var metadata: Node = metadata_script.new()
	metadata.name = "WCSModelMetadata"
	metadata.set("pof_file", conversion_result.get("source_file", ""))
	metadata.set("conversion_data", conversion_result)
	root.add_child(metadata)
	metadata.owner = root
	
	# Add collision shapes if requested
	if options.get("generate_collision", true):
		_add_collision_shapes(root, options)
	
	# Add LOD nodes if generated
	if options.get("generate_lods", true) and conversion_result.has("lod_meshes"):
		_add_lod_system(root, conversion_result.get("lod_meshes", []))
	
	# Create new PackedScene with enhancements
	var enhanced_scene: PackedScene = PackedScene.new()
	enhanced_scene.pack(root)
	
	root.queue_free()
	return enhanced_scene

func _add_collision_shapes(root: Node3D, options: Dictionary) -> void:
	"""Add collision shapes to mesh instances"""
	
	var collision_type: int = options.get("collision_shape", 0)
	var collision_name: String
	
	match collision_type:
		0: collision_name = "convex"
		1: collision_name = "trimesh"
		2: collision_name = "simplified"
		_: collision_name = "convex"
	
	_find_and_add_collision_recursive(root, collision_name)

func _find_and_add_collision_recursive(node: Node, collision_type: String) -> void:
	"""Recursively find MeshInstance3D nodes and add collision shapes"""
	
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			# Create StaticBody3D for collision
			var static_body: StaticBody3D = StaticBody3D.new()
			static_body.name = mesh_instance.name + "_Collision"
			
			# Create CollisionShape3D
			var collision_shape: CollisionShape3D = CollisionShape3D.new()
			collision_shape.name = "CollisionShape3D"
			
			# Generate appropriate collision shape
			match collision_type:
				"convex":
					collision_shape.shape = mesh_instance.mesh.create_convex_shape()
				"trimesh":
					collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()
				"simplified":
					collision_shape.shape = mesh_instance.mesh.create_convex_shape()
			
			static_body.add_child(collision_shape)
			collision_shape.owner = node.get_tree().current_scene
			
			mesh_instance.add_child(static_body)
			static_body.owner = node.get_tree().current_scene
	
	# Recurse through children
	for child in node.get_children():
		_find_and_add_collision_recursive(child, collision_type)

func _add_lod_system(root: Node3D, lod_meshes: Array) -> void:
	"""Add LOD (Level of Detail) system to the model"""
	
	# Find the main mesh instance
	var main_mesh: MeshInstance3D = _find_main_mesh_instance(root)
	if main_mesh == null:
		push_warning("No main mesh instance found for LOD system")
		return
	
	# Create LOD group
	var lod_group: Node3D = Node3D.new()
	lod_group.name = "LODGroup"
	
	# Move main mesh to LOD group
	main_mesh.get_parent().remove_child(main_mesh)
	lod_group.add_child(main_mesh)
	main_mesh.owner = root
	
	# Add LOD meshes
	for i in range(lod_meshes.size()):
		var lod_mesh_data: Dictionary = lod_meshes[i]
		# Implementation would create LOD mesh instances here
		# This is a simplified version
	
	root.add_child(lod_group)
	lod_group.owner = root

func _find_main_mesh_instance(node: Node) -> MeshInstance3D:
	"""Find the primary MeshInstance3D in the scene"""
	
	if node is MeshInstance3D:
		return node as MeshInstance3D
	
	for child in node.get_children():
		var result: MeshInstance3D = _find_main_mesh_instance(child)
		if result != null:
			return result
	
	return null

func _generate_glb_import_file(glb_path: String, options: Dictionary) -> void:
	"""Generate .import file for the GLB with optimized settings"""
	
	var import_path: String = glb_path + ".import"
	var import_content: String = """[remap]

importer="scene"
importer_version=1
type="PackedScene"
uid="uid://""" + _generate_uid() + """"
path="res://.godot/imported/""" + glb_path.get_file() + """-""" + _generate_uid() + """.scn"

[deps]

source_file="res://""" + glb_path.get_file() + """"
dest_files=["res://.godot/imported/""" + glb_path.get_file() + """-""" + _generate_uid() + """.scn"]

[params]

nodes/root_type="Node3D"
nodes/root_name="Model"
nodes/apply_root_scale=true
nodes/root_scale=""" + str(options.get("import_scale", 1.0)) + """
meshes/ensure_tangents=true
meshes/generate_lods=""" + str(options.get("generate_lods", true)) + """
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=true
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
import_script/path=""
_subresources={}
gltf/naming_version=0
gltf/embedded_image_handling=1
"""
	
	var file: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
	if file != null:
		file.store_string(import_content)
		file.close()

func _generate_uid() -> String:
	"""Generate a UID for resource files"""
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
	var uid: String = ""
	for i in range(8):
		uid += "%02x" % rng.randi_range(0, 255)
	
	return uid