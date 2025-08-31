# Weapon resource loader for Godot
# This script loads weapon data resources and provides access to weapon definitions

class_name WeaponLoader
extends Node

# Dictionary to store loaded weapon resources
var weapons: Dictionary = {}

# Preload the weapon data script
const WeaponDataScript = preload("res://features/weapons/weapon_data.gd")

func _ready():
	# Initialize the weapon loader
	load_all_weapons()

func load_all_weapons():
	"""
	Load all weapon resources from the weapons directory
	"""
	# In a real implementation, you would load all .tres files from the weapons directory
	# For now, we'll just set up the dictionary structure
	pass

func get_weapon(weapon_name: String) -> WeaponData:
	"""
	Get a weapon resource by name
	"""
	if weapons.has(weapon_name):
		return weapons[weapon_name]
	else:
		# Try to load the weapon resource if not already loaded
		var weapon_path = "res://features/weapons/%s.tres" % weapon_name
		if ResourceLoader.exists(weapon_path):
			var weapon = ResourceLoader.load(weapon_path)
			weapons[weapon_name] = weapon
			return weapon
		else:
			push_warning("Weapon resource not found: %s" % weapon_name)
			return null

func get_all_weapons() -> Array:
	"""
	Get an array of all loaded weapon resources
	"""
	return weapons.values()

func get_weapons_by_type(weapon_type: WeaponData.WeaponType) -> Array:
	"""
	Get an array of weapons filtered by type
	"""
	var filtered_weapons = []
	for weapon in weapons.values():
		if weapon.weapon_type == weapon_type:
			filtered_weapons.append(weapon)
	return filtered_weapons

func get_player_allowed_weapons() -> Array:
	"""
	Get an array of weapons that are allowed for player use
	"""
	var player_weapons = []
	for weapon in weapons.values():
		if weapon.player_allowed:
			player_weapons.append(weapon)
	return player_weapons