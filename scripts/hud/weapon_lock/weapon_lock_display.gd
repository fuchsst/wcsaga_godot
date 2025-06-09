@tool
extends HUDGauge
class_name WeaponLockDisplay

## Main weapon lock indicator system for HUD-007
## Displays various weapon lock states and firing solution information
## Integrates with multiple weapon types and lock-on systems

# Weapon types for lock display
enum WeaponType {
	ENERGY,		# Lasers, particle beams
	BALLISTIC,	# Mass drivers, autocannons
	MISSILE,	# Seeking missiles
	BEAM,		# Continuous beam weapons
	SPECIAL		# EMP, flak, swarm
}

# Lock states
enum LockState {
	NONE,		# No lock attempt
	SEEKING,	# Acquiring lock
	LOCKED,		# Target locked
	LOST,		# Lock lost/broken
	JAMMED		# Lock jammed/disrupted
}

# Lock display modes
enum DisplayMode {
	MINIMAL,	# Basic lock indicators only
	STANDARD,	# Standard weapon lock display
	DETAILED	# Full firing solution display
}

# Lock display state
@export_group("Lock Status")
@export var lock_state: LockState = LockState.NONE:
	set(value):
		if lock_state != value:
			var old_state: LockState = lock_state
			lock_state = value
			_on_lock_state_changed(old_state, value)
			queue_redraw()

@export var weapon_type: WeaponType = WeaponType.ENERGY:
	set(value):
		weapon_type = value
		queue_redraw()

@export var display_mode: DisplayMode = DisplayMode.STANDARD:
	set(value):
		display_mode = value
		queue_redraw()

@export_range(0.0, 1.0) var lock_progress: float = 0.0:
	set(value):
		lock_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var lock_screen_position: Vector2 = Vector2.ZERO:
	set(value):
		lock_screen_position = value
		queue_redraw()

# Weapon status
@export_group("Weapon Status")
@export var weapon_ready: bool = false:
	set(value):
		weapon_ready = value
		queue_redraw()

@export var ammo_count: int = 0:
	set(value):
		ammo_count = value
		queue_redraw()

@export var weapon_energy: float = 1.0:
	set(value):
		weapon_energy = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var weapon_heat: float = 0.0:
	set(value):
		weapon_heat = clampf(value, 0.0, 1.0)
		queue_redraw()

# Firing solution data
@export_group("Firing Solution")
@export var target_distance: float = 0.0:
	set(value):
		target_distance = value
		queue_redraw()

@export var time_to_impact: float = 0.0:
	set(value):
		time_to_impact = value
		queue_redraw()

@export var hit_probability: float = 0.0:
	set(value):
		hit_probability = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var target_velocity: Vector3 = Vector3.ZERO:
	set(value):
		target_velocity = value
		queue_redraw()

# Visual settings
@export_group("Visual Settings")
@export var lock_indicator_size: float = 30.0
@export var progress_ring_radius: float = 40.0
@export var weapon_status_offset: Vector2 = Vector2(50, 0)
@export var firing_solution_offset: Vector2 = Vector2(-80, 20)

# Color settings
@export_group("Colors")
@export var color_seeking: Color = Color.YELLOW
@export var color_locked: Color = Color.GREEN
@export var color_lost: Color = Color.RED
@export var color_jammed: Color = Color.MAGENTA
@export var color_weapon_ready: Color = Color.GREEN
@export var color_weapon_charging: Color = Color.YELLOW
@export var color_weapon_overheated: Color = Color.RED

# Animation state
var _animation_time: float = 0.0
var _flash_state: bool = false
var _rotation_angle: float = 0.0
var _lock_acquire_start_time: float = 0.0

# Audio references
@onready var lock_seeking_audio: AudioStreamPlayer = $LockSeekingAudio
@onready var lock_acquired_audio: AudioStreamPlayer = $LockAcquiredAudio
@onready var lock_lost_audio: AudioStreamPlayer = $LockLostAudio

# Child components
var lock_on_manager: LockOnManager
var firing_solution_display: FiringSolutionDisplay
var weapon_status_indicator: WeaponStatusIndicator

func _init() -> void:
	super._init()
	gauge_id = GaugeType.MISSILE_WARNING_ARROW  # Reusing existing ID
	is_popup = false

func _ready() -> void:
	super._ready()
	_initialize_components()
	_setup_audio_streams()

## Initialize child components
func _initialize_components() -> void:
	"""Initialize sub-components for weapon lock display."""
	# Create lock-on manager
	lock_on_manager = LockOnManager.new()
	add_child(lock_on_manager)
	lock_on_manager.initialize_lock_on_manager()
	
	# Connect signals
	lock_on_manager.lock_state_changed.connect(_on_lock_manager_state_changed)
	lock_on_manager.lock_progress_updated.connect(_on_lock_progress_updated)
	
	# Create firing solution display
	firing_solution_display = FiringSolutionDisplay.new()
	add_child(firing_solution_display)
	firing_solution_display.initialize_firing_solution_display()
	
	# Create weapon status indicator
	weapon_status_indicator = WeaponStatusIndicator.new()
	add_child(weapon_status_indicator)
	weapon_status_indicator.initialize_weapon_status_indicator()

## Setup audio streams for lock feedback
func _setup_audio_streams() -> void:
	"""Setup audio streams for weapon lock feedback."""
	if lock_seeking_audio:
		# Load seeking sound (continuous tone)
		# lock_seeking_audio.stream = preload("res://audio/hud/weapon_lock_seeking.ogg")
		lock_seeking_audio.autoplay = false
		
	if lock_acquired_audio:
		# Load lock acquired sound (single beep)
		# lock_acquired_audio.stream = preload("res://audio/hud/weapon_lock_acquired.ogg")
		lock_acquired_audio.autoplay = false
		
	if lock_lost_audio:
		# Load lock lost sound
		# lock_lost_audio.stream = preload("res://audio/hud/weapon_lock_lost.ogg")
		lock_lost_audio.autoplay = false

## Update display from game state
func update_from_game_state() -> void:
	"""Update weapon lock display from current game state."""
	# Check if player ship and weapon systems exist
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() == 0 or not is_instance_valid(player_nodes[0]):
		_reset_display()
		return
	
	var player_ship = player_nodes[0]
	if not player_ship.weapon_manager:
		_reset_display()
		return
	
	var weapon_manager = player_ship.weapon_manager
	
	# Get current weapon lock data
	var lock_data: Dictionary = weapon_manager.get_weapon_lock_data()
	
	# Update lock state
	if lock_data.has("lock_state"):
		lock_state = lock_data["lock_state"]
	
	if lock_data.has("lock_progress"):
		lock_progress = lock_data["lock_progress"]
	
	if lock_data.has("lock_position"):
		lock_screen_position = lock_data["lock_position"]
	
	if lock_data.has("weapon_type"):
		weapon_type = lock_data["weapon_type"]
	
	# Update weapon status
	var weapon_status: Dictionary = weapon_manager.get_current_weapon_status()
	
	if weapon_status.has("ready"):
		weapon_ready = weapon_status["ready"]
	
	if weapon_status.has("ammo"):
		ammo_count = weapon_status["ammo"]
	
	if weapon_status.has("energy"):
		weapon_energy = weapon_status["energy"]
	
	if weapon_status.has("heat"):
		weapon_heat = weapon_status["heat"]
	
	# Update firing solution
	var firing_data: Dictionary = weapon_manager.get_firing_solution_data()
	
	if firing_data.has("target_distance"):
		target_distance = firing_data["target_distance"]
	
	if firing_data.has("time_to_impact"):
		time_to_impact = firing_data["time_to_impact"]
	
	if firing_data.has("hit_probability"):
		hit_probability = firing_data["hit_probability"]
	
	if firing_data.has("target_velocity"):
		target_velocity = firing_data["target_velocity"]
	
	# Update child components
	if lock_on_manager:
		lock_on_manager.update_lock_status(lock_data)
	
	if firing_solution_display:
		firing_solution_display.update_firing_solution(firing_data)
	
	if weapon_status_indicator:
		weapon_status_indicator.update_weapon_status(weapon_status)

## Reset display to default state
func _reset_display() -> void:
	"""Reset display to default state when no ship/weapons available."""
	lock_state = LockState.NONE
	lock_progress = 0.0
	weapon_ready = false
	ammo_count = 0
	weapon_energy = 1.0
	weapon_heat = 0.0
	target_distance = 0.0
	time_to_impact = 0.0
	hit_probability = 0.0

## Handle lock state changes
func _on_lock_state_changed(old_state: LockState, new_state: LockState) -> void:
	"""Handle lock state transition logic."""
	# Reset animation state
	_animation_time = 0.0
	_flash_state = false
	
	match new_state:
		LockState.SEEKING:
			_lock_acquire_start_time = Time.get_ticks_msec() / 1000.0
			_play_seeking_audio()
			
		LockState.LOCKED:
			_play_lock_acquired_audio()
			_stop_seeking_audio()
			
		LockState.LOST:
			_play_lock_lost_audio()
			_stop_seeking_audio()
			
		LockState.JAMMED:
			_stop_seeking_audio()
			
		LockState.NONE:
			_stop_all_audio()

## Audio control methods
func _play_seeking_audio() -> void:
	"""Play seeking lock audio."""
	if lock_seeking_audio and not lock_seeking_audio.playing:
		lock_seeking_audio.play()

func _play_lock_acquired_audio() -> void:
	"""Play lock acquired audio."""
	if lock_acquired_audio:
		lock_acquired_audio.play()

func _play_lock_lost_audio() -> void:
	"""Play lock lost audio."""
	if lock_lost_audio:
		lock_lost_audio.play()

func _stop_seeking_audio() -> void:
	"""Stop seeking audio."""
	if lock_seeking_audio and lock_seeking_audio.playing:
		lock_seeking_audio.stop()

func _stop_all_audio() -> void:
	"""Stop all lock audio."""
	_stop_seeking_audio()
	if lock_acquired_audio and lock_acquired_audio.playing:
		lock_acquired_audio.stop()
	if lock_lost_audio and lock_lost_audio.playing:
		lock_lost_audio.stop()

## Drawing methods
func _draw() -> void:
	"""Main drawing method for weapon lock display."""
	if Engine.is_editor_hint():
		_draw_editor_preview()
		return
	
	if not can_draw():
		return
	
	var base_color: Color = get_current_color()
	
	# Draw based on display mode
	match display_mode:
		DisplayMode.MINIMAL:
			_draw_minimal_display(base_color)
		DisplayMode.STANDARD:
			_draw_standard_display(base_color)
		DisplayMode.DETAILED:
			_draw_detailed_display(base_color)

## Draw editor preview
func _draw_editor_preview() -> void:
	"""Draw editor preview."""
	var preview_size: Vector2 = Vector2(200, 150)
	draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
	
	var center: Vector2 = preview_size / 2.0
	_draw_lock_indicator(center, Color.CYAN, true)
	
	# Draw weapon type label
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var weapon_name: String = WeaponType.keys()[weapon_type]
	draw_string(font, Vector2(5, font_size + 5), "Weapon Lock: " + weapon_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	
	super._draw()

## Draw minimal display
func _draw_minimal_display(base_color: Color) -> void:
	"""Draw minimal lock display - just basic indicator."""
	if lock_state == LockState.NONE:
		return
	
	_draw_lock_indicator(lock_screen_position, base_color, false)

## Draw standard display
func _draw_standard_display(base_color: Color) -> void:
	"""Draw standard lock display with weapon status."""
	if lock_state == LockState.NONE:
		return
	
	# Main lock indicator
	_draw_lock_indicator(lock_screen_position, base_color, false)
	
	# Weapon status
	_draw_weapon_status(lock_screen_position + weapon_status_offset, base_color)

## Draw detailed display
func _draw_detailed_display(base_color: Color) -> void:
	"""Draw detailed display with full firing solution."""
	if lock_state == LockState.NONE:
		return
	
	# Main lock indicator
	_draw_lock_indicator(lock_screen_position, base_color, false)
	
	# Weapon status
	_draw_weapon_status(lock_screen_position + weapon_status_offset, base_color)
	
	# Firing solution
	_draw_firing_solution(lock_screen_position + firing_solution_offset, base_color)

## Draw lock indicator based on weapon type and state
func _draw_lock_indicator(position: Vector2, color: Color, is_preview: bool) -> void:
	"""Draw weapon lock indicator based on type and state."""
	var indicator_color: Color = color
	
	# Override color based on lock state
	match lock_state:
		LockState.SEEKING:
			indicator_color = color_seeking
		LockState.LOCKED:
			indicator_color = color_locked
		LockState.LOST:
			indicator_color = color_lost
		LockState.JAMMED:
			indicator_color = color_jammed
	
	# Draw based on weapon type
	match weapon_type:
		WeaponType.ENERGY:
			_draw_energy_weapon_indicator(position, indicator_color, is_preview)
		WeaponType.BALLISTIC:
			_draw_ballistic_weapon_indicator(position, indicator_color, is_preview)
		WeaponType.MISSILE:
			_draw_missile_weapon_indicator(position, indicator_color, is_preview)
		WeaponType.BEAM:
			_draw_beam_weapon_indicator(position, indicator_color, is_preview)
		WeaponType.SPECIAL:
			_draw_special_weapon_indicator(position, indicator_color, is_preview)

## Draw energy weapon indicator (crosshair style)
func _draw_energy_weapon_indicator(position: Vector2, color: Color, is_preview: bool) -> void:
	"""Draw energy weapon lock indicator."""
	var size: float = lock_indicator_size
	
	# Draw crosshair
	draw_line(position - Vector2(size, 0), position + Vector2(size, 0), color, 2.0)
	draw_line(position - Vector2(0, size), position + Vector2(0, size), color, 2.0)
	
	# Draw progress ring for seeking
	if lock_state == LockState.SEEKING:
		var progress_arc: float = TAU * lock_progress
		draw_arc(position, progress_ring_radius, -PI/2, -PI/2 + progress_arc, 32, color, 2.0)
	
	# Draw lock confirmation for locked state
	elif lock_state == LockState.LOCKED:
		if _flash_state:
			draw_circle(position, size * 0.3, color)

## Draw ballistic weapon indicator (square style)
func _draw_ballistic_weapon_indicator(position: Vector2, color: Color, is_preview: bool) -> void:
	"""Draw ballistic weapon lock indicator."""
	var size: float = lock_indicator_size
	
	# Draw square brackets
	var bracket_size: float = size * 0.7
	for i in range(4):
		var angle: float = i * PI/2
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var corner: Vector2 = position + dir * size
		var line1_end: Vector2 = corner - dir * bracket_size
		var line2_end: Vector2 = corner - Vector2(-dir.y, dir.x) * bracket_size
		
		draw_line(corner, line1_end, color, 2.0)
		draw_line(corner, line2_end, color, 2.0)
	
	# Draw progress for seeking
	if lock_state == LockState.SEEKING:
		var progress_size: float = size * (0.5 + 0.5 * lock_progress)
		draw_rect(Rect2(position - Vector2(progress_size, progress_size), 
			Vector2(progress_size * 2, progress_size * 2)), color, false, 2.0)

## Draw missile weapon indicator (diamond style)
func _draw_missile_weapon_indicator(position: Vector2, color: Color, is_preview: bool) -> void:
	"""Draw missile weapon lock indicator."""
	var size: float = lock_indicator_size
	
	# Draw diamond shape
	var points: PackedVector2Array = PackedVector2Array([
		position + Vector2(0, -size),
		position + Vector2(size, 0),
		position + Vector2(0, size),
		position + Vector2(-size, 0)
	])
	var closed_points = points.duplicate()
	closed_points.append(points[0])
	draw_polyline(closed_points, color, 2.0)
	
	# Draw seeking animation
	if lock_state == LockState.SEEKING:
		# Rotating elements
		for i in range(4):
			var angle: float = _rotation_angle + i * PI/2
			var pos: Vector2 = position + Vector2(cos(angle), sin(angle)) * (size + 10)
			draw_circle(pos, 3, color)
	
	# Draw lock confirmation
	elif lock_state == LockState.LOCKED:
		if _flash_state:
			# Draw filled diamond
			draw_colored_polygon(points, color)

## Draw beam weapon indicator (targeting reticle style)
func _draw_beam_weapon_indicator(position: Vector2, color: Color, is_preview: bool) -> void:
	"""Draw beam weapon lock indicator."""
	var size: float = lock_indicator_size
	
	# Draw outer circle
	draw_arc(position, size, 0, TAU, 32, color, 2.0)
	
	# Draw inner crosshair
	var inner_size: float = size * 0.5
	draw_line(position - Vector2(inner_size, 0), position + Vector2(inner_size, 0), color, 1.0)
	draw_line(position - Vector2(0, inner_size), position + Vector2(0, inner_size), color, 1.0)
	
	# Draw beam charge indicator
	if lock_state == LockState.SEEKING:
		var charge_progress: float = lock_progress * TAU
		draw_arc(position, size + 5, -PI/2, -PI/2 + charge_progress, 32, color, 3.0)

## Draw special weapon indicator (hexagon style)
func _draw_special_weapon_indicator(position: Vector2, color: Color, is_preview: bool) -> void:
	"""Draw special weapon lock indicator."""
	var size: float = lock_indicator_size
	
	# Draw hexagon
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var angle: float = i * PI/3
		points.append(position + Vector2(cos(angle), sin(angle)) * size)
	
	var closed_points = points.duplicate()
	closed_points.append(points[0])
	draw_polyline(closed_points, color, 2.0)
	
	# Special seeking animation
	if lock_state == LockState.SEEKING:
		var pulse_scale: float = 1.0 + 0.3 * sin(_animation_time * 4.0)
		var pulse_size: float = size * pulse_scale
		draw_circle(position, pulse_size, Color(color.r, color.g, color.b, 0.3))

## Draw weapon status information
func _draw_weapon_status(position: Vector2, color: Color) -> void:
	"""Draw weapon status information."""
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var line_height: float = font_size + 2.0
	var current_y: float = position.y
	
	# Weapon ready status
	var ready_color: Color = color_weapon_ready if weapon_ready else color_weapon_charging
	draw_string(font, Vector2(position.x, current_y), 
		"RDY" if weapon_ready else "CHG", 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ready_color)
	
	current_y += line_height
	
	# Ammo count (for missiles/ballistic)
	if weapon_type in [WeaponType.MISSILE, WeaponType.BALLISTIC]:
		draw_string(font, Vector2(position.x, current_y), 
			"AMO: %d" % ammo_count,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		current_y += line_height
	
	# Energy level (for energy weapons)
	if weapon_type in [WeaponType.ENERGY, WeaponType.BEAM]:
		var energy_color: Color = color_weapon_ready if weapon_energy > 0.3 else color_weapon_charging
		draw_string(font, Vector2(position.x, current_y), 
			"PWR: %d%%" % int(weapon_energy * 100),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, energy_color)
		current_y += line_height
	
	# Heat level (if overheating)
	if weapon_heat > 0.5:
		var heat_color: Color = color_weapon_overheated if weapon_heat > 0.8 else color_weapon_charging
		draw_string(font, Vector2(position.x, current_y), 
			"HOT: %d%%" % int(weapon_heat * 100),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, heat_color)

## Draw firing solution information
func _draw_firing_solution(position: Vector2, color: Color) -> void:
	"""Draw firing solution information."""
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var line_height: float = font_size + 2.0
	var current_y: float = position.y
	
	# Target distance
	draw_string(font, Vector2(position.x, current_y), 
		"RNG: %.0fm" % target_distance,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	current_y += line_height
	
	# Time to impact
	if time_to_impact > 0.0:
		draw_string(font, Vector2(position.x, current_y), 
			"TTI: %.1fs" % time_to_impact,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		current_y += line_height
	
	# Hit probability
	var prob_color: Color = color_weapon_ready if hit_probability > 0.5 else color_weapon_charging
	draw_string(font, Vector2(position.x, current_y), 
		"HIT: %d%%" % int(hit_probability * 100),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, prob_color)

## Process animation updates
func _process(delta: float) -> void:
	super._process(delta)
	
	_animation_time += delta
	
	# Update rotation for seeking states
	if lock_state == LockState.SEEKING:
		_rotation_angle += PI * delta
		if _rotation_angle > TAU:
			_rotation_angle -= TAU
	
	# Update flash state for locked
	if lock_state == LockState.LOCKED:
		if fmod(_animation_time, 0.6) < 0.3:
			_flash_state = true
		else:
			_flash_state = false
	
	# Redraw if animating
	if lock_state in [LockState.SEEKING, LockState.LOCKED, LockState.JAMMED]:
		queue_redraw()

## Signal handlers from child components
func _on_lock_manager_state_changed(new_state: int) -> void:
	"""Handle lock state changes from lock manager."""
	lock_state = new_state as LockState

func _on_lock_progress_updated(progress: float) -> void:
	"""Handle lock progress updates."""
	lock_progress = progress

## Configuration methods
func set_display_mode(mode: DisplayMode) -> void:
	"""Set weapon lock display mode."""
	display_mode = mode

func set_weapon_type(type: WeaponType) -> void:
	"""Set weapon type for lock display."""
	weapon_type = type

func set_lock_position(position: Vector2) -> void:
	"""Set screen position for lock indicator."""
	lock_screen_position = position

## Get current lock status for external systems
func get_lock_status() -> Dictionary:
	"""Get current weapon lock status."""
	return {
		"lock_state": lock_state,
		"lock_progress": lock_progress,
		"weapon_type": weapon_type,
		"weapon_ready": weapon_ready,
		"hit_probability": hit_probability,
		"time_to_impact": time_to_impact
	}
