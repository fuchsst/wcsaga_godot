# Confederation Rapier ship entity for Godot
# This is a basic ship entity that can be instantiated in the game world with weapon hardpoints

class_name ConfedRapier
extends Node3D

# Reference to the ship data resource
@export var ship_data: ShipData

# Ship state
var current_shields: float = 0.0
var current_hitpoints: float = 0.0
var current_energy: float = 0.0

# Weapon hardpoints
@onready var weapon_hardpoints = $WeaponHardpoints
@onready var engine_nodes = $Engines

# Physics
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO

func _ready():
	# Initialize the ship
	if ship_data:
		# Set up the ship based on its data
		setup_ship()

func setup_ship():
	"""
	Set up the ship based on its data resource
	"""
	if not ship_data:
		return
		
	# Initialize ship stats from data
	current_shields = ship_data.shields
	current_hitpoints = ship_data.hitpoints
	current_energy = ship_data.power_output
	
	# Set up weapon hardpoints based on ship data
	# In a real implementation, you would parse the gun_mounts data
	# and create appropriate weapon instances
	
	# Set up engine properties
	setup_engines()

func setup_engines():
	"""
	Set up engine properties from ship data
	"""
	if not ship_data or not engine_nodes:
		return
		
	# Configure engine effects based on ship data
	# This would typically involve setting up particle effects, sounds, etc.

func take_damage(damage: float, damage_type: String = "generic"):
	"""
	Apply damage to the ship
	"""
	if damage <= 0:
		return
		
	var actual_damage = damage
	
	# Apply damage factors based on type
	match damage_type:
		"armor":
			actual_damage *= ship_data.armor_factor if ship_data else 1.0
		"shield":
			actual_damage *= ship_data.shield_factor if ship_data else 1.0
		"subsystem":
			actual_damage *= ship_data.subsystem_factor if ship_data else 1.0
			
	# Apply damage to shields first
	if current_shields > 0:
		if actual_damage <= current_shields:
			current_shields -= actual_damage
			actual_damage = 0
		else:
			actual_damage -= current_shields
			current_shields = 0
			
	# Apply remaining damage to hull
	if actual_damage > 0:
		current_hitpoints -= actual_damage
		
	# Check if ship is destroyed
	if current_hitpoints <= 0:
		destroy_ship()

func regenerate_shields(delta: float):
	"""
	Regenerate shields over time
	"""
	if not ship_data or current_shields >= ship_data.shields:
		return
		
	var regen_amount = ship_data.shield_regen_rate * delta
	current_shields = min(current_shields + regen_amount, ship_data.shields)

func regenerate_weapons(delta: float):
	"""
	Regenerate weapon energy over time
	"""
	if not ship_data:
		return
		
	current_energy = min(current_energy + (ship_data.weapon_regen_rate * delta), ship_data.power_output)

func destroy_ship():
	"""
	Destroy the ship
	"""
	# In a real implementation, this would involve:
	# 1. Playing explosion effects
	# 2. Spawning debris
	# 3. Removing the ship from the game world
	# 4. Notifying other systems of the ship's destruction
	
	print("Ship destroyed: %s" % (ship_data.name if ship_data else "Unknown"))

func fire_weapons():
	"""
	Fire all weapons mounted on the ship
	"""
	if not weapon_hardpoints:
		return
		
	# Iterate through all weapon hardpoints and fire weapons
	for i in range(weapon_hardpoints.get_child_count()):
		var hardpoint = weapon_hardpoints.get_child(i)
		if hardpoint and hardpoint.has_method("start_firing"):
			hardpoint.start_firing()

func stop_firing_weapons():
	"""
	Stop firing all weapons
	"""
	if not weapon_hardpoints:
		return
		
	# Iterate through all weapon hardpoints and stop firing
	for i in range(weapon_hardpoints.get_child_count()):
		var hardpoint = weapon_hardpoints.get_child(i)
		if hardpoint and hardpoint.has_method("stop_firing"):
			hardpoint.stop_firing()

func get_shield_percentage() -> float:
	"""
	Get the current shield percentage
	"""
	if not ship_data:
		return 0.0
	return (current_shields / ship_data.shields) * 100.0 if ship_data.shields > 0 else 0.0

func get_hull_percentage() -> float:
	"""
	Get the current hull percentage
	"""
	if not ship_data:
		return 0.0
	return (current_hitpoints / ship_data.hitpoints) * 100.0 if ship_data.hitpoints > 0 else 0.0

func _process(delta):
	"""
	Process the ship each frame
	"""
	# Regenerate shields and weapons
	regenerate_shields(delta)
	regenerate_weapons(delta)
	
	# Update physics
	update_physics(delta)

func update_physics(delta: float):
	"""
	Update ship physics
	"""
	# Apply velocity
	global_transform.origin += velocity * delta
	
	# Apply angular velocity (rotation)
	rotate_x(angular_velocity.x * delta)
	rotate_y(angular_velocity.y * delta)
	rotate_z(angular_velocity.z * delta)

# Ship movement functions
func accelerate.forward(thrust: float):
	"""
	Apply forward thrust
	"""
	if not ship_data:
		return
		
	# Apply thrust in the ship's forward direction
	var forward = global_transform.basis.z.normalized()
	velocity += forward * thrust * delta

func turn.pitch(angle: float):
	"""
	Pitch the ship (rotate around local X axis)
	"""
	angular_velocity.x += angle

func turn.yaw(angle: float):
	"""
	Yaw the ship (rotate around local Y axis)
	"""
	angular_velocity.y += angle

func turn.roll(angle: float):
	"""
	Roll the ship (rotate around local Z axis)
	"""
	angular_velocity.z += angle