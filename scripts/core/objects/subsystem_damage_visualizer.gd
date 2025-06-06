class_name SubsystemDamageVisualizer
extends Node

## Subsystem damage state visualization with animation integration
## Provides visual feedback for subsystem health states including smoke, sparks, and disabled animations
## Integrates with AC6 effects system for appropriate visual feedback

# EPIC-008 Graphics Integration
var graphics_engine: Node = null
var effects_manager: Node = null

# Damage visualization signals
signal damage_effect_created(subsystem_name: String, effect_type: String, intensity: float)
signal damage_effect_updated(subsystem_name: String, effect_type: String, new_intensity: float)
signal damage_effect_removed(subsystem_name: String, effect_type: String)

# Damage effect types
enum DamageEffectType {
	SMOKE,
	SPARKS,
	FIRE,
	ELECTRICAL_ARCS,
	COOLANT_LEAK,
	DEBRIS_SHOWER
}

# Visual effect intensity levels based on damage percentage
var _damage_effect_thresholds: Dictionary = {
	0.25: {  # Light damage (75% health remaining)
		"effects": [DamageEffectType.SPARKS],
		"intensity": 0.3,
		"animation_degradation": 0.1
	},
	0.50: {  # Moderate damage (50% health remaining)
		"effects": [DamageEffectType.SMOKE, DamageEffectType.SPARKS],
		"intensity": 0.6,
		"animation_degradation": 0.3
	},
	0.75: {  # Heavy damage (25% health remaining)
		"effects": [DamageEffectType.SMOKE, DamageEffectType.FIRE, DamageEffectType.ELECTRICAL_ARCS],
		"intensity": 0.8,
		"animation_degradation": 0.6
	},
	0.90: {  # Critical damage (10% health remaining)
		"effects": [DamageEffectType.SMOKE, DamageEffectType.FIRE, DamageEffectType.ELECTRICAL_ARCS, DamageEffectType.COOLANT_LEAK],
		"intensity": 1.0,
		"animation_degradation": 0.9
	}
}

# Active damage effects registry
var _active_effects: Dictionary = {}  # subsystem_name -> Array[EffectData]
var _subsystem_integration: Node = null
var _animation_controller: Node = null

## Damage effect data structure
class EffectData:
	var effect_type: DamageEffectType
	var effect_node: Node3D
	var intensity: float
	var particles: GPUParticles3D
	var audio: AudioStreamPlayer3D
	var duration: float = -1.0  # -1 for permanent, >0 for timed effects
	var start_time: float

func _ready() -> void:
	name = "SubsystemDamageVisualizer"
	_initialize_systems_integration()
	_connect_subsystem_signals()

## Initialize integration with graphics and effects systems (AC6)
func _initialize_systems_integration() -> void:
	# EPIC-008 Graphics engine integration
	graphics_engine = get_node_or_null("/root/GraphicsRenderingEngine")
	if graphics_engine:
		effects_manager = graphics_engine.find_child("EffectsManager", false, false)
		print("SubsystemDamageVisualizer: Integrated with EPIC-008 Graphics and Effects")
	
	# Find subsystem integration
	_subsystem_integration = get_parent().find_child("ModelSubsystemIntegration", false, false)
	
	# Find animation controller
	_animation_controller = get_parent().find_child("SubsystemAnimationController", false, false)

## Connect to subsystem damage signals
func _connect_subsystem_signals() -> void:
	if _subsystem_integration:
		_subsystem_integration.subsystem_damage_applied.connect(_on_subsystem_damage_applied)
		_subsystem_integration.subsystem_destroyed.connect(_on_subsystem_destroyed)
		_subsystem_integration.subsystem_repaired.connect(_on_subsystem_repaired)

## Handle subsystem damage application (AC3)
func _on_subsystem_damage_applied(space_object: BaseSpaceObject, subsystem_name: String, damage_percentage: float) -> void:
	# Update visual damage effects
	_update_damage_effects(space_object, subsystem_name, damage_percentage)
	
	# Apply animation degradation based on damage
	_apply_animation_degradation(space_object, subsystem_name, damage_percentage)

## Handle subsystem destruction
func _on_subsystem_destroyed(space_object: BaseSpaceObject, subsystem_name: String) -> void:
	# Create destruction effect
	_create_destruction_effect(space_object, subsystem_name)
	
	# Disable all animations for destroyed subsystem
	if _animation_controller:
		_animation_controller.stop_subsystem_animations(subsystem_name)

## Handle subsystem repair
func _on_subsystem_repaired(space_object: BaseSpaceObject, subsystem_name: String) -> void:
	# Remove all damage effects
	_clear_damage_effects(subsystem_name)
	
	# Restore animation capabilities
	_restore_animation_capabilities(space_object, subsystem_name)

## Update damage effects based on damage percentage (AC3, AC6)
func _update_damage_effects(space_object: BaseSpaceObject, subsystem_name: String, damage_percentage: float) -> void:
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if not subsystem:
		return
	
	# Clear existing effects
	_clear_damage_effects(subsystem_name)
	
	# Determine appropriate damage effect level
	var effect_config: Dictionary = _get_damage_effect_config(damage_percentage)
	if effect_config.is_empty():
		return
	
	# Create new damage effects
	var effects_array: Array[EffectData] = []
	
	for effect_type in effect_config["effects"]:
		var effect_data: EffectData = _create_damage_effect(subsystem, effect_type, effect_config["intensity"])
		if effect_data:
			effects_array.append(effect_data)
	
	if effects_array.size() > 0:
		_active_effects[subsystem_name] = effects_array

## Get damage effect configuration for damage percentage
func _get_damage_effect_config(damage_percentage: float) -> Dictionary:
	var threshold_keys: Array = _damage_effect_thresholds.keys()
	threshold_keys.sort()
	
	for threshold in threshold_keys:
		if damage_percentage >= threshold:
			return _damage_effect_thresholds[threshold]
	
	return {}  # No damage effects for low damage

## Create individual damage effect
func _create_damage_effect(subsystem: Node3D, effect_type: DamageEffectType, intensity: float) -> EffectData:
	var effect_data: EffectData = EffectData.new()
	effect_data.effect_type = effect_type
	effect_data.intensity = intensity
	effect_data.start_time = Time.get_time_dict_from_system()["msec"] / 1000.0
	
	# Create effect container node
	var effect_container: Node3D = Node3D.new()
	effect_container.name = "DamageEffect_%s" % _effect_type_to_string(effect_type)
	subsystem.add_child(effect_container)
	effect_data.effect_node = effect_container
	
	# Create particle system for effect
	effect_data.particles = _create_effect_particles(effect_type, intensity)
	effect_container.add_child(effect_data.particles)
	
	# Create audio for effect
	effect_data.audio = _create_effect_audio(effect_type, intensity)
	if effect_data.audio:
		effect_container.add_child(effect_data.audio)
	
	# Emit signal for effect creation
	damage_effect_created.emit(subsystem.name, _effect_type_to_string(effect_type), intensity)
	
	return effect_data

## Create particle system for specific damage effect type
func _create_effect_particles(effect_type: DamageEffectType, intensity: float) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Particles"
	particles.emitting = true
	
	# Configure based on effect type
	match effect_type:
		DamageEffectType.SMOKE:
			_configure_smoke_particles(particles, intensity)
		DamageEffectType.SPARKS:
			_configure_sparks_particles(particles, intensity)
		DamageEffectType.FIRE:
			_configure_fire_particles(particles, intensity)
		DamageEffectType.ELECTRICAL_ARCS:
			_configure_electrical_particles(particles, intensity)
		DamageEffectType.COOLANT_LEAK:
			_configure_coolant_particles(particles, intensity)
		DamageEffectType.DEBRIS_SHOWER:
			_configure_debris_particles(particles, intensity)
	
	return particles

## Configure smoke particle effect
func _configure_smoke_particles(particles: GPUParticles3D, intensity: float) -> void:
	particles.amount = int(50 * intensity)
	particles.lifetime = 3.0 + (intensity * 2.0)
	particles.emission_rate_over_time = particles.amount / 2.0
	
	# Create smoke material (if available through EPIC-008)
	if effects_manager and effects_manager.has_method("get_smoke_material"):
		var smoke_material = effects_manager.get_smoke_material()
		if smoke_material:
			particles.material_override = smoke_material

## Configure sparks particle effect
func _configure_sparks_particles(particles: GPUParticles3D, intensity: float) -> void:
	particles.amount = int(25 * intensity)
	particles.lifetime = 0.5 + (intensity * 0.5)
	particles.emission_rate_over_time = particles.amount * 2.0
	
	# Sparks should have burst emission pattern
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.gravity = Vector3(0, -9.8, 0)
	process_material.initial_velocity_min = 2.0 * intensity
	process_material.initial_velocity_max = 5.0 * intensity
	particles.process_material = process_material

## Configure fire particle effect
func _configure_fire_particles(particles: GPUParticles3D, intensity: float) -> void:
	particles.amount = int(75 * intensity)
	particles.lifetime = 2.0 + (intensity * 1.5)
	particles.emission_rate_over_time = particles.amount / 1.5
	
	# Fire should move upward
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.gravity = Vector3(0, -2.0, 0)  # Reduced gravity for fire
	process_material.initial_velocity_min = 1.0
	process_material.initial_velocity_max = 3.0
	particles.process_material = process_material

## Configure electrical arc particle effect
func _configure_electrical_particles(particles: GPUParticles3D, intensity: float) -> void:
	particles.amount = int(30 * intensity)
	particles.lifetime = 0.2 + (intensity * 0.3)
	particles.emission_rate_over_time = particles.amount * 3.0
	
	# Electrical arcs should be intermittent
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.initial_velocity_min = 0.5
	process_material.initial_velocity_max = 2.0
	particles.process_material = process_material

## Configure coolant leak particle effect
func _configure_coolant_particles(particles: GPUParticles3D, intensity: float) -> void:
	particles.amount = int(40 * intensity)
	particles.lifetime = 4.0
	particles.emission_rate_over_time = particles.amount / 3.0
	
	# Coolant should fall due to gravity
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.gravity = Vector3(0, -15.0, 0)  # Strong gravity for liquid
	process_material.initial_velocity_min = 0.5
	process_material.initial_velocity_max = 1.5
	particles.process_material = process_material

## Configure debris shower particle effect
func _configure_debris_particles(particles: GPUParticles3D, intensity: float) -> void:
	particles.amount = int(60 * intensity)
	particles.lifetime = 5.0 + (intensity * 3.0)
	particles.emission_rate_over_time = particles.amount / 4.0
	
	# Debris should scatter in all directions
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.gravity = Vector3(0, -9.8, 0)
	process_material.initial_velocity_min = 1.0 * intensity
	process_material.initial_velocity_max = 4.0 * intensity
	particles.process_material = process_material

## Create audio for damage effects
func _create_effect_audio(effect_type: DamageEffectType, intensity: float) -> AudioStreamPlayer3D:
	# Only create audio for certain effect types to avoid audio clutter
	if effect_type not in [DamageEffectType.SPARKS, DamageEffectType.ELECTRICAL_ARCS, DamageEffectType.FIRE]:
		return null
	
	var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio.name = "Audio"
	audio.volume_db = -10.0 + (intensity * 5.0)  # Louder for more damage
	audio.max_distance = 50.0
	
	# Configure audio based on effect type
	match effect_type:
		DamageEffectType.SPARKS:
			# Intermittent crackling sound
			audio.autoplay = true
		DamageEffectType.ELECTRICAL_ARCS:
			# Electrical buzzing sound
			audio.autoplay = true
		DamageEffectType.FIRE:
			# Continuous burning sound
			audio.autoplay = true
	
	return audio

## Apply animation degradation based on damage (AC3)
func _apply_animation_degradation(space_object: BaseSpaceObject, subsystem_name: String, damage_percentage: float) -> void:
	if not _animation_controller:
		return
	
	var effect_config: Dictionary = _get_damage_effect_config(damage_percentage)
	if effect_config.is_empty():
		return
	
	var degradation_factor: float = effect_config.get("animation_degradation", 0.0)
	
	# Apply degradation to subsystem animation capabilities
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if subsystem:
		# Reduce animation speed
		var original_speed: Vector3 = subsystem.get_meta("rotation_speed", Vector3(90, 90, 90))
		var degraded_speed: Vector3 = original_speed * (1.0 - degradation_factor)
		subsystem.set_meta("current_rotation_speed", degraded_speed)
		
		# Reduce animation accuracy (add jitter for damaged subsystems)
		subsystem.set_meta("animation_jitter", degradation_factor * 0.1)  # Up to 0.1 radian jitter
		
		# Mark as degraded for animation controller
		subsystem.set_meta("animation_degraded", degradation_factor > 0.1)

## Create destruction effect for destroyed subsystem
func _create_destruction_effect(space_object: BaseSpaceObject, subsystem_name: String) -> void:
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if not subsystem:
		return
	
	# Create large explosion effect
	var explosion_particles: GPUParticles3D = GPUParticles3D.new()
	explosion_particles.name = "DestructionExplosion"
	explosion_particles.emitting = true
	explosion_particles.amount = 200
	explosion_particles.lifetime = 3.0
	explosion_particles.one_shot = true
	
	# Configure explosion particles
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.gravity = Vector3(0, -5.0, 0)
	process_material.initial_velocity_min = 5.0
	process_material.initial_velocity_max = 15.0
	explosion_particles.process_material = process_material
	
	# Add to space object (not subsystem) so it persists after subsystem is hidden
	space_object.add_child(explosion_particles)
	explosion_particles.global_position = subsystem.global_position
	
	# Auto-remove after effect duration
	var timer: Timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(explosion_particles.queue_free)
	explosion_particles.add_child(timer)
	timer.start()
	
	# Emit destruction effect signal
	damage_effect_created.emit(subsystem_name, "destruction", 1.0)

## Clear all damage effects for subsystem
func _clear_damage_effects(subsystem_name: String) -> void:
	if subsystem_name not in _active_effects:
		return
	
	var effects_array: Array[EffectData] = _active_effects[subsystem_name]
	
	for effect_data in effects_array:
		if is_instance_valid(effect_data.effect_node):
			effect_data.effect_node.queue_free()
		
		damage_effect_removed.emit(subsystem_name, _effect_type_to_string(effect_data.effect_type))
	
	_active_effects.erase(subsystem_name)

## Restore animation capabilities after repair
func _restore_animation_capabilities(space_object: BaseSpaceObject, subsystem_name: String) -> void:
	var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
	if not subsystem:
		return
	
	# Restore original animation speeds
	if subsystem.has_meta("rotation_speed"):
		subsystem.set_meta("current_rotation_speed", subsystem.get_meta("rotation_speed"))
	
	# Remove animation degradation
	subsystem.set_meta("animation_jitter", 0.0)
	subsystem.set_meta("animation_degraded", false)

## Update effect intensity for existing effects
func update_effect_intensity(subsystem_name: String, effect_type: DamageEffectType, new_intensity: float) -> void:
	if subsystem_name not in _active_effects:
		return
	
	var effects_array: Array[EffectData] = _active_effects[subsystem_name]
	
	for effect_data in effects_array:
		if effect_data.effect_type == effect_type:
			effect_data.intensity = new_intensity
			
			# Update particle system
			if effect_data.particles:
				var base_amount: int = 50  # Base amount varies by effect type
				effect_data.particles.amount = int(base_amount * new_intensity)
			
			# Update audio volume
			if effect_data.audio:
				effect_data.audio.volume_db = -10.0 + (new_intensity * 5.0)
			
			damage_effect_updated.emit(subsystem_name, _effect_type_to_string(effect_type), new_intensity)
			break

## Find subsystem by name in space object
func _find_subsystem(space_object: BaseSpaceObject, subsystem_name: String) -> Node3D:
	var subsystems_container: Node = space_object.find_child("Subsystems", false, false)
	if not subsystems_container:
		return null
	
	return subsystems_container.find_child(subsystem_name, false, false) as Node3D

## Convert effect type enum to string
func _effect_type_to_string(effect_type: DamageEffectType) -> String:
	match effect_type:
		DamageEffectType.SMOKE: return "smoke"
		DamageEffectType.SPARKS: return "sparks"
		DamageEffectType.FIRE: return "fire"
		DamageEffectType.ELECTRICAL_ARCS: return "electrical_arcs"
		DamageEffectType.COOLANT_LEAK: return "coolant_leak"
		DamageEffectType.DEBRIS_SHOWER: return "debris_shower"
		_: return "unknown"

## Get active damage effects for subsystem
func get_active_effects(subsystem_name: String) -> Array[Dictionary]:
	var effects_info: Array[Dictionary] = []
	
	if subsystem_name in _active_effects:
		var effects_array: Array[EffectData] = _active_effects[subsystem_name]
		
		for effect_data in effects_array:
			effects_info.append({
				"type": _effect_type_to_string(effect_data.effect_type),
				"intensity": effect_data.intensity,
				"duration": effect_data.duration,
				"elapsed_time": Time.get_time_dict_from_system()["msec"] / 1000.0 - effect_data.start_time
			})
	
	return effects_info

## Get damage visualization statistics
func get_damage_visualization_stats() -> Dictionary:
	var total_effects: int = 0
	var subsystems_with_effects: int = 0
	
	for subsystem_name in _active_effects.keys():
		subsystems_with_effects += 1
		total_effects += _active_effects[subsystem_name].size()
	
	return {
		"total_active_effects": total_effects,
		"subsystems_with_effects": subsystems_with_effects,
		"effect_types_available": DamageEffectType.size(),
		"graphics_engine_connected": graphics_engine != null,
		"effects_manager_connected": effects_manager != null
	}