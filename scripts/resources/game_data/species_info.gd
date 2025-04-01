# scripts/resources/species_info.gd
# Defines species-specific properties.
# Corresponds to C++ 'species_info' struct and data from species_defs.tbl.
class_name SpeciesInfo
extends Resource

@export var species_name: String = "Terran" 		# $Species_Name:
@export var default_iff_name: String = "Friendly" 	# $Default IFF: (Store name, resolve to index/enum later)
@export var fred_color: Color = Color(0, 0, 0.75) 	# $FRED Color: (r, g, b)

@export_group("Visuals")
@export var debris_texture_path: String = "" 		# +Debris_Texture: (Path to Texture2D)
@export var shield_anim_path: String = "" 			# +Shield_Hit_ani: (Path to SpriteFrames resource)

# Thruster Flames (Paths to SpriteFrames resources)
@export_group("Thruster Flames")
@export var thrust_flame_normal_path: String = "" 	# +Normal: / +Pri_Normal:
@export var thrust_flame_ab_path: String = "" 		# +Afterburn: / +Pri_Afterburn:

# Thruster Glows (Paths to Texture2D resources)
@export_group("Thruster Glows")
@export var thrust_glow_normal_path: String = "" 	# +Normal:
@export var thrust_glow_ab_path: String = "" 		# +Afterburn:
@export var thrust_secondary_glow_normal_path: String = "" # +Sec_Normal:
@export var thrust_secondary_glow_ab_path: String = "" # +Sec_Afterburn:
@export var thrust_tertiary_glow_normal_path: String = "" # +Ter_Normal:
@export var thrust_tertiary_glow_ab_path: String = "" # +Ter_Afterburn:

# Gameplay Properties
@export_group("Gameplay")
@export var awacs_multiplier: float = 1.0 			# $AwacsMultiplier:

# TODO: Add properties for flyby sounds if needed (snd_flyby_fighter, snd_flyby_bomber)
# TODO: Add properties for briefing icons if species-specific icons are used

# --- Helper Methods (Optional) ---
# func get_debris_texture() -> Texture2D:
#	 return load(debris_texture_path) if not debris_texture_path.is_empty() else null

# func get_shield_anim() -> SpriteFrames:
#	 return load(shield_anim_path) if not shield_anim_path.is_empty() else null

# ... similar helpers for thruster anims/glows ...
