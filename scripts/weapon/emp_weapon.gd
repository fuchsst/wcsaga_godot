extends WeaponInstance
class_name EMPWeapon

# EMP specific properties from WeaponData (can be accessed via weapon_data)
# var emp_intensity: float = GlobalConstants.EMP_DEFAULT_INTENSITY
# var emp_time: float = GlobalConstants.EMP_DEFAULT_TIME

# NOTE: The core EMP logic (applying effects to ships/subsystems) should be
# implemented in the ProjectileBase._apply_impact method (or a dedicated EMPProjectile script),
# triggered upon collision. The projectile should call the apply_emp_effect method on the hit ShipBase.

func _ready():
	super._ready()
	# No specific EMP initialization needed here for now.


# Override fire if needed for EMP-specific launch behavior.
# For now, just call the base fire method.
func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	var fired = super.fire(target, target_subsystem)
	if fired:
		# TODO: Trigger EMP-specific muzzle flash?
		print("EMPWeapon fired (base logic)!") # Placeholder print
	return fired


# Override can_fire if needed for specific EMP checks
# func can_fire() -> bool:
#	 if not super.can_fire():
#		 return false
#	 # TODO: Check ammo/energy via WeaponSystem reference
#	 return true
