extends Node

# Application Entry Point
# Handles global initialization and high-level application lifecycle

func _ready() -> void:
	print("Wing Commander Saga: Godot Edition - Initializing...")
	
	# Initialize global systems
	_initialize_systems()
	
	# Transition to initial state is handled by HSM initialization
	# GameStateMachine.change_state(GameStateMachine.State.INTRO)

func _initialize_systems() -> void:
	# Initialize InputManager (Autoload)
	# Initialize AudioManager (Autoload) - To be implemented
	# Initialize Settings (Autoload) - To be implemented
	print("Systems Initialized.")
