# addons/wcs_asset_core/resources/mission/mission_cutscene_data.gd
# Defines data for a cutscene associated with a mission event (briefing, debriefing, etc.)
class_name MissionCutsceneData
extends Resource

# --- Dependencies ---
const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")

# --- Cutscene Types (Mirroring MOVIE_*) ---
enum CutsceneType {
	PRE_FICTION = 0,
	PRE_CMD_BRIEF = 1,
	PRE_BRIEF = 2,
	PRE_GAME = 3,
	PRE_DEBRIEF = 4
}

# --- Properties ---
@export var type: CutsceneType = CutsceneType.PRE_GAME
@export var cutscene_filename: String = "" # Path to the video file (e.g., .ogv, .webm)
@export var is_campaign_only: bool = false
@export var formula_sexp: SexpExpression = null # SEXP node to determine if cutscene plays
