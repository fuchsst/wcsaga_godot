# Base ship entity script with IFF integration
# Demonstrates how ships use the IFF system

class_name Ship
extends Node3D

# The IFF team this ship belongs to
@export var iff_team: String = "Friendly"


# Get this ship's IFF color for HUD display
func get_iff_color() -> Color:
	return IFFManager.get_iff_color(iff_team)


# Check if this ship considers another ship an enemy
func is_enemy(other_ship: Ship) -> bool:
	return IFFInterface.are_enemies(iff_team, other_ship.iff_team)


# Get how this ship perceives another ship (for stealth/cloaking)
func get_perceived_color_of(other_ship: Ship) -> Color:
	return IFFInterface.get_perceived_color(iff_team, other_ship.iff_team)
