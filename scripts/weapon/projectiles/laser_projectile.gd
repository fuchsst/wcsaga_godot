# scripts/weapon/projectiles/laser_projectile.gd
extends ProjectileBase
class_name LaserProjectile

# Laser-specific properties or overrides can go here.
# For example, handling beam rendering if this represents a continuous laser,
# or specific impact effects.

func _ready():
	super._ready() # Call parent's ready function


func _physics_process(delta):
	super._physics_process(delta) # Call parent's physics process

	# Add any laser-specific per-frame logic here.
	# For simple laser bolts, the base movement might be sufficient.
	# If this represents a beam, update beam visuals/collision checks here.


func _apply_impact(hit_object: Node, hit_position: Vector3, hit_normal: Vector3):
	# Override impact logic if lasers have unique effects
	# print("Laser projectile impact!")

	# Call the base impact logic to handle damage, sound, basic effects
	super._apply_impact(hit_object, hit_position, hit_normal)

	# Add laser-specific impact effects here (e.g., different particle effect)


func _expire():
	# Override if lasers have a specific expiration behavior (e.g., fade out)
	# print("Laser projectile expired")
	super._expire() # Call base expiration logic (removes the node)
