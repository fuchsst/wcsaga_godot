# Ship resource loader for Godot
# This script loads ship data resources and provides access to ship definitions

class_name ShipLoader
extends Node

# Dictionary to store loaded ship resources
var ships: Dictionary = {}

# Preload the ship data script
const ShipDataScript = preload("res://features/ships/ship_data.gd")

func _ready():
	# Initialize the ship loader
	load_all_ships()

func load_all_ships():
	"""
	Load all ship resources from the ships directory
	"""
	# In a real implementation, you would load all .tres files from the ships directory
	# For now, we'll just set up the dictionary structure
	pass

func get_ship(ship_name: String) -> ShipData:
	"""
	Get a ship resource by name
	"""
	if ships.has(ship_name):
		return ships[ship_name]
	else:
		# Try to load the ship resource if not already loaded
		var ship_path = "res://features/ships/%s.tres" % ship_name
		if ResourceLoader.exists(ship_path):
			var ship = ResourceLoader.load(ship_path)
			ships[ship_name] = ship
			return ship
		else:
			push_warning("Ship resource not found: %s" % ship_name)
			return null

func get_all_ships() -> Array:
	"""
	Get an array of all loaded ship resources
	"""
	return ships.values()

func get_ships_by_type(ship_type: String) -> Array:
	"""
	Get an array of ships filtered by type (e.g., "Light Fighter", "Heavy Fighter", "Corvette", etc.)
	"""
	var filtered_ships = []
	for ship in ships.values():
		if ship.ship_type == ship_type:
			filtered_ships.append(ship)
	return filtered_ships

func get_player_ships() -> Array:
	"""
	Get an array of ships that are allowed for player use
	"""
	var player_ships = []
	for ship in ships.values():
		if ship.is_player_ship:
			player_ships.append(ship)
	return player_ships

func get_fighter_ships() -> Array:
	"""
	Get an array of fighter ships
	"""
	var fighter_ships = []
	for ship in ships.values():
		if ship.is_fighter:
			fighter_ships.append(ship)
	return fighter_ships

func get_capital_ships() -> Array:
	"""
	Get an array of capital ships
	"""
	var capital_ships = []
	for ship in ships.values():
		if ship.is_capital:
			capital_ships.append(ship)
	return capital_ships

func get_ships_by_species(species: String) -> Array:
	"""
	Get an array of ships filtered by species (e.g., "Terran", "Kilrathi")
	"""
	var filtered_ships = []
	for ship in ships.values():
		if ship.species == species:
			filtered_ships.append(ship)
	return filtered_ships