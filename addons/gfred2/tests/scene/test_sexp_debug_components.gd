@tool
extends GdUnitTestSuite

## Test suite for GFRED2 SEXP debugging components (GFRED2-006B)
## Tests debug controls, variable watch, and advanced debugging integration

func test_sexp_debug_controls_scene_instantiation():
	"""Test SEXP debug controls scene can be instantiated."""
	
	var scene_path: String = "res://addons/gfred2/scenes/components/sexp_debug_controls_panel.tscn"
	assert_file_exists(scene_path)
	
	var scene: PackedScene = load(scene_path)
	assert_not_null(scene)
	
	var instance: SexpDebugController = scene.instantiate()
	assert_not_null(instance)
	assert_that(instance).is_instance_of(SexpDebugController)
	
	# Test initial state
	var debug_state: Dictionary = instance.get_debug_state()
	assert_bool(debug_state.is_debugging).is_false()
	assert_bool(debug_state.is_paused).is_false()
	assert_that(debug_state.step_count).is_equal(0)
	
	instance.queue_free()

func test_sexp_debug_controls_session_management():
	"""Test debug session start/stop functionality."""
	
	var debug_controller: SexpDebugController = SexpDebugController.new()
	add_child(debug_controller)
	
	# Monitor signals
	var session_started_monitor: GdUnitSignalMonitor = monitor_signal(debug_controller.debug_session_started)
	var session_stopped_monitor: GdUnitSignalMonitor = monitor_signal(debug_controller.debug_session_stopped)
	
	# Start debug session
	var session_id: String = debug_controller.start_debug_session("test_expression")
	assert_that(session_id).is_not_empty()
	
	# Verify session started
	await wait_until(func(): return session_started_monitor.get_signal_count() > 0).wait_at_most(1000)
	assert_signal_emitted(debug_controller.debug_session_started)
	
	var debug_state: Dictionary = debug_controller.get_debug_state()
	assert_bool(debug_state.is_debugging).is_true()
	assert_that(debug_state.session_id).is_equal(session_id)
	
	# Stop debug session
	debug_controller.stop_debug_session()
	
	# Verify session stopped
	await wait_until(func(): return session_stopped_monitor.get_signal_count() > 0).wait_at_most(1000)
	assert_signal_emitted(debug_controller.debug_session_stopped)
	
	debug_state = debug_controller.get_debug_state()
	assert_bool(debug_state.is_debugging).is_false()
	
	debug_controller.queue_free()

func test_sexp_debug_controls_stepping():
	"""Test step-through debugging functionality."""
	
	var debug_controller: SexpDebugController = SexpDebugController.new()
	add_child(debug_controller)
	
	# Start debug session
	var session_id: String = debug_controller.start_debug_session()
	assert_that(session_id).is_not_empty()
	
	# Test step into
	var step_result: bool = debug_controller.step_into()
	assert_bool(step_result).is_true()
	
	# Test step over
	step_result = debug_controller.step_over()
	assert_bool(step_result).is_true()
	
	# Test step out
	step_result = debug_controller.step_out()
	assert_bool(step_result).is_true()
	
	# Test continue execution
	var continue_result: bool = debug_controller.continue_execution()
	assert_bool(continue_result).is_true()
	
	debug_controller.queue_free()

func test_sexp_variable_watch_scene_instantiation():
	"""Test SEXP variable watch scene can be instantiated."""
	
	var scene_path: String = "res://addons/gfred2/scenes/components/sexp_variable_watch_panel.tscn"
	assert_file_exists(scene_path)
	
	var scene: PackedScene = load(scene_path)
	assert_not_null(scene)
	
	var instance: SexpVariableWatchManager = scene.instantiate()
	assert_not_null(instance)
	assert_that(instance).is_instance_of(SexpVariableWatchManager)
	
	# Test initial state
	assert_that(instance.get_watched_variable_count()).is_equal(0)
	
	instance.queue_free()

func test_sexp_variable_watch_functionality():
	"""Test variable watch add/remove functionality."""
	
	var watch_manager: SexpVariableWatchManager = SexpVariableWatchManager.new()
	add_child(watch_manager)
	
	# Monitor signals
	var watch_added_monitor: GdUnitSignalMonitor = monitor_signal(watch_manager.variable_watch_added)
	var watch_removed_monitor: GdUnitSignalMonitor = monitor_signal(watch_manager.variable_watch_removed)
	
	# Add variable to watch
	var success: bool = watch_manager.add_variable_watch("test_variable")
	assert_bool(success).is_true()
	
	# Verify watch added
	await wait_until(func(): return watch_added_monitor.get_signal_count() > 0).wait_at_most(1000)
	assert_signal_emitted(watch_manager.variable_watch_added)
	assert_that(watch_manager.get_watched_variable_count()).is_equal(1)
	
	# Test duplicate add (should fail)
	success = watch_manager.add_variable_watch("test_variable")
	assert_bool(success).is_false()
	assert_that(watch_manager.get_watched_variable_count()).is_equal(1)
	
	# Remove variable from watch
	success = watch_manager.remove_variable_watch("@test_variable")  # Normalized name
	assert_bool(success).is_true()
	
	# Verify watch removed
	await wait_until(func(): return watch_removed_monitor.get_signal_count() > 0).wait_at_most(1000)
	assert_signal_emitted(watch_manager.variable_watch_removed)
	assert_that(watch_manager.get_watched_variable_count()).is_equal(0)
	
	watch_manager.queue_free()

func test_sexp_variable_watch_real_time_updates():
	"""Test real-time variable value updates."""
	
	var watch_manager: SexpVariableWatchManager = SexpVariableWatchManager.new()
	add_child(watch_manager)
	
	# Add variable to watch
	watch_manager.add_variable_watch("@test_health")
	
	# Enable real-time updates with short interval
	watch_manager.set_real_time_updates(true)
	watch_manager.set_update_interval(0.1)  # 100ms
	
	# Monitor value changes
	var value_changed_monitor: GdUnitSignalMonitor = monitor_signal(watch_manager.variable_value_changed)
	
	# Wait for at least one update cycle
	await wait_for(500)  # Wait 500ms for updates
	
	# Verify updates occurred (simulated values should change)
	var update_count: int = value_changed_monitor.get_signal_count()
	assert_that(update_count).is_greater_equal(1)
	
	# Disable real-time updates
	watch_manager.set_real_time_updates(false)
	
	watch_manager.queue_free()

func test_sexp_debug_console_scene_instantiation():
	"""Test SEXP debug console scene can be instantiated."""
	
	var scene_path: String = "res://addons/gfred2/scenes/components/sexp_debug_console_panel.tscn"
	assert_file_exists(scene_path)
	
	var scene: PackedScene = load(scene_path)
	assert_not_null(scene)
	
	var instance: SexpDebugConsole = scene.instantiate()
	assert_not_null(instance)
	assert_that(instance).is_instance_of(SexpDebugConsole)
	
	instance.queue_free()

func test_sexp_advanced_debug_integration():
	"""Test advanced SEXP debug integration functionality."""
	
	var integration: SexpAdvancedDebugIntegration = SexpAdvancedDebugIntegration.new()
	add_child(integration)
	
	# Create mock mission data
	var mission_data: MockMissionData = MockMissionData.new()
	
	# Monitor session signals
	var session_state_monitor: GdUnitSignalMonitor = monitor_signal(integration.debug_session_state_changed)
	
	# Start advanced debug session
	var session_id: String = integration.start_advanced_debug_session(mission_data, "Test Session")
	assert_that(session_id).is_not_empty()
	
	# Verify session started
	await wait_until(func(): return session_state_monitor.get_signal_count() > 0).wait_at_most(1000)
	assert_signal_emitted(integration.debug_session_state_changed)
	
	# Test debug state
	var debug_state: Dictionary = integration.get_debug_state()
	assert_bool(debug_state.has_active_session).is_true()
	assert_that(debug_state.session_id).is_equal(session_id)
	
	# Test expression preview evaluation
	var eval_result: Dictionary = integration.evaluate_expression_preview("(+ 1 2)")
	assert_bool(eval_result.success).is_true()
	assert_that(eval_result.result).is_equal(3)
	assert_that(eval_result.execution_time_ms).is_greater_equal(0)
	
	# Test variable watch
	var watch_success: bool = integration.add_variable_to_watch("@test_var")
	assert_bool(watch_success).is_true()
	
	# Test breakpoint
	var breakpoint_success: bool = integration.add_expression_breakpoint("(test-expression)")
	assert_bool(breakpoint_success).is_true()
	
	# Stop debug session
	var summary: Dictionary = integration.stop_advanced_debug_session()
	assert_that(summary).has_key("session_id")
	assert_that(summary).has_key("duration")
	
	# Verify session stopped
	debug_state = integration.get_debug_state()
	assert_bool(debug_state.has_active_session).is_false()
	
	integration.queue_free()

func test_debug_session_configuration_save_restore():
	"""Test debug session configuration save and restore."""
	
	var integration: SexpAdvancedDebugIntegration = SexpAdvancedDebugIntegration.new()
	add_child(integration)
	
	var mission_data: MockMissionData = MockMissionData.new()
	
	# Start session and configure it
	var session_id: String = integration.start_advanced_debug_session(mission_data, "Config Test")
	integration.add_variable_to_watch("@config_test_var")
	integration.add_expression_breakpoint("(config-test)")
	
	# Save session configuration
	var save_path: String = "user://test_debug_session.json"
	var save_error: Error = integration.save_debug_session_configuration(session_id, save_path)
	assert_that(save_error).is_equal(OK)
	
	# Verify file exists
	assert_file_exists(save_path)
	
	# Stop session and start new one
	integration.stop_advanced_debug_session()
	var new_session_id: String = integration.start_advanced_debug_session(mission_data, "Restored Session")
	
	# Restore configuration
	var restore_error: Error = integration.restore_debug_session_configuration(save_path)
	assert_that(restore_error).is_equal(OK)
	
	# Verify configuration was restored
	var debug_state: Dictionary = integration.get_debug_state()
	assert_that(debug_state.active_breakpoints).is_greater_equal(1)
	assert_that(debug_state.watched_variables).is_greater_equal(1)
	
	# Clean up
	integration.stop_advanced_debug_session()
	DirAccess.remove_absolute(save_path)
	integration.queue_free()

func test_debug_performance_monitoring():
	"""Test debug performance monitoring functionality."""
	
	var integration: SexpAdvancedDebugIntegration = SexpAdvancedDebugIntegration.new()
	add_child(integration)
	
	# Monitor performance alerts
	var performance_alert_monitor: GdUnitSignalMonitor = monitor_signal(integration.debug_performance_alert)
	
	# Evaluate expressions to generate performance data
	integration.evaluate_expression_preview("(+ 1 2)")
	integration.evaluate_expression_preview("(* 3 4)")
	
	# Get performance profile
	var performance_data: Dictionary = integration.get_performance_profile()
	assert_that(performance_data).is_not_empty()
	
	# Test specific expression performance
	var specific_perf: Dictionary = integration.get_performance_profile("(+ 1 2)")
	assert_that(specific_perf).has_key("(+ 1 2)")
	
	integration.queue_free()

func test_debug_component_performance_requirements():
	"""Test that debug components meet performance requirements."""
	
	# Test debug controls scene instantiation time
	var start_time: int = Time.get_ticks_msec()
	
	var scene_path: String = "res://addons/gfred2/scenes/components/sexp_debug_controls_panel.tscn"
	var scene: PackedScene = load(scene_path)
	var instance: SexpDebugController = scene.instantiate()
	add_child(instance)
	
	var instantiation_time: int = Time.get_ticks_msec() - start_time
	
	# Performance requirement: < 16ms scene instantiation
	assert_that(instantiation_time).is_less_than(16)
	
	# Test debug state update performance
	start_time = Time.get_ticks_msec()
	
	var session_id: String = instance.start_debug_session()
	instance.step_into()
	instance.get_debug_state()
	
	var operation_time: int = Time.get_ticks_msec() - start_time
	
	# Should be very fast for debug operations
	assert_that(operation_time).is_less_than(10)
	
	instance.queue_free()

## Mock classes for testing

class MockMissionData:
	extends RefCounted
	
	var ships: Array = []
	var events: Array = []
	var wings: Array = []
	
	func _init():
		# Add some mock data
		ships.append(MockShip.new("Alpha 1"))
		ships.append(MockShip.new("Beta 1"))
		events.append(MockEvent.new("Test Event"))

class MockShip:
	extends RefCounted
	
	var ship_name: String
	var ship_class: String = "GTF_Apollo"
	
	func _init(name: String):
		ship_name = name

class MockEvent:
	extends RefCounted
	
	var event_name: String
	var condition_sexp: String = "(is-destroyed \"Alpha 1\")"
	
	func _init(name: String):
		event_name = name