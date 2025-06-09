class_name CombatScalingController
extends Node

## SHIP-016 AC5: Combat Scaling Controller for dynamic quality adjustment in large battles
## Maintains stable performance with 50+ ships through dynamic quality adjustment and load balancing
## Implements ship-specific scaling that works with existing LOD systems

signal combat_scale_changed(new_scale: float, reason: String, ships_affected: int)
signal battle_intensity_changed(intensity: BattleIntensity, ship_count: int, weapon_count: int)
signal performance_mode_activated(mode: PerformanceMode, quality_reduction: float)
signal ship_system_scaled(ship: BaseShip, system_name: String, scale_factor: float)

# Battle intensity levels
enum BattleIntensity {
	PEACEFUL,       # <5 ships, minimal weapons fire
	SKIRMISH,       # 5-15 ships, moderate combat
	ENGAGEMENT,     # 15-30 ships, active combat
	BATTLE,         # 30-50 ships, intense combat  
	MASSIVE_BATTLE  # 50+ ships, maximum combat
}

# Performance modes for scaling
enum PerformanceMode {
	MAXIMUM_QUALITY,    # No scaling, full quality
	BALANCED,           # Minimal scaling for distant objects
	PERFORMANCE,        # Moderate scaling for stability
	SURVIVAL            # Aggressive scaling to maintain frame rate
}

# Configuration
@export var enable_combat_scaling: bool = true
@export var target_fps: float = 60.0
@export var minimum_fps: float = 30.0
@export var ship_count_threshold: int = 50
@export var update_frequency: float = 0.5  # Scaling updates every 500ms
@export var auto_performance_mode: bool = true

# Current state
var current_battle_intensity: BattleIntensity = BattleIntensity.PEACEFUL
var current_performance_mode: PerformanceMode = PerformanceMode.MAXIMUM_QUALITY
var combat_scale_factor: float = 1.0
var active_ships: Array[BaseShip] = []
var last_update_time: float = 0.0

# Performance tracking
var fps_samples: Array[float] = []
var sample_count: int = 30
var performance_history: Array[Dictionary] = []

# Ship system scaling factors
var ship_system_scales: Dictionary = {
	"weapon_effects": 1.0,
	"engine_effects": 1.0,
	"shield_effects": 1.0,
	"damage_effects": 1.0,
	"audio_effects": 1.0,
	"physics_detail": 1.0,
	"ai_complexity": 1.0,
	"subsystem_updates": 1.0
}

# Battle intensity thresholds
var intensity_thresholds: Dictionary = {
	BattleIntensity.PEACEFUL: {"ship_count": 5, "weapon_fire_rate": 10},
	BattleIntensity.SKIRMISH: {"ship_count": 15, "weapon_fire_rate": 50},
	BattleIntensity.ENGAGEMENT: {"ship_count": 30, "weapon_fire_rate": 100},
	BattleIntensity.BATTLE: {"ship_count": 50, "weapon_fire_rate": 200},
	BattleIntensity.MASSIVE_BATTLE: {"ship_count": 1000, "weapon_fire_rate": 1000}
}

# Performance mode scaling configurations
var performance_mode_configs: Dictionary = {
	PerformanceMode.MAXIMUM_QUALITY: {
		"weapon_effects": 1.0,
		"engine_effects": 1.0,
		"shield_effects": 1.0,
		"damage_effects": 1.0,
		"audio_effects": 1.0,
		"physics_detail": 1.0,
		"ai_complexity": 1.0,
		"subsystem_updates": 1.0
	},
	PerformanceMode.BALANCED: {
		"weapon_effects": 0.9,
		"engine_effects": 0.9,
		"shield_effects": 0.95,
		"damage_effects": 0.8,
		"audio_effects": 0.9,
		"physics_detail": 0.95,
		"ai_complexity": 0.9,
		"subsystem_updates": 0.9
	},
	PerformanceMode.PERFORMANCE: {
		"weapon_effects": 0.7,
		"engine_effects": 0.7,
		"shield_effects": 0.8,
		"damage_effects": 0.6,
		"audio_effects": 0.7,
		"physics_detail": 0.8,
		"ai_complexity": 0.7,
		"subsystem_updates": 0.8
	},
	PerformanceMode.SURVIVAL: {
		"weapon_effects": 0.4,
		"engine_effects": 0.5,
		"shield_effects": 0.6,
		"damage_effects": 0.3,
		"audio_effects": 0.4,
		"physics_detail": 0.6,
		"ai_complexity": 0.5,
		"subsystem_updates": 0.6
	}
}

func _ready() -> void:
	set_process(enable_combat_scaling)
	_initialize_fps_samples()
	print("CombatScalingController: Dynamic quality adjustment system for large battles initialized")

## Initialize FPS sampling array
func _initialize_fps_samples() -> void:
	fps_samples.resize(sample_count)
	for i in range(sample_count):
		fps_samples[i] = target_fps

func _process(delta: float) -> void:
	if not enable_combat_scaling:
		return
	
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Update FPS tracking
	_update_fps_tracking(delta)
	
	# Update scaling at specified frequency
	if current_time - last_update_time >= update_frequency:
		_update_combat_scaling()
		last_update_time = current_time

## Update FPS tracking samples
func _update_fps_tracking(delta: float) -> void:
	var current_fps: float = 1.0 / delta if delta > 0.0 else target_fps
	
	# Shift samples and add new one
	fps_samples.pop_front()
	fps_samples.append(current_fps)

## Update combat scaling based on current conditions
func _update_combat_scaling() -> void:
	# Get current battle state
	var ship_count: int = _get_active_ship_count()
	var weapon_fire_rate: float = _get_weapon_fire_rate()
	var average_fps: float = _calculate_average_fps()
	
	# Determine battle intensity
	var new_intensity: BattleIntensity = _calculate_battle_intensity(ship_count, weapon_fire_rate)
	if new_intensity != current_battle_intensity:
		current_battle_intensity = new_intensity
		battle_intensity_changed.emit(new_intensity, ship_count, int(weapon_fire_rate))
	
	# Determine performance mode
	var new_mode: PerformanceMode = _determine_performance_mode(average_fps, ship_count)
	if new_mode != current_performance_mode:
		_apply_performance_mode(new_mode)
	
	# Update combat scale factor
	var new_scale: float = _calculate_combat_scale_factor(new_intensity, new_mode, average_fps)
	if abs(new_scale - combat_scale_factor) > 0.05:
		_apply_combat_scale_factor(new_scale)

## Calculate current battle intensity
func _calculate_battle_intensity(ship_count: int, weapon_fire_rate: float) -> BattleIntensity:
	# Start from highest intensity and work down
	var intensities: Array = [
		BattleIntensity.MASSIVE_BATTLE,
		BattleIntensity.BATTLE,
		BattleIntensity.ENGAGEMENT,
		BattleIntensity.SKIRMISH,
		BattleIntensity.PEACEFUL
	]
	
	for intensity in intensities:
		var threshold: Dictionary = intensity_thresholds[intensity]
		if ship_count >= threshold["ship_count"] or weapon_fire_rate >= threshold["weapon_fire_rate"]:
			return intensity
	
	return BattleIntensity.PEACEFUL

## Determine appropriate performance mode
func _determine_performance_mode(average_fps: float, ship_count: int) -> PerformanceMode:
	if not auto_performance_mode:
		return current_performance_mode
	
	# Performance-based mode selection
	if average_fps < minimum_fps:
		return PerformanceMode.SURVIVAL
	elif average_fps < target_fps * 0.8:
		return PerformanceMode.PERFORMANCE
	elif ship_count > ship_count_threshold or average_fps < target_fps * 0.95:
		return PerformanceMode.BALANCED
	else:
		return PerformanceMode.MAXIMUM_QUALITY

## Calculate combat scale factor
func _calculate_combat_scale_factor(intensity: BattleIntensity, mode: PerformanceMode, fps: float) -> float:
	var base_scale: float = 1.0
	
	# Intensity-based scaling
	match intensity:
		BattleIntensity.PEACEFUL:
			base_scale = 1.0
		BattleIntensity.SKIRMISH:
			base_scale = 0.95
		BattleIntensity.ENGAGEMENT:
			base_scale = 0.9
		BattleIntensity.BATTLE:
			base_scale = 0.8
		BattleIntensity.MASSIVE_BATTLE:
			base_scale = 0.7
	
	# Performance-based modifier
	var fps_modifier: float = 1.0
	if fps < target_fps:
		fps_modifier = fps / target_fps
		fps_modifier = max(0.3, fps_modifier)  # Never go below 30%
	
	return base_scale * fps_modifier

## Apply performance mode to all ship systems
func _apply_performance_mode(mode: PerformanceMode) -> void:
	var old_mode: PerformanceMode = current_performance_mode
	current_performance_mode = mode
	
	var config: Dictionary = performance_mode_configs[mode]
	var ships_affected: int = 0
	
	# Apply scaling to all ship systems
	for system_name in config.keys():
		var scale_factor: float = config[system_name]
		ship_system_scales[system_name] = scale_factor
		
		# Apply to active ships
		for ship in active_ships:
			if _apply_system_scaling_to_ship(ship, system_name, scale_factor):
				ships_affected += 1
	
	# Calculate quality reduction
	var quality_reduction: float = (1.0 - _calculate_average_scale(config)) * 100.0
	
	performance_mode_activated.emit(mode, quality_reduction)
	print("CombatScalingController: Performance mode changed from %s to %s (%.1f%% quality reduction)" % 
		[PerformanceMode.keys()[old_mode], PerformanceMode.keys()[mode], quality_reduction])

## Apply combat scale factor
func _apply_combat_scale_factor(new_scale: float) -> void:
	var old_scale: float = combat_scale_factor
	combat_scale_factor = new_scale
	
	var reason: String = ""
	if new_scale < old_scale:
		reason = "Performance optimization"
	else:
		reason = "Performance improvement"
	
	var ships_affected: int = _apply_scale_to_active_ships(new_scale)
	combat_scale_changed.emit(new_scale, reason, ships_affected)

## Apply system scaling to specific ship
func _apply_system_scaling_to_ship(ship: BaseShip, system_name: String, scale_factor: float) -> bool:
	if not is_instance_valid(ship):
		return false
	
	match system_name:
		"weapon_effects":
			return _scale_weapon_effects(ship, scale_factor)
		"engine_effects":
			return _scale_engine_effects(ship, scale_factor)
		"shield_effects":
			return _scale_shield_effects(ship, scale_factor)
		"damage_effects":
			return _scale_damage_effects(ship, scale_factor)
		"audio_effects":
			return _scale_audio_effects(ship, scale_factor)
		"physics_detail":
			return _scale_physics_detail(ship, scale_factor)
		"ai_complexity":
			return _scale_ai_complexity(ship, scale_factor)
		"subsystem_updates":
			return _scale_subsystem_updates(ship, scale_factor)
	
	return false

## Scale weapon effects for ship
func _scale_weapon_effects(ship: BaseShip, scale_factor: float) -> bool:
	# Reduce particle counts and effect quality
	var weapon_manager = ship.get_node_or_null("WeaponManager")
	if weapon_manager and weapon_manager.has_method("set_effect_scale"):
		weapon_manager.set_effect_scale(scale_factor)
		ship_system_scaled.emit(ship, "weapon_effects", scale_factor)
		return true
	return false

## Scale engine effects for ship
func _scale_engine_effects(ship: BaseShip, scale_factor: float) -> bool:
	# Reduce engine trail particle counts
	var particles: Array[Node] = ship.find_children("*", "GPUParticles3D")
	for particle_node in particles:
		if particle_node.name.contains("Engine") or particle_node.name.contains("Trail"):
			var particles_3d: GPUParticles3D = particle_node as GPUParticles3D
			var original_amount: int = particles_3d.get_meta("original_amount", particles_3d.amount)
			particles_3d.set_meta("original_amount", original_amount)
			particles_3d.amount = int(original_amount * scale_factor)
	
	ship_system_scaled.emit(ship, "engine_effects", scale_factor)
	return true

## Scale shield effects for ship
func _scale_shield_effects(ship: BaseShip, scale_factor: float) -> bool:
	# Reduce shield hit effect intensity
	var shield_manager = ship.get_node_or_null("ShieldManager")
	if shield_manager and shield_manager.has_method("set_effect_intensity"):
		shield_manager.set_effect_intensity(scale_factor)
		ship_system_scaled.emit(ship, "shield_effects", scale_factor)
		return true
	return false

## Scale damage effects for ship
func _scale_damage_effects(ship: BaseShip, scale_factor: float) -> bool:
	# Reduce damage particle effects and smoke
	var damage_manager = ship.get_node_or_null("DamageManager")
	if damage_manager and damage_manager.has_method("set_effect_scale"):
		damage_manager.set_effect_scale(scale_factor)
		ship_system_scaled.emit(ship, "damage_effects", scale_factor)
		return true
	return false

## Scale audio effects for ship
func _scale_audio_effects(ship: BaseShip, scale_factor: float) -> bool:
	# Reduce audio effect complexity and range
	var audio_players: Array[Node] = ship.find_children("*", "AudioStreamPlayer3D")
	for audio_node in audio_players:
		var audio_player: AudioStreamPlayer3D = audio_node as AudioStreamPlayer3D
		var original_distance: float = audio_player.get_meta("original_max_distance", audio_player.max_distance)
		audio_player.set_meta("original_max_distance", original_distance)
		audio_player.max_distance = original_distance * scale_factor
	
	ship_system_scaled.emit(ship, "audio_effects", scale_factor)
	return true

## Scale physics detail for ship
func _scale_physics_detail(ship: BaseShip, scale_factor: float) -> bool:
	# Reduce physics update frequency (leverage existing LOD system)
	if ship.has_method("set_physics_lod_scale"):
		ship.set_physics_lod_scale(scale_factor)
		ship_system_scaled.emit(ship, "physics_detail", scale_factor)
		return true
	return false

## Scale AI complexity for ship
func _scale_ai_complexity(ship: BaseShip, scale_factor: float) -> bool:
	# Reduce AI decision frequency and complexity
	var ai_controller = ship.get_node_or_null("AIController")
	if ai_controller and ai_controller.has_method("set_complexity_scale"):
		ai_controller.set_complexity_scale(scale_factor)
		ship_system_scaled.emit(ship, "ai_complexity", scale_factor)
		return true
	return false

## Scale subsystem updates for ship
func _scale_subsystem_updates(ship: BaseShip, scale_factor: float) -> bool:
	# Reduce subsystem update frequency
	var subsystem_manager = ship.get_node_or_null("SubsystemManager")
	if subsystem_manager and subsystem_manager.has_method("set_update_frequency_scale"):
		subsystem_manager.set_update_frequency_scale(scale_factor)
		ship_system_scaled.emit(ship, "subsystem_updates", scale_factor)
		return true
	return false

## Apply scale factor to all active ships
func _apply_scale_to_active_ships(scale_factor: float) -> int:
	var ships_affected: int = 0
	
	for ship in active_ships:
		if not is_instance_valid(ship):
			continue
		
		# Apply global scale to all systems
		for system_name in ship_system_scales.keys():
			var system_scale: float = ship_system_scales[system_name] * scale_factor
			if _apply_system_scaling_to_ship(ship, system_name, system_scale):
				ships_affected += 1
	
	return ships_affected

## Get current active ship count
func _get_active_ship_count() -> int:
	# Clean up invalid ships
	active_ships = active_ships.filter(func(ship): return is_instance_valid(ship))
	return active_ships.size()

## Get current weapon fire rate (shots per second)
func _get_weapon_fire_rate() -> float:
	var total_fire_rate: float = 0.0
	
	for ship in active_ships:
		if not is_instance_valid(ship):
			continue
		
		# Get ship's current weapon activity
		if ship.has_method("get_weapon_fire_rate"):
			total_fire_rate += ship.get_weapon_fire_rate()
	
	return total_fire_rate

## Calculate average FPS from samples
func _calculate_average_fps() -> float:
	if fps_samples.is_empty():
		return target_fps
	
	var sum: float = 0.0
	for fps in fps_samples:
		sum += fps
	
	return sum / fps_samples.size()

## Calculate average scale factor from config
func _calculate_average_scale(config: Dictionary) -> float:
	var sum: float = 0.0
	var count: int = 0
	
	for scale_value in config.values():
		sum += scale_value
		count += 1
	
	return sum / max(1, count)

# Public API

## Register ship for combat scaling
func register_ship(ship: BaseShip) -> bool:
	if not ship or active_ships.has(ship):
		return false
	
	active_ships.append(ship)
	print("CombatScalingController: Registered ship %s for combat scaling" % ship.ship_name)
	return true

## Unregister ship from combat scaling
func unregister_ship(ship: BaseShip) -> bool:
	var index: int = active_ships.find(ship)
	if index == -1:
		return false
	
	active_ships.remove_at(index)
	print("CombatScalingController: Unregistered ship %s from combat scaling" % ship.ship_name)
	return true

## Set performance mode manually
func set_performance_mode(mode: PerformanceMode) -> void:
	auto_performance_mode = false
	_apply_performance_mode(mode)

## Enable automatic performance mode
func enable_auto_performance_mode() -> void:
	auto_performance_mode = true
	print("CombatScalingController: Automatic performance mode enabled")

## Get current combat statistics
func get_combat_statistics() -> Dictionary:
	return {
		"battle_intensity": BattleIntensity.keys()[current_battle_intensity],
		"performance_mode": PerformanceMode.keys()[current_performance_mode],
		"combat_scale_factor": combat_scale_factor,
		"active_ship_count": _get_active_ship_count(),
		"weapon_fire_rate": _get_weapon_fire_rate(),
		"average_fps": _calculate_average_fps(),
		"ship_system_scales": ship_system_scales.duplicate(),
		"auto_performance_mode": auto_performance_mode
	}

## Force combat scale recalculation
func force_scale_update() -> void:
	last_update_time = 0.0  # Force immediate update
	print("CombatScalingController: Forced combat scale recalculation")

## Set custom system scale
func set_system_scale(system_name: String, scale_factor: float) -> bool:
	if not ship_system_scales.has(system_name):
		return false
	
	ship_system_scales[system_name] = clamp(scale_factor, 0.1, 1.0)
	
	# Apply to all active ships
	for ship in active_ships:
		_apply_system_scaling_to_ship(ship, system_name, scale_factor)
	
	print("CombatScalingController: Set %s scale to %.2f" % [system_name, scale_factor])
	return true

## Get system scale
func get_system_scale(system_name: String) -> float:
	return ship_system_scales.get(system_name, 1.0)

## Set scaling enabled/disabled
func set_scaling_enabled(enabled: bool) -> void:
	enable_combat_scaling = enabled
	set_process(enabled)
	
	if not enabled:
		# Reset all scales to maximum
		for system_name in ship_system_scales.keys():
			ship_system_scales[system_name] = 1.0
		
		combat_scale_factor = 1.0
		_apply_scale_to_active_ships(1.0)
	
	print("CombatScalingController: Combat scaling %s" % ("enabled" if enabled else "disabled"))