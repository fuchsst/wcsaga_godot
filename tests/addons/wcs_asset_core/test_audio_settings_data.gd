class_name TestAudioSettingsData
extends GdUnitTestSuite

## Unit tests for AudioSettingsData class.
## Tests validation, volume management, quality presets, and device configuration.

var audio_settings: AudioSettingsData

func before_each() -> void:
	"""Set up fresh AudioSettingsData instance for each test."""
	audio_settings = AudioSettingsData.new()

func after_each() -> void:
	"""Clean up after each test."""
	audio_settings = null

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_initialization() -> void:
	"""Test that AudioSettingsData initializes with correct defaults."""
	assert_that(audio_settings).is_not_null()
	assert_that(audio_settings.data_type).is_equal("AudioSettingsData")
	assert_that(audio_settings.master_volume).is_equal(1.0)
	assert_that(audio_settings.music_volume).is_equal(0.8)
	assert_that(audio_settings.effects_volume).is_equal(0.9)
	assert_that(audio_settings.voice_volume).is_equal(1.0)
	assert_that(audio_settings.ambient_volume).is_equal(0.7)
	assert_that(audio_settings.ui_volume).is_equal(0.8)

func test_quality_defaults() -> void:
	"""Test that audio quality settings initialize correctly."""
	assert_that(audio_settings.sample_rate).is_equal(44100)
	assert_that(audio_settings.bit_depth).is_equal(16)
	assert_that(audio_settings.audio_channels).is_equal(2)

func test_spatial_audio_defaults() -> void:
	"""Test that spatial audio settings initialize correctly."""
	assert_that(audio_settings.enable_3d_audio).is_true()
	assert_that(audio_settings.doppler_effect).is_true()
	assert_that(audio_settings.reverb_enabled).is_true()
	assert_that(audio_settings.audio_occlusion).is_true()
	assert_that(audio_settings.distance_attenuation).is_equal(1.0)

func test_voice_defaults() -> void:
	"""Test that voice and subtitle settings initialize correctly."""
	assert_that(audio_settings.voice_enabled).is_true()
	assert_that(audio_settings.briefing_voice_enabled).is_true()
	assert_that(audio_settings.subtitles_enabled).is_false()
	assert_that(audio_settings.subtitle_size).is_equal(1)
	assert_that(audio_settings.subtitle_background).is_true()

# ============================================================================
# VALIDATION TESTS
# ============================================================================

func test_valid_default_settings() -> void:
	"""Test that default settings are valid."""
	assert_that(audio_settings.is_valid()).is_true()

func test_volume_range_validation() -> void:
	"""Test that volume levels must be within 0.0-1.0 range."""
	audio_settings.master_volume = 1.5  # Invalid: too high
	assert_that(audio_settings.is_valid()).is_false()
	
	audio_settings.master_volume = -0.1  # Invalid: negative
	assert_that(audio_settings.is_valid()).is_false()
	
	audio_settings.master_volume = 0.5  # Valid
	assert_that(audio_settings.is_valid()).is_true()

func test_sample_rate_validation() -> void:
	"""Test that sample rate must be a valid option."""
	audio_settings.sample_rate = 48000  # Valid
	assert_that(audio_settings.is_valid()).is_true()
	
	audio_settings.sample_rate = 32000  # Invalid
	assert_that(audio_settings.is_valid()).is_false()

func test_bit_depth_validation() -> void:
	"""Test that bit depth must be a valid option."""
	audio_settings.bit_depth = 24  # Valid
	assert_that(audio_settings.is_valid()).is_true()
	
	audio_settings.bit_depth = 12  # Invalid
	assert_that(audio_settings.is_valid()).is_false()

func test_channel_configuration_validation() -> void:
	"""Test that channel configuration must be valid."""
	audio_settings.audio_channels = 6  # Valid (5.1 surround)
	assert_that(audio_settings.is_valid()).is_true()
	
	audio_settings.audio_channels = 3  # Invalid
	assert_that(audio_settings.is_valid()).is_false()

func test_subtitle_size_validation() -> void:
	"""Test that subtitle size must be within valid range."""
	audio_settings.subtitle_size = 2  # Valid
	assert_that(audio_settings.is_valid()).is_true()
	
	audio_settings.subtitle_size = 3  # Invalid: too high
	assert_that(audio_settings.is_valid()).is_false()
	
	audio_settings.subtitle_size = -1  # Invalid: negative
	assert_that(audio_settings.is_valid()).is_false()

func test_buffer_size_validation() -> void:
	"""Test that buffer size must be a power of 2 within valid range."""
	audio_settings.buffer_size = 1024  # Valid
	assert_that(audio_settings.is_valid()).is_true()
	
	audio_settings.buffer_size = 2048  # Valid
	assert_that(audio_settings.is_valid()).is_true()
	
	audio_settings.buffer_size = 1000  # Invalid: not power of 2
	assert_that(audio_settings.is_valid()).is_false()
	
	audio_settings.buffer_size = 128  # Invalid: too small
	assert_that(audio_settings.is_valid()).is_false()

func test_distance_attenuation_validation() -> void:
	"""Test that distance attenuation must be within valid range."""
	audio_settings.distance_attenuation = 2.0  # Valid
	assert_that(audio_settings.is_valid()).is_true()
	
	audio_settings.distance_attenuation = 6.0  # Invalid: too high
	assert_that(audio_settings.is_valid()).is_false()
	
	audio_settings.distance_attenuation = 0.05  # Invalid: too low
	assert_that(audio_settings.is_valid()).is_false()

# ============================================================================
# VOLUME MANAGEMENT TESTS
# ============================================================================

func test_get_volume_levels() -> void:
	"""Test getting all volume levels as dictionary."""
	var volumes: Dictionary = audio_settings.get_volume_levels()
	
	assert_that(volumes.has("master")).is_true()
	assert_that(volumes.has("music")).is_true()
	assert_that(volumes.has("effects")).is_true()
	assert_that(volumes.has("voice")).is_true()
	assert_that(volumes.has("ambient")).is_true()
	assert_that(volumes.has("ui")).is_true()
	
	assert_that(volumes.master).is_equal(1.0)
	assert_that(volumes.music).is_equal(0.8)
	assert_that(volumes.effects).is_equal(0.9)

func test_set_volume_levels() -> void:
	"""Test setting volume levels from dictionary."""
	var new_volumes: Dictionary = {
		"master": 0.7,
		"music": 0.5,
		"effects": 0.6,
		"voice": 0.8,
		"ambient": 0.4,
		"ui": 0.9
	}
	
	audio_settings.set_volume_levels(new_volumes)
	
	assert_that(audio_settings.master_volume).is_equal(0.7)
	assert_that(audio_settings.music_volume).is_equal(0.5)
	assert_that(audio_settings.effects_volume).is_equal(0.6)
	assert_that(audio_settings.voice_volume).is_equal(0.8)
	assert_that(audio_settings.ambient_volume).is_equal(0.4)
	assert_that(audio_settings.ui_volume).is_equal(0.9)

func test_set_volume_levels_clamping() -> void:
	"""Test that volume levels are clamped to valid range."""
	var invalid_volumes: Dictionary = {
		"master": 1.5,  # Too high
		"music": -0.2,  # Negative
		"effects": 0.5  # Valid
	}
	
	audio_settings.set_volume_levels(invalid_volumes)
	
	assert_that(audio_settings.master_volume).is_equal(1.0)  # Clamped to max
	assert_that(audio_settings.music_volume).is_equal(0.0)   # Clamped to min
	assert_that(audio_settings.effects_volume).is_equal(0.5) # Unchanged

func test_partial_volume_update() -> void:
	"""Test that partial volume dictionaries work correctly."""
	var partial_volumes: Dictionary = {
		"master": 0.5,
		"music": 0.3
		# Other volumes should remain unchanged
	}
	
	audio_settings.set_volume_levels(partial_volumes)
	
	assert_that(audio_settings.master_volume).is_equal(0.5)
	assert_that(audio_settings.music_volume).is_equal(0.3)
	assert_that(audio_settings.effects_volume).is_equal(0.9)  # Default unchanged
	assert_that(audio_settings.voice_volume).is_equal(1.0)    # Default unchanged

# ============================================================================
# QUALITY PRESET TESTS
# ============================================================================

func test_quality_preset_names() -> void:
	"""Test quality preset name conversion."""
	assert_that(audio_settings.get_quality_preset_name(AudioSettingsData.AudioQualityPreset.LOW)).is_equal("Low Quality")
	assert_that(audio_settings.get_quality_preset_name(AudioSettingsData.AudioQualityPreset.MEDIUM)).is_equal("Medium Quality")
	assert_that(audio_settings.get_quality_preset_name(AudioSettingsData.AudioQualityPreset.HIGH)).is_equal("High Quality")
	assert_that(audio_settings.get_quality_preset_name(AudioSettingsData.AudioQualityPreset.ULTRA)).is_equal("Ultra Quality")
	assert_that(audio_settings.get_quality_preset_name(AudioSettingsData.AudioQualityPreset.CUSTOM)).is_equal("Custom")

func test_apply_low_quality_preset() -> void:
	"""Test applying low quality preset."""
	audio_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.LOW)
	
	assert_that(audio_settings.sample_rate).is_equal(22050)
	assert_that(audio_settings.bit_depth).is_equal(16)
	assert_that(audio_settings.audio_channels).is_equal(2)
	assert_that(audio_settings.enable_3d_audio).is_false()
	assert_that(audio_settings.doppler_effect).is_false()
	assert_that(audio_settings.reverb_enabled).is_false()
	assert_that(audio_settings.dynamic_range_compression).is_true()

func test_apply_medium_quality_preset() -> void:
	"""Test applying medium quality preset."""
	audio_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.MEDIUM)
	
	assert_that(audio_settings.sample_rate).is_equal(44100)
	assert_that(audio_settings.bit_depth).is_equal(16)
	assert_that(audio_settings.audio_channels).is_equal(2)
	assert_that(audio_settings.enable_3d_audio).is_true()
	assert_that(audio_settings.doppler_effect).is_false()
	assert_that(audio_settings.reverb_enabled).is_true()
	assert_that(audio_settings.dynamic_range_compression).is_false()

func test_apply_high_quality_preset() -> void:
	"""Test applying high quality preset."""
	audio_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.HIGH)
	
	assert_that(audio_settings.sample_rate).is_equal(48000)
	assert_that(audio_settings.bit_depth).is_equal(24)
	assert_that(audio_settings.audio_channels).is_equal(2)
	assert_that(audio_settings.enable_3d_audio).is_true()
	assert_that(audio_settings.doppler_effect).is_true()
	assert_that(audio_settings.reverb_enabled).is_true()
	assert_that(audio_settings.audio_occlusion).is_true()

func test_apply_ultra_quality_preset() -> void:
	"""Test applying ultra quality preset."""
	audio_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.ULTRA)
	
	assert_that(audio_settings.sample_rate).is_equal(96000)
	assert_that(audio_settings.bit_depth).is_equal(32)
	assert_that(audio_settings.audio_channels).is_equal(6)  # 5.1 surround
	assert_that(audio_settings.enable_3d_audio).is_true()
	assert_that(audio_settings.doppler_effect).is_true()
	assert_that(audio_settings.reverb_enabled).is_true()
	assert_that(audio_settings.audio_occlusion).is_true()

# ============================================================================
# UTILITY METHOD TESTS
# ============================================================================

func test_sample_rate_names() -> void:
	"""Test sample rate name conversion."""
	assert_that(audio_settings.get_sample_rate_name(22050)).is_equal("22.05 kHz")
	assert_that(audio_settings.get_sample_rate_name(44100)).is_equal("44.1 kHz (CD Quality)")
	assert_that(audio_settings.get_sample_rate_name(48000)).is_equal("48 kHz (Studio)")
	assert_that(audio_settings.get_sample_rate_name(96000)).is_equal("96 kHz (High-Res)")
	assert_that(audio_settings.get_sample_rate_name(32000)).is_equal("32000 Hz")

func test_bit_depth_names() -> void:
	"""Test bit depth name conversion."""
	assert_that(audio_settings.get_bit_depth_name(16)).is_equal("16-bit (CD Quality)")
	assert_that(audio_settings.get_bit_depth_name(24)).is_equal("24-bit (Studio)")
	assert_that(audio_settings.get_bit_depth_name(32)).is_equal("32-bit (High-Res)")
	assert_that(audio_settings.get_bit_depth_name(12)).is_equal("12-bit")

func test_channel_configuration_names() -> void:
	"""Test channel configuration name conversion."""
	assert_that(audio_settings.get_channel_configuration_name(1)).is_equal("Mono")
	assert_that(audio_settings.get_channel_configuration_name(2)).is_equal("Stereo")
	assert_that(audio_settings.get_channel_configuration_name(6)).is_equal("5.1 Surround")
	assert_that(audio_settings.get_channel_configuration_name(8)).is_equal("7.1 Surround")
	assert_that(audio_settings.get_channel_configuration_name(4)).is_equal("4 Channels")

func test_subtitle_size_names() -> void:
	"""Test subtitle size name conversion."""
	assert_that(audio_settings.get_subtitle_size_name(0)).is_equal("Small")
	assert_that(audio_settings.get_subtitle_size_name(1)).is_equal("Medium")
	assert_that(audio_settings.get_subtitle_size_name(2)).is_equal("Large")
	assert_that(audio_settings.get_subtitle_size_name(3)).is_equal("Unknown")

# ============================================================================
# PERFORMANCE ESTIMATION TESTS
# ============================================================================

func test_memory_usage_estimation() -> void:
	"""Test memory usage estimation."""
	var base_usage: float = audio_settings.get_estimated_memory_usage()
	assert_that(base_usage).is_greater(0.0)
	
	# Ultra quality should use more memory
	audio_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.ULTRA)
	var ultra_usage: float = audio_settings.get_estimated_memory_usage()
	assert_that(ultra_usage).is_greater(base_usage)

func test_cpu_impact_estimation() -> void:
	"""Test CPU impact estimation."""
	# Low quality should have low impact
	audio_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.LOW)
	var low_impact: String = audio_settings.get_estimated_cpu_impact()
	assert_that(low_impact).is_in(["Low", "Medium"])
	
	# Ultra quality should have high impact
	audio_settings.apply_quality_preset(AudioSettingsData.AudioQualityPreset.ULTRA)
	var ultra_impact: String = audio_settings.get_estimated_cpu_impact()
	assert_that(ultra_impact).is_in(["High", "Very High"])

# ============================================================================
# CLONING TESTS
# ============================================================================

func test_clone() -> void:
	"""Test that cloning creates an independent copy."""
	audio_settings.master_volume = 0.5
	audio_settings.sample_rate = 48000
	audio_settings.enable_3d_audio = false
	
	var cloned: AudioSettingsData = audio_settings.clone()
	
	assert_that(cloned).is_not_same(audio_settings)
	assert_that(cloned.master_volume).is_equal(0.5)
	assert_that(cloned.sample_rate).is_equal(48000)
	assert_that(cloned.enable_3d_audio).is_false()
	
	# Modify original, clone should be unchanged
	audio_settings.master_volume = 1.0
	assert_that(cloned.master_volume).is_equal(0.5)

func test_clone_preserves_all_settings() -> void:
	"""Test that cloning preserves all audio settings."""
	audio_settings.music_volume = 0.3
	audio_settings.bit_depth = 24
	audio_settings.audio_channels = 6
	audio_settings.doppler_effect = false
	audio_settings.subtitles_enabled = true
	audio_settings.buffer_size = 2048
	audio_settings.dynamic_range_compression = true
	
	var cloned: AudioSettingsData = audio_settings.clone()
	
	assert_that(cloned.music_volume).is_equal(0.3)
	assert_that(cloned.bit_depth).is_equal(24)
	assert_that(cloned.audio_channels).is_equal(6)
	assert_that(cloned.doppler_effect).is_false()
	assert_that(cloned.subtitles_enabled).is_true()
	assert_that(cloned.buffer_size).is_equal(2048)
	assert_that(cloned.dynamic_range_compression).is_true()

# ============================================================================
# RESET FUNCTIONALITY TESTS
# ============================================================================

func test_reset_to_defaults() -> void:
	"""Test resetting settings to default values."""
	# Modify settings
	audio_settings.master_volume = 0.5
	audio_settings.sample_rate = 96000
	audio_settings.enable_3d_audio = false
	audio_settings.subtitles_enabled = true
	
	# Reset to defaults
	audio_settings.reset_to_defaults()
	
	# Verify defaults are restored
	assert_that(audio_settings.master_volume).is_equal(1.0)
	assert_that(audio_settings.music_volume).is_equal(0.8)
	assert_that(audio_settings.sample_rate).is_equal(44100)
	assert_that(audio_settings.enable_3d_audio).is_true()
	assert_that(audio_settings.subtitles_enabled).is_false()
	assert_that(audio_settings.is_valid()).is_true()

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_boundary_values() -> void:
	"""Test boundary values for various settings."""
	# Test minimum valid values
	audio_settings.master_volume = 0.0
	audio_settings.distance_attenuation = 0.1
	audio_settings.crossfade_duration = 0.0
	
	assert_that(audio_settings.is_valid()).is_true()
	
	# Test maximum valid values
	audio_settings.master_volume = 1.0
	audio_settings.distance_attenuation = 5.0
	audio_settings.crossfade_duration = 10.0
	
	assert_that(audio_settings.is_valid()).is_true()

func test_all_volumes_validation() -> void:
	"""Test that all volume parameters are validated."""
	var volume_properties: Array[String] = [
		"master_volume", "music_volume", "effects_volume", 
		"voice_volume", "ambient_volume", "ui_volume"
	]
	
	for property in volume_properties:
		# Reset to valid state
		audio_settings.reset_to_defaults()
		
		# Set invalid high value
		audio_settings.set(property, 1.5)
		assert_that(audio_settings.is_valid()).is_false()
		
		# Set invalid negative value
		audio_settings.set(property, -0.1)
		assert_that(audio_settings.is_valid()).is_false()
		
		# Set valid value
		audio_settings.set(property, 0.5)
		assert_that(audio_settings.is_valid()).is_true()