extends LimboHSM

# Global State Machine (LimboAI Refactor)
# Manages high-level game states using Hierarchical State Machine
# Flow: Intro -> CampaignSelect -> MainHall -> Mission Flow -> Debrief

# State Classes
const IntroStateClass = preload("res://scripts/core/game_state/states/GameStateIntro.gd")
const CampaignSelectStateClass = preload(
	"res://scripts/core/game_state/states/GameStateCampaignSelect.gd"
)
const MainHallStateClass = preload("res://scripts/core/game_state/states/GameStateMainHall.gd")
const BriefingStateClass = preload("res://scripts/core/game_state/states/GameStateBriefing.gd")
const GameplayStateClass = preload("res://scripts/core/game_state/states/GameStateGameplay.gd")
const DebriefStateClass = preload("res://scripts/core/game_state/states/GameStateDebrief.gd")
const PauseStateClass = preload("res://scripts/core/game_state/states/GameStatePause.gd")
const ShipSelectStateClass = preload("res://scripts/core/game_state/states/GameStateShipSelect.gd")
const WeaponSelectStateClass = preload(
	"res://scripts/core/game_state/states/GameStateWeaponSelect.gd"
)
const CmdBriefStateClass = preload("res://scripts/core/game_state/states/GameStateCmdBrief.gd")
const FictionStateClass = preload("res://scripts/core/game_state/states/GameStateFictionViewer.gd")
const OptionsStateClass = preload("res://scripts/core/game_state/states/GameStateOptions.gd")
const TechRoomStateClass = preload("res://scripts/core/game_state/states/GameStateTechRoom.gd")
const BarracksStateClass = preload("res://scripts/core/game_state/states/GameStateBarracks.gd")
const CampaignIntroStateClass = preload(
	"res://scripts/core/game_state/states/GameStateCampaignIntro.gd"
)

# State Instances
var state_intro: LimboState
var state_campaign_select: LimboState  # Timeline / campaign selection
var state_main_hall: LimboState  # Bridge / in-mission menu
var state_briefing: LimboState
var state_gameplay: LimboState
var state_debrief: LimboState
var state_pause: LimboState
var state_ship_select: LimboState
var state_weapon_select: LimboState
var state_cmd_brief: LimboState
var state_fiction: LimboState
var state_options: LimboState
var state_tech_room: LimboState
var state_barracks: LimboState
var state_campaign_intro: LimboState  # Campaign intro cutscene


func _init() -> void:
	# Initialize all states
	state_intro = IntroStateClass.new()
	state_campaign_select = CampaignSelectStateClass.new()
	state_main_hall = MainHallStateClass.new()
	state_briefing = BriefingStateClass.new()
	state_gameplay = GameplayStateClass.new()
	state_debrief = DebriefStateClass.new()
	state_pause = PauseStateClass.new()
	state_ship_select = ShipSelectStateClass.new()
	state_weapon_select = WeaponSelectStateClass.new()
	state_cmd_brief = CmdBriefStateClass.new()
	state_fiction = FictionStateClass.new()
	state_options = OptionsStateClass.new()
	state_tech_room = TechRoomStateClass.new()
	state_barracks = BarracksStateClass.new()
	state_campaign_intro = CampaignIntroStateClass.new()


func _ready() -> void:
	# Add all states to HSM
	add_child(state_intro)
	add_child(state_campaign_select)
	add_child(state_main_hall)
	add_child(state_briefing)
	add_child(state_gameplay)
	add_child(state_debrief)
	add_child(state_pause)
	add_child(state_ship_select)
	add_child(state_weapon_select)
	add_child(state_cmd_brief)
	add_child(state_fiction)
	add_child(state_options)
	add_child(state_tech_room)
	add_child(state_barracks)
	add_child(state_campaign_intro)

	# === CORE FLOW ===

	# Intro -> CampaignSelect (timeline)
	add_transition(state_intro, state_campaign_select, &"to_campaign_select")

	# CampaignSelect -> CampaignIntro (play campaign intro cutscene)
	add_transition(state_campaign_select, state_campaign_intro, &"to_campaign_intro")

	# CampaignIntro -> MainHall (after cutscene)
	add_transition(state_campaign_intro, state_main_hall, &"to_main_hall")

	# CampaignSelect -> MainHall (skip intro, returning from debrief)
	add_transition(state_campaign_select, state_main_hall, &"to_main_hall")

	# === MAIN HALL NAVIGATION ===

	# MainHall -> Options
	add_transition(state_main_hall, state_options, &"to_options")
	add_transition(state_options, state_main_hall, &"options_closed")

	# MainHall -> Tech Room
	add_transition(state_main_hall, state_tech_room, &"to_tech_room")
	add_transition(state_tech_room, state_main_hall, &"to_main_hall")

	# MainHall -> Barracks
	add_transition(state_main_hall, state_barracks, &"to_barracks")
	add_transition(state_barracks, state_main_hall, &"to_main_hall")

	# MainHall -> CampaignSelect (back)
	add_transition(state_main_hall, state_campaign_select, &"to_campaign_select")

	# === MISSION START FLOW ===

	# MainHall -> CmdBrief (start mission with command briefing)
	add_transition(state_main_hall, state_cmd_brief, &"start_mission")

	# CmdBrief -> Briefing
	add_transition(state_cmd_brief, state_briefing, &"to_briefing")

	# MainHall -> Briefing (skip cmd brief)
	add_transition(state_main_hall, state_briefing, &"to_briefing")

	# === FICTION FLOW ===
	add_transition(state_briefing, state_fiction, &"to_fiction")
	add_transition(state_fiction, state_ship_select, &"fiction_done")

	# === LOADOUT FLOW ===
	add_transition(state_briefing, state_ship_select, &"to_ship_select")
	add_transition(state_ship_select, state_weapon_select, &"to_weapon_select")
	add_transition(state_weapon_select, state_gameplay, &"start_game")
	add_transition(state_briefing, state_gameplay, &"start_game")

	# === BACK NAVIGATION ===
	add_transition(state_ship_select, state_briefing, &"to_briefing")
	add_transition(state_weapon_select, state_ship_select, &"to_ship_select")
	add_transition(state_briefing, state_main_hall, &"to_main_hall")

	# === GAMEPLAY TRANSITIONS ===
	add_transition(state_gameplay, state_pause, &"pause_game")
	add_transition(state_pause, state_gameplay, &"resume_game")
	add_transition(state_pause, state_options, &"to_options")
	add_transition(state_pause, state_main_hall, &"to_main_hall")

	add_transition(state_gameplay, state_debrief, &"mission_ended")
	add_transition(state_gameplay, state_main_hall, &"to_main_hall")

	# === DEBRIEF FLOW ===
	add_transition(state_debrief, state_main_hall, &"to_main_hall")
	add_transition(state_debrief, state_cmd_brief, &"start_mission")

	# Initialize HSM
	initial_state = state_intro
	initialize(self)
	set_active(true)

	print("GameStateMachine Initialized with 14 states")


func transition_to(event: StringName) -> void:
	dispatch(event)


func get_current_state_name() -> String:
	if get_active_state():
		return get_active_state().name
	return "None"
