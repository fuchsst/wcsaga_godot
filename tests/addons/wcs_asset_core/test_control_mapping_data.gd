class_name TestControlMappingData
extends GdUnitTestSuite

## Unit tests for ControlMappingData class.
## Tests input binding management, conflict detection, device settings, and validation.

var control_mapping: ControlMappingData

func before_each() -> void:
	"""Set up fresh ControlMappingData instance for each test."""
	control_mapping = ControlMappingData.new()

func after_each() -> void:
	"""Clean up after each test."""
	control_mapping = null

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_initialization() -> void:
	"""Test that ControlMappingData initializes with correct defaults."""
	assert_that(control_mapping).is_not_null()
	assert_that(control_mapping.data_type).is_equal("ControlMappingData")
	assert_that(control_mapping.mouse_sensitivity).is_equal(1.0)
	assert_that(control_mapping.gamepad_sensitivity).is_equal(1.0)
	assert_that(control_mapping.mouse_deadzone).is_equal(0.1)
	assert_that(control_mapping.gamepad_deadzone).is_equal(0.2)

func test_default_controls_initialized() -> void:
	"""Test that default control mappings are initialized."""
	assert_that(control_mapping.targeting_controls).is_not_empty()
	assert_that(control_mapping.ship_controls).is_not_empty()
	assert_that(control_mapping.weapon_controls).is_not_empty()
	assert_that(control_mapping.computer_controls).is_not_empty()
	assert_that(control_mapping.camera_controls).is_not_empty()
	assert_that(control_mapping.communication_controls).is_not_empty()

func test_default_targeting_controls() -> void:
	"""Test that default targeting controls are properly set."""
	assert_that(control_mapping.targeting_controls.has("target_next")).is_true()
	assert_that(control_mapping.targeting_controls.has("target_previous")).is_true()
	assert_that(control_mapping.targeting_controls.has("target_closest_enemy")).is_true()
	assert_that(control_mapping.targeting_controls.has("clear_target")).is_true()

func test_default_ship_controls() -> void:
	"""Test that default ship controls are properly set."""
	assert_that(control_mapping.ship_controls.has("pitch_up")).is_true()
	assert_that(control_mapping.ship_controls.has("pitch_down")).is_true()
	assert_that(control_mapping.ship_controls.has("yaw_left")).is_true()
	assert_that(control_mapping.ship_controls.has("yaw_right")).is_true()
	assert_that(control_mapping.ship_controls.has("throttle_up")).is_true()
	assert_that(control_mapping.ship_controls.has("afterburner")).is_true()

func test_default_weapon_controls() -> void:
	"""Test that default weapon controls are properly set."""
	assert_that(control_mapping.weapon_controls.has("fire_primary")).is_true()
	assert_that(control_mapping.weapon_controls.has("fire_secondary")).is_true()
	assert_that(control_mapping.weapon_controls.has("cycle_primary")).is_true()
	assert_that(control_mapping.weapon_controls.has("launch_countermeasure")).is_true()

# ============================================================================
# INPUT BINDING TESTS
# ============================================================================

func test_input_binding_creation() -> void:
	"""Test InputBinding creation and validation."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	
	assert_that(binding).is_not_null()
	assert_that(binding.key).is_equal(KEY_SPACE)
	assert_that(binding.is_valid()).is_true()

func test_input_binding_with_modifiers() -> void:
	"""Test InputBinding with modifier keys."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_T, KEY_SHIFT)
	
	assert_that(binding.key).is_equal(KEY_T)
	assert_that(binding.modifiers).is_equal(KEY_SHIFT)
	assert_that(binding.is_valid()).is_true()

func test_mouse_button_binding() -> void:
	"""Test InputBinding with mouse buttons."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, MOUSE_BUTTON_LEFT)
	
	assert_that(binding.mouse_button).is_equal(MOUSE_BUTTON_LEFT)
	assert_that(binding.is_valid()).is_true()

func test_gamepad_button_binding() -> void:
	"""Test InputBinding with gamepad buttons."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, JOY_BUTTON_A)
	
	assert_that(binding.gamepad_button).is_equal(JOY_BUTTON_A)
	assert_that(binding.is_valid()).is_true()

func test_gamepad_axis_binding() -> void:
	"""Test InputBinding with gamepad axis."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, -1, JOY_AXIS_LEFT_X, 1)
	
	assert_that(binding.gamepad_axis).is_equal(JOY_AXIS_LEFT_X)
	assert_that(binding.axis_direction).is_equal(1)
	assert_that(binding.is_valid()).is_true()

func test_invalid_binding() -> void:
	"""Test that empty InputBinding is invalid."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new()
	
	assert_that(binding.is_valid()).is_false()

# ============================================================================
# CONFLICT DETECTION TESTS
# ============================================================================

func test_keyboard_conflict_detection() -> void:
	"""Test detection of keyboard binding conflicts."""
	var binding1: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	var binding2: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	
	assert_that(binding1.has_conflicts_with(binding2)).is_true()

func test_keyboard_modifier_conflict() -> void:
	"""Test that modifier keys are considered in conflicts."""
	var binding1: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_T)
	var binding2: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_T, KEY_SHIFT)
	
	assert_that(binding1.has_conflicts_with(binding2)).is_false()

func test_mouse_conflict_detection() -> void:
	"""Test detection of mouse button conflicts."""
	var binding1: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, MOUSE_BUTTON_LEFT)
	var binding2: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, MOUSE_BUTTON_LEFT)
	
	assert_that(binding1.has_conflicts_with(binding2)).is_true()

func test_gamepad_button_conflict() -> void:
	"""Test detection of gamepad button conflicts."""
	var binding1: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, JOY_BUTTON_A)
	var binding2: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, JOY_BUTTON_A)
	
	assert_that(binding1.has_conflicts_with(binding2)).is_true()

func test_gamepad_axis_conflict() -> void:
	"""Test detection of gamepad axis conflicts."""
	var binding1: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, -1, JOY_AXIS_LEFT_X, 1)
	var binding2: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, -1, JOY_AXIS_LEFT_X, 1)
	
	assert_that(binding1.has_conflicts_with(binding2)).is_true()

func test_different_axis_directions_no_conflict() -> void:
	"""Test that different axis directions don't conflict."""
	var binding1: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, -1, JOY_AXIS_LEFT_X, 1)
	var binding2: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, -1, JOY_AXIS_LEFT_X, -1)
	
	assert_that(binding1.has_conflicts_with(binding2)).is_false()

func test_different_devices_no_conflict() -> void:
	"""Test that different device IDs don't conflict."""
	var binding1: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, JOY_BUTTON_A, -1, 0, 0)
	var binding2: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, JOY_BUTTON_A, -1, 0, 1)
	
	assert_that(binding1.has_conflicts_with(binding2)).is_false()

func test_cross_input_type_no_conflict() -> void:
	"""Test that different input types don't conflict."""
	var keyboard_binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	var mouse_binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, MOUSE_BUTTON_LEFT)
	
	assert_that(keyboard_binding.has_conflicts_with(mouse_binding)).is_false()

# ============================================================================
# STRING REPRESENTATION TESTS
# ============================================================================

func test_keyboard_binding_string() -> void:
	"""Test string representation of keyboard bindings."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	var binding_str: String = binding.to_string()
	
	assert_that(binding_str).contains("Space")

func test_keyboard_with_modifiers_string() -> void:
	"""Test string representation with modifier keys."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_T, KEY_SHIFT | KEY_CTRL)
	var binding_str: String = binding.to_string()
	
	assert_that(binding_str).contains("Shift")
	assert_that(binding_str).contains("Ctrl")
	assert_that(binding_str).contains("T")

func test_mouse_binding_string() -> void:
	"""Test string representation of mouse bindings."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, MOUSE_BUTTON_LEFT)
	var binding_str: String = binding.to_string()
	
	assert_that(binding_str).contains("Left Click")

func test_gamepad_binding_string() -> void:
	"""Test string representation of gamepad bindings."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, JOY_BUTTON_A)
	var binding_str: String = binding.to_string()
	
	assert_that(binding_str).contains("Gamepad Button")

func test_gamepad_axis_string() -> void:
	"""Test string representation of gamepad axis bindings."""
	var binding_positive: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, -1, JOY_AXIS_LEFT_X, 1)
	var binding_negative: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(-1, 0, -1, -1, JOY_AXIS_LEFT_X, -1)
	
	assert_that(binding_positive.to_string()).contains("Gamepad Axis")
	assert_that(binding_positive.to_string()).contains("+")
	assert_that(binding_negative.to_string()).contains("-")

func test_empty_binding_string() -> void:
	"""Test string representation of empty binding."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new()
	
	assert_that(binding.to_string()).is_equal("None")

# ============================================================================
# SERIALIZATION TESTS
# ============================================================================

func test_binding_serialization() -> void:
	"""Test InputBinding serialization to dictionary."""
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE, KEY_SHIFT)
	var data: Dictionary = binding.to_dictionary()
	
	assert_that(data.has("key")).is_true()
	assert_that(data.has("modifiers")).is_true()
	assert_that(data["key"]).is_equal(KEY_SPACE)
	assert_that(data["modifiers"]).is_equal(KEY_SHIFT)

func test_binding_deserialization() -> void:
	"""Test InputBinding deserialization from dictionary."""
	var data: Dictionary = {
		"key": KEY_T,
		"modifiers": KEY_CTRL,
		"mouse_button": -1,
		"gamepad_button": -1,
		"gamepad_axis": -1,
		"axis_direction": 0,
		"device_id": 0
	}
	
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new()
	binding.from_dictionary(data)
	
	assert_that(binding.key).is_equal(KEY_T)
	assert_that(binding.modifiers).is_equal(KEY_CTRL)
	assert_that(binding.mouse_button).is_equal(-1)

# ============================================================================
# VALIDATION TESTS
# ============================================================================

func test_valid_default_settings() -> void:
	"""Test that default settings are valid."""
	assert_that(control_mapping.is_valid()).is_true()

func test_sensitivity_range_validation() -> void:
	"""Test that sensitivity values must be within valid range."""
	control_mapping.mouse_sensitivity = 0.05  # Too low
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.mouse_sensitivity = 15.0  # Too high
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.mouse_sensitivity = 2.0  # Valid
	assert_that(control_mapping.is_valid()).is_true()

func test_deadzone_range_validation() -> void:
	"""Test that deadzone values must be within 0.0-1.0 range."""
	control_mapping.mouse_deadzone = -0.1  # Invalid: negative
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.mouse_deadzone = 1.5  # Invalid: too high
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.mouse_deadzone = 0.3  # Valid
	assert_that(control_mapping.is_valid()).is_true()

func test_acceleration_range_validation() -> void:
	"""Test that mouse acceleration must be within valid range."""
	control_mapping.mouse_acceleration = 0.05  # Too low
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.mouse_acceleration = 6.0  # Too high
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.mouse_acceleration = 2.0  # Valid
	assert_that(control_mapping.is_valid()).is_true()

func test_vibration_strength_validation() -> void:
	"""Test that vibration strength must be within 0.0-1.0 range."""
	control_mapping.gamepad_vibration_strength = -0.1  # Invalid
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.gamepad_vibration_strength = 1.5  # Invalid
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.gamepad_vibration_strength = 0.8  # Valid
	assert_that(control_mapping.is_valid()).is_true()

func test_repeat_settings_validation() -> void:
	"""Test that repeat delay and rate must be within valid ranges."""
	control_mapping.repeat_delay = 0.05  # Too low
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.repeat_delay = 0.5  # Valid
	control_mapping.repeat_rate = 0.005  # Too low
	assert_that(control_mapping.is_valid()).is_false()
	
	control_mapping.repeat_rate = 0.1  # Valid
	assert_that(control_mapping.is_valid()).is_true()

# ============================================================================
# CONTROL MANAGEMENT TESTS
# ============================================================================

func test_get_controls_for_category() -> void:
	"""Test getting controls for specific categories."""
	var targeting_controls: Dictionary = control_mapping.get_controls_for_category(ControlMappingData.ControlCategory.TARGETING)
	var ship_controls: Dictionary = control_mapping.get_controls_for_category(ControlMappingData.ControlCategory.SHIP)
	
	assert_that(targeting_controls).is_not_empty()
	assert_that(ship_controls).is_not_empty()
	assert_that(targeting_controls.has("target_next")).is_true()
	assert_that(ship_controls.has("pitch_up")).is_true()

func test_get_category_name() -> void:
	"""Test category name retrieval."""
	assert_that(control_mapping.get_control_category_name(ControlMappingData.ControlCategory.TARGETING)).is_equal("Targeting")
	assert_that(control_mapping.get_control_category_name(ControlMappingData.ControlCategory.SHIP)).is_equal("Ship Movement")
	assert_that(control_mapping.get_control_category_name(ControlMappingData.ControlCategory.WEAPON)).is_equal("Weapons")

func test_get_all_bindings() -> void:
	"""Test getting all control bindings as flat dictionary."""
	var all_bindings: Dictionary = control_mapping.get_all_bindings()
	
	assert_that(all_bindings).is_not_empty()
	assert_that(all_bindings.has("target_next")).is_true()
	assert_that(all_bindings.has("pitch_up")).is_true()
	assert_that(all_bindings.has("fire_primary")).is_true()

func test_get_binding() -> void:
	"""Test getting specific binding by action name."""
	var target_binding: ControlMappingData.InputBinding = control_mapping.get_binding("target_next")
	
	assert_that(target_binding).is_not_null()
	assert_that(target_binding.is_valid()).is_true()

func test_set_binding() -> void:
	"""Test setting a specific binding."""
	var new_binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_F1)
	var success: bool = control_mapping.set_binding("target_next", new_binding)
	
	assert_that(success).is_true()
	
	var retrieved_binding: ControlMappingData.InputBinding = control_mapping.get_binding("target_next")
	assert_that(retrieved_binding.key).is_equal(KEY_F1)

func test_clear_binding() -> void:
	"""Test clearing a specific binding."""
	var success: bool = control_mapping.clear_binding("target_next")
	
	assert_that(success).is_true()
	
	var cleared_binding: ControlMappingData.InputBinding = control_mapping.get_binding("target_next")
	assert_that(cleared_binding.is_valid()).is_false()

func test_nonexistent_binding() -> void:
	"""Test operations with non-existent bindings."""
	var binding: ControlMappingData.InputBinding = control_mapping.get_binding("nonexistent_action")
	assert_that(binding.is_valid()).is_false()
	
	var success: bool = control_mapping.set_binding("nonexistent_action", ControlMappingData.InputBinding.new(KEY_F12))
	assert_that(success).is_false()

# ============================================================================
# CONFLICT DETECTION SYSTEM TESTS
# ============================================================================

func test_detect_conflicts() -> void:
	"""Test system-wide conflict detection."""
	# Create a conflict by setting two actions to the same key
	var binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_SPACE)
	control_mapping.set_binding("target_next", binding)
	control_mapping.set_binding("pitch_up", binding)  # Conflict!
	
	var conflicts: Array[Dictionary] = control_mapping.detect_conflicts()
	
	assert_that(conflicts).is_not_empty()
	assert_that(conflicts[0].has("action1")).is_true()
	assert_that(conflicts[0].has("action2")).is_true()

func test_no_conflicts_default() -> void:
	"""Test that default configuration has no conflicts."""
	var conflicts: Array[Dictionary] = control_mapping.detect_conflicts()
	
	# Default configuration should be conflict-free
	assert_that(conflicts).is_empty()

# ============================================================================
# CLONING TESTS
# ============================================================================

func test_clone() -> void:
	"""Test that cloning creates an independent copy."""
	control_mapping.mouse_sensitivity = 2.5
	control_mapping.gamepad_deadzone = 0.3
	
	var cloned: ControlMappingData = control_mapping.clone()
	
	assert_that(cloned).is_not_same(control_mapping)
	assert_that(cloned.mouse_sensitivity).is_equal(2.5)
	assert_that(cloned.gamepad_deadzone).is_equal(0.3)
	
	# Modify original, clone should be unchanged
	control_mapping.mouse_sensitivity = 1.0
	assert_that(cloned.mouse_sensitivity).is_equal(2.5)

func test_clone_preserves_bindings() -> void:
	"""Test that cloning preserves all control bindings."""
	var new_binding: ControlMappingData.InputBinding = ControlMappingData.InputBinding.new(KEY_F5)
	control_mapping.set_binding("target_next", new_binding)
	
	var cloned: ControlMappingData = control_mapping.clone()
	var cloned_binding: ControlMappingData.InputBinding = cloned.get_binding("target_next")
	
	assert_that(cloned_binding.key).is_equal(KEY_F5)
	
	# Modify original binding, clone should be unchanged
	control_mapping.set_binding("target_next", ControlMappingData.InputBinding.new(KEY_F6))
	assert_that(cloned_binding.key).is_equal(KEY_F5)

# ============================================================================
# RESET FUNCTIONALITY TESTS
# ============================================================================

func test_reset_to_defaults() -> void:
	"""Test resetting settings to default values."""
	# Modify settings
	control_mapping.mouse_sensitivity = 3.0
	control_mapping.gamepad_vibration_enabled = false
	control_mapping.set_binding("target_next", ControlMappingData.InputBinding.new(KEY_F12))
	
	# Reset to defaults
	control_mapping.reset_to_defaults()
	
	# Verify defaults are restored
	assert_that(control_mapping.mouse_sensitivity).is_equal(1.0)
	assert_that(control_mapping.gamepad_vibration_enabled).is_true()
	assert_that(control_mapping.is_valid()).is_true()
	
	# Check that default bindings are restored
	var target_binding: ControlMappingData.InputBinding = control_mapping.get_binding("target_next")
	assert_that(target_binding.key).is_equal(KEY_T)

# ============================================================================
# GODOT INPUT MAP EXPORT TESTS
# ============================================================================

func test_export_to_godot_input_map() -> void:
	"""Test export to Godot InputMap format."""
	var input_map: Dictionary = control_mapping.export_to_godot_input_map()
	
	assert_that(input_map).is_not_empty()
	assert_that(input_map.has("target_next")).is_true()
	assert_that(input_map.has("fire_primary")).is_true()

func test_exported_input_map_structure() -> void:
	"""Test that exported input map has correct structure."""
	var input_map: Dictionary = control_mapping.export_to_godot_input_map()
	
	# Check that each action has an array of events
	for action_name in input_map:
		var events: Array = input_map[action_name]
		assert_that(events).is_not_empty()
		
		for event in events:
			assert_that(event).is_instance_of(InputEvent)