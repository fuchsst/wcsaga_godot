class_name BeamLifecycleManager
extends Node

## SHIP-013 AC4: Beam Lifecycle Management
## Controls warmup, active, and warmdown phases with proper visual and audio feedback
## Manages beam weapon timing and state transitions

# Signals
signal beam_phase_changed(beam_id: String, old_phase: int, new_phase: int)
signal beam_warmup_started(beam_id: String, warmup_duration: float)
signal beam_warmup_completed(beam_id: String)
signal beam_activated(beam_id: String, active_duration: float)
signal beam_warmdown_started(beam_id: String, warmdown_duration: float)
signal beam_warmdown_completed(beam_id: String)
signal beam_expired(beam_id: String)
signal beam_lifecycle_error(beam_id: String, error_message: String)

# Beam lifecycle phases - matching BeamWeaponSystem
enum BeamPhase {
	INACTIVE = 0,
	WARMUP = 1,
	ACTIVE = 2,
	WARMDOWN = 3
}

# Active beam lifecycle tracking
var beam_lifecycles: Dictionary = {}  # beam_id -> lifecycle_data
var phase_timers: Dictionary = {}     # beam_id -> current_phase_timer
var lifecycle_callbacks: Dictionary = {}  # beam_id -> callback_functions

# Lifecycle configuration
@export var enable_lifecycle_debugging: bool = false
@export var warmup_audio_delay: float = 0.1  # Delay before warmup audio
@export var active_visual_delay: float = 0.05  # Delay before active visuals
@export var warmdown_fade_duration: float = 0.2  # Visual fade time during warmdown

# Performance tracking
var lifecycle_performance_stats: Dictionary = {
	"total_beams_processed": 0,
	"active_lifecycle_count": 0,
	"phase_transitions": 0,
	"lifecycle_errors": 0
}

# System references for feedback
var beam_renderer: BeamRenderer = null
var audio_manager: Node = null

func _ready() -> void:
	_setup_lifecycle_manager()

## Initialize beam lifecycle manager
func initialize_lifecycle_manager() -> void:
	# Find system references
	_connect_system_references()
	
	if enable_lifecycle_debugging:
		print("BeamLifecycleManager: Initialized")

## Start beam lifecycle for new beam
func start_beam_lifecycle(beam_id: String, beam_data: Dictionary) -> void:
	var config = beam_data.get("config", {})
	
	# Create lifecycle data
	var lifecycle_data = {
		"beam_id": beam_id,
		"beam_data": beam_data,
		"current_phase": BeamPhase.INACTIVE,
		"warmup_time": config.get("warmup_time", 0.5),
		"active_duration": config.get("active_duration", 3.0),
		"warmdown_time": config.get("warmdown_time", 0.3),
		"start_time": Time.get_ticks_msec() / 1000.0,
		"phase_start_time": 0.0,
		"total_lifetime": 0.0,
		"callbacks_executed": [],
		"lifecycle_complete": false
	}
	
	# Calculate total lifetime
	lifecycle_data["total_lifetime"] = lifecycle_data["warmup_time"] + lifecycle_data["active_duration"] + lifecycle_data["warmdown_time"]
	
	# Register lifecycle
	beam_lifecycles[beam_id] = lifecycle_data
	phase_timers[beam_id] = 0.0
	lifecycle_callbacks[beam_id] = {}
	
	# Start warmup phase
	_transition_to_phase(beam_id, BeamPhase.WARMUP)
	
	lifecycle_performance_stats["total_beams_processed"] += 1
	lifecycle_performance_stats["active_lifecycle_count"] = beam_lifecycles.size()
	
	if enable_lifecycle_debugging:
		print("BeamLifecycleManager: Started lifecycle for beam %s (total: %.2fs)" % [
			beam_id, lifecycle_data["total_lifetime"]
		])

## Force beam to warmdown phase
func start_beam_warmdown(beam_id: String) -> void:
	if not beam_lifecycles.has(beam_id):
		beam_lifecycle_error.emit(beam_id, "Cannot start warmdown: beam not found")
		return
	
	var lifecycle_data = beam_lifecycles[beam_id]
	var current_phase = lifecycle_data.get("current_phase", BeamPhase.INACTIVE)
	
	# Only transition if currently in warmup or active phase
	if current_phase == BeamPhase.WARMUP or current_phase == BeamPhase.ACTIVE:
		_transition_to_phase(beam_id, BeamPhase.WARMDOWN)
		
		if enable_lifecycle_debugging:
			print("BeamLifecycleManager: Forced beam %s to warmdown phase" % beam_id)

## Get current beam phase
func get_beam_phase(beam_id: String) -> BeamPhase:
	if beam_lifecycles.has(beam_id):
		return beam_lifecycles[beam_id].get("current_phase", BeamPhase.INACTIVE)
	return BeamPhase.INACTIVE

## Get beam lifecycle progress (0.0 to 1.0)
func get_beam_lifecycle_progress(beam_id: String) -> float:
	if not beam_lifecycles.has(beam_id):
		return 0.0
	
	var lifecycle_data = beam_lifecycles[beam_id]
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed_time = current_time - lifecycle_data.get("start_time", 0.0)
	var total_lifetime = lifecycle_data.get("total_lifetime", 1.0)
	
	return clamp(elapsed_time / total_lifetime, 0.0, 1.0)

## Get current phase progress (0.0 to 1.0)
func get_phase_progress(beam_id: String) -> float:
	if not beam_lifecycles.has(beam_id) or not phase_timers.has(beam_id):
		return 0.0
	
	var lifecycle_data = beam_lifecycles[beam_id]
	var current_phase = lifecycle_data.get("current_phase", BeamPhase.INACTIVE)
	var phase_timer = phase_timers[beam_id]
	
	var phase_duration = _get_phase_duration(beam_id, current_phase)
	if phase_duration <= 0.0:
		return 1.0
	
	return clamp(phase_timer / phase_duration, 0.0, 1.0)

## Register lifecycle callback
func register_lifecycle_callback(beam_id: String, phase: BeamPhase, callback: Callable) -> void:
	if not lifecycle_callbacks.has(beam_id):
		lifecycle_callbacks[beam_id] = {}
	
	if not lifecycle_callbacks[beam_id].has(phase):
		lifecycle_callbacks[beam_id][phase] = []
	
	lifecycle_callbacks[beam_id][phase].append(callback)

## Setup lifecycle manager
func _setup_lifecycle_manager() -> void:
	beam_lifecycles.clear()
	phase_timers.clear()
	lifecycle_callbacks.clear()
	
	# Reset performance stats
	lifecycle_performance_stats = {
		"total_beams_processed": 0,
		"active_lifecycle_count": 0,
		"phase_transitions": 0,
		"lifecycle_errors": 0
	}

## Connect system references
func _connect_system_references() -> void:
	# Find beam renderer
	beam_renderer = get_parent().get_node_or_null("BeamRenderer")
	
	# Find audio manager
	audio_manager = get_parent().get_node_or_null("CombatAudioManager")
	if not audio_manager:
		audio_manager = get_node_or_null("/root/AudioManager")

## Transition beam to new phase
func _transition_to_phase(beam_id: String, new_phase: BeamPhase) -> void:
	if not beam_lifecycles.has(beam_id):
		beam_lifecycle_error.emit(beam_id, "Cannot transition phase: beam not found")
		lifecycle_performance_stats["lifecycle_errors"] += 1
		return
	
	var lifecycle_data = beam_lifecycles[beam_id]
	var old_phase = lifecycle_data.get("current_phase", BeamPhase.INACTIVE)
	
	# Update lifecycle data
	lifecycle_data["current_phase"] = new_phase
	lifecycle_data["phase_start_time"] = Time.get_ticks_msec() / 1000.0
	phase_timers[beam_id] = 0.0
	
	# Execute phase-specific actions
	_execute_phase_actions(beam_id, new_phase)
	
	# Execute callbacks
	_execute_phase_callbacks(beam_id, new_phase)
	
	# Emit signals
	beam_phase_changed.emit(beam_id, old_phase, new_phase)
	_emit_phase_specific_signals(beam_id, new_phase)
	
	lifecycle_performance_stats["phase_transitions"] += 1
	
	if enable_lifecycle_debugging:
		print("BeamLifecycleManager: Beam %s transitioned from %s to %s" % [
			beam_id, _phase_to_string(old_phase), _phase_to_string(new_phase)
		])

## Execute actions specific to beam phase
func _execute_phase_actions(beam_id: String, phase: BeamPhase) -> void:
	match phase:
		BeamPhase.WARMUP:
			_execute_warmup_actions(beam_id)
		
		BeamPhase.ACTIVE:
			_execute_active_actions(beam_id)
		
		BeamPhase.WARMDOWN:
			_execute_warmdown_actions(beam_id)
		
		BeamPhase.INACTIVE:
			_execute_inactive_actions(beam_id)

## Execute warmup phase actions
func _execute_warmup_actions(beam_id: String) -> void:
	# Start warmup visual effects
	if beam_renderer:
		beam_renderer.start_beam_warmup(beam_id)
	
	# Start warmup audio with delay
	if audio_manager:
		var timer = create_tween()
		timer.tween_delay(warmup_audio_delay)
		timer.tween_callback(_play_warmup_audio.bind(beam_id))

## Execute active phase actions
func _execute_active_actions(beam_id: String) -> void:
	# Activate full beam rendering
	if beam_renderer:
		var timer = create_tween()
		timer.tween_delay(active_visual_delay)
		timer.tween_callback(beam_renderer.activate_full_beam_rendering.bind(beam_id))
	
	# Start active beam audio
	if audio_manager:
		_play_active_beam_audio(beam_id)

## Execute warmdown phase actions
func _execute_warmdown_actions(beam_id: String) -> void:
	# Start beam fade-out
	if beam_renderer:
		beam_renderer.start_beam_fadeout(beam_id, warmdown_fade_duration)
	
	# Fade out audio
	if audio_manager:
		_fade_beam_audio(beam_id)

## Execute inactive phase actions
func _execute_inactive_actions(beam_id: String) -> void:
	# Complete beam shutdown
	if beam_renderer:
		beam_renderer.stop_beam_rendering(beam_id)
	
	# Stop all audio
	if audio_manager:
		_stop_beam_audio(beam_id)

## Execute phase callbacks
func _execute_phase_callbacks(beam_id: String, phase: BeamPhase) -> void:
	if not lifecycle_callbacks.has(beam_id):
		return
	
	var beam_callbacks = lifecycle_callbacks[beam_id]
	if beam_callbacks.has(phase):
		var callbacks = beam_callbacks[phase]
		for callback in callbacks:
			if callback.is_valid():
				callback.call()

## Emit phase-specific signals
func _emit_phase_specific_signals(beam_id: String, phase: BeamPhase) -> void:
	var lifecycle_data = beam_lifecycles.get(beam_id, {})
	
	match phase:
		BeamPhase.WARMUP:
			var warmup_duration = lifecycle_data.get("warmup_time", 0.5)
			beam_warmup_started.emit(beam_id, warmup_duration)
		
		BeamPhase.ACTIVE:
			var active_duration = lifecycle_data.get("active_duration", 3.0)
			beam_activated.emit(beam_id, active_duration)
		
		BeamPhase.WARMDOWN:
			var warmdown_duration = lifecycle_data.get("warmdown_time", 0.3)
			beam_warmdown_started.emit(beam_id, warmdown_duration)

## Audio system integration
func _play_warmup_audio(beam_id: String) -> void:
	if audio_manager and audio_manager.has_method("play_beam_warmup_audio"):
		var lifecycle_data = beam_lifecycles.get(beam_id, {})
		var beam_data = lifecycle_data.get("beam_data", {})
		audio_manager.play_beam_warmup_audio(beam_data)

func _play_active_beam_audio(beam_id: String) -> void:
	if audio_manager and audio_manager.has_method("play_beam_active_audio"):
		var lifecycle_data = beam_lifecycles.get(beam_id, {})
		var beam_data = lifecycle_data.get("beam_data", {})
		audio_manager.play_beam_active_audio(beam_data)

func _fade_beam_audio(beam_id: String) -> void:
	if audio_manager and audio_manager.has_method("fade_beam_audio"):
		audio_manager.fade_beam_audio(beam_id, warmdown_fade_duration)

func _stop_beam_audio(beam_id: String) -> void:
	if audio_manager and audio_manager.has_method("stop_beam_audio"):
		audio_manager.stop_beam_audio(beam_id)

## Update beam lifecycles
func _update_beam_lifecycles(delta: float) -> void:
	var beams_to_remove: Array[String] = []
	
	for beam_id in beam_lifecycles.keys():
		var lifecycle_data = beam_lifecycles[beam_id]
		var current_phase = lifecycle_data.get("current_phase", BeamPhase.INACTIVE)
		
		# Update phase timer
		if phase_timers.has(beam_id):
			phase_timers[beam_id] += delta
		
		# Check for phase transitions
		var phase_duration = _get_phase_duration(beam_id, current_phase)
		var phase_timer = phase_timers.get(beam_id, 0.0)
		
		if phase_timer >= phase_duration:
			_handle_phase_completion(beam_id, current_phase, beams_to_remove)
	
	# Remove completed beams
	for beam_id in beams_to_remove:
		_complete_beam_lifecycle(beam_id)

## Handle phase completion
func _handle_phase_completion(beam_id: String, completed_phase: BeamPhase, beams_to_remove: Array[String]) -> void:
	match completed_phase:
		BeamPhase.WARMUP:
			beam_warmup_completed.emit(beam_id)
			_transition_to_phase(beam_id, BeamPhase.ACTIVE)
		
		BeamPhase.ACTIVE:
			_transition_to_phase(beam_id, BeamPhase.WARMDOWN)
		
		BeamPhase.WARMDOWN:
			beam_warmdown_completed.emit(beam_id)
			beams_to_remove.append(beam_id)
		
		BeamPhase.INACTIVE:
			beams_to_remove.append(beam_id)

## Complete beam lifecycle
func _complete_beam_lifecycle(beam_id: String) -> void:
	if beam_lifecycles.has(beam_id):
		beam_lifecycles[beam_id]["lifecycle_complete"] = true
		beam_lifecycles.erase(beam_id)
	
	phase_timers.erase(beam_id)
	lifecycle_callbacks.erase(beam_id)
	
	lifecycle_performance_stats["active_lifecycle_count"] = beam_lifecycles.size()
	
	beam_expired.emit(beam_id)
	
	if enable_lifecycle_debugging:
		print("BeamLifecycleManager: Completed lifecycle for beam %s" % beam_id)

## Get phase duration for beam
func _get_phase_duration(beam_id: String, phase: BeamPhase) -> float:
	if not beam_lifecycles.has(beam_id):
		return 0.0
	
	var lifecycle_data = beam_lifecycles[beam_id]
	
	match phase:
		BeamPhase.WARMUP:
			return lifecycle_data.get("warmup_time", 0.5)
		BeamPhase.ACTIVE:
			return lifecycle_data.get("active_duration", 3.0)
		BeamPhase.WARMDOWN:
			return lifecycle_data.get("warmdown_time", 0.3)
		BeamPhase.INACTIVE:
			return 0.0
		_:
			return 0.0

## Convert phase enum to string
func _phase_to_string(phase: BeamPhase) -> String:
	match phase:
		BeamPhase.INACTIVE:
			return "INACTIVE"
		BeamPhase.WARMUP:
			return "WARMUP"
		BeamPhase.ACTIVE:
			return "ACTIVE"
		BeamPhase.WARMDOWN:
			return "WARMDOWN"
		_:
			return "UNKNOWN"

## Get lifecycle statistics
func get_lifecycle_statistics() -> Dictionary:
	return {
		"active_lifecycles": beam_lifecycles.size(),
		"performance_stats": lifecycle_performance_stats.duplicate(),
		"phase_distribution": _get_phase_distribution()
	}

## Get phase distribution
func _get_phase_distribution() -> Dictionary:
	var distribution = {
		BeamPhase.INACTIVE: 0,
		BeamPhase.WARMUP: 0,
		BeamPhase.ACTIVE: 0,
		BeamPhase.WARMDOWN: 0
	}
	
	for lifecycle_data in beam_lifecycles.values():
		var phase = lifecycle_data.get("current_phase", BeamPhase.INACTIVE)
		distribution[phase] += 1
	
	return distribution

## Get beam lifecycle data
func get_beam_lifecycle_data(beam_id: String) -> Dictionary:
	return beam_lifecycles.get(beam_id, {}).duplicate()

## Check if beam is in specific phase
func is_beam_in_phase(beam_id: String, phase: BeamPhase) -> bool:
	return get_beam_phase(beam_id) == phase

## Process frame updates
func _process(delta: float) -> void:
	_update_beam_lifecycles(delta)