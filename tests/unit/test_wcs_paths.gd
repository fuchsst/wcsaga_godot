extends GdUnitTestSuite

## Unit tests for WCSPaths class
## Tests path constants, utility functions, and cross-platform compatibility
## Ensures all paths follow Godot conventions

func test_base_directory_constants():
	# Test base directory constants
	assert_that(WCSPaths.GAME_DATA_DIR).is_equal("res://data/")
	assert_that(WCSPaths.USER_DATA_DIR).is_equal("user://data/")

func test_asset_directory_constants():
	# Test asset directory constants
	assert_that(WCSPaths.MISSIONS_DIR).is_equal("res://data/missions/")
	assert_that(WCSPaths.MODELS_DIR).is_equal("res://data/models/")
	assert_that(WCSPaths.TEXTURES_DIR).is_equal("res://data/textures/")
	assert_that(WCSPaths.SOUNDS_DIR).is_equal("res://data/sounds/")
	assert_that(WCSPaths.MUSIC_DIR).is_equal("res://data/music/")

func test_user_data_directories():
	# Test user data directory constants
	assert_that(WCSPaths.SAVES_DIR).is_equal("user://data/saves/")
	assert_that(WCSPaths.CONFIG_DIR).is_equal("user://data/config/")
	assert_that(WCSPaths.SCREENSHOTS_DIR).is_equal("user://data/screenshots/")

func test_cache_directories():
	# Test cache directory constants
	assert_that(WCSPaths.CACHE_DIR).is_equal("user://data/cache/")
	assert_that(WCSPaths.MODEL_CACHE_DIR).is_equal("user://data/cache/models/")
	assert_that(WCSPaths.TEXTURE_CACHE_DIR).is_equal("user://data/cache/textures/")

func test_file_extensions():
	# Test file extension constants
	assert_that(WCSPaths.MISSION_EXT).is_equal(".fs2")
	assert_that(WCSPaths.MODEL_EXT).is_equal(".pof")
	assert_that(WCSPaths.TABLE_EXT).is_equal(".tbl")
	assert_that(WCSPaths.ARCHIVE_EXT).is_equal(".vp")
	assert_that(WCSPaths.RESOURCE_EXT).is_equal(".tres")
	assert_that(WCSPaths.SCENE_EXT).is_equal(".tscn")

func test_combine_path():
	# Test path combination function
	assert_that(WCSPaths.combine_path("res://data", "missions")).is_equal("res://data/missions")
	assert_that(WCSPaths.combine_path("res://data/", "missions")).is_equal("res://data/missions")
	assert_that(WCSPaths.combine_path("user://", "config/controls")).is_equal("user://config/controls")

func test_ensure_trailing_separator():
	# Test trailing separator function
	assert_that(WCSPaths.ensure_trailing_separator("res://data")).is_equal("res://data/")
	assert_that(WCSPaths.ensure_trailing_separator("res://data/")).is_equal("res://data/")
	assert_that(WCSPaths.ensure_trailing_separator("")).is_equal("/")

func test_remove_extension():
	# Test extension removal function
	assert_that(WCSPaths.remove_extension("test.pof")).is_equal("test")
	assert_that(WCSPaths.remove_extension("mission1.fs2")).is_equal("mission1")
	assert_that(WCSPaths.remove_extension("config.tbl")).is_equal("config")
	assert_that(WCSPaths.remove_extension("noextension")).is_equal("noextension")
	assert_that(WCSPaths.remove_extension(".hidden")).is_equal("")

func test_get_extension():
	# Test extension extraction function
	assert_that(WCSPaths.get_extension("test.pof")).is_equal(".pof")
	assert_that(WCSPaths.get_extension("mission1.fs2")).is_equal(".fs2")
	assert_that(WCSPaths.get_extension("data.backup.tbl")).is_equal(".tbl")
	assert_that(WCSPaths.get_extension("noextension")).is_equal("")
	assert_that(WCSPaths.get_extension(".hidden")).is_equal(".hidden")

func test_wcs_to_godot_path():
	# Test WCS path to Godot path conversion
	assert_that(WCSPaths.wcs_to_godot_path("data\\missions\\test.fs2")).is_equal("res://data/missions/test.fs2")
	assert_that(WCSPaths.wcs_to_godot_path("data/missions/test.fs2")).is_equal("res://data/missions/test.fs2")
	assert_that(WCSPaths.wcs_to_godot_path("res://data/test.pof")).is_equal("res://data/test.pof")
	assert_that(WCSPaths.wcs_to_godot_path("user://config/test.cfg")).is_equal("user://config/test.cfg")

func test_validate_wcs_file_extension():
	# Test file extension validation
	assert_that(WCSPaths.validate_wcs_file_extension("test.pof", ".pof")).is_true()
	assert_that(WCSPaths.validate_wcs_file_extension("mission.fs2", ".fs2")).is_true()
	assert_that(WCSPaths.validate_wcs_file_extension("TEST.POF", ".pof")).is_true()
	
	assert_that(WCSPaths.validate_wcs_file_extension("test.pof", ".fs2")).is_false()
	assert_that(WCSPaths.validate_wcs_file_extension("test", ".pof")).is_false()

func test_get_cache_dir_for_extension():
	# Test cache directory selection by extension
	assert_that(WCSPaths.get_cache_dir_for_extension(".pof")).is_equal(WCSPaths.MODEL_CACHE_DIR)
	assert_that(WCSPaths.get_cache_dir_for_extension(".pcx")).is_equal(WCSPaths.TEXTURE_CACHE_DIR)
	assert_that(WCSPaths.get_cache_dir_for_extension(".jpg")).is_equal(WCSPaths.TEXTURE_CACHE_DIR)
	assert_that(WCSPaths.get_cache_dir_for_extension(".lua")).is_equal(WCSPaths.SCRIPT_CACHE_DIR)
	assert_that(WCSPaths.get_cache_dir_for_extension(".unknown")).is_equal(WCSPaths.CACHE_DIR)

func test_get_cached_path():
	# Test cached path generation
	var original_path: String = "res://data/models/fighter.pof"
	var cached_path: String = WCSPaths.get_cached_path(original_path)
	
	assert_that(cached_path.begins_with(WCSPaths.MODEL_CACHE_DIR)).is_true()
	assert_that(cached_path.ends_with("fighter.tres")).is_true()
	
	var texture_path: String = "res://data/textures/hull.pcx"
	var cached_texture: String = WCSPaths.get_cached_path(texture_path)
	assert_that(cached_texture.begins_with(WCSPaths.TEXTURE_CACHE_DIR)).is_true()

func test_pathname_validation():
	# Test pathname length validation
	var short_path: String = "data/missions/test.fs2"
	var max_path: String = "a".repeat(WCSConstants.PATHNAME_LENGTH)
	var long_path: String = "a".repeat(WCSConstants.PATHNAME_LENGTH + 1)
	
	assert_that(WCSPaths.validate_pathname_length(short_path)).is_true()
	assert_that(WCSPaths.validate_pathname_length(max_path)).is_true()
	assert_that(WCSPaths.validate_pathname_length(long_path)).is_false()

func test_filename_validation():
	# Test filename length validation
	var short_name: String = "test.pof"
	var max_name: String = "a".repeat(WCSConstants.MAX_FILENAME_LEN)
	var long_name: String = "a".repeat(WCSConstants.MAX_FILENAME_LEN + 1)
	
	assert_that(WCSPaths.validate_filename_length(short_name)).is_true()
	assert_that(WCSPaths.validate_filename_length(max_name)).is_true()
	assert_that(WCSPaths.validate_filename_length(long_name)).is_false()

func test_get_mission_path():
	# Test mission path generation
	assert_that(WCSPaths.get_mission_path("training1")).is_equal("res://data/missions/training1.fs2")
	assert_that(WCSPaths.get_mission_path("training1.fs2")).is_equal("res://data/missions/training1.fs2")

func test_get_model_path():
	# Test model path generation
	assert_that(WCSPaths.get_model_path("fighter")).is_equal("res://data/models/fighter.pof")
	assert_that(WCSPaths.get_model_path("fighter.pof")).is_equal("res://data/models/fighter.pof")

func test_get_table_path():
	# Test table path generation
	assert_that(WCSPaths.get_table_path("ships")).is_equal("res://data/tables/ships.tbl")
	assert_that(WCSPaths.get_table_path("ships.tbl")).is_equal("res://data/tables/ships.tbl")

# Note: File and directory existence tests would require actual file system setup
# These are integration tests that should be run in a proper test environment
func test_file_operations_interface():
	# Test that file operation functions exist and have correct signatures
	# These are interface tests - actual functionality depends on file system
	
	# Test file_exists function exists
	var result: bool = WCSPaths.file_exists("nonexistent.file")
	# Result can be true or false, we're just testing the function exists
	
	# Test dir_exists function exists  
	result = WCSPaths.dir_exists("nonexistent/directory")
	# Result can be true or false, we're just testing the function exists

func test_create_directories_interface():
	# Test that create_directories function exists and can be called
	# Actual directory creation would require file system access
	WCSPaths.create_directories()
	# No assertion - just testing the function can be called without error