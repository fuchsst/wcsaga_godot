@tool
extends GdUnitTestSuite

## Test suite for GFRED2-008 Campaign Editor Integration.
## Tests campaign data structures, editor components, progression logic, and export functionality.

func test_campaign_data_instantiation():
	"""Test campaign data can be instantiated."""
	
	var campaign_data: CampaignData = CampaignData.new()
	assert_not_null(campaign_data)
	assert_that(campaign_data).is_instance_of(CampaignData)
	assert_that(campaign_data.missions).is_not_null()
	assert_that(campaign_data.missions.size()).is_equal(0)
	assert_that(campaign_data.campaign_variables).is_not_null()
	assert_that(campaign_data.campaign_variables.size()).is_equal(0)

func test_campaign_data_mission_management():
	"""Test campaign data mission management."""
	
	var campaign_data: CampaignData = CampaignData.new()
	campaign_data.campaign_name = "Test Campaign"
	
	# Create test mission
	var mission: CampaignMissionData = CampaignMissionData.new()
	mission.mission_name = "Test Mission"
	mission.mission_filename = "test_mission.mission"
	mission.mission_id = "test_mission_1"
	mission.position = Vector2(100, 100)
	
	# Add mission
	campaign_data.add_mission(mission)
	
	assert_that(campaign_data.missions.size()).is_equal(1)
	assert_that(campaign_data.get_mission("test_mission_1")).is_equal(mission)
	assert_that(campaign_data.get_mission_at_index(0)).is_equal(mission)
	
	# Add another mission
	var mission2: CampaignMissionData = CampaignMissionData.new()
	mission2.mission_name = "Test Mission 2"
	mission2.mission_filename = "test_mission_2.mission"
	mission2.mission_id = "test_mission_2"
	mission2.position = Vector2(200, 200)
	campaign_data.add_mission(mission2)
	
	assert_that(campaign_data.missions.size()).is_equal(2)
	
	# Remove mission
	campaign_data.remove_mission("test_mission_1")
	assert_that(campaign_data.missions.size()).is_equal(1)
	assert_that(campaign_data.get_mission("test_mission_1")).is_null()
	assert_that(campaign_data.get_mission("test_mission_2")).is_equal(mission2)

func test_campaign_data_variable_management():
	"""Test campaign data variable management."""
	
	var campaign_data: CampaignData = CampaignData.new()
	
	# Create test variable
	var variable: CampaignVariable = CampaignVariable.new()
	variable.variable_name = "test_var"
	variable.variable_type = CampaignVariable.VariableType.INTEGER
	variable.initial_value = "42"
	variable.description = "Test variable"
	variable.is_persistent = true
	
	# Add variable
	campaign_data.add_campaign_variable(variable)
	
	assert_that(campaign_data.campaign_variables.size()).is_equal(1)
	assert_that(campaign_data.get_campaign_variable("test_var")).is_equal(variable)
	
	# Add another variable
	var variable2: CampaignVariable = CampaignVariable.new()
	variable2.variable_name = "test_var_2"
	variable2.variable_type = CampaignVariable.VariableType.BOOLEAN
	variable2.initial_value = "true"
	campaign_data.add_campaign_variable(variable2)
	
	assert_that(campaign_data.campaign_variables.size()).is_equal(2)
	
	# Remove variable
	campaign_data.remove_campaign_variable("test_var")
	assert_that(campaign_data.campaign_variables.size()).is_equal(1)
	assert_that(campaign_data.get_campaign_variable("test_var")).is_null()
	assert_that(campaign_data.get_campaign_variable("test_var_2")).is_equal(variable2)

func test_campaign_data_validation():
	"""Test campaign data validation."""
	
	var campaign_data: CampaignData = CampaignData.new()
	
	# Empty campaign should have validation errors
	var errors: Array[String] = campaign_data.validate_campaign()
	assert_that(errors.size()).is_greater(0)
	assert_that(errors).contains("Campaign must have a name")
	assert_that(errors).contains("Campaign must have at least one mission")
	
	# Add name and mission
	campaign_data.campaign_name = "Valid Campaign"
	var mission: CampaignMissionData = CampaignMissionData.new()
	mission.mission_name = "Valid Mission"
	mission.mission_filename = "valid.mission"
	mission.mission_id = "valid_mission"
	campaign_data.add_mission(mission)
	campaign_data.starting_mission_id = "valid_mission"
	
	# Should now be valid
	errors = campaign_data.validate_campaign()
	assert_that(errors.size()).is_equal(0)

func test_campaign_mission_data():
	"""Test campaign mission data structure."""
	
	var mission: CampaignMissionData = CampaignMissionData.new()
	mission.mission_name = "Test Mission"
	mission.mission_filename = "test.mission"
	mission.mission_description = "A test mission"
	mission.mission_author = "Test Author"
	mission.position = Vector2(150, 200)
	mission.is_required = true
	mission.difficulty_level = 3
	
	assert_that(mission.mission_name).is_equal("Test Mission")
	assert_that(mission.mission_filename).is_equal("test.mission")
	assert_that(mission.mission_description).is_equal("A test mission")
	assert_that(mission.mission_author).is_equal("Test Author")
	assert_that(mission.position).is_equal(Vector2(150, 200))
	assert_bool(mission.is_required).is_true()
	assert_that(mission.difficulty_level).is_equal(3)

func test_campaign_mission_prerequisites():
	"""Test campaign mission prerequisite management."""
	
	var mission: CampaignMissionData = CampaignMissionData.new()
	mission.mission_id = "test_mission"
	
	# Add prerequisites
	mission.add_prerequisite("mission_1")
	mission.add_prerequisite("mission_2")
	
	assert_that(mission.prerequisite_missions.size()).is_equal(2)
	assert_that(mission.prerequisite_missions).contains("mission_1")
	assert_that(mission.prerequisite_missions).contains("mission_2")
	
	# Remove prerequisite
	mission.remove_prerequisite("mission_1")
	assert_that(mission.prerequisite_missions.size()).is_equal(1)
	assert_that(mission.prerequisite_missions).contains("mission_2")
	assert_that(mission.prerequisite_missions).not_contains("mission_1")

func test_campaign_mission_branches():
	"""Test campaign mission branch management."""
	
	var mission: CampaignMissionData = CampaignMissionData.new()
	mission.mission_id = "test_mission"
	
	# Create test branch
	var branch: CampaignMissionDataBranch = CampaignMissionDataBranch.new()
	branch.branch_type = CampaignMissionDataBranch.BranchType.SUCCESS
	branch.target_mission_id = "next_mission"
	branch.branch_description = "Success branch"
	
	# Add branch
	mission.add_mission_branch(branch)
	
	assert_that(mission.mission_branches.size()).is_equal(1)
	assert_that(mission.mission_branches[0]).is_equal(branch)
	
	# Add another branch
	var branch2: CampaignMissionDataBranch = CampaignMissionDataBranch.new()
	branch2.branch_type = CampaignMissionDataBranch.BranchType.FAILURE
	branch2.target_mission_id = "failure_mission"
	mission.add_mission_branch(branch2)
	
	assert_that(mission.mission_branches.size()).is_equal(2)
	
	# Remove branch
	mission.remove_mission_branch(0)
	assert_that(mission.mission_branches.size()).is_equal(1)
	assert_that(mission.mission_branches[0]).is_equal(branch2)

func test_campaign_mission_branch_data():
	"""Test campaign mission branch data structure."""
	
	var branch: CampaignMissionDataBranch = CampaignMissionDataBranch.new()
	branch.branch_type = CampaignMissionDataBranch.BranchType.CONDITION
	branch.target_mission_id = "conditional_mission"
	branch.branch_condition = "(> score 80)"
	branch.branch_description = "High score branch"
	branch.is_enabled = true
	
	assert_that(branch.branch_type).is_equal(CampaignMissionDataBranch.BranchType.CONDITION)
	assert_that(branch.target_mission_id).is_equal("conditional_mission")
	assert_that(branch.branch_condition).is_equal("(> score 80)")
	assert_that(branch.branch_description).is_equal("High score branch")
	assert_bool(branch.is_enabled).is_true()

func test_campaign_variable_data():
	"""Test campaign variable data structure."""
	
	var variable: CampaignVariable = CampaignVariable.new()
	variable.variable_name = "player_score"
	variable.variable_type = CampaignVariable.VariableType.INTEGER
	variable.initial_value = "1000"
	variable.description = "Player's current score"
	variable.is_persistent = true
	
	assert_that(variable.variable_name).is_equal("player_score")
	assert_that(variable.variable_type).is_equal(CampaignVariable.VariableType.INTEGER)
	assert_that(variable.initial_value).is_equal("1000")
	assert_that(variable.description).is_equal("Player's current score")
	assert_bool(variable.is_persistent).is_true()
	
	# Test typed initial value
	assert_that(variable.get_typed_initial_value()).is_equal(1000)

func test_campaign_variable_validation():
	"""Test campaign variable validation."""
	
	var variable: CampaignVariable = CampaignVariable.new()
	
	# Empty variable should have validation errors
	var errors: Array[String] = variable.validate_variable()
	assert_that(errors.size()).is_greater(0)
	assert_that(errors).contains("Variable must have a name")
	
	# Set valid data
	variable.variable_name = "valid_var"
	variable.variable_type = CampaignVariable.VariableType.INTEGER
	variable.initial_value = "42"
	
	# Should now be valid
	errors = variable.validate_variable()
	assert_that(errors.size()).is_equal(0)
	
	# Test invalid value format
	variable.initial_value = "not_a_number"
	errors = variable.validate_variable()
	assert_that(errors.size()).is_greater(0)
	assert_that(errors).contains("Initial value must be a valid integer")

func test_campaign_progression_manager_initialization():
	"""Test campaign progression manager initialization."""
	
	var campaign_data: CampaignData = _create_test_campaign_data()
	var progression_manager: CampaignProgressionManager = CampaignProgressionManager.new()
	progression_manager.setup_campaign_progression(campaign_data)
	
	# Check initial state
	var starting_missions: Array[String] = progression_manager.get_unlocked_missions()
	assert_that(starting_missions.size()).is_greater(0)
	
	# Starting mission should be unlocked
	assert_bool(progression_manager.is_mission_unlocked("mission_1")).is_true()

func test_campaign_progression_mission_completion():
	"""Test campaign progression mission completion."""
	
	var campaign_data: CampaignData = _create_test_campaign_data()
	var progression_manager: CampaignProgressionManager = CampaignProgressionManager.new()
	progression_manager.setup_campaign_progression(campaign_data)
	
	# Monitor completion signal
	var completion_monitor: GdUnitSignalMonitor = monitor_signal(progression_manager.mission_completed)
	
	# Complete first mission
	progression_manager.complete_mission("mission_1", true, 95.0)
	
	assert_signal_emitted(progression_manager.mission_completed)
	assert_bool(progression_manager.is_mission_completed("mission_1")).is_true()
	
	# Dependent missions should now be unlocked
	var unlocked: Array[String] = progression_manager.get_unlocked_missions()
	assert_that(unlocked).contains("mission_2")

func test_campaign_progression_variable_management():
	"""Test campaign progression variable management."""
	
	var campaign_data: CampaignData = _create_test_campaign_data()
	var progression_manager: CampaignProgressionManager = CampaignProgressionManager.new()
	progression_manager.setup_campaign_progression(campaign_data)
	
	# Set variable value
	progression_manager.set_campaign_variable("test_score", 500)
	
	# Get variable value
	var score: Variant = progression_manager.get_campaign_variable("test_score")
	assert_that(score).is_equal(500)
	
	# Get all variables
	var all_vars: Dictionary = progression_manager.get_all_campaign_variables()
	assert_that(all_vars).has_key("test_score")
	assert_that(all_vars["test_score"]).is_equal(500)

func test_campaign_progression_validation():
	"""Test campaign progression validation."""
	
	var campaign_data: CampaignData = _create_test_campaign_data()
	var progression_manager: CampaignProgressionManager = CampaignProgressionManager.new()
	progression_manager.setup_campaign_progression(campaign_data)
	
	# Validate progression logic
	var errors: Array[String] = progression_manager.validate_campaign_progression()
	
	# Should have no errors for valid test campaign
	assert_that(errors.size()).is_equal(0)

func test_campaign_flow_diagram_instantiation():
	"""Test campaign flow diagram can be instantiated."""
	
	var flow_diagram: CampaignFlowDiagram = CampaignFlowDiagram.new()
	assert_not_null(flow_diagram)
	assert_that(flow_diagram).is_instance_of(CampaignFlowDiagram)

func test_campaign_flow_diagram_setup():
	"""Test campaign flow diagram setup."""
	
	var flow_diagram: CampaignFlowDiagram = CampaignFlowDiagram.new()
	add_child(flow_diagram)
	
	var campaign_data: CampaignData = _create_test_campaign_data()
	
	# Setup flow diagram
	flow_diagram.setup_campaign_flow(campaign_data)
	
	assert_that(flow_diagram.campaign_data).is_equal(campaign_data)
	assert_that(flow_diagram.mission_nodes.size()).is_greater(0)
	
	flow_diagram.queue_free()

func test_campaign_variable_manager_instantiation():
	"""Test campaign variable manager can be instantiated."""
	
	var variable_manager: CampaignVariableManager = CampaignVariableManager.new()
	assert_not_null(variable_manager)
	assert_that(variable_manager).is_instance_of(CampaignVariableManager)

func test_campaign_variable_manager_setup():
	"""Test campaign variable manager setup."""
	
	var variable_manager: CampaignVariableManager = CampaignVariableManager.new()
	add_child(variable_manager)
	
	var campaign_data: CampaignData = _create_test_campaign_data()
	
	# Setup variable manager
	variable_manager.setup_variable_manager(campaign_data)
	
	assert_that(variable_manager.campaign_data).is_equal(campaign_data)
	
	# Get campaign variables
	var variables: Array[CampaignVariable] = variable_manager.get_campaign_variables()
	assert_that(variables.size()).is_greater(0)
	
	variable_manager.queue_free()

func test_mission_details_panel_instantiation():
	"""Test mission details panel can be instantiated."""
	
	var details_panel: MissionDetailsPanel = MissionDetailsPanel.new()
	assert_not_null(details_panel)
	assert_that(details_panel).is_instance_of(MissionDetailsPanel)

func test_mission_details_panel_setup():
	"""Test mission details panel setup."""
	
	var details_panel: MissionDetailsPanel = MissionDetailsPanel.new()
	add_child(details_panel)
	
	var campaign_data: CampaignData = _create_test_campaign_data()
	var mission: CampaignMissionData = campaign_data.missions[0]
	
	# Setup details panel
	details_panel.setup_mission_details(mission, campaign_data)
	
	assert_that(details_panel.get_mission_data()).is_equal(mission)
	
	details_panel.queue_free()

func test_campaign_validation_panel_instantiation():
	"""Test campaign validation panel can be instantiated."""
	
	var validation_panel: CampaignValidationPanel = CampaignValidationPanel.new()
	assert_not_null(validation_panel)
	assert_that(validation_panel).is_instance_of(CampaignValidationPanel)

func test_campaign_validation_panel_validation():
	"""Test campaign validation panel validation functionality."""
	
	var validation_panel: CampaignValidationPanel = CampaignValidationPanel.new()
	add_child(validation_panel)
	
	var campaign_data: CampaignData = _create_test_campaign_data()
	validation_panel.setup_validation_panel(campaign_data)
	
	# Show validation results
	validation_panel.show_validation_results(true, [])
	
	# Check results
	var results: Array[String] = validation_panel.get_validation_results()
	assert_that(results.size()).is_equal(0)
	
	# Test with errors
	var errors: Array[String] = ["Test error 1", "Test error 2"]
	validation_panel.show_validation_results(false, errors)
	
	results = validation_panel.get_validation_results()
	assert_that(results.size()).is_equal(2)
	assert_that(results).contains("Test error 1")
	assert_that(results).contains("Test error 2")
	
	validation_panel.queue_free()

func test_campaign_export_manager_initialization():
	"""Test campaign export manager initialization."""
	
	var export_manager: CampaignExportManager = CampaignExportManager.new()
	var campaign_data: CampaignData = _create_test_campaign_data()
	
	export_manager.setup_campaign_export(campaign_data)
	
	# Check supported formats
	var formats: Array = export_manager.get_supported_formats()
	assert_that(formats.size()).is_greater(0)
	assert_that(formats).contains(CampaignExportManager.ExportFormat.WCS_CAMPAIGN)
	assert_that(formats).contains(CampaignExportManager.ExportFormat.GODOT_RESOURCE)

func test_campaign_export_format_info():
	"""Test campaign export format information."""
	
	var export_manager: CampaignExportManager = CampaignExportManager.new()
	
	# Test format names
	var wcs_name: String = export_manager.get_format_name(CampaignExportManager.ExportFormat.WCS_CAMPAIGN)
	assert_that(wcs_name).is_equal("WCS Campaign (.fc2)")
	
	var json_name: String = export_manager.get_format_name(CampaignExportManager.ExportFormat.JSON_DATA)
	assert_that(json_name).is_equal("JSON Data (.json)")
	
	# Test format extensions
	var wcs_ext: String = export_manager.get_format_extension(CampaignExportManager.ExportFormat.WCS_CAMPAIGN)
	assert_that(wcs_ext).is_equal("fc2")
	
	var json_ext: String = export_manager.get_format_extension(CampaignExportManager.ExportFormat.JSON_DATA)
	assert_that(json_ext).is_equal("json")

func test_campaign_editor_dialog_instantiation():
	"""Test campaign editor dialog can be instantiated."""
	
	var editor_dialog: CampaignEditorDialog = CampaignEditorDialog.new()
	assert_not_null(editor_dialog)
	assert_that(editor_dialog).is_instance_of(CampaignEditorDialog)
	
	editor_dialog.queue_free()

func test_campaign_integration_workflow():
	"""Test integration between campaign editor components."""
	
	var campaign_data: CampaignData = _create_test_campaign_data()
	
	# Test progression manager with campaign
	var progression_manager: CampaignProgressionManager = CampaignProgressionManager.new()
	progression_manager.setup_campaign_progression(campaign_data)
	
	# Test variable manager integration
	var variable_manager: CampaignVariableManager = CampaignVariableManager.new()
	add_child(variable_manager)
	variable_manager.setup_variable_manager(campaign_data)
	
	# Test validation panel integration
	var validation_panel: CampaignValidationPanel = CampaignValidationPanel.new()
	add_child(validation_panel)
	validation_panel.setup_validation_panel(campaign_data)
	
	# Test export manager integration
	var export_manager: CampaignExportManager = CampaignExportManager.new()
	export_manager.setup_campaign_export(campaign_data)
	
	# All components should be working with the same campaign data
	assert_that(progression_manager.campaign_data).is_equal(campaign_data)
	assert_that(variable_manager.campaign_data).is_equal(campaign_data)
	assert_that(validation_panel.campaign_data).is_equal(campaign_data)
	assert_that(export_manager.campaign_data).is_equal(campaign_data)
	
	variable_manager.queue_free()
	validation_panel.queue_free()

func test_campaign_performance_requirements():
	"""Test campaign editor performance requirements."""
	
	# Test large campaign data creation performance
	var start_time: int = Time.get_ticks_msec()
	
	var campaign_data: CampaignData = _create_large_campaign_data()
	
	var creation_time: int = Time.get_ticks_msec() - start_time
	
	# Should create large campaign quickly
	assert_that(creation_time).is_less_than(100)  # Less than 100ms
	
	# Test component instantiation performance
	start_time = Time.get_ticks_msec()
	
	var flow_diagram: CampaignFlowDiagram = CampaignFlowDiagram.new()
	add_child(flow_diagram)
	
	var instantiation_time: int = Time.get_ticks_msec() - start_time
	
	# Performance requirement: < 16ms scene instantiation
	assert_that(instantiation_time).is_less_than(16)
	
	flow_diagram.queue_free()

## Helper Methods

func _create_test_campaign_data() -> CampaignData:
	"""Creates test campaign data for testing."""
	var campaign_data: CampaignData = CampaignData.new()
	campaign_data.campaign_name = "Test Campaign"
	campaign_data.campaign_description = "A test campaign for unit testing"
	campaign_data.campaign_author = "Test Author"
	
	# Add test missions
	for i in range(3):
		var mission: CampaignMissionData = CampaignMissionData.new()
		mission.mission_id = "mission_%d" % (i + 1)
		mission.mission_name = "Mission %d" % (i + 1)
		mission.mission_filename = "mission_%d.mission" % (i + 1)
		mission.mission_description = "Test mission %d" % (i + 1)
		mission.position = Vector2(i * 150, 100)
		mission.is_required = i < 2  # First two missions are required
		mission.difficulty_level = i + 1
		
		# Add prerequisites (mission 2 depends on mission 1, mission 3 depends on mission 2)
		if i > 0:
			mission.add_prerequisite("mission_%d" % i)
		
		# Add test branches
		if i < 2:  # Add branch to next mission
			var branch: CampaignMissionDataBranch = CampaignMissionDataBranch.new()
			branch.branch_type = CampaignMissionDataBranch.BranchType.SUCCESS
			branch.target_mission_id = "mission_%d" % (i + 2)
			branch.branch_description = "Success branch to mission %d" % (i + 2)
			mission.add_mission_branch(branch)
		
		campaign_data.add_mission(mission)
	
	# Set starting mission
	campaign_data.starting_mission_id = "mission_1"
	
	# Add test variables
	var score_var: CampaignVariable = CampaignVariable.new()
	score_var.variable_name = "test_score"
	score_var.variable_type = CampaignVariable.VariableType.INTEGER
	score_var.initial_value = "0"
	score_var.description = "Test score variable"
	score_var.is_persistent = true
	campaign_data.add_campaign_variable(score_var)
	
	var flag_var: CampaignVariable = CampaignVariable.new()
	flag_var.variable_name = "test_flag"
	flag_var.variable_type = CampaignVariable.VariableType.BOOLEAN
	flag_var.initial_value = "false"
	flag_var.description = "Test flag variable"
	flag_var.is_persistent = false
	campaign_data.add_campaign_variable(flag_var)
	
	return campaign_data

func _create_large_campaign_data() -> CampaignData:
	"""Creates a large campaign data structure for performance testing."""
	var campaign_data: CampaignData = CampaignData.new()
	campaign_data.campaign_name = "Large Test Campaign"
	
	# Create 50 missions with complex dependencies
	for i in range(50):
		var mission: CampaignMissionData = CampaignMissionData.new()
		mission.mission_id = "large_mission_%d" % (i + 1)
		mission.mission_name = "Large Mission %d" % (i + 1)
		mission.mission_filename = "large_mission_%d.mission" % (i + 1)
		mission.mission_description = "Large mission content with detailed description for mission %d" % (i + 1)
		mission.position = Vector2(randf_range(-1000, 1000), randf_range(-500, 500))
		mission.is_required = (i % 3) == 0  # Every third mission is required
		mission.difficulty_level = (i % 5) + 1
		
		# Add prerequisites (complex dependency tree)
		if i > 0:
			var prereq_count: int = min(i, 3)  # Up to 3 prerequisites
			for j in range(prereq_count):
				var prereq_index: int = max(0, i - j - 1)
				mission.add_prerequisite("large_mission_%d" % (prereq_index + 1))
		
		# Add multiple branches
		for k in range(3):
			if i + k + 1 < 50:
				var branch: CampaignMissionDataBranch = CampaignMissionDataBranch.new()
				match k:
					0:
						branch.branch_type = CampaignMissionDataBranch.BranchType.SUCCESS
					1:
						branch.branch_type = CampaignMissionDataBranch.BranchType.FAILURE
					2:
						branch.branch_type = CampaignMissionDataBranch.BranchType.CONDITION
						branch.branch_condition = "(> score %d)" % (i * 10)
				
				branch.target_mission_id = "large_mission_%d" % (i + k + 2)
				branch.branch_description = "Branch %d from mission %d" % [k + 1, i + 1]
				mission.add_mission_branch(branch)
		
		campaign_data.add_mission(mission)
	
	# Set starting mission
	campaign_data.starting_mission_id = "large_mission_1"
	
	# Add many variables
	for i in range(20):
		var variable: CampaignVariable = CampaignVariable.new()
		variable.variable_name = "large_var_%d" % (i + 1)
		variable.variable_type = CampaignVariable.VariableType.INTEGER
		variable.initial_value = str(i * 10)
		variable.description = "Large variable %d for testing" % (i + 1)
		variable.is_persistent = (i % 2) == 0
		campaign_data.add_campaign_variable(variable)
	
	return campaign_data