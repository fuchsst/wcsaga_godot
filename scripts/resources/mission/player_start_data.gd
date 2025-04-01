# scripts/resources/player_start_data.gd
# Defines starting ship choices and weapon pools for a specific team in a mission.
class_name PlayerStartData
extends Resource

# Ship choices: Array of ShipData resource indices or names
@export var ship_choices: Array[int] = [] # Indices referencing ShipData array in GlobalConstants or similar
@export var ship_choice_variables: Array[int] = [] # SEXP variable indices for ship choices
@export var ship_counts: Array[int] = [] # Number of each ship available
@export var ship_count_variables: Array[int] = [] # SEXP variable indices for ship counts
@export var default_ship_index: int = -1 # Index into ship_choices array for default selection

# Weapon pool: Array of WeaponData resource indices or names
@export var weapon_pool: Array[int] = [] # Indices referencing WeaponData array
@export var weapon_pool_variables: Array[int] = [] # SEXP variable indices for weapon pool
@export var weapon_counts: Array[int] = [] # Number of each weapon available
@export var weapon_count_variables: Array[int] = [] # SEXP variable indices for weapon counts
