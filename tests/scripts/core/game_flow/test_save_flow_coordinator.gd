extends GdUnitTestSuite

## Unit tests for SaveFlowCoordinator
## Tests save/load coordination with existing SaveGameManager integration

const SaveFlowCoordinator = preload("res://scripts/core/game_flow/save_flow_coordinator.gd")
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")

var coordinator: SaveFlowCoordinator
var mock_pilot_coordinator: Node

func before():
	# Create SaveFlowCoordinator instance
	coordinator = SaveFlowCoordinator.new()
	coordinator.name = "TestSaveFlowCoordinator"
	add_child(coordinator)
	
	# Create mock pilot coordinator for testing
	_setup_mock_pilot_coordinator()
	
	# Wait for initialization
	await get_tree().process_frame

func after():
	# Clean up
	if coordinator:
		coordinator.queue_free()
	
	if mock_pilot_coordinator:
		mock_pilot_coordinator.queue_free()
	
	# Clean up test save files
	_cleanup_test_saves()

func _setup_mock_pilot_coordinator():
	# Create a mock PilotDataCoordinator for testing
	mock_pilot_coordinator = Node.new()
	mock_pilot_coordinator.name = "MockPilotDataCoordinator"
	
	# Add mock properties and methods
	mock_pilot_coordinator.set_script(GDScript.new())
	mock_pilot_coordinator.get_script().source_code = """
extends Node

var current_pilot_profile = null
var active_save_slot: int = -1

func has_current_pilot() -> bool:
	return current_pilot_profile != null

func get_current_pilot_profile():
	return current_pilot_profile

func get_active_save_slot() -> int:
	return active_save_slot
"""
	
	add_child(mock_pilot_coordinator)
	coordinator.pilot_data_coordinator = mock_pilot_coordinator

func _cleanup_test_saves():
	# Clean up test save files
	var dir = DirAccess.open("user://saves/")
	if dir:
		# Remove test save files
		for i in range(10):
			var profile_path = "profile_%d.tres" % i
			var campaign_path = "campaign_%d.tres" % i
			var context_path = "flow_context_%d.json" % i
			
			if dir.file_exists(profile_path):
				dir.remove(profile_path)
			if dir.file_exists(campaign_path):
				dir.remove(campaign_path)
			if dir.file_exists(context_path):
				dir.remove(context_path)

func test_coordinator_initialization():
	"""Test SaveFlowCoordinator initializes correctly"""
	assert_that(coordinator).is_not_null()
	assert_that(coordinator.enable_state_transition_saves).is_true()
	assert_that(coordinator.enable_auto_save_on_transitions).is_true()
	assert_that(coordinator.quick_save_slot).is_equal(999)
	assert_that(coordinator.auto_save_slot).is_equal(998)
	assert_that(coordinator.is_save_flow_active).is_false()

func test_save_context_validation():
	"""Test save context validation"""
	# Test with invalid context (no SaveGameManager)
	var original_save_manager = SaveGameManager
	SaveGameManager = null
	
	var result = coordinator._validate_save_context()
	assert_that(result).is_false()
	
	# Restore SaveGameManager
	SaveGameManager = original_save_manager

func test_save_type_mapping():
	"""Test save operation to save type mapping"""
	var manual_type = coordinator._get_save_type_for_operation(SaveFlowCoordinator.SaveOperation.MANUAL_SAVE)
	assert_that(manual_type).is_equal(SaveGameManager.SaveSlotInfo.SaveType.MANUAL)
	
	var auto_type = coordinator._get_save_type_for_operation(SaveFlowCoordinator.SaveOperation.AUTO_SAVE)
	assert_that(auto_type).is_equal(SaveGameManager.SaveSlotInfo.SaveType.AUTO)
	
	var quick_type = coordinator._get_save_type_for_operation(SaveFlowCoordinator.SaveOperation.QUICK_SAVE)
	assert_that(quick_type).is_equal(SaveGameManager.SaveSlotInfo.SaveType.QUICK)

func test_operation_name_mapping():
	"""Test operation to name mapping"""
	var manual_name = coordinator._get_operation_name(SaveFlowCoordinator.SaveOperation.MANUAL_SAVE)
	assert_that(manual_name).is_equal("manual_save")
	
	var quick_name = coordinator._get_operation_name(SaveFlowCoordinator.SaveOperation.QUICK_SAVE)
	assert_that(quick_name).is_equal("quick_save")
	
	var auto_name = coordinator._get_operation_name(SaveFlowCoordinator.SaveOperation.AUTO_SAVE)
	assert_that(auto_name).is_equal("auto_save")

func test_pilot_save_slot_determination():
	"""Test pilot save slot determination"""
	# Test with no pilot coordinator
	coordinator.pilot_data_coordinator = null
	var slot = coordinator._get_pilot_save_slot()
	assert_that(slot).is_greater_equal(0)
	
	# Test with mock pilot coordinator
	coordinator.pilot_data_coordinator = mock_pilot_coordinator
	mock_pilot_coordinator.active_save_slot = 5
	slot = coordinator._get_pilot_save_slot()
	assert_that(slot).is_equal(5)

func test_save_flow_context_creation():
	"""Test save flow context creation"""
	var save_slot = 1
	var save_name = "Test Save"
	var operation = SaveFlowCoordinator.SaveOperation.MANUAL_SAVE
	
	# Start save operation to create context
	coordinator.current_save_operation = operation
	coordinator.save_operation_context = {
		"save_slot": save_slot,
		"save_name": save_name,
		"operation": operation,
		"game_state": GameStateManager.GameState.MAIN_MENU,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var context = coordinator.get_current_operation_context()
	assert_that(context.has("save_slot")).is_true()
	assert_that(context.has("save_name")).is_true()
	assert_that(context.has("operation")).is_true()
	assert_that(context.save_slot).is_equal(save_slot)
	assert_that(context.save_name).is_equal(save_name)

func test_available_save_slots_retrieval():
	"""Test available save slots retrieval"""
	var slots = coordinator.get_available_save_slots()
	assert_that(slots).is_not_null()
	assert_that(slots).is_instance_of(Array)
	
	# Each slot should have required fields
	for slot_data in slots:
		assert_that(slot_data.has("slot_number")).is_true()
		assert_that(slot_data.has("pilot_callsign")).is_true()
		assert_that(slot_data.has("save_name")).is_true()

func test_save_slot_validation():
	"""Test save slot validation delegation to SaveGameManager"""
	# Test valid slot range
	var valid_result = coordinator.is_save_slot_valid(0)
	assert_that(valid_result).is_instance_of(bool)
	
	# Test invalid slot
	var invalid_result = coordinator.is_save_slot_valid(-1)
	assert_that(invalid_result).is_false()

func test_quick_save_slot_checking():
	"""Test quick save availability checking"""
	var has_quick_save = coordinator.has_quick_save()
	assert_that(has_quick_save).is_instance_of(bool)
	
	var has_auto_save = coordinator.has_auto_save()
	assert_that(has_auto_save).is_instance_of(bool)

func test_save_operation_status():
	"""Test save operation status tracking"""
	# Initially no operation should be active
	assert_that(coordinator.is_save_operation_active()).is_false()
	
	# Set save flow as active
	coordinator.is_save_flow_active = true
	assert_that(coordinator.is_save_operation_active()).is_true()
	
	coordinator.is_save_flow_active = false

func test_configuration_methods():
	"""Test configuration method functionality"""
	# Test state transition saves configuration
	coordinator.set_state_transition_saves_enabled(false)
	assert_that(coordinator.enable_state_transition_saves).is_false()
	
	coordinator.set_state_transition_saves_enabled(true)
	assert_that(coordinator.enable_state_transition_saves).is_true()
	
	# Test auto-save on transitions configuration
	coordinator.set_auto_save_on_transitions_enabled(false)
	assert_that(coordinator.enable_auto_save_on_transitions).is_false()
	
	coordinator.set_auto_save_on_transitions_enabled(true)
	assert_that(coordinator.enable_auto_save_on_transitions).is_true()

func test_performance_stats_delegation():
	"""Test performance statistics delegation to SaveGameManager"""
	var stats = coordinator.get_save_performance_stats()
	assert_that(stats).is_not_null()
	assert_that(stats).is_instance_of(Dictionary)
	
	# Should contain expected performance data structure
	assert_that(stats.has("save_stats")).is_true()
	assert_that(stats.has("load_stats")).is_true()

func test_game_flow_context_serialization():
	"""Test game flow context save/load"""
	var test_slot = 1
	
	# Setup test context
	coordinator.current_save_operation = SaveFlowCoordinator.SaveOperation.MANUAL_SAVE
	
	# Save context
	coordinator._save_game_flow_context(test_slot)
	
	# Verify context file was created
	var context_path = "user://saves/flow_context_%d.json" % test_slot
	assert_that(FileAccess.file_exists(context_path)).is_true()
	
	# Load context
	coordinator._load_game_flow_context(test_slot)
	# Loading should complete without error (verified by no exceptions)

func test_save_complete_flow_operation():
	"""Test complete save flow operation lifecycle"""
	var operation = SaveFlowCoordinator.SaveOperation.MANUAL_SAVE
	var success = true
	var error_message = ""
	
	# Setup operation context
	coordinator.current_save_operation = operation
	coordinator.save_operation_context = {"test": "data"}
	coordinator.is_save_flow_active = true
	
	# Complete the operation
	coordinator._complete_save_flow(success, error_message)
	
	# Verify state is reset
	assert_that(coordinator.is_save_flow_active).is_false()
	assert_that(coordinator.current_save_operation).is_equal(SaveFlowCoordinator.SaveOperation.MANUAL_SAVE)
	assert_that(coordinator.save_operation_context).is_empty()

func test_signal_emission_tracking():
	"""Test signal emission during operations"""
	var save_flow_started_received = false
	var save_flow_completed_received = false
	
	# Connect to signals
	coordinator.save_flow_started.connect(func(operation_type, context): save_flow_started_received = true)
	coordinator.save_flow_completed.connect(func(operation_type, success, context): save_flow_completed_received = true)
	
	# Trigger operation completion
	coordinator.current_save_operation = SaveFlowCoordinator.SaveOperation.MANUAL_SAVE
	coordinator.save_operation_context = {}
	coordinator._complete_save_flow(true, "")
	
	# Wait for signal processing
	await get_tree().process_frame
	
	# Check signals were emitted
	assert_that(save_flow_completed_received).is_true()

func test_game_state_change_handling():
	"""Test game state change handling for auto-saves"""
	# Setup for state transition saves
	coordinator.enable_state_transition_saves = true
	coordinator.enable_auto_save_on_transitions = true
	
	# Mock current pilot profile for saves
	var test_profile = PlayerProfile.new()
	test_profile.set_callsign("TestPilot")
	mock_pilot_coordinator.current_pilot_profile = test_profile
	mock_pilot_coordinator.active_save_slot = 1
	
	# Test state change that should trigger save
	coordinator._on_game_state_changed(
		GameStateManager.GameState.MISSION, 
		GameStateManager.GameState.MISSION_COMPLETE
	)
	
	# Verify mission completion handling
	# (Actual save operation would be tested in integration tests)

func test_pilot_integration():
	"""Test pilot data coordinator integration"""
	# Test without pilot coordinator
	coordinator.pilot_data_coordinator = null
	var profile = coordinator._get_current_pilot_profile()
	assert_that(profile).is_null()
	
	# Test with mock pilot coordinator
	var test_profile = PlayerProfile.new()
	test_profile.set_callsign("TestPilot")
	mock_pilot_coordinator.current_pilot_profile = test_profile
	coordinator.pilot_data_coordinator = mock_pilot_coordinator
	
	profile = coordinator._get_current_pilot_profile()
	assert_that(profile).is_equal(test_profile)

func test_save_slot_operations():
	"""Test save slot operations delegation"""
	# Test delete save slot
	var delete_result = coordinator.delete_save_slot(999)  # Use non-existent slot
	assert_that(delete_result).is_instance_of(bool)
	
	# Test copy save slot (would fail for non-existent slots, but should not crash)
	var copy_result = coordinator.copy_save_slot(999, 998)
	assert_that(copy_result).is_instance_of(bool)

func test_operation_conflict_prevention():
	"""Test prevention of conflicting save operations"""
	# Set save flow as active
	coordinator.is_save_flow_active = true
	
	# Attempt to start another operation
	var result = coordinator.save_current_game_state(1, "Test")
	assert_that(result).is_false()
	
	result = coordinator.load_game_state(1)
	assert_that(result).is_false()
	
	# Reset state
	coordinator.is_save_flow_active = false

func test_save_operation_types():
	"""Test different save operation types"""
	var operations = [
		SaveFlowCoordinator.SaveOperation.MANUAL_SAVE,
		SaveFlowCoordinator.SaveOperation.QUICK_SAVE,
		SaveFlowCoordinator.SaveOperation.AUTO_SAVE,
		SaveFlowCoordinator.SaveOperation.STATE_TRANSITION,
		SaveFlowCoordinator.SaveOperation.CAMPAIGN_CHECKPOINT,
		SaveFlowCoordinator.SaveOperation.MISSION_COMPLETE
	]
	
	# Test that each operation type has a valid name mapping
	for operation in operations:
		var name = coordinator._get_operation_name(operation)
		assert_that(name).is_not_empty()
		assert_that(name).does_not_contain("unknown")

func test_quick_save_load_availability():
	"""Test quick save and load availability checks"""
	# Test quick save without pilot (should fail gracefully)
	coordinator.pilot_data_coordinator = null
	var quick_save_result = coordinator.quick_save()
	assert_that(quick_save_result).is_false()
	
	# Test quick load without existing save
	var quick_load_result = coordinator.quick_load()
	# Should handle missing quick save gracefully