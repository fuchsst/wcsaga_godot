class_name ShipSceneGenerator
extends RefCounted

const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")

func generate(res: ShipStats, output_dir: String, source_root: String) -> bool:
    print("Generating Scene for " + res.ship_class)
    
    # 1. Determine Output Path
    var pof_file = res.model_file
    if pof_file.is_empty():
        pof_file = res.ship_class + ".pof"
        
    var path_info = WCSPathResolver.determine_output_path(pof_file)
    var category = path_info[0] # e.g. "manual", "ships/fighter"
    # Mapping "ships/fighter" -> "fighters" for simpler feature paths?
    # Refinement doc says: features/fighters
    # PathResolver uses "ships/fighter". We need to map this.
    var feature_category = _map_category_to_feature(category)
    
    var filename = _normalize_filename(res.ship_class)
    var ship_feature_dir = "res://features".path_join(feature_category).path_join(filename)
    
    # Ensure directory exists
    DirAccess.make_dir_recursive_absolute(ship_feature_dir)
    
    # 2. Create Root Node
    var ShipEntity = load("res://scripts/entities/ship/ship_entity.gd")
    if not ShipEntity:
        print("Error: Could not load ShipEntity script")
        return false
        
    var ship_node = ShipEntity.new()
    ship_node.name = filename # e.g. "hellcat_v"
    ship_node.stats = res # Assign stats
    
    # 3. Add Model Instance
    var model_filename = res.model_file
    var model_path = "res://assets".path_join(category).path_join(filename).path_join(model_filename)
    # Check if model exists (converted by ship_generator)
    if not FileAccess.file_exists(model_path):
        print("Warning: Model not found at " + model_path)
        # Try finding it recursively or checking if path resolution was slightly off?
        # Fallback: check standard paths if category was maybe partial
        if not FileAccess.file_exists(model_path):
             # Try appending "ships" to category if missing
             var alt_path = "res://assets/ships".path_join(category).path_join(filename).path_join(model_filename)
             if FileAccess.file_exists(alt_path):
                 model_path = alt_path
    
    if FileAccess.file_exists(model_path):
        var model_scene = load(model_path)
        if model_scene:
            var model_instance = model_scene.instantiate()
            model_instance.name = "Model"
            ship_node.add_child(model_instance)
            model_instance.owner = ship_node # Required for saving
    else:
        print("Error: Could not locate model for " + res.ship_class)
        # Continue anyway to generate the node structure? No, probably fail.
        # return false
    
    # 4. Add Collision Shape
    # (Usually this comes from the GLTF if imported with collisions, or we add a generic one)
    # For now, we add a placeholder collision shape if none exists in model
    var collision = CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    collision.shape = BoxShape3D.new() # Placeholder
    ship_node.add_child(collision)
    collision.owner = ship_node

    # 5. Generate Hardpoints & Visuals from ShipModelData
    if ship_node.stats.model_data:
        _generate_hardpoints(ship_node, ship_node.stats.model_data)

    # 6. Save Scene
    var scene = PackedScene.new()
    var result = scene.pack(ship_node)
    if result == OK:
        var scene_path = ship_feature_dir.path_join(filename + ".tscn")
        ResourceSaver.save(scene, scene_path)
        print("Saved Scene: " + scene_path)
        
        # Cleanup
        ship_node.free()
        return true
    else:
        print("Error packing scene: " + str(result))
        ship_node.free()
        return false

func _generate_hardpoints(root: Node, data: ShipModelData):
    # --- Hardpoints Container (Guns, Missiles, Turrets, Eyes) ---
    var hardpoints_root = Node3D.new()
    hardpoints_root.name = "Hardpoints"
    root.add_child(hardpoints_root)
    hardpoints_root.owner = root

    # 1. Guns (Array[ShipHardpointBank])
    if not data.guns.is_empty():
        var group = Node3D.new()
        group.name = "Guns"
        hardpoints_root.add_child(group)
        group.owner = root
        
        for bank in data.guns:
            var bank_node = Node3D.new()
            # Clean bank name
            bank_node.name = "Bank_" + bank.name.replace(" ", "_")
            group.add_child(bank_node)
            bank_node.owner = root
            
            for i in bank.points.size():
                var marker = Marker3D.new()
                marker.name = "Point_" + str(i)
                marker.position = bank.points[i]
                bank_node.add_child(marker)
                marker.owner = root

    # 2. Missiles (Array[ShipHardpointBank])
    if not data.missiles.is_empty():
        var group = Node3D.new()
        group.name = "Missiles"
        hardpoints_root.add_child(group)
        group.owner = root
        
        for bank in data.missiles:
            var bank_node = Node3D.new()
            bank_node.name = "Bank_" + bank.name.replace(" ", "_")
            group.add_child(bank_node)
            bank_node.owner = root
            
            for i in bank.points.size():
                var marker = Marker3D.new()
                marker.name = "Point_" + str(i)
                marker.position = bank.points[i]
                bank_node.add_child(marker)
                marker.owner = root

    # 3. Eyes / Viewpoints (Array[ShipEye])
    if not data.eyes.is_empty():
        var group = Node3D.new()
        group.name = "Eyes"
        hardpoints_root.add_child(group)
        group.owner = root
        
        for i in data.eyes.size():
            var eye_data = data.eyes[i]
            var marker = Marker3D.new()
            marker.name = "Eye_" + str(i)
            marker.position = eye_data.position
            # TODO: Set rotation from eye_data.normal
            group.add_child(marker)
            marker.owner = root

    # 4. Turrets (Array[ShipTurret])
    if not data.turrets.is_empty():
        var group = Node3D.new()
        group.name = "Turrets"
        hardpoints_root.add_child(group)
        group.owner = root
        
        for t_data in data.turrets:
            var t_node = Node3D.new()
            t_node.name = t_data.name
            group.add_child(t_node)
            t_node.owner = root
            
            # Add fire points as markers
            for i in t_data.fire_points.size():
                var marker = Marker3D.new()
                marker.name = "FirePoint_" + str(i)
                marker.position = t_data.fire_points[i]
                t_node.add_child(marker)
                marker.owner = root

    # --- Visuals Container (Thrusters, Engine Glows) ---
    var visuals_root = Node3D.new()
    visuals_root.name = "Visuals"
    root.add_child(visuals_root)
    visuals_root.owner = root

    # 5. Thrusters (Array[ShipThruster])
    if not data.thrusters.is_empty():
        var group = Node3D.new()
        group.name = "Thrusters"
        visuals_root.add_child(group)
        group.owner = root
        
        for i in data.thrusters.size():
            var t_data = data.thrusters[i]
            var glow = GPUParticles3D.new()
            glow.name = "Thruster_" + str(i)
            glow.position = t_data.position
            # Placeholder setup
            glow.emitting = true
            glow.amount = 16
            glow.lifetime = 0.5
            
            group.add_child(glow)
            glow.owner = root


func _map_category_to_feature(cat: String) -> String:
    # "ships/fighter" -> "fighters"
    # "ships/capital" -> "capital_ships"
    if cat.contains("fighter") or cat.contains("bomber"):
        return "fighters"
    if cat.contains("capital"):
        return "capital_ships"
    if cat.contains("utility") or cat.contains("support"):
        return "support"
    return "misc"

func _normalize_filename(name: String) -> String:
    var n = name.to_lower()
    n = n.replace(" ", "_")
    n = n.replace("-", "_")
    n = n.replace("#", "_")
    return n
