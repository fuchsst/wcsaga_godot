extends LimboHSM

# Global State Machine (LimboAI Refactor)
# Manages high-level game states using Hierarchical State Machine
# Full mission flow: MainMenu -> Briefing -> Gameplay -> Debrief -> MainMenu

# State Nodes (use aliases to avoid shadowing global classes)
const IntroStateClass = preload("res://scripts/core/game_state/states/GameStateIntro.gd")
const MainMenuStateClass = preload("res://scripts/core/game_state/states/GameStateMainMenu.gd")
const BriefingStateClass = preload("res://scripts/core/game_state/states/GameStateBriefing.gd")
const GameplayStateClass = preload("res://scripts/core/game_state/states/GameStateGameplay.gd")
const DebriefStateClass = preload("res://scripts/core/game_state/states/GameStateDebrief.gd")

var state_intro: IntroStateClass
var state_main_menu: MainMenuStateClass
var state_briefing: BriefingStateClass
var state_gameplay: GameplayStateClass
var state_debrief: DebriefStateClass


func _init() -> void:
	# Initialize states
	state_intro = IntroStateClass.new()
	state_main_menu = MainMenuStateClass.new()
	state_briefing = BriefingStateClass.new()
	state_gameplay = GameplayStateClass.new()
	state_debrief = DebriefStateClass.new()


func _ready() -> void:
	# Setup HSM
	add_child(state_intro)
	add_child(state_main_menu)
	add_child(state_briefing)
	add_child(state_gameplay)
	add_child(state_debrief)

	# Define transitions
	# Intro -> MainMenu
	add_transition(state_intro, state_main_menu, &"to_main_menu")

	# MainMenu -> Briefing (start mission flow)
	add_transition(state_main_menu, state_briefing, &"start_mission")

	# MainMenu -> Gameplay (skip briefing for quick start)
	add_transition(state_main_menu, state_gameplay, &"start_game")

	# Briefing -> Gameplay (launch mission)
	add_transition(state_briefing, state_gameplay, &"start_game")

	# Briefing -> MainMenu (cancel)
	add_transition(state_briefing, state_main_menu, &"to_main_menu")

	# Gameplay -> Debrief (mission ended)
	add_transition(state_gameplay, state_debrief, &"mission_ended")

	# Gameplay -> MainMenu (abort)
	add_transition(state_gameplay, state_main_menu, &"to_main_menu")

	# Debrief -> MainMenu
	add_transition(state_debrief, state_main_menu, &"to_main_menu")

	# Initialize
	initial_state = state_intro
	initialize(self)
	set_active(true)

	print("GameStateMachine (LimboAI) Initialized with 5 states")


# Helper to trigger transitions globally
func transition_to(event: StringName) -> void:
	dispatch(event)
