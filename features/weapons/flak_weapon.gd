class_name FlakWeapon
extends ProjectileWeapon

# Flak specific logic
# Flak detonates near target or at distance

func _handle_movement(step: Vector3) -> void:
    super._handle_movement(step)
    
    # Check for proximity detonation if target is set
    if target and is_instance_valid(target):
        var dist = global_position.distance_to(target.global_position)
        if dist < weapon_data.det_radius: # Using det_radius from data
             _detonate()
