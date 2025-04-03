# scripts/resources/mission/mission_cutscene_data.gd
# Defines the data structure for a cutscene entry in a mission file.
extends Resource
class_name MissionCutsceneData

# Corresponds to FS2 cutscene type (MOVIE_PRE_FICTION, etc.) - Use enum later
@export var cutscene_type: int = -1

# Corresponds to FS2 cutscene filename (e.g., "intro.mve")
@export var cutscene_name: String = ""

# Corresponds to FS2 +campaign_only flag
@export var is_campaign_only: bool = false

# Corresponds to FS2 +formula: SEXP
@export var formula: Resource # SexpNode
