extends GutTest

## Test suite for SexpEvaluationContext
##
## Validates evaluation context functionality including variable management,
## object references, context hierarchy, and state management from SEXP-003.

const SexpEvaluationContext = preload("res://addons/sexp/core/sexp_evaluation_context.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var context: SexpEvaluationContext

func before_each():
	context = SexpEvaluationContext.new("test_context", "test")

## Test basic context creation
func test_context_creation():
	assert_not_null(context, "Context should be created")
	assert_eq(context.context_id, "test_context", "Context should have correct ID")
	assert_eq(context.context_type, "test", "Context should have correct type")
	assert_gt(context.creation_time, 0, "Context should have creation time")

## Test variable management
func test_variable_management():
	# Test setting variables
	var num_result = SexpResult.create_number(42)
	var str_result = SexpResult.create_string("hello")
	
	assert_true(context.set_variable("num_var", num_result), "Should set number variable")
	assert_true(context.set_variable("str_var", str_result), "Should set string variable")
	
	# Test getting variables
	var retrieved_num = context.get_variable("num_var")
	assert_true(retrieved_num.is_success(), "Should retrieve number variable")
	assert_eq(retrieved_num.get_number_value(), 42, "Should have correct number value")
	
	var retrieved_str = context.get_variable("str_var")
	assert_true(retrieved_str.is_success(), "Should retrieve string variable")
	assert_eq(retrieved_str.get_string_value(), "hello", "Should have correct string value")
	
	# Test variable existence
	assert_true(context.has_variable("num_var"), "Should confirm variable exists")
	assert_false(context.has_variable("nonexistent"), "Should confirm variable doesn't exist")

## Test variable access tracking
func test_variable_access_tracking():
	var result = SexpResult.create_number(10)
	context.set_variable("tracked_var", result)
	
	# Access variable multiple times
	context.get_variable("tracked_var")
	context.get_variable("tracked_var")
	context.get_variable("tracked_var")
	
	var metadata = context.get_variable_metadata("tracked_var")
	assert_gt(metadata["access_count"], 0, "Should track variable access count")
	assert_gt(metadata["last_access"], metadata["creation_time"], "Should update last access time")

## Test undefined variable error
func test_undefined_variable():
	var result = context.get_variable("undefined_variable")
	assert_true(result.is_error(), "Should return error for undefined variable")
	assert_eq(result.error_type, SexpResult.ErrorType.UNDEFINED_VARIABLE, "Should be undefined variable error")

## Test variable removal
func test_variable_removal():
	var result = SexpResult.create_boolean(true)
	context.set_variable("removable_var", result)
	assert_true(context.has_variable("removable_var"), "Variable should exist before removal")
	
	var removed = context.remove_variable("removable_var")
	assert_true(removed, "Should successfully remove variable")
	assert_false(context.has_variable("removable_var"), "Variable should not exist after removal")

## Test variable name validation
func test_variable_name_validation():
	var result = SexpResult.create_string("test")
	
	# Test invalid variable names
	assert_false(context.set_variable("", result), "Should not allow empty variable name")
	assert_false(context.set_variable("123invalid", result), "Should not allow name starting with number")
	assert_false(context.set_variable("invalid-char!", result), "Should not allow special characters")
	
	# Test valid variable names
	assert_true(context.set_variable("valid_name", result), "Should allow valid variable name")
	assert_true(context.set_variable("_underscore", result), "Should allow underscore prefix")
	assert_true(context.set_variable("CamelCase", result), "Should allow camel case")

## Test variable list retrieval
func test_variable_list():
	# Add multiple variables
	context.set_variable("var1", SexpResult.create_number(1))
	context.set_variable("var2", SexpResult.create_string("test"))
	context.set_variable("var3", SexpResult.create_boolean(true))
	
	var var_names = context.get_variable_names()
	assert_eq(var_names.size(), 3, "Should return all variable names")
	assert_true("var1" in var_names, "Should include var1")
	assert_true("var2" in var_names, "Should include var2")
	assert_true("var3" in var_names, "Should include var3")

## Test object reference management
func test_object_references():
	# Create test objects
	var test_dict = {"name": "test_object", "value": 42}
	var test_node = Node.new()
	test_node.name = "TestNode"
	
	# Set object references
	assert_true(context.set_object_reference("dict_obj", test_dict), "Should set dictionary reference")
	assert_true(context.set_object_reference("node_obj", test_node), "Should set node reference")
	
	# Get object references
	var dict_result = context.get_object_reference("dict_obj")
	assert_true(dict_result.is_success(), "Should retrieve dictionary reference")
	assert_eq(dict_result.get_object_value(), test_dict, "Should return correct dictionary")
	
	var node_result = context.get_object_reference("node_obj")
	assert_true(node_result.is_success(), "Should retrieve node reference")
	assert_eq(node_result.get_object_value(), test_node, "Should return correct node")
	
	# Test object existence
	assert_true(context.has_object_reference("dict_obj"), "Should confirm object exists")
	assert_false(context.has_object_reference("nonexistent"), "Should confirm object doesn't exist")
	
	# Clean up
	test_node.queue_free()

## Test invalid object references
func test_invalid_object_references():
	# Set null object reference
	context.set_object_reference("null_obj", null)
	
	var result = context.get_object_reference("null_obj")
	assert_true(result.is_error(), "Should return error for null object")
	assert_eq(result.error_type, SexpResult.ErrorType.OBJECT_NOT_FOUND, "Should be object not found error")

## Test object reference validation
func test_object_validation():
	var valid_node = Node.new()
	context.set_object_reference("valid_node", valid_node)
	
	# Free the node to make reference invalid
	valid_node.queue_free()
	await get_tree().process_frame  # Wait for node to be freed
	
	# Validate object references
	var invalid_objects = context.validate_object_references()
	assert_gt(invalid_objects.size(), 0, "Should detect invalid object references")
	assert_true("valid_node" in invalid_objects, "Should include freed node in invalid list")

## Test context hierarchy
func test_context_hierarchy():
	# Create parent and child contexts
	var parent = SexpEvaluationContext.new("parent", "test")
	var child = parent.create_child_context("child", "test")
	
	assert_eq(child.get_parent_context(), parent, "Child should have correct parent")
	assert_true(child in parent.get_child_contexts(), "Parent should contain child")
	
	# Test variable inheritance
	parent.set_variable("parent_var", SexpResult.create_string("parent_value"))
	child.set_variable("child_var", SexpResult.create_string("child_value"))
	
	# Child should access parent variables
	var parent_var_result = child.get_variable("parent_var")
	assert_true(parent_var_result.is_success(), "Child should access parent variable")
	assert_eq(parent_var_result.get_string_value(), "parent_value", "Should get parent variable value")
	
	# Parent should not access child variables
	var child_var_result = parent.get_variable("child_var")
	assert_true(child_var_result.is_error(), "Parent should not access child variable")

## Test context hierarchy removal
func test_context_hierarchy_removal():
	var parent = SexpEvaluationContext.new("parent", "test")
	var child = parent.create_child_context("child", "test")
	
	assert_true(parent.remove_child_context(child), "Should remove child context")
	assert_false(child in parent.get_child_contexts(), "Parent should not contain removed child")
	assert_null(child.get_parent_context(), "Child should not have parent after removal")

## Test context search
func test_context_search():
	var root = SexpEvaluationContext.new("root", "test")
	var child1 = root.create_child_context("child1", "test")
	var child2 = root.create_child_context("child2", "test")
	var grandchild = child1.create_child_context("grandchild", "test")
	
	# Test finding contexts by ID
	assert_eq(root.find_context("root"), root, "Should find root context")
	assert_eq(root.find_context("child1"), child1, "Should find child context")
	assert_eq(root.find_context("grandchild"), grandchild, "Should find grandchild context")
	assert_null(root.find_context("nonexistent"), "Should not find nonexistent context")

## Test context state management
func test_context_state():
	# Test locking
	context.lock_context()
	assert_false(context.set_variable("locked_var", SexpResult.create_number(1)), "Should not set variable when locked")
	
	context.unlock_context()
	assert_true(context.set_variable("unlocked_var", SexpResult.create_number(1)), "Should set variable when unlocked")
	
	# Test read-only mode
	context.set_read_only(true)
	assert_false(context.set_variable("readonly_var", SexpResult.create_number(2)), "Should not set variable when read-only")
	
	context.set_read_only(false)
	assert_true(context.set_variable("writable_var", SexpResult.create_number(2)), "Should set variable when writable")

## Test context clearing
func test_context_clearing():
	# Add variables and objects
	context.set_variable("clear_var", SexpResult.create_number(1))
	context.set_object_reference("clear_obj", {"test": "object"})
	
	assert_gt(context.get_variable_names().size(), 0, "Should have variables before clear")
	assert_gt(context.get_object_ids().size(), 0, "Should have objects before clear")
	
	# Clear context
	assert_true(context.clear_all(), "Should clear context successfully")
	assert_eq(context.get_variable_names().size(), 0, "Should have no variables after clear")
	assert_eq(context.get_object_ids().size(), 0, "Should have no objects after clear")

## Test context limits
func test_context_limits():
	# Test variable limit
	context.max_variables = 2
	
	assert_true(context.set_variable("var1", SexpResult.create_number(1)), "Should set first variable")
	assert_true(context.set_variable("var2", SexpResult.create_number(2)), "Should set second variable")
	assert_false(context.set_variable("var3", SexpResult.create_number(3)), "Should not exceed variable limit")
	
	# Test object limit
	context.max_objects = 1
	
	assert_true(context.set_object_reference("obj1", {"test": 1}), "Should set first object")
	assert_false(context.set_object_reference("obj2", {"test": 2}), "Should not exceed object limit")

## Test context serialization
func test_context_serialization():
	# Add test data
	context.set_variable("ser_num", SexpResult.create_number(42))
	context.set_variable("ser_str", SexpResult.create_string("serialized"))
	context.set_variable("ser_bool", SexpResult.create_boolean(true))
	
	# Export to dictionary
	var exported = context.to_dict()
	assert_true(exported.has("context_id"), "Exported data should have context ID")
	assert_true(exported.has("variables"), "Exported data should have variables")
	assert_eq(exported["context_id"], "test_context", "Should export correct context ID")
	
	# Import from dictionary
	var imported_context = SexpEvaluationContext.from_dict(exported)
	assert_eq(imported_context.context_id, "test_context", "Should import correct context ID")
	
	# Verify imported variables
	var imported_num = imported_context.get_variable("ser_num")
	assert_true(imported_num.is_success(), "Should import number variable")
	assert_eq(imported_num.get_number_value(), 42, "Should have correct imported value")

## Test context statistics
func test_context_statistics():
	# Add some data and perform operations
	context.set_variable("stat_var", SexpResult.create_number(1))
	context.get_variable("stat_var")
	context.get_variable("stat_var")
	
	var stats = context.get_statistics()
	assert_true(stats.has("variable_count"), "Stats should include variable count")
	assert_true(stats.has("variable_access_count"), "Stats should include access count")
	assert_true(stats.has("context_id"), "Stats should include context ID")
	assert_eq(stats["variable_count"], 1, "Should have correct variable count")
	assert_gt(stats["variable_access_count"], 0, "Should have variable accesses")

## Test context debug summary
func test_debug_summary():
	context.set_variable("debug_var", SexpResult.create_string("test"))
	
	var summary = context.get_debug_summary()
	assert_true(summary is String, "Debug summary should be a string")
	assert_true(summary.contains("test_context"), "Should contain context ID")
	assert_true(summary.contains("Variables"), "Should contain variable information")

## Test context string representation
func test_string_representation():
	context.set_variable("str_var", SexpResult.create_number(1))
	context.set_object_reference("str_obj", {"test": "object"})
	
	var context_str = str(context)
	assert_true(context_str is String, "Should convert to string")
	assert_true(context_str.contains("SexpEvaluationContext"), "Should contain class name")
	assert_true(context_str.contains("test_context"), "Should contain context ID")

## Test context signals
func test_context_signals():
	var variable_set_received = false
	var variable_accessed_received = false
	
	# Connect to signals
	context.variable_set.connect(func(name, value): variable_set_received = true)
	context.variable_accessed.connect(func(name, value): variable_accessed_received = true)
	
	# Trigger signals
	context.set_variable("signal_var", SexpResult.create_string("test"))
	assert_true(variable_set_received, "Should emit variable set signal")
	
	context.get_variable("signal_var")
	assert_true(variable_accessed_received, "Should emit variable accessed signal")

## Test context performance
func test_context_performance():
	# Test that variable operations are fast
	var start_time = Time.get_ticks_msec()
	
	for i in range(100):
		context.set_variable("perf_var_%d" % i, SexpResult.create_number(i))
	
	for i in range(100):
		context.get_variable("perf_var_%d" % i)
	
	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	
	assert_lt(total_time, 100, "Variable operations should be fast (under 100ms for 200 ops)")