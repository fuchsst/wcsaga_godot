extends GdUnitTestSuite

## Test suite for VariableValidator utility class.
## Tests validation rules, constraints, and error detection for campaign variables.

const VariableValidator = preload("res://scripts/core/game_flow/campaign_system/variable_validator.gd")
const CampaignVariables = preload("res://scripts/core/game_flow/campaign_system/campaign_variables.gd")

# --- Variable Name Validation Tests ---

func test_valid_variable_names() -> void:
	# Test valid variable name formats
	var valid_names: Array[String] = [
		"validName",
		"valid_name",
		"valid-name",
		"ValidName123",
		"a",
		"name_with_underscores",
		"name-with-dashes",
		"CamelCaseName",
		"mixedCase_with-Everything123"
	]
	
	for name: String in valid_names:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_name(name)
		assert_bool(result.is_valid).is_true()
		assert_that(result.errors).is_empty()

func test_invalid_variable_names() -> void:
	# Test invalid variable name formats
	var invalid_names: Array[String] = [
		"",                    # Empty
		"123name",             # Starts with number
		"invalid name",        # Contains space
		"invalid@name",        # Invalid character
		"invalid.name",        # Invalid character
		"invalid$name",        # Invalid character
		"invalid/name",        # Invalid character
		"invalid\\name",       # Invalid character
		"invalid%name",        # Invalid character
		"a" * 65              # Too long (over 64 characters)
	]
	
	for name: String in invalid_names:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_name(name)
		assert_bool(result.is_valid).is_false()
		assert_that(result.errors.size()).is_greater(0)

func test_reserved_variable_names() -> void:
	# Test reserved prefixes
	var reserved_prefixes: Array[String] = [
		"_system_test",
		"_internal_test",
		"_temp_test",
		"_debug_test"
	]
	
	for name: String in reserved_prefixes:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_name(name)
		assert_bool(result.is_valid).is_false()
		assert_that(result.errors[0]).contains("reserved prefix")
	
	# Test reserved names
	var reserved_names: Array[String] = [
		"null",
		"true",
		"false",
		"nil",
		"undefined"
	]
	
	for name: String in reserved_names:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_name(name)
		assert_bool(result.is_valid).is_false()
		assert_that(result.errors[0]).contains("reserved")

func test_keyword_warnings() -> void:
	# Test programming keyword warnings
	var keywords: Array[String] = [
		"if",
		"else",
		"for",
		"while",
		"function",
		"class",
		"extends",
		"var",
		"const"
	]
	
	for keyword: String in keywords:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_name(keyword)
		assert_that(result.warnings.size()).is_greater(0)
		assert_that(result.warnings[0]).contains("keyword")

# --- Variable Value Validation Tests ---

func test_integer_value_validation() -> void:
	# Test valid integers
	var valid_integers: Array[int] = [0, 1, -1, 100, -100, 2147483647, -2147483648]
	
	for value: int in valid_integers:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(value)
		assert_bool(result.is_valid).is_true()
	
	# Test out-of-range integers (should generate warnings)
	var large_value: int = 2147483647
	# Note: In GDScript, we can't easily create out-of-range values for testing
	# This would be tested in a language that allows overflow

func test_float_value_validation() -> void:
	# Test valid floats
	var valid_floats: Array[float] = [0.0, 1.0, -1.0, 3.14159, -2.5, 1e10, -1e-10]
	
	for value: float in valid_floats:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(value)
		assert_bool(result.is_valid).is_true()
	
	# Test special float values
	var nan_value: float = NAN
	var inf_value: float = INF
	
	var nan_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(nan_value)
	assert_bool(nan_result.is_valid).is_false()
	assert_that(nan_result.errors[0]).contains("NaN")
	
	var inf_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(inf_value)
	assert_bool(inf_result.is_valid).is_false()
	assert_that(inf_result.errors[0]).contains("infinite")

func test_boolean_value_validation() -> void:
	# Booleans are always valid
	var result_true: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(true)
	var result_false: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(false)
	
	assert_bool(result_true.is_valid).is_true()
	assert_bool(result_false.is_valid).is_true()

func test_string_value_validation() -> void:
	# Test valid strings
	var valid_strings: Array[String] = [
		"",
		"hello",
		"Hello World!",
		"String with\nnewlines",
		"Unicode: αβγδε",
		"Numbers: 123456"
	]
	
	for value: String in valid_strings:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(value)
		assert_bool(result.is_valid).is_true()
	
	# Test very long string (should generate error)
	var long_string: String = "a".repeat(5000)  # Over MAX_STRING_VALUE_LENGTH (4096)
	var long_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(long_string)
	assert_bool(long_result.is_valid).is_false()
	assert_that(long_result.errors[0]).contains("too long")
	
	# Test string with null characters (should generate warning)
	var null_string: String = "hello\0world"
	var null_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(null_string)
	assert_that(null_result.warnings.size()).is_greater(0)
	assert_that(null_result.warnings[0]).contains("null characters")

func test_array_value_validation() -> void:
	# Test valid arrays
	var valid_arrays: Array[Array] = [
		[],
		[1, 2, 3],
		["a", "b", "c"],
		[true, false],
		[{"key": "value"}]
	]
	
	for value: Array in valid_arrays:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(value)
		assert_bool(result.is_valid).is_true()
	
	# Test array that's too large
	var large_array: Array = []
	for i in range(1001):  # Over MAX_ARRAY_SIZE (1000)
		large_array.append(i)
	
	var large_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(large_array)
	assert_bool(large_result.is_valid).is_false()
	assert_that(large_result.errors[0]).contains("too large")
	
	# Test mixed type array (should generate warning)
	var mixed_array: Array = [1, "string", true, []]
	var mixed_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(mixed_array)
	assert_that(mixed_result.warnings.size()).is_greater(0)
	assert_that(mixed_result.warnings[0]).contains("mixed types")

func test_dictionary_value_validation() -> void:
	# Test valid dictionaries
	var valid_dicts: Array[Dictionary] = [
		{},
		{"key": "value"},
		{"int": 42, "float": 3.14, "bool": true},
		{"nested": {"inner": "value"}}
	]
	
	for value: Dictionary in valid_dicts:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(value)
		assert_bool(result.is_valid).is_true()
	
	# Test dictionary that's too large
	var large_dict: Dictionary = {}
	for i in range(101):  # Over MAX_DICTIONARY_SIZE (100)
		large_dict["key_%d" % i] = i
	
	var large_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(large_dict)
	assert_bool(large_result.is_valid).is_false()
	assert_that(large_result.errors[0]).contains("too large")
	
	# Test dictionary with non-string keys (should generate warning)
	var non_string_key_dict: Dictionary = {
		42: "numeric key",
		"string_key": "string key"
	}
	
	var non_string_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(non_string_key_dict)
	assert_that(non_string_result.warnings.size()).is_greater(0)
	assert_that(non_string_result.warnings[0]).contains("non-string key")

# --- Type Compatibility Tests ---

func test_type_compatibility() -> void:
	# Test compatible type conversions
	var test_cases: Array[Dictionary] = [
		{
			"value": 42,
			"expected_type": CampaignVariables.VariableType.INTEGER,
			"should_be_compatible": true
		},
		{
			"value": 3.14,
			"expected_type": CampaignVariables.VariableType.INTEGER,
			"should_be_compatible": true  # Float can convert to int
		},
		{
			"value": true,
			"expected_type": CampaignVariables.VariableType.INTEGER,
			"should_be_compatible": true  # Bool can convert to int
		},
		{
			"value": "hello",
			"expected_type": CampaignVariables.VariableType.INTEGER,
			"should_be_compatible": false  # String can't convert to int reliably
		},
		{
			"value": "anything",
			"expected_type": CampaignVariables.VariableType.STRING,
			"should_be_compatible": true  # Everything can convert to string
		},
		{
			"value": [1, 2, 3],
			"expected_type": CampaignVariables.VariableType.DICTIONARY,
			"should_be_compatible": false  # Array can't convert to dict
		}
	]
	
	for test_case: Dictionary in test_cases:
		var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(
			test_case.value, 
			test_case.expected_type
		)
		
		if test_case.should_be_compatible:
			# Should have no warnings about compatibility
			var has_compatibility_warning: bool = false
			for warning: String in result.warnings:
				if "compatible" in warning:
					has_compatibility_warning = true
					break
			assert_bool(has_compatibility_warning).is_false()
		else:
			# Should have warning about compatibility
			var has_compatibility_warning: bool = false
			for warning: String in result.warnings:
				if "compatible" in warning:
					has_compatibility_warning = true
					break
			assert_bool(has_compatibility_warning).is_true()

# --- Scope Validation Tests ---

func test_variable_scope_validation() -> void:
	# Test system variables scope
	var system_global_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_scope(
		"_system_test", 
		CampaignVariables.VariableScope.GLOBAL
	)
	assert_bool(system_global_result.is_valid).is_true()
	
	var system_campaign_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_scope(
		"_system_test", 
		CampaignVariables.VariableScope.CAMPAIGN
	)
	assert_bool(system_campaign_result.is_valid).is_false()
	assert_that(system_campaign_result.errors[0]).contains("global scope")
	
	# Test temporary variables scope recommendations
	var temp_global_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_scope(
		"_temp_test", 
		CampaignVariables.VariableScope.GLOBAL
	)
	assert_that(temp_global_result.warnings.size()).is_greater(0)
	assert_that(temp_global_result.warnings[0]).contains("mission or session scope")
	
	# Test debug variables scope recommendations
	var debug_campaign_result: VariableValidator.ValidationResult = VariableValidator.validate_variable_scope(
		"_debug_test", 
		CampaignVariables.VariableScope.CAMPAIGN
	)
	assert_that(debug_campaign_result.warnings.size()).is_greater(0)
	assert_that(debug_campaign_result.warnings[0]).contains("session scope")

# --- Variable Set Validation Tests ---

func test_variable_set_validation() -> void:
	# Create test variable set
	var variables: Dictionary = {
		"int_var": 42,
		"string_var": "hello",
		"bool_var": true,
		"array_var": [1, 2, 3]
	}
	
	var metadata: Dictionary = {
		"int_var": {
			"type": CampaignVariables.VariableType.INTEGER,
			"scope": CampaignVariables.VariableScope.CAMPAIGN
		},
		"string_var": {
			"type": CampaignVariables.VariableType.STRING,
			"scope": CampaignVariables.VariableScope.CAMPAIGN
		},
		"bool_var": {
			"type": CampaignVariables.VariableType.BOOLEAN,
			"scope": CampaignVariables.VariableScope.MISSION
		},
		"array_var": {
			"type": CampaignVariables.VariableType.ARRAY,
			"scope": CampaignVariables.VariableScope.SESSION
		}
	}
	
	var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_set(variables, metadata)
	assert_bool(result.is_valid).is_true()

func test_variable_set_missing_metadata() -> void:
	var variables: Dictionary = {
		"var1": "value1",
		"var2": "value2"
	}
	
	var metadata: Dictionary = {
		"var1": {"type": CampaignVariables.VariableType.STRING}
		# var2 metadata missing
	}
	
	var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_set(variables, metadata)
	assert_that(result.warnings.size()).is_greater(0)
	assert_that(result.warnings[0]).contains("missing metadata")

func test_variable_set_orphaned_metadata() -> void:
	var variables: Dictionary = {
		"var1": "value1"
	}
	
	var metadata: Dictionary = {
		"var1": {"type": CampaignVariables.VariableType.STRING},
		"var2": {"type": CampaignVariables.VariableType.STRING}  # var2 doesn't exist
	}
	
	var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_set(variables, metadata)
	assert_that(result.warnings.size()).is_greater(0)
	assert_that(result.warnings[0]).contains("Orphaned metadata")

func test_variable_set_type_mismatch() -> void:
	var variables: Dictionary = {
		"var1": "string_value"  # String value
	}
	
	var metadata: Dictionary = {
		"var1": {"type": CampaignVariables.VariableType.INTEGER}  # Expected integer
	}
	
	var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_set(variables, metadata)
	assert_bool(result.is_valid).is_false()
	assert_that(result.errors[0]).contains("validation failed")

# --- Nesting Depth Tests ---

func test_array_nesting_depth() -> void:
	# Create deeply nested array
	var nested_array: Array = [1, 2, [3, 4, [5, 6, [7, 8, [9, 10, [11, 12]]]]]]
	
	var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(nested_array)
	assert_that(result.warnings.size()).is_greater(0)
	assert_that(result.warnings[0]).contains("nesting too deep")

func test_dictionary_nesting_depth() -> void:
	# Create deeply nested dictionary
	var nested_dict: Dictionary = {
		"level1": {
			"level2": {
				"level3": {
					"level4": {
						"level5": {
							"level6": "too deep"
						}
					}
				}
			}
		}
	}
	
	var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_value(nested_dict)
	assert_that(result.warnings.size()).is_greater(0)
	assert_that(result.warnings[0]).contains("nesting too deep")

# --- Circular Reference Tests ---

func test_circular_reference_detection() -> void:
	var variables: Dictionary = {
		"var1": "var1",  # Simple self-reference
		"var2": "safe_value",
		"array_var": ["item1", "array_var", "item3"],  # Array containing self-reference
		"dict_var": {"key": "dict_var"}  # Dictionary containing self-reference
	}
	
	var metadata: Dictionary = {
		"var1": {"type": CampaignVariables.VariableType.STRING},
		"var2": {"type": CampaignVariables.VariableType.STRING},
		"array_var": {"type": CampaignVariables.VariableType.ARRAY},
		"dict_var": {"type": CampaignVariables.VariableType.DICTIONARY}
	}
	
	var result: VariableValidator.ValidationResult = VariableValidator.validate_variable_set(variables, metadata)
	
	# Should detect circular references
	var has_circular_warning: bool = false
	for warning: String in result.warnings:
		if "circular reference" in warning:
			has_circular_warning = true
			break
	
	assert_bool(has_circular_warning).is_true()

# --- ValidationResult Tests ---

func test_validation_result_functionality() -> void:
	var result: VariableValidator.ValidationResult = VariableValidator.ValidationResult.new()
	
	# Initially valid
	assert_bool(result.is_valid).is_true()
	assert_bool(result.has_issues()).is_false()
	assert_that(result.get_summary()).is_equal("Valid")
	
	# Add warning
	result.add_warning("Test warning")
	assert_bool(result.is_valid).is_true()  # Still valid with warnings
	assert_bool(result.has_issues()).is_true()
	assert_that(result.get_summary()).contains("1 warnings")
	
	# Add error
	result.add_error("Test error")
	assert_bool(result.is_valid).is_false()  # Invalid with errors
	assert_bool(result.has_issues()).is_true()
	assert_that(result.get_summary()).contains("1 errors")
	assert_that(result.get_summary()).contains("1 warnings")