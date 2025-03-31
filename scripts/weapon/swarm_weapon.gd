extends MissileWeapon
class_name SwarmWeapon

# Swarm specific properties from WeaponData (can be accessed via weapon_data)
# var swarm_count: int = 4
# var swarm_wait: int = 150 # ms

# NOTE: The core swarm logic (firing multiple projectiles in sequence)
# is handled by the WeaponSystem and ShipBase (_manage_weapon_sequences),
# initiated when fire_secondary is called for this weapon type.
# Projectile-specific swarm behavior (e.g., pathing) would be in MissileProjectile
# or a derived SwarmProjectile script.

func _ready():
	super._ready()
	# No specific swarm initialization needed here for now.


# Override fire if needed for swarm-specific launch adjustments.
# For now, rely on the base MissileWeapon fire method.
func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	# The WeaponSystem handles initiating the sequence.
	# This fire() method will be called multiple times by ShipBase._manage_weapon_sequences.
	var fired = super.fire(target, target_subsystem)
	if fired:
		print("SwarmWeapon fired (base MissileWeapon logic)!") # Placeholder print
	return fired
