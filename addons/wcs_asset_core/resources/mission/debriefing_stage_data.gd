# addons/wcs_asset_core/resources/debriefing_stage_data.gd
# Defines a single stage within a mission debriefing.
class_name DebriefingStageData
extends Resource

# --- Nested Resource Definitions ---
const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd") # Assuming SexpExpression exists

# --- Stage Properties ---
@export var formula_sexp: SexpExpression = null # SEXP condition for this stage to be shown
@export var text: String = "" # Multi-line text for this stage
@export var voice_path: String = "" # Path to the voice audio file
@export var recommendation_text: String = "" # Recommendation text shown in this stage
