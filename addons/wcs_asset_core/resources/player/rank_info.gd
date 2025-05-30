# addons/wcs_asset_core/resources/rank_info.gd
# Defines the structure for rank information.
# Corresponds to C++ 'rank_stuff' struct and data from rank.tbl.
class_name RankInfo
extends Resource

@export var rank_name: String = "Ensign" # $Name
@export var points_required: int = 0    # $Points
@export var rank_bitmap_path: String = "" # $Bitmap (Path to texture)
@export var promotion_voice_base: String = "" # $Promotion Voice Base (Base filename for voice)
@export var promotion_text: String = "" # $Promotion Text (Multi-line text)

# Note: The original C++ struct doesn't have much more than this.
# We might add helper functions later if needed.
