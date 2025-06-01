extends GdUnitTestSuite

## Test suite for Mission File I/O System
## 
## Tests the complete .fs2 mission file reading and writing functionality
## to ensure compatibility with original WCS mission files while leveraging
## Godot's modern Resource system.

const TEMP_MISSION_FILE = "user://test_mission.fs2"
const SAMPLE_MISSION_CONTENT = """#Mission Info

$Version: 0.10
$Name: Test Mission
$Author: GFRED2 Test Suite
$Created: 01/01/2025 at 00:00:00
$Modified: 01/01/2025 at 00:00:00

$Notes:
This is a test mission for validating the Mission File I/O System.
It contains basic mission information and structure.
$end_multi_text

$Mission Desc:
A simple test mission to verify file I/O functionality.
$end_multi_text

$Game Type: single
$Flags: 
$Num Players: 1
$Num Respawns: 0

#End
"""

func test_mission_file_io_class_exists():
	# Verify MissionFileIO class is available
	assert_not_null(MissionFileIO, "MissionFileIO class should exist")

func test_load_mission_with_nonexistent_file():
	# Test loading a file that doesn't exist
	var mission := MissionFileIO.load_mission("user://nonexistent.fs2")
	assert_null(mission, "Loading nonexistent file should return null")

func test_load_mission_with_invalid_content():
	# Create a file with invalid content
	var invalid_content := "This is not a valid mission file"
	var file := FileAccess.open(TEMP_MISSION_FILE, FileAccess.WRITE)
	file.store_string(invalid_content)
	file.close()
	
	var mission := MissionFileIO.load_mission(TEMP_MISSION_FILE)
	assert_null(mission, "Loading invalid mission file should return null")

func test_load_valid_mission_file():
	# Create a valid mission file
	var file := FileAccess.open(TEMP_MISSION_FILE, FileAccess.WRITE)
	file.store_string(SAMPLE_MISSION_CONTENT)
	file.close()
	
	# Load the mission
	var mission := MissionFileIO.load_mission(TEMP_MISSION_FILE)
	assert_not_null(mission, "Loading valid mission file should succeed")
	assert_that(mission).is_instance_of(MissionData)

func test_mission_info_parsing():
	# Create a valid mission file
	var file := FileAccess.open(TEMP_MISSION_FILE, FileAccess.WRITE)
	file.store_string(SAMPLE_MISSION_CONTENT)
	file.close()
	
	# Load and verify mission info
	var mission := MissionFileIO.load_mission(TEMP_MISSION_FILE)
	assert_not_null(mission, "Mission should load successfully")
	
	assert_str(mission.mission_title).is_equal("Test Mission")
	assert_str(mission.author).is_equal("GFRED2 Test Suite")
	assert_float(mission.version).is_equal_approx(0.10, 0.001)
	assert_str(mission.created_date).is_equal("01/01/2025 at 00:00:00")
	assert_str(mission.modified_date).is_equal("01/01/2025 at 00:00:00")
	assert_int(mission.num_players).is_equal(1)
	assert_int(mission.num_respawns).is_equal(0)
	
	# Check multiline fields
	assert_bool(mission.mission_notes.contains("test mission")).is_true()
	assert_bool(mission.mission_desc.contains("simple test mission")).is_true()

func test_game_type_parsing():
	# Test different game types
	var test_cases := [
		{"input": "single", "expected": MissionFileIO.MISSION_TYPE_SINGLE},
		{"input": "multi", "expected": MissionFileIO.MISSION_TYPE_MULTI},
		{"input": "training", "expected": MissionFileIO.MISSION_TYPE_TRAINING},
		{"input": "single, multi", "expected": MissionFileIO.MISSION_TYPE_SINGLE | MissionFileIO.MISSION_TYPE_MULTI},
		{"input": "coop", "expected": MissionFileIO.MISSION_TYPE_MULTI_COOP},
		{"input": "teams", "expected": MissionFileIO.MISSION_TYPE_MULTI_TEAMS},
		{"input": "dogfight", "expected": MissionFileIO.MISSION_TYPE_MULTI_DOGFIGHT}
	]
	
	for test_case in test_cases:
		var mission_content := SAMPLE_MISSION_CONTENT.replace("$Game Type: single", "$Game Type: " + test_case.input)
		
		var file := FileAccess.open(TEMP_MISSION_FILE, FileAccess.WRITE)
		file.store_string(mission_content)
		file.close()
		
		var mission := MissionFileIO.load_mission(TEMP_MISSION_FILE)
		assert_not_null(mission, "Mission should load for game type: " + test_case.input)
		assert_int(mission.game_type).is_equal(test_case.expected)

func test_mission_flags_parsing():
	# Test mission flags parsing
	var flags_content := SAMPLE_MISSION_CONTENT.replace("$Flags: ", "$Flags: subspace, no promotion, full nebula")
	
	var file := FileAccess.open(TEMP_MISSION_FILE, FileAccess.WRITE)
	file.store_string(flags_content)
	file.close()
	
	var mission := MissionFileIO.load_mission(TEMP_MISSION_FILE)
	assert_not_null(mission, "Mission should load with flags")
	
	var expected_flags := MissionFileIO.MISSION_FLAG_SUBSPACE | MissionFileIO.MISSION_FLAG_NO_PROMOTION | MissionFileIO.MISSION_FLAG_FULLNEB
	assert_int(mission.flags).is_equal(expected_flags)

func test_save_mission_basic():
	# Create a simple mission
	var mission := MissionData.create_empty_mission()
	mission.mission_title = "Test Save Mission"
	mission.author = "Test Author"
	mission.version = 0.10
	mission.num_players = 2
	mission.game_type = MissionFileIO.MISSION_TYPE_SINGLE
	
	# Save the mission
	var result := MissionFileIO.save_mission(mission, TEMP_MISSION_FILE)
	assert_int(result).is_equal(OK)
	
	# Verify file was created
	assert_bool(FileAccess.file_exists(TEMP_MISSION_FILE)).is_true()

func test_save_and_load_roundtrip():
	# Create a mission with various properties
	var original_mission := MissionData.create_empty_mission()
	original_mission.mission_title = "Roundtrip Test Mission"
	original_mission.author = "Test Suite"
	original_mission.version = 0.10
	original_mission.mission_notes = "Test notes\nMultiple lines"
	original_mission.mission_desc = "Test description\nWith details"
	original_mission.num_players = 4
	original_mission.num_respawns = 3
	original_mission.game_type = MissionFileIO.MISSION_TYPE_MULTI_COOP
	original_mission.flags = MissionFileIO.MISSION_FLAG_FULLNEB | MissionFileIO.MISSION_FLAG_NO_PROMOTION
	original_mission.red_alert = true
	original_mission.scramble = false
	
	# Save the mission
	var save_result := MissionFileIO.save_mission(original_mission, TEMP_MISSION_FILE)
	assert_int(save_result).is_equal(OK)
	
	# Load the mission back
	var loaded_mission := MissionFileIO.load_mission(TEMP_MISSION_FILE)
	assert_not_null(loaded_mission, "Mission should load after saving")
	
	# Compare all properties
	assert_str(loaded_mission.mission_title).is_equal(original_mission.mission_title)
	assert_str(loaded_mission.author).is_equal(original_mission.author)
	assert_float(loaded_mission.version).is_equal_approx(original_mission.version, 0.001)
	assert_str(loaded_mission.mission_notes).is_equal(original_mission.mission_notes)
	assert_str(loaded_mission.mission_desc).is_equal(original_mission.mission_desc)
	assert_int(loaded_mission.num_players).is_equal(original_mission.num_players)
	assert_int(loaded_mission.num_respawns).is_equal(original_mission.num_respawns)
	assert_int(loaded_mission.game_type).is_equal(original_mission.game_type)
	assert_int(loaded_mission.flags).is_equal(original_mission.flags)
	assert_bool(loaded_mission.red_alert).is_equal(original_mission.red_alert)
	assert_bool(loaded_mission.scramble).is_equal(original_mission.scramble)

func test_validate_mission_file_with_valid_file():
	# Create a valid mission file
	var file := FileAccess.open(TEMP_MISSION_FILE, FileAccess.WRITE)
	file.store_string(SAMPLE_MISSION_CONTENT)
	file.close()
	
	# Validate the file
	var result := MissionFileIO.validate_mission_file(TEMP_MISSION_FILE)
	assert_not_null(result, "Validation result should exist")
	assert_that(result).is_instance_of(ValidationResult)
	
	# Should be valid (no errors)
	assert_bool(result.is_valid()).is_true()

func test_validate_mission_file_with_nonexistent_file():
	# Validate nonexistent file
	var result := MissionFileIO.validate_mission_file("user://nonexistent.fs2")
	assert_not_null(result, "Validation result should exist")
	assert_bool(result.is_valid()).is_false()
	assert_int(result.get_error_count()).is_greater(0)

func test_validate_mission_file_with_invalid_extension():
	# Create file with wrong extension
	var wrong_file := "user://test.txt"
	var file := FileAccess.open(wrong_file, FileAccess.WRITE)
	file.store_string(SAMPLE_MISSION_CONTENT)
	file.close()
	
	var result := MissionFileIO.validate_mission_file(wrong_file)
	assert_not_null(result, "Validation result should exist")
	assert_bool(result.has_warnings()).is_true()

func test_mission_file_format_constants():
	# Verify format constants are correct
	assert_float(MissionFileIO.MISSION_VERSION).is_equal_approx(0.10, 0.001)
	assert_float(MissionFileIO.FRED_MISSION_VERSION).is_equal_approx(0.10, 0.001)
	assert_str(MissionFileIO.FS_MISSION_FILE_EXT).is_equal(".fs2")

func test_mission_type_flags():
	# Verify mission type flags are correct powers of 2
	assert_int(MissionFileIO.MISSION_TYPE_SINGLE).is_equal(1)
	assert_int(MissionFileIO.MISSION_TYPE_MULTI).is_equal(2)
	assert_int(MissionFileIO.MISSION_TYPE_TRAINING).is_equal(4)
	assert_int(MissionFileIO.MISSION_TYPE_MULTI_COOP).is_equal(8)
	assert_int(MissionFileIO.MISSION_TYPE_MULTI_TEAMS).is_equal(16)
	assert_int(MissionFileIO.MISSION_TYPE_MULTI_DOGFIGHT).is_equal(32)

func test_mission_flags():
	# Verify key mission flags are correct
	assert_int(MissionFileIO.MISSION_FLAG_SUBSPACE).is_equal(1)
	assert_int(MissionFileIO.MISSION_FLAG_NO_PROMOTION).is_equal(2)
	assert_int(MissionFileIO.MISSION_FLAG_FULLNEB).is_equal(4)
	assert_int(MissionFileIO.MISSION_FLAG_RED_ALERT).is_equal(65536)  # 1 << 16
	assert_int(MissionFileIO.MISSION_FLAG_SCRAMBLE).is_equal(131072)  # 1 << 17

func test_invalid_mission_save():
	# Try to save an invalid mission (null)
	var result := MissionFileIO.save_mission(null, TEMP_MISSION_FILE)
	assert_int(result).is_not_equal(OK)

func test_save_with_invalid_path():
	# Try to save to an invalid path
	var mission := MissionData.create_empty_mission()
	var result := MissionFileIO.save_mission(mission, "/invalid/path/mission.fs2")
	assert_int(result).is_not_equal(OK)

func test_multiline_content_parsing():
	# Test mission with complex multiline content
	var complex_content := """#Mission Info

$Version: 0.10
$Name: Complex Mission
$Author: Test

$Notes:
Line 1 of notes
Line 2 of notes
Line 3 with special characters: !@#$%^&*()
$end_multi_text

$Mission Desc:
This is a complex description.
It has multiple lines.
And various formatting.
$end_multi_text

$Game Type: single
$Flags: 

#End
"""
	
	var file := FileAccess.open(TEMP_MISSION_FILE, FileAccess.WRITE)
	file.store_string(complex_content)
	file.close()
	
	var mission := MissionFileIO.load_mission(TEMP_MISSION_FILE)
	assert_not_null(mission, "Complex mission should load")
	
	# Check multiline content
	assert_bool(mission.mission_notes.contains("Line 1 of notes")).is_true()
	assert_bool(mission.mission_notes.contains("Line 2 of notes")).is_true()
	assert_bool(mission.mission_notes.contains("special characters")).is_true()
	
	assert_bool(mission.mission_desc.contains("complex description")).is_true()
	assert_bool(mission.mission_desc.contains("multiple lines")).is_true()
	assert_bool(mission.mission_desc.contains("various formatting")).is_true()

func test_performance_large_mission():
	# Test performance with a mission containing many flags
	var all_flags := [
		"subspace", "no promotion", "full nebula", "no builtin msgs", "no traitor",
		"toggle ship trails", "support repairs hull", "beam free all", "no briefing",
		"toggle debriefing", "allow dock trees", "2d mission", "red alert", "scramble",
		"no builtin command", "player start ai", "all attack", "use ap cinematics", "deactivate ap"
	]
	
	var flags_content := SAMPLE_MISSION_CONTENT.replace("$Flags: ", "$Flags: " + ", ".join(all_flags))
	
	var file := FileAccess.open(TEMP_MISSION_FILE, FileAccess.WRITE)
	file.store_string(flags_content)
	file.close()
	
	# Time the loading operation
	var start_time := Time.get_ticks_msec()
	var mission := MissionFileIO.load_mission(TEMP_MISSION_FILE)
	var load_time := Time.get_ticks_msec() - start_time
	
	assert_not_null(mission, "Mission with many flags should load")
	assert_int(load_time).is_less(1000)  # Should load in under 1 second

# Cleanup function
func after_test():
	# Clean up temporary files
	if FileAccess.file_exists(TEMP_MISSION_FILE):
		DirAccess.open("user://").remove(TEMP_MISSION_FILE.get_file())