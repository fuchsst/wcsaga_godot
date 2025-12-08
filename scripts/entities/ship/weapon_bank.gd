class_name WeaponBank
extends RefCounted

## Manages a single weapon bank (collection of linked hardpoints)
## Handles firing logic, cooldowns, and projectile spawning

# Configuration
var bank_name: String = ""
var is_secondary: bool = false
var hardpoints: Array[Node3D] = [] # Marker3D nodes
var mount_info: Resource # WeaponMount from ShipStats (defines linkage/gimbal)
var weapon_data: Resource # WeaponData (loaded weapon type)

# State
var current_ammo: int = -1 # -1 = infinite
var max_ammo: int = -1
var cooldown_timer: float = 0.0
var fire_sequence_index: int = 0 # For sequential firing (if not firing all at once)

# Owner
var ship: Node # ShipEntity

func _init(ship_entity: Node, mount_res: Resource, hardpoint_nodes: Array[Node3D]) -> void:
	ship = ship_entity
	mount_info = mount_res
	hardpoints = hardpoint_nodes
	
	if mount_info:
		bank_name = mount_info.mount_name
		is_secondary = (mount_info.mount_type == 1)

func load_weapon(weapon_res: Resource) -> void:
	weapon_data = weapon_res
	if not weapon_data:
		return
		
	# Initialize ammo if secondary
	if is_secondary:
		# TODO: Get max capacity from mount or ship stats?
		# Usually capacity is defined per bank in ShipStats but standard TBL might define it differently
		# unique capacity per projectile type?
		# For now assume infinite or set from loadout
		current_ammo = 10 # Placeholder default
		max_ammo = 10

func update(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

func can_fire() -> bool:
	if not weapon_data:
		return false
	if cooldown_timer > 0:
		return false
	if current_ammo == 0:
		return false
	return true

func fire(target: Node = null) -> bool:
	if not can_fire():
		return false
		
	# Consume energy (if primary)
	if not is_secondary:
		var energy_cost = weapon_data.energy_consumed
		if ship.has_method("consume_weapon_energy"):
			if not ship.consume_weapon_energy(energy_cost):
				return false
	
	# Consume ammo
	if current_ammo > 0:
		current_ammo -= 1
		
	# Set cooldown
	cooldown_timer = weapon_data.refire_delay
	
	# Spawn projectiles
	# If bank fires all points simultaneously:
	for point in hardpoints:
		_spawn_projectile(point, target)
		
	return true

func _spawn_projectile(_spawn_point: Node3D, _target: Node) -> void:
	# Instantiate projectile scene
	# WeaponData should have projectile_scene path or resource
	# For now we assume WeaponData has a way to get the scene
	# TODO: Implement projectile spawning
	# var proj = weapon_data.instantiate_projectile()
	# ship.get_parent().add_child(proj)
	# ... setup position/velocity
	pass
