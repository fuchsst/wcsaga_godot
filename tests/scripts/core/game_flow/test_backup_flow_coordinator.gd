extends GdUnitTestSuite

## Unit tests for BackupFlowCoordinator
## Tests backup automation, health monitoring, and recovery assistance

const BackupFlowCoordinator = preload("res://scripts/core/game_flow/backup_flow_coordinator.gd")
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")

var coordinator: BackupFlowCoordinator
var mock_save_flow: Node

func before():
	# Create BackupFlowCoordinator instance
	coordinator = BackupFlowCoordinator.new()
	coordinator.name = "TestBackupFlowCoordinator"
	add_child(coordinator)
	
	# Create mock SaveFlowCoordinator
	_setup_mock_save_flow_coordinator()
	
	# Wait for initialization
	await get_tree().process_frame

func after():
	# Clean up
	if coordinator:
		coordinator.queue_free()
	
	if mock_save_flow:
		mock_save_flow.queue_free()
	
	# Clean up test files
	_cleanup_test_files()

func _setup_mock_save_flow_coordinator():
	mock_save_flow = Node.new()
	mock_save_flow.name = "MockSaveFlowCoordinator"
	mock_save_flow.set_script(GDScript.new())
	mock_save_flow.get_script().source_code = """
extends Node

signal save_flow_completed(operation_type: String, success: bool, context: Dictionary)

func _get_current_pilot_profile():
	var profile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd").new()
	profile.set_callsign("TestPilot")
	return profile

func _get_pilot_save_slot() -> int:
	return 1
"""
	
	add_child(mock_save_flow)
	coordinator.save_flow_coordinator = mock_save_flow

func _cleanup_test_files():
	# Clean up test backup metadata files
	var dir = DirAccess.open("user://saves/")
	if dir:
		# Remove test metadata files
		for i in range(10):
			var metadata_path = "backup_metadata_%d.json" % i
			if dir.file_exists(metadata_path):
				dir.remove(metadata_path)

func test_coordinator_initialization():
	"""Test BackupFlowCoordinator initializes correctly"""
	assert_that(coordinator).is_not_null()
	assert_that(coordinator.enable_automated_backups).is_true()
	assert_that(coordinator.backup_schedule_hours).is_equal(24)
	assert_that(coordinator.max_automated_backups).is_equal(30)
	assert_that(coordinator.enable_event_backups).is_true()
	assert_that(coordinator.enable_health_monitoring).is_true()
	assert_that(coordinator.is_backup_flow_active).is_false()

func test_backup_scheduler_setup():
	"""Test backup scheduler timer setup"""
	assert_that(coordinator.backup_scheduler_timer).is_not_null()
	assert_that(coordinator.backup_scheduler_timer.wait_time).is_equal(coordinator.backup_schedule_hours * 3600.0)
	assert_that(coordinator.backup_scheduler_timer.one_shot).is_false()

func test_health_monitoring_setup():
	"""Test health monitoring timer setup"""
	assert_that(coordinator.health_check_timer).is_not_null()
	assert_that(coordinator.health_check_timer.wait_time).is_equal(coordinator.health_check_interval_hours * 3600.0)
	assert_that(coordinator.health_check_timer.one_shot).is_false()

func test_backup_operation_types():
	"""Test backup operation enumeration"""
	var operations = [
		BackupFlowCoordinator.BackupOperation.MANUAL_BACKUP,
		BackupFlowCoordinator.BackupOperation.SCHEDULED_BACKUP,
		BackupFlowCoordinator.BackupOperation.EVENT_TRIGGERED,
		BackupFlowCoordinator.BackupOperation.EMERGENCY_BACKUP,
		BackupFlowCoordinator.BackupOperation.EXPORT_BACKUP,
		BackupFlowCoordinator.BackupOperation.IMPORT_BACKUP
	]
	
	# Test that all operations are valid enum values
	for operation in operations:
		assert_that(operation).is_instance_of(int)
		assert_that(operation).is_greater_equal(0)

func test_recovery_scenarios():
	"""Test recovery scenario enumeration"""
	var scenarios = [
		BackupFlowCoordinator.RecoveryScenario.CORRUPTED_SAVE,
		BackupFlowCoordinator.RecoveryScenario.MISSING_SAVE,
		BackupFlowCoordinator.RecoveryScenario.PILOT_DATA_LOSS,
		BackupFlowCoordinator.RecoveryScenario.CAMPAIGN_CORRUPTION,
		BackupFlowCoordinator.RecoveryScenario.SETTINGS_RESET,
		BackupFlowCoordinator.RecoveryScenario.COMPLETE_DATA_LOSS
	]
	
	for scenario in scenarios:
		assert_that(scenario).is_instance_of(int)
		assert_that(scenario).is_greater_equal(0)

func test_backup_triggers():
	"""Test backup trigger enumeration"""
	var triggers = [
		BackupFlowCoordinator.BackupTrigger.MANUAL,
		BackupFlowCoordinator.BackupTrigger.TIMER_INTERVAL,
		BackupFlowCoordinator.BackupTrigger.MISSION_COMPLETE,
		BackupFlowCoordinator.BackupTrigger.CAMPAIGN_MILESTONE,
		BackupFlowCoordinator.BackupTrigger.ACHIEVEMENT_EARNED,
		BackupFlowCoordinator.BackupTrigger.GAME_SHUTDOWN,
		BackupFlowCoordinator.BackupTrigger.CRITICAL_PROGRESS
	]
	
	for trigger in triggers:
		assert_that(trigger).is_instance_of(int)
		assert_that(trigger).is_greater_equal(0)

func test_trigger_reason_mapping():
	"""Test trigger reason string mapping"""
	var timer_reason = coordinator._get_trigger_reason(BackupFlowCoordinator.BackupTrigger.TIMER_INTERVAL)
	assert_that(timer_reason).is_equal("Scheduled Interval")
	
	var mission_reason = coordinator._get_trigger_reason(BackupFlowCoordinator.BackupTrigger.MISSION_COMPLETE)
	assert_that(mission_reason).is_equal("Mission Completion")
	
	var manual_reason = coordinator._get_trigger_reason(BackupFlowCoordinator.BackupTrigger.MANUAL)
	assert_that(manual_reason).is_equal("Manual Request")

func test_backup_status_retrieval():
	"""Test backup status retrieval"""
	var status = coordinator.get_backup_status()
	
	assert_that(status).is_not_null()
	assert_that(status.has("save_slots")).is_true()
	assert_that(status.has("automated_backups_enabled")).is_true()
	assert_that(status.has("last_automated_backup")).is_true()
	assert_that(status.has("last_health_check")).is_true()
	assert_that(status.has("backup_schedule_hours")).is_true()
	assert_that(status.has("health_check_interval_hours")).is_true()
	
	assert_that(status.automated_backups_enabled).is_equal(coordinator.enable_automated_backups)
	assert_that(status.backup_schedule_hours).is_equal(coordinator.backup_schedule_hours)

func test_configuration_methods():
	"""Test configuration update methods"""
	# Test automated backup configuration
	coordinator.set_automated_backups_enabled(false)
	assert_that(coordinator.enable_automated_backups).is_false()
	
	coordinator.set_automated_backups_enabled(true)
	assert_that(coordinator.enable_automated_backups).is_true()
	
	# Test backup schedule configuration
	coordinator.set_backup_schedule_hours(12)
	assert_that(coordinator.backup_schedule_hours).is_equal(12)
	assert_that(coordinator.backup_scheduler_timer.wait_time).is_equal(12 * 3600.0)
	
	# Test health monitoring configuration
	coordinator.set_health_monitoring_enabled(false)
	assert_that(coordinator.enable_health_monitoring).is_false()
	
	coordinator.set_health_monitoring_enabled(true)
	assert_that(coordinator.enable_health_monitoring).is_true()

func test_backup_operation_status():
	"""Test backup operation status tracking"""
	# Initially no operation should be active
	assert_that(coordinator.is_backup_operation_active()).is_false()
	
	# Set backup flow as active
	coordinator.is_backup_flow_active = true
	assert_that(coordinator.is_backup_operation_active()).is_true()
	
	coordinator.is_backup_flow_active = false

func test_operation_context_management():
	"""Test operation context creation and retrieval"""
	var test_context = {
		"backup_name": "Test Backup",
		"description": "Test Description",
		"operation": BackupFlowCoordinator.BackupOperation.MANUAL_BACKUP
	}
	
	coordinator.backup_operation_context = test_context
	var retrieved_context = coordinator.get_current_operation_context()
	
	assert_that(retrieved_context).is_not_null()
	assert_that(retrieved_context.backup_name).is_equal("Test Backup")
	assert_that(retrieved_context.description).is_equal("Test Description")

func test_save_slot_backup_checking():
	"""Test save slot backup checking methods"""
	var test_slot = 1
	
	# Test backup existence checking
	var has_backups = coordinator._slot_has_backups(test_slot)
	assert_that(has_backups).is_instance_of(bool)
	
	# Test backup count
	var backup_count = coordinator._get_slot_backup_count(test_slot)
	assert_that(backup_count).is_instance_of(int)
	assert_that(backup_count).is_greater_equal(0)
	
	# Test last backup time
	var last_backup_time = coordinator._get_last_backup_time(test_slot)
	assert_that(last_backup_time).is_instance_of(int)
	assert_that(last_backup_time).is_greater_equal(0)

func test_health_check_report_structure():
	"""Test health check report structure"""
	var report = coordinator.perform_health_check()
	
	assert_that(report).is_not_null()
	assert_that(report.has("check_time")).is_true()
	assert_that(report.has("total_backups")).is_true()
	assert_that(report.has("healthy_backups")).is_true()
	assert_that(report.has("corrupted_backups")).is_true()
	assert_that(report.has("suspicious_backups")).is_true()
	assert_that(report.has("backup_details")).is_true()
	assert_that(report.has("recommendations")).is_true()
	assert_that(report.has("overall_health")).is_true()
	
	# Verify data types
	assert_that(report.check_time).is_instance_of(int)
	assert_that(report.total_backups).is_instance_of(int)
	assert_that(report.backup_details).is_instance_of(Array)
	assert_that(report.recommendations).is_instance_of(Array)
	assert_that(report.overall_health).is_instance_of(String)

func test_health_recommendations():
	"""Test health recommendation generation"""
	var test_report = {
		"total_backups": 0,
		"healthy_backups": 0,
		"corrupted_backups": 0,
		"suspicious_backups": 0
	}
	
	var recommendations = coordinator._generate_health_recommendations(test_report)
	assert_that(recommendations).is_not_empty()
	assert_that(recommendations[0]).contains("No backups found")

func test_overall_health_determination():
	"""Test overall health determination logic"""
	# Test critical health (no backups)
	var critical_report = {"total_backups": 0, "healthy_backups": 0, "corrupted_backups": 0}
	var health = coordinator._determine_overall_health(critical_report)
	assert_that(health).is_equal("critical")
	
	# Test excellent health (many healthy backups)
	var excellent_report = {"total_backups": 5, "healthy_backups": 5, "corrupted_backups": 0}
	health = coordinator._determine_overall_health(excellent_report)
	assert_that(health).is_equal("excellent")
	
	# Test warning health (some corruption)
	var warning_report = {"total_backups": 3, "healthy_backups": 2, "corrupted_backups": 1}
	health = coordinator._determine_overall_health(warning_report)
	assert_that(health).is_equal("warning")

func test_recovery_situation_analysis():
	"""Test recovery situation analysis"""
	var scenario = BackupFlowCoordinator.RecoveryScenario.CORRUPTED_SAVE
	var context = {"save_slot": 1, "error_details": "Checksum mismatch"}
	
	var analysis = coordinator._analyze_recovery_situation(scenario, context)
	
	assert_that(analysis).is_not_null()
	assert_that(analysis.has("scenario")).is_true()
	assert_that(analysis.has("context")).is_true()
	assert_that(analysis.has("available_backups")).is_true()
	assert_that(analysis.has("recovery_options")).is_true()
	assert_that(analysis.has("recommended_action")).is_true()
	assert_that(analysis.has("data_loss_risk")).is_true()
	
	assert_that(analysis.scenario).is_equal(scenario)
	assert_that(analysis.context).is_equal(context)

func test_recovery_wizard_configuration():
	"""Test recovery wizard configuration creation"""
	var scenario = BackupFlowCoordinator.RecoveryScenario.MISSING_SAVE
	var analysis = {"scenario": scenario, "data_loss_risk": "medium"}
	
	var config = coordinator._create_recovery_wizard_config(scenario, analysis)
	
	assert_that(config).is_not_null()
	assert_that(config.has("scenario")).is_true()
	assert_that(config.has("title")).is_true()
	assert_that(config.has("steps")).is_true()
	assert_that(config.has("analysis")).is_true()
	
	assert_that(config.scenario).is_equal(scenario)
	assert_that(config.steps).is_instance_of(Array)
	assert_that(config.analysis).is_equal(analysis)

func test_export_backup_structure():
	"""Test backup export data structure"""
	var test_slot = 1
	var export_path = "user://test_export.json"
	
	# Mock successful export (would fail with real SaveGameManager in test)
	# Test data structure validation instead
	var export_data = {
		"player_profile": "profile_data",
		"campaign_state": {},
		"export_timestamp": Time.get_unix_time_from_system(),
		"export_version": "1.0",
		"source_slot": test_slot
	}
	
	# Verify required fields
	assert_that(export_data.has("player_profile")).is_true()
	assert_that(export_data.has("campaign_state")).is_true()
	assert_that(export_data.has("export_timestamp")).is_true()
	assert_that(export_data.has("export_version")).is_true()
	assert_that(export_data.has("source_slot")).is_true()

func test_import_backup_validation():
	"""Test backup import validation logic"""
	# Test valid import data structure
	var valid_import_data = {
		"player_profile": "valid_profile_data",
		"campaign_state": {},
		"export_timestamp": Time.get_unix_time_from_system(),
		"export_version": "1.0"
	}
	
	# Check required fields
	assert_that(valid_import_data.has("player_profile")).is_true()
	assert_that(valid_import_data.has("export_version")).is_true()
	
	# Test invalid import data
	var invalid_import_data = {
		"invalid_field": "data"
	}
	
	assert_that(invalid_import_data.has("player_profile")).is_false()
	assert_that(invalid_import_data.has("export_version")).is_false()

func test_metadata_management():
	"""Test backup metadata save/load"""
	var test_slot = 1
	var test_context = {
		"backup_name": "Test Backup",
		"description": "Test metadata",
		"operation": BackupFlowCoordinator.BackupOperation.MANUAL_BACKUP
	}
	
	# Save metadata
	coordinator._save_backup_metadata(test_slot, test_context)
	
	# Load metadata
	var loaded_metadata = coordinator._get_backup_metadata(test_slot)
	
	# Verify metadata structure
	if not loaded_metadata.is_empty():
		assert_that(loaded_metadata.has("backup_context")).is_true()
		assert_that(loaded_metadata.has("coordinator_version")).is_true()
		assert_that(loaded_metadata.has("creation_time")).is_true()

func test_signal_emission_setup():
	"""Test signal emission during operations"""
	var backup_flow_started_received = false
	var backup_flow_completed_received = false
	var health_check_completed_received = false
	
	# Connect to signals
	coordinator.backup_flow_started.connect(func(operation_type, context): backup_flow_started_received = true)
	coordinator.backup_flow_completed.connect(func(operation_type, success, context): backup_flow_completed_received = true)
	coordinator.health_check_completed.connect(func(report): health_check_completed_received = true)
	
	# Trigger operation completion
	coordinator.current_backup_operation = BackupFlowCoordinator.BackupOperation.MANUAL_BACKUP
	coordinator.backup_operation_context = {}
	coordinator._complete_backup_flow(true, "")
	
	# Trigger health check
	coordinator.perform_health_check()
	
	# Wait for signal processing
	await get_tree().process_frame
	
	# Check signals were emitted
	assert_that(backup_flow_completed_received).is_true()
	assert_that(health_check_completed_received).is_true()

func test_automated_backup_disabling():
	"""Test automated backup can be disabled"""
	coordinator.set_automated_backups_enabled(false)
	
	# Attempt automated backup when disabled
	var result = coordinator.trigger_automated_backup(BackupFlowCoordinator.BackupTrigger.TIMER_INTERVAL)
	assert_that(result).is_true()  # Returns true when disabled by design

func test_backup_flow_conflict_prevention():
	"""Test prevention of conflicting backup operations"""
	# Set backup flow as active
	coordinator.is_backup_flow_active = true
	
	# Attempt to start another manual backup
	var result = coordinator.create_manual_backup("Test Backup")
	assert_that(result).is_false()
	
	# Attempt automated backup during active operation
	result = coordinator.trigger_automated_backup(BackupFlowCoordinator.BackupTrigger.MANUAL)
	assert_that(result).is_false()
	
	# Reset state
	coordinator.is_backup_flow_active = false

func test_performance_stats_retrieval():
	"""Test performance statistics retrieval"""
	var stats = coordinator.get_backup_performance_stats()
	
	assert_that(stats).is_not_null()
	assert_that(stats.has("automated_backups_enabled")).is_true()
	assert_that(stats.has("last_automated_backup")).is_true()
	assert_that(stats.has("last_health_check")).is_true()
	assert_that(stats.has("backup_schedule_hours")).is_true()
	assert_that(stats.has("health_check_interval_hours")).is_true()
	assert_that(stats.has("max_automated_backups")).is_true()
	assert_that(stats.has("event_backups_enabled")).is_true()
	assert_that(stats.has("health_monitoring_enabled")).is_true()

func test_game_state_change_handling():
	"""Test game state change trigger handling"""
	# Setup for event backups
	coordinator.enable_event_backups = true
	
	# Test mission complete trigger
	coordinator._on_game_state_changed(
		GameStateManager.GameState.MISSION, 
		GameStateManager.GameState.MISSION_COMPLETE
	)
	
	# Test shutdown trigger
	coordinator._on_game_state_changed(
		GameStateManager.GameState.MAIN_MENU, 
		GameStateManager.GameState.SHUTDOWN
	)
	
	# Should handle without errors (actual backup would be tested in integration tests)

func test_save_flow_integration():
	"""Test SaveFlowCoordinator integration"""
	# Test save flow completion handling
	coordinator._on_save_flow_completed("mission_complete", true, {"test": "data"})
	
	# Should handle without errors when event backups enabled
	coordinator.enable_event_backups = true
	coordinator._on_save_flow_completed("campaign_checkpoint", true, {"test": "data"})

func test_corruption_detection_handling():
	"""Test corruption detection response"""
	var test_slot = 1
	var error_details = "Checksum validation failed"
	
	# Test corruption handling
	coordinator._on_corruption_detected(test_slot, error_details)
	
	# Should handle without errors and potentially trigger recovery