class_name ShipData
extends BaseAssetData

## Ship data resource for the WCS Asset Core addon.
## Comprehensive ship specifications extracted from the existing WCS codebase.
## Contains all properties needed to define a ship class in the WCS-Godot conversion.

# Asset type setup
func _init() -> void:
	asset_type = AssetTypes.Type.SHIP

## General Information
@export var ship_name: String = "" # ship_info.name
@export var alt_name: String = "" # ship_info.alt_name
@export var short_name: String = "" # ship_info.short_name
@export var species: int = 0 # ship_info.species (Index into SpeciesInfo array/resource)
@export var class_type: int = -1 # ship_info.class_type (Index into ShipTypeInfo array/resource)
@export var manufacturer: String = "" # ship_info.manufacturer_str
@export var ship_description: String = "" # ship_info.desc
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

## Thruster Properties
@export var thruster_bitmap: String = "" # ship_info.thruster_flame_info.flame.filename
@export var thruster_glow_bitmap: String = "" # ship_info.thruster_glow_info.flame.filename
@export var thruster_secondary_glow_bitmap: String = "" # ship_info.thruster_secondary_glow_info.bitmap.filename
@export var thruster_tertiary_glow_bitmap: String = "" # ship_info.thruster_tertiary_glow_info.bitmap.filename
@export var thruster01_glow_rad_factor: float = 1.0 # ship_info.thruster01_glow_rad_factor
@export var thruster02_glow_rad_factor: float = 1.0 # ship_info.thruster02_glow_rad_factor
@export var thruster03_glow_rad_factor: float = 1.0 # ship_info.thruster03_glow_rad_factor
@export var thruster02_glow_len_factor: float = 1.0 # ship_info.thruster02_glow_len_factor

## Afterburner Effects
@export var afterburner_trail_bitmap: String = "" # ship_info.afterburner_trail.filename
@export var afterburner_trail_width_factor: float = 1.0 # ship_info.afterburner_trail_width_factor
@export var afterburner_trail_alpha_factor: float = 1.0 # ship_info.afterburner_trail_alpha_factor
@export var afterburner_trail_life: float = 1.0 # ship_info.afterburner_trail_life
@export var afterburner_trail_faded_out_sections: int = 0 # ship_info.afterburner_trail_faded_out_sections

## Visual Properties
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

## Advanced Movement
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

## Weapons Configuration
@export var num_primary_banks: int = 0 # ship_info.num_primary_banks
@export var num_secondary_banks: int = 0 # ship_info.num_secondary_banks
@export var primary_bank_weapons: Array[String] = [] # Weapon resource paths instead of indices
@export var primary_bank_ammo_capacity: Array[int] = [] # ship_info.primary_bank_ammo_capacity
@export var secondary_bank_weapons: Array[String] = [] # Weapon resource paths instead of indices
@export var secondary_bank_ammo_capacity: Array[int] = [] # ship_info.secondary_bank_ammo_capacity
@export var allowed_weapons: Array[String] = [] # Allowed weapon resource paths
@export var restricted_loadout_flag: Array[bool] = [] # ship_info.restricted_loadout_flag

## Weapon Configuration
@export var aiming_flags: int = 0 # ship_info.aiming_flags (AIM_FLAG_*)
@export var minimum_convergence_distance: float = 0.0 # ship_info.minimum_convergence_distance
@export var convergence_distance: float = 500.0 # ship_info.convergence_distance
@export var convergence_offset: Vector3 = Vector3.ZERO # ship_info.convergence_offset
@export var autoaim_fov: float = 0.0 # ship_info.autoaim_fov

## Countermeasures
@export var cmeasure_type: String = "" # Countermeasure weapon resource path
@export var cmeasure_max: int = 0 # ship_info.cmeasure_max

## Subsystems (Resource paths to SubsystemDefinition resources)
@export var subsystems: Array[String] = [] # Paths to subsystem definition resources

## AI Properties
@export var ai_class: int = 0 # ship_info.ai_class (Index into AIProfile array/resource)

## Sound Configuration
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

## Debris Properties
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
@export var num_debris_objects: int = 0 # polymodel.num_debris_objects
@export var debris_objects: Array[String] = [] # Paths to debris ship resources

## Ship Flags (SIF_*, SIF2_*)
@export var flags: int = 0 # ship_info.flags
@export var flags2: int = 0 # ship_info.flags2

## Miscellaneous Properties
@export var score: int = 0 # ship_info.score
@export var scan_time: int = 0 # ship_info.scan_time
@export var damage_lightning_type: int = 0 # ship_info.damage_lightning_type (SLT_*)

## Complex Structure Arrays (stored as Dictionaries for now)
@export var contrails: Array[Dictionary] = [] # ship_info.ct_info
@export var maneuvering_thrusters: Array[Dictionary] = [] # ship_info.maneuvering
@export var iff_colors: Dictionary = {} # ship_info.ship_iff_info

## Override validation to include ship-specific checks
func get_validation_errors() -> Array[String]:
	"""Get validation errors specific to ship data.
	Returns:
		Array of validation error messages"""
	
	var errors: Array[String] = super.get_validation_errors()
	
	# Ship-specific validation
	if ship_name.is_empty():
		errors.append("Ship name is required")
	
	if mass <= 0.0:
		errors.append("Ship mass must be positive")
	
	if max_hull_strength <= 0.0:
		errors.append("Hull strength must be positive")
	
	if max_vel.length() <= 0.0:
		errors.append("Maximum velocity must be positive")
	
	# Weapon bank validation
	if num_primary_banks > 0 and primary_bank_weapons.size() != num_primary_banks:
		errors.append("Primary weapon bank count mismatch")
	
	if num_secondary_banks > 0 and secondary_bank_weapons.size() != num_secondary_banks:
		errors.append("Secondary weapon bank count mismatch")
	
	# Capacity validation
	if primary_bank_ammo_capacity.size() != num_primary_banks:
		errors.append("Primary ammo capacity array size mismatch")
	
	if secondary_bank_ammo_capacity.size() != num_secondary_banks:
		errors.append("Secondary ammo capacity array size mismatch")
	
	return errors

## Ship-specific utility functions

func get_max_speed() -> float:
	"""Get the maximum forward speed of the ship.
	Returns:
		Maximum forward velocity"""
	
	return max_vel.z  # Assuming Z is forward

func get_afterburner_speed() -> float:
	"""Get the maximum afterburner speed.
	Returns:
		Maximum afterburner velocity"""
	
	return afterburner_max_vel.z

func has_afterburner() -> bool:
	"""Check if ship has afterburner capability.
	Returns:
		true if ship can use afterburner"""
	
	return afterburner_fuel_capacity > 0.0 and afterburner_burn_rate > 0.0

func get_total_weapon_banks() -> int:
	"""Get total number of weapon banks.
	Returns:
		Sum of primary and secondary banks"""
	
	return num_primary_banks + num_secondary_banks

func has_countermeasures() -> bool:
	"""Check if ship can carry countermeasures.
	Returns:
		true if ship has countermeasure capability"""
	
	return not cmeasure_type.is_empty() and cmeasure_max > 0

func get_power_efficiency() -> float:
	"""Calculate power efficiency based on mass and power output.
	Returns:
		Power-to-mass ratio"""
	
	if mass <= 0.0:
		return 0.0
	
	return power_output / mass

func get_maneuverability_rating() -> float:
	"""Calculate basic maneuverability rating.
	Returns:
		Maneuverability score (higher is more maneuverable)"""
	
	if mass <= 0.0:
		return 0.0
	
	# Simple formula: rotational velocity / mass
	var avg_rotvel: float = (max_rotvel.x + max_rotvel.y + max_rotvel.z) / 3.0
	return avg_rotvel / mass

func get_combat_rating() -> float:
	"""Calculate basic combat effectiveness rating.
	Returns:
		Combat effectiveness score"""
	
	var rating: float = 0.0
	
	# Factor in hull and shield strength
	rating += max_hull_strength * 0.3
	rating += max_shield_strength * 0.4
	
	# Factor in weapon capacity
	rating += get_total_weapon_banks() * 50.0
	
	# Factor in speed and agility
	rating += get_max_speed() * 0.5
	rating += get_maneuverability_rating() * 100.0
	
	return rating

## Enhanced memory size calculation
func get_memory_size() -> int:
	"""Calculate estimated memory usage for this ship data.
	Returns:
		Estimated memory size in bytes"""
	
	var size: int = super.get_memory_size()
	
	# Add ship-specific data sizes
	size += ship_name.length() + alt_name.length() + short_name.length()
	size += manufacturer.length() + ship_description.length() + tech_description.length()
	size += pof_file.length() + icon_filename.length() + anim_filename.length()
	
	# Arrays
	size += detail_distances.size() * 4  # int array
	size += primary_bank_weapons.size() * 50  # estimate for resource paths
	size += secondary_bank_weapons.size() * 50
	size += allowed_weapons.size() * 50
	size += subsystems.size() * 50
	
	# Complex structures (rough estimate)
	size += contrails.size() * 200
	size += maneuvering_thrusters.size() * 200
	size += iff_colors.size() * 100
	
	return size

## Conversion utilities for migration from existing ship data

func convert_from_legacy_ship_data(legacy_data: Resource) -> void:
	"""Convert from existing ShipData resource format.
	Args:
		legacy_data: Existing ShipData resource to convert"""
	
	if not legacy_data:
		return
	
	# Copy common properties that exist in both formats
	# This would be expanded based on the exact legacy format
	if legacy_data.has_method("get") or "ship_name" in legacy_data:
		ship_name = legacy_data.get("ship_name") or ""
		alt_name = legacy_data.get("alt_name") or ""
		mass = legacy_data.get("mass") or 100.0
		max_hull_strength = legacy_data.get("max_hull_strength") or 100.0
		# ... more conversion logic
	
	# Mark as converted and track source
	source_file = "legacy_ship_data"
	conversion_notes = "Converted from existing ShipData resource"

func to_dictionary() -> Dictionary:
	"""Convert ship data to dictionary representation.
	Returns:
		Complete dictionary representation of ship data"""
	
	var dict: Dictionary = super.to_dictionary()
	
	# Add ship-specific fields
	dict["ship_name"] = ship_name
	dict["alt_name"] = alt_name
	dict["short_name"] = short_name
	dict["species"] = species
	dict["class_type"] = class_type
	dict["manufacturer"] = manufacturer
	dict["ship_description"] = ship_description
	dict["mass"] = mass
	dict["max_hull_strength"] = max_hull_strength
	dict["max_shield_strength"] = max_shield_strength
	dict["max_vel"] = var_to_str(max_vel)
	dict["primary_bank_weapons"] = primary_bank_weapons
	dict["secondary_bank_weapons"] = secondary_bank_weapons
	dict["flags"] = flags
	# Add other critical fields as needed
	
	return dict
