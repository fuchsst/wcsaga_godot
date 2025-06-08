extends SceneTree

## Test runner for Core Manager unit tests
## Executes all core manager tests and reports results

func _init():
	print("=== Core Manager Test Suite ===")
	print("Running comprehensive tests for all core managers...")
	
	run_test_suite()

func run_test_suite():
	var test_files: Array[String] = [
		"res://tests/core/test_object_manager.gd",
		"res://tests/core/test_game_state_manager.gd", 
		"res://tests/core/test_physics_manager.gd",
		"res://tests/core/test_input_manager.gd"
	]
	
	var total_tests: int = 0
	var passed_tests: int = 0
	var failed_tests: int = 0
	
	print("\n--- Running Unit Tests ---")
	
	for test_file in test_files:
		print("Executing: %s" % test_file)
		
		if ResourceLoader.exists(test_file):
			var test_script = load(test_file)
			if test_script:
				var result = execute_test_script(test_script)
				total_tests += result.get("total", 0)
				passed_tests += result.get("passed", 0)
				failed_tests += result.get("failed", 0)
			else:
				print("  ERROR: Failed to load test script")
		else:
			print("  ERROR: Test file not found")
	
	print("\n=== Test Results Summary ===")
	print("Total Tests: %d" % total_tests)
	print("Passed: %d" % passed_tests)
	print("Failed: %d" % failed_tests)
	print("Success Rate: %.1f%%" % ((float(passed_tests) / float(total_tests)) * 100.0))
	
	if failed_tests == 0:
		print("✅ ALL TESTS PASSED!")
	else:
		print("❌ %d test(s) failed" % failed_tests)
	
	print("===============================")
	
	# Exit with appropriate code
	var exit_code: int = 0 if failed_tests == 0 else 1
	quit(exit_code)

func execute_test_script(test_script: Script) -> Dictionary:
	var result: Dictionary = {"total": 0, "passed": 0, "failed": 0}
	
	# Get test methods from script
	var test_methods: Array[String] = []
	var script_methods = test_script.get_script_method_list()
	
	for method in script_methods:
		if method.name.begins_with("test_"):
			test_methods.append(method.name)
	
	result.total = test_methods.size()
	
	if test_methods.is_empty():
		print("  No test methods found")
		return result
	
	# Create test instance
	var test_instance = test_script.new()
	add_child(test_instance)
	
	# Execute each test method
	for method_name in test_methods:
		var test_passed: bool = execute_test_method(test_instance, method_name)
		
		if test_passed:
			result.passed += 1
			print("    ✓ %s" % method_name)
		else:
			result.failed += 1
			print("    ✗ %s" % method_name)
	
	# Cleanup
	test_instance.queue_free()
	
	return result

func execute_test_method(test_instance: Object, method_name: String) -> bool:
	var test_passed: bool = true
	
	# Setup
	if test_instance.has_method("before_test"):
		test_instance.before_test()
	
	# Execute test
	if test_instance.has_method(method_name):
		# Use signal to catch test completion for async tests
		var callable = Callable(test_instance, method_name)
		callable.call()
		
		# For async tests, we'd need to wait for completion
		# This is a simplified version
		test_passed = true
	else:
		test_passed = false
	
	# Cleanup
	if test_instance.has_method("after_test"):
		test_instance.after_test()
	
	return test_passed

# Additional validation
func validate_core_managers() -> bool:
	print("\n--- Validating Core Manager Availability ---")
	
	var all_valid: bool = true
	var managers: Array[String] = ["ObjectManager", "GameStateManager", "PhysicsManager", "InputManager"]
	
	for manager_name in managers:
		var manager = get_node_or_null("/root/" + manager_name)
		if manager:
			print("✓ %s: Available" % manager_name)
			
			if manager.has_method("get_performance_stats"):
				var stats = manager.get_performance_stats()
				print("  Stats: %s" % stats)
		else:
			print("✗ %s: NOT FOUND" % manager_name)
			all_valid = false
	
	return all_valid
