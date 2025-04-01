# scripts/mission_system/debriefing/debriefing_screen.gd
# Main script for the debriefing screen UI (debriefing_screen.tscn).
# Handles stage evaluation, text display, voice playback, stats, and awards.
class_name DebriefingScreen
extends Control # Assuming the root node is a Control

# --- Dependencies ---
const DebriefingData = preload("res://scripts/resources/mission/debriefing_data.gd")
const DebriefingStageData = preload("res://scripts/resources/mission/debriefing_stage_data.gd")
# Access GameManager, GameSequenceManager, SoundManager, MusicManager, ScoringManager, CampaignManager via singletons
# Access SEXPSystem via singleton: Engine.get_singleton("SEXPSystem")

# --- Nodes ---
# Assign these in the Godot editor
@onready var debriefing_text_label: RichTextLabel = %DebriefingTextLabel # Example path
@onready var recommendation_text_label: RichTextLabel = %RecommendationTextLabel # Example path
@onready var stats_display_node = %StatsDisplay # Example path (Could be a VBoxContainer, GridContainer, etc.)
@onready var awards_display_node = %AwardsDisplay # Example path (Node to show medals/promotions)
@onready var voice_player: AudioStreamPlayer = %VoicePlayer # Example path
@onready var next_button: Button = %NextButton
@onready var prev_button: Button = %PrevButton # Might not be needed if stages are sequential only
@onready var accept_button: Button = %AcceptButton
# Add other buttons (Replay, Help, Options?)

# --- State ---
var current_debriefing_data: DebriefingData = null
var current_stage_index: int = -1 # Start before the first valid stage
var valid_stage_indices: Array[int] = [] # Indices of stages whose SEXP evaluated to true
var num_valid_stages: int = 0
var is_voice_playing: bool = false

# --- Godot Lifecycle ---
func _ready() -> void:
	print("DebriefingScreen initialized.")
	# TODO: Get debriefing data for the current mission/team
	# current_debriefing_data = MissionManager.get_current_debriefing_data() # Example

	if current_debriefing_data == null or current_debriefing_data.stages.is_empty():
		printerr("DebriefingScreen: No debriefing data available!")
		_go_to_next_state() # Skip debriefing
		return

	# Evaluate SEXP conditions for each stage to determine which ones to show
	_evaluate_stages()

	if num_valid_stages == 0:
		printerr("DebriefingScreen: No valid stages to display after evaluation.")
		_go_to_next_state() # Skip if no stages are valid
		return

	# Initialize UI elements
	next_button.pressed.connect(_on_next_pressed)
	# prev_button.pressed.connect(_on_prev_pressed) # If allowing going back
	accept_button.pressed.connect(_on_accept_pressed)
	# Connect other button signals

	# Load the first valid stage
	current_stage_index = 0
	_load_stage(valid_stage_indices[current_stage_index])

	# TODO: Display initial stats and awards
	_display_stats()
	_display_awards()

	# TODO: Start appropriate debriefing music (success/average/fail) (call MusicManager)


func _process(delta: float) -> void:
	# Check voice playback status
	if is_voice_playing and is_instance_valid(voice_player) and not voice_player.is_playing():
		is_voice_playing = false
		# TODO: Handle voice finished (e.g., enable auto-advance?)


# --- UI Signal Handlers ---

func _on_next_pressed() -> void:
	if current_stage_index < num_valid_stages - 1:
		current_stage_index += 1
		_load_stage(valid_stage_indices[current_stage_index])
	else:
		# Reached end, maybe force accept?
		print("DebriefingScreen: Reached last stage.")
		_on_accept_pressed()


# func _on_prev_pressed() -> void: # If allowing back navigation
#	 if current_stage_index > 0:
#		 current_stage_index -= 1
#		 _load_stage(valid_stage_indices[current_stage_index])
#	 else:
#		 print("DebriefingScreen: Already at first stage.")


func _on_accept_pressed() -> void:
	print("DebriefingScreen: Accept pressed.")
	# TODO: Stop debriefing music
	# TODO: Stop any playing voice
	if is_instance_valid(voice_player): voice_player.stop()
	# TODO: Finalize mission stats (merge mission stats into all-time stats in PilotData)
	# ScoringManager.finalize_mission_stats(PilotData) # Example
	# TODO: Save campaign progress (call CampaignManager.save_progress())
	# TODO: Transition to the next game state (e.g., Main Menu, Next Mission Briefing)
	_go_to_next_state()


# --- Internal Logic ---

func _evaluate_stages() -> void:
	valid_stage_indices.clear()
	num_valid_stages = 0
	if current_debriefing_data == null: return

	for i in range(current_debriefing_data.stages.size()):
		var stage_data: DebriefingStageData = current_debriefing_data.stages[i]
		if stage_data.formula_sexp == null:
			printerr("DebriefingScreen: Stage %d has null formula SEXP." % i)
			continue # Skip stages without a formula? Or assume true? Check FS2 behavior.

		# TODO: Evaluate stage_data.formula_sexp using SEXPSystem
		var context = {} # Build context if needed
		var result = false # Placeholder: = SEXPSystem.evaluate_expression(stage_data.formula_sexp, context)

		# TEMP: Assume true for testing until SEXP is implemented
		result = true

		if result:
			valid_stage_indices.append(i)

	num_valid_stages = valid_stage_indices.size()
	print("DebriefingScreen: Found %d valid stages." % num_valid_stages)


func _load_stage(stage_data_index: int) -> void:
	if stage_data_index < 0 or stage_data_index >= current_debriefing_data.stages.size():
		printerr("DebriefingScreen: Invalid stage data index: ", stage_data_index)
		return

	print("DebriefingScreen: Loading stage index ", stage_data_index)
	var stage_data: DebriefingStageData = current_debriefing_data.stages[stage_data_index]

	# Stop previous voice
	if is_instance_valid(voice_player): voice_player.stop()
	is_voice_playing = false

	# Update debriefing text
	if is_instance_valid(debriefing_text_label):
		# TODO: Apply color codes if needed
		debriefing_text_label.text = stage_data.text

	# Update recommendation text
	if is_instance_valid(recommendation_text_label):
		recommendation_text_label.text = stage_data.recommendation_text

	# Play voice
	if not stage_data.voice_path.is_empty():
		var voice_stream = load("res://assets/voices/" + stage_data.voice_path) as AudioStream # Adjust path
		if voice_stream and is_instance_valid(voice_player):
			voice_player.stream = voice_stream
			# TODO: Set volume based on settings
			voice_player.play()
			is_voice_playing = true
		else:
			printerr("DebriefingScreen: Failed to load voice: ", stage_data.voice_path)

	# Update button states
	# prev_button.disabled = (current_stage_index == 0) # If allowing back nav
	next_button.disabled = (current_stage_index == num_valid_stages - 1)


func _display_stats() -> void:
	if not is_instance_valid(stats_display_node): return
	# TODO: Clear previous stats display
	# TODO: Get mission stats (from ScoringManager or temporary storage)
	# TODO: Populate stats_display_node with Labels, ItemLists, etc. showing:
	# - Kills (by type?)
	# - Assists
	# - Shots fired/hit percentages
	# - Friendly fire incidents
	# - Score
	pass


func _display_awards() -> void:
	if not is_instance_valid(awards_display_node): return
	# TODO: Clear previous awards display
	# TODO: Get medals/badges/promotions earned this mission (from ScoringManager or temp storage)
	# TODO: Populate awards_display_node with TextureRects (for medals/badges) and Labels (for promotion)
	pass


func _go_to_next_state() -> void:
	# Determine the next state after debriefing
	var next_state = GlobalConstants.GameState.MAIN_MENU # Default fallback
	# TODO: Check CampaignManager for next mission in campaign
	# if CampaignManager.has_next_mission():
	#	 next_state = GlobalConstants.GameState.BRIEFING # Or CMD_BRIEF?
	# else:
	#	 next_state = GlobalConstants.GameState.END_OF_CAMPAIGN # Or MAIN_MENU?

	if Engine.has_singleton("GameSequenceManager"):
		GameSequenceManager.set_state(next_state)
	else:
		printerr("DebriefingScreen: GameSequenceManager not found!")
