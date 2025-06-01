class_name TestGraphicsSettingsData
extends GdUnitTestSuite

## Unit tests for GraphicsSettingsData class.
## Tests validation, serialization, utility methods, and configuration management.

var graphics_settings: GraphicsSettingsData

func before_each() -> void:
	"""Set up fresh GraphicsSettingsData instance for each test."""
	graphics_settings = GraphicsSettingsData.new()

func after_each() -> void:
	"""Clean up after each test."""
	graphics_settings = null

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_initialization() -> void:
	"""Test that GraphicsSettingsData initializes with correct defaults."""
	assert_that(graphics_settings).is_not_null()
	assert_that(graphics_settings.asset_type).is_equal("graphics_settings")
	assert_that(graphics_settings.resolution_width).is_equal(1920)
	assert_that(graphics_settings.resolution_height).is_equal(1080)
	assert_that(graphics_settings.fullscreen_mode).is_equal(GraphicsSettingsData.FullscreenMode.WINDOWED)
	assert_that(graphics_settings.vsync_enabled).is_true()
	assert_that(graphics_settings.max_fps).is_equal(60)

func test_quality_defaults() -> void:
	"""Test that quality settings initialize with correct defaults."""
	assert_that(graphics_settings.texture_quality).is_equal(2)
	assert_that(graphics_settings.shadow_quality).is_equal(2)
	assert_that(graphics_settings.effects_quality).is_equal(2)
	assert_that(graphics_settings.model_quality).is_equal(2)
	assert_that(graphics_settings.shader_quality).is_equal(2)

func test_antialiasing_defaults() -> void:
	"""Test that anti-aliasing settings initialize correctly."""
	assert_that(graphics_settings.antialiasing_enabled).is_true()
	assert_that(graphics_settings.antialiasing_level).is_equal(1)
	assert_that(graphics_settings.msaa_quality).is_equal(1)
	assert_that(graphics_settings.fxaa_enabled).is_false()
	assert_that(graphics_settings.temporal_anti_aliasing).is_false()
	assert_that(graphics_settings.anisotropic_filtering).is_equal(4)

# ============================================================================
# VALIDATION TESTS
# ============================================================================

func test_valid_default_settings() -> void:
	"""Test that default settings are valid."""
	assert_that(graphics_settings.is_valid()).is_true()
	assert_that(graphics_settings.validation_errors).is_empty()

func test_invalid_resolution() -> void:
	"""Test validation fails for invalid resolution."""
	graphics_settings.resolution_width = 0
	graphics_settings.resolution_height = 0
	
	assert_that(graphics_settings.is_valid()).is_false()
	assert_that(graphics_settings.validation_errors).contains("Invalid resolution dimensions")

func test_minimum_resolution() -> void:
	"""Test validation fails for resolution below minimum."""
	graphics_settings.resolution_width = 320
	graphics_settings.resolution_height = 240
	
	assert_that(graphics_settings.is_valid()).is_false()
	assert_that(graphics_settings.validation_errors).contains("Resolution too small (minimum 640x480)")

func test_quality_range_validation() -> void:
	"""Test that quality settings must be within valid range."""
	graphics_settings.texture_quality = 5  # Invalid: max is 4
	
	assert_that(graphics_settings.is_valid()).is_false()
	assert_that(graphics_settings.validation_errors).contains("Texture quality out of range (0-4)")

func test_negative_quality_validation() -> void:
	"""Test that negative quality settings are invalid."""
	graphics_settings.shadow_quality = -1
	
	assert_that(graphics_settings.is_valid()).is_false()
	assert_that(graphics_settings.validation_errors).contains("Shadow quality out of range (0-4)")

func test_invalid_framerate() -> void:
	"""Test validation for invalid frame rate settings."""
	graphics_settings.max_fps = -1  # Invalid: negative
	
	assert_that(graphics_settings.is_valid()).is_false()
	assert_that(graphics_settings.validation_errors).contains("Invalid frame rate limit (must be >= 0)")

func test_low_framerate() -> void:
	"""Test validation for very low frame rate."""
	graphics_settings.max_fps = 15  # Too low
	
	assert_that(graphics_settings.is_valid()).is_false()
	assert_that(graphics_settings.validation_errors).contains("Frame rate limit too low (minimum 30 FPS)")

func test_particle_density_validation() -> void:
	"""Test particle density range validation."""
	graphics_settings.particle_density = 3.0  # Too high
	
	assert_that(graphics_settings.is_valid()).is_false()
	assert_that(graphics_settings.validation_errors).contains("Particle density out of range (0.1-2.0)")

# ============================================================================
# SERIALIZATION TESTS
# ============================================================================

func test_to_dictionary() -> void:
	"""Test serialization to dictionary."""
	var data: Dictionary = graphics_settings.to_dictionary()
	
	assert_that(data).is_not_null()
	assert_that(data.has("resolution")).is_true()
	assert_that(data.has("quality")).is_true()
	assert_that(data.has("antialiasing")).is_true()
	assert_that(data.has("post_processing")).is_true()
	assert_that(data.has("performance")).is_true()

func test_resolution_serialization() -> void:
	"""Test resolution data serialization."""
	var data: Dictionary = graphics_settings.to_dictionary()
	var resolution: Dictionary = data["resolution"]
	
	assert_that(resolution["width"]).is_equal(1920)
	assert_that(resolution["height"]).is_equal(1080)
	assert_that(resolution["fullscreen_mode"]).is_equal(GraphicsSettingsData.FullscreenMode.WINDOWED)
	assert_that(resolution["vsync_enabled"]).is_true()
	assert_that(resolution["max_fps"]).is_equal(60)

func test_from_dictionary() -> void:
	"""Test deserialization from dictionary."""
	var test_data: Dictionary = {
		"resolution": {
			"width": 2560,
			"height": 1440,
			"fullscreen_mode": GraphicsSettingsData.FullscreenMode.EXCLUSIVE,
			"vsync_enabled": false,
			"max_fps": 120
		},
		"quality": {
			"texture_quality": 4,
			"shadow_quality": 3,
			"effects_quality": 4,
			"model_quality": 3,
			"shader_quality": 4
		}
	}
	
	graphics_settings.from_dictionary(test_data)
	
	assert_that(graphics_settings.resolution_width).is_equal(2560)
	assert_that(graphics_settings.resolution_height).is_equal(1440)
	assert_that(graphics_settings.fullscreen_mode).is_equal(GraphicsSettingsData.FullscreenMode.EXCLUSIVE)
	assert_that(graphics_settings.vsync_enabled).is_false()
	assert_that(graphics_settings.max_fps).is_equal(120)
	assert_that(graphics_settings.texture_quality).is_equal(4)
	assert_that(graphics_settings.shadow_quality).is_equal(3)

func test_round_trip_serialization() -> void:
	"""Test that serialization and deserialization preserves data."""
	graphics_settings.resolution_width = 3840
	graphics_settings.resolution_height = 2160
	graphics_settings.texture_quality = 4
	graphics_settings.antialiasing_enabled = false
	
	var data: Dictionary = graphics_settings.to_dictionary()
	var new_settings: GraphicsSettingsData = GraphicsSettingsData.new()
	new_settings.from_dictionary(data)
	
	assert_that(new_settings.resolution_width).is_equal(3840)
	assert_that(new_settings.resolution_height).is_equal(2160)
	assert_that(new_settings.texture_quality).is_equal(4)
	assert_that(new_settings.antialiasing_enabled).is_false()

# ============================================================================
# UTILITY METHOD TESTS
# ============================================================================

func test_quality_level_names() -> void:
	"""Test quality level name conversion."""
	assert_that(graphics_settings.get_quality_level_name(0)).is_equal("Off")
	assert_that(graphics_settings.get_quality_level_name(1)).is_equal("Low")
	assert_that(graphics_settings.get_quality_level_name(2)).is_equal("Medium")
	assert_that(graphics_settings.get_quality_level_name(3)).is_equal("High")
	assert_that(graphics_settings.get_quality_level_name(4)).is_equal("Ultra")
	assert_that(graphics_settings.get_quality_level_name(5)).is_equal("Custom")

func test_fullscreen_mode_names() -> void:
	"""Test fullscreen mode name conversion."""
	assert_that(graphics_settings.get_fullscreen_mode_name(GraphicsSettingsData.FullscreenMode.WINDOWED)).is_equal("Windowed")
	assert_that(graphics_settings.get_fullscreen_mode_name(GraphicsSettingsData.FullscreenMode.BORDERLESS)).is_equal("Borderless Fullscreen")
	assert_that(graphics_settings.get_fullscreen_mode_name(GraphicsSettingsData.FullscreenMode.EXCLUSIVE)).is_equal("Exclusive Fullscreen")

func test_resolution_string() -> void:
	"""Test resolution string formatting."""
	assert_that(graphics_settings.get_resolution_string()).is_equal("1920x1080")
	
	graphics_settings.resolution_width = 2560
	graphics_settings.resolution_height = 1440
	assert_that(graphics_settings.get_resolution_string()).is_equal("2560x1440")

func test_antialiasing_names() -> void:
	"""Test anti-aliasing level names."""
	assert_that(graphics_settings.get_antialiasing_name(1)).is_equal("2x MSAA")
	assert_that(graphics_settings.get_antialiasing_name(2)).is_equal("4x MSAA")
	assert_that(graphics_settings.get_antialiasing_name(3)).is_equal("8x MSAA")
	assert_that(graphics_settings.get_antialiasing_name(4)).is_equal("Custom")

func test_high_performance_detection() -> void:
	"""Test high performance configuration detection."""
	# Default settings should not be high performance
	assert_that(graphics_settings.is_high_performance_config()).is_false()
	
	# Set high performance settings
	graphics_settings.texture_quality = 4
	graphics_settings.shadow_quality = 4
	graphics_settings.effects_quality = 4
	graphics_settings.model_quality = 4
	graphics_settings.antialiasing_enabled = true
	graphics_settings.real_time_reflections = true
	
	assert_that(graphics_settings.is_high_performance_config()).is_true()

func test_performance_impact_estimation() -> void:
	"""Test performance impact rating calculation."""
	# Default settings should be medium impact
	var impact: String = graphics_settings.get_estimated_performance_impact()
	assert_that(impact).is_in(["Low", "Medium"])
	
	# Ultra settings should be high/very high impact
	graphics_settings.resolution_width = 3840
	graphics_settings.resolution_height = 2160
	graphics_settings.texture_quality = 4
	graphics_settings.shadow_quality = 4
	graphics_settings.effects_quality = 4
	graphics_settings.shader_quality = 4
	graphics_settings.antialiasing_enabled = true
	graphics_settings.antialiasing_level = 3
	graphics_settings.screen_space_ambient_occlusion = true
	graphics_settings.screen_space_reflections = true
	graphics_settings.volumetric_fog = true
	
	impact = graphics_settings.get_estimated_performance_impact()
	assert_that(impact).is_in(["High", "Very High"])

# ============================================================================
# CLONING TESTS
# ============================================================================

func test_clone() -> void:
	"""Test that cloning creates an independent copy."""
	graphics_settings.resolution_width = 2560
	graphics_settings.texture_quality = 4
	graphics_settings.antialiasing_enabled = false
	
	var cloned: GraphicsSettingsData = graphics_settings.clone()
	
	assert_that(cloned).is_not_same(graphics_settings)
	assert_that(cloned.resolution_width).is_equal(2560)
	assert_that(cloned.texture_quality).is_equal(4)
	assert_that(cloned.antialiasing_enabled).is_false()
	
	# Modify original, clone should be unchanged
	graphics_settings.resolution_width = 1920
	assert_that(cloned.resolution_width).is_equal(2560)

# ============================================================================
# COMPARISON TESTS
# ============================================================================

func test_equality_comparison() -> void:
	"""Test equality comparison between settings."""
	var other_settings: GraphicsSettingsData = GraphicsSettingsData.new()
	
	assert_that(graphics_settings.is_equal_to(other_settings)).is_true()
	
	other_settings.resolution_width = 2560
	assert_that(graphics_settings.is_equal_to(other_settings)).is_false()

func test_differences_detection() -> void:
	"""Test difference detection between settings."""
	var other_settings: GraphicsSettingsData = GraphicsSettingsData.new()
	other_settings.resolution_width = 2560
	other_settings.resolution_height = 1440
	other_settings.texture_quality = 4
	
	var differences: Array[String] = graphics_settings.get_differences(other_settings)
	
	assert_that(differences.size()).is_greater(0)
	# Should contain resolution and texture quality differences
	var has_resolution_diff: bool = false
	var has_texture_diff: bool = false
	
	for diff in differences:
		if "Resolution" in diff:
			has_resolution_diff = true
		if "Texture quality" in diff:
			has_texture_diff = true
	
	assert_that(has_resolution_diff).is_true()
	assert_that(has_texture_diff).is_true()

func test_null_comparison() -> void:
	"""Test comparison with null settings."""
	assert_that(graphics_settings.is_equal_to(null)).is_false()
	
	var differences: Array[String] = graphics_settings.get_differences(null)
	assert_that(differences.size()).is_equal(1)
	assert_that(differences[0]).is_equal("Other settings is null")

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_zero_framerate_unlimited() -> void:
	"""Test that zero frame rate is valid (unlimited)."""
	graphics_settings.max_fps = 0
	assert_that(graphics_settings.is_valid()).is_true()

func test_boundary_values() -> void:
	"""Test boundary values for various settings."""
	# Test minimum valid values
	graphics_settings.resolution_width = 640
	graphics_settings.resolution_height = 480
	graphics_settings.particle_density = 0.1
	graphics_settings.draw_distance = 0.5
	graphics_settings.level_of_detail_bias = 0.5
	
	assert_that(graphics_settings.is_valid()).is_true()
	
	# Test maximum valid values
	graphics_settings.particle_density = 2.0
	graphics_settings.draw_distance = 2.0
	graphics_settings.level_of_detail_bias = 2.0
	
	assert_that(graphics_settings.is_valid()).is_true()

func test_multiple_validation_errors() -> void:
	"""Test that multiple validation errors are collected."""
	graphics_settings.resolution_width = -1
	graphics_settings.texture_quality = -1
	graphics_settings.max_fps = -1
	
	assert_that(graphics_settings.is_valid()).is_false()
	assert_that(graphics_settings.validation_errors.size()).is_greater_equal(3)