# BTWeaponSelect - Enhanced Weapon Selection
# Selects optimal weapon based on target type, range, and ammunition
# Based on legacy aicode.cpp weapon selection logic

@tool
extends BTAction

## Selection priorities
@export var prefer_missiles_for_capital: bool = true
@export var conserve_missiles: bool = true
@export var energy_threshold: float = 0.3 ## Min energy before conserving

## Selection result
var _selected_weapon_group: int = 0 # 0=primary, 1=secondary


func _generate_name() -> String:
	return "WeaponSelect"


func _tick(_delta: float) -> Status:
	var ship = blackboard.get_var("ship")
	var target = blackboard.get_var("target")
	var ai_class = blackboard.get_var("ai_class")

	if not ship or not is_instance_valid(ship):
		return FAILURE

	# Get weapon system
	var weapon_system = null
	if ship.has_method("get_weapon_system"):
		weapon_system = ship.get_weapon_system()
	elif "weapon_system" in ship:
		weapon_system = ship.weapon_system

	if not weapon_system:
		return FAILURE

	# Determine optimal weapon
	var use_secondary = _should_use_secondary(ship, target, ai_class)

	if use_secondary:
		_selected_weapon_group = 1
		blackboard.set_var("weapon_group", 1)
		blackboard.set_var("use_secondary", true)
	else:
		_selected_weapon_group = 0
		blackboard.set_var("weapon_group", 0)
		blackboard.set_var("use_secondary", false)

	return SUCCESS


func _should_use_secondary(ship: Node, target: Node, ai_class: Resource) -> bool:
	"""Determine if secondary weapons should be used"""
	if not target or not is_instance_valid(target):
		return false

	# Check ammunition conservation
	if conserve_missiles:
		var missile_count = _get_missile_count(ship)
		if missile_count <= 1: # Save last missile
			return false

	# Check target type
	var target_is_capital = false
	if target.is_in_group("capital"):
		target_is_capital = true
	elif "ship_class" in target:
		var ship_class = target.ship_class
		if ship_class in ["cruiser", "capital", "supercap", "destroyer"]:
			target_is_capital = true

	if target_is_capital and prefer_missiles_for_capital:
		return true

	# Check AI class missile chance
	if ai_class and "ai_chance_to_use_missiles_on_plr" in ai_class:
		var chance = ai_class.ai_chance_to_use_missiles_on_plr
		# Chance is x/7
		if randf() < (chance / 7.0):
			return true

	# Check range
	var dist = ship.global_position.distance_to(target.global_position)
	var secondary_range = 2000.0
	if ai_class and "ai_secondary_range_mult" in ai_class:
		secondary_range *= ai_class.ai_secondary_range_mult

	# Use missiles at long range
	if dist > 800.0 and dist < secondary_range:
		if randf() < 0.3: # 30% chance at good range
			return true

	return false


func _get_missile_count(ship: Node) -> int:
	"""Get total missile count"""
	var count = 0

	if ship.has_method("get_secondary_ammo"):
		count = ship.get_secondary_ammo()
	elif "weapon_system" in ship:
		var ws = ship.weapon_system
		if ws and "secondary_ammo" in ws:
			count = ws.secondary_ammo

	return count


func _get_weapon_energy(ship: Node) -> float:
	"""Get weapon energy as percentage"""
	var energy = 1.0

	if ship.has_method("get_weapon_energy_percent"):
		energy = ship.get_weapon_energy_percent()
	elif "weapon_energy" in ship and "max_weapon_energy" in ship:
		if ship.max_weapon_energy > 0:
			energy = ship.weapon_energy / ship.max_weapon_energy

	return energy
