extends GdUnitTestSuite

## Test suite for PilotCreationController
## Validates pilot creation UI, validation, and form handling functionality
## Tests integration with PilotDataManager and UI theme system

# Test objects
var creation_controller: PilotCreationController = null
var test_scene: Node = null
var mock_theme_manager: UIThemeManager = null
var test_pilots: Array[String] = []

func before_test() -> void:
	"""Setup before each test."""
	# Create test scene
	test_scene = Node.new()
	add_child(test_scene)
	
	# Create mock theme manager
	mock_theme_manager = UIThemeManager.new()
	mock_theme_manager.add_to_group("ui_theme_manager")
	test_scene.add_child(mock_theme_manager)
	
	# Create creation controller
	creation_controller = PilotCreationController.new()
	test_scene.add_child(creation_controller)
	
	# Clear test pilots list
	test_pilots.clear()

func after_test() -> void:
	"""Cleanup after each test."""
	# Clean up test pilots
	for callsign in test_pilots:
		var file_path: String = "user://test_pilots/" + callsign + ".tres"
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	
	if test_scene:
		test_scene.queue_free()
	
	creation_controller = null
	mock_theme_manager = null

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_creation_controller_initializes_correctly() -> void:
	"""Test that PilotCreationController initializes properly."""
	# Act
	creation_controller._ready()
	
	# Assert
	assert_object(creation_controller.main_container).is_not_null()
	assert_object(creation_controller.title_label).is_not_null()
	assert_object(creation_controller.creation_form).is_not_null()
	assert_object(creation_controller.button_container).is_not_null()

func test_ui_components_created() -> void:
	"""Test that UI components are created correctly."""
	# Act
	creation_controller._ready()
	
	# Assert
	assert_object(creation_controller.callsign_input).is_not_null()
	assert_object(creation_controller.callsign_validation_label).is_not_null()
	assert_object(creation_controller.create_button).is_not_null()
	assert_object(creation_controller.cancel_button).is_not_null()

func test_squadron_input_created_when_enabled() -> void:
	"""Test that squadron input is created when enabled."""
	# Arrange
	creation_controller.enable_squadron_selection = true
	
	# Act
	creation_controller._ready()
	
	# Assert
	assert_object(creation_controller.squadron_input).is_not_null()

func test_portrait_selection_created_when_enabled() -> void:
	"""Test that portrait selection is created when enabled."""
	# Arrange
	creation_controller.enable_portrait_selection = true
	
	# Act
	creation_controller._ready()
	
	# Assert
	assert_object(creation_controller.portrait_container).is_not_null()
	assert_object(creation_controller.portrait_grid).is_not_null()

func test_preview_panel_created_when_enabled() -> void:
	"""Test that preview panel is created when enabled."""
	# Arrange
	creation_controller.show_preview_panel = true
	
	# Act
	creation_controller._ready()
	
	# Assert
	assert_object(creation_controller.preview_panel).is_not_null()
	assert_object(creation_controller.preview_callsign).is_not_null()
	assert_object(creation_controller.preview_squadron).is_not_null()

# ============================================================================
# CALLSIGN VALIDATION TESTS
# ============================================================================

func test_validate_callsign_valid() -> void:
	"""Test callsign validation with valid inputs."""
	# Arrange
	creation_controller._ready()
	var valid_callsigns: Array[String] = [
		"Alpha",
		"Test_Pilot",
		"Test-Pilot",
		"Test Pilot",
		"Pilot123"
	]
	
	for callsign in valid_callsigns:
		# Act
		var validation_result: Dictionary = creation_controller._validate_callsign(callsign)
		
		# Assert
		assert_bool(validation_result.valid).is_true()

func test_validate_callsign_invalid() -> void:
	"""Test callsign validation with invalid inputs."""
	# Arrange
	creation_controller._ready()
	var invalid_callsigns: Array[String] = [
		"",  # Empty
		"Very Long Pilot Name That Exceeds Maximum Length",  # Too long
		"Test@Pilot",  # Invalid character
		"Test\nPilot"  # Newline
	]
	
	for callsign in invalid_callsigns:
		# Act
		var validation_result: Dictionary = creation_controller._validate_callsign(callsign)
		
		# Assert
		assert_bool(validation_result.valid).is_false()
		assert_str(validation_result.message).is_not_empty()

func test_callsign_input_triggers_validation() -> void:
	"""Test that callsign input triggers validation."""
	# Arrange
	creation_controller._ready()
	
	# Act
	creation_controller.callsign_input.text = "TestPilot"
	creation_controller._on_callsign_changed("TestPilot")
	
	# Assert
	assert_bool(creation_controller.callsign_valid).is_true()
	assert_bool(creation_controller.create_button.disabled).is_false()

func test_invalid_callsign_disables_create_button() -> void:
	"""Test that invalid callsign disables create button."""
	# Arrange
	creation_controller._ready()
	
	# Act
	creation_controller.callsign_input.text = ""
	creation_controller._on_callsign_changed("")
	
	# Assert
	assert_bool(creation_controller.callsign_valid).is_false()
	assert_bool(creation_controller.create_button.disabled).is_true()

# ============================================================================
# FORM VALIDATION TESTS
# ============================================================================

func test_validate_all_inputs() -> void:
	"""Test complete form validation."""
	# Arrange
	creation_controller._ready()
	
	# Act - Set valid inputs
	creation_controller.callsign_input.text = "ValidPilot"
	creation_controller._validate_all_inputs()
	
	# Assert
	assert_bool(creation_controller.callsign_valid).is_true()
	assert_bool(creation_controller.squadron_valid).is_true()
	assert_bool(creation_controller.create_button.disabled).is_false()

func test_form_validation_with_squadron() -> void:
	"""Test form validation with squadron input."""
	# Arrange
	creation_controller.enable_squadron_selection = true
	creation_controller._ready()
	
	# Act
	creation_controller.callsign_input.text = "ValidPilot"
	creation_controller.squadron_input.text = "Test Squadron"
	creation_controller._validate_all_inputs()
	
	# Assert
	assert_bool(creation_controller.callsign_valid).is_true()
	assert_bool(creation_controller.squadron_valid).is_true()

func test_form_validation_updates_preview() -> void:
	"""Test that form validation updates preview."""
	# Arrange
	creation_controller.show_preview_panel = true
	creation_controller._ready()
	
	# Act
	creation_controller.callsign_input.text = "PreviewTest"
	creation_controller._validate_all_inputs()
	
	# Assert
	assert_str(creation_controller.preview_callsign.text).is_equal("PreviewTest")

# ============================================================================
# PORTRAIT SELECTION TESTS
# ============================================================================

func test_portrait_selection() -> void:
	"""Test portrait selection functionality."""
	# Arrange
	creation_controller.enable_portrait_selection = true
	creation_controller._ready()
	
	# Act
	creation_controller._on_portrait_selected("test_portrait.png")
	
	# Assert
	assert_str(creation_controller.selected_portrait).is_equal("test_portrait.png")

func test_portrait_selection_updates_preview() -> void:
	"""Test that portrait selection updates preview."""
	# Arrange
	creation_controller.enable_portrait_selection = true
	creation_controller.show_preview_panel = true
	creation_controller._ready()
	
	# Mock portrait texture
	var test_texture: ImageTexture = ImageTexture.new()
	var test_image: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	test_image.fill(Color.RED)
	test_texture.set_image(test_image)
	creation_controller.portrait_textures["test_portrait.png"] = test_texture
	
	# Act
	creation_controller._on_portrait_selected("test_portrait.png")
	creation_controller._validate_all_inputs()
	
	# Assert
	assert_object(creation_controller.preview_image.texture).is_equal(test_texture)

# ============================================================================
# PILOT CREATION TESTS
# ============================================================================

func test_create_pilot_success() -> void:
	"""Test successful pilot creation."""
	# Arrange
	creation_controller._ready()
	creation_controller.callsign_input.text = "CreateTest"
	creation_controller.squadron_input.text = "Test Squadron"
	creation_controller._validate_all_inputs()
	test_pilots.append("CreateTest")
	
	var signal_monitor: SignalWatcher = watch_signals(creation_controller)
	
	# Act
	creation_controller._on_create_pilot_pressed()
	
	# Assert
	assert_signal(signal_monitor).is_emitted("pilot_creation_completed")

func test_create_pilot_with_invalid_form() -> void:
	"""Test pilot creation attempt with invalid form."""
	# Arrange
	creation_controller._ready()
	creation_controller.callsign_input.text = ""  # Invalid
	creation_controller._validate_all_inputs()
	
	var signal_monitor: SignalWatcher = watch_signals(creation_controller)
	
	# Act
	creation_controller._on_create_pilot_pressed()
	
	# Assert - Should not emit completion signal
	assert_signal(signal_monitor).is_not_emitted("pilot_creation_completed")

func test_callsign_submission_creates_pilot() -> void:
	"""Test that Enter key in callsign field creates pilot."""
	# Arrange
	creation_controller._ready()
	creation_controller.callsign_input.text = "EnterTest"
	creation_controller._validate_all_inputs()
	test_pilots.append("EnterTest")
	
	var signal_monitor: SignalWatcher = watch_signals(creation_controller)
	
	# Act
	creation_controller._on_callsign_submitted("EnterTest")
	
	# Assert
	assert_signal(signal_monitor).is_emitted("pilot_creation_completed")

# ============================================================================
# FORM MANAGEMENT TESTS
# ============================================================================

func test_reset_form() -> void:
	"""Test form reset functionality."""
	# Arrange
	creation_controller._ready()
	creation_controller.callsign_input.text = "TestPilot"
	creation_controller.squadron_input.text = "Test Squadron"
	creation_controller.selected_portrait = "test.png"
	
	# Act
	creation_controller.reset_form()
	
	# Assert
	assert_str(creation_controller.callsign_input.text).is_empty()
	assert_str(creation_controller.squadron_input.text).is_empty()
	assert_str(creation_controller.selected_portrait).is_empty()

func test_get_form_data() -> void:
	"""Test getting form data."""
	# Arrange
	creation_controller._ready()
	creation_controller.callsign_input.text = "DataTest"
	creation_controller.squadron_input.text = "Data Squadron"
	creation_controller.selected_portrait = "data.png"
	
	# Act
	var form_data: Dictionary = creation_controller.get_form_data()
	
	# Assert
	assert_dict(form_data).contains_keys(["callsign", "squadron", "portrait"])
	assert_str(form_data["callsign"]).is_equal("DataTest")
	assert_str(form_data["squadron"]).is_equal("Data Squadron")
	assert_str(form_data["portrait"]).is_equal("data.png")

func test_set_form_data() -> void:
	"""Test setting form data."""
	# Arrange
	creation_controller._ready()
	var test_data: Dictionary = {
		"callsign": "SetTest",
		"squadron": "Set Squadron",
		"portrait": "set.png"
	}
	
	# Act
	creation_controller.set_form_data(test_data)
	
	# Assert
	assert_str(creation_controller.callsign_input.text).is_equal("SetTest")
	assert_str(creation_controller.squadron_input.text).is_equal("Set Squadron")
	assert_str(creation_controller.selected_portrait).is_equal("set.png")

func test_is_form_valid() -> void:
	"""Test form validity checking."""
	# Arrange
	creation_controller._ready()
	
	# Act & Assert - Invalid form
	creation_controller.callsign_input.text = ""
	creation_controller._validate_all_inputs()
	assert_bool(creation_controller.is_form_valid()).is_false()
	
	# Act & Assert - Valid form
	creation_controller.callsign_input.text = "ValidTest"
	creation_controller._validate_all_inputs()
	assert_bool(creation_controller.is_form_valid()).is_true()

# ============================================================================
# SIGNAL HANDLING TESTS
# ============================================================================

func test_cancel_button_emits_signal() -> void:
	"""Test that cancel button emits cancellation signal."""
	# Arrange
	creation_controller._ready()
	var signal_monitor: SignalWatcher = watch_signals(creation_controller)
	
	# Act
	creation_controller._on_cancel_pressed()
	
	# Assert
	assert_signal(signal_monitor).is_emitted("pilot_creation_cancelled")

func test_validation_error_signal() -> void:
	"""Test validation error signal emission."""
	# Arrange
	creation_controller._ready()
	var signal_monitor: SignalWatcher = watch_signals(creation_controller)
	
	# Act
	creation_controller._on_pilot_manager_validation_error("Test error")
	
	# Assert
	assert_signal(signal_monitor).is_emitted("validation_error")

# ============================================================================
# UI STATE TESTS
# ============================================================================

func test_create_button_initial_state() -> void:
	"""Test that create button is initially disabled."""
	# Act
	creation_controller._ready()
	
	# Assert
	assert_bool(creation_controller.create_button.disabled).is_true()

func test_validation_label_updates() -> void:
	"""Test that validation label updates with feedback."""
	# Arrange
	creation_controller._ready()
	
	# Act - Valid input
	creation_controller.callsign_input.text = "ValidTest"
	creation_controller._validate_all_inputs()
	
	# Assert
	assert_str(creation_controller.callsign_validation_label.text).contains("valid")

func test_theme_manager_integration() -> void:
	"""Test integration with UIThemeManager."""
	# Arrange & Act
	creation_controller._ready()
	
	# Assert
	assert_object(creation_controller.ui_theme_manager).is_not_null()

# ============================================================================
# PORTRAIT GRID TESTS
# ============================================================================

func test_portrait_grid_population() -> void:
	"""Test that portrait grid is populated."""
	# Arrange
	creation_controller.enable_portrait_selection = true
	
	# Act
	creation_controller._ready()
	
	# Assert
	assert_object(creation_controller.portrait_grid).is_not_null()
	# Should have at least default portraits
	assert_int(creation_controller.portrait_grid.get_child_count()).is_greater(0)

func test_default_portraits_creation() -> void:
	"""Test creation of default portraits when none found."""
	# Arrange
	creation_controller.enable_portrait_selection = true
	
	# Act
	creation_controller._create_default_portraits()
	
	# Assert
	assert_int(creation_controller.available_portraits.size()).is_greater(0)
	assert_dict(creation_controller.portrait_textures).is_not_empty()

func test_image_file_detection() -> void:
	"""Test image file extension detection."""
	# Arrange
	var image_files: Array[String] = ["test.png", "pilot.jpg", "avatar.jpeg", "icon.bmp"]
	var non_image_files: Array[String] = ["test.txt", "pilot.doc", "avatar.mp3"]
	
	# Act & Assert - Image files
	for file in image_files:
		assert_bool(creation_controller._is_image_file(file)).is_true()
	
	# Act & Assert - Non-image files
	for file in non_image_files:
		assert_bool(creation_controller._is_image_file(file)).is_false()

# ============================================================================
# PREVIEW PANEL TESTS
# ============================================================================

func test_preview_update() -> void:
	"""Test preview panel updates."""
	# Arrange
	creation_controller.show_preview_panel = true
	creation_controller._ready()
	
	# Act
	creation_controller.callsign_input.text = "PreviewPilot"
	creation_controller.squadron_input.text = "Preview Squadron"
	creation_controller._update_preview()
	
	# Assert
	assert_str(creation_controller.preview_callsign.text).is_equal("PreviewPilot")
	assert_str(creation_controller.preview_squadron.text).is_equal("Preview Squadron")

func test_preview_with_empty_data() -> void:
	"""Test preview panel with empty data."""
	# Arrange
	creation_controller.show_preview_panel = true
	creation_controller._ready()
	
	# Act
	creation_controller._update_preview()
	
	# Assert
	assert_str(creation_controller.preview_callsign.text).is_equal("<not set>")
	assert_str(creation_controller.preview_squadron.text).is_equal("Unassigned")

# ============================================================================
# CONFIGURATION TESTS
# ============================================================================

func test_configuration_options() -> void:
	"""Test configuration option effects."""
	# Test portrait selection disabled
	creation_controller.enable_portrait_selection = false
	creation_controller._ready()
	assert_object(creation_controller.portrait_container).is_null()
	
	# Reset and test squadron selection disabled
	creation_controller.queue_free()
	creation_controller = PilotCreationController.new()
	test_scene.add_child(creation_controller)
	creation_controller.enable_squadron_selection = false
	creation_controller._ready()
	assert_object(creation_controller.squadron_container).is_null()
	
	# Reset and test preview panel disabled
	creation_controller.queue_free()
	creation_controller = PilotCreationController.new()
	test_scene.add_child(creation_controller)
	creation_controller.show_preview_panel = false
	creation_controller._ready()
	assert_object(creation_controller.preview_panel).is_null()

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_pilot_manager_integration() -> void:
	"""Test integration with PilotDataManager."""
	# Arrange
	creation_controller._ready()
	
	# Assert
	assert_object(creation_controller.pilot_manager).is_not_null()

func test_theme_change_handling() -> void:
	"""Test handling of theme changes."""
	# Arrange
	creation_controller._ready()
	
	# Act & Assert - Should not crash
	creation_controller._on_theme_changed("new_theme")

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

func test_handles_missing_ui_components() -> void:
	"""Test graceful handling of missing UI components."""
	# Arrange
	creation_controller.show_preview_panel = false
	creation_controller.enable_portrait_selection = false
	creation_controller.enable_squadron_selection = false
	
	# Act & Assert - Should not crash
	creation_controller._ready()
	creation_controller._validate_all_inputs()

func test_handles_portrait_loading_errors() -> void:
	"""Test handling of portrait loading errors."""
	# Arrange
	creation_controller.enable_portrait_selection = true
	
	# Act & Assert - Should not crash when portrait directory doesn't exist
	creation_controller._ready()
	
	# Should have default portraits
	assert_int(creation_controller.available_portraits.size()).is_greater(0)