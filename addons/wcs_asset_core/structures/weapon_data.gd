class_name WeaponData
extends BaseAssetData

## Weapon data resource for the WCS Asset Core addon.
## Comprehensive weapon specifications extracted from the existing WCS codebase.
## Contains all properties needed to define a weapon in the WCS-Godot conversion.

# Asset type setup
func _init() -> void:
	asset_type = AssetTypes.Type.WEAPON

## General Information
@export var weapon_name: String = "" # weapon_info.name
@export var alt_name: String = "" # weapon_info.alt_name
@export var title: String = "" # weapon_info.title
@export var weapon_description: String = "" # weapon_info.desc
@export var tech_title: String = "" # weapon_info.tech_title
@export var tech_description: String = "" # weapon_info.tech_desc
@export var tech_anim_filename: String = "" # weapon_info.tech_anim_filename
@export var tech_model: String = "" # weapon_info.tech_model
@export var hud_filename: String = "" # weapon_info.hud_filename
@export var icon_filename: String = "" # weapon_info.icon_filename
@export var anim_filename: String = "" # weapon_info.anim_filename

## Type and Rendering
@export var subtype: int = 0 # weapon_info.subtype (WP_*)
@export var render_type: int = 0 # weapon_info.render_type (WRT_*)

## Model and Visuals (POF/Laser)
@export var pof_file: String = "" # weapon_info.pofbitmap_name (if WRT_POF)
@export var projectile_scene_path: String = "" # Path to the Godot scene (.tscn) to instantiate when firing
@export var hud_target_lod: int = 0 # weapon_info.hud_target_lod

## Laser Properties (if WRT_LASER)
@export var laser_bitmap: String = "" # weapon_info.laser_bitmap.filename
@export var laser_glow_bitmap: String = "" # weapon_info.laser_glow_bitmap.filename
@export var laser_color_1: Color = Color(1,1,1) # weapon_info.laser_color_1
@export var laser_color_2: Color = Color(0,0,0) # weapon_info.laser_color_2
@export var laser_length: float = 10.0 # weapon_info.laser_length
@export var laser_head_radius: float = 1.0 # weapon_info.laser_head_radius
@export var laser_tail_radius: float = 1.0 # weapon_info.laser_tail_radius

## External Model Properties
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
@export var rearm_rate: float = 1.0 # weapon_info.rearm_rate (Seconds per unit)
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
@export var arm_time: float = 0.0 # weapon_info.arm_time (Seconds)
@export var arm_dist: float = 0.0 # weapon_info.arm_dist
@export var arm_radius: float = 0.0 # weapon_info.arm_radius
@export var det_range: float = 0.0 # weapon_info.det_range
@export var det_radius: float = 0.0 # weapon_info.det_radius
@export var weapon_hitpoints: int = 0 # weapon_info.weapon_hitpoints

## Homing Properties (if WIF_HOMING)
@export var homing_type: int = 0 # WIF_HOMING_HEAT, WIF_HOMING_ASPECT, WIF_HOMING_JAVELIN
@export var free_flight_time: float = 0.25 # weapon_info.free_flight_time
@export var turn_time: float = 1.0 # weapon_info.turn_time
@export var fov: float = 0.5 # weapon_info.fov (Cosine of half-angle)
@export var min_lock_time: float = 0.0 # weapon_info.min_lock_time
@export var lock_pixels_per_sec: int = 50 # weapon_info.lock_pixels_per_sec
@export var catchup_pixels_per_sec: int = 50 # weapon_info.catchup_pixels_per_sec
@export var catchup_pixel_penalty: int = 50 # weapon_info.catchup_pixel_penalty
@export var seeker_strength: float = 1.0 # weapon_info.seeker_strength
@export var target_lead_scaler: float = 0.0 # weapon_info.target_lead_scaler

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
@export var emp_intensity: float = 1.0 # weapon_info.emp_intensity
@export var emp_time: float = 2.0 # weapon_info.emp_time

## Energy Suck Properties (if WIF_ENERGY_SUCK)
@export var weapon_reduce: float = 0.25 # weapon_info.weapon_reduce
@export var afterburner_reduce: float = 0.25 # weapon_info.afterburner_reduce

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
@export var cm_effective_rad: float = 500.0 # weapon_info.cm_effective_rad

## Tag Properties (if WIF_TAG)
@export var tag_level: int = -1 # weapon_info.tag_level
@export var tag_time: float = -1.0 # weapon_info.tag_time
@export var ssm_index: int = -1 # weapon_info.SSM_index

## Spawn Properties (if WIF_SPAWN)
@export var spawn_info: Array[Dictionary] = [] # weapon_info.spawn_info

## Sound Effects
@export var launch_snd: int = -1 # weapon_info.launch_snd (Index into GameSounds resource)
@export var impact_snd: int = -1 # weapon_info.impact_snd
@export var disarmed_impact_snd: int = -1 # weapon_info.disarmed_impact_snd
@export var flyby_snd: int = -1 # weapon_info.flyby_snd

## Impact and Explosion Effects
@export var impact_explosion_radius: float = 1.0 # weapon_info.impact_explosion_radius
@export var impact_weapon_expl_index: int = -1 # weapon_info.impact_weapon_expl_index
@export var dinky_impact_explosion_radius: float = 1.0 # weapon_info.dinky_impact_explosion_radius
@export var dinky_impact_weapon_expl_index: int = -1 # weapon_info.dinky_impact_weapon_expl_index
@export var flash_impact_weapon_expl_index: int = -1 # weapon_info.flash_impact_weapon_expl_index
@export var flash_impact_explosion_radius: float = 0.0 # weapon_info.flash_impact_explosion_radius

## Piercing Impact Properties
@export var piercing_impact_explosion_radius: float = 0.0 # weapon_info.piercing_impact_explosion_radius
@export var piercing_impact_particle_count: int = 0 # weapon_info.piercing_impact_particle_count
@export var piercing_impact_particle_life: float = 0.0 # weapon_info.piercing_impact_particle_life
@export var piercing_impact_particle_velocity: float = 0.0 # weapon_info.piercing_impact_particle_velocity
@export var piercing_impact_weapon_expl_index: int = -1 # weapon_info.piercing_impact_weapon_expl_index
@export var piercing_impact_particle_back_velocity: float = 0.0 # weapon_info.piercing_impact_particle_back_velocity
@export var piercing_impact_particle_variance: float = 0.0 # weapon_info.piercing_impact_particle_variance

## Visual Effects
@export var muzzle_flash_index: int = -1 # weapon_info.muzzle_flash
@export var shockwave: Dictionary = {} # weapon_info.shockwave
@export var dinky_shockwave: Dictionary = {} # weapon_info.dinky_shockwave

## Decal Properties
@export var decal_texture: String = "" # weapon_info.decal_texture.filename
@export var decal_glow_texture: String = "" # weapon_info.decal_glow_texture_id
@export var decal_burn_texture: String = "" # weapon_info.decal_burn_texture_id
@export var decal_backface_texture: String = "" # weapon_info.decal_backface_texture.filename
@export var decal_rad: float = -1.0 # weapon_info.decal_rad
@export var decal_burn_time: int = 1000 # weapon_info.decal_burn_time (Milliseconds)

## Thruster Properties
@export var thruster_flame_anim: String = "" # weapon_info.thruster_flame.filename
@export var thruster_glow_anim: String = "" # weapon_info.thruster_glow.filename
@export var thruster_glow_factor: float = 1.0 # weapon_info.thruster_glow_factor

## Trail Properties (if WIF_TRAIL)
@export var trail_info: Dictionary = {
	"w_start": 1.0,
	"w_end": 1.0,
	"a_start": 1.0,
	"a_end": 1.0,
	"max_life": 1.0,
	"stamp": 0,
	"texture": "",
	"n_fade_out_sections": 0
} # weapon_info.tr_info

## Particle Spew Properties (if WIF_PARTICLE_SPEW)
@export var particle_spew_count: int = 1 # weapon_info.particle_spew_count
@export var particle_spew_time: int = 25 # weapon_info.particle_spew_time (Milliseconds)
@export var particle_spew_vel: float = 0.4 # weapon_info.particle_spew_vel
@export var particle_spew_radius: float = 2.0 # weapon_info.particle_spew_radius
@export var particle_spew_lifetime: float = 0.15 # weapon_info.particle_spew_lifetime
@export var particle_spew_scale: float = 0.8 # weapon_info.particle_spew_scale
@export var particle_spew_anim: String = "" # weapon_info.particle_spew_anim.filename

## Beam Properties (if WIF_BEAM)
@export var beam_info: Dictionary = {
	"type": -1,
	"life": -1.0,
	"warmup": -1,
	"warmdown": -1,
	"muzzle_radius": 0.0,
	"particle_count": -1,
	"particle_radius": 0.0,
	"particle_angle": 0.0,
	"particle_ani": "",
	"loop_sound": -1,
	"warmup_sound": -1,
	"warmdown_sound": -1,
	"num_sections": 0,
	"glow_anim": "",
	"shots": 1,
	"shrink_factor": 0.0,
	"shrink_pct": 0.0,
	"range": 10000.0,
	"damage_threshold": 1.0,
	"width": -1.0,
	"miss_factor": [0.0, 0.0, 0.0, 0.0, 0.0],
	"sections": []
} # weapon_info.b_info

## Weapon Flags (WIF_*, WIF2_*)
@export var flags: int = 0 # weapon_info.wi_flags
@export var flags2: int = 0 # weapon_info.wi_flags2

## Miscellaneous Properties
@export var cargo_size: float = 1.0 # weapon_info.cargo_size
@export var field_of_fire: float = 0.0 # weapon_info.field_of_fire (Degrees)
@export var alpha_max: float = 1.0 # weapon_info.alpha_max (if WIF2_TRANSPARENT)
@export var alpha_min: float = 0.0 # weapon_info.alpha_min
@export var alpha_cycle: float = 0.0 # weapon_info.alpha_cycle
@export var targeting_priorities: Array[int] = [] # weapon_info.targeting_priorities

## Override validation to include weapon-specific checks
func get_validation_errors() -> Array[String]:
	"""Get validation errors specific to weapon data.
	Returns:
		Array of validation error messages"""
	
	var errors: Array[String] = super.get_validation_errors()
	
	# Weapon-specific validation
	if weapon_name.is_empty():
		errors.append("Weapon name is required")
	
	if damage < 0.0:
		errors.append("Weapon damage cannot be negative")
	
	if max_speed <= 0.0:
		errors.append("Weapon speed must be positive")
	
	if lifetime <= 0.0:
		errors.append("Weapon lifetime must be positive")
	
	if fire_wait < 0.0:
		errors.append("Fire wait time cannot be negative")
	
	# Range validation
	if weapon_range <= 0.0:
		errors.append("Weapon range must be positive")
	
	if weapon_min_range < 0.0:
		errors.append("Minimum range cannot be negative")
	
	if weapon_min_range >= weapon_range:
		errors.append("Minimum range must be less than maximum range")
	
	# Homing weapon validation
	if is_homing_weapon():
		if turn_time <= 0.0:
			errors.append("Homing weapon turn time must be positive")
		
		if fov <= 0.0 or fov > 1.0:
			errors.append("Homing weapon FOV must be between 0 and 1")
	
	# Beam weapon validation
	if is_beam_weapon():
		if beam_info.has("life") and beam_info["life"] <= 0.0:
			errors.append("Beam weapon life must be positive")
	
	return errors

## Weapon-specific utility functions

func is_primary_weapon() -> bool:
	"""Check if this is a primary weapon.
	Returns:
		true if weapon is a primary weapon type"""
	
	# This would use weapon subtype flags to determine primary vs secondary
	# For now, simple check based on energy consumption
	return energy_consumed > 0.0

func is_secondary_weapon() -> bool:
	"""Check if this is a secondary weapon (missile/bomb).
	Returns:
		true if weapon is a secondary weapon type"""
	
	return not is_primary_weapon()

func is_homing_weapon() -> bool:
	"""Check if this weapon has homing capability.
	Returns:
		true if weapon can home on targets"""
	
	return homing_type > 0

func is_beam_weapon() -> bool:
	"""Check if this is a beam weapon.
	Returns:
		true if weapon is a beam type"""
	
	return beam_info.has("type") and beam_info["type"] >= 0

func is_countermeasure() -> bool:
	"""Check if this weapon is a countermeasure.
	Returns:
		true if weapon is a countermeasure"""
	
	return cm_aspect_effectiveness > 0.0 or cm_heat_effectiveness > 0.0

func get_dps() -> float:
	"""Calculate damage per second.
	Returns:
		Damage per second rating"""
	
	if fire_wait <= 0.0:
		return 0.0
	
	var shots_per_second: float = 1.0 / fire_wait
	return damage * shots_per_second * shots

func get_range_effectiveness() -> float:
	"""Calculate range effectiveness based on speed and lifetime.
	Returns:
		Effective range in distance units"""
	
	return max_speed * lifetime

func get_tracking_ability() -> float:
	"""Calculate tracking ability for homing weapons.
	Returns:
		Tracking ability score (0-1, higher is better)"""
	
	if not is_homing_weapon():
		return 0.0
	
	# Simple formula based on turn rate and FOV
	if turn_time <= 0.0:
		return 0.0
	
	var turn_rate: float = 1.0 / turn_time
	return min(1.0, (turn_rate * fov * seeker_strength))

func get_cargo_space_required() -> int:
	"""Get cargo space required for this weapon.
	Returns:
		Cargo space units required"""
	
	return int(cargo_size)

func can_target_type(target_type: int) -> bool:
	"""Check if weapon can target a specific type.
	Args:
		target_type: Target type to check
	Returns:
		true if weapon can target this type"""
	
	if targeting_priorities.is_empty():
		return true  # Can target anything if no restrictions
	
	return targeting_priorities.has(target_type)

func get_effectiveness_vs_armor(armor_factor_override: float = -1.0) -> float:
	"""Get effectiveness against armor.
	Args:
		armor_factor_override: Optional armor factor override
	Returns:
		Damage multiplier against armor (1.0 = normal, 2.0 = double damage)"""
	
	if armor_factor_override >= 0.0:
		return armor_factor_override
	
	return armor_factor

func get_effectiveness_vs_shields(shield_factor_override: float = -1.0) -> float:
	"""Get effectiveness against shields.
	Args:
		shield_factor_override: Optional shield factor override
	Returns:
		Damage multiplier against shields"""
	
	if shield_factor_override >= 0.0:
		return shield_factor_override
	
	return shield_factor

## Enhanced memory size calculation
func get_memory_size() -> int:
	"""Calculate estimated memory usage for this weapon data.
	Returns:
		Estimated memory size in bytes"""
	
	var size: int = super.get_memory_size()
	
	# Add weapon-specific data sizes
	size += weapon_name.length() + alt_name.length() + title.length()
	size += weapon_description.length() + tech_title.length() + tech_description.length()
	size += pof_file.length() + projectile_scene_path.length()
	size += laser_bitmap.length() + laser_glow_bitmap.length()
	
	# Complex structures
	size += spawn_info.size() * 100  # rough estimate for spawn info
	size += trail_info.size() * 20   # dictionary overhead
	size += beam_info.size() * 20    # dictionary overhead
	size += targeting_priorities.size() * 4  # int array
	
	return size

## Conversion utilities

func convert_from_legacy_weapon_data(legacy_data: Resource) -> void:
	"""Convert from existing WeaponData resource format.
	Args:
		legacy_data: Existing WeaponData resource to convert"""
	
	if not legacy_data:
		return
	
	# Copy common properties that exist in both formats
	if legacy_data.has_method("get") or "weapon_name" in legacy_data:
		weapon_name = legacy_data.get("weapon_name", "")
		alt_name = legacy_data.get("alt_name", "")
		damage = legacy_data.get("damage", 10.0)
		max_speed = legacy_data.get("max_speed", 100.0)
		lifetime = legacy_data.get("lifetime", 5.0)
		fire_wait = legacy_data.get("fire_wait", 0.25)
		# ... more conversion logic
	
	# Mark as converted
	source_file = "legacy_weapon_data"
	conversion_notes = "Converted from existing WeaponData resource"

func to_dictionary() -> Dictionary:
	"""Convert weapon data to dictionary representation.
	Returns:
		Complete dictionary representation of weapon data"""
	
	var dict: Dictionary = super.to_dictionary()
	
	# Add weapon-specific fields
	dict["weapon_name"] = weapon_name
	dict["alt_name"] = alt_name
	dict["subtype"] = subtype
	dict["render_type"] = render_type
	dict["damage"] = damage
	dict["max_speed"] = max_speed
	dict["lifetime"] = lifetime
	dict["fire_wait"] = fire_wait
	dict["energy_consumed"] = energy_consumed
	dict["weapon_range"] = weapon_range
	dict["homing_type"] = homing_type
	dict["flags"] = flags
	dict["flags2"] = flags2
	# Add other critical fields as needed
	
	return dict