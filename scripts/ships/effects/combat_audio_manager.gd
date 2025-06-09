class_name CombatAudioManager
extends Node

## SHIP-012 AC5: Combat Audio Manager
## Provides positional combat sounds with weapon firing, impact, and explosion audio
## Implements WCS-authentic audio feedback with 3D spatial positioning and performance optimization

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")

# Signals
signal combat_audio_played(audio_type: String, audio_data: Dictionary)
signal audio_priority_adjusted(audio_source: AudioStreamPlayer3D, priority_level: float)
signal audio_performance_warning(active_sources: int, performance_impact: float)
signal spatial_audio_updated(listener_position: Vector3, audio_zones: Array)

# Audio resource management
var weapon_firing_sounds: Dictionary = {}
var impact_sounds: Dictionary = {}
var explosion_sounds: Dictionary = {}
var ambient_combat_sounds: Dictionary = {}
var environment_sounds: Dictionary = {}

# Audio source pools
var weapon_audio_pool: Array[AudioStreamPlayer3D] = []
var impact_audio_pool: Array[AudioStreamPlayer3D] = []
var explosion_audio_pool: Array[AudioStreamPlayer3D] = []
var ambient_audio_pool: Array[AudioStreamPlayer3D] = []

# Active audio tracking
var active_audio_sources: Array[AudioStreamPlayer3D] = []
var audio_priority_queue: Array[Dictionary] = []
var spatial_audio_zones: Array[Dictionary] = []

# Audio listener reference
var audio_listener: AudioListener3D = null
var camera_node: Camera3D = null
var current_listener_position: Vector3 = Vector3.ZERO

# Configuration
@export var enable_3d_audio: bool = true
@export var enable_audio_priorities: bool = true
@export var enable_distance_culling: bool = true
@export var enable_doppler_effects: bool = true
@export var debug_audio_logging: bool = false

# Performance settings
@export var max_simultaneous_audio_sources: int = 32
@export var audio_culling_distance: float = 500.0
@export var priority_update_frequency: float = 0.1
@export var spatial_update_frequency: float = 0.05

# Audio parameters
@export var master_combat_volume: float = 1.0
@export var weapon_volume_modifier: float = 0.8
@export var impact_volume_modifier: float = 0.9
@export var explosion_volume_modifier: float = 1.2
@export var ambient_volume_modifier: float = 0.6

# Distance and falloff settings
@export var audio_max_distance: float = 200.0
@export var audio_reference_distance: float = 10.0
@export var doppler_tracking_enabled: bool = true
@export var reverb_zones_enabled: bool = true

# Audio priority levels
enum AudioPriority {
	CRITICAL = 5,    # Player weapon firing, major explosions
	HIGH = 4,        # Nearby weapon impacts, shield hits
	MEDIUM = 3,      # Distant weapon fire, medium explosions
	LOW = 2,         # Ambient combat sounds, distant impacts
	BACKGROUND = 1   # Environmental audio, distant battles
}

# Update timers
var priority_update_timer: float = 0.0
var spatial_update_timer: float = 0.0

func _ready() -> void:
	_setup_combat_audio_system()
	_initialize_audio_pools()
	_load_audio_resources()

## Initialize combat audio system
func initialize_combat_audio(listener: AudioListener3D = null, camera: Camera3D = null) -> void:
	audio_listener = listener
	camera_node = camera
	
	if not audio_listener and camera_node:
		# Create audio listener if none provided
		audio_listener = AudioListener3D.new()
		camera_node.add_child(audio_listener)
	
	if debug_audio_logging:
		print("CombatAudioManager: Initialized with 3D audio %s" % 
			("enabled" if enable_3d_audio else "disabled"))

## Play weapon firing audio
func play_weapon_firing_audio(weapon_data: Dictionary) -> AudioStreamPlayer3D:
	var weapon_type = weapon_data.get("weapon_type", WeaponTypes.Type.PRIMARY_LASER)
	var firing_position = weapon_data.get("position", Vector3.ZERO)
	var firing_velocity = weapon_data.get("velocity", Vector3.ZERO)
	var weapon_name = weapon_data.get("weapon_name", "unknown")
	
	# Get appropriate audio stream
	var audio_stream = _get_weapon_firing_sound(weapon_type)
	if not audio_stream:
		return null
	
	# Get audio source from pool
	var audio_source = _get_weapon_audio_source()
	if not audio_source:
		return null
	
	# Configure audio source
	audio_source.stream = audio_stream
	audio_source.global_position = firing_position
	audio_source.volume_db = linear_to_db(master_combat_volume * weapon_volume_modifier)
	
	# Set 3D audio properties
	if enable_3d_audio:
		_configure_3d_audio_source(audio_source, firing_position, firing_velocity)
	
	# Set priority
	var priority = _calculate_weapon_firing_priority(weapon_data)
	_set_audio_priority(audio_source, priority)
	
	# Play audio
	audio_source.play()
	_add_active_audio_source(audio_source, "weapon_firing", weapon_data)
	
	if debug_audio_logging:
		print("CombatAudioManager: Playing weapon firing sound for %s at %s" % [
			weapon_name, firing_position
		])
	
	return audio_source

## Play weapon impact audio
func play_weapon_impact_audio(impact_data: Dictionary) -> AudioStreamPlayer3D:
	var impact_position = impact_data.get("position", Vector3.ZERO)
	var damage_type = impact_data.get("damage_type", DamageTypes.Type.KINETIC)
	var damage_amount = impact_data.get("damage_amount", 50.0)
	var material_type = impact_data.get("material_type", 0)
	var impact_velocity = impact_data.get("impact_velocity", Vector3.ZERO)
	
	# Get appropriate impact sound
	var audio_stream = _get_weapon_impact_sound(damage_type, material_type)
	if not audio_stream:
		return null
	
	# Get audio source from pool
	var audio_source = _get_impact_audio_source()
	if not audio_source:
		return null
	
	# Configure audio source
	audio_source.stream = audio_stream
	audio_source.global_position = impact_position
	audio_source.volume_db = linear_to_db(
		master_combat_volume * impact_volume_modifier * 
		_calculate_impact_volume_modifier(damage_amount)
	)
	
	# Set 3D audio properties
	if enable_3d_audio:
		_configure_3d_audio_source(audio_source, impact_position, impact_velocity)
	
	# Set priority based on proximity and damage
	var priority = _calculate_impact_priority(impact_data)
	_set_audio_priority(audio_source, priority)
	
	# Pitch variation for impact variety
	audio_source.pitch_scale = randf_range(0.9, 1.1)
	
	# Play audio
	audio_source.play()
	_add_active_audio_source(audio_source, "weapon_impact", impact_data)
	
	if debug_audio_logging:
		print("CombatAudioManager: Playing impact sound for %s damage at %s" % [
			DamageTypes.get_damage_type_name(damage_type), impact_position
		])
	
	return audio_source

## Play explosion audio
func play_explosion_audio(explosion_data: Dictionary) -> AudioStreamPlayer3D:
	var explosion_position = explosion_data.get("position", Vector3.ZERO)
	var explosion_type = explosion_data.get("explosion_type", "small")
	var blast_radius = explosion_data.get("blast_radius", 10.0)
	var damage_amount = explosion_data.get("damage_amount", 100.0)
	
	# Get appropriate explosion sound
	var audio_stream = _get_explosion_sound(explosion_type, blast_radius)
	if not audio_stream:
		return null
	
	# Get audio source from pool
	var audio_source = _get_explosion_audio_source()
	if not audio_source:
		return null
	
	# Configure audio source
	audio_source.stream = audio_stream
	audio_source.global_position = explosion_position
	audio_source.volume_db = linear_to_db(
		master_combat_volume * explosion_volume_modifier * 
		_calculate_explosion_volume_modifier(explosion_type, blast_radius)
	)
	
	# Set 3D audio properties
	if enable_3d_audio:
		_configure_3d_audio_source(audio_source, explosion_position, Vector3.ZERO)
		# Explosions have longer range
		audio_source.max_distance = audio_max_distance * 2.0
	
	# Explosions always have high priority
	_set_audio_priority(audio_source, AudioPriority.HIGH)
	
	# Pitch variation based on explosion size
	audio_source.pitch_scale = randf_range(0.8, 1.2)
	
	# Play audio
	audio_source.play()
	_add_active_audio_source(audio_source, "explosion", explosion_data)
	
	if debug_audio_logging:
		print("CombatAudioManager: Playing %s explosion sound at %s (radius: %.1f)" % [
			explosion_type, explosion_position, blast_radius
		])
	
	return audio_source

## Play ambient combat audio
func play_ambient_combat_audio(ambient_data: Dictionary) -> AudioStreamPlayer3D:
	var ambient_type = ambient_data.get("type", "battle_distant")
	var position = ambient_data.get("position", Vector3.ZERO)
	var intensity = ambient_data.get("intensity", 0.5)
	var looping = ambient_data.get("looping", true)
	
	# Get ambient sound
	var audio_stream = _get_ambient_combat_sound(ambient_type)
	if not audio_stream:
		return null
	
	# Get audio source from pool
	var audio_source = _get_ambient_audio_source()
	if not audio_source:
		return null
	
	# Configure audio source
	audio_source.stream = audio_stream
	audio_source.global_position = position
	audio_source.volume_db = linear_to_db(
		master_combat_volume * ambient_volume_modifier * intensity
	)
	
	# Set 3D audio properties
	if enable_3d_audio:
		_configure_3d_audio_source(audio_source, position, Vector3.ZERO)
		# Ambient sounds have longer range but lower priority
		audio_source.max_distance = audio_max_distance * 1.5
	
	# Low priority for ambient sounds
	_set_audio_priority(audio_source, AudioPriority.BACKGROUND)
	
	# Play audio (looping if specified)
	audio_source.play()
	_add_active_audio_source(audio_source, "ambient_combat", ambient_data)
	
	if debug_audio_logging:
		print("CombatAudioManager: Playing ambient combat audio: %s" % ambient_type)
	
	return audio_source

## Update audio listener position
func update_listener_position(new_position: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	current_listener_position = new_position
	
	if audio_listener:
		audio_listener.global_position = new_position
	
	# Update doppler effects if enabled
	if enable_doppler_effects and doppler_tracking_enabled:
		_update_doppler_effects(velocity)
	
	# Update spatial audio zones
	_update_spatial_audio_zones()

## Setup combat audio system
func _setup_combat_audio_system() -> void:
	active_audio_sources.clear()
	audio_priority_queue.clear()
	spatial_audio_zones.clear()
	
	# Initialize update timers
	priority_update_timer = 0.0
	spatial_update_timer = 0.0

## Initialize audio pools
func _initialize_audio_pools() -> void:
	# Weapon firing audio pool
	for i in range(12):
		var audio_source = AudioStreamPlayer3D.new()
		audio_source.name = "WeaponAudio_" + str(i)
		_configure_default_audio_source(audio_source)
		weapon_audio_pool.append(audio_source)
		add_child(audio_source)
	
	# Impact audio pool
	for i in range(15):
		var audio_source = AudioStreamPlayer3D.new()
		audio_source.name = "ImpactAudio_" + str(i)
		_configure_default_audio_source(audio_source)
		impact_audio_pool.append(audio_source)
		add_child(audio_source)
	
	# Explosion audio pool
	for i in range(8):
		var audio_source = AudioStreamPlayer3D.new()
		audio_source.name = "ExplosionAudio_" + str(i)
		_configure_default_audio_source(audio_source)
		explosion_audio_pool.append(audio_source)
		add_child(audio_source)
	
	# Ambient audio pool
	for i in range(5):
		var audio_source = AudioStreamPlayer3D.new()
		audio_source.name = "AmbientAudio_" + str(i)
		_configure_default_audio_source(audio_source)
		ambient_audio_pool.append(audio_source)
		add_child(audio_source)

## Configure default audio source settings
func _configure_default_audio_source(audio_source: AudioStreamPlayer3D) -> void:
	audio_source.max_distance = audio_max_distance
	audio_source.unit_size = audio_reference_distance
	audio_source.attenuation_filter_cutoff_hz = 5000.0
	audio_source.attenuation_filter_db = -24.0
	audio_source.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	audio_source.autoplay = false

## Load audio resources
func _load_audio_resources() -> void:
	# Load weapon firing sounds
	weapon_firing_sounds = {
		WeaponTypes.Type.PRIMARY_LASER: _create_placeholder_audio_stream("laser_fire", 0.3),
		WeaponTypes.Type.PRIMARY_MASS_DRIVER: _create_placeholder_audio_stream("mass_driver_fire", 0.5),
		WeaponTypes.Type.SECONDARY_MISSILE: _create_placeholder_audio_stream("missile_launch", 0.7),
		WeaponTypes.Type.BEAM_WEAPON: _create_placeholder_audio_stream("beam_fire", 1.0)
	}
	
	# Load impact sounds
	impact_sounds = {
		"energy_metal": _create_placeholder_audio_stream("energy_impact_metal", 0.2),
		"kinetic_metal": _create_placeholder_audio_stream("kinetic_impact_metal", 0.3),
		"explosive_metal": _create_placeholder_audio_stream("explosive_impact_metal", 0.4),
		"energy_shield": _create_placeholder_audio_stream("energy_impact_shield", 0.3),
		"kinetic_shield": _create_placeholder_audio_stream("kinetic_impact_shield", 0.2)
	}
	
	# Load explosion sounds
	explosion_sounds = {
		"small": _create_placeholder_audio_stream("explosion_small", 0.8),
		"medium": _create_placeholder_audio_stream("explosion_medium", 1.2),
		"large": _create_placeholder_audio_stream("explosion_large", 1.8),
		"massive": _create_placeholder_audio_stream("explosion_massive", 2.5)
	}
	
	# Load ambient combat sounds
	ambient_combat_sounds = {
		"battle_distant": _create_placeholder_audio_stream("battle_distant", 2.0),
		"engine_hum": _create_placeholder_audio_stream("engine_hum", 1.5),
		"space_ambient": _create_placeholder_audio_stream("space_ambient", 3.0)
	}

## Create placeholder audio stream
func _create_placeholder_audio_stream(stream_name: String, duration: float) -> AudioStream:
	# This would load actual audio files in a real implementation
	# For now, return null as placeholder
	return null

## Configure 3D audio source
func _configure_3d_audio_source(audio_source: AudioStreamPlayer3D, position: Vector3, velocity: Vector3) -> void:
	audio_source.global_position = position
	
	# Calculate distance from listener
	var distance = position.distance_to(current_listener_position)
	
	# Adjust attenuation based on distance
	if distance > audio_max_distance:
		audio_source.volume_db = linear_to_db(0.0)  # Mute distant audio
	else:
		var distance_factor = 1.0 - (distance / audio_max_distance)
		audio_source.attenuation_filter_cutoff_hz = 5000.0 * distance_factor + 1000.0
	
	# Set doppler tracking
	if enable_doppler_effects and velocity.length() > 0:
		audio_source.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	else:
		audio_source.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED

## Get audio sources from pools
func _get_weapon_audio_source() -> AudioStreamPlayer3D:
	for audio_source in weapon_audio_pool:
		if not audio_source.playing:
			return audio_source
	return null

func _get_impact_audio_source() -> AudioStreamPlayer3D:
	for audio_source in impact_audio_pool:
		if not audio_source.playing:
			return audio_source
	return null

func _get_explosion_audio_source() -> AudioStreamPlayer3D:
	for audio_source in explosion_audio_pool:
		if not audio_source.playing:
			return audio_source
	return null

func _get_ambient_audio_source() -> AudioStreamPlayer3D:
	for audio_source in ambient_audio_pool:
		if not audio_source.playing:
			return audio_source
	return null

## Get audio streams
func _get_weapon_firing_sound(weapon_type: int) -> AudioStream:
	return weapon_firing_sounds.get(weapon_type)

func _get_weapon_impact_sound(damage_type: int, material_type: int) -> AudioStream:
	var sound_key = ""
	
	# Determine sound key based on damage and material type
	match damage_type:
		DamageTypes.Type.ENERGY:
			sound_key = "energy_"
		DamageTypes.Type.KINETIC:
			sound_key = "kinetic_"
		DamageTypes.Type.EXPLOSIVE:
			sound_key = "explosive_"
		_:
			sound_key = "energy_"
	
	# Add material type (simplified)
	if material_type == 0:  # Shield
		sound_key += "shield"
	else:  # Hull/armor
		sound_key += "metal"
	
	return impact_sounds.get(sound_key)

func _get_explosion_sound(explosion_type: String, blast_radius: float) -> AudioStream:
	return explosion_sounds.get(explosion_type)

func _get_ambient_combat_sound(ambient_type: String) -> AudioStream:
	return ambient_combat_sounds.get(ambient_type)

## Calculate audio priorities
func _calculate_weapon_firing_priority(weapon_data: Dictionary) -> int:
	var position = weapon_data.get("position", Vector3.ZERO)
	var distance = position.distance_to(current_listener_position)
	
	# Player weapons or very close weapons get high priority
	if distance < 20.0:
		return AudioPriority.CRITICAL
	elif distance < 50.0:
		return AudioPriority.HIGH
	elif distance < 100.0:
		return AudioPriority.MEDIUM
	else:
		return AudioPriority.LOW

func _calculate_impact_priority(impact_data: Dictionary) -> int:
	var position = impact_data.get("position", Vector3.ZERO)
	var damage = impact_data.get("damage_amount", 50.0)
	var distance = position.distance_to(current_listener_position)
	
	# High damage or close impacts get priority
	if damage > 100.0 or distance < 30.0:
		return AudioPriority.HIGH
	elif damage > 50.0 or distance < 75.0:
		return AudioPriority.MEDIUM
	else:
		return AudioPriority.LOW

## Calculate volume modifiers
func _calculate_impact_volume_modifier(damage_amount: float) -> float:
	return clamp(damage_amount / 100.0, 0.3, 1.5)

func _calculate_explosion_volume_modifier(explosion_type: String, blast_radius: float) -> float:
	var base_modifier = 1.0
	
	match explosion_type:
		"small":
			base_modifier = 0.8
		"medium":
			base_modifier = 1.0
		"large":
			base_modifier = 1.3
		"massive":
			base_modifier = 1.6
	
	return base_modifier * clamp(blast_radius / 20.0, 0.5, 2.0)

## Audio priority management
func _set_audio_priority(audio_source: AudioStreamPlayer3D, priority: int) -> void:
	if not enable_audio_priorities:
		return
	
	# Store priority data
	audio_priority_queue.append({
		"audio_source": audio_source,
		"priority": priority,
		"start_time": Time.get_ticks_msec() / 1000.0
	})
	
	audio_priority_adjusted.emit(audio_source, priority)

## Add active audio source
func _add_active_audio_source(audio_source: AudioStreamPlayer3D, audio_type: String, audio_data: Dictionary) -> void:
	active_audio_sources.append(audio_source)
	
	# Performance check
	if active_audio_sources.size() > max_simultaneous_audio_sources:
		_cull_low_priority_audio()
	
	combat_audio_played.emit(audio_type, audio_data)

## Update doppler effects
func _update_doppler_effects(listener_velocity: Vector3) -> void:
	# Update doppler for all active audio sources
	for audio_source in active_audio_sources:
		if audio_source and audio_source.playing:
			# Doppler calculation would be implemented here
			# For now, Godot handles doppler automatically if enabled
			pass

## Update spatial audio zones
func _update_spatial_audio_zones() -> void:
	# Update audio zones based on listener position
	spatial_audio_zones.clear()
	
	# Add audio zones for different combat areas
	# This would be expanded based on actual game requirements
	
	spatial_audio_updated.emit(current_listener_position, spatial_audio_zones)

## Cull low priority audio
func _cull_low_priority_audio() -> void:
	if audio_priority_queue.is_empty():
		return
	
	# Sort by priority (lowest first)
	audio_priority_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["priority"] < b["priority"]
	)
	
	# Stop lowest priority audio
	var lowest_priority = audio_priority_queue[0]
	var audio_source = lowest_priority["audio_source"]
	if audio_source and audio_source.playing:
		audio_source.stop()
		active_audio_sources.erase(audio_source)
		audio_priority_queue.erase(lowest_priority)

## Performance monitoring
func _check_audio_performance() -> void:
	var active_count = active_audio_sources.size()
	
	if active_count > max_simultaneous_audio_sources * 0.8:
		var performance_impact = float(active_count) / float(max_simultaneous_audio_sources)
		audio_performance_warning.emit(active_count, performance_impact)

## Process frame updates
func _process(delta: float) -> void:
	priority_update_timer += delta
	spatial_update_timer += delta
	
	# Update audio priorities
	if priority_update_timer >= priority_update_frequency:
		priority_update_timer = 0.0
		_update_audio_priorities()
	
	# Update spatial audio
	if spatial_update_timer >= spatial_update_frequency:
		spatial_update_timer = 0.0
		_update_spatial_audio()
	
	# Cleanup finished audio sources
	_cleanup_finished_audio_sources()

## Update audio priorities
func _update_audio_priorities() -> void:
	if not enable_audio_priorities:
		return
	
	# Remove expired priority entries
	var current_time = Time.get_ticks_msec() / 1000.0
	var expired_entries: Array[Dictionary] = []
	
	for priority_entry in audio_priority_queue:
		var audio_source = priority_entry["audio_source"]
		if not audio_source or not audio_source.playing:
			expired_entries.append(priority_entry)
	
	for entry in expired_entries:
		audio_priority_queue.erase(entry)

## Update spatial audio
func _update_spatial_audio() -> void:
	if not enable_3d_audio:
		return
	
	# Update distance-based effects for all active sources
	for audio_source in active_audio_sources:
		if audio_source and audio_source.playing:
			var distance = audio_source.global_position.distance_to(current_listener_position)
			
			# Cull distant audio if enabled
			if enable_distance_culling and distance > audio_culling_distance:
				audio_source.volume_db = linear_to_db(0.0)
			else:
				# Update 3D audio properties based on distance
				_update_audio_source_3d_properties(audio_source, distance)

## Update audio source 3D properties
func _update_audio_source_3d_properties(audio_source: AudioStreamPlayer3D, distance: float) -> void:
	# Adjust filter cutoff based on distance
	var distance_factor = 1.0 - clamp(distance / audio_max_distance, 0.0, 1.0)
	audio_source.attenuation_filter_cutoff_hz = 5000.0 * distance_factor + 1000.0

## Cleanup finished audio sources
func _cleanup_finished_audio_sources() -> void:
	var finished_sources: Array[AudioStreamPlayer3D] = []
	
	for audio_source in active_audio_sources:
		if not audio_source or not audio_source.playing:
			finished_sources.append(audio_source)
	
	for source in finished_sources:
		active_audio_sources.erase(source)

## Get audio system status
func get_combat_audio_status() -> Dictionary:
	return {
		"active_sources": active_audio_sources.size(),
		"max_sources": max_simultaneous_audio_sources,
		"priority_queue_size": audio_priority_queue.size(),
		"3d_audio_enabled": enable_3d_audio,
		"doppler_enabled": enable_doppler_effects,
		"listener_position": current_listener_position
	}