extends MissileWeapon
class_name CorkscrewWeapon

# Corkscrew specific properties from WeaponData (can be accessed via weapon_data)
# var cs_num_fired: int = 4
# var cs_radius: float = 1.25
# var cs_delay: int = 30 # ms
# var cs_crotate: bool = true
# var cs_twist: float = 5.0

# NOTE: The core corkscrew logic (firing multiple projectiles in sequence or specific projectile movement)
# should be handled by the WeaponSystem and ShipBase (_manage_weapon_sequences),
# initiated when fire_secondary is called for this weapon type.
# Projectile-specific corkscrew movement would be in MissileProjectile
# or a derived CorkscrewProjectile script.

func _ready():
	super._ready()
	# No specific corkscrew initialization needed here for now.


# Override fire if needed for corkscrew-specific launch adjustments.
# For now, rely on the base MissileWeapon fire method.
func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	# The WeaponSystem handles initiating the sequence.
	# This fire() method will be called multiple times by ShipBase._manage_weapon_sequences.
	var fired = super.fire(target, target_subsystem)
	if fired:
		print("CorkscrewWeapon fired (base MissileWeapon logic)!") # Placeholder print
	return fired


# Override can_fire if needed for specific corkscrew checks
# func can_fire() -> bool:
#	 if not super.can_fire():
#		 return false
#	 # TODO: Check ammo/energy via WeaponSystem reference, potentially considering cs_num_fired
#	 return true
