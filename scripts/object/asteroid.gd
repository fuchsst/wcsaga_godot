# scripts/object/asteroid.gd
extends RigidBody3D # Use RigidBody for physics simulation
class_name AsteroidObject

# TODO: Add properties like asteroid type, subtype, initial health, etc.
# @export var asteroid_type: int = 0
# @export var asteroid_subtype: int = 0
var hull_strength: float = 500.0 # Example initial health

func _ready():
	# Initialization logic for asteroids
	# Set initial health based on type/subtype?
	# hull_strength = initial_health
	# Connect body_entered signal
	body_entered.connect(_on_body_entered)
	pass

func _physics_process(delta):
	# Asteroids might just drift, or have slow rotation
	pass

# Called when hit by something (e.g., weapon)
func hit(source_object: Node, hit_pos: Vector3, damage: float):
	if hull_strength <= 0.0: return # Already destroyed

	# TODO: Apply armor/resistance based on asteroid type?
	hull_strength -= damage
	# print("Asteroid hit, health: ", hull_strength)
	if hull_strength <= 0.0:
		destroy_asteroid()

func destroy_asteroid():
	# TODO: Spawn debris, explosion effect
	# EffectManager.create_asteroid_explosion(global_position, radius) # Example
	print("Asteroid destroyed")
	queue_free()

# Collision handler
func _on_body_entered(body: Node3D):
	if hull_strength <= 0.0: return # Ignore if already destroyed

	var hit_pos = global_position # Approximate

	if body is ShipBase:
		var ship: ShipBase = body
		print("Asteroid collided with Ship ", ship.name)
		# Apply damage to ship (placeholder amount)
		# TODO: Calculate damage based on relative velocity/mass?
		ship.take_damage(hit_pos, 20.0, get_instance_id()) # Placeholder damage
		# Damage the asteroid based on ship impact?
		hit(ship, hit_pos, 50.0) # Placeholder damage to asteroid

	elif body is WeaponBase:
		# Weapon collision is handled by the weapon itself calling our hit() method.
		pass
	elif body is DebrisObject:
		# Optional: Handle asteroid-debris collisions
		pass
	elif body is AsteroidObject:
		# Optional: Handle asteroid-asteroid collisions (bounce?)
		pass
