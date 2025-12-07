extends GdUnitTestSuite
## TestSuite for ProfileManager and profile resources.

const TEST_PROFILE_NAME = "test_profile_unit"
const TEST_CLONE_NAME = "test_cloned_profile"
const PROFILE_DIR = "user://profiles/"


func before_test() -> void:
	cleanup()


func after_test() -> void:
	cleanup()


func cleanup() -> void:
	var dir := DirAccess.open(PROFILE_DIR)
	if dir:
		for profile_name in [TEST_PROFILE_NAME, TEST_CLONE_NAME]:
			if dir.file_exists(profile_name + ".tres"):
				dir.remove(profile_name + ".tres")


func test_create_profile() -> void:
	var profile := ProfileManager.create_profile(TEST_PROFILE_NAME)

	assert_object(profile).is_not_null()
	assert_str(profile.callsign).is_equal(TEST_PROFILE_NAME)
	assert_str(ProfileManager.active_profile_name).is_equal(TEST_PROFILE_NAME)

	# Verify PlayerStats initialized
	assert_object(profile.stats).is_not_null()
	assert_int(profile.stats.kills).is_equal(0)

	# Verify file existence
	var path := PROFILE_DIR + TEST_PROFILE_NAME + ".tres"
	assert_bool(FileAccess.file_exists(path)).is_true()


func test_load_profile() -> void:
	ProfileManager.create_profile(TEST_PROFILE_NAME)
	ProfileManager.active_profile = null

	var profile := ProfileManager.load_profile(TEST_PROFILE_NAME)

	assert_object(profile).is_not_null()
	assert_str(profile.callsign).is_equal(TEST_PROFILE_NAME)
	assert_object(profile.stats).is_not_null()


func test_save_profile_persistence() -> void:
	var profile := ProfileManager.create_profile(TEST_PROFILE_NAME)
	profile.stats.kills = 500
	profile.stats.score = 6500 # Should be Captain rank
	profile.squad_name = "Black Lions"

	ProfileManager.save_profile()
	ProfileManager.active_profile = null

	var loaded_profile := ProfileManager.load_profile(TEST_PROFILE_NAME)

	assert_int(loaded_profile.stats.kills).is_equal(500)
	assert_int(loaded_profile.stats.score).is_equal(6500)
	assert_str(loaded_profile.squad_name).is_equal("Black Lions")
	# Rank is Captain (index 5)
	assert_str(loaded_profile.get_rank_name()).is_equal("Captain")


func test_rank_calculation() -> void:
	var profile := UserProfile.new()

	# Test rank thresholds
	profile.stats.score = 0
	profile.calculate_rank()
	assert_str(profile.get_rank_name()).is_equal("Ensign")

	profile.stats.score = 1500
	profile.calculate_rank()
	assert_str(profile.get_rank_name()).is_equal("Lt. Commander")

	profile.stats.score = 200000
	profile.calculate_rank()
	assert_str(profile.get_rank_name()).is_equal("Admiral")


func test_player_stats_accuracy() -> void:
	var stats := PlayerStats.new()
	stats.p_shots_fired = 100
	stats.p_shots_hit = 75

	assert_float(stats.get_primary_accuracy()).is_equal(75.0)

	stats.s_shots_fired = 50
	stats.s_shots_hit = 25

	assert_float(stats.get_overall_accuracy()).is_equal(66.666664)


func test_get_profile_list() -> void:
	ProfileManager.create_profile(TEST_PROFILE_NAME)

	var list := ProfileManager.get_profile_list()
	assert_array(list).contains([TEST_PROFILE_NAME])


func test_delete_profile() -> void:
	ProfileManager.create_profile(TEST_PROFILE_NAME)

	var success := ProfileManager.delete_profile(TEST_PROFILE_NAME)
	assert_bool(success).is_true()

	var path := PROFILE_DIR + TEST_PROFILE_NAME + ".tres"
	assert_bool(FileAccess.file_exists(path)).is_false()


func test_clone_profile() -> void:
	var original := ProfileManager.create_profile(TEST_PROFILE_NAME)
	original.stats.kills = 100
	original.stats.score = 1000
	ProfileManager.save_profile()

	var cloned := ProfileManager.clone_profile(TEST_PROFILE_NAME, TEST_CLONE_NAME)

	assert_object(cloned).is_not_null()
	assert_str(cloned.callsign).is_equal(TEST_CLONE_NAME)
	assert_int(cloned.stats.kills).is_equal(100)
	assert_int(cloned.stats.score).is_equal(1000)

	# Ensure files are separate
	assert_bool(FileAccess.file_exists(PROFILE_DIR + TEST_CLONE_NAME + ".tres")).is_true()


func test_duplicate_profile() -> void:
	var original := UserProfile.new()
	original.callsign = "Original"
	original.stats.kills = 50
	original.stats.score = 500

	var copy := original.duplicate_profile()

	# Verify independence
	copy.stats.kills = 100
	assert_int(original.stats.kills).is_equal(50)
	assert_int(copy.stats.kills).is_equal(100)
