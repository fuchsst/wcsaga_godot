extends Resource
class_name PlayerData

## Player ship selection and weaponry loadout configuration

@export var starting_ship: String = "" # Starting ship name (e.g., "Alpha 1")
@export var default_ship: String = "" # Default ship selection
@export var ship_choices: Array[ShipChoice] = [] # Available ship selections
@export var weaponry_pool: Array[WeaponryPoolItem] = [] # Available weapons
