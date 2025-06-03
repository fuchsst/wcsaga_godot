class_name WCSEffectPool
extends Node

## Efficient effect pooling system for visual effects
## Provides pre-allocated effect nodes to avoid runtime allocation overhead

signal pool_exhausted()
signal effect_returned(effect_node: Node3D)
signal pool_expanded(new_size: int)

var effect_type: WCSEffectsManager.EffectType
var pool_size: int
var available_effects: Array[Node3D] = []
var active_effects: Array[Node3D] = []
var total_created: int = 0

func _init(eff_type: WCSEffectsManager.EffectType, size: int) -> void:
	effect_type = eff_type
	pool_size = size
	_initialize_pool()

func _ready() -> void:
	name = "EffectPool_" + WCSEffectsManager.EffectType.keys()[effect_type]
	print("WCSEffectPool: Initialized %s pool with %d effects" % [
		WCSEffectsManager.EffectType.keys()[effect_type], pool_size
	])

func _initialize_pool() -> void:
	# Pre-create effects for the pool
	for i in range(pool_size):
		var effect_node: Node3D = _create_effect_node()
		if effect_node:
			effect_node.visible = false
			available_effects.append(effect_node)
			total_created += 1

func _create_effect_node() -> Node3D:
	var effect_node: Node3D
	
	match effect_type:
		WCSEffectsManager.EffectType.WEAPON_MUZZLE_FLASH, \
		WCSEffectsManager.EffectType.WEAPON_IMPACT_SPARKS, \
		WCSEffectsManager.EffectType.EXPLOSION_SMALL, \
		WCSEffectsManager.EffectType.EXPLOSION_MEDIUM, \
		WCSEffectsManager.EffectType.EXPLOSION_LARGE, \
		WCSEffectsManager.EffectType.EXPLOSION_CAPITAL, \
		WCSEffectsManager.EffectType.EXPLOSION_ASTEROID, \
		WCSEffectsManager.EffectType.ENGINE_EXHAUST, \
		WCSEffectsManager.EffectType.ENGINE_AFTERBURNER, \
		WCSEffectsManager.EffectType.THRUSTER_TRAIL, \
		WCSEffectsManager.EffectType.SHIELD_IMPACT, \
		WCSEffectsManager.EffectType.SHIELD_OVERLOAD, \
		WCSEffectsManager.EffectType.ENVIRONMENT_SPACE_DUST, \
		WCSEffectsManager.EffectType.ENVIRONMENT_NEBULA, \
		WCSEffectsManager.EffectType.ENVIRONMENT_DEBRIS:
			# Particle-based effects
			effect_node = _create_particle_effect_node()
		
		WCSEffectsManager.EffectType.WEAPON_LASER_BEAM:
			# Mesh-based laser beam
			effect_node = _create_laser_beam_node()
		
		WCSEffectsManager.EffectType.WEAPON_PLASMA_BOLT:
			# Plasma bolt with particles and mesh
			effect_node = _create_plasma_bolt_node()
		
		WCSEffectsManager.EffectType.WEAPON_MISSILE_TRAIL:
			# Missile trail effect
			effect_node = _create_missile_trail_node()
		
		_:
			# Default to particle effect
			effect_node = _create_particle_effect_node()
	
	if effect_node:
		effect_node.name = "PooledEffect_" + WCSEffectsManager.EffectType.keys()[effect_type]
	
	return effect_node

func _create_particle_effect_node() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	
	# Basic configuration based on effect type
	match effect_type:
		WCSEffectsManager.EffectType.EXPLOSION_SMALL:
			_configure_explosion_base(particles, material, 100)
		WCSEffectsManager.EffectType.EXPLOSION_MEDIUM:
			_configure_explosion_base(particles, material, 200)
		WCSEffectsManager.EffectType.EXPLOSION_LARGE:
			_configure_explosion_base(particles, material, 350)
		WCSEffectsManager.EffectType.EXPLOSION_CAPITAL:
			_configure_explosion_base(particles, material, 500)
		WCSEffectsManager.EffectType.EXPLOSION_ASTEROID:
			_configure_asteroid_explosion_base(particles, material, 150)
		WCSEffectsManager.EffectType.WEAPON_MUZZLE_FLASH:
			_configure_muzzle_flash_base(particles, material)
		WCSEffectsManager.EffectType.WEAPON_IMPACT_SPARKS:
			_configure_impact_sparks_base(particles, material)
		WCSEffectsManager.EffectType.ENGINE_EXHAUST:
			_configure_engine_exhaust_base(particles, material)
		WCSEffectsManager.EffectType.ENGINE_AFTERBURNER:
			_configure_afterburner_base(particles, material)
		WCSEffectsManager.EffectType.THRUSTER_TRAIL:
			_configure_thruster_base(particles, material)
		WCSEffectsManager.EffectType.SHIELD_IMPACT:
			_configure_shield_impact_base(particles, material)
		WCSEffectsManager.EffectType.ENVIRONMENT_SPACE_DUST:
			_configure_space_dust_base(particles, material)
		_:
			_configure_generic_base(particles, material)
	
	particles.process_material = material
	particles.emitting = false  # Will be enabled when used
	
	return particles

func _configure_explosion_base(particles: GPUParticles3D, material: ParticleProcessMaterial, amount: int) -> void:
	particles.amount = amount
	particles.lifetime = 3.0
	
	material.emission = ParticleProcessMaterial.EMISSION_SPHERE
	material.emission_sphere_radius = 1.0
	
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 25.0
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	
	material.scale_min = 0.3
	material.scale_max = 1.5
	
	material.gravity = Vector3(0, -2.0, 0)  # Light gravity for space
	material.damping_min = 0.1
	material.damping_max = 0.3

func _configure_asteroid_explosion_base(particles: GPUParticles3D, material: ParticleProcessMaterial, amount: int) -> void:
	_configure_explosion_base(particles, material, amount)
	
	# Asteroid-specific modifications
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, -1.0, 0)  # Even lighter for asteroid debris

func _configure_muzzle_flash_base(particles: GPUParticles3D, material: ParticleProcessMaterial) -> void:
	particles.amount = 50
	particles.lifetime = 0.2
	
	material.emission = ParticleProcessMaterial.EMISSION_SPHERE
	material.emission_sphere_radius = 0.5
	
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 30.0
	
	material.scale_min = 0.1
	material.scale_max = 0.5

func _configure_impact_sparks_base(particles: GPUParticles3D, material: ParticleProcessMaterial) -> void:
	particles.amount = 75
	particles.lifetime = 0.5
	
	material.emission = ParticleProcessMaterial.EMISSION_SPHERE
	material.emission_sphere_radius = 0.3
	
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 20.0
	
	material.scale_min = 0.05
	material.scale_max = 0.3
	
	material.gravity = Vector3(0, -5.0, 0)

func _configure_engine_exhaust_base(particles: GPUParticles3D, material: ParticleProcessMaterial) -> void:
	particles.amount = 150
	particles.lifetime = 2.0
	
	material.emission = ParticleProcessMaterial.EMISSION_BOX
	material.emission_box_extents = Vector3(0.2, 0.2, 0.1)
	
	material.direction = Vector3(0, 0, -1)
	material.initial_velocity_min = 15.0
	material.initial_velocity_max = 25.0
	
	material.scale_min = 0.2
	material.scale_max = 0.8

func _configure_afterburner_base(particles: GPUParticles3D, material: ParticleProcessMaterial) -> void:
	_configure_engine_exhaust_base(particles, material)
	
	# Afterburner-specific modifications
	particles.amount = 250
	material.initial_velocity_min = 25.0
	material.initial_velocity_max = 40.0

func _configure_thruster_base(particles: GPUParticles3D, material: ParticleProcessMaterial) -> void:
	particles.amount = 100
	particles.lifetime = 1.5
	
	material.emission = ParticleProcessMaterial.EMISSION_BOX
	material.emission_box_extents = Vector3(0.1, 0.1, 0.1)
	
	material.direction = Vector3(0, 0, -1)
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 20.0
	
	material.scale_min = 0.1
	material.scale_max = 0.4

func _configure_shield_impact_base(particles: GPUParticles3D, material: ParticleProcessMaterial) -> void:
	particles.amount = 100
	particles.lifetime = 1.0
	
	material.emission = ParticleProcessMaterial.EMISSION_SPHERE
	material.emission_sphere_radius = 2.0
	
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	
	material.scale_min = 0.2
	material.scale_max = 1.0

func _configure_space_dust_base(particles: GPUParticles3D, material: ParticleProcessMaterial) -> void:
	particles.amount = 200
	particles.lifetime = 10.0
	
	material.emission = ParticleProcessMaterial.EMISSION_BOX
	material.emission_box_extents = Vector3(50, 50, 50)
	
	material.initial_velocity_min = 0.1
	material.initial_velocity_max = 1.0
	
	material.scale_min = 0.02
	material.scale_max = 0.1

func _configure_generic_base(particles: GPUParticles3D, material: ParticleProcessMaterial) -> void:
	particles.amount = 100
	particles.lifetime = 2.0
	
	material.emission = ParticleProcessMaterial.EMISSION_SPHERE
	material.emission_sphere_radius = 1.0
	
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	
	material.scale_min = 0.2
	material.scale_max = 0.8

func _create_laser_beam_node() -> Node3D:
	var container: Node3D = Node3D.new()
	
	# Beam mesh
	var beam: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 1.0)  # Default size, will be adjusted
	beam.mesh = mesh
	beam.name = "BeamMesh"
	container.add_child(beam)
	
	# Beam glow particles
	var glow: GPUParticles3D = GPUParticles3D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	
	glow.amount = 50
	glow.lifetime = 0.3
	
	material.emission = ParticleProcessMaterial.EMISSION_BOX
	material.emission_box_extents = Vector3(0.2, 0.2, 0.5)
	
	glow.process_material = material
	glow.name = "BeamGlow"
	container.add_child(glow)
	
	return container

func _create_plasma_bolt_node() -> Node3D:
	var container: Node3D = Node3D.new()
	
	# Core mesh
	var core: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	core.mesh = mesh
	core.name = "PlasmCore"
	container.add_child(core)
	
	# Plasma particles
	var particles: GPUParticles3D = GPUParticles3D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	
	particles.amount = 75
	particles.lifetime = 0.8
	
	material.emission = ParticleProcessMaterial.EMISSION_SPHERE
	material.emission_sphere_radius = 0.5
	
	particles.process_material = material
	particles.name = "PlasmaParticles"
	container.add_child(particles)
	
	return container

func _create_missile_trail_node() -> Node3D:
	var container: Node3D = Node3D.new()
	
	# Trail particles
	var trail: GPUParticles3D = GPUParticles3D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	
	trail.amount = 100
	trail.lifetime = 2.0
	
	material.emission = ParticleProcessMaterial.EMISSION_BOX
	material.emission_box_extents = Vector3(0.1, 0.1, 0.5)
	material.direction = Vector3(0, 0, -1)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	
	trail.process_material = material
	trail.name = "MissileTrail"
	container.add_child(trail)
	
	return container

func get_effect(properties: Dictionary = {}) -> Node3D:
	if available_effects.is_empty():
		# Try to expand pool if needed
		if total_created < pool_size * 2:  # Allow 2x expansion
			var new_effect: Node3D = _create_effect_node()
			if new_effect:
				new_effect.visible = false
				available_effects.append(new_effect)
				total_created += 1
		
		if available_effects.is_empty():
			pool_exhausted.emit()
			return null
	
	var effect: Node3D = available_effects.pop_back()
	active_effects.append(effect)
	
	# Reset effect to clean state
	_reset_effect(effect)
	effect.visible = true
	
	return effect

func return_effect(effect: Node3D) -> void:
	if not effect:
		return
	
	# Remove from active list
	var index: int = active_effects.find(effect)
	if index >= 0:
		active_effects.remove_at(index)
	
	# Reset and return to available pool
	_reset_effect(effect)
	effect.visible = false
	
	# Remove from scene tree if attached
	if effect.get_parent():
		effect.get_parent().remove_child(effect)
	
	available_effects.append(effect)
	effect_returned.emit(effect)

func _reset_effect(effect: Node3D) -> void:
	if not effect:
		return
	
	# Reset position and rotation
	effect.position = Vector3.ZERO
	effect.rotation = Vector3.ZERO
	effect.scale = Vector3.ONE
	
	# Reset particle systems
	if effect is GPUParticles3D:
		var particles: GPUParticles3D = effect as GPUParticles3D
		particles.emitting = false
		particles.restart()
	else:
		# For container nodes, reset child particles
		for child in effect.get_children():
			if child is GPUParticles3D:
				var particles: GPUParticles3D = child as GPUParticles3D
				particles.emitting = false
				particles.restart()

func expand_pool(additional_size: int) -> void:
	var old_size: int = pool_size
	pool_size += additional_size
	
	# Create additional effects
	for i in range(additional_size):
		var effect_node: Node3D = _create_effect_node()
		if effect_node:
			effect_node.visible = false
			available_effects.append(effect_node)
			total_created += 1
	
	pool_expanded.emit(pool_size)
	print("WCSEffectPool: Expanded %s pool from %d to %d effects" % [
		WCSEffectsManager.EffectType.keys()[effect_type], old_size, pool_size
	])

func get_statistics() -> Dictionary:
	return {
		"pool_size": pool_size,
		"available": available_effects.size(),
		"active": active_effects.size(),
		"total_created": total_created,
		"utilization": float(active_effects.size()) / float(total_created) if total_created > 0 else 0.0
	}

func cleanup_unused_effects() -> void:
	# Remove excess available effects if pool is over-expanded
	var target_available: int = pool_size
	
	while available_effects.size() > target_available:
		var effect: Node3D = available_effects.pop_back()
		effect.queue_free()
		total_created -= 1

func force_return_all_effects() -> void:
	# Force return all active effects (emergency cleanup)
	var effects_to_return: Array[Node3D] = active_effects.duplicate()
	
	for effect in effects_to_return:
		return_effect(effect)

func _exit_tree() -> void:
	# Clean up all effects
	for effect in available_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	
	available_effects.clear()
	active_effects.clear()