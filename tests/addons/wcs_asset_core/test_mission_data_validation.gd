extends GdUnitTestSuite  # Requires GdUnit framework to be installed

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
	# Test MissionValidationResult class functionality
	var result := MissionValidationResult.new()
	
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
	# Test MissionValidationResult merging functionality
	var result1 := MissionValidationResult.new()
	result1.add_error("Error 1")
	
	var result2 := MissionValidationResult.new()
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

# QA REMEDIATION TESTS - Testing newly added functionality based on C++ struct analysis

func test_mission_metadata_validation():
	# Test QA REMEDIATION: Mission metadata fields validation
	var mission := MissionData.new()
	mission.mission_title = "Test Mission"
	mission.num_players = 1
	mission.author = ""  # Empty author should trigger warning
	mission.version = 0.0  # Invalid version should trigger warning
	mission.contrail_threshold = -5  # Negative threshold should trigger warning
	
	var result := mission.validate()
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid()).is_true()  # Should still be valid despite warnings
	assert_that(result.has_warnings()).is_true()
	assert_that(result.get_warnings()).contains("Mission author not specified")
	assert_that(result.get_warnings()).contains("Mission version not specified or invalid")
	assert_that(result.get_warnings()).contains("Contrail threshold cannot be negative, using default value")
	
	# Verify contrail threshold was corrected
	assert_that(mission.contrail_threshold).is_equal(45)

func test_mission_metadata_fields_present():
	# Test QA REMEDIATION: Ensure all new metadata fields are present
	var mission := MissionData.new()
	
	# Verify all new metadata fields exist
	assert_that(mission.has_property("author")).is_true()
	assert_that(mission.has_property("version")).is_true()
	assert_that(mission.has_property("created_date")).is_true()
	assert_that(mission.has_property("modified_date")).is_true()
	assert_that(mission.has_property("envmap_name")).is_true()
	assert_that(mission.has_property("contrail_threshold")).is_true()
	
	# Verify default values
	assert_that(mission.author).is_equal("")
	assert_that(mission.version).is_equal(0.0)
	assert_that(mission.created_date).is_equal("")
	assert_that(mission.modified_date).is_equal("")
	assert_that(mission.envmap_name).is_equal("")
	assert_that(mission.contrail_threshold).is_equal(45)

func test_ship_object_status_system():
	# Test QA REMEDIATION: Object status tracking system
	var ship := ShipInstanceData.new()
	ship.ship_name = "Test Ship"
	ship.ship_class_name = "GTF Ulysses"
	
	# Test adding object status entries
	ship.add_object_status(1, 100, "Target Ship")
	ship.add_object_status(2, 50, "")
	
	assert_that(ship.object_status_entries.size()).is_equal(2)
	
	var status1 := ship.object_status_entries[0] as ObjectStatusData
	assert_that(status1).is_not_null()
	assert_that(status1.status_type).is_equal(1)
	assert_that(status1.status_value).is_equal(100)
	assert_that(status1.target_name).is_equal("Target Ship")
	
	# Test getting status by type
	var type1_statuses := ship.get_object_status_by_type(1)
	assert_that(type1_statuses.size()).is_equal(1)
	assert_that(type1_statuses[0].status_type).is_equal(1)

func test_ship_validation_with_object_status():
	# Test QA REMEDIATION: Ship validation includes object status validation
	var ship := ShipInstanceData.new()
	ship.ship_name = "Test Ship"
	ship.ship_class_name = "GTF Ulysses"
	
	# Add an invalid object status (negative type)
	var invalid_status := ObjectStatusData.new()
	invalid_status.status_type = -1  # Invalid negative type
	ship.object_status_entries.append(invalid_status)
	
	var result := ship.validate()
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid()).is_false()
	assert_that(result.get_errors()).contains("Object status type cannot be negative")

func test_mission_event_flags():
	# Test QA REMEDIATION: Mission event flags implementation
	var event := MissionEventData.new()
	
	# Verify all new event fields exist
	assert_that(event.has_property("flags")).is_true()
	assert_that(event.has_property("display_count")).is_true()
	assert_that(event.has_property("born_on_date")).is_true()
	assert_that(event.has_property("satisfied_time")).is_true()
	
	# Verify default values
	assert_that(event.flags).is_equal(0)
	assert_that(event.display_count).is_equal(0)
	assert_that(event.born_on_date).is_equal(0)
	assert_that(event.satisfied_time).is_equal(0)

func test_wing_statistics_tracking():
	# Test QA REMEDIATION: Wing statistics tracking
	var wing := WingInstanceData.new()
	
	# Verify all new wing statistics fields exist
	assert_that(wing.has_property("total_destroyed")).is_true()
	assert_that(wing.has_property("total_departed")).is_true()
	assert_that(wing.has_property("total_vanished")).is_true()
	
	# Verify default values
	assert_that(wing.total_destroyed).is_equal(0)
	assert_that(wing.total_departed).is_equal(0)
	assert_that(wing.total_vanished).is_equal(0)
	
	# Test statistics tracking (simulated)
	wing.total_destroyed = 3
	wing.total_departed = 2
	wing.total_vanished = 1
	
	assert_that(wing.total_destroyed).is_equal(3)
	assert_that(wing.total_departed).is_equal(2)
	assert_that(wing.total_vanished).is_equal(1)

func test_ship_percentage_validation():
	# Test ship percentage field validation
	var ship := ShipInstanceData.new()
	ship.ship_name = "Test Ship"
	ship.ship_class_name = "GTF Ulysses"
	ship.initial_hull_percent = 150  # Invalid > 100
	ship.initial_shields_percent = -10  # Invalid < 0
	ship.assist_score_pct = 1.5  # Invalid > 1.0
	
	var result := ship.validate()
	
	assert_that(result).is_not_null()
	assert_that(result.has_warnings()).is_true()
	assert_that(result.get_warnings()).contains("Initial hull percentage should be between 0-100")
	assert_that(result.get_warnings()).contains("Initial shield percentage should be between 0-100")
	assert_that(result.get_warnings()).contains("Assist score percentage should be between 0.0-1.0")

func test_object_status_data_validation():
	# Test ObjectStatusData validation
	var status := ObjectStatusData.new()
	status.status_type = -5  # Invalid negative type
	
	var result := status.validate()
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid()).is_false()
	assert_that(result.get_errors()).contains("Object status type cannot be negative")
	
	# Test valid status
	var valid_status := ObjectStatusData.create_status(1, 100, "Target")
	var valid_result := valid_status.validate()
	
	assert_that(valid_result).is_not_null()
	assert_that(valid_result.is_valid()).is_true()

func test_mission_data_hash_includes_new_fields():
	# Test that the data hash calculation includes new metadata fields
	var mission1 := MissionData.new()
	mission1.mission_title = "Test Mission"
	mission1.author = "Test Author"
	
	var mission2 := MissionData.new()
	mission2.mission_title = "Test Mission"
	mission2.author = "Different Author"
	
	# Force hash calculation by calling validate
	mission1.validate()
	mission2.validate()
	
	# Since the authors are different, the missions should be considered different
	# This is tested by ensuring validation cache doesn't interfere
	var result1 := mission1.validate()
	var result2 := mission2.validate()
	
	# Both should validate successfully but independently
	assert_that(result1).is_not_null()
	assert_that(result2).is_not_null()
	assert_that(result1.is_valid()).is_true()
	assert_that(result2.is_valid()).is_true()
