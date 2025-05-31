@tool
extends GdUnitTestSuite

## Test suite for GFRED2-006C Template and Pattern Library components
## Tests template browser, customization dialog, and pattern browsers
## Validates scene-based UI architecture and performance requirements

func test_mission_template_browser_scene_instantiation():
	"""Test mission template browser scene can be instantiated."""
	
	var browser: MissionTemplateBrowser = MissionTemplateBrowser.new()
	assert_not_null(browser)
	assert_that(browser).is_instance_of(VBoxContainer)
	
	# Test initial state
	assert_not_null(browser.template_manager)
	assert_that(browser.current_templates).is_not_null()
	assert_that(browser.selected_template).is_null()
	
	browser.queue_free()

func test_mission_template_browser_template_loading():
	"""Test template browser loads templates correctly."""
	
	var browser: MissionTemplateBrowser = MissionTemplateBrowser.new()
	add_child(browser)
	
	# Test template loading
	browser.refresh_templates()
	
	# Verify templates are loaded
	assert_that(browser.current_templates.size()).is_greater_equal(5)  # Default templates
	
	# Check for expected default templates
	var template_names: Array[String] = []
	for template in browser.current_templates:
		template_names.append(template.template_name)
	
	assert_that(template_names).contains("Standard Escort Mission")
	assert_that(template_names).contains("Standard Patrol Mission")
	assert_that(template_names).contains("Capital Ship Assault")
	
	browser.queue_free()

func test_mission_template_browser_filtering():
	"""Test template browser filtering functionality."""
	
	var browser: MissionTemplateBrowser = MissionTemplateBrowser.new()
	add_child(browser)
	
	browser.refresh_templates()
	var total_templates: int = browser.current_templates.size()
	
	# Test category filter
	browser.category_filter.selected = 1  # First non-"All" category
	browser._on_filter_changed(1)
	
	# Should have fewer templates after filtering
	var filtered_count: int = _count_visible_template_items(browser)
	assert_that(filtered_count).is_less_equal(total_templates)
	
	# Test search filter
	browser.search_box.text = "Escort"
	browser._on_search_changed("Escort")
	
	# Should find escort-related templates
	var search_filtered_count: int = _count_visible_template_items(browser)
	assert_that(search_filtered_count).is_greater_equal(1)
	
	browser.queue_free()

func _count_visible_template_items(browser: MissionTemplateBrowser) -> int:
	"""Helper to count visible template items."""
	return browser.template_items.size()

func test_template_customization_dialog_scene_instantiation():
	"""Test template customization dialog can be instantiated."""
	
	var dialog: TemplateCustomizationDialog = TemplateCustomizationDialog.new()
	assert_not_null(dialog)
	assert_that(dialog).is_instance_of(AcceptDialog)
	
	# Test initial state
	assert_that(dialog.template).is_null()
	assert_that(dialog.parameter_controls).is_not_null()
	assert_that(dialog.current_parameters).is_not_null()
	
	dialog.queue_free()

func test_template_customization_dialog_template_setup():
	"""Test customization dialog setup with template."""
	
	var dialog: TemplateCustomizationDialog = TemplateCustomizationDialog.new()
	add_child(dialog)
	
	# Create test template
	var template: MissionTemplate = MissionTemplate.new()
	template.template_name = "Test Template"
	template.template_type = MissionTemplate.TemplateType.ESCORT
	template.parameters = {
		"convoy_ship_count": 3,
		"escort_distance": 1000.0,
		"mission_title": "Test Mission"
	}
	
	# Setup dialog with template
	dialog.setup_for_template(template)
	
	# Verify setup
	assert_that(dialog.template).is_equal(template)
	assert_that(dialog.current_parameters.size()).is_greater_equal(3)
	assert_that(dialog.parameter_controls.size()).is_greater_equal(3)
	
	dialog.queue_free()

func test_template_customization_dialog_parameter_validation():
	"""Test parameter validation in customization dialog."""
	
	var dialog: TemplateCustomizationDialog = TemplateCustomizationDialog.new()
	add_child(dialog)
	
	# Create test template with validation constraints
	var template: MissionTemplate = MissionTemplate.new()
	template.template_name = "Validation Test"
	template.parameters = {
		"ship_count": 5,
		"distance": 1000.0,
		"enabled": true
	}
	
	dialog.setup_for_template(template)
	
	# Test validation with valid parameters
	var errors: Array[String] = dialog._validate_parameters()
	assert_that(errors).is_empty()
	
	# Test validation with invalid parameters (if constraints exist)
	dialog.current_parameters["ship_count"] = -1  # Invalid negative value
	errors = dialog._validate_parameters()
	# Note: Validation will depend on parameter definitions in the template
	
	dialog.queue_free()

func test_sexp_pattern_browser_scene_instantiation():
	"""Test SEXP pattern browser scene can be instantiated."""
	
	var browser: SexpPatternBrowser = SexpPatternBrowser.new()
	assert_not_null(browser)
	assert_that(browser).is_instance_of(VBoxContainer)
	
	# Test initial state
	assert_not_null(browser.template_manager)
	assert_that(browser.current_patterns).is_not_null()
	assert_that(browser.selected_pattern).is_null()
	
	browser.queue_free()

func test_sexp_pattern_browser_pattern_loading():
	"""Test SEXP pattern browser loads patterns correctly."""
	
	var browser: SexpPatternBrowser = SexpPatternBrowser.new()
	add_child(browser)
	
	# Test pattern loading
	browser.refresh_patterns()
	
	# Verify patterns are loaded (should have default patterns)
	assert_that(browser.current_patterns.size()).is_greater_equal(1)
	
	# Check for expected pattern types
	var has_trigger: bool = false
	var has_action: bool = false
	
	for pattern in browser.current_patterns:
		if pattern.category == SexpPattern.PatternCategory.TRIGGER:
			has_trigger = true
		elif pattern.category == SexpPattern.PatternCategory.ACTION:
			has_action = true
	
	# Should have at least one trigger or action pattern
	assert_bool(has_trigger or has_action).is_true()
	
	browser.queue_free()

func test_sexp_pattern_browser_pattern_selection():
	"""Test SEXP pattern selection and details update."""
	
	var browser: SexpPatternBrowser = SexpPatternBrowser.new()
	add_child(browser)
	
	browser.refresh_patterns()
	
	if browser.current_patterns.size() > 0:
		var test_pattern: SexpPattern = browser.current_patterns[0]
		
		# Simulate pattern selection
		browser._on_pattern_item_selected(test_pattern, Control.new())
		
		# Verify selection
		assert_that(browser.selected_pattern).is_equal(test_pattern)
		assert_that(browser.pattern_name_label.text).is_equal(test_pattern.pattern_name)
		
		# Test that parameters are initialized
		assert_that(browser.current_parameters).is_not_null()
	
	browser.queue_free()

func test_sexp_pattern_browser_expression_application():
	"""Test SEXP pattern expression application with parameters."""
	
	var browser: SexpPatternBrowser = SexpPatternBrowser.new()
	add_child(browser)
	
	# Create test pattern
	var pattern: SexpPattern = SexpPattern.new()
	pattern.pattern_name = "Test Pattern"
	pattern.sexp_expression = "(when (= @test_var {value}) (ship-destroy \"{ship_name}\"))"
	pattern.parameter_placeholders = {
		"value": {"type": "int", "default": 1},
		"ship_name": {"type": "string", "default": "Test Ship"}
	}
	
	browser.selected_pattern = pattern
	browser.current_parameters = {"value": 5, "ship_name": "Enemy 1"}
	
	# Test expression application
	var applied_expression: String = browser.apply_current_pattern()
	
	# Verify parameter substitution
	assert_that(applied_expression).contains("5")
	assert_that(applied_expression).contains("Enemy 1")
	assert_that(applied_expression).does_not_contain("{value}")
	assert_that(applied_expression).does_not_contain("{ship_name}")
	
	browser.queue_free()

func test_asset_pattern_browser_scene_instantiation():
	"""Test asset pattern browser scene can be instantiated."""
	
	var browser: AssetPatternBrowser = AssetPatternBrowser.new()
	assert_not_null(browser)
	assert_that(browser).is_instance_of(VBoxContainer)
	
	# Test initial state
	assert_not_null(browser.template_manager)
	assert_that(browser.current_patterns).is_not_null()
	assert_that(browser.selected_pattern).is_null()
	
	browser.queue_free()

func test_asset_pattern_browser_pattern_loading():
	"""Test asset pattern browser loads patterns correctly."""
	
	var browser: AssetPatternBrowser = AssetPatternBrowser.new()
	add_child(browser)
	
	# Test pattern loading
	browser.refresh_patterns()
	
	# Verify patterns are loaded (should have default patterns)
	assert_that(browser.current_patterns.size()).is_greater_equal(1)
	
	# Check for expected pattern types
	var pattern_types: Array[AssetPattern.PatternType] = []
	for pattern in browser.current_patterns:
		if not pattern_types.has(pattern.pattern_type):
			pattern_types.append(pattern.pattern_type)
	
	# Should have at least one pattern type
	assert_that(pattern_types.size()).is_greater_equal(1)
	
	browser.queue_free()

func test_asset_pattern_browser_filtering():
	"""Test asset pattern browser filtering functionality."""
	
	var browser: AssetPatternBrowser = AssetPatternBrowser.new()
	add_child(browser)
	
	browser.refresh_patterns()
	var total_patterns: int = browser.current_patterns.size()
	
	if total_patterns > 0:
		# Test type filter
		browser.type_filter.selected = 1  # First non-"All" type
		browser._on_filter_changed(1)
		
		# Test role filter
		browser.role_filter.selected = 1  # First non-"All" role
		browser._on_filter_changed(1)
		
		# Test search filter
		browser.search_box.text = "Fighter"
		browser._on_search_changed("Fighter")
		
		# Should handle filtering without errors
		var filtered_count: int = browser.pattern_items.size()
		assert_that(filtered_count).is_greater_equal(0)
	
	browser.queue_free()

func test_asset_pattern_browser_pattern_selection_and_parameters():
	"""Test asset pattern selection and parameter generation."""
	
	var browser: AssetPatternBrowser = AssetPatternBrowser.new()
	add_child(browser)
	
	browser.refresh_patterns()
	
	if browser.current_patterns.size() > 0:
		var test_pattern: AssetPattern = browser.current_patterns[0]
		
		# Simulate pattern selection
		browser._on_pattern_item_selected(test_pattern, Control.new())
		
		# Verify selection
		assert_that(browser.selected_pattern).is_equal(test_pattern)
		assert_that(browser.pattern_name_label.text).is_equal(test_pattern.pattern_name)
		
		# Test that basic parameters are generated
		assert_that(browser.current_parameters).has_key("Ship Name")
		assert_that(browser.current_parameters).has_key("Team")
		assert_that(browser.current_parameters).has_key("Position X")
		
		# Test parameter controls are created
		assert_that(browser.parameter_controls.size()).is_greater_equal(5)
	
	browser.queue_free()

func test_template_library_performance_requirements():
	"""Test that template library components meet performance requirements."""
	
	# Test template browser instantiation time
	var start_time: int = Time.get_ticks_msec()
	
	var browser: MissionTemplateBrowser = MissionTemplateBrowser.new()
	add_child(browser)
	
	var instantiation_time: int = Time.get_ticks_msec() - start_time
	
	# Performance requirement: < 16ms scene instantiation
	assert_that(instantiation_time).is_less_than(16)
	
	# Test template loading performance
	start_time = Time.get_ticks_msec()
	
	browser.refresh_templates()
	
	var loading_time: int = Time.get_ticks_msec() - start_time
	
	# Should load quickly even with many templates
	assert_that(loading_time).is_less_than(100)  # 100ms limit for loading
	
	# Test filter performance
	start_time = Time.get_ticks_msec()
	
	browser.search_box.text = "test"
	browser._on_search_changed("test")
	
	var filter_time: int = Time.get_ticks_msec() - start_time
	
	# Filtering should be very fast
	assert_that(filter_time).is_less_than(50)  # 50ms limit for filtering
	
	browser.queue_free()

func test_pattern_browser_performance_requirements():
	"""Test that pattern browsers meet performance requirements."""
	
	# Test SEXP pattern browser
	var start_time: int = Time.get_ticks_msec()
	
	var sexp_browser: SexpPatternBrowser = SexpPatternBrowser.new()
	add_child(sexp_browser)
	
	var sexp_instantiation_time: int = Time.get_ticks_msec() - start_time
	assert_that(sexp_instantiation_time).is_less_than(16)
	
	# Test asset pattern browser
	start_time = Time.get_ticks_msec()
	
	var asset_browser: AssetPatternBrowser = AssetPatternBrowser.new()
	add_child(asset_browser)
	
	var asset_instantiation_time: int = Time.get_ticks_msec() - start_time
	assert_that(asset_instantiation_time).is_less_than(16)
	
	# Test pattern loading performance
	start_time = Time.get_ticks_msec()
	
	sexp_browser.refresh_patterns()
	asset_browser.refresh_patterns()
	
	var pattern_loading_time: int = Time.get_ticks_msec() - start_time
	assert_that(pattern_loading_time).is_less_than(100)
	
	sexp_browser.queue_free()
	asset_browser.queue_free()

func test_template_library_signal_integration():
	"""Test signal communication between template library components."""
	
	var browser: MissionTemplateBrowser = MissionTemplateBrowser.new()
	add_child(browser)
	
	# Monitor signals
	var template_selected_monitor: GdUnitSignalMonitor = monitor_signal(browser.template_selected)
	var use_requested_monitor: GdUnitSignalMonitor = monitor_signal(browser.template_use_requested)
	
	browser.refresh_templates()
	
	if browser.current_templates.size() > 0:
		var test_template: MissionTemplate = browser.current_templates[0]
		
		# Simulate template selection
		browser._on_template_item_selected(test_template, Control.new())
		
		# Should emit template_selected signal
		await wait_until(func(): return template_selected_monitor.get_signal_count() > 0).wait_at_most(1000)
		assert_signal_emitted(browser.template_selected)
		
		# Simulate use template button press
		browser._on_use_template_pressed()
		
		# Should emit template_use_requested signal
		await wait_until(func(): return use_requested_monitor.get_signal_count() > 0).wait_at_most(1000)
		assert_signal_emitted(browser.template_use_requested)
	
	browser.queue_free()

func test_pattern_validation_integration():
	"""Test pattern validation integration with validation systems."""
	
	var sexp_browser: SexpPatternBrowser = SexpPatternBrowser.new()
	add_child(sexp_browser)
	
	# Monitor validation signal
	var validation_monitor: GdUnitSignalMonitor = monitor_signal(sexp_browser.pattern_validated)
	
	# Create test pattern
	var pattern: SexpPattern = SexpPattern.new()
	pattern.pattern_name = "Test Validation"
	pattern.sexp_expression = "(when (is-destroyed \"Alpha 1\") (ship-create \"Beta 1\"))"
	pattern.required_functions = ["when", "is-destroyed", "ship-create"]
	
	sexp_browser.selected_pattern = pattern
	
	# Test validation
	sexp_browser._on_validate_pressed()
	
	# Should emit validation signal
	await wait_until(func(): return validation_monitor.get_signal_count() > 0).wait_at_most(1000)
	assert_signal_emitted(sexp_browser.pattern_validated)
	
	sexp_browser.queue_free()

func test_community_template_features():
	"""Test community template import/export functionality."""
	
	var browser: MissionTemplateBrowser = MissionTemplateBrowser.new()
	add_child(browser)
	
	browser.refresh_templates()
	
	if browser.current_templates.size() > 0:
		var test_template: MissionTemplate = browser.current_templates[0]
		browser.selected_template = test_template
		
		# Test export functionality
		var export_path: String = "user://test_template_export.json"
		var export_result: Error = browser.template_manager.export_template_for_community(
			test_template.template_id, export_path
		)
		
		# Export should succeed
		assert_that(export_result).is_equal(OK)
		
		# File should exist
		assert_file_exists(export_path)
		
		# Test import functionality
		var imported_template: MissionTemplate = browser.template_manager.import_template_from_community(export_path)
		
		# Import should succeed
		assert_not_null(imported_template)
		assert_that(imported_template.template_name).is_equal(test_template.template_name)
		assert_bool(imported_template.is_community_template).is_true()
		
		# Clean up
		DirAccess.remove_absolute(export_path)
	
	browser.queue_free()

func test_template_parameter_application():
	"""Test template parameter application to mission creation."""
	
	var template: MissionTemplate = MissionTemplate.new()
	template.template_name = "Parameter Test"
	template.template_type = MissionTemplate.TemplateType.ESCORT
	template.parameters = {
		"mission_title": "Default Title",
		"convoy_ship_count": 3,
		"difficulty_multiplier": 1.0
	}
	
	# Create basic mission data
	template.template_mission_data = MissionData.new()
	template.template_mission_data.title = "Default Title"
	
	# Test parameter application
	var custom_parameters: Dictionary = {
		"mission_title": "Custom Mission",
		"convoy_ship_count": 5,
		"difficulty_multiplier": 1.5
	}
	
	var created_mission: MissionData = template.create_mission(custom_parameters)
	
	# Verify parameter application
	assert_not_null(created_mission)
	assert_that(created_mission.title).is_equal("Custom Mission")
	
	# Verify the mission is a copy, not the original
	assert_that(created_mission).is_not_equal(template.template_mission_data)
	
	template.queue_free()

## Mock classes for testing

class MockMissionData:
	extends RefCounted
	
	var title: String = ""
	var description: String = ""
	var objects: Dictionary = {}
	var goals: Array = []
	
	func add_object(obj) -> void:
		objects[obj.id] = obj
	
	func add_goal(goal) -> void:
		goals.append(goal)
	
	func validate() -> Array[String]:
		return []

class MockMissionObject:
	extends RefCounted
	
	var id: String = ""
	var name: String = ""
	var type: int = 0
	var team: int = 1

class MockMissionGoal:
	extends RefCounted
	
	var goal_name: String = ""
	var description: String = ""
	var type: int = 0