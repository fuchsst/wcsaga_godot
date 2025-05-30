# addons/wcs_asset_core/resources/briefing_stage_data.gd
# Defines a single stage within a mission briefing.
class_name BriefingStageData
extends Resource

# --- Nested Resource Definitions ---
# Ensure these paths are correct relative to this script's location
const BriefingIconData = preload("briefing_icon_data.gd")
const BriefingLineData = preload("briefing_line_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd") # Assuming SexpNode exists

# --- Stage Properties ---
@export var text: String = "" # Multi-line text for this stage
@export var voice_path: String = "" # Path to the voice audio file
@export var camera_pos: Vector3 = Vector3.ZERO
@export var camera_orient: Basis = Basis.IDENTITY
@export var camera_time_ms: int = 0 # Time in milliseconds for camera transition
@export var flags: int = 0 # Bitmask for stage flags (e.g., BS_FORWARD_CUT)
@export var formula_sexp: SexpNode = null # SEXP condition for this stage to be active/visible

@export var icons: Array[BriefingIconData] = [] # Icons displayed in this stage
@export var lines: Array[BriefingLineData] = [] # Lines connecting icons in this stage
