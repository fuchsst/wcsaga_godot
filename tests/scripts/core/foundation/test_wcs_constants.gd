extends GdUnitTestSuite

## Unit tests for WCSConstants class
## Validates all constant values match WCS source code exactly
## Tests utility functions and validation methods

func test_string_length_constants():
	# Test critical string length constants match WCS globals.h
	assert_that(WCSConstants.PATHNAME_LENGTH).is_equal(192)
	assert_that(WCSConstants.NAME_LENGTH).is_equal(32)
	assert_that(WCSConstants.SEXP_LENGTH).is_equal(128)
	assert_that(WCSConstants.MESSAGE_LENGTH).is_equal(512)
	assert_that(WCSConstants.MULTITEXT_LENGTH).is_equal(4096)

func test_ship_constants():
	# Test ship-related constants match WCS values
	assert_that(WCSConstants.MAX_SHIPS).is_equal(400)
	assert_that(WCSConstants.MAX_SHIP_CLASSES).is_equal(130)
	assert_that(WCSConstants.MAX_WINGS).is_equal(75)
	assert_that(WCSConstants.MAX_SHIPS_PER_WING).is_equal(6)

func test_weapon_constants():
	# Test weapon-related constants match WCS values
	assert_that(WCSConstants.MAX_SHIP_PRIMARY_BANKS).is_equal(3)
	assert_that(WCSConstants.MAX_SHIP_SECONDARY_BANKS).is_equal(6)
	assert_that(WCSConstants.MAX_SHIP_WEAPONS).is_equal(9)
	assert_that(WCSConstants.MAX_WEAPONS).is_equal(700)

func test_object_system_constants():
	# Test object system constants match WCS values
	assert_that(WCSConstants.MAX_OBJECTS).is_equal(2000)
	assert_that(WCSConstants.MAX_LIGHTS).is_equal(256)
	assert_that(WCSConstants.MAX_PLAYERS).is_equal(12)

func test_math_constants():
	# Test mathematical constants match WCS values with proper precision
	assert_that(WCSConstants.PI).is_equal_approx(3.141592654, 0.000001)
	assert_that(WCSConstants.PI2).is_equal_approx(6.283185308, 0.000001)
	assert_that(WCSConstants.PI_2).is_equal_approx(1.570796327, 0.000001)

func test_angle_conversion():
	# Test angle to radians conversion
	assert_that(WCSConstants.angle_to_radians(0.0)).is_equal_approx(0.0, 0.001)
	assert_that(WCSConstants.angle_to_radians(90.0)).is_equal_approx(WCSConstants.PI_2, 0.001)
	assert_that(WCSConstants.angle_to_radians(180.0)).is_equal_approx(WCSConstants.PI, 0.001)
	assert_that(WCSConstants.angle_to_radians(360.0)).is_equal_approx(WCSConstants.PI2, 0.001)

func test_filename_validation():
	# Test filename validation function
	assert_that(WCSConstants.is_valid_filename("test.pof")).is_true()
	assert_that(WCSConstants.is_valid_filename("mission1.fs2")).is_true()
	
	assert_that(WCSConstants.is_valid_filename("")).is_false()
	assert_that(WCSConstants.is_valid_filename("none")).is_false()
	assert_that(WCSConstants.is_valid_filename("NONE")).is_false()
	assert_that(WCSConstants.is_valid_filename("<none>")).is_false()
	assert_that(WCSConstants.is_valid_filename("<NONE>")).is_false()

func test_clamp_utility():
	# Test clamp utility function
	assert_that(WCSConstants.clamp_value(5.0, 0.0, 10.0)).is_equal(5.0)
	assert_that(WCSConstants.clamp_value(-5.0, 0.0, 10.0)).is_equal(0.0)
	assert_that(WCSConstants.clamp_value(15.0, 0.0, 10.0)).is_equal(10.0)

func test_min_max_utilities():
	# Test min and max utility functions
	assert_that(WCSConstants.min_value(5.0, 10.0)).is_equal(5.0)
	assert_that(WCSConstants.min_value(10.0, 5.0)).is_equal(5.0)
	
	assert_that(WCSConstants.max_value(5.0, 10.0)).is_equal(10.0)
	assert_that(WCSConstants.max_value(10.0, 5.0)).is_equal(10.0)

func test_validation_functions():
	# Test ship count validation
	assert_that(WCSConstants.validate_ship_count(0)).is_true()
	assert_that(WCSConstants.validate_ship_count(200)).is_true()
	assert_that(WCSConstants.validate_ship_count(400)).is_true()
	assert_that(WCSConstants.validate_ship_count(-1)).is_false()
	assert_that(WCSConstants.validate_ship_count(401)).is_false()
	
	# Test weapon count validation
	assert_that(WCSConstants.validate_weapon_count(0)).is_true()
	assert_that(WCSConstants.validate_weapon_count(350)).is_true()
	assert_that(WCSConstants.validate_weapon_count(700)).is_true()
	assert_that(WCSConstants.validate_weapon_count(-1)).is_false()
	assert_that(WCSConstants.validate_weapon_count(701)).is_false()
	
	# Test object count validation
	assert_that(WCSConstants.validate_object_count(0)).is_true()
	assert_that(WCSConstants.validate_object_count(1000)).is_true()
	assert_that(WCSConstants.validate_object_count(2000)).is_true()
	assert_that(WCSConstants.validate_object_count(-1)).is_false()
	assert_that(WCSConstants.validate_object_count(2001)).is_false()

func test_string_length_validation():
	# Test pathname length validation
	var short_path: String = "data/missions/test.fs2"
	var long_path: String = "a".repeat(WCSConstants.PATHNAME_LENGTH + 1)
	var max_path: String = "a".repeat(WCSConstants.PATHNAME_LENGTH)
	
	assert_that(WCSConstants.validate_pathname_length(short_path)).is_true()
	assert_that(WCSConstants.validate_pathname_length(max_path)).is_true()
	assert_that(WCSConstants.validate_pathname_length(long_path)).is_false()
	
	# Test name length validation
	var short_name: String = "Test"
	var long_name: String = "a".repeat(WCSConstants.NAME_LENGTH + 1)
	var max_name: String = "a".repeat(WCSConstants.NAME_LENGTH)
	
	assert_that(WCSConstants.validate_name_length(short_name)).is_true()
	assert_that(WCSConstants.validate_name_length(max_name)).is_true()
	assert_that(WCSConstants.validate_name_length(long_name)).is_false()

func test_noise_constants():
	# Test noise array constants for thruster animations
	assert_that(WCSConstants.NOISE_NUM_FRAMES).is_equal(15)
	assert_that(WCSConstants.NOISE_VALUES.size()).is_equal(15)
	
	# Test specific noise values match WCS source
	assert_that(WCSConstants.NOISE_VALUES[0]).is_equal_approx(0.468225, 0.000001)
	assert_that(WCSConstants.NOISE_VALUES[9]).is_equal_approx(1.000000, 0.000001)
	assert_that(WCSConstants.NOISE_VALUES[14]).is_equal_approx(0.000000, 0.000001)

func test_platform_constants():
	# Test platform-specific constants
	assert_that(WCSConstants.DIR_SEPARATOR_STR).is_equal("/")
	assert_that(WCSConstants.UNINITIALIZED).is_equal(0x7f8e6d9c)

func test_file_system_constants():
	# Test file system constants
	assert_that(WCSConstants.MAX_FILENAME_LEN).is_equal(32)
	assert_that(WCSConstants.MAX_PATH_LEN).is_equal(260)

func test_detail_level_constants():
	# Test detail level constants
	assert_that(WCSConstants.MAX_DETAIL_LEVEL).is_equal(4)
	assert_that(WCSConstants.NUM_DEFAULT_DETAIL_LEVELS).is_equal(4)