class_name RenderStateManager
extends RefCounted

## Godot rendering state management and optimization

var current_environment: Environment
var current_camera_effects: CameraAttributes
var render_layers: Dictionary = {}
var viewport_config: Dictionary = {}

func _init() -> void:
	setup_default_environment()

func configure_space_environment() -> void:
	print("RenderStateManager: Configuring space environment")
	
	# Create space-appropriate environment
	current_environment = Environment.new()
	
	# Background configuration for space
	current_environment.background_mode = Environment.BG_SKY
	current_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	current_environment.ambient_light_energy = 0.1
	current_environment.ambient_light_color = Color(0.05, 0.05, 0.1)
	
	# Tone mapping for space visuals
	current_environment.tonemap_exposure = 1.0
	
	# Glow/bloom settings for energy effects
	current_environment.glow_enabled = true
	current_environment.glow_intensity = 1.0
	current_environment.glow_strength = 0.8
	current_environment.glow_bloom = 0.1
	current_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	# Fog configuration for depth
	current_environment.fog_enabled = false  # Space has no fog by default
	
	# Sky configuration
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color.BLACK
	sky_material.sky_horizon_color = Color(0.1, 0.1, 0.2)
	sky_material.ground_bottom_color = Color.BLACK
	sky_material.ground_horizon_color = Color.BLACK
	sky_material.sun_angle_max = 0.0  # No sun disk
	sky.sky_material = sky_material
	current_environment.sky = sky
	
	# Apply to main viewport
	apply_environment_to_viewport()

func setup_default_environment() -> void:
	current_environment = Environment.new()
	current_camera_effects = CameraAttributes.new()

func apply_environment_to_viewport() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree and current_environment:
		var main_viewport: Window = scene_tree.get_root()
		if main_viewport:
			main_viewport.world_3d.environment = current_environment
			print("RenderStateManager: Applied environment to main viewport")

func configure_viewport_for_quality(quality_level: int) -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		push_error("Could not get scene tree")
		return
	var main_viewport: Window = scene_tree.get_root()
	if not main_viewport:
		push_error("Could not get main viewport")
		return
	
	match quality_level:
		0: # Low
			main_viewport.msaa_3d = Viewport.MSAA_DISABLED
			main_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			main_viewport.use_taa = false
		1: # Medium
			main_viewport.msaa_3d = Viewport.MSAA_2X
			main_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			main_viewport.use_taa = false
		2: # High
			main_viewport.msaa_3d = Viewport.MSAA_4X
			main_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			main_viewport.use_taa = false
		3: # Ultra
			main_viewport.msaa_3d = Viewport.MSAA_8X
			main_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			main_viewport.use_taa = true
	
	print("RenderStateManager: Configured viewport for quality level ", quality_level)

func configure_camera_effects(quality_level: int) -> void:
	if not current_camera_effects:
		current_camera_effects = CameraAttributes.new()
	
	# Configure camera attributes based on quality
	# Note: DOF effects moved to post-processing in Godot 4.4
	match quality_level:
		0, 1: # Low/Medium
			if current_camera_effects is CameraAttributesPractical:
				(current_camera_effects as CameraAttributesPractical).auto_exposure_enabled = false
		2: # High  
			if current_camera_effects is CameraAttributesPractical:
				(current_camera_effects as CameraAttributesPractical).auto_exposure_enabled = true
				(current_camera_effects as CameraAttributesPractical).auto_exposure_speed = 0.5
		3: # Ultra
			if current_camera_effects is CameraAttributesPractical:
				(current_camera_effects as CameraAttributesPractical).auto_exposure_enabled = true
				(current_camera_effects as CameraAttributesPractical).auto_exposure_speed = 1.0

func set_render_layer_visibility(layer: int, visible: bool) -> void:
	render_layers[layer] = visible

func get_render_layer_visibility(layer: int) -> bool:
	return render_layers.get(layer, true)

func configure_lighting_for_space() -> void:
	if current_environment:
		# Ensure space-appropriate lighting
		current_environment.ambient_light_energy = 0.1
		current_environment.ambient_light_color = Color(0.05, 0.05, 0.1)

func set_bloom_settings(enabled: bool, intensity: float, threshold: float) -> void:
	if current_environment:
		current_environment.glow_enabled = enabled
		current_environment.glow_intensity = intensity
		current_environment.glow_strength = threshold

func get_current_environment() -> Environment:
	return current_environment

func get_current_camera_effects() -> CameraAttributes:
	return current_camera_effects

func cleanup() -> void:
	current_environment = null
	current_camera_effects = null
	render_layers.clear()
	viewport_config.clear()