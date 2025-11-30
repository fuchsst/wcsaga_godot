# SpeciesData - Simplified for Wing Commander Saga
# Represents species/faction data from Species_defs.tbl

class_name SpeciesData
extends Resource

# Identity
@export var species_name: String = ""
@export var default_iff: String = ""
@export var fred_color: Color = Color(0, 0, 0)

# Thruster Animations
@export_group("Thruster Animations")
@export var thruster_normal: SpriteFrames
@export var thruster_afterburn: SpriteFrames
@export var thruster_secondary_normal: SpriteFrames
@export var thruster_secondary_afterburn: SpriteFrames
@export var thruster_tertiary_normal: SpriteFrames
@export var thruster_tertiary_afterburn: SpriteFrames

# Thruster Glows
@export_group("Thruster Glows")
@export var glow_normal: Texture2D
@export var glow_afterburn: Texture2D

# Miscellaneous Animations
@export_group("Misc Animations")
@export var debris_texture: Texture2D
@export var shield_hit_anim: SpriteFrames

# Sensors
@export var awacs_multiplier: float = 1.0
