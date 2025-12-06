@tool
extends RefCounted
class_name ModelDataGenerator

const ShipModelData = preload("res://scripts/resources/ships/ship_model_data.gd")
const ShipHardpointBank = preload("res://scripts/resources/ships/common/ship_hardpoint_bank.gd")
const ShipTurret = preload("res://scripts/resources/ships/common/ship_turret.gd")
const ShipThruster = preload("res://scripts/resources/ships/common/ship_thruster.gd")
const ShipEye = preload("res://scripts/resources/ships/common/ship_eye.gd")
const ShipSubsystem = preload("res://scripts/resources/ships/common/ship_subsystem.gd")

func generate(json_path: String) -> Resource:
    if not FileAccess.file_exists(json_path):
        printerr("ModelDataGenerator: JSON file not found: " + json_path)
        return null

    var json_string = FileAccess.get_file_as_string(json_path)
    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        printerr("ModelDataGenerator: Failed to parse JSON: " + json.get_error_message())
        return null

    var data: Dictionary = json.data
    var model_data = ShipModelData.new()
    
    model_data.ship_name = data.get("ship_name", "Unknown")
    model_data.source_file = json_path
    
    # Process Hardpoints (Guns & Missiles)
    # The JSON exporter currently dumps all hardpoints as raw list with 'type' field.
    # We need to group them into banks. 
    # Or did we decide to group them in Python? 
    # Python code: "self._process_hardpoints(mesh_data.hardpoints)" returns list of dicts.
    # Each dict: name, position, normal, type, parent.
    
    var hardpoints = data.get("hardpoints", [])
    model_data.guns = _process_weapon_banks(hardpoints, "weapon")
    model_data.missiles = _process_weapon_banks(hardpoints, "missile")
    
    # Process Turrets
    var turrets_data = data.get("turrets", [])
    model_data.turrets = _process_turrets(turrets_data)
    
    # Process Thrusters
    var thrusters_data = data.get("thrusters", [])
    model_data.thrusters = _process_thrusters(thrusters_data)
    
    # Process Eyes
    var eyes_data = data.get("eyes", [])
    model_data.eyes = _process_eyes(eyes_data)
    
    # Process Subsystems
    var subs_data = data.get("subsystems", [])
    model_data.subsystems = _process_subsystems(subs_data)
    
    # Determine Output Path (Change .json to .tres)
    var output_path = json_path.replace("_data.json", "_model.tres")
    var save_err = ResourceSaver.save(model_data, output_path)
    if save_err != OK:
        printerr("ModelDataGenerator: Failed to save resource to " + output_path)
        return null
        
    print("ModelDataGenerator: Successfully generated " + output_path)
    return model_data

func _process_weapon_banks(hardpoints: Array, type_filter: String) -> Array[ShipHardpointBank]:
    var banks: Dictionary = {} # Maps bank_name -> Array[Vector3]
    
    for hp in hardpoints:
        if hp.get("type", "") != type_filter:
            continue
            
        var hp_name: String = hp.get("name", "unknown")
        # Heuristic: group by name prefix? Or assume POF order?
        # Typically "gun bank 1", "gun bank 2".
        # If we can't determine bank, put in "bank_0".
        
        # Simple heuristic: try to extract a number? Or use full name as bank name?
        # Usually POF has multiple points per bank. 
        # Example: "gun-0a", "gun-0b" -> Bank 0. 
        # Let's assume unique names mean unique banks unless formatted specially.
        # Ideally Python side provided bank info. 
        # Since Python side just dumped raw points, let's group by simple string matching or just create single-point banks for now 
        # if we can't be smart.
        
        # BETTER: For now, create one bank per hardpoint called by its name.
        # This is safe but maybe not ideal for fire linking. (User requested "Banks").
        # BUT: ShipHardpointBank contains `points: Array[Vector3]`.
        # If we have "gun-1a" and "gun-1b", they should be in same bank?
        # Let's just create a bank for each point for safety until better logic.
        
        var bank_name = hp_name
        var pos_array: Array[Vector3] = []
        pos_array.append(_parse_vec3(hp.get("position")))
        
        var bank = ShipHardpointBank.new()
        bank.name = bank_name
        bank.points = pos_array
        # No normal in ShipHardpointBank? It's usually implied by orientation or per-point?
        # Checked ShipHardpointBank definition: `points: Array[Vector3]`. No norms.
        
        # TODO: Refine Bank Logic
        # Actually, let's try to group.
        # If name has $bank=... property? JSON export didn't include properties for HPs.
        
        # Temporary: 1 point per bank.
        # Return typed array.
        pass
        
    var result: Array[ShipHardpointBank] = []
    
    # Grouping Logic v2 (Simple):
    # Just dump them.
    for hp in hardpoints:
        if hp.get("type", "") != type_filter:
            continue
        var bank = ShipHardpointBank.new()
        bank.name = hp.get("name", "hardpoint")
        bank.points = [_parse_vec3(hp.get("position"))]
        result.append(bank)
        
    return result

func _process_turrets(data: Array) -> Array[ShipTurret]:
    var result: Array[ShipTurret] = []
    for t_data in data:
        var turret = ShipTurret.new()
        turret.normal = _parse_vec3(t_data.get("normal"))
        
        var fps = t_data.get("fire_points", [])
        var points_vec: Array[Vector3] = []
        for fp in fps:
            points_vec.append(_parse_vec3(fp))
        turret.fire_points = points_vec
        
        # Name?
        turret.name = "turret_" + str(t_data.get("parent_obj_id", 0))
        turret.base_position = Vector3.ZERO # Turret position is relative to subobject, which is assumed 0,0,0 usually?
        
        result.append(turret)
    return result

func _process_thrusters(data: Array) -> Array[ShipThruster]:
    var result: Array[ShipThruster] = []
    for bank_data in data:
        var glows = bank_data.get("glows", [])
        for glow in glows:
            var t = ShipThruster.new()
            t.position = _parse_vec3(glow.get("position"))
            t.normal = _parse_vec3(glow.get("normal"))
            t.radius = glow.get("radius", 1.0)
            # t.is_afterburner_only ... check bank_data.tags?
            result.append(t)
    return result

func _process_eyes(data: Array) -> Array[ShipEye]:
    var result: Array[ShipEye] = []
    for e_data in data:
        var eye = ShipEye.new()
        eye.position = _parse_vec3(e_data.get("position"))
        eye.normal = _parse_vec3(e_data.get("normal"))
        eye.parent_subsystem = str(e_data.get("parent_subobj", ""))
        result.append(eye)
    return result

func _process_subsystems(data: Array) -> Array[ShipSubsystem]:
    var result: Array[ShipSubsystem] = []
    for s_data in data:
        var sub = ShipSubsystem.new()
        sub.name = s_data.get("name", "subsystem")
        sub.bbox_min = _parse_vec3(s_data.get("bbox_min"))
        sub.bbox_max = _parse_vec3(s_data.get("bbox_max"))
        sub.center = _parse_vec3(s_data.get("center"))
        sub.radius = 1.0 # Derived?
        # Targetable?
        
        result.append(sub)
    return result

func _parse_vec3(data) -> Vector3:
    if data is Array and data.size() >= 3:
        return Vector3(data[0], data[1], data[2])
    return Vector3.ZERO
