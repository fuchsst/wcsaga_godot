# extends GdUnitTestSuite  # Requires GdUnit framework to be installed

## Test suite for MissionData validation and functionality
## Tests STORY-005 acceptance criteria implementation

func test_empty_mission_creation():
	# Test AC-3: Resource Serialization - Basic creation
	var mission := MissionData.create_empty_mission()
	
	assert_that(mission).is_not_null()
	assert_that(mission.mission_title).is_equal("New Mission")
	assert_that(mission.num_players).is_equal(1)
	assert_that(mission.ships).is_empty()
	assert_that(mission.wings).is_empty()

func test_mission_validation_empty_title():
	# Test AC-4: Data Validation System
	var mission := MissionData.new()
	mission.mission_title = ""  # Invalid empty title
	mission.num_players = 1
	
	var result := mission.validate()
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid()).is_false()
	assert_that(result.get_errors()).contains("Mission title cannot be empty")

func test_mission_validation_invalid_players():
	# Test AC-4: Data Validation System - Invalid player count
	var mission := MissionData.new()
	mission.mission_title = "Test Mission"
	mission.num_players = 0  # Invalid player count
	
	var result := mission.validate()
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid()).is_false()
	assert_that(result.get_errors()).contains("Mission must have at least one player")

func test_mission_validation_too_many_players():
	# Test AC-4: Data Validation System - Warning for many players
	var mission := MissionData.new()
	mission.mission_title = "Test Mission"
	mission.num_players = 15  # Should trigger warning
	
	var result := mission.validate()
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid()).is_true()  # Should still be valid
	assert_that(result.has_warnings()).is_true()
	assert_that(result.get_warnings()).contains("Mission has more than 12 players - may cause performance issues")

func test_mission_statistics():
	# Test mission statistics functionality
	var mission := MissionData.create_empty_mission()
	
	# Add some mock data
	var ship := ShipInstanceData.new()
	ship.ship_name = "Test Ship"
	mission.ships.append(ship)
	
	var stats := mission.get_mission_statistics()
	
	assert_that(stats).is_not_null()
	assert_that(stats["total_ships"]).is_equal(1)
	assert_that(stats["total_wings"]).is_equal(0)
	assert_that(stats["total_events"]).is_equal(0)
	assert_that(stats["total_goals"]).is_equal(0)

func test_add_ship_with_auto_naming():
	# Test AC-1: Core Mission Data Structure - Object management
	var mission := MissionData.create_empty_mission()
	var ship := ShipInstanceData.new()
	# Don't set ship_name, should be auto-generated
	
	mission.add_ship(ship)
	
	assert_that(mission.ships.size()).is_equal(1)
	assert_that(ship.ship_name).is_not_empty()
	assert_that(ship.ship_name).contains("Ship")

func test_unique_ship_name_generation():
	# Test unique name generation
	var mission := MissionData.create_empty_mission()
	
	# Add first ship
	var ship1 := ShipInstanceData.new()
	mission.add_ship(ship1)
	
	# Add second ship
	var ship2 := ShipInstanceData.new()
	mission.add_ship(ship2)
	
	assert_that(ship1.ship_name).is_not_equal(ship2.ship_name)
	assert_that(mission.get_ship_by_name(ship1.ship_name)).is_equal(ship1)
	assert_that(mission.get_ship_by_name(ship2.ship_name)).is_equal(ship2)

func test_validation_result_functionality():
	# Test ValidationResult class functionality
	var result := ValidationResult.new()
	
	result.add_error("Test error")
	result.add_warning("Test warning")
	result.add_info("Test info")
	
	assert_that(result.is_valid()).is_false()
	assert_that(result.has_warnings()).is_true()
	assert_that(result.get_error_count()).is_equal(1)
	assert_that(result.get_warning_count()).is_equal(1)
	assert_that(result.get_info_count()).is_equal(1)
	
	var summary := result.get_summary()
	assert_that(summary).contains("1 errors")
	assert_that(summary).contains("1 warnings")
	assert_that(summary).contains("1 info")

func test_validation_result_merge():
	# Test ValidationResult merging functionality
	var result1 := ValidationResult.new()
	result1.add_error("Error 1")
	
	var result2 := ValidationResult.new()
	result2.add_error("Error 2")
	result2.add_warning("Warning 1")
	
	result1.merge(result2)
	
	assert_that(result1.get_error_count()).is_equal(2)
	assert_that(result1.get_warning_count()).is_equal(1)
	assert_that(result1.get_errors()).contains("Error 1")
	assert_that(result1.get_errors()).contains("Error 2")
	assert_that(result1.get_warnings()).contains("Warning 1")

func test_mission_data_change_signals():
	# Test AC-5: Signal-Based Change Notification
	var mission := MissionData.create_empty_mission()
	var signal_emitted := false
	var received_property := ""
	
	# Connect to data_changed signal
	mission.data_changed.connect(func(property: String, old_value: Variant, new_value: Variant):
		signal_emitted = true
		received_property = property
	)
	
	# Add a ship, which should emit signal
	var ship := ShipInstanceData.new()
	mission.add_ship(ship)
	
	# Wait a frame for signal processing
	await get_tree().process_frame
	
	assert_that(signal_emitted).is_true()
	assert_that(received_property).is_equal("ships")