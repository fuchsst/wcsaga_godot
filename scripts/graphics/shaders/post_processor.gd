class_name PostProcessor
extends RefCounted

## Post-processing pipeline for WCS-style screen effects
## Manages bloom, motion blur, color correction, and other screen-space effects

signal post_processing_initialized()
signal post_processing_effect_added(effect_name: String)
signal post_processing_effect_removed(effect_name: String)
signal post_processing_quality_changed(quality_level: int)

var active_post_effects: Dictionary = {}
var post_processing_environment: Environment
var quality_level: int = 2
var is_initialized: bool = false

# Effect configurations
var effect_configs: Dictionary = {}

func _init() -> void:
	_initialize_effect_configs()
	print("PostProcessor: Initialized with effect configurations")

## Initialize post-processing pipeline
func initialize_post_processing(viewport: Viewport) -> bool:
	if is_initialized:
		push_warning("PostProcessor: Already initialized")
		return true
	
	# Create environment for post-processing effects
	post_processing_environment = Environment.new()
	_configure_base_environment()
	
	# Apply to viewport if provided
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		# Note: Camera3D nodes will need to reference these directly
	
	is_initialized = true
	post_processing_initialized.emit()
	print("PostProcessor: Post-processing pipeline initialized")
	return true

## Configure base environment settings
func _configure_base_environment() -> void:
	if not post_processing_environment:
		return
	
	# Background and ambient settings for space
	post_processing_environment.background_mode = Environment.BG_SKY
	post_processing_environment.sky_custom_fov = 75.0
	post_processing_environment.ambient_light_energy = 0.1
	post_processing_environment.ambient_light_color = Color(0.2, 0.2, 0.3)
	
	# Initial post-processing setup
	_setup_bloom_effect()
	_setup_tone_mapping()
	_setup_color_correction()


## Set up bloom effect for energy weapons and engines
func _setup_bloom_effect() -> void:
	if not post_processing_environment:
		return
	
	post_processing_environment.glow_enabled = true
	post_processing_environment.glow_intensity = 0.8
	post_processing_environment.glow_strength = 1.2
	post_processing_environment.glow_bloom = 0.1
	post_processing_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	# HDR settings for bright effects
	post_processing_environment.glow_hdr_threshold = 1.0
	post_processing_environment.glow_hdr_scale = 2.0
	
	print("PostProcessor: Bloom effect configured")

## Set up tone mapping for HDR content
func _setup_tone_mapping() -> void:
	if not post_processing_environment:
		return
	
	post_processing_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	post_processing_environment.tonemap_exposure = 1.0
	post_processing_environment.tonemap_white = 1.0
	
	print("PostProcessor: Tone mapping configured")

## Set up color correction for WCS visual style
func _setup_color_correction() -> void:
	if not post_processing_environment:
		return
	
	# Slight color adjustments for space aesthetic
	post_processing_environment.adjustment_enabled = true
	post_processing_environment.adjustment_brightness = 1.0
	post_processing_environment.adjustment_contrast = 1.1
	post_processing_environment.adjustment_saturation = 1.05
	
	# Note: adjustment_color_correction requires a ColorCorrection resource in Godot 4.4
	# Using basic adjustments instead
	
	print("PostProcessor: Color correction configured")

## Add a post-processing effect
func add_post_effect(effect_name: String, effect_config: Dictionary = {}) -> bool:
	if effect_name in active_post_effects:
		push_warning("PostProcessor: Effect already active: " + effect_name)
		return false
	
	var success: bool = false
	
	match effect_name:
		"motion_blur":
			success = _add_motion_blur_effect(effect_config)
		"screen_distortion":
			success = _add_screen_distortion_effect(effect_config)
		"damage_overlay":
			success = _add_damage_overlay_effect(effect_config)
		"energy_discharge":
			success = _add_energy_discharge_effect(effect_config)
		"warp_effect":
			success = _add_warp_effect(effect_config)
		_:
			push_error("PostProcessor: Unknown post-processing effect: " + effect_name)
			return false
	
	if success:
		active_post_effects[effect_name] = effect_config
		post_processing_effect_added.emit(effect_name)
		print("PostProcessor: Added post-processing effect: " + effect_name)
	
	return success

## Remove a post-processing effect
func remove_post_effect(effect_name: String) -> bool:
	if not effect_name in active_post_effects:
		return false
	
	var success: bool = false
	
	match effect_name:
		"motion_blur":
			success = _remove_motion_blur_effect()
		"screen_distortion":
			success = _remove_screen_distortion_effect()
		"damage_overlay":
			success = _remove_damage_overlay_effect()
		"energy_discharge":
			success = _remove_energy_discharge_effect()
		"warp_effect":
			success = _remove_warp_effect()
		_:
			success = true  # Unknown effect, just remove from tracking
	
	if success:
		active_post_effects.erase(effect_name)
		post_processing_effect_removed.emit(effect_name)
		print("PostProcessor: Removed post-processing effect: " + effect_name)
	
	return success

## Update bloom intensity for weapon effects
func update_bloom_intensity(intensity: float, duration: float = 0.0) -> void:
	if not post_processing_environment:
		return
	
	var target_intensity: float = clamp(intensity, 0.0, 2.0)
	
	if duration > 0.0:
		# Would need tween for smooth animation
		print("PostProcessor: Bloom intensity animation requested (duration: %.2fs)" % duration)
	
	post_processing_environment.glow_intensity = target_intensity
	print("PostProcessor: Updated bloom intensity to %.2f" % target_intensity)

## Flash effect for explosions and impacts
func create_flash_effect(intensity: float = 2.0, duration: float = 0.1, 
						color: Color = Color.WHITE) -> void:
	if not post_processing_environment:
		return
	
	# Temporarily boost bloom
	var original_intensity: float = post_processing_environment.glow_intensity
	
	# Apply flash (only intensity for now)
	post_processing_environment.glow_intensity = intensity
	
	# Schedule restoration (would use timer in real implementation)
	print("PostProcessor: Flash effect triggered (intensity: %.2f, duration: %.2fs)" % [intensity, duration])
	
	# Note: In full implementation, this would use a Timer or Tween to restore original values

## Set quality level and adjust all post-processing effects
func set_quality_level(new_quality: int) -> void:
	quality_level = new_quality
	
	if not post_processing_environment:
		return
	
	match quality_level:
		0, 1:  # Low quality
			post_processing_environment.glow_enabled = false
			post_processing_environment.adjustment_enabled = false
			post_processing_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		2:     # Medium quality
			post_processing_environment.glow_enabled = true
			post_processing_environment.glow_intensity = 0.6
			post_processing_environment.adjustment_enabled = true
			post_processing_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		3, 4:  # High/Ultra quality
			post_processing_environment.glow_enabled = true
			post_processing_environment.glow_intensity = 0.8
			post_processing_environment.adjustment_enabled = true
			post_processing_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	
	post_processing_quality_changed.emit(quality_level)
	print("PostProcessor: Quality level set to %d" % quality_level)

## Get the configured environment for camera assignment
func get_environment() -> Environment:
	return post_processing_environment


## Initialize effect configurations
func _initialize_effect_configs() -> void:
	effect_configs = {
		"motion_blur": {
			"enabled": false,
			"strength": 0.5,
			"sample_count": 8,
			"velocity_scale": 1.0
		},
		
		"screen_distortion": {
			"enabled": false,
			"distortion_strength": 0.1,
			"center_offset": Vector2.ZERO,
			"barrel_power": 1.0
		},
		
		"damage_overlay": {
			"enabled": false,
			"damage_level": 0.0,
			"static_noise": 0.0,
			"color_shift": Color.RED
		},
		
		"energy_discharge": {
			"enabled": false,
			"discharge_intensity": 1.0,
			"flicker_rate": 10.0,
			"color": Color.CYAN
		},
		
		"warp_effect": {
			"enabled": false,
			"warp_factor": 0.0,
			"tunnel_effect": 0.0,
			"speed_lines": false
		}
	}

## Add motion blur effect (placeholder implementation)
func _add_motion_blur_effect(config: Dictionary) -> bool:
	# Motion blur would typically be implemented as a custom shader
	# or by using Godot's camera motion blur if available
	print("PostProcessor: Motion blur effect added (placeholder)")
	return true

## Remove motion blur effect
func _remove_motion_blur_effect() -> bool:
	print("PostProcessor: Motion blur effect removed")
	return true

## Add screen distortion effect
func _add_screen_distortion_effect(config: Dictionary) -> bool:
	# Would typically involve a full-screen quad with distortion shader
	print("PostProcessor: Screen distortion effect added (placeholder)")
	return true

## Remove screen distortion effect
func _remove_screen_distortion_effect() -> bool:
	print("PostProcessor: Screen distortion effect removed")
	return true

## Add damage overlay effect
func _add_damage_overlay_effect(config: Dictionary) -> bool:
	# Damage effects like static, color shifts, scanlines
	if not post_processing_environment:
		return false
	
	var damage_level: float = config.get("damage_level", 0.0)
	
	# Adjust environment based on damage
	post_processing_environment.adjustment_contrast = 1.0 - damage_level * 0.2
	post_processing_environment.adjustment_saturation = 1.0 - damage_level * 0.3
	
	print("PostProcessor: Damage overlay effect added (damage level: %.2f)" % damage_level)
	return true

## Remove damage overlay effect
func _remove_damage_overlay_effect() -> bool:
	if not post_processing_environment:
		return false
	
	# Restore normal values
	post_processing_environment.adjustment_contrast = 1.1
	post_processing_environment.adjustment_saturation = 1.05
	
	print("PostProcessor: Damage overlay effect removed")
	return true

## Add energy discharge effect
func _add_energy_discharge_effect(config: Dictionary) -> bool:
	# Energy crackling effects, typically animated
	print("PostProcessor: Energy discharge effect added (placeholder)")
	return true

## Remove energy discharge effect
func _remove_energy_discharge_effect() -> bool:
	print("PostProcessor: Energy discharge effect removed")
	return true

## Add warp effect for jump drives
func _add_warp_effect(config: Dictionary) -> bool:
	# Warp tunnel and speed line effects
	if not post_processing_environment:
		return false
	
	var warp_factor: float = config.get("warp_factor", 0.0)
	
	# Enhance bloom for warp effect
	post_processing_environment.glow_intensity = 0.8 + warp_factor
	post_processing_environment.glow_strength = 1.2 + warp_factor * 0.5
	
	print("PostProcessor: Warp effect added (warp factor: %.2f)" % warp_factor)
	return true

## Remove warp effect
func _remove_warp_effect() -> bool:
	if not post_processing_environment:
		return false
	
	# Restore normal bloom
	_setup_bloom_effect()
	
	print("PostProcessor: Warp effect removed")
	return true

## Update post-processing for combat intensity
func update_combat_intensity(intensity: float) -> void:
	if not post_processing_environment:
		return
	
	# Adjust bloom and contrast based on combat intensity
	var base_glow: float = 0.8
	var combat_glow: float = base_glow + intensity * 0.4
	
	post_processing_environment.glow_intensity = clamp(combat_glow, 0.5, 1.5)
	post_processing_environment.adjustment_contrast = 1.1 + intensity * 0.1
	
	print("PostProcessor: Combat intensity updated to %.2f" % intensity)

## Create weapon impact screen effect
func create_weapon_impact_effect(impact_strength: float, impact_color: Color = Color.WHITE) -> void:
	# Quick flash and slight screen shake effect
	create_flash_effect(impact_strength, 0.08, impact_color)
	
	# Could also trigger screen distortion
	if impact_strength > 1.0:
		add_post_effect("screen_distortion", {
			"distortion_strength": impact_strength * 0.05,
			"duration": 0.2
		})

## Create jump effect sequence
func create_jump_effect_sequence(jump_duration: float = 3.0) -> void:
	# Multi-stage jump effect
	print("PostProcessor: Starting jump effect sequence (duration: %.2fs)" % jump_duration)
	
	# Stage 1: Build up
	add_post_effect("warp_effect", {"warp_factor": 0.5})
	
	# Stage 2: Jump tunnel (would be animated)
	# Stage 3: Exit flash
	# Stage 4: Cleanup
	
	# In full implementation, this would use timers and tweens for sequencing

## Get current post-processing statistics
func get_post_processing_stats() -> Dictionary:
	return {
		"active_effects": active_post_effects.keys(),
		"quality_level": quality_level,
		"bloom_enabled": post_processing_environment.glow_enabled if post_processing_environment else false,
		"tone_mapping": post_processing_environment.tonemap_mode if post_processing_environment else -1,
		"environment_configured": post_processing_environment != null
	}

## Apply post-processing to a camera
func apply_to_camera(camera: Camera3D) -> bool:
	if not camera:
		push_error("PostProcessor: Invalid camera provided")
		return false
	
	if post_processing_environment:
		camera.environment = post_processing_environment
	
	print("PostProcessor: Applied post-processing to camera: " + camera.name)
	return true

## Remove post-processing from a camera
func remove_from_camera(camera: Camera3D) -> bool:
	if not camera:
		return false
	
	camera.environment = null
	
	print("PostProcessor: Removed post-processing from camera: " + camera.name)
	return true

## Cleanup all post-processing effects
func cleanup() -> void:
	for effect_name in active_post_effects.keys():
		remove_post_effect(effect_name)
	
	if post_processing_environment:
		post_processing_environment = null
	
	is_initialized = false
	print("PostProcessor: Cleanup completed")
