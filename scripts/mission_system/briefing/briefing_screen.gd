# scripts/mission_system/briefing/briefing_screen.gd
# Main script for the briefing screen UI (briefing_screen.tscn).
# Handles stage navigation, text display, voice playback, and map interaction.
class_name BriefingScreen
extends Control # Assuming the root node is a Control

# --- Dependencies ---
const BriefingData = preload("res://addons/wcs_asset_core/resources/mission/briefing_data.gd")
const BriefingStageData = preload("res://addons/wcs_asset_core/resources/mission/briefing_stage_data.gd")
# Access GameManager, GameSequenceManager, SoundManager, MusicManager via singletons

# --- Nodes ---
# Assign these in the Godot editor
@onready var briefing_text_label: RichTextLabel = %BriefingTextLabel # Example path
@onready var stage_label: Label = %StageLabel # Example path
@onready var map_manager = %BriefingMapManager # Assuming a child node with BriefingMapManager script
@onready var voice_player: AudioStreamPlayer = %VoicePlayer # Example path
@onready var next_button: Button = %NextButton
@onready var prev_button: Button = %PrevButton
@onready var commit_button: Button = %CommitButton
# Add other buttons (Help, Options, Scroll Up/Down for text?)

# --- State ---
var current_briefing_data: BriefingData = null
var current_stage_index: int = 0
var num_stages: int = 0
var is_voice_playing: bool = false
var is_text_wiping: bool = false # Flag to manage text wipe effect
var text_wipe_timer: float = 0.0
const TEXT_WIPE_CHAR_TIME = 0.02 # Seconds per character for wipe effect

# --- Godot Lifecycle ---
func _ready() -> void:
	print("BriefingScreen initialized.")
	# TODO: Get briefing data for the current mission/team
	# This might involve getting it from MissionManager or CampaignManager
	# current_briefing_data = MissionManager.get_current_briefing_data() # Example

	if current_briefing_data == null or current_briefing_data.stages.is_empty():
		printerr("BriefingScreen: No briefing data available!")
		# TODO: Handle this case gracefully (e.g., show error message, skip briefing)
		_go_to_next_state() # Example: Skip briefing
		return

	num_stages = current_briefing_data.stages.size()
	current_stage_index = 0

	# Initialize UI elements
	next_button.pressed.connect(_on_next_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	commit_button.pressed.connect(_on_commit_pressed)
	# Connect other button signals

	# Load the first stage
	_load_stage(current_stage_index)

	# TODO: Start briefing music (call MusicManager)


func _process(delta: float) -> void:
	if not is_instance_valid(briefing_text_label): return # Guard against errors if nodes not ready

	# Handle text wipe effect
	if is_text_wiping:
		text_wipe_timer += delta
		var chars_to_show = int(text_wipe_timer / TEXT_WIPE_CHAR_TIME)
		briefing_text_label.visible_characters = chars_to_show
		if chars_to_show >= briefing_text_label.get_total_character_count():
			is_text_wiping = false
			briefing_text_label.visible_characters = -1 # Show all

	# Check voice playback status
	if is_voice_playing and not voice_player.is_playing():
		is_voice_playing = false
		# TODO: Handle voice finished (e.g., enable auto-advance?)

	# TODO: Handle auto-advance logic if enabled (check Player settings)
	# if Player.auto_advance and not is_voice_playing and not is_text_wiping:
	#	 _check_auto_advance_timer(delta)


# --- UI Signal Handlers ---

func _on_next_pressed() -> void:
	if current_stage_index < num_stages - 1:
		current_stage_index += 1
		_load_stage(current_stage_index)
	else:
		# Reached end, maybe loop or go to commit?
		print("BriefingScreen: Reached last stage.")
		# Optionally automatically press commit: _on_commit_pressed()


func _on_prev_pressed() -> void:
	if current_stage_index > 0:
		current_stage_index -= 1
		_load_stage(current_stage_index)
	else:
		print("BriefingScreen: Already at first stage.")


func _on_commit_pressed() -> void:
	print("BriefingScreen: Commit pressed.")
	# TODO: Stop briefing music
	# TODO: Stop any playing voice
	if is_instance_valid(voice_player): voice_player.stop()
	# TODO: Transition to the next game state (e.g., Ship Select or Gameplay)
	_go_to_next_state()


# --- Internal Logic ---

func _load_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= num_stages:
		printerr("BriefingScreen: Invalid stage index: ", stage_index)
		return

	print("BriefingScreen: Loading stage ", stage_index + 1)
	var stage_data: BriefingStageData = current_briefing_data.stages[stage_index]

	# Stop previous voice
	if is_instance_valid(voice_player): voice_player.stop()
	is_voice_playing = false

	# Update stage label
	if is_instance_valid(stage_label):
		stage_label.text = "Stage %d of %d" % [stage_index + 1, num_stages]

	# Update briefing text and start wipe effect
	if is_instance_valid(briefing_text_label):
		# TODO: Apply color codes from original text format if needed
		briefing_text_label.text = stage_data.text
		briefing_text_label.visible_characters = 0
		text_wipe_timer = 0.0
		is_text_wiping = true
		# TODO: Play text wipe sound (call SoundManager)

	# Play voice
	if not stage_data.voice_path.is_empty():
		var voice_stream = load("res://assets/voices/" + stage_data.voice_path) as AudioStream # Adjust path
		if voice_stream and is_instance_valid(voice_player):
			voice_player.stream = voice_stream
			# TODO: Set volume based on settings
			voice_player.play()
			is_voice_playing = true
		else:
			printerr("BriefingScreen: Failed to load voice: ", stage_data.voice_path)

	# Update map manager (camera, icons, lines)
	if is_instance_valid(map_manager):
		map_manager.set_stage_data(stage_data) # Assuming map_manager has this method

	# Update button states
	prev_button.disabled = (stage_index == 0)
	# next_button.disabled = (stage_index == num_stages - 1) # Or allow wrapping/commit


func _go_to_next_state() -> void:
	# Determine the next state after briefing (e.g., Ship Select or direct to Gameplay)
	# This might depend on mission flags or campaign context.
	var next_state = GlobalConstants.GameState.SHIP_SELECT # Default assumption
	# TODO: Add logic to check if ship/weapon select is needed for this mission

	if Engine.has_singleton("GameSequenceManager"):
		GameSequenceManager.set_state(next_state)
	else:
		printerr("BriefingScreen: GameSequenceManager not found!")
