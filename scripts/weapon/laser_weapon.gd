# scripts/weapon/laser_weapon.gd
extends WeaponInstance
class_name LaserWeapon

# Laser-specific properties or overrides can go here if needed.
# For simple lasers, most logic might be in the base class and the projectile.

func _ready():
	super._ready() # Call parent's ready function

func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	# Override fire if laser behavior differs significantly,
	# otherwise, rely on the base WeaponInstance fire method.
	# For example, beam weapons would heavily override this.
	# Standard lasers might just call super.fire() after potentially
	# checking laser-specific conditions.
	# print("LaserWeapon fire called")
	return super.fire(target, target_subsystem)

# Add any laser-specific methods below, e.g., for charge-up mechanics.
