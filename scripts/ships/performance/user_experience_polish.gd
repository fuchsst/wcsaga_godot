class_name UserExperiencePolish
extends Node

## SHIP-016 AC7: User Experience Polish for smooth animations and responsive feedback
## Provides professional visual quality matching WCS standards with smooth transitions
## Enhances player feedback and interface responsiveness during ship combat

signal animation_started(animation_name: String, duration: float)
signal animation_completed(animation_name: String, total_time: float)
signal feedback_provided(feedback_type: String, intensity: float)
signal quality_adjusted(quality_level: String, effects_enabled: bool)

# Polish configuration
@export_group("Animation Settings")
@export var smooth_transitions_enabled: bool = true
@export var default_transition_duration: float = 0.3
@export var ui_response_time_target_ms: float = 16.0  # 60 FPS target
@export var animation_quality_scale: float = 1.0

@export_group("Visual Quality")
@export var enable_visual_effects: bool = true
@export var effect_quality_level: String = "HIGH"  # HIGH, MEDIUM, LOW
@export var screen_space_reflections: bool = true
@export var motion_blur_enabled: bool = true
@export var particle_quality_multiplier: float = 1.0

@export_group("Audio Feedback")
@export var enable_audio_feedback: bool = true
@export var ui_audio_volume: float = 0.8
@export var spatial_audio_enabled: bool = true
@export var audio_feedback_delay_ms: float = 50.0

@export_group("Haptic Feedback")
@export var enable_haptic_feedback: bool = true
@export var haptic_intensity: float = 0.7
@export var controller_rumble_enabled: bool = true

# Performance tracking
var animation_performance: Dictionary = {}
var ui_response_times: Array[float] = []
var quality_adjustments: int = 0
var total_animations_played: int = 0

# Animation system
var active_animations: Dictionary = {}  # node -> AnimationData
var animation_queue: Array[Dictionary] = []
var tween_pool: Array[Tween] = []

# Visual effects management
var effect_nodes: Array[Node] = []
var particle_systems: Array[GPUParticles3D] = []
var post_processing_effects: Dictionary = {}

# Audio feedback system
var ui_audio_players: Array[AudioStreamPlayer] = []
var feedback_audio_cache: Dictionary = {}  # sound_name -> AudioStream

# Haptic feedback system
var haptic_patterns: Dictionary = {}
var last_haptic_time: float = 0.0

# Animation data structure
class AnimationData:
	var node: Node
	var animation_name: String
	var start_time: float
	var duration: float
	var properties: Dictionary
	var completion_callback: Callable
	var is_ui_critical: bool = false
	
	func _init(target_node: Node, name: String, time: float) -> void:
		node = target_node
		animation_name = name
		start_time = time
		properties = {}

# Quality level configurations
var quality_configs: Dictionary = {
	"HIGH": {
		"particle_count_multiplier": 1.0,
		"effect_complexity": 1.0,
		"animation_framerate": 60.0,
		"post_processing_enabled": true,
		"motion_blur_enabled": true,
		"screen_space_reflections": true
	},
	"MEDIUM": {
		"particle_count_multiplier": 0.7,
		"effect_complexity": 0.8,
		"animation_framerate": 30.0,
		"post_processing_enabled": true,
		"motion_blur_enabled": false,
		"screen_space_reflections": false
	},
	"LOW": {
		"particle_count_multiplier": 0.4,
		"effect_complexity": 0.5,
		"animation_framerate": 20.0,
		"post_processing_enabled": false,
		"motion_blur_enabled": false,
		"screen_space_reflections": false
	}
}

func _ready() -> void:
	set_process(true)
	_initialize_polish_systems()
	_setup_audio_feedback()
	_setup_haptic_patterns()
	print("UserExperiencePolish: Professional visual quality and feedback system initialized")

## Initialize polish systems
func _initialize_polish_systems() -> void:
	# Create tween pool for smooth animations
	_create_tween_pool(10)
	
	# Setup post-processing effects
	_setup_post_processing()
	
	# Initialize performance tracking
	ui_response_times.resize(60)  # Track last 60 frames
	for i in range(60):
		ui_response_times[i] = ui_response_time_target_ms

func _process(delta: float) -> void:
	# Update animations
	_update_active_animations(delta)
	
	# Process animation queue
	_process_animation_queue()
	
	# Track UI response time
	_track_ui_response_time(delta)
	
	# Update visual effects quality
	_update_visual_effects_quality()

## Create pool of tweens for efficient animation
func _create_tween_pool(pool_size: int) -> void:
	tween_pool.clear()
	for i in range(pool_size):
		var tween: Tween = create_tween()
		tween.pause()
		tween_pool.append(tween)

## Get available tween from pool
func _get_pooled_tween() -> Tween:
	for tween in tween_pool:
		if not tween.is_valid() or tween.is_finished():
			return tween
	
	# Create new tween if pool exhausted
	var new_tween: Tween = create_tween()
	tween_pool.append(new_tween)
	return new_tween

## Setup post-processing effects
func _setup_post_processing() -> void:
	# Initialize post-processing effect nodes
	var viewport: Viewport = get_viewport()
	if viewport:
		# Setup screen-space effects
		_setup_screen_space_effects(viewport)

## Setup screen-space effects
func _setup_screen_space_effects(viewport: Viewport) -> void:
	# Motion blur setup
	if motion_blur_enabled and effect_quality_level in ["HIGH", "MEDIUM"]:
		_enable_motion_blur(viewport)
	
	# Screen-space reflections
	if screen_space_reflections and effect_quality_level == "HIGH":
		_enable_screen_space_reflections(viewport)

## Enable motion blur effect
func _enable_motion_blur(viewport: Viewport) -> void:
	# Setup motion blur rendering
	var camera: Camera3D = viewport.get_camera_3d()
	if camera and camera.has_method("set_motion_blur_enabled"):
		camera.set_motion_blur_enabled(true)
		post_processing_effects["motion_blur"] = true

## Enable screen-space reflections
func _enable_screen_space_reflections(viewport: Viewport) -> void:
	# Setup SSR if available
	var render_data = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES)
	if render_data:
		post_processing_effects["screen_space_reflections"] = true

## Setup audio feedback system
func _setup_audio_feedback() -> void:
	if not enable_audio_feedback:
		return
	
	# Create audio players for UI feedback
	for i in range(5):  # Pool of 5 audio players
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = linear_to_db(ui_audio_volume)
		player.bus = "UI"
		add_child(player)
		ui_audio_players.append(player)
	
	# Load common UI sounds
	_load_feedback_audio()

## Load audio feedback sounds
func _load_feedback_audio() -> void:
	var audio_files: Dictionary = {
		"button_hover": "res://assets/audio/ui/button_hover.ogg",
		"button_click": "res://assets/audio/ui/button_click.ogg",
		"warning": "res://assets/audio/ui/warning.ogg",
		"confirmation": "res://assets/audio/ui/confirmation.ogg",
		"error": "res://assets/audio/ui/error.ogg"
	}
	
	for sound_name in audio_files:
		var audio_path: String = audio_files[sound_name]
		if ResourceLoader.exists(audio_path):
			var audio_stream: AudioStream = load(audio_path)
			feedback_audio_cache[sound_name] = audio_stream

## Setup haptic feedback patterns
func _setup_haptic_patterns() -> void:
	if not enable_haptic_feedback:
		return
	
	# Define haptic patterns for different events
	haptic_patterns["weapon_fire"] = {
		"intensity": 0.3,
		"duration": 0.1,
		"pattern": "short_pulse"
	}
	haptic_patterns["damage_taken"] = {
		"intensity": 0.7,
		"duration": 0.3,
		"pattern": "heavy_pulse"
	}
	haptic_patterns["shield_hit"] = {
		"intensity": 0.4,
		"duration": 0.15,
		"pattern": "medium_pulse"
	}
	haptic_patterns["explosion"] = {
		"intensity": 1.0,
		"duration": 0.5,
		"pattern": "explosion_rumble"
	}

## Update active animations
func _update_active_animations(delta: float) -> void:
	var completed_animations: Array[Node] = []
	
	for node in active_animations:
		var anim_data: AnimationData = active_animations[node]
		var elapsed_time: float = Time.get_ticks_usec() / 1000000.0 - anim_data.start_time
		
		if elapsed_time >= anim_data.duration:
			# Animation completed
			completed_animations.append(node)
			animation_completed.emit(anim_data.animation_name, elapsed_time)
			
			# Call completion callback if set
			if anim_data.completion_callback.is_valid():
				anim_data.completion_callback.call()
	
	# Remove completed animations
	for node in completed_animations:
		active_animations.erase(node)

## Start animation immediately from queue
func _start_animation_immediate(anim_request: Dictionary) -> void:
	var node: Node = anim_request.get("node")
	var property: String = anim_request.get("property", "")
	var target_value: Variant = anim_request.get("target_value")
	var duration: float = anim_request.get("duration", default_transition_duration)
	
	if is_instance_valid(node) and property != "":
		animate_property(node, property, target_value, duration)

## Process animation queue
func _process_animation_queue() -> void:
	if animation_queue.is_empty():
		return
	
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	var processed_count: int = 0
	
	# Process up to 3 animations per frame to maintain performance
	while not animation_queue.is_empty() and processed_count < 3:
		var anim_request: Dictionary = animation_queue.pop_front()
		_start_animation_immediate(anim_request)
		processed_count += 1

## Track UI response time
func _track_ui_response_time(delta: float) -> void:
	var frame_time_ms: float = delta * 1000.0
	
	# Shift array and add new sample
	for i in range(ui_response_times.size() - 1):
		ui_response_times[i] = ui_response_times[i + 1]
	ui_response_times[-1] = frame_time_ms
	
	# Check if UI response is lagging
	var average_response: float = 0.0
	for time in ui_response_times:
		average_response += time
	average_response /= ui_response_times.size()
	
	# Adjust quality if response time is poor
	if average_response > ui_response_time_target_ms * 1.5:
		_adjust_quality_for_performance()

## Update visual effects quality based on performance
func _update_visual_effects_quality() -> void:
	var current_config: Dictionary = quality_configs[effect_quality_level]
	
	# Update particle systems
	for particle_system in particle_systems:
		if is_instance_valid(particle_system):
			var original_amount: int = particle_system.get_meta("original_amount", particle_system.amount)
			particle_system.set_meta("original_amount", original_amount)
			particle_system.amount = int(original_amount * current_config["particle_count_multiplier"])

## Adjust quality for performance
func _adjust_quality_for_performance() -> void:
	match effect_quality_level:
		"HIGH":
			set_effect_quality_level("MEDIUM")
		"MEDIUM":
			set_effect_quality_level("LOW")
		_:
			return  # Already at lowest quality
	
	quality_adjustments += 1
	print("UserExperiencePolish: Automatically reduced quality to %s for performance" % effect_quality_level)

# Public API

## Start smooth animation
func animate_property(node: Node, property: String, target_value: Variant, duration: float = -1.0, 
					 ease_type: Tween.EaseType = Tween.EASE_OUT, 
					 transition_type: Tween.TransitionType = Tween.TRANS_CUBIC,
					 completion_callback: Callable = Callable()) -> bool:
	"""Start smooth property animation with professional easing.
	
	Args:
		node: Target node to animate
		property: Node property to animate
		target_value: Target value for the property
		duration: Animation duration (uses default if negative)
		ease_type: Easing type for the animation
		transition_type: Transition type for the animation
		completion_callback: Optional callback when animation completes
		
	Returns:
		true if animation started successfully
	"""
	if not is_instance_valid(node):
		push_error("UserExperiencePolish: Cannot animate invalid node")
		return false
	
	if duration < 0.0:
		duration = default_transition_duration
	
	var anim_name: String = "%s_%s" % [node.name, property]
	var start_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Create animation data
	var anim_data: AnimationData = AnimationData.new(node, anim_name, start_time)
	anim_data.duration = duration
	anim_data.completion_callback = completion_callback
	anim_data.properties[property] = target_value
	
	# Get tween from pool
	var tween: Tween = _get_pooled_tween()
	if not tween:
		push_error("UserExperiencePolish: Could not get tween for animation")
		return false
	
	# Start animation
	tween.tween_property(node, property, target_value, duration)
	tween.set_ease(ease_type)
	tween.set_trans(transition_type)
	
	# Track animation
	active_animations[node] = anim_data
	total_animations_played += 1
	animation_started.emit(anim_name, duration)
	
	return true

## Animate UI element with responsive feedback
func animate_ui_element(node: Control, animation_type: String, intensity: float = 1.0) -> bool:
	"""Animate UI element with predefined patterns.
	
	Args:
		node: UI Control node to animate
		animation_type: Type of animation (hover, click, focus, etc.)
		intensity: Animation intensity multiplier
		
	Returns:
		true if animation started successfully
	"""
	if not is_instance_valid(node):
		return false
	
	match animation_type:
		"hover":
			return _animate_hover_effect(node, intensity)
		"click":
			return _animate_click_effect(node, intensity)
		"focus":
			return _animate_focus_effect(node, intensity)
		"pulse":
			return _animate_pulse_effect(node, intensity)
		"shake":
			return _animate_shake_effect(node, intensity)
		_:
			push_warning("UserExperiencePolish: Unknown animation type: %s" % animation_type)
			return false

## Animate hover effect
func _animate_hover_effect(node: Control, intensity: float) -> bool:
	var scale_target: Vector2 = Vector2.ONE * (1.0 + 0.05 * intensity)
	return animate_property(node, "scale", scale_target, 0.15, Tween.EASE_OUT, Tween.TRANS_BACK)

## Animate click effect
func _animate_click_effect(node: Control, intensity: float) -> bool:
	var scale_down: Vector2 = Vector2.ONE * (1.0 - 0.1 * intensity)
	var tween: Tween = _get_pooled_tween()
	
	if not tween:
		return false
	
	# Click down then back up
	tween.tween_property(node, "scale", scale_down, 0.05)
	tween.tween_property(node, "scale", Vector2.ONE, 0.1)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	
	return true

## Animate focus effect
func _animate_focus_effect(node: Control, intensity: float) -> bool:
	# Glow effect through modulation
	var glow_color: Color = Color.WHITE
	glow_color.a = 0.3 * intensity
	
	return animate_property(node, "modulate", glow_color, 0.2, Tween.EASE_IN_OUT)

## Animate pulse effect
func _animate_pulse_effect(node: Control, intensity: float) -> bool:
	var tween: Tween = _get_pooled_tween()
	
	if not tween:
		return false
	
	var pulse_scale: Vector2 = Vector2.ONE * (1.0 + 0.1 * intensity)
	tween.set_loops(3)  # Pulse 3 times
	tween.tween_property(node, "scale", pulse_scale, 0.3)
	tween.tween_property(node, "scale", Vector2.ONE, 0.3)
	
	return true

## Animate shake effect
func _animate_shake_effect(node: Control, intensity: float) -> bool:
	var original_position: Vector2 = node.position
	var shake_amount: float = 5.0 * intensity
	var tween: Tween = _get_pooled_tween()
	
	if not tween:
		return false
	
	# Shake sequence
	for i in range(6):
		var shake_offset: Vector2 = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		tween.tween_property(node, "position", original_position + shake_offset, 0.02)
	
	# Return to original position
	tween.tween_property(node, "position", original_position, 0.1)
	
	return true

## Provide audio feedback
func provide_audio_feedback(sound_name: String, intensity: float = 1.0) -> bool:
	"""Play audio feedback with specified intensity.
	
	Args:
		sound_name: Name of the sound to play
		intensity: Volume intensity multiplier
		
	Returns:
		true if audio played successfully
	"""
	if not enable_audio_feedback or not feedback_audio_cache.has(sound_name):
		return false
	
	var player: AudioStreamPlayer = _get_available_audio_player()
	if not player:
		return false
	
	var audio_stream: AudioStream = feedback_audio_cache[sound_name]
	player.stream = audio_stream
	player.volume_db = linear_to_db(ui_audio_volume * intensity)
	player.play()
	
	feedback_provided.emit("audio", intensity)
	return true

## Get available audio player
func _get_available_audio_player() -> AudioStreamPlayer:
	for player in ui_audio_players:
		if not player.playing:
			return player
	
	return null

## Provide haptic feedback
func provide_haptic_feedback(pattern_name: String, intensity_override: float = -1.0) -> bool:
	"""Provide haptic feedback using predefined patterns.
	
	Args:
		pattern_name: Name of haptic pattern to use
		intensity_override: Override pattern intensity (uses pattern default if negative)
		
	Returns:
		true if haptic feedback triggered successfully
	"""
	if not enable_haptic_feedback or not controller_rumble_enabled:
		return false
	
	if not haptic_patterns.has(pattern_name):
		push_warning("UserExperiencePolish: Unknown haptic pattern: %s" % pattern_name)
		return false
	
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Rate limiting for haptic feedback
	if current_time - last_haptic_time < 0.05:  # 50ms minimum between haptic events
		return false
	
	var pattern: Dictionary = haptic_patterns[pattern_name]
	var intensity: float = intensity_override if intensity_override >= 0.0 else pattern["intensity"]
	var duration: float = pattern["duration"]
	
	# Trigger haptic feedback (platform dependent)
	_trigger_haptic_rumble(intensity * haptic_intensity, duration)
	
	last_haptic_time = current_time
	feedback_provided.emit("haptic", intensity)
	return true

## Trigger haptic rumble
func _trigger_haptic_rumble(intensity: float, duration: float) -> void:
	# Platform-specific haptic feedback
	if Input.get_connected_joypads().size() > 0:
		var joypad_id: int = Input.get_connected_joypads()[0]
		Input.start_joy_vibration(joypad_id, intensity, intensity, duration)

## Set effect quality level
func set_effect_quality_level(quality: String) -> bool:
	"""Set visual effect quality level.
	
	Args:
		quality: Quality level (HIGH, MEDIUM, LOW)
		
	Returns:
		true if quality level was valid and applied
	"""
	if not quality_configs.has(quality):
		push_error("UserExperiencePolish: Invalid quality level: %s" % quality)
		return false
	
	effect_quality_level = quality
	var config: Dictionary = quality_configs[quality]
	
	# Apply quality settings
	particle_quality_multiplier = config["particle_count_multiplier"]
	motion_blur_enabled = config["motion_blur_enabled"]
	screen_space_reflections = config["screen_space_reflections"]
	
	# Update post-processing effects
	_update_post_processing_effects(config)
	
	quality_adjusted.emit(quality, enable_visual_effects)
	print("UserExperiencePolish: Effect quality set to %s" % quality)
	return true

## Update post-processing effects based on quality
func _update_post_processing_effects(config: Dictionary) -> void:
	# Update motion blur
	if post_processing_effects.has("motion_blur"):
		var viewport: Viewport = get_viewport()
		var camera: Camera3D = viewport.get_camera_3d() if viewport else null
		if camera and camera.has_method("set_motion_blur_enabled"):
			camera.set_motion_blur_enabled(config["motion_blur_enabled"])
	
	# Update screen-space reflections
	if post_processing_effects.has("screen_space_reflections"):
		# Platform-specific SSR handling
		_update_screen_space_reflections(config["screen_space_reflections"])

## Update screen-space reflections
func _update_screen_space_reflections(enabled: bool) -> void:
	# Implementation depends on Godot version and platform
	post_processing_effects["screen_space_reflections"] = enabled

## Register particle system for quality management
func register_particle_system(particle_system: GPUParticles3D) -> bool:
	"""Register particle system for automatic quality management.
	
	Args:
		particle_system: GPUParticles3D node to manage
		
	Returns:
		true if registered successfully
	"""
	if not is_instance_valid(particle_system):
		return false
	
	if particle_system in particle_systems:
		return true  # Already registered
	
	particle_systems.append(particle_system)
	
	# Store original amount for quality scaling
	particle_system.set_meta("original_amount", particle_system.amount)
	
	return true

## Unregister particle system
func unregister_particle_system(particle_system: GPUParticles3D) -> bool:
	"""Unregister particle system from quality management.
	
	Args:
		particle_system: GPUParticles3D node to unregister
		
	Returns:
		true if unregistered successfully
	"""
	var index: int = particle_systems.find(particle_system)
	if index == -1:
		return false
	
	particle_systems.remove_at(index)
	return true

## Get polish performance statistics
func get_polish_performance_stats() -> Dictionary:
	"""Get comprehensive polish system performance statistics.
	
	Returns:
		Dictionary containing performance metrics
	"""
	var average_ui_response: float = 0.0
	for time in ui_response_times:
		average_ui_response += time
	average_ui_response /= ui_response_times.size()
	
	return {
		"total_animations_played": total_animations_played,
		"active_animations_count": active_animations.size(),
		"animation_queue_size": animation_queue.size(),
		"average_ui_response_time_ms": average_ui_response,
		"ui_response_target_ms": ui_response_time_target_ms,
		"ui_performance_ratio": ui_response_time_target_ms / max(1.0, average_ui_response),
		"quality_adjustments_count": quality_adjustments,
		"current_quality_level": effect_quality_level,
		"particle_systems_managed": particle_systems.size(),
		"audio_players_available": ui_audio_players.size(),
		"haptic_feedback_enabled": enable_haptic_feedback,
		"visual_effects_enabled": enable_visual_effects,
		"post_processing_effects_active": post_processing_effects.size()
	}

## Get UI responsiveness status
func get_ui_responsiveness_status() -> Dictionary:
	"""Get current UI responsiveness analysis.
	
	Returns:
		Dictionary containing responsiveness metrics
	"""
	var average_response: float = 0.0
	var max_response: float = 0.0
	for time in ui_response_times:
		average_response += time
		max_response = max(max_response, time)
	average_response /= ui_response_times.size()
	
	var responsiveness_rating: String = "EXCELLENT"
	if average_response > ui_response_time_target_ms * 2.0:
		responsiveness_rating = "POOR"
	elif average_response > ui_response_time_target_ms * 1.5:
		responsiveness_rating = "FAIR"
	elif average_response > ui_response_time_target_ms * 1.2:
		responsiveness_rating = "GOOD"
	
	return {
		"rating": responsiveness_rating,
		"average_response_time_ms": average_response,
		"max_response_time_ms": max_response,
		"target_response_time_ms": ui_response_time_target_ms,
		"performance_ratio": ui_response_time_target_ms / max(1.0, average_response),
		"frames_above_target": _count_frames_above_target(),
		"consistency_score": 1.0 - (max_response - average_response) / max(1.0, average_response)
	}

## Count frames above target response time
func _count_frames_above_target() -> int:
	var count: int = 0
	for time in ui_response_times:
		if time > ui_response_time_target_ms:
			count += 1
	return count

## Enable/disable smooth transitions
func set_smooth_transitions_enabled(enabled: bool) -> void:
	smooth_transitions_enabled = enabled
	
	if not enabled:
		# Cancel all active animations
		for node in active_animations:
			# Stop tweens for immediate transitions
			pass
	
	print("UserExperiencePolish: Smooth transitions %s" % ("enabled" if enabled else "disabled"))

## Set animation quality scale
func set_animation_quality_scale(scale: float) -> void:
	animation_quality_scale = clamp(scale, 0.1, 2.0)
	default_transition_duration *= scale
	print("UserExperiencePolish: Animation quality scale set to %.2f" % scale)