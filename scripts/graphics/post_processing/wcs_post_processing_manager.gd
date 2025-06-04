class_name WCSPostProcessingManager
extends Node

## Post-processing effects and visual enhancement system for WCS-style graphics
## Manages bloom, color correction, screen effects, and performance optimization

signal post_processing_enabled(effect_name: String)
signal post_processing_disabled(effect_name: String)
signal post_processing_quality_changed(effect_name: String, quality: int)
signal screen_effect_triggered(effect_type: String, intensity: float)

enum PostProcessEffect {
	BLOOM,
	MOTION_BLUR,
	COLOR_CORRECTION,
	SCREEN_DISTORTION,
	HEAT_HAZE,
	DAMAGE_OVERLAY,
	LENS_FLARE,
	CHROMATIC_ABERRATION
}

# Environment and camera effects
var environment: Environment
var camera_effects: CameraAttributes
var viewport: Viewport

# Post-processing configuration
var bloom_enabled: bool = true
var bloom_intensity: float = 1.0
var bloom_threshold: float = 0.6
var motion_blur_enabled: bool = true
var motion_blur_scale: float = 1.0
var color_correction_enabled: bool = true

# Screen effects
var active_screen_effects: Dictionary = {}
var screen_effect_materials: Dictionary = {}

# Quality settings
var current_quality_level: int = 2
var quality_multipliers: Dictionary = {
	0: {"bloom": 0.0, "blur": 0.0, "effects": 0.3},      # Low
	1: {"bloom": 0.5, "blur": 0.0, "effects": 0.6},      # Medium  
	2: {"bloom": 1.0, "blur": 0.5, "effects": 0.8},      # High
	3: {"bloom": 1.5, "blur": 1.0, "effects": 1.0}       # Ultra
}

func _ready() -> void:
	name = "WCSPostProcessingManager"
	_initialize_post_processing()
	print("WCSPostProcessingManager: Initialized with WCS-style post-processing")

func _initialize_post_processing() -> void:
	viewport = get_viewport()
	_setup_environment()
	_setup_camera_effects()
	_create_screen_effect_materials()
	_apply_quality_settings(current_quality_level)

func _setup_environment() -> void:
	environment = Environment.new()
	
	# HDR and tone mapping for space environment
	environment.background_mode = Environment.BG_SKY
	environment.tonemap_mode = Environment.TONE_MAP_ACES
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 4.0
	
	# Bloom configuration for WCS-style energy effects
	environment.glow_enabled = bloom_enabled
	environment.glow_intensity = bloom_intensity
	environment.glow_strength = 0.8
	environment.glow_bloom = bloom_threshold
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.glow_hdr_threshold = 0.8
	environment.glow_hdr_scale = 2.0
	
	# Color correction for WCS visual style
	environment.adjustment_enabled = color_correction_enabled
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 1.2
	environment.adjustment_color_correction = null  # Custom color correction
	
	# Apply to viewport
	if viewport:
		viewport.render_scene_buffers.connect(_on_render_scene_buffers)
		viewport.environment = environment

func _setup_camera_effects() -> void:
	var camera: Camera3D = viewport.get_camera_3d()
	if not camera:
		return
	
	# Create camera attributes for motion blur and other effects
	camera_effects = CameraAttributesPractical.new()
	
	# Configure for space environment
	camera_effects.auto_exposure_enabled = false
	camera_effects.exposure_multiplier = 1.0
	
	# Apply to camera
	camera.attributes = camera_effects

func _create_screen_effect_materials() -> void:
	# Create shader materials for screen effects
	_create_screen_distortion_material()
	_create_heat_haze_material()
	_create_damage_overlay_material()
	_create_lens_flare_material()

func _create_screen_distortion_material() -> void:
	var distortion_shader: Shader = load("res://shaders/post_processing/screen_distortion.gdshader")
	if not distortion_shader:
		# Create fallback shader
		distortion_shader = _create_fallback_screen_shader("screen_distortion")
	
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = distortion_shader
	material.set_shader_parameter("distortion_intensity", 0.0)
	material.set_shader_parameter("distortion_center", Vector2(0.5, 0.5))
	material.set_shader_parameter("distortion_radius", 0.3)
	material.set_shader_parameter("time", 0.0)
	
	screen_effect_materials["screen_distortion"] = material

func _create_heat_haze_material() -> void:
	var haze_shader: Shader = load("res://shaders/post_processing/heat_haze.gdshader")
	if not haze_shader:
		haze_shader = _create_fallback_screen_shader("heat_haze")
	
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = haze_shader
	material.set_shader_parameter("haze_intensity", 0.0)
	material.set_shader_parameter("haze_speed", 2.0)
	material.set_shader_parameter("noise_scale", 10.0)
	material.set_shader_parameter("time", 0.0)
	
	screen_effect_materials["heat_haze"] = material

func _create_damage_overlay_material() -> void:
	var damage_shader: Shader = load("res://shaders/post_processing/damage_overlay.gdshader")
	if not damage_shader:
		damage_shader = _create_fallback_screen_shader("damage_overlay")
	
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = damage_shader
	material.set_shader_parameter("damage_level", 0.0)
	material.set_shader_parameter("edge_damage", 0.0)
	material.set_shader_parameter("static_intensity", 0.0)
	material.set_shader_parameter("red_tint", 0.0)
	
	screen_effect_materials["damage_overlay"] = material

func _create_lens_flare_material() -> void:
	var flare_shader: Shader = load("res://shaders/post_processing/lens_flare.gdshader")
	if not flare_shader:
		flare_shader = _create_fallback_screen_shader("lens_flare")
	
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = flare_shader
	material.set_shader_parameter("flare_intensity", 0.0)
	material.set_shader_parameter("flare_position", Vector2(0.5, 0.5))
	material.set_shader_parameter("flare_size", 1.0)
	material.set_shader_parameter("color_tint", Color.WHITE)
	
	screen_effect_materials["lens_flare"] = material

func _create_fallback_screen_shader(effect_name: String) -> Shader:
	# Create a simple fallback shader for missing post-processing shaders
	var shader: Shader = Shader.new()
	var shader_code: String = """
shader_type canvas_item;

uniform float effect_intensity : hint_range(0.0, 2.0) = 0.0;
uniform vec2 screen_center = vec2(0.5, 0.5);
uniform float time = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 color = texture(SCREEN_TEXTURE, uv);
	
	// Simple effect based on name
	if (effect_intensity > 0.0) {
		float dist = distance(uv, screen_center);
		color.rgb *= (1.0 + effect_intensity * 0.1 * sin(time + dist * 10.0));
	}
	
	COLOR = color;
}
"""
	shader.code = shader_code
	print("WCSPostProcessingManager: Created fallback shader for: " + effect_name)
	return shader

func set_bloom_settings(enabled: bool, intensity: float, threshold: float) -> void:
	bloom_enabled = enabled
	bloom_intensity = intensity
	bloom_threshold = threshold
	
	if environment:
		environment.glow_enabled = enabled
		environment.glow_intensity = intensity * _get_quality_multiplier("bloom")
		environment.glow_bloom = threshold
		
		post_processing_quality_changed.emit("bloom", current_quality_level)

func set_motion_blur_settings(enabled: bool, scale: float) -> void:
	motion_blur_enabled = enabled
	motion_blur_scale = scale
	
	# Motion blur in Godot is typically handled via velocity buffers
	# This is a simplified implementation
	var multiplier: float = _get_quality_multiplier("blur")
	if enabled and multiplier > 0.0:
		_enable_motion_blur(scale * multiplier)
	else:
		_disable_motion_blur()

func _enable_motion_blur(scale: float) -> void:
	# Enable motion blur if supported
	if camera_effects:
		# Motion blur implementation would go here
		# Currently Godot doesn't have built-in motion blur
		pass

func _disable_motion_blur() -> void:
	# Disable motion blur
	if camera_effects:
		# Motion blur disabling would go here
		pass

func set_color_correction_settings(enabled: bool, brightness: float = 1.0, 
								  contrast: float = 1.1, saturation: float = 1.2) -> void:
	color_correction_enabled = enabled
	
	if environment:
		environment.adjustment_enabled = enabled
		environment.adjustment_brightness = brightness
		environment.adjustment_contrast = contrast
		environment.adjustment_saturation = saturation

func apply_explosion_distortion(center: Vector2, intensity: float, duration: float) -> void:
	var material: ShaderMaterial = screen_effect_materials.get("screen_distortion")
	if not material:
		return
	
	# Apply distortion effect
	material.set_shader_parameter("distortion_center", center)
	material.set_shader_parameter("distortion_intensity", intensity)
	
	# Animate distortion
	var tween: Tween = create_tween()
	tween.tween_method(
		func(value): material.set_shader_parameter("distortion_intensity", value),
		intensity, 0.0, duration
	)
	
	screen_effect_triggered.emit("explosion_distortion", intensity)

func apply_heat_haze_effect(intensity: float, duration: float = -1.0) -> void:
	var material: ShaderMaterial = screen_effect_materials.get("heat_haze")
	if not material:
		return
	
	material.set_shader_parameter("haze_intensity", intensity * _get_quality_multiplier("effects"))
	
	if duration > 0.0:
		# Temporary effect
		var tween: Tween = create_tween()
		tween.tween_delay(duration)
		tween.tween_method(
			func(value): material.set_shader_parameter("haze_intensity", value),
			intensity, 0.0, 0.5
		)
	
	screen_effect_triggered.emit("heat_haze", intensity)

func apply_damage_overlay(damage_level: float) -> void:
	var material: ShaderMaterial = screen_effect_materials.get("damage_overlay")
	if not material:
		return
	
	var effects_multiplier: float = _get_quality_multiplier("effects")
	
	material.set_shader_parameter("damage_level", damage_level * effects_multiplier)
	material.set_shader_parameter("edge_damage", damage_level * 0.5 * effects_multiplier)
	material.set_shader_parameter("static_intensity", damage_level * 0.3 * effects_multiplier)
	material.set_shader_parameter("red_tint", damage_level * 0.2 * effects_multiplier)
	
	screen_effect_triggered.emit("damage_overlay", damage_level)

func apply_lens_flare(sun_position: Vector2, intensity: float) -> void:
	var material: ShaderMaterial = screen_effect_materials.get("lens_flare")
	if not material:
		return
	
	material.set_shader_parameter("flare_position", sun_position)
	material.set_shader_parameter("flare_intensity", intensity * _get_quality_multiplier("effects"))
	material.set_shader_parameter("color_tint", Color(1.0, 0.9, 0.7))  # Sun color
	
	screen_effect_triggered.emit("lens_flare", intensity)

func set_quality_level(quality: int) -> void:
	current_quality_level = clamp(quality, 0, 3)
	_apply_quality_settings(current_quality_level)
	print("WCSPostProcessingManager: Quality set to level %d" % current_quality_level)

func _apply_quality_settings(quality: int) -> void:
	var multipliers: Dictionary = quality_multipliers.get(quality, quality_multipliers[2])
	
	# Apply bloom quality
	if environment:
		var bloom_mult: float = multipliers.get("bloom", 1.0)
		environment.glow_enabled = bloom_enabled and bloom_mult > 0.0
		environment.glow_intensity = bloom_intensity * bloom_mult
		
		# Adjust bloom quality
		match quality:
			0:  # Low - disable bloom
				environment.glow_enabled = false
			1:  # Medium - basic bloom
				environment.glow_levels = 4
			2:  # High - enhanced bloom  
				environment.glow_levels = 6
			3:  # Ultra - full bloom
				environment.glow_levels = 7
	
	# Apply screen effects quality
	var effects_mult: float = multipliers.get("effects", 1.0)
	_update_screen_effects_quality(effects_mult)
	
	# Emit quality change signals
	for effect in PostProcessEffect.values():
		var effect_name: String = PostProcessEffect.keys()[effect]
		post_processing_quality_changed.emit(effect_name.to_lower(), quality)

func _update_screen_effects_quality(multiplier: float) -> void:
	# Update all screen effect materials with quality multiplier
	for effect_name in screen_effect_materials:
		var material: ShaderMaterial = screen_effect_materials[effect_name]
		if material.shader and material.shader.has_shader_param("quality_multiplier"):
			material.set_shader_parameter("quality_multiplier", multiplier)

func _get_quality_multiplier(effect_type: String) -> float:
	var multipliers: Dictionary = quality_multipliers.get(current_quality_level, quality_multipliers[2])
	return multipliers.get(effect_type, 1.0)

func clear_all_screen_effects() -> void:
	# Clear all active screen effects
	for effect_name in screen_effect_materials:
		var material: ShaderMaterial = screen_effect_materials[effect_name]
		match effect_name:
			"screen_distortion":
				material.set_shader_parameter("distortion_intensity", 0.0)
			"heat_haze":
				material.set_shader_parameter("haze_intensity", 0.0)
			"damage_overlay":
				material.set_shader_parameter("damage_level", 0.0)
			"lens_flare":
				material.set_shader_parameter("flare_intensity", 0.0)
	
	active_screen_effects.clear()

func get_post_processing_statistics() -> Dictionary:
	return {
		"quality_level": current_quality_level,
		"bloom_enabled": bloom_enabled and environment.glow_enabled,
		"motion_blur_enabled": motion_blur_enabled,
		"color_correction_enabled": color_correction_enabled,
		"active_screen_effects": active_screen_effects.size(),
		"environment_configured": environment != null,
		"camera_effects_configured": camera_effects != null
	}

func enable_effect(effect: PostProcessEffect, properties: Dictionary = {}) -> void:
	var effect_name: String = PostProcessEffect.keys()[effect].to_lower()
	
	match effect:
		PostProcessEffect.BLOOM:
			var intensity: float = properties.get("intensity", 1.0)
			var threshold: float = properties.get("threshold", 0.6)
			set_bloom_settings(true, intensity, threshold)
			
		PostProcessEffect.MOTION_BLUR:
			var scale: float = properties.get("scale", 1.0)
			set_motion_blur_settings(true, scale)
			
		PostProcessEffect.COLOR_CORRECTION:
			var brightness: float = properties.get("brightness", 1.0)
			var contrast: float = properties.get("contrast", 1.1)
			var saturation: float = properties.get("saturation", 1.2)
			set_color_correction_settings(true, brightness, contrast, saturation)
			
		PostProcessEffect.SCREEN_DISTORTION:
			var intensity: float = properties.get("intensity", 1.0)
			var center: Vector2 = properties.get("center", Vector2(0.5, 0.5))
			var duration: float = properties.get("duration", 1.0)
			apply_explosion_distortion(center, intensity, duration)
			
		PostProcessEffect.HEAT_HAZE:
			var intensity: float = properties.get("intensity", 1.0)
			var duration: float = properties.get("duration", -1.0)
			apply_heat_haze_effect(intensity, duration)
			
		PostProcessEffect.DAMAGE_OVERLAY:
			var damage_level: float = properties.get("damage_level", 0.5)
			apply_damage_overlay(damage_level)
			
		PostProcessEffect.LENS_FLARE:
			var position: Vector2 = properties.get("position", Vector2(0.5, 0.5))
			var intensity: float = properties.get("intensity", 1.0)
			apply_lens_flare(position, intensity)
	
	active_screen_effects[effect_name] = properties
	post_processing_enabled.emit(effect_name)

func disable_effect(effect: PostProcessEffect) -> void:
	var effect_name: String = PostProcessEffect.keys()[effect].to_lower()
	
	match effect:
		PostProcessEffect.BLOOM:
			set_bloom_settings(false, 0.0, 1.0)
		PostProcessEffect.MOTION_BLUR:
			set_motion_blur_settings(false, 0.0)
		PostProcessEffect.COLOR_CORRECTION:
			set_color_correction_settings(false)
		_:
			# Clear screen effect
			var material: ShaderMaterial = screen_effect_materials.get(effect_name)
			if material:
				_clear_screen_effect_material(material, effect_name)
	
	active_screen_effects.erase(effect_name)
	post_processing_disabled.emit(effect_name)

func _clear_screen_effect_material(material: ShaderMaterial, effect_name: String) -> void:
	match effect_name:
		"screen_distortion":
			material.set_shader_parameter("distortion_intensity", 0.0)
		"heat_haze":
			material.set_shader_parameter("haze_intensity", 0.0)
		"damage_overlay":
			material.set_shader_parameter("damage_level", 0.0)
		"lens_flare":
			material.set_shader_parameter("flare_intensity", 0.0)

func _process(delta: float) -> void:
	# Update time-based shader parameters
	var time: float = Time.get_ticks_msec() / 1000.0
	
	for material in screen_effect_materials.values():
		if material.shader and material.shader.has_shader_param("time"):
			material.set_shader_parameter("time", time)

func _on_render_scene_buffers() -> void:
	# Hook for custom post-processing effects
	# This would be called during rendering pipeline
	pass

func _exit_tree() -> void:
	clear_all_screen_effects()