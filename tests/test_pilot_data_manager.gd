extends GdUnitTestSuite

## Test suite for PilotDataManager
## Validates pilot creation, loading, saving, and management functionality
## Tests integration with PlayerProfile system and file operations

# Test objects
var pilot_manager: PilotDataManager = null
var test_directory: String = "user://test_pilots/"
var test_pilots: Array[String] = []

func before_test() -> void:
	"""Setup before each test."""
	# Create test pilot manager
	pilot_manager = PilotDataManager.new()
	pilot_manager.pilot_directory = test_directory
	pilot_manager.auto_backup_enabled = false  # Disable for testing
	
	# Ensure test directory exists
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("test_pilots"):
		dir.make_dir("test_pilots")
	
	# Clear test pilots list
	test_pilots.clear()

func after_test() -> void:
	"""Cleanup after each test."""
	# Clean up test pilots
	for callsign in test_pilots:
		var file_path: String = pilot_manager._get_pilot_file_path(callsign)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	
	# Clean up test directory
	var dir: DirAccess = DirAccess.open("user://")
	if dir.dir_exists("test_pilots"):
		dir.remove("test_pilots")
	
	pilot_manager = null

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_pilot_manager_initializes_correctly() -> void:
	"""Test that PilotDataManager initializes properly."""
	# Assert
	assert_object(pilot_manager).is_not_null()
	assert_str(pilot_manager.pilot_directory).is_equal(test_directory)
	assert_int(pilot_manager.max_pilots).is_equal(100)
	assert_int(pilot_manager.backup_count).is_equal(3)

func test_validation_patterns_setup() -> void:
	"""Test that validation patterns are set up correctly."""
	# Assert
	assert_object(pilot_manager.callsign_pattern).is_not_null()
	assert_object(pilot_manager.squadron_pattern).is_not_null()

# ============================================================================
# PILOT CREATION TESTS
# ============================================================================

func test_create_pilot_success() -> void:
	"""Test successful pilot creation."""
	# Arrange
	var callsign: String = "TestPilot"
	var squadron: String = "Test Squadron"
	var image: String = "test_image.png"
	test_pilots.append(callsign)
	
	# Act
	var profile: PlayerProfile = pilot_manager.create_pilot(callsign, squadron, image)
	
	# Assert
	assert_object(profile).is_not_null()
	assert_str(profile.callsign).is_equal(callsign)
	assert_str(profile.squad_name).is_equal(squadron)
	assert_str(profile.image_filename).is_equal(image)

func test_create_pilot_empty_callsign() -> void:
	"""Test pilot creation with empty callsign."""
	# Arrange
	var callsign: String = ""
	
	# Act
	var profile: PlayerProfile = pilot_manager.create_pilot(callsign)
	
	# Assert
	assert_object(profile).is_null()

func test_create_pilot_invalid_callsign() -> void:
	"""Test pilot creation with invalid callsign."""
	# Arrange
	var invalid_callsigns: Array[String] = [
		"Test@Pilot",  # Invalid character
		"Very Long Pilot Name That Exceeds Limit",  # Too long
		"Test\nPilot",  # Newline character
		"123$%^&*"  # Special characters
	]
	
	for callsign in invalid_callsigns:
		# Act
		var profile: PlayerProfile = pilot_manager.create_pilot(callsign)
		
		# Assert
		assert_object(profile).is_null()

func test_create_duplicate_pilot() -> void:
	"""Test creation of duplicate pilot."""
	# Arrange
	var callsign: String = "DuplicateTest"
	test_pilots.append(callsign)
	
	# Act - Create first pilot
	var profile1: PlayerProfile = pilot_manager.create_pilot(callsign)
	
	# Act - Attempt to create duplicate
	var profile2: PlayerProfile = pilot_manager.create_pilot(callsign)
	
	# Assert
	assert_object(profile1).is_not_null()
	assert_object(profile2).is_null()

func test_create_pilot_generates_short_callsign() -> void:
	"""Test that short callsign is generated correctly."""
	# Arrange
	var callsign: String = "Long Test Name"
	test_pilots.append(callsign)
	
	# Act
	var profile: PlayerProfile = pilot_manager.create_pilot(callsign)
	
	# Assert
	assert_object(profile).is_not_null()
	assert_str(profile.short_callsign).is_equal("LongTest")

# ============================================================================
# PILOT LOADING TESTS
# ============================================================================

func test_load_pilot_success() -> void:
	"""Test successful pilot loading."""
	# Arrange
	var callsign: String = "LoadTest"
	test_pilots.append(callsign)
	var created_profile: PlayerProfile = pilot_manager.create_pilot(callsign, "Test Squad")
	
	# Act
	var loaded_profile: PlayerProfile = pilot_manager.load_pilot(callsign)
	
	# Assert
	assert_object(loaded_profile).is_not_null()
	assert_str(loaded_profile.callsign).is_equal(callsign)
	assert_str(loaded_profile.squad_name).is_equal("Test Squad")

func test_load_nonexistent_pilot() -> void:
	"""Test loading non-existent pilot."""
	# Arrange
	var callsign: String = "NonExistent"
	
	# Act
	var profile: PlayerProfile = pilot_manager.load_pilot(callsign)
	
	# Assert
	assert_object(profile).is_null()

func test_load_pilot_caching() -> void:
	"""Test that pilot loading uses cache."""
	# Arrange
	var callsign: String = "CacheTest"
	test_pilots.append(callsign)
	pilot_manager.create_pilot(callsign)
	
	# Act - Load twice
	var profile1: PlayerProfile = pilot_manager.load_pilot(callsign)
	var profile2: PlayerProfile = pilot_manager.load_pilot(callsign)
	
	# Assert - Should be same object from cache
	assert_object(profile1).is_not_null()
	assert_object(profile2).is_not_null()
	assert_object(profile1).is_same(profile2)

# ============================================================================
# PILOT LIST MANAGEMENT TESTS
# ============================================================================

func test_get_pilot_list() -> void:
	"""Test getting pilot list."""
	# Arrange
	var test_callsigns: Array[String] = ["Alpha", "Bravo", "Charlie"]
	for callsign in test_callsigns:
		test_pilots.append(callsign)
		pilot_manager.create_pilot(callsign)
	
	# Act
	var pilot_list: Array[String] = pilot_manager.get_pilot_list()
	
	# Assert
	assert_int(pilot_list.size()).is_equal(3)
	for callsign in test_callsigns:
		assert_bool(callsign in pilot_list).is_true()

func test_pilot_exists() -> void:
	"""Test pilot existence checking."""
	# Arrange
	var callsign: String = "ExistsTest"
	test_pilots.append(callsign)
	
	# Act & Assert - Before creation
	assert_bool(pilot_manager.pilot_exists(callsign)).is_false()
	
	# Act - Create pilot
	pilot_manager.create_pilot(callsign)
	
	# Assert - After creation
	assert_bool(pilot_manager.pilot_exists(callsign)).is_true()

func test_get_pilot_info() -> void:
	"""Test getting pilot information."""
	# Arrange
	var callsign: String = "InfoTest"
	var squadron: String = "Info Squadron"
	test_pilots.append(callsign)
	pilot_manager.create_pilot(callsign, squadron)
	
	# Act
	var pilot_info: Dictionary = pilot_manager.get_pilot_info(callsign)
	
	# Assert
	assert_dict(pilot_info).is_not_empty()
	assert_dict(pilot_info).contains_keys(["callsign", "squadron", "created", "rank", "score"])
	assert_str(pilot_info["callsign"]).is_equal(callsign)
	assert_str(pilot_info["squadron"]).is_equal(squadron)

# ============================================================================
# PILOT DELETION TESTS
# ============================================================================

func test_delete_pilot_success() -> void:
	"""Test successful pilot deletion."""
	# Arrange
	var callsign: String = "DeleteTest"
	test_pilots.append(callsign)
	pilot_manager.create_pilot(callsign)
	
	# Act
	var delete_result: bool = pilot_manager.delete_pilot(callsign, true)
	
	# Assert
	assert_bool(delete_result).is_true()
	assert_bool(pilot_manager.pilot_exists(callsign)).is_false()

func test_delete_pilot_without_confirmation() -> void:
	"""Test pilot deletion without confirmation."""
	# Arrange
	var callsign: String = "NoConfirmTest"
	test_pilots.append(callsign)
	pilot_manager.create_pilot(callsign)
	
	# Act
	var delete_result: bool = pilot_manager.delete_pilot(callsign, false)
	
	# Assert
	assert_bool(delete_result).is_false()
	assert_bool(pilot_manager.pilot_exists(callsign)).is_true()

func test_delete_nonexistent_pilot() -> void:
	"""Test deletion of non-existent pilot."""
	# Arrange
	var callsign: String = "NonExistentDelete"
	
	# Act
	var delete_result: bool = pilot_manager.delete_pilot(callsign, true)
	
	# Assert
	assert_bool(delete_result).is_false()

# ============================================================================
# PILOT PERSISTENCE TESTS
# ============================================================================

func test_save_current_pilot() -> void:
	"""Test saving current pilot."""
	# Arrange
	var callsign: String = "SaveTest"
	test_pilots.append(callsign)
	var profile: PlayerProfile = pilot_manager.create_pilot(callsign)
	pilot_manager.set_current_pilot(profile)
	
	# Modify profile
	profile.pilot_stats.score = 1500
	
	# Act
	var save_result: bool = pilot_manager.save_current_pilot()
	
	# Assert
	assert_bool(save_result).is_true()
	
	# Verify saved data
	var loaded_profile: PlayerProfile = pilot_manager.load_pilot(callsign)
	assert_int(loaded_profile.pilot_stats.score).is_equal(1500)

func test_save_without_current_pilot() -> void:
	"""Test saving when no pilot is current."""
	# Act
	var save_result: bool = pilot_manager.save_current_pilot()
	
	# Assert
	assert_bool(save_result).is_false()

# ============================================================================
# VALIDATION TESTS
# ============================================================================

func test_validate_pilot_name_valid() -> void:
	"""Test pilot name validation with valid names."""
	var valid_names: Array[String] = [
		"Alpha",
		"Test_Pilot",
		"Test-Pilot",
		"Test Pilot",
		"Pilot123",
		"A"  # Single character
	]
	
	for name in valid_names:
		# Act & Assert
		assert_bool(PilotDataManager.validate_pilot_name(name)).is_true()

func test_validate_pilot_name_invalid() -> void:
	"""Test pilot name validation with invalid names."""
	var invalid_names: Array[String] = [
		"",  # Empty
		"Very Long Pilot Name That Exceeds The Maximum Length Limit",  # Too long
		"Test@Pilot",  # Invalid character
		"Test\nPilot",  # Newline
		"Test\tPilot"  # Tab
	]
	
	for name in invalid_names:
		# Act & Assert
		assert_bool(PilotDataManager.validate_pilot_name(name)).is_false()

# ============================================================================
# CURRENT PILOT MANAGEMENT TESTS
# ============================================================================

func test_get_set_current_pilot() -> void:
	"""Test getting and setting current pilot."""
	# Arrange
	var callsign: String = "CurrentTest"
	test_pilots.append(callsign)
	var profile: PlayerProfile = pilot_manager.create_pilot(callsign)
	
	# Act
	pilot_manager.set_current_pilot(profile)
	
	# Assert
	assert_object(pilot_manager.get_current_pilot()).is_same(profile)
	assert_bool(pilot_manager.is_pilot_loaded()).is_true()

func test_clear_current_pilot() -> void:
	"""Test clearing current pilot."""
	# Arrange
	var callsign: String = "ClearTest"
	test_pilots.append(callsign)
	var profile: PlayerProfile = pilot_manager.create_pilot(callsign)
	pilot_manager.set_current_pilot(profile)
	
	# Act
	pilot_manager.set_current_pilot(null)
	
	# Assert
	assert_object(pilot_manager.get_current_pilot()).is_null()
	assert_bool(pilot_manager.is_pilot_loaded()).is_false()

# ============================================================================
# UTILITY TESTS
# ============================================================================

func test_refresh_pilot_list() -> void:
	"""Test refreshing pilot list."""
	# Arrange
	var callsign: String = "RefreshTest"
	test_pilots.append(callsign)
	pilot_manager.create_pilot(callsign)
	
	# Act
	pilot_manager.refresh_pilot_list()
	
	# Assert
	assert_bool(callsign in pilot_manager.get_pilot_list()).is_true()

func test_clear_pilot_cache() -> void:
	"""Test clearing pilot cache."""
	# Arrange
	var callsign: String = "CacheTest"
	test_pilots.append(callsign)
	pilot_manager.create_pilot(callsign)
	pilot_manager.load_pilot(callsign)  # Load into cache
	
	# Act
	pilot_manager.clear_pilot_cache()
	
	# Assert - Should still be able to load from file
	var profile: PlayerProfile = pilot_manager.load_pilot(callsign)
	assert_object(profile).is_not_null()

func test_get_pilot_count() -> void:
	"""Test getting pilot count."""
	# Arrange
	var initial_count: int = pilot_manager.get_pilot_count()
	var callsign: String = "CountTest"
	test_pilots.append(callsign)
	
	# Act
	pilot_manager.create_pilot(callsign)
	
	# Assert
	assert_int(pilot_manager.get_pilot_count()).is_equal(initial_count + 1)

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

func test_manager_handles_corrupted_files() -> void:
	"""Test manager handling of corrupted pilot files."""
	# Arrange
	var callsign: String = "CorruptedTest"
	test_pilots.append(callsign)
	
	# Create a corrupted file
	var file_path: String = pilot_manager._get_pilot_file_path(callsign)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string("corrupted data")
	file.close()
	
	# Add to pilot list manually
	pilot_manager.pilot_list.append(callsign)
	
	# Act
	var profile: PlayerProfile = pilot_manager.load_pilot(callsign)
	
	# Assert - Should handle gracefully
	assert_object(profile).is_null()

func test_manager_handles_missing_directory() -> void:
	"""Test manager handling when pilot directory is missing."""
	# Arrange
	pilot_manager.pilot_directory = "user://nonexistent_directory/"
	
	# Act & Assert - Should not crash
	var pilot_list: Array[String] = pilot_manager.get_pilot_list()
	assert_array(pilot_list).is_empty()

# ============================================================================
# SIGNAL TESTS
# ============================================================================

func test_pilot_created_signal() -> void:
	"""Test pilot created signal emission."""
	# Arrange
	var callsign: String = "SignalTest"
	test_pilots.append(callsign)
	var signal_monitor: SignalWatcher = watch_signals(pilot_manager)
	
	# Act
	pilot_manager.create_pilot(callsign)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("pilot_created")

func test_pilot_loaded_signal() -> void:
	"""Test pilot loaded signal emission."""
	# Arrange
	var callsign: String = "LoadSignalTest"
	test_pilots.append(callsign)
	pilot_manager.create_pilot(callsign)
	var signal_monitor: SignalWatcher = watch_signals(pilot_manager)
	
	# Act
	pilot_manager.load_pilot(callsign)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("pilot_loaded")

func test_pilot_deleted_signal() -> void:
	"""Test pilot deleted signal emission."""
	# Arrange
	var callsign: String = "DeleteSignalTest"
	test_pilots.append(callsign)
	pilot_manager.create_pilot(callsign)
	var signal_monitor: SignalWatcher = watch_signals(pilot_manager)
	
	# Act
	pilot_manager.delete_pilot(callsign, true)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("pilot_deleted")

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

func test_pilot_creation_performance() -> void:
	"""Test that pilot creation is performant."""
	# Arrange
	var start_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Act - Create multiple pilots
	for i in range(10):
		var callsign: String = "PerfTest_%d" % i
		test_pilots.append(callsign)
		pilot_manager.create_pilot(callsign)
	
	var end_time: float = Time.get_time_dict_from_system()["unix"]
	var elapsed_time: float = (end_time - start_time) * 1000.0  # Convert to ms
	
	# Assert - Should complete quickly (under 1000ms for 10 pilots)
	assert_float(elapsed_time).is_less(1000.0)

func test_pilot_loading_performance() -> void:
	"""Test that pilot loading is performant."""
	# Arrange
	var callsigns: Array[String] = []
	for i in range(5):
		var callsign: String = "LoadPerfTest_%d" % i
		callsigns.append(callsign)
		test_pilots.append(callsign)
		pilot_manager.create_pilot(callsign)
	
	var start_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Act - Load pilots multiple times
	for i in range(20):
		var callsign: String = callsigns[i % callsigns.size()]
		pilot_manager.load_pilot(callsign)
	
	var end_time: float = Time.get_time_dict_from_system()["unix"]
	var elapsed_time: float = (end_time - start_time) * 1000.0  # Convert to ms
	
	# Assert - Should complete quickly (under 500ms for 20 loads with caching)
	assert_float(elapsed_time).is_less(500.0)