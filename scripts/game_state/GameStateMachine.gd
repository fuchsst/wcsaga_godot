extends LimboHSM

# Global State Machine (LimboAI Refactor)
# Manages high-level game states using Hierarchical State Machine

# State Nodes (use aliases to avoid shadowing global classes)
const IntroStateClass = preload("res://scripts/game_state/states/GameStateIntro.gd")
const MainMenuStateClass = preload("res://scripts/game_state/states/GameStateMainMenu.gd")
const GameplayStateClass = preload("res://scripts/game_state/states/GameStateGameplay.gd")

var state_intro: IntroStateClass
var state_main_menu: MainMenuStateClass
var state_gameplay: GameplayStateClass

func _init() -> void:
	# Initialize states
	state_intro = IntroStateClass.new()
	state_main_menu = MainMenuStateClass.new()
	state_gameplay = GameplayStateClass.new()

func _ready() -> void:
	# Setup HSM
	add_child(state_intro)
	add_child(state_main_menu)
	add_child(state_gameplay)
	
	# Define transitions
	# Intro -> MainMenu
	add_transition(state_intro, state_main_menu, &"to_main_menu")
	
	# MainMenu -> Gameplay
	add_transition(state_main_menu, state_gameplay, &"start_game")
	
	# Gameplay -> MainMenu
	add_transition(state_gameplay, state_main_menu, &"to_main_menu")
	
	# Initialize
	initial_state = state_intro
	initialize(self)
	set_active(true)
	
	print("GameStateMachine (LimboAI) Initialized")

# Helper to trigger transitions globally
func transition_to(event: StringName) -> void:
	dispatch(event)
