# scripts/resources/mission/ship_loadout_choice.gd
# Defines a single ship choice within the player start loadout.
class_name ShipLoadoutChoice
extends Resource

## The name of the ship class (e.g., "Hercules"). Resolved at runtime.
@export var ship_class_name: String = ""

## Optional SEXP variable name to check if this ship class is available. Empty means always available.
@export var ship_variable: String = ""

## The number of this ship class available.
@export var count: int = 0

## Optional SEXP variable name to check for the count. Empty means use the static count.
@export var count_variable: String = ""
