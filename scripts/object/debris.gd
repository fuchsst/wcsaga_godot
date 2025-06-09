# scripts/object/debris.gd
extends RigidBody3D # Use RigidBody for physics simulation
class_name DebrisObject

# TODO: Add properties specific to debris, like lifetime, damage multiplier, etc.
@export var lifetime: float = 30.0 # Default lifetime in seconds
@export var damage_mult: float = 1.0
# var model_num: int = -1 # Index to model resource if needed
var hull_strength: float = 10.0 # Example initial health

# Signals
signal destroyed

func _ready():
	# Initialization logic for debris
	# Connect body_entered signal for physics collisions
	body_entered.connect(_on_body_entered)
	pass

func _physics_process(delta):
	# Update lifetime, check for expiration
	lifetime -= delta
	if lifetime <= 0.0:
		# print("Debris lifetime expired")
		_destroy_debris_internal() # Use internal function to avoid duplicate signal emission
	pass

# Called when hit by something (e.g., weapon, ship)
# Corresponds roughly to debris_hit()
func hit(source_object: Node, hit_pos: Vector3, damage: float):
	if hull_strength <= 0.0: return # Already destroyed

	# Apply damage multiplier
	var actual_damage = damage * damage_mult
	hull_strength -= actual_damage
	# print("Debris hit, health: ", hull_strength)
	if hull_strength <= 0.0:
		_destroy_debris_internal()

# Internal function to handle destruction logic and signal emission
func _destroy_debris_internal():
	if hull_strength > 0.0: # Prevent multiple destructions/signals
		hull_strength = 0.0 # Mark as destroyed immediately

		# TODO: Spawn smaller debris pieces or explosion effect
		# EffectManager.create_debris_explosion(global_position, radius) # Example
		print("Debris destroyed")
		emit_signal("destroyed")
		queue_free()

# Collision handler for physics interactions
func _on_body_entered(body: Node3D):
	# Ignore collision if already destroyed
	if hull_strength <= 0.0: return

	var hit_pos = global_position # Approximate contact point

	if body is BaseShip:
		var ship: BaseShip = body
		print("Debris collided with Ship ", ship.name)
		# Apply damage to ship (placeholder amount, scaled by debris damage multiplier)
		# TODO: Calculate impact damage based on relative velocity/mass?
		if ship.has_method("take_damage"):
			ship.take_damage(hit_pos, 5.0 * damage_mult, get_instance_id()) # Pass debris instance ID as killer
		# Destroy debris on impact with ship
		_destroy_debris_internal()
	elif body is WeaponBase:
		# Weapon collision is handled by the weapon's _on_body_entered calling our hit() method.
		pass
	elif body is DebrisObject:
		# Optional: Handle debris-debris collisions (e.g., bounce off, destroy smaller one)
		# Maybe apply small damage to each other?
		# hit(body, hit_pos, 1.0) # Example: Apply tiny damage
		pass
	elif body is AsteroidObject:
		# Optional: Handle debris-asteroid collisions
		# Asteroid might destroy debris, debris might slightly damage asteroid?
		# hit(body, hit_pos, 1.0) # Example: Apply tiny damage
		pass
