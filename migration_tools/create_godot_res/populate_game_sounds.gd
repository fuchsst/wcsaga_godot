@tool
extends EditorScript

# This script helps populate the initial sound entries in the GameSounds resource
# Run it from the editor (Project -> Tools -> Run EditorScript...)

func _run() -> void:
	var sounds := GameSounds.new()
	
	# Populate game sounds
	_add_game_sounds(sounds)
	_add_interface_sounds(sounds)
	
	# Save the resource
	var err := ResourceSaver.save(sounds, "res://resources/game_sounds.tres")
	if err != OK:
		push_error("Failed to save game_sounds.tres")
		return
	
	print("Successfully populated game_sounds.tres")

func _add_game_sound(sounds: GameSounds, filename: String, category: SoundEntry.Category, 
		volume: float = 1.0, type: SoundEntry.SoundType = SoundEntry.SoundType.NORMAL, 
		min_distance: float = 0.0, max_distance: float = 0.0) -> void:
	var entry := SoundEntry.new()
	if filename != "none.wav":
		entry.audio_stream = load("res://assets/hermes_sounds/" + filename)
	entry.default_volume = volume
	entry.category = category
	entry.type = type
	entry.min_distance = min_distance
	entry.max_distance = max_distance
	entry.attenuation = 1.0
	
	# Set preload for frequently used sounds
	entry.should_preload = (
		filename.begins_with("snd_engine_") or
		filename.begins_with("snd_weapon_") or
		filename.begins_with("snd_missile_") or
		filename.begins_with("snd_ambient_")
	)
	
	entry.resource_name = filename.get_basename()  # For better editor display
	entry.id = entry.resource_name  # Use filename as unique ID
	sounds.game_sounds.append(entry)

func _add_interface_sound(sounds: GameSounds, filename: String, volume: float = 1.0, 
		type: SoundEntry.SoundType = SoundEntry.SoundType.NORMAL, min_distance: float = 0.0, 
		max_distance: float = 0.0) -> void:
	var entry := SoundEntry.new()
	if filename != "none.wav":
		entry.audio_stream = load("res://assets/hermes_sounds/" + filename)
	entry.default_volume = volume
	entry.category = SoundEntry.Category.INTERFACE
	entry.type = type
	entry.min_distance = min_distance
	entry.max_distance = max_distance
	entry.attenuation = 1.0
	
	# Set preload for common UI sounds
	entry.should_preload = (
		filename.begins_with("snd_mouse_") or
		filename.begins_with("snd_click_") or
		filename.begins_with("snd_hover_")
	)
	
	entry.resource_name = filename.get_basename()  # For better editor display
	entry.id = entry.resource_name  # Use filename as unique ID
	sounds.interface_sounds.append(entry)

func _add_game_sounds(sounds: GameSounds) -> void:
	# Missile and weapon sounds
	_add_game_sound(sounds, "snd_missile_tracking.wav", SoundEntry.Category.WEAPON, 0.40)
	_add_game_sound(sounds, "snd_missile_lock.wav", SoundEntry.Category.WEAPON, 0.40)
	_add_game_sound(sounds, "snd_primary_cycle.wav", SoundEntry.Category.WEAPON, 0.60)
	_add_game_sound(sounds, "snd_secondary_cycle.wav", SoundEntry.Category.WEAPON, 0.60)
	
	# Ship sounds
	_add_game_sound(sounds, "snd_engine.wav", SoundEntry.Category.SHIP, 0.55)
	_add_game_sound(sounds, "snd_cargo_reveal.wav", SoundEntry.Category.SHIP, 0.40)
	_add_game_sound(sounds, "snd_death_roll.wav", SoundEntry.Category.SHIP, 1.00, SoundEntry.SoundType.A3D, 100, 800)
	_add_game_sound(sounds, "snd_ship_explode_1.wav", SoundEntry.Category.SHIP, 0.90, SoundEntry.SoundType.A3D, 750, 1500)
	
	# Interface sounds
	_add_game_sound(sounds, "snd_target_acquire.wav", SoundEntry.Category.INTERFACE, 0.60)
	_add_game_sound(sounds, "snd_energy_adjust.wav", SoundEntry.Category.INTERFACE, 0.50)
	_add_game_sound(sounds, "snd_energy_adjust_fail.wav", SoundEntry.Category.INTERFACE, 0.50)
	_add_game_sound(sounds, "snd_energy_trans.wav", SoundEntry.Category.INTERFACE, 0.50)
	_add_game_sound(sounds, "snd_energy_trans_fail.wav", SoundEntry.Category.INTERFACE, 0.50)
	
	# Ship control sounds
	_add_game_sound(sounds, "snd_full_throttle.wav", SoundEntry.Category.SHIP, 0.40)
	_add_game_sound(sounds, "snd_zero_throttle.wav", SoundEntry.Category.SHIP, 0.40)
	_add_game_sound(sounds, "snd_throttle_up.wav", SoundEntry.Category.SHIP, 0.40)
	_add_game_sound(sounds, "snd_throttle_down.wav", SoundEntry.Category.SHIP, 0.40)
	
	# Docking sounds
	_add_game_sound(sounds, "snd_dock_approach.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 10, 800)
	_add_game_sound(sounds, "snd_dock_attach.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 10, 800)
	_add_game_sound(sounds, "snd_dock_detach.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 10, 800)
	_add_game_sound(sounds, "snd_dock_depart.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 10, 800)
	
	# Afterburner sounds
	_add_game_sound(sounds, "snd_aburn_engage.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.NORMAL, 100, 500)
	_add_game_sound(sounds, "snd_aburn_loop.wav", SoundEntry.Category.SHIP, 0.75, SoundEntry.SoundType.NORMAL, 100, 500)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "snd_aburn_fail.wav", SoundEntry.Category.SHIP, 0.50)
	
	# Warning sounds
	_add_game_sound(sounds, "snd_heatlock_warn.wav", SoundEntry.Category.INTERFACE, 1.00)
	_add_game_sound(sounds, "snd_out_of_missles.wav", SoundEntry.Category.INTERFACE, 0.60)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.INTERFACE, 0.80)
	_add_game_sound(sounds, "snd_target_fail.wav", SoundEntry.Category.INTERFACE, 0.50)
	
	# Communication sounds
	_add_game_sound(sounds, "snd_squadmsging_on.wav", SoundEntry.Category.VOICE, 0.50)
	_add_game_sound(sounds, "snd_squadmsging_off.wav", SoundEntry.Category.VOICE, 0.50)
	
	# Debris and damage sounds
	_add_game_sound(sounds, "snd_debris.wav", SoundEntry.Category.SHIP, 0.40, SoundEntry.SoundType.A3D, 100, 300)
	_add_game_sound(sounds, "snd_subsys_die_1.wav", SoundEntry.Category.SHIP, 0.60)
	
	# Weapon loading sounds
	_add_game_sound(sounds, "snd_missile_start_load.wav", SoundEntry.Category.WEAPON, 0.50)
	_add_game_sound(sounds, "snd_missile_load.wav", SoundEntry.Category.WEAPON, 0.50)
	
	# Ship systems
	_add_game_sound(sounds, "snd_ship_repair.wav", SoundEntry.Category.SHIP, 0.50)
	_add_game_sound(sounds, "snd_player_hit_laser.wav", SoundEntry.Category.SHIP, 0.90, SoundEntry.SoundType.A3D, 30, 100)
	_add_game_sound(sounds, "snd_player_hit_missile.wav", SoundEntry.Category.SHIP, 0.90, SoundEntry.SoundType.A3D, 30, 100)
	_add_game_sound(sounds, "snd_cmeasure_cycle.wav", SoundEntry.Category.WEAPON, 0.80)
	
	# Shield sounds
	_add_game_sound(sounds, "snd_shield_hit.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 250, 1500)
	_add_game_sound(sounds, "snd_shield_hit_you.wav", SoundEntry.Category.SHIP, 0.80, SoundEntry.SoundType.A3D, 10, 100)
	_add_game_sound(sounds, "snd_shield_xfer_ok.wav", SoundEntry.Category.SHIP, 0.60)
	
	# Interface and feedback
	_add_game_sound(sounds, "snd_game_mouse_click.wav", SoundEntry.Category.INTERFACE, 0.60)
	_add_game_sound(sounds, "snd_aspectlock_warn.wav", SoundEntry.Category.INTERFACE, 1.00)
	
	# Engine effects
	_add_game_sound(sounds, "snd_engine_wash.wav", SoundEntry.Category.SHIP, 0.80)
	
	# Warp sounds
	_add_game_sound(sounds, "snd_warp_in.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 750, 1500)
	_add_game_sound(sounds, "snd_warp_out.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 750, 1500)
	_add_game_sound(sounds, "snd_player_warp_fail.wav", SoundEntry.Category.SHIP, 0.50)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.60)
	_add_game_sound(sounds, "snd_ship_explode_2.wav", SoundEntry.Category.SHIP, 0.90, SoundEntry.SoundType.A3D, 750, 1500)
	_add_game_sound(sounds, "snd_player_warp_out.wav", SoundEntry.Category.SHIP, 0.70)
	
	# Ship collision sounds
	_add_game_sound(sounds, "snd_ship_ship_heavy.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 100, 200)
	_add_game_sound(sounds, "snd_ship_ship_light.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 100, 200)
	_add_game_sound(sounds, "snd_ship_ship_shield.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 100, 200)
	
	# Warning system sounds
	_add_game_sound(sounds, "snd_threat_flash.wav", SoundEntry.Category.INTERFACE, 0.50)
	_add_game_sound(sounds, "snd_proximity_warning.wav", SoundEntry.Category.INTERFACE, 0.90)
	_add_game_sound(sounds, "snd_proximity_asp_warning.wav", SoundEntry.Category.INTERFACE, 0.90)
	_add_game_sound(sounds, "snd_directive_complete.wav", SoundEntry.Category.INTERFACE, 0.70)
	
	# Explosion sounds
	_add_game_sound(sounds, "snd_subsys_explode.wav", SoundEntry.Category.SHIP, 0.90, SoundEntry.SoundType.A3D, 250, 800)
	_add_game_sound(sounds, "snd_capship_explode.wav", SoundEntry.Category.SHIP, 0.90, SoundEntry.SoundType.A3D, 2000, 4000)
	_add_game_sound(sounds, "snd_capship_subsys_explode.wav", SoundEntry.Category.SHIP, 0.90, SoundEntry.SoundType.A3D, 250, 1500)
	
	# Large ship sounds
	_add_game_sound(sounds, "snd_largeship_warpout.wav", SoundEntry.Category.SHIP, 1.00, SoundEntry.SoundType.A3D, 1500, 2000)
	
	# Asteroid sounds
	_add_game_sound(sounds, "snd_asteroid_explode_large.wav", SoundEntry.Category.SHIP, 0.80, SoundEntry.SoundType.A3D, 750, 1500)
	_add_game_sound(sounds, "snd_asteroid_explode_small.wav", SoundEntry.Category.SHIP, 0.80, SoundEntry.SoundType.A3D, 500, 1000)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.90)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.90)
	
	# Scanning sounds
	_add_game_sound(sounds, "snd_cargo_scan.wav", SoundEntry.Category.SHIP, 0.50)
	
	# Weapon flyby sounds
	_add_game_sound(sounds, "snd_weapon_flyby.wav", SoundEntry.Category.WEAPON, 0.60, SoundEntry.SoundType.A3D, 50, 250)
	
	# Asteroid ambient
	_add_game_sound(sounds, "snd_asteroid.wav", SoundEntry.Category.AMBIENT, 0.50, SoundEntry.SoundType.A3D, 200, 700)
	
	# Capital ship sounds
	_add_game_sound(sounds, "snd_capital_warp_in.wav", SoundEntry.Category.SHIP, 1.00, SoundEntry.SoundType.A3D, 2000, 4000)
	_add_game_sound(sounds, "snd_capital_warp_out.wav", SoundEntry.Category.SHIP, 1.00, SoundEntry.SoundType.A3D, 2000, 4000)
	_add_game_sound(sounds, "snd_engine_loop_large.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 600, 1000)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.30)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.30)
	
	# Combat feedback
	_add_game_sound(sounds, "snd_missile_evaded_popup.wav", SoundEntry.Category.INTERFACE, 0.70)
	
	# Large engine sounds
	_add_game_sound(sounds, "snd_engine_loop_huge.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 600, 1000)
	
	# Weapon sounds
	_add_game_sound(sounds, "snd_laser_cannon_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_plasma_gun_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_reaper_gun_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_mass_driver_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_ion_cannon_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_meson_blaster_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_tachyon_gun_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_particle_gun_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_neutron_gun_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_laser_impact.wav", SoundEntry.Category.WEAPON, 0.90, SoundEntry.SoundType.A3D, 200, 800)
	_add_game_sound(sounds, "snd_photon_gun_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	
	# Missile sounds
	_add_game_sound(sounds, "snd_dumbfire_launch.wav", SoundEntry.Category.WEAPON, 0.80, SoundEntry.SoundType.A3D, 200, 1800)
	_add_game_sound(sounds, "snd_missile_impact.wav", SoundEntry.Category.WEAPON, 0.80, SoundEntry.SoundType.A3D, 500, 1200)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	
	# Additional weapon sounds
	_add_game_sound(sounds, "snd_light_tachyon_fire.wav", SoundEntry.Category.WEAPON, 0.50, SoundEntry.SoundType.A3D, 200, 1200)
	_add_game_sound(sounds, "snd_torpedo_launch.wav", SoundEntry.Category.WEAPON, 1.00, SoundEntry.SoundType.A3D, 500, 3000)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "snd_cmeasure1_launch.wav", SoundEntry.Category.WEAPON, 0.90, SoundEntry.SoundType.A3D, 100, 1000)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "snd_shockwave_explode.wav", SoundEntry.Category.WEAPON, 0.80, SoundEntry.SoundType.A3D, 1200, 2000)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	
	# Capital ship engine loops
	_add_game_sound(sounds, "snd_engine_loop_capital_1.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 100, 2000)
	_add_game_sound(sounds, "snd_engine_loop_capital_2.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 100, 2000)
	_add_game_sound(sounds, "snd_engine_loop_capital_3.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 100, 2000)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	
	# Impact and weapon sounds
	_add_game_sound(sounds, "snd_shockwave_impact.wav", SoundEntry.Category.WEAPON, 0.70, SoundEntry.SoundType.A3D, 50, 800)
	
	# Turret sounds
	_add_game_sound(sounds, "snd_laser_turret_fire.wav", SoundEntry.Category.WEAPON, 0.60, SoundEntry.SoundType.A3D, 200, 2000)
	_add_game_sound(sounds, "snd_amg_turret_fire.wav", SoundEntry.Category.WEAPON, 0.60, SoundEntry.SoundType.A3D, 500, 3500)
	_add_game_sound(sounds, "snd_tachyon_turret_fire.wav", SoundEntry.Category.WEAPON, 0.60, SoundEntry.SoundType.A3D, 200, 2000)
	_add_game_sound(sounds, "snd_neutron_turret_fire.wav", SoundEntry.Category.WEAPON, 0.60, SoundEntry.SoundType.A3D, 200, 2000)
	_add_game_sound(sounds, "snd_plasma_turret_fire.wav", SoundEntry.Category.WEAPON, 0.60, SoundEntry.SoundType.A3D, 200, 2000)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "snd_flak_fire.wav", SoundEntry.Category.WEAPON, 0.60, SoundEntry.SoundType.A3D, 250, 1000)
	_add_game_sound(sounds, "snd_shield_breaker.wav", SoundEntry.Category.WEAPON, 0.80, SoundEntry.SoundType.A3D, 400, 800)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "snd_autocannon_loop.wav", SoundEntry.Category.WEAPON, 0.60, SoundEntry.SoundType.A3D, 200, 600)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.WEAPON, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	
	# Ship engine sounds
	_add_game_sound(sounds, "snd_confed_fighter_eng.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_confed_bomber_eng.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_confed_utility_eng.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_confed_capship_eng.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_confed_base_eng.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_kilrathi_fighter_eng.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_kilrathi_bomber_eng.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_kilrathi_utility_eng.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_kilrathi_capship_eng.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_kilrathi_base_eng.wav", SoundEntry.Category.SHIP, 0.60, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_behemoth_eng.wav", SoundEntry.Category.SHIP, 0.70, SoundEntry.SoundType.A3D, 100, 2000)
	_add_game_sound(sounds, "snd_dreadnaught_eng.wav", SoundEntry.Category.SHIP, 0.80, SoundEntry.SoundType.A3D, 100, 2000)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	
	# Debris arc sounds
	_add_game_sound(sounds, "snd_debris_arc_01.wav", SoundEntry.Category.SHIP, 0.30, SoundEntry.SoundType.A3D, 200, 400)
	_add_game_sound(sounds, "snd_debris_arc_02.wav", SoundEntry.Category.SHIP, 0.30, SoundEntry.SoundType.A3D, 200, 400)
	_add_game_sound(sounds, "snd_debris_arc_03.wav", SoundEntry.Category.SHIP, 0.30, SoundEntry.SoundType.A3D, 200, 400)
	_add_game_sound(sounds, "snd_debris_arc_04.wav", SoundEntry.Category.SHIP, 0.30, SoundEntry.SoundType.A3D, 200, 400)
	_add_game_sound(sounds, "snd_debris_arc_05.wav", SoundEntry.Category.SHIP, 0.30, SoundEntry.SoundType.A3D, 200, 400)
	
	# Cloak sounds
	_add_game_sound(sounds, "snd_cloak_on.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "snd_cloak_off.wav", SoundEntry.Category.SHIP, 0.80)	
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	
	# Startup sound
	_add_game_sound(sounds, "snd_startup.wav", SoundEntry.Category.INTERFACE, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	
	# Large engine loops
	_add_game_sound(sounds, "snd_engine_loop_large_1.wav", SoundEntry.Category.SHIP, 0.80, SoundEntry.SoundType.A3D, 50, 1000)
	_add_game_sound(sounds, "snd_engine_loop_large_2.wav", SoundEntry.Category.SHIP, 0.80, SoundEntry.SoundType.A3D, 50, 1000)
	
	# Final placeholders
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	
	# Lightning sounds
	_add_game_sound(sounds, "snd_lightning_1.wav", SoundEntry.Category.AMBIENT, 0.60)
	_add_game_sound(sounds, "snd_lightning_2.wav", SoundEntry.Category.AMBIENT, 0.60)
	_add_game_sound(sounds, "snd_lightning_3.wav", SoundEntry.Category.AMBIENT, 0.60)
	_add_game_sound(sounds, "snd_lightning_4.wav", SoundEntry.Category.AMBIENT, 0.60)
	
	# Final placeholders
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	_add_game_sound(sounds, "none.wav", SoundEntry.Category.SHIP, 0.80)
	
	# Installation sounds
	_add_game_sound(sounds, "snd_installation_1.wav", SoundEntry.Category.SHIP, 0.80, SoundEntry.SoundType.A3D, 1500, 3000)
	_add_game_sound(sounds, "snd_installation_2.wav", SoundEntry.Category.SHIP, 0.80, SoundEntry.SoundType.A3D, 1500, 3000)
	
func _add_interface_sounds(sounds: GameSounds) -> void:
	_add_interface_sound(sounds, "snd_iface_mouse_click.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_icon_drop_on_wing.wav", 0.60, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_icon_drop.wav", 0.60, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_screen_mode_pressed.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_switch_screens.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_help_pressed.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_commit_pressed.wav", 0.60, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_prev_next_pressed.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_scroll.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_general_fail.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_ship_icon_change.wav", 0.50, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.60, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.60, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_brief_stage_chg.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_brief_stage_chg_fail.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_brief_icon_select.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_user_over.wav", 0.50, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_user_select.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_reset_pressed.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_brief_text_wipe.wav", 0.60, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.50, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_weapon_anim_start.wav", 0.60, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_door_open.wav", 0.50, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_door_close.wav", 0.50, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.50, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.50, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.60, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_popup_appear.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_popup_disappear.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_voice_slider_clip.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.50, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.70, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_weld3.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_weld4.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.80, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.80, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.80, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_icon_highlight.wav", 0.40, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_briefing_static.wav", 0.40, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall2_crane1_1.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_1.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_2.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_3.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_4.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_5.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_6.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_7.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_8.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_9.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_10.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_11.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_12.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_13.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_14.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_15.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_16.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_17.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "snd_main_hall_pa_18.wav", 1.00, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.80, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.80, SoundEntry.SoundType.NORMAL)
	_add_interface_sound(sounds, "none.wav", 0.80, SoundEntry.SoundType.NORMAL)
