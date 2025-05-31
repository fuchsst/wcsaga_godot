@tool
class_name BriefingTimelineEditor
extends Control

## Timeline editor component for GFRED2-007 Briefing Editor System.
## Provides timeline-based editing for briefing stages, keyframes, and animations.

signal timeline_position_changed(position: float)
signal keyframe_added(keyframe: BriefingKeyframe)
signal keyframe_removed(keyframe_index: int)
signal keyframe_selected(keyframe: BriefingKeyframe)
signal playback_started()
signal playback_stopped()
signal playback_paused()

# Timeline configuration
var timeline_duration: float = 60.0  # Default 60 seconds
var timeline_scale: float = 10.0      # Pixels per second
var current_position: float = 0.0
var is_playing: bool = false
var playback_speed: float = 1.0

# UI components
@onready var timeline_header: HBoxContainer = $VBoxContainer/TimelineHeader
@onready var time_ruler: TimelineRuler = $VBoxContainer/TimelineHeader/TimeRuler
@onready var playback_controls: HBoxContainer = $VBoxContainer/TimelineHeader/PlaybackControls
@onready var play_button: Button = $VBoxContainer/TimelineHeader/PlaybackControls/PlayButton
@onready var pause_button: Button = $VBoxContainer/TimelineHeader/PlaybackControls/PauseButton
@onready var stop_button: Button = $VBoxContainer/TimelineHeader/PlaybackControls/StopButton
@onready var position_label: Label = $VBoxContainer/TimelineHeader/PlaybackControls/PositionLabel

# Timeline tracks
@onready var tracks_container: VBoxContainer = $VBoxContainer/TimelineContent/TracksContainer
@onready var camera_track: CameraTimelineTrack = $VBoxContainer/TimelineContent/TracksContainer/CameraTrack
@onready var icon_track: IconTimelineTrack = $VBoxContainer/TimelineContent/TracksContainer/IconTrack
@onready var audio_track: AudioTimelineTrack = $VBoxContainer/TimelineContent/TracksContainer/AudioTrack
@onready var text_track: TextTimelineTrack = $VBoxContainer/TimelineContent/TracksContainer/TextTrack

# Timeline cursor and selection
@onready var timeline_cursor: Control = $VBoxContainer/TimelineContent/TimelineCursor
var selected_keyframes: Array[BriefingKeyframe] = []

# Briefing data
var briefing_data: BriefingData = null
var current_stage_index: int = -1
var current_stage: BriefingStage = null

# Playback timer
var playback_timer: Timer

func _ready() -> void:
	name = "BriefingTimelineEditor"
	
	# Setup timeline UI
	_setup_timeline_ui()
	
	# Initialize playback timer
	_setup_playback_timer()
	
	# Connect UI signals
	_connect_timeline_signals()
	
	print("BriefingTimelineEditor: Timeline editor initialized")

## Sets up timeline UI components
func _setup_timeline_ui() -> void:
	# Configure time ruler
	if time_ruler:
		time_ruler.setup_ruler(timeline_duration, timeline_scale)
		time_ruler.position_changed.connect(_on_ruler_position_changed)
	
	# Setup tracks
	_setup_timeline_tracks()
	
	# Update timeline cursor
	_update_timeline_cursor()

## Sets up timeline tracks
func _setup_timeline_tracks() -> void:
	if camera_track:
		camera_track.setup_camera_track(timeline_duration, timeline_scale)
		camera_track.keyframe_added.connect(_on_camera_keyframe_added)
		camera_track.keyframe_removed.connect(_on_camera_keyframe_removed)
	
	if icon_track:
		icon_track.setup_icon_track(timeline_duration, timeline_scale)
		icon_track.keyframe_added.connect(_on_icon_keyframe_added)
		icon_track.keyframe_removed.connect(_on_icon_keyframe_removed)
	
	if audio_track:
		audio_track.setup_audio_track(timeline_duration, timeline_scale)
		audio_track.audio_clip_added.connect(_on_audio_clip_added)
		audio_track.audio_clip_removed.connect(_on_audio_clip_removed)
	
	if text_track:
		text_track.setup_text_track(timeline_duration, timeline_scale)
		text_track.text_clip_added.connect(_on_text_clip_added)
		text_track.text_clip_removed.connect(_on_text_clip_removed)

## Sets up playback timer
func _setup_playback_timer() -> void:
	playback_timer = Timer.new()
	playback_timer.wait_time = 0.016  # 60 FPS updates
	playback_timer.timeout.connect(_on_playback_timer_timeout)
	add_child(playback_timer)

## Connects timeline UI signals
func _connect_timeline_signals() -> void:
	# Playback controls
	play_button.pressed.connect(_on_play_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	stop_button.pressed.connect(_on_stop_pressed)

func _input(event: InputEvent) -> void:
	if not has_focus():
		return
	
	# Handle timeline keyboard shortcuts
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if is_playing:
					pause_playback()
				else:
					start_playback()
			KEY_HOME:
				set_timeline_position(0.0)
			KEY_END:
				set_timeline_position(timeline_duration)
			KEY_DELETE:
				_delete_selected_keyframes()

## Sets up briefing timeline with data
func setup_briefing_timeline(target_briefing: BriefingData) -> void:
	briefing_data = target_briefing
	
	# Update timeline duration based on total briefing length
	_calculate_timeline_duration()
	
	# Refresh all tracks
	_refresh_timeline_tracks()

## Selects a specific stage for timeline editing
func select_stage(stage_index: int) -> void:
	current_stage_index = stage_index
	
	if stage_index >= 0 and stage_index < briefing_data.stages.size():
		current_stage = briefing_data.stages[stage_index]
		_load_stage_keyframes()
	else:
		current_stage = null
		_clear_stage_keyframes()

## Calculates total timeline duration
func _calculate_timeline_duration() -> void:
	if not briefing_data:
		timeline_duration = 60.0
		return
	
	var total_duration: float = 0.0
	for stage in briefing_data.stages:
		total_duration += stage.stage_duration
	
	timeline_duration = max(total_duration, 60.0)  # Minimum 60 seconds
	
	# Update UI with new duration
	if time_ruler:
		time_ruler.set_timeline_duration(timeline_duration)
	
	_refresh_timeline_tracks()

## Refreshes all timeline tracks
func _refresh_timeline_tracks() -> void:
	_setup_timeline_tracks()
	
	if current_stage:
		_load_stage_keyframes()

## Loads keyframes for current stage
func _load_stage_keyframes() -> void:
	if not current_stage:
		return
	
	# Load camera keyframes
	if camera_track:
		camera_track.load_camera_keyframes(current_stage.keyframes)
	
	# Load icon keyframes
	if icon_track:
		icon_track.load_icon_keyframes(current_stage.keyframes)
	
	# Load audio clips
	if audio_track:
		audio_track.load_audio_clips(current_stage.audio_clips)
	
	# Load text clips
	if text_track:
		text_track.load_text_clips(current_stage.text_clips)

## Clears stage keyframes
func _clear_stage_keyframes() -> void:
	if camera_track:
		camera_track.clear_keyframes()
	if icon_track:
		icon_track.clear_keyframes()
	if audio_track:
		audio_track.clear_audio_clips()
	if text_track:
		text_track.clear_text_clips()

## Starts timeline playback
func start_playback() -> void:
	is_playing = true
	playback_timer.start()
	
	# Update UI state
	play_button.disabled = true
	pause_button.disabled = false
	stop_button.disabled = false
	
	playback_started.emit()
	print("BriefingTimelineEditor: Playback started")

## Pauses timeline playback
func pause_playback() -> void:
	is_playing = false
	playback_timer.stop()
	
	# Update UI state
	play_button.disabled = false
	pause_button.disabled = true
	
	playback_paused.emit()
	print("BriefingTimelineEditor: Playback paused")

## Stops timeline playback
func stop_playback() -> void:
	is_playing = false
	playback_timer.stop()
	current_position = 0.0
	
	# Update UI state
	play_button.disabled = false
	pause_button.disabled = true
	stop_button.disabled = true
	
	_update_timeline_cursor()
	_update_position_display()
	
	playback_stopped.emit()
	timeline_position_changed.emit(current_position)
	print("BriefingTimelineEditor: Playback stopped")

## Sets timeline position
func set_timeline_position(position: float) -> void:
	current_position = clamp(position, 0.0, timeline_duration)
	_update_timeline_cursor()
	_update_position_display()
	timeline_position_changed.emit(current_position)

## Updates timeline cursor position
func _update_timeline_cursor() -> void:
	if timeline_cursor:
		var cursor_x: float = current_position * timeline_scale
		timeline_cursor.position.x = cursor_x

## Updates position display
func _update_position_display() -> void:
	if position_label:
		var minutes: int = int(current_position) / 60
		var seconds: float = current_position - (minutes * 60)
		position_label.text = "%02d:%05.2f" % [minutes, seconds]

## Adds a keyframe at current position
func add_keyframe_at_position(keyframe_type: BriefingKeyframe.KeyframeType, data: Dictionary = {}) -> BriefingKeyframe:
	var keyframe: BriefingKeyframe = BriefingKeyframe.new()
	keyframe.keyframe_type = keyframe_type
	keyframe.time_position = current_position
	keyframe.keyframe_data = data
	
	# Add to current stage
	if current_stage:
		current_stage.keyframes.append(keyframe)
		
		# Update appropriate track
		match keyframe_type:
			BriefingKeyframe.KeyframeType.CAMERA_POSITION:
				if camera_track:
					camera_track.add_camera_keyframe(keyframe)
			BriefingKeyframe.KeyframeType.CAMERA_ROTATION:
				if camera_track:
					camera_track.add_camera_keyframe(keyframe)
			BriefingKeyframe.KeyframeType.ICON_POSITION:
				if icon_track:
					icon_track.add_icon_keyframe(keyframe)
			BriefingKeyframe.KeyframeType.ICON_VISIBILITY:
				if icon_track:
					icon_track.add_icon_keyframe(keyframe)
	
	keyframe_added.emit(keyframe)
	return keyframe

## Removes a keyframe
func remove_keyframe(keyframe: BriefingKeyframe) -> void:
	if not current_stage:
		return
	
	# Find and remove from stage
	for i in range(current_stage.keyframes.size()):
		if current_stage.keyframes[i] == keyframe:
			current_stage.keyframes.remove_at(i)
			keyframe_removed.emit(i)
			break
	
	# Remove from appropriate track
	match keyframe.keyframe_type:
		BriefingKeyframe.KeyframeType.CAMERA_POSITION, BriefingKeyframe.KeyframeType.CAMERA_ROTATION:
			if camera_track:
				camera_track.remove_camera_keyframe(keyframe)
		BriefingKeyframe.KeyframeType.ICON_POSITION, BriefingKeyframe.KeyframeType.ICON_VISIBILITY:
			if icon_track:
				icon_track.remove_icon_keyframe(keyframe)

## Deletes selected keyframes
func _delete_selected_keyframes() -> void:
	for keyframe in selected_keyframes:
		remove_keyframe(keyframe)
	selected_keyframes.clear()

## Signal Handlers

func _on_playback_timer_timeout() -> void:
	if is_playing:
		current_position += playback_timer.wait_time * playback_speed
		
		if current_position >= timeline_duration:
			stop_playback()
		else:
			_update_timeline_cursor()
			_update_position_display()
			timeline_position_changed.emit(current_position)

func _on_play_pressed() -> void:
	start_playback()

func _on_pause_pressed() -> void:
	pause_playback()

func _on_stop_pressed() -> void:
	stop_playback()

func _on_ruler_position_changed(position: float) -> void:
	set_timeline_position(position)

func _on_camera_keyframe_added(keyframe: BriefingKeyframe) -> void:
	if current_stage:
		current_stage.keyframes.append(keyframe)
	keyframe_added.emit(keyframe)

func _on_camera_keyframe_removed(keyframe: BriefingKeyframe) -> void:
	remove_keyframe(keyframe)

func _on_icon_keyframe_added(keyframe: BriefingKeyframe) -> void:
	if current_stage:
		current_stage.keyframes.append(keyframe)
	keyframe_added.emit(keyframe)

func _on_icon_keyframe_removed(keyframe: BriefingKeyframe) -> void:
	remove_keyframe(keyframe)

func _on_audio_clip_added(audio_clip: BriefingAudioClip) -> void:
	if current_stage:
		current_stage.audio_clips.append(audio_clip)

func _on_audio_clip_removed(audio_clip: BriefingAudioClip) -> void:
	if current_stage:
		current_stage.audio_clips.erase(audio_clip)

func _on_text_clip_added(text_clip: BriefingTextClip) -> void:
	if current_stage:
		current_stage.text_clips.append(text_clip)

func _on_text_clip_removed(text_clip: BriefingTextClip) -> void:
	if current_stage:
		current_stage.text_clips.erase(text_clip)

## Public API

## Gets current timeline position
func get_timeline_position() -> float:
	return current_position

## Gets timeline duration
func get_timeline_duration() -> float:
	return timeline_duration

## Sets timeline scale (pixels per second)
func set_timeline_scale(scale: float) -> void:
	timeline_scale = scale
	_refresh_timeline_tracks()

## Gets timeline scale
func get_timeline_scale() -> float:
	return timeline_scale

## Sets playback speed
func set_playback_speed(speed: float) -> void:
	playback_speed = clamp(speed, 0.1, 4.0)

## Gets playback speed
func get_playback_speed() -> float:
	return playback_speed

## Checks if timeline is currently playing
func is_timeline_playing() -> bool:
	return is_playing

## Selects a keyframe
func select_keyframe(keyframe: BriefingKeyframe) -> void:
	if not selected_keyframes.has(keyframe):
		selected_keyframes.append(keyframe)
	keyframe_selected.emit(keyframe)

## Deselects a keyframe
func deselect_keyframe(keyframe: BriefingKeyframe) -> void:
	selected_keyframes.erase(keyframe)

## Clears keyframe selection
func clear_keyframe_selection() -> void:
	selected_keyframes.clear()

## Gets selected keyframes
func get_selected_keyframes() -> Array[BriefingKeyframe]:
	return selected_keyframes.duplicate()

## Zooms timeline to fit all content
func zoom_to_fit() -> void:
	if timeline_duration > 0:
		var available_width: float = size.x - 100  # Account for track labels
		var new_scale: float = available_width / timeline_duration
		set_timeline_scale(new_scale)

## Zooms timeline to selection
func zoom_to_selection() -> void:
	if selected_keyframes.is_empty():
		return
	
	var min_time: float = selected_keyframes[0].time_position
	var max_time: float = selected_keyframes[0].time_position
	
	for keyframe in selected_keyframes:
		min_time = min(min_time, keyframe.time_position)
		max_time = max(max_time, keyframe.time_position)
	
	var selection_duration: float = max_time - min_time
	if selection_duration > 0:
		var available_width: float = size.x - 100
		var new_scale: float = available_width / selection_duration
		set_timeline_scale(new_scale)
		set_timeline_position(min_time)