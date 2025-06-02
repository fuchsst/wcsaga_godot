extends GdUnitTestSuite

## Unit tests for MissionContext
## Tests mission context data structure and validation functionality

const MissionContext = preload("res://scripts/core/game_flow/mission_context/mission_context.gd")
const MissionData = preload("res://addons/wcs_asset_core/resources/mission/mission_data.gd")
const CampaignState = preload("res://addons/wcs_asset_core/resources/save_system/campaign_state.gd")
const ShipData = preload("res://addons/wcs_asset_core/resources/ship/ship_data.gd")

var mission_context: MissionContext
var mock_mission_data: MissionData
var mock_campaign_state: CampaignState
var mock_ship_data: ShipData

func before_test() -> void:
	# Create mission context
	mission_context = MissionContext.new()
	
	# Create mock data
	_setup_mock_data()

func after_test() -> void:
	mission_context = null
	mock_mission_data = null
	mock_campaign_state = null
	mock_ship_data = null

func _setup_mock_data() -> void:
	# Mock mission data
	mock_mission_data = MissionData.new()
	mock_mission_data.mission_title = "Test Mission"
	mock_mission_data.mission_desc = "A test mission"
	mock_mission_data.num_players = 1
	
	# Mock campaign state
	mock_campaign_state = CampaignState.new()
	mock_campaign_state.initialize_from_campaign_data({
		"campaign_name": "Test Campaign",
		"total_missions": 3
	})
	
	# Mock ship data
	mock_ship_data = ShipData.new()
	mock_ship_data.display_name = "Test Fighter"
	mock_ship_data.ship_class = "fighter"

# --- Basic Functionality Tests ---

func test_mission_context_initialization() -> void:
	"""Test MissionContext initializes correctly"""
	assert_that(mission_context).is_not_null()
	assert_that(mission_context.mission_id).is_equal("")
	assert_that(mission_context.mission_data).is_null()
	assert_that(mission_context.campaign_state).is_null()
	assert_that(mission_context.current_phase).is_equal(MissionContext.Phase.BRIEFING)
	assert_that(mission_context.start_time).is_greater(0)

func test_mission_context_validation() -> void:
	"""Test mission context validation"""
	# Invalid context (empty)
	assert_that(mission_context.is_valid()).is_false()
	
	# Partially valid context
	mission_context.mission_id = "test_mission"
	assert_that(mission_context.is_valid()).is_false()
	
	mission_context.mission_data = mock_mission_data
	assert_that(mission_context.is_valid()).is_false()
	
	# Fully valid context
	mission_context.campaign_state = mock_campaign_state
	assert_that(mission_context.is_valid()).is_true()

func test_mission_context_setup() -> void:
	"""Test mission context setup with data"""
	mission_context.mission_id = "test_mission"
	mission_context.mission_data = mock_mission_data
	mission_context.campaign_state = mock_campaign_state
	
	assert_that(mission_context.mission_id).is_equal("test_mission")
	assert_that(mission_context.mission_data).is_equal(mock_mission_data)
	assert_that(mission_context.campaign_state).is_equal(mock_campaign_state)
	assert_that(mission_context.is_valid()).is_true()

# --- Phase Management Tests ---

func test_phase_progression_validation() -> void:
	"""Test phase progression validation rules"""
	# Setup valid context
	mission_context.mission_id = "test"
	mission_context.mission_data = mock_mission_data
	mission_context.campaign_state = mock_campaign_state
	
	# Test progression from BRIEFING
	mission_context.current_phase = MissionContext.Phase.BRIEFING
	
	# Cannot go to ship selection without acknowledging briefing
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.SHIP_SELECTION)).is_false()
	
	# Can advance after acknowledging briefing
	mission_context.briefing_acknowledged = true
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.SHIP_SELECTION)).is_true()
	
	# Test progression from SHIP_SELECTION
	mission_context.current_phase = MissionContext.Phase.SHIP_SELECTION
	
	# Cannot go to loading without ship selection
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.LOADING)).is_false()
	
	# Can advance after selecting ship
	mission_context.selected_ship = mock_ship_data
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.LOADING)).is_true()
	
	# Test progression from LOADING
	mission_context.current_phase = MissionContext.Phase.LOADING
	
	# Cannot go to in-mission without full resource loading
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.IN_MISSION)).is_false()
	
	# Can advance after resources loaded
	mission_context.resource_loading_progress = 1.0
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.IN_MISSION)).is_true()

func test_invalid_phase_transitions() -> void:
	"""Test invalid phase transitions are rejected"""
	mission_context.current_phase = MissionContext.Phase.BRIEFING
	
	# Cannot skip phases
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.LOADING)).is_false()
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.IN_MISSION)).is_false()
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.COMPLETED)).is_false()
	assert_that(mission_context.can_advance_to_phase(MissionContext.Phase.DEBRIEFING)).is_false()

# --- Mission Data Access Tests ---

func test_get_mission_objectives() -> void:
	"""Test getting mission objectives"""
	# No mission data
	var objectives = mission_context.get_mission_objectives()
	assert_that(objectives).is_empty()
	
	# With mission data
	mission_context.mission_data = mock_mission_data
	objectives = mission_context.get_mission_objectives()
	assert_that(objectives).is_not_null()
	# Objectives size depends on mock data setup

func test_get_available_ships() -> void:
	"""Test getting available ships"""
	# No mission data
	var ships = mission_context.get_available_ships()
	assert_that(ships).is_empty()
	
	# With mission data (will use default ships)
	mission_context.mission_data = mock_mission_data
	ships = mission_context.get_available_ships()
	# Should return default ships if no specific ships are configured

func test_get_mission_briefing() -> void:
	"""Test getting mission briefing"""
	# No mission data
	var briefing = mission_context.get_mission_briefing()
	assert_that(briefing).is_null()
	
	# With mission data containing briefing
	mission_context.mission_data = mock_mission_data
	var briefing_data = BriefingData.new()
	briefing_data.text = "Test briefing"
	mock_mission_data.briefings.append(briefing_data)
	
	briefing = mission_context.get_mission_briefing()
	assert_that(briefing).is_equal(briefing_data)

# --- Mission Variable Management Tests ---

func test_mission_variable_management() -> void:
	"""Test mission variable setting and getting"""
	mission_context.campaign_state = mock_campaign_state
	
	# Set mission variable
	mission_context.set_mission_variable("test_var", 42)
	
	# Get mission variable
	var value = mission_context.get_mission_variable("test_var")
	assert_that(value).is_equal(42)
	
	# Get non-existent variable with default
	var default_value = mission_context.get_mission_variable("nonexistent", "default")
	assert_that(default_value).is_equal("default")

func test_mission_variable_campaign_integration() -> void:
	"""Test mission variable integration with campaign state"""
	mission_context.campaign_state = mock_campaign_state
	
	# Set variable in mission context
	mission_context.set_mission_variable("mission_var", "test_value")
	
	# Should also be set in campaign state
	var campaign_value = mock_campaign_state.get_variable("mission_var")
	assert_that(campaign_value).is_equal("test_value")

# --- Ship Selection Tests ---

func test_ship_selection() -> void:
	"""Test ship selection functionality"""
	# Select valid ship
	var success = mission_context.select_ship(mock_ship_data)
	assert_that(success).is_true()
	assert_that(mission_context.selected_ship).is_equal(mock_ship_data)
	assert_that(mission_context.selected_loadout).is_not_empty()

func test_ship_selection_validation() -> void:
	"""Test ship selection validation"""
	# Select null ship
	var success = mission_context.select_ship(null)
	assert_that(success).is_false()
	assert_that(mission_context.selected_ship).is_null()

func test_loadout_selection() -> void:
	"""Test loadout selection functionality"""
	# Must select ship first
	var loadout = {"primary_weapons": ["laser"], "secondary_weapons": ["missile"]}
	var success = mission_context.select_loadout(loadout)
	assert_that(success).is_false()
	
	# Select ship then loadout
	mission_context.select_ship(mock_ship_data)
	success = mission_context.select_loadout(loadout)
	assert_that(success).is_true()
	assert_that(mission_context.selected_loadout).is_equal(loadout)

# --- Mission Completion Tests ---

func test_mission_completion() -> void:
	"""Test mission completion handling"""
	mission_context.mission_id = "test_mission"
	mission_context.mission_data = mock_mission_data
	mission_context.campaign_state = mock_campaign_state
	mission_context.start_time = Time.get_unix_time_from_system() - 100
	
	var result_data = {"success": true, "score": 5000}
	mission_context.complete_mission(result_data)
	
	assert_that(mission_context.current_phase).is_equal(MissionContext.Phase.COMPLETED)
	assert_that(mission_context.mission_result).is_equal(result_data)
	assert_that(mission_context.end_time).is_greater(mission_context.start_time)
	assert_that(mission_context.duration).is_greater(0)

# --- Mission Summary Tests ---

func test_mission_summary() -> void:
	"""Test mission summary generation"""
	mission_context.mission_id = "test_mission"
	mission_context.mission_data = mock_mission_data
	mission_context.campaign_state = mock_campaign_state
	mission_context.selected_ship = mock_ship_data
	mission_context.briefing_acknowledged = true
	
	var summary = mission_context.get_mission_summary()
	
	assert_that(summary).has_key("mission_id")
	assert_that(summary).has_key("mission_name")
	assert_that(summary).has_key("current_phase")
	assert_that(summary).has_key("selected_ship")
	assert_that(summary).has_key("briefing_read")
	assert_that(summary).has_key("is_valid")
	
	assert_that(summary.mission_id).is_equal("test_mission")
	assert_that(summary.mission_name).is_equal("Test Mission")
	assert_that(summary.selected_ship).is_equal("Test Fighter")
	assert_that(summary.briefing_read).is_true()
	assert_that(summary.is_valid).is_true()

# --- Resource Management Tests ---

func test_resource_management() -> void:
	"""Test resource management functionality"""
	mission_context.mission_id = "test_mission"
	mission_context.mission_data = mock_mission_data
	mission_context.selected_ship = mock_ship_data
	
	# Add loaded resource
	mission_context.add_loaded_resource("test_resource.tres")
	assert_that(mission_context.loaded_resources).contains("test_resource.tres")
	
	# Don't add duplicates
	mission_context.add_loaded_resource("test_resource.tres")
	assert_that(mission_context.loaded_resources.count("test_resource.tres")).is_equal(1)
	
	# Get required resources
	var required = mission_context.get_required_resources()
	assert_that(required).is_not_empty()

# --- Edge Case Tests ---

func test_empty_mission_data_handling() -> void:
	"""Test handling of empty mission data"""
	mission_context.mission_data = null
	
	# Should handle gracefully
	var objectives = mission_context.get_mission_objectives()
	assert_that(objectives).is_empty()
	
	var ships = mission_context.get_available_ships()
	assert_that(ships).is_empty()
	
	var briefing = mission_context.get_mission_briefing()
	assert_that(briefing).is_null()

func test_mission_variable_without_campaign_state() -> void:
	"""Test mission variables without campaign state"""
	mission_context.campaign_state = null
	
	# Should still work with local storage
	mission_context.set_mission_variable("local_var", "value")
	var value = mission_context.get_mission_variable("local_var")
	assert_that(value).is_equal("value")

func test_phase_name_conversion() -> void:
	"""Test phase name conversion helper"""
	mission_context.current_phase = MissionContext.Phase.BRIEFING
	var summary = mission_context.get_mission_summary()
	assert_that(summary.current_phase).is_equal("Briefing")
	
	mission_context.current_phase = MissionContext.Phase.SHIP_SELECTION
	summary = mission_context.get_mission_summary()
	assert_that(summary.current_phase).is_equal("Ship Selection")
	
	mission_context.current_phase = MissionContext.Phase.IN_MISSION
	summary = mission_context.get_mission_summary()
	assert_that(summary.current_phase).is_equal("In Mission")