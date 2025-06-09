extends GdUnitTestSuite

## Unit tests for Enhanced Transition Manager (FLOW-002)
## Tests enhanced state transition validation, error recovery, and performance monitoring

const EnhancedTransitionManager = preload("res://scripts/core/game_flow/state_management/enhanced_transition_manager.gd")

var enhanced_transition_manager: EnhancedTransitionManager
var game_state_manager: Node

func before():
	# Get reference to GameStateManager autoload
	game_state_manager = GameStateManager
	if not game_state_manager:
		fail("GameStateManager autoload not found")
	
	# Create enhanced transition manager instance
	enhanced_transition_manager = EnhancedTransitionManager.new()
	if not enhanced_transition_manager:
		fail("Failed to create EnhancedTransitionManager instance")

func after():
	# Clean up
	if enhanced_transition_manager:
		enhanced_transition_manager = null
	
	# Reset game state
	if game_state_manager and game_state_manager.get_current_state() != GameStateManager.GameState.MAIN_MENU:
		game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)
		await game_state_manager.state_transition_completed

func test_enhanced_transition_manager_initialization():
	"""Test Enhanced Transition Manager initialization and configuration"""
	assert_that(enhanced_transition_manager).is_not_null()
	assert_that(enhanced_transition_manager.enable_performance_monitoring).is_true()
	assert_that(enhanced_transition_manager.enable_rollback).is_true()
	assert_that(enhanced_transition_manager.max_transition_time_ms).is_equal(16.0)
	assert_that(enhanced_transition_manager.warning_transition_time_ms).is_equal(8.0)

func test_enhanced_transition_validation_success():
	"""Test successful enhanced transition validation"""
	# Setup valid transition data
	var transition_data: Dictionary = {
		"pilot_selected": true,
		"briefing_completed": false
	}
	
	# Test valid transition
	var result: EnhancedTransitionManager.EnhancedTransitionResult = await enhanced_transition_manager.execute_enhanced_transition(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.PILOT_SELECTION,
		transition_data
	)
	
	assert_that(result).is_not_null()
	assert_that(result.success).is_true()
	assert_that(result.error_message).is_empty()
	assert_that(result.transition_time_ms).is_greater(0)

func test_enhanced_transition_validation_failure():
	"""Test enhanced transition validation failure and error reporting"""
	# Setup invalid transition data
	var transition_data: Dictionary = {}
	
	# Test invalid transition (skip directly to ship selection without briefing)
	var result: EnhancedTransitionManager.EnhancedTransitionResult = await enhanced_transition_manager.execute_enhanced_transition(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.SHIP_SELECTION,
		transition_data
	)
	
	assert_that(result).is_not_null()
	assert_that(result.success).is_false()
	assert_that(result.error_message).is_not_empty()

func test_performance_monitoring():
	"""Test performance monitoring and warning system"""
	var performance_warning_emitted: bool = false
	var warning_time: float = 0.0
	
	# Connect to performance warning signal
	enhanced_transition_manager.transition_performance_warning.connect(
		func(time_ms: float, from_state: GameStateManager.GameState, to_state: GameStateManager.GameState):
			performance_warning_emitted = true
			warning_time = time_ms
	)
	
	# Set very low warning threshold to trigger warning
	enhanced_transition_manager.set_performance_limits(100.0, 0.1)
	
	# Execute transition that should trigger warning
	var result: EnhancedTransitionManager.EnhancedTransitionResult = await enhanced_transition_manager.execute_enhanced_transition(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.PILOT_SELECTION,
		{}
	)
	
	# Performance warning should be triggered for slow transition
	if result.transition_time_ms > 0.1:
		assert_that(performance_warning_emitted).is_true()
		assert_that(warning_time).is_greater(0.1)

func test_resource_preparation():
	"""Test resource preparation for different states"""
	# Test mission state resource preparation
	var mission_data: Dictionary = {
		"mission_file": "res://test_mission.tres"  # Non-existent file for testing
	}
	
	var result: EnhancedTransitionManager.EnhancedTransitionResult = await enhanced_transition_manager.execute_enhanced_transition(
		GameStateManager.GameState.BRIEFING,
		GameStateManager.GameState.MISSION,
		mission_data
	)
	
	# Should handle resource preparation gracefully
	assert_that(result).is_not_null()

func test_rollback_mechanism():
	"""Test transaction rollback on failed transitions"""
	var rollback_performed: bool = false
	
	# Connect to rollback signal
	enhanced_transition_manager.transition_rollback_performed.connect(
		func(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, reason: String):
			rollback_performed = true
	)
	
	# Enable rollback
	enhanced_transition_manager.set_rollback_enabled(true)
	
	# Attempt transition that might fail (invalid state combination)
	var result: EnhancedTransitionManager.EnhancedTransitionResult = await enhanced_transition_manager.execute_enhanced_transition(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.MISSION_COMPLETE,  # Invalid direct transition
		{}
	)
	
	# Should fail and trigger rollback
	assert_that(result.success).is_false()
	if result.rollback_performed:
		assert_that(rollback_performed).is_true()

func test_performance_configuration():
	"""Test performance limit configuration"""
	# Test setting performance limits
	enhanced_transition_manager.set_performance_limits(50.0, 25.0)
	
	var stats: Dictionary = enhanced_transition_manager.get_performance_stats()
	assert_that(stats["max_transition_time_ms"]).is_equal(50.0)
	assert_that(stats["warning_transition_time_ms"]).is_equal(25.0)
	
	# Test enabling/disabling monitoring
	enhanced_transition_manager.set_performance_monitoring(false)
	stats = enhanced_transition_manager.get_performance_stats()
	assert_that(stats["enable_performance_monitoring"]).is_false()
	
	enhanced_transition_manager.set_performance_monitoring(true)
	stats = enhanced_transition_manager.get_performance_stats()
	assert_that(stats["enable_performance_monitoring"]).is_true()

func test_concurrent_transition_prevention():
	"""Test prevention of concurrent transitions"""
	# Start a transition without waiting
	var result1_task: EnhancedTransitionManager.EnhancedTransitionResult = enhanced_transition_manager.execute_enhanced_transition(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.PILOT_SELECTION,
		{}
	)
	
	# Attempt second transition while first is in progress
	var result2: EnhancedTransitionManager.EnhancedTransitionResult = await enhanced_transition_manager.execute_enhanced_transition(
		GameStateManager.GameState.PILOT_SELECTION,
		GameStateManager.GameState.CAMPAIGN_MENU,
		{}
	)
	
	# Second transition should be rejected
	assert_that(result2.success).is_false()
	assert_that(result2.error_message).contains("already in progress")
	
	# Wait for first transition to complete
	var result1: EnhancedTransitionManager.EnhancedTransitionResult = await result1_task

func test_validation_signal_emission():
	"""Test that validation failure signals are properly emitted"""
	var validation_failed: bool = false
	var validation_error: String = ""
	
	# Connect to validation failure signal
	enhanced_transition_manager.transition_validation_failed.connect(
		func(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, error_message: String):
			validation_failed = true
			validation_error = error_message
	)
	
	# Attempt invalid transition
	var result: EnhancedTransitionManager.EnhancedTransitionResult = await enhanced_transition_manager.execute_enhanced_transition(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.MISSION_COMPLETE,
		{}
	)
	
	# Validation failure signal should be emitted
	assert_that(validation_failed).is_true()
	assert_that(validation_error).is_not_empty()

func test_performance_metrics_collection():
	"""Test performance metrics collection and reporting"""
	var result: EnhancedTransitionManager.EnhancedTransitionResult = await enhanced_transition_manager.execute_enhanced_transition(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.PILOT_SELECTION,
		{}
	)
	
	if result.success:
		assert_that(result.performance_metrics).is_not_empty()
		assert_that(result.performance_metrics.has("transition_time_ms")).is_true()
		assert_that(result.performance_metrics.has("memory_usage")).is_true()
		assert_that(result.performance_metrics.has("from_state")).is_true()
		assert_that(result.performance_metrics.has("to_state")).is_true()
		assert_that(result.performance_metrics.has("timestamp")).is_true()