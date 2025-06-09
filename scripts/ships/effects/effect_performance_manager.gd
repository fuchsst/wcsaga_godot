class_name EffectPerformanceManager
extends Node

## SHIP-012 AC7: Effect Performance Manager
## Manages LOD systems and culling optimization for smooth effects rendering during large-scale combat
## Implements performance monitoring and adaptive quality scaling

# Signals
signal performance_level_changed(new_level: int, reason: String)
signal effect_culled(effect_type: String, culled_count: int)
signal lod_level_adjusted(effect_type: String, old_level: int, new_level: int)
signal performance_warning(warning_type: String, severity: float)

# Performance monitoring
var frame_times: Array[float] = []
var current_fps: float = 60.0
var target_fps: float = 60.0
var performance_samples: int = 30
var performance_update_frequency: float = 0.5

# Effect management references
var weapon_impact_manager: WeaponImpactEffectManager = null
var explosion_system: ExplosionSystem = null
var damage_visualization: DamageVisualizationController = null
var shield_effect_manager: ShieldEffectManager = null
var combat_audio_manager: CombatAudioManager = null
var environmental_effects: EnvironmentalEffectSystem = null

# Camera reference for distance calculations
var camera_node: Camera3D = null
var current_camera_position: Vector3 = Vector3.ZERO

# Performance levels (0 = lowest, 4 = highest quality)
enum PerformanceLevel {
	POTATO = 0,      # Minimal effects for very low-end hardware
	LOW = 1,         # Reduced particle counts, short durations
	MEDIUM = 2,      # Balanced quality and performance
	HIGH = 3,        # Full effects with optimization
	ULTRA = 4        # Maximum quality, no compromises
}

# Current performance state
var current_performance_level: PerformanceLevel = PerformanceLevel.HIGH
var auto_adjust_performance: bool = true
var performance_adjustment_enabled: bool = true

# LOD distance thresholds
var lod_distance_thresholds: Array[float] = [25.0, 50.0, 100.0, 200.0, 500.0]
var audio_lod_thresholds: Array[float] = [50.0, 100.0, 200.0, 400.0]

# Effect limits per performance level
var effect_limits: Dictionary = {
	PerformanceLevel.POTATO: {
		"max_particles": 500,
		"max_audio_sources": 8,
		"max_explosions": 3,
		"max_impacts": 10,
		"particle_scale": 0.3,
		"effect_duration_scale": 0.5
	},
	PerformanceLevel.LOW: {
		"max_particles": 1500,
		"max_audio_sources": 16,
		"max_explosions": 6,
		"max_impacts": 20,
		"particle_scale": 0.6,
		"effect_duration_scale": 0.7
	},
	PerformanceLevel.MEDIUM: {
		"max_particles": 3000,
		"max_audio_sources": 24,
		"max_explosions": 10,
		"max_impacts": 40,
		"particle_scale": 0.8,
		"effect_duration_scale": 0.85
	},
	PerformanceLevel.HIGH: {
		"max_particles": 5000,
		"max_audio_sources": 32,
		"max_explosions": 15,
		"max_impacts": 60,
		"particle_scale": 1.0,
		"effect_duration_scale": 1.0
	},
	PerformanceLevel.ULTRA: {
		"max_particles": 8000,
		"max_audio_sources": 48,
		"max_explosions": 25,
		"max_impacts": 100,
		"particle_scale": 1.2,
		"effect_duration_scale": 1.2
	}
}

# Performance monitoring
var total_active_particles: int = 0
var total_active_audio_sources: int = 0
var total_active_effects: int = 0
var memory_usage_mb: float = 0.0

# Culling statistics
var culling_stats: Dictionary = {}
var performance_history: Array[Dictionary] = []

# Configuration
@export var enable_automatic_lod: bool = true
@export var enable_distance_culling: bool = true
@export var enable_performance_monitoring: bool = true
@export var enable_adaptive_quality: bool = true
@export var debug_performance_logging: bool = false

# Performance thresholds
@export var fps_warning_threshold: float = 50.0
@export var fps_critical_threshold: float = 30.0
@export var memory_warning_threshold: float = 512.0  # MB
@export var particle_warning_threshold: int = 4000

# Update timers
var performance_update_timer: float = 0.0
var lod_update_timer: float = 0.0
var culling_update_timer: float = 0.0

func _ready() -> void:
	_setup_performance_manager()
	_initialize_performance_monitoring()

## Initialize performance manager with effect system references
func initialize_performance_manager(effect_managers: Dictionary, camera: Camera3D = null) -> void:
	weapon_impact_manager = effect_managers.get("weapon_impact_manager")
	explosion_system = effect_managers.get("explosion_system")
	damage_visualization = effect_managers.get("damage_visualization")
	shield_effect_manager = effect_managers.get("shield_effect_manager")
	combat_audio_manager = effect_managers.get("combat_audio_manager")
	environmental_effects = effect_managers.get("environmental_effects")
	
	camera_node = camera
	
	# Apply initial performance settings
	_apply_performance_level(current_performance_level)
	
	if debug_performance_logging:
		print("EffectPerformanceManager: Initialized with performance level %d" % current_performance_level)

## Set performance level manually
func set_performance_level(level: PerformanceLevel, disable_auto_adjust: bool = false) -> void:
	if disable_auto_adjust:
		auto_adjust_performance = false
	
	var old_level = current_performance_level
	current_performance_level = level
	
	_apply_performance_level(level)
	performance_level_changed.emit(level, "manual_override")
	
	if debug_performance_logging:
		print("EffectPerformanceManager: Performance level changed from %d to %d" % [old_level, level])

## Update camera position for distance calculations
func update_camera_position(new_position: Vector3) -> void:
	current_camera_position = new_position

## Get current performance statistics
func get_performance_statistics() -> Dictionary:
	return {
		"current_fps": current_fps,
		"target_fps": target_fps,
		"performance_level": current_performance_level,
		"total_active_particles": total_active_particles,
		"total_active_audio_sources": total_active_audio_sources,
		"total_active_effects": total_active_effects,
		"memory_usage_mb": memory_usage_mb,
		"culling_stats": culling_stats,
		"auto_adjust_enabled": auto_adjust_performance
	}

## Setup performance manager
func _setup_performance_manager() -> void:
	frame_times.clear()
	culling_stats.clear()
	performance_history.clear()
	
	# Initialize culling statistics
	culling_stats = {
		"particles_culled": 0,
		"audio_culled": 0,
		"effects_culled": 0,
		"distance_culled": 0,
		"performance_culled": 0
	}
	
	# Set initial timers
	performance_update_timer = 0.0
	lod_update_timer = 0.0
	culling_update_timer = 0.0

## Initialize performance monitoring
func _initialize_performance_monitoring() -> void:
	# Pre-populate frame times with target FPS
	for i in range(performance_samples):
		frame_times.append(1.0 / target_fps)

## Apply performance level settings
func _apply_performance_level(level: PerformanceLevel) -> void:
	var limits = effect_limits[level]
	
	# Apply limits to weapon impact manager
	if weapon_impact_manager:
		weapon_impact_manager.max_simultaneous_impacts = limits["max_impacts"]
		weapon_impact_manager.particle_count_scale = limits["particle_scale"]
	
	# Apply limits to explosion system
	if explosion_system:
		weapon_impact_manager.max_simultaneous_impacts = limits["max_explosions"]
	
	# Apply limits to audio manager
	if combat_audio_manager:
		combat_audio_manager.max_simultaneous_audio_sources = limits["max_audio_sources"]
	
	# Apply particle scaling to all systems
	_apply_particle_scaling(limits["particle_scale"])
	
	# Apply duration scaling
	_apply_duration_scaling(limits["effect_duration_scale"])

## Apply particle scaling to all effect systems
func _apply_particle_scaling(scale_factor: float) -> void:
	# This would scale particle counts across all effect systems
	if weapon_impact_manager:
		weapon_impact_manager.particle_count_scale = scale_factor
	
	if environmental_effects:
		environmental_effects.debris_density *= scale_factor

## Apply duration scaling to all effect systems
func _apply_duration_scaling(duration_scale: float) -> void:
	# This would scale effect durations across all systems
	if weapon_impact_manager:
		weapon_impact_manager.impact_effect_duration *= duration_scale
	
	if explosion_system:
		explosion_system.fireball_duration *= duration_scale

## Update performance monitoring
func _update_performance_monitoring() -> void:
	# Calculate current FPS
	var current_frame_time = get_process_delta_time()
	frame_times.append(current_frame_time)
	
	if frame_times.size() > performance_samples:
		frame_times.remove_at(0)
	
	# Calculate average FPS
	var average_frame_time = 0.0
	for frame_time in frame_times:
		average_frame_time += frame_time
	average_frame_time /= frame_times.size()
	
	current_fps = 1.0 / average_frame_time
	
	# Update effect counts
	_update_effect_counts()
	
	# Update memory usage estimate
	_update_memory_usage()
	
	# Check for performance issues
	_check_performance_thresholds()
	
	# Auto-adjust performance if enabled
	if auto_adjust_performance and performance_adjustment_enabled:
		_auto_adjust_performance_level()

## Update effect counts from all systems
func _update_effect_counts() -> void:
	total_active_particles = 0
	total_active_audio_sources = 0
	total_active_effects = 0
	
	# Count particles from weapon impacts
	if weapon_impact_manager:
		total_active_effects += weapon_impact_manager.active_impact_effects.size()
	
	# Count particles from explosions
	if explosion_system:
		total_active_effects += explosion_system.active_explosions.size()
	
	# Count audio sources
	if combat_audio_manager:
		total_active_audio_sources = combat_audio_manager.active_audio_sources.size()
	
	# Count environmental effects
	if environmental_effects:
		total_active_effects += environmental_effects.active_space_debris.size()
		total_active_effects += environmental_effects.active_energy_discharges.size()

## Update memory usage estimate
func _update_memory_usage() -> void:
	# Rough estimate of memory usage based on active effects
	var particle_memory = total_active_particles * 0.1  # 0.1 KB per particle
	var audio_memory = total_active_audio_sources * 2.0  # 2 MB per audio source
	var effect_memory = total_active_effects * 0.5      # 0.5 KB per effect
	
	memory_usage_mb = particle_memory + audio_memory + effect_memory

## Check performance thresholds
func _check_performance_thresholds() -> void:
	# FPS warnings
	if current_fps < fps_critical_threshold:
		performance_warning.emit("fps_critical", fps_critical_threshold - current_fps)
	elif current_fps < fps_warning_threshold:
		performance_warning.emit("fps_warning", fps_warning_threshold - current_fps)
	
	# Memory warnings
	if memory_usage_mb > memory_warning_threshold:
		performance_warning.emit("memory_warning", memory_usage_mb - memory_warning_threshold)
	
	# Particle count warnings
	if total_active_particles > particle_warning_threshold:
		performance_warning.emit("particle_warning", total_active_particles - particle_warning_threshold)

## Auto-adjust performance level
func _auto_adjust_performance_level() -> void:
	var target_level = current_performance_level
	
	# Reduce quality if performance is poor
	if current_fps < fps_critical_threshold and current_performance_level > PerformanceLevel.POTATO:
		target_level = current_performance_level - 1
		
	elif current_fps < fps_warning_threshold and current_performance_level > PerformanceLevel.LOW:
		# Only reduce if consistently poor performance
		if _is_consistently_poor_performance():
			target_level = current_performance_level - 1
	
	# Increase quality if performance is good
	elif current_fps > target_fps + 10.0 and current_performance_level < PerformanceLevel.ULTRA:
		# Only increase if consistently good performance
		if _is_consistently_good_performance():
			target_level = current_performance_level + 1
	
	# Apply change if needed
	if target_level != current_performance_level:
		set_performance_level(target_level, false)
		
		if debug_performance_logging:
			print("EffectPerformanceManager: Auto-adjusted performance level to %d (FPS: %.1f)" % [
				target_level, current_fps
			])

## Check for consistently poor performance
func _is_consistently_poor_performance() -> bool:
	if performance_history.size() < 5:
		return false
	
	var poor_count = 0
	for history_entry in performance_history.slice(-5):
		if history_entry.get("fps", 60.0) < fps_warning_threshold:
			poor_count += 1
	
	return poor_count >= 4

## Check for consistently good performance
func _is_consistently_good_performance() -> bool:
	if performance_history.size() < 10:
		return false
	
	var good_count = 0
	for history_entry in performance_history.slice(-10):
		if history_entry.get("fps", 60.0) > target_fps + 5.0:
			good_count += 1
	
	return good_count >= 8

## Update LOD levels based on distance
func _update_lod_levels() -> void:
	if not enable_automatic_lod or not camera_node:
		return
	
	# Update weapon impact LOD
	_update_weapon_impact_lod()
	
	# Update explosion LOD
	_update_explosion_lod()
	
	# Update audio LOD
	_update_audio_lod()
	
	# Update environmental effect LOD
	_update_environmental_lod()

## Update weapon impact LOD
func _update_weapon_impact_lod() -> void:
	if not weapon_impact_manager:
		return
	
	# Adjust particle counts based on distance
	for effect in weapon_impact_manager.active_impact_effects:
		if effect and is_instance_valid(effect):
			var distance = effect.global_position.distance_to(current_camera_position)
			var lod_level = _get_lod_level_for_distance(distance)
			_apply_weapon_impact_lod(effect, lod_level)

## Update explosion LOD
func _update_explosion_lod() -> void:
	if not explosion_system:
		return
	
	for explosion in explosion_system.active_explosions:
		if explosion and is_instance_valid(explosion):
			var distance = explosion.global_position.distance_to(current_camera_position)
			var lod_level = _get_lod_level_for_distance(distance)
			_apply_explosion_lod(explosion, lod_level)

## Update audio LOD
func _update_audio_lod() -> void:
	if not combat_audio_manager:
		return
	
	for audio_source in combat_audio_manager.active_audio_sources:
		if audio_source and is_instance_valid(audio_source):
			var distance = audio_source.global_position.distance_to(current_camera_position)
			var lod_level = _get_audio_lod_level_for_distance(distance)
			_apply_audio_lod(audio_source, lod_level)

## Update environmental effect LOD
func _update_environmental_lod() -> void:
	if not environmental_effects:
		return
	
	# Cull distant environmental effects
	_cull_distant_environmental_effects()

## Get LOD level for distance
func _get_lod_level_for_distance(distance: float) -> int:
	for i in range(lod_distance_thresholds.size()):
		if distance < lod_distance_thresholds[i]:
			return i
	return lod_distance_thresholds.size()

## Get audio LOD level for distance
func _get_audio_lod_level_for_distance(distance: float) -> int:
	for i in range(audio_lod_thresholds.size()):
		if distance < audio_lod_thresholds[i]:
			return i
	return audio_lod_thresholds.size()

## Apply LOD to specific effects
func _apply_weapon_impact_lod(effect: Node3D, lod_level: int) -> void:
	# Reduce particle counts based on LOD level
	for child in effect.get_children():
		if child is GPUParticles3D:
			var particles = child as GPUParticles3D
			var base_amount = particles.amount
			
			match lod_level:
				0, 1:  # Close - full quality
					pass
				2:     # Medium distance - 75%
					particles.amount = int(base_amount * 0.75)
				3:     # Far - 50%
					particles.amount = int(base_amount * 0.5)
				4:     # Very far - 25%
					particles.amount = int(base_amount * 0.25)
				_:     # Extremely far - minimal
					particles.amount = int(base_amount * 0.1)

func _apply_explosion_lod(explosion: Node3D, lod_level: int) -> void:
	# Similar to weapon impact LOD but with different scaling
	for child in explosion.get_children():
		if child is GPUParticles3D:
			var particles = child as GPUParticles3D
			var base_amount = particles.amount
			
			match lod_level:
				0:     # Close - full quality
					pass
				1:     # Near - 90%
					particles.amount = int(base_amount * 0.9)
				2:     # Medium - 70%
					particles.amount = int(base_amount * 0.7)
				3:     # Far - 40%
					particles.amount = int(base_amount * 0.4)
				_:     # Very far - 20%
					particles.amount = int(base_amount * 0.2)

func _apply_audio_lod(audio_source: AudioStreamPlayer3D, lod_level: int) -> void:
	# Adjust audio quality and volume based on distance
	match lod_level:
		0:     # Close - full quality
			audio_source.pitch_scale = 1.0
		1:     # Near - slight reduction
			audio_source.pitch_scale = 1.0
		2:     # Medium - reduced quality
			audio_source.volume_db -= 3.0
		3:     # Far - heavily reduced
			audio_source.volume_db -= 6.0
		_:     # Very far - minimal/mute
			audio_source.volume_db = -80.0

## Cull distant environmental effects
func _cull_distant_environmental_effects() -> void:
	if not environmental_effects:
		return
	
	var culling_distance = lod_distance_thresholds[-1]  # Use largest threshold
	var culled_count = 0
	
	# Cull distant debris
	var debris_to_remove: Array[RigidBody3D] = []
	for debris in environmental_effects.active_space_debris:
		if debris and is_instance_valid(debris):
			var distance = debris.global_position.distance_to(current_camera_position)
			if distance > culling_distance:
				debris_to_remove.append(debris)
	
	for debris in debris_to_remove:
		environmental_effects.active_space_debris.erase(debris)
		debris.queue_free()
		culled_count += 1
	
	if culled_count > 0:
		culling_stats["distance_culled"] += culled_count
		effect_culled.emit("environmental_debris", culled_count)

## Perform distance culling
func _perform_distance_culling() -> void:
	if not enable_distance_culling:
		return
	
	# Cull weapon impacts
	_cull_distant_weapon_impacts()
	
	# Cull explosions
	_cull_distant_explosions()
	
	# Cull audio sources
	_cull_distant_audio()

## Cull distant weapon impacts
func _cull_distant_weapon_impacts() -> void:
	if not weapon_impact_manager:
		return
	
	var culling_distance = weapon_impact_manager.effect_culling_distance
	var culled_count = 0
	
	var effects_to_remove: Array[Node3D] = []
	for effect in weapon_impact_manager.active_impact_effects:
		if effect and is_instance_valid(effect):
			var distance = effect.global_position.distance_to(current_camera_position)
			if distance > culling_distance:
				effects_to_remove.append(effect)
	
	for effect in effects_to_remove:
		weapon_impact_manager.active_impact_effects.erase(effect)
		effect.queue_free()
		culled_count += 1
	
	if culled_count > 0:
		culling_stats["effects_culled"] += culled_count
		effect_culled.emit("weapon_impacts", culled_count)

## Cull distant explosions
func _cull_distant_explosions() -> void:
	if not explosion_system:
		return
	
	var culling_distance = 400.0  # Explosions have longer visibility
	var culled_count = 0
	
	var explosions_to_remove: Array[Node3D] = []
	for explosion in explosion_system.active_explosions:
		if explosion and is_instance_valid(explosion):
			var distance = explosion.global_position.distance_to(current_camera_position)
			if distance > culling_distance:
				explosions_to_remove.append(explosion)
	
	for explosion in explosions_to_remove:
		explosion_system.active_explosions.erase(explosion)
		explosion.queue_free()
		culled_count += 1
	
	if culled_count > 0:
		culling_stats["effects_culled"] += culled_count
		effect_culled.emit("explosions", culled_count)

## Cull distant audio
func _cull_distant_audio() -> void:
	if not combat_audio_manager:
		return
	
	var culling_distance = combat_audio_manager.audio_culling_distance
	var culled_count = 0
	
	var audio_to_stop: Array[AudioStreamPlayer3D] = []
	for audio_source in combat_audio_manager.active_audio_sources:
		if audio_source and is_instance_valid(audio_source):
			var distance = audio_source.global_position.distance_to(current_camera_position)
			if distance > culling_distance:
				audio_to_stop.append(audio_source)
	
	for audio_source in audio_to_stop:
		audio_source.stop()
		combat_audio_manager.active_audio_sources.erase(audio_source)
		culled_count += 1
	
	if culled_count > 0:
		culling_stats["audio_culled"] += culled_count
		effect_culled.emit("audio", culled_count)

## Process frame updates
func _process(delta: float) -> void:
	performance_update_timer += delta
	lod_update_timer += delta
	culling_update_timer += delta
	
	# Update performance monitoring
	if performance_update_timer >= performance_update_frequency:
		performance_update_timer = 0.0
		_update_performance_monitoring()
		
		# Store performance history
		performance_history.append({
			"fps": current_fps,
			"particles": total_active_particles,
			"effects": total_active_effects,
			"memory": memory_usage_mb,
			"timestamp": Time.get_ticks_msec() / 1000.0
		})
		
		# Limit history size
		if performance_history.size() > 60:  # Keep 30 seconds of history
			performance_history.remove_at(0)
	
	# Update LOD levels
	if lod_update_timer >= 0.2:  # Update LOD every 0.2 seconds
		lod_update_timer = 0.0
		_update_lod_levels()
	
	# Perform distance culling
	if culling_update_timer >= 1.0:  # Cull every second
		culling_update_timer = 0.0
		_perform_distance_culling()