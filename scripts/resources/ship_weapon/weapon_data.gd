# scripts/resources/weapon_data.gd
extends Resource
class_name WeaponData

## General Information
@export var weapon_name: String = "" # weapon_info.name
@export var alt_name: String = "" # weapon_info.alt_name
@export var title: String = "" # weapon_info.title
@export var description: String = "" # weapon_info.desc
@export var tech_title: String = "" # weapon_info.tech_title
@export var tech_description: String = "" # weapon_info.tech_desc
@export var tech_anim_filename: String = "" # weapon_info.tech_anim_filename
@export var tech_model: String = "" # weapon_info.tech_model
@export var hud_filename: String = "" # weapon_info.hud_filename
@export var icon_filename: String = "" # weapon_info.icon_filename
@export var anim_filename: String = "" # weapon_info.anim_filename

## Type and Rendering
@export var subtype: int = GlobalConstants.WP_LASER # weapon_info.subtype (WP_*)
@export var render_type: int = GlobalConstants.WRT_NONE # weapon_info.render_type (WRT_*)

## Model and Visuals (POF/Laser)
@export var pof_file: String = "" # weapon_info.pofbitmap_name (if WRT_POF) - Path to the original POF model file for the projectile itself (if any)
@export var projectile_scene_path: String = "" # Path to the Godot scene (.tscn) to instantiate when firing
@export var hud_target_lod: int = 0 # weapon_info.hud_target_lod
@export var laser_bitmap: String = "" # weapon_info.laser_bitmap.filename (if WRT_LASER)
@export var laser_glow_bitmap: String = "" # weapon_info.laser_glow_bitmap.filename (if WRT_LASER)
@export var laser_color_1: Color = Color(1,1,1) # weapon_info.laser_color_1
@export var laser_color_2: Color = Color(0,0,0) # weapon_info.laser_color_2
@export var laser_length: float = 10.0 # weapon_info.laser_length
@export var laser_head_radius: float = 1.0 # weapon_info.laser_head_radius
@export var laser_tail_radius: float = 1.0 # weapon_info.laser_tail_radius
@export var external_model_name: String = "" # weapon_info.external_model_name
@export var weapon_submodel_rotate_accell: float = 10.0 # weapon_info.weapon_submodel_rotate_accell
@export var weapon_submodel_rotate_vel: float = 0.0 # weapon_info.weapon_submodel_rotate_vel

## Physics and Movement
@export var mass: float = 1.0 # weapon_info.mass
@export var max_speed: float = 100.0 # weapon_info.max_speed
@export var lifetime: float = 5.0 # weapon_info.lifetime
@export var life_min: float = -1.0 # weapon_info.life_min (Use -1 if lifetime is static)
@export var life_max: float = -1.0 # weapon_info.life_max (Use -1 if lifetime is static)
@export var weapon_range: float = 5000.0 # weapon_info.weapon_range
@export var weapon_min_range: float = 0.0 # weapon_info.WeaponMinRange

## Firing Properties
@export var fire_wait: float = 0.25 # weapon_info.fire_wait
@export var energy_consumed: float = 0.0 # weapon_info.energy_consumed
@export var rearm_rate: float = 1.0 # weapon_info.rearm_rate (Seconds per unit, convert from 1/rate)
@export var shots: int = 1 # weapon_info.shots
@export var burst_shots: int = 0 # weapon_info.burst_shots
@export var burst_delay: float = 0.1 # weapon_info.burst_delay (Seconds)
@export var burst_flags: int = 0 # weapon_info.burst_flags (WBF_*)

## Damage Properties
@export var damage: float = 10.0 # weapon_info.damage
@export var damage_type_idx: int = -1 # weapon_info.damage_type_idx (Index into DamageType array/resource)
@export var armor_factor: float = 1.0 # weapon_info.armor_factor
@export var shield_factor: float = 1.0 # weapon_info.shield_factor
@export var subsystem_factor: float = 1.0 # weapon_info.subsystem_factor

## Missile/Bomb Properties
@export var arm_time: float = 0.0 # weapon_info.arm_time (Seconds, convert from fix)
@export var arm_dist: float = 0.0 # weapon_info.arm_dist
@export var arm_radius: float = 0.0 # weapon_info.arm_radius
@export var det_range: float = 0.0 # weapon_info.det_range
@export var det_radius: float = 0.0 # weapon_info.det_radius
@export var weapon_hitpoints: int = 0 # weapon_info.weapon_hitpoints

## Homing Properties (if WIF_HOMING)
@export var homing_type: int = GlobalConstants.WIF_HOMING_NONE # WIF_HOMING_HEAT, WIF_HOMING_ASPECT, WIF_HOMING_JAVELIN
@export var free_flight_time: float = 0.25 # weapon_info.free_flight_time
@export var turn_time: float = 1.0 # weapon_info.turn_time
@export var fov: float = 0.5 # weapon_info.fov (Cosine of half-angle)
@export var min_lock_time: float = 0.0 # weapon_info.min_lock_time
@export var lock_pixels_per_sec: int = 50 # weapon_info.lock_pixels_per_sec
@export var catchup_pixels_per_sec: int = 50 # weapon_info.catchup_pixels_per_sec
@export var catchup_pixel_penalty: int = 50 # weapon_info.catchup_pixel_penalty
@export var seeker_strength: float = 1.0 # weapon_info.seeker_strength
@export var target_lead_scaler: float = 0.0 # weapon_info.target_lead_scaler (0.0 for heat, 1.0 for aspect default)

## Swarm Properties (if WIF_SWARM)
@export var swarm_count: int = 4 # weapon_info.swarm_count
@export var swarm_wait: int = 150 # weapon_info.SwarmWait (Milliseconds)

## Corkscrew Properties (if WIF_CORKSCREW)
@export var cs_num_fired: int = 4 # weapon_info.cs_num_fired
@export var cs_radius: float = 1.25 # weapon_info.cs_radius
@export var cs_delay: int = 30 # weapon_info.cs_delay (Milliseconds)
@export var cs_crotate: bool = true # weapon_info.cs_crotate
@export var cs_twist: float = 5.0 # weapon_info.cs_twist

## EMP Properties (if WIF_EMP)
@export var emp_intensity: float = GlobalConstants.EMP_DEFAULT_INTENSITY # weapon_info.emp_intensity
@export var emp_time: float = GlobalConstants.EMP_DEFAULT_TIME # weapon_info.emp_time

## Energy Suck Properties (if WIF_ENERGY_SUCK)
@export var weapon_reduce: float = GlobalConstants.ESUCK_DEFAULT_WEAPON_REDUCE # weapon_info.weapon_reduce
@export var afterburner_reduce: float = GlobalConstants.ESUCK_DEFAULT_AFTERBURNER_REDUCE # weapon_info.afterburner_reduce

## Electronics Properties (if WIF_ELECTRONICS)
@export var elec_time: int = 8000 # weapon_info.elec_time (Milliseconds)
@export var elec_eng_mult: float = 1.0 # weapon_info.elec_eng_mult
@export var elec_weap_mult: float = 1.0 # weapon_info.elec_weap_mult
@export var elec_beam_mult: float = 1.0 # weapon_info.elec_beam_mult
@export var elec_sensors_mult: float = 1.0 # weapon_info.elec_sensors_mult
@export var elec_randomness: int = 2000 # weapon_info.elec_randomness (Milliseconds)
@export var elec_use_new_style: bool = false # weapon_info.elec_use_new_style

## Local SSM Properties (if WIF2_LOCAL_SSM)
@export var lssm_warpout_delay: int = 0 # weapon_info.lssm_warpout_delay (Milliseconds)
@export var lssm_warpin_delay: int = 0 # weapon_info.lssm_warpin_delay (Milliseconds)
@export var lssm_stage5_vel: float = 0.0 # weapon_info.lssm_stage5_vel
@export var lssm_warpin_radius: float = 0.0 # weapon_info.lssm_warpin_radius
@export var lssm_lock_range: float = 1000000.0 # weapon_info.lssm_lock_range

## Countermeasure Properties (if WIF_CMEASURE)
@export var cm_aspect_effectiveness: float = 1.0 # weapon_info.cm_aspect_effectiveness
@export var cm_heat_effectiveness: float = 1.0 # weapon_info.cm_heat_effectiveness
@export var cm_effective_rad: float = GlobalConstants.MAX_CMEASURE_TRACK_DIST # weapon_info.cm_effective_rad

## Tag Properties (if WIF_TAG)
@export var tag_level: int = -1 # weapon_info.tag_level
@export var tag_time: float = -1.0 # weapon_info.tag_time
@export var ssm_index: int = -1 # weapon_info.SSM_index

## Spawn Properties (if WIF_SPAWN)
# Array of Dictionaries: [{ "type": weapon_index, "count": int, "angle": float_degrees }]
@export var spawn_info: Array = [] # weapon_info.spawn_info

## Effects
@export var launch_snd: int = -1 # weapon_info.launch_snd (Index into GameSounds resource)
@export var impact_snd: int = -1 # weapon_info.impact_snd
@export var disarmed_impact_snd: int = -1 # weapon_info.disarmed_impact_snd
@export var flyby_snd: int = -1 # weapon_info.flyby_snd
@export var impact_explosion_radius: float = 1.0 # weapon_info.impact_explosion_radius
@export var impact_weapon_expl_index: int = -1 # weapon_info.impact_weapon_expl_index (Index into WeaponExplosions resource/array)
@export var dinky_impact_explosion_radius: float = 1.0 # weapon_info.dinky_impact_explosion_radius
@export var dinky_impact_weapon_expl_index: int = -1 # weapon_info.dinky_impact_weapon_expl_index
@export var flash_impact_weapon_expl_index: int = -1 # weapon_info.flash_impact_weapon_expl_index
@export var flash_impact_explosion_radius: float = 0.0 # weapon_info.flash_impact_explosion_radius
@export var piercing_impact_explosion_radius: float = 0.0 # weapon_info.piercing_impact_explosion_radius
@export var piercing_impact_particle_count: int = 0 # weapon_info.piercing_impact_particle_count
@export var piercing_impact_particle_life: float = 0.0 # weapon_info.piercing_impact_particle_life
@export var piercing_impact_particle_velocity: float = 0.0 # weapon_info.piercing_impact_particle_velocity
@export var piercing_impact_weapon_expl_index: int = -1 # weapon_info.piercing_impact_weapon_expl_index
@export var piercing_impact_particle_back_velocity: float = 0.0 # weapon_info.piercing_impact_particle_back_velocity
@export var piercing_impact_particle_variance: float = 0.0 # weapon_info.piercing_impact_particle_variance
@export var muzzle_flash_index: int = -1 # weapon_info.muzzle_flash (Index into MuzzleFlashInfo array/resource)
@export var shockwave: Dictionary = {} # weapon_info.shockwave (Map to ShockwaveCreateInfo properties)
@export var dinky_shockwave: Dictionary = {} # weapon_info.dinky_shockwave (Map to ShockwaveCreateInfo properties)
@export var decal_texture: String = "" # weapon_info.decal_texture.filename
@export var decal_glow_texture: String = "" # weapon_info.decal_glow_texture_id (derived name)
@export var decal_burn_texture: String = "" # weapon_info.decal_burn_texture_id (derived name)
@export var decal_backface_texture: String = "" # weapon_info.decal_backface_texture.filename
@export var decal_rad: float = -1.0 # weapon_info.decal_rad
@export var decal_burn_time: int = 1000 # weapon_info.decal_burn_time (Milliseconds)
@export var thruster_flame_anim: String = "" # weapon_info.thruster_flame.filename
@export var thruster_glow_anim: String = "" # weapon_info.thruster_glow.filename
@export var thruster_glow_factor: float = 1.0 # weapon_info.thruster_glow_factor

## Trail Properties (if WIF_TRAIL)
@export var trail_info: Dictionary = { # weapon_info.tr_info
	"w_start": 1.0,
	"w_end": 1.0,
	"a_start": 1.0,
	"a_end": 1.0,
	"max_life": 1.0,
	"stamp": 0,
	"texture": "", # Path to texture
	"n_fade_out_sections": 0
}

## Particle Spew Properties (if WIF_PARTICLE_SPEW)
@export var particle_spew_count: int = 1 # weapon_info.particle_spew_count
@export var particle_spew_time: int = 25 # weapon_info.particle_spew_time (Milliseconds)
@export var particle_spew_vel: float = 0.4 # weapon_info.particle_spew_vel
@export var particle_spew_radius: float = 2.0 # weapon_info.particle_spew_radius
@export var particle_spew_lifetime: float = 0.15 # weapon_info.particle_spew_lifetime
@export var particle_spew_scale: float = 0.8 # weapon_info.particle_spew_scale
@export var particle_spew_anim: String = "" # weapon_info.particle_spew_anim.filename

## Beam Properties (if WIF_BEAM)
@export var beam_info: Dictionary = { # weapon_info.b_info
	"type": -1, # BEAM_TYPE_*
	"life": -1.0,
	"warmup": -1, # Milliseconds
	"warmdown": -1, # Milliseconds
	"muzzle_radius": 0.0,
	"particle_count": -1,
	"particle_radius": 0.0,
	"particle_angle": 0.0,
	"particle_ani": "", # Path to animation
	"loop_sound": -1, # Index into GameSounds
	"warmup_sound": -1,
	"warmdown_sound": -1,
	"num_sections": 0,
	"glow_anim": "", # Path to animation
	"shots": 1,
	"shrink_factor": 0.0,
	"shrink_pct": 0.0,
	"range": GlobalConstants.BEAM_FAR_LENGTH,
	"damage_threshold": 1.0, # Attenuation start percentage
	"width": -1.0, # Override calculated width
	"miss_factor": [0.0, 0.0, 0.0, 0.0, 0.0], # Per skill level
	"sections": [] # Array of section dictionaries
}
# Example Beam Section Dictionary:
# {
#   "width": 1.0,
#   "rgba_inner": [0,0,0,0], # Color array
#   "rgba_outer": [255,255,255,255],
#   "flicker": 0.1,
#   "z_add": 0.0,
#   "tile_factor": 1.0,
#   "tile_type": 0,
#   "translation": 0.0,
#   "texture": "" # Path to texture/animation
# }

## Flags (WIF_*, WIF2_*) - Use individual booleans or a bitmask integer
@export var flags: int = 0 # weapon_info.wi_flags
@export var flags2: int = 0 # weapon_info.wi_flags2

## Miscellaneous
@export var cargo_size: float = 1.0 # weapon_info.cargo_size
@export var field_of_fire: float = 0.0 # weapon_info.field_of_fire (Degrees)
@export var alpha_max: float = 1.0 # weapon_info.alpha_max (if WIF2_TRANSPARENT)
@export var alpha_min: float = 0.0 # weapon_info.alpha_min
@export var alpha_cycle: float = 0.0 # weapon_info.alpha_cycle
@export var targeting_priorities: Array[int] = [] # weapon_info.targeting_priorities
