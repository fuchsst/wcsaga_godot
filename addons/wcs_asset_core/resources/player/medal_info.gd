# addons/wcs_asset_core/resources/medal_info.gd
# Defines the structure for medal and badge information.
# Corresponds to C++ 'medal_stuff' struct and data from medals.tbl.
class_name MedalInfo
extends Resource

# --- Medal/Badge Properties ---
@export var medal_name: String = "" 		# $Name:
@export var bitmap_base_name: String = "" 	# $Bitmap: (Base name, e.g., "Medal01")
@export var num_versions: int = 1 			# $Num mods: (Number of medal variations, e.g., bronze, silver, gold)

# --- Badge Specific Properties (if applicable) ---
# Badges are medals awarded based on kill counts.
@export var kills_needed: int = 0 			# +Num Kills: (If > 0, this is a badge)
# badge_num is assigned dynamically during parsing/loading based on order in table.

# --- Promotion Text (if applicable) ---
# Some medals might grant promotions, though rank is usually separate.
# This field was present in the C++ struct, likely for flavor text.
@export var promotion_text: String = "" 	# $Promotion Text:

# --- Voice ---
# Base filename for voice lines associated with awarding this medal/badge.
@export var voice_base_name: String = "" 	# $Wavefile Base: (or $Wavefile 1/2)

# Note: The original C++ struct doesn't have much more than this.
# We might add helper functions later if needed, e.g., to get the correct
# bitmap filename based on the number of times awarded (num_versions).

func get_bitmap_filename(award_count: int = 1) -> String:
	# Helper to construct the actual bitmap filename based on award count
	if num_versions <= 1 or award_count <= 1:
		return bitmap_base_name
	else:
		# Clamp award_count to the number of versions available
		var version_index = clamp(award_count, 1, num_versions)
		# Construct filename like "Medal01a", "Medal01b", etc.
		# Assumes 'a' corresponds to the 2nd award (index 1), 'b' to 3rd (index 2)
		var suffix = char(ord('a') + version_index - 2)
		return "%s%s" % [bitmap_base_name, suffix]
