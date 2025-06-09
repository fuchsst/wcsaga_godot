extends GdUnitTestSuite

## Unit tests for MissionContextManager
## Tests mission flow coordination and context management using existing systems

const MissionContextManager = preload("res://scripts/core/game_flow/mission_context/mission_context_manager.gd")
const MissionContext = preload("res://scripts/core/game_flow/mission_context/mission_context.gd")
const MissionData = preload("res://addons/wcs_asset_core/resources/mission/mission_data.gd")
const CampaignState = preload("res://addons/wcs_asset_core/resources/save_system/campaign_state.gd")
const ShipData = preload("res://addons/wcs_asset_core/resources/ship/ship_data.gd")

var mission_context_manager: MissionContextManager
var mock_campaign_state: CampaignState
var mock_mission_data: MissionData

func before_test() -> void:
	# Create mission context manager
	mission_context_manager = MissionContextManager.new()
	
	# Create mock campaign state
	mock_campaign_state = CampaignState.new()
	mock_campaign_state.initialize_from_campaign_data({
		"campaign_name": "Test Campaign",
		"total_missions": 5
	})
	
	# Create mock mission data
	_setup_mock_mission_data()

func after_test() -> void:
	mission_context_manager = null
	mock_campaign_state = null
	mock_mission_data = null
	MissionContextManager.instance = null

func _setup_mock_mission_data() -> void:
	mock_mission_data = MissionData.new()
	mock_mission_data.mission_title = "Test Mission"
	mock_mission_data.mission_desc = "A test mission for unit testing"
	mock_mission_data.num_players = 1
	
	# Create mock briefing data
	var briefing_data = BriefingData.new()
	briefing_data.text = "Test briefing text"
	mock_mission_data.briefings.append(briefing_data)

# --- Basic Functionality Tests ---

func test_mission_context_manager_initialization() -> void:
	"""Test MissionContextManager initializes correctly"""
	assert_that(mission_context_manager).is_not_null()
	assert_that(mission_context_manager.resource_coordinator).is_not_null()
	assert_that(mission_context_manager.current_mission).is_null()
	assert_that(mission_context_manager.mission_history).is_empty()

func test_start_mission_sequence_success() -> void:
	"""Test successful mission sequence start"""
	# Mock the mission loading by setting mission_data directly
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		if mission_id == "test_mission":
			return mock_mission_data
		return null
	
	var signal_received = false
	var received_mission = null
	
	# Connect to signal
	mission_context_manager.mission_sequence_started.connect(func(mission: MissionContext):
		signal_received = true
		received_mission = mission
	)
	
	# Start mission sequence
	var success = mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	
	# Verify success
	assert_that(success).is_true()
	assert_that(mission_context_manager.current_mission).is_not_null()
	assert_that(mission_context_manager.current_mission.mission_id).is_equal("test_mission")
	assert_that(mission_context_manager.current_mission.mission_data).is_equal(mock_mission_data)
	assert_that(mission_context_manager.current_mission.campaign_state).is_equal(mock_campaign_state)
	
	# Verify signal emission
	assert_that(signal_received).is_true()
	assert_that(received_mission).is_equal(mission_context_manager.current_mission)

func test_start_mission_sequence_failure() -> void:
	"""Test mission sequence start failure with invalid mission"""
	# Mock failed mission loading
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return null
	
	var success = mission_context_manager.start_mission_sequence("invalid_mission", mock_campaign_state)
	
	# Verify failure
	assert_that(success).is_false()
	assert_that(mission_context_manager.current_mission).is_null()

func test_complete_mission_sequence() -> void:
	"""Test mission sequence completion"""
	# Start a mission first
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	
	var signal_received = false
	var received_mission = null
	var received_result = {}
	
	# Connect to completion signal
	mission_context_manager.mission_sequence_completed.connect(func(mission: MissionContext, result: Dictionary):
		signal_received = true
		received_mission = mission
		received_result = result
	)
	
	# Complete mission
	var mission_result = {"success": true, "score": 5000}
	mission_context_manager.complete_mission_sequence(mission_result)
	
	# Verify completion
	assert_that(signal_received).is_true()
	assert_that(received_result).is_equal(mission_result)
	assert_that(mission_context_manager.current_mission).is_null()
	assert_that(mission_context_manager.mission_history.size()).is_equal(1)

# --- State Transition Tests ---

func test_transition_to_briefing() -> void:
	"""Test transition to briefing state"""
	# Setup mission
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	
	# Mock GameStateManager transition
	GameStateManager.transition_to_state = func(state: GameStateManager.GameState, data: Dictionary) -> bool:
		return state == GameStateManager.GameState.MISSION_BRIEFING
	
	# Test transition
	var success = mission_context_manager.transition_to_briefing()
	
	assert_that(success).is_true()
	assert_that(mission_context_manager.current_mission.current_phase).is_equal(MissionContext.Phase.BRIEFING)

func test_transition_to_ship_selection() -> void:
	"""Test transition to ship selection state"""
	# Setup mission in briefing phase
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	mission_context_manager.current_mission.current_phase = MissionContext.Phase.BRIEFING
	mission_context_manager.current_mission.briefing_acknowledged = true
	
	# Mock GameStateManager transition
	GameStateManager.transition_to_state = func(state: GameStateManager.GameState, data: Dictionary) -> bool:
		return state == GameStateManager.GameState.SHIP_SELECTION
	
	# Test transition
	var success = mission_context_manager.transition_to_ship_selection()
	
	assert_that(success).is_true()
	assert_that(mission_context_manager.current_mission.current_phase).is_equal(MissionContext.Phase.SHIP_SELECTION)

func test_transition_to_mission_loading() -> void:
	"""Test transition to mission loading state"""
	# Setup mission in ship selection phase
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	mission_context_manager.current_mission.current_phase = MissionContext.Phase.SHIP_SELECTION
	
	# Mock selected ship
	var mock_ship = ShipData.new()
	mock_ship.display_name = "Test Ship"
	mission_context_manager.current_mission.selected_ship = mock_ship
	
	# Mock GameStateManager transition
	GameStateManager.transition_to_state = func(state: GameStateManager.GameState, data: Dictionary) -> bool:
		return state == GameStateManager.GameState.MISSION_LOADING
	
	# Test transition
	var success = mission_context_manager.transition_to_mission_loading()
	
	assert_that(success).is_true()
	assert_that(mission_context_manager.current_mission.current_phase).is_equal(MissionContext.Phase.LOADING)

func test_transition_to_in_mission() -> void:
	"""Test transition to in-mission state"""
	# Setup mission in loading phase
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	mission_context_manager.current_mission.current_phase = MissionContext.Phase.LOADING
	mission_context_manager.current_mission.resource_loading_progress = 1.0
	
	# Mock MissionManager initialization
	MissionManager.load_mission = func(path: String) -> bool:
		return true
	MissionManager.start_mission = func() -> bool:
		return true
	
	# Mock GameStateManager transition
	GameStateManager.transition_to_state = func(state: GameStateManager.GameState, data: Dictionary) -> bool:
		return state == GameStateManager.GameState.IN_MISSION
	
	# Test transition
	var success = mission_context_manager.transition_to_in_mission()
	
	assert_that(success).is_true()
	assert_that(mission_context_manager.current_mission.current_phase).is_equal(MissionContext.Phase.IN_MISSION)

func test_transition_to_debriefing() -> void:
	"""Test transition to debriefing state"""
	# Setup mission in completed phase
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	mission_context_manager.current_mission.current_phase = MissionContext.Phase.COMPLETED
	mission_context_manager.current_mission.mission_result = {"success": true, "score": 1000}
	
	# Mock GameStateManager transition
	GameStateManager.transition_to_state = func(state: GameStateManager.GameState, data: Dictionary) -> bool:
		return state == GameStateManager.GameState.MISSION_DEBRIEFING
	
	# Test transition
	var success = mission_context_manager.transition_to_debriefing()
	
	assert_that(success).is_true()
	assert_that(mission_context_manager.current_mission.current_phase).is_equal(MissionContext.Phase.DEBRIEFING)

# --- Error Handling Tests ---

func test_transition_without_active_mission() -> void:
	"""Test state transitions fail without active mission"""
	var success = mission_context_manager.transition_to_briefing()
	assert_that(success).is_false()

func test_invalid_phase_transitions() -> void:
	"""Test invalid phase transitions are rejected"""
	# Setup mission
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	
	# Try to go to ship selection without acknowledging briefing
	mission_context_manager.current_mission.current_phase = MissionContext.Phase.BRIEFING
	mission_context_manager.current_mission.briefing_acknowledged = false
	
	var success = mission_context_manager.transition_to_ship_selection()
	assert_that(success).is_false()

func test_mission_loading_without_ship_selection() -> void:
	"""Test mission loading fails without ship selection"""
	# Setup mission in ship selection phase without ship
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	mission_context_manager.current_mission.current_phase = MissionContext.Phase.SHIP_SELECTION
	mission_context_manager.current_mission.selected_ship = null
	
	var success = mission_context_manager.transition_to_mission_loading()
	assert_that(success).is_false()

# --- Integration Tests ---

func test_mission_phase_change_signals() -> void:
	"""Test mission phase change signals are emitted"""
	# Setup mission
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	
	var signal_received = false
	var old_phase = null
	var new_phase = null
	
	# Connect to phase change signal
	mission_context_manager.mission_phase_changed.connect(func(mission: MissionContext, old_p: MissionContext.Phase, new_p: MissionContext.Phase):
		signal_received = true
		old_phase = old_p
		new_phase = new_p
	)
	
	# Mock GameStateManager
	GameStateManager.transition_to_state = func(state: GameStateManager.GameState, data: Dictionary) -> bool:
		return true
	
	# Transition to briefing
	mission_context_manager.transition_to_briefing()
	
	# Verify signal
	assert_that(signal_received).is_true()
	assert_that(new_phase).is_equal(MissionContext.Phase.BRIEFING)

func test_mission_context_accessors() -> void:
	"""Test mission context accessor methods"""
	# Test without active mission
	assert_that(mission_context_manager.get_current_mission()).is_null()
	assert_that(mission_context_manager.is_mission_active()).is_false()
	assert_that(mission_context_manager.get_mission_history()).is_empty()
	
	# Start a mission
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	mission_context_manager.start_mission_sequence("test_mission", mock_campaign_state)
	
	# Test with active mission
	assert_that(mission_context_manager.get_current_mission()).is_not_null()
	assert_that(mission_context_manager.is_mission_active()).is_true()
	
	# Complete mission and test history
	mission_context_manager.complete_mission_sequence({"success": true})
	
	assert_that(mission_context_manager.get_current_mission()).is_null()
	assert_that(mission_context_manager.is_mission_active()).is_false()
	assert_that(mission_context_manager.get_mission_history().size()).is_equal(1)

func test_mission_history_management() -> void:
	"""Test mission history management and limits"""
	mission_context_manager._load_mission_data = func(mission_id: String) -> MissionData:
		return mock_mission_data
	
	# Complete 12 missions to test history limit (max 10)
	for i in range(12):
		mission_context_manager.start_mission_sequence("test_mission_%d" % i, mock_campaign_state)
		mission_context_manager.complete_mission_sequence({"success": true, "mission_number": i})
	
	# Verify history is limited to 10
	assert_that(mission_context_manager.mission_history.size()).is_equal(10)
	
	# Verify oldest missions were removed (should have missions 2-11)
	var first_mission = mission_context_manager.mission_history[0]
	assert_that(first_mission.mission_id).is_equal("test_mission_2")