# addons/wcs_asset_core/resources/mission/weapon_loadout_choice.gd
# Defines a single weapon choice within the player start loadout pool.
class_name WeaponLoadoutChoice
extends Resource

## The name of the weapon class (e.g., "Subach HL-7"). Resolved at runtime.
@export var weapon_class_name: String = ""

## Optional SEXP variable name to check if this weapon class is available. Empty means always available.
@export var weapon_variable: String = ""

## The number/amount of this weapon available in the pool.
@export var count: int = 0

## Optional SEXP variable name to check for the count. Empty means use the static count.
@export var count_variable: String = ""
