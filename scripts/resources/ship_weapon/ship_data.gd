# scripts/resources/ship_data.gd
extends Resource
class_name ShipData

## General Information
@export var ship_name: String = "" # ship_info.name
@export var alt_name: String = "" # ship_info.alt_name
@export var short_name: String = "" # ship_info.short_name
@export var species: int = 0 # ship_info.species (Index into SpeciesInfo array/resource)
@export var class_type: int = -1 # ship_info.class_type (Index into ShipTypeInfo array/resource)
@export var manufacturer: String = "" # ship_info.manufacturer_str
@export var description: String = "" # ship_info.desc
@export var tech_description: String = "" # ship_info.tech_desc
@export var ship_length: String = "" # ship_info.ship_length

## Models and Visuals
@export var pof_file: String = "" # ship_info.pof_file
@export var pof_file_hud: String = "" # ship_info.pof_file_hud
@export var cockpit_pof_file: String = "" # ship_info.cockpit_pof_file
@export var cockpit_offset: Vector3 = Vector3.ZERO # ship_info.cockpit_offset
@export var detail_distances: Array[int] = [] # ship_info.detail_distance (up to MAX_SHIP_DETAIL_LEVELS)
@export var hud_target_lod: int = 0 # ship_info.hud_target_lod
@export var icon_filename: String = "" # ship_info.icon_filename
@export var anim_filename: String = "" # ship_info.anim_filename
@export var overhead_filename: String = "" # ship_info.overhead_filename
@export var thruster_bitmap: String = "" # ship_info.thruster_flame_info.flame.filename
@export var thruster_glow_bitmap: String = "" # ship_info.thruster_glow_info.flame.filename
@export var thruster_secondary_glow_bitmap: String = "" # ship_info.thruster_secondary_glow_info.bitmap.filename
@export var thruster_tertiary_glow_bitmap: String = "" # ship_info.thruster_tertiary_glow_info.bitmap.filename
@export var thruster01_glow_rad_factor: float = 1.0 # ship_info.thruster01_glow_rad_factor
@export var thruster02_glow_rad_factor: float = 1.0 # ship_info.thruster02_glow_rad_factor
@export var thruster03_glow_rad_factor: float = 1.0 # ship_info.thruster03_glow_rad_factor
@export var thruster02_glow_len_factor: float = 1.0 # ship_info.thruster02_glow_len_factor
@export var afterburner_trail_bitmap: String = "" # ship_info.afterburner_trail.filename
@export var afterburner_trail_width_factor: float = 1.0 # ship_info.afterburner_trail_width_factor
@export var afterburner_trail_alpha_factor: float = 1.0 # ship_info.afterburner_trail_alpha_factor
@export var afterburner_trail_life: float = 1.0 # ship_info.afterburner_trail_life
@export var afterburner_trail_faded_out_sections: int = 0 # ship_info.afterburner_trail_faded_out_sections
@export var shield_color: Color = Color(1.0, 1.0, 1.0) # ship_info.shield_color
@export var shield_icon_index: int = 0 # ship_info.shield_icon_index
@export var radar_image_2d_idx: int = -1 # ship_info.radar_image_2d_idx
@export var radar_image_size: int = 0 # ship_info.radar_image_size
@export var radar_projection_size_mult: float = 1.0 # ship_info.radar_projection_size_mult
@export var topdown_offset: Vector3 = Vector3.ZERO # ship_info.topdown_offset
@export var topdown_offset_def: bool = false # ship_info.topdown_offset_def
@export var closeup_pos: Vector3 = Vector3.ZERO # ship_info.closeup_pos
@export var closeup_zoom: float = 1.0 # ship_info.closeup_zoom
@export var splodeing_texture_name: String = "" # ship_info.splodeing_texture_name
@export var max_decals: int = 0 # ship_info.max_decals
@export var draw_primary_models: Array[bool] = [] # ship_info.draw_primary_models
@export var draw_secondary_models: Array[bool] = [] # ship_info.draw_secondary_models
@export var draw_models: bool = true # ship_info.draw_models
@export var weapon_model_draw_distance: float = 1000.0 # ship_info.weapon_model_draw_distance

## Physics Properties
@export var density: float = 1.0 # ship_info.density
@export var mass: float = 100.0 # Calculated from density and volume, or explicit if needed
@export var damp: float = 0.1 # ship_info.damp
@export var rotdamp: float = 0.1 # ship_info.rotdamp
@export var delta_bank_const: float = 1.0 # ship_info.delta_bank_const
@export var max_vel: Vector3 = Vector3(100, 100, 100) # ship_info.max_vel
@export var afterburner_max_vel: Vector3 = Vector3(200, 200, 200) # ship_info.afterburner_max_vel
@export var max_rotvel: Vector3 = Vector3(1, 1, 1) # ship_info.max_rotvel
@export var rotation_time: Vector3 = Vector3(1, 1, 1) # ship_info.rotation_time
@export var srotation_time: float = 1.0 # ship_info.srotation_time
@export var max_rear_vel: float = 50.0 # ship_info.max_rear_vel
@export var forward_accel: float = 50.0 # ship_info.forward_accel
@export var afterburner_forward_accel: float = 100.0 # ship_info.afterburner_forward_accel
@export var forward_decel: float = 25.0 # ship_info.forward_decel
@export var slide_accel: float = 30.0 # ship_info.slide_accel
@export var slide_decel: float = 15.0 # ship_info.slide_decel
@export var can_glide: bool = false # ship_info.can_glide
@export var glide_cap: float = 0.0 # ship_info.glide_cap
@export var glide_dynamic_cap: bool = false # ship_info.glide_dynamic_cap
@export var glide_accel_mult: float = 1.0 # ship_info.glide_accel_mult
@export var use_newtonian_damp: bool = false # ship_info.use_newtonian_damp
@export var newtonian_damp_override: bool = false # ship_info.newtonian_damp_override

## Afterburner Properties
@export var afterburner_fuel_capacity: float = 100.0 # ship_info.afterburner_fuel_capacity
@export var afterburner_burn_rate: float = 10.0 # ship_info.afterburner_burn_rate
@export var afterburner_recover_rate: float = 5.0 # ship_info.afterburner_recover_rate
@export var afterburner_max_reverse_vel: float = 0.0 # ship_info.afterburner_max_reverse_vel
@export var afterburner_reverse_accel: float = 0.0 # ship_info.afterburner_reverse_accel

## Hull, Shields, Armor, Energy
@export var max_hull_strength: float = 100.0 # ship_info.max_hull_strength
@export var max_shield_strength: float = 100.0 # ship_info.max_shield_strength (Total across quadrants)
@export var hull_repair_rate: float = 0.0 # ship_info.hull_repair_rate
@export var subsys_repair_rate: float = 0.0 # ship_info.subsys_repair_rate
@export var sup_hull_repair_rate: float = 0.0 # ship_info.sup_hull_repair_rate
@export var sup_shield_repair_rate: float = 0.0 # ship_info.sup_shield_repair_rate
@export var sup_subsys_repair_rate: float = 0.0 # ship_info.sup_subsys_repair_rate
@export var power_output: float = 100.0 # ship_info.power_output
@export var max_overclocked_speed: float = 0.0 # ship_info.max_overclocked_speed
@export var max_weapon_reserve: float = 100.0 # ship_info.max_weapon_reserve
@export var max_shield_regen_per_second: float = 10.0 # ship_info.max_shield_regen_per_second
@export var max_weapon_regen_per_second: float = 10.0 # ship_info.max_weapon_regen_per_second
@export var armor_type_idx: int = -1 # ship_info.armor_type_idx (Index into ArmorData array/resource)
@export var shield_armor_type_idx: int = -1 # ship_info.shield_armor_type_idx (Index into ArmorData array/resource)
@export var collision_damage_type_idx: int = -1 # ship_info.collision_damage_type_idx (Index into DamageType array/resource)
@export var emp_resistance_mod: float = 0.0 # ship_info.emp_resistance_mod
@export var piercing_damage_draw_limit: float = 0.0 # ship_info.piercing_damage_draw_limit

## Weapons
@export var num_primary_banks: int = 0 # ship_info.num_primary_banks
@export var num_secondary_banks: int = 0 # ship_info.num_secondary_banks
@export var primary_bank_weapons: Array[int] = [] # ship_info.primary_bank_weapons (Indices into WeaponData)
@export var primary_bank_ammo_capacity: Array[int] = [] # ship_info.primary_bank_ammo_capacity
@export var secondary_bank_weapons: Array[int] = [] # ship_info.secondary_bank_weapons (Indices into WeaponData)
@export var secondary_bank_ammo_capacity: Array[int] = [] # ship_info.secondary_bank_ammo_capacity
@export var allowed_weapons: Array[int] = [] # ship_info.allowed_weapons (Indices into WeaponData)
@export var restricted_loadout_flag: Array[bool] = [] # ship_info.restricted_loadout_flag (Indexed by weapon index)
# allowed_bank_restricted_weapons needs careful mapping, maybe a Dictionary? { bank_index: [allowed_weapon_indices] }
@export var aiming_flags: int = 0 # ship_info.aiming_flags (AIM_FLAG_*)
@export var minimum_convergence_distance: float = 0.0 # ship_info.minimum_convergence_distance
@export var convergence_distance: float = 500.0 # ship_info.convergence_distance
@export var convergence_offset: Vector3 = Vector3.ZERO # ship_info.convergence_offset
@export var autoaim_fov: float = 0.0 # ship_info.autoaim_fov

## Countermeasures
@export var cmeasure_type: int = -1 # ship_info.cmeasure_type (Index into WeaponData)
@export var cmeasure_max: int = 0 # ship_info.cmeasure_max

## Subsystems (Definitions - Runtime state is in ShipSubsystem node)
# This should likely be an array of custom SubsystemDefinition resources
@export var subsystems: Array = [] # ship_info.subsystems (Array of SubsystemDefinition resources)

## AI Properties
@export var ai_class: int = 0 # ship_info.ai_class (Index into AIProfile array/resource)

## Sounds
@export var engine_snd: int = -1 # ship_info.engine_snd (Index into GameSounds resource)
@export var warpin_snd_start: int = -1 # ship_info.warpin_snd_start
@export var warpin_snd_end: int = -1 # ship_info.warpin_snd_end
@export var warpout_snd_start: int = -1 # ship_info.warpout_snd_start
@export var warpout_snd_end: int = -1 # ship_info.warpout_snd_end

## Warp Properties
@export var warpin_anim: String = "" # ship_info.warpin_anim
@export var warpin_radius: float = 0.0 # ship_info.warpin_radius
@export var warpin_speed: float = 0.0 # ship_info.warpin_speed
@export var warpin_time: int = 0 # ship_info.warpin_time
@export var warpin_type: int = 0 # ship_info.warpin_type (WT_*)
@export var warpout_anim: String = "" # ship_info.warpout_anim
@export var warpout_radius: float = 0.0 # ship_info.warpout_radius
@export var warpout_speed: float = 0.0 # ship_info.warpout_speed
@export var warpout_time: int = 0 # ship_info.warpout_time
@export var warpout_type: int = 0 # ship_info.warpout_type (WT_*)
@export var warpout_player_speed: float = 0.0 # ship_info.warpout_player_speed

## Destruction Properties
@export var shockwave: Dictionary = {} # ship_info.shockwave (Map to ShockwaveCreateInfo properties)
@export var explosion_propagates: bool = false # ship_info.explosion_propagates
@export var death_roll_time: int = 3000 # ship_info.death_roll_time (Milliseconds, use -1 for default calculation)
@export var big_exp_visual_rad: float = 0.0 # ship_info.big_exp_visual_rad
@export var shockwave_count: int = 0 # ship_info.shockwave_count
@export var explosion_bitmap_anims: Array[String] = [] # ship_info.explosion_bitmap_anims (Paths to animations)
@export var vaporize_chance: float = 0.0 # ship_info.vaporize_chance (Probability 0.0 to 1.0)
@export var ispew_max_particles: int = 0 # ship_info.ispew_max_particles
@export var dspew_max_particles: int = 0 # ship_info.dspew_max_particles
@export var debris_min_lifetime: float = 0.0 # ship_info.debris_min_lifetime
@export var debris_max_lifetime: float = 0.0 # ship_info.debris_max_lifetime
@export var debris_min_speed: float = 0.0 # ship_info.debris_min_speed
@export var debris_max_speed: float = 0.0 # ship_info.debris_max_speed
@export var debris_min_rotspeed: float = 0.0 # ship_info.debris_min_rotspeed
@export var debris_max_rotspeed: float = 0.0 # ship_info.debris_max_rotspeed
@export var debris_damage_type_idx: int = -1 # ship_info.debris_damage_type_idx
@export var debris_min_hitpoints: float = 0.0 # ship_info.debris_min_hitpoints
@export var debris_max_hitpoints: float = 0.0 # ship_info.debris_max_hitpoints
@export var debris_damage_mult: float = 1.0 # ship_info.debris_damage_mult
@export var debris_arc_percent: float = 0.0 # ship_info.debris_arc_percent

## Flags (SIF_*, SIF2_*) - Use individual booleans or a bitmask integer
@export var flags: int = 0 # ship_info.flags
@export var flags2: int = 0 # ship_info.flags2

## Miscellaneous
@export var score: int = 0 # ship_info.score
@export var scan_time: int = 0 # ship_info.scan_time
@export var damage_lightning_type: int = 0 # ship_info.damage_lightning_type (SLT_*)

# Contrails - Array of Dictionaries or custom TrailDefinition resources
@export var contrails: Array = [] # ship_info.ct_info

# Maneuvering Thrusters - Array of Dictionaries or custom ThrusterDefinition resources
@export var maneuvering_thrusters: Array = [] # ship_info.maneuvering

# IFF Colors - Dictionary { team_a: { team_b: Color } }
@export var iff_colors: Dictionary = {} # ship_info.ship_iff_info

# TODO: Add definitions for nested structures like thruster_particles, thrust_pair, etc.
# These might become separate Resource types or Dictionaries within ShipData.
# Example for a subsystem definition (could be its own Resource type):
# @export var subsystem_definitions: Array[SubsystemDefinition]
