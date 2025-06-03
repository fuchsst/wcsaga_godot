class_name TestGraphicsEngineSettingsIntegration
extends GdUnitTestSuite

## Unit tests for GraphicsSettingsData functionality

var settings: GraphicsSettingsData

func before_each() -> void:
	# Create GraphicsSettingsData instance directly
	settings = GraphicsSettingsData.new()

func after_each() -> void:
	settings = null

func test_default_settings_creation() -> void:
	# Test that default settings are created with valid values
	assert_that(settings).is_not_null()
	assert_that(settings.render_quality).is_between(0, 3)
	assert_that(settings.target_framerate).is_between(30, 240)

func test_settings_validation() -> void:
	# Test graphics settings validation
	
	# Test valid settings
	settings.render_quality = 2
	settings.target_framerate = 60
	settings.particle_density = 1.0
	assert_that(settings.is_valid()).is_true()
	
	# Test invalid render quality
	settings.render_quality = -1
	assert_that(settings.is_valid()).is_false()
	
	# Reset to valid and test invalid framerate
	settings.render_quality = 2
	settings.target_framerate = 999
	assert_that(settings.is_valid()).is_false()

func test_quality_preset_application() -> void:
	# Test quality preset application
	
	# Test LOW preset
	settings.apply_quality_preset(0)  # LOW
	assert_that(settings.render_quality).is_equal(0)
	assert_that(settings.particle_density).is_less(0.5)
	
	# Test ULTRA preset
	settings.apply_quality_preset(3)  # ULTRA
	assert_that(settings.render_quality).is_equal(3)
	assert_that(settings.particle_density).is_equal(1.0)

func test_validation_errors() -> void:
	# Test validation error reporting
	settings.render_quality = -1
	settings.target_framerate = 999
	
	var errors: Array = settings.get_validation_errors()
	assert_that(errors).is_not_empty()
	assert_that(errors.size()).is_greater_equal(2)

func test_quality_description() -> void:
	# Test quality level descriptions
	var low_desc: String = settings.get_quality_description(0)
	var ultra_desc: String = settings.get_quality_description(3)
	
	assert_that(low_desc).contains("Low")
	assert_that(ultra_desc).contains("Ultra")

func test_settings_cloning() -> void:
	# Test settings cloning
	settings.render_quality = 1
	settings.target_framerate = 90
	
	var cloned = settings.clone()
	assert_that(cloned).is_not_null()
	assert_that(cloned.render_quality).is_equal(1)
	assert_that(cloned.target_framerate).is_equal(90)

func test_dictionary_conversion() -> void:
	# Test dictionary conversion
	settings.render_quality = 2
	settings.target_framerate = 120
	
	var dict: Dictionary = settings.to_dictionary()
	assert_that(dict).contains_key("render_quality")
	assert_that(dict).contains_key("target_framerate")
	assert_that(dict.render_quality).is_equal(2)
	assert_that(dict.target_framerate).is_equal(120)

func test_from_dictionary() -> void:
	# Test loading from dictionary
	var test_data: Dictionary = {
		"render_quality": 1,
		"target_framerate": 75,
		"bloom_enabled": false
	}
	
	settings.from_dictionary(test_data)
	assert_that(settings.render_quality).is_equal(1)
	assert_that(settings.target_framerate).is_equal(75)
	assert_that(settings.bloom_enabled).is_false()

func test_boundary_values() -> void:
	# Test boundary value validation
	
	# Test minimum values
	settings.render_quality = 0
	settings.target_framerate = 30
	settings.particle_density = 0.0
	assert_that(settings.is_valid()).is_true()
	
	# Test maximum values
	settings.render_quality = 3
	settings.target_framerate = 240
	settings.particle_density = 2.0
	assert_that(settings.is_valid()).is_true()
	
	# Test beyond boundaries
	settings.render_quality = 4
	assert_that(settings.is_valid()).is_false()
	
	settings.render_quality = 3
	settings.target_framerate = 241
	assert_that(settings.is_valid()).is_false()

func test_preset_configurations() -> void:
	# Test that all quality presets are properly configured
	
	for quality_level in range(4):
		settings.apply_quality_preset(quality_level)
		assert_that(settings.is_valid()).is_true()
		assert_that(settings.render_quality).is_equal(quality_level)
	
	# Verify preset progression (higher quality = better settings)
	settings.apply_quality_preset(0)  # LOW
	var low_particle_density: float = settings.particle_density
	
	settings.apply_quality_preset(3)  # ULTRA
	var ultra_particle_density: float = settings.particle_density
	
	assert_that(ultra_particle_density).is_greater(low_particle_density)