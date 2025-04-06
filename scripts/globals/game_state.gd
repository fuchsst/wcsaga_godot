# scripts/globals/game_state.gd
# Singleton (Autoload) responsible for holding references to critical runtime state.
extends Node
class_name GameState

# Holds the reference to the currently controlled player ship node
var player_ship: ShipBase = null

# Holds the loaded player data resource (stats, kills, etc.)
var player_data: PlayerData = null

# TODO: Add methods to set/get these references safely
# Example:
# func set_player_ship(ship_node: ShipBase):
#     player_ship = ship_node
#
# func set_player_data(data: PlayerData):
#     player_data = data

func _ready():
	print("GameState Singleton Initialized.")
