# scripts/core_systems/game_manager.gd
# Singleton (Autoload) responsible for managing core game state like time and pausing.
# Corresponds to parts of freespace.cpp functionality.
class_name GameManager
extends Node

# --- Dependencies ---
# Access other singletons directly via their names (e.g., GameSettings)

# --- Core Game State ---
var mission_time: float = 0.0
var is_paused: bool = false
# Note: Time compression is handled globally via Engine.time_scale

# --- Settings ---
var settings: GameSettings = null

func _ready() -> void:
	# Load game settings (assuming GameSettings is an Autoload)
	if Engine.has_singleton("GameSettings"):
		settings = GameSettings
	else:
		# Fallback if GameSettings isn't an Autoload (less ideal)
		# Ensure GameSettings script exists in scripts/globals/
		var GameSettingsCls = load("res://scripts/globals/game_settings.gd")
		if GameSettingsCls:
			settings = GameSettingsCls.load_or_create()
			print("GameManager: Loaded GameSettings manually.")
		else:
			printerr("GameManager: GameSettings script not found at res://scripts/globals/game_settings.gd")


	print("GameManager initialized.")
	# Ensure the game isn't paused when the manager starts
	get_tree().paused = false
	is_paused = false
	Engine.time_scale = 1.0 # Reset time scale

func _physics_process(delta: float) -> void:
	# Update mission time only if not paused and time is flowing
	if not get_tree().paused and Engine.time_scale > 0:
		# Use the *unscaled* delta time multiplied by the time scale
		# to correctly track mission time even when time compression changes.
		mission_time += get_physics_process_delta_time() * Engine.time_scale

# --- Public Methods ---

func pause_game():
	if not is_paused:
		get_tree().paused = true
		is_paused = true
		# TODO: Emit a signal game_paused?
		print("GameManager: Game Paused.")

func unpause_game():
	if is_paused:
		get_tree().paused = false
		is_paused = false
		# TODO: Emit a signal game_unpaused?
		print("GameManager: Game Unpaused.")

func toggle_pause():
	if is_paused:
		unpause_game()
	else:
		pause_game()

func set_time_compression(factor: float):
	# Clamp factor to reasonable limits (e.g., 0.1x to 10x)
	var clamped_factor = clamp(factor, 0.1, 10.0)
	Engine.time_scale = clamped_factor
	print("GameManager: Time compression set to %.2fx" % Engine.time_scale)
	# TODO: Emit signal time_compression_changed?

func get_time_compression() -> float:
	return Engine.time_scale

func get_mission_time() -> float:
	return mission_time

func reset_mission_time():
	mission_time = 0.0

# --- TODO ---
# - Add methods/signals to interact with GameSequenceManager for state changes.
# - Integrate difficulty settings from GameSettings to affect gameplay parameters globally.
# - Handle mission start/end logic (resetting time, etc.).
