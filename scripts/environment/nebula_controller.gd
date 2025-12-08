# NebulaController - Nebula Visual Effects and Ship Impact
# Manages nebula fog, particles, environmental effects, and gameplay impact
# Uses NebulaData resource for comprehensive configuration

class_name NebulaController
extends Node3D

## Emitted when nebula is fully initialized
signal nebula_ready

## Emitted when nebula parameters change
signal nebula_updated

## Emitted when environmental damage is applied
signal damage_applied(damage_info: Dictionary)

## Emitted when ship enters/exits nebula
signal ship_entered_nebula(ship: Node3D)
signal ship_exited_nebula(ship: Node3D)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Nebula Data")
## Nebula resource containing configuration
@export var nebula_data: Resource # NebulaData

@export_group("Visual Settings")
## Enable fog effect
@export var fog_enabled: bool = true
## Enable particle effects
@export var particles_enabled: bool = true
## Background texture
@export var background_texture: Texture2D

@export_group("Performance")
## Maximum particle count
@export var max_particles: int = 1000
## Update distance for LOD
@export var lod_distance: float = 500.0

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

## World environment for fog/atmosphere
var _world_environment: WorldEnvironment = null

## Particle systems
var _particle_systems: Array[GPUParticles3D] = []

## Background sprites/meshes
var _background_sprites: Array[Sprite3D] = []

## Ships currently in nebula
var _ships_in_nebula: Array[Node3D] = []

## Nebula bounds (for entry/exit detection)
var _nebula_bounds: AABB = AABB()

## Cached nebula properties
var _fog_color: Color = Color(0.3, 0.2, 0.4, 0.5)
var _fog_density: float = 0.01
var _particle_velocity: Vector3 = Vector3.ZERO
var _is_initialized: bool = false

# Lightning effect state
var _lightning_timer: float = 0.0
var _lightning_interval: float = 5.0 # Seconds between lightning

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	_setup_base_environment()
	if nebula_data:
		initialize_from_resource(nebula_data)
	nebula_ready.emit()


func _process(delta: float) -> void:
	if not _is_initialized:
		return
	
	_update_particles(delta)
	_update_lightning(delta)
	_check_ship_positions()


## Initialize from NebulaData resource
func initialize_from_resource(data: Resource) -> void:
	nebula_data = data
	
	if not data:
		push_warning("NebulaController: No nebula data provided")
		return
	
	# Extract visual properties
	_fog_color = data.get("nebula_tint_color") if data.get("nebula_tint_color") else Color(0.3, 0.2, 0.4, 0.5)
	_fog_density = data.get("visual_opacity_coefficient") if data.get("visual_opacity_coefficient") else 0.3
	_particle_velocity = data.get("particle_velocity_vector") if data.get("particle_velocity_vector") else Vector3.ZERO
	
	# Set up lightning based on nebula type
	if data.get("nebula_classification") == 1: # Ion Storm
		_lightning_interval = 3.0 / max(data.get("ion_storm_intensity") if data.get("ion_storm_intensity") else 0.1, 0.01)
	else:
		_lightning_interval = 10.0 # Less frequent for other types
	
	_apply_fog_settings()
	_setup_particles()
	_setup_background()
	
	_is_initialized = true
	
	print("NebulaController: Initialized nebula '%s' (Classification: %s)" % [
		data.get("nebula_name") if data.get("nebula_name") else "unnamed",
		_get_classification_name(data.get("nebula_classification") if data.get("nebula_classification") else 0)
	])
	
	nebula_updated.emit()


## Set a background texture for the nebula
func set_background_texture(texture: Texture2D) -> void:
	background_texture = texture
	_setup_background()


# ==============================================================================
# SETUP
# ==============================================================================


func _setup_base_environment() -> void:
	# Create WorldEnvironment node for fog effects
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "NebulaEnvironment"
	
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	
	# Fog settings (will be updated when nebula data is loaded)
	env.fog_enabled = fog_enabled
	env.fog_light_color = _fog_color
	env.fog_density = _fog_density * 0.01
	
	# Volumetric fog for more realistic nebula
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = _fog_density * 0.005
	env.volumetric_fog_albedo = _fog_color
	env.volumetric_fog_emission = _fog_color * 0.1
	
	_world_environment.environment = env
	add_child(_world_environment)


func _apply_fog_settings() -> void:
	if not _world_environment or not _world_environment.environment:
		return
	
	var env := _world_environment.environment
	env.fog_enabled = fog_enabled
	env.fog_light_color = _fog_color
	env.fog_density = _fog_density * 0.01
	
	env.volumetric_fog_enabled = fog_enabled
	env.volumetric_fog_density = _fog_density * 0.005
	env.volumetric_fog_albedo = _fog_color
	env.volumetric_fog_emission = _fog_color * 0.1


func _setup_particles() -> void:
	if not particles_enabled:
		return
	
	# Clear existing particles
	for particles in _particle_systems:
		if is_instance_valid(particles):
			particles.queue_free()
	_particle_systems.clear()
	
	# Get particle settings from nebula data
	var particle_density := 50
	var turbulence := 0.2
	
	if nebula_data:
		particle_density = nebula_data.get("particle_density_per_cubic_meter") if nebula_data.get("particle_density_per_cubic_meter") else 50
		turbulence = nebula_data.get("turbulence_force_factor") if nebula_data.get("turbulence_force_factor") else 0.2
	
	# Create main particle system
	var particles := GPUParticles3D.new()
	particles.name = "NebulaParticles"
	particles.amount = min(particle_density * 10, max_particles)
	particles.lifetime = 10.0
	particles.emitting = true
	particles.visibility_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	
	# Create particle material
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(200, 200, 200)
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 5.0
	material.direction = _particle_velocity.normalized() if _particle_velocity.length() > 0 else Vector3(1, 0, 0)
	material.spread = 180.0
	material.turbulence_enabled = true
	material.turbulence_noise_strength = turbulence * 10.0
	material.turbulence_noise_scale = 2.0
	material.scale_min = 0.5
	material.scale_max = 2.0
	material.color = Color(_fog_color.r, _fog_color.g, _fog_color.b, 0.3)
	
	particles.process_material = material
	
	# Create particle mesh (simple quad)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	particles.draw_pass_1 = mesh
	
	# Create draw material
	var draw_material := StandardMaterial3D.new()
	draw_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_material.albedo_color = Color(_fog_color.r, _fog_color.g, _fog_color.b, 0.2)
	draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.material_override = draw_material
	
	add_child(particles)
	_particle_systems.append(particles)


func _setup_background() -> void:
	# Clear existing backgrounds
	for sprite in _background_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_background_sprites.clear()
	
	if not background_texture:
		return
	
	# Create skybox-style background with nebula texture
	# Place large sprites on all 6 sides of a cube
	var directions := [
		Vector3(0, 0, -1), # Front
		Vector3(0, 0, 1), # Back
		Vector3(1, 0, 0), # Right
		Vector3(-1, 0, 0), # Left
		Vector3(0, 1, 0), # Up
		Vector3(0, -1, 0), # Down
	]
	
	var distance := 800.0
	var size := 1600.0
	
	for i in range(directions.size()):
		var dir: Vector3 = directions[i]
		var sprite := Sprite3D.new()
		sprite.name = "Background_%d" % i
		sprite.texture = background_texture
		sprite.pixel_size = size / background_texture.get_width() if background_texture.get_width() > 0 else 1.0
		sprite.position = dir * distance
		sprite.modulate = _fog_color
		sprite.modulate.a = 0.8
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sprite.render_priority = -100
		sprite.no_depth_test = true
		
		# Rotate to face center
		sprite.look_at(Vector3.ZERO)
		
		add_child(sprite)
		_background_sprites.append(sprite)


# ==============================================================================
# UPDATE LOOPS
# ==============================================================================


func _update_particles(_delta: float) -> void:
	# Update particle positions to follow camera (for infinite effect)
	var camera := get_viewport().get_camera_3d()
	if camera:
		for particles in _particle_systems:
			if is_instance_valid(particles):
				particles.global_position = camera.global_position


func _update_lightning(delta: float) -> void:
	if not nebula_data:
		return
	
	# Only create lightning for ion storms
	if nebula_data.get("nebula_classification") != 1:
		return
	
	_lightning_timer += delta
	if _lightning_timer >= _lightning_interval:
		_lightning_timer = 0.0
		_create_lightning_flash()
		
		# Randomize next interval
		var ion_intensity: float = nebula_data.get("ion_storm_intensity") if nebula_data.get("ion_storm_intensity") else 0.1
		_lightning_interval = randf_range(2.0, 8.0) / max(ion_intensity, 0.1)


func _create_lightning_flash() -> void:
	# Create a brief flash effect
	# This would be expanded with actual lightning bolt visuals
	if _world_environment and _world_environment.environment:
		var env := _world_environment.environment
		var original_emission := env.volumetric_fog_emission
		
		# Flash
		env.volumetric_fog_emission = Color.WHITE
		
		# Reset after brief delay (using tween)
		var tween := create_tween()
		tween.tween_property(env, "volumetric_fog_emission", original_emission, 0.2)
	
	# Emit signal for audio/damage systems
	damage_applied.emit({
		"type": "lightning",
		"intensity": nebula_data.get("ion_storm_intensity") if nebula_data.get("ion_storm_intensity") else 0.0
	})


func _check_ship_positions() -> void:
	# This would be called to check ship entry/exit
	# Implementation depends on how ships are tracked in the game
	pass


# ==============================================================================
# SHIP IMPACT API
# ==============================================================================


## Calculate environmental impact on a ship
func calculate_ship_impact(ship_stats: Resource) -> Dictionary:
	if not nebula_data:
		return {}
	
	# Delegate to NebulaData's comprehensive calculation
	if nebula_data.has_method("calculate_environmental_impact"):
		return nebula_data.calculate_environmental_impact(ship_stats)
	
	# Fallback basic calculation
	return {
		"velocity_impact": nebula_data.get("max_velocity_reduction") if nebula_data.get("max_velocity_reduction") else 0.0,
		"sensor_impact": nebula_data.get("radar_sensor_range_reduction") if nebula_data.get("radar_sensor_range_reduction") else 0.0,
		"shield_impact": 1.0 - (nebula_data.get("shield_effectiveness_multiplier") if nebula_data.get("shield_effectiveness_multiplier") else 1.0)
	}


## Apply environmental damage to a ship over time
func apply_damage_to_ship(ship: Node3D, delta: float) -> Dictionary:
	if not nebula_data:
		return {}
	
	# Delegate to NebulaData's damage calculation
	if nebula_data.has_method("apply_damage_to_ship"):
		var damage: Dictionary = nebula_data.apply_damage_to_ship(ship, delta)
		if damage.get("radiation_damage", 0.0) > 0 or damage.get("shield_drain", 0.0) > 0:
			damage_applied.emit(damage)
		return damage
	
	return {}


## Get tactical severity of this nebula (0.0-1.0)
func get_tactical_severity() -> float:
	if not nebula_data:
		return 0.0
	
	if nebula_data.has_method("calculate_tactical_severity"):
		return nebula_data.calculate_tactical_severity()
	
	return 0.5 # Default moderate severity


## Get visibility/concealment effectiveness
func get_visibility_concealment() -> float:
	if not nebula_data:
		return 0.0
	
	if nebula_data.has_method("get_visibility_concealment"):
		return nebula_data.get_visibility_concealment()
	
	return _fog_density * 0.5


# ==============================================================================
# PUBLIC API
# ==============================================================================


## Enable/disable nebula effects
func set_enabled(enabled: bool) -> void:
	fog_enabled = enabled
	particles_enabled = enabled
	
	_apply_fog_settings()
	
	for particles in _particle_systems:
		if is_instance_valid(particles):
			particles.emitting = enabled
			particles.visible = enabled
	
	for sprite in _background_sprites:
		if is_instance_valid(sprite):
			sprite.visible = enabled


## Get nebula fog color
func get_fog_color() -> Color:
	return _fog_color


## Set custom fog color
func set_fog_color(color: Color) -> void:
	_fog_color = color
	_apply_fog_settings()
	
	for sprite in _background_sprites:
		if is_instance_valid(sprite):
			sprite.modulate = color


## Get nebula classification name
func get_classification_name() -> String:
	if not nebula_data:
		return "Unknown"
	return _get_classification_name(nebula_data.get("nebula_classification") if nebula_data.get("nebula_classification") else 0)


func _get_classification_name(classification: int) -> String:
	match classification:
		0: return "Gas Cloud"
		1: return "Ion Storm"
		2: return "Dust Cloud"
		3: return "Radiation Field"
		_: return "Unknown"


## Check if nebula is safe for prolonged exposure
func is_safe_for_prolonged_exposure() -> bool:
	if not nebula_data:
		return true
	
	if nebula_data.has_method("is_safe_for_prolonged_exposure"):
		return nebula_data.is_safe_for_prolonged_exposure()
	
	return true


## Get WorldEnvironment for external modification
func get_world_environment() -> WorldEnvironment:
	return _world_environment
