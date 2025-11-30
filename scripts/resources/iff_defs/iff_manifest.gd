class_name IFFManifest
extends Resource

# Global IFF Settings
@export_group("Global Settings")
@export var traitor_iff_name: String = "Traitor"
@export var selection_color: Color = Color.WHITE
@export var message_color: Color = Color(0.5, 0.5, 0.5)
@export var tagged_color: Color = Color.YELLOW

# Radar Settings
@export_group("Radar Settings")
@export var dimmed_iff_brightness: int = 4
@export var use_alternate_blip_coloring: bool = false

# Radar Blip Colors
@export_group("Radar Blip Colors")
@export var missile_blip_color: Color = Color.WHITE
@export var navbuoy_blip_color: Color = Color.WHITE
@export var warping_blip_color: Color = Color.WHITE
@export var node_blip_color: Color = Color.WHITE
@export var tagged_blip_color: Color = Color.YELLOW

# Radar Target ID Flags
@export_group("Radar Flags")
@export var radar_crosshairs: bool = true
@export var radar_blink: bool = false
@export var radar_pulsate: bool = false
@export var radar_enlarge: bool = false

# IFF Definitions
@export_group("IFF Definitions")
@export var iffs: Array[Resource] = [] # Array of IFFResource
