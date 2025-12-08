class_name ShipWeaponSystem
extends Node

## Central weapon controller for a ship
## Manages primary and secondary banks, firing logic, and energy

signal primary_bank_changed(index: int)
signal secondary_bank_changed(index: int)
signal weapon_fired(bank_index: int, is_secondary: bool)

# Dependencies
const WeaponBank = preload("res://scripts/entities/ship/weapon_bank.gd")

# Owner
var ship: Node # ShipEntity

# Banks
var primary_banks: Array[WeaponBank] = []
var secondary_banks: Array[WeaponBank] = []

# Selection
var active_primary_index: int = 0
var active_secondary_index: int = 0

# Firing State
var is_trigger_held: bool = false
var is_secondary_trigger_held: bool = false


func setup(ship_entity: Node) -> void:
	ship = ship_entity
	_initialize_banks()
	
	# Load default weapons if defined in stats
	_load_defaults()


func _process(delta: float) -> void:
	# Update cooldowns
	for bank in primary_banks:
		bank.update(delta)
	for bank in secondary_banks:
		bank.update(delta)
		
	# Handle continuous fire for primary
	if is_trigger_held:
		_fire_active_primary()


func set_trigger(held: bool) -> void:
	is_trigger_held = held

func set_secondary_trigger(held: bool) -> void:
	is_secondary_trigger_held = held
	if held:
		_fire_active_secondary()


func cycle_primary() -> void:
	if primary_banks.is_empty(): return
	active_primary_index = (active_primary_index + 1) % primary_banks.size()
	primary_bank_changed.emit(active_primary_index)


func cycle_secondary() -> void:
	if secondary_banks.is_empty(): return
	active_secondary_index = (active_secondary_index + 1) % secondary_banks.size()
	secondary_bank_changed.emit(active_secondary_index)


func _fire_active_primary() -> void:
	if primary_banks.is_empty(): return
	
	# If "fire all" mode is implemented, we might fire multiple banks
	# For now, just active bank
	var bank = primary_banks[active_primary_index]
	if bank.fire(ship.get_target() if ship.has_method("get_target") else null):
		weapon_fired.emit(active_primary_index, false)


func _fire_active_secondary() -> void:
	if secondary_banks.is_empty(): return
	
	var bank = secondary_banks[active_secondary_index]
	if bank.fire(ship.get_target() if ship.has_method("get_target") else null):
		weapon_fired.emit(active_secondary_index, true)


func _initialize_banks() -> void:
	primary_banks.clear()
	secondary_banks.clear()
	
	if not ship.has_method("get_stats") and not "stats" in ship:
		return
		
	var stats = ship.stats
	if not stats: return
	
	var hardpoints_root = ship.get_node_or_null("Hardpoints")
	if not hardpoints_root: return
	
	# Parse WeaponMounts
	for mount in stats.weapon_mounts:
		var bank_node_name = "Bank_" + mount.mount_name.replace(" ", "_")
		
		# Find hardpoints
		var points: Array[Node3D] = []
		var group_name = "Guns" if mount.mount_type == 0 else "Missiles"
		
		var group_node = hardpoints_root.get_node_or_null(group_name)
		if group_node:
			var bank_node = group_node.get_node_or_null(bank_node_name)
			if bank_node:
				for child in bank_node.get_children():
					if child is Node3D: # Marker3D inherits Node3D
						points.append(child)
		
		if points.is_empty():
			# Warning: Defined mount has no physical hardpoints
			# push_warning("WeaponSystem: Mount " + mount.mount_name + " has no hardpoints")
			continue
			
		var bank = WeaponBank.new(ship, mount, points)
		
		if mount.mount_type == 0: # Primary
			primary_banks.append(bank)
		elif mount.mount_type == 1: # Secondary
			secondary_banks.append(bank)


func _load_defaults() -> void:
	var stats = ship.stats
	if not stats: return
	
	# Load default primaries
	# Assuming stats.default_primary_loadouts contains WeaponData resource paths or names
	for i in range(min(primary_banks.size(), stats.default_primary_loadouts.size())):
		var weapon_ref = stats.default_primary_loadouts[i]
		if not weapon_ref.is_empty():
			# Resolve resource
			# If it's a string path, load it. If it's a name, lookup via database?
			# Assuming path for now
			if ResourceLoader.exists(weapon_ref):
				var weapon_res = load(weapon_ref)
				primary_banks[i].load_weapon(weapon_res)

	# Load default secondaries
	for i in range(min(secondary_banks.size(), stats.default_secondary_loadouts.size())):
		var weapon_ref = stats.default_secondary_loadouts[i]
		if not weapon_ref.is_empty():
			if ResourceLoader.exists(weapon_ref):
				var weapon_res = load(weapon_ref)
				secondary_banks[i].load_weapon(weapon_res)
