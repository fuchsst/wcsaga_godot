# IFF Interface for interacting with the IFF system
# Provides simplified access to common IFF queries

class_name IFFInterface
extends Node


# Check if two entities are enemies based on their IFFs
func are_enemies(iff1: String, iff2: String) -> bool:
	if iff1 == iff2:
		return false  # Same IFF teams are not enemies

	# Check if either IFF attacks the other
	return IFFManager.does_iff_attack(iff1, iff2) or IFFManager.does_iff_attack(iff2, iff1)


# Get the color to display for an IFF on the HUD
func get_hud_color(iff_name: String) -> Color:
	return IFFManager.get_iff_color(iff_name)


# Get how one IFF perceives another (for stealth/cloaking mechanics)
func get_perceived_color(viewer_iff: String, target_iff: String) -> Color:
	return IFFManager.get_iff_perception(viewer_iff, target_iff)
