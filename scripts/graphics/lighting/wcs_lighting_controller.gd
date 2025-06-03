class_name WCSLightingController
extends Node

## Dynamic lighting system for space environments with WCS-style lighting characteristics
## Manages main star lighting, ambient space environment, and dynamic combat lighting

signal lighting_profile_changed(profile_name: String)
signal ambient_light_updated(color: Color, intensity: float)
signal main_star_light_configured(direction: Vector3, intensity: float)
signal dynamic_light_created(light_id: String, light: Light3D)
signal dynamic_light_destroyed(light_id: String)
signal lighting_quality_adjusted(quality_level: int)

enum LightingProfile {
	DEEP_SPACE = 0,     # Minimal ambient, single star source
	NEBULA = 1,         # Colored ambient, atmospheric effects
	PLANET_PROXIMITY = 2, # Planetary reflection, multiple sources
	ASTEROID_FIELD = 3, # Multiple shadows, scattered lighting
	CUSTOM = 4          # User-defined lighting setup
}

enum DynamicLightType {
	WEAPON_MUZZLE_FLASH = 0,
	LASER_BEAM = 1,
	EXPLOSION = 2,
	ENGINE_GLOW = 3,
	THRUSTER = 4,
	SHIELD_IMPACT = 5
}

# Main lighting components
var main_star_light: DirectionalLight3D
var ambient_environment: Environment
var dynamic_light_pool: WCSDynamicLightPool
var lighting_profiles: Dictionary = {}

# Current lighting state
var current_profile: LightingProfile = LightingProfile.DEEP_SPACE
var quality_level: int = 2  # Medium quality
var ambient_intensity: float = 0.15  # WCS default ambient
var reflective_intensity: float = 0.75  # WCS default reflective

# Performance management
var max_dynamic_lights: int = 32
var active_dynamic_lights: Dictionary = {}
var light_priority_queue: Array[Dictionary] = []

# Lighting constants from WCS
const AMBIENT_LIGHT_DEFAULT: float = 0.15
const REFLECTIVE_LIGHT_DEFAULT: float = 0.75
const MIN_LIGHT_INTENSITY: float = 0.03

func _ready() -> void:
	name = "WCSLightingController"
	_initialize_lighting_system()
	print("WCSLightingController: Initialized with WCS-style space lighting")

func _initialize_lighting_system() -> void:
	# Initialize dynamic light pool
	dynamic_light_pool = WCSDynamicLightPool.new(max_dynamic_lights)
	add_child(dynamic_light_pool)
	
	# Load lighting profiles
	_setup_lighting_profiles()
	
	# Create main lighting components
	_create_main_star_light()
	_create_ambient_environment()
	
	# Apply default lighting profile
	apply_lighting_profile(current_profile)

func _setup_lighting_profiles() -> void:
	lighting_profiles = {
		LightingProfile.DEEP_SPACE: {
			"name": "Deep Space",
			"star_color": Color(1.0, 0.95, 0.8),  # Warm white star
			"star_intensity": 1.2,
			"star_direction": Vector3(-0.5, -0.3, -0.8).normalized(),
			"ambient_color": Color(0.05, 0.05, 0.1),  # Very dark blue
			"ambient_energy": 0.1,
			"shadow_enabled": true,
			"shadow_distance": 5000.0
		},
		LightingProfile.NEBULA: {
			"name": "Nebula Environment", 
			"star_color": Color(0.9, 0.7, 1.0),  # Purple-tinted star
			"star_intensity": 0.8,
			"star_direction": Vector3(-0.3, -0.5, -0.7).normalized(),
			"ambient_color": Color(0.3, 0.1, 0.4),  # Purple nebula glow
			"ambient_energy": 0.35,
			"shadow_enabled": true,
			"shadow_distance": 3000.0,
			"fog_enabled": true,
			"fog_color": Color(0.2, 0.05, 0.3)
		},
		LightingProfile.PLANET_PROXIMITY: {
			"name": "Planet Proximity",
			"star_color": Color(1.0, 1.0, 0.9),  # Bright white star
			"star_intensity": 1.5,
			"star_direction": Vector3(-0.4, -0.6, -0.5).normalized(),
			"ambient_color": Color(0.2, 0.15, 0.1),  # Planet-reflected light
			"ambient_energy": 0.25,
			"shadow_enabled": true,
			"shadow_distance": 8000.0
		},
		LightingProfile.ASTEROID_FIELD: {
			"name": "Asteroid Field",
			"star_color": Color(1.0, 0.9, 0.7),  # Slightly warm star
			"star_intensity": 1.0,
			"star_direction": Vector3(-0.6, -0.2, -0.8).normalized(),
			"ambient_color": Color(0.1, 0.1, 0.15),  # Scattered asteroid light
			"ambient_energy": 0.2,
			"shadow_enabled": true,
			"shadow_distance": 2000.0  # Shorter for performance
		}
	}

func _create_main_star_light() -> void:
	main_star_light = DirectionalLight3D.new()
	main_star_light.name = "MainStarLight"
	
	# Configure for space environment
	main_star_light.light_energy = 1.2
	main_star_light.light_color = Color(1.0, 0.95, 0.8)
	main_star_light.shadow_enabled = true
	main_star_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	main_star_light.directional_shadow_max_distance = 5000.0
	main_star_light.directional_shadow_split_1 = 0.1
	main_star_light.directional_shadow_split_2 = 0.3
	main_star_light.directional_shadow_split_3 = 0.6
	
	# Position like a distant star (default deep space)
	main_star_light.rotation_degrees = Vector3(-30, 45, 0)
	
	add_child(main_star_light)

func _create_ambient_environment() -> void:
	ambient_environment = Environment.new()
	
	# Space-appropriate ambient lighting
	ambient_environment.background_mode = Environment.BG_COLOR
	ambient_environment.background_color = Color.BLACK
	ambient_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambient_environment.ambient_light_color = Color(0.05, 0.05, 0.1)
	ambient_environment.ambient_light_energy = 0.1
	
	# HDR for realistic space lighting
	ambient_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambient_environment.tonemap_exposure = 1.0
	
	# Subtle glow for energy effects
	ambient_environment.glow_enabled = true
	ambient_environment.glow_intensity = 0.4
	ambient_environment.glow_strength = 1.2
	ambient_environment.glow_bloom = 0.1

func apply_lighting_profile(profile: LightingProfile) -> void:
	if profile not in lighting_profiles:
		push_warning("Invalid lighting profile: " + str(profile))
		return
	
	current_profile = profile
	var profile_data: Dictionary = lighting_profiles[profile]
	
	# Configure main star light
	main_star_light.light_color = profile_data.star_color
	main_star_light.light_energy = profile_data.star_intensity
	var direction: Vector3 = profile_data.star_direction
	main_star_light.look_at(main_star_light.global_position + direction, Vector3.UP)
	
	# Configure ambient lighting
	ambient_environment.ambient_light_color = profile_data.ambient_color
	ambient_environment.ambient_light_energy = profile_data.ambient_energy
	
	# Configure shadows
	main_star_light.shadow_enabled = profile_data.get("shadow_enabled", true)
	main_star_light.directional_shadow_max_distance = profile_data.get("shadow_distance", 5000.0)
	
	# Configure fog if specified
	if profile_data.has("fog_enabled") and profile_data.fog_enabled:
		ambient_environment.fog_enabled = true
		ambient_environment.fog_light_color = profile_data.get("fog_color", Color.BLACK)
		ambient_environment.fog_density = 0.01
	else:
		ambient_environment.fog_enabled = false
	
	print("WCSLightingController: Applied lighting profile: ", profile_data.name)
	lighting_profile_changed.emit(profile_data.name)
	ambient_light_updated.emit(profile_data.ambient_color, profile_data.ambient_energy)
	main_star_light_configured.emit(direction, profile_data.star_intensity)

func create_dynamic_light(light_type: DynamicLightType, position: Vector3, 
						 properties: Dictionary = {}) -> String:
	var light_id: String = _generate_light_id(light_type)
	var light: Light3D = dynamic_light_pool.get_light(light_type)
	
	if not light:
		push_warning("Failed to create dynamic light: pool exhausted")
		return ""
	
	# Configure light based on type
	_configure_dynamic_light(light, light_type, properties)
	
	# Position the light
	light.global_position = position
	add_child(light)
	
	# Track the light
	active_dynamic_lights[light_id] = {
		"light": light,
		"type": light_type,
		"created_time": Time.get_ticks_msec(),
		"priority": properties.get("priority", 5)
	}
	
	# Auto-cleanup timer if specified
	var lifetime: float = properties.get("lifetime", 0.0)
	if lifetime > 0.0:
		var timer: Timer = Timer.new()
		timer.wait_time = lifetime
		timer.one_shot = true
		timer.timeout.connect(func(): destroy_dynamic_light(light_id))
		add_child(timer)
		timer.start()
	
	dynamic_light_created.emit(light_id, light)
	return light_id

func _configure_dynamic_light(light: Light3D, light_type: DynamicLightType, 
							 properties: Dictionary) -> void:
	match light_type:
		DynamicLightType.WEAPON_MUZZLE_FLASH:
			_configure_muzzle_flash_light(light, properties)
		DynamicLightType.LASER_BEAM:
			_configure_laser_beam_light(light, properties)
		DynamicLightType.EXPLOSION:
			_configure_explosion_light(light, properties)
		DynamicLightType.ENGINE_GLOW:
			_configure_engine_glow_light(light, properties)
		DynamicLightType.THRUSTER:
			_configure_thruster_light(light, properties)
		DynamicLightType.SHIELD_IMPACT:
			_configure_shield_impact_light(light, properties)

func _configure_muzzle_flash_light(light: Light3D, properties: Dictionary) -> void:
	if light is OmniLight3D:
		var omni_light: OmniLight3D = light as OmniLight3D
		omni_light.light_color = properties.get("color", Color.WHITE)
		omni_light.light_energy = properties.get("intensity", 3.0)
		omni_light.omni_range = properties.get("range", 25.0)
		omni_light.omni_attenuation = 2.0  # Rapid falloff for muzzle flash

func _configure_laser_beam_light(light: Light3D, properties: Dictionary) -> void:
	if light is SpotLight3D:
		var spot_light: SpotLight3D = light as SpotLight3D
		spot_light.light_color = properties.get("color", Color.RED)
		spot_light.light_energy = properties.get("intensity", 2.0)
		spot_light.spot_range = properties.get("range", 50.0)
		spot_light.spot_angle = 15.0  # Narrow beam for laser

func _configure_explosion_light(light: Light3D, properties: Dictionary) -> void:
	if light is OmniLight3D:
		var omni_light: OmniLight3D = light as OmniLight3D
		omni_light.light_color = properties.get("color", Color.ORANGE)
		omni_light.light_energy = properties.get("intensity", 5.0)
		omni_light.omni_range = properties.get("range", 100.0)
		omni_light.omni_attenuation = 1.5  # Gradual falloff for explosion

func _configure_engine_glow_light(light: Light3D, properties: Dictionary) -> void:
	if light is OmniLight3D:
		var omni_light: OmniLight3D = light as OmniLight3D
		omni_light.light_color = properties.get("color", Color.CYAN)
		omni_light.light_energy = properties.get("intensity", 1.5)
		omni_light.omni_range = properties.get("range", 30.0)
		omni_light.omni_attenuation = 1.2

func _configure_thruster_light(light: Light3D, properties: Dictionary) -> void:
	if light is SpotLight3D:
		var spot_light: SpotLight3D = light as SpotLight3D
		spot_light.light_color = properties.get("color", Color.BLUE)
		spot_light.light_energy = properties.get("intensity", 2.0)
		spot_light.spot_range = properties.get("range", 40.0)
		spot_light.spot_angle = 30.0  # Cone for thruster exhaust

func _configure_shield_impact_light(light: Light3D, properties: Dictionary) -> void:
	if light is OmniLight3D:
		var omni_light: OmniLight3D = light as OmniLight3D
		omni_light.light_color = properties.get("color", Color.GREEN)
		omni_light.light_energy = properties.get("intensity", 2.5)
		omni_light.omni_range = properties.get("range", 35.0)
		omni_light.omni_attenuation = 1.8  # Quick falloff for shield impact

func destroy_dynamic_light(light_id: String) -> void:
	if light_id not in active_dynamic_lights:
		return
	
	var light_data: Dictionary = active_dynamic_lights[light_id]
	var light: Light3D = light_data.light
	
	# Return light to pool
	dynamic_light_pool.return_light(light, light_data.type)
	
	# Remove from tracking
	active_dynamic_lights.erase(light_id)
	
	dynamic_light_destroyed.emit(light_id)

func _generate_light_id(light_type: DynamicLightType) -> String:
	var type_name: String = DynamicLightType.keys()[light_type].to_lower()
	var timestamp: int = Time.get_ticks_msec()
	var random_suffix: int = randi() % 1000
	return "%s_%d_%d" % [type_name, timestamp, random_suffix]

func create_weapon_muzzle_flash(position: Vector3, color: Color = Color.WHITE, 
							   intensity: float = 3.0, range: float = 25.0,
							   lifetime: float = 0.15) -> String:
	var properties: Dictionary = {
		"color": color,
		"intensity": intensity,
		"range": range,
		"lifetime": lifetime,
		"priority": 8
	}
	return create_dynamic_light(DynamicLightType.WEAPON_MUZZLE_FLASH, position, properties)

func create_explosion_light(position: Vector3, explosion_type: String = "medium",
						   scale_factor: float = 1.0, lifetime: float = 2.0) -> String:
	var properties: Dictionary = {
		"lifetime": lifetime,
		"priority": 7
	}
	
	# Configure based on explosion type
	match explosion_type:
		"small":
			properties["color"] = Color.ORANGE
			properties["intensity"] = 3.0 * scale_factor
			properties["range"] = 50.0 * scale_factor
		"medium":
			properties["color"] = Color.RED
			properties["intensity"] = 5.0 * scale_factor
			properties["range"] = 80.0 * scale_factor
		"large":
			properties["color"] = Color.YELLOW
			properties["intensity"] = 8.0 * scale_factor
			properties["range"] = 120.0 * scale_factor
		"capital":
			properties["color"] = Color.WHITE
			properties["intensity"] = 12.0 * scale_factor
			properties["range"] = 200.0 * scale_factor
	
	return create_dynamic_light(DynamicLightType.EXPLOSION, position, properties)

func create_engine_glow_lights(ship_node: Node3D, engine_positions: Array[Vector3],
							   color: Color = Color.CYAN, intensity: float = 1.5) -> Array[String]:
	var light_ids: Array[String] = []
	
	for engine_pos in engine_positions:
		var world_pos: Vector3 = ship_node.to_global(engine_pos)
		var properties: Dictionary = {
			"color": color,
			"intensity": intensity,
			"range": 30.0,
			"priority": 6
		}
		
		var light_id: String = create_dynamic_light(DynamicLightType.ENGINE_GLOW, world_pos, properties)
		if not light_id.is_empty():
			light_ids.append(light_id)
			
			# Parent the light to the ship for movement
			var light_data: Dictionary = active_dynamic_lights[light_id]
			var light: Light3D = light_data.light
			light.reparent(ship_node)
			light.position = engine_pos
	
	return light_ids

func set_lighting_quality(quality: int) -> void:
	quality_level = clamp(quality, 0, 4)
	
	# Adjust lighting based on quality
	match quality_level:
		0, 1:  # Low quality
			max_dynamic_lights = 16
			main_star_light.directional_shadow_max_distance = 2000.0
			main_star_light.shadow_enabled = false
		2:  # Medium quality
			max_dynamic_lights = 24
			main_star_light.directional_shadow_max_distance = 3500.0
			main_star_light.shadow_enabled = true
		3, 4:  # High/Ultra quality
			max_dynamic_lights = 32
			main_star_light.directional_shadow_max_distance = 5000.0
			main_star_light.shadow_enabled = true
	
	# Update light pool capacity
	if dynamic_light_pool:
		dynamic_light_pool.update_capacity(max_dynamic_lights)
	
	lighting_quality_adjusted.emit(quality_level)
	print("WCSLightingController: Lighting quality set to level ", quality_level)

func get_lighting_statistics() -> Dictionary:
	return {
		"current_profile": LightingProfile.keys()[current_profile],
		"active_dynamic_lights": active_dynamic_lights.size(),
		"max_dynamic_lights": max_dynamic_lights,
		"quality_level": quality_level,
		"ambient_intensity": ambient_environment.ambient_light_energy,
		"star_intensity": main_star_light.light_energy,
		"shadows_enabled": main_star_light.shadow_enabled,
		"light_pool_stats": dynamic_light_pool.get_pool_statistics() if dynamic_light_pool else {}
	}

func cleanup_expired_lights() -> void:
	# Remove any lights that should have been cleaned up
	var current_time: int = Time.get_ticks_msec()
	var expired_lights: Array[String] = []
	
	for light_id in active_dynamic_lights:
		var light_data: Dictionary = active_dynamic_lights[light_id]
		var age: float = (current_time - light_data.created_time) / 1000.0
		
		# Clean up very old lights (failsafe)
		if age > 30.0:  # 30 seconds max lifetime
			expired_lights.append(light_id)
	
	for light_id in expired_lights:
		destroy_dynamic_light(light_id)

func get_environment() -> Environment:
	return ambient_environment

func _exit_tree() -> void:
	# Clean up all dynamic lights
	for light_id in active_dynamic_lights.keys():
		destroy_dynamic_light(light_id)