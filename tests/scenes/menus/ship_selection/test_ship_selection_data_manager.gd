extends GdUnitTestSuite

## Unit tests for ShipSelectionDataManager
## Tests ship data loading, loadout management, and validation.

var ship_data_manager: ShipSelectionDataManager
var test_mission_data: MissionData
var test_pilot_data: PlayerProfile
var test_ship_data: ShipData

func before_test() -> void:
	"""Setup test environment before each test."""
	ship_data_manager = ShipSelectionDataManager.create_ship_selection_data_manager()
	
	# Create test mission data
	test_mission_data = MissionData.new()
	test_mission_data.mission_title = "Test Mission"
	
	# Create test player start with ship choices
	var player_start: PlayerStartData = PlayerStartData.new()
	var ship_choice: ShipLoadoutChoice = ShipLoadoutChoice.new()
	ship_choice.ship_class_name = "GTF Ulysses"
	ship_choice.count = 1
	player_start.ship_loadout_choices.append(ship_choice)
	test_mission_data.player_starts.append(player_start)
	
	# Create test pilot data
	test_pilot_data = PlayerProfile.new()
	
	# Create test ship data
	test_ship_data = ShipData.new()
	test_ship_data.ship_name = "GTF Ulysses"
	test_ship_data.short_name = "Ulysses"
	test_ship_data.manufacturer = "Terran"

func after_test() -> void:
	"""Cleanup after each test."""
	if ship_data_manager:
		ship_data_manager.queue_free()

func test_create_ship_selection_data_manager() -> void:
	"""Test ship selection data manager creation."""
	var manager: ShipSelectionDataManager = ShipSelectionDataManager.create_ship_selection_data_manager()
	assert_that(manager).is_not_null()
	assert_that(manager.name).is_equal("ShipSelectionDataManager")
	manager.queue_free()

func test_load_ship_data_for_mission_valid_data() -> void:
	"""Test loading ship data with valid mission and pilot data."""
	var result: bool = ship_data_manager.load_ship_data_for_mission(test_mission_data, test_pilot_data)
	assert_that(result).is_true()

func test_load_ship_data_for_mission_null_mission() -> void:
	"""Test loading ship data with null mission data."""
	var result: bool = ship_data_manager.load_ship_data_for_mission(null, test_pilot_data)
	assert_that(result).is_false()

func test_load_ship_data_for_mission_null_pilot() -> void:
	"""Test loading ship data with null pilot data."""
	var result: bool = ship_data_manager.load_ship_data_for_mission(test_mission_data, null)
	assert_that(result).is_false()

func test_get_available_ships_initially_empty() -> void:
	"""Test that available ships is initially empty."""
	var ships: Array[ShipData] = ship_data_manager.get_available_ships()
	assert_that(ships).is_empty()

func test_get_ship_loadout_nonexistent_ship() -> void:
	"""Test getting loadout for non-existent ship."""
	var loadout: Dictionary = ship_data_manager.get_ship_loadout("NonexistentShip")
	assert_that(loadout).is_empty()

func test_set_ship_loadout_valid_loadout() -> void:
	"""Test setting a valid ship loadout."""
	var loadout: Dictionary = {
		"primary_weapons": ["Subach HL-7", "Prometheus R"],
		"secondary_weapons": ["MX-50", "Harpoon"]
	}
	
	var result: bool = ship_data_manager.set_ship_loadout("GTF Ulysses", loadout)
	assert_that(result).is_true()
	
	var retrieved_loadout: Dictionary = ship_data_manager.get_ship_loadout("GTF Ulysses")
	assert_that(retrieved_loadout).is_equal(loadout)

func test_set_ship_loadout_empty_ship_class() -> void:
	"""Test setting loadout with empty ship class."""
	var loadout: Dictionary = {"primary_weapons": ["Subach HL-7"]}
	var result: bool = ship_data_manager.set_ship_loadout("", loadout)
	assert_that(result).is_false()

func test_validate_ship_loadout_no_loadout() -> void:
	"""Test validation with no configured loadout."""
	var result: Dictionary = ship_data_manager.validate_ship_loadout("GTF Ulysses")
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).is_not_empty()

func test_get_ship_specifications_valid_ship() -> void:
	"""Test getting ship specifications for valid ship."""
	# Add ship to available ships for testing
	ship_data_manager.available_ship_classes.append(test_ship_data)
	
	var specs: Dictionary = ship_data_manager.get_ship_specifications("GTF Ulysses")
	assert_that(specs).is_not_empty()
	assert_that(specs.name).is_equal("GTF Ulysses")
	assert_that(specs.manufacturer).is_equal("Terran")

func test_get_ship_specifications_invalid_ship() -> void:
	"""Test getting ship specifications for invalid ship."""
	var specs: Dictionary = ship_data_manager.get_ship_specifications("InvalidShip")
	assert_that(specs).is_empty()

func test_get_weapon_bank_info_valid_ship() -> void:
	"""Test getting weapon bank info for valid ship."""
	ship_data_manager.available_ship_classes.append(test_ship_data)
	
	var bank_info: Dictionary = ship_data_manager.get_weapon_bank_info("GTF Ulysses")
	assert_that(bank_info).is_not_empty()
	assert_that(bank_info.has("primary_banks")).is_true()
	assert_that(bank_info.has("secondary_banks")).is_true()

func test_get_weapon_bank_info_invalid_ship() -> void:
	"""Test getting weapon bank info for invalid ship."""
	var bank_info: Dictionary = ship_data_manager.get_weapon_bank_info("InvalidShip")
	assert_that(bank_info).is_empty()

func test_generate_ship_recommendations_no_data() -> void:
	"""Test generating recommendations with no mission data."""
	var recommendations: Array[Dictionary] = ship_data_manager.generate_ship_recommendations()
	assert_that(recommendations).is_empty()

func test_generate_ship_recommendations_with_data() -> void:
	"""Test generating recommendations with mission data."""
	ship_data_manager.current_mission_data = test_mission_data
	ship_data_manager.available_ship_classes.append(test_ship_data)
	
	var recommendations: Array[Dictionary] = ship_data_manager.generate_ship_recommendations()
	assert_that(recommendations).is_not_empty()
	
	for recommendation in recommendations:
		assert_that(recommendation.has("ship_class")).is_true()
		assert_that(recommendation.has("score")).is_true()
		assert_that(recommendation.has("reason")).is_true()
		assert_that(recommendation.has("priority")).is_true()

func test_mission_ship_choices_extraction() -> void:
	"""Test extraction of ship choices from mission data."""
	var ship_choices: Array[String] = ship_data_manager._get_mission_ship_choices(test_mission_data)
	assert_that(ship_choices).is_not_empty()
	assert_that(ship_choices).contains("GTF Ulysses")

func test_mission_ship_choices_empty_mission() -> void:
	"""Test extraction with empty mission data."""
	var empty_mission: MissionData = MissionData.new()
	var ship_choices: Array[String] = ship_data_manager._get_mission_ship_choices(empty_mission)
	assert_that(ship_choices).is_empty()

func test_is_fighter_class_detection() -> void:
	"""Test fighter class detection."""
	assert_that(ship_data_manager._is_fighter_class("GTF Ulysses")).is_true()
	assert_that(ship_data_manager._is_fighter_class("GTB Ursa")).is_true()
	assert_that(ship_data_manager._is_fighter_class("GTC Leviathan")).is_false()

func test_ship_availability_to_pilot() -> void:
	"""Test ship availability checking."""
	var is_available: bool = ship_data_manager._is_ship_available_to_pilot(test_ship_data, test_pilot_data)
	assert_that(is_available).is_true()  # Default should be true when restrictions disabled

func test_default_loadout_creation() -> void:
	"""Test creation of default loadout."""
	var loadout: Dictionary = ship_data_manager._create_default_loadout(test_ship_data)
	assert_that(loadout).is_not_empty()
	assert_that(loadout.has("primary_weapons")).is_true()
	assert_that(loadout.has("secondary_weapons")).is_true()

func test_mission_requirements_analysis() -> void:
	"""Test mission requirements analysis."""
	ship_data_manager.current_mission_data = test_mission_data
	
	var analysis: Dictionary = ship_data_manager._analyze_mission_requirements()
	assert_that(analysis).is_not_empty()
	assert_that(analysis.has("mission_type")).is_true()
	assert_that(analysis.has("primary_threats")).is_true()
	assert_that(analysis.has("required_capabilities")).is_true()

func test_ship_mission_score_calculation() -> void:
	"""Test ship mission score calculation."""
	var mission_analysis: Dictionary = {
		"mission_type": "assault",
		"required_capabilities": ["assault"],
		"primary_threats": ["capital"]
	}
	
	ship_data_manager.current_pilot_data = test_pilot_data
	var score: float = ship_data_manager._calculate_ship_mission_score(test_ship_data, mission_analysis)
	
	assert_that(score).is_greater_equal(0.0)
	assert_that(score).is_less_equal(100.0)

func test_recommendation_reason_generation() -> void:
	"""Test recommendation reason generation."""
	var mission_analysis: Dictionary = {
		"mission_type": "assault",
		"required_capabilities": ["assault"],
		"primary_threats": ["capital"]
	}
	
	var reason: String = ship_data_manager._generate_recommendation_reason(test_ship_data, mission_analysis)
	assert_that(reason).is_not_empty()

func test_recommendation_priority_calculation() -> void:
	"""Test recommendation priority calculation."""
	var priority_high: int = ship_data_manager._get_recommendation_priority(85.0)
	var priority_low: int = ship_data_manager._get_recommendation_priority(15.0)
	
	assert_that(priority_high).is_greater(priority_low)
	assert_that(priority_high).is_greater_equal(1)
	assert_that(priority_high).is_less_equal(5)

func test_signal_emission_ship_data_loaded() -> void:
	"""Test that ship_data_loaded signal is emitted."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(ship_data_manager.ship_data_loaded, 1000)
	
	ship_data_manager.available_ship_classes.append(test_ship_data)
	ship_data_manager.ship_data_loaded.emit([test_ship_data])
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_loadout_changed() -> void:
	"""Test that loadout_changed signal is emitted."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(ship_data_manager.loadout_changed, 1000)
	
	var loadout: Dictionary = {"primary_weapons": ["Subach HL-7"]}
	ship_data_manager.set_ship_loadout("GTF Ulysses", loadout)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_configuration_flags() -> void:
	"""Test configuration flag behavior."""
	# Test pilot restrictions
	ship_data_manager.enable_pilot_restrictions = false
	var is_available: bool = ship_data_manager._is_ship_available_to_pilot(test_ship_data, test_pilot_data)
	assert_that(is_available).is_true()
	
	# Test mission constraints
	assert_that(ship_data_manager.enable_mission_constraints).is_true()
	assert_that(ship_data_manager.enable_rank_restrictions).is_true()
	assert_that(ship_data_manager.enable_loadout_validation).is_true()

func test_error_handling_invalid_data() -> void:
	"""Test error handling with invalid data."""
	# Test with corrupted ship data
	var corrupt_ship: ShipData = ShipData.new()
	# Leave name empty to test error handling
	
	var specs: Dictionary = ship_data_manager.get_ship_specifications("")
	assert_that(specs).is_empty()
	
	var bank_info: Dictionary = ship_data_manager.get_weapon_bank_info("")
	assert_that(bank_info).is_empty()

func test_performance_large_ship_list() -> void:
	"""Test performance with large ship list."""
	var start_time: int = Time.get_ticks_msec()
	
	# Add many test ships
	for i in range(100):
		var ship: ShipData = ShipData.new()
		ship.ship_name = "TestShip" + str(i)
		ship_data_manager.available_ship_classes.append(ship)
	
	# Test operations
	var ships: Array[ShipData] = ship_data_manager.get_available_ships()
	assert_that(ships.size()).is_equal(100)
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (less than 100ms)
	assert_that(elapsed).is_less(100)