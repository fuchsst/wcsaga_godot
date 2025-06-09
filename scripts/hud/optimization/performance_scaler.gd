class_name HUDPerformanceScaler
extends Node

## EPIC-012 HUD-003: Automatic performance scaling for HUD systems
## Monitors performance and adjusts quality settings to maintain target FPS

signal performance_profile_changed(old_profile: PerformanceProfile, new_profile: PerformanceProfile)
signal quality_adjustment_applied(element_type: String, quality_change: String)
signal fps_threshold_crossed(fps: float, threshold: float, direction: String)

# Performance profiles from highest to lowest quality
enum PerformanceProfile {
	MAXIMUM = 0,  # Maximum quality, all features enabled
	HIGH = 1,     # High quality, minor optimizations
	MEDIUM = 2,   # Medium quality, noticeable optimizations
	LOW = 3,      # Low quality, significant optimizations
	MINIMAL = 4   # Minimal quality, maximum performance
}

# Scaling configuration
@export var auto_scaling_enabled: bool = true
@export var target_fps: float = 60.0                  # Target frame rate
@export var fps_tolerance: float = 5.0                # Tolerance before scaling
@export var scaling_hysteresis_time: float = 3.0      # Delay before scaling changes
@export var emergency_fps_threshold: float = 30.0     # Emergency scaling threshold

# Current state
var current_profile: PerformanceProfile = PerformanceProfile.MAXIMUM
var requested_profile: PerformanceProfile = PerformanceProfile.MAXIMUM
var profile_change_timer: float = 0.0
var last_fps_samples: Array[float] = []
var max_fps_samples: int = 30  # 30 frames of history

# FPS thresholds for automatic scaling
var fps_thresholds: Dictionary = {
	PerformanceProfile.MAXIMUM: 58.0,   # Above 58 FPS: MAXIMUM
	PerformanceProfile.HIGH: 50.0,      # Above 50 FPS: HIGH  
	PerformanceProfile.MEDIUM: 42.0,    # Above 42 FPS: MEDIUM
	PerformanceProfile.LOW: 35.0,       # Above 35 FPS: LOW
	PerformanceProfile.MINIMAL: 25.0    # Below 35 FPS: MINIMAL
}

# Quality settings for each performance profile
var profile_settings: Dictionary = {
	PerformanceProfile.MAXIMUM: {
		"update_frequency_multiplier": 1.0,
		"lod_bias": 0,
		"effect_quality": 1.0,
		"shadow_quality": 1.0,
		"texture_quality": 1.0,
		"particle_density": 1.0,
		"animation_quality": 1.0
	},
	PerformanceProfile.HIGH: {
		"update_frequency_multiplier": 0.9,
		"lod_bias": 0,
		"effect_quality": 0.9,
		"shadow_quality": 0.8,
		"texture_quality": 1.0,
		"particle_density": 0.8,
		"animation_quality": 0.9
	},
	PerformanceProfile.MEDIUM: {
		"update_frequency_multiplier": 0.75,
		"lod_bias": 1,
		"effect_quality": 0.7,
		"shadow_quality": 0.6,
		"texture_quality": 0.8,
		"particle_density": 0.6,
		"animation_quality": 0.75
	},
	PerformanceProfile.LOW: {
		"update_frequency_multiplier": 0.6,
		"lod_bias": 2,
		"effect_quality": 0.5,
		"shadow_quality": 0.3,
		"texture_quality": 0.6,
		"particle_density": 0.4,
		"animation_quality": 0.6
	},
	PerformanceProfile.MINIMAL: {
		"update_frequency_multiplier": 0.4,
		"lod_bias": 3,
		"effect_quality": 0.2,
		"shadow_quality": 0.0,
		"texture_quality": 0.4,
		"particle_density": 0.2,
		"animation_quality": 0.4
	}
}

# References to other optimization systems
var lod_manager: HUDLODManager
var update_scheduler: HUDUpdateScheduler
var render_optimizer: HUDRenderOptimizer
var memory_manager: HUDMemoryManager

# Statistics
var profile_changes: int = 0
var automatic_scaling_events: int = 0
var manual_overrides: int = 0
var emergency_scaling_events: int = 0

func _ready() -> void:
	print("HUDPerformanceScaler: Initializing performance scaling system")
	_initialize_scaler()

func _initialize_scaler() -> void:
	# Initialize FPS sample buffer
	last_fps_samples.resize(max_fps_samples)
	last_fps_samples.fill(target_fps)
	
	# Find optimization system references
	_connect_to_optimization_systems()
	
	# Set up processing
	set_process(true)
	
	print("HUDPerformanceScaler: Performance scaler initialized (target: %.0f FPS)" % target_fps)

func _connect_to_optimization_systems() -> void:
	# Try to find optimization systems in the scene tree
	var hud_manager = get_node_or_null("/root/HUDManager")
	if hud_manager:
		lod_manager = hud_manager.get_node_or_null("HUDLODManager")
		update_scheduler = hud_manager.get_node_or_null("HUDUpdateScheduler")
		render_optimizer = hud_manager.get_node_or_null("HUDRenderOptimizer")
		memory_manager = hud_manager.get_node_or_null("HUDMemoryManager")
	
	print("HUDPerformanceScaler: Connected to optimization systems")

func _process(delta: float) -> void:
	if not auto_scaling_enabled:
		return
	
	# Update FPS tracking
	_update_fps_tracking()
	
	# Update profile change timer
	profile_change_timer += delta
	
	# Check for automatic scaling needs
	_check_automatic_scaling()
	
	# Apply pending profile changes
	_apply_pending_profile_changes()

## Update FPS tracking with current frame rate
func _update_fps_tracking() -> void:
	var current_fps = Engine.get_frames_per_second()
	
	# Add to sample buffer
	last_fps_samples.push_back(current_fps)
	if last_fps_samples.size() > max_fps_samples:
		last_fps_samples.pop_front()

## Get average FPS over recent samples
func get_average_fps() -> float:
	if last_fps_samples.is_empty():
		return target_fps
	
	var total = 0.0
	for fps in last_fps_samples:
		total += fps
	
	return total / last_fps_samples.size()

## Check if automatic scaling is needed
func _check_automatic_scaling() -> void:
	var avg_fps = get_average_fps()
	var target_profile = _calculate_target_profile(avg_fps)
	
	# Check for emergency scaling
	if avg_fps < emergency_fps_threshold and current_profile != PerformanceProfile.MINIMAL:
		set_performance_profile(PerformanceProfile.MINIMAL, true)
		emergency_scaling_events += 1
		return
	
	# Normal scaling with hysteresis
	if target_profile != current_profile:
		if target_profile != requested_profile:
			# New target profile, reset timer
			requested_profile = target_profile
			profile_change_timer = 0.0
		elif profile_change_timer >= scaling_hysteresis_time:
			# Timer expired, apply profile change
			set_performance_profile(target_profile, false)
			automatic_scaling_events += 1

## Calculate target performance profile based on FPS
func _calculate_target_profile(fps: float) -> PerformanceProfile:
	# Check thresholds from highest to lowest
	if fps >= fps_thresholds[PerformanceProfile.MAXIMUM]:
		return PerformanceProfile.MAXIMUM
	elif fps >= fps_thresholds[PerformanceProfile.HIGH]:
		return PerformanceProfile.HIGH
	elif fps >= fps_thresholds[PerformanceProfile.MEDIUM]:
		return PerformanceProfile.MEDIUM
	elif fps >= fps_thresholds[PerformanceProfile.LOW]:
		return PerformanceProfile.LOW
	else:
		return PerformanceProfile.MINIMAL

## Apply pending profile changes
func _apply_pending_profile_changes() -> void:
	if requested_profile != current_profile and profile_change_timer >= scaling_hysteresis_time:
		_apply_performance_profile(requested_profile)

## Set performance profile (manual or automatic)
func set_performance_profile(profile: PerformanceProfile, immediate: bool = false) -> void:
	if profile == current_profile:
		return
	
	if immediate:
		_apply_performance_profile(profile)
	else:
		requested_profile = profile
		profile_change_timer = 0.0

## Apply a performance profile immediately
func _apply_performance_profile(profile: PerformanceProfile) -> void:
	var old_profile = current_profile
	current_profile = profile
	requested_profile = profile
	profile_change_timer = 0.0
	
	# Get settings for this profile
	var settings = profile_settings.get(profile, {})
	
	# Apply settings to optimization systems
	_apply_lod_settings(settings)
	_apply_update_settings(settings)
	_apply_render_settings(settings)
	_apply_memory_settings(settings)
	
	# Emit signals
	performance_profile_changed.emit(old_profile, current_profile)
	profile_changes += 1
	
	print("HUDPerformanceScaler: Applied performance profile %s" % PerformanceProfile.keys()[profile])

## Apply LOD settings for the performance profile
func _apply_lod_settings(settings: Dictionary) -> void:
	if not lod_manager:
		return
	
	var lod_bias = settings.get("lod_bias", 0)
	
	# Apply LOD bias - higher bias means lower quality
	match lod_bias:
		0:
			lod_manager.set_global_lod(HUDLODManager.LODLevel.MAXIMUM)
		1:
			lod_manager.set_global_lod(HUDLODManager.LODLevel.HIGH)
		2:
			lod_manager.set_global_lod(HUDLODManager.LODLevel.MEDIUM)
		3:
			lod_manager.set_global_lod(HUDLODManager.LODLevel.LOW)
		_:
			lod_manager.set_global_lod(HUDLODManager.LODLevel.MINIMAL)
	
	quality_adjustment_applied.emit("lod", "bias_%d" % lod_bias)

## Apply update scheduler settings
func _apply_update_settings(settings: Dictionary) -> void:
	if not update_scheduler:
		return
	
	var frequency_multiplier = settings.get("update_frequency_multiplier", 1.0)
	
	# Adjust frame budget based on frequency multiplier
	var base_budget = 2.0  # Base 2ms budget
	var new_budget = base_budget * frequency_multiplier
	update_scheduler.frame_budget_ms = new_budget
	
	quality_adjustment_applied.emit("updates", "frequency_%.1f" % frequency_multiplier)

## Apply render optimization settings
func _apply_render_settings(settings: Dictionary) -> void:
	if not render_optimizer:
		return
	
	var effect_quality = settings.get("effect_quality", 1.0)
	
	# Adjust culling aggressiveness based on quality
	if effect_quality < 0.5:
		render_optimizer.culling_margin = 100.0  # More aggressive culling
	elif effect_quality < 0.8:
		render_optimizer.culling_margin = 75.0   # Moderate culling
	else:
		render_optimizer.culling_margin = 50.0   # Normal culling
	
	quality_adjustment_applied.emit("rendering", "quality_%.1f" % effect_quality)

## Apply memory management settings
func _apply_memory_settings(settings: Dictionary) -> void:
	if not memory_manager:
		return
	
	var texture_quality = settings.get("texture_quality", 1.0)
	
	# Adjust cache limits based on texture quality
	var base_cache_mb = 20.0
	var cache_limit = base_cache_mb * texture_quality
	memory_manager.cache_size_limit_mb = cache_limit
	
	quality_adjustment_applied.emit("memory", "cache_%.1fMB" % cache_limit)

## Force immediate performance scaling to specific profile
func force_performance_profile(profile: PerformanceProfile) -> void:
	set_performance_profile(profile, true)
	manual_overrides += 1
	print("HUDPerformanceScaler: Forced performance profile to %s" % PerformanceProfile.keys()[profile])

## Enable emergency performance mode (minimal quality)
func enable_emergency_mode() -> void:
	print("HUDPerformanceScaler: Enabling emergency performance mode")
	force_performance_profile(PerformanceProfile.MINIMAL)
	emergency_scaling_events += 1

## Disable emergency mode and return to automatic scaling
func disable_emergency_mode() -> void:
	print("HUDPerformanceScaler: Disabling emergency performance mode")
	auto_scaling_enabled = true

## Enable or disable automatic scaling
func set_auto_scaling_enabled(enabled: bool) -> void:
	auto_scaling_enabled = enabled
	
	if enabled:
		# Reset to allow immediate scaling
		profile_change_timer = scaling_hysteresis_time
	
	print("HUDPerformanceScaler: Automatic scaling %s" % ("enabled" if enabled else "disabled"))

## Set custom FPS thresholds for performance profiles
func set_fps_thresholds(thresholds: Dictionary) -> void:
	fps_thresholds = thresholds
	print("HUDPerformanceScaler: Updated FPS thresholds for performance scaling")

## Get current performance statistics
func get_performance_statistics() -> Dictionary:
	return {
		"current_profile": PerformanceProfile.keys()[current_profile],
		"requested_profile": PerformanceProfile.keys()[requested_profile],
		"current_fps": Engine.get_frames_per_second(),
		"average_fps": get_average_fps(),
		"target_fps": target_fps,
		"auto_scaling_enabled": auto_scaling_enabled,
		"profile_changes": profile_changes,
		"automatic_scaling_events": automatic_scaling_events,
		"manual_overrides": manual_overrides,
		"emergency_scaling_events": emergency_scaling_events,
		"time_until_next_scale": max(0.0, scaling_hysteresis_time - profile_change_timer)
	}

## Get detailed settings for current performance profile
func get_current_profile_settings() -> Dictionary:
	return profile_settings.get(current_profile, {})

## Configure performance profile settings
func configure_profile_settings(profile: PerformanceProfile, settings: Dictionary) -> void:
	profile_settings[profile] = settings
	
	# Re-apply if this is the current profile
	if profile == current_profile:
		_apply_performance_profile(profile)
	
	print("HUDPerformanceScaler: Configured settings for profile %s" % PerformanceProfile.keys()[profile])

## Predict performance impact of switching to a profile
func predict_performance_impact(target_profile: PerformanceProfile) -> Dictionary:
	var current_settings = profile_settings.get(current_profile, {})
	var target_settings = profile_settings.get(target_profile, {})
	
	var impact = {
		"expected_fps_change": 0.0,
		"quality_changes": {},
		"memory_impact": 0.0,
		"battery_impact": 0.0
	}
	
	# Estimate FPS improvement/degradation
	var frequency_change = target_settings.get("update_frequency_multiplier", 1.0) / current_settings.get("update_frequency_multiplier", 1.0)
	impact.expected_fps_change = (1.0 / frequency_change - 1.0) * 100.0  # Percentage change
	
	# Identify quality changes
	for setting in ["effect_quality", "shadow_quality", "texture_quality", "particle_density"]:
		var current_val = current_settings.get(setting, 1.0)
		var target_val = target_settings.get(setting, 1.0)
		
		if abs(current_val - target_val) > 0.05:  # Significant change
			impact.quality_changes[setting] = {
				"from": current_val,
				"to": target_val,
				"change_percent": (target_val - current_val) / current_val * 100.0
			}
	
	return impact

## Temporarily boost performance for critical operations
func boost_performance_temporarily(duration_seconds: float) -> void:
	print("HUDPerformanceScaler: Boosting performance for %.1f seconds" % duration_seconds)
	
	var original_profile = current_profile
	force_performance_profile(PerformanceProfile.MINIMAL)
	
	# Create timer to restore original profile
	var timer = Timer.new()
	timer.wait_time = duration_seconds
	timer.one_shot = true
	timer.timeout.connect(func(): 
		force_performance_profile(original_profile)
		timer.queue_free()
		print("HUDPerformanceScaler: Performance boost expired, restored to %s" % PerformanceProfile.keys()[original_profile])
	)
	add_child(timer)
	timer.start()

## Monitor critical performance events
func monitor_performance_event(event_name: String, start_time: float, end_time: float) -> void:
	var duration_ms = (end_time - start_time) / 1000.0
	var current_fps = Engine.get_frames_per_second()
	
	# Check if event caused performance issues
	if duration_ms > 16.67:  # Longer than one frame at 60 FPS
		print("HUDPerformanceScaler: Performance event '%s' took %.1fms (current FPS: %.1f)" % [event_name, duration_ms, current_fps])
		
		# Consider temporary performance boost
		if current_fps < target_fps * 0.8:  # FPS dropped significantly
			boost_performance_temporarily(2.0)  # Boost for 2 seconds