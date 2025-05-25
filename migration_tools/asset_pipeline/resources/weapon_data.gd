class_name WeaponData
extends Resource

## WCS Weapon data resource containing all properties from weapons.tbl
## Represents a weapon system with damage, projectile, and behavior data

@export var weapon_name: String = ""
@export var title: String = ""
@export var desc: String = ""
@export var tech_title: String = ""
@export var tech_anim: String = ""
@export var tech_desc: String = ""

# Basic weapon properties
@export var subtype: String = "Primary"  # Primary, Secondary
@export var model_file: String = ""
@export var mass: float = 1.0
@export var velocity: float = 100.0
@export var fire_wait: float = 1.0  # Seconds between shots
@export var damage: float = 10.0
@export var damage_type: String = "energy"  # energy, kinetic, heat, etc.

# Projectile behavior
@export var lifetime: float = 5.0
@export var energy_consumed: float = 1.0
@export var cargo_size: float = 1.0
@export var homing_type: String = "none"  # none, heat, aspect, javelin
@export var turn_rate: float = 0.0  # For homing weapons
@export var lock_time: float = 0.0  # Time to achieve lock

# Damage and effects
@export var damage_time: float = 0.0  # Duration of damage effect
@export var blast_radius: float = 0.0
@export var inner_radius: float = 0.0
@export var outer_radius: float = 0.0
@export var shockwave_speed: float = 0.0
@export var armor_factor: float = 1.0
@export var shield_factor: float = 1.0
@export var subsystem_factor: float = 1.0

# Visual and audio
@export var muzzle_flash: String = ""
@export var impact_effect: String = ""
@export var dinky_impact_effect: String = ""
@export var flash_radius: float = 10.0
@export var flash_color: Color = Color.WHITE

# Sounds
@export var launch_sound: String = ""
@export var impact_sound: String = ""
@export var disarmed_impact_sound: String = ""
@export var flyby_sound: String = ""

# Targeting and tracking
@export var target_lead_scaler: float = 1.0
@export var target_restrict: String = "none"  # ships, missiles, debris, etc.
@export var max_lock_range: float = 1000.0
@export var min_lock_range: float = 50.0
@export var lock_pixels_per_sec: int = 50

# Special weapon flags
@export var spawn_children: bool = false
@export var child_weapon: String = ""
@export var spawn_count: int = 1
@export var pierce_shields: bool = false
@export var no_dumbfire: bool = false
@export var in_tech_database: bool = true
@export var player_allowed: bool = true

# Ballistic properties (for projectile weapons)
@export var ballistic: bool = false
@export var pierce_armor: bool = false
@export var no_pierce_shields: bool = false
@export var local_ssm: bool = false
@export var tagged_only: bool = false

# Secondary weapon specific
@export var dual_fire: bool = false
@export var swarm_count: int = 1
@export var swarm_wait: float = 0.1

# EMP and special damage
@export var emp_intensity: float = 0.0
@export var emp_time: float = 0.0
@export var rearm_rate: float = 1.0
@export var weapon_range: float = 1000.0

# Countermeasures
@export var cmeasure_type: String = "none"  # chaff, flare, etc.
@export var cmeasure_effectiveness: float = 0.0

# Advanced WCS weapon properties
@export var weapon_subtype: String = ""  # Additional weapon classification
@export var model_num: int = -1  # Model number in models table
@export var external_model_num: int = -1  # External model number
@export var weapon_hitpoints: float = 1.0  # Weapon/missile hitpoints
@export var burst_shots: int = 1  # Shots per burst
@export var burst_delay: float = 0.0  # Delay between burst shots
@export var burst_flags: int = 0  # Burst firing flags

# Beam weapon properties
@export var b_info_beam_type: int = 0  # Beam type (0=normal, 1=slashing, etc.)
@export var b_info_beam_life: float = 1.0  # Beam duration
@export var b_info_beam_warmup: float = 0.0  # Beam warmup time
@export var b_info_beam_warmdown: float = 0.0  # Beam warmdown time
@export var b_info_beam_muzzle_radius: float = 0.0  # Beam muzzle radius
@export var b_info_beam_particle_count: int = 1  # Beam particle count
@export var b_info_beam_particle_radius: float = 1.0  # Beam particle radius
@export var b_info_beam_particle_angle: float = 0.0  # Beam particle spread angle
@export var b_info_beam_loop_sound: String = ""  # Beam loop sound
@export var b_info_beam_warmup_sound: String = ""  # Beam warmup sound
@export var b_info_beam_warmdown_sound: String = ""  # Beam warmdown sound
@export var b_info_beam_num_sections: int = 5  # Beam sections
@export var b_info_beam_glow_noise: float = 1.0  # Beam glow noise

# Flak weapon properties
@export var flak_targeting_accuracy: float = 1.0  # Flak targeting accuracy
@export var flak_detonation_accuracy: float = 1.0  # Flak detonation accuracy
@export var untargeted_flak_range_penalty: float = 1.0  # Range penalty for untargeted flak

# EMP properties
@export var weapon_reduce: float = 1.0  # Weapon system reduction factor
@export var afterburner_reduce: float = 1.0  # Afterburner reduction factor
@export var maneuver_reduce: float = 1.0  # Maneuverability reduction factor

# Electronic warfare
@export var elec_beam_mult: float = 1.0  # Electronic beam multiplier
@export var elec_sensors_mult: float = 1.0  # Electronic sensor multiplier
@export var elec_rotation_mult: float = 1.0  # Electronic rotation multiplier
@export var elec_radiate_ship_mult: float = 1.0  # Electronic radiation multiplier
@export var elec_randomness: float = 0.0  # Electronic randomness factor
@export var elec_use_new_style: bool = false  # Use new style electronic warfare

# SSM (Ship-to-Ship Missile) properties
@export var ssm_lock_range: float = 1000.0  # SSM lock-on range

# Swarm missile properties
@export var SwarmWait: int = 150  # Swarm missile wait time (milliseconds)

# Special weapon flags
@export var big_only: bool = false  # Only affects big ships
@export var huge_only: bool = false  # Only affects huge ships
@export var bomber_plus: bool = false  # Bomber or larger ships only
@export var electronics: bool = false  # Electronic warfare weapon
@export var puncture: bool = false  # Puncture capability
@export var supercap: bool = false  # Super capital weapon
@export var decoy: bool = false  # Decoy/chaff weapon
@export var flak: bool = false  # Flak weapon
@export var particle_spew: bool = false  # Particle spew weapon
@export var emp: bool = false  # EMP weapon
@export var esuck: bool = false  # Energy suck weapon
@export var energy_suck: bool = false  # Energy suck (alternative)
@export var flaming: bool = false  # Flaming weapon effect
@export var cycle: bool = false  # Cyclic weapon
@export var small_only: bool = false  # Small ships only
@export var beam: bool = false  # Beam weapon
@export var fighter: bool = false  # Fighter weapon
@export var bomber: bool = false  # Bomber weapon
@export var big_ship: bool = false  # Big ship weapon
@export var huge_ship: bool = false  # Huge ship weapon
@export var capital: bool = false  # Capital ship weapon
@export var antisubsystem: bool = false  # Anti-subsystem weapon
@export var heat_seeking: bool = false  # Heat seeking missile
@export var aspect_seeking: bool = false  # Aspect seeking missile
@export var javelin: bool = false  # Javelin homing
@export var spawn: bool = false  # Spawns child weapons
@export var remote: bool = false  # Remote detonation
@export var training: bool = false  # Training weapon
@export var smart_spawn: bool = false  # Smart spawn behavior
@export var inherit_parent_target: bool = false  # Child inherits parent target
@export var no_homing_speed_ramp: bool = false  # Disable homing speed ramp
@export var pulls_aspect_seekers: bool = false  # Pulls aspect seekers
@export var ciws: bool = false  # Close-in weapon system
@export var anti_fighter_beam: bool = false  # Anti-fighter beam
@export var targeting_laser: bool = false  # Targeting laser
@export var beam_no_collide: bool = false  # Beam doesn't collide
@export var stream: bool = false  # Stream weapon
@export var supressed: bool = false  # Suppressed weapon
@export var secretweapon: bool = false  # Secret weapon
@export var first_time: bool = false  # First time flag
@export var cmeasure_ignore: bool = false  # Ignore countermeasures
@export var variable_lead_homing: bool = false  # Variable lead homing
@export var tag: bool = false  # Tag weapon
@export var shudder: bool = false  # Shudder effect
@export var lockarm: bool = false  # Lock arm requirement
@export var hurts_big_ships_more: bool = false  # More damage to big ships
@export var scale_with_difficulty: bool = false  # Scale damage with difficulty
@export var ignore_shields: bool = false  # Ignore shields
@export var laser_bitmap: String = ""  # Laser bitmap
@export var laser_glow: String = ""  # Laser glow bitmap
@export var laser_color: Color = Color.WHITE  # Laser color
@export var laser_length: float = 10.0  # Laser visual length
@export var laser_head_radius: float = 1.0  # Laser head radius
@export var laser_tail_radius: float = 0.5  # Laser tail radius

# Impact and detonation
@export var impact_weapon_expl_effect: String = ""  # Impact explosion effect
@export var weapon_expl_effect: String = ""  # Weapon explosion effect
@export var dinky_impact_weapon_expl_effect: String = ""  # Small impact effect
@export var flash_impact_weapon_expl_effect: String = ""  # Flash impact effect
@export var piercing_impact_effect: String = ""  # Piercing impact effect
@export var piercing_impact_secondary_effect: String = ""  # Secondary piercing effect
@export var impact_decal: String = ""  # Impact decal texture
@export var impact_decal_radius: float = 5.0  # Impact decal radius

# Advanced targeting
@export var field_of_fire: float = 180.0  # Weapon field of fire in degrees
@export var fof_spread_rate: float = 1.0  # Field of fire spread rate
@export var fof_reset_rate: float = 1.0  # Field of fire reset rate
@export var max_fof_spread: float = 90.0  # Maximum field of fire spread

# Trails and effects
@export var trail_flag: bool = false  # Has trail effect
@export var trail_life: float = 1.0  # Trail lifetime
@export var trail_width: float = 1.0  # Trail width
@export var trail_alpha: float = 1.0  # Trail alpha
@export var trail_bitmap: String = ""  # Trail bitmap
@export var trail_faded_out_sections: int = 0  # Faded trail sections

# Corkscrew properties
@export var cs_num_fired: int = 1  # Corkscrew missiles fired
@export var cs_radius: float = 50.0  # Corkscrew radius
@export var cs_twist: float = 5.0  # Corkscrew twist rate
@export var cs_crotate: bool = false  # Corkscrew counter-rotate
@export var cs_delay: int = 0  # Corkscrew launch delay

func _init() -> void:
	# Initialize default shield quadrants if empty
	if shield_quadrants.is_empty():
		shield_quadrants = [25.0, 25.0, 25.0, 25.0]
	if explosion_bitmap_anims.is_empty():
		explosion_bitmap_anims = []
	if bay_doors.is_empty():
		bay_doors = []
	if cargo_holds.is_empty():
		cargo_holds = []
	if team_coloration.is_empty():
		team_coloration = []
	if thruster_secondary.is_empty():
		thruster_secondary = []

## Utility functions for weapon data

func is_primary_weapon() -> bool:
	"""Check if this is a primary weapon."""
	return subtype.to_lower() == "primary"

func is_secondary_weapon() -> bool:
	"""Check if this is a secondary/missile weapon."""
	return subtype.to_lower() == "secondary"

func is_homing_weapon() -> bool:
	"""Check if this weapon has homing capability."""
	return homing_type != "none" and turn_rate > 0.0

func is_ballistic_weapon() -> bool:
	"""Check if this is a ballistic projectile weapon."""
	return ballistic

func get_effective_range() -> float:
	"""Calculate effective weapon range based on velocity and lifetime."""
	return velocity * lifetime

func get_dps() -> float:
	"""Calculate damage per second."""
	if fire_wait <= 0:
		return 0.0
	return damage / fire_wait

func get_energy_efficiency() -> float:
	"""Calculate damage per energy unit."""
	if energy_consumed <= 0:
		return damage
	return damage / energy_consumed

func can_target(target_type: String) -> bool:
	"""Check if weapon can target specific object type."""
	if target_restrict == "none":
		return true
	
	var allowed_targets: PackedStringArray = target_restrict.split(",")
	return target_type.to_lower() in allowed_targets

func get_damage_vs_armor() -> float:
	"""Get effective damage against armor."""
	return damage * armor_factor

func get_damage_vs_shields() -> float:
	"""Get effective damage against shields."""
	return damage * shield_factor

func get_damage_vs_subsystems() -> float:
	"""Get effective damage against subsystems."""
	return damage * subsystem_factor

func has_area_effect() -> bool:
	"""Check if weapon has area-of-effect damage."""
	return blast_radius > 0.0

func get_threat_rating() -> float:
	"""Calculate weapon threat rating for AI evaluation."""
	var threat: float = damage
	
	# Factor in rate of fire
	threat *= (1.0 / max(0.1, fire_wait))
	
	# Factor in range
	threat *= min(1.0, get_effective_range() / 1000.0)
	
	# Homing weapons are more threatening
	if is_homing_weapon():
		threat *= 1.5
	
	# Area effect weapons are more dangerous
	if has_area_effect():
		threat *= (1.0 + blast_radius / 100.0)
	
	# Shield piercing is valuable
	if pierce_shields:
		threat *= 1.3
	
	return threat

func get_projectile_speed() -> float:
	"""Get projectile velocity in m/s."""
	return velocity

func get_time_to_target(distance: float) -> float:
	"""Calculate time for projectile to reach target at given distance."""
	if velocity <= 0:
		return -1.0
	return distance / velocity

func can_intercept_at_range(range: float) -> bool:
	"""Check if weapon can effectively engage at given range."""
	var max_range: float = get_effective_range()
	var min_range: float = min_lock_range if is_homing_weapon() else 0.0
	
	return range >= min_range and range <= max_range

func get_lock_time_at_range(range: float) -> float:
	"""Get lock time required at specific range (for homing weapons)."""
	if not is_homing_weapon():
		return 0.0
	
	if range > max_lock_range:
		return -1.0  # Cannot lock at this range
	
	# Lock time typically increases with range
	var range_factor: float = range / max_lock_range
	return lock_time * (0.5 + range_factor * 0.5)

func is_beam_weapon() -> bool:
	"""Check if this is a beam weapon."""
	return beam

func is_flak_weapon() -> bool:
	"""Check if this is a flak weapon."""
	return flak

func is_emp_weapon() -> bool:
	"""Check if this is an EMP weapon."""
	return emp

func is_swarm_weapon() -> bool:
	"""Check if this is a swarm missile."""
	return swarm_count > 1

func is_corkscrew_weapon() -> bool:
	"""Check if this is a corkscrew missile."""
	return cs_num_fired > 1

func is_spawn_weapon() -> bool:
	"""Check if this weapon spawns child weapons."""
	return spawn and not child_weapon.is_empty()

func is_electronic_weapon() -> bool:
	"""Check if this is an electronic warfare weapon."""
	return electronics

func is_puncture_weapon() -> bool:
	"""Check if this weapon has puncture capability."""
	return puncture

func can_target_size_class(size_class: String) -> bool:
	"""Check if weapon can target specific ship size class."""
	var size_lower: String = size_class.to_lower()
	
	# Check size restrictions
	if small_only and size_lower not in ["fighter", "interceptor", "bomber"]:
		return false
	if big_only and size_lower not in ["cruiser", "destroyer", "corvette"]:
		return false
	if huge_only and size_lower not in ["supercap", "huge"]:
		return false
	if bomber_plus and size_lower == "fighter":
		return false
	
	return true

func get_beam_duration() -> float:
	"""Get total beam weapon duration."""
	if not is_beam_weapon():
		return 0.0
	return b_info_beam_warmup + b_info_beam_life + b_info_beam_warmdown

func get_burst_damage() -> float:
	"""Get total damage for a full burst."""
	return damage * float(burst_shots)

func get_burst_duration() -> float:
	"""Get total time for a burst sequence."""
	if burst_shots <= 1:
		return 0.0
	return burst_delay * float(burst_shots - 1)

func get_effective_dps() -> float:
	"""Calculate DPS including burst behavior."""
	if burst_shots > 1:
		var burst_damage: float = get_burst_damage()
		var cycle_time: float = fire_wait + get_burst_duration()
		return burst_damage / cycle_time
	else:
		return get_dps()

func get_shield_penetration() -> float:
	"""Get shield penetration percentage."""
	if pierce_shields or ignore_shields:
		return 1.0
	return 1.0 - shield_factor

func get_armor_penetration() -> float:
	"""Get armor penetration effectiveness."""
	if pierce_armor:
		return 2.0  # Double effectiveness
	return armor_factor

func get_emp_effect_duration() -> float:
	"""Get EMP effect duration."""
	if is_emp_weapon():
		return emp_time
	return 0.0

func get_countermeasure_vulnerability() -> float:
	"""Get vulnerability to countermeasures."""
	if cmeasure_ignore:
		return 0.0
	return 1.0 - cmeasure_effectiveness

func get_turning_capability() -> float:
	"""Get weapon turning capability (for homing weapons)."""
	if not is_homing_weapon():
		return 0.0
	return turn_rate

func get_weapon_class_flags() -> Array[String]:
	"""Get list of all active weapon class flags."""
	var flags: Array[String] = []
	
	if beam: flags.append("beam")
	if flak: flags.append("flak")
	if emp: flags.append("emp")
	if electronics: flags.append("electronics")
	if puncture: flags.append("puncture")
	if spawn: flags.append("spawn")
	if swarm_count > 1: flags.append("swarm")
	if cs_num_fired > 1: flags.append("corkscrew")
	if heat_seeking: flags.append("heat_seeking")
	if aspect_seeking: flags.append("aspect_seeking")
	if javelin: flags.append("javelin")
	if pierce_shields: flags.append("shield_piercing")
	if pierce_armor: flags.append("armor_piercing")
	if big_only: flags.append("big_only")
	if small_only: flags.append("small_only")
	if huge_only: flags.append("huge_only")
	if bomber_plus: flags.append("bomber_plus")
	if supercap: flags.append("supercap")
	if antisubsystem: flags.append("antisubsystem")
	if training: flags.append("training")
	if ciws: flags.append("ciws")
	if tag: flags.append("tag")
	
	return flags

func get_visual_effects() -> Dictionary:
	"""Get weapon visual effect information."""
	var effects: Dictionary = {}
	
	effects["muzzle_flash"] = muzzle_flash
	effects["impact_effect"] = impact_effect
	effects["laser_bitmap"] = laser_bitmap
	effects["laser_glow"] = laser_glow
	effects["laser_color"] = laser_color
	effects["trail_bitmap"] = trail_bitmap
	effects["weapon_expl_effect"] = weapon_expl_effect
	effects["impact_decal"] = impact_decal
	
	return effects

func get_audio_effects() -> Dictionary:
	"""Get weapon audio effect information."""
	var audio: Dictionary = {}
	
	audio["launch_sound"] = launch_sound
	audio["impact_sound"] = impact_sound
	audio["flyby_sound"] = flyby_sound
	audio["beam_loop_sound"] = b_info_beam_loop_sound
	audio["beam_warmup_sound"] = b_info_beam_warmup_sound
	audio["beam_warmdown_sound"] = b_info_beam_warmdown_sound
	
	return audio

func clone_with_overrides(overrides: Dictionary) -> WeaponData:
	"""Create a copy of this weapon data with specific property overrides."""
	var clone: WeaponData = WeaponData.new()
	
	# Copy all properties with overrides
	clone.weapon_name = overrides.get("weapon_name", weapon_name)
	clone.title = overrides.get("title", title)
	clone.subtype = overrides.get("subtype", subtype)
	clone.damage = overrides.get("damage", damage)
	clone.velocity = overrides.get("velocity", velocity)
	clone.fire_wait = overrides.get("fire_wait", fire_wait)
	clone.homing_type = overrides.get("homing_type", homing_type)
	clone.turn_rate = overrides.get("turn_rate", turn_rate)
	# ... (would copy all properties in real implementation)
	
	return clone

func to_debug_string() -> String:
	"""Get debug information about this weapon."""
	var debug_info: Array[String] = []
	
	debug_info.append("Weapon: %s (%s)" % [weapon_name, subtype])
	debug_info.append("Damage: %.1f, DPS: %.1f" % [damage, get_dps()])
	debug_info.append("Range: %.0fm, Speed: %.0fm/s" % [get_effective_range(), velocity])
	
	if is_homing_weapon():
		debug_info.append("Homing: %s (turn rate: %.1f°/s)" % [homing_type, turn_rate])
	
	if has_area_effect():
		debug_info.append("Blast radius: %.1fm" % blast_radius)
	
	debug_info.append("Energy cost: %.1f per shot" % energy_consumed)
	
	return "\n".join(debug_info)