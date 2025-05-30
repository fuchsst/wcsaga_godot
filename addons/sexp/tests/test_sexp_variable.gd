extends GutTest

## Test suite for SEXP Variable Resource from SEXP-006
##
## Tests individual variable functionality including type safety, validation,
## constraints, serialization, and metadata tracking.

const SexpVariable = preload("res://addons/sexp/variables/sexp_variable.gd")
const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

var variable: SexpVariable

func before_each():
	variable = SexpVariable.new()

## Basic variable operations

func test_variable_creation():
	assert_not_null(variable, "Should create variable instance")
	assert_gt(variable.created_time, 0.0, "Should set creation time")
	assert_eq(variable.created_time, variable.modified_time, "Creation and modification time should be equal initially")

func test_set_and_get_value():
	var test_value: SexpResult = SexpResult.create_number(42.5)
	
	var success: bool = variable.set_value(test_value)
	assert_true(success, "Should successfully set value")
	
	var retrieved: SexpResult = variable.get_value()
	assert_true(retrieved.is_number(), "Should retrieve number result")
	assert_eq(retrieved.get_number_value(), 42.5, "Should retrieve correct value")
	
	# Check that access count increased
	assert_gt(variable.access_count, 0, "Access count should increase")

func test_value_safe_access():
	var test_value: SexpResult = SexpResult.create_string("test")
	variable.set_value(test_value)
	
	var initial_access_count: int = variable.access_count
	var retrieved: SexpResult = variable.get_value_safe()
	
	assert_eq(retrieved.get_string_value(), "test", "Should retrieve correct value")
	assert_eq(variable.access_count, initial_access_count, "Safe access should not increment access count")

## Type management

func test_type_locking():
	var initial_value: SexpResult = SexpResult.create_number(10)
	variable.set_value(initial_value)
	
	# Lock type
	variable.lock_type()
	assert_true(variable.type_locked, "Should be type locked")
	
	# Try to change to different type
	var string_value: SexpResult = SexpResult.create_string("hello")
	var success: bool = variable.set_value(string_value)
	assert_false(success, "Should reject type change when locked")
	
	# Same type should work
	var another_number: SexpResult = SexpResult.create_number(20)
	success = variable.set_value(another_number)
	assert_true(success, "Should allow same type when locked")

func test_allowed_types():
	# Set allowed types to only numbers and strings
	variable.set_allowed_types([SexpResult.ResultType.NUMBER, SexpResult.ResultType.STRING])
	
	# Number should be allowed
	var number_value: SexpResult = SexpResult.create_number(42)
	var success: bool = variable.set_value(number_value)
	assert_true(success, "Should allow number type")
	
	# String should be allowed
	var string_value: SexpResult = SexpResult.create_string("hello")
	success = variable.set_value(string_value)
	assert_true(success, "Should allow string type")
	
	# Boolean should be rejected
	var bool_value: SexpResult = SexpResult.create_boolean(true)
	success = variable.set_value(bool_value)
	assert_false(success, "Should reject boolean type")

## Value constraints

func test_number_range_constraints():
	# Set range constraint
	variable.set_number_range(0.0, 100.0)
	
	# Value within range should work
	var valid_value: SexpResult = SexpResult.create_number(50.0)
	var success: bool = variable.set_value(valid_value)
	assert_true(success, "Should allow value within range")
	
	# Value below range should be rejected
	var below_range: SexpResult = SexpResult.create_number(-10.0)
	success = variable.set_value(below_range)
	assert_false(success, "Should reject value below range")
	
	# Value above range should be rejected
	var above_range: SexpResult = SexpResult.create_number(150.0)
	success = variable.set_value(above_range)
	assert_false(success, "Should reject value above range")

func test_string_value_constraints():
	# Set allowed string values
	variable.set_allowed_string_values(["easy", "normal", "hard"])
	
	# Allowed value should work
	var valid_string: SexpResult = SexpResult.create_string("normal")
	var success: bool = variable.set_value(valid_string)
	assert_true(success, "Should allow valid string value")
	
	# Invalid value should be rejected
	var invalid_string: SexpResult = SexpResult.create_string("extreme")
	success = variable.set_value(invalid_string)
	assert_false(success, "Should reject invalid string value")

## Read-only protection

func test_read_only_variable():
	# Set initial value
	var initial_value: SexpResult = SexpResult.create_string("readonly")
	variable.set_value(initial_value)
	
	# Make read-only
	variable.set_read_only(true)
	
	# Try to modify
	var new_value: SexpResult = SexpResult.create_string("modified")
	var success: bool = variable.set_value(new_value)
	assert_false(success, "Should reject modification of read-only variable")
	
	# Original value should remain
	var current: SexpResult = variable.get_value()
	assert_eq(current.get_string_value(), "readonly", "Original value should be preserved")

## Type checking methods

func test_type_checking_methods():
	# Test with number
	variable.set_value(SexpResult.create_number(42))
	assert_true(variable.is_number(), "Should identify as number")
	assert_false(variable.is_string(), "Should not identify as string")
	assert_false(variable.is_boolean(), "Should not identify as boolean")
	
	# Test with string
	variable.set_value(SexpResult.create_string("test"))
	assert_false(variable.is_number(), "Should not identify as number")
	assert_true(variable.is_string(), "Should identify as string")
	assert_false(variable.is_boolean(), "Should not identify as boolean")
	
	# Test with boolean
	variable.set_value(SexpResult.create_boolean(true))
	assert_false(variable.is_number(), "Should not identify as number")
	assert_false(variable.is_string(), "Should not identify as string")
	assert_true(variable.is_boolean(), "Should identify as boolean")

func test_get_type_string():
	variable.set_value(SexpResult.create_number(42))
	assert_eq(variable.get_type_string(), "number", "Should return correct type string")
	
	variable.set_value(SexpResult.create_string("test"))
	assert_eq(variable.get_type_string(), "string", "Should return correct type string")
	
	variable.set_value(SexpResult.create_boolean(false))
	assert_eq(variable.get_type_string(), "boolean", "Should return correct type string")

## Type conversion

func test_convert_to_number():
	# String to number
	variable.set_value(SexpResult.create_string("123.45"))
	var number_result: SexpResult = variable.convert_to_number()
	assert_true(number_result.is_number(), "Should convert string to number")
	assert_eq(number_result.get_number_value(), 123.45, "Should convert correctly")
	
	# Boolean to number (WCS semantics)
	variable.set_value(SexpResult.create_boolean(true))
	number_result = variable.convert_to_number()
	assert_eq(number_result.get_number_value(), 1.0, "True should convert to 1")
	
	variable.set_value(SexpResult.create_boolean(false))
	number_result = variable.convert_to_number()
	assert_eq(number_result.get_number_value(), 0.0, "False should convert to 0")

func test_convert_to_string():
	# Number to string
	variable.set_value(SexpResult.create_number(42.5))
	var string_result: SexpResult = variable.convert_to_string()
	assert_true(string_result.is_string(), "Should convert number to string")
	assert_eq(string_result.get_string_value(), "42.5", "Should convert correctly")
	
	# Boolean to string
	variable.set_value(SexpResult.create_boolean(true))
	string_result = variable.convert_to_string()
	assert_eq(string_result.get_string_value(), "true", "Should convert boolean to string")

func test_convert_to_boolean():
	# Number to boolean (WCS semantics)
	variable.set_value(SexpResult.create_number(0.0))
	var bool_result: SexpResult = variable.convert_to_boolean()
	assert_false(bool_result.get_boolean_value(), "Zero should convert to false")
	
	variable.set_value(SexpResult.create_number(42.0))
	bool_result = variable.convert_to_boolean()
	assert_true(bool_result.get_boolean_value(), "Non-zero should convert to true")
	
	# String to boolean
	variable.set_value(SexpResult.create_string(""))
	bool_result = variable.convert_to_boolean()
	assert_false(bool_result.get_boolean_value(), "Empty string should convert to false")
	
	variable.set_value(SexpResult.create_string("hello"))
	bool_result = variable.convert_to_boolean()
	assert_true(bool_result.get_boolean_value(), "Non-empty string should convert to true")

## Metadata and information

func test_metadata_tracking():
	variable.name = "test_var"
	variable.scope = SexpVariableManager.VariableScope.CAMPAIGN
	variable.set_description("Test variable for unit testing")
	variable.set_source_info("test_mission", "test_function")
	
	var info: Dictionary = variable.get_info()
	
	assert_eq(info.name, "test_var", "Should include variable name")
	assert_eq(info.scope, "campaign", "Should include scope as string")
	assert_eq(info.description, "Test variable for unit testing", "Should include description")
	assert_eq(info.source_mission, "test_mission", "Should include source mission")
	assert_eq(info.source_function, "test_function", "Should include source function")
	assert_has(info, "created_time", "Should include creation time")
	assert_has(info, "access_count", "Should include access count")

func test_age_calculation():
	var age: float = variable.get_age_seconds()
	assert_ge(age, 0.0, "Age should be non-negative")
	assert_lt(age, 1.0, "Age should be very small for new variable")

## Serialization and persistence

func test_serialization_roundtrip():
	# Set up variable with various properties
	variable.name = "serialize_test"
	variable.scope = SexpVariableManager.VariableScope.GLOBAL
	variable.set_value(SexpResult.create_number(42.5))
	variable.set_description("Serialization test variable")
	variable.set_source_info("test_mission", "serialize_function")
	variable.set_number_range(0.0, 100.0)
	variable.set_allowed_types([SexpResult.ResultType.NUMBER])
	variable.lock_type()
	variable.access_count = 5
	
	# Serialize
	var serialized: Dictionary = variable.serialize()
	assert_not_null(serialized, "Should serialize to dictionary")
	assert_has(serialized, "name", "Should include name in serialization")
	assert_has(serialized, "value", "Should include value in serialization")
	
	# Deserialize into new variable
	var new_variable: SexpVariable = SexpVariable.new()
	var success: bool = new_variable.deserialize(serialized)
	assert_true(success, "Should successfully deserialize")
	
	# Verify all properties
	assert_eq(new_variable.name, "serialize_test", "Name should be preserved")
	assert_eq(new_variable.scope, SexpVariableManager.VariableScope.GLOBAL, "Scope should be preserved")
	assert_eq(new_variable.get_value_safe().get_number_value(), 42.5, "Value should be preserved")
	assert_eq(new_variable.description, "Serialization test variable", "Description should be preserved")
	assert_eq(new_variable.source_mission, "test_mission", "Source mission should be preserved")
	assert_eq(new_variable.source_function, "serialize_function", "Source function should be preserved")
	assert_eq(new_variable.type_locked, true, "Type lock should be preserved")
	assert_eq(new_variable.access_count, 5, "Access count should be preserved")

func test_serialization_with_different_types():
	# Test string value
	variable.set_value(SexpResult.create_string("hello world"))
	var serialized_string: Dictionary = variable.serialize()
	var string_var: SexpVariable = SexpVariable.new()
	string_var.deserialize(serialized_string)
	assert_eq(string_var.get_value_safe().get_string_value(), "hello world", "String should serialize correctly")
	
	# Test boolean value
	variable.set_value(SexpResult.create_boolean(true))
	var serialized_bool: Dictionary = variable.serialize()
	var bool_var: SexpVariable = SexpVariable.new()
	bool_var.deserialize(serialized_bool)
	assert_eq(bool_var.get_value_safe().get_boolean_value(), true, "Boolean should serialize correctly")
	
	# Test error value
	var error_result: SexpResult = SexpResult.create_error("Test error", SexpResult.ErrorType.RUNTIME_ERROR)
	variable.set_value(error_result, false)  # Skip validation for error
	var serialized_error: Dictionary = variable.serialize()
	var error_var: SexpVariable = SexpVariable.new()
	error_var.deserialize(serialized_error)
	assert_true(error_var.get_value_safe().is_error(), "Error should serialize correctly")

## Constraint management

func test_constraint_clearing():
	# Set up constraints
	variable.set_number_range(0.0, 100.0)
	variable.set_allowed_string_values(["a", "b", "c"])
	variable.set_allowed_types([SexpResult.ResultType.NUMBER])
	
	# Clear constraints
	variable.clear_constraints()
	
	# Verify constraints are cleared
	assert_eq(variable.min_value, -INF, "Min value should be reset")
	assert_eq(variable.max_value, INF, "Max value should be reset")
	assert_eq(variable.allowed_string_values.size(), 0, "String values should be cleared")
	assert_eq(variable.allowed_types.size(), 0, "Allowed types should be cleared")

## Error handling

func test_invalid_serialization_data():
	var invalid_data: Dictionary = {"invalid": "data"}
	var success: bool = variable.deserialize(invalid_data)
	assert_false(success, "Should reject invalid serialization data")

func test_null_value_handling():
	var success: bool = variable.set_value(null)
	assert_false(success, "Should reject null value")
	
	# Convert null should return error
	variable.value = null
	var convert_result: SexpResult = variable.convert_to_number()
	assert_true(convert_result.is_error(), "Converting null should return error")