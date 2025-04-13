# scripts/weapon/projectiles/emp_projectile.gd
extends ProjectileBase
class_name EMPProjectile

# EMP specific properties can be accessed via weapon_data
# weapon_data.emp_intensity
# weapon_data.emp_time

func _physics_process(delta):
	# Handle standard projectile updates (lifetime, basic movement)
	super._physics_process(delta)
	# No specific EMP movement logic needed here.

# Override _apply_impact to handle EMP effect application.
func _apply_impact(hit_object: Node, hit_position: Vector3, hit_normal: Vector3):
	# Call base impact first to handle standard effects (sound, visual explosion)
	# Note: Base _apply_impact queues_free at the end, so EMP logic must happen before calling super.
	# Let's re-evaluate this. The base _apply_impact handles sound/visuals/damage.
	# We want the EMP effect *in addition* to those, not instead of them.
	# The base class already calls queue_free().

	if not weapon_data: return

	var is_armed = _is_armed()

	# Apply EMP effect if armed and hit object is a ship
	if is_armed and is_instance_valid(hit_object) and hit_object is ShipBase:
		var target_ship: ShipBase = hit_object
		# Call the method on the ship to apply the effect
		if target_ship.has_method("apply_emp_effect"):
			target_ship.apply_emp_effect(weapon_data.emp_intensity, weapon_data.emp_time)
			print("EMPProjectile: Applied EMP Effect to %s (Intensity: %.1f, Time: %.1f)" % [target_ship.name, weapon_data.emp_intensity, weapon_data.emp_time])
		else:
			printerr("EMPProjectile: EMP Hit Ship %s which has no apply_emp_effect method!" % target_ship.name)
	# else: EMP hit something other than a ship, or wasn't armed.

	# Now call the base impact logic to handle standard damage, sound, visual effects, and queue_free()
	super._apply_impact(hit_object, hit_position, hit_normal)

# Override expiration if EMP needs a specific visual/sound on fizzle
# func _expire():
#     super._expire()
#     # Add specific EMP fizzle effect?
