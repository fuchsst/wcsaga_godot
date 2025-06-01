extends GdUnitTestSuite

## Unit tests for LoadoutManager
## Tests weapon loadout validation, persistence, and optimization.

var loadout_manager: LoadoutManager
var test_ship_data: ShipData
var test_mission_data: MissionData
var test_loadout: Dictionary

func before_test() -> void:
	"""Setup test environment before each test."""
	loadout_manager = LoadoutManager.create_loadout_manager()
	
	# Create test ship data
	test_ship_data = ShipData.new()
	test_ship_data.ship_name = "GTF Ulysses"
	test_ship_data.short_name = "Ulysses"
	
	# Create test mission data
	test_mission_data = MissionData.new()
	test_mission_data.mission_title = "Test Mission"
	
	# Create test loadout
	test_loadout = {
		"primary_weapons": ["Subach HL-7", "Prometheus R"],
		"secondary_weapons": ["MX-50", "Harpoon"]
	}

func after_test() -> void:
	"""Cleanup after each test."""
	if loadout_manager:
		loadout_manager.queue_free()

func test_create_loadout_manager() -> void:
	"""Test loadout manager creation."""
	var manager: LoadoutManager = LoadoutManager.create_loadout_manager()
	assert_that(manager).is_not_null()
	assert_that(manager.name).is_equal("LoadoutManager")
	manager.queue_free()

func test_validate_loadout_valid() -> void:
	"""Test validation of valid loadout."""
	var result: Dictionary = loadout_manager.validate_loadout(test_ship_data, test_loadout)
	
	assert_that(result).is_not_empty()
	assert_that(result.has("is_valid")).is_true()
	assert_that(result.has("errors")).is_true()
	assert_that(result.has("warnings")).is_true()
	assert_that(result.has("performance_score")).is_true()
	assert_that(result.has("recommendations")).is_true()

func test_validate_loadout_null_ship() -> void:
	"""Test validation with null ship data."""
	var result: Dictionary = loadout_manager.validate_loadout(null, test_loadout)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).is_not_empty()
	assert_that(result.errors[0]).contains("Ship data is required")

func test_validate_loadout_empty_loadout() -> void:
	"""Test validation with empty loadout."""
	var result: Dictionary = loadout_manager.validate_loadout(test_ship_data, {})
	
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).is_not_empty()
	assert_that(result.errors[0]).contains("Loadout cannot be empty")

func test_save_pilot_loadout_valid() -> void:
	"""Test saving pilot loadout with valid data."""
	loadout_manager.enable_persistence = true
	
	var result: bool = loadout_manager.save_pilot_loadout("test_pilot", "GTF Ulysses", test_loadout)
	assert_that(result).is_true()

func test_save_pilot_loadout_persistence_disabled() -> void:
	"""Test saving pilot loadout with persistence disabled."""
	loadout_manager.enable_persistence = false
	
	var result: bool = loadout_manager.save_pilot_loadout("test_pilot", "GTF Ulysses", test_loadout)
	assert_that(result).is_false()

func test_save_pilot_loadout_empty_pilot_id() -> void:
	"""Test saving loadout with empty pilot ID."""
	var result: bool = loadout_manager.save_pilot_loadout("", "GTF Ulysses", test_loadout)
	assert_that(result).is_false()

func test_save_pilot_loadout_empty_ship_class() -> void:
	"""Test saving loadout with empty ship class."""
	var result: bool = loadout_manager.save_pilot_loadout("test_pilot", "", test_loadout)
	assert_that(result).is_false()

func test_load_pilot_loadout_existing() -> void:
	"""Test loading existing pilot loadout."""
	loadout_manager.enable_persistence = true
	
	# Save first
	loadout_manager.save_pilot_loadout("test_pilot", "GTF Ulysses", test_loadout)
	
	# Then load
	var loaded_loadout: Dictionary = loadout_manager.load_pilot_loadout("test_pilot", "GTF Ulysses")
	assert_that(loaded_loadout).is_equal(test_loadout)

func test_load_pilot_loadout_nonexistent() -> void:
	"""Test loading non-existent pilot loadout."""
	var loaded_loadout: Dictionary = loadout_manager.load_pilot_loadout("nonexistent_pilot", "GTF Ulysses")
	assert_that(loaded_loadout).is_empty()

func test_get_pilot_preferences_default() -> void:
	"""Test getting default pilot preferences."""
	var preferences: Dictionary = loadout_manager.get_pilot_preferences("new_pilot")
	
	assert_that(preferences).is_not_empty()
	assert_that(preferences.has("preferred_primary_weapons")).is_true()
	assert_that(preferences.has("preferred_secondary_weapons")).is_true()
	assert_that(preferences.has("weapon_experience")).is_true()
	assert_that(preferences.has("favorite_loadouts")).is_true()

func test_set_pilot_preferences() -> void:
	"""Test setting pilot preferences."""
	var preferences: Dictionary = {
		"preferred_primary_weapons": ["Subach HL-7"],
		"preferred_secondary_weapons": ["MX-50"],
		"weapon_experience": {"Subach HL-7": 100},
		"favorite_loadouts": {}
	}
	
	loadout_manager.set_pilot_preferences("test_pilot", preferences)
	var retrieved_preferences: Dictionary = loadout_manager.get_pilot_preferences("test_pilot")
	
	assert_that(retrieved_preferences).is_equal(preferences)

func test_create_balanced_loadout() -> void:
	"""Test creation of balanced loadout."""
	var loadout: Dictionary = loadout_manager.create_balanced_loadout(test_ship_data, "general")
	
	assert_that(loadout).is_not_empty()
	assert_that(loadout.has("primary_weapons")).is_true()
	assert_that(loadout.has("secondary_weapons")).is_true()

func test_create_balanced_loadout_mission_specific() -> void:
	"""Test creation of mission-specific balanced loadout."""
	var assault_loadout: Dictionary = loadout_manager.create_balanced_loadout(test_ship_data, "anti_capital")
	var fighter_loadout: Dictionary = loadout_manager.create_balanced_loadout(test_ship_data, "anti_fighter")
	
	assert_that(assault_loadout).is_not_empty()
	assert_that(fighter_loadout).is_not_empty()
	
	# Loadouts might be different based on mission type
	# This depends on implementation specifics

func test_optimize_loadout_for_mission() -> void:
	"""Test loadout optimization for mission."""
	var optimized_loadout: Dictionary = loadout_manager.optimize_loadout_for_mission(test_ship_data, test_loadout, test_mission_data)
	
	assert_that(optimized_loadout).is_not_empty()
	assert_that(optimized_loadout.has("primary_weapons")).is_true()
	assert_that(optimized_loadout.has("secondary_weapons")).is_true()

func test_get_weapon_compatibility() -> void:
	"""Test weapon compatibility information."""
	var compatibility: Dictionary = loadout_manager.get_weapon_compatibility(test_ship_data)
	
	assert_that(compatibility).is_not_empty()
	assert_that(compatibility.has("primary_banks")).is_true()
	assert_that(compatibility.has("secondary_banks")).is_true()

func test_calculate_loadout_cost() -> void:
	"""Test loadout cost calculation."""
	var cost: Dictionary = loadout_manager.calculate_loadout_cost(test_loadout)
	
	assert_that(cost).is_not_empty()
	assert_that(cost.has("credits")).is_true()
	assert_that(cost.has("research_points")).is_true()
	assert_that(cost.has("maintenance")).is_true()
	assert_that(cost.has("ammunition")).is_true()
	
	assert_that(cost.credits).is_greater_equal(0)
	assert_that(cost.research_points).is_greater_equal(0)
	assert_that(cost.maintenance).is_greater_equal(0)
	assert_that(cost.ammunition).is_greater_equal(0)

func test_validate_primary_weapons() -> void:
	"""Test primary weapon validation."""
	var result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	result = loadout_manager._validate_primary_weapons(test_ship_data, test_loadout, result)
	
	# Should have validation results
	assert_that(result.has("errors")).is_true()
	assert_that(result.has("warnings")).is_true()

func test_validate_secondary_weapons() -> void:
	"""Test secondary weapon validation."""
	var result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	result = loadout_manager._validate_secondary_weapons(test_ship_data, test_loadout, result)
	
	# Should have validation results
	assert_that(result.has("errors")).is_true()
	assert_that(result.has("warnings")).is_true()

func test_validate_mission_constraints() -> void:
	"""Test mission constraint validation."""
	var result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	result = loadout_manager._validate_mission_constraints(test_ship_data, test_loadout, test_mission_data, result)
	
	# Should have validation results
	assert_that(result.has("errors")).is_true()
	assert_that(result.has("warnings")).is_true()

func test_weapon_compatibility_checking() -> void:
	"""Test weapon compatibility checking."""
	var weapon_data: WeaponData = WeaponData.new()
	weapon_data.weapon_name = "Subach HL-7"
	
	var is_compatible: bool = loadout_manager._is_weapon_compatible_with_bank(test_ship_data, weapon_data, 0, true)
	assert_that(is_compatible).is_true()  # Should default to true with basic implementation

func test_weapon_type_detection() -> void:
	"""Test weapon type detection."""
	var primary_weapon: WeaponData = WeaponData.new()
	primary_weapon.subtype = 0
	
	var secondary_weapon: WeaponData = WeaponData.new()
	secondary_weapon.subtype = 1
	
	assert_that(loadout_manager._is_primary_weapon(primary_weapon)).is_true()
	assert_that(loadout_manager._is_secondary_weapon(secondary_weapon)).is_true()
	assert_that(loadout_manager._is_primary_weapon(secondary_weapon)).is_false()
	assert_that(loadout_manager._is_secondary_weapon(primary_weapon)).is_false()

func test_performance_score_calculation() -> void:
	"""Test loadout performance score calculation."""
	var score: float = loadout_manager._calculate_loadout_performance(test_ship_data, test_loadout)
	
	assert_that(score).is_greater_equal(0.0)
	assert_that(score).is_less_equal(100.0)

func test_weapon_score_calculation() -> void:
	"""Test individual weapon score calculation."""
	var score: float = loadout_manager._calculate_weapon_score("Subach HL-7")
	
	assert_that(score).is_greater_equal(0.0)
	assert_that(score).is_less_equal(100.0)

func test_mission_threat_analysis() -> void:
	"""Test mission threat analysis."""
	# Add enemy ships to mission
	var enemy_ship: ShipInstanceData = ShipInstanceData.new()
	enemy_ship.ship_class_name = "SF Dragon"
	enemy_ship.team = 1  # Enemy team
	test_mission_data.ships.append(enemy_ship)
	
	var threats: Dictionary = loadout_manager._analyze_mission_threats(test_mission_data)
	
	assert_that(threats).is_not_empty()
	assert_that(threats.has("fighters")).is_true()
	assert_that(threats.has("bombers")).is_true()
	assert_that(threats.has("capital_ships")).is_true()
	assert_that(threats.has("unknown")).is_true()

func test_ship_threat_classification() -> void:
	"""Test ship threat classification."""
	assert_that(loadout_manager._classify_ship_threat("GTF Ulysses")).is_equal("fighters")
	assert_that(loadout_manager._classify_ship_threat("GTB Ursa")).is_equal("bombers")
	assert_that(loadout_manager._classify_ship_threat("GTC Leviathan")).is_equal("capital_ships")
	assert_that(loadout_manager._classify_ship_threat("Unknown Ship")).is_equal("unknown")

func test_mission_type_determination() -> void:
	"""Test mission type determination."""
	# Add capital ship enemy
	var capital_ship: ShipInstanceData = ShipInstanceData.new()
	capital_ship.ship_class_name = "SC Rakshasa"
	capital_ship.team = 1
	test_mission_data.ships.append(capital_ship)
	
	var mission_type: String = loadout_manager._determine_mission_type(test_mission_data)
	assert_that(mission_type).is_equal("anti_capital")

func test_weapon_capability_detection() -> void:
	"""Test weapon capability detection."""
	var loadout_with_anti_capital: Dictionary = {
		"secondary_weapons": ["Tornado"]
	}
	
	var loadout_with_anti_fighter: Dictionary = {
		"primary_weapons": ["Subach HL-7"]
	}
	
	var loadout_with_assault: Dictionary = {
		"primary_weapons": ["Prometheus R"]
	}
	
	assert_that(loadout_manager._has_anti_capital_weapons(loadout_with_anti_capital)).is_true()
	assert_that(loadout_manager._has_anti_fighter_weapons(loadout_with_anti_fighter)).is_true()
	assert_that(loadout_manager._has_assault_weapons(loadout_with_assault)).is_true()

func test_weapon_synergy_detection() -> void:
	"""Test weapon synergy detection."""
	var synergistic_loadout: Dictionary = {
		"primary_weapons": ["Subach HL-7", "Prometheus R"],
		"secondary_weapons": ["MX-50"]
	}
	
	var non_synergistic_loadout: Dictionary = {
		"primary_weapons": ["Subach HL-7"],
		"secondary_weapons": []
	}
	
	assert_that(loadout_manager._has_weapon_synergy(synergistic_loadout)).is_true()
	assert_that(loadout_manager._has_weapon_synergy(non_synergistic_loadout)).is_false()

func test_balanced_loadout_detection() -> void:
	"""Test balanced loadout detection."""
	var balanced_loadout: Dictionary = {
		"primary_weapons": ["Subach HL-7"],
		"secondary_weapons": ["MX-50"]
	}
	
	var unbalanced_loadout: Dictionary = {
		"primary_weapons": ["Subach HL-7"],
		"secondary_weapons": []
	}
	
	assert_that(loadout_manager._is_loadout_balanced(balanced_loadout)).is_true()
	assert_that(loadout_manager._is_loadout_balanced(unbalanced_loadout)).is_false()

func test_signal_emission_loadout_validation_completed() -> void:
	"""Test that loadout_validation_completed signal is emitted."""
	var signal_monitor: GdUnitSignalAwaiter = await_signal(loadout_manager.loadout_validation_completed, 1000)
	
	loadout_manager.validate_loadout(test_ship_data, test_loadout)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_signal_emission_loadout_saved() -> void:
	"""Test that loadout_saved signal is emitted."""
	loadout_manager.enable_persistence = true
	var signal_monitor: GdUnitSignalAwaiter = await_signal(loadout_manager.loadout_saved, 1000)
	
	loadout_manager.save_pilot_loadout("test_pilot", "GTF Ulysses", test_loadout)
	
	await signal_monitor.wait_until(500)
	assert_that(signal_monitor.is_emitted()).is_true()

func test_configuration_flags() -> void:
	"""Test configuration flag behavior."""
	# Test persistence toggle
	loadout_manager.enable_persistence = false
	var result: bool = loadout_manager.save_pilot_loadout("test", "ship", {})
	assert_that(result).is_false()
	
	# Test other configuration flags
	assert_that(loadout_manager.enable_validation).is_true()
	assert_that(loadout_manager.enable_auto_save).is_true()
	assert_that(loadout_manager.validation_timeout).is_equal(5.0)

func test_error_handling_corrupted_data() -> void:
	"""Test error handling with corrupted data."""
	var corrupted_loadout: Dictionary = {
		"invalid_key": "invalid_value"
	}
	
	var result: Dictionary = loadout_manager.validate_loadout(test_ship_data, corrupted_loadout)
	assert_that(result.is_valid).is_false()

func test_performance_large_loadout() -> void:
	"""Test performance with large loadout."""
	var start_time: int = Time.get_ticks_msec()
	
	# Create large loadout
	var large_loadout: Dictionary = {
		"primary_weapons": [],
		"secondary_weapons": []
	}
	
	for i in range(10):
		large_loadout.primary_weapons.append("Weapon" + str(i))
		large_loadout.secondary_weapons.append("Missile" + str(i))
	
	# Test validation performance
	var result: Dictionary = loadout_manager.validate_loadout(test_ship_data, large_loadout)
	
	var end_time: int = Time.get_ticks_msec()
	var elapsed: int = end_time - start_time
	
	# Should complete within reasonable time (less than 50ms)
	assert_that(elapsed).is_less(50)
	assert_that(result).is_not_empty()

func test_memory_usage_cleanup() -> void:
	"""Test memory usage and cleanup."""
	var initial_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy multiple managers
	for i in range(10):
		var manager: LoadoutManager = LoadoutManager.create_loadout_manager()
		manager.queue_free()
	
	# Force garbage collection
	await get_tree().process_frame
	
	var final_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Object count should not increase significantly
	var object_diff: int = final_objects - initial_objects
	assert_that(object_diff).is_less(5)  # Allow for some variance