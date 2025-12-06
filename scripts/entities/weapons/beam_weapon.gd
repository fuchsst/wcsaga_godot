class_name BeamWeapon
extends Node3D

# Dependencies
const WeaponData = preload("res://scripts/resources/weapons/weapon_data.gd")

# Configuration
@export var weapon_data: WeaponData

# State
var fired_by: Node3D
var is_firing: bool = false
var beam_mesh: MeshInstance3D

func _ready() -> void:
    if weapon_data:
        _setup_visuals()

func setup(shooter: Node3D, turret_node: Node3D) -> void:
    fired_by = shooter
    # Attach to turret or mount point
    if turret_node:
        get_parent().remove_child(self)
        turret_node.add_child(self)
        transform = Transform3D.IDENTITY

func fire() -> void:
    is_firing = true
    visible = true
    # Enable RayCasts / ShapeCasts
    set_process(true)

func stop_fire() -> void:
    is_firing = false
    visible = false
    set_process(false)

func _process(delta: float) -> void:
    if not is_firing:
        return
        
    # Perform Raycast
    var max_len = weapon_data.weapon_range_meters
    var cast_to = Vector3(0, 0, -max_len)
    
    # Simple Raycast for now
    var space_state = get_world_3d().direct_space_state
    var from = global_position
    var to = global_transform * cast_to
    
    var query = PhysicsRayQueryParameters3D.create(from, to)
    if fired_by:
        query.exclude = [fired_by.get_rid()]
        
    var result = space_state.intersect_ray(query)
    
    if result:
        # Hit something
        # Update visual length
        # Apply Damage (continuous)
        pass
    else:
        # Update visual length to max
        pass

func _setup_visuals() -> void:
    # Create simple cylinder or quad for beam
    pass
