class_name SpaceLightingProfile
extends Resource

## Configuration data for space environment lighting profiles
## Defines lighting characteristics for different space environments

@export var profile_name: String = ""
@export var description: String = ""

# Star lighting configuration
@export var star_color: Color = Color.WHITE
@export var star_intensity: float = 1.0
@export var star_direction: Vector3 = Vector3(-0.5, -0.3, -0.8)

# Ambient lighting configuration
@export var ambient_color: Color = Color(0.1, 0.1, 0.15)
@export var ambient_energy: float = 0.15

# Shadow configuration
@export var shadow_enabled: bool = true
@export var shadow_distance: float = 5000.0
@export var shadow_split_1: float = 0.1
@export var shadow_split_2: float = 0.3
@export var shadow_split_3: float = 0.6

# Environment effects
@export var fog_enabled: bool = false
@export var fog_color: Color = Color.BLACK
@export var fog_density: float = 0.01
@export var fog_start: float = 100.0
@export var fog_end: float = 1000.0

# HDR and tone mapping
@export var tonemap_mode: Environment.ToneMapper = Environment.TONE_MAPPER_ACES
@export var tonemap_exposure: float = 1.0
@export var tonemap_white: float = 1.0

# Glow and bloom effects
@export var glow_enabled: bool = true
@export var glow_intensity: float = 0.4
@export var glow_strength: float = 1.2
@export var glow_bloom: float = 0.1

# Performance optimization settings
@export var max_dynamic_lights: int = 32
@export var light_culling_distance: float = 1000.0
@export var shadow_quality_multiplier: float = 1.0

func _init() -> void:
	resource_name = "SpaceLightingProfile"

func validate() -> bool:
	# Validate profile settings
	if profile_name.is_empty():
		push_error("SpaceLightingProfile: Profile name cannot be empty")
		return false
	
	if star_intensity < 0.0 or star_intensity > 10.0:
		push_error("SpaceLightingProfile: Star intensity must be between 0.0 and 10.0")
		return false
	
	if ambient_energy < 0.0 or ambient_energy > 2.0:
		push_error("SpaceLightingProfile: Ambient energy must be between 0.0 and 2.0") 
		return false
	
	if shadow_distance < 100.0 or shadow_distance > 20000.0:
		push_error("SpaceLightingProfile: Shadow distance must be between 100.0 and 20000.0")
		return false
	
	return true

func apply_to_environment(environment: Environment) -> void:
	if not environment:
		push_error("SpaceLightingProfile: Cannot apply to null environment")
		return
	
	# Configure background
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	
	# Configure ambient lighting
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = ambient_energy
	
	# Configure tone mapping
	environment.tonemap_mode = tonemap_mode
	environment.tonemap_exposure = tonemap_exposure
	environment.tonemap_white = tonemap_white
	
	# Configure glow effects
	environment.glow_enabled = glow_enabled
	environment.glow_intensity = glow_intensity
	environment.glow_strength = glow_strength
	environment.glow_bloom = glow_bloom
	
	# Configure fog
	environment.fog_enabled = fog_enabled
	if fog_enabled:
		environment.fog_light_color = fog_color
		environment.fog_density = fog_density

func apply_to_directional_light(light: DirectionalLight3D) -> void:
	if not light:
		push_error("SpaceLightingProfile: Cannot apply to null directional light")
		return
	
	# Configure light properties
	light.light_color = star_color
	light.light_energy = star_intensity
	
	# Configure shadows
	light.shadow_enabled = shadow_enabled
	if shadow_enabled:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = shadow_distance
		light.directional_shadow_split_1 = shadow_split_1
		light.directional_shadow_split_2 = shadow_split_2
		light.directional_shadow_split_3 = shadow_split_3
	
	# Position the light according to star direction
	var normalized_dir: Vector3 = star_direction.normalized()
	light.look_at(light.global_position + normalized_dir, Vector3.UP)

func get_performance_multiplier() -> float:
	# Calculate performance impact multiplier based on settings
	var multiplier: float = 1.0
	
	if shadow_enabled:
		multiplier += 0.3 * shadow_quality_multiplier
	
	if glow_enabled:
		multiplier += 0.1 * glow_intensity
	
	if fog_enabled:
		multiplier += 0.05
	
	multiplier *= float(max_dynamic_lights) / 32.0
	
	return multiplier

func create_deep_space_profile() -> SpaceLightingProfile:
	var profile: SpaceLightingProfile = SpaceLightingProfile.new()
	profile.profile_name = "Deep Space"
	profile.description = "Minimal ambient lighting with single star source"
	
	profile.star_color = Color(1.0, 0.95, 0.8)
	profile.star_intensity = 1.2
	profile.star_direction = Vector3(-0.5, -0.3, -0.8).normalized()
	
	profile.ambient_color = Color(0.05, 0.05, 0.1)
	profile.ambient_energy = 0.1
	
	profile.shadow_enabled = true
	profile.shadow_distance = 5000.0
	
	profile.fog_enabled = false
	profile.max_dynamic_lights = 32
	
	return profile

func create_nebula_profile() -> SpaceLightingProfile:
	var profile: SpaceLightingProfile = SpaceLightingProfile.new()
	profile.profile_name = "Nebula Environment"
	profile.description = "Colored ambient lighting with atmospheric effects"
	
	profile.star_color = Color(0.9, 0.7, 1.0)
	profile.star_intensity = 0.8
	profile.star_direction = Vector3(-0.3, -0.5, -0.7).normalized()
	
	profile.ambient_color = Color(0.3, 0.1, 0.4)
	profile.ambient_energy = 0.35
	
	profile.shadow_enabled = true
	profile.shadow_distance = 3000.0
	
	profile.fog_enabled = true
	profile.fog_color = Color(0.2, 0.05, 0.3)
	profile.fog_density = 0.01
	
	profile.glow_intensity = 0.6
	profile.max_dynamic_lights = 28
	
	return profile

func create_planet_proximity_profile() -> SpaceLightingProfile:
	var profile: SpaceLightingProfile = SpaceLightingProfile.new()
	profile.profile_name = "Planet Proximity"
	profile.description = "Enhanced lighting with planetary reflection"
	
	profile.star_color = Color(1.0, 1.0, 0.9)
	profile.star_intensity = 1.5
	profile.star_direction = Vector3(-0.4, -0.6, -0.5).normalized()
	
	profile.ambient_color = Color(0.2, 0.15, 0.1)
	profile.ambient_energy = 0.25
	
	profile.shadow_enabled = true
	profile.shadow_distance = 8000.0
	
	profile.fog_enabled = false
	profile.max_dynamic_lights = 24
	
	return profile

func create_asteroid_field_profile() -> SpaceLightingProfile:
	var profile: SpaceLightingProfile = SpaceLightingProfile.new()
	profile.profile_name = "Asteroid Field"
	profile.description = "Multiple shadows with performance optimization"
	
	profile.star_color = Color(1.0, 0.9, 0.7)
	profile.star_intensity = 1.0
	profile.star_direction = Vector3(-0.6, -0.2, -0.8).normalized()
	
	profile.ambient_color = Color(0.1, 0.1, 0.15)
	profile.ambient_energy = 0.2
	
	profile.shadow_enabled = true
	profile.shadow_distance = 2000.0  # Reduced for performance
	profile.shadow_quality_multiplier = 0.7
	
	profile.fog_enabled = false
	profile.max_dynamic_lights = 20  # Reduced for performance
	profile.light_culling_distance = 500.0
	
	return profile