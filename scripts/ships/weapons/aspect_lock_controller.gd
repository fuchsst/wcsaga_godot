class_name AspectLockController
extends Node

## Aspect lock controller providing pixel-based lock tolerance and minimum lock times
## Implements authentic WCS lock-on mechanics with visual and audio feedback
## Implementation of SHIP-006 AC2: Aspect lock mechanics

# Constants
const MIN_LOCK_TIME: float = 1.0  # Minimum time to achieve aspect lock (seconds)
const PIXEL_LOCK_TOLERANCE: float = 20.0  # Pixel tolerance for lock-on (from screen center)
const LOCK_DECAY_RATE: float = 2.0  # Rate at which lock decays when off target (per second)
const LOCK_BUILD_RATE: float = 1.5  # Rate at which lock builds when on target (per second)

# Signals for lock events
signal aspect_lock_acquired(target: Node3D, lock_time: float)
signal aspect_lock_lost(target: Node3D)
signal aspect_lock_progress_changed(target: Node3D, progress: float)
signal lock_tone_start(target: Node3D)
signal lock_tone_stop()

# Lock state tracking
var current_target: Node3D = null
var lock_progress: float = 0.0  # 0.0 to 1.0
var has_aspect_lock: bool = false
var lock_start_time: float = 0.0
var last_lock_check_time: float = 0.0

# Ship and camera references
var parent_ship: BaseShip
var ship_camera: Camera3D
var viewport: Viewport

# Lock tolerance and timing settings
var pixel_tolerance: float = PIXEL_LOCK_TOLERANCE
var min_lock_time: float = MIN_LOCK_TIME
var lock_decay_rate: float = LOCK_DECAY_RATE
var lock_build_rate: float = LOCK_BUILD_RATE

# Screen position tracking
var target_screen_position: Vector2 = Vector2.ZERO
var screen_center: Vector2 = Vector2.ZERO
var last_valid_screen_pos: Vector2 = Vector2.ZERO

# Audio state
var lock_tone_playing: bool = false

func _init() -> void:
	set_process(true)

func _ready() -> void:
	# Get viewport reference
	viewport = get_viewport()
	if viewport:
		screen_center = viewport.get_visible_rect().size * 0.5
	
	last_lock_check_time = Time.get_ticks_msec()

func _process(delta: float) -> void:
	if not current_target or not parent_ship:
		return
	
	# Update lock progress
	_update_aspect_lock(delta)
	
	# Update audio feedback
	_update_lock_audio()

## Initialize aspect lock controller
func initialize_aspect_lock_controller(ship: BaseShip, camera: Camera3D = null) -> bool:
	"""Initialize aspect lock controller with ship and camera references.
	
	Args:
		ship: Parent ship reference
		camera: Ship camera for screen position calculations
		
	Returns:
		true if initialization successful
	"""
	if not ship:
		push_error("AspectLockController: Cannot initialize without valid ship")
		return false
	
	parent_ship = ship
	ship_camera = camera
	
	# Try to find camera if not provided
	if not ship_camera:
		ship_camera = _find_ship_camera()
	
	if not ship_camera:
		push_warning("AspectLockController: No camera found for screen position calculations")
	
	return true

## Set target for aspect lock tracking
func set_target(target: Node3D) -> void:
	"""Set target for aspect lock tracking.
	
	Args:
		target: Target to track (null to clear)
	"""
	if current_target == target:
		return
	
	# Clear previous lock state
	_clear_lock_state()
	
	current_target = target
	
	if target:
		lock_start_time = Time.get_ticks_msec()
		_start_lock_tracking()

## Update aspect lock progress (SHIP-006 AC2)
func _update_aspect_lock(delta: float) -> void:
	"""Update aspect lock progress based on target position and timing."""
	if not current_target or not is_instance_valid(current_target):
		_clear_lock_state()
		return
	
	# Calculate target screen position
	var on_target: bool = _is_target_in_lock_tolerance()
	
	# Update lock progress
	if on_target:
		# Build lock progress
		lock_progress += lock_build_rate * delta
		lock_progress = min(lock_progress, 1.0)
		
		# Check for aspect lock achievement
		if not has_aspect_lock and lock_progress >= 1.0:
			var lock_time: float = (Time.get_ticks_msec() - lock_start_time) * 0.001
			if lock_time >= min_lock_time:
				_achieve_aspect_lock()
	else:
		# Decay lock progress
		lock_progress -= lock_decay_rate * delta
		lock_progress = max(lock_progress, 0.0)
		
		# Check for lock loss
		if has_aspect_lock and lock_progress <= 0.0:
			_lose_aspect_lock()
	
	# Emit progress signal
	aspect_lock_progress_changed.emit(current_target, lock_progress)

## Check if target is within lock tolerance (SHIP-006 AC2)
func _is_target_in_lock_tolerance() -> bool:
	"""Check if target is within pixel-based lock tolerance."""
	if not current_target or not ship_camera or not viewport:
		return false
	
	# Get target screen position
	target_screen_position = ship_camera.unproject_position(current_target.global_position)
	
	# Check if target is in front of camera
	var camera_to_target: Vector3 = current_target.global_position - ship_camera.global_position
	var camera_forward: Vector3 = -ship_camera.global_transform.basis.z
	if camera_to_target.dot(camera_forward) <= 0:
		return false  # Target is behind camera
	
	# Check if target is within screen bounds
	var screen_size: Vector2 = viewport.get_visible_rect().size
	if target_screen_position.x < 0 or target_screen_position.x > screen_size.x or \
	   target_screen_position.y < 0 or target_screen_position.y > screen_size.y:
		return false  # Target is off-screen
	
	# Calculate distance from screen center
	var distance_from_center: float = target_screen_position.distance_to(screen_center)
	
	# Update last valid position
	if distance_from_center <= pixel_tolerance * 2.0:  # Slightly larger tolerance for position tracking
		last_valid_screen_pos = target_screen_position
	
	return distance_from_center <= pixel_tolerance

## Achieve aspect lock
func _achieve_aspect_lock() -> void:
	"""Handle aspect lock achievement."""
	has_aspect_lock = true
	var lock_time: float = (Time.get_ticks_msec() - lock_start_time) * 0.001
	
	aspect_lock_acquired.emit(current_target, lock_time)
	
	# Start lock tone
	if not lock_tone_playing:
		lock_tone_start.emit(current_target)
		lock_tone_playing = true

## Lose aspect lock
func _lose_aspect_lock() -> void:
	"""Handle aspect lock loss."""
	has_aspect_lock = false
	
	aspect_lock_lost.emit(current_target)
	
	# Stop lock tone
	if lock_tone_playing:
		lock_tone_stop.emit()
		lock_tone_playing = false

## Clear lock state
func _clear_lock_state() -> void:
	"""Clear all lock state."""
	if has_aspect_lock and current_target:
		aspect_lock_lost.emit(current_target)
	
	current_target = null
	lock_progress = 0.0
	has_aspect_lock = false
	lock_start_time = 0.0
	
	# Stop lock audio
	if lock_tone_playing:
		lock_tone_stop.emit()
		lock_tone_playing = false

## Start lock tracking
func _start_lock_tracking() -> void:
	"""Initialize lock tracking for new target."""
	lock_progress = 0.0
	has_aspect_lock = false
	lock_start_time = Time.get_ticks_msec()

## Update lock audio feedback
func _update_lock_audio() -> void:
	"""Update audio feedback based on lock state."""
	if not current_target:
		if lock_tone_playing:
			lock_tone_stop.emit()
			lock_tone_playing = false
		return
	
	# Play lock tone when lock progress is building
	var should_play_tone: bool = lock_progress > 0.3 and not has_aspect_lock
	
	if should_play_tone and not lock_tone_playing:
		lock_tone_start.emit(current_target)
		lock_tone_playing = true
	elif not should_play_tone and lock_tone_playing and not has_aspect_lock:
		lock_tone_stop.emit()
		lock_tone_playing = false

## Find ship camera automatically
func _find_ship_camera() -> Camera3D:
	"""Attempt to find ship camera automatically."""
	if not parent_ship:
		return null
	
	# Look for camera in ship hierarchy
	var cameras: Array[Camera3D] = []
	_find_cameras_recursive(parent_ship, cameras)
	
	# Return first camera found
	if not cameras.is_empty():
		return cameras[0]
	
	# Look for active camera in scene
	var current_viewport := get_viewport()
	if current_viewport and current_viewport.get_camera_3d():
		return current_viewport.get_camera_3d()
	
	return null

## Recursively find cameras in node tree
func _find_cameras_recursive(node: Node, cameras: Array[Camera3D]) -> void:
	"""Recursively search for Camera3D nodes."""
	if node is Camera3D:
		cameras.append(node as Camera3D)
	
	for child in node.get_children():
		_find_cameras_recursive(child, cameras)

## Get lock status information
func get_lock_status() -> Dictionary:
	"""Get comprehensive lock status information."""
	return {
		"has_target": current_target != null,
		"target_name": current_target.name if current_target else "",
		"has_aspect_lock": has_aspect_lock,
		"lock_progress": lock_progress,
		"lock_time": (Time.get_ticks_msec() - lock_start_time) * 0.001 if current_target else 0.0,
		"target_screen_position": target_screen_position,
		"distance_from_center": target_screen_position.distance_to(screen_center) if current_target else 0.0,
		"pixel_tolerance": pixel_tolerance,
		"lock_tone_playing": lock_tone_playing
	}

## Get target screen position for HUD display
func get_target_screen_position() -> Vector2:
	"""Get current target screen position for HUD rendering."""
	if current_target and ship_camera and viewport:
		return ship_camera.unproject_position(current_target.global_position)
	return Vector2.ZERO

## Check if target is on screen
func is_target_on_screen() -> bool:
	"""Check if current target is visible on screen."""
	if not current_target or not ship_camera or not viewport:
		return false
	
	var screen_pos: Vector2 = ship_camera.unproject_position(current_target.global_position)
	var screen_size: Vector2 = viewport.get_visible_rect().size
	
	return screen_pos.x >= 0 and screen_pos.x <= screen_size.x and \
		   screen_pos.y >= 0 and screen_pos.y <= screen_size.y

## Set lock tolerance parameters
func set_lock_parameters(tolerance: float, min_time: float) -> void:
	"""Configure lock tolerance and timing parameters.
	
	Args:
		tolerance: Pixel tolerance for lock-on
		min_time: Minimum time required for aspect lock
	"""
	pixel_tolerance = tolerance
	min_lock_time = min_time

## Get lock progress as percentage
func get_lock_progress_percent() -> float:
	"""Get lock progress as percentage (0-100)."""
	return lock_progress * 100.0

## Check if can achieve lock (for missile firing)
func can_fire_missiles() -> bool:
	"""Check if aspect lock is sufficient for missile firing."""
	return has_aspect_lock

## Force clear lock (for emergency situations)
func force_clear_lock() -> void:
	"""Force clear aspect lock immediately."""
	_clear_lock_state()

## Get time since lock achieved
func get_lock_duration() -> float:
	"""Get time since aspect lock was achieved."""
	if not has_aspect_lock:
		return 0.0
	
	return (Time.get_ticks_msec() - lock_start_time) * 0.001

## Debug information
func debug_info() -> String:
	"""Get debug information string."""
	var info: String = "AspectLock: "
	info += "Target:%s " % (current_target.name if current_target else "None")
	info += "Progress:%.1f%% " % (lock_progress * 100.0)
	info += "Locked:%s " % has_aspect_lock
	if current_target:
		info += "Dist:%.1fpx " % target_screen_position.distance_to(screen_center)
	return info