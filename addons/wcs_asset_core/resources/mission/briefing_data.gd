# addons/wcs_asset_core/resources/briefing_data.gd
# Holds data for one team's briefing, containing multiple stages.
class_name BriefingData
extends Resource

# --- Nested Resource Definition ---
const BriefingStageData = preload("briefing_stage_data.gd")

# --- Briefing Properties ---
@export var stages: Array[BriefingStageData] = []
