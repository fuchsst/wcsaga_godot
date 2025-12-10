class_name WeaponBank
extends RefCounted

## Manages a single weapon bank (collection of linked hardpoints)
## Handles firing logic, cooldowns, and projectile spawning

# Configuration
var bank_name: String = ""
var is_secondary: bool = false
var hardpoints: Array[Node3D] = []  # Marker3D nodes
var mount_info: Resource  # WeaponMount from ShipStats (defines linkage/gimbal)
var weapon_data: Resource  # WeaponData (loaded weapon type)

# State
var current_ammo: int = -1  # -1 = infinite
var max_ammo: int = -1
var cooldown_timer: float = 0.0
var fire_sequence_index: int = 0  # For sequential firing (if not firing all at once)

# Owner
var ship: Node  # ShipEntity


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
		current_ammo = 10  # Placeholder default
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
		var energy_cost = weapon_data.energy_per_shot
		if ship.has_method("consume_weapon_energy"):
			if not ship.consume_weapon_energy(energy_cost):
				return false

	# Consume ammo
	if current_ammo > 0:
		current_ammo -= 1

	# Set cooldown (fire_rate_hz = shots per second, so delay = 1/rate)
	if weapon_data.fire_rate_hz > 0:
		cooldown_timer = 1.0 / weapon_data.fire_rate_hz
	else:
		cooldown_timer = 1.0  # Default 1 second if not specified

	# Spawn projectiles
	# If bank fires all points simultaneously:
	for point in hardpoints:
		_spawn_projectile(point, target)

	return true


func _spawn_projectile(spawn_point: Node3D, target: Node) -> void:
	if not weapon_data:
		push_error("WeaponBank: No weapon_data to spawn projectile")
		return

	# Get projectile scene path
	var scene_path: String = ""

	# Check if WeaponData has scene_path property
	if "scene_path" in weapon_data and not weapon_data.scene_path.is_empty():
		scene_path = weapon_data.scene_path
	else:
		# Try to derive scene path from resource path
		# e.g., weapon_data at res://assets/weapons/.../laser.tres -> .../laser.tscn
		var tres_path = weapon_data.resource_path
		if not tres_path.is_empty():
			scene_path = tres_path.get_basename() + ".tscn"

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("WeaponBank: Projectile scene not found: " + scene_path)
		return

	# Load and instantiate the scene
	var scene = load(scene_path) as PackedScene
	if not scene:
		push_error("WeaponBank: Failed to load projectile scene: " + scene_path)
		return

	var projectile = scene.instantiate()
	if not projectile:
		push_error("WeaponBank: Failed to instantiate projectile")
		return

	# Add to scene tree (sibling to ship, not child)
	var spawn_parent = ship.get_parent()
	if not spawn_parent:
		spawn_parent = ship.get_tree().root
	spawn_parent.add_child(projectile)

	# Position at hardpoint
	projectile.global_transform = spawn_point.global_transform

	# Set weapon_data on projectile (if it has the property)
	if "weapon_data" in projectile:
		projectile.weapon_data = weapon_data
	elif projectile.has_meta("weapon_data"):
		# Scene stores it in metadata, script should read it
		pass

	# Call setup method if available (BaseWeapon convention)
	if projectile.has_method("setup"):
		var ship_velocity = Vector3.ZERO
		if ship is RigidBody3D:
			ship_velocity = ship.linear_velocity
		elif "velocity" in ship:
			ship_velocity = ship.velocity
		projectile.setup(spawn_point.global_position, ship_velocity, ship, target)

	# Set team on projectile if available
	if "team" in projectile and "team" in ship:
		projectile.team = ship.team
