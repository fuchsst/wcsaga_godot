# scripts/sound_animation/music_manager.gd
extends Node
# Autoload Singleton for managing event-driven music playback.

# Reference to the MusicData autoload
# Use get_node_or_null to avoid errors if MusicData isn't ready yet during _ready
@onready var MusicData = get_node_or_null("/root/MusicData")

# TODO: Add references to other necessary managers/singletons if needed for state checks
# @onready var MissionManager = get_node_or_null("/root/MissionManager")
# @onready var ObjectManager = get_node_or_null("/root/ObjectManager")
# @onready var PlayerData = get_node_or_null("/root/PlayerData") # Assuming player state access needed

# Enum for music states, mirroring original logic.
enum MusicState { NORMAL, BATTLE, ARRIVAL, VICTORY, FAILURE, DEAD }

var current_state: MusicState = MusicState.NORMAL
var current_pattern: MusicEntry.MusicPattern = MusicEntry.MusicPattern.NONE
var next_pattern: MusicEntry.MusicPattern = MusicEntry.MusicPattern.NONE # Pattern explicitly requested via force_transition
var pending_pattern: MusicEntry.MusicPattern = MusicEntry.MusicPattern.NONE # Default pattern to play after current one finishes naturally

var current_loop_count: int = 0
var force_transition: bool = false
var is_fs1_cycle_mode: bool = false # Based on loaded soundtrack flags
var current_soundtrack_name: String = "" # Store the name of the loaded soundtrack

var music_player: AudioStreamPlayer
var fade_tween: Tween

# Timestamps for event debouncing/timing
var battle_over_timestamp: int = 0
var hostile_presence_timestamp: int = 0
var mission_over_timestamp: int = 0
var next_arrival_timestamp: int = 0
var check_for_battle_music_timestamp: int = 0

const BATTLE_START_INTERVAL = 1000
const ARRIVAL_INTERVAL_TIMESTAMP = 3000
const HOSTILE_PRESENCE_CHECK_INTERVAL = 1000
const MISSION_OVER_CHECK_INTERVAL = 3000
const BATTLE_OVER_INTERVAL = 5000
const PATTERN_DELAY_SHORT = 150 # ms delay before starting first pattern

var _initial_pattern_timer: Timer = null

func _ready():
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	# Assign to a specific bus if using separate buses for music/sfx
	# music_player.bus = "Music"
	add_child(music_player)
	music_player.connect("finished", Callable(self, "_on_music_finished"))

	# Ensure MusicData is available
	if MusicData == null:
		printerr("MusicManager: MusicData autoload not found!")
		set_process(false) # Disable processing if MusicData is missing
		return

	# TODO: Connect to relevant game signals (battle state, goal state, player death, arrivals)
	# Example: GameManager.battle_state_changed.connect(_on_battle_state_changed)
	# Example: MissionManager.goal_state_changed.connect(_on_goal_state_changed)
	# Example: Player.died.connect(_on_player_died)
	# Example: SpawnManager.ship_arrived.connect(_on_ship_arrived)

	# Initialize timestamps
	_reset_timers()

func _reset_timers():
	"""Resets all event check timers."""
	var current_time = Time.get_ticks_msec()
	hostile_presence_timestamp = current_time + HOSTILE_PRESENCE_CHECK_INTERVAL
	mission_over_timestamp = current_time + MISSION_OVER_CHECK_INTERVAL
	check_for_battle_music_timestamp = current_time # Check immediately
	next_arrival_timestamp = current_time # Allow immediate arrival check
	battle_over_timestamp = 0 # Not waiting to transition out of battle

func load_soundtrack(soundtrack_name: String):
	"""Loads music data for a specific soundtrack."""
	if MusicData == null:
		printerr("MusicManager: Cannot load soundtrack, MusicData is null.")
		return

	current_soundtrack_name = soundtrack_name
	var flags = MusicData.get_soundtrack_flags(soundtrack_name)
	# Assuming flags are defined in GlobalConstants or similar
	# Example: is_fs1_cycle_mode = (flags & GlobalConstants.EMF_CYCLE_FS1) != 0
	# Placeholder check based on original code comment:
	is_fs1_cycle_mode = false # Default to FS2 style unless flag indicates otherwise
	if flags != 0: # Replace with actual flag check, e.g., flags & EMF_CYCLE_FS1
		# is_fs1_cycle_mode = true # Example
		pass

	print("MusicManager: Loaded soundtrack '%s'. FS1 Cycle Mode: %s" % [soundtrack_name, is_fs1_cycle_mode])
	# TODO: Potentially preload some music streams if needed (though usually streamed)

func start_music(start_in_battle: bool = false):
	"""Starts the music system, usually called at mission start."""
	if MusicData == null: return # Guard against missing MusicData

	stop_music() # Ensure clean state
	_reset_timers() # Reset timers when starting new music sequence

	var initial_pattern_type = MusicEntry.MusicPattern.NRML_1
	# Use the current soundtrack name stored during load_soundtrack
	if current_soundtrack_name == "":
		printerr("MusicManager: No soundtrack loaded before calling start_music!")
		return

	if start_in_battle or _check_hostile_presence():
		initial_pattern_type = MusicEntry.MusicPattern.BTTL_1
		current_state = MusicState.BATTLE
	else:
		current_state = MusicState.NORMAL

	var initial_entry = MusicData.get_entry(initial_pattern_type, current_soundtrack_name)
	if initial_entry:
		current_pattern = initial_pattern_type
		# Use the correct function to get the next pattern based on the loaded entry
		pending_pattern = _get_default_next_pattern(initial_entry) # Set initial pending pattern
		next_pattern = pending_pattern # Initialize next_pattern as well
		current_loop_count = initial_entry.default_loop_for

		# Delay starting the first pattern slightly
		if _initial_pattern_timer != null and is_instance_valid(_initial_pattern_timer):
			_initial_pattern_timer.stop()
			_initial_pattern_timer.queue_free()

		_initial_pattern_timer = Timer.new()
		_initial_pattern_timer.wait_time = PATTERN_DELAY_SHORT / 1000.0
		_initial_pattern_timer.one_shot = true
		_initial_pattern_timer.connect("timeout", Callable(self, "_play_current_pattern"), CONNECT_ONE_SHOT) # Use CONNECT_ONE_SHOT
		add_child(_initial_pattern_timer)
		_initial_pattern_timer.start()
		print("MusicManager: Starting music with pattern: ", MusicEntry.MusicPattern.keys()[current_pattern])
	# TODO: Potentially preload some music streams if needed (though usually streamed)

func start_music(start_in_battle: bool = false):
	"""Starts the music system, usually called at mission start."""
	if MusicData == null: return # Guard against missing MusicData

	stop_music() # Ensure clean state
	_reset_timers() # Reset timers when starting new music sequence

	var initial_pattern_type = MusicEntry.MusicPattern.NRML_1
	# Use the current soundtrack name stored during load_soundtrack
	if current_soundtrack_name == "":
		printerr("MusicManager: No soundtrack loaded before calling start_music!")
		return

	if start_in_battle or _check_hostile_presence():
		initial_pattern_type = MusicEntry.MusicPattern.BTTL_1
		current_state = MusicState.BATTLE
	else:
		current_state = MusicState.NORMAL

	var initial_entry = MusicData.get_entry(initial_pattern_type, current_soundtrack_name)
	if initial_entry:
		current_pattern = initial_pattern_type
		# Use the correct function to get the next pattern based on the loaded entry
		pending_pattern = _get_default_next_pattern(initial_entry) # Set initial pending pattern
		next_pattern = pending_pattern # Initialize next_pattern as well
		current_loop_count = initial_entry.default_loop_for

		# Delay starting the first pattern slightly
		if _initial_pattern_timer != null and is_instance_valid(_initial_pattern_timer):
			_initial_pattern_timer.stop()
			_initial_pattern_timer.queue_free()

		_initial_pattern_timer = Timer.new()
		_initial_pattern_timer.wait_time = PATTERN_DELAY_SHORT / 1000.0
		_initial_pattern_timer.one_shot = true
		_initial_pattern_timer.connect("timeout", Callable(self, "_play_current_pattern"), CONNECT_ONE_SHOT) # Use CONNECT_ONE_SHOT
		add_child(_initial_pattern_timer)
		_initial_pattern_timer.start()
		print("MusicManager: Starting music with pattern: ", MusicEntry.MusicPattern.keys()[current_pattern])
	else:
		printerr("MusicManager: Could not find initial music pattern '%s' in soundtrack '%s'" % [MusicEntry.MusicPattern.keys()[initial_pattern_type], current_soundtrack_name])


func stop_music():
	"""Stops music playback and resets state."""
	if is_instance_valid(music_player):
		music_player.stop()
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	if _initial_pattern_timer != null and is_instance_valid(_initial_pattern_timer):
		_initial_pattern_timer.stop()
		_initial_pattern_timer.queue_free()
		_initial_pattern_timer = null

	current_state = MusicState.NORMAL
	current_pattern = MusicEntry.MusicPattern.NONE
	next_pattern = MusicEntry.MusicPattern.NONE
	pending_pattern = MusicEntry.MusicPattern.NONE
	current_loop_count = 0
	force_transition = false
	battle_over_timestamp = 0


func _process(delta):
	if current_pattern == MusicEntry.MusicPattern.NONE or MusicData == null:
		return

	var current_time = Time.get_ticks_msec()

	# Check for forced transitions based on game state
	_check_game_state_transitions(current_time)

	# Check if current pattern allows forcing and if a force is requested
	var current_entry = MusicData.get_entry(current_pattern, current_soundtrack_name)
	if current_entry and force_transition and current_entry.can_force:
		# Check if enough time has passed or if we are near the end of a measure
		# For simplicity, we'll transition immediately when forced via _request_transition
		# by setting current_loop_count = 0 and letting _on_music_finished handle it,
		# or potentially stopping and starting the next track immediately if needed.
		# Let's refine _request_transition to handle this better.
		# For now, just ensuring the flag is checked. If force_transition is true,
		# _on_music_finished will handle the switch.
		pass


func _check_game_state_transitions(current_time: int):
	"""Checks game state and potentially triggers music transitions."""
	if current_pattern == MusicEntry.MusicPattern.DEAD_1:
		return # Player is dead, music stays dead

	# Check for mission end conditions first (highest priority)
	if current_time >= mission_over_timestamp:
		mission_over_timestamp = current_time + MISSION_OVER_CHECK_INTERVAL
		# TODO: Check actual mission goal status (e.g., MissionManager.are_primary_goals_met())
		var goals_met = false # Placeholder - Replace with actual check
		if goals_met and not _check_hostile_presence():
			if current_pattern != MusicEntry.MusicPattern.VICT_1 and current_pattern != MusicEntry.MusicPattern.VICT_2:
				_request_transition(MusicEntry.MusicPattern.VICT_1)
				current_state = MusicState.VICTORY # Update state
				return # Don't check lower priority states

	# Check battle state transitions only if not already in VICTORY/FAILURE/DEAD states
	if current_state in [MusicState.NORMAL, MusicState.BATTLE, MusicState.ARRIVAL]:
		match current_state:
		MusicState.NORMAL:
			if current_time >= check_for_battle_music_timestamp:
				check_for_battle_music_timestamp = current_time + BATTLE_START_INTERVAL
				if _check_hostile_presence():
					_request_transition(MusicEntry.MusicPattern.BTTL_1)
					current_state = MusicState.BATTLE
					battle_over_timestamp = 0 # Reset battle over timer
			MusicState.BATTLE:
				if battle_over_timestamp > 0 and current_time >= battle_over_timestamp:
					battle_over_timestamp = 0
					if not _check_hostile_presence():
						# TODO: Check if primary goals are met (e.g., MissionManager.are_primary_goals_met())
						var goals_met = false # Placeholder
						if goals_met:
							_request_transition(MusicEntry.MusicPattern.VICT_1)
							current_state = MusicState.VICTORY
						else:
							_request_transition(_get_normal_pattern_after_battle())
							current_state = MusicState.NORMAL
				elif battle_over_timestamp == 0 and current_time >= hostile_presence_timestamp:
					hostile_presence_timestamp = current_time + HOSTILE_PRESENCE_CHECK_INTERVAL
					if not _check_hostile_presence():
						# Start timer to transition out of battle music if no hostiles detected
						battle_over_timestamp = current_time + BATTLE_OVER_INTERVAL
			MusicState.ARRIVAL:
				# Arrival music transitions are handled by _on_music_finished based on pending_pattern
				pass


func _request_transition(target_pattern: MusicEntry.MusicPattern):
	"""Sets the next pattern and flags for a forced transition if possible."""
	if current_pattern == MusicEntry.MusicPattern.NONE or current_pattern == target_pattern or MusicData == null:
		return

	var current_entry = MusicData.get_entry(current_pattern, current_soundtrack_name)
	var target_entry = MusicData.get_entry(target_pattern, current_soundtrack_name)

	if not target_entry:
		printerr("MusicManager: Target pattern %s not found in soundtrack %s" % [MusicEntry.MusicPattern.keys()[target_pattern], current_soundtrack_name])
		return

	# If the current pattern cannot be forced, we queue the request by setting pending_pattern
	if current_entry and not current_entry.can_force:
		print("MusicManager: Cannot force transition from %s, queuing %s" % [MusicEntry.MusicPattern.keys()[current_pattern], MusicEntry.MusicPattern.keys()[target_pattern]])
		pending_pattern = target_pattern # Set the desired pattern for natural transition
		# Don't set force_transition = true
		return

	# If we are already forcing a transition, maybe prioritize? (e.g., DEAD overrides others)
	# For now, let the new request override the previous forced one.
	if force_transition:
		print("MusicManager: Overriding previous forced transition. New target: ", MusicEntry.MusicPattern.keys()[target_pattern])

	print("MusicManager: Requesting transition from %s to %s" % [MusicEntry.MusicPattern.keys()[current_pattern], MusicEntry.MusicPattern.keys()[target_pattern]])
	next_pattern = target_pattern
	force_transition = true
	# Set loop count to 0 to trigger transition ASAP in _on_music_finished
	current_loop_count = 0


func _play_current_pattern():
	"""Plays the music track defined by current_pattern."""
	if _initial_pattern_timer != null and is_instance_valid(_initial_pattern_timer):
		_initial_pattern_timer.queue_free() # Ensure timer is removed
		_initial_pattern_timer = null

	if MusicData == null: return # Guard

	var entry = MusicData.get_entry(current_pattern, current_soundtrack_name)
	if not entry or entry.audio_stream_path == "":
		printerr("MusicManager: Cannot play invalid pattern '%s' in soundtrack '%s'" % [MusicEntry.MusicPattern.keys()[current_pattern], current_soundtrack_name])
		# Attempt to recover, e.g., go to NRML_1
		if current_pattern != MusicEntry.MusicPattern.NRML_1:
			current_pattern = MusicEntry.MusicPattern.NRML_1
			entry = MusicData.get_entry(current_pattern, current_soundtrack_name)
			if not entry: return # Serious issue if NRML_1 is missing
		else:
			return # Already tried NRML_1

	var stream = entry.get_stream()
	if stream and is_instance_valid(music_player):
		music_player.stream = stream
		# TODO: Apply master music volume from AudioServer bus or settings
		# var master_vol = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) # Example
		music_player.volume_db = 0 # Placeholder - use master_vol
		music_player.play()
		print("MusicManager: Playing pattern ", MusicEntry.MusicPattern.keys()[current_pattern])
	elif not is_instance_valid(music_player):
		printerr("MusicManager: Music player node is invalid!")
	else:
		printerr("MusicManager: Failed to load stream for pattern: ", MusicEntry.MusicPattern.keys()[current_pattern])


func _on_music_finished():
	"""Called when the current music track finishes playing naturally."""
	if MusicData == null: return # Guard

	print("MusicManager: Pattern finished: ", MusicEntry.MusicPattern.keys()[current_pattern])

	# Check loop count *before* decrementing if force_transition is true
	if force_transition:
		print("MusicManager: Forced transition to: ", MusicEntry.MusicPattern.keys()[next_pattern])
		current_pattern = next_pattern
		force_transition = false # Reset force flag
		var entry = MusicData.get_entry(current_pattern, current_soundtrack_name)
		if entry:
			current_loop_count = entry.default_loop_for
			# Determine the *next* default pattern based on the *new* current pattern
			pending_pattern = _get_default_next_pattern(entry)
		else:
			# Invalid target pattern, fallback
			printerr("MusicManager: Invalid forced target pattern: ", MusicEntry.MusicPattern.keys()[current_pattern])
			current_pattern = MusicEntry.MusicPattern.NRML_1
			entry = MusicData.get_entry(current_pattern, current_soundtrack_name)
			current_loop_count = entry.default_loop_for if entry else 1
			pending_pattern = _get_default_next_pattern(entry) if entry else MusicEntry.MusicPattern.NRML_1
		_play_current_pattern()
		return # Don't process looping/natural transition

	# If not forced, decrement loop count
	current_loop_count -= 1

	if current_loop_count > 0:
		print("MusicManager: Looping pattern: ", MusicEntry.MusicPattern.keys()[current_pattern], ", loops left: ", current_loop_count)
		_play_current_pattern() # Loop the current pattern
	else:
		# Natural transition to the pending pattern
		print("MusicManager: Natural transition to pending: ", MusicEntry.MusicPattern.keys()[pending_pattern])
		current_pattern = pending_pattern
		var entry = MusicData.get_entry(current_pattern, current_soundtrack_name)
		if entry:
			current_loop_count = entry.default_loop_for
			# Determine the *next* default pattern based on the *new* current pattern
			pending_pattern = _get_default_next_pattern(entry)
		else:
			# Invalid pending pattern, fallback
			printerr("MusicManager: Invalid pending pattern: ", MusicEntry.MusicPattern.keys()[current_pattern])
			current_pattern = MusicEntry.MusicPattern.NRML_1
			entry = MusicData.get_entry(current_pattern, current_soundtrack_name)
			current_loop_count = entry.default_loop_for if entry else 1
			pending_pattern = _get_default_next_pattern(entry) if entry else MusicEntry.MusicPattern.NRML_1
		_play_current_pattern()


func _get_default_next_pattern(entry: MusicEntry) -> MusicEntry.MusicPattern:
	"""Determines the default next pattern based on cycle mode and entry data."""
	if not entry:
		printerr("MusicManager: _get_default_next_pattern called with null entry!")
		return MusicEntry.MusicPattern.NRML_1 # Fallback

	var next_p = entry.default_next_pattern_fs1 if is_fs1_cycle_mode else entry.default_next_pattern_fs2

	# --- Add FS2 specific transition logic from eventmusic.cpp ---
	if not is_fs1_cycle_mode:
		# If current is BTTL_3 and next default is BTTL_1, check player hull
		if current_pattern == MusicEntry.MusicPattern.BTTL_3 and next_p == MusicEntry.MusicPattern.BTTL_1:
			# TODO: Get player hull percentage (e.g., from PlayerData or player node)
			var player_hull_pct = 1.0 # Placeholder
			const HULL_THRESHOLD = 0.75 # From eventmusic.cpp
			if player_hull_pct < HULL_THRESHOLD:
				# Check if BTTL_2 exists before switching
				if MusicData.get_entry(MusicEntry.MusicPattern.BTTL_2, current_soundtrack_name):
					next_p = MusicEntry.MusicPattern.BTTL_2
				else:
					next_p = MusicEntry.MusicPattern.BTTL_1 # Fallback if BTTL_2 missing
	# -------------------------------------------------------------

	# Ensure the chosen next pattern actually exists in the current soundtrack
	if not MusicData.get_entry(next_p, current_soundtrack_name):
		printerr("MusicManager: Default next pattern %s not found in soundtrack %s, falling back." % [MusicEntry.MusicPattern.keys()[next_p], current_soundtrack_name])
		# Fallback logic: try BTTL_1 if in battle, else NRML_1
		if current_state == MusicState.BATTLE:
			if MusicData.get_entry(MusicEntry.MusicPattern.BTTL_1, current_soundtrack_name):
				return MusicEntry.MusicPattern.BTTL_1
		return MusicEntry.MusicPattern.NRML_1 # Ultimate fallback

	return next_p


func _get_normal_pattern_after_battle() -> MusicEntry.MusicPattern:
	"""Determines which normal pattern to play after a battle, ensuring it exists."""
	var target_pattern = MusicEntry.MusicPattern.NRML_3 if is_fs1_cycle_mode else MusicEntry.MusicPattern.NRML_1
	if MusicData.get_entry(target_pattern, current_soundtrack_name):
		return target_pattern
	else:
		# Fallback if the preferred normal pattern doesn't exist
		if target_pattern == MusicEntry.MusicPattern.NRML_3:
			if MusicData.get_entry(MusicEntry.MusicPattern.NRML_1, current_soundtrack_name):
				return MusicEntry.MusicPattern.NRML_1
		# Add more fallbacks if necessary
		printerr("MusicManager: No suitable normal pattern found after battle in soundtrack %s" % current_soundtrack_name)
		return MusicEntry.MusicPattern.NONE # Indicate failure


# --- Signal Handlers (Connect these in _ready) ---

func _on_battle_state_changed(in_battle: bool):
	"""Handles changes in the game's battle state."""
	print("MusicManager: Battle state changed to: ", in_battle)
	if in_battle:
		if current_state == MusicState.NORMAL:
			_request_transition(MusicEntry.MusicPattern.BTTL_1)
			current_state = MusicState.BATTLE
			battle_over_timestamp = 0 # Reset timer
	else:
		if current_state == MusicState.BATTLE:
			# Start timer to check if we should transition out of battle music
			if battle_over_timestamp == 0: # Only start if not already waiting
				battle_over_timestamp = Time.get_ticks_msec() + BATTLE_OVER_INTERVAL

func _on_primary_goal_failed():
	"""Handles the event when any primary mission goal fails."""
	print("MusicManager: Primary goal failed.")
	if current_pattern == MusicEntry.MusicPattern.DEAD_1: return # Ignore if player dead
	if current_pattern == MusicEntry.MusicPattern.FAIL_1: return # Already playing failure

	# Check if FAIL_1 pattern exists
	if MusicData.get_entry(MusicEntry.MusicPattern.FAIL_1, current_soundtrack_name):
		_request_transition(MusicEntry.MusicPattern.FAIL_1)
		current_state = MusicState.FAILURE
		# Set pending pattern after failure (usually normal or battle)
		var next_p = MusicEntry.MusicPattern.NRML_1 # Default fallback
		if _check_hostile_presence():
			next_p = MusicEntry.MusicPattern.BTTL_1
		else:
			next_p = _get_normal_pattern_after_battle()
		pending_pattern = next_p
	else:
		printerr("MusicManager: FAIL_1 pattern not found for soundtrack: ", current_soundtrack_name)


func _on_primary_goals_met():
	"""Handles the event when all primary mission goals are met."""
	print("MusicManager: Primary goals met.")
	if current_pattern == MusicEntry.MusicPattern.DEAD_1: return
	if current_pattern == MusicEntry.MusicPattern.VICT_1 or current_pattern == MusicEntry.MusicPattern.VICT_2: return

	# Check if VICT_1 pattern exists
	if MusicData.get_entry(MusicEntry.MusicPattern.VICT_1, current_soundtrack_name):
		_request_transition(MusicEntry.MusicPattern.VICT_1)
		current_state = MusicState.VICTORY
		# Set pending pattern after victory (usually VICT_2 or battle/normal)
		var next_p = MusicEntry.MusicPattern.VICT_2
		if _check_hostile_presence():
			next_p = MusicEntry.MusicPattern.BTTL_1
		elif not MusicData.get_entry(MusicEntry.MusicPattern.VICT_2, current_soundtrack_name):
			# If VICT_2 doesn't exist, go to normal after VICT_1
			next_p = _get_normal_pattern_after_battle()

		# Ensure the pending pattern exists
		if not MusicData.get_entry(next_p, current_soundtrack_name):
			next_p = _get_normal_pattern_after_battle() # Fallback further

		pending_pattern = next_p
	else:
		printerr("MusicManager: VICT_1 pattern not found for soundtrack: ", current_soundtrack_name)


func _on_player_died():
	"""Handles the player death event."""
	print("MusicManager: Player died.")
	if current_pattern != MusicEntry.MusicPattern.DEAD_1:
		if MusicData.get_entry(MusicEntry.MusicPattern.DEAD_1, current_soundtrack_name):
			_request_transition(MusicEntry.MusicPattern.DEAD_1)
			current_state = MusicState.DEAD
		else:
			printerr("MusicManager: DEAD_1 pattern not found for soundtrack: ", current_soundtrack_name)
			stop_music() # Stop music if no death track


func _on_player_respawned():
	"""Handles the player respawn event."""
	print("MusicManager: Player respawned.")
	# Typically transition back to normal music after respawn
	if current_state == MusicState.DEAD:
		var respawn_pattern = _get_normal_pattern_after_battle()
		if respawn_pattern != MusicEntry.MusicPattern.NONE:
			_request_transition(respawn_pattern)
			current_state = MusicState.NORMAL
		else:
			stop_music() # Stop if no suitable pattern


func _on_ship_arrived(ship_node: Node, team: int):
	"""Handles ship arrival events."""
	if Time.get_ticks_msec() < next_arrival_timestamp or MusicData == null:
		return # Debounce arrivals or guard

	# TODO: Get player team from PlayerData or GameManager
	var player_team = 0 # Placeholder
	# TODO: Use IFF check (e.g., GlobalConstants.iff_x_attacks_y(player_team, team))
	var is_hostile = true if team != player_team else false # Basic IFF check

	print("MusicManager: Ship arrived. Hostile: ", is_hostile, " Current State: ", MusicState.keys()[current_state])

	var arrival_pattern = MusicEntry.MusicPattern.NONE
	var pattern_after_arrival = MusicEntry.MusicPattern.NONE

	if is_hostile:
		arrival_pattern = MusicEntry.MusicPattern.EARV_1 if current_state == MusicState.NORMAL else MusicEntry.MusicPattern.EARV_2
		# After enemy arrival, usually transition to battle music
		pattern_after_arrival = MusicEntry.MusicPattern.BTTL_1 # Simple default, could be smarter
		current_state = MusicState.BATTLE # Assume battle starts
		battle_over_timestamp = 0 # Reset battle end timer
	else: # Friendly
		# Check EMF_ALLIED_ARRIVAL_OVERLAY flag - if set, play sound effect instead of changing music
		var flags = MusicData.get_soundtrack_flags(current_soundtrack_name)
		# Assuming flag constant exists: if flags & GlobalConstants.EMF_ALLIED_ARRIVAL_OVERLAY:
		if false: # Placeholder for flag check
			# TODO: Play the AARV_1 sound effect via SoundManager
			# SoundManager.play_sound_2d("SND_AARV_1") # Assuming SND_AARV_1 maps to the sound
			print("MusicManager: Playing allied arrival overlay sound (TODO)")
			return # Don't change music track

		# If not overlay, change music track
		arrival_pattern = MusicEntry.MusicPattern.AARV_1 if current_state == MusicState.NORMAL else MusicEntry.MusicPattern.AARV_2
		# After friendly arrival, return to previous state's default next pattern
		var current_entry = MusicData.get_entry(current_pattern, current_soundtrack_name)
		pattern_after_arrival = _get_default_next_pattern(current_entry) if current_entry else MusicEntry.MusicPattern.NRML_1


	var arrival_entry = MusicData.get_entry(arrival_pattern, current_soundtrack_name)
	if arrival_entry:
		_request_transition(arrival_pattern)
		# Set the pattern that should play *after* the arrival jingle finishes
		var next_entry = MusicData.get_entry(pattern_after_arrival, current_soundtrack_name)
		if next_entry:
			pending_pattern = pattern_after_arrival # Set what plays after arrival
		else:
			# Fallback if the intended next pattern doesn't exist
			pending_pattern = _get_default_next_pattern(arrival_entry)
			printerr("MusicManager: Pattern after arrival %s not found, falling back to %s" % [MusicEntry.MusicPattern.keys()[pattern_after_arrival], MusicEntry.MusicPattern.keys()[pending_pattern]])

		# Update state based on arrival type if needed (e.g., MusicState.ARRIVAL)
		# current_state = MusicState.ARRIVAL
		next_arrival_timestamp = Time.get_ticks_msec() + ARRIVAL_INTERVAL_TIMESTAMP
	else:
		printerr("MusicManager: Arrival pattern %s not found in soundtrack %s" % [MusicEntry.MusicPattern.keys()[arrival_pattern], current_soundtrack_name])


# --- Utility Functions ---

func _check_hostile_presence() -> bool:
	"""Checks if hostile ships are currently considered a threat."""
	# TODO: Implement logic similar to original hostile_ships_present()
	# This might involve querying ObjectManager for ships and checking IFF/AI state.
	return false # Placeholder

func set_master_volume(volume: float):
	"""Sets the master volume for music."""
	# TODO: Adjust the volume of the 'Music' audio bus.
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(clamp(volume, 0.0, 1.0)))
	pass
