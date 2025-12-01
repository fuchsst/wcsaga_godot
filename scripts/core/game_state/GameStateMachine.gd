class_name GameStateMachine
extends LimboHSM

# Global State Machine (LimboAI Refactor)
# Manages high-level game states using Hierarchical State Machine

# State Nodes
var state_intro: GameStateIntro
var state_main_menu: GameStateMainMenu
var state_gameplay: GameStateGameplay

func _init() -> void:
	# Initialize states
	state_intro = GameStateIntro.new()
	state_main_menu = GameStateMainMenu.new()
	state_gameplay = GameStateGameplay.new()

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
