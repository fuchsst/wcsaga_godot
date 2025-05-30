# addons/wcs_asset_core/resources/debriefing_data.gd
# Holds data for one team's debriefing, containing multiple stages.
class_name DebriefingData
extends Resource

# --- Nested Resource Definition ---
const DebriefingStageData = preload("debriefing_stage_data.gd")

# --- Debriefing Properties ---
@export var stages: Array[DebriefingStageData] = []
