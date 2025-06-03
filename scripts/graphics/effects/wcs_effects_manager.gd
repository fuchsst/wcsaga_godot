class_name WCSEffectsManager
extends Node

## Comprehensive visual effects system for WCS-style space combat effects
## Manages explosions, weapon effects, engine trails, and environmental particles

signal effect_created(effect_id: String, effect_node: Node3D)
signal effect_destroyed(effect_id: String)
signal effect_template_loaded(template_name: String)
signal effect_pool_exhausted(effect_type: String)
signal effect_performance_warning(active_effects: int, recommended_max: int)

enum EffectType {
	WEAPON_MUZZLE_FLASH = 0,
	WEAPON_LASER_BEAM = 1,
	WEAPON_PLASMA_BOLT = 2,
	WEAPON_MISSILE_TRAIL = 3,
	WEAPON_IMPACT_SPARKS = 4,
	
	EXPLOSION_SMALL = 10,
	EXPLOSION_MEDIUM = 11,
	EXPLOSION_LARGE = 12,
	EXPLOSION_CAPITAL = 13,
	EXPLOSION_ASTEROID = 14,
	
	ENGINE_EXHAUST = 20,
	ENGINE_AFTERBURNER = 21,
	ENGINE_JUMP_DRIVE = 22,
	THRUSTER_TRAIL = 23,
	
	SHIELD_IMPACT = 30,
	SHIELD_OVERLOAD = 31,
	SHIELD_RECHARGE = 32,
	
	ENVIRONMENT_SPACE_DUST = 40,
	ENVIRONMENT_NEBULA = 41,
	ENVIRONMENT_DEBRIS = 42,
	ENVIRONMENT_ASTEROID_DUST = 43
}

# Effect management
var active_effects: Dictionary = {}
var effect_pools: Dictionary = {}
var effect_templates: Dictionary = {}
var effect_id_counter: int = 0

# Performance management
var max_active_effects: int = 64
var quality_level: int = 2
var particle_quality_multiplier: float = 1.0

# Integration systems
var lighting_controller: WCSLightingController
var shader_manager: WCSShaderManager

func _ready() -> void:
	name = "WCSEffectsManager"
	_initialize_effect_system()
	print("WCSEffectsManager: Initialized with comprehensive visual effects")

func _initialize_effect_system() -> void:
	# Initialize effect pools for performance
	_create_effect_pools()
	
	# Load effect templates
	_load_effect_templates()
	
	# Set up performance monitoring
	_setup_performance_monitoring()

func _create_effect_pools() -> void:
	# Pre-allocate effect pools based on expected usage
	var pool_sizes: Dictionary = {
		EffectType.WEAPON_MUZZLE_FLASH: 20,
		EffectType.WEAPON_LASER_BEAM: 15,
		EffectType.WEAPON_PLASMA_BOLT: 12,
		EffectType.WEAPON_MISSILE_TRAIL: 8,
		EffectType.WEAPON_IMPACT_SPARKS: 25,
		
		EffectType.EXPLOSION_SMALL: 10,
		EffectType.EXPLOSION_MEDIUM: 8,
		EffectType.EXPLOSION_LARGE: 5,
		EffectType.EXPLOSION_CAPITAL: 3,
		EffectType.EXPLOSION_ASTEROID: 6,
		
		EffectType.ENGINE_EXHAUST: 16,
		EffectType.ENGINE_AFTERBURNER: 8,
		EffectType.THRUSTER_TRAIL: 12,
		
		EffectType.SHIELD_IMPACT: 15,
		EffectType.SHIELD_OVERLOAD: 4,
		EffectType.SHIELD_RECHARGE: 6,
		
		EffectType.ENVIRONMENT_SPACE_DUST: 5,
		EffectType.ENVIRONMENT_NEBULA: 3,
		EffectType.ENVIRONMENT_DEBRIS: 8
	}
	
	# Create pools for each effect type
	for effect_type in pool_sizes:
		effect_pools[effect_type] = WCSEffectPool.new(effect_type, pool_sizes[effect_type])
		add_child(effect_pools[effect_type])

func _load_effect_templates() -> void:
	# Load pre-configured effect templates
	effect_templates = {
		# Weapon effect templates
		"laser_red": _create_laser_template(Color.RED, 2.0, 50.0),
		"laser_green": _create_laser_template(Color.GREEN, 1.8, 45.0),
		"laser_blue": _create_laser_template(Color.BLUE, 2.2, 55.0),
		"plasma_orange": _create_plasma_template(Color.ORANGE, 1.5, 30.0),
		"plasma_purple": _create_plasma_template(Color.PURPLE, 1.7, 35.0),
		
		# Explosion templates
		"fighter_explosion": _create_explosion_template("small", 1.0, 2.0),
		"bomber_explosion": _create_explosion_template("medium", 1.5, 3.0),
		"cruiser_explosion": _create_explosion_template("large", 2.5, 5.0),
		"capital_explosion": _create_explosion_template("capital", 4.0, 8.0),
		"asteroid_explosion": _create_explosion_template("asteroid", 1.2, 2.5),
		
		# Engine templates
		"standard_engine": _create_engine_template(Color.CYAN, 1.0, 2.0),
		"afterburner": _create_engine_template(Color.BLUE, 2.0, 4.0),
		"alien_engine": _create_engine_template(Color.GREEN, 1.2, 2.5),
		
		# Shield templates
		"standard_shield": _create_shield_template(Color.BLUE, 1.0),
		"enhanced_shield": _create_shield_template(Color.GREEN, 1.5),
		"alien_shield": _create_shield_template(Color.PURPLE, 1.3)
	}
	
	print("WCSEffectsManager: Loaded %d effect templates" % effect_templates.size())

func create_effect(effect_type: EffectType, position: Vector3, 
				  properties: Dictionary = {}) -> String:
	# Generate unique effect ID
	var effect_id: String = _generate_effect_id(effect_type)
	
	# Check effect limits
	if active_effects.size() >= max_active_effects:
		_handle_effect_overflow()
	
	# Get effect node from pool or create new
	var effect_node: Node3D = _get_effect_from_pool(effect_type, properties)
	if not effect_node:
		push_warning("Failed to create effect: pool exhausted")
		return ""
	
	# Configure effect
	_configure_effect(effect_node, effect_type, position, properties)
	
	# Add to scene and track
	add_child(effect_node)
	active_effects[effect_id] = {
		"node": effect_node,
		"type": effect_type,
		"created_time": Time.get_ticks_msec(),
		"properties": properties
	}
	
	# Auto-cleanup timer if specified
	var lifetime: float = properties.get("lifetime", 0.0)
	if lifetime > 0.0:
		_setup_effect_cleanup_timer(effect_id, lifetime)
	
	effect_created.emit(effect_id, effect_node)
	return effect_id

func create_weapon_effect(weapon_type: String, start_pos: Vector3, end_pos: Vector3,
						 color: Color = Color.WHITE, intensity: float = 1.0) -> String:
	var effect_type: EffectType
	var properties: Dictionary = {
		"color": color,
		"intensity": intensity,
		"start_position": start_pos,
		"end_position": end_pos,
		"lifetime": 0.5
	}
	
	# Map weapon type to effect type
	match weapon_type.to_lower():
		"laser":
			effect_type = EffectType.WEAPON_LASER_BEAM
			properties["beam_width"] = 0.5 * intensity
		"plasma":
			effect_type = EffectType.WEAPON_PLASMA_BOLT
			properties["particle_count"] = int(50 * intensity)
		"missile":
			effect_type = EffectType.WEAPON_MISSILE_TRAIL
			properties["trail_length"] = 10.0 * intensity
		_:
			effect_type = EffectType.WEAPON_MUZZLE_FLASH
			properties["flash_range"] = 15.0 * intensity
	
	return create_effect(effect_type, start_pos, properties)

func create_explosion_effect(position: Vector3, explosion_type: String,
							scale_factor: float = 1.0, lifetime: float = 0.0) -> String:
	var effect_type: EffectType
	var properties: Dictionary = {
		"scale": scale_factor,
		"color_primary": Color.ORANGE,
		"color_secondary": Color.RED,
		"particle_count": 200
	}
	
	# Configure based on explosion type
	match explosion_type.to_lower():
		"small", "fighter":
			effect_type = EffectType.EXPLOSION_SMALL
			properties["lifetime"] = 2.0 if lifetime <= 0.0 else lifetime
			properties["stages"] = 3
		"medium", "bomber":
			effect_type = EffectType.EXPLOSION_MEDIUM
			properties["lifetime"] = 3.0 if lifetime <= 0.0 else lifetime
			properties["stages"] = 4
			properties["particle_count"] = 350
		"large", "cruiser":
			effect_type = EffectType.EXPLOSION_LARGE
			properties["lifetime"] = 5.0 if lifetime <= 0.0 else lifetime
			properties["stages"] = 5
			properties["particle_count"] = 500
		"capital":
			effect_type = EffectType.EXPLOSION_CAPITAL
			properties["lifetime"] = 8.0 if lifetime <= 0.0 else lifetime
			properties["stages"] = 6
			properties["particle_count"] = 800
		"asteroid":
			effect_type = EffectType.EXPLOSION_ASTEROID
			properties["lifetime"] = 3.0 if lifetime <= 0.0 else lifetime
			properties["color_primary"] = Color.GRAY
			properties["color_secondary"] = Color.DARK_GRAY
			properties["particle_count"] = 150
		_:
			effect_type = EffectType.EXPLOSION_MEDIUM
			properties["lifetime"] = 3.0 if lifetime <= 0.0 else lifetime
	
	return create_effect(effect_type, position, properties)

func create_engine_effect(ship_node: Node3D, engine_positions: Array[Vector3],
						 engine_type: String = "standard", intensity: float = 1.0) -> Array[String]:
	var effect_ids: Array[String] = []
	var effect_type: EffectType = EffectType.ENGINE_EXHAUST
	
	var properties: Dictionary = {
		"intensity": intensity,
		"lifetime": -1.0,  # Persistent effect
		"particle_count": int(100 * intensity),
		"color": Color.CYAN
	}
	
	# Configure based on engine type
	match engine_type.to_lower():
		"afterburner":
			effect_type = EffectType.ENGINE_AFTERBURNER
			properties["color"] = Color.BLUE
			properties["intensity"] *= 2.0
		"alien":
			properties["color"] = Color.GREEN
		"jump":
			effect_type = EffectType.ENGINE_JUMP_DRIVE
			properties["color"] = Color.PURPLE
			properties["intensity"] *= 3.0
	
	# Create effect for each engine position
	for engine_pos in engine_positions:
		var world_pos: Vector3 = ship_node.to_global(engine_pos)
		var effect_id: String = create_effect(effect_type, world_pos, properties)
		
		if not effect_id.is_empty():
			effect_ids.append(effect_id)
			
			# Parent effect to ship for movement
			var effect_data: Dictionary = active_effects[effect_id]
			var effect_node: Node3D = effect_data.node
			effect_node.reparent(ship_node)
			effect_node.position = engine_pos
	
	return effect_ids

func create_shield_impact_effect(impact_position: Vector3, shield_node: Node3D,
								 impact_strength: float = 1.0) -> String:
	var properties: Dictionary = {
		"impact_strength": impact_strength,
		"impact_radius": 5.0 * impact_strength,
		"color": Color.BLUE,
		"lifetime": 1.5,
		"shield_node": shield_node
	}
	
	return create_effect(EffectType.SHIELD_IMPACT, impact_position, properties)

func destroy_effect(effect_id: String) -> void:
	if effect_id not in active_effects:
		return
	
	var effect_data: Dictionary = active_effects[effect_id]
	var effect_node: Node3D = effect_data.node
	var effect_type: EffectType = effect_data.type
	
	# Return to pool or destroy
	if effect_type in effect_pools:
		effect_pools[effect_type].return_effect(effect_node)
	else:
		effect_node.queue_free()
	
	# Remove from tracking
	active_effects.erase(effect_id)
	effect_destroyed.emit(effect_id)

func _get_effect_from_pool(effect_type: EffectType, properties: Dictionary) -> Node3D:
	if effect_type in effect_pools:
		var pool: WCSEffectPool = effect_pools[effect_type]
		return pool.get_effect(properties)
	
	# Create new effect if no pool available
	return _create_effect_node(effect_type, properties)

func _create_effect_node(effect_type: EffectType, properties: Dictionary) -> Node3D:
	var effect_node: Node3D
	
	match effect_type:
		EffectType.WEAPON_MUZZLE_FLASH, EffectType.WEAPON_IMPACT_SPARKS, \
		EffectType.EXPLOSION_SMALL, EffectType.EXPLOSION_MEDIUM, \
		EffectType.EXPLOSION_LARGE, EffectType.EXPLOSION_CAPITAL, EffectType.EXPLOSION_ASTEROID:
			effect_node = _create_particle_effect(effect_type, properties)
		
		EffectType.WEAPON_LASER_BEAM:
			effect_node = _create_laser_beam_effect(properties)
		
		EffectType.WEAPON_PLASMA_BOLT:
			effect_node = _create_plasma_bolt_effect(properties)
		
		EffectType.ENGINE_EXHAUST, EffectType.ENGINE_AFTERBURNER, EffectType.THRUSTER_TRAIL:
			effect_node = _create_engine_effect_node(effect_type, properties)
		
		EffectType.SHIELD_IMPACT, EffectType.SHIELD_OVERLOAD:
			effect_node = _create_shield_effect(effect_type, properties)
		
		_:
			effect_node = _create_generic_particle_effect(properties)
	
	if effect_node:
		effect_node.name = "Effect_" + EffectType.keys()[effect_type]
	
	return effect_node

func _create_particle_effect(effect_type: EffectType, properties: Dictionary) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	
	# Configure based on effect type
	match effect_type:
		EffectType.EXPLOSION_SMALL:
			_configure_explosion_particles(particles, material, properties, 150)
		EffectType.EXPLOSION_MEDIUM:
			_configure_explosion_particles(particles, material, properties, 250)
		EffectType.EXPLOSION_LARGE:
			_configure_explosion_particles(particles, material, properties, 400)
		EffectType.EXPLOSION_CAPITAL:
			_configure_explosion_particles(particles, material, properties, 600)
		EffectType.WEAPON_MUZZLE_FLASH:
			_configure_muzzle_flash_particles(particles, material, properties)
		EffectType.WEAPON_IMPACT_SPARKS:
			_configure_impact_spark_particles(particles, material, properties)
		_:
			_configure_generic_particles(particles, material, properties)
	
	particles.process_material = material
	particles.emitting = true
	
	return particles

func _configure_explosion_particles(particles: GPUParticles3D, material: ParticleProcessMaterial,
								   properties: Dictionary, base_amount: int) -> void:
	var scale: float = properties.get("scale", 1.0)
	var stages: int = properties.get("stages", 3)
	
	particles.amount = int(base_amount * scale * particle_quality_multiplier)
	particles.lifetime = properties.get("lifetime", 3.0)
	
	# Explosion particle configuration
	material.emission = ParticleProcessMaterial.EMISSION_SPHERE
	material.emission_sphere_radius = 2.0 * scale
	
	material.initial_velocity_min = 10.0 * scale
	material.initial_velocity_max = 30.0 * scale
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	
	material.scale_min = 0.5 * scale
	material.scale_max = 2.0 * scale
	material.scale_over_velocity_max = 0.1
	
	# Color progression
	var color_primary: Color = properties.get("color_primary", Color.ORANGE)
	var color_secondary: Color = properties.get("color_secondary", Color.RED)
	material.color = color_primary
	
	# Gravity and damping
	material.gravity = Vector3(0, -9.8 * 0.1, 0)  # Reduced gravity for space
	material.damping_min = 0.1
	material.damping_max = 0.3

func _configure_muzzle_flash_particles(particles: GPUParticles3D, material: ParticleProcessMaterial,
									  properties: Dictionary) -> void:
	var intensity: float = properties.get("intensity", 1.0)
	
	particles.amount = int(50 * intensity * particle_quality_multiplier)
	particles.lifetime = 0.2
	
	material.emission = ParticleProcessMaterial.EMISSION_SPHERE
	material.emission_sphere_radius = 1.0 * intensity
	
	material.initial_velocity_min = 20.0 * intensity
	material.initial_velocity_max = 40.0 * intensity
	
	material.scale_min = 0.2
	material.scale_max = 1.0
	
	var color: Color = properties.get("color", Color.WHITE)
	material.color = color

func _create_laser_beam_effect(properties: Dictionary) -> MeshInstance3D:
	var beam: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	
	var start_pos: Vector3 = properties.get("start_position", Vector3.ZERO)
	var end_pos: Vector3 = properties.get("end_position", Vector3(0, 0, 10))
	var beam_width: float = properties.get("beam_width", 0.5)
	
	# Configure beam geometry
	var beam_length: float = start_pos.distance_to(end_pos)
	mesh.size = Vector3(beam_width, beam_width, beam_length)
	beam.mesh = mesh
	
	# Position and orient beam
	beam.position = (start_pos + end_pos) * 0.5
	beam.look_at(end_pos, Vector3.UP)
	
	# Apply laser shader material
	if shader_manager:
		var material: ShaderMaterial = shader_manager.create_material_with_shader("laser_beam", {
			"beam_color": properties.get("color", Color.RED),
			"beam_intensity": properties.get("intensity", 2.0),
			"beam_width": beam_width
		})
		beam.material_override = material
	
	return beam

func _setup_performance_monitoring() -> void:
	# Monitor effect performance every 2 seconds
	var timer: Timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_check_effect_performance)
	add_child(timer)

func _check_effect_performance() -> void:
	var current_effects: int = active_effects.size()
	var recommended_max: int = max_active_effects
	
	# Adjust recommended max based on quality level
	match quality_level:
		0, 1:  # Low quality
			recommended_max = max_active_effects / 2
		2:  # Medium quality
			recommended_max = int(max_active_effects * 0.75)
		3, 4:  # High/Ultra quality
			recommended_max = max_active_effects
	
	if current_effects > recommended_max:
		effect_performance_warning.emit(current_effects, recommended_max)
		_handle_effect_overflow()

func _handle_effect_overflow() -> void:
	# Remove oldest, lowest priority effects
	var effect_ages: Array[Dictionary] = []
	
	for effect_id in active_effects:
		var effect_data: Dictionary = active_effects[effect_id]
		var age: int = Time.get_ticks_msec() - effect_data.created_time
		var priority: int = effect_data.properties.get("priority", 5)
		
		effect_ages.append({
			"id": effect_id,
			"age": age,
			"priority": priority,
			"score": age / (priority + 1)  # Higher score = remove first
		})
	
	# Sort by removal score (age/priority)
	effect_ages.sort_custom(func(a, b): return a.score > b.score)
	
	# Remove oldest, lowest priority effects
	var effects_to_remove: int = min(10, active_effects.size() / 4)
	for i in range(effects_to_remove):
		if i < effect_ages.size():
			destroy_effect(effect_ages[i].id)

func set_quality_level(quality: int) -> void:
	quality_level = clamp(quality, 0, 4)
	
	# Adjust particle quality multiplier
	match quality_level:
		0:  # Very low
			particle_quality_multiplier = 0.25
			max_active_effects = 32
		1:  # Low
			particle_quality_multiplier = 0.5
			max_active_effects = 48
		2:  # Medium
			particle_quality_multiplier = 0.75
			max_active_effects = 64
		3:  # High
			particle_quality_multiplier = 1.0
			max_active_effects = 80
		4:  # Ultra
			particle_quality_multiplier = 1.5
			max_active_effects = 96
	
	print("WCSEffectsManager: Quality set to level %d (%.2fx particles, %d max effects)" % 
		  [quality_level, particle_quality_multiplier, max_active_effects])

func get_effect_statistics() -> Dictionary:
	var pool_stats: Dictionary = {}
	for effect_type in effect_pools:
		var pool: WCSEffectPool = effect_pools[effect_type]
		pool_stats[EffectType.keys()[effect_type]] = pool.get_statistics()
	
	return {
		"active_effects": active_effects.size(),
		"max_effects": max_active_effects,
		"quality_level": quality_level,
		"particle_multiplier": particle_quality_multiplier,
		"effect_templates": effect_templates.size(),
		"pool_statistics": pool_stats
	}

func clear_all_effects() -> void:
	# Destroy all active effects
	for effect_id in active_effects.keys():
		destroy_effect(effect_id)

func _generate_effect_id(effect_type: EffectType) -> String:
	effect_id_counter += 1
	var type_name: String = EffectType.keys()[effect_type].to_lower()
	return "%s_%d_%d" % [type_name, effect_id_counter, Time.get_ticks_msec()]

func _setup_effect_cleanup_timer(effect_id: String, lifetime: float) -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(func(): destroy_effect(effect_id))
	add_child(timer)
	timer.start()

func _configure_effect(effect_node: Node3D, effect_type: EffectType, 
					  position: Vector3, properties: Dictionary) -> void:
	effect_node.global_position = position
	
	# Type-specific configuration
	if effect_node is GPUParticles3D:
		var particles: GPUParticles3D = effect_node as GPUParticles3D
		particles.emitting = true
		particles.restart()

# Template creation functions
func _create_laser_template(color: Color, intensity: float, range: float) -> Dictionary:
	return {
		"type": "laser",
		"color": color,
		"intensity": intensity,
		"range": range,
		"beam_width": 0.5,
		"lifetime": 0.1
	}

func _create_plasma_template(color: Color, intensity: float, range: float) -> Dictionary:
	return {
		"type": "plasma",
		"color": color,
		"intensity": intensity,
		"range": range,
		"particle_count": 75,
		"lifetime": 0.8
	}

func _create_explosion_template(size: String, scale: float, lifetime: float) -> Dictionary:
	return {
		"type": "explosion",
		"size": size,
		"scale": scale,
		"lifetime": lifetime,
		"stages": 4,
		"color_primary": Color.ORANGE,
		"color_secondary": Color.RED
	}

func _create_engine_template(color: Color, intensity: float, lifetime: float) -> Dictionary:
	return {
		"type": "engine",
		"color": color,
		"intensity": intensity,
		"lifetime": lifetime,
		"particle_count": 150
	}

func _create_shield_template(color: Color, strength: float) -> Dictionary:
	return {
		"type": "shield",
		"color": color,
		"strength": strength,
		"impact_radius": 5.0,
		"lifetime": 1.5
	}

func _exit_tree() -> void:
	clear_all_effects()