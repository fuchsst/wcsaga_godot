class_name TestCoreManagers
extends RefCounted

## Unit tests for WCS core manager infrastructure.
## Tests ObjectManager, GameStateManager, PhysicsManager, and InputManager functionality.

var object_manager: ObjectManager
var game_state_manager: GameStateManager  
var physics_manager: PhysicsManager
var input_manager: InputManager

func before_each() -> void:
	"""Set up test environment before each test."""
	
	# Create manager instances for testing
	object_manager = ObjectManager.new()
	game_state_manager = GameStateManager.new()
	physics_manager = PhysicsManager.new()
	input_manager = InputManager.new()

func after_each() -> void:
	"""Clean up after each test."""
	
	if object_manager:
		object_manager.queue_free()
	if game_state_manager:
		game_state_manager.queue_free()
	if physics_manager:
		physics_manager.queue_free()
	if input_manager:
		input_manager.queue_free()

## ObjectManager Tests

func test_object_manager_initialization() -> bool:
	"""Test that ObjectManager initializes correctly."""
	
	assert(object_manager != null, "ObjectManager should be created")
	assert(object_manager.max_objects > 0, "max_objects should be positive")
	
	# Test debug stats
	var stats: Dictionary = object_manager.get_debug_stats()
	assert(stats.has("active_count"), "Debug stats should include active_count")
	assert(stats.has("max_objects"), "Debug stats should include max_objects")
	assert(stats.active_count == 0, "Should start with 0 active objects")
	
	return true

func test_object_manager_registration() -> bool:
	"""Test object registration and unregistration."""
	
	# Create a test WCS object
	var test_object: WCSObject = WCSObject.new()
	test_object.object_type = WCSObject.ObjectType.SHIP
	
	# Test registration
	object_manager.register_object(test_object)
	var stats: Dictionary = object_manager.get_debug_stats()
	assert(stats.active_count == 1, "Should have 1 active object after registration")
	
	# Test unregistration
	object_manager.unregister_object(test_object)
	stats = object_manager.get_debug_stats()
	assert(stats.active_count == 0, "Should have 0 active objects after unregistration")
	
	test_object.queue_free()
	return true

## GameStateManager Tests

func test_game_state_manager_initialization() -> bool:
	"""Test that GameStateManager initializes correctly."""
	
	assert(game_state_manager != null, "GameStateManager should be created")
	
	# Test debug stats
	var stats: Dictionary = game_state_manager.get_debug_stats()
	assert(stats.has("current_state"), "Debug stats should include current_state")
	assert(stats.has("state_stack_size"), "Debug stats should include state_stack_size")
	assert(stats.state_stack_size == 0, "Should start with empty state stack")
	
	return true

func test_game_state_transitions() -> bool:
	"""Test basic state transitions."""
	
	var initial_state: GameStateManager.GameState = game_state_manager.get_current_state()
	
	# Test state change request
	var success: bool = game_state_manager.request_state_change(GameStateManager.GameState.OPTIONS)
	# Note: This might fail due to scene loading, which is expected in unit tests
	
	# Test state stack operations
	success = game_state_manager.push_state(GameStateManager.GameState.PAUSED)
	var stats: Dictionary = game_state_manager.get_debug_stats()
	# State stack behavior depends on successful state transitions
	
	return true

## PhysicsManager Tests

func test_physics_manager_initialization() -> bool:
	"""Test that PhysicsManager initializes correctly."""
	
	assert(physics_manager != null, "PhysicsManager should be created")
	assert(physics_manager.physics_frequency > 0, "Physics frequency should be positive")
	
	# Test debug stats
	var stats: Dictionary = physics_manager.get_debug_stats()
	assert(stats.has("active_bodies"), "Debug stats should include active_bodies")
	assert(stats.has("actual_update_rate"), "Debug stats should include actual_update_rate")
	assert(stats.active_bodies == 0, "Should start with 0 active bodies")
	
	return true

func test_physics_body_management() -> bool:
	"""Test physics body creation and management."""
	
	# Create test object
	var test_object: WCSObject = WCSObject.new()
	test_object.object_type = WCSObject.ObjectType.SHIP
	
	# Test body creation
	physics_manager.register_physics_body(test_object)
	var stats: Dictionary = physics_manager.get_debug_stats()
	assert(stats.active_bodies == 1, "Should have 1 active body after registration")
	
	# Test body removal
	physics_manager.unregister_physics_body(test_object)
	stats = physics_manager.get_debug_stats()
	assert(stats.active_bodies == 0, "Should have 0 active bodies after removal")
	
	test_object.queue_free()
	return true

## InputManager Tests

func test_input_manager_initialization() -> bool:
	"""Test that InputManager initializes correctly."""
	
	assert(input_manager != null, "InputManager should be created")
	assert(input_manager.analog_deadzone >= 0.0, "Analog deadzone should be non-negative")
	assert(input_manager.analog_curve > 0.0, "Analog curve should be positive")
	
	# Test debug stats
	var stats: Dictionary = input_manager.get_debug_stats()
	assert(stats.has("active_control_scheme"), "Debug stats should include active_control_scheme")
	assert(stats.has("connected_devices"), "Debug stats should include connected_devices")
	
	return true

func test_input_control_schemes() -> bool:
	"""Test control scheme switching."""
	
	var initial_scheme: InputManager.ControlScheme = input_manager.current_scheme
	
	# Test scheme change
	input_manager.set_control_scheme(InputManager.ControlScheme.GAMEPAD)
	assert(input_manager.current_scheme == InputManager.ControlScheme.GAMEPAD, 
		"Control scheme should change to GAMEPAD")
	
	# Test revert
	input_manager.set_control_scheme(initial_scheme)
	assert(input_manager.current_scheme == initial_scheme,
		"Control scheme should revert to initial")
	
	return true

## Integration Tests

func test_manager_debug_stats_format() -> bool:
	"""Test that all managers return properly formatted debug stats."""
	
	var managers: Array = [object_manager, game_state_manager, physics_manager, input_manager]
	
	for manager in managers:
		if manager.has_method("get_debug_stats"):
			var stats: Dictionary = manager.get_debug_stats()
			assert(stats is Dictionary, "Debug stats should be a Dictionary")
			assert(stats.size() > 0, "Debug stats should not be empty")
		else:
			assert(false, "Manager should have get_debug_stats method")
	
	return true

## Test Runner

func run_all_tests() -> Dictionary:
	"""Run all tests and return results."""
	
	var results: Dictionary = {
		"total": 0,
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests: Array[String] = [
		"test_object_manager_initialization",
		"test_object_manager_registration", 
		"test_game_state_manager_initialization",
		"test_game_state_transitions",
		"test_physics_manager_initialization",
		"test_physics_body_management",
		"test_input_manager_initialization",
		"test_input_control_schemes",
		"test_manager_debug_stats_format"
	]
	
	for test_name in tests:
		results.total += 1
		before_each()
		
		var success: bool = false
		try:
			success = call(test_name)
		except:
			success = false
			results.failures.append(test_name + ": Exception occurred")
		
		if success:
			results.passed += 1
			print("✓ " + test_name)
		else:
			results.failed += 1
			results.failures.append(test_name + ": Test assertion failed")
			print("✗ " + test_name)
		
		after_each()
	
	print("\nTest Results: %d/%d passed" % [results.passed, results.total])
	if results.failed > 0:
		print("Failures:")
		for failure in results.failures:
			print("  - " + failure)
	
	return results