# scripts/resources/briefing_icon_data.gd
# Defines an icon displayed in a briefing stage.
class_name BriefingIconData
extends Resource

@export var type: int = 0 # Enum: ICON_FIGHTER, ICON_WAYPOINT, etc. (See GlobalConstants.BriefingIconType)
@export var team: int = 0 # IFF team index
@export var ship_class_name: String = "" # Ship class name (if applicable), resolved at runtime
@export var position: Vector3 = Vector3.ZERO # Position on the briefing map
@export var label: String = "" # Text label displayed near the icon
#@export var closeup_label: String = "" # Text label for the closeup view (Seems unused in FS2 format?)
@export var id: int = -1 # Unique ID for tracking icon movement between stages
@export var flags: int = 0 # Bitmask: BI_HIGHLIGHT, BI_MIRROR_ICON, etc. (See GlobalConstants.BriefingIconFlags)

# --- Runtime Data (Set during briefing) ---
# var x: int = 0 # Screen X coordinate
# var y: int = 0 # Screen Y coordinate
# var w: int = 0 # Screen width
# var h: int = 0 # Screen height
# var highlight_anim: HUDAnim = null # Instance of highlight animation
# var fadein_anim: HUDAnim = null # Instance of fade-in animation
