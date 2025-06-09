extends GdUnitTestSuite

## Test suite for CampaignVariables system.
## Tests variable management, type validation, access control, and SEXP integration.

const CampaignVariables = preload("res://scripts/core/game_flow/campaign_system/campaign_variables.gd")
const VariableChange = preload("res://scripts/core/game_flow/campaign_system/variable_change.gd")
const CampaignState = preload("res://addons/wcs_asset_core/resources/save_system/campaign_state.gd")

var campaign_variables: CampaignVariables
var mock_campaign_state: CampaignState

func before_test() -> void:
	# Create mock campaign state
	mock_campaign_state = CampaignState.new()
	mock_campaign_state.initialize_from_campaign_data({
		"campaign_name": "Test Campaign",
		"total_missions": 10
	})
	
	# Create campaign variables instance
	campaign_variables = CampaignVariables.new(mock_campaign_state)

func after_test() -> void:
	campaign_variables = null
	mock_campaign_state = null
	CampaignVariables.instance = null

# --- Basic Variable Operations ---

func test_set_and_get_variable() -> void:
	# Test setting and getting basic types
	assert_bool(campaign_variables.set_variable("test_int", 42)).is_true()
	assert_that(campaign_variables.get_variable("test_int")).is_equal(42)
	
	assert_bool(campaign_variables.set_variable("test_float", 3.14)).is_true()
	assert_that(campaign_variables.get_variable("test_float")).is_equal(3.14)
	
	assert_bool(campaign_variables.set_variable("test_bool", true)).is_true()
	assert_that(campaign_variables.get_variable("test_bool")).is_equal(true)
	
	assert_bool(campaign_variables.set_variable("test_string", "hello")).is_true()
	assert_that(campaign_variables.get_variable("test_string")).is_equal("hello")

func test_variable_with_default_value() -> void:
	# Test getting non-existent variable with default
	assert_that(campaign_variables.get_variable("nonexistent", "default")).is_equal("default")
	assert_that(campaign_variables.get_variable("nonexistent", 100)).is_equal(100)

func test_has_variable() -> void:
	# Test variable existence checking
	assert_bool(campaign_variables.has_variable("nonexistent")).is_false()
	
	campaign_variables.set_variable("exists", "value")
	assert_bool(campaign_variables.has_variable("exists")).is_true()

func test_variable_scopes() -> void:
	# Test different variable scopes
	assert_bool(campaign_variables.set_variable("global_var", "global", CampaignVariables.VariableScope.GLOBAL)).is_true()
	assert_bool(campaign_variables.set_variable("campaign_var", "campaign", CampaignVariables.VariableScope.CAMPAIGN)).is_true()
	assert_bool(campaign_variables.set_variable("mission_var", "mission", CampaignVariables.VariableScope.MISSION)).is_true()
	assert_bool(campaign_variables.set_variable("session_var", "session", CampaignVariables.VariableScope.SESSION)).is_true()
	
	# Verify scopes are correctly stored
	assert_that(campaign_variables.get_variable_scope("global_var")).is_equal(CampaignVariables.VariableScope.GLOBAL)
	assert_that(campaign_variables.get_variable_scope("campaign_var")).is_equal(CampaignVariables.VariableScope.CAMPAIGN)
	assert_that(campaign_variables.get_variable_scope("mission_var")).is_equal(CampaignVariables.VariableScope.MISSION)
	assert_that(campaign_variables.get_variable_scope("session_var")).is_equal(CampaignVariables.VariableScope.SESSION)

# --- Typed Variable Accessors ---

func test_typed_integer_access() -> void:
	campaign_variables.set_variable("int_var", 42)
	campaign_variables.set_variable("float_var", 3.14)
	campaign_variables.set_variable("string_var", "123")
	campaign_variables.set_variable("bool_var", true)
	
	# Test direct integer
	assert_that(campaign_variables.get_int("int_var")).is_equal(42)
	
	# Test float to int conversion
	assert_that(campaign_variables.get_int("float_var")).is_equal(3)
	
	# Test string to int conversion
	assert_that(campaign_variables.get_int("string_var")).is_equal(123)
	
	# Test bool to int conversion
	assert_that(campaign_variables.get_int("bool_var")).is_equal(1)
	
	# Test default value
	assert_that(campaign_variables.get_int("nonexistent", 999)).is_equal(999)

func test_typed_float_access() -> void:
	campaign_variables.set_variable("float_var", 3.14)
	campaign_variables.set_variable("int_var", 42)
	campaign_variables.set_variable("string_var", "2.5")
	
	# Test direct float
	assert_that(campaign_variables.get_float("float_var")).is_equal(3.14)
	
	# Test int to float conversion
	assert_that(campaign_variables.get_float("int_var")).is_equal(42.0)
	
	# Test string to float conversion
	assert_that(campaign_variables.get_float("string_var")).is_equal(2.5)

func test_typed_boolean_access() -> void:
	campaign_variables.set_variable("bool_var", true)
	campaign_variables.set_variable("int_zero", 0)
	campaign_variables.set_variable("int_nonzero", 5)
	campaign_variables.set_variable("string_true", "true")
	campaign_variables.set_variable("string_false", "false")
	campaign_variables.set_variable("string_yes", "yes")
	
	# Test direct boolean
	assert_bool(campaign_variables.get_bool("bool_var")).is_true()
	
	# Test int to bool conversion
	assert_bool(campaign_variables.get_bool("int_zero")).is_false()
	assert_bool(campaign_variables.get_bool("int_nonzero")).is_true()
	
	# Test string to bool conversion
	assert_bool(campaign_variables.get_bool("string_true")).is_true()
	assert_bool(campaign_variables.get_bool("string_false")).is_false()
	assert_bool(campaign_variables.get_bool("string_yes")).is_true()

func test_typed_string_access() -> void:
	campaign_variables.set_variable("string_var", "hello")
	campaign_variables.set_variable("int_var", 42)
	campaign_variables.set_variable("float_var", 3.14)
	campaign_variables.set_variable("bool_var", true)
	
	# Test direct string
	assert_that(campaign_variables.get_string("string_var")).is_equal("hello")
	
	# Test conversion to string
	assert_that(campaign_variables.get_string("int_var")).is_equal("42")
	assert_that(campaign_variables.get_string("float_var")).is_equal("3.14")
	assert_that(campaign_variables.get_string("bool_var")).is_equal("true")

# --- Variable Operations ---

func test_increment_variable() -> void:
	# Test increment on integer
	campaign_variables.set_variable("int_counter", 10)
	assert_bool(campaign_variables.increment_variable("int_counter")).is_true()
	assert_that(campaign_variables.get_int("int_counter")).is_equal(11)
	
	assert_bool(campaign_variables.increment_variable("int_counter", 5)).is_true()
	assert_that(campaign_variables.get_int("int_counter")).is_equal(16)
	
	# Test increment on float
	campaign_variables.set_variable("float_counter", 1.5)
	assert_bool(campaign_variables.increment_variable("float_counter", 0.5)).is_true()
	assert_that(campaign_variables.get_float("float_counter")).is_equal(2.0)
	
	# Test increment on non-numeric (should fail)
	campaign_variables.set_variable("string_var", "hello")
	assert_bool(campaign_variables.increment_variable("string_var")).is_false()

func test_append_to_array() -> void:
	# Test append to array
	campaign_variables.set_variable("array_var", [1, 2, 3])
	assert_bool(campaign_variables.append_to_array("array_var", 4)).is_true()
	
	var array_result: Array = campaign_variables.get_variable("array_var")
	assert_that(array_result).contains_exactly([1, 2, 3, 4])
	
	# Test append to non-array (should fail)
	campaign_variables.set_variable("not_array", "string")
	assert_bool(campaign_variables.append_to_array("not_array", "value")).is_false()

func test_delete_variable() -> void:
	# Test delete variable
	campaign_variables.set_variable("to_delete", "value")
	assert_bool(campaign_variables.has_variable("to_delete")).is_true()
	
	assert_bool(campaign_variables.delete_variable("to_delete")).is_true()
	assert_bool(campaign_variables.has_variable("to_delete")).is_false()
	
	# Test delete non-existent variable
	assert_bool(campaign_variables.delete_variable("nonexistent")).is_false()

func test_clear_variables_by_scope() -> void:
	# Set up variables with different scopes
	campaign_variables.set_variable("global1", "value", CampaignVariables.VariableScope.GLOBAL)
	campaign_variables.set_variable("global2", "value", CampaignVariables.VariableScope.GLOBAL)
	campaign_variables.set_variable("mission1", "value", CampaignVariables.VariableScope.MISSION)
	campaign_variables.set_variable("mission2", "value", CampaignVariables.VariableScope.MISSION)
	campaign_variables.set_variable("campaign1", "value", CampaignVariables.VariableScope.CAMPAIGN)
	
	# Clear mission variables
	var cleared_count: int = campaign_variables.clear_variables_by_scope(CampaignVariables.VariableScope.MISSION)
	assert_that(cleared_count).is_equal(2)
	
	# Verify mission variables are gone, others remain
	assert_bool(campaign_variables.has_variable("mission1")).is_false()
	assert_bool(campaign_variables.has_variable("mission2")).is_false()
	assert_bool(campaign_variables.has_variable("global1")).is_true()
	assert_bool(campaign_variables.has_variable("campaign1")).is_true()

# --- Variable Name Validation ---

func test_variable_name_validation() -> void:
	# Valid names should work
	assert_bool(campaign_variables.set_variable("valid_name", "value")).is_true()
	assert_bool(campaign_variables.set_variable("ValidName", "value")).is_true()
	assert_bool(campaign_variables.set_variable("valid-name", "value")).is_true()
	assert_bool(campaign_variables.set_variable("name123", "value")).is_true()
	
	# Invalid names should fail
	assert_bool(campaign_variables.set_variable("", "value")).is_false()  # Empty
	assert_bool(campaign_variables.set_variable("123invalid", "value")).is_false()  # Starts with number
	assert_bool(campaign_variables.set_variable("invalid name", "value")).is_false()  # Contains space
	assert_bool(campaign_variables.set_variable("invalid@name", "value")).is_false()  # Invalid character

func test_system_variable_protection() -> void:
	# System variables should be write-protected
	assert_bool(campaign_variables.set_variable("_system_variable", "value")).is_false()
	assert_bool(campaign_variables.set_variable("_internal_var", "value")).is_false()

# --- Type Information ---

func test_get_variable_type() -> void:
	campaign_variables.set_variable("int_var", 42)
	campaign_variables.set_variable("float_var", 3.14)
	campaign_variables.set_variable("bool_var", true)
	campaign_variables.set_variable("string_var", "hello")
	campaign_variables.set_variable("array_var", [1, 2, 3])
	campaign_variables.set_variable("dict_var", {"key": "value"})
	
	assert_that(campaign_variables.get_variable_type("int_var")).is_equal(CampaignVariables.VariableType.INTEGER)
	assert_that(campaign_variables.get_variable_type("float_var")).is_equal(CampaignVariables.VariableType.FLOAT)
	assert_that(campaign_variables.get_variable_type("bool_var")).is_equal(CampaignVariables.VariableType.BOOLEAN)
	assert_that(campaign_variables.get_variable_type("string_var")).is_equal(CampaignVariables.VariableType.STRING)
	assert_that(campaign_variables.get_variable_type("array_var")).is_equal(CampaignVariables.VariableType.ARRAY)
	assert_that(campaign_variables.get_variable_type("dict_var")).is_equal(CampaignVariables.VariableType.DICTIONARY)

# --- Variable Change Tracking ---

func test_variable_change_signal() -> void:
	var signal_received: bool = false
	var received_name: String = ""
	var received_new_value: Variant = null
	var received_old_value: Variant = null
	
	# Connect to signal
	campaign_variables.variable_changed.connect(func(name: String, new_value: Variant, old_value: Variant, scope: CampaignVariables.VariableScope):
		signal_received = true
		received_name = name
		received_new_value = new_value
		received_old_value = old_value
	)
	
	# Set variable should emit signal
	campaign_variables.set_variable("test_var", "new_value")
	
	assert_bool(signal_received).is_true()
	assert_that(received_name).is_equal("test_var")
	assert_that(received_new_value).is_equal("new_value")
	assert_that(received_old_value).is_equal(null)
	
	# Update variable should emit signal with old value
	signal_received = false
	campaign_variables.set_variable("test_var", "updated_value")
	
	assert_bool(signal_received).is_true()
	assert_that(received_new_value).is_equal("updated_value")
	assert_that(received_old_value).is_equal("new_value")

# --- Import/Export ---

func test_export_import_variables() -> void:
	# Set up test variables
	campaign_variables.set_variable("test_int", 42)
	campaign_variables.set_variable("test_string", "hello")
	campaign_variables.set_variable("test_array", [1, 2, 3])
	
	# Export variables
	var exported_data: Dictionary = campaign_variables.export_variables_to_dict()
	assert_that(exported_data).contains_keys(["variables", "metadata"])
	
	# Create new instance and import
	var new_variables: CampaignVariables = CampaignVariables.new()
	assert_bool(new_variables.import_variables_from_dict(exported_data)).is_true()
	
	# Verify imported variables
	assert_that(new_variables.get_variable("test_int")).is_equal(42)
	assert_that(new_variables.get_variable("test_string")).is_equal("hello")
	assert_that(new_variables.get_variable("test_array")).contains_exactly([1, 2, 3])

# --- CampaignState Integration ---

func test_campaign_state_integration() -> void:
	# Set variables through campaign variables
	campaign_variables.set_variable("campaign_var", "campaign_value", CampaignVariables.VariableScope.CAMPAIGN)
	campaign_variables.set_variable("mission_var", "mission_value", CampaignVariables.VariableScope.MISSION)
	
	# Verify they are reflected in CampaignState
	assert_that(mock_campaign_state.get_variable("campaign_var")).is_equal("campaign_value")
	assert_that(mock_campaign_state.get_variable("mission_var")).is_equal("mission_value")
	
	# Set variable directly in CampaignState
	mock_campaign_state.set_variable("direct_var", "direct_value", true)
	
	# Verify it's accessible through campaign variables
	assert_that(campaign_variables.get_variable("direct_var")).is_equal("direct_value")

# --- Static Access Methods ---

func test_static_access() -> void:
	# Test static access methods
	assert_bool(CampaignVariables.set_global_variable("static_test", "static_value")).is_true()
	assert_that(CampaignVariables.get_global_variable("static_test")).is_equal("static_value")
	assert_bool(CampaignVariables.has_global_variable("static_test")).is_true()

# --- Error Handling ---

func test_error_handling_without_instance() -> void:
	# Clear instance to test error handling
	CampaignVariables.instance = null
	
	# Static methods should handle missing instance gracefully
	assert_bool(CampaignVariables.set_global_variable("test", "value")).is_false()
	assert_that(CampaignVariables.get_global_variable("test", "default")).is_equal("default")
	assert_bool(CampaignVariables.has_global_variable("test")).is_false()

func test_get_all_variable_names() -> void:
	# Set up test variables
	campaign_variables.set_variable("var1", "value1")
	campaign_variables.set_variable("var2", "value2")
	campaign_variables.set_variable("var3", "value3")
	
	var names: Array[String] = campaign_variables.get_variable_names()
	assert_that(names).contains("var1")
	assert_that(names).contains("var2")
	assert_that(names).contains("var3")

# --- Complex Type Handling ---

func test_complex_array_operations() -> void:
	# Test nested array operations
	var complex_array: Array = [
		{"name": "item1", "value": 10},
		{"name": "item2", "value": 20},
		[1, 2, 3]
	]
	
	campaign_variables.set_variable("complex_array", complex_array)
	var retrieved: Array = campaign_variables.get_variable("complex_array")
	
	assert_that(retrieved).has_size(3)
	assert_that(retrieved[0]).is_same(complex_array[0])
	assert_that(retrieved[2]).contains_exactly([1, 2, 3])

func test_complex_dictionary_operations() -> void:
	# Test nested dictionary operations
	var complex_dict: Dictionary = {
		"metadata": {
			"version": 1,
			"created": "2024-01-01"
		},
		"data": [1, 2, 3, 4],
		"settings": {
			"enabled": true,
			"level": 5
		}
	}
	
	campaign_variables.set_variable("complex_dict", complex_dict)
	var retrieved: Dictionary = campaign_variables.get_variable("complex_dict")
	
	assert_that(retrieved["metadata"]["version"]).is_equal(1)
	assert_that(retrieved["data"]).contains_exactly([1, 2, 3, 4])
	assert_that(retrieved["settings"]["enabled"]).is_equal(true)