@tool
extends HUDGauge
class_name HUDLockGauge

# Lock states (Mirroring HUDReticleGauge for consistency)
enum LockState {
	NONE,
	SEEKING,
	LOCKED
}

# Lock State
@export_group("Lock Status")
@export var lock_state: LockState = LockState.NONE:
	set(value):
		if lock_state != value:
			lock_state = value
			_reset_animation_and_sound() # Reset animation/sound on state change
			queue_redraw()
@export_range(0.0, 1.0) var lock_progress: float = 0.0:
	set(value):
		lock_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var lock_screen_position: Vector2 = Vector2.ZERO: # Where to draw the lock indicator
	set(value):
		lock_screen_position = value
		queue_redraw()

# Visual Settings
@export_group("Visual Settings")
@export var lock_seeking_anim: SpriteFrames = null # Assign seeking animation (e.g., lock1.tres)
@export var lock_locked_anim: SpriteFrames = null # Assign locked animation (e.g., lockspin.tres)
@export var lock_gauge_offset: Vector2 = Vector2(-15, -15) # Offset from lock_screen_position (adjust based on anim size)
@export var lock_spin_offset: Vector2 = Vector2(-16, -16) # Offset for locked anim (adjust based on anim size)
@export var locked_blink_rate: float = 0.1 # Corresponds to 1000 / (2 * LOCK_GAUGE_BLINK_RATE)

# Sound Settings
@export_group("Sound Settings")
@export var sound_seeking: AudioStream = null # Assign SND_MISSILE_TRACKING
@export var sound_locked: AudioStream = null # Assign SND_MISSILE_LOCK

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(100, 100) # Small preview area

# Runtime State
@onready var seeking_sprite: AnimatedSprite2D = $SeekingSprite # Assuming child node
@onready var locked_sprite: AnimatedSprite2D = $LockedSprite   # Assuming child node
@onready var seeking_audio: AudioStreamPlayer = $SeekingAudio # Assuming child node
@onready var locked_audio: AudioStreamPlayer = $LockedAudio   # Assuming child node

var _locked_blink_timer: float = 0.0
var _locked_sprite_visible: bool = true

func _init() -> void:
	super._init()
	gauge_id = GaugeType.MISSILE_WARNING_ARROW # Note: Original code didn't have a specific gauge ID for lock indicator itself, often part of reticle/target. Using MISSILE_WARNING_ARROW as placeholder ID, might need adjustment.
	is_popup = false # Lock indicator is usually persistent while locking

func _ready() -> void:
	super._ready()
	# Ensure child nodes exist or create them? For now, assume they exist.
	if not seeking_sprite: printerr("HUDLockGauge: SeekingSprite node not found!")
	if not locked_sprite: printerr("HUDLockGauge: LockedSprite node not found!")
	if not seeking_audio: printerr("HUDLockGauge: SeekingAudio node not found!")
	if not locked_audio: printerr("HUDLockGauge: LockedAudio node not found!")

	# Initial state
	if seeking_sprite: seeking_sprite.visible = false
	if locked_sprite: locked_sprite.visible = false
	if seeking_audio: seeking_audio.stream = sound_seeking
	if locked_audio: locked_audio.stream = sound_locked


# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship and targeting component exist
	if GameState.player_ship and is_instance_valid(GameState.player_ship) and GameState.player_ship.targeting_component:
		var targeting_comp = GameState.player_ship.targeting_component

		# Get lock status and progress
		var current_lock_state = targeting_comp.get_lock_state() # Placeholder method
		var current_lock_progress = targeting_comp.get_lock_progress() # Placeholder method
		var current_lock_pos = targeting_comp.get_lock_screen_position() # Placeholder method

		# Update gauge state (setters handle redraw)
		lock_state = current_lock_state
		lock_progress = current_lock_progress
		lock_screen_position = current_lock_pos
	else:
		# No player or targeting component, ensure lock is NONE
		lock_state = LockState.NONE
		lock_progress = 0.0
		lock_screen_position = Vector2.ZERO


func _process(delta: float):
	# Base class handles its own flashing/popups if needed
	# super._process(delta)

	# Update visibility and animation based on lock state
	if not can_draw():
		if seeking_sprite and seeking_sprite.visible: seeking_sprite.visible = false
		if locked_sprite and locked_sprite.visible: locked_sprite.visible = false
		_stop_lock_sounds()
		return

	match lock_state:
		LockState.NONE:
			if seeking_sprite and seeking_sprite.visible: seeking_sprite.visible = false
			if locked_sprite and locked_sprite.visible: locked_sprite.visible = false
			_stop_lock_sounds()

		LockState.SEEKING:
			if locked_sprite and locked_sprite.visible: locked_sprite.visible = false
			if seeking_sprite:
				if not seeking_sprite.visible:
					seeking_sprite.visible = true
					seeking_sprite.play("default") # Assuming animation name
					_play_lock_sounds()
				seeking_sprite.position = lock_screen_position + lock_gauge_offset
				# Update seeking animation based on lock_progress?
				# Original used distance, here we use progress directly.
				# Maybe adjust animation speed or frame?
				# seeking_sprite.speed_scale = 1.0 + (1.0 - lock_progress) * 2.0 # Example: faster when further
				# Or set frame directly (needs knowing total frames):
				# seeking_sprite.frame = int(lock_progress * seeking_sprite.sprite_frames.get_frame_count("default"))

		LockState.LOCKED:
			if seeking_sprite and seeking_sprite.visible: seeking_sprite.visible = false
			if locked_sprite:
				if not locked_sprite.visible:
					locked_sprite.visible = true
					locked_sprite.play("default") # Assuming animation name
					_play_lock_sounds()
				locked_sprite.position = lock_screen_position + lock_spin_offset

				# Handle blinking for locked state
				_locked_blink_timer += delta
				if _locked_blink_timer >= locked_blink_rate:
					_locked_blink_timer = 0.0
					_locked_sprite_visible = not _locked_sprite_visible
					locked_sprite.visible = _locked_sprite_visible


func _reset_animation_and_sound():
	# Called when lock_state changes
	if seeking_sprite: seeking_sprite.visible = false; seeking_sprite.stop()
	if locked_sprite: locked_sprite.visible = false; locked_sprite.stop()
	_stop_lock_sounds()
	_locked_blink_timer = 0.0
	_locked_sprite_visible = true


func _play_lock_sounds():
	match lock_state:
		LockState.NONE:
			_stop_lock_sounds()
		LockState.SEEKING:
			if locked_audio and locked_audio.playing: locked_audio.stop()
			if seeking_audio and not seeking_audio.playing: seeking_audio.play()
		LockState.LOCKED:
			if seeking_audio and seeking_audio.playing: seeking_audio.stop()
			if locked_audio and not locked_audio.playing: locked_audio.play() # Play lock sound once


func _stop_lock_sounds():
	if seeking_audio and seeking_audio.playing: seeking_audio.stop()
	if locked_audio and locked_audio.playing: locked_audio.stop()


# Draw is handled by AnimatedSprite2D nodes now
func _draw():
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		# Draw placeholder visuals if needed
		var center = preview_size / 2.0
		draw_arc(center, 20, 0, TAU * 0.75, 32, Color.YELLOW) # Example seeking
		draw_rect(Rect2(center - Vector2(5,5), Vector2(10,10)), Color.RED, false) # Example locked
	pass # Drawing is handled by child AnimatedSprite2D nodes
