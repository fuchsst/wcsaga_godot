class_name HudSceneGenerator
extends RefCounted

const HudGaugeResource = preload("res://scripts/resources/ui/hud/hud_gauge_resource.gd")

func create_custom_gauges_scene(gauges: Array[HudGaugeResource], output_dir: String) -> void:
	_create_scene(gauges, output_dir.path_join("cockpits/custom_gauges.tscn"), "CustomGauges")

func create_main_gauges_scene(gauges: Array[HudGaugeResource], output_dir: String) -> void:
	_create_scene(gauges, output_dir.path_join("cockpits/main_gauges.tscn"), "MainGauges")

func create_gauges_scene(gauges: Array[HudGaugeResource], output_dir: String) -> void:
	_create_scene(gauges, output_dir.path_join("cockpits/gauges.tscn"), "Gauges")

func create_ship_scenes(ship_gauges: Dictionary, output_dir: String, is_main: bool) -> void:
	for ship_name in ship_gauges:
		var gauges = ship_gauges[ship_name]
		var safe_ship_name = ship_name.to_lower().replace(" ", "_").replace(".", "_")
		var subfolder = "main_gauges.tscn" if is_main else "gauges.tscn"
		var path = output_dir.path_join("cockpits/ship_gauges").path_join(safe_ship_name).path_join(subfolder)
		var root_name = "ShipMainGauges" if is_main else "ShipGauges"
		_create_scene(gauges, path, root_name)

func _create_scene(gauges: Array[HudGaugeResource], path: String, root_name: String) -> void:
	var root = Node2D.new()
	root.name = root_name
	
	# Map names to nodes for parenting
	var node_map = {}
	var nodes_to_add = []
	
	# First pass: Create all nodes
	for gauge in gauges:
		var node = Node2D.new()
		node.name = gauge.name if not gauge.name.is_empty() else "Gauge"
		node.position = Vector2(gauge.position)
		
		# Store metadata/properties if needed, or attach a script/resource
		# For now, we just create the hierarchy and position
		# We could attach the resource as metadata
		node.set_meta("gauge_resource", gauge)
		
		node_map[gauge.name] = node
		nodes_to_add.append({"node": node, "parent": gauge.parent})
		
		# Handle sub-gauges recursively (simplified for 1 level)
		for sub in gauge.sub_gauges:
			var sub_node = Node2D.new()
			sub_node.name = sub.name
			sub_node.position = Vector2(sub.position)
			sub_node.set_meta("gauge_resource", sub)
			node.add_child(sub_node)
			
	# Second pass: Build hierarchy
	for item in nodes_to_add:
		var node = item.node
		var parent_name = item.parent
		
		if not parent_name.is_empty() and node_map.has(parent_name):
			node_map[parent_name].add_child(node)
		else:
			root.add_child(node)
			
	# Set owner for all nodes to root (required for PackedScene)
	_set_owner_recursive(root, root)
	
	# Save scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root)
	if result == OK:
		var dir = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
			
		var err = ResourceSaver.save(packed_scene, path)
		if err == OK:
			print("Saved scene: " + path)
		else:
			print("Failed to save scene: " + path)
	else:
		print("Failed to pack scene: " + root_name)
		
	root.free()

func _set_owner_recursive(node: Node, root: Node) -> void:
	if node != root:
		node.owner = root
	for child in node.get_children():
		_set_owner_recursive(child, root)
