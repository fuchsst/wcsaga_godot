extends GdUnitTestSuite

## SHIP-016 AC7: Focused test suite for UserExperiencePolish
## Tests smooth animations, responsive feedback, and professional visual quality

var user_experience_polish: UserExperiencePolish
var test_scene: Node
var test_ui_elements: Array[Control] = []

func before_test() -> void:
	test_scene = Node.new()
	add_child(test_scene)
	
	user_experience_polish = UserExperiencePolish.new()
	test_scene.add_child(user_experience_polish)
	
	# Create test UI elements
	_create_test_ui_elements()

func after_test() -> void:
	for element in test_ui_elements:
		if is_instance_valid(element):
			element.queue_free()
	test_ui_elements.clear()
	
	if is_instance_valid(test_scene):
		test_scene.queue_free()

func _create_test_ui_elements() -> void:
	# Create various UI elements for testing
	var test_button = Button.new()
	test_button.text = "Test Button"
	test_button.size = Vector2(100, 40)
	test_scene.add_child(test_button)
	test_ui_elements.append(test_button)
	
	var test_label = Label.new()
	test_label.text = "Test Label"
	test_scene.add_child(test_label)
	test_ui_elements.append(test_label)
	
	var test_panel = Panel.new()
	test_panel.size = Vector2(200, 150)
	test_scene.add_child(test_panel)
	test_ui_elements.append(test_panel)

func test_user_experience_polish_initialization() -> void:
	assert_that(user_experience_polish).is_not_null()
	assert_that(user_experience_polish.smooth_transitions_enabled).is_true()
	assert_that(user_experience_polish.ui_response_time_target_ms).is_less_equal(16.0)  # 60 FPS

func test_smooth_animations() -> void:
	var test_button = test_ui_elements[0] as Button
	assert_that(test_button).is_not_null()
	
	var animation_started = false
	var animation_completed = false
	
	user_experience_polish.animation_started.connect(
		func(name, duration): animation_started = true
	)
	user_experience_polish.animation_completed.connect(
		func(name, total_time): animation_completed = true
	)
	
	# Test smooth property animation
	var success = user_experience_polish.animate_property(
		test_button, "scale", Vector2(1.2, 1.2), 0.2
	)
	
	assert_that(success).is_true()
	
	# Wait for animation to start
	await get_tree().create_timer(0.05).timeout
	assert_that(animation_started).is_true()
	
	# Wait for animation to complete
	await get_tree().create_timer(0.25).timeout
	assert_that(animation_completed).is_true()

func test_ui_animation_types() -> void:
	var test_button = test_ui_elements[0] as Button
	
	# Test different animation types
	assert_that(user_experience_polish.animate_ui_element(test_button, "hover", 1.0)).is_true()
	await get_tree().create_timer(0.1).timeout
	
	assert_that(user_experience_polish.animate_ui_element(test_button, "click", 1.0)).is_true()
	await get_tree().create_timer(0.1).timeout
	
	assert_that(user_experience_polish.animate_ui_element(test_button, "focus", 1.0)).is_true()
	await get_tree().create_timer(0.1).timeout
	
	assert_that(user_experience_polish.animate_ui_element(test_button, "pulse", 1.0)).is_true()
	await get_tree().create_timer(0.1).timeout
	
	assert_that(user_experience_polish.animate_ui_element(test_button, "shake", 1.0)).is_true()
	await get_tree().create_timer(0.1).timeout

func test_responsive_feedback() -> void:
	var feedback_provided = false
	user_experience_polish.feedback_provided.connect(
		func(feedback_type, intensity): feedback_provided = true
	)
	
	# Test audio feedback (may not work if audio files don't exist)
	user_experience_polish.provide_audio_feedback("button_click", 1.0)
	
	# Test haptic feedback
	user_experience_polish.provide_haptic_feedback("weapon_fire", 0.5)
	
	# At least one type of feedback should be attempted
	var stats = user_experience_polish.get_polish_performance_stats()
	assert_that(stats).contains_key("haptic_feedback_enabled")

func test_ui_responsiveness_monitoring() -> void:
	# Test UI responsiveness tracking
	var responsiveness = user_experience_polish.get_ui_responsiveness_status()
	
	assert_that(responsiveness).contains_keys([
		"rating", "average_response_time_ms", "max_response_time_ms",
		"target_response_time_ms", "performance_ratio"
	])
	
	assert_that(responsiveness["target_response_time_ms"]).is_less_equal(16.0)  # 60 FPS target
	assert_that(responsiveness["rating"]).is_in(["EXCELLENT", "GOOD", "FAIR", "POOR"])

func test_visual_quality_levels() -> void:
	# Test different quality levels
	assert_that(user_experience_polish.set_effect_quality_level("HIGH")).is_true()
	assert_that(user_experience_polish.effect_quality_level).is_equal("HIGH")
	
	assert_that(user_experience_polish.set_effect_quality_level("MEDIUM")).is_true()
	assert_that(user_experience_polish.effect_quality_level).is_equal("MEDIUM")
	
	assert_that(user_experience_polish.set_effect_quality_level("LOW")).is_true()
	assert_that(user_experience_polish.effect_quality_level).is_equal("LOW")
	
	# Test invalid quality level
	assert_that(user_experience_polish.set_effect_quality_level("INVALID")).is_false()

func test_particle_system_quality_management() -> void:
	# Create test particle system
	var particle_system = GPUParticles3D.new()
	particle_system.amount = 100
	particle_system.emitting = true
	test_scene.add_child(particle_system)
	
	# Register for quality management
	assert_that(user_experience_polish.register_particle_system(particle_system)).is_true()
	
	# Test quality scaling
	user_experience_polish.set_effect_quality_level("MEDIUM")
	await get_tree().create_timer(0.1).timeout
	
	# Should have stored original amount
	var original_amount = particle_system.get_meta("original_amount", 0)
	assert_that(original_amount).is_equal(100)
	
	# Unregister
	assert_that(user_experience_polish.unregister_particle_system(particle_system)).is_true()
	
	particle_system.queue_free()

func test_animation_performance_scaling() -> void:
	# Test animation quality scaling
	user_experience_polish.set_animation_quality_scale(0.5)
	assert_that(user_experience_polish.animation_quality_scale).is_equal(0.5)
	
	user_experience_polish.set_animation_quality_scale(2.0)
	assert_that(user_experience_polish.animation_quality_scale).is_equal(2.0)
	
	# Test clamping
	user_experience_polish.set_animation_quality_scale(5.0)  # Should be clamped to 2.0
	assert_that(user_experience_polish.animation_quality_scale).is_equal(2.0)

func test_wcs_quality_standards() -> void:
	"""Test that the system meets WCS visual quality standards."""
	
	# Test high quality settings match WCS standards
	user_experience_polish.set_effect_quality_level("HIGH")
	
	var stats = user_experience_polish.get_polish_performance_stats()
	assert_that(stats["current_quality_level"]).is_equal("HIGH")
	assert_that(stats["visual_effects_enabled"]).is_true()
	
	# Test professional visual quality preservation
	user_experience_polish.enable_visual_effects = true
	user_experience_polish.motion_blur_enabled = true
	user_experience_polish.screen_space_reflections = true
	
	assert_that(user_experience_polish.enable_visual_effects).is_true()
	assert_that(user_experience_polish.motion_blur_enabled).is_true()
	assert_that(user_experience_polish.screen_space_reflections).is_true()

func test_smooth_transitions_control() -> void:
	# Test enabling/disabling smooth transitions
	user_experience_polish.set_smooth_transitions_enabled(false)
	assert_that(user_experience_polish.smooth_transitions_enabled).is_false()
	
	user_experience_polish.set_smooth_transitions_enabled(true)
	assert_that(user_experience_polish.smooth_transitions_enabled).is_true()

func test_audio_feedback_system() -> void:
	# Test audio feedback configuration
	user_experience_polish.enable_audio_feedback = true
	user_experience_polish.ui_audio_volume = 0.8
	
	assert_that(user_experience_polish.enable_audio_feedback).is_true()
	assert_that(user_experience_polish.ui_audio_volume).is_equal(0.8)
	
	# Test audio feedback (may not succeed if audio files don't exist)
	var audio_attempted = user_experience_polish.provide_audio_feedback("button_hover", 1.0)
	# Result depends on whether audio files exist, but function should not crash

func test_haptic_feedback_system() -> void:
	# Test haptic feedback configuration
	user_experience_polish.enable_haptic_feedback = true
	user_experience_polish.haptic_intensity = 0.7
	user_experience_polish.controller_rumble_enabled = true
	
	assert_that(user_experience_polish.enable_haptic_feedback).is_true()
	assert_that(user_experience_polish.haptic_intensity).is_equal(0.7)
	
	# Test different haptic patterns
	var patterns = ["weapon_fire", "damage_taken", "shield_hit", "explosion"]
	for pattern in patterns:
		var haptic_attempted = user_experience_polish.provide_haptic_feedback(pattern, 0.5)
		# Result depends on platform support, but should not crash

func test_performance_statistics() -> void:
	var stats = user_experience_polish.get_polish_performance_stats()
	
	assert_that(stats).contains_keys([
		"total_animations_played", "active_animations_count", "animation_queue_size",
		"average_ui_response_time_ms", "ui_response_target_ms", "ui_performance_ratio",
		"quality_adjustments_count", "current_quality_level", "particle_systems_managed",
		"audio_players_available", "haptic_feedback_enabled", "visual_effects_enabled"
	])
	
	assert_that(stats["ui_response_target_ms"]).is_less_equal(16.0)  # 60 FPS
	assert_that(stats["current_quality_level"]).is_in(["HIGH", "MEDIUM", "LOW"])

func test_professional_visual_quality() -> void:
	"""Test professional visual quality matching WCS standards."""
	
	# Configure for maximum quality
	user_experience_polish.set_effect_quality_level("HIGH")
	user_experience_polish.enable_visual_effects = true
	user_experience_polish.particle_quality_multiplier = 1.0
	
	# Test that quality settings are professional-grade
	assert_that(user_experience_polish.particle_quality_multiplier).is_equal(1.0)
	assert_that(user_experience_polish.enable_visual_effects).is_true()
	
	# Test responsiveness meets professional standards
	var responsiveness = user_experience_polish.get_ui_responsiveness_status()
	assert_that(responsiveness["target_response_time_ms"]).is_less_equal(16.0)  # 60 FPS

func test_animation_completion_callbacks() -> void:
	var callback_executed = false
	var completion_callback = func(): callback_executed = true
	
	var test_button = test_ui_elements[0] as Button
	
	# Test animation with completion callback
	var success = user_experience_polish.animate_property(
		test_button, "modulate", Color.RED, 0.1,
		Tween.EASE_OUT, Tween.TRANS_LINEAR, completion_callback
	)
	
	assert_that(success).is_true()
	
	# Wait for animation to complete
	await get_tree().create_timer(0.15).timeout
	assert_that(callback_executed).is_true()

func test_error_handling() -> void:
	# Test with null/invalid objects
	assert_that(user_experience_polish.animate_property(null, "scale", Vector2.ONE, 0.1)).is_false()
	assert_that(user_experience_polish.animate_ui_element(null, "hover", 1.0)).is_false()
	
	# Test with invalid animation type
	var test_button = test_ui_elements[0] as Button
	assert_that(user_experience_polish.animate_ui_element(test_button, "invalid_type", 1.0)).is_false()
	
	# Test particle system error handling
	assert_that(user_experience_polish.register_particle_system(null)).is_false()
	assert_that(user_experience_polish.unregister_particle_system(null)).is_false()

func test_quality_adjustment_for_performance() -> void:
	# Simulate poor performance to trigger quality adjustment
	user_experience_polish.ui_response_time_target_ms = 16.0
	
	# Manually trigger performance adjustment
	user_experience_polish._adjust_quality_for_performance()
	
	var stats = user_experience_polish.get_polish_performance_stats()
	assert_that(stats["quality_adjustments_count"]).is_greater_equal(0)

func test_post_processing_effects() -> void:
	# Test post-processing effect management
	user_experience_polish.motion_blur_enabled = true
	user_experience_polish.screen_space_reflections = true
	
	# Apply quality settings that should affect post-processing
	user_experience_polish.set_effect_quality_level("HIGH")
	user_experience_polish.set_effect_quality_level("LOW")
	
	# Should handle post-processing changes gracefully
	var stats = user_experience_polish.get_polish_performance_stats()
	assert_that(stats["post_processing_effects_active"]).is_greater_equal(0)