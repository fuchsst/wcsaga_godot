# Combat system for Godot
# This system integrates weapons and ships in combat scenarios

class_name CombatSystem
extends Node

# Combat state
var active_combatants: Array = []
var projectiles: Array = []

func _ready():
	# Initialize the combat system
	pass

func register_combatant(combatant: Node):
	"""
	Register a combatant (ship) with the combat system
	"""
	if not active_combatants.has(combatant):
		active_combatants.append(combatant)

func unregister_combatant(combatant: Node):
	"""
	Unregister a combatant from the combat system
	"""
	active_combatants.erase(combatant)

func create_projectile(weapon_data: WeaponData, origin: Vector3, direction: Vector3, owner: Node) -> Node3D:
	"""
	Create a projectile based on weapon data
	"""
	# In a real implementation, you would:
	# 1. Instance a projectile scene based on the weapon type
	# 2. Set up the projectile with the weapon's properties
	# 3. Add it to the scene and physics simulation
	# 4. Track it in the projectiles array
	
	var projectile = Node3D.new()
	projectile.position = origin
	projectile.look_at(origin + direction, Vector3.UP)
	
	# Store projectile data
	projectile.set_meta("weapon_data", weapon_data)
	projectile.set_meta("owner", owner)
	projectile.set_meta("velocity", direction * weapon_data.velocity)
	
	# Add to scene
	add_child(projectile)
	projectiles.append(projectile)
	
	return projectile

func update_projectiles(delta: float):
	"""
	Update all active projectiles
	"""
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile = projectiles[i]
		if not is_instance_valid(projectile):
			projectiles.remove_at(i)
			continue
			
		# Move projectile
		var velocity = projectile.get_meta("velocity", Vector3.ZERO)
		projectile.position += velocity * delta
		
		# Check projectile lifetime
		var weapon_data = projectile.get_meta("weapon_data", null)
		if weapon_data:
			# Simple lifetime check based on distance or time
			var distance_traveled = projectile.position.distance_to(projectile.get_meta("start_position", projectile.position))
			if distance_traveled > weapon_data.velocity * weapon_data.lifetime:
				# Projectile expired
				projectile.queue_free()
				projectiles.remove_at(i)

func check_collisions():
	"""
	Check for collisions between projectiles and ships
	"""
	# In a real implementation, you would:
	# 1. Use Godot's physics system (Area3D, CollisionShape3D) for efficient collision detection
	# 2. Check each projectile against potential targets
	# 3. Apply damage to hit targets
	# 4. Remove expired projectiles
	
	# This is a simplified version for demonstration
	for projectile in projectiles:
		if not is_instance_valid(projectile):
			continue
			
		var weapon_data = projectile.get_meta("weapon_data", null)
		var owner = projectile.get_meta("owner", null)
		
		if not weapon_data or not owner:
			continue
			
		# Check for hits against combatants
		for combatant in active_combatants:
			if combatant == owner:
				continue  # Don't hit the owner
				
			# Simple distance check (in a real game, use proper collision detection)
			if projectile.position.distance_to(combatant.position) < 2.0:
				# Hit detected
				apply_damage(combatant, weapon_data.damage, weapon_data)
				
				# Remove projectile
				projectile.queue_free()
				projectiles.erase(projectile)
				break

func apply_damage(target: Node, damage: float, weapon_data: WeaponData):
	"""
	Apply damage from a weapon to a target
	"""
	# Determine damage type based on weapon properties
	var damage_type = "generic"
	if weapon_data.impact_explosion != "":
		damage_type = "explosion"
	elif weapon_data.is_bomb:
		damage_type = "bomb"
		
	# Apply damage to target if it has a take_damage method
	if target.has_method("take_damage"):
		target.take_damage(damage, damage_type)
		
	# Play impact effects
	play_impact_effects(target.position, weapon_data)

func play_impact_effects(position: Vector3, weapon_data: WeaponData):
	"""
	Play visual and audio effects for weapon impacts
	"""
	# In a real implementation, you would:
	# 1. Instance an appropriate impact effect based on weapon_data.impact_explosion
	# 2. Play an impact sound based on weapon_data.impact_sound
	# 3. Apply screen shake or other feedback effects
	pass

func _process(delta):
	"""
	Process combat each frame
	"""
	update_projectiles(delta)
	check_collisions()

func get_nearest_target(from_position: Vector3, exclude: Node = null) -> Node:
	"""
	Find the nearest combatant to a position
	"""
	var nearest: Node = null
	var nearest_distance: float = INF
	
	for combatant in active_combatants:
		if combatant == exclude:
			continue
			
		var distance = from_position.distance_to(combatant.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = combatant
			
	return nearest

func get_targets_in_cone(origin: Vector3, direction: Vector3, angle: float, max_distance: float, exclude: Node = null) -> Array:
	"""
	Get all combatants within a cone-shaped area
	"""
	var targets = []
	
	for combatant in active_combatants:
		if combatant == exclude:
			continue
			
		var to_target = combatant.position - origin
		var distance = to_target.length()
		
		if distance > max_distance:
			continue
			
		to_target = to_target.normalized()
		var dot = direction.dot(to_target)
		var target_angle = acos(dot)
		
		if target_angle <= angle:
			targets.append(combatant)
			
	return targets