# scripts/weapon/missile_weapon.gd
extends WeaponInstance
class_name MissileWeapon

# Missile-specific properties or overrides can go here.

func _ready():
	super._ready() # Call parent's ready function


func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	# Override fire to potentially check for lock status before calling super.fire()
	# if weapon_data.flags & GlobalConstants.WIF_LOCKARM or weapon_data.flags & GlobalConstants.WIF_LOCKED_HOMING:
	#     if not _is_target_locked(target): # Need a way to check lock status
	#         print("Missile requires lock, but target is not locked.")
	#         # TODO: Play lock required sound?
	#         return false

	# print("MissileWeapon fire called")
	return super.fire(target, target_subsystem)


# Helper function placeholder to check lock status (needs implementation)
func _is_target_locked(target: Node3D) -> bool:
	# This needs access to the ship's targeting system/state
	# For now, assume locked if a target is provided
	return target != null

# Add any missile-specific methods below.
