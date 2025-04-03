# scripts/sound_animation/ani_player_2d.gd
extends AnimatedSprite2D
class_name AniPlayer2D

## Custom AnimatedSprite2D to replicate specific .ANI playback features.

# Exported variables to control playback behavior, mirroring anim_instance properties.
@export var ping_pong: bool = false		 # If true, reverses direction at end instead of looping/stopping.
@export var skip_frames: bool = true	 # If true, jumps frames based on time; if false, plays frame-by-frame.
# Note: AnimatedSprite2D has 'playing' and 'speed_scale'. 'loop' is handled by animation resource.
# 'direction' might be handled by flip_h/flip_v or custom logic if needed.

# Internal state variables
var _time_elapsed: float = 0.0
var _current_direction: int = 1 # 1 for forward, -1 for reverse (used for ping_pong)
var _paused: bool = false
var _stop_now: bool = false # Flag to stop after the current frame finishes

# TODO: Add support for start_at and stop_at frames if needed, requires overriding play().

func _process(delta):
	if not playing or _paused or sprite_frames == null:
		return

	if _stop_now:
		stop()
		_stop_now = false
		return

	var anim_name = animation
	if not sprite_frames.has_animation(anim_name):
		printerr("AniPlayer2D: Animation '%s' not found in SpriteFrames." % anim_name)
		stop()
		return

	var fps = sprite_frames.get_animation_speed(anim_name)
	if fps <= 0:
		printerr("AniPlayer2D: Animation '%s' has invalid FPS (<= 0)." % anim_name)
		stop()
		return

	var frame_count = sprite_frames.get_frame_count(anim_name)
	if frame_count <= 0:
		stop()
		return

	var frame_duration = 1.0 / fps
	_time_elapsed += delta * speed_scale

	var target_frame_float = _time_elapsed / frame_duration
	var new_frame_index = frame # Start with current frame

	# Determine the next frame based on time elapsed and playback mode
	if skip_frames:
		# Jump directly to the calculated frame based on time
		new_frame_index = int(floor(target_frame_float))
	else:
		# Advance frame by frame if enough time has passed
		if _time_elapsed >= frame_duration:
			new_frame_index = frame + _current_direction
			_time_elapsed = fmod(_time_elapsed, frame_duration) # Keep remainder time

	# Handle animation end/looping/ping-pong
	var animation_ended = false
	if _current_direction == 1 and new_frame_index >= frame_count:
		animation_ended = true
		new_frame_index = frame_count - 1 # Clamp to last frame before deciding action
	elif _current_direction == -1 and new_frame_index < 0:
		animation_ended = true
		new_frame_index = 0 # Clamp to first frame before deciding action

	if animation_ended:
		var is_looping = sprite_frames.get_animation_loop_mode(anim_name) != SpriteFrames.LOOP_NONE # Check Godot's loop mode

		if ping_pong:
			_current_direction *= -1 # Reverse direction
			# Adjust frame index based on new direction to avoid skipping
			new_frame_index = frame + _current_direction
			# Clamp again after direction change
			new_frame_index = clamp(new_frame_index, 0, frame_count - 1)
			# Reset time elapsed for ping-pong? Or keep remainder? Keeping remainder for now.
		elif is_looping:
			# Godot's AnimatedSprite2D handles looping internally when playing.
			# However, our custom logic needs to reset the frame index correctly.
			if _current_direction == 1:
				new_frame_index = 0 # Loop back to start
			else: # Should not happen if looping forward only, but handle anyway
				new_frame_index = frame_count - 1
			_time_elapsed = 0.0 # Reset time for loop
		else:
			# Animation finished and not looping or ping-ponging
			_stop_now = true # Stop after this frame renders
			# Keep clamped frame index (last or first depending on direction)
			new_frame_index = clamp(frame, 0, frame_count - 1)


	# Set the actual frame if it changed
	if new_frame_index != frame:
		frame = new_frame_index

	# Update visual direction if needed (e.g., for ping-pong without flipping sprite)
	# flip_h = (_current_direction == -1) # Example if sprite needs flipping

# Override play to reset internal state
func play(anim_name: String = "", p_custom_speed: float = 1.0, p_from_end: bool = false):
	# Call base class play first
	super.play(anim_name, p_custom_speed, p_from_end)

	# Reset custom state variables
	_time_elapsed = 0.0
	_current_direction = 1 # Always start forward
	_paused = false
	_stop_now = false
	# TODO: Handle p_from_end if necessary for ping-pong or custom logic

# Override stop to reset internal state
func stop():
	super.stop()
	_time_elapsed = 0.0
	_current_direction = 1
	_paused = false
	_stop_now = false

func pause_playback():
	_paused = true
	# Note: AnimatedSprite2D doesn't have a built-in pause,
	# setting speed_scale = 0 is an alternative, but _paused flag allows custom logic.

func resume_playback():
	_paused = false

# TODO: Add functions for color translation if needed (likely requires shader).
# func set_color_translation(palette_translation: PackedByteArray):
