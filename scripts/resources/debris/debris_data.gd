# DebrisData - Debris Configuration Resource
# Holds configuration for debris spawned from destroyed objects
# Based on legacy debris struct from debris.h

class_name DebrisData
extends Resource


## Debug/Editor Settings
@export_group("Identity")
@export var debris_name: String = "" ## Identifier for this debris type
@export var source_ship_class: String = "" ## Ship class this debris came from


## Lifespan Configuration
@export_group("Lifespan")
@export var min_lifetime: float = -1.0 ## Minimum seconds before death (-1 = use defaults)
@export var max_lifetime: float = -1.0 ## Maximum seconds before death (-1 = use defaults)
@export var min_hitpoints: float = -1.0 ## Minimum hull strength (-1 = use defaults)
@export var max_hitpoints: float = -1.0 ## Maximum hull strength (-1 = use defaults)


## Physics Configuration
@export_group("Physics")
@export var rotvel_scale: float = 5.0 ## Multiplier for rotational velocity
@export var explosion_force: float = 1.0 ## Force multiplier for radial velocity
@export var max_speed_small: float = 200.0 ## Max velocity for small debris
@export var max_speed_large: float = 150.0 ## Max velocity for large hull debris
@export var max_speed_capital: float = 100.0 ## Max velocity for capital ship debris


## Visual Effects
@export_group("Effects")
@export var arc_percent: float = 0.5 ## Probability of electric arcs (0.0-1.0)
@export var arc_frequency_base: int = 1000 ## Base milliseconds between arc triggers
@export var damage_mult: float = 1.0 ## Damage multiplier for collision damage


## Source Information (runtime)
var source_species: int = -1 ## Species index for texture swapping
var source_team: int = 0 ## Team index for IFF


# ==============================================================================
# HELPER METHODS
# ==============================================================================


## Get random lifetime within configured bounds
func get_random_lifetime(is_hull: bool) -> float:
	if min_lifetime >= 0.0 and max_lifetime >= 0.0:
		return randf_range(min_lifetime, max_lifetime)
	
	# Default behavior from legacy code
	if is_hull:
		# 1/6 chance to blow up quickly, otherwise persist
		if randf() < 0.166:
			return randf_range(0.5, 2.5)
		else:
			return -1.0 # Persist forever
	else:
		# Small debris: 0.1 to 2.1 seconds
		return randf_range(0.1, 2.1)


## Get random hitpoints within configured bounds
func get_random_hitpoints(source_hull_strength: float) -> float:
	if min_hitpoints >= 0.0 and max_hitpoints >= 0.0:
		return randf_range(min_hitpoints, max_hitpoints)
	
	# Default: 1/8 of source ship's hull
	return source_hull_strength / 8.0


## Get max speed based on debris size category
func get_max_speed(is_hull: bool, is_capital: bool) -> float:
	if is_capital:
		return max_speed_capital
	elif is_hull:
		return max_speed_large
	else:
		return max_speed_small


## Check if this debris should have electric arcs
func should_have_arcs() -> bool:
	return randf() < arc_percent


func get_resource_type() -> String:
	return "debris_data"
